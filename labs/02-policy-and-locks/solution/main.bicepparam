using 'main.bicep'

// Keep this in sync with the region you deploy to (deploy.ps1 -Location).
param allowedLocations = [
  'southcentralus'
  'centralus'
]

param requiredTagName = 'costCenter'
param lockLevel = 'CanNotDelete'
