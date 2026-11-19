#!/bin/bash

# ==========================================================
# DroneVision - Implantacao automatizada
# FIAP - Turma 5EMR - RM 95829
# ==========================================================

set -e

RESOURCE_GROUP="rg-dronevision-rm95829"
LOCATION="brazilsouth"

VISION_NAME="aiv-dronevision-rm95829"
VISION_LOCATION="eastus"

PLAN_NAME="plan-dronevision-rm95829"
WEBAPP_NAME="app-dronevision-rm95829"

DEPLOY_ZIP="$HOME/dronevision-deploy.zip"

echo "=========================================="
echo " INICIANDO IMPLANTACAO DRONEVISION"
echo "=========================================="

# 1. Criar Resource Group
echo "[1/7] Criando Resource Group..."

az group create \
  --name "$RESOURCE_GROUP" \
  --location "$LOCATION" \
  --output none

# 2. Criar Azure AI Vision
echo "[2/7] Criando Azure AI Vision..."

if ! az cognitiveservices account show \
  --name "$VISION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output none 2>/dev/null; then

  az cognitiveservices account create \
    --name "$VISION_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$VISION_LOCATION" \
    --kind ComputerVision \
    --sku F0 \
    --yes \
    --output none
fi

# 3. Obter endpoint e chave do Vision
echo "[3/7] Configurando acesso ao Azure AI Vision..."

VISION_ENDPOINT=$(az cognitiveservices account show \
  --name "$VISION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query endpoint \
  --output tsv)

VISION_KEY=$(az cognitiveservices account keys list \
  --name "$VISION_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query key1 \
  --output tsv)

if [ -z "$VISION_ENDPOINT" ] || [ -z "$VISION_KEY" ]; then
  echo "ERRO: Nao foi possivel obter as credenciais do Azure AI Vision."
  exit 1
fi

# 4. Criar App Service Plan
echo "[4/7] Criando App Service Plan..."

if ! az appservice plan show \
  --name "$PLAN_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output none 2>/dev/null; then

  az appservice plan create \
    --name "$PLAN_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku F1 \
    --is-linux \
    --output none
fi

# 5. Criar Web App
echo "[5/7] Criando Web App..."

if ! az webapp show \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --output none 2>/dev/null; then

  az webapp create \
    --name "$WEBAPP_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --plan "$PLAN_NAME" \
    --runtime "PYTHON:3.12" \
    --output none
fi

# 6. Configurar aplicacao
echo "[6/7] Configurando aplicacao..."

az webapp config appsettings set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --settings \
    VISION_ENDPOINT="$VISION_ENDPOINT" \
    VISION_KEY="$VISION_KEY" \
    SCM_DO_BUILD_DURING_DEPLOYMENT=true \
    WEBSITE_HTTPLOGGING_ENABLED=true \
  --output none

az webapp config set \
  --name "$WEBAPP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --startup-file "gunicorn --bind=0.0.0.0:8000 app:app" \
  --output none

# 7. Compactar e publicar a aplicacao
echo "[7/7] Publicando aplicacao no Azure App Service..."

if ! command -v zip >/dev/null 2>&1; then
  echo "ERRO: O comando zip nao esta instalado."
  exit 1
fi

rm -f "$DEPLOY_ZIP"

zip -r "$DEPLOY_ZIP" \
  app.py requirements.txt templates static

az webapp deploy \
  --resource-group "$RESOURCE_GROUP" \
  --name "$WEBAPP_NAME" \
  --src-path "$DEPLOY_ZIP" \
  --type zip

echo ""
echo "=========================================="
echo " IMPLANTACAO CONCLUIDA!"
echo "=========================================="
echo "Resource Group: $RESOURCE_GROUP"
echo "Azure AI Vision: $VISION_NAME"
echo "App Service Plan: $PLAN_NAME"
echo "Web App: $WEBAPP_NAME"
echo ""
echo "URL: https://${WEBAPP_NAME}.azurewebsites.net"
echo "=========================================="
