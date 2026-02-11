#!/bin/bash

# Azure Container App Update Script
# This script updates the Container App with the latest Docker image from ACR

# Configuration - Update these values for your environment
RESOURCE_GROUP=\"le-app-westus2-dev-rg\"
CONTAINER_APP_NAME=\"le-app-westus2-dev-aca\"
ACR_NAME=\"eastusdev\"
IMAGE_NAME=\"currency-dashboard\"
IMAGE_TAG=\"latest\"

# Build the full image URI
IMAGE_URI=\"${ACR_NAME}.azurecr.io/${IMAGE_NAME}:${IMAGE_TAG}\"

echo \"========================================\"
echo \"Azure Container App Update\"
echo \"========================================\"
echo \"Resource Group: $RESOURCE_GROUP\"
echo \"Container App: $CONTAINER_APP_NAME\"
echo \"New Image: $IMAGE_URI\"
echo \"\"

# Verify the image exists in ACR
echo \"[1/4] Verifying image exists in ACR...\"
if az acr repository show-tags \\
    --name \"$ACR_NAME\" \\
    --repository \"$IMAGE_NAME\" \\
    --query \"[?@ == '$IMAGE_TAG']\" \\
    --output tsv | grep -q \"$IMAGE_TAG\"; then
    echo \"✅ Image found: $IMAGE_URI\"
else
    echo \"❌ Image not found in ACR. Available tags:\"
    az acr repository show-tags --name \"$ACR_NAME\" --repository \"$IMAGE_NAME\"
    exit 1
fi

# Get current Container App details
echo \"\"
echo \"[2/4] Getting Container App details...\"
CURRENT_IMAGE=$(az containerapp show \\
    --resource-group \"$RESOURCE_GROUP\" \\
    --name \"$CONTAINER_APP_NAME\" \\
    --query 'properties.template.containers[0].image' \\
    --output tsv)
echo \"Current Image: $CURRENT_IMAGE\"

# Update Container App
echo \"\"
echo \"[3/4] Updating Container App...\"
az containerapp update \\
    --resource-group \"$RESOURCE_GROUP\" \\
    --name \"$CONTAINER_APP_NAME\" \\
    --image \"$IMAGE_URI\"

if [ $? -eq 0 ]; then
    echo \"✅ Container App updated successfully\"
else
    echo \"❌ Failed to update Container App\"
    exit 1
fi

# Wait for deployment
echo \"\"
echo \"[4/4] Waiting for Container App to update...\"
sleep 5

# Show deployment status
PROVISIONING_STATE=$(az containerapp show \\
    --resource-group \"$RESOURCE_GROUP\" \\
    --name \"$CONTAINER_APP_NAME\" \\
    --query 'properties.provisioningState' \\
    --output tsv)

echo \"Provisioning State: $PROVISIONING_STATE\"

# Get Container App URL
APP_URL=$(az containerapp show \\
    --resource-group \"$RESOURCE_GROUP\" \\
    --name \"$CONTAINER_APP_NAME\" \\
    --query 'properties.configuration.ingress.fqdn' \\
    --output tsv)

echo \"\"
echo \"========================================\"
echo \"✅ Update Complete!\"
echo \"========================================\"
echo \"Container App URL: https://$APP_URL\"
echo \"\"
echo \"To view logs:\"
echo \"  az containerapp logs show --resource-group $RESOURCE_GROUP --name $CONTAINER_APP_NAME\"
echo \"\"
