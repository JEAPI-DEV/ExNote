import http.server
import socketserver
import socket
import os
import qrcode

PORT = 4080
APK_PATH = "./build/app/outputs/flutter-apk/app-release.apk"

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Connects to a dummy address to get the preferred local IP
        s.connect(('10.255.255.255', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

class CustomHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/':
            if not os.path.exists(APK_PATH):
                self.send_response(404)
                self.end_headers()
                self.wfile.write(b"APK not found on server.")
                return

            self.send_response(200)
            self.send_header('Content-Type', 'application/vnd.android.package-archive')
            self.send_header('Content-Disposition', 'attachment; filename="app-release.apk"')
            
            # Get file size
            fs = os.fstat(os.open(APK_PATH, os.O_RDONLY))
            self.send_header("Content-Length", str(fs.st_size))
            self.end_headers()
            
            with open(APK_PATH, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    if not os.path.exists(APK_PATH):
        print(f"Warning: APK not found at {APK_PATH}. Ensure it is built.")
        
    ip = get_local_ip()
    url = f"http://{ip}:{PORT}/"
    
    print(f"URL: {url}")
    print("Scan this QR code to download the APK:")
    print("========================================\n")
    
    qr = qrcode.QRCode()
    qr.add_data(url)
    qr.make(fit=True)
    qr.print_ascii(invert=True)
    
    with socketserver.TCPServer(("", PORT), CustomHandler) as httpd:
        print(f"\nServing APK on {url}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nShutting down server.")
            httpd.server_close()
