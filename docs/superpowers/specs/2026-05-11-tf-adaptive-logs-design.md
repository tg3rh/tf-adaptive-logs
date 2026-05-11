# Terraform Module for Grafana Adaptive Logs API — Design

**Date:** 2026-05-11
**Author:** Timo Gerhard
**Status:** Approved

## Goal

Provide a reusable Terraform child module that manages Grafana Adaptive Logs resources (drop rules, exemptions, segments) via the Adaptive Logs HTTP API, plus a read-only data source for recommendations. The module should let a single tenant declare all of its Adaptive Logs configuration as code from one module block.

API reference: <https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/manage-as-code/adaptive-logs-api/>

## Non-goals

- Building a native Go Terraform provider.
- Managing recommendations (read-only on the server side).
- Multi-tenant orchestration in a single module instance — consumers wanting multi-tenant should instantiate the module per tenant.
- Wrapping endpoints that are not documented on the linked API reference page.

## Approach

Use the [`magodo/restful`](https://registry.terraform.io/providers/magodo/restful/latest) provider. Each API resource type maps to a `restful_resource` block, instantiated via `for_each` over a map of user-supplied objects. The provider is configured inside the module (single-tenant assumption) with Basic Authentication built from `tenant_id` and `token`.

The `restful` provider was chosen over alternatives (terracurl, null_resource + local-exec, custom Go provider) because it supports proper read-based drift detection, native JSON body diffing, and standard Terraform CRUD semantics without shelling out or building a new provider.

## Repository layout

```
.
├── main.tf                      # restful_resource blocks per API resource
├── variables.tf                 # inputs
├── outputs.tf                   # IDs and resolved bodies, keyed by user-supplied key
├── versions.tf                  # terraform + provider version constraints
├── providers.tf                 # restful provider config (auth, base URL)
├── data.tf                      # recommendations data source
├── README.md                    # usage, auth setup, variable reference
└── examples/
    └── basic/
        ├── main.tf              # module "adaptive_logs" { source = "../.." ... }
        ├── terraform.tfvars.example
        └── README.md            # how to run against a real tenant
```

## Provider configuration

`providers.tf` declares one `restful` provider with:

- `base_url = var.loki_url` (e.g., `https://logs-prod-006.grafana.net`).
- `security.http.basic.username = var.tenant_id`.
- `security.http.basic.password = var.token` (sensitive).
- `header = { "Content-Type" = "application/json" }`.

The module owns this provider — consumers do not need to configure `magodo/restful` themselves. If a consumer needs to manage two Adaptive Logs tenants, they instantiate the module twice with different `tenant_id`/`token`/`loki_url`.

## Variables

| Variable          | Type                                                                                                                                                                                                                                                                                                            | Required | Description                                                                                  |
| ----------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | -------------------------------------------------------------------------------------------- |
| `loki_url`        | `string`                                                                                                                                                                                                                                                                                                        | yes      | Base URL of the Grafana Cloud Loki endpoint, e.g. `https://logs-prod-006.grafana.net`.       |
| `tenant_id`       | `string`                                                                                                                                                                                                                                                                                                        | yes      | Numeric Loki tenant ID.                                                                      |
| `token`           | `string` (sensitive)                                                                                                                                                                                                                                                                                            | yes      | Grafana Cloud Access Policy token with `adaptive-logs:admin` scope.                          |
| `drop_rules`      | `map(object({ segment_id = string, name = string, version = number, disabled = bool, expires_at = optional(string), body = object({ stream_selector = string, drop_rate = number, levels = optional(list(string)), log_line_contains = optional(list(string)) }) }))`                                          | no, `{}` | Drop rules keyed by stable user-chosen key.                                                  |
| `exemptions`      | `map(object({ stream_selector = string, reason = optional(string), expires_at = optional(string) }))`                                                                                                                                                                                                            | no, `{}` | Exemptions keyed by stable user-chosen key.                                                  |
| `segments`        | `map(object({ name = string, selector = string }))`                                                                                                                                                                                                                                                              | no, `{}` | Segments keyed by stable user-chosen key.                                                    |
| `enable_recommendations_data_source` | `bool`                                                                                                                                                                                                                                                                                       | no, `true` | When `true`, exposes recommendations via `data.restful_resource` and surfaces in outputs.    |

The map keys are not sent to the API. They are the Terraform-side identifier (used in `for_each` and in outputs) and let consumers reference resources without depending on server-assigned IDs.

## Resource mapping

### Drop rules

```hcl
resource "restful_resource" "drop_rule" {
  for_each      = var.drop_rules
  path          = "/adaptive-logs/drop-rules"
  read_path     = "$(path)/$(body.id)"
  body          = jsonencode({
    segment_id = each.value.segment_id
    name       = each.value.name
    version    = each.value.version
    disabled   = each.value.disabled
    expires_at = each.value.expires_at
    body       = each.value.body
  })
  poll_create = { status_locator = "code", success = "200,201" }
}
```

- Create: `POST /adaptive-logs/drop-rules`
- Read: `GET /adaptive-logs/drop-rules/<id>`
- Update: `PUT /adaptive-logs/drop-rules/<id>`
- Delete: `DELETE /adaptive-logs/drop-rules/<id>`

`read_selector` ignores server-managed fields (`id`, `created_at`, `updated_at`) so drift is detected only on user-controlled fields.

### Exemptions

Same shape as drop rules, against `/adaptive-logs/exemptions`. Path-based ID for read/update/delete.

### Segments

Segments are special: the documented API uses `/adaptive-logs/segment` (singular) with the segment ID passed as the `?segment=<id>` query parameter for read/update/delete, and `/adaptive-logs/segments` (plural) for list.

The module handles this by configuring `read_path`, `update_path`, and `delete_path` on the `restful_resource` to use the query-string form.

### Recommendations (data source)

```hcl
data "restful_resource" "recommendations" {
  count = var.enable_recommendations_data_source ? 1 : 0
  path  = "/adaptive-logs/recommendations"
}
```

Exposed via `output "recommendations"`. Recalculated server-side every 24 hours; the data source re-reads on every `terraform plan`.

## Outputs

| Output                | Type          | Description                                                  |
| --------------------- | ------------- | ------------------------------------------------------------ |
| `drop_rule_ids`       | `map(string)` | Server-assigned drop rule IDs keyed by user-supplied key.    |
| `exemption_ids`       | `map(string)` | Server-assigned exemption IDs keyed by user-supplied key.    |
| `segment_ids`         | `map(string)` | Server-assigned segment IDs keyed by user-supplied key.      |
| `recommendations`     | `any`         | Raw recommendations response (or `null` if disabled).        |

## Drift detection

`restful_resource` performs a GET on every refresh and diffs the configured body fields. Server-managed fields are excluded via `read_selector` so timestamps don't cause perpetual drift. External changes (someone editing a rule in the UI) show up as a Terraform plan diff and are reconciled on apply.

## Sensitive handling

- `token` is `sensitive = true` in `variables.tf`.
- The provider config does not echo the token in any output.
- The example uses `terraform.tfvars.example` so committed examples never contain real credentials.

## Example (`examples/basic/`)

A runnable example that:

1. Reads `loki_url`, `tenant_id`, `token` from `terraform.tfvars` (gitignored; user copies from `terraform.tfvars.example`).
2. Declares one segment, one drop rule referencing that segment, and one exemption.
3. Outputs the resulting IDs and the latest recommendations.

`examples/basic/README.md` documents how to obtain `tenant_id` and `token`, and how to verify the apply against a real Grafana Cloud tenant.

## Testing

Manual verification path (no automated tests in v1):

1. From `examples/basic/`, fill in `terraform.tfvars` with real credentials.
2. `terraform init && terraform apply`.
3. Confirm resources appear in the Grafana Cloud Adaptive Logs UI.
4. Modify a field in the UI, run `terraform plan`, confirm drift detected.
5. `terraform destroy` cleans up.

Automated testing (Terratest, `terraform test`) is out of scope for v1.

## Open risks

- **API stability**: The Adaptive Logs API is GA but field shapes may evolve. The module pins resource bodies explicitly; new optional fields will need module updates.
- **Segments query-param API**: Non-standard pattern; the `restful` provider supports it via path overrides but it's the most likely source of friction.
- **Version field on drop rules**: API uses optimistic concurrency via `version`. Terraform doesn't naturally express "bump version on every change." The module sets `version` as a user-supplied field; consumers must increment it when they change a rule. Documented in README.
