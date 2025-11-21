# AI Inference Kubernetes Clusters
# Supports both Kind and Minikube for local development

# Cluster Configuration
KIND_CLUSTER_NAME ?= ai-inference-kind
MINIKUBE_CLUSTER_NAME ?= ai-inference-minikube
NAMESPACE ?= ai-inference

# Ports for AI services
GATEWAY_PORT ?= 30080
API_PORT ?= 30090
METRICS_PORT ?= 30091

# Resource Configuration for AI Workloads
MEMORY_SIZE ?= 8g
CPUS ?= 4
DISK_SIZE ?= 50g
# For larger models (like Llama-70B), increase these:
# MEMORY_SIZE ?= 100g
# CPUS ?= 16
# DISK_SIZE ?= 200g

# Container Runtime
CONTAINER_RUNTIME ?= docker

.PHONY: help
help: ## Show this comprehensive help message
	@echo '🚀 AI Inference Kubernetes Clusters'
	@echo '=================================='
	@echo ''
	@echo '📋 QUICK START (One-Command Complete Setup):'
	@echo '  make small-complete     🤖 Small models (DialoGPT, DistilBERT) - 2 CPU, 4GB RAM'
	@echo '  make medium-complete    🚀 Medium models (Llama-2-7B, Mistral-7B) - 8 CPU, 16GB RAM'
	@echo '  make large-complete     ⚡ Large models (Llama-2-70B, GPT-4 scale) - 16 CPU, 100GB RAM'
	@echo ''
	@echo '🎯 MODEL-SPECIFIC CLUSTER CREATION:'
	@echo '  make small-model-minikube   Create Minikube cluster for small models (2 CPU, 4GB RAM, 20GB disk)'
	@echo '  make small-model-kind       Create Kind cluster for small models'
	@echo '  make medium-model-minikube  Create Minikube cluster for medium models (8 CPU, 16GB RAM, 100GB disk)'
	@echo '  make medium-model-kind      Create Kind cluster for medium models'
	@echo '  make large-model-minikube   Create Minikube cluster for large models (16 CPU, 100GB RAM, 200GB disk)'
	@echo '  make large-model-kind       Create Kind cluster for large models'
	@echo ''
	@echo '🤖 MODEL DEPLOYMENT (Requires existing cluster):'
	@echo '  make deploy-small-model     Deploy DialoGPT (small model example)'
	@echo '  make deploy-medium-model    Deploy Llama-2-7B (medium model)'
	@echo '  make deploy-large-model     Deploy Llama-2-70B (large model)'
	@echo ''
	@echo '⚙️  TRADITIONAL CLUSTER OPERATIONS:'
	@echo '  make kind-create            Create default Kind cluster (2 nodes)'
	@echo '  make kind-destroy           Destroy Kind cluster'
	@echo '  make kind-status            Show Kind cluster status'
	@echo '  make minikube-create        Create default Minikube cluster (4 CPU, 8GB RAM)'
	@echo '  make minikube-destroy       Destroy Minikube cluster'
	@echo '  make minikube-status        Show Minikube cluster status'
	@echo ''
	@echo '🔍 MONITORING & ACCESS:'
	@echo '  make status                 Show status of all clusters'
	@echo '  make logs                   Show logs from AI inference pods'
	@echo '  make port-forward           Forward ports for local access (http://localhost:8000)'
	@echo ''
	@echo '📦 SETUP & DEPENDENCIES:'
	@echo '  make check-deps             Check if required dependencies are installed'
	@echo '  make install-kind           Install Kind'
	@echo '  make install-minikube       Install Minikube'
	@echo '  make setup-namespace        Create ai-inference namespace'
	@echo ''
	@echo '🧹 CLEANUP OPTIONS:'
	@echo '  make clean-small            Clean up small model clusters'
	@echo '  make clean-medium           Clean up medium model clusters'
	@echo '  make clean-large            Clean up large model clusters'
	@echo '  make clean-all              Destroy all clusters (Kind and Minikube)'
	@echo '  make remove-vllm-example    Remove example vLLM service'
	@echo ''
	@echo '⚡ QUICK EXAMPLES:'
	@echo '  make deploy-vllm-example    Deploy example vLLM service'
	@echo '  make quick-kind             Quick start with Kind cluster'
	@echo '  make quick-minikube         Quick start with Minikube cluster'
	@echo ''
	@echo '💡 RESOURCE RECOMMENDATIONS:'
	@echo '  Small models (2-7B):    2 CPU, 4GB RAM, 20GB disk   - Testing, lightweight models'
	@echo '  Medium models (7B-13B): 8 CPU, 16GB RAM, 100GB disk - Development, standard models'
	@echo '  Large models (70B+):    16 CPU, 100GB RAM, 200GB disk - Production, enterprise models'
	@echo ''
	@echo '🔧 ENVIRONMENT VARIABLES:'
	@echo '  MEMORY_SIZE=16g             Override memory allocation for Minikube'
	@echo '  CPUS=8                      Override CPU allocation for Minikube'
	@echo '  DISK_SIZE=100g              Override disk size for Minikube'
	@echo '  KIND_CLUSTER_NAME=my-kind   Override Kind cluster name'
	@echo '  MINIKUBE_CLUSTER_NAME=my-mb Override Minikube cluster name'
	@echo '  NAMESPACE=my-ai             Override Kubernetes namespace'
	@echo ''
	@echo '🧪 TESTING YOUR SETUP:'
	@echo '  1. Run any *-complete target'
	@echo '  2. make port-forward'
	@echo '  3. curl -X POST http://localhost:8000/v1/completions \'
	@echo '     -H "Content-Type: application/json" \'
	@echo '     -d '\''{"model":"chat-model","prompt":"Hello!","max_tokens":50}'\'''
	@echo ''
	@echo 'For detailed help: make help-detailed'

.PHONY: help-detailed
help-detailed: ## Show detailed help with all targets and descriptions
	@echo 'AI Inference Kubernetes Clusters - Detailed Help'
	@echo '==============================================='
	@echo ''
	@echo 'All Available Targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-25s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: help-quick
help-quick: ## Show just the most common commands
	@echo '🚀 AI K8s Clusters - Quick Commands'
	@echo '================================='
	@echo ''
	@echo 'Most Common:'
	@echo '  make small-complete     🤖 Complete small model setup'
	@echo '  make medium-complete    🚀 Complete medium model setup'
	@echo '  make large-complete     ⚡ Complete large model setup'
	@echo '  make status             📊 Show all cluster status'
	@echo '  make clean-all          🧹 Remove all clusters'
	@echo ''
	@echo 'Access:'
	@echo '  make port-forward       🌐 Access API at localhost:8000'
	@echo '  make logs              📋 View AI pod logs'
	@echo ''
	@echo 'For full help: make help'

.PHONY: list
list: help-quick ## Alias for help-quick

## Kind Cluster Targets
.PHONY: kind-create
kind-create: ## Create Kind cluster optimized for AI inference
	@echo "🚀 Creating Kind cluster: $(KIND_CLUSTER_NAME)"
	@./scripts/kind-cluster.sh create $(KIND_CLUSTER_NAME) $(GATEWAY_PORT) $(API_PORT) $(METRICS_PORT)

.PHONY: kind-destroy
kind-destroy: ## Destroy Kind cluster
	@echo "🗑️  Destroying Kind cluster: $(KIND_CLUSTER_NAME)"
	@./scripts/kind-cluster.sh destroy $(KIND_CLUSTER_NAME)

.PHONY: kind-status
kind-status: ## Show Kind cluster status
	@echo "📊 Kind cluster status:"
	@./scripts/kind-cluster.sh status $(KIND_CLUSTER_NAME)

## Minikube Cluster Targets
.PHONY: minikube-create
minikube-create: ## Create Minikube cluster optimized for AI inference
	@echo "🚀 Creating Minikube cluster: $(MINIKUBE_CLUSTER_NAME)"
	@./scripts/minikube-cluster.sh create $(MINIKUBE_CLUSTER_NAME) $(MEMORY_SIZE) $(CPUS) $(DISK_SIZE)

.PHONY: minikube-destroy
minikube-destroy: ## Destroy Minikube cluster
	@echo "🗑️  Destroying Minikube cluster: $(MINIKUBE_CLUSTER_NAME)"
	@./scripts/minikube-cluster.sh destroy $(MINIKUBE_CLUSTER_NAME)

.PHONY: minikube-status
minikube-status: ## Show Minikube cluster status
	@echo "📊 Minikube cluster status:"
	@./scripts/minikube-cluster.sh status $(MINIKUBE_CLUSTER_NAME)

## Common Cluster Operations
.PHONY: status
status: ## Show status of all clusters
	@echo "🔍 Checking all clusters..."
	@echo "=== Kind Clusters ==="
	@kind get clusters 2>/dev/null || echo "No Kind clusters found"
	@echo ""
	@echo "=== Minikube Clusters ==="
	@minikube profile list 2>/dev/null || echo "No Minikube clusters found"

.PHONY: clean-all
clean-all: ## Destroy all clusters (Kind and Minikube)
	@echo "🧹 Cleaning up all clusters..."
	@$(MAKE) kind-destroy || true
	@$(MAKE) minikube-destroy || true
	@echo "✅ All clusters destroyed"

.PHONY: setup-namespace
setup-namespace: ## Create namespace for AI inference workloads
	@echo "📦 Setting up namespace: $(NAMESPACE)"
	@kubectl create namespace $(NAMESPACE) --dry-run=client -o yaml | kubectl apply -f -
	@kubectl label namespace $(NAMESPACE) name=$(NAMESPACE) --overwrite

## AI Inference Specific Targets
.PHONY: deploy-vllm-example
deploy-vllm-example: setup-namespace ## Deploy example vLLM service
	@echo "🤖 Deploying vLLM example to namespace: $(NAMESPACE)"
	@kubectl apply -f configs/vllm-example.yaml -n $(NAMESPACE)

.PHONY: remove-vllm-example
remove-vllm-example: ## Remove example vLLM service
	@echo "🗑️  Removing vLLM example from namespace: $(NAMESPACE)"
	@kubectl delete -f configs/vllm-example.yaml -n $(NAMESPACE) --ignore-not-found

## Monitoring and Debugging
.PHONY: logs
logs: ## Show logs from AI inference pods
	@echo "📋 AI inference pod logs:"
	@kubectl get pods -n $(NAMESPACE)
	@echo ""
	@kubectl logs -l app=vllm -n $(NAMESPACE) --tail=50 --follow=false || true

.PHONY: port-forward
port-forward: ## Forward ports for local access
	@echo "🌐 Setting up port forwarding..."
	@echo "vLLM API will be available at: http://localhost:8000"
	@kubectl port-forward -n $(NAMESPACE) svc/vllm-service 8000:8000

## Prerequisites Check
.PHONY: check-deps
check-deps: ## Check if required dependencies are installed
	@echo "🔍 Checking dependencies..."
	@command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
	@command -v kubectl >/dev/null 2>&1 || { echo "❌ kubectl is required but not installed."; exit 1; }
	@command -v kind >/dev/null 2>&1 || echo "⚠️  Kind not found. Run 'make install-kind' to install."
	@command -v minikube >/dev/null 2>&1 || echo "⚠️  Minikube not found. Run 'make install-minikube' to install."
	@echo "✅ Dependency check complete"

.PHONY: install-kind
install-kind: ## Install Kind
	@echo "📥 Installing Kind..."
	@curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
	@chmod +x ./kind
	@sudo mv ./kind /usr/local/bin/kind
	@echo "✅ Kind installed successfully"

.PHONY: install-minikube
install-minikube: ## Install Minikube
	@echo "📥 Installing Minikube..."
	@curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
	@sudo install minikube-linux-amd64 /usr/local/bin/minikube
	@rm -f minikube-linux-amd64
	@echo "✅ Minikube installed successfully"

## Model Size Specific Targets
.PHONY: small-model-kind
small-model-kind: check-deps ## Create Kind cluster for small models (DialoGPT, small BERT)
	@echo "🤖 Creating Kind cluster for SMALL models (2-7B params)"
	@echo "💡 Suitable for: DialoGPT, DistilBERT, small GPT models"
	@KIND_CLUSTER_NAME=ai-small-kind $(MAKE) kind-create
	@KIND_CLUSTER_NAME=ai-small-kind $(MAKE) setup-namespace
	@echo "✅ Small model cluster ready! Resources: Kind cluster optimized for small models"

.PHONY: small-model-minikube
small-model-minikube: check-deps ## Create Minikube cluster for small models (2 CPU, 4GB RAM, 20GB disk)
	@echo "🤖 Creating Minikube cluster for SMALL models (2-7B params)"
	@echo "💡 Suitable for: DialoGPT, DistilBERT, small GPT models"
	@MINIKUBE_CLUSTER_NAME=ai-small-minikube MEMORY_SIZE=4g CPUS=2 DISK_SIZE=20g $(MAKE) minikube-create
	@MINIKUBE_CLUSTER_NAME=ai-small-minikube $(MAKE) setup-namespace
	@echo "✅ Small model cluster ready! Resources: 2 CPU, 4GB RAM, 20GB disk"

.PHONY: medium-model-kind
medium-model-kind: check-deps ## Create Kind cluster for medium models (Llama-7B, Llama-13B)
	@echo "🚀 Creating Kind cluster for MEDIUM models (7B-13B params)"
	@echo "💡 Suitable for: Llama-2-7B, Llama-2-13B, Code Llama, Mistral-7B"
	@KIND_CLUSTER_NAME=ai-medium-kind $(MAKE) kind-create
	@KIND_CLUSTER_NAME=ai-medium-kind $(MAKE) setup-namespace
	@echo "✅ Medium model cluster ready! Resources: Kind cluster optimized for medium models"

.PHONY: medium-model-minikube
medium-model-minikube: check-deps ## Create Minikube cluster for medium models (8 CPU, 16GB RAM, 100GB disk)
	@echo "🚀 Creating Minikube cluster for MEDIUM models (7B-13B params)"
	@echo "💡 Suitable for: Llama-2-7B, Llama-2-13B, Code Llama, Mistral-7B"
	@MINIKUBE_CLUSTER_NAME=ai-medium-minikube MEMORY_SIZE=16g CPUS=8 DISK_SIZE=100g $(MAKE) minikube-create
	@MINIKUBE_CLUSTER_NAME=ai-medium-minikube $(MAKE) setup-namespace
	@echo "✅ Medium model cluster ready! Resources: 8 CPU, 16GB RAM, 100GB disk"

.PHONY: large-model-kind
large-model-kind: check-deps ## Create Kind cluster for large models (Llama-70B, large foundation models)
	@echo "⚡ Creating Kind cluster for LARGE models (70B+ params)"
	@echo "💡 Suitable for: Llama-2-70B, GPT-4 scale models, large foundation models"
	@echo "⚠️  Note: Kind clusters share host resources. Consider using large-model-minikube for better resource control."
	@KIND_CLUSTER_NAME=ai-large-kind $(MAKE) kind-create
	@KIND_CLUSTER_NAME=ai-large-kind $(MAKE) setup-namespace
	@echo "✅ Large model cluster ready! Resources: Kind cluster (resource-limited by host)"

.PHONY: large-model-minikube
large-model-minikube: check-deps ## Create Minikube cluster for large models (16 CPU, 100GB RAM, 200GB disk)
	@echo "⚡ Creating Minikube cluster for LARGE models (70B+ params)"
	@echo "💡 Suitable for: Llama-2-70B, GPT-4 scale models, large foundation models"
	@echo "⚠️  WARNING: This requires significant host resources!"
	@MINIKUBE_CLUSTER_NAME=ai-large-minikube MEMORY_SIZE=100g CPUS=16 DISK_SIZE=200g $(MAKE) minikube-create
	@MINIKUBE_CLUSTER_NAME=ai-large-minikube $(MAKE) setup-namespace
	@echo "✅ Large model cluster ready! Resources: 16 CPU, 100GB RAM, 200GB disk"

## Quick Model Deployment Targets
.PHONY: deploy-small-model
deploy-small-model: ## Deploy example small model (requires small model cluster)
	@echo "🤖 Deploying small model example..."
	@kubectl create namespace ai-inference --dry-run=client -o yaml | kubectl apply -f -
	@kubectl apply -f configs/vllm-example.yaml -n ai-inference
	@echo "✅ Small model deployed! Access with: make port-forward"

.PHONY: deploy-medium-model
deploy-medium-model: ## Deploy medium model configuration
	@echo "🚀 Deploying medium model configuration..."
	@kubectl create namespace ai-inference --dry-run=client -o yaml | kubectl apply -f -
	@sed 's/microsoft\/DialoGPT-medium/meta-llama\/Llama-2-7b-chat-hf/g; s/2048/4096/g; s/cpu: "2"/cpu: "4"/g; s/memory: "4Gi"/memory: "8Gi"/g; s/cpu: "4"/cpu: "8"/g; s/memory: "8Gi"/memory: "16Gi"/g' configs/vllm-example.yaml | kubectl apply -f - -n ai-inference
	@echo "✅ Medium model deployed! Access with: make port-forward"

.PHONY: deploy-large-model
deploy-large-model: ## Deploy large model configuration
	@echo "⚡ Deploying large model configuration..."
	@kubectl create namespace ai-inference --dry-run=client -o yaml | kubectl apply -f -
	@sed 's/microsoft\/DialoGPT-medium/meta-llama\/Llama-2-70b-chat-hf/g; s/2048/8192/g; s/tensor-parallel-size=1/tensor-parallel-size=2/g; s/cpu: "2"/cpu: "8"/g; s/memory: "4Gi"/memory: "32Gi"/g; s/cpu: "4"/cpu: "16"/g; s/memory: "8Gi"/memory: "64Gi"/g' configs/vllm-example.yaml | kubectl apply -f - -n ai-inference
	@echo "✅ Large model deployed! Access with: make port-forward"

## Complete Model-Specific Workflows
.PHONY: small-complete
small-complete: small-model-minikube deploy-small-model ## Complete setup for small models (cluster + deployment)
	@echo "🎉 Complete small model environment ready!"
	@echo "🌐 Run 'make port-forward' to access the API at http://localhost:8000"
	@echo "🧪 Test with: curl -X POST http://localhost:8000/v1/completions -H 'Content-Type: application/json' -d '{\"model\":\"chat-model\",\"prompt\":\"Hello!\",\"max_tokens\":50}'"

.PHONY: medium-complete
medium-complete: medium-model-minikube deploy-medium-model ## Complete setup for medium models (cluster + deployment)
	@echo "🎉 Complete medium model environment ready!"
	@echo "🌐 Run 'make port-forward' to access the API at http://localhost:8000"
	@echo "⚠️  Note: First startup may take time to download Llama-2-7B model"

.PHONY: large-complete
large-complete: large-model-minikube deploy-large-model ## Complete setup for large models (cluster + deployment)
	@echo "🎉 Complete large model environment ready!"
	@echo "🌐 Run 'make port-forward' to access the API at http://localhost:8000"
	@echo "⚠️  WARNING: First startup may take 30+ minutes to download Llama-2-70B model"
	@echo "💡 Monitor with: kubectl logs -f deployment/vllm-deployment -n ai-inference"

## Cleanup by Model Size
.PHONY: clean-small
clean-small: ## Clean up small model clusters
	@echo "🧹 Cleaning up small model clusters..."
	@kind delete cluster --name ai-small-kind 2>/dev/null || true
	@minikube delete --profile ai-small-minikube 2>/dev/null || true
	@echo "✅ Small model clusters cleaned"

.PHONY: clean-medium
clean-medium: ## Clean up medium model clusters
	@echo "🧹 Cleaning up medium model clusters..."
	@kind delete cluster --name ai-medium-kind 2>/dev/null || true
	@minikube delete --profile ai-medium-minikube 2>/dev/null || true
	@echo "✅ Medium model clusters cleaned"

.PHONY: clean-large
clean-large: ## Clean up large model clusters
	@echo "🧹 Cleaning up large model clusters..."
	@kind delete cluster --name ai-large-kind 2>/dev/null || true
	@minikube delete --profile ai-large-minikube 2>/dev/null || true
	@echo "✅ Large model clusters cleaned"

## Quick Start
.PHONY: quick-kind
quick-kind: check-deps kind-create setup-namespace deploy-vllm-example ## Quick start with Kind cluster
	@echo "🎉 Kind cluster ready for AI inference!"
	@echo "Run 'make port-forward' to access vLLM API locally"

.PHONY: quick-minikube
quick-minikube: check-deps minikube-create setup-namespace deploy-vllm-example ## Quick start with Minikube cluster
	@echo "🎉 Minikube cluster ready for AI inference!"
	@echo "Run 'make port-forward' to access vLLM API locally"