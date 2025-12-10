#!/bin/bash
set -e

echo "[INFO] Checking required student files..."
REQUIRED=("client_driver.c" "client.s" "server_driver.c" "server.asm" "Makefile")

for f in "${REQUIRED[@]}"; do
    if [ ! -f "$f" ]; then
        echo "Missing required file: $f"
        exit 1
    fi
done

echo "[INFO] Building with Makefile..."
make

echo "[INFO] Creating FIFOs..."
rm -f server.pipe anthony.pipe
mkfifo server.pipe
mkfifo anthony.pipe

echo "[INFO] Starting server..."
qemu-i386 -L /usr/i386-linux-gnu ./server > server_output.txt 2>&1 &
SERVER_PID=$!
sleep 1

echo "[INFO] Running client..."
qemu-riscv64 ./client > client_output.txt 2>&1

sleep 1
kill $SERVER_PID || true

echo "[INFO] Checking communication..."
if grep -q "Hello from RISC-V" server_output.txt && grep -q "Hello" client_output.txt ; then
    echo "OK"
else
    echo "FAIL"
    echo "--- SERVER OUTPUT ---"
    cat server_output.txt
    echo "--- CLIENT OUTPUT ---"
    cat client_output.txt
    exit 1
fi

