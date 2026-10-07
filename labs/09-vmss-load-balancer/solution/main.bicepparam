using 'main.bicep'

// deploy.ps1 reads your SSH public key into this variable.
param adminPublicKey = readEnvironmentVariable('AZ104_ADMIN_SECRET', '')

param vmSize = 'Standard_B1s'
param instanceCount = 2
