param location string = resourceGroup().location
param bastionPublicIpName string = 'pip-bas-cac-001'
param bastionName string = 'bas-pvaks-cac-001'
param vmName string = 'vm-1'
@minLength(3)
param vmUsername string = 'vmuser'
@secure()
param vmPassword string

// ACR name must be globally unique
param acrName string = 'acrpvaksindev001'
@allowed([ 'Standard_D2s_v3','Standard_D2_v2' ])
param vmSize string = 'Standard_D2s_v3'

resource vnetHub 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-hub'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.0.0.0/16' ]
    }
    subnets: [
      {
        name: 'AzureBastionSubnet'
        properties: { addressPrefix: '10.0.0.0/27' }
      }
      {
        name: 'snet-global'
        properties: {
          addressPrefix: '10.0.1.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
    ]
  }
}

resource vnetAks 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: 'vnet-aks'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [ '10.1.0.0/16' ]
    }
    subnets: [
      {
        name: 'snet-agw'
        properties: { addressPrefix: '10.1.0.0/24' }
      }
      {
        name: 'snet-aks'
        properties: {
          addressPrefix: '10.1.1.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-utils'
        properties: {
          addressPrefix: '10.1.2.0/24'
          privateEndpointNetworkPolicies: 'Enabled'
        }
      }
      {
        name: 'snet-services'
        properties: { addressPrefix: '10.1.3.0/24' }
      }
    ]
  }
}

// VNET peering (hub -> aks)
resource peeringHubToAks 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: vnetHub
  name: 'peer-to-vnet-aks'
  properties: {
    remoteVirtualNetwork: {
      id: vnetAks.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: true
  }
}

resource peeringAksToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2021-05-01' = {
  parent: vnetAks
  name: 'peer-to-vnet-hub'
  properties: {
    remoteVirtualNetwork: {
      id: vnetHub.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

// --------------------
// Bastion
// --------------------
resource bastionPip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: bastionPublicIpName
  location: location
  sku: { name: 'Standard' }
  properties: { publicIPAllocationMethod: 'Static' }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2021-05-01' = {
  name: bastionName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'configuration'
        properties: {
          subnet: { id: '${vnetHub.id}/subnets/AzureBastionSubnet' }
          publicIPAddress: { id: bastionPip.id }
        }
      }
    ]
  }
}

// --------------------
// Virtual machine (Windows) + NIC
// --------------------
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: 'nic-vm-1'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'internal'
        properties: {
          subnet: { id: '${vnetHub.id}/subnets/snet-global' }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: { vmSize: vmSize }
    osProfile: {
      computerName: vmName
      adminUsername: vmUsername
      adminPassword: vmPassword
      windowsConfiguration: { provisionVMAgent: true }
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        caching: 'ReadWrite'
        managedDisk: { storageAccountType: 'Standard_LRS' }
      }
      imageReference: {
        publisher: 'microsoftwindowsdesktop'
        offer: 'windows-11'
        sku: 'win11-23h2-ent'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [ { id: nic.id } ]
    }
  }
}

// --------------------
// Container Registry + Private Endpoint + Private DNS
// --------------------
resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' = {
  name: acrName
  location: location
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    policies: { trustPolicy: null }
    publicNetworkAccess: 'Disabled'
  }
}

resource acrPrivateDns 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: 'privatelink.azurecr.io'
  location: 'global'
  properties: {}
}

resource acrLinkHub 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${acrPrivateDns.name}/pdznl-acr-cac-001'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetHub.id }
    registrationEnabled: false
  }
}

resource acrLinkAks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${acrPrivateDns.name}/pdznl-acr-cac-002'
  location: 'global'
  properties: {
    virtualNetwork: { id: vnetAks.id }
    registrationEnabled: false
  }

resource acrPe 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: 'pe-acr-cac-001'
   location: location
  properties: {
    subnet: { id: '${vnetHub.id}/subnets/snet-global' }
    privateLinkServiceConnections: [
      {
        name: 'psc-acr-cac-001'
        properties: {
          privateLinkServiceId: acr.id
          groupIds: [ 'registry' ]
          requestMessage: 'Auto-approved by deployment'
        }
      }
    ]
  }
}
