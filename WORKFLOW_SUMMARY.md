# Docker Build & Deploy Workflow Setup - Summary

## 📋 What Was Created

This setup integrates Docker image building, Azure Container Registry (ACR), and Azure Container Apps (ACA) deployment.

### 1. GitHub Actions Workflow
**File**: [.github/workflows/docker-build-push.yml](.github/workflows/docker-build-push.yml)

**Features**:
- Manual trigger (workflow_dispatch) for on-demand builds
- Environment selection (dev/stg/prd)
- OIDC authentication with Azure
- Docker image build and push to ACR
- Multiple image tags (latest, commit SHA, environment-specific)
- Detailed output showing image URI and next steps

**How to use**:
1. Go to GitHub → Actions → Docker Build & Push to ACR
2. Click \"Run workflow\"
3. Select your environment
4. Watch the build progress

### 2. Updated Terraform Configuration
**Files Modified**:
- [terraform/module/azure_container_app/variable.tf](terraform/module/azure_container_app/variable.tf)
- [terraform/module/azure_container_app/main.tf](terraform/module/azure_container_app/main.tf)

**Changes**:
- Added `container_image` variable to specify ACR image URI
- Added `container_port` variable (default: 8080 to match Dockerfile)
- Container App now references `var.container_image` instead of hardcoded image
- Port updated from 80 to 8080 to match Streamlit app

### 3. Deployment Guide
**File**: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)

Complete step-by-step guide covering:
- Prerequisites and setup
- Infrastructure deployment (Terraform)
- Building and pushing Docker images
- Updating Container App
- Troubleshooting and monitoring

### 4. Helper Scripts
Created scripts to simplify Container App updates:
- [scripts/update-container-app.sh](scripts/update-container-app.sh) - Linux/Mac bash script
- [scripts/update-container-app.bat](scripts/update-container-app.bat) - Windows batch script
- [scripts/update-container-app.ps1](scripts/update-container-app.ps1) - Windows PowerShell script (recommended)

**Features**:
- Verifies image exists in ACR
- Shows current and new images
- Updates Container App
- Waits for deployment
- Shows deployment URL
- Handles errors gracefully

## 🚀 Quick Start

### Step 1: Deploy Infrastructure
```bash
cd terraform/environment/dev
terraform apply
```

### Step 2: Build and Push Docker Image
Go to GitHub Actions and trigger \"Docker Build & Push to ACR\" workflow, or run:
```bash
# Build manually with Azure CLI
az acr build \\
  --registry eastusdev \\
  --image currency-dashboard:latest \\
  --file currency-dashboard/dockerFile \\
  ./currency-dashboard
```

### Step 3: Update Container App
**Option A - Using Terraform (Recommended)**:
```bash
cd terraform/environment/dev
terraform apply -var \"container_image=eastusdev.azurecr.io/currency-dashboard:latest\"
```

**Option B - Using PowerShell script**:
```powershell
.\\scripts\\update-container-app.ps1 -Environment dev -ImageTag latest
```

**Option C - Using Azure CLI directly**:
```bash
az containerapp update \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --image eastusdev.azurecr.io/currency-dashboard:latest
```

## 📁 File Structure

```
.github/
└── workflows/
    └── docker-build-push.yml          # GitHub Actions workflow

terraform/
├── module/
│   └── azure_container_app/
│       ├── main.tf                    # Updated with image variable
│       └── variable.tf                # Added container_image variable
└── environment/
    └── dev/
        └── *.tf                       # Terraform environment configs

currency-dashboard/
├── app.py
├── dockerFile                         # Python 3.11, Streamlit on port 8080
├── requirements.txt
└── ...

scripts/
├── update-container-app.sh            # Bash helper script
├── update-container-app.bat           # Batch helper script
└── update-container-app.ps1           # PowerShell helper script

DEPLOYMENT_GUIDE.md                    # Comprehensive guide
WORKFLOW_SUMMARY.md                    # This file
```

## 🔑 Key Environment Variables

For the workflow, ensure these GitHub repository variables are set:
- `ARM_CLIENT_ID` - Service principal client ID
- `ARM_TENANT_ID` - Azure tenant ID
- `ARM_SUBSCRIPTION_ID` - Azure subscription ID

## 🎯 Image Naming Convention

The workflow creates images with the following tags:
- `registry/image:latest` - Always points to latest build
- `registry/image:abc123` - Git commit SHA for traceability
- `registry/image:dev-latest` - Environment-specific latest tag

Example: `eastusdev.azurecr.io/currency-dashboard:latest`

## ⚙️ Configuration Reference

### ACR Details (Terraform)
- **Module**: [terraform/module/azure_container_registry/](terraform/module/azure_container_registry/)
- **Name**: `{location}{environment}acr` (e.g., \"eastusdev\" for dev)
- **SKU**: Standard

### Container App Details (Terraform)
- **Module**: [terraform/module/azure_container_app/](terraform/module/azure_container_app/)
- **Port**: 8080 (matches Dockerfile EXPOSE)
- **Min Replicas**: 1
- **Max Replicas**: 2
- **Ingress**: External (public access enabled)

### Docker Details
- **Base Image**: Python 3.11-slim
- **Port**: 8080
- **Framework**: Streamlit
- **Command**: `streamlit run app.py --server.address=0.0.0.0 --server.port=8080 --server.headless=true`

## 📊 Workflow Process Diagram

```
┌──────────────────────┐
│  GitHub Push/Trigger │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────┐
│  GitHub Actions          │
│  - Checkout code         │
│  - Azure Login (OIDC)    │
│  - Get ACR credentials   │
│  - Build Docker image    │
│  - Push to ACR           │
│  - Output image info     │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────┐
│  Azure Container      │
│  Registry (ACR)       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────────┐
│  Update via:             │
│  - Terraform             │
│  - Azure CLI             │
│  - Helper Script         │
└──────────┬───────────────┘
           │
           ▼
┌──────────────────────┐
│  Container App       │
│  (Running Image)     │
└──────────────────────┘
```

## 🧪 Testing the Deployment

### 1. Verify Image in ACR
```bash
az acr repository list --name eastusdev
az acr repository show-tags --name eastusdev --repository currency-dashboard
```

### 2. Check Container App Status
```bash
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.configuration.ingress.fqdn\" \\
  --output tsv
```

### 3. View Logs
```bash
az containerapp logs show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --follow
```

## ✅ Validation Checklist

- [ ] GitHub repository variables set (ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID)
- [ ] Terraform infrastructure deployed (resource group, ACR, ACA)
- [ ] Workflow file present at `.github/workflows/docker-build-push.yml`
- [ ] Dockerfile exists at `currency-dashboard/dockerFile`
- [ ] Container App Terraform updated with image variable
- [ ] Test workflow run completes successfully
- [ ] Docker image pushed to ACR
- [ ] Container App starts with new image

## 🔧 Customization

To use different ACR names or image names:

1. Update the GitHub Actions workflow:
   ```yaml
   env:
     REGISTRY_NAME: your-acr-name
     IMAGE_NAME: your-image-name
   ```

2. Update helper scripts:
   ```bash
   set ACR_NAME=your-acr-name
   set IMAGE_NAME=your-image-name
   ```

3. Update Terraform tfvars with correct image URI

## 📚 Additional Resources

- [Azure Container Apps Documentation](https://learn.microsoft.com/azure/container-apps/)
- [Azure Container Registry Documentation](https://learn.microsoft.com/azure/container-registry/)
- [GitHub Actions Azure Login](https://github.com/azure/login)
- [Docker Build Push Action](https://github.com/docker/build-push-action)
- [Streamlit Documentation](https://docs.streamlit.io/)

## 📞 Support

For issues:
1. Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
2. Review workflow logs in GitHub Actions
3. Check Container App logs: `az containerapp logs show ...`
4. Verify ACR image exists: `az acr repository show ...`
