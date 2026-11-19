//go:build ios

package main

/*
#include "SDLWindowFix.h"
*/
import "C"

import (
	"strings"

	"github.com/veandco/go-sdl2/sdl"
)

// Gets the actual device pixel size (Retina displays are special).
// Vulkan/MoltenVK renders into a CAMetalLayer; OpenGL ES renders into SDL's
// own drawable. Asking Metal for a GL window's size returns the wrong extent
// and made the GLES viewport occupy only a corner of the screen.
func (w *Window) GetDrawablePixelSize() (int32, int32) {
	if gfx != nil && strings.HasPrefix(gfx.GetName(), "OpenGL") {
		return w.GLGetDrawableSize()
	}
	winWidth, winHeight := sdl.Metal_GetDrawableSize(w.Window)
	return int32(winWidth), int32(winHeight)
}

// GLGetDrawableSize returns the OpenGL drawable size in pixels.
func (w *Window) GLGetDrawableSize() (int32, int32) {
	winWidth, winHeight := w.Window.GLGetDrawableSize()
	return winWidth, winHeight
}

func attachIOSMetalLayer(windowID uint32) {
	C.IkemenAttachMetalLayer(C.uint32_t(windowID))
}

func attachIOSGLESOverlay(windowID uint32) {
	C.IkemenAttachGLESOverlay(C.uint32_t(windowID))
}

func refreshIOSMetalLayer() {
	C.IkemenRefreshMetalLayer()
}

func setOrientationHints() {
	sdl.SetHint(sdl.HINT_ORIENTATIONS, "LandscapeLeft LandscapeRight Portrait PortraitUpsideDown")
}
