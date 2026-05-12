mock_provider "restapi" {
  mock_resource "restapi_object" {
    defaults = {
      id = "mock-id"
    }
  }
}

run "empty_inputs_yield_empty_outputs" {
  command = plan

  variables {
    segments   = {}
    drop_rules = {}
    exemptions = {}
  }

  assert {
    condition     = length(output.segment_ids) == 0
    error_message = "segment_ids must be empty when segments={}"
  }

  assert {
    condition     = length(output.drop_rule_ids) == 0
    error_message = "drop_rule_ids must be empty when drop_rules={}"
  }

  assert {
    condition     = length(output.exemption_ids) == 0
    error_message = "exemption_ids must be empty when exemptions={}"
  }
}

run "output_keys_match_input_keys" {
  command = plan

  variables {
    segments = {
      billing = { name = "Billing", selector = "{service=\"billing\"}" }
      orders  = { name = "Orders", selector = "{service=\"orders\"}" }
    }
    drop_rules = {
      drop-debug = {
        name            = "Drop debug"
        stream_selector = "{service=\"x\"}"
        drop_rate       = 100
        levels          = ["debug"]
      }
    }
    exemptions = {
      keep-prod = {
        stream_selector = "{env=\"prod\"}"
        reason          = "compliance"
      }
    }
  }

  assert {
    condition     = sort(keys(output.segment_ids)) == tolist(["billing", "orders"])
    error_message = "segment_ids keys must mirror var.segments keys"
  }

  assert {
    condition     = keys(output.drop_rule_ids) == ["drop-debug"]
    error_message = "drop_rule_ids keys must mirror var.drop_rules keys"
  }

  assert {
    condition     = keys(output.exemption_ids) == ["keep-prod"]
    error_message = "exemption_ids keys must mirror var.exemptions keys"
  }
}

run "drop_rule_segment_reference_resolves_to_module_segment_id" {
  command = apply

  variables {
    segments = {
      billing = { name = "Billing", selector = "{service=\"billing\"}" }
    }
    drop_rules = {
      drop-billing-debug = {
        name            = "Drop debug on billing"
        stream_selector = "{service=\"billing\"}"
        drop_rate       = 100
        segment         = "billing"
      }
    }
    exemptions = {}
  }

  assert {
    condition     = jsondecode(module.drop_rules["drop-billing-debug"].data).segment_id == "mock-id"
    error_message = "segment='billing' must resolve to module.segments['billing'].id"
  }
}

run "drop_rule_segment_falls_through_when_key_absent" {
  command = apply

  variables {
    segments = {}
    drop_rules = {
      tenant-wide = {
        name            = "Drop all debug"
        stream_selector = "{a=\"b\"}"
        drop_rate       = 100
        segment         = "__global__"
      }
    }
    exemptions = {}
  }

  assert {
    condition     = jsondecode(module.drop_rules["tenant-wide"].data).segment_id == "__global__"
    error_message = "unknown segment key must fall through unchanged (no module.segments lookup match)"
  }
}

run "drop_rule_segment_defaults_to_global_when_omitted" {
  command = apply

  variables {
    segments = {}
    drop_rules = {
      default-scoped = {
        name            = "Drop"
        stream_selector = "{a=\"b\"}"
        drop_rate       = 50
      }
    }
    exemptions = {}
  }

  assert {
    condition     = jsondecode(module.drop_rules["default-scoped"].data).segment_id == "__global__"
    error_message = "omitting segment must default to __global__"
  }
}
