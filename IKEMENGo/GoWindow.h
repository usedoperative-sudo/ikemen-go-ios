//
//  GoWindow.h
//  I.K.E.M.E.N-Go
//
//  Created by Jesuszilla on 8/29/26.
//
//  Bridge into the exported Go symbols of libengine.a. The upstream engine
//  exports GetMoltenVKWindowID() so the app can ask the engine for the SDL
//  window that carries the Metal/Vulkan drawable.

#ifndef GO_WINDOW_H
#define GO_WINDOW_H

#include <stdint.h>
#include <stdlib.h>

uint32_t GetMoltenVKWindowID(void);

#endif