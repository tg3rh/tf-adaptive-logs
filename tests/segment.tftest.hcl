mock_provider "restapi" {}

run "encodes_name_and_selector" {
  command = plan

  module {
    source = "./modules/segment"
  }

  variables {
    name     = "Frontend-Service"
    selector = "{service_name=\"frontend-service\"}"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).name == "Frontend-Service"
    error_message = "segment payload missing or wrong name"
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).selector == "{service_name=\"frontend-service\"}"
    error_message = "segment payload missing or wrong selector"
  }

  assert {
    condition     = restapi_object.this.path == "/adaptive-logs/segment"
    error_message = "segment path incorrect"
  }

  assert {
    condition     = restapi_object.this.read_path == "/adaptive-logs/segment?segment={id}"
    error_message = "segment read_path must include ?segment={id}"
  }

  assert {
    condition     = restapi_object.this.update_path == "/adaptive-logs/segment?segment={id}"
    error_message = "segment update_path must include ?segment={id}"
  }

  assert {
    condition     = restapi_object.this.destroy_path == "/adaptive-logs/segment?segment={id}"
    error_message = "segment destroy_path must include ?segment={id}"
  }

  assert {
    condition     = restapi_object.this.ignore_all_server_changes == true
    error_message = "segment must set ignore_all_server_changes=true (server reshapes the body on read)"
  }
}

run "rejects_selector_without_braces" {
  command = plan

  module {
    source = "./modules/segment"
  }

  variables {
    name     = "Bad"
    selector = "service_name=\"frontend-service\""
  }

  expect_failures = [
    var.selector,
  ]
}
