package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os/exec"
	"strings"
)

// Command represents an incoming execution command over VSOCK.
//
// This is the Go owner of the host/guest wire contract. Its Swift counterpart is
// GuestCommand/GuestResponse in apc-core/Sources/APCCore/GuestProtocol.swift —
// field names and the newline-delimited-JSON framing must stay in sync.
type Command struct {
	Action string   `json:"action"` // "run", "stop", "ps", "exec"
	Name   string   `json:"name,omitempty"`
	Image  string   `json:"image,omitempty"`
	Cmd    []string `json:"cmd,omitempty"`
}

// Response represents a structured stdout/stderr reply back to the host.
type Response struct {
	Success bool   `json:"success"`
	Output  string `json:"output,omitempty"`
	Error   string `json:"error,omitempty"`
}

func main() {
	log.Println("--------------------------------------------------")
	log.Println("ShibaStack Guest Agent Daemon (vminitd) Starting...")
	log.Println("--------------------------------------------------")

	// Start VSOCK/TCP Connection Loop
	runAgent()
}

func handleHostChannel(conn net.Conn) {
	defer conn.Close()
	reader := bufio.NewReader(conn)
	for {
		line, err := reader.ReadString('\n')
		if err != nil {
			log.Printf("[vminitd] Disconnected from host channel: %v. Reconnecting...", err)
			return
		}

		line = strings.TrimSpace(line)
		if line == "" {
			continue
		}

		log.Printf("[vminitd] Received raw command payload: %s", line)
		var cmd Command
		if err := json.Unmarshal([]byte(line), &cmd); err != nil {
			sendError(conn, "Invalid command JSON syntax: "+err.Error())
			continue
		}

		dispatchCommand(conn, cmd)
	}
}

func dispatchCommand(conn net.Conn, cmd Command) {
	var resp Response
	switch strings.ToLower(cmd.Action) {
	case "run":
		log.Printf("[vminitd] [OCI Spine] Instantiating container '%s' from image '%s'...", cmd.Name, cmd.Image)
		execCmd := exec.Command("/usr/local/bin/container", "run", "-d", "--name", cmd.Name, cmd.Image)
		out, err := execCmd.CombinedOutput()
		if err != nil {
			resp = Response{
				Success: false,
				Error:   fmt.Sprintf("Failed to run container: %v (Output: %s)", err, string(out)),
			}
		} else {
			resp = Response{
				Success: true,
				Output:  fmt.Sprintf("Container %s successfully provisioned and launched in OCI namespaces.", cmd.Name),
			}
		}

	case "exec":
		if cmd.Name == "" {
			resp = Response{
				Success: false,
				Error:   "Command execution requires a targeted container name.",
			}
			break
		}
		shellCmd := strings.Join(cmd.Cmd, " ")
		log.Printf("[vminitd] [OCI Spine] Executing shell command inside container '%s': %s", cmd.Name, shellCmd)

		// Run command strictly inside the targeted secure container context to eliminate host RCE vulnerabilities
		execCmd := exec.Command("/usr/local/bin/container", "exec", cmd.Name, "sh", "-c", shellCmd)
		out, err := execCmd.CombinedOutput()
		if err != nil {
			if len(out) > 0 {
				resp = Response{
					Success: true,
					Output:  string(out),
				}
			} else {
				resp = Response{
					Success: false,
					Error:   err.Error() + ": " + string(out),
				}
			}
		} else {
			resp = Response{
				Success: true,
				Output:  string(out),
			}
		}

	case "ps":
		log.Println("[vminitd] [OCI Spine] Fetching container lists from engine...")
		execCmd := exec.Command("/usr/local/bin/container", "list", "--format", "json")
		out, err := execCmd.CombinedOutput()
		if err != nil {
			resp = Response{
				Success: false,
				Error:   err.Error(),
			}
		} else {
			resp = Response{
				Success: true,
				Output:  string(out),
			}
		}

	default:
		resp = Response{
			Success: false,
			Error:   fmt.Sprintf("Command action '%s' not supported by guest execution spine yet.", cmd.Action),
		}
	}

	data, _ := json.Marshal(resp)
	_, _ = conn.Write(append(data, '\n'))
}

func sendError(conn net.Conn, errMsg string) {
	resp := Response{Success: false, Error: errMsg}
	data, _ := json.Marshal(resp)
	_, _ = conn.Write(append(data, '\n'))
}
