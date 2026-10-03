from http.server import HTTPServer, BaseHTTPRequestHandler
from prometheus_client import generate_latest, CONTENT_TYPE_LATEST, Counter, Gauge, Histogram, Summary

# 1. COUNTER: Tracks total incoming client requests natively by method and path
REQUEST_COUNT = Counter('demo_requests_total', 'Total number of HTTP requests received', ['method', 'endpoint'])

# 2. GAUGE: Tracks active parameters (Can be incremented/decremented manually on connections)
ACTIVE_USERS = Gauge('demo_active_users', 'Current active users on the platform')

# 3. HISTOGRAM: Tracks the actual performance latency processing real responses
REQUEST_LATENCY = Histogram('demo_request_latency_seconds', 'Time spent processing request')

# 4. SUMMARY: Tracks the exact size bytes footprint of real processed response contents
PAYLOAD_SIZE = Summary('demo_payload_size_bytes', 'Size of processed payloads')

class MetricServer(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/metrics':
            # Serve the metrics to Prometheus cleanly without updating metrics counters
            self.send_response(200)
            self.send_header('Content-Type', CONTENT_TYPE_LATEST)
            self.end_headers()
            self.wfile.write(generate_latest())
        else:
            # Track real user activity when an endpoint is hit
            REQUEST_COUNT.labels(method=self.command, endpoint=self.path).inc()
            
            # Track performance speed of the real response pipeline execution
            with REQUEST_LATENCY.time():
                # Construct response payload content block
                response_content = b"<h1>Demo App: Request logged successfully!</h1>"
                payload_len = len(response_content)
                
                # Update metrics based on authentic data shapes
                PAYLOAD_SIZE.observe(payload_len)
                
                self.send_response(200)
                self.send_header('Content-Type', 'text/html')
                self.end_headers()
                self.wfile.write(response_content)

if __name__ == '__main__':
    server = HTTPServer(('0.0.0.0', 8000), MetricServer)
    print("Server started on port 8000")
    server.serve_forever()
