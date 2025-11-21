#!/bin/bash

# Kind cluster management script for AI inference workloads

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DEFAULT_CLUSTER_NAME="ai-inference-kind"
DEFAULT_GATEWAY_PORT="30080"
DEFAULT_API_PORT="30090"
DEFAULT_METRICS_PORT="30091"

# Functions
usage() {
    echo "Usage: $0 {create|destroy|status} [cluster-name] [gateway-port] [api-port] [metrics-port]"
    echo ""
    echo "Commands:"
    echo "  create   - Create a new kind cluster"
    echo "  destroy  - Destroy an existing kind cluster"
    echo "  status   - Show cluster status"
    echo ""
    echo "Arguments:"
    echo "  cluster-name   - Name of the cluster (default: ${DEFAULT_CLUSTER_NAME})"
    echo "  gateway-port   - Gateway service port (default: ${DEFAULT_GATEWAY_PORT})"
    echo "  api-port       - API service port (default: ${DEFAULT_API_PORT})"
    echo "  metrics-port   - Metrics port (default: ${DEFAULT_METRICS_PORT})"
    exit 1
}

check_prerequisites() {
    if ! command -v kind &> /dev/null; then
        echo -e "${RED}❌ kind is not installed. Install with: curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64 && chmod +x ./kind && sudo mv ./kind /usr/local/bin/kind${NC}"
        exit 1
    fi

    # Check for Docker or Podman
    if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker found and running${NC}"
        CONTAINER_RUNTIME="docker"
    elif command -v podman &> /dev/null; then
        echo -e "${GREEN}✅ Podman found (using as Docker alternative)${NC}"
        CONTAINER_RUNTIME="podman"
        # For Kind with Podman, we need to ensure rootless mode is properly configured
        if podman info &> /dev/null; then
            echo -e "${GREEN}✅ Podman is accessible${NC}"
            # Check if we need to set up docker alias for kind
            if ! command -v docker &> /dev/null; then
                echo -e "${YELLOW}💡 Kind expects 'docker' command. Consider creating alias:${NC}"
                echo -e "${YELLOW}   alias docker=podman${NC}"
                echo -e "${YELLOW}   Or: sudo ln -s \$(which podman) /usr/local/bin/docker${NC}"
            fi
        else
            echo -e "${YELLOW}⚠️  Podman found but may need configuration. Trying to continue...${NC}"
        fi
    else
        echo -e "${RED}❌ Neither Docker nor Podman is available or running.${NC}"
        echo -e "${YELLOW}Please install and start one of:${NC}"
        echo "- Docker: https://docs.docker.com/engine/install/"
        echo "- Podman: sudo dnf install podman (Fedora/RHEL) or sudo apt install podman-docker (Ubuntu)"
        exit 1
    fi
}

create_cluster() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}
    local gateway_port=${2:-$DEFAULT_GATEWAY_PORT}
    local api_port=${3:-$DEFAULT_API_PORT}
    local metrics_port=${4:-$DEFAULT_METRICS_PORT}

    echo -e "${GREEN}🚀 Creating Kind cluster: ${cluster_name}${NC}"

    # Check if cluster already exists
    if kind get clusters | grep -q "^${cluster_name}$"; then
        echo -e "${YELLOW}⚠️  Cluster ${cluster_name} already exists.${NC}"
        read -p "Do you want to delete it and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}🗑️  Deleting existing cluster...${NC}"
            kind delete cluster --name "${cluster_name}"
        else
            echo -e "${GREEN}✅ Using existing cluster${NC}"
            return 0
        fi
    fi

    # Create kind config file optimized for AI inference
    local config_file="/tmp/kind-config-${cluster_name}.yaml"
    cat > "${config_file}" << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ${cluster_name}
nodes:
# Control-plane node with high resources for AI workloads
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true,ai-inference=true"
        max-pods: "250"
        kube-reserved: "cpu=500m,memory=1Gi"
        system-reserved: "cpu=500m,memory=1Gi"
  extraPortMappings:
  # Standard web ports
  - containerPort: 80
    hostPort: 80
    protocol: TCP
  - containerPort: 443
    hostPort: 443
    protocol: TCP
  # AI inference service ports
  - containerPort: ${gateway_port}
    hostPort: ${gateway_port}
    protocol: TCP
  - containerPort: ${api_port}
    hostPort: ${api_port}
    protocol: TCP
  - containerPort: ${metrics_port}
    hostPort: ${metrics_port}
    protocol: TCP
  # vLLM default ports
  - containerPort: 8000
    hostPort: 8000
    protocol: TCP
  # Additional ports for model serving
  - containerPort: 8001
    hostPort: 8001
    protocol: TCP
  - containerPort: 8080
    hostPort: 8080
    protocol: TCP
# Worker node optimized for AI inference
- role: worker
  kubeadmConfigPatches:
  - |
    kind: JoinConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "node-type=worker,ai-inference=true"
        max-pods: "250"
        kube-reserved: "cpu=500m,memory=2Gi"
        system-reserved: "cpu=500m,memory=1Gi"
EOF

    echo -e "${GREEN}📝 Created cluster configuration for AI inference${NC}"

    # Create the cluster
    echo -e "${GREEN}🏗️  Creating kind cluster...${NC}"
    kind create cluster --config="${config_file}"

    # Wait for cluster to be ready
    echo -e "${GREEN}⏳ Waiting for cluster to be ready...${NC}"
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    # Apply additional configurations for AI workloads
    echo -e "${GREEN}🔧 Configuring cluster for AI inference...${NC}"

    # Install metrics server for resource monitoring
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

    # Patch metrics server for kind
    kubectl patch deployment metrics-server -n kube-system --type='json' \
        -p='[{"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"}]'

    # Install NGINX Ingress Controller for AI services
    echo -e "${GREEN}📦 Installing NGINX Ingress Controller...${NC}"
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

    echo -e "${GREEN}⏳ Waiting for ingress controller to be ready...${NC}"
    kubectl wait --namespace ingress-nginx \
      --for=condition=ready pod \
      --selector=app.kubernetes.io/component=controller \
      --timeout=300s

    # Clean up config file
    rm -f "${config_file}"

    # Get cluster info
    echo -e "${GREEN}📊 Cluster Information:${NC}"
    echo -e "Cluster name: ${BLUE}${cluster_name}${NC}"
    echo -e "Gateway port: ${BLUE}${gateway_port}${NC}"
    echo -e "API port: ${BLUE}${api_port}${NC}"
    echo -e "Metrics port: ${BLUE}${metrics_port}${NC}"
    echo ""
    echo "Nodes:"
    kubectl get nodes -o wide

    echo -e "${GREEN}✅ Kind cluster '${cluster_name}' is ready for AI inference!${NC}"
    echo -e "${GREEN}🎯 Quick commands:${NC}"
    echo "  kubectl get nodes"
    echo "  kubectl get pods --all-namespaces"
    echo "  kind delete cluster --name ${cluster_name}  # to delete"
    echo ""
    echo -e "${GREEN}🌐 Access your AI services:${NC}"
    echo "  localhost:8000 (vLLM API)"
    echo "  localhost:${gateway_port} (Gateway)"
    echo "  localhost:${api_port} (API)"
    echo "  localhost:${metrics_port} (Metrics)"
}

destroy_cluster() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}

    echo -e "${YELLOW}🗑️  Destroying Kind cluster: ${cluster_name}${NC}"

    if ! kind get clusters | grep -q "^${cluster_name}$"; then
        echo -e "${YELLOW}⚠️  Cluster ${cluster_name} does not exist${NC}"
        return 0
    fi

    kind delete cluster --name "${cluster_name}"
    echo -e "${GREEN}✅ Cluster ${cluster_name} destroyed successfully${NC}"
}

show_status() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}

    echo -e "${GREEN}📊 Kind cluster status: ${cluster_name}${NC}"

    if ! kind get clusters | grep -q "^${cluster_name}$"; then
        echo -e "${YELLOW}⚠️  Cluster ${cluster_name} does not exist${NC}"
        return 1
    fi

    echo -e "${BLUE}Cluster exists and kubectl context:${NC}"
    kubectl cluster-info --context "kind-${cluster_name}"

    echo -e "\n${BLUE}Nodes:${NC}"
    kubectl get nodes -o wide

    echo -e "\n${BLUE}System pods:${NC}"
    kubectl get pods --all-namespaces | grep -E "(kube-system|ingress-nginx|metrics-server)"

    echo -e "\n${BLUE}Available contexts:${NC}"
    kubectl config get-contexts
}

# Main script logic
case "${1:-}" in
    create)
        check_prerequisites
        create_cluster "$2" "$3" "$4" "$5"
        ;;
    destroy)
        check_prerequisites
        destroy_cluster "$2"
        ;;
    status)
        check_prerequisites
        show_status "$2"
        ;;
    *)
        usage
        ;;
esac