#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
test_command="cd '$root_dir/tests' && stty rows 27 cols 91 && exec ./bin/posix_initial_size_tests"
log_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-posix-size.XXXXXX")
trap 'rm -f "$log_file"' EXIT HUP INT TERM

case $(uname -s) in
  Darwin)
    script -q /dev/null /bin/sh -c "$test_command" >"$log_file"
    ;;
  *)
    script -q -e -c "$test_command" /dev/null >"$log_file"
    ;;
esac

if ! grep -q "POSIX initial size tests passed" "$log_file"; then
  echo "POSIX initial size test did not complete successfully" >&2
  exit 1
fi

echo "POSIX initial size tests passed"
