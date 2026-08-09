#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
log_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-kitchen.XXXXXX")
pid_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-kitchen-pid.XXXXXX")
timeout_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-kitchen-timeout.XXXXXX")
rm -f "$timeout_file"
session_pid=
watchdog_pid=

terminate_session() {
  signal=$1
  child_pid=
  if [ -s "$pid_file" ]; then
    child_pid=$(sed -n '1p' "$pid_file")
  fi
  case $child_pid in
    ''|*[!0-9]*) ;;
    *)
      kill -"$signal" -"$child_pid" 2>/dev/null ||
        kill -"$signal" "$child_pid" 2>/dev/null || true
      ;;
  esac
  if [ -n "$session_pid" ]; then
    kill -"$signal" "$session_pid" 2>/dev/null || true
  fi
}

cleanup() {
  if [ -n "$watchdog_pid" ]; then
    kill "$watchdog_pid" 2>/dev/null || true
    wait "$watchdog_pid" 2>/dev/null || true
  fi
  if [ -n "$session_pid" ]; then
    terminate_session TERM
    sleep 0.1
    terminate_session KILL
    wait "$session_pid" 2>/dev/null || true
  fi
  rm -f "$log_file" "$pid_file" "$timeout_file"
}

trap cleanup EXIT
trap 'exit 1' HUP INT TERM

if ! "$root_dir/examples/bin/kitchen_sink" --responsive-self-test \
  >"$log_file" 2>&1
then
  echo "kitchen responsive geometry assertions failed" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

if ! grep -q "kitchen responsive self-tests passed" "$log_file"; then
  echo "kitchen responsive geometry assertions did not complete" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

test_command="printf '%s\n' \"\$\$\" > '$pid_file'; stty rows 1 cols 1; (
  sleep 0.15; stty rows 6 cols 20 < /dev/tty
  sleep 0.15; stty rows 15 cols 55 < /dev/tty
  sleep 0.15; stty rows 15 cols 56 < /dev/tty
  sleep 0.15; stty rows 24 cols 80 < /dev/tty
  sleep 0.15; stty rows 50 cols 160 < /dev/tty
) & '$root_dir/examples/bin/kitchen_sink'
status=\$?
printf '\n__FLYOLOGY_KITCHEN_EXIT_%s__\n' "\$status"
exit "\$status""

case $(uname -s) in
  Darwin)
    (sleep 1; printf '\003') |
      script -q /dev/null /bin/sh -c "$test_command" >>"$log_file" &
    ;;
  Linux)
    (sleep 1; printf '\003') |
      script -q -e -c "$test_command" /dev/null >>"$log_file" &
    ;;
  *)
    echo "kitchen resize PTY test supports Darwin and Linux" >&2
    exit 1
    ;;
esac
session_pid=$!

(
  sleep 15
  if kill -0 "$session_pid" 2>/dev/null; then
    : >"$timeout_file"
    terminate_session TERM
    sleep 1
    terminate_session KILL
  fi
) &
watchdog_pid=$!

if wait "$session_pid"; then
  session_status=0
else
  session_status=$?
fi
session_pid=
kill "$watchdog_pid" 2>/dev/null || true
wait "$watchdog_pid" 2>/dev/null || true
watchdog_pid=

if [ -e "$timeout_file" ]; then
  echo "kitchen resize PTY test timed out after 15 seconds" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

if [ "$session_status" -ne 0 ]; then
  echo "kitchen resize PTY session exited with status $session_status" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

if grep -Eiq 'constraint_error|program_error|raised [A-Z_]+|traceback' \
  "$log_file"
then
  echo "kitchen resize smoke test reported an exception" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

if ! grep -q "__FLYOLOGY_KITCHEN_EXIT_0__" "$log_file"; then
  echo "kitchen resize smoke test did not shut down cleanly" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

echo "kitchen resize smoke tests passed (1x1, 20x6, 55x15, 56x15, 80x24, 160x50)"
