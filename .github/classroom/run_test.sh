# #!/bin/bash
# set -e

# TOTAL_POINTS=0
# MAX_POINTS=10

# ./server &
# SERVER_PID=$!
# sleep 1  

# run_test() {
#     TEST_NAME=$1
#     CLIENT_CMD=$2 
#     EXPECTED_OUTPUT=$3
#     POINTS=$4
#     FOLDER=$5

#     echo "Running test: $TEST_NAME (worth $POINTS points)"

#     # Run client 
#     if ! eval "$CLIENT_CMD" >client.out 2>&1; then
#         echo "Client crashed"
#         kill $SERVER_PID
#         return 0
#     fi

#     # Compare output
#     if diff -u "$EXPECTED_OUTPUT" client.out; then
#         echo "Test passed! +$POINTS points"
#         TOTAL_POINTS=$((TOTAL_POINTS + $POINTS))
#     else
#         echo "Test failed!"
#     fi

#     if diff -u "$EXPECTED_OUTPUT" client.out >; then
#         if [ -d "$FOLDER" ] && [ "$(find "$FOLDER" -maxdepth 1 -type f -name "*.txt" | wc -l)" -eq 2 ]; then
#             echo "Test passed! +$POINTS points"
#             TOTAL_POINTS=$((TOTAL_POINTS + POINTS))
#         else
#             echo "Test failed! Folder missing or does not contain exactly 2 .txt files"
#         fi
#     else
#         echo "Test failed! Client output mismatch"
#     fi
# }

# run_test "Create User" "qemu-riscv64 ./client create anthony" "expected_client_output.txt" 5 anthony
# run_test "Create User" "qemu-riscv64 ./client create bob" "expected_client_output.txt" 5 bob

# kill $SERVER_PID

# echo "Total score: $TOTAL_POINTS/$MAX_POINTS"
# exit 0
