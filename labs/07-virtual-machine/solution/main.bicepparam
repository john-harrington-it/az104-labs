using 'main.bicep'

// deploy.ps1 puts your SSH public key (Linux) or the password you type (Windows) in this variable.
param adminPasswordOrKey = readEnvironmentVariable('AZ104_ADMIN_SECRET', '')

param osType = readEnvironmentVariable('AZ104_OS_TYPE', 'Linux')
param vmSize = readEnvironmentVariable('AZ104_VM_SIZE', 'Standard_B1s')
param enableAutoShutdown = true
param autoShutdownTime = '1900'
param autoShutdownTimeZone = 'Central Standard Time'
