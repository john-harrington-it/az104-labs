using 'main.bicep'

// deploy.ps1 reads your SSH public key (~/.ssh/id_ed25519.pub or id_rsa.pub) into this variable.
param adminPasswordOrKey = readEnvironmentVariable('AZ104_ADMIN_SECRET', '')

param vmSize = 'Standard_B1s'
