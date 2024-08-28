#!/usr/bin/env bash

function build_help() {
	#statements
	cat << EOF
usage:
    build_image.sh --tag=<tag> OPTIONS

args:
EOF
printf "    %-40s %-40s\n" '--tag=<tag>' 'name of image (requierd)'
printf "    %-40s %-40s\n" '--token=<token>' 'token used to substitute {token} in --apps_json ex: [{"branch": "branch", "url": "https://{user}:{token}@url"}] or see transfer_company_template.json'
printf "    %-40s %-40s\n" '--apps-json=<apps_json>' 'json string of apps ex: content of transfer_company_template.json'
printf "    %-40s %-40s\n" '--frappe-path=<repo-path>' 'clone frappe from this repo default(https://github.com/fintechsys/frappe.git )'
printf "    %-40s %-40s\n" '--frappe-branch=<branch>' 'default(version-14)'
printf "    %-40s %-40s\n" '--fintech-branch=<branch>' 'branch used to substitute {fintech_branch} in --apps_json ex: [{"branch": "{fintech_branch}", "url": "https://{user}:{token}@url"}] or see transfer_company_template.json default(version-14)'
printf "    %-40s %-40s\n" '--app-branch=<app>:<branch>' 'branch used to substitute branch for specific app (app) in --apps_json ex: [{"branch": "branch`", "url": "https://{user}:{token}@url/app.git"}] or see transfer_company_template.json default(version-14)'
printf "    %-40s %-40s\n" '--build-commend=<commend>' 'tool used to build image default(docker)'
printf "    %-40s %-40s\n" '--container-file=<containerfile-path>' 'Containerfile used to build image default(./FrappeContainerfile)'
printf "    %-40s %-40s\n" '--working-dir=<path>' 'working dir for build command default (./)'
printf "    %-40s %-40s\n" '--node-version=<version>' 'node-version used to build image (16.18.0)'
printf "    %-40s %-40s\n" '--remove-user' 'substitute {user}:{token}@ from --apps_json ex: see transfer_company_template.json'
printf "    %-40s %-40s\n" '--no-remove-user' 'revrese --remove-user last one will be used (default)'
printf "    %-40s %-40s\n" '--no-cache' 'do not use cache when build image (default)'
printf "    %-40s %-40s\n" '--cache' 'use cache when build image'
printf "    %-40s %-40s\n" '--keygen-account' 'set product keygen account id'
printf "    %-40s %-40s\n" '--dry-run' 'only print what will be done'
printf "    %-40s %-40s\n" '--help' 'show help message and exit'

	exit ${1:-0}
}

function build_error() {
	# TODO: print error message based on $1
	exit ${1:-127}
}
function check_args() {
	if [ -z $TAG ]; then
		build_help 1>&2
	fi
}

function check_json() {

	if ! printf "$APPS_JSON" | jq empty ; then
		echo "ERROR in JSON"
		echo "$APPS_JSON"
		build_error $BAD_JSON
	fi

	UNIQ_URL=$(printf "$APPS_JSON" | jq -r ".[].url" | sort | uniq)
	SORT_URL=$(printf "$APPS_JSON" | jq -r ".[].url" | sort)

	if [ "$UNIQ_URL" != "$SORT_URL" ] ; then
		build_error $DUPLICATE_APPS
	fi
}

BAD_JSON=2
DUPLICATE_APPS=3

TEMP=$(getopt -o "" --long "apps-json:,frappe-path:,frappe-branch:,token:,build-commend:,container-file:,tag:,fintech-branch:,app-branch:,working-dir:,node-version:,keygen-account:,remove-user,no-remove-user,cache,no-cache,dry-run,help" -- "$@" )
eval set -- "$TEMP"

SCRIPT_PATH="$(dirname "$(readlink -f "$0")")"
FRAPPE_PATH=https://github.com/fintechsys/frappe.git
FRAPPE_BRANCH=version-14
FINTECH_BRANCH=version-14
BUILD_COMMEND=docker
CONTAINERFILE="$SCRIPT_PATH/FrappeContainerfile"
WORKING_DIR="$SCRIPT_PATH/"
REMOVE_USER=false
APPS_BRANCHES=""
CACHE="--no-cache-filter init-frappe"
NODE_VERSION="16.18.0"
KEYGEN_ACCOUNT_ID=""
DRY_RUN=false

while true; do
	case "$1" in
		--apps-json)
				export APPS_JSON="$2"; shift 2;;
		--frappe-path)
				FRAPPE_PATH="$2"; shift 2;;
		--frappe-branch)
				FRAPPE_BRANCH="$2"; shift 2;;
		--token)
				TOKEN="$2"; shift 2;;
		--build-commend)
				BUILD_COMMEND="$2"; shift 2;;
		--container-file)
				CONTAINERFILE="$2"; shift 2;;
		--working-dir)
				WORKING_DIR="$2"; shift 2;;
		--tag)
				TAG="$2"; shift 2;;
		--fintech-branch)
				FINTECH_BRANCH="$2"; shift 2;;
		--app-branch)
				APPS_BRANCHES=$(printf "$APPS_BRANCHES\n$2");
				shift 2;;
		--remove-user)
				REMOVE_USER=true; shift;;
		--no-remove-user)
				REMOVE_USER=false; shift;;
		--help)
				build_help; shift;;
		--no-cache)
				CACHE="--no-cache-filter init-frappe";  shift;;
	  	--cache)
				CACHE="";  shift;;
			--node-version)
					NODE_VERSION="$2";  shift 2;;
			--keygen-account)
					KEYGEN_ACCOUNT_ID="$2";  shift 2;;
			--dry-run)
					DRY_RUN=true;  shift;;
		--)
				shift; break;;
		*)
			build_help 19 1>&2; shift;;
	esac
done

check_args

CONTAINERFILE=$(realpath "$CONTAINERFILE")

if $REMOVE_USER ; then
	APPS_JSON=$(printf "$APPS_JSON" | sed "s/{user}:{token}@//g")
else
	APPS_JSON=$(printf "$APPS_JSON" | sed "s/{token}/${TOKEN}/g")
fi

APPS_JSON=$(printf "$APPS_JSON" | sed "s:{fintech_branch}:${FINTECH_BRANCH}:g")
APPS_JSON=$(printf "$APPS_JSON" | sed "s:{frappe_branch}:${FRAPPE_BRANCH}:g")

if command -v jq > /dev/null; then
	check_json
fi

if [ -n "$APPS_BRANCHES" ] ; then
	_TMPFILE=$(mktemp)
	# Write APPS_BRANCHES to the temporary file
	printf '%s\n' "$APPS_BRANCHES" > "$_TMPFILE"

	while IFS= read -r _APP_BRANCH; do
		_APP="${_APP_BRANCH%:*}"
		_BRANCH="${_APP_BRANCH##*:}"
		if [ -n "$_APP" ] && [ -n "$_BRANCH" ] ; then
			echo $_APP
			echo $_BRANCH
			APPS_JSON=$(printf "$APPS_JSON" | jq '.[] |= if .url | contains("'"$_APP"'") then .branch = "'"$_BRANCH"'" else . end')
		fi
	done < "$_TMPFILE"
	rm "$_TMPFILE"
fi


export APPS_JSON_BASE64=$(echo ${APPS_JSON} | base64 -w 0)

if ${DRY_RUN} ; then
	cat << EOF
cd "$WORKING_DIR" || ! echo "${WORKING_DIR} doesn't exists"

${BUILD_COMMEND} build ${CACHE} --build-arg=FRAPPE_PATH="${FRAPPE_PATH}" \\
		--build-arg=FRAPPE_BRANCH="${FRAPPE_BRANCH}" \\
		--build-arg=PYTHON_VERSION=3.10.5 \\
		--build-arg=NODE_VERSION=${NODE_VERSION} \\
		--build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \\
		--build-arg=GITHUB_AUTH_TOKEN=${TOKEN} \
		--build-arg=KEYGEN_ACCOUNT_ID=${KEYGEN_ACCOUNT_ID} \\
		--tag="${TAG}" \\
		--file="${CONTAINERFILE}" .
EOF
else
	cd "$WORKING_DIR" || ! echo "${WORKING_DIR} doesn't exists"

	${BUILD_COMMEND} build ${CACHE} --build-arg=FRAPPE_PATH="${FRAPPE_PATH}" \
			--build-arg=FRAPPE_BRANCH="${FRAPPE_BRANCH}" \
			--build-arg=PYTHON_VERSION=3.11.6 \
			--build-arg=NODE_VERSION="${NODE_VERSION}" \
			--build-arg=APPS_JSON_BASE64=$APPS_JSON_BASE64 \
			--build-arg=GITHUB_AUTH_TOKEN="${TOKEN}" \
			--build-arg=KEYGEN_ACCOUNT_ID="${KEYGEN_ACCOUNT_ID}" \
			--tag="${TAG}" \
			--file="${CONTAINERFILE}" .
fi
