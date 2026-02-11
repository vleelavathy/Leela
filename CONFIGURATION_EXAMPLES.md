# Example Configuration Files

This document shows example configurations and commands for different environments (dev, stg, prd).

## Terraform Configuration Examples

### Dev Environment (terraform/environment/dev/terraform.tfvars)

```hcl
# Application Configuration
appName = \"le-app\"
location = \"westus2\"
environment = \"dev\"
owner = \"leela\"
resource_group = \"le-app-westus2-dev-rg\"

# Container Image Configuration
container_image = \"eastusdev.azurecr.io/currency-dashboard:latest\"
container_port = 8080

# Environment Variables for Container App
environment_variables = {
  LOG_LEVEL = \"INFO\"
  DEBUG = \"false\"
  ENVIRONMENT = \"development\"
}
```

### Staging Environment (terraform/environment/stg/terraform.tfvars)

```hcl
appName = \"le-app\"
location = \"westus2\"
environment = \"stg\"
owner = \"leela\"
resource_group = \"le-app-westus2-stg-rg\"

container_image = \"westus2stgacr.azurecr.io/currency-dashboard:stg-latest\"
container_port = 8080

environment_variables = {
  LOG_LEVEL = \"DEBUG\"
  DEBUG = \"true\"
  ENVIRONMENT = \"staging\"
}
```

### Production Environment (terraform/environment/prd/terraform.tfvars)

```hcl
appName = \"le-app\"
location = \"westus2\"
environment = \"prd\"
owner = \"leela\"
resource_group = \"le-app-westus2-prd-rg\"

container_image = \"westus2prdacr.azurecr.io/currency-dashboard:v1.0.0\"
container_port = 8080

environment_variables = {
  LOG_LEVEL = \"WARN\"
  DEBUG = \"false\"
  ENVIRONMENT = \"production\"
}
```

## GitHub Secrets Configuration

Add these to your GitHub repository at:
`Settings > Secrets and variables > Repository variables`

```yaml
# Azure Service Principal Details
ARM_CLIENT_ID: \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"
ARM_TENANT_ID: \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"
ARM_SUBSCRIPTION_ID: \"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx\"

# Optional: Environment-specific values
ACR_NAME_DEV: \"eastusdev\"
ACR_NAME_STG: \"westus2stgacr\"
ACR_NAME_PRD: \"westus2prdacr\"
```

## Azure CLI Command Examples

### Build and Push for Dev

```bash
# Login to Azure
az login

# Build and push to ACR (Dev)
az acr build \\
  --registry eastusdev \\
  --image currency-dashboard:latest \\
  --image currency-dashboard:v1.0.0 \\
  --file currency-dashboard/dockerFile \\
  ./currency-dashboard

# Verify image
az acr repository show-tags \\
  --name eastusdev \\
  --repository currency-dashboard
```

### Build and Push for Staging

```bash
# Build and push to ACR (Staging)
az acr build \\
  --registry westus2stgacr \\
  --image currency-dashboard:stg-latest \\
  --image currency-dashboard:v1.1.0 \\
  --file currency-dashboard/dockerFile \\
  ./currency-dashboard

# Tag for staging
az acr import \\
  --name westus2stgacr \\
  --source eastusdev.azurecr.io/currency-dashboard:latest \\
  --image currency-dashboard:stg-latest
```

### Deploy to Container App

```bash
# Dev Environment
az containerapp update \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --image eastusdev.azurecr.io/currency-dashboard:latest

# Staging Environment
az containerapp update \\
  --resource-group le-app-westus2-stg-rg \\
  --name le-app-westus2-stg-aca \\
  --image westus2stgacr.azurecr.io/currency-dashboard:stg-latest

# Production Environment
az containerapp update \\
  --resource-group le-app-westus2-prd-rg \\
  --name le-app-westus2-prd-aca \\
  --image westus2prdacr.azurecr.io/currency-dashboard:v1.0.0
```

## Dockerfile Example

Current Dockerfile in `currency-dashboard/dockerFile`:

```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# Azure Container Apps: expose the port you set in Ingress (use 8080)
EXPOSE 8080

CMD [\"streamlit\", \"run\", \"app.py\", \"--server.address=0.0.0.0\", \"--server.port=8080\", \"--server.headless=true\"]
```

### Optional: Multi-stage Build (for optimization)

```dockerfile
# Build stage
FROM python:3.11-slim AS builder

WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

# Runtime stage
FROM python:3.11-slim

WORKDIR /app

# Copy Python packages from builder
COPY --from=builder /root/.local /root/.local
ENV PATH=/root/.local/bin:$PATH

COPY app.py .

EXPOSE 8080

CMD [\"streamlit\", \"run\", \"app.py\", \"--server.address=0.0.0.0\", \"--server.port=8080\", \"--server.headless=true\"]
```

## requirements.txt Example

```txt
streamlit==1.28.0
pandas==2.0.0
requests==2.31.0
python-dotenv==1.0.0
```

## GitHub Actions Workflow - Customization Examples

### Example 1: Trigger on push to main

Modify `.github/workflows/docker-build-push.yml`:

```yaml
on:
  push:
    branches:
      - main
    paths:
      - 'currency-dashboard/**'
      - '.github/workflows/docker-build-push.yml'
  workflow_dispatch:
    inputs:
      environment:
        description: 'Select the environment'
        required: true
        type: choice
        options:
          - dev
          - stg
          - prd
```

### Example 2: Multi-environment build

```yaml
jobs:
  build-and-push:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        environment: [dev, stg, prd]
    env:
      ENVIRONMENT: ${{ matrix.environment }}
      
    steps:
      # ... existing steps ...
      - name: Build and Push (Dynamic)
        run: |
          if [ \"$ENVIRONMENT\" = \"dev\" ]; then
            ACR_NAME=\"eastusdev\"
            IMAGE_TAG=\"latest\"
          elif [ \"$ENVIRONMENT\" = \"stg\" ]; then
            ACR_NAME=\"westus2stgacr\"
            IMAGE_TAG=\"stg-latest\"
          else
            ACR_NAME=\"westus2prdacr\"
            IMAGE_TAG=\"v1.0.0\"
          fi
          
          # Build and push with dynamic values
          az acr build \\
            --registry $ACR_NAME \\
            --image currency-dashboard:$IMAGE_TAG \\
            --file currency-dashboard/dockerFile \\
            ./currency-dashboard
```

## Terraform Module Variables - Extended Examples

### Container App with Advanced Settings

Update `terraform/module/azure_container_app/variable.tf`:

```hcl
variable \"cpu_cores\" {
  description = \"CPU cores for container\"
  type        = number
  default     = 2
}

variable \"memory_gb\" {
  description = \"Memory in GB\"
  type        = number
  default     = 4
}

variable \"min_replicas\" {
  description = \"Minimum replicas\"
  type        = number
  default     = 1
}

variable \"max_replicas\" {
  description = \"Maximum replicas\"
  type        = number
  default     = 2
}

variable \"enable_ingress\" {
  description = \"Enable public ingress\"
  type        = bool
  default     = true
}

variable \"container_port\" {
  description = \"Container port\"
  type        = number
  default     = 8080
}

variable \"container_image\" {
  description = \"Container image URI\"
  type        = string
  default     = \"mcr.microsoft.com/azuredocs/containerapps-helloworld:latest\"
}

variable \"environment_variables\" {
  description = \"Environment variables\"
  type        = map(string)
  default     = {}
}
```

Update `terraform/module/azure_container_app/main.tf`:

```hcl
template {
  container {
    name   = \"${var.appName}-${var.location}-${var.environment}-container\"
    image  = var.container_image
    cpu    = var.cpu_cores
    memory = \"${var.memory_gb}Gi\"

    dynamic \"env\" {
      for_each = var.environment_variables
      content {
        name  = env.key
        value = env.value
      }
    }
  }

  min_replicas = var.min_replicas
  max_replicas = var.max_replicas
}

ingress {
  external_enabled = var.enable_ingress
  target_port      = var.container_port
  transport        = \"auto\"

  traffic_weight {
    latest_revision = true
    percentage      = 100
  }
}
```

## Monitoring and Logging Configuration

### Add Application Insights to Terraform

```hcl
resource \"azurerm_application_insights\" \"appinsights\" {
  name                = \"${var.appName}-${var.environment}-ai\"
  location            = var.location
  resource_group_name = var.resource_group
  application_type    = \"web\"

  tags = {
    Environment = var.environment
    Owner       = var.owner
  }
}

output \"instrumentation_key\" {
  value = azurerm_application_insights.appinsights.instrumentation_key
}
```

## Deployment Checklist Script

Create `scripts/pre-deployment-check.sh`:

```bash
#!/bin/bash

echo \"Pre-Deployment Validation\"
echo \"==========================\"
echo \"\"

# Check Azure CLI
if ! command -v az &> /dev/null; then
    echo \"❌ Azure CLI not installed\"
    exit 1
fi
echo \"✅ Azure CLI installed\"

# Check Terraform
if ! command -v terraform &> /dev/null; then
    echo \"❌ Terraform not installed\"
    exit 1
fi
echo \"✅ Terraform installed\"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo \"⚠️  Docker not installed (needed for local builds)\"
else
    echo \"✅ Docker installed\"
fi

# Check Azure login
if ! az account show &> /dev/null; then
    echo \"❌ Not logged into Azure\"
    exit 1
fi
echo \"✅ Azure login valid\"

# Check required files
echo \"\"
echo \"Checking required files...\"
files=(
    \"currency-dashboard/dockerFile\"
    \"currency-dashboard/app.py\"
    \"currency-dashboard/requirements.txt\"
    \"terraform/module/azure_container_app/main.tf\"
    \"terraform/module/azure_container_app/variable.tf\"
    \".github/workflows/docker-build-push.yml\"
)

for file in \"${files[@]}\"; do
    if [ -f \"$file\" ]; then
        echo \"✅ $file\"
    else
        echo \"❌ $file (MISSING)\"
    fi
done

echo \"\"
echo \"Validation complete!\"
```

Make it executable:
```bash
chmod +x scripts/pre-deployment-check.sh
./scripts/pre-deployment-check.sh
```
