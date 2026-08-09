#!/bin/sh
set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
log_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-posix-size.XXXXXX")
pid_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-posix-size-pid.XXXXXX")
timeout_file=$(mktemp "${TMPDIR:-/tmp}/flyology-tui-posix-size-timeout.XXXXXX")
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

test_command="printf '%s\n' \"\$\$\" > '$pid_file'; cd '$root_dir/tests' && stty rows 27 cols 91 && exec ./bin/posix_initial_size_tests"

case $(uname -s) in
  Darwin)
    script -q /dev/null /bin/sh -c "$test_command" >"$log_file" &
    ;;
  Linux)
    script -q -e -c "$test_command" /dev/null >"$log_file" &
    ;;
  *)
    echo "POSIX initial size PTY test supports Darwin and Linux" >&2
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
  echo "POSIX initial size PTY test timed out after 15 seconds" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

if [ "$session_status" -ne 0 ]; then
  echo "POSIX initial size PTY session exited with status $session_status" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

if ! grep -q "POSIX initial size tests passed" "$log_file"; then
  echo "POSIX initial size test did not complete successfully" >&2
  sed -n '1,200p' "$log_file" >&2
  exit 1
fi

echo "POSIX initial size tests passed"
