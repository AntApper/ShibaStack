# Oracle Steering Checkpoint — Loop 5 / 100

**Date:** 2026-06-14
**Auditor:** oracle (decision-consistency subagent, fresh fork)
**Scope:** Loops 1–5 (uncommitted working tree). Audit of git diff, real builds, and test reality vs. OrbStack parity goal.

---

## TL;DR

Loops 1–5 produced solid, real scaffolding (Rosetta share, VSOCK device, memory-balloon pressure monitoring, USB null-guards, Go watcher optimization, a much richer GUI). **But the current working tree does not compile**, the loop's "all tests passed" claims were validated against **stale pre-built binaries**, and the program's core — actually running containers — **remains entirely simulated**. Fix the build immediately, harden the verification ritual, then make a deliberate decision about whether this project is pursuing *real* OrbStack parity or a high-fidelity *demo*. The remaining checklist currently assumes the former but is building the latter.

---

## P0 — BLOCKING: the build is broken right now

`apc-core/Sources/APCCore/VSOCKManager.swift:70` — `connectToGuest(...)` calls the VSOCK connect API with a two-argument `(connection, error)` closure, but the current SDK signature is single-argument `Result`-based.

Verified independently this iteration:
- `swift build -c release` → **fails**
- GUI `swiftc … apc-core/Sources/APCCore/*.swift` → **fails** (it bundles the same file)

```
VSOCKManager.swift:70:46: error: contextual closure type
'(Result<VZVirtioSocketConnection, any Error>) -> Void'
expects 1 argument, but 2 were used in closure body
```

**Exact fix (P0, apply before any further loop work):**
```swift
socketDevice.connect(toPort: port) { result in
    switch result {
    case .success(let connection):
        print("[VSOCKManager] Connected to guest VSOCK port \(port) (fd: \(connection.fileDescriptor))")
        completion(connection.fileDescriptor, nil)
    case .failure(let error):
        completion(nil, error)
    }
}
```

Why this slipped through: the loop ran only `lsp_diagnostics`, which returned **stale, phantom** errors (`createVolume`/`removeVolume` not found — those actually exist and compile fine) while **missing the real VSOCK error**. SourceKit was out of sync with the on-disk sources.

---

## P0 — Verification ritual is giving false green

Two independent reliability failures this checkpoint:

1. **LSP is not a build.** `lsp_diagnostics` reported errors that don't exist and missed an error that does. Treat it as a hint, never as proof.
2. **Integration tests ran against stale binaries.** `build/ShibaStack.app/.../apc` timestamp is `17:19:37`; `VSOCKManager.swift` was edited at `17:20:43`. The integration suite executes the *pre-built* CLI, so a green run says nothing about the edited source. The "100% pass" reported for Loop 5 was structurally meaningless.

**Required gate for every future loop (in order, all must pass before `ralph_done`):**
1. `cd apc-core && swift build -c release` (authoritative compile of core/CLI/daemon)
2. GUI compile via `scripts/build-dmg.sh` (this is the only thing that exercises `apc-gui/main.swift` + bundled sources)
3. **Only then** `./scripts/test-integration.sh` and `./scripts/test-gui.sh`

If `build-dmg.sh` is not run, the GUI source is effectively untested — `swiftc` is the only consumer of `main.swift`.

---

## P1 — STRATEGIC DRIFT: "feature parity with OrbStack" vs. what is being built

This is the most important steering item, and it is bigger than any single loop.

**Inherited contract:** "fully functional app that has feature parity to OrbStack using apple containers."

**Reality of the codebase after 5 loops:**
- `ContainerManager.runNewContainer` creates a struct with a random ID and **hardcoded fake log lines**. No process is spawned, no image is pulled, no OCI runtime runs.
- The GUI container terminal is a **hardcoded `switch` of canned outputs** (`ls`, `uname`, `cat index.html`, …). It is not connected to anything.
- USB attach/detach, image pull, and stats are all **simulated**.
- The VM itself runs in **mock mode** in this environment (no `com.apple.security.virtualization` entitlement at runtime), which is fine for dev — but nothing downstream of it is real either.
- Grep for any real execution path (`Process`, `posix_spawn`, `container run`, `runc`/`crun`, `task.exec`) finds **only host-side dependency checks** (`which`, `xcode-select`, `brew`, `osascript`). Zero container execution.

The last 5 loops added **real plumbing** (Rosetta directory share, a real `VZVirtioSocketDeviceConfiguration`, real balloon-device calls, real IOKit registry reads). That work is genuine. But the spine that would make this OrbStack-comparable — **a guest agent (vminitd) inside the VM that pulls images and executes OCI containers, surfaced to the host over the VSOCK channel just built** — does not exist, and the checklist does not contain it as an explicit milestone.

**Consequence if unaddressed:** Loop 31–35 (Docker CLI bridge / `docker.sock`) and Loop 36–40 (Image & Volume Explorer) will necessarily be **façades** — a fake `docker.sock` returning canned JSON, an image list that pulls nothing. That is drift away from the stated goal, dressed as progress.

**Recommended pivot (revising the checklist, not the goal):** Insert a core-execution milestone *before* the Docker/Image façade loops, and reframe the VSOCK work (Loop 21–25) as its first real consumer:

- **New milestone — Real Guest Execution Spine (do before Loop 31+):**
  1. Boot a real Alpine guest with the kernels the onboarding already downloads (the `vminitd --vsock 1024` reference already appears in the fake terminal output — make it real).
  2. Stand up a minimal guest agent that accepts commands over the VSOCK port `VSOCKManager` now configures, and returns real stdout/stderr.
  3. Back `runNewContainer` and the GUI terminal with that agent (even a single `busybox`/`apk` exec is a real milestone).
  4. Evaluate `apple/container` / `containerization` as the OCI layer (the architecture doc already references Apple's framework) instead of hand-rolling.

If the *intended* deliverable is actually a **convincing demo / design prototype** rather than a working runtime, that is a legitimate choice — but it should be **stated explicitly** in the task file so later loops stop being measured against an unreachable parity bar. **This is the one decision the main agent should make consciously now.** Either answer changes how Loops 31–50 are scoped.

---

## P2 — Correctness / robustness nits (fix opportunistically)

1. **Boot params are partly cargo-culted** (`VMManager.swift`). Alpine uses **OpenRC, not systemd**, so `fsck.mode=skip` is ignored (systemd-only). `elevator=noop` was **removed from the kernel in 5.0+** (modern equivalent is `none`, set per-device via sysfs). `fastboot` is init-system specific. These are likely silently dropped. `quiet loglevel=3 noatime` are fine. Net effect: the "down to milliseconds" boot-speed claim in the notes is **unverified and partly based on no-op flags**. Recommend trimming to params that are actually honored and dropping the unmeasured speed claim, or measure it once a real boot exists.
2. **`memoryPressureSource` is read/written without the `lock`** used for all other shared state in `VMManager` (set in `startMemoryPressureMonitoring`, cleared in `stop…`). Called from VM start/stop completion handlers — low collision risk, but inconsistent with the file's own concurrency discipline. Guard it with the same lock.
3. **Balloon floor underflow.** At critical pressure you set target to 50% of allocation; `VZVirtioTraditionalMemoryBalloonDevice` has a framework minimum and the guest can OOM. Add a sane floor (e.g. never below 512 MB or below a configurable minimum) and a log when clamped.
4. **`reclaimGuestMemory` re-reads `loadVMConfig()` (disk I/O) on every pressure event**, inside the dispatch handler. Cache the configured size in memory at VM start instead of hitting the filesystem under memory pressure.
5. **Go `watchConfig` double-load on startup** (`loadRoutes()` is called in `main()` and again on the watcher's first zero-`lastModTime` tick). Harmless, but tighten if touched.

## Positives worth keeping (no action)
- `USBManager` `IO_OBJECT_NULL` guards: correct, safe defensive fix.
- Go `watchConfig` mtime gate: sound, real idle-CPU win.
- Rosetta availability `switch` with `@unknown default`: correctly handles all `VZLinuxRosettaDirectoryShare.availability` cases.
- `VMConfig` `enableRosetta` with `decodeIfPresent` default: backward-compatible decoding done right.
- GUI live-metrics overview + volume CRUD sheet: genuine, well-structured SwiftUI.

---

## Checklist adjustments for Loops 6–10 and beyond

1. **Loop 6 (immediate):** Apply the P0 VSOCK fix. Add the rebuild-before-test gate to the loop's standing procedure. Re-run `swift build -c release` + `build-dmg.sh` + both test scripts and confirm green *against freshly built binaries*. Do not advance until the working tree compiles.
2. **Decision gate (Loop 6–7):** Main agent explicitly records in the task file: **"real runtime"** or **"prototype/demo."** This unblocks correct scoping of everything after Loop 30.
3. **If "real runtime":** insert the Guest Execution Spine milestone (above) before Loop 31. Make Loop 21–25's VSOCK console its first consumer instead of the hardcoded terminal switch.
4. **Commit cadence:** 5 loops of work are sitting uncommitted in one pile. Commit per-loop (or per-phase) so a broken loop is bisectable and recoverable. Right now a single bad edit (the VSOCK break) contaminates the entire unstaged set.
5. **Stop trusting `lsp_diagnostics` as a build oracle.** It produced both false positives and a false negative this checkpoint.
6. **Trim or substantiate performance claims** in the task notes (boot speed, "near-zero overhead"). Unmeasured superlatives accumulate into a misleading record.

---

## One-line steer for the next 5 loops
Fix the build, make "real vs. demo" an explicit decision, and stop adding simulated façades on top of an un-compiled tree validated by stale binaries.
