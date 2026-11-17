// Deploys the container to Azure Container Apps.
//
// Three resources:
//   1. Log Analytics workspace   - where the container logs end up
//   2. Container Apps environment - the shared runtime the app lives in
//   3. Container App              - the app itself, reachable over HTTPS

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Short name used in every resource name.')
@minLength(3)
@maxLength(12)
param appName string = 'cicddemo'

@description('Deployment environment.')
@allowed([
  'dev'
  'test'
  'prod'
])
param environment string = 'dev'

@description('Full container image reference, for example ghcr.io/owner/repo:sha-abc1234.')
param image string

@description('Lowest number of replicas. 0 means the app scales to zero when idle and costs nothing.')
@minValue(0)
@maxValue(5)
param minReplicas int = 0

@description('Highest number of replicas under load.')
@minValue(1)
@maxValue(10)
param maxReplicas int = 2

var suffix = '${appName}-${environment}'
var tags = {
  project: appName
  environment: environment
  managed_by: 'bicep'
}

resource logs 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: 'log-${suffix}'
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: 'cae-${suffix}'
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logs.properties.customerId
        sharedKey: logs.listKeys().primarySharedKey
      }
    }
  }
}

resource app 'Microsoft.App/containerApps@2024-03-01' = {
  name: 'ca-${suffix}'
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      // A new revision replaces the old one only after it passes its health checks.
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8000
        allowInsecure: false // HTTP is redirected to HTTPS
        transport: 'auto'
      }
    }
    template: {
      containers: [
        {
          name: 'web'
          image: image
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'ENVIRONMENT'
              value: environment
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/healthz'
                port: 8000
              }
              periodSeconds: 30
            }
            {
              type: 'Readiness'
              httpGet: {
                path: '/healthz'
                port: 8000
              }
              initialDelaySeconds: 3
              periodSeconds: 10
            }
          ]
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        rules: [
          {
            name: 'http-load'
            http: {
              metadata: {
                concurrentRequests: '50'
              }
            }
          }
        ]
      }
    }
  }
}

@description('Public HTTPS address of the app.')
output url string = 'https://${app.properties.configuration.ingress.fqdn}'

@description('Name of the revision that is now live.')
output revision string = app.properties.latestRevisionName
