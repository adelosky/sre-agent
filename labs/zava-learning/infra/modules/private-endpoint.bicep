// Private endpoint + private DNS zone for the Key Vault. Required because tenant policy forces
// publicNetworkAccess=Disabled; without this the Container Apps cannot resolve the pg-password secret reference.

@description('Azure region for all resources.')
param location string
@description('Resource name suffix token.')
param resourceToken string
@description('Tags applied to all resources.')
param tags object = {}
@description('Subnet where the NIC lands.')
param subnetId string
@description('Private Link ID of the key vault.')
param keyVaultId string
@description('Zone for the vNet link.')
param vnetId string

resource kvPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.vaultcore.azure.net'
  location: 'global'
  tags: tags
}

resource kvDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name: 'vnetlink-privdns-${resourceToken}'
  parent: kvPrivateDnsZone
  location: 'global'
  tags: tags
  properties: {
        virtualNetwork: { id: vnetId }
        registrationEnabled: false
        }
}

resource kvPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-11-01' = {
  name: 'pe-kv-${resourceToken}'
  location: location
  tags: tags
  properties: {
        subnet: { id: subnetId }
        privateLinkServiceConnections: [
          {
            name: 'plconnect'
            properties: {
              privateLinkServiceId: keyVaultId
              groupIds: [ 'vault' ]
            }
          }
        ]
  }
}

@description('Registers the vault A-record in the private DNS zone so callers resolve the private IP.')
resource kvDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-11-01' = {
  name: 'default'
  parent: kvPrivateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-vaultcore-azure-net'
        properties: {
          privateDnsZoneId: kvPrivateDnsZone.id
        }
      }
    ]
  }
}

output privateEndpointId string = kvPrivateEndpoint.id
output dnsZoneName string = kvPrivateDnsZone.name
@description('Resource id of the private DNS zone (use to order dependent modules).')
output dnsZoneId string = kvPrivateDnsZone.id