using 'main.bicep'

param vnetAddressPrefix = '10.50.0.0/16'
param webSubnetPrefix = '10.50.1.0/24'
param appSubnetPrefix = '10.50.2.0/24'

// Your public IP as /32 to allow SSH/RDP to the web ASG (find it with: curl https://ifconfig.me). Empty = no rule.
param adminSourcePrefix = ''
