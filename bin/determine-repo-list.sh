#!/bin/bash

CHECKED_REPO_PATH=${2}
TIMEOUT_SECONDS=${3:-86400}
MAX_TRIGGERS=${4:-99999}

output_repositories() {
    REPOSITORIES_INPUT=$1
    echo " Queue to process: ${REPOSITORIES_INPUT%?}"
    [ -z "$REPOSITORIES_INPUT" ] && echo "::set-output name=IS_EMPTY_REPO_LIST::true" && return || echo "::set-output name=IS_EMPTY_REPO_LIST::false"
    echo "::set-output name=REPOSITORIES_LIST::$REPOSITORIES_INPUT"
}

repo_previous_check() {
    repo=$(grep "$1" "$CHECKED_REPO_PATH")
    # Timestamp
    echo "$repo" | cut -d' ' -f2
}

add_workflow_in_queue() {
    echo "    - Adding to queue ${1}"
    queue="${1},${queue}"
}

compare_timeout_times() {
    TIMEOUT_TIME=$1
    TARGET_REPO_EPOCH_TIME=$2

    # if the target repository time is larger or the same than the time out time, we should not do anything as
    # the repo is within the timeframe and does not need checking.
    # In this case we should exit
    if (($TARGET_REPO_EPOCH_TIME >= $TIMEOUT_TIME)); then
        echo 'false'
    else
        # the repo is not within the timeframe and does need checking.
        # In this case we should echo something and exit the application.
        echo 'true'
    fi
}

# -------------------------------------------------------------------------------------------------------

[ -n "$1" ] && REPO_LIST_PATH=$1 || exit 1

echo "max_triggers: ${MAX_TRIGGERS}"
echo "timeout_seconds: ${TIMEOUT_SECONDS}"

triggers=0
queue=""

current_time=$(date +%s)
timeout_time=$(expr $current_time - $TIMEOUT_SECONDS)

echo "- Reading $REPO_LIST_PATH"

FILE_CONTENT=$(sed "s/,/\n/g" "$REPO_LIST_PATH")

for repo in ${FILE_CONTENT//,/\n}; do
    if [ $(($triggers)) -ge $(($MAX_TRIGGERS)) ]; then
        echo "Enough workflows in queue... let's trigger the workflow"
        break
    fi
    previous_timestamp=$(repo_previous_check "$repo")
    if [ -n "$previous_timestamp" ]; then
        need_checking=$(compare_timeout_times $timeout_time $previous_timestamp)
        if [ "$need_checking" == "true" ]; then
            triggers=$((triggers + 1))
            printf '  - %s: triggering: %s - %s is too long ago\n' "$triggers" "$repo" "$previous_timestamp"
            add_workflow_in_queue "$repo"
        else
            echo "    - already checked $repo at $previous_timestamp."
        fi
    else
        echo "    - never checked $repo"
        triggers=$((triggers + 1))
        printf '  - %s: triggering: %s\n' "$triggers" "$repo"
        add_workflow_in_queue "$repo"
    fi
done

output_repositories "$queue"
