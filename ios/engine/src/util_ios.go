//go:build ios

package main

/*
#cgo CFLAGS: -DSDL_MAIN_HANDLED
#cgo ios CFLAGS: -I/workspaces/ikemen-go-ios/deps/ios-sdl/include/SDL2
#cgo ios LDFLAGS: -framework OpenGLES
#include <stdlib.h>
#include <string.h>
#include "SDL.h"
#include "iosgl.h"

// Provided by the app wrapper (main.m): returns the Documents base dir
// (malloc'd) or NULL. Decouples base-dir resolution from the environment, which
// Go's runtime may not observe if IKEMEN_BASE_DIR is set after Go init.
char* IOSGameBaseDir(void);
*/
import "C"
import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"sync"
	"unsafe"

	findfont "github.com/flopp/go-findfont"
)

var (
	iosLogFileMtx sync.Mutex
	iosLogFile    *os.File
)

// initIOSFileLog opens save/logs/engine.log and redirects os.Stdout and
// os.Stderr into it, so every print/Logcat lands in the sandbox (curl-able
// via the debug server) for on-device diagnostics. Call this once
// sys.baseDir is known (iOS branch).
func initIOSFileLog() {
	logDir := filepath.Join(sys.baseDir, "save", "logs")
	os.MkdirAll(logDir, 0755)
	logPath := filepath.Join(logDir, "engine.log")
	f, err := os.OpenFile(logPath, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0644)
	if err != nil {
		// Keep stderr pointing at the device console and fall through
		return
	}

	// Prepare two independent handles so closing one later won't poison the other.
	stdout := os.NewFile(f.Fd(), "engine.log-stdout")
	stderr := os.NewFile(f.Fd(), "engine.log-stderr")

	iosLogFileMtx.Lock()
	iosLogFile = f
	iosLogFileMtx.Unlock()

	os.Stdout = stdout
	os.Stderr = stderr
	Logcat("=== IKEMEN engine.log opened: " + logPath + " ===")
}

// Log writer implementation
// On iOS, Stderr goes to the device/system log
func NewLogWriter() io.Writer {
	return os.Stderr
}

// TTF font loading
func LoadFntTtf(f *Fnt, fontfile string, filename string, height int32) {
	// 1. Path resolution
	fileDir := SearchFile(filename, []string{fontfile, sys.motif.Def, "", "data/"}, "font/")

	// 2. iOS Path Correction
	if !filepath.IsAbs(fileDir) && FileExist(fileDir) == "" {
		fullPath := filepath.Join(getIOSDocumentsDir(), fileDir)
		if FileExist(fullPath) != "" {
			fileDir = fullPath
		}
	}

	// Fallback to findfont if still not found
	if FileExist(fileDir) == "" {
		if found, err := findfont.Find(fileDir); err == nil {
			fileDir = found
		} else {
			Logcat(fmt.Sprintf("Font search failed for %s, trying direct path...", filename))
		}
	}

	// 2. Set dimensions
	if height == -1 {
		height = int32(f.Size[1])
	} else {
		f.Size[1] = uint16(height)
	}

	// 3. Load the TTF
	ttf, err := gfxFont.LoadFont(fileDir, height, int(sys.gameWidth), int(sys.gameHeight))
	if err != nil {
		Logcat(fmt.Sprintf("ERROR: Failed to load TTF from %s", fileDir))
		panic(fmt.Errorf("failed to load ttf font %v: %w", fileDir, err))
	}

	f.ttf = ttf.(Font)

	// 4. Create dummy palettes
	f.palettes = make([][256]uint32, 1)
	for i := 0; i < 256; i++ {
		f.palettes[0][i] = 0
	}
}

// Message box implementation
func ShowInfoDialog(message, title string) {
	Logcat(fmt.Sprintf("INFO [%s]: %s", title, message))
}

func ShowErrorDialog(message string) {
	Logcat(fmt.Sprintf("CRITICAL ERROR: %s", message))
}

//export SDL_main
func SDL_main(argc C.int, argv **C.char) C.int {
	runtime.LockOSThread()
	realMain()
	return 0
}

func iosGetProcAddress(name string) unsafe.Pointer {
	cname := C.CString(name)
	defer C.free(unsafe.Pointer(cname))
	return C.iosGetProcAddress(cname)
}

func selectRenderer(cfgVal string) (Renderer, FontRenderer) {
	return &Renderer_IOS{}, &FontRenderer_IOS{}
}

// getIOSDocumentsDir returns the app's Documents/ikemen-go/IkemenGo directory,
// which is exposed via iOS file sharing / the Files app for easy custom
// stage/char/data additions. The wrapper (main.m) seeds this directory with the
// IKEMEN data tree and hands its path to us through IOSGameBaseDir(). We fall
// back to SDL_GetPrefPath if it's unavailable (e.g. running on desktop).
func getIOSDocumentsDir() string {
	if dir := C.IOSGameBaseDir(); dir != nil {
		defer C.free(unsafe.Pointer(dir))
		if s := C.GoString(dir); s != "" {
			return s
		}
	}
	dir := C.SDL_GetPrefPath(C.CString("ikemen-go"), C.CString("IkemenGo"))
	if dir == nil {
		return "."
	}
	defer C.SDL_free(unsafe.Pointer(dir))
	return C.GoString(dir)
}

// osPreferredLanguage is not available without Foundation/ObjC on iOS.
func osPreferredLanguage() string {
	return ""
}

func Logcat(s string) {
	fmt.Fprintln(os.Stderr, s)
}