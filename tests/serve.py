#!/usr/bin/env python3
"""Serve DIR over HTTP on 127.0.0.1:PORT for the installer tests in tests/run.sh.

  serve.py DIR PORT

/partial/<file> sends the first 300 bytes of <file> with a much larger
Content-Length and then drops the connection, like a download cut short.
"""
import functools
import http.server
import os
import sys

ROOT, PORT = sys.argv[1], int(sys.argv[2])


class Handler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path.startswith("/partial/"):
            with open(os.path.join(ROOT, self.path[len("/partial/"):]), "rb") as f:
                body = f.read(300)
            self.send_response(200)
            self.send_header("Content-Length", "50000")
            self.end_headers()
            self.wfile.write(body)
            self.wfile.flush()
            self.close_connection = True
            return
        super().do_GET()

    def log_message(self, *args):
        pass


http.server.ThreadingHTTPServer(("127.0.0.1", PORT), functools.partial(Handler, directory=ROOT)).serve_forever()
