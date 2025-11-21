#!/bin/bash

# Minikube cluster management script for AI inference workloads

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values for AI inference workloads
DEFAULT_CLUSTER_NAME="ai-inference-minikube"
DEFAULT_MEMORY="8g"      # Minimum for small models
DEFAULT_CPUS="4"         # Minimum for decent performance
DEFAULT_DISK_SIZE="50g"  # Space for models and data
DEFAULT_DRIVER="docker"

# Functions
usage() {
    echo "Usage: $0 {create|destroy|status} [cluster-name] [memory] [cpus] [disk-size]"
    echo ""
    echo "Commands:"
    echo "  create   - Create a new minikube cluster"
    echo "  destroy  - Destroy an existing minikube cluster"
    echo "  status   - Show cluster status"
    echo ""
    echo "Arguments:"
    echo "  cluster-name - Name of the cluster (default: ${DEFAULT_CLUSTER_NAME})"
    echo "  memory       - Memory allocation (default: ${DEFAULT_MEMORY})"
    echo "  cpus         - CPU allocation (default: ${DEFAULT_CPUS})"
    echo "  disk-size    - Disk size (default: ${DEFAULT_DISK_SIZE})"
    echo ""
    echo "Examples:"
    echo "  $0 create                                    # Use defaults (4 CPUs, 8GB RAM, 50GB disk)"
    echo "  $0 create ai-cluster 16g 8 100g             # Large setup for bigger models"
    echo "  $0 create small-cluster 4g 2 20g            # Minimal setup for testing"
    echo ""
    echo "Resource Recommendations:"
    echo "  Small models (7B params):     4 CPUs, 8GB RAM, 50GB disk"
    echo "  Medium models (13B params):   8 CPUs, 16GB RAM, 100GB disk"
    echo "  Large models (70B params):    16 CPUs, 100GB RAM, 200GB disk"
    exit 1
}

check_prerequisites() {
    if ! command -v minikube &> /dev/null; then
        echo -e "${RED}❌ minikube is not installed. Install with:${NC}"
        echo "make install-minikube-user  # For user-space installation (no sudo)"
        echo "Or manually: curl -Lo ~/.local/bin/minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 && chmod +x ~/.local/bin/minikube"
        exit 1
    fi

    # Check for Docker or Podman
    if command -v docker &> /dev/null && docker info &> /dev/null 2>&1; then
        echo -e "${GREEN}✅ Docker found and running${NC}"
        CONTAINER_RUNTIME="docker"
    elif command -v podman &> /dev/null; then
        echo -e "${GREEN}✅ Podman found (using as Docker alternative)${NC}"
        CONTAINER_RUNTIME="podman"

        # Configure minikube for rootless podman if sudo is not available
        configure_rootless_minikube

        # Check if podman machine is running (for macOS/Windows compatibility)
        if podman machine list 2>/dev/null | grep -q "Currently running"; then
            echo -e "${GREEN}✅ Podman machine is running${NC}"
        elif podman info &> /dev/null; then
            echo -e "${GREEN}✅ Podman is accessible${NC}"
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

configure_rootless_minikube() {
    # Check if sudo is available without prompting
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}🔧 Configuring minikube for rootless podman (no sudo access)${NC}"

        # Configure minikube for rootless operation
        minikube config set rootless true
        minikube config set driver podman

        echo -e "${GREEN}✅ Minikube configured for rootless operation${NC}"
    else
        echo -e "${GREEN}✅ Sudo access available, using standard podman configuration${NC}"
    fi
}

create_cluster() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}
    local memory=${2:-$DEFAULT_MEMORY}
    local cpus=${3:-$DEFAULT_CPUS}
    local disk_size=${4:-$DEFAULT_DISK_SIZE}

    echo -e "${GREEN}🚀 Creating Minikube cluster: ${cluster_name}${NC}"
    echo -e "${BLUE}Resources: ${cpus} CPUs, ${memory} memory, ${disk_size} disk${NC}"

    # Check if cluster already exists
    if minikube profile list -o json 2>/dev/null | grep -q "\"Name\":\"${cluster_name}\""; then
        echo -e "${YELLOW}⚠️  Cluster ${cluster_name} already exists.${NC}"
        read -p "Do you want to delete it and recreate? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "${YELLOW}🗑️  Deleting existing cluster...${NC}"
            minikube delete --profile "${cluster_name}"
        else
            echo -e "${GREEN}✅ Using existing cluster${NC}"
            minikube profile "${cluster_name}"
            return 0
        fi
    fi

    # Start minikube with AI-optimized configuration
    echo -e "${GREEN}🏗️  Starting minikube cluster...${NC}"
    echo -e "${BLUE}Using container runtime: ${CONTAINER_RUNTIME}${NC}"
    minikube start \
        --profile="${cluster_name}" \
        --driver="${CONTAINER_RUNTIME}" \
        --memory="${memory}" \
        --cpus="${cpus}" \
        --disk-size="${disk_size}" \
        --kubernetes-version=v1.28.0 \
        --extra-config=kubelet.max-pods=250 \
        --extra-config=kubelet.kube-reserved=cpu=500m,memory=1Gi \
        --extra-config=kubelet.system-reserved=cpu=500m,memory=1Gi

    # Set as default profile
    minikube profile "${cluster_name}"

    # Wait for cluster to be ready
    echo -e "${GREEN}⏳ Waiting for cluster to be ready...${NC}"
    kubectl wait --for=condition=Ready nodes --all --timeout=300s

    # Enable essential addons for AI workloads
    echo -e "${GREEN}🔧 Enabling addons for AI inference...${NC}"

    # Enable metrics server for resource monitoring
    minikube addons enable metrics-server --profile="${cluster_name}"

    # Enable ingress for external access
    minikube addons enable ingress --profile="${cluster_name}"

    # Enable dashboard for monitoring (optional)
    minikube addons enable dashboard --profile="${cluster_name}"

    # Enable storage provisioner
    minikube addons enable storage-provisioner --profile="${cluster_name}"
    minikube addons enable default-storageclass --profile="${cluster_name}"

    # Enable registry for custom images (optional)
    minikube addons enable registry --profile="${cluster_name}"

    # Label nodes for AI workloads
    echo -e "${GREEN}🏷️  Labeling nodes for AI inference...${NC}"
    kubectl label nodes --all ai-inference=true --overwrite

    # Get cluster info
    echo -e "${GREEN}📊 Cluster Information:${NC}"
    echo -e "Cluster name: ${BLUE}${cluster_name}${NC}"
    echo -e "Memory: ${BLUE}${memory}${NC}"
    echo -e "CPUs: ${BLUE}${cpus}${NC}"
    echo -e "Disk size: ${BLUE}${disk_size}${NC}"
    echo ""
    echo "Nodes:"
    kubectl get nodes -o wide

    echo ""
    echo "Enabled addons:"
    minikube addons list --profile="${cluster_name}" | grep enabled

    echo -e "${GREEN}✅ Minikube cluster '${cluster_name}' is ready for AI inference!${NC}"
    echo -e "${GREEN}🎯 Quick commands:${NC}"
    echo "  kubectl get nodes"
    echo "  kubectl get pods --all-namespaces"
    echo "  minikube dashboard --profile ${cluster_name}    # open dashboard"
    echo "  minikube delete --profile ${cluster_name}       # to delete"
    echo ""
    echo -e "${GREEN}🌐 Access your AI services:${NC}"
    echo "  minikube service list --profile ${cluster_name} # list all services"
    echo "  minikube ip --profile ${cluster_name}           # get cluster IP"
    echo "  minikube tunnel --profile ${cluster_name}       # expose LoadBalancer services"
}

destroy_cluster() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}

    echo -e "${YELLOW}🗑️  Destroying Minikube cluster: ${cluster_name}${NC}"

    if ! minikube profile list -o json 2>/dev/null | grep -q "\"Name\":\"${cluster_name}\""; then
        echo -e "${YELLOW}⚠️  Cluster ${cluster_name} does not exist${NC}"
        return 0
    fi

    minikube delete --profile "${cluster_name}"
    echo -e "${GREEN}✅ Cluster ${cluster_name} destroyed successfully${NC}"
}

show_status() {
    local cluster_name=${1:-$DEFAULT_CLUSTER_NAME}

    echo -e "${GREEN}📊 Minikube cluster status: ${cluster_name}${NC}"

    if ! minikube profile list -o json 2>/dev/null | grep -q "\"Name\":\"${cluster_name}\""; then
        echo -e "${YELLOW}⚠️  Cluster ${cluster_name} does not exist${NC}"
        return 1
    fi

    # Set profile for status commands
    minikube profile "${cluster_name}"

    echo -e "${BLUE}Cluster status:${NC}"
    minikube status --profile="${cluster_name}"

    echo -e "\n${BLUE}Cluster info:${NC}"
    kubectl cluster-info

    echo -e "\n${BLUE}Nodes:${NC}"
    kubectl get nodes -o wide

    echo -e "\n${BLUE}System pods:${NC}"
    kubectl get pods --all-namespaces | grep -E "(kube-system|ingress-nginx|kubernetes-dashboard)"

    echo -e "\n${BLUE}Enabled addons:${NC}"
    minikube addons list --profile="${cluster_name}" | grep enabled

    echo -e "\n${BLUE}Resource usage:${NC}"
    kubectl top nodes 2>/dev/null || echo "Metrics not available yet. Wait a moment and try again."

    echo -e "\n${BLUE}Cluster access:${NC}"
    echo "Cluster IP: $(minikube ip --profile="${cluster_name}")"
    echo "Dashboard: minikube dashboard --profile ${cluster_name}"
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