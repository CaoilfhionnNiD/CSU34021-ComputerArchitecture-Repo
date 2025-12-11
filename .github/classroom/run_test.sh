#!/bin/bash
set -e

mkfifo server.pipe anthony.pipe

# Run server
./server &
SERVER_PID=$!

sleep 1

# Run RISC-V client
qemu-riscv64 ./client >client.out 2>&1 || {
    echo "Client crashed"
    exit 1
}

# Wait for server
wait $SERVER_PID || {
    echo "Server exited with failure"
    exit 1
}

# Check output
if ! diff -u expected_client_output.txt client.out; then
    echo "Client output mismatch"
    exit 1
fi

echo "test passed"
exit 0

