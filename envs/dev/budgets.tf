resource "aws_budgets_budget" "monthly_cost" {
  name         = "${var.project_name}-${var.environment}-monthly-cost"
  budget_type  = "COST"
  limit_amount = "10"
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = false
    include_tax                = false
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 1
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 3
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 5
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 8
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 10
    threshold_type             = "ABSOLUTE_VALUE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_notification_email]
  }
}

resource "aws_budgets_budget_action" "deny_high_cost_provisioning" {
  budget_name        = aws_budgets_budget.monthly_cost.name
  action_type        = "APPLY_IAM_POLICY"
  approval_model     = "AUTOMATIC"
  notification_type  = "ACTUAL"
  execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/BudgetActionExecutionRole"

  action_threshold {
    action_threshold_type  = "ABSOLUTE_VALUE"
    action_threshold_value = 10
  }

  definition {
    iam_action_definition {
      policy_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/DenyHighCostProvisioningAtBudgetLimit"
      roles      = ["TerraformExecutionRole"]
    }
  }

  subscriber {
    subscription_type = "EMAIL"
    address           = var.budget_notification_email
  }
}
