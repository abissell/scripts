#!/bin/sh

. ./scripts/sh/common.sh

ensure_working_directory "${HOME}"

run_with_prompt 'curl -s "https://get.sdkman.io" | bash'
