# Azure Container App Update Script (PowerShell)
# This script updates the Container App with the latest Docker image from ACR

param(
    [string]$Environment = 'dev',
    [string]$ImageTag = 'latest'
)

# Configuration based on environment
$config = @{
    'dev' = @{
        ResourceGroup = 'le-app-westus2-dev-rg'
        ContainerAppName = 'le-app-westus2-dev-aca'
        AcrName = 'eastusdev'
    }
    'stg' = @{
        ResourceGroup = 'le-app-westus2-stg-rg'
        ContainerAppName = 'le-app-westus2-stg-aca'
        AcrName = 'eastuesstgacr'
    }
    'prd' = @{
        ResourceGroup = 'le-app-westus2-prd-rg'
        ContainerAppName = 'le-app-westus2-prd-aca'
        AcrName = 'eastuesprdacr'
    }
}

# Validate environment
if (-not $config.ContainsKey($Environment)) {
    Write-Error \"Invalid environment: $Environment. Valid options: dev, stg, prd\"
    exit 1
}

$cfg = $config[$Environment]
$ImageName = 'currency-dashboard'
$ImageUri = \"$($cfg.AcrName).azurecr.io/$ImageName:$ImageTag\"

# Display header
Write-Host \"`n\" -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host 'Azure Container App Update' -ForegroundColor Cyan
Write-Host '========================================' -ForegroundColor Cyan
Write-Host \"Environment: $Environment\" -ForegroundColor Yellow
Write-Host \"Resource Group: $($cfg.ResourceGroup)\" -ForegroundColor Yellow
Write-Host \"Container App: $($cfg.ContainerAppName)\" -ForegroundColor Yellow
Write-Host \"New Image: $ImageUri\" -ForegroundColor Yellow
Write-Host \"\" -ForegroundColor Cyan

try {
    # Step 1: Verify image exists in ACR
    Write-Host '[1/4] Verifying image exists in ACR...' -ForegroundColor Cyan
    
    $tags = az acr repository show-tags `
        --name $cfg.AcrName `
        --repository $ImageName `
        --query \"[?@ == '$ImageTag']\" `
        --output tsv 2>$null
    
    if ($tags) {
        Write-Host \"✅ Image found: $ImageUri\" -ForegroundColor Green
    }
    else {
        Write-Host \"❌ Image not found in ACR. Available tags:\" -ForegroundColor Red
        az acr repository show-tags `
            --name $cfg.AcrName `
            --repository $ImageName
        exit 1
    }
    
    # Step 2: Get current Container App details
    Write-Host \"\" -ForegroundColor Cyan
    Write-Host '[2/4] Getting Container App details...' -ForegroundColor Cyan
    
    $currentImage = az containerapp show `
        --resource-group $cfg.ResourceGroup `
        --name $cfg.ContainerAppName `
        --query 'properties.template.containers[0].image' `
        --output tsv
    
    Write-Host \"Current Image: $currentImage\" -ForegroundColor Yellow
    
    # Step 3: Update Container App
    Write-Host \"\" -ForegroundColor Cyan
    Write-Host '[3/4] Updating Container App...' -ForegroundColor Cyan
    
    az containerapp update `
        --resource-group $cfg.ResourceGroup `
        --name $cfg.ContainerAppName `
        --image $ImageUri | Out-Null
    
    Write-Host \"✅ Container App update initiated\" -ForegroundColor Green
    
    # Step 4: Wait and show status
    Write-Host \"\" -ForegroundColor Cyan
    Write-Host '[4/4] Checking deployment status...' -ForegroundColor Cyan
    
    Start-Sleep -Seconds 5
    
    $provisioningState = az containerapp show `
        --resource-group $cfg.ResourceGroup `
        --name $cfg.ContainerAppName `
        --query 'properties.provisioningState' `
        --output tsv
    
    Write-Host \"Provisioning State: $provisioningState\" -ForegroundColor Yellow
    
    # Get Container App URL
    $appUrl = az containerapp show `
        --resource-group $cfg.ResourceGroup `
        --name $cfg.ContainerAppName `
        --query 'properties.configuration.ingress.fqdn' `
        --output tsv
    
    # Success message
    Write-Host \"\" -ForegroundColor Cyan
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host '✅ Update Complete!' -ForegroundColor Green
    Write-Host '========================================' -ForegroundColor Cyan
    Write-Host \"Container App URL: https://$appUrl\" -ForegroundColor Green
    Write-Host \"\" -ForegroundColor Cyan
    Write-Host 'To view logs:' -ForegroundColor Cyan
    Write-Host \"  az containerapp logs show --resource-group $($cfg.ResourceGroup) --name $($cfg.ContainerAppName)\" -ForegroundColor Gray
    Write-Host \"\" -ForegroundColor Cyan
}
catch {
    Write-Error \"An error occurred: $_\"
    exit 1
}
