// In case you would like to use Azure Key Vault Access Policies instead of using Azure RBAC.
// Azure RBAC is recommended.

param keyVaultName string
param tenantId string
param objectId string

resource keyVaultAccessPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2023-07-01' = {
  name: '${keyVaultName}/add' // Include the Key Vault name and the access policy name
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: objectId
        permissions: {
          keys: [
            'unwrapKey'
            'wrapKey'
            'get'
          ]
        }
      }
    ]
  }
}
