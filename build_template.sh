#!/usr/bin/env bash

# Get the path of the executable file
SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"

function template_help() {
	#statements
	cat << EOF
usage:
    build_template.sh --template=<path-to-template> -- --tag=<tag> [build_image.sh OPTIONS]

build_image.sh help:
EOF
	"$SCRIPT_PATH/build_image.sh" --help
	exit ${1:-0}
}

function check_args() {
	if [ -z $TEMPLATE ]; then
		template_help 19 1>&2
	fi
}

TEMP=$(getopt -o ":" --long "template:,help" -- "$@" )
eval set -- "$TEMP"


while true; do
	case "$1" in
		--template)
			TEMPLATE="$2"; shift 2;;
		--help)
			template_help; shift;;
		--)
			shift; break;;
	esac
done

check_args

APPS_JSON=$(cat "$TEMPLATE")
cat $TEMPLATE

"$SCRIPT_PATH/build_image.sh" "$@" --apps-json="$APPS_JSON"
