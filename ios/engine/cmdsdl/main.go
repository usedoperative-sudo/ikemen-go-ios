package main

import (
	"fmt"

	"github.com/veandco/go-sdl2/sdl"
)

func main() {
	var v sdl.Version
	sdl.GetVersion(&v)
	fmt.Printf("SDL %d.%d.%d init=%v\n", v.Major, v.Minor, v.Patch, sdl.WasInit(sdl.INIT_EVERYTHING))
}
