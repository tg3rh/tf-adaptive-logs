# tf-adaptive-logs

Terraform modules for managing [Grafana Cloud Adaptive Logs](https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/) resources as code.

## What is Adaptive Logs?

Adaptive Logs is a Grafana Cloud feature that reduces log storage cost by identifying log lines that are ingested but rarely (or never) queried, and dropping a configurable share of them at ingest time. It groups log lines into patterns, analyses query usage on a 15-day rolling window, and produces drop recommendations you can review, customise, or override.

This repository exposes the three resource types from the [Adaptive Logs API](https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/manage-as-code/adaptive-logs-api/) as Terraform modules so they can be version-controlled, code-reviewed, and rolled out through normal Terraform pipelines.

| Resource | Module | Purpose |
| --- | --- | --- |
| Segment | [modules/segment](modules/segment/) | Groups log streams by a shared label (team, service, env) so drop rules and recommendations can be scoped per-group. |
| Drop rule | [modules/drop-rule](modules/drop-rule/) | Drops a configurable percentage of log lines matching a LogQL stream selector, optionally filtered by log level or substring. |
| Exemption | [modules/exemption](modules/exemption/) | Protects logs matching a LogQL selector from being dropped — for compliance, debugging, or incident investigation. |

There is no official Terraform provider for Adaptive Logs, so the modules wrap the REST API through the [Mastercard/restapi](https://registry.terraform.io/providers/Mastercard/restapi/latest/docs) provider.

## Requirements

| Requirement | Notes |
| --- | --- |
| Terraform | `>= 1.5` |
| Provider | `Mastercard/restapi ~> 2.0` |
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

## Modules

### `modules/segment`

Creates an Adaptive Logs segment — a named group of log streams identified by a LogQL selector. Segments let you scope drop rules and recommendations to a team or service. The reserved id `__global__` represents the tenant-wide default segment and does not need to be created.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| `name` | `string` | yes | Human-readable segment name. |
| `selector` | `string` | yes | LogQL selector. Only equality matchers or multi-literal regex matchers are accepted by the API. |

Outputs: `id` (server-generated, pass to drop-rule `segment_id`), `name`.

### `modules/drop-rule`

Creates a user-defined drop rule that removes a percentage of matching log lines at ingest. Rules can be scoped to a segment or applied tenant-wide via `__global__`.

| Variable | Type | Required | Default | Description |
| --- | --- | --- | --- | --- |
| `name` | `string` | yes | — | Human-readable rule name. |
| `stream_selector` | `string` | yes | — | LogQL stream selector matching the logs the rule applies to. |
| `drop_rate` | `number` | yes | — | Percentage of matching lines to drop, `0`–`100`. |
| `segment_id` | `string` | no | `"__global__"` | Target segment. Use the `id` output of a `segment` module, or leave default for tenant-wide. |
| `levels` | `list(string)` | no | `null` | Log levels to match, e.g. `["debug", "info"]`. Omit to match all levels. |
| `log_line_contains` | `list(string)` | no | `null` | Substrings the log line must contain for the rule to match. |
| `disabled` | `bool` | no | `false` | Create the rule disabled. |
| `expires_at` | `string` | no | `null` | RFC3339 timestamp after which the rule stops applying. Permanent if null. |
| `rule_version` | `number` | no | `1` | Optimistic-concurrency token sent as `version`. Bump if the rule was edited out-of-band and the next apply 409s. |

Outputs: `id`.

### `modules/exemption`

Creates an exemption that protects logs matching a selector from being dropped, regardless of segment-level or global drop rules.

| Variable | Type | Required | Description |
| --- | --- | --- | --- |
| `stream_selector` | `string` | yes | LogQL stream selector identifying logs that must not be dropped. |
| `reason` | `string` | no | Business justification recorded with the exemption. |

Outputs: `id`.

> **Note:** the exemption module is pinned with `lifecycle { ignore_changes = all }`. The provider issues a PUT whenever any tracked attribute changes, and the API rejects the response-shaped body that ends up in state after the first read (HTTP 500). To change an exemption, recreate it:
>
> ```bash
> terraform apply -replace='module.<name>.restapi_object.this'
> ```

## Example

```hcl
module "billing_segment" {
  source = "./modules/segment"

  name     = "Billing API"
  selector = "{service_name=\"billing-api\"}"
}

module "drop_debug_billing" {
  source = "./modules/drop-rule"

  segment_id      = module.billing_segment.id
  name            = "Drop debug logs on billing-api"
  stream_selector = "{service_name=\"billing-api\"}"
  drop_rate       = 100
  levels          = ["debug"]
}

module "exempt_billing_prod" {
  source = "./modules/exemption"

  stream_selector = "{service_name=\"billing-api\", env=\"prod\"}"
  reason          = "Keep full fidelity while investigating latency regression"
}
```

## Repository layout

```
modules/
  segment/      # Adaptive Logs segments
  drop-rule/    # User-defined drop rules
  exemption/    # Drop-rule exemptions
examples/
  basic/        # End-to-end example, runnable against a real stack
```
