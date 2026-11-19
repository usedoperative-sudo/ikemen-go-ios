//go:build !ios

package main

import "C"

// Gets the actual device pixel size
func (w *Window) GetDrawablePixelSize() (int32, int32) {
	winWidth, winHeight := w.Window.GetSize()
	return winWidth, winHeight
}

func attachIOSMetalLayer(windowID uint32) {
	// NOOP
}

func refreshIOSMetalLayer() {
	// NOOP
}

func setOrientationHints() {
	// NOOP
}

func nativeEngineReady() {
	// NOOP
}

func nativeIsAppActive() bool {
	// No iOS lifecycle to poll on other platforms.
	return true
}
