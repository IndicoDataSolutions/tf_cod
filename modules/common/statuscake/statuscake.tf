resource "statuscake_ssl_check" "app-edge" {
  check_interval   = 43200 # every 12 hours
  user_agent       = "terraform managed SSL check"
  follow_redirects = true

  alert_config {
    alert_at    = [29, 7, 1]
    on_broken   = false
    on_expiry   = true
    on_mixed    = false
    on_reminder = true
  }

  contact_groups = [
    var.statuscake_devops_sa_contact_group_id
  ]

  monitored_resource {
    address = var.app_edge_url
  }
}

resource "statuscake_uptime_check" "app-edge" {
  check_interval = 60
  confirmation   = 3
  name           = var.cluster_name
  trigger_rate   = 10

  contact_groups = [
    var.statuscake_devops_sa_contact_group_id
  ]


  http_check {
    enable_cookies   = true
    follow_redirects = true
    timeout          = 20
    user_agent       = "terraform managed uptime check"
    validate_ssl     = true

    status_codes = [
      "204", "205", "206", "303", "400", "401", "403", "404",
      "405", "406", "408", "410", "413", "444", "429", "494",
      "495", "497", "499", "500", "501", "502", "503", "504",
      "505", "506", "507", "508", "509", "510", "511", "521",
      "522", "523", "524", "520", "598", "599"
    ]
  }



  monitored_resource {
    address = var.app_edge_url
  }

  tags = [
    "tf_cod"
  ]
}
