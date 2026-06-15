package main

import (
	"encoding/json"
	"log"
	"os"
	"strings"
	"sync"
	"time"
)

// Config is the on-disk schema of routing.json — the single Go owner of that
// shape. Its Swift counterpart is RoutingConfig in apc-core (Models.swift): the
// container layer writes the file, this registry reads it.
type Config struct {
	Routes map[string]int `json:"routes"` // host (e.g. "web.apc.local") -> host port
}

// RoutingRegistry owns host -> host-port resolution for the reverse proxy.
//
// It is the single reader of routing.json and the home of the loop guard, so the
// proxy asks it rather than touching a shared map. Lookup and loop detection sit
// behind its small interface; reloads are concurrency-safe and never block a
// lookup on file I/O.
type RoutingRegistry struct {
	mu        sync.RWMutex
	routes    map[string]int
	path      string
	proxyPort int
}

func NewRoutingRegistry(path string) *RoutingRegistry {
	return &RoutingRegistry{routes: map[string]int{}, path: path, proxyPort: 8080}
}

// Lookup resolves a request Host (with optional ":port" suffix) to a target host port.
func (r *RoutingRegistry) Lookup(host string) (int, bool) {
	if idx := strings.Index(host, ":"); idx != -1 {
		host = host[:idx]
	}
	r.mu.RLock()
	defer r.mu.RUnlock()
	port, ok := r.routes[host]
	return port, ok
}

// WouldLoop reports whether routing this host points back at the proxy's own
// listener — the one-hop loopback case the 508 guard rejects.
func (r *RoutingRegistry) WouldLoop(host string) bool {
	port, ok := r.Lookup(host)
	return ok && port == r.ProxyPort()
}

// SetProxyPort records the port the proxy actually bound to, so WouldLoop can
// recognise routes that resolve straight back to it.
func (r *RoutingRegistry) SetProxyPort(port int) {
	r.mu.Lock()
	r.proxyPort = port
	r.mu.Unlock()
}

func (r *RoutingRegistry) ProxyPort() int {
	r.mu.RLock()
	defer r.mu.RUnlock()
	return r.proxyPort
}

// Load (re)reads the config file into the table, creating a default file if it is
// absent. Decoding happens before the write lock so slow I/O never blocks lookups.
func (r *RoutingRegistry) Load() {
	file, err := os.Open(r.path)
	if err != nil {
		if os.IsNotExist(err) {
			defaultCfg := Config{Routes: map[string]int{"demo.apc.local": 8080}}
			data, _ := json.MarshalIndent(defaultCfg, "", "  ")
			_ = os.WriteFile(r.path, data, 0644)
			r.replace(defaultCfg.Routes)
			return
		}
		log.Printf("Error reading config file: %v", err)
		return
	}
	defer file.Close()

	var cfg Config
	if err := json.NewDecoder(file).Decode(&cfg); err != nil {
		log.Printf("Error decoding config JSON: %v", err)
		return
	}
	r.replace(cfg.Routes)
	log.Printf("Loaded routes: %v", cfg.Routes)
}

func (r *RoutingRegistry) replace(routes map[string]int) {
	if routes == nil {
		routes = map[string]int{}
	}
	r.mu.Lock()
	r.routes = routes
	r.mu.Unlock()
}

// Watch polls the config file and reloads the table on modification.
func (r *RoutingRegistry) Watch() {
	var lastModTime time.Time
	for {
		time.Sleep(1 * time.Second)
		info, err := os.Stat(r.path)
		if err != nil {
			continue
		}
		if info.ModTime().After(lastModTime) {
			lastModTime = info.ModTime()
			r.Load()
		}
	}
}
