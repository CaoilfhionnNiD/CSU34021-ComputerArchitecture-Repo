#!/bin/bash
set -e

TOTAL_POINTS=0
MAX_POINTS=35

./server &
SERVER_PID=$!
sleep 1  

run_create_user_tests() {
    TEST_NAME=$1
    CLIENT_CMD=$2 
    EXPECTED_OUTPUT=$3
    POINTS=$4
    FOLDER=${5:-""}
    TIMEOUT=5

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    if ! pgrep -x "server" > /dev/null; then
        ./server &
        SERVER_PID=$!
        sleep 1
    fi
    # Run client 
    # if ! eval "$CLIENT_CMD" >client.out 2>&1; then
    #     echo "Client crashed"
    #     kill $SERVER_PID
    #     return 0
    # fi
    if ! timeout "${TIMEOUT}s" bash -c "$CLIENT_CMD" > client.out 2>&1; then
        STATUS=$?
        if [[ $STATUS -eq 124 ]]; then
            echo "Test failed: timed out after ${TIMEOUT}s"
        else
            echo "Test failed: client crashed"
        fi
        kill $SERVER_PID
        return 0
    fi

    # Compare output
    if diff -u "$EXPECTED_OUTPUT" client.out; then
        echo "Test passed! Output as expected +$((POINTS - 3)) points"
        TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 3))
    else
        echo "Test failed!"
    fi

    if diff -u "$EXPECTED_OUTPUT" client.out; then
        if [[ -d "$FOLDER" ]] && [[ -f "$FOLDER/friends.txt" ]] && [[ -f "$FOLDER/wall.txt" ]]; then
            echo "Test passed! .txt files exist +$((POINTS - 2)) points"
            TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
        else
            echo "Test failed! Folder missing or does not contain the exactly two .txt files"
        fi
    else
        echo "Test failed! Client output mismatch"
    fi
}

run_add_friend_test() {
    TEST_NAME=$1
    CLIENT_CMD=$2 
    EXPECTED_OUTPUT=$3
    EXPECTED_FILE=$4
    POINTS=$5
    FOLDER=${6:-""}
    TIMEOUT=5

    ls

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    if ! pgrep -x "server" > /dev/null; then
        echo "Server not running. Starting server..."
        ./server &
        SERVER_PID=$!
        sleep 1  
    else
        SERVER_PID=$(pgrep -x "server")
        echo "Server already running with PID $SERVER_PID"
    fi

    timeout "${TIMEOUT}s" $CLIENT_CMD > client.out 2>&1
    STATUS=$?

    echo "Client exit status: $STATUS"

    if [[ $STATUS -eq 124 ]]; then
        echo "Test failed: timed out after ${TIMEOUT}s"
        kill $SERVER_PID
        return 0
    elif [[ $STATUS -ne 0 ]]; then
        echo here
        echo "Test failed: client crashed"
        kill $SERVER_PID
        return 0
    fi
    
    echo reached
    # Compare output
    if diff -u "$EXPECTED_OUTPUT" client.out; then
        echo "Test passed! Output as expected +$((POINTS - 3)) points"
        TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 3))
    else
        echo "Test failed!"
    fi

    if diff -u "$EXPECTED_OUTPUT" client.out; then
        if [[ -n "$FOLDER" && -d "$FOLDER" ]]; then
            if diff -u "$EXPECTED_FILE" $FOLDER/friends.txt; then
                echo "Test passed! friends.txt as expected +$((POINTS - 2)) points"
                TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
            else
                echo "Test failed! Friend missing in .txt file"
            fi
        else
            TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
        fi
    else
        echo "Test failed! Client output mismatch"
    fi
}

run_create_user_tests "Create User" "qemu-riscv64 ./client create anthony" "expected_client_output.txt" 5 anthony
run_create_user_tests "Create User" "qemu-riscv64 ./client create person1" "expected_output_user_exists.txt" 5 person1
# run_create_user_tests "Create User" "qemu-riscv64 ./client create" "expected_output_no_id.txt" 5


run_add_friend_test "Add Friend" "qemu-riscv64 ./client add person1 person2" "expected_output_ok.txt" "expected_friend_file.txt" 5 person1
# run_add_friend_test "Add Friend" "qemu-riscv64 ./client add anthony bill" "expected_output_no_friend.txt" "expected_friend_file.txt" 5 anthony
# run_add_friend_test "Add Friend" "qemu-riscv64 ./client add bill bob" "expected_output_no_id2.txt" "emptyfile.txt" 5


kill $SERVER_PID

echo "Total score: $TOTAL_POINTS/$MAX_POINTS"
exit 0
