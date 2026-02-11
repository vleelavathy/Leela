@echo off
REM Azure Container App Update Script (Windows)
REM This script updates the Container App with the latest Docker image from ACR

setlocal enabledelayedexpansion

REM Configuration - Update these values for your environment
set RESOURCE_GROUP=le-app-westus2-dev-rg
set CONTAINER_APP_NAME=le-app-westus2-dev-aca
set ACR_NAME=eastusdev
set IMAGE_NAME=currency-dashboard
set IMAGE_TAG=latest

REM Build the full image URI
set IMAGE_URI=%ACR_NAME%.azurecr.io/%IMAGE_NAME%:%IMAGE_TAG%

echo.
echo ========================================
echo Azure Container App Update
echo ========================================
echo Resource Group: %RESOURCE_GROUP%
echo Container App: %CONTAINER_APP_NAME%
echo New Image: %IMAGE_URI%
echo.

REM Verify the image exists in ACR
echo [1/4] Verifying image exists in ACR...
for /f %%A in ('az acr repository show-tags --name %ACR_NAME% --repository %IMAGE_NAME% --query \"[?@ == '%IMAGE_TAG%']\" --output tsv') do (
    set FOUND_TAG=%%A
)

if defined FOUND_TAG (
    echo ✅ Image found: %IMAGE_URI%
) else (
    echo ❌ Image not found in ACR. Available tags:
    az acr repository show-tags --name %ACR_NAME% --repository %IMAGE_NAME%
    exit /b 1
)

REM Get current Container App details
echo.
echo [2/4] Getting Container App details...
for /f %%A in ('az containerapp show --resource-group %RESOURCE_GROUP% --name %CONTAINER_APP_NAME% --query \"properties.template.containers[0].image\" --output tsv') do (
    set CURRENT_IMAGE=%%A
)
echo Current Image: %CURRENT_IMAGE%

REM Update Container App
echo.
echo [3/4] Updating Container App...
az containerapp update ^
    --resource-group %RESOURCE_GROUP% ^
    --name %CONTAINER_APP_NAME% ^
    --image %IMAGE_URI%

if %errorlevel% equ 0 (
    echo ✅ Container App updated successfully
) else (
    echo ❌ Failed to update Container App
    exit /b 1
)

REM Wait for deployment
echo.
echo [4/4] Waiting for Container App to update...
timeout /t 5 /nobreak

REM Show deployment status
for /f %%A in ('az containerapp show --resource-group %RESOURCE_GROUP% --name %CONTAINER_APP_NAME% --query \"properties.provisioningState\" --output tsv') do (
    set PROVISIONING_STATE=%%A
)

echo Provisioning State: %PROVISIONING_STATE%

REM Get Container App URL
for /f %%A in ('az containerapp show --resource-group %RESOURCE_GROUP% --name %CONTAINER_APP_NAME% --query \"properties.configuration.ingress.fqdn\" --output tsv') do (
    set APP_URL=%%A
)

echo.
echo ========================================
echo ✅ Update Complete!
echo ========================================
echo Container App URL: https://%APP_URL%
echo.
echo To view logs:
echo   az containerapp logs show --resource-group %RESOURCE_GROUP% --name %CONTAINER_APP_NAME%
echo.

endlocal
