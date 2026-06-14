package main

import (
	"encoding/json"
	"fmt"
	"log"
	"net"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

// Config represents the dynamic routing configuration.
type Config struct {
	Routes map[string]int `json:"routes"` // Map of host (e.g., "web-app.apc.local") to port (e.g., 8080)
}

var (
	configPath string
	routes     = make(map[string]int)
	routesMu   sync.RWMutex
)

func init() {
	home, err := os.UserHomeDir()
	if err != nil {
		home = "/tmp"
	}
	configDir := filepath.Join(home, ".apc")
	_ = os.MkdirAll(configDir, 0755)
	configPath = filepath.Join(configDir, "routing.json")
}

func main() {
	log.Println("Starting APC Network & DNS Resolver...")

	// Load initial routes and start config watcher
	loadRoutes()
	go watchConfig()

	// Start DNS Server (UDP port 15353)
	go startDNSServer()

	// Start HTTP Reverse Proxy (TCP port 8080 with attempt on 80)
	startHTTPProxy()
}

func loadRoutes() {
	routesMu.Lock()
	defer routesMu.Unlock()

	file, err := os.Open(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			// Write default empty configuration
			defaultCfg := Config{Routes: map[string]int{
				"demo.apc.local": 8080,
			}}
			data, _ := json.MarshalIndent(defaultCfg, "", "  ")
			_ = os.WriteFile(configPath, data, 0644)
			routes = defaultCfg.Routes
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

	routes = cfg.Routes
	log.Printf("Loaded routes: %v", routes)
}

func watchConfig() {
	for {
		time.Sleep(2 * time.Second)
		loadRoutes()
	}
}

func getTargetPort(host string) (int, bool) {
	routesMu.RLock()
	defer routesMu.RUnlock()

	// Strip port from host if present
	if idx := strings.Index(host, ":"); idx != -1 {
		host = host[:idx]
	}

	port, exists := routes[host]
	return port, exists
}

// startDNSServer runs a lightweight, zero-dependency DNS server resolving all *.apc.local to 127.0.0.1.
func startDNSServer() {
	addr, err := net.ResolveUDPAddr("udp", "127.0.0.1:15353")
	if err != nil {
		log.Fatalf("Failed to resolve UDP address: %v", err)
	}

	conn, err := net.ListenUDP("udp", addr)
	if err != nil {
		log.Fatalf("Failed to listen on UDP 127.0.0.1:15353: %v", err)
	}
	defer conn.Close()

	log.Println("DNS Server listening on 127.0.0.1:15353 (resolving *.apc.local)")

	buf := make([]byte, 512)
	for {
		n, raddr, err := conn.ReadFromUDP(buf)
		if err != nil {
			log.Printf("DNS Read error: %v", err)
			continue
		}

		if n < 12 {
			continue // Invalid packet
		}

		// Basic DNS validation and parsing
		// TxID: buf[0:2]
		// Flags: buf[2:4]
		// Questions: buf[4:6]
		qdCount := int(buf[4])<<8 | int(buf[5])
		if qdCount == 0 {
			continue
		}

		// Simple parsing of the queried domain name
		domainParts := []string{}
		offset := 12
		for offset < n {
			length := int(buf[offset])
			if length == 0 {
				offset++
				break
			}
			if offset+1+length > n {
				break
			}
			domainParts = append(domainParts, string(buf[offset+1:offset+1+length]))
			offset += 1 + length
		}

		domain := strings.Join(domainParts, ".")
		if !strings.HasSuffix(domain, "apc.local") {
			continue // Only answer for *.apc.local
		}

		// Construct DNS Response packet
		response := make([]byte, 0, 512)
		// Tx ID
		response = append(response, buf[0:2]...)
		// Standard Response Flags: Response, No error (0x8180)
		response = append(response, 0x81, 0x80)
		// Questions Count (1)
		response = append(response, 0x00, 0x01)
		// Answer Count (1)
		response = append(response, 0x00, 0x01)
		// Authority RRs, Additional RRs (0)
		response = append(response, 0x00, 0x00, 0x00, 0x00)

		// Copy Question Section
		questionLen := offset - 12
		// Question type & class (4 bytes at the end of the question section)
		if offset+4 <= n {
			questionLen += 4
		}
		response = append(response, buf[12:12+questionLen]...)

		// Append Answer Section (A Record pointing to 127.0.0.1)
		// Name pointer (offset pointing to the name in the question section, usually 0xc00c)
		response = append(response, 0xc, 0x0c)
		// Type A (0x0001), Class IN (0x0001)
		response = append(response, 0x00, 0x01, 0x00, 0x01)
		// TTL (30 seconds)
		response = append(response, 0x00, 0x00, 0x00, 0x1e)
		// Data Length (4 bytes for IPv4)
		response = append(response, 0x00, 0x04)
		// IP: 127.0.0.1
		response = append(response, 127, 0, 0, 1)

		_, err = conn.WriteToUDP(response, raddr)
		if err != nil {
			log.Printf("DNS Write error: %v", err)
		}
	}
}

// startHTTPProxy runs an HTTP reverse proxy that routes requests based on the Host header.
func startHTTPProxy() {
	proxy := &httputil.ReverseProxy{
		Director: func(req *http.Request) {
			host := req.Host
			port, found := getTargetPort(host)
			if !found {
				// Default fallback port if route is unknown
				port = 8080
			}

			targetURL, err := url.Parse(fmt.Sprintf("http://127.0.0.1:%d", port))
			if err != nil {
				log.Printf("Error parsing target URL: %v", err)
				return
			}

			req.URL.Scheme = targetURL.Scheme
			req.URL.Host = targetURL.Host
			req.URL.Path = singleJoiningSlash(targetURL.Path, req.URL.Path)
			if targetURL.RawQuery == "" || req.URL.RawQuery == "" {
				req.URL.RawQuery = targetURL.RawQuery + req.URL.RawQuery
			} else {
				req.URL.RawQuery = targetURL.RawQuery + "&" + req.URL.RawQuery
			}
			req.Header.Set("X-Forwarded-Host", host)
		},
		ErrorHandler: func(w http.ResponseWriter, r *http.Request, err error) {
			w.WriteHeader(http.StatusBadGateway)
			fmt.Fprintf(w, "APC Proxy Gateway Error: Could not route request to container for host %q. Error: %v\n", r.Host, err)
		},
	}

	// Try running on port 80 (standard HTTP).
	// If it fails (due to lack of root/sudo), fall back to port 8080.
	serverAddr := "127.0.0.1:80"
	log.Printf("Attempting to start HTTP Reverse Proxy on %s...", serverAddr)
	listener, err := net.Listen("tcp", serverAddr)
	if err != nil {
		log.Printf("Could not bind to port 80 (usually requires sudo/root). Falling back to 127.0.0.1:8080. Error: %v", err)
		serverAddr = "127.0.0.1:8080"
		listener, err = net.Listen("tcp", serverAddr)
		if err != nil {
			log.Fatalf("Failed to listen on backup port 127.0.0.1:8080: %v", err)
		}
	}

	log.Printf("HTTP Reverse Proxy successfully listening on %s", serverAddr)
	server := &http.Server{
		Handler: proxy,
	}
	if err := server.Serve(listener); err != nil {
		log.Fatalf("HTTP Proxy server failed: %v", err)
	}
}

func singleJoiningSlash(a, b string) string {
	aslash := strings.HasSuffix(a, "/")
	bslash := strings.HasPrefix(b, "/")
	switch {
	case aslash && bslash:
		return a + b[1:]
	case !aslash && !bslash:
		return a + "/" + b
	}
	return a + b
}
