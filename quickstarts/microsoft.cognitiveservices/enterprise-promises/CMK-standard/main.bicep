/*
  Standard agent setup - with CMK. Still in progress.
  
  Description: 
  - Agents use customer-owned, single-tenant search and storage resources. With this setup, you have full control and visibility over these resources, but you incur costs based on your usage. 
  - Built-on deployments are used for model deployments.
  - User needs to have:
    - Managed Identity set up
    - Azure Key Vault set up, and key name, key version ready.
    - Azure Storage Account set up, and storage account name, storage account target ready.
    - Azure AI Search set up, and search service name, search service target ready.
    - CosmosDB set up, and CosmosDB account name, CosmosDB account target ready.

*/
@description('That name is the name of our application. It has to be unique.Type a name followed by your resource group name. (<name>-<resourceGroupName>)')
param aiServicesName string = 'aiServices02-${uniqueString(resourceGroup().id)}'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Name of the first project')
param defaultProjectName string = '${aiServicesName}-proj'
param defaultProjectDisplayName string = '${aiServicesName}-proj'
param defaultProjectDescription string = 'Describe what your project is about.'

// Prerequisite: The following parameters are required BYO-resources for standard setup

// CosmosDB Account
@description('Name of the customers existing CosmosDB Resource')
param cosmosDBAccountName string
@description('Resource Group name of the CosmosDB resource')
param cosmosDBAccountResourceGroupName string = resourceGroup().name
@description('Subscription ID of the CosmosDB resource')
param cosmosDBAccountSubscriptionId string = subscription().subscriptionId

// Azure Storage Account
/*
@description('Name of the customers existing Azure Storage Account')
param storageAccountName string
@description('Azure Storage account target ')
param storageAccountTarget string
@description('Resource Group name of the Azure Storage Account')
param azureStorageAccountResourceGroupName string
@description('Subscription ID of the Azure Storage Account')
param azureStorageAccountSubscriptionId string
*/

// Azure AI Search
@description('Name AI Search resource')
param aiSearchName string
@description('Resource Group name of the AI Search resource')
param aiSearchServiceResourceGroupName string = resourceGroup().name
@description('Subscription ID of the AI Search resource')
param aiSearchServiceSubscriptionId string = subscription().subscriptionId

// Azure Key Vault
@description('Name of the customers existing Azure Key Vault resource')
param azureKeyVaultName string
@description('Name of the Azure Key Vault target')
param azureKeyVaultTarget string = 'https://${azureKeyVaultName}.vault.azure.net/' 
@description('Resource Group name of the Azure Key Vault resource')
param azureKeyVaultResourceGroupName string = resourceGroup().name
@description('Subscription ID of the Azure Key Vault resource')
param azureKeyVaultSubscriptionId string = subscription().subscriptionId
@description('Name of the Azure Key Vault key')
param azureKeyName string
@description('Version of the Azure Key Vault key')
param azureKeyVersion string = 'ca6784237c914edebfb9019b53f92c83'

// User Assigned Identity
@description('User Assigned Identity Name')
param userAssignedIdentityName string
@description('User Assigned Identity Resource Group Name')
param userIdentityResourceGroupName string = resourceGroup().name

var userAssignedIdentityId = extensionResourceId(format('/subscriptions/{0}/resourceGroups/{1}', subscription().subscriptionId, '${userIdentityResourceGroupName}'), 'Microsoft.ManagedIdentity/userAssignedIdentities', '${userAssignedIdentityName}')

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: userAssignedIdentityName
  scope: resourceGroup(userIdentityResourceGroupName)
}

/*
  Step 1: Get your existing/previously created Azure resources
  
  - Get existing CosmosDB Account, Azure Storage Account, and Azure AI Search resources
*/ 
resource searchService 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: aiSearchName
  scope: resourceGroup(aiSearchServiceSubscriptionId, aiSearchServiceResourceGroupName)
}
resource cosmosDBAccount 'Microsoft.DocumentDB/databaseAccounts@2024-12-01-preview' existing = {
  name: cosmosDBAccountName
  scope: resourceGroup(cosmosDBAccountSubscriptionId, cosmosDBAccountResourceGroupName)
}
/*
resource storageAccount 'Microsoft.Search/accounts@2024-06-01-preview' existing = {
  name: storageAccountName
  scope: resourceGroup(azureStorageAccountSubscriptionId, azureStorageAccountResourceGroupName)
}
*/
/* Not Needed. Azure Key Vault will need to be connected on the account level.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: azureKeyVaultName
  scope: resourceGroup(azureKeyVaultSubscriptionId, azureKeyVaultResourceGroupName)
}

module keyVaultAccessPolicyModule './modules/keyVaultAccessPolicy.bicep' = {
  name: 'keyVaultAccessPolicyDeployment'
  scope: resourceGroup(azureKeyVaultSubscriptionId, azureKeyVaultResourceGroupName)
  params: {
    keyVaultName: azureKeyVaultName
    tenantId: subscription().tenantId
    objectId: userAssignedIdentity.properties.principalId
  }
}
*/


/*
  Step 2: Create a Cognitive Services Account 
  
  - Note: both public and private networking is supported.
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
    publicNetworkAccess: 'Enabled'
    /*
    networkAcls: {
      defaultAction: 'Deny'
    }
    */
    // Encryption - if needed
    /*
    encryption: {
      keySource: 'Microsoft.KeyVault'
      keyVaultProperties: {
        //identityClientId: userAssignedIdentity.properties.clientId
        keyName: azureKeyName
        keyVaultUri: azureKeyVaultTarget
        keyVersion: azureKeyVersion
      }
    }
    */
    // When set, we provision hub virtual workspace on existing Account
    // Below property cannot be reversed once set
    allowProjectManagement: true

    // auth
    disableLocalAuth: false

    // read-only Account properties
    // defaultProject: defaultProjectName
    // endpoints: {
    //   'Azure AI Foundry API': 'https://{resource}.services.ai.azure.com/'
    //   'Azure OpenAI Service API': 'https://{resource}.openai.azure.com/'
    // }
  }
}

/*
  Step 3: Deploy gpt-4o model
  
  - Agents will use the build-in model deployments

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01'= {
  parent: account
  name: 'gpt-4o'
  sku : {
    capacity: '50'
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
*/

/*
  Step 4: Set an Account Capability Host. This resource maps to virtual hub Capability Host

  - Only property is optional and is the capabilityHostKind
  - Otherwise properties are empty



resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHost@2025-01-01-preview' = {  
    // others
    name: '${aiServicesName}-capabilities'
    properties: {
      capabilityHostKind: 'Agents'
    }
}
*/
/*
  Step 5: Create a Project. This resource maps to virtual Azure ML project

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01' = {
  name: defaultProjectName
  parent: account
  properties: {
    displayName: defaultProjectDisplayName
    description: defaultProjectDescription
    //read-only
    // endpoints: {
    //   'Azure AI Foundry API': 'https://{resource}.services.ai.azure.com/projects/{project}'
    // }
    isDefault: true //can't be updated after creation; can only be set by one project in the account
  }
}
*/
/*
  Step 6: Create a Project connection to BYO resources

  - Create project connections to CosmosDB, Azure Storage Account, and Azure AI Search resources

resource project_connection_cosmosdb 'Microsoft.CognitiveServices/accounts/projects/connections@2025-01-01-preview' = {
  name: 'myThreadStorageProjectConnectionName'
  parent: project
  properties: {
    category: 'CosmosDB'
    target: 'https://${cosmosDBAccountName}documents.azure.com:443/'
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: cosmosDBAccount.id
      location: cosmosDBAccount.location
    }
  }
}

resource project_connection_azure_storage 'Microsoft.CognitiveServices/accounts/projects/connections@2025-01-01-preview' = {
  name: 'myStorageProjectConnectionName'
  parent: project
  properties: {
    category: 'AzureStorage'
    target: storageAccountTarget
    authType: 'AAD'
    metadata: {
      ApiType: 'Azure'
      ResourceId: cosmosDBAccount.id
      location: cosmosDBAccount.location
    }
  }
}

resource project_connection_azureai_search 'Microsoft.CognitiveServices/accounts/projects/connections@2025-01-01-preview' = {
  name: 'myVectorStoreProjectConnectionName'
  parent: project
  properties: {
    category: 'CognitiveSearch'
    target: 'https://${aiSearchName}.search.windows.net'
    authType: 'AAD'
    //useWorkspaceManagedIdentity: false
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: searchService.id
      location: searchService.location
    }
  }
}

/*
resource project_connection_azure_keyvault 'Microsoft.CognitiveServices/accounts/connections@2025-01-01-preview' = {
  name: 'myAzureKeyVaultConnection'
  parent: account
  properties: {
    category: 'CognitiveSearch'
    target: azureKeyVaultTarget
    authType: 'AAD'
    //useWorkspaceManagedIdentity: false
    isSharedToAll: true
    metadata: {
      ApiType: 'Azure'
      ResourceId: keyVault.id
      location: keyVault.location
    }
  }
}
*/
/*
  Step 7: Create a Project Capability Host

  - Set properities with BYO resources: CosmosDB, Azure Storage Account, and Azure AI Search 

resource capabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHost@2025-01-01' = {
  name: '${defaultProjectName}-capabilities'
  // pass in required BYO resources for files, threads, and vector stores
  properties: {
    capabilityHostKind: 'Agents'

    // these three parameter are required for standard setup
    storageConnections: ['myStorageConnectionName']
    threadStorageConnections: ['myThreadStorageConnectionName']
    vectorStoreConnections: ['myVectorStoreConnectionName']

    }
}
*/
//output objectId string = userAssignedIdentity.properties.principalId
output accountId string = account.id
output accountName string = account.name
