# Troubleshooting Guide

## Common Issues and Solutions

### 🔴 GitHub Actions Workflow Issues

#### Workflow fails with: \"OIDC not found\" or authentication error
**Cause**: GitHub repository variables not set  
**Solution**:
```
1. Go to Settings > Secrets and variables > Repository variables
2. Add these variables:
   - ARM_CLIENT_ID
   - ARM_TENANT_ID
   - ARM_SUBSCRIPTION_ID
3. Ensure values are correct (no extra spaces)
```

#### Workflow fails with: \"dockerFile not found\"
**Cause**: File path incorrect  
**Solution**:
```bash
# Verify Dockerfile exists
ls -la currency-dashboard/dockerFile

# Check Docker build context
ls -la currency-dashboard/
# Should contain: app.py, requirements.txt, dockerFile
```

#### Workflow fails with: \"ACR login failed\"
**Cause**: ACR not found or not deployed  
**Solution**:
```bash
# Check if ACR exists
az acr list --query \"[].name\"

# Verify ACR name matches workflow (eastusdev for dev)
az acr show --name eastusdev
```

### 🔴 Docker Build Issues

#### Build fails with: \"requirements.txt not found\"
**Cause**: Missing file in Docker context  
**Solution**:
```bash
# Check file exists
ls -la currency-dashboard/requirements.txt

# Ensure Dockerfile COPY command is correct
cat currency-dashboard/dockerFile | grep COPY
```

#### Build fails with: \"Python package not found\"
**Cause**: Missing or incorrect package in requirements.txt  
**Solution**:
```bash
# Validate requirements.txt
cat currency-dashboard/requirements.txt

# Build locally to test
docker build -f currency-dashboard/dockerFile -t test:latest ./currency-dashboard
```

#### Image size too large
**Cause**: Not using slim base image or caching issues  
**Solution**:
```dockerfile
# Ensure using slim image
FROM python:3.11-slim  # ✅ Good
FROM python:3.11      # ❌ Too large

# Clear cache
--no-cache-dir
```

### 🔴 ACR Push Issues

#### Cannot authenticate to ACR
**Cause**: Not logged in or credentials expired  
**Solution**:
```bash
# Login to ACR
az login --use-device-code
az acr login --name eastusdev

# Verify access
az acr repository list --name eastusdev
```

#### Image not appearing in ACR
**Cause**: Push failed silently or wrong registry  
**Solution**:
```bash
# Check build logs
az acr build-task logs --build-id <build-id> --registry eastusdev

# Verify image was pushed
az acr repository list --name eastusdev
az acr repository show-tags --name eastusdev --repository currency-dashboard
```

### 🔴 Terraform Issues

#### Error: \"container_image variable not found\"
**Cause**: Terraform variable file not updated  
**Solution**:
```bash
# Ensure variable.tf has the variable
cat terraform/module/azure_container_app/variable.tf | grep -A 5 container_image

# Reinstall with updated variables
terraform init -upgrade
terraform apply
```

#### Container App still shows old image
**Cause**: Terraform may not be updating  
**Solution**:
```bash
# Force update
terraform apply -replace=\"azurerm_container_app.app\" \\
  -var=\"container_image=eastusdev.azurecr.io/currency-dashboard:latest\"

# Verify via CLI
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.template.containers[0].image\"
```

#### \"target_port\" variable error
**Cause**: Old Terraform configuration still in use  
**Solution**:
```bash
# Verify main.tf is updated
grep \"target_port\" terraform/module/azure_container_app/main.tf

# Should show: target_port = var.container_port
# NOT: target_port = 80
```

### 🔴 Container App Issues

#### Container App won't start after update
**Cause**: Image not found or port mismatch  
**Solution**:
```bash
# Check Container App status
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.provisioningState\"

# View logs for errors
az containerapp logs show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --follow

# Verify port configuration
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.configuration.ingress.targetPort\"
# Should be: 8080
```

#### \"Image not accessible\" error
**Cause**: Wrong image URI or ACR credentials not configured  
**Solution**:
```bash
# Verify image exists and is accessible
az acr repository show \\
  --name eastusdev \\
  --repository currency-dashboard

# Update Container App with correct image
az containerapp update \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --image eastusdev.azurecr.io/currency-dashboard:latest
```

#### Application returns 502 Bad Gateway
**Cause**: Port mismatch or app not starting properly  
**Solution**:
```bash
# Check port configuration
az containerapp ingress show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca

# Should have targetPort: 8080

# Check container logs
az containerapp logs show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --follow

# Topic: Check if Streamlit app is running on correct port and address
# The Dockerfile should have:
# CMD [\"streamlit\", \"run\", \"app.py\", \"--server.address=0.0.0.0\", \"--server.port=8080\", \"--server.headless=true\"]
```

### 🔴 Script Issues

#### PowerShell script fails to execute
**Cause**: Execution policy  
**Solution**:
```powershell
# Check current policy
Get-ExecutionPolicy

# Set to allow scripts (temporary session only)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process

# Or run with bypass
powershell -ExecutionPolicy Bypass -File .\\scripts\\update-container-app.ps1
```

#### Script shows \"Resource not found\" error
**Cause**: Wrong resource group or container app name  
**Solution**:
```bash
# List your resources
az containerapp list --query \"[].name\"
az containerapp list --query \"[].resourceGroup\"

# Update script with correct values
# Edit the $config hashtable in update-container-app.ps1
```

### 🔴 Network/Connectivity Issues

#### Cannot reach Container App URL
**Cause**: External ingress not enabled or firewall  
**Solution**:
```bash
# Get the URL
URL=$(az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.configuration.ingress.fqdn\" \\
  -o tsv)
echo $URL

# Test connectivity
curl -v https://$URL

# Verify ingress is external
az containerapp ingress show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.external\"
# Should be: true
```

#### DNS resolution fails
**Cause**: DNS cache or propagation delay  
**Solution**:
```bash
# Flush DNS cache
# Windows: ipconfig /flushdns
# Mac: sudo dscacheutil -flushcache
# Linux: sudo systemctl restart systemd-resolved

# Wait 60 seconds and retry
sleep 60
curl https://<your-app-url>
```

## 🔍 Debugging Steps

### 1. Check GitHub Actions Logs
```
GitHub > Actions > [Workflow Name] > [Latest Run] > View logs
```
Look for:
- Azure login status
- Docker build output
- Image push confirmation
- Errors or failures

### 2. Check Terraform State
```bash
cd terraform/environment/dev
terraform state show azurerm_container_app.app
```

### 3. Check ACR
```bash
# List images
az acr repository list --name eastusdev

# Check specific image tags
az acr repository show-tags \\
  --name eastusdev \\
  --repository currency-dashboard

# Get image details
az acr repository show \\
  --name eastusdev \\
  --repository currency-dashboard
```

### 4. Check Container App
```bash
# Full details
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  -o json | jq .

# Specific properties
az containerapp show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --query \"properties.template.containers[0]\"
```

### 5. View Detailed Logs
```bash
# Stream logs (real-time)
az containerapp logs show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --follow

# Get logs from specific time
az containerapp logs show \\
  --resource-group le-app-westus2-dev-rg \\
  --name le-app-westus2-dev-aca \\
  --since 1h
```

## 📞 Getting More Help

1. **Azure CLI Help**: `az containerapp --help`
2. **Terraform Help**: `terraform -help`
3. **GitHub Actions Docs**: https://docs.github.com/en/actions
4. **Azure Container Apps**: https://learn.microsoft.com/azure/container-apps/
5. **Streamlit Issues**: https://docs.streamlit.io/library/faq-and-troubleshooting

## ✅ Validation Checklist

Before considering your setup complete:

- [ ] GitHub repository variables are set and correct
- [ ] Terraform infrastructure deployed successfully
- [ ] ACR created and accessible
- [ ] Docker image builds without errors locally
- [ ] Image pushes to ACR successfully
- [ ] Container App updates with new image
- [ ] Application starts on port 8080
- [ ] Can access application via public URL
- [ ] Logs show no errors
