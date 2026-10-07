// Lab 00 - Subscription budget with email alerts (STARTER)
// Scope: subscription. Deploy with ./deploy.ps1 (runs what-if first).
//
// This starter already deploys a working budget with one alert at 50% of actual spend.
// Finish the TODOs, then compare with solution/main.bicep.
targetScope = 'subscription'

@description('Name of the monthly cost budget.')
param budgetName string = 'budget-az104-labs'

@description('Monthly budget amount in your billing currency (10 = $10 USD).')
@minValue(1)
param amount int = 10

@description('Email addresses that receive budget alerts. Set AZ104_ALERT_EMAIL or pass -AlertEmail to deploy.ps1.')
@minLength(1)
param contactEmails string[]

@description('Budget start date. Must be the first day of a month and not in the past. Defaults to the current UTC month.')
param startDate string = '${utcNow('yyyy-MM')}-01'

resource budget 'Microsoft.Consumption/budgets@2026-06-01' = {
  name: budgetName
  properties: {
    category: 'Cost'
    amount: amount
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: startDate
    }
    notifications: {
      actual50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
      // TODO: Add a second notification named actual80 that fires at 80% of ACTUAL spend.
      // TODO: Add a third notification named forecast100 that fires when the FORECAST reaches 100%.
      //       Hint: thresholdType accepts 'Actual' or 'Forecasted'.
    }
  }
}

output budgetId string = budget.id
// TODO: Add an output named budgetAmount (int) that returns budget.properties.amount.
