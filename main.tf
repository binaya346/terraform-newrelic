// Provider

terraform {
  required_providers {
    newrelic = {
      source  = "newrelic/newrelic"
      version = "3.26.0"
    }
  }
}

provider "newrelic" {
  account_id = "4154167"
  api_key    = "xxxxx" # usually prefixed with 'NRAK'
  region     = "US"                               # Valid regions are US and EU
}

resource "newrelic_notification_destination" "new_webhook_rundeck_auto_recover_service_destination" {
  name = "new-webhook-rundeck-auto-recover-service-destination"
  type = "WEBHOOK"

  property {
    key   = "url"
    value = "http://13.235.0.73:4440/api/41/webhook/QpGMFVfz8eT4Im8p3fsRn1gtNsgBfbwQ#EC2_Auto_Recovery_"
  }
}



resource "newrelic_notification_channel" "webhook_auto_recover_service_channel" {
  name           = "rundeck-auto-recover-service-channel-webhook"
  type           = "WEBHOOK"
  destination_id = newrelic_notification_destination.new_webhook_rundeck_auto_recover_service_destination.id
  product        = "IINT"

  property {
    key   = "payload"
    value = <<-eof
    {
	"host": {{ json accumulations.tag.hostname.[0] }},
	"condition_name": {{ json accumulations.conditionName.[0] }},
	"timestamp": {{ createdAt }},
	"instance_id" : {{ json accumulations.tag.host.id.[0] }}
    }
    eof
  }
}

resource "newrelic_workflow" "workflow_auto_recover_service" {
  name                  = "auto-recover-service-"
  muting_rules_handling = "NOTIFY_ALL_ISSUES"

  issues_filter {
    name = "filter--project--generic"
    type = "FILTER"

    predicate {
      attribute = "labels.policyIds"
      operator  = "EXACTLY_MATCHES"
      values    = ["4795556"]
    }

    # predicate {
    #   attribute = "state"
    #   operator  = "DOES_NOT_EQUAL"
    #   values    = ["CLOSED"]
    # }
  }

  destination {
    channel_id = newrelic_notification_channel.webhook_auto_recover_service_channel.id
  }

}

resource "newrelic_alert_policy" "generic_policy" {
  name                = "Project Generic"
  incident_preference = "PER_CONDITION"
}

resource "newrelic_infra_alert_condition" "cpu" {
  policy_id = newrelic_alert_policy.generic_policy.id

  name        = "High CPU usage"
  description = "Warning if CPU usage goes above 60% and critical alert if goes above 80%"
  type        = "infra_metric"
  event       = "SystemSample"
  select      = "cpuPercent"
  comparison  = "above"

  critical {
    duration      = 5
    value         = 90
    time_function = "all"
  }
}

resource "newrelic_infra_alert_condition" "memory" {
  policy_id = newrelic_alert_policy.generic_policy.id

  name        = "High Memory usage"
  description = "Critical alert if memory usage goes above 90% for 5 minutes"
  type        = "infra_metric"
  event       = "SystemSample"
  select      = "memoryUsedPercent"
  comparison  = "above"

  critical {
    duration      = 5
    value         = 90
    time_function = "all"
  }
}

resource "newrelic_infra_alert_condition" "host_not_reporting" {
  policy_id = newrelic_alert_policy.generic_policy.id

  name        = "Host not reporting"
  description = "Critical alert when the host is not reporting"
  type        = "infra_host_not_reporting"

  critical {
    duration = 5
  }
}
