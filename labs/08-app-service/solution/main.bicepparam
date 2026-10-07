using 'main.bicep'

// F1 is free. Switch to S1 only for the slots/autoscale step, then switch back or clean up.
param skuName = readEnvironmentVariable('AZ104_APP_SKU', 'F1')
param instanceCount = 1
param linuxFxVersion = 'NODE|22-lts'
