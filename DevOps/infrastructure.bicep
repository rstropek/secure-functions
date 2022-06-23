@description('Name of the project')
param projectName string = 'heroapi'

@description('Location of the resources, uses resource group\'s location by default')
param location string = resourceGroup().location

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Stage of the deployment, uses dev by default')
param stage string = 'dev'

@allowed([
  'EP1'
  'EP2'
  'EP3'
])
param appServicePlanSku string = 'EP1'

@description('Indicates whether IP addresses in logs should be masked, consider GDPR before enabling this')
param disableIpMaskingInLogs bool = false

@description('Optional ID of admin user, this user will have access to storage services with customer data; for dev/test stages only')
param adminPrincipalId string = ''

var baseName = '${stage}-${projectName}'
var names = {
  vnet: 'vnet-${uniqueString('${baseName}-main')}'
  appServicePlan: 'plan-${uniqueString('${baseName}')}'
  functionStorage: 'st${uniqueString('${baseName}-functionstorage')}'
  appInsights: 'appi-${uniqueString('${baseName}')}'
  logAnalytics: 'log-${uniqueString('${baseName}')}'
  functionApp: 'func-${uniqueString('${baseName}')}'
  dataStorage: 'st${uniqueString('${baseName}-users')}'
  secretsVault: 'kv-${uniqueString('${baseName}')}'
  dnsZoneTable: 'privatelink.table.${environment().suffixes.storage}'
  dnsZoneKv: 'privatelink.vaultcore.azure.net'
  peTable: 'pe-${uniqueString('${baseName}-data')}'
  peTableDnsGroupName: 'tablednsgroupname'
  peVault: 'pe-${uniqueString('${baseName}-vault')}'
  peVaultDnsGroupName: 'vaultdnsgroupname'
}
var tags = {
  Project: projectName
  Environment: stage
}
var tagsConfigData = {
  DataClassification: 'Configuration'
}
var tagsTelemetryData = {
  DataClassification: 'Telemetry'
}
var tagsCustomerData = {
  DataClassification: 'Customer Data'
}
var roleIds = {
  // See https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#all
  StorageTableDataContributor: '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  KeyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource apiVnet 'Microsoft.Network/virtualNetworks@2021-08-01' = {
  name: names.vnet
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.10.0/24'
        }
      }
      {
        name: 'privateendpoints'
        properties: {
          addressPrefix: '10.0.11.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Disabled'
        }
      }
      {
        name: 'serverfarms'
        properties: {
          addressPrefix: '10.0.12.0/24'
          delegations: [
            {
              name: 'Microsoft.Web.serverFarms'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
        }
      }
    ]
  }
}

resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: names.appServicePlan
  location: location
  tags: tags
  sku: {
    name: appServicePlanSku
  }
  properties: {
    reserved: true // Required for Linux app service plans
  }
  kind: 'linux'
}

resource functionStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: names.functionStorage
  location: location
  tags: union(tags, tagsConfigData)
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true // Ok because storage contains just config data
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: names.logAnalytics
  location: location
  tags: union(tags, tagsTelemetryData)
  properties: {
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    retentionInDays: 30
    features: {
      disableLocalAuth: false
      enableDataExport: false
    }
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: names.appInsights
  location: location
  tags: union(tags, {
      'hidden-link:/subscriptions/${subscription().id}/resourceGroups/${resourceGroup().name}/providers/Microsoft.Web/sites/${names.functionApp}': 'Resource'
    }, tagsTelemetryData)
  kind: 'web'
  properties: {
    Application_Type: 'web'
    DisableIpMasking: disableIpMaskingInLogs
    WorkspaceResourceId: logAnalytics.id
  }
}

resource functionApp 'Microsoft.Web/sites@2021-03-01' = {
  name: names.functionApp
  location: location
  tags: tags
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    enabled: true
    httpsOnly: true
    serverFarmId: appServicePlan.id
    clientAffinityEnabled: true
    siteConfig: {
      vnetRouteAllEnabled: true
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      scmMinTlsVersion: '1.2'
      minimumElasticInstanceCount: 1
      http20Enabled: true
      healthCheckPath: '/healthy'
    }
  }
  resource network 'networkConfig@2021-03-01' = {
    name: 'virtualNetwork'
    properties: {
      subnetResourceId: apiVnet.properties.subnets[2].id
      swiftSupported: true
    }
  }

  resource settings 'config@2021-03-01' = {
    name: 'appsettings'
    properties: {
      'APPINSIGHTS_INSTRUMENTATIONKEY': appInsights.properties.InstrumentationKey
      'AzureWebJobsStorage': 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionStorage.id, functionStorage.apiVersion).keys[0].value}'
      'FUNCTIONS_EXTENSION_VERSION': '~4'
      'FUNCTIONS_WORKER_RUNTIME': 'dotnet'
      'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING': 'DefaultEndpointsProtocol=https;AccountName=${functionStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(functionStorage.id, functionStorage.apiVersion).keys[0].value}'
      'AZURE_FUNCTIONS_ENVIRONMENT': stage == 'prod' ? 'Production' : stage == 'test' ? 'Staging' : 'Development'
      'AzureWebJobsDisableHomepage': 'true'
      'WEBSITE_CONTENTSHARE': names.functionApp
      'TableStorageAccountName': dataStorage.name
      'KeyVaultName': keyvault.name
      'WEBSITE_RUN_FROM_PACKAGE': '1'
    }
  }
}

resource dataStorage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: names.dataStorage
  location: location
  tags: union(tags, tagsCustomerData)
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }

  resource usersTableService 'tableServices@2021-09-01' = {
    name: 'default'
    resource dataTable 'tables@2021-09-01' = {
      name: 'data'
    }
  }
}

module stgModule 'storage.bicep' = {
  name: 'stdemostorageasdfasdf'
  scope: resourceGroup()
  params: {
    storageName: 'stdemostorageasdfasdf'
    location: location
    tags: union(tags, tagsCustomerData)
  }
}

resource tablePe 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: names.peTable
  location: location
  tags: union(tags, { Type: 'Table' })
  properties: {
    subnet: {
      id: apiVnet.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: names.peTable
        properties: {
          privateLinkServiceId: dataStorage.id
          groupIds: [
            'table'
          ]
        }
      }
    ]
  }

  resource pvtEndpointDnsGroup 'privateDnsZoneGroups@2021-05-01' = {
    name: names.peTableDnsGroupName
    properties: {
      privateDnsZoneConfigs: [
        {
          name: guid(names.peTableDnsGroupName, 'config')
          properties: {
            privateDnsZoneId: tableDnsZone.id
          }
        }
      ]
    }
  }
}

resource functionAppTableStorageAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(dataStorage.id, functionApp.id)
  scope: dataStorage
  properties: {
    principalId: functionApp.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleIds.StorageTableDataContributor)
    // Note also bug/limitation https://github.com/Azure/bicep/issues/2031#issuecomment-816743989
    principalType: 'ServicePrincipal'
  }
}

resource adminTableStorageAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (adminPrincipalId != '') {
  name: guid(dataStorage.id, adminPrincipalId)
  scope: dataStorage
  properties: {
    principalId: adminPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleIds.StorageTableDataContributor)
    // Note also bug/limitation https://github.com/Azure/bicep/issues/2031#issuecomment-816743989
  }
}

resource keyvault 'Microsoft.KeyVault/vaults@2021-11-01-preview' = {
  name: names.secretsVault
  location: location
  tags: union(tags, tagsConfigData)
  properties: {
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
  }

  resource dataConnectionStringSecret 'secrets@2021-11-01-preview' = {
    name: 'DataStorageConnectionString'
    properties: {
      value: 'DefaultEndpointsProtocol=https;AccountName=${dataStorage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${listKeys(dataStorage.id, dataStorage.apiVersion).keys[0].value}'
    }
  }
}

resource keyvaultPe 'Microsoft.Network/privateEndpoints@2020-06-01' = {
  name: names.peVault
  location: location
  tags: union(tags, { Type: 'KeyVault' })
  properties: {
    subnet: {
      id: apiVnet.properties.subnets[1].id
    }
    privateLinkServiceConnections: [
      {
        name: names.peVault
        properties: {
          privateLinkServiceId: keyvault.id
          groupIds: [
            'vault'
          ]
        }
      }
    ]
  }
  
  resource pvtEndpointDnsGroup 'privateDnsZoneGroups@2021-05-01' = {
    name: names.peVaultDnsGroupName
    properties: {
      privateDnsZoneConfigs: [
        {
          name: guid(names.peTableDnsGroupName, 'config')
          properties: {
            privateDnsZoneId: vaultDnsZone.id
          }
        }
      ]
    }
  }

}

resource functionAppKeyVaultAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(keyvault.id, functionApp.id)
  scope: keyvault
  properties: {
    //principalId: functionApp.identity.principalId
    principalId: functionApp.identity.principalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleIds.KeyVaultSecretsUser)
    // Note also bug/limitation https://github.com/Azure/bicep/issues/2031#issuecomment-816743989
    principalType: 'ServicePrincipal'
  }
}

resource adminKeyVaultAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (adminPrincipalId != '') {
  name: guid(keyvault.id, adminPrincipalId)
  scope: keyvault
  properties: {
    principalId: adminPrincipalId
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleIds.KeyVaultSecretsUser)
    // Note also bug/limitation https://github.com/Azure/bicep/issues/2031#issuecomment-816743989
  }
}

resource tableDnsZone 'Microsoft.Network/privateDnsZones@2020-01-01' = {
  name: names.dnsZoneTable
  location: 'global'
  properties: { }

  resource dnsZoneLink 'virtualNetworkLinks@2020-01-01' = {
    name: names.dnsZoneTable
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: apiVnet.id
      }
    }
  }
}

resource vaultDnsZone 'Microsoft.Network/privateDnsZones@2020-01-01' = {
  name: names.dnsZoneKv
  location: 'global'
  properties: { }

  resource dnsZoneLink 'virtualNetworkLinks@2020-01-01' = {
    name: names.dnsZoneKv
    location: 'global'
    properties: {
      registrationEnabled: false
      virtualNetwork: {
        id: apiVnet.id
      }
    }
  }
}
