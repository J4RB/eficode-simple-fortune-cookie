#!/bin/bash

# --- Script to get Kubernetes node IPs, service information, and then run curl ---

echo "Starting Kubernetes information retrieval and curl execution..."
echo "----------------------------------------------------"

# 1. Get Kubernetes Nodes and their IPs (using -o wide)
echo "1. Getting Kubernetes Nodes and their IPs..."
echo "----------------------------------------------------"
kubectl_get_nodes_output=$(kubectl get nodes -o wide)
if [ $? -eq 0 ]; then
    echo "$kubectl_get_nodes_output"
else
    echo "Error: Failed to get Kubernetes nodes. Is 'kubectl' configured correctly and are you connected to a cluster?"
    exit 1
fi
echo ""

# Optional: Extract just the internal IPs for potential later use (e.g., if you wanted to curl a node directly)
# This part is commented out as it's not explicitly requested for the curl target,
# but it shows how you could process the output further.
# echo "Extracted Node Internal IPs:"
# echo "$kubectl_get_nodes_output" | awk 'NR>1 {print $6}' # Assuming IP is the 6th column for internal IP
# echo ""

# 2. Get Kubernetes Services (which often map to pods via selectors)
# Note: 'kubectl get services' shows service IPs. To get *pod* IPs, you'd typically look at `kubectl get pods -o wide`
# or describe a service/pod to see its IP. Since you asked for 'get services to get pods',
# I'll show services, but later clarify how to find pod IPs if needed for curl.
echo "2. Getting Kubernetes Services (often map to pods)..."
echo "----------------------------------------------------"
kubectl_get_services_output=$(kubectl get services)
if [ $? -eq 0 ]; then
    echo "$kubectl_get_services_output"
else
    echo "Error: Failed to get Kubernetes services. Is 'kubectl' configured correctly and are you connected to a cluster?"
    exit 1
fi
echo ""

# --- Clarification for "get services to get pods" and curl target ---
echo "--- Important Note on Services and Pods ---"
echo "While 'kubectl get services' shows service IPs, it doesn't directly show individual pod IPs."
echo "Services act as stable network endpoints that load-balance traffic to a set of pods."
echo "To curl a *specific* pod, you usually need its IP (from 'kubectl get pods -o wide') or expose it via a port-forward."
echo "However, the most common way to *curl into your cluster* from outside is via a Service that has an external IP or NodePort."
echo "----------------------------------------------------"
echo ""

# 3. Determine a target for curl
# We need an actual URL/IP and port to curl.
# This is the trickiest part as it depends on your cluster's services.
# I'll provide a placeholder example and some common scenarios.

# Common Scenarios for Curl Target:
# A) An external IP of a LoadBalancer Service
# B) A NodePort Service's IP:Port (Node IP + NodePort)
# C) An Ingress controller's IP
# D) A port-forward to a service or pod (requires an active port-forward)

# For demonstration, let's try to find an external IP from a Service.
# If no external IP is found, we'll give a generic example.

EXTERNAL_IP=""
SERVICE_PORT=""

echo "Attempting to find an external IP from Services for curl target..."
# Parse the services output to find an External IP and a port
# This is a bit fragile as format varies, but a common pattern for LoadBalancer services
while IFS= read -r line; do
    if [[ "$line" =~ "LoadBalancer" ]]; then
        # Example line: default kubernetes ClusterIP 10.96.0.1 <none> 443/TCP 1d
        # Example line: my-app LoadBalancer 10.96.10.10 34.123.45.67 80:30000/TCP 5m
        # Using awk to get the 4th field which is usually the EXTERNAL-IP, and the 5th for PORT (before /TCP)
        current_ip=$(echo "$line" | awk '{print $4}')
        current_port=$(echo "$line" | awk '{print $5}' | cut -d':' -f1 | cut -d'/' -f1) # Handles NodePort format too

        if [[ "$current_ip" != "<none>" && -n "$current_ip" && "$current_ip" != "ClusterIP" ]]; then # Filter out <none> and internal ClusterIP
            EXTERNAL_IP="$current_ip"
            SERVICE_PORT="$current_port"
            echo "Found potential external IP: $EXTERNAL_IP:$SERVICE_PORT from service line: $line"
            break # Take the first one we find
        fi
    fi
done <<< "$kubectl_get_services_output"

# If an external IP was found, use it. Otherwise, prompt the user or use a dummy.
if [ -n "$EXTERNAL_IP" ] && [ -n "$SERVICE_PORT" ]; then
    CURL_TARGET="http://$EXTERNAL_IP:$SERVICE_PORT"
    echo "Using discovered external IP: $CURL_TARGET for curl."
else
    echo "No obvious external IP found from LoadBalancer services. You might need to manually specify a target."
    echo "Common targets include (replace with actual values):"
    echo "  - http://<EXTERNAL_LOAD_BALANCER_IP>:<SERVICE_PORT>"
    echo "  - http://<NODE_IP>:<NODE_PORT> (for NodePort services)"
    echo "  - http://localhost:<LOCAL_PORT> (if using 'kubectl port-forward')"
    # SET A DUMMY TARGET OR EXIT IF YOU DON'T WANT TO RUN CURL BLINDLY
    echo "For demonstration, attempting to curl a common service within the cluster (like your API server's health endpoint if accessible directly via service name DNS)."
    echo "Note: This might not work from outside the cluster without proper routing."
    CURL_TARGET="https://kubernetes.default.svc" # Example: Internal cluster DNS for the Kubernetes API server
    # Or, if you know a service is running on a certain port on localhost (e.g., if you're tunneling):
    # CURL_TARGET="http://localhost:8080"
    echo "Using placeholder target: $CURL_TARGET"
fi

echo ""
echo "3. Running curl on the determined target: $CURL_TARGET"
echo "----------------------------------------------------"
if [[ "$CURL_TARGET" == "https://kubernetes.default.svc" ]]; then
    # For internal HTTPS targets, you often need to disable certificate verification or provide a CA.
    # For the API server, it's usually authenticated, so a direct curl might be denied.
    # This is a conceptual example. For real world, you might curl an exposed web app.
    curl_command="curl -k -s -L $CURL_TARGET" # -k for insecure, -s for silent, -L for follow redirects
else
    curl_command="curl -s -L $CURL_TARGET"
fi

echo "Executing: $curl_command"
$curl_command
if [ $? -eq 0 ]; then
    echo ""
    echo "Curl command executed successfully."
else
    echo ""
    echo "Error: Curl command failed. Check the target URL and network connectivity."
    echo "You might need to adjust the CURL_TARGET variable."
fi
echo "----------------------------------------------------"
echo "Script finished."