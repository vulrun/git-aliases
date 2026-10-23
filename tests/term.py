#!/usr/bin/env python3
"""Run commands on a pseudo-terminal for tests/run.sh.

  term.py run -- CMD...
      Run CMD with a terminal as stdin/stdout and print "rc=<exit status>".

  term.py shell --shell bash|zsh --source FILE --cmd CMD [--expect TEXT] [--keys K,K,...]
      Start an interactive shell, source FILE, type CMD at the prompt and, once TEXT
      appears, send the keys (UP, DOWN, ENTER, CTRL_C or literal characters).
      Prints "rc=<status> menu=<yes|no> tty=<restored|broken>", then the output.
"""
import argparse
import os
import pty
import re
import select
import sys
import time

KEYS = {"UP": b"\x1b[A", "DOWN": b"\x1b[B", "ENTER": b"\r", "CTRL_C": b"\x03"}
SHELLS = {"bash": ["bash", "--norc", "--noprofile", "-i"], "zsh": ["zsh", "-f", "-i"]}


class Session:
    def __init__(self, argv):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvp(argv[0], argv)
        self.buf = b""
        self.pos = 0

    def read(self, timeout):
        """Read whatever arrives within timeout; False once the child has gone away."""
        ready, _, _ = select.select([self.fd], [], [], timeout)
        if not ready:
            return True
        try:
            data = os.read(self.fd, 65536)
        except OSError:
            return False
        self.buf += data
        return bool(data)

    def wait_for(self, text, timeout):
        """Wait for text after the last match; True if it showed up."""
        end = time.time() + timeout
        while time.time() < end:
            at = self.buf.find(text, self.pos)
            if at >= 0:
                self.pos = at + len(text)
                return True
            if not self.read(0.05):
                return False
        return False

    def type(self, line):
        os.write(self.fd, line.encode() + b"\r")

    def finish(self):
        while self.read(0.2):
            pass
        _, status = os.waitpid(self.pid, 0)
        os.close(self.fd)
        return os.waitstatus_to_exitcode(status)


def run(argv):
    session = Session(argv)
    end = time.time() + 60
    while time.time() < end and session.read(0.1):
        pass
    print(f"rc={session.finish()}")


def shell(args):
    s = Session(SHELLS[args.shell])
    time.sleep(0.5)
    # markers are split in what we type so the terminal's echo can't match them
    s.type("PS1='__P''ROMPT__ '")
    s.wait_for(b"__PROMPT__", 10)
    s.type(f'source "{args.source}" > /dev/null 2>&1')
    s.wait_for(b"__PROMPT__", 10)
    start = len(s.buf)
    s.type(args.cmd)
    menu = s.wait_for(args.expect.encode(), 5) if args.keys else False
    for key in filter(None, (args.keys or "").split(",")):
        time.sleep(0.2)
        os.write(s.fd, KEYS.get(key, key.encode()))
    s.wait_for(b"__PROMPT__", 30)
    output = s.buf[start:].decode(errors="replace")
    mark = len(s.buf)
    s.type('echo "__R""C__=$?"; stty -a; echo "__DO""NE__"')
    s.wait_for(b"__DONE__", 10)
    tail = s.buf[mark:].decode(errors="replace")
    s.type("exit")
    s.finish()
    # only the printed text between the markers, not the echo of what we typed
    found = re.search(r"__RC__=(\d+)(.*?)__DONE__", tail, re.S)
    flags = set(re.findall(r"(?<![\w-])(-?(?:icanon|echo))(?![\w-])", found.group(2))) if found else set()
    tty = "restored" if {"icanon", "echo"} <= flags else "broken"
    print(f"rc={found.group(1) if found else '?'} menu={'yes' if menu else 'no'} tty={tty}")
    print(re.sub(r"\x1b\[[0-9;?]*[A-Za-z]|\r", "", output))


def main():
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="mode", required=True)
    p_run = sub.add_parser("run")
    p_run.add_argument("argv", nargs=argparse.REMAINDER)
    p_shell = sub.add_parser("shell")
    p_shell.add_argument("--shell", choices=SHELLS, default="bash")
    p_shell.add_argument("--source", required=True)
    p_shell.add_argument("--cmd", required=True)
    p_shell.add_argument("--expect", default="")
    p_shell.add_argument("--keys", default="")
    args = parser.parse_args()
    if args.mode == "run":
        run(args.argv[1:] if args.argv[:1] == ["--"] else args.argv)
    else:
        shell(args)


if __name__ == "__main__":
    sys.exit(main())
