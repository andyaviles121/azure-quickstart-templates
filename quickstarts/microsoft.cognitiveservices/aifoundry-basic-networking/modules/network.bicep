@description('Foundry account private link endpoint name')
param accountPleName string

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Account ARM Id')
param accountARMId string

@description('Resource ID of the subnet resource')
param subnetId string

resource machineLearningPrivateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: accountPleName
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: accountPleName
        properties: {
          groupIds: [
            'account'
          ]
          privateLinkServiceId: accountARMId
        }
      }
    ]
    subnet: {
      id: subnetId 
    }
  }
}
