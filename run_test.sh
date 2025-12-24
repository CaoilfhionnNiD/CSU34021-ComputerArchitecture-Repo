#!/bin/bash
set -e

TOTAL_POINTS=0
MAX_POINTS=50

start_server_if_needed() {
    if ! pgrep -x "server" > /dev/null; then
        ./server &
        SERVER_PID=$!
        sleep 1
    fi
}

run_with_timeout() {
    CLIENT_CMD=$1
    TIMEOUT=5

    if ! timeout "${TIMEOUT}s" bash -c "$CLIENT_CMD" > client.out 2>&1; then
        STATUS=$?
        if [[ $STATUS -eq 124 ]]; then
            echo "Test failed: timed out after ${TIMEOUT}s"
        else
            echo "Test failed: client crashed"
        fi
        kill $SERVER_PID
        return 1
    fi
    return 0
}


compare_output() {
    EXPECTED_OUTPUT=$1
    local points=$2
    MESSAGE_PASS=$3
    MESSAGE_FAIL=$4
    if diff -u "$EXPECTED_OUTPUT" client.out; then
        echo "Test passed! $MESSAGE_PASS +$points points"
        TOTAL_POINTS=$((TOTAL_POINTS + points))
        return 0
    else
        echo "Test failed: $MESSAGE_FAIL"
        return 1
    fi
}

run_create_user_tests() {
    TEST_NAME=$1
    CLIENT_CMD=$2 
    EXPECTED_OUTPUT=$3
    POINTS=$4
    FOLDER=${5:-""}
    TIMEOUT=5

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    start_server_if_needed

    run_with_timeout "$CLIENT_CMD" || return

    compare_output "$EXPECTED_OUTPUT" $((POINTS-3)) "Output as expected" "Output not as expected"

    if diff -u "$EXPECTED_OUTPUT" client.out; then
        if [[ -d "$FOLDER" ]] && [[ -f "$FOLDER/friends.txt" ]] && [[ -f "$FOLDER/wall.txt" ]]; then
            echo "Test passed! .txt files exist +$((POINTS - 2)) points"
            TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
        else
            echo "Test failed! Folder missing or does not contain the exactly two .txt files"
        fi
    else
        echo "Test failed: Output not as expected"
    fi
}

run_client_without_server_test() {
    TEST_NAME=$1
    CLIENT_CMD=$2
    EXPECTED_OUTPUT=$3
    EXPECTED_OUTPUT_2=$4
    CLIENT_NAME=$5
    TIMEOUT=5

    echo "Running test: $TEST_NAME (worth 20 points)"

    if pgrep -x "server" > /dev/null; then
        echo "Test failed: Server is running when it should not be"
        return 0
    fi

    cat server.pipe > server_pipe.out &

    bash -c "$CLIENT_CMD" > client.out 2>&1 &
    CLIENT_PID=$!

    sleep 2

    echo "ok: user created!" > $CLIENT_NAME.pipe &

    sleep 2

    if diff -u "$EXPECTED_OUTPUT" server_pipe.out; then
        echo "Test passed! Output as expected to server pipe +10 points"
        TOTAL_POINTS=$((TOTAL_POINTS + 10))
    else
        echo "Test failed: Output not as expected to server pipe"
    fi

    compare_output "$EXPECTED_OUTPUT_2" 10 "Output as expected from client pipe" "Output not as expected from client"
}


run_server_without_client_test() {
    TEST_NAME=$1
    EXPECTED_OUTPUT=$2
    CLIENT_NAME=$3

    echo "Running test: $TEST_NAME (worth 10 points)"

    cat $CLIENT_NAME.pipe > client_pipe.out &

    start_server_if_needed

    echo "create $CLIENT_NAME" > server.pipe 

    sleep 2

    if diff -u "$EXPECTED_OUTPUT" client_pipe.out; then
        echo "Test passed! Output as expected +10 points"
        TOTAL_POINTS=$((TOTAL_POINTS + 10))
    else
        echo "Test failed! Output from server to client pipe did not match"
    fi
}

run_post_wall_test() {
    TEST_NAME=$1
    CLIENT_CMD=$2 
    EXPECTED_OUTPUT=$3
    EXPECTED_FILE=$4
    POINTS=$5
    FOLDER=${6:-""}
    TIMEOUT=10

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    start_server_if_needed

    run_with_timeout "$CLIENT_CMD" || return

    compare_output "$EXPECTED_OUTPUT" $((POINTS - 3)) "Output as expected" "Output not as expected from client"

    if diff -u "$EXPECTED_OUTPUT" client.out; then
        if [[ -n "$FOLDER" && -d "$FOLDER" ]]; then
            if diff -u "$EXPECTED_FILE" $FOLDER/wall.txt; then
                echo "Test passed! wall.txt as expected +$((POINTS - 2)) points"
                TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
            else
                echo "Test failed: Post missing in wall.txt file"
            fi
        else
            echo "Test failed: required folders do not exist"
        fi
    else
        echo "Test failed: Output not as expected from client"
    fi

}

run_add_friend_test() {
    TEST_NAME=$1
    CLIENT_CMD=$2 
    EXPECTED_OUTPUT=$3
    EXPECTED_FILE=$4
    POINTS=$5
    FOLDER=${6:-""}
    FOLDER2=${7:-""}
    TIMEOUT=10

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    echo "$FOLDER" > $FOLDER2/friends.txt

    start_server_if_needed

    run_with_timeout "$CLIENT_CMD" || return

    compare_output "$EXPECTED_OUTPUT" $((POINTS - 3)) "Output as expected" "Output not as expected from client"

    if diff -u "$EXPECTED_OUTPUT" client.out; then
        if [[ -n "$FOLDER" && -d "$FOLDER" ]]; then
            if diff -u "$EXPECTED_FILE" $FOLDER/friends.txt; then
                echo "Test passed! friends.txt as expected +$((POINTS - 2)) points"
                TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
            else
                echo "Test failed! Friend missing in .txt file"
            fi
        else
            echo "Test failed: required folders do not exist"
        fi
    else
        echo "Test failed: Output not as expected from client"
    fi
}

name1="user_$RANDOM"
name2="user_$RANDOM"

while [[ "$name1" == "$name2" ]]; do
    name2="user_$RANDOM"
done

echo "Creating named pipes..."
mkfifo $name1.pipe $name2.pipe server.pipe

echo -n "create $name1" > expected_output/expected_output.txt

run_client_without_server_test "Create User without server" "qemu-riscv64 ./client $name1 create " "expected_output/expected_output.txt" "expected_output/expected_client_output.txt" $name1
STATUS1=$?
run_server_without_client_test "Create User without client" "expected_output/expected_client_output.txt" $name1
STATUS2=$?

if [[ $STATUS1 -eq 0 && $STATUS2 -eq 0 ]]; then
    rm -rf $name1

    run_create_user_tests "Create User" "qemu-riscv64 ./client $name1 create" "expected_output/expected_client_output.txt" 5 $name1
    run_create_user_tests "Create User" "qemu-riscv64 ./client $name1 create" "expected_output/expected_output_user_exists.txt" 5 $name1

    mkdir "$name2"
    touch "$name2/friends.txt" "$name2/wall.txt"

    echo "$name2" > expected_output/expected_output.txt

    run_add_friend_test "Add Friend" "qemu-riscv64 ./client $name1 add $name2" "expected_output/expected_output_ok.txt" "expected_output/expected_output.txt" 5 $name1 $name2

    echo "$name1: hey" > expected_output/expected_output.txt

    run_post_wall_test "Post Wall" "qemu-riscv64 ./client $name1 post $name2 hey" "expected_output/expected_output_ok.txt" "expected_output/expected_output.txt" 5 $name2
else
    echo "First two tests failed so remaining tests are not executed"
fi
    echo "Total score: $TOTAL_POINTS/$MAX_POINTS"
exit 0
