/*
  Azure AI Fouondry accoutn and project - with Customer Managed Key (CMK)
  
  Description: 
  - Create an Azure AI Foundry account and project with CMK
  - Create a model deployment

*/
@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param aiServicesName string = 'aiServices-${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location


@description('Name of the first project')
param defaultProjectName string = '${aiServicesName}-proj'
param defaultProjectDisplayName string = 'Project'
param defaultProjectDescription string = 'Describe what your project is about.'

// Networking Parameters
@description('Foundry account private link endpoint name')
param accountPleName string

@description('Resource ID of the subnet resource')
param subnetId string

/*
  Step 2: Create a Cognitive Services Account 
  
*/ 
resource account 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' = {
  name: aiServicesName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  properties: {
    // Networking
    publicNetworkAccess: 'Disabled'

    // When set, we provision hub virtual workspace on existing Account
    // Below property cannot be reversed once set
    allowProjectManagement: true

    customSubDomainName: '${aiServicesName}-azureai'
    // auth
    disableLocalAuth: false
  }
}

/* 
  Step 3: Ensure that moduel
  - Create a private endpoint for the account

*/  
module machineLearningPrivateEndpoint './modules/network.bicep' = {
  name: 'machineLearningNetworking'
  scope: resourceGroup()
  params: {
    location: location
    accountARMId: account.id
    accountPleName: accountPleName
    subnetId: subnetId
  }
}

/*
  Step 3: Deploy gpt-4o model
  
  - Agents will use the build-in model deployments
*/
resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01'= {
  parent: account
  name: 'gpt-4o'
  sku : {
    capacity: 1
    name: 'GlobalStandard'
  }
  properties: {
    model:{
      name: 'gpt-4o'
      format: 'OpenAI'
      version: '2024-08-06'
    }
  }
}

/*
  Step 4: Create a Project. This resource maps to virtual Azure ML project

*/
resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' = {
  name: defaultProjectName
  parent: account
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: defaultProjectDisplayName
    description: defaultProjectDescription
    isDefault: true //can't be updated after creation; can only be set by one project in the account
  }
}

output accountId string = account.id
output accountName string = account.name
