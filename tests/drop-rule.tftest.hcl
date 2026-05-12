mock_provider "restapi" {}

run "encodes_minimal_payload" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "Drop debug logs"
      stream_selector = "{service_name=\"orders\"}"
      drop_rate       = 100
    }
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).name == "Drop debug logs"
    error_message = "name not encoded"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).segment_id == "__global__"
    error_message = "segment_id should default to __global__"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).version == 1
    error_message = "rule_version should default to 1"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).disabled == false
    error_message = "disabled should default to false"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).body.stream_selector == "{service_name=\"orders\"}"
    error_message = "stream_selector must be nested under body"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).body.drop_rate == 100
    error_message = "drop_rate must be nested under body"
  }
}

run "strips_null_optional_fields" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "minimal"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 50
    }
  }

  assert {
    condition     = !contains(keys(jsondecode(restapi_object.this.data)), "expires_at")
    error_message = "expires_at must be absent when null"
  }

  assert {
    condition     = !contains(keys(jsondecode(restapi_object.this.data).body), "levels")
    error_message = "body.levels must be absent when null"
  }

  assert {
    condition     = !contains(keys(jsondecode(restapi_object.this.data).body), "log_line_contains")
    error_message = "body.log_line_contains must be absent when null"
  }
}

run "encodes_full_payload" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name              = "full"
      stream_selector   = "{service_name=\"x\"}"
      drop_rate         = 75
      segment_id        = "seg-123"
      levels            = ["debug", "info"]
      log_line_contains = ["healthcheck", "probe"]
      disabled          = true
      expires_at        = "2026-12-31T00:00:00Z"
      rule_version      = 4
    }
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).segment_id == "seg-123"
    error_message = "segment_id not encoded"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).disabled == true
    error_message = "disabled not encoded"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).version == 4
    error_message = "rule_version must serialise as 'version'"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).expires_at == "2026-12-31T00:00:00Z"
    error_message = "expires_at not encoded"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).body.levels[0] == "debug" && jsondecode(restapi_object.this.data).body.levels[1] == "info"
    error_message = "levels not encoded in body"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).body.log_line_contains[0] == "healthcheck"
    error_message = "log_line_contains not encoded in body"
  }
}

run "ignore_all_server_changes_enabled" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "x"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 1
    }
  }

  assert {
    condition     = restapi_object.this.ignore_all_server_changes == true
    error_message = "ignore_all_server_changes must be true (server returns response shape that drifts data)"
  }
}

run "rejects_stream_selector_without_braces" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "bad"
      stream_selector = "service_name=orders"
      drop_rate       = 50
    }
  }

  expect_failures = [var.rule]
}

run "rejects_drop_rate_above_100" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "bad"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 150
    }
  }

  expect_failures = [var.rule]
}

run "rejects_drop_rate_negative" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "bad"
      stream_selector = "{a=\"b\"}"
      drop_rate       = -1
    }
  }

  expect_failures = [var.rule]
}

run "accepts_drop_rate_boundary_zero" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "ok"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 0
    }
  }
}

run "accepts_drop_rate_boundary_hundred" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "ok"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 100
    }
  }
}

run "rejects_unknown_level" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "bad"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 50
      levels          = ["super-debug"]
    }
  }

  expect_failures = [var.rule]
}

run "accepts_full_level_whitelist" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "ok"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 50
      levels          = ["trace", "debug", "info", "warn", "error", "critical", "fatal", "unknown"]
    }
  }
}

run "rejects_invalid_expires_at" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "bad"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 50
      expires_at      = "next tuesday"
    }
  }

  expect_failures = [var.rule]
}

run "accepts_rfc3339_expires_at" {
  command = plan

  module {
    source = "./modules/drop-rule"
  }

  variables {
    rule = {
      name            = "ok"
      stream_selector = "{a=\"b\"}"
      drop_rate       = 50
      expires_at      = "2026-07-01T00:00:00Z"
    }
  }
}
