@description('Environment name used in resource names and tags.')
param env string = 'dev'

@description('Azure region.')
param location string = resourceGroup().location

@description('Short base name for resources.')
@maxLength(18)
param baseName string = 'appcreator'

@description('Container image to deploy into Azure Container Apps.')
param containerImage string

@description('Postgres admin username.')
param postgresAdminLogin string

@secure()
@description('Postgres admin password.')
param postgresAdminPassword string

@secure()
@description('Application session secret.')
param sessionSecret string

@description('OIDC issuer URL.')
param oidcIssuer string

@description('OIDC app registration client id.')
param oidcClientId string

@secure()
@description('OIDC app registration client secret.')
param oidcClientSecret string

@description('Allowed email domains for SSO, comma separated.')
param oidcAllowedEmailDomains string = ''

var suffix = '${baseName}-${env}'
var unique = take(uniqueString(resourceGroup().id), 6)
var tags = {
  app: baseName
  env: env
}
var storageName = take(toLower('st${baseName}${env}${unique}'), 24)
var pgName = take('pg-${suffix}-${unique}', 63)
var dbName = 'app_creator'
var workspaceName = 'log-${suffix}'
var appInsightsName = 'appi-${suffix}'
var managedEnvName = 'cae-${suffix}'
var appName = 'ca-${suffix}'
var identityName = 'id-${suffix}'
var keyVaultName = take('kv-${suffix}-${unique}', 24)

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  name: identityName
  location: location
  tags: tags
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: env == 'prod' ? 90 : 30
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  tags: tags
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: workspace.id
  }
}

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageName
  location: location
  tags: tags
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: storage
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: 30
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: 30
    }
  }
}

resource filesContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'app-files'
  properties: {
    publicAccess: 'None'
  }
}

resource postgres 'Microsoft.DBforPostgreSQL/flexibleServers@2023-06-01-preview' = {
  name: pgName
  location: location
  tags: tags
  sku: {
    name: env == 'prod' ? 'Standard_D2s_v3' : 'Standard_B1ms'
    tier: env == 'prod' ? 'GeneralPurpose' : 'Burstable'
  }
  properties: {
    administratorLogin: postgresAdminLogin
    administratorLoginPassword: postgresAdminPassword
    version: '16'
    storage: {
      storageSizeGB: env == 'prod' ? 128 : 32
    }
    backup: {
      backupRetentionDays: env == 'prod' ? 14 : 7
      geoRedundantBackup: 'Disabled'
    }
    highAvailability: {
      mode: 'Disabled'
    }
  }
}

resource database 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2023-06-01-preview' = {
  parent: postgres
  name: dbName
  properties: {
    charset: 'UTF8'
    collation: 'en_US.utf8'
  }
}

resource allowAzure 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2023-06-01-preview' = {
  parent: postgres
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    tenantId: subscription().tenantId
    sku: {
      family: 'A'
      name: 'standard'
    }
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 90
    enablePurgeProtection: env == 'prod'
  }
}

resource kvSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, identity.id, 'kv-secrets-user')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: managedEnvName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: workspace.properties.customerId
        sharedKey: workspace.listKeys().primarySharedKey
      }
    }
  }
}

var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};AccountKey=${storage.listKeys().keys[0].value};EndpointSuffix=${environment().suffixes.storage}'
var databaseUrl = 'postgresql://${postgresAdminLogin}:${postgresAdminPassword}@${postgres.properties.fullyQualifiedDomainName}:5432/${dbName}?sslmode=require&schema=public'

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: appName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 3000
        transport: 'auto'
      }
      secrets: [
        {
          name: 'database-url'
          value: databaseUrl
        }
        {
          name: 'storage-connection-string'
          value: storageConnectionString
        }
        {
          name: 'session-secret'
          value: sessionSecret
        }
        {
          name: 'oidc-client-secret'
          value: oidcClientSecret
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'web'
          image: containerImage
          env: [
            {
              name: 'NODE_ENV'
              value: 'production'
            }
            {
              name: 'AUTH_MODE'
              value: 'oidc'
            }
            {
              name: 'DATABASE_URL'
              secretRef: 'database-url'
            }
            {
              name: 'AZURE_STORAGE_CONNECTION_STRING'
              secretRef: 'storage-connection-string'
            }
            {
              name: 'AZURE_STORAGE_CONTAINER'
              value: 'app-files'
            }
            {
              name: 'SESSION_SECRET'
              secretRef: 'session-secret'
            }
            {
              name: 'OIDC_ISSUER'
              value: oidcIssuer
            }
            {
              name: 'OIDC_CLIENT_ID'
              value: oidcClientId
            }
            {
              name: 'OIDC_CLIENT_SECRET'
              secretRef: 'oidc-client-secret'
            }
            {
              name: 'OIDC_ALLOWED_EMAIL_DOMAINS'
              value: oidcAllowedEmailDomains
            }
            {
              name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
              value: appInsights.properties.ConnectionString
            }
          ]
          resources: {
            cpu: env == 'prod' ? json('1.0') : json('0.5')
            memory: env == 'prod' ? '2Gi' : '1Gi'
          }
        }
      ]
      scale: {
        minReplicas: env == 'prod' ? 1 : 0
        maxReplicas: env == 'prod' ? 5 : 1
      }
    }
  }
}

output appUrl string = 'https://${app.properties.configuration.ingress.fqdn}'
output postgresHost string = postgres.properties.fullyQualifiedDomainName
output storageAccount string = storage.name
