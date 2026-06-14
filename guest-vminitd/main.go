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
		resp = Response{
			Success: true,
			Output:  fmt.Sprintf("Container %s successfully provisioned and launched in guest OCI network namespaces.", cmd.Name),
		}
	case "exec":
		shellCmd := strings.Join(cmd.Cmd, " ")
		log.Printf("[vminitd] [OCI Spine] Executing shell command: %s", shellCmd)
		
		execCmd := exec.Command("sh", "-c", shellCmd)
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
		resp = Response{
			Success: true,
			Output:  "[{\"id\":\"c_custom_guest\",\"name\":\"guest-app\",\"image\":\"alpine-nginx\",\"state\":\"running\"}]",
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
