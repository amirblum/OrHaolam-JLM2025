#!/usr/bin/env python3
"""
Simple HTTP server to test Godot web builds locally.
Serves the builds/web directory on http://localhost:8000
"""

import http.server
import socketserver
import os
import sys
from pathlib import Path

# Change to the builds/web directory
web_build_dir = Path(__file__).parent / "builds" / "web"

if not web_build_dir.exists():
    print(f"Error: Web build directory not found at {web_build_dir}")
    print("Please export your Godot project to builds/web first.")
    sys.exit(1)

os.chdir(web_build_dir)

PORT = 8000

class MyHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        # Add CORS headers for local development
        self.send_header('Cross-Origin-Opener-Policy', 'same-origin')
        self.send_header('Cross-Origin-Embedder-Policy', 'require-corp')
        super().end_headers()

    def log_message(self, format, *args):
        # Suppress default logging, or customize as needed
        pass

def main():
    with socketserver.TCPServer(("", PORT), MyHTTPRequestHandler) as httpd:
        print(f"🚀 Serving Godot web build at http://localhost:{PORT}")
        print(f"📁 Serving from: {web_build_dir}")
        print(f"\n🌐 Open your browser and navigate to: http://localhost:{PORT}")
        print(f"\nPress Ctrl+C to stop the server\n")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\nServer stopped.")

if __name__ == "__main__":
    main()

