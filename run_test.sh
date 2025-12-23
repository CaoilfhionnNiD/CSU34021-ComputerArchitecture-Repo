#!/bin/bash
set -e

TOTAL_POINTS=0
MAX_POINTS=35

run_create_user_tests() {
    TEST_NAME=$1
    CLIENT_CMD=$2 
    EXPECTED_OUTPUT=$3
    POINTS=$4
    FOLDER=${5:-""}
    TIMEOUT=5

    rm -rf anthony

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    if ! pgrep -x "server" > /dev/null; then
        ./server &
        SERVER_PID=$!
        sleep 1
    fi

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

run_client_without_server_test() {
    TEST_NAME=$1
    CLIENT_CMD=$2
    EXPECTED_OUTPUT=$3
    EXPECTED_OUTPUT_2=$4
    POINTS=$5

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    if pgrep -x "server" > /dev/null; then
        echo "Server is running when it should not be"
        return 0
    fi

    cat server.pipe > server_pipe.out &
    PIPE_PID=$!

    bash -c "$CLIENT_CMD" > client.out 2>&1 &
    CLIENT_PID=$!

    sleep 2

    echo "ok: user created!" > anthony.pipe &

    sleep 1

    if diff -u "$EXPECTED_OUTPUT" server_pipe.out; then
        echo "Test passed! Output as expected to server pipe +$POINTS points"
        TOTAL_POINTS=$((TOTAL_POINTS + POINTS))
    else
        echo "Test failed! Output not as expected to server pipe"
    fi

    if diff -u "$EXPECTED_OUTPUT_2" client.out; then
        echo "Test passed! Output as expected from client pipe +$POINTS points"
        TOTAL_POINTS=$((TOTAL_POINTS + POINTS))
    else
        echo "Test failed! Output not as expected from client"
    fi
}


run_server_without_client_test() {
    TEST_NAME=$1
    EXPECTED_OUTPUT=$2
    POINTS=$3

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    cat anthony.pipe > anthony_pipe.out &

    if ! pgrep -x "server" > /dev/null; then
        ./server &
        SERVER_PID=$!
        sleep 1
    fi

    echo "create anthony" > server.pipe 

    sleep 2

    if diff -u "$EXPECTED_OUTPUT" anthony_pipe.out; then
        echo "Test passed! Output as expected +$POINTS points"
        TOTAL_POINTS=$((TOTAL_POINTS + POINTS))
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

    if ! pgrep -x "server" > /dev/null; then
        ./server &
        SERVER_PID=$!
        sleep 1
    fi

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

    if diff -u "$EXPECTED_OUTPUT" client.out; then
        echo "Test passed! Output as expected +$((POINTS - 3)) points"
        TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 3))
    else
        echo "Test failed! Output did not match"
    fi

    if diff -u "$EXPECTED_OUTPUT" client.out; then
        if [[ -n "$FOLDER" && -d "$FOLDER" ]]; then
            if diff -u "$EXPECTED_FILE" $FOLDER/wall.txt; then
                echo "Test passed! wall.txt as expected +$((POINTS - 2)) points"
                TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
            else
                echo "Test failed! Post missing in wall.txt file"
            fi
        else
            TOTAL_POINTS=$((TOTAL_POINTS + POINTS - 2))
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
    TIMEOUT=10

    echo "Running test: $TEST_NAME (worth $POINTS points)"

    echo "person1" > person2/friends.txt


    if ! pgrep -x "server" > /dev/null; then
        echo "Server not running. Starting server..."
         ./server > server.out 2>&1 &
        SERVER_PID=$!
        sleep 1  
    else
        SERVER_PID=$(pgrep -x "server")
        echo "Server already running with PID $SERVER_PID"
    fi

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

name1="user_$RANDOM"
name2="user_$RANDOM"

while [[ "$name1" == "$name2" ]]; do
    name2="user_$RANDOM"
done

echo "Creating named pipes..."
mkfifo $name1.pipe
mkfifo $name2.pipe

echo "create $name1" > expected_server_pipe_output.txt

run_client_without_server_test "Create User without server" "qemu-riscv64 ./client $name1 create " "expected_server_pipe_output.txt" "expected_client_output.txt" 5 
run_server_without_client_test "Create User without client" "expected_client_output.txt" 5

# ./server &
# SERVER_PID=$!
# sleep 1  

run_create_user_tests "Create User" "qemu-riscv64 ./client $name1 create" "expected_client_output.txt" 5 $name1
run_create_user_tests "Create User" "qemu-riscv64 ./client $name1 create" "expected_output_user_exists.txt" 5 $name1
# kill $SERVER_PID

mkdir "$name2"
touch "$name2/friends.txt" "$name2/wall.txt"

echo "$name2" > expected_friend_file.txt

# ./server &
# SERVER_PID=$!
# sleep 1  
run_add_friend_test "Add Friend" "qemu-riscv64 ./client $name1 add $name2" "expected_output_ok.txt" "expected_friend_file.txt" 5 $name1

echo "$name1: hey" > expected_wall_file.txt

run_post_wall_test "Post Wall" "qemu-riscv64 ./client $name1 post $name2 hey" "expected_output_ok.txt" "expected_wall_file.txt" 5 $name2
# kill $SERVER_PID

echo "Total score: $TOTAL_POINTS/$MAX_POINTS"
exit 0
