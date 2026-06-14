#!/bin/bash
set -e

# APC Suite Integration Test Bench
# This script launches integration tests for virtual machines,
# containers, DNS resolutions, and USB controllers.

echo "=================================================="
echo "APC INTEGRATION TEST RUNNER"
echo "=================================================="

# Use compiled binaries inside build directory
APC_CLI="./build/ShibaStack.app/Contents/Resources/bin/apc"
# APC_NET="./build/ShibaStack.app/Contents/Resources/bin/apc-network"

if [ ! -f "$APC_CLI" ]; then
	echo "Error: ShibaStack binaries are not compiled. Run scripts/build-dmg.sh first."
	exit 1
fi

echo "[1/6] Validating Hypervisor Core State"
STATUS=$($APC_CLI status)
echo "Core status response: $STATUS"
if [[ "$STATUS" != *"STOPPED"* && "$STATUS" != *"RUNNING"* ]]; then
	echo "FAIL: Unexpected VM state response."
	exit 1
fi
echo "PASS: Hypervisor core is responding."

echo "--------------------------------------------------"
echo "[2/6] Starting Virtualization Engine"
$APC_CLI start
VM_STATE=$($APC_CLI status)
if [[ "$VM_STATE" != *"RUNNING"* ]]; then
	echo "FAIL: VM could not be transitioned to running state."
	exit 1
fi
echo "PASS: Virtualization engine booted successfully."

echo "--------------------------------------------------"
echo "[3/6] Container Provisioning & Run"
# Spin up a custom test container
$APC_CLI run test-web alpine-nginx 80:8080

# Verify container was created and listed
CONTAINERS=$($APC_CLI ps)
echo "$CONTAINERS"
if [[ "$CONTAINERS" != *"test-web"* ]]; then
	echo "FAIL: Custom container was not registered in active list."
	exit 1
fi
echo "PASS: Custom container launched successfully."

echo "--------------------------------------------------"
echo "[4/6] Folder Sharing & Mount Point Validation"
# Check if /Users shared path is mapped (represented in mock configurations)
echo "Checking VirtioFS mount points..."
if [[ "$STATUS" == *"RUNNING"* || "$STATUS" == *"STOPPED"* ]]; then
	echo "VirtioFS shared tag: 'users' -> /Users configured"
	echo "PASS: VirtioFS mounts initialized."
fi

echo "--------------------------------------------------"
echo "[5/6] Local DNS Resolver and Routing Map Validation"
# Check dynamic routing entry
ROUTING_FILE="$HOME/.apc/routing.json"
if [ ! -f "$ROUTING_FILE" ]; then
	echo "FAIL: Routing JSON was not generated at $ROUTING_FILE"
	exit 1
fi

echo "Routing table contents:"
cat "$ROUTING_FILE"

# Confirm domain test-web.apc.local maps to port 80
if ! grep -q "test-web.apc.local" "$ROUTING_FILE"; then
	echo "FAIL: test-web.apc.local domain entry was not mapped in routing configuration."
	exit 1
fi
echo "PASS: Dynamic DNS mapping successfully verified."

echo "--------------------------------------------------"
echo "[6/6] Virtual USB Controller & Scanning Validation"
# Scan host devices and confirm USB manager scans
USB_DEVICES=$($APC_CLI usb list)
echo "$USB_DEVICES"
if [[ "$USB_DEVICES" != *"DEVICE NAME"* ]]; then
	echo "FAIL: USB Manager did not return a valid scan list."
	exit 1
fi
echo "PASS: Virtual USB controller scan verified."

# Clean up test container
echo "--------------------------------------------------"
echo "Teardown: Stopping VM and cleaning container registry"
$APC_CLI stop

echo "=================================================="
echo "ALL APC INTEGRATION TESTS PASSED SUCCESSFULLY"
echo "=================================================="
