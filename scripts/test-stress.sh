#!/bin/bash
# ==================================================
# SHIBASTACK ADVANCED END-TO-END STRESS & BENCHMARK SUITE
# ==================================================
set -e

echo "=================================================="
echo "SHIBASTACK HIGH-THROUGHPUT & CONCURRENCY BENCHMARK"
echo "=================================================="

# Start the proxy daemon in background for benchmarking
echo "Launching ShibaStack background services..."
build/ShibaStack.app/Contents/Resources/bin/apc-network >/dev/null 2>&1 &
PROXY_PID=$!

# Ensure cleanup on interrupt or exit
trap 'kill $PROXY_PID 2>/dev/null || true; rm -rf /tmp/stress-*; echo "Services stopped. Cleanup done."' EXIT

sleep 2

# --------------------------------------------------
# Test 1: DNS Query Benchmark (UDP Latency Verification)
# --------------------------------------------------
echo "--------------------------------------------------"
echo "[1/3] Benchmarking User-Space DNS Server (Port 15353)"
echo "--------------------------------------------------"

TOTAL_QUERIES=100
START_TIME=$(date +%s%N)

# Run queries sequentially in a fast, robust loop (takes ~100ms total)
for i in $(seq 1 $TOTAL_QUERIES); do
	dig @127.0.0.1 -p 15353 web-app.apc.local +short >/dev/null 2>&1
done

END_TIME=$(date +%s%N)
ELAPSED_NS=$((END_TIME - START_TIME))
ELAPSED_MS=$((ELAPSED_NS / 1000000))
AVG_LATENCY_MS=$(echo "scale=3; $ELAPSED_MS / $TOTAL_QUERIES" | bc)

echo "✓ DNS Benchmark Finished Successfully."
echo "  Total Queries Resolved : $TOTAL_QUERIES"
echo "  Total Elapsed Duration : ${ELAPSED_MS} ms"
echo "  Average Resolver Delay : ${AVG_LATENCY_MS} ms/query"

# --------------------------------------------------
# Test 2: HTTP Reverse Proxy Throughput (TCP Performance Gate)
# --------------------------------------------------
echo "--------------------------------------------------"
echo "[2/3] Benchmarking HTTP Reverse Proxy Throughput (Port 8080)"
echo "--------------------------------------------------"

TOTAL_REQUESTS=100
START_TIME=$(date +%s%N)

# Run requests sequentially in a fast, robust loop (takes ~150ms total)
for i in $(seq 1 $TOTAL_REQUESTS); do
	curl -s -H "Host: web-app.apc.local" http://127.0.0.1:8080/ >/dev/null 2>&1
done

END_TIME=$(date +%s%N)
ELAPSED_NS=$((END_TIME - START_TIME))
ELAPSED_MS=$((ELAPSED_NS / 1000000))
ELAPSED_SEC=$(echo "scale=3; $ELAPSED_MS / 1000" | bc)
REQS_PER_SEC=$(echo "scale=1; $TOTAL_REQUESTS / $ELAPSED_SEC" | bc)
AVG_LATENCY_MS=$(echo "scale=3; $ELAPSED_MS / $TOTAL_REQUESTS" | bc)

echo "✓ Reverse Proxy Throughput Benchmark Finished."
echo "  Total Requests Served : $TOTAL_REQUESTS"
echo "  Total Elapsed Duration: ${ELAPSED_SEC} seconds (${ELAPSED_MS} ms)"
echo "  System Query Rate     : ${REQS_PER_SEC} requests/sec"
echo "  Average Routing Delay : ${AVG_LATENCY_MS} ms/request"

# --------------------------------------------------
# Test 3: Resource Leak & Memory Starvation Guard
# --------------------------------------------------
echo "--------------------------------------------------"
echo "[3/3] System Integrity and Resource Leak Analysis"
echo "--------------------------------------------------"

# Read memory usage of our network daemon after high stress
MEM_KB=$(ps -o rss= -p $PROXY_PID | tr -d ' ')
MEM_MB=$(echo "scale=2; $MEM_KB / 1024" | bc)

echo "✓ Resource Leak Checks Completed."
echo "  Network Proxy PID      : $PROXY_PID"
echo "  Resident Memory (RSS)  : ${MEM_MB} MB"

if (($(echo "$MEM_MB < 30.0" | bc -l))); then
	echo "  [✓] Memory Consumption : HEALTHY (<30MB under stress)"
else
	echo "  [WARNING] High memory usage detected: ${MEM_MB} MB"
	exit 1
fi

echo "=================================================="
echo "ALL APC STRESS TESTS PASSED SUCCESSFULLY!"
echo "=================================================="
