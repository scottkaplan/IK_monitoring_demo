import time
import random
from http.server import HTTPServer, BaseHTTPRequestHandler
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, Summary

REQUEST_COUNT = Counter('demo_requests_total', 'Total number of HTTP requests received', ['method', 'endpoint'])
ACTIVE_USERS = Gauge('demo_active_users', 'Current active users on the platform')
REQUEST_LATENCY = Histogram('demo_request_latency_seconds', 'Time spent processing request')
PAYLOAD_SIZE = Summary('demo_payload_size_bytes', 'Size of processed payloads')

class MetricServer(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
        else:
            REQUEST_COUNT.labels(method=self.command, endpoint=self.path).inc()
            ACTIVE_USERS.set(random.randint(10, 100))
            with REQUEST_LATENCY.time():
                time.sleep(random.uniform(0.01, 0.5))
            PAYLOAD_SIZE.observe(random.randint(100, 5000))
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(b"<h1>Demo App running... Traffic simulated dynamically!</h1>")

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8000), MetricServer)
    print("Server started on port 8000")
    server.serve_forever()
