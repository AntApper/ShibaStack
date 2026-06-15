package main

import (
	"os"
	"path/filepath"
	"testing"
)

func TestLookupStripsPortSuffix(t *testing.T) {
	r := NewRoutingRegistry("")
	r.replace(map[string]int{"web.apc.local": 8081})

	if port, ok := r.Lookup("web.apc.local:8080"); !ok || port != 8081 {
		t.Fatalf("Lookup with port suffix = (%d, %v), want (8081, true)", port, ok)
	}
	if _, ok := r.Lookup("missing.apc.local"); ok {
		t.Fatalf("Lookup of unknown host should report not-found")
	}
}

func TestWouldLoopDetectsProxyPort(t *testing.T) {
	r := NewRoutingRegistry("")
	r.SetProxyPort(8080)
	r.replace(map[string]int{"loop.apc.local": 8080, "ok.apc.local": 9000})

	if !r.WouldLoop("loop.apc.local") {
		t.Fatalf("a route to the proxy's own port should loop")
	}
	if r.WouldLoop("ok.apc.local") {
		t.Fatalf("a route to a real backend should not loop")
	}
}

func TestLoadCreatesDefaultWhenMissing(t *testing.T) {
	path := filepath.Join(t.TempDir(), "routing.json")
	r := NewRoutingRegistry(path)
	r.Load()

	if _, err := os.Stat(path); err != nil {
		t.Fatalf("Load should create a default config file: %v", err)
	}
	if port, ok := r.Lookup("demo.apc.local"); !ok || port != 8080 {
		t.Fatalf("default route missing: (%d, %v)", port, ok)
	}
}
