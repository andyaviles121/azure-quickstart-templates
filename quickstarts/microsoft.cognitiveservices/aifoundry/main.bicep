@description('Display name of the Azure AI Vision resource')
param aiServicesName string = 'aiServices-${uniqueString(resourceGroup().id)}'

@description('SKU for AI Services')
@allowed([
  'S0'
])
param sku string = 'S0'

@description('Location of the resource group.')
param location string = resourceGroup().location

resource aiServices 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: aiServicesName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  sku: {
    name: sku
  }
  properties: {
    publicNetworkAccess: 'Enabled'
  }
}
