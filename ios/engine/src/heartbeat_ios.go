//go:build ios

package main

/*
#include <mach/mach.h>
#include <mach/task_info.h>
#include <stdio.h>

// Resident set size (true process memory) in bytes, -1 on failure.
static long iosResidentBytes(void) {
	struct task_basic_info info;
	mach_msg_type_number_t size = sizeof(info);
	kern_return_t k = task_info(mach_task_self(), TASK_BASIC_INFO,
		(task_info_t)&info, &size);
	if (k != KERN_SUCCESS) {
		return -1;
	}
	return (long)info.resident_size;
}
*/
import "C"

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"runtime/debug"
	"runtime/pprof"
	"time"
)

// iosHeartbeatLogPath returns where the heartbeat is stored.
func iosHeartbeatLogPath() string {
	return filepath.Join(sys.baseDir, "save", "logs", "heartbeat.log")
}

var iosHeartbeatFile *os.File
var iosHeartbeatStart = time.Now()
var iosHeartbeatLast = time.Now()
var iosHeartbeatTicks int64

// iosHeartbeat periodically (about once a second) appends a line recording the
// true process memory footprint (RSS via mach task_info), the Go heap stats,
// and how far the main game loop has progressed. It fsyncs before closing so
// the data survives a SIGKILL. This lets us distinguish a Jetsam (memory) kill
// from a watchdog (main-thread hang) kill: if the last heartbeat is within ~1s
// of death with memory climbing, it's memory; if it stops well before death,
// the main loop hung.
func iosHeartbeat() {
	now := time.Now()
	if now.Sub(iosHeartbeatLast) < time.Second {
		return
	}
	iosHeartbeatLast = now
	iosHeartbeatTicks++

	if iosHeartbeatFile == nil {
		dir := filepath.Dir(iosHeartbeatLogPath())
		os.MkdirAll(dir, 0755)
		f, err := os.OpenFile(iosHeartbeatLogPath(), os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0644)
		if err != nil {
			return
		}
		iosHeartbeatFile = f
	}

	var ms runtime.MemStats
	runtime.ReadMemStats(&ms)
	rss := int64(C.iosResidentBytes())

	elapsed := now.Sub(iosHeartbeatStart)
	line := fmt.Sprintf("t=%7.1fs ticks=%d RSS=%dMB GoSys=%dMB GoHeapInuse=%dMB GoHeapObjects=%d goroutines=%d\n",
		elapsed.Seconds(), iosHeartbeatTicks,
		rss/(1024*1024), ms.Sys/(1024*1024), ms.HeapInuse/(1024*1024),
		ms.HeapObjects, runtime.NumGoroutine())

	if f := iosHeartbeatFile; f != nil {
		f.WriteString(line)
		f.Sync()
	}

	// Periodically dump a Go heap profile so we can pinpoint exactly which types
	// accumulate during a fight (analyze with: go tool pprof <file>.pprof).
	if iosHeartbeatTicks%15 == 0 {
		fn := filepath.Join(filepath.Dir(iosHeartbeatLogPath()),
			fmt.Sprintf("heap_%04d.pprof", iosHeartbeatTicks))
		if pf, err := os.Create(fn); err == nil {
			_ = pprof.Lookup("heap").WriteTo(pf, 0)
			pf.Close()
		}
	}

	// Safety net: Go grows its heap arena but rarely returns freed memory to the
	// OS, so RSS can stay dangerously high even after large assets are dropped
	// (e.g. tag-out SND unloads when no partner swap frees anything on our side).
	// Every ~30s, if the live heap is well below the arena, force a GC and hand
	// the unused memory back to iOS. Keep it rare to avoid stop-the-world stutter.
	if iosHeartbeatTicks%30 == 0 {
		if ms.HeapAlloc < ms.HeapSys-(100*1024*1024) {
			runtime.GC()
			debug.FreeOSMemory()
		}
	}
}
