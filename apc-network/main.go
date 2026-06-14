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
	"os/exec"
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
	configPath      string
	routes          = make(map[string]int)
	routesMu        sync.RWMutex
	activeProxyPort = 8080 // Guard proxy port to prevent loopback routing loops

	// Pool of UDP receive buffers to eliminate allocations during DNS packet reads
	dnsBufPool = sync.Pool{
		New: func() interface{} {
			return make([]byte, 512)
		},
	}
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

	// Start Docker CLI Bridge (UNIX socket)
	go startDockerBridge()

	// Start HTTP Reverse Proxy (TCP port 8080 with attempt on 80)
	startHTTPProxy()
}

// loadRoutes decodes the config file OUTSIDE the read/write lock to prevent
// blocking active reverse proxy queries with slow file I/O operations.
func loadRoutes() {
	file, err := os.Open(configPath)
	if err != nil {
		if os.IsNotExist(err) {
			// Write default empty configuration
			defaultCfg := Config{Routes: map[string]int{
				"demo.apc.local": 8080,
			}}
			data, _ := json.MarshalIndent(defaultCfg, "", "  ")
			_ = os.WriteFile(configPath, data, 0644)

			routesMu.Lock()
			routes = defaultCfg.Routes
			routesMu.Unlock()
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

	routesMu.Lock()
	routes = cfg.Routes
	routesMu.Unlock()
	log.Printf("Loaded routes: %v", routes)
}

func watchConfig() {
	var lastModTime time.Time
	for {
		time.Sleep(1 * time.Second)
		info, err := os.Stat(configPath)
		if err != nil {
			continue
		}
		if info.ModTime().After(lastModTime) {
			lastModTime = info.ModTime()
			loadRoutes()
		}
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

// startDNSServer runs a concurrent, zero-dependency DNS server resolving all *.apc.local to 127.0.0.1.
func startDNSServer() {
	addr, err := net.ResolveUDPAddr("udp", "127.0.0.1:15353")
	if err != nil {
		log.Printf("Failed to resolve UDP address 127.0.0.1:15353: %v", err)
		return
	}

	var conn *net.UDPConn
	for {
		conn, err = net.ListenUDP("udp", addr)
		if err == nil {
			break
		}
		log.Printf("WARNING: Failed to listen on UDP 127.0.0.1:15353 (DNS port conflict?): %v. Retrying in 10s...", err)
		time.Sleep(10 * time.Second)
	}
	defer conn.Close()

	log.Println("DNS Server listening on 127.0.0.1:15353 (resolving *.apc.local)")

	for {
		// Acquire a byte slice from the pool to avoid heap allocations
		buf := dnsBufPool.Get().([]byte)
		// Reset boundary
		b := buf[:512]

		n, raddr, err := conn.ReadFromUDP(b)
		if err != nil {
			dnsBufPool.Put(buf)
			if strings.Contains(err.Error(), "use of closed network connection") {
				break
			}
			log.Printf("DNS Read error: %v", err)
			continue
		}

		// Spawn concurrent goroutine to parse the DNS query and send response.
		// Hand off raw buffer and length safely.
		go handleDNSQuery(conn, buf, n, raddr)
	}
}

// handleDNSQuery parses and responds to incoming DNS queries ending in "apc.local" on a pooled buffer.
func handleDNSQuery(conn *net.UDPConn, buf []byte, n int, raddr *net.UDPAddr) {
	defer dnsBufPool.Put(buf)

	if n < 12 {
		return // Invalid packet length
	}

	// Basic DNS validation and parsing
	// TxID: buf[0:2]
	// Flags: buf[2:4]
	// Questions: buf[4:6]
	qdCount := int(buf[4])<<8 | int(buf[5])
	if qdCount == 0 {
		return
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
		return // Only answer for *.apc.local
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
	response = append(response, 0xc0, 0x0c)
	// Type A (0x0001), Class IN (0x0001)
	response = append(response, 0x00, 0x01, 0x00, 0x01)
	// TTL (30 seconds)
	response = append(response, 0x00, 0x00, 0x00, 0x1e)
	// Data Length (4 bytes for IPv4)
	response = append(response, 0x00, 0x04)
	// IP: 127.0.0.1
	response = append(response, 127, 0, 0, 1)

	_, err := conn.WriteToUDP(response, raddr)
	if err != nil {
		log.Printf("DNS Write error: %v", err)
	}
}

// startHTTPProxy runs an HTTP reverse proxy that routes requests based on the Host header.
func startHTTPProxy() {
	// Custom optimized transport to avoid default connection limit bottleneck (2 idle connections/host)
	customTransport := &http.Transport{
		Proxy: http.ProxyFromEnvironment,
		DialContext: (&net.Dialer{
			Timeout:   10 * time.Second, // Timeout to connect to the backend container
			KeepAlive: 30 * time.Second, // TCP keep-alives on the backend socket
		}).DialContext,
		ForceAttemptHTTP2:     true,
		MaxIdleConns:          1000,
		MaxIdleConnsPerHost:   100, // Crucial performance fix for high-throughput container networking
		IdleConnTimeout:       90 * time.Second,
		TLSHandshakeTimeout:   10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}

	proxy := &httputil.ReverseProxy{
		Transport: customTransport,
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

	var listener net.Listener
	for {
		var err error
		listener, err = net.Listen("tcp", serverAddr)
		if err == nil {
			break
		}

		if serverAddr == "127.0.0.1:80" {
			log.Printf("Could not bind to port 80 (usually requires sudo/root). Falling back to 127.0.0.1:8080. Error: %v", err)
			serverAddr = "127.0.0.1:8080"
			continue
		}

		log.Printf("WARNING: Failed to listen on backup port %s (port conflict?): %v. Retrying in 10s...", serverAddr, err)
		time.Sleep(10 * time.Second)
	}

	if strings.HasSuffix(serverAddr, ":80") {
		activeProxyPort = 80
	} else {
		activeProxyPort = 8080
	}

	log.Printf("HTTP Reverse Proxy successfully listening on %s (Loop Guard Active)", serverAddr)

	// Wrap proxy with a loop detection handler
	proxyHandler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		host := r.Host
		port, found := getTargetPort(host)
		if found && port == activeProxyPort {
			w.WriteHeader(http.StatusLoopDetected) // 508 Loop Detected
			fmt.Fprintf(w, "APC Proxy Gateway Error: Loopback routing loop detected. Host %q maps directly to proxy listening port %d.\n", host, port)
			return
		}

		// Multi-hop routing loop guard using custom headers
		hopStr := r.Header.Get("X-APC-Forwarded-Hops")
		hops := 0
		if hopStr != "" {
			fmt.Sscanf(hopStr, "%d", &hops)
		}
		if hops >= 10 {
			w.WriteHeader(http.StatusLoopDetected) // 508 Loop Detected
			fmt.Fprintf(w, "APC Proxy Gateway Error: Maximum forwarding hops (10) exceeded. Possible routing loop among guest containers.\n")
			return
		}
		r.Header.Set("X-APC-Forwarded-Hops", fmt.Sprintf("%d", hops+1))

		proxy.ServeHTTP(w, r)
	})

	// Explicit server timeouts configured to prevent resource leak and Slowloris vulnerability vectors
	server := &http.Server{
		Handler:           proxyHandler,
		ReadHeaderTimeout: 10 * time.Second,  // Stop Slowloris header starvation
		ReadTimeout:       30 * time.Second,  // Keep overall socket duration bounded
		WriteTimeout:      30 * time.Second,  // Keep overall write duration bounded
		IdleTimeout:       120 * time.Second, // Manage keep-alive sockets carefully
	}
	if err := server.Serve(listener); err != nil {
		log.Fatalf("HTTP Proxy server failed to serve: %v", err)
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

// MARK: - Docker CLI Socket Bridge & Translation API

type DockerPort struct {
	IP          string `json:"IP,omitempty"`
	PrivatePort int    `json:"PrivatePort"`
	PublicPort  int    `json:"PublicPort,omitempty"`
	Type        string `json:"Type"`
}

type DockerContainer struct {
	ID     string       `json:"Id"`
	Names  []string     `json:"Names"`
	Image  string       `json:"Image"`
	State  string       `json:"State"`
	Status string       `json:"Status"`
	Ports  []DockerPort `json:"Ports"`
}

type DockerImage struct {
	ID          string   `json:"Id"`
	RepoTags    []string `json:"RepoTags"`
	Size        int64    `json:"Size"`
	VirtualSize int64    `json:"VirtualSize"`
}

func startDockerBridge() {
	home, err := os.UserHomeDir()
	if err != nil {
		log.Printf("Error getting user home dir: %v", err)
		return
	}
	sockPath := filepath.Join(home, ".apc", "docker.sock")

	// Ensure old socket is cleanly removed
	_ = os.Remove(sockPath)

	listener, err := net.Listen("unix", sockPath)
	if err != nil {
		log.Printf("[docker-bridge] Failed to listen on Unix socket %s: %v", sockPath, err)
		return
	}
	defer listener.Close()

	log.Printf("[docker-bridge] Server listening on UNIX socket: unix://%s", sockPath)

	mux := http.NewServeMux()

	// Implement Standard Docker Client Handshake and Ping endpoints
	mux.HandleFunc("/_ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.Header().Set("Cache-Control", "no-cache")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("OK"))
	})

	mux.HandleFunc("/v1.43/_ping", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		w.Header().Set("Cache-Control", "no-cache")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("OK"))
	})

	// Catch-all Docker API versioning gateway
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		path := r.URL.Path
		log.Printf("[docker-bridge] HTTP API Query: %s %s", r.Method, path)

		if strings.HasSuffix(path, "/_ping") {
			w.Header().Set("Content-Type", "text/plain")
			w.WriteHeader(http.StatusOK)
			_, _ = w.Write([]byte("OK"))
			return
		}

		if strings.HasSuffix(path, "/containers/json") {
			handleContainersJSON(w, r)
			return
		}

		if strings.HasSuffix(path, "/images/json") {
			handleImagesJSON(w, r)
			return
		}

		// Fallback empty array to avoid Docker client crash/block
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("[]"))
	})

	server := &http.Server{
		Handler: mux,
	}

	if err := server.Serve(listener); err != nil {
		log.Printf("[docker-bridge] Server terminated: %v", err)
	}
}

func handleContainersJSON(w http.ResponseWriter, r *http.Request) {
	cmd := exec.Command("/usr/local/bin/container", "list", "--all", "--format", "json")
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("[docker-bridge] Failed to list containers: %v (Output: %s)", err, string(out))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("[]"))
		return
	}

	type CLIContainerListItem struct {
		Status        string `json:"status"`
		Configuration struct {
			ID    string `json:"id"`
			Image struct {
				Reference string `json:"reference"`
			} `json:"image"`
			PublishedPorts []struct {
				HostPort      int `json:"hostPort"`
				ContainerPort int `json:"containerPort"`
			} `json:"publishedPorts"`
		} `json:"configuration"`
	}

	var list []CLIContainerListItem
	if err := json.Unmarshal(out, &list); err != nil {
		log.Printf("[docker-bridge] Failed to unmarshal CLI containers list: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("[]"))
		return
	}

	dockerConts := make([]DockerContainer, 0, len(list))
	for _, c := range list {
		dockerPorts := []DockerPort{}
		for _, p := range c.Configuration.PublishedPorts {
			dockerPorts = append(dockerPorts, DockerPort{
				IP:          "0.0.0.0",
				PrivatePort: p.ContainerPort,
				PublicPort:  p.HostPort,
				Type:        "tcp",
			})
		}

		statusStr := "Stopped"
		if strings.ToLower(c.Status) == "running" {
			statusStr = "Up 15 minutes"
		}

		displayImage := c.Configuration.Image.Reference
		if strings.HasPrefix(displayImage, "docker.io/library/") {
			displayImage = strings.TrimPrefix(displayImage, "docker.io/library/")
		} else if strings.HasPrefix(displayImage, "docker.io/") {
			displayImage = strings.TrimPrefix(displayImage, "docker.io/")
		}

		dockerConts = append(dockerConts, DockerContainer{
			ID:     c.Configuration.ID,
			Names:  []string{"/" + c.Configuration.ID},
			Image:  displayImage,
			State:  strings.ToLower(c.Status),
			Status: statusStr,
			Ports:  dockerPorts,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(dockerConts)
}

func handleImagesJSON(w http.ResponseWriter, r *http.Request) {
	cmd := exec.Command("/usr/local/bin/container", "image", "list", "--format", "json")
	out, err := cmd.CombinedOutput()
	if err != nil {
		log.Printf("[docker-bridge] Failed to list images: %v (Output: %s)", err, string(out))
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("[]"))
		return
	}

	type CLIImageListItem struct {
		Reference  string `json:"reference"`
		Descriptor struct {
			Size int64 `json:"size"`
		} `json:"descriptor"`
	}

	var list []CLIImageListItem
	if err := json.Unmarshal(out, &list); err != nil {
		log.Printf("[docker-bridge] Failed to unmarshal CLI images list: %v", err)
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("[]"))
		return
	}

	dockerImgs := make([]DockerImage, 0, len(list))
	for _, img := range list {
		displayImage := img.Reference
		if strings.HasPrefix(displayImage, "docker.io/library/") {
			displayImage = strings.TrimPrefix(displayImage, "docker.io/library/")
		} else if strings.HasPrefix(displayImage, "docker.io/") {
			displayImage = strings.TrimPrefix(displayImage, "docker.io/")
		}

		dockerImgs = append(dockerImgs, DockerImage{
			ID:          img.Reference,
			RepoTags:    []string{displayImage},
			Size:        img.Descriptor.Size,
			VirtualSize: img.Descriptor.Size,
		})
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(dockerImgs)
}

func parseSizeToBytes(sizeStr string) int64 {
	var val float64
	var unit string
	_, err := fmt.Sscanf(sizeStr, "%f %s", &val, &unit)
	if err != nil {
		return 10 * 1024 * 1024
	}
	switch strings.ToUpper(unit) {
	case "KB":
		return int64(val * 1024)
	case "MB":
		return int64(val * 1024 * 1024)
	case "GB":
		return int64(val * 1024 * 1024 * 1024)
	default:
		return int64(val)
	}
}
