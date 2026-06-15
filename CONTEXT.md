# ShibaStack

Domain language for ShibaStack (Apple Private Container) — a macOS suite that runs OCI containers on Apple Silicon via Apple's Virtualization framework, with user-space DNS and a reverse proxy so containers are reachable at friendly local domains.

## Containers & routing

**Container**:
A running or stopped OCI workload managed on the host. Owns its published ports and derives its own developer-facing domains.
_Avoid_: instance, workload, box.

**Host port**:
The host side of a published-port mapping (`"8081:80"` → `8081`) — the port a developer actually reaches. The guest side is internal.
_Avoid_: external port, public port.

**Primary domain**:
A container's bare `*.apc.local` address, `<name>.apc.local`, owned by its first published port. Later ports get suffixed `<name>-<hostPort>.apc.local` domains.
_Avoid_: hostname, vhost, FQDN.

**Routing registry**:
The single owner of host→port resolution backing `routing.json`: the reverse proxy reads it, the container layer writes it. Lookup and the loop guard live behind its interface.
_Avoid_: routing table, route map, registry (bare).

## Runtime seams

**Container engine**:
The seam between container mapping logic and the host runtime. The production adapter shells out to the native `container` binary; a fake adapter feeds canned output to tests.
_Avoid_: backend, driver, CLI wrapper.

**Guest daemon**:
The Go process (`guest-vminitd`) running inside the Alpine guest that receives commands and streams output back to the host.
_Avoid_: agent, init, vminitd (bare).

**Guest command**:
A single exec request sent to the guest daemon, and its response. One wire contract owns the shape across the Swift host and the Go guest.
_Avoid_: message, payload, RPC.

**Guest transport**:
The seam carrying guest commands. The production adapter uses VSOCK; a loopback adapter over local TCP serves tests and CI where real virtualization is unavailable.
_Avoid_: channel, connection, socket.
