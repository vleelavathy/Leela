# Quick Start Checklist

## ✅ Setup Complete!

The following components have been created to automate your Docker build and Azure Container App deployment:

### 1. GitHub Actions Workflow ✓
- **File**: `.github/workflows/docker-build-push.yml`
- **Trigger**: Manual (workflow_dispatch) - select environment and run
- **Actions**: Builds Docker image → Pushes to ACR → Outputs deployment info

### 2. Terraform Updates ✓
- **Files Modified**:
  - `terraform/module/azure_container_app/variable.tf` - Added container image & port variables
  - `terraform/module/azure_container_app/main.tf` - Uses variables instead of hardcoded image
  
### 3. Documentation ✓
- **DEPLOYMENT_GUIDE.md** - Complete step-by-step guide
- **WORKFLOW_SUMMARY.md** - Overview and reference
- **QUICK_START.md** - This file

### 4. Helper Scripts ✓
- **scripts/update-container-app.sh** - Linux/Mac version
- **scripts/update-container-app.bat** - Windows batch version
- **scripts/update-container-app.ps1** - Windows PowerShell version (recommended)

---

## 🚀 To Deploy Your Application

### **Step 1: Prepare GitHub**
Ensure your GitHub repository has these **Repository Variables** set:
```
Settings > Secrets and variables > Repository variables
```
- `ARM_CLIENT_ID` - Your service principal client ID
- `ARM_TENANT_ID` - Your Azure tenant ID
- `ARM_SUBSCRIPTION_ID` - Your subscription ID

### **Step 2: Deploy Infrastructure (One-time)**
```bash
cd terraform/environment/dev
terraform init
terraform apply
# This creates: Resource Group, ACR, Container Apps Environment, Container App
```

### **Step 3: Build Docker Image & Push to ACR**
**Option A: GitHub Actions (Recommended)**
1. Go to: GitHub → **Actions** → **Docker Build & Push to ACR**
2. Click: **Run workflow**
3. Select: Your environment (dev/stg/prd)
4. Click: **Run workflow**

**Option B: Azure CLI (Manual)**
```bash
az acr build \\
  --registry eastusdev \\
  --image currency-dashboard:latest \\
  --file currency-dashboard/dockerFile \\
  ./currency-dashboard
```

### **Step 4: Update Container App**
**Option A: Using Terraform (Recommended)**
```bash
cd terraform/environment/dev
terraform apply -var \"container_image=eastusdev.azurecr.io/currency-dashboard:latest\"
```

**Option B: Using PowerShell Script (Easiest for Windows)**
```powershell
.\\scripts\\update-container-app.ps1 -Environment dev -ImageTag latest
```

**Option C: Using Azure CLI**
```bash
az containerapp update \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --image eastusdev.azurecr.io/currency-dashboard:latest
```

---

## 📝 Common Commands

### Check Image in ACR
```bash
az acr repository show-tags --name eastusdev --repository currency-dashboard
```

### View Container App Status
```bash
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca
```

### View Container Logs
```bash
az containerapp logs show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --follow
```

### Get Container App URL
```bash
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.configuration.ingress.fqdn\" \\
  --output tsv
```

---

## 📋 Key Information

| Component | Value |
|-----------|-------|
| **ACR Name** | eastusdev |
| **Image Name** | currency-dashboard |
| **Container Port** | 8080 |
| **Resource Group (Dev)** | le-app-westus2-dev-rg |
| **Container App (Dev)** | le-app-westus2-dev-aca |
| **Docker Base** | python:3.11-slim |
| **Framework** | Streamlit |

---

## 🔄 Complete Flow Diagram

```
[GitHub Actions] 
    ↓ (Manual trigger)
[Build Docker Image]
    ↓
[Push to ACR]
    ↓
[Update Container App via Terraform/CLI]
    ↓
[Application Running on Port 8080]
```

---

## ❓ Need Help?

1. **Workflow Issues**: Check [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#troubleshooting)
2. **Setup Questions**: See [WORKFLOW_SUMMARY.md](WORKFLOW_SUMMARY.md)
3. **Step-by-step Guide**: Read [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
4. **Script Usage**: Run: `powershell .\\scripts\\update-container-app.ps1 -Help`

---

## ✨ Next Steps (Optional)

- [ ] Add GitHub OIDC authentication (already configured)
- [ ] Set up monitoring with Application Insights
- [ ] Configure auto-scaling rules
- [ ] Add CI/CD pipeline for staging/production
- [ ] Implement health checks in Container App
- [ ] Set up alerts for deployment failures
