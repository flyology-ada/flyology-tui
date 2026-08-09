# POSIX bridge boundary

`src/native/flyology_tui_posix.c` exists because the relevant ABI surface is
defined through C structures and macros whose layouts differ between macOS and
Linux: `termios`, `winsize`, `pollfd`, `O_NONBLOCK`, and `FD_CLOEXEC`.

The bridge exposes only these mechanisms:

- capture, enable, and restore raw terminal attributes;
- read the terminal dimensions;
- create and flag a wake pipe;
- poll the input and wake descriptors;
- signal, drain, and close the wake descriptors.

Direct fixed-signature `read` and `write` imports remain in Ada. Ada owns input
buffering, escape timing, resize policy, error classification, output retry,
view reconciliation, cleanup ordering, and all application-visible behavior.
No application pointer, model value, command, surface, or parser state crosses
the C boundary.

The behavioral suite covers parsing and rendering without the bridge. Building
the library and counter example compiles and links the native symbols on the
host platform. A pseudoterminal integration suite is a suitable follow-up when
automated Linux and macOS runners are configured.
