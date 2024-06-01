#!/usr/bin/env python3

import argparse
import contextlib
import os
import socket
import subprocess
import sys
from http.server import HTTPServer, SimpleHTTPRequestHandler, test  # type: ignore
from pathlib import Path


# See cpython GH-17851 and GH-17864.
class DualStackServer(HTTPServer):
    def server_bind(self):
        # Suppress exception when protocol is IPv4.
        with contextlib.suppress(Exception):
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
        return super().server_bind()


class CORSRequestHandler(SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Access-Control-Allow-Origin", "*")
        super().end_headers()


def shell_open(url):
    if sys.platform == "win32":
        os.startfile(url)
    else:
        opener = "open" if sys.platform == "darwin" else "xdg-open"
        subprocess.call([opener, url])


def serve(root, port):
    os.chdir(root)

    test(CORSRequestHandler, DualStackServer, port=port)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--port", help="port to listen on", default=8060, type=int)
    parser.add_argument(
        "-r", "--root", help="path to serve as root (relative to current working directory)", default=".", type=Path
    )
    args = parser.parse_args()

    # Change to the directory where the script is located,
    # so that the script can be run from any location.
    os.chdir(Path(__file__).resolve().parent)

    serve(args.root, args.port)
