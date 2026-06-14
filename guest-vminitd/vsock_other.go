//go:build !linux
package main

import (
	"log"
	"net"
	"time"
)

func runAgent() {
	log.Println("[vminitd] Operating on macOS / Other (Local Dev). Establishing localhost mock loop tunnel...")
	
	addr := "127.0.0.1:10124"
	for {
		conn, err := net.Dial("tcp", addr)
		if err != nil {
			log.Printf("[vminitd] Waiting for ShibaStack host daemon loop on %s: %v. Retrying in 5s...", addr, err)
			time.Sleep(5 * time.Second)
			continue
		}

		log.Printf("[vminitd] Handshake successful! Connected to mock host tunnel on %s", addr)
		handleHostChannel(conn)
	}
}
