# Docker Build & Push + Azure Container App Deployment Guide

This guide explains the complete workflow to build Docker images, push them to Azure Container Registry (ACR), and deploy them to Azure Container Apps (ACA).

## Workflow Overview

The solution uses a GitHub Actions workflow that:
1. Builds a Docker image from the Dockerfile in `currency-dashboard/`
2. Pushes the image to your Azure Container Registry (ACR)
3. Generates tags for easy reference and updates

## Prerequisites

Before using the workflow, ensure:

1. **Azure Credentials are configured in GitHub**:
   - `ARM_CLIENT_ID` - Service principal client ID
   - `ARM_TENANT_ID` - Azure tenant ID
   - `ARM_SUBSCRIPTION_ID` - Azure subscription ID
   
   Set these in your GitHub repository **Settings > Secrets and variables > Repository variables**

2. **ACR is deployed** via Terraform to your dev/stg/prd environments

3. **Container App is deployed** via Terraform

## Step 1: Deploy Infrastructure (Terraform)

First, deploy your Azure resources using Terraform:

```bash
cd terraform/environment/dev
terraform init
terraform plan
terraform apply
```

This creates:
- Resource Group
- Azure Container Registry (ACR)
- Log Analytics Workspace
- Container Apps Environment
- Container App (with placeholder image)

## Step 2: Build and Push Docker Image to ACR

### Method 1: Manual Workflow Dispatch (Recommended)

1. Go to your GitHub repository
2. Click **Actions** → **Docker Build & Push to ACR**
3. Click **Run workflow**
4. Select your environment (dev, stg, or prd)
5. Click **Run workflow**

The workflow will:
- Log into Azure using OIDC
- Build the Dockerfile
- Push to ACR with tags:
  - `<registry>/<image>:latest`
  - `<registry>/<image>:<git-sha>`
  - `<registry>/<image>:<environment>-latest`

### Method 2: Manual Docker Build (Without GitHub Actions)

```bash
# Login to ACR
az acr login --name eastusdev

# Build and push manually
az acr build \
  --registry eastusdev \
  --image currency-dashboard:latest \
  --file currency-dashboard/dockerFile \
  ./currency-dashboard
```

## Step 3: Update Container App with New Image

After the Docker image is pushed to ACR, update your Container App to use it.

### Option A: Using Terraform (Recommended for production)

Update the `container_image` variable when applying Terraform:

```bash
cd terraform/environment/dev

terraform apply \
  -var "container_image=eastusdev.azurecr.io/currency-dashboard:latest"
```

Or add to `terraform.tfvars`:

```hcl
appName = "le-app"
location = "westus2"
environment = "dev"
resource_group = "le-app-westus2-dev-rg"
container_image = "eastusdev.azurecr.io/currency-dashboard:latest"
container_port = 8080
```

### Option B: Using Azure CLI (Quick update)

Update the Container App directly without Terraform:

```bash
az containerapp update \
  --resource-group le-app-westus2-dev-rg \
  --name le-app-westus2-dev-aca \
  --image eastusdev.azurecr.io/currency-dashboard:latest
```

## Understanding the Workflow

### File Locations

- **Workflow**: [.github/workflows/docker-build-push.yml](.github/workflows/docker-build-push.yml)
- **Dockerfile**: [currency-dashboard/dockerFile](currency-dashboard/dockerFile)
- **Terraform ACR Module**: [terraform/module/azure_container_registry/](terraform/module/azure_container_registry/)
- **Terraform ACA Module**: [terraform/module/azure_container_app/](terraform/module/azure_container_app/)

### Key Variables

In the workflow:
- `REGISTRY_NAME`: ACR name (eastusdev for dev environment)
- `IMAGE_NAME`: Image name (currency-dashboard)
- `DOCKERFILE_PATH`: Path to Dockerfile
- `DOCKER_CONTEXT`: Docker build context directory

### Terraform Variables

In `terraform/module/azure_container_app/variable.tf`:
- `container_image` - Container image URI
- `container_port` - Port number (default: 8080)
- `environment_variables` - Environment variables to inject

## Complete End-to-End Example

```bash
# 1. Deploy infrastructure
cd terraform/environment/dev
terraform apply

# 2. Build and push Docker image (via GitHub Actions)
# Go to GitHub > Actions > Docker Build & Push to ACR > Run workflow > Select 'dev'

# 3. Update Container App with new image
terraform apply -var "container_image=eastusdev.azurecr.io/currency-dashboard:latest"
```

## Troubleshooting

### Workflow fails with authentication errors

Check that your GitHub repository variables are set:
```bash
Settings > Secrets and variables > Repository variables
```

Required variables:
- `ARM_CLIENT_ID`
- `ARM_TENANT_ID`
- `ARM_SUBSCRIPTION_ID`

### Docker build fails

Ensure the Dockerfile path is correct and requirements.txt exists:
```bash
ls -la currency-dashboard/
# Should show: app.py, dockerFile, requirements.txt
```

### Container App doesn't start

Check the image is accessible:
```bash
az acr repository list --name eastusdev
az acr repository show-tags --name eastusdev --repository currency-dashboard
```

Check Container App logs:
```bash
az containerapp logs show \
  --resource-group le-app-westus2-dev-rg \
  --name le-app-westus2-dev-aca
```

## Monitoring and Logs

### View ACR Build History

```bash
az acr task list-runs --registry eastusdev
```

### View Container App Logs

```bash
az containerapp logs show \
  --resource-group le-app-westus2-dev-rg \
  --name le-app-westus2-dev-aca \
  --follow
```

### Get Container App Status

```bash
az containerapp show \
  --resource-group le-app-westus2-dev-rg \
  --name le-app-westus2-dev-aca
```

## Next Steps

1. Configure GitHub OIDC authentication for secure deployments
2. Add environment-specific variables to Container Apps
3. Set up auto-scaling based on CPU/memory metrics
4. Implement health checks for the Container App
5. Add monitoring and alerting via Application Insights
