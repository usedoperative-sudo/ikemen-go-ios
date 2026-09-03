//go:build ios

package main

/*
#cgo CFLAGS: -DSDL_MAIN_HANDLED
#cgo ios CFLAGS: -I/workspaces/ikemen-go-ios/deps/ios-sdl/include/SDL2
#include <stdlib.h>

// Provided by the app (IKEMENGo/OverlayController.m). Adds the native UIKit
// on-screen controls on top of SDL's UIKit window. Must be safe to call from
// any thread; it marshals onto the main thread internally.
void IOSInstallOverlay(void *uiWindow);
*/
import "C"

import (
	"sync"
	"unsafe"
)

// Native on-screen controls for iOS.
//
// The UIKit overlay (implemented in Objective-C in the app wrapper) owns all
// touch handling. When a virtual button / joystick changes state it calls the
// exported IOSHandleKey(), which enqueues an abstract input event. Each
// rendered frame the game thread drains that queue and translates it into
// synthetic keyboard presses for Player 1 using sys.keyConfig[0] (indices
// 0..12) or Escape (index 13), reusing the engine's existing keyboard input
// path (GetKeyboardState) so it works on every screen (menu, select, fight).

type iosInputEvent struct {
	id      int
	pressed bool
}

var (
	iosInputMtx sync.Mutex
	iosInputQ   []iosInputEvent
)

//export IOSHandleKey
func IOSHandleKey(keyID C.int, pressed C.int) {
	iosInputMtx.Lock()
	iosInputQ = append(iosInputQ, iosInputEvent{id: int(keyID), pressed: pressed != 0})
	iosInputMtx.Unlock()
}

// Key index to keycode mapping, honoring the player's configured keyboard
// layout. Indices match the [14]bool returned by GetKeyboardState.
func iosPlayerKey(idx int) Key {
	if len(sys.keyConfig) <= 0 {
		return KeyUnknown
	}
	kc := sys.keyConfig[0]
	switch idx {
	case 0:
		return Key(kc.dU)
	case 1:
		return Key(kc.dD)
	case 2:
		return Key(kc.dL)
	case 3:
		return Key(kc.dR)
	case 4:
		return Key(kc.bA)
	case 5:
		return Key(kc.bB)
	case 6:
		return Key(kc.bC)
	case 7:
		return Key(kc.bX)
	case 8:
		return Key(kc.bY)
	case 9:
		return Key(kc.bZ)
	case 10:
		return Key(kc.bS)
	case 11:
		return Key(kc.bD)
	case 12:
		return Key(kc.bW)
	}
	return KeyUnknown
}

func iosKeyChange(id int, pressed bool) {
	var key Key
	if id == 13 { // MENU -> Escape (pause in fights, back in menus)
		key = KeyEscape
	} else {
		key = iosPlayerKey(id)
	}
	if key == KeyUnknown {
		return
	}
	if pressed {
		OnKeyPressed(key, 0)
	} else {
		OnKeyReleased(key, 0)
	}
}

// Drain queued native input on the game thread. Called each rendered frame.
func iosTouchUpdateInput() {
	iosInputMtx.Lock()
	q := iosInputQ
	iosInputQ = nil
	iosInputMtx.Unlock()
	for _, ev := range q {
		iosKeyChange(ev.id, ev.pressed)
	}
}

// Return the native UIKit window backing the SDL window, or nil.
func iosUIKitWindow() unsafe.Pointer {
	if sys.window == nil || sys.window.Window == nil {
		return nil
	}
	if info, err := sys.window.Window.GetWMInfo(); err == nil {
		if ui := info.GetUIKitInfo(); ui != nil {
			return ui.Window
		}
	}
	return nil
}

// Attach the native overlay. Called once after SDL's window is created.
func iosInstallOverlay() {
	uikitWin := iosUIKitWindow()
	if uikitWin == nil {
		Logcat("iosInstallOverlay: no UIKit window available")
		return
	}
	C.IOSInstallOverlay(uikitWin)
	Logcat("iosInstallOverlay: native overlay installed")
}
