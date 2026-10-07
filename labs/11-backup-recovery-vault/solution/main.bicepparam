using 'main.bicep'

// deploy.ps1 reads your SSH public key into this variable.
param adminPublicKey = readEnvironmentVariable('AZ104_ADMIN_SECRET', '')

param backupTimeUtc = '05:00'
param dailyRetentionDays = 7
param softDeleteState = 'Disabled'
