# Terraform Module for Grafana Adaptive Logs API — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable Terraform child module that manages Grafana Adaptive Logs drop rules, exemptions, and segments via the Adaptive Logs HTTP API, with a read-only data source for recommendations and a runnable example targeting a real Grafana Cloud tenant.

**Architecture:** One root child module that owns its `magodo/restful` provider configuration. Each API resource type is implemented as a `restful_resource` driven by `for_each` over a typed `map(object(...))` variable. Auth is HTTP Basic with `tenant_id` as username and the access policy token as password.

**Tech Stack:** Terraform >= 1.5, `magodo/restful` >= 2.0, Grafana Cloud Adaptive Logs HTTP API.

**Spec:** `docs/superpowers/specs/2026-05-11-tf-adaptive-logs-design.md`

**API reference:** <https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/manage-as-code/adaptive-logs-api/>

---

## Notes for the implementer

- You are working in `/Users/tger/code/customers/dmtech/tf-adaptive-logs/`. It is a fresh git repo with only the spec under `docs/`.
- The `magodo/restful` provider's exact attribute names matter. Open <https://registry.terraform.io/providers/magodo/restful/latest/docs/resources/resource> in a browser and keep it handy. Where this plan and the docs disagree, the docs win — fix the plan inline as you go.
- "Verification" for this module is `terraform fmt -check`, `terraform validate`, and (for the example) `terraform plan` against a real tenant. There are no unit tests.
- Commit after each task. Use Conventional Commits (`feat:`, `chore:`, `docs:`).

---

## Task 1: Scaffold repo and pin provider versions

**Files:**
- Create: `.gitignore`
- Create: `versions.tf`

- [ ] **Step 1: Write `.gitignore`**

```gitignore
# Terraform
.terraform/
.terraform.lock.hcl
*.tfstate
*.tfstate.*
*.tfvars
!*.tfvars.example
crash.log
crash.*.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraformrc
terraform.rc

# macOS
.DS_Store
```

- [ ] **Step 2: Write `versions.tf`**

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    restful = {
      source  = "magodo/restful"
      version = "~> 2.0"
    }
  }
}
```

- [ ] **Step 3: Verify init works**

Run: `terraform init -backend=false`
Expected: `Terraform has been successfully initialized!` and `.terraform/providers/.../magodo/restful/...` is populated.

- [ ] **Step 4: Commit**

```bash
git add .gitignore versions.tf
git commit -m "chore: scaffold module with .gitignore and provider pin"
```

---

## Task 2: Define auth variables and configure the provider

**Files:**
- Create: `variables.tf` (auth section only — resource variables come in Task 3)
- Create: `providers.tf`

- [ ] **Step 1: Write auth variables in `variables.tf`**

```hcl
variable "loki_url" {
  description = "Base URL of the Grafana Cloud Loki endpoint, e.g. https://logs-prod-006.grafana.net (no trailing slash)."
  type        = string

  validation {
    condition     = can(regex("^https://[^/]+$", var.loki_url))
    error_message = "loki_url must be an https URL with no path and no trailing slash."
  }
}

variable "tenant_id" {
  description = "Numeric Loki tenant ID (instance ID). Used as the Basic Auth username."
  type        = string
}

variable "token" {
  description = "Grafana Cloud Access Policy token with adaptive-logs:admin scope. Used as the Basic Auth password."
  type        = string
  sensitive   = true
}
```

- [ ] **Step 2: Write `providers.tf`**

```hcl
provider "restful" {
  base_url = var.loki_url

  security = {
    http = {
      basic = {
        username = var.tenant_id
        password = var.token
      }
    }
  }

  header = {
    "Content-Type" = "application/json"
  }
}
```

- [ ] **Step 3: Verify formatting and validation**

Run: `terraform fmt -check && terraform validate`
Expected: no output from fmt, `Success! The configuration is valid.` from validate.

If validate complains that the `security` or `header` block shape is wrong, consult the provider docs at <https://registry.terraform.io/providers/magodo/restful/latest/docs> and fix the block shape inline. The intent is HTTP Basic Auth with `tenant_id` as username and `token` as password.

- [ ] **Step 4: Commit**

```bash
git add variables.tf providers.tf
git commit -m "feat: configure restful provider with basic auth for adaptive-logs API"
```

---

## Task 3: Define resource input variables

**Files:**
- Modify: `variables.tf`

- [ ] **Step 1: Append `drop_rules`, `exemptions`, `segments`, and `enable_recommendations_data_source` to `variables.tf`**

```hcl
variable "drop_rules" {
  description = <<-EOT
    Map of Adaptive Logs drop rules, keyed by a stable user-chosen key.
    The key is used only on the Terraform side (for_each and outputs); it is not sent to the API.

    Notes:
    - `segment_id`: use "__global__" for tenant-wide rules, or the ID of a segment created by this module.
    - `version`: optimistic concurrency token. Bump it every time you change the rule (the API rejects stale versions).
    - `body.drop_rate`: percentage 0-100 of log lines to drop matching the selector.
  EOT
  type = map(object({
    segment_id = string
    name       = string
    version    = number
    disabled   = bool
    expires_at = optional(string)
    body = object({
      stream_selector    = string
      drop_rate          = number
      levels             = optional(list(string))
      log_line_contains  = optional(list(string))
    })
  }))
  default = {}
}

variable "exemptions" {
  description = <<-EOT
    Map of Adaptive Logs exemptions, keyed by a stable user-chosen key.
    Exemptions prevent specific log streams from being dropped by any rule.
  EOT
  type = map(object({
    stream_selector = string
    reason          = optional(string)
    expires_at      = optional(string)
  }))
  default = {}
}

variable "segments" {
  description = <<-EOT
    Map of Adaptive Logs segments, keyed by a stable user-chosen key.
    All segments in a tenant must reference identical label names; only equality and multi-literal regex matchers are allowed.
  EOT
  type = map(object({
    name     = string
    selector = string
  }))
  default = {}
}

variable "enable_recommendations_data_source" {
  description = "If true, the module exposes the GET /adaptive-logs/recommendations response via the `recommendations` output. Recalculated server-side every 24h."
  type        = bool
  default     = true
}
```

- [ ] **Step 2: Verify validation still passes**

Run: `terraform fmt -check && terraform validate`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add variables.tf
git commit -m "feat: declare drop_rules, exemptions, segments, recommendations input variables"
```

---

## Task 4: Implement exemptions resource

Implement the simplest resource first to nail the `restful_resource` pattern. Drop rules and segments will follow.

**Files:**
- Create: `main.tf`

- [ ] **Step 1: Write the exemptions `restful_resource` block in `main.tf`**

The Adaptive Logs API for exemptions:

| Operation | Method | Path                                     |
| --------- | ------ | ---------------------------------------- |
| Create    | POST   | `/adaptive-logs/exemptions`              |
| Read      | GET    | `/adaptive-logs/exemptions/<id>`         |
| Update    | PUT    | `/adaptive-logs/exemptions/<id>`         |
| Delete    | DELETE | `/adaptive-logs/exemptions/<id>`         |

Server returns `id`, `created_at`, `updated_at` which must NOT participate in drift.

```hcl
resource "restful_resource" "exemption" {
  for_each = var.exemptions

  path = "/adaptive-logs/exemptions"

  body = jsonencode({
    stream_selector = each.value.stream_selector
    reason          = each.value.reason
    expires_at      = each.value.expires_at
  })

  # By default magodo/restful derives read/update/delete paths from `path` + the
  # ID field in the create response. Verify in the provider docs that the default
  # ID locator is `body.id`; if not, set `read_path` / `update_path` / `delete_path`
  # explicitly to "$(path)/$(body.id)".

  # Exclude server-managed fields from drift detection.
  # The provider attribute may be named `read_selector`, `output_attrs`, or
  # similar depending on the provider version — confirm against the docs and
  # use the one that scopes the diff to user-controlled fields only.
}
```

If the provider rejects any of these attributes, open <https://registry.terraform.io/providers/magodo/restful/latest/docs/resources/resource> and fix attribute names inline. The semantics required:

- POST the JSON body to `/adaptive-logs/exemptions` on create.
- Track the resource by the `id` field in the response.
- On refresh, GET `/adaptive-logs/exemptions/<id>` and compare only the `stream_selector`, `reason`, `expires_at` fields.
- On update, PUT to `/adaptive-logs/exemptions/<id>` with the same body shape.
- On destroy, DELETE `/adaptive-logs/exemptions/<id>`.

- [ ] **Step 2: Verify validation**

Run: `terraform fmt -check && terraform validate`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add main.tf
git commit -m "feat: manage adaptive-logs exemptions via restful_resource"
```

---

## Task 5: Implement drop rules resource

**Files:**
- Modify: `main.tf`

- [ ] **Step 1: Append the drop rules `restful_resource` block to `main.tf`**

The Adaptive Logs API for drop rules:

| Operation | Method | Path                                |
| --------- | ------ | ----------------------------------- |
| Create    | POST   | `/adaptive-logs/drop-rules`         |
| Read      | GET    | `/adaptive-logs/drop-rules/<id>`    |
| Update    | PUT    | `/adaptive-logs/drop-rules/<id>`    |
| Delete    | DELETE | `/adaptive-logs/drop-rules/<id>`    |

```hcl
resource "restful_resource" "drop_rule" {
  for_each = var.drop_rules

  path = "/adaptive-logs/drop-rules"

  body = jsonencode({
    segment_id = each.value.segment_id
    name       = each.value.name
    version    = each.value.version
    disabled   = each.value.disabled
    expires_at = each.value.expires_at
    body = {
      stream_selector   = each.value.body.stream_selector
      drop_rate         = each.value.body.drop_rate
      levels            = each.value.body.levels
      log_line_contains = each.value.body.log_line_contains
    }
  })

  # Same notes as exemption: confirm read/update/delete paths default to
  # `$(path)/$(body.id)` and that drift is scoped to user-controlled fields.
}
```

- [ ] **Step 2: Verify validation**

Run: `terraform fmt -check && terraform validate`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add main.tf
git commit -m "feat: manage adaptive-logs drop rules via restful_resource"
```

---

## Task 6: Implement segments resource (query-param API)

Segments are special: the API uses singular `/adaptive-logs/segment` with the segment ID as a `?segment=<id>` query parameter for read/update/delete, instead of path-based IDs. List uses plural `/adaptive-logs/segments`.

**Files:**
- Modify: `main.tf`

- [ ] **Step 1: Append the segments `restful_resource` block to `main.tf`**

| Operation | Method | URL                                                 |
| --------- | ------ | --------------------------------------------------- |
| Create    | POST   | `/adaptive-logs/segment`                            |
| Read      | GET    | `/adaptive-logs/segment?segment=<id>`               |
| Update    | PUT    | `/adaptive-logs/segment?segment=<id>`               |
| Delete    | DELETE | `/adaptive-logs/segment?segment=<id>`               |

The provider's path interpolation supports `$(body.id)` for the create-response ID. The exact syntax for combining a static path with a query parameter depends on the provider version; the two common forms are:

- `read_path = "/adaptive-logs/segment?segment=$(body.id)"` (inline query string)
- A separate `query` attribute on the read/update/delete operations

Try the inline form first; if the provider rejects it or fails to URL-encode properly, switch to the `query` attribute form. Verify against the provider docs.

```hcl
resource "restful_resource" "segment" {
  for_each = var.segments

  path = "/adaptive-logs/segment"

  body = jsonencode({
    name     = each.value.name
    selector = each.value.selector
  })

  read_path   = "/adaptive-logs/segment?segment=$(body.id)"
  update_path = "/adaptive-logs/segment?segment=$(body.id)"
  delete_path = "/adaptive-logs/segment?segment=$(body.id)"
}
```

- [ ] **Step 2: Verify validation**

Run: `terraform fmt -check && terraform validate`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add main.tf
git commit -m "feat: manage adaptive-logs segments via restful_resource"
```

---

## Task 7: Add recommendations data source

**Files:**
- Create: `data.tf`

- [ ] **Step 1: Write `data.tf`**

```hcl
data "restful_resource" "recommendations" {
  count = var.enable_recommendations_data_source ? 1 : 0

  path = "/adaptive-logs/recommendations"
}
```

If the `restful` provider exposes the data source under a different name (e.g., `restful_resource` vs. `restful_data_source`), use whatever the docs prescribe for an authenticated GET that returns the response body verbatim.

- [ ] **Step 2: Verify validation**

Run: `terraform fmt -check && terraform validate`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add data.tf
git commit -m "feat: expose adaptive-logs recommendations as data source"
```

---

## Task 8: Wire outputs

**Files:**
- Create: `outputs.tf`

- [ ] **Step 1: Write `outputs.tf`**

The exact attribute on `restful_resource` that holds the server's response JSON depends on provider version — common names are `output`, `body`, or `response`. Substitute the correct one inline if `output` is wrong.

```hcl
output "drop_rule_ids" {
  description = "Server-assigned drop rule IDs keyed by the user-supplied key in var.drop_rules."
  value = {
    for k, r in restful_resource.drop_rule : k => jsondecode(r.output).id
  }
}

output "exemption_ids" {
  description = "Server-assigned exemption IDs keyed by the user-supplied key in var.exemptions."
  value = {
    for k, r in restful_resource.exemption : k => jsondecode(r.output).id
  }
}

output "segment_ids" {
  description = "Server-assigned segment IDs keyed by the user-supplied key in var.segments."
  value = {
    for k, r in restful_resource.segment : k => jsondecode(r.output).id
  }
}

output "recommendations" {
  description = "Raw response from GET /adaptive-logs/recommendations, or null if disabled."
  value       = var.enable_recommendations_data_source ? jsondecode(data.restful_resource.recommendations[0].output) : null
}
```

- [ ] **Step 2: Verify validation**

Run: `terraform fmt -check && terraform validate`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add outputs.tf
git commit -m "feat: surface server-assigned IDs and recommendations as outputs"
```

---

## Task 9: Write the runnable example

**Files:**
- Create: `examples/basic/main.tf`
- Create: `examples/basic/terraform.tfvars.example`
- Create: `examples/basic/README.md`

- [ ] **Step 1: Write `examples/basic/main.tf`**

```hcl
terraform {
  required_version = ">= 1.5.0"
}

variable "loki_url" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "token" {
  type      = string
  sensitive = true
}

module "adaptive_logs" {
  source = "../.."

  loki_url  = var.loki_url
  tenant_id = var.tenant_id
  token     = var.token

  segments = {
    api = {
      name     = "api"
      selector = "{service=\"api\"}"
    }
  }

  drop_rules = {
    api_debug = {
      segment_id = "__global__"
      name       = "drop-api-debug"
      version    = 1
      disabled   = false
      body = {
        stream_selector = "{service=\"api\"}"
        drop_rate       = 90
        levels          = ["debug"]
      }
    }
  }

  exemptions = {
    keep_errors = {
      stream_selector = "{service=\"api\"} |= \"error\""
      reason          = "Never drop error lines from the api service."
    }
  }
}

output "drop_rule_ids" {
  value = module.adaptive_logs.drop_rule_ids
}

output "exemption_ids" {
  value = module.adaptive_logs.exemption_ids
}

output "segment_ids" {
  value = module.adaptive_logs.segment_ids
}

output "recommendations" {
  value = module.adaptive_logs.recommendations
}
```

The example uses `segment_id = "__global__"` (tenant-wide). You cannot reference `module.adaptive_logs.segment_ids["api"]` from within the same module block — that's a cycle. To tie a drop rule to a named segment, either (a) split into two module calls (segments in one, drop rules in another that depends on the first) or (b) run `terraform apply` once with segments only, then add drop rules referencing the now-known segment IDs.

- [ ] **Step 2: Write `examples/basic/terraform.tfvars.example`**

```hcl
# Copy to terraform.tfvars and fill in real values. terraform.tfvars is gitignored.

# Base URL of your Grafana Cloud Loki endpoint. Find it in Grafana Cloud Portal
# under "Loki" → "Details" → "URL". No path, no trailing slash.
loki_url = "https://logs-prod-006.grafana.net"

# Numeric instance ID, also from the Loki details page (the "User" field).
tenant_id = "123456"

# Access Policy token. Create one at https://grafana.com/orgs/<org>/access-policies
# with the `adaptive-logs:admin` scope. Treat as a secret.
token = "glc_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

- [ ] **Step 3: Write `examples/basic/README.md`**

```markdown
# Example: basic Adaptive Logs configuration

This example creates one segment, one drop rule on that segment, and one exemption against a real Grafana Cloud tenant.

## Prerequisites

1. A Grafana Cloud stack with Adaptive Logs enabled.
2. The Loki endpoint URL and numeric tenant ID (Grafana Cloud Portal → Loki → Details).
3. An Access Policy token with the `adaptive-logs:admin` scope. Create one at `https://grafana.com/orgs/<org>/access-policies`.

## Run

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your loki_url, tenant_id, token
terraform init
terraform plan
terraform apply
```

## Verify

After `apply`:

1. Open Grafana Cloud → Adaptive Logs and confirm the segment, drop rule, and exemption appear.
2. Edit the drop rate in the UI, then run `terraform plan` here — Terraform should report drift.
3. Run `terraform apply` again to reconcile.

## Tear down

```bash
terraform destroy
```
```

- [ ] **Step 4: Verify example validates**

Run: `cd examples/basic && terraform init -backend=false && terraform validate && cd ../..`
Expected: `Success! The configuration is valid.`

- [ ] **Step 5: Commit**

```bash
git add examples/
git commit -m "docs: add runnable basic example with real-tenant instructions"
```

---

## Task 10: Write the module README

**Files:**
- Create: `README.md`

- [ ] **Step 1: Write `README.md`**

```markdown
# terraform-grafana-adaptive-logs

Terraform module for managing [Grafana Cloud Adaptive Logs](https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/) configuration via its [HTTP API](https://grafana.com/docs/grafana-cloud/adaptive-telemetry/adaptive-logs/manage-as-code/adaptive-logs-api/).

Manages:

- Drop rules
- Exemptions
- Segments
- Recommendations (read-only data source)

Uses the [`magodo/restful`](https://registry.terraform.io/providers/magodo/restful/latest) provider; no custom binaries.

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.5.0 |
| restful   | ~> 2.0   |

## Authentication

| Variable    | Purpose                                                                  |
| ----------- | ------------------------------------------------------------------------ |
| `loki_url`  | Base URL of your Loki endpoint, e.g. `https://logs-prod-006.grafana.net` |
| `tenant_id` | Numeric Loki instance ID (Basic Auth username)                           |
| `token`     | Access Policy token with `adaptive-logs:admin` scope (Basic Auth password) |

Find `loki_url` and `tenant_id` in the Grafana Cloud Portal under Loki → Details. Create the token at `https://grafana.com/orgs/<org>/access-policies`.

## Usage

```hcl
module "adaptive_logs" {
  source = "github.com/<you>/terraform-grafana-adaptive-logs"

  loki_url  = "https://logs-prod-006.grafana.net"
  tenant_id = "123456"
  token     = var.adaptive_logs_token

  segments = {
    api = { name = "api", selector = "{service=\"api\"}" }
  }

  drop_rules = {
    api_debug = {
      segment_id = "__global__"
      name       = "drop-api-debug"
      version    = 1
      disabled   = false
      body = {
        stream_selector = "{service=\"api\"}"
        drop_rate       = 90
        levels          = ["debug"]
      }
    }
  }

  exemptions = {
    keep_errors = {
      stream_selector = "{service=\"api\"} |= \"error\""
      reason          = "Never drop error lines from the api service."
    }
  }
}
```

Tying a drop rule to a segment created by the same module call requires either two module instances (segments first, drop rules second, with the second depending on the first's outputs) or a two-step apply. You cannot reference `module.adaptive_logs.segment_ids[...]` from inside the same `module "adaptive_logs"` block — that's a dependency cycle.

See [`examples/basic`](./examples/basic) for a complete runnable example.

## Inputs

| Name                                  | Type                            | Default | Description                                                                  |
| ------------------------------------- | ------------------------------- | ------- | ---------------------------------------------------------------------------- |
| `loki_url`                            | `string`                        | n/a     | Base URL of the Loki endpoint, no trailing slash.                            |
| `tenant_id`                           | `string`                        | n/a     | Numeric Loki tenant ID. Basic Auth username.                                 |
| `token`                               | `string` (sensitive)            | n/a     | Access policy token with `adaptive-logs:admin` scope.                        |
| `drop_rules`                          | `map(object(...))`              | `{}`    | Drop rules keyed by stable user key. See `variables.tf` for the object shape. |
| `exemptions`                          | `map(object(...))`              | `{}`    | Exemptions keyed by stable user key.                                         |
| `segments`                            | `map(object(...))`              | `{}`    | Segments keyed by stable user key.                                           |
| `enable_recommendations_data_source`  | `bool`                          | `true`  | Whether to expose `recommendations` output.                                  |

## Outputs

| Name              | Description                                                  |
| ----------------- | ------------------------------------------------------------ |
| `drop_rule_ids`   | Server-assigned drop rule IDs keyed by input key.            |
| `exemption_ids`   | Server-assigned exemption IDs keyed by input key.            |
| `segment_ids`     | Server-assigned segment IDs keyed by input key.              |
| `recommendations` | Raw recommendations response, or `null` if disabled.         |

## Notes

- **Optimistic concurrency on drop rules**: bump `version` every time you change a rule, or the API will reject the update. This is the only field you must remember to increment manually.
- **Segment label consistency**: all segments in a tenant must reference the same label names; otherwise the API rejects them at apply time.
- **Drift**: external edits in the Grafana Cloud UI show up as drift on the next `terraform plan` and are reconciled on `apply`.
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: add module README with usage, inputs, outputs"
```

---

## Task 11: Final verification

- [ ] **Step 1: Run formatting and validation across the whole module and example**

Run:
```bash
terraform fmt -recursive -check
terraform validate
(cd examples/basic && terraform validate)
```
Expected: all clean.

- [ ] **Step 2: Confirm files exist**

Run: `ls -1 *.tf examples/basic/*.tf examples/basic/*.example`
Expected:
```
data.tf
main.tf
outputs.tf
providers.tf
variables.tf
versions.tf
examples/basic/main.tf
examples/basic/terraform.tfvars.example
```

- [ ] **Step 3: Tag final commit**

```bash
git log --oneline
```
Expected: ~10 commits in reverse chronological order, one per task.

---

## Out of scope (do NOT add)

- Automated tests (Terratest, `terraform test`). Spec calls this out as v1 non-goal.
- Additional examples beyond `basic/`.
- A second submodule layout — single module with maps is what the spec specifies.
- A custom Go provider.
- Any endpoint not in the Adaptive Logs API doc page.
