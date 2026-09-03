//go:build !ios

package main

// No-op stubs for the native on-screen controls on non-iOS platforms.
// (The real implementation lives in input_ios.go.)

func iosTouchUpdateInput() {}

func iosInstallOverlay() {}
