#!/usr/bin/env bash

# Get the path of the executable file
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"


TEMPLATE_PATH="$SCRIPT_PATH/helpdesk.json"
"$SCRIPT_PATH/build_template.sh" --template="$TEMPLATE_PATH" -- --node-version="18.19.0" "$@"
