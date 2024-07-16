@description('Parameters for template')
param functionAppName string
param resourceLocation string
param jss string
param jssPass string
param jssUser string

@description('Variables for template')
var accountNameCosmos = toLower(functionAppName)
var cosmosURI = 'https://${accountNameCosmos}.documents.azure.com:443/'
var cosmosKey = cosmosDB.listKeys().primaryMasterKey
var resourcePrefix  = 'jamfsync'
var storageSkuName = 'Standard_LRS'
var resourceSuffix = substring(uniqueString(resourceGroup().id), 0, 7)
var storageAccountName = '${resourcePrefix}storage${resourceSuffix}'
var storageConnectionString = 'DefaultEndpointsProtocol=https;AccountName=${storage.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storage.listKeys().keys[0].value}'
var appInsightsConnectionString = reference(resourceId('Microsoft.Insights/components', functionAppName), '2020-02-02').InstrumentationKey

///////////////////////////////
// Begin Cosmos DB resources //
///////////////////////////////
resource cosmosDB 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: accountNameCosmos
  location: resourceLocation
  tags: {
    defaultExperience: 'Core (SQL)'
    'hidden-cosmos-mmspecial': ''
  }
  kind: 'GlobalDocumentDB'
  identity: {
    type: 'None'
  }
  properties: {
    publicNetworkAccess: 'Enabled'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    disableKeyBasedMetadataWriteAccess: false
    enableFreeTier: false
    enableAnalyticalStorage: true
    analyticalStorageConfiguration: {
      schemaType: 'WellDefined'
    }
    databaseAccountOfferType: 'Standard'
    defaultIdentity: 'FirstPartyIdentity'
    networkAclBypass: 'None'
    disableLocalAuth: false
    enablePartitionMerge: false
    minimalTlsVersion: 'Tls'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
      maxIntervalInSeconds: 5
      maxStalenessPrefix: 100
    }
    locations: [
      {
        locationName: resourceLocation
        provisioningState: 'Succeeded'
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    cors: [
      {
        allowedOrigins: 'https://functions.azure.com, https://portal.azure.com'
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    ipRules: []
    backupPolicy: {
      type: 'Periodic'
      periodicModeProperties: {
        backupIntervalInMinutes: 240
        backupRetentionIntervalInHours: 8
        backupStorageRedundancy: 'Geo'
      }
    }
    networkAclBypassResourceIds: []
    capacity: {
      totalThroughputLimit: 4000
    }
    keysMetadata: {}
  }
}

resource cosmosDBSqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-04-15' = {
  name: '${accountNameCosmos}/Jamf Pro Cosmos'
  dependsOn: [cosmosDB]
  properties: {
    resource: {
      id: 'Jamf Pro Cosmos'
    }
  }
}

var containerNames = [
  'computer-application-usage'
  'computer-history'
  'computers'
  'historical-data'
  'last-sync'
  'mobile-devices'
]

resource cosmosDBContainers 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-04-15' = [for containerName in containerNames: {
  name: '${accountNameCosmos}/Jamf Pro Cosmos/${containerName}'
  dependsOn: [
    cosmosDB
    cosmosDBSqlDatabase
  ]
  properties: {
    resource: {
      id: containerName
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
        version: 2
      }
      uniqueKeyPolicy: {
        uniqueKeys: []
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}]

resource cosmosDBSqlRoleDefinitionsDataReader 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2023-04-15' = {
    name: '${accountNameCosmos}/00000000-0000-0000-0000-000000000001'
    dependsOn: [cosmosDB]
    properties: {
      roleName: 'Cosmos DB Built-in Data Reader'
      type: 'BuiltInRole'
      assignableScopes: [
        cosmosDB.id
      ]
      permissions: [
        {
          dataActions: [
            'Microsoft.DocumentDB/databaseAccounts/readMetadata'
            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/executeQuery'
            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/readChangeFeed'
            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/read'
          ]
          notDataActions: []
        }
      ]
    }
  }

  resource cosmosDBSqlRoleDefinitionsContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2023-04-15' = {
    name: '${accountNameCosmos}/00000000-0000-0000-0000-000000000002'
    dependsOn: [cosmosDB]
    properties: {
      roleName: 'Cosmos DB Built-in Data Contributor'
      type: 'BuiltInRole'
      assignableScopes: [
        cosmosDB.id
      ]
      permissions: [
        {
          dataActions: [
            'Microsoft.DocumentDB/databaseAccounts/readMetadata'
            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
            'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
          ]
          notDataActions: []
        }
      ]
    }
  }
/////////////////////////////
// End Cosmos DB resources //
/////////////////////////////

/////////////////////////////////////////
// Begin Azure Function App resources //
/////////////////////////////////////////
resource storage 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: resourceLocation
  sku: {
    name: storageSkuName
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    encryption: {
      keySource: 'Microsoft.Storage'
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
        queue: {
          enabled: true
        }
        table: {
          enabled: true
        }
      }
    }
  }
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  dependsOn: [cosmosDB]
  location: resourceLocation
  kind: 'functionapp,linux'
  properties: {
    enabled: true
    hostNameSslStates: [
      {
        name: '${functionAppName}.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Standard'
      }
      {
        name: '${functionAppName}.scm.azurewebsites.net'
        sslState: 'Disabled'
        hostType: 'Repository'
      }
    ]
    reserved: true
    isXenon: false
    hyperV: false
    vnetRouteAllEnabled: false
    vnetImagePullEnabled: false
    vnetContentShareEnabled: false
    siteConfig: {
      numberOfWorkers: 1
      linuxFxVersion: 'Python|3.11'
      acrUseManagedIdentityCreds: false
      alwaysOn: false
      http20Enabled: false
      functionAppScaleLimit: 5
      minimumElasticInstanceCount: 0
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsightsConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'JSS'
          value: jss
        }
        {
          name: 'JSSUSER'
          value: jssUser
        }
        {
          name: 'JSSPASS'
          value: jssPass
        }
        {
          name: 'COMPUTER_APPLICATION_USAGE_DAYS_AGO'
          value: '1825'
        }
        {
          name: 'SYNC_COMPUTERS'
          value: 'True'
        }
        {
          name: 'SYNC_MOBILE_DEVICES'
          value: 'True'
        }
        {
          name: 'SYNC_APPS_HISTORICAL'
          value: 'True'
        }
        {
          name: 'SYNC_GROUPS_HISTORICAL'
          value: 'True'
        }
        {
          name: 'COSMOS_URI'
          value: cosmosURI
        }
        {
          name: 'COSMOS_KEY'
          value: cosmosKey
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'AzureWebJobsSecretStorageType'
          value: 'files'
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: 'true'
        }
      ]
    }
    scmSiteAlsoStopped: false
    clientAffinityEnabled: false
    clientCertEnabled: false
    clientCertMode: 'Required'
    hostNamesDisabled: false
    customDomainVerificationId: '5075D10DA89134DE94C1214A4B0C76D208F486FD2864A3B641C9EBEBC5007A73'
    containerSize: 1536
    dailyMemoryTimeQuota: 0
    httpsOnly: true
    redundancyMode: 'None'
    publicNetworkAccess: 'Enabled'
    storageAccountRequired: true
    keyVaultReferenceIdentity: 'SystemAssigned'
  }
}

resource ftpAccess 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  name: '${functionAppName}/ftp'
  location: resourceLocation
  dependsOn: [functionApp]
  properties: {
    allow: true
  }
}

resource scmAccess 'Microsoft.Web/sites/basicPublishingCredentialsPolicies@2022-09-01' = {
  name: '${functionAppName}/scm'
  location: resourceLocation
  dependsOn: [functionApp]
  properties: {
    allow: true
  }
}

resource webConfig 'Microsoft.Web/sites/config@2022-09-01' = {
  name: '${functionAppName}/web'
  location: resourceLocation
  dependsOn: [functionApp]
  properties: {
    numberOfWorkers: 1
    defaultDocuments: [
      'Default.htm'
      'Default.html'
      'Default.asp'
      'index.htm'
      'index.html'
      'iisstart.htm'
      'default.aspx'
      'index.php'
    ]
    netFrameworkVersion: 'v4.0'
    linuxFxVersion: 'python|3.9'
    requestTracingEnabled: false
    remoteDebuggingEnabled: false
    httpLogging: false

    Enabled: false
    acrUseManagedIdentityCreds: false
    logsDirectorySizeLimit: 35
    detailedErrorLoggingEnabled: false
    publishingUsername: '$${functionAppName}'
    scmType: 'None'
    use32BitWorkerProcess: false
    webSocketsEnabled: false
    alwaysOn: false
    managedPipelineMode: 'Integrated'
    virtualApplications: [
      {
        virtualPath: '/'
        physicalPath: 'site\\wwwroot'
        preloadEnabled: false
      }
    ]
    loadBalancing: 'LeastRequests'
    experiments: {
      rampUpRules: []
    }
    autoHealEnabled: false
    vnetRouteAllEnabled: false
    vnetPrivatePortsCount: 0
    publicNetworkAccess: 'Enabled'
    cors: {
      allowedOrigins: [
        'https://portal.azure.com'
        'https://functions.azure.com'
      ]
      supportCredentials: false
    }
    localMySqlEnabled: false
    ipSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictions: [
      {
        ipAddress: 'Any'
        action: 'Allow'
        priority: 2147483647
        name: 'Allow all'
        description: 'Allow all access'
      }
    ]
    scmIpSecurityRestrictionsUseMain: false
    http20Enabled: false
    minTlsVersion: '1.2'
    scmMinTlsVersion: '1.2'
    ftpsState: 'FtpsOnly'
    preWarmedInstanceCount: 0
    functionAppScaleLimit: 5
    functionsRuntimeScaleMonitoringEnabled: false
    minimumElasticInstanceCount: 0
    azureStorageAccounts: {}
  }
}

resource hostNameBinding 'Microsoft.Web/sites/hostNameBindings@2022-09-01' = {
  parent: functionApp
  name: '${functionAppName}.azurewebsites.net'
  properties: {
    siteName: functionAppName
    hostNameType: 'Verified'
  }
}

resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
  name: functionAppName
  location: resourceLocation
  tags: {
    'hidden-link:${resourceId('Microsoft.Web/sites', functionAppName)}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
  }
  kind: 'web'
}

resource zipDeploy 'Microsoft.Web/sites/extensions@2020-12-01' = {
  name: '${functionAppName}/zipdeploy'
  dependsOn: [functionApp]
  properties: {
    packageUri: 'https://masonjamfstorage.blob.core.windows.net/functionzip/Jamf-2024-04-26.zip?sp=r&st=2024-04-25T17:46:57Z&se=2025-09-30T01:46:57Z&spr=https&sv=2022-11-02&sr=b&sig=ekzMfRM47wSOUzdf3ZdK6uYsTma9zKTmJg19J3c%2F8FM%3D'
  }
}
//////////////////////////////////////
// End Azure Function App resources //
//////////////////////////////////////
