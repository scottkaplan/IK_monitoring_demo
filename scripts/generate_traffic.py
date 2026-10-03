#!/usr/bin/env python3
import time
import random
import argparse
import requests

# 1. Define endpoints with realistic popularity weights
ENDPOINTS = [
    ("/home", 0.40),       # 40% of traffic hits home page
    ("/api/v1/users", 0.25), # 25% hits users API
    ("/products", 0.20),   # 20% explores products
    ("/checkout", 0.10),   # 10% initiates checkout
    ("/settings", 0.05)    # 5% views settings
]

def get_random_endpoint():
    """Selects an endpoint based on real-world popularity distribution weights."""
    paths, weights = zip(*ENDPOINTS)
    return random.choices(paths, weights=weights)[0]

def simulate_traffic(target_host, requests_per_second):
    """Generates continuous randomized traffic targeting the metric web application server."""
    base_url = f"http://{target_host.strip('/')}:8000"
    
    # Calculate the average time delay interval needed between requests
    target_interval = 1.0 / requests_per_second
    
    print(f"🚀 Starting realistic traffic generator targeting: {base_url}")
    print(f"📈 Target Rate: {requests_per_second} req/sec (Avg delay: {target_interval:.3f}s)")
    print("Press Ctrl+C to stop traffic flow.\n")
    
    request_counter = 0
    while True:
        request_counter += 1
        path = get_random_endpoint()
        url = f"{base_url}{path}"
        
        # Randomize HTTP methods to build diverse label dimensions
        method = "POST" if path == "/checkout" and random.random() < 0.3 else "GET"
        
        try:
            start_time = time.time()
            if method == "GET":
                response = requests.get(url, timeout=5)
            else:
                response = requests.post(url, json={"qty": random.randint(1, 3)}, timeout=5)
                
            duration = time.time() - start_time
            print(f"[{request_counter}] Sent {method} {path} -> Status: {response.status_code} ({duration:.3f}s)")
            
        except requests.RequestException as e:
            print(f"[{request_counter}] ❌ Connection failed to {path}: {e}")

        # Real-World Randomization: Use an exponential distribution delay pattern
        # This prevents robotic linear ticks and simulates true organic human arrival patterns
        actual_delay = random.expovariate(1.0 / target_interval)
        
        # Simulate an occasional sudden network traffic congestion spike (1% chance)
        if random.random() < 0.01:
            spike_delay = random.uniform(1.0, 3.0)
            print(f"⚠️  Simulating random network latency spike: Adding {spike_delay:.2f}s delay...")
            actual_delay += spike_delay
            
        time.sleep(actual_delay)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Organic Traffic Generator for Prometheus Demo App")
    parser.add_file_path_or_argument = parser.add_argument(
        "--host", 
        default="monitoring-demo.kaplans.com", 
        help="Target EC2 instance host domain address or IP"
    )
    parser.add_argument(
        "--rate", 
        type=float, 
        default=2.0, 
        help="Target traffic injection rate in requests per second (e.g., 0.5, 5.0, 10)"
    )
    
    args = parser.parse_args()
    
    # Simple dependency verification check
    try:
        import requests
    except ImportError:
        import sys
        print("Error: The 'requests' library is required. Run 'pip install requests' first.")
        sys.exit(1)
        
    simulate_traffic(args.host, args.rate)
