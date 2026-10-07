using 'main.bicep'

// deploy.ps1 sets these from -AlertEmail and your signed-in identity.
param alertEmail = readEnvironmentVariable('AZ104_ALERT_EMAIL', 'set-AZ104_ALERT_EMAIL@example.com')
param dataContributorPrincipalId = readEnvironmentVariable('AZ104_PRINCIPAL_ID', '')
