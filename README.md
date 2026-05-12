# tf-adaptive-logs

Terraform module for managing [Grafana Cloud Adaptive Logs](https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/) resources as code.

## What is Adaptive Logs?

Adaptive Logs is a Grafana Cloud feature that reduces log storage cost by identifying log lines that are ingested but rarely (or never) queried, and dropping a configurable share of them at ingest time. It groups log lines into patterns, analyses query usage on a 15-day rolling window, and produces drop recommendations you can review, customise, or override.

This repository exposes the three resource types from the [Adaptive Logs API](https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/manage-as-code/adaptive-logs-api/) so they can be version-controlled, code-reviewed, and rolled out through normal Terraform pipelines.

| Entry point | Path | When to use |
| --- | --- | --- |
| Wrapper (root) | `.` | Manage segments, drop rules, and exemptions together as maps. Recommended for most users. |
| Segment sub-module | [`modules/segment`](modules/segment/) | Compose segments individually (e.g. across multiple stacks). |
| Drop-rule sub-module | [`modules/drop-rule`](modules/drop-rule/) | Compose drop rules individually. |
| Exemption sub-module | [`modules/exemption`](modules/exemption/) | Compose exemptions individually. |

There is no official Terraform provider for Adaptive Logs, so the modules wrap the REST API through the [Mastercard/restapi](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs) provider.

## Requirements

| Requirement | Notes |
| --- | --- |
| Terraform | `>= 1.5` |
| Provider | `Mastercard/restapi ~> 3.0` |
| Grafana Cloud | A stack with Loki and Adaptive Logs enabled |
| Loki URL | e.g. `https://logs-prod-012.grafana.net` — found under **Connections → Loki → Details** in Grafana Cloud |
| Tenant ID | Numeric instance ID from the same Loki details page |
| Access policy token | A Grafana Cloud Access Policy token scoped to `adaptive-logs:admin` |

The API authenticates with HTTP Basic auth where the username is the tenant ID and the password is the access policy token.

## Provider configuration

The modules expect a pre-configured `restapi` provider. The example shows the canonical configuration:

```hcl
provider "restapi" {
  uri                  = var.loki_url       # https://logs-prod-<region>.grafana.net
  write_returns_object = true
  id_attribute         = "id"

  headers = {
    Authorization = "Basic ${base64encode("${var.loki_tenant}:${var.loki_token}")}"
    Content-Type  = "application/json"
  }
}
```

A working end-to-end example lives in [examples/basic](examples/basic/). Copy `terraform.tfvars.example` to `terraform.tfvars`, fill in your credentials, and run `terraform init && terraform apply`.

## Usage — wrapper (recommended)

The root module takes three maps and fans them out with `for_each`. The map keys are stable, human-readable identifiers you control — use them in plan output, state addressing, and cross-references between drop rules and segments.

```hcl
module "adaptive_logs" {
  source = "github.com/grafana/tf-adaptive-logs?ref=v0.1.0"

  segments = {
    billing = {
      name     = "Billing API"
      selector = "{service_name=\"billing-api\"}"
    }
  }

  drop_rules = {
    debug-api-gateway = {
      name            = "Drop debug logs on api-gateway"
      stream_selector = "{service_name=\"api-gateway\"}"
      drop_rate       = 100
      levels          = ["debug"]
    }

    debug-billing = {
      segment         = "billing"      # references segments map key
      name            = "Drop debug logs on billing-api"
      stream_selector = "{service_name=\"billing-api\"}"
      drop_rate       = 100
      levels          = ["debug"]
    }
  }

  exemptions = {
    api-gateway-prod = {
      stream_selector = "{service_name=\"api-gateway\", env=\"prod\"}"
      reason          = "Investigating latency spike — keep full fidelity"
    }
  }
}
```

### Inputs

| Variable | Type | Description |
| --- | --- | --- |
| `segments` | `map(object)` | Segments keyed by local identifier. Required fields: `name`, `selector`. |
| `drop_rules` | `map(object)` | Drop rules keyed by local identifier. See [drop rule fields](#drop-rule-fields). |
| `exemptions` | `map(object)` | Exemptions keyed by local identifier. Required field: `stream_selector`. Optional: `reason`, `expires_at`. |

### Drop rule fields

| Field | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Human-readable rule name. |
| `stream_selector` | `string` | yes | — | LogQL stream selector matching the logs the rule applies to. |
| `drop_rate` | `number` | yes | — | Percentage of matching lines to drop, `0`–`100`. |
| `segment` | `string` | no | `"__global__"` | Segment key from `var.segments`, a literal segment ID, or `__global__` for tenant-wide. |
| `levels` | `list(string)` | no | `null` | Log levels to match — subset of `trace`, `debug`, `info`, `warn`, `error`, `critical`, `fatal`, `unknown`. Omit to match all. |
| `log_line_contains` | `list(string)` | no | `null` | Substrings the log line must contain for the rule to match. |
| `disabled` | `bool` | no | `false` | Create the rule disabled. |
| `expires_at` | `string` | no | `null` | RFC3339 timestamp after which the rule stops applying. Permanent if null. |
| `rule_version` | `number` | no | `1` | Optimistic-concurrency token sent as `version`. See [Troubleshooting](#troubleshooting) if an apply 409s. |

### Outputs

| Output | Description |
| --- | --- |
| `segment_ids` | Map from segment key to server-generated segment ID. |
| `drop_rule_ids` | Map from drop-rule key to server-generated rule ID. |
| `exemption_ids` | Map from exemption key to server-generated exemption ID. |

## Usage — sub-modules

Each resource type is also available as a stand-alone sub-module under [`modules/`](modules/). Use them when the wrapper's map-based shape doesn't fit — for example, when assembling resources across multiple stacks or composing with other Terraform configurations.

### `modules/segment`

Creates one Adaptive Logs segment.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | `string` | yes | Human-readable segment name. |
| `selector` | `string` | yes | LogQL selector. Only equality matchers or multi-literal regex matchers are accepted by the API. |

Outputs: `id` (server-generated, pass to drop-rule `rule.segment_id`), `name`.

### `modules/drop-rule`

Creates one user-defined drop rule. Takes a single `rule` object — see the [drop rule fields table](#drop-rule-fields) above for the schema. The sub-module's object uses `segment_id` (literal ID or `__global__`) rather than the wrapper's `segment` key, since there is no segments map to reference.

```hcl
module "drop_debug_billing" {
  source = "./modules/drop-rule"

  rule = {
    segment_id      = module.billing_segment.id
    name            = "Drop debug logs on billing-api"
    stream_selector = "{service_name=\"billing-api\"}"
    drop_rate       = 100
    levels          = ["debug"]
  }
}
```

Outputs: `id`.

### `modules/exemption`

Creates one exemption that protects logs matching a selector from being dropped.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| `stream_selector` | `string` | yes | LogQL stream selector identifying logs that must not be dropped. |
| `reason` | `string` | no | Business justification recorded with the exemption. |
| `expires_at` | `string` | no | RFC3339 timestamp after which the exemption stops applying. Permanent if null. |

Outputs: `id`.

> **Note:** the exemption sub-module is pinned with `lifecycle { ignore_changes = all }`. To change an exemption, recreate it — see [Troubleshooting](#troubleshooting).

## Importing existing resources

Adaptive Logs is typically configured in the Grafana UI before being moved to code. To bring an existing segment, drop rule, or exemption under Terraform management without recreating it, import its state.

First, fetch the resource ID from the API:

```bash
# Segments
curl -s -u "${LOKI_TENANT}:${LOKI_TOKEN}" "${LOKI_URL}/adaptive-logs/segment" | jq

# Drop rules
curl -s -u "${LOKI_TENANT}:${LOKI_TOKEN}" "${LOKI_URL}/adaptive-logs/drop-rules" | jq

# Exemptions
curl -s -u "${LOKI_TENANT}:${LOKI_TOKEN}" "${LOKI_URL}/adaptive-logs/exemptions" | jq
```

Then declare the resource in your Terraform code and import it. The form of the import ID is `<path>/<resource-id>`.

### Wrapper module

Use the map key in the Terraform address:

```bash
terraform import \
  'module.adaptive_logs.module.drop_rules["debug-billing"].restapi_object.this' \
  "/adaptive-logs/drop-rules/${RULE_ID}"

terraform import \
  'module.adaptive_logs.module.segments["billing"].restapi_object.this' \
  "/adaptive-logs/segment/${SEGMENT_ID}"

terraform import \
  'module.adaptive_logs.module.exemptions["api-gateway-prod"].restapi_object.this' \
  "/adaptive-logs/exemptions/${EXEMPTION_ID}"
```

### Terraform 1.5+ `import` blocks

For declarative, reviewable imports, write `import` blocks alongside your resource declarations and let `terraform plan` show the import in the plan output:

```hcl
import {
  to = module.adaptive_logs.module.drop_rules["debug-billing"].restapi_object.this
  id = "/adaptive-logs/drop-rules/abc123"
}
```

After the first successful apply, remove the `import` block.

### Sub-module direct usage

```bash
terraform import \
  'module.billing_segment.restapi_object.this' \
  "/adaptive-logs/segment/${SEGMENT_ID}"
```

After import, run `terraform plan` to verify there is no drift. If the plan wants to update the resource, reconcile the code with what the server holds before applying.

## Troubleshooting

### Drop rule apply returns HTTP 409

The API uses `version` as an optimistic-concurrency token: every successful update increments it server-side. If a rule was edited out-of-band (Grafana UI, another Terraform workspace, a direct API call), the version Terraform sends will be stale and the next apply will 409.

The fix is to resync local state with the server, then re-apply. Two options:

**1. Re-import the resource (preferred).** This refreshes the local state from the server, including the current `version`:

```bash
RULE_ID=$(terraform output -json drop_rule_ids | jq -r '.["debug-billing"]')

terraform state rm 'module.adaptive_logs.module.drop_rules["debug-billing"].restapi_object.this'
terraform import \
  'module.adaptive_logs.module.drop_rules["debug-billing"].restapi_object.this' \
  "/adaptive-logs/drop-rules/${RULE_ID}"
terraform apply
```

**2. Bump `rule_version` manually.** Query the current version from the API and set the field to match:

```bash
curl -s -u "${LOKI_TENANT}:${LOKI_TOKEN}" \
  "${LOKI_URL}/adaptive-logs/drop-rules/${RULE_ID}" \
  | jq '.version'
```

Then update the rule in your map:

```hcl
drop_rules = {
  debug-billing = {
    # ...
    rule_version = 4   # whatever the server reports + the apply you are about to make
  }
}
```

### Editing an exemption returns HTTP 500

The `Mastercard/restapi` provider issues a PUT containing the body it received on the previous read, but the Adaptive Logs API rejects that response-shaped body. The exemption sub-module works around this by pinning `lifecycle { ignore_changes = all }`, which means in-place edits are not possible. To change an exemption, recreate it:

```bash
terraform apply -replace='module.adaptive_logs.module.exemptions["api-gateway-prod"].restapi_object.this'
```

## Repository layout

```
main.tf, variables.tf, outputs.tf, versions.tf   # Root wrapper module
modules/
  segment/      # Adaptive Logs segments
  drop-rule/    # User-defined drop rules
  exemption/    # Drop-rule exemptions
examples/
  basic/        # End-to-end example, runnable against a real stack
tests/          # terraform test suite (see Testing section)
```

## Testing

The `tests/` directory holds a `terraform test` suite that covers payload encoding, variable validation, and root-module fan-out for every sub-module. Tests use `mock_provider "restapi" {}` and run `command = plan`, so they need no Grafana credentials and no network access.

Requirements:

| Tool | Minimum version | Why |
| --- | --- | --- |
| Terraform | `>= 1.7` | `mock_provider` blocks were added in 1.7. The module itself still works on `>= 1.5`; only the test runner needs 1.7+. |

Run the full suite from the repo root:

```bash
terraform init
terraform test
```

To run a single file or single `run` block:

```bash
terraform test -filter=tests/drop_rule.tftest.hcl
terraform test -verbose
```

## License

Licensed under the [Apache License, Version 2.0](LICENSE).
