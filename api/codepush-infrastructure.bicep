// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

param project_suffix string
param az_location string = 'eastus'
param github_client_id string
@secure()
param github_client_secret string

param app_github_client_id string
@secure()
param app_github_client_secret string
param microsoft_client_id string
@secure()
param microsoft_client_secret string
param logging bool = true

var servicePlanName = 'codepush-asp-${project_suffix}'
var storageAccountName = 'codepushstorage${project_suffix}'
var webAppName = 'codepush-${project_suffix}'
var cacheName = 'codepush-cache-${project_suffix}'
var cacheHost = 'codepush-cache-${project_suffix}.redis.cache.windows.net'
var serverUrl = 'https://codepush-${project_suffix}.azurewebsites.net'
var appServerUrl = 'http://localhost:4000'

targetScope = 'resourceGroup'

resource servicePlan 'Microsoft.Web/serverfarms@2023-01-01' = {
  name: servicePlanName
  location: az_location
  properties: {
    reserved: true
  }
  sku: {
    name: 'B1'
    tier: 'Standard'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: az_location
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: true
    publicNetworkAccess: 'Enabled'
  }
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webAppName
  location: az_location
  properties: {
    serverFarmId: servicePlan.id
    httpsOnly: true
    siteConfig: {
      minTlsVersion: '1.2'
      alwaysOn: true
      linuxFxVersion: 'NODE|18-lts'
      scmType: 'LocalGit'
      appSettings: [
        { name: 'AZURE_STORAGE_ACCOUNT', value: storageAccount.name }
        { name: 'AZURE_STORAGE_ACCESS_KEY', value: storageAccount.listKeys().keys[0].value }
        { name: 'GITHUB_CLIENT_ID', value: github_client_id }
        { name: 'GITHUB_CLIENT_SECRET', value: github_client_secret }
        { name: 'APP_GITHUB_CLIENT_ID', value: app_github_client_id }
        { name: 'APP_GITHUB_CLIENT_SECRET', value: app_github_client_secret }
        { name: 'MICROSOFT_CLIENT_ID', value: microsoft_client_id }
        { name: 'MICROSOFT_CLIENT_SECRET', value: microsoft_client_secret }
        { name: 'WEBSITE_NODE_DEFAULT_VERSION', value: '18-lts' }
        { name: 'SERVER_URL', value: serverUrl }
        { name: 'CORS_ORIGIN', value: serverUrl }
        { name: 'APP_SERVER_URL', value: appServerUrl }
        { name: 'LOGGING', value: logging ? 'true' : 'false' }
        { name: 'REDIS_HOST', value: cacheHost }
        { name: 'REDIS_PORT', value: '6380' }
        { name: 'REDIS_TLS_ENABLED', value: 'true' }
        { name: 'REDIS_KEY', value: cache.listKeys().primaryKey }
      ]
    }
  }
}

resource scmBasicAuth 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2023-01-01' = {
  name: 'scm'
  parent: webApp
  properties: {
    allow: true
  }
}

resource cache 'Microsoft.Cache/redis@2024-11-01' = {
  name: cacheName
  location: az_location
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 0 // Smallest instance type (C0)
    }
    enableNonSslPort: false // no 6379. only 6380
    redisVersion: '6' // the latest one supported by Azure Basic tier
  }
}
