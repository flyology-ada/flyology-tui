#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$root_dir"
alr build

cd "$root_dir/tests"
alr build
./bin/flyology_tui_tests
./bin/foundation_layout_tests
./bin/controls_tests
./bin/visual_components_tests
./bin/window_components_tests
./bin/accordion_tests
./bin/data_navigation_tests
./bin/editing_tests

cd "$root_dir"
alr exec -- gprbuild -P tests/editor_lifecycle_tests.gpr -p
./tests/bin/editor_lifecycle_tests

cd "$root_dir/examples"
alr build
