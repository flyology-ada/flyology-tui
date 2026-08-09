/*
 * Narrow POSIX ABI bridge for terminal layouts and pollfd. TUI policy,
 * parsing, retry decisions, rendering, and lifecycle ordering remain in Ada.
 */
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <termios.h>
#include <unistd.h>

struct flyology_tui_raw_state {
    struct termios saved;
};

void *flyology_tui_raw_enable(int fd)
{
    struct flyology_tui_raw_state *state = malloc(sizeof(*state));
    struct termios raw;

    if (state == NULL) {
        return NULL;
    }
    if (tcgetattr(fd, &state->saved) != 0) {
        free(state);
        return NULL;
    }
    raw = state->saved;
    raw.c_iflag &= (tcflag_t)~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
    raw.c_oflag &= (tcflag_t)~OPOST;
    raw.c_cflag |= CS8;
    raw.c_lflag &= (tcflag_t)~(ECHO | ICANON | IEXTEN | ISIG);
    raw.c_cc[VMIN] = 0;
    raw.c_cc[VTIME] = 0;
    if (tcsetattr(fd, TCSAFLUSH, &raw) != 0) {
        free(state);
        return NULL;
    }
    return state;
}

int flyology_tui_raw_restore(int fd, void *opaque)
{
    struct flyology_tui_raw_state *state = opaque;
    int result;

    if (state == NULL) {
        return 0;
    }
    result = tcsetattr(fd, TCSAFLUSH, &state->saved);
    free(state);
    return result;
}

int flyology_tui_terminal_size(int fd, unsigned *width, unsigned *height)
{
    struct winsize size;

    if (ioctl(fd, TIOCGWINSZ, &size) != 0) {
        return -1;
    }
    *width = size.ws_col;
    *height = size.ws_row;
    return 0;
}

static int set_descriptor_flags(int fd)
{
    int status = fcntl(fd, F_GETFL, 0);
    int descriptor = fcntl(fd, F_GETFD, 0);

    if (status < 0 || descriptor < 0) {
        return -1;
    }
    if (fcntl(fd, F_SETFL, status | O_NONBLOCK) != 0) {
        return -1;
    }
    if (fcntl(fd, F_SETFD, descriptor | FD_CLOEXEC) != 0) {
        return -1;
    }
    return 0;
}

int flyology_tui_wake_open(int *read_fd, int *write_fd)
{
    int descriptors[2];

    if (pipe(descriptors) != 0) {
        return -1;
    }
    if (set_descriptor_flags(descriptors[0]) != 0
        || set_descriptor_flags(descriptors[1]) != 0) {
        close(descriptors[0]);
        close(descriptors[1]);
        return -1;
    }
    *read_fd = descriptors[0];
    *write_fd = descriptors[1];
    return 0;
}

int flyology_tui_poll(int input_fd, int wake_fd, int timeout_ms)
{
    struct pollfd descriptors[2];
    int result;
    int ready = 0;

    memset(descriptors, 0, sizeof(descriptors));
    descriptors[0].fd = input_fd;
    descriptors[0].events = POLLIN;
    descriptors[1].fd = wake_fd;
    descriptors[1].events = POLLIN;

    do {
        result = poll(descriptors, 2, timeout_ms);
    } while (result < 0 && errno == EINTR);
    if (result < 0) {
        return -1;
    }
    if ((descriptors[0].revents & (POLLERR | POLLNVAL)) != 0
        || (descriptors[1].revents & (POLLERR | POLLHUP | POLLNVAL)) != 0) {
        return -1;
    }
    if ((descriptors[0].revents & (POLLIN | POLLHUP)) != 0) {
        ready |= 1;
    }
    if ((descriptors[1].revents & POLLIN) != 0) {
        ready |= 2;
    }
    return ready;
}

int flyology_tui_wake_signal(int fd)
{
    unsigned char byte = 1;
    ssize_t result = write(fd, &byte, sizeof(byte));

    return result == 1 || (result < 0 && errno == EAGAIN) ? 0 : -1;
}

void flyology_tui_wake_drain(int fd)
{
    unsigned char buffer[64];

    while (read(fd, buffer, sizeof(buffer)) > 0) {
    }
}

void flyology_tui_fd_close(int fd)
{
    if (fd >= 0) {
        close(fd);
    }
}
