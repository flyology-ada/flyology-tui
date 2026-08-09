#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
log_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-kitchen.XXXXXX")
trap 'rm -f "$log_file"' EXIT HUP INT TERM

test_command="stty rows 1 cols 1; (
  sleep 0.15; stty rows 6 cols 20 < /dev/tty
  sleep 0.15; stty rows 15 cols 55 < /dev/tty
  sleep 0.15; stty rows 24 cols 80 < /dev/tty
  sleep 0.15; stty rows 50 cols 160 < /dev/tty
) & '$root_dir/examples/bin/kitchen_sink'
status=\$?
printf '\n__FLYOLOGY_KITCHEN_EXIT_%s__\n' "\$status"
exit "\$status""

case $(uname -s) in
  Darwin)
    (sleep 1; printf '\003') |
      script -q /dev/null /bin/sh -c "$test_command" >"$log_file"
    ;;
  *)
    (sleep 1; printf '\003') |
      script -q -e -c "$test_command" /dev/null >"$log_file"
    ;;
esac

if grep -Eiq 'constraint_error|program_error|raised [A-Z_]+|traceback' \
  "$log_file"
then
  echo "kitchen resize smoke test reported an exception" >&2
  exit 1
fi

if ! grep -q "__FLYOLOGY_KITCHEN_EXIT_0__" "$log_file"; then
  echo "kitchen resize smoke test did not shut down cleanly" >&2
  exit 1
fi

echo "kitchen resize smoke tests passed (1x1, 20x6, 55x15, 80x24, 160x50)"
