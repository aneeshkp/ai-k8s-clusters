# AI Inference Kubernetes Clusters

Easy-to-use Makefile-based setup for creating and managing Kubernetes clusters optimized for AI inference workloads. Supports both Kind (Kubernetes in Docker) and Minikube with configurations tailored for running LLMs and other AI models.

## Features

- 🚀 **Quick Setup**: One-command cluster creation
- 🔧 **AI Optimized**: Pre-configured for AI inference workloads
- 📦 **Dual Support**: Both Kind and Minikube cluster types
- 🎯 **Resource Scaling**: Easy resource configuration for different model sizes
- 🧹 **Easy Cleanup**: Simple cluster destruction
- 📊 **Monitoring Ready**: Includes metrics server and dashboard

## Prerequisites

- Docker
- kubectl
- Make
- Kind (for Kind clusters)
- Minikube (for Minikube clusters)

### Install Dependencies

```bash
# Check what's missing
make check-deps

# Install Kind
make install-kind

# Install Minikube
make install-minikube
```

## Quick Start

### Option 1: Kind Cluster (Recommended for Development)

```bash
# Quick start with Kind cluster + example vLLM deployment
make quick-kind

# Or create just the cluster
make kind-create
```

### Option 2: Minikube Cluster (Better for Resource Management)

```bash
# Quick start with Minikube cluster + example vLLM deployment
make quick-minikube

# Or create just the cluster
make minikube-create
```

## Cluster Management

### Creating Clusters

#### Model-Specific Quick Setup (Recommended)

```bash
# 🤖 SMALL Models (2-7B params) - DialoGPT, DistilBERT, small GPT
make small-complete        # Complete setup: cluster + model deployment
make small-model-minikube  # Just cluster (2 CPU, 4GB RAM, 20GB disk)
make small-model-kind      # Kind version

# 🚀 MEDIUM Models (7B-13B params) - Llama-2-7B, Mistral-7B, Code Llama
make medium-complete        # Complete setup: cluster + Llama-2-7B
make medium-model-minikube  # Just cluster (8 CPU, 16GB RAM, 100GB disk)
make medium-model-kind      # Kind version

# ⚡ LARGE Models (70B+ params) - Llama-2-70B, GPT-4 scale models
make large-complete         # Complete setup: cluster + Llama-2-70B
make large-model-minikube   # Just cluster (16 CPU, 100GB RAM, 200GB disk)
make large-model-kind       # Kind version (limited by host resources)
```

#### Traditional Setup

```bash
# Create Kind cluster (default: 2 nodes, optimized for AI)
make kind-create

# Create Minikube cluster (default: 4 CPUs, 8GB RAM, 50GB disk)
make minikube-create

# Create Minikube with custom resources for larger models
MEMORY_SIZE=16g CPUS=8 DISK_SIZE=100g make minikube-create
```

### Managing Clusters

```bash
# Check cluster status
make kind-status
make minikube-status

# Show all clusters
make status

# Destroy specific cluster
make kind-destroy
make minikube-destroy

# Destroy all clusters
make clean-all

# Model-specific cleanup
make clean-small    # Clean up small model clusters
make clean-medium   # Clean up medium model clusters
make clean-large    # Clean up large model clusters
```

## Resource Recommendations

| Model Size | CPUs | Memory | Disk | Use Case |
|------------|------|--------|------|----------|
| Small (7B params) | 4 | 8GB | 50GB | Testing, small models |
| Medium (13B params) | 8 | 16GB | 100GB | Development, medium models |
| Large (70B params) | 16 | 100GB | 200GB | Production, large models |

### Examples for Different Model Sizes

```bash
# Small models (testing)
MEMORY_SIZE=4g CPUS=2 DISK_SIZE=20g make minikube-create

# Medium models (development)
MEMORY_SIZE=16g CPUS=8 DISK_SIZE=100g make minikube-create

# Large models (production)
MEMORY_SIZE=100g CPUS=16 DISK_SIZE=200g make minikube-create
```

## AI Workload Deployment

### Deploy Example vLLM Service

```bash
# Deploy example vLLM with DialoGPT model
make deploy-vllm-example

# Access the API
make port-forward
# Now available at http://localhost:8000

# Test the API
curl http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "chat-model",
    "prompt": "Hello, how are you?",
    "max_tokens": 50
  }'
```

### Custom Model Deployment

Edit `configs/vllm-example.yaml` to use your preferred model:

```yaml
args:
- --model=meta-llama/Llama-2-7b-chat-hf  # Change this
- --host=0.0.0.0
- --port=8000
- --max-model-len=4096
- --tensor-parallel-size=1
```

## Monitoring and Debugging

```bash
# View logs from AI pods
make logs

# Port forward for local access
make port-forward

# Access Minikube dashboard (Minikube only)
minikube dashboard --profile ai-inference-minikube
```

## Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `KIND_CLUSTER_NAME` | ai-inference-kind | Kind cluster name |
| `MINIKUBE_CLUSTER_NAME` | ai-inference-minikube | Minikube cluster name |
| `NAMESPACE` | ai-inference | Kubernetes namespace |
| `MEMORY_SIZE` | 8g | Minikube memory allocation |
| `CPUS` | 4 | Minikube CPU allocation |
| `DISK_SIZE` | 50g | Minikube disk size |

### Port Mappings

| Port | Service | Description |
|------|---------|-------------|
| 8000 | vLLM API | Main model serving API |
| 30080 | Gateway | Service gateway |
| 30090 | API | Custom API endpoints |
| 30091 | Metrics | Monitoring metrics |

## File Structure

```
ai-k8s-clusters/
├── Makefile              # Main commands
├── README.md            # This file
├── scripts/
│   ├── kind-cluster.sh     # Kind cluster management
│   └── minikube-cluster.sh # Minikube cluster management
└── configs/
    └── vllm-example.yaml   # Example vLLM deployment
```

## Advanced Usage

### Multiple Clusters

You can run multiple clusters simultaneously:

```bash
# Create both cluster types
make kind-create
make minikube-create

# Check all clusters
make status

# Use specific cluster
kubectl config use-context kind-ai-inference-kind
# or
kubectl config use-context ai-inference-minikube
```

### Custom Configurations

#### Large Model Setup (Llama-70B)

```bash
# Create large Minikube cluster
MEMORY_SIZE=100g CPUS=16 DISK_SIZE=200g make minikube-create

# Edit configs/vllm-example.yaml to use larger model
# Deploy with more resources
make deploy-vllm-example
```

#### GPU Support (if available)

For GPU support, you'll need to:
1. Use Minikube with GPU driver
2. Install NVIDIA device plugin
3. Modify deployment specs to request GPUs

## Troubleshooting

### Common Issues

1. **Docker not running**
   ```bash
   sudo systemctl start docker
   ```

2. **Insufficient resources**
   ```bash
   # Increase resources
   MEMORY_SIZE=16g CPUS=8 make minikube-create
   ```

3. **Port conflicts**
   ```bash
   # Check what's using the port
   sudo netstat -tulpn | grep 8000
   ```

4. **Cluster not accessible**
   ```bash
   # Reset kubectl context
   make kind-status  # or minikube-status
   ```

### Debugging Commands

```bash
# Check cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Check resources
kubectl top nodes
kubectl top pods -n ai-inference

# View events
kubectl get events -n ai-inference --sort-by=.firstTimestamp
```

## Contributing

Feel free to modify the configurations for your specific AI workloads:

1. **Adjust resource limits** in `configs/vllm-example.yaml`
2. **Modify cluster configurations** in `scripts/`
3. **Add new deployment configs** in `configs/`
4. **Extend Makefile** with custom targets

## Quick Reference

### One-Command Complete Setup

```bash
make small-complete     # 🤖 Small models (DialoGPT, DistilBERT)
make medium-complete    # 🚀 Medium models (Llama-2-7B, Mistral-7B)
make large-complete     # ⚡ Large models (Llama-2-70B, GPT-4 scale)
```

### Cluster Only (No Model)

```bash
# Small: 2 CPU, 4GB RAM, 20GB disk
make small-model-minikube
make small-model-kind

# Medium: 8 CPU, 16GB RAM, 100GB disk
make medium-model-minikube
make medium-model-kind

# Large: 16 CPU, 100GB RAM, 200GB disk
make large-model-minikube
make large-model-kind
```

### Model Deployment Only

```bash
make deploy-small-model    # DialoGPT (default)
make deploy-medium-model   # Llama-2-7B
make deploy-large-model    # Llama-2-70B
```

### Cleanup

```bash
make clean-small     # Remove small model clusters
make clean-medium    # Remove medium model clusters
make clean-large     # Remove large model clusters
make clean-all       # Remove all clusters
```

### Testing Your Setup

```bash
# After any complete setup:
make port-forward

# Test the API:
curl -X POST http://localhost:8000/v1/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"chat-model","prompt":"Hello!","max_tokens":50}'
```

## References

- [Kind Documentation](https://kind.sigs.k8s.io/)
- [Minikube Documentation](https://minikube.sigs.k8s.io/)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)

## License

This project is open source. Feel free to use and modify as needed for your AI inference workloads.