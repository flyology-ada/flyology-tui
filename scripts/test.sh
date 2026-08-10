#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$root_dir"
alr build

cd "$root_dir/tests"
alr build
./bin/flyology_tui_tests

case "$(uname -s)" in
    Darwin)
        run_posix_color_lifecycle() {
            script -q /dev/null ./bin/flyology_tui_tests
        }
        ;;
    Linux)
        run_posix_color_lifecycle() {
            script -q -e -c "./bin/flyology_tui_tests" /dev/null
        }
        ;;
    *)
        echo "unsupported host for POSIX color lifecycle test" >&2
        exit 1
        ;;
esac

(
    unset NO_COLOR
    TERM=xterm-256color
    COLORTERM=
    FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE=ansi256
    export TERM COLORTERM FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE
    run_posix_color_lifecycle
)
(
    NO_COLOR=
    TERM=xterm-256color
    COLORTERM=
    FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE=ansi256
    export NO_COLOR TERM COLORTERM FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE
    run_posix_color_lifecycle
)
(
    NO_COLOR=1
    TERM=xterm-256color
    COLORTERM=
    FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE=monochrome
    export NO_COLOR TERM COLORTERM FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE
    run_posix_color_lifecycle
)
(
    NO_COLOR=1
    TERM=dumb
    COLORTERM=
    FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE=forced_truecolor
    export NO_COLOR TERM COLORTERM FLYOLOGY_TUI_TEST_POSIX_COLOR_LIFECYCLE
    run_posix_color_lifecycle
)

./bin/foundation_layout_tests
./bin/controls_tests
./bin/visual_components_tests
./bin/window_components_tests
./bin/accordion_tests
./bin/data_navigation_tests
./bin/editing_tests
./bin/streaming_text_tests
./bin/chat_tests
./bin/panel_group_tests
./bin/markdown_components_tests
./bin/menubar_tests
./bin/gradient_tests
./bin/responsive_geometry_tests
./bin/dock_workspace_tests

cd "$root_dir"
./scripts/test-posix-initial-size.sh

cd "$root_dir"
alr exec -- gprbuild -P tests/editor_lifecycle_tests.gpr -p
./tests/bin/editor_lifecycle_tests

cd "$root_dir/examples"
alr build

cd "$root_dir"
./scripts/test-kitchen-resize.sh
