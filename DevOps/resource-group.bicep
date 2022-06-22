// This script creates the resource group for the API.

targetScope = 'subscription'

@description('Name of the project')
param projectName string = 'heroapi'

@description('Location of the resources')
param location string = 'westeurope'

@allowed([
  'dev'
  'test'
  'prod'
])
@description('Stage of the deployment, uses dev by default')
param stage string = 'dev'

resource rg 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: '${projectName}-${stage}'
  location: location
  tags: {
    Project: projectName
    Environment: stage
  }
}

output rgName string = rg.name
