//go:build linux
package main

import (
	"log"
	"net"
	"os"
	"syscall"
	"time"
	"unsafe"
)

// SockaddrVM is standard Go/syscall representation for sockaddr_vm
type SockaddrVM struct {
	Family    uint16
	Reserved1 uint16
	Port      uint32
	CID       uint32
	Zero      [4]byte
}

func (sa *SockaddrVM) sockaddr() (unsafe.Pointer, int, error) {
	return unsafe.Pointer(sa), 16, nil
}

func runAgent() {
	log.Println("[vminitd] Operating on native Guest Linux. Establishing real AF_VSOCK bridge to host...")

	for {
		fd, err := syscall.Socket(40, syscall.SOCK_STREAM, 0) // 40 = AF_VSOCK
		if err != nil {
			log.Printf("[vminitd] Failed to create VSOCK socket: %v. Retrying in 5s...", err)
			time.Sleep(5 * time.Second)
			continue
		}

		sa := &SockaddrVM{
			Family: 40, // AF_VSOCK
			Port:   1024,
			CID:    2, // VMADDR_CID_HOST
		}

		// Connect using raw syscall
		_, _, errno := syscall.Syscall(syscall.SYS_CONNECT, uintptr(fd), uintptr(unsafe.Pointer(sa)), 16)
		if errno != 0 {
			syscall.Close(fd)
			log.Printf("[vminitd] Waiting for ShibaStack host VSOCK on port 1024: %v. Retrying in 5s...", errno)
			time.Sleep(5 * time.Second)
			continue
		}

		log.Println("[vminitd] Connected to Host via real VSOCK channel!")
		
		file := os.NewFile(uintptr(fd), "vsock")
		conn, err := net.FileConn(file)
		if err != nil {
			file.Close()
			syscall.Close(fd)
			log.Printf("[vminitd] Failed to wrap VSOCK file descriptor: %v", err)
			time.Sleep(5 * time.Second)
			continue
		}

		handleHostChannel(conn)
		conn.Close()
		file.Close()
	}
}
