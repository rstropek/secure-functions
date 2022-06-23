param storageName string
param location string = resourceGroup().location
param tags object
param kind string = 'StorageV2'
param sku string = 'Standard_LRS'
param tier string = 'Hot'
param sharedKeyAccess bool = false

resource dataStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: storageName
  location: location
  tags: tags
  kind: kind
  sku: {
    name: sku
  }
  properties: {
    accessTier: tier
    allowBlobPublicAccess: false
    allowSharedKeyAccess: sharedKeyAccess
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}
