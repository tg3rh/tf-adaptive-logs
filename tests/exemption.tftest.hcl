mock_provider "restapi" {}

run "minimal_payload_has_only_stream_selector" {
  command = plan

  module {
    source = "./modules/exemption"
  }

  variables {
    stream_selector = "{service_name=\"frontend-service\", env=\"prod\"}"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).stream_selector == "{service_name=\"frontend-service\", env=\"prod\"}"
    error_message = "stream_selector not encoded"
  }

  assert {
    condition     = !contains(keys(jsondecode(restapi_object.this.data)), "reason")
    error_message = "reason key must be absent when var.reason is null"
  }

  assert {
    condition     = !contains(keys(jsondecode(restapi_object.this.data)), "expires_at")
    error_message = "expires_at key must be absent when var.expires_at is null"
  }
}

run "encodes_reason_and_expires_at_when_set" {
  command = plan

  module {
    source = "./modules/exemption"
  }

  variables {
    stream_selector = "{service_name=\"frontend-service\"}"
    reason          = "Investigating latency spike - keep full fidelity"
    expires_at      = "2026-12-31T00:00:00Z"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).reason == "Investigating latency spike - keep full fidelity"
    error_message = "reason not encoded"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).expires_at == "2026-12-31T00:00:00Z"
    error_message = "expires_at not encoded"
  }
}

run "update_data_equals_create_data" {
  command = plan

  module {
    source = "./modules/exemption"
  }

  variables {
    stream_selector = "{service_name=\"x\"}"
    reason          = "test"
  }

  assert {
    condition     = restapi_object.this.update_data == restapi_object.this.data
    error_message = "update_data must equal data so the PUT body matches the create body (PUT-on-read workaround)"
  }
}

run "id_attribute_is_result_id" {
  command = plan

  module {
    source = "./modules/exemption"
  }

  variables {
    stream_selector = "{service_name=\"x\"}"
  }

  assert {
    condition     = restapi_object.this.id_attribute == "result/id"
    error_message = "id_attribute must be 'result/id' to pull the ID out of the wrapped response"
  }
}

run "rejects_selector_without_braces" {
  command = plan

  module {
    source = "./modules/exemption"
  }

  variables {
    stream_selector = "service_name=x"
  }

  expect_failures = [
    var.stream_selector,
  ]
}

run "rejects_invalid_expires_at" {
  command = plan

  module {
    source = "./modules/exemption"
  }

  variables {
    stream_selector = "{service_name=\"x\"}"
    expires_at      = "not-a-date"
  }

  expect_failures = [
    var.expires_at,
  ]
}
