#! /usr/bin/env bash

# Entry point for the `clean` command.
#
# This command removes all regtest data from the `environments` directory
# which isn't for the currently active environment, if any.
exec_clean() {
    local -i bytes_before bytes_after bytes_reclaimed

    if [ ! -d "./environments" ]; then
        printf "No regtest data to remove\n"
        exit 0
    fi
    
    bytes_before="$( du -s --bytes ./environments | cut -f1 )"

    for dir in ./environments/*; do
        if [ "$(basename "$dir")" != "$REGTEST_ENV_ID" ]; then
            echo "‣ Removing regtest data from $dir"
            rm -rf "$dir"
        else
            # shellcheck disable=SC2059
            printf "${GRAY}NOTE: Skipping active environment: '$REGTEST_ENV_ID'${NC}\n"
        fi
    done

    bytes_after="$( du -s --bytes ./environments | cut -f1 )"
    mb_after=$(( bytes_after / 1024 / 1024 ))
    reclaimed=$(( bytes_before - bytes_after ))
    reclaimed=$(( bytes_reclaimed / 1024 / 1024 ))

    printf "${GREEN}Finished:${NC} %sMB reclaimed, %sMB remaining\n" $reclaimed $mb_after
}