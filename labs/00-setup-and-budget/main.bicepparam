using 'main.bicep'

// Your alert email is read from an environment variable so it never gets committed.
// deploy.ps1 sets AZ104_ALERT_EMAIL from its -AlertEmail parameter.
param contactEmails = [
  readEnvironmentVariable('AZ104_ALERT_EMAIL', 'set-AZ104_ALERT_EMAIL@example.com')
]

param amount = 10
