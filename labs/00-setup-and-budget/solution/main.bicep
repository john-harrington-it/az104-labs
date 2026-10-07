// Lab 00 - Subscription budget with email alerts (reference solution)
// Scope: subscription. Deploy with: az deployment sub create --location <region> ...
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
      // Actual spend reaches 50% of the budget.
      actual50: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
      // Actual spend reaches 80% of the budget.
      actual80: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
      // Azure forecasts you will go over budget by the end of the month.
      forecast100: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: contactEmails
      }
    }
  }
}

output budgetId string = budget.id
output budgetAmount int = budget.properties.amount
