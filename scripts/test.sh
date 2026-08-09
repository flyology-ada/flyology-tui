#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$root_dir"
alr build

cd "$root_dir/tests"
alr build
./bin/flyology_tui_tests
