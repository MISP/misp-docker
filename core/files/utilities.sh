#!/bin/bash

# Check whether passed env variables are defined
check_env_vars() {
    local required_vars=("$@")

    missing_vars=()
    for i in "${required_vars[@]}"
    do
        test -n "${!i:+y}" || missing_vars+=("$i")
    done
    if [ ${#missing_vars[@]} -ne 0 ]
    then
        echo "The following env variables are not set:"
        printf ' %q\n' "${missing_vars[@]}"
        exit 1
    fi
}
