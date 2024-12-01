param(
    [string]$registry,
    [string]$repository = 'aoc_bot',
    [string]$tag = 'latest'
)
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot "Logging.psm1") -Force

if($registry.Contains('azurecr.io')) {
    Write-Info "Logging into Azure Container Registry"
    az acr login --name $registry
}

$image = "$registry/${repository}:$tag"

docker build . -t $image
docker push $image

Write-Success "Successfully pushed image to $image"
