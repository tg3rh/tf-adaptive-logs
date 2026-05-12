# Tests

Unit tests for the module, using Terraform's native [`terraform test`](https://developer.hashicorp.com/terraform/language/tests) framework. Tests run entirely against a mocked `restapi` provider — no real Grafana stack or credentials needed.

## Requirements

| Tool | Version |
| --- | --- |
| Terraform | `>= 1.7` (for `mock_provider` blocks) |

The module itself remains compatible with Terraform `>= 1.5`; the version constraint here only applies to running the tests.

## Running

From the repository root:

```bash
terraform init
terraform test
```

`terraform test` discovers any `*.tftest.hcl` file under the `tests/` directory and reports pass/fail per `run` block. The full suite finishes in a couple of seconds because nothing hits the network.

## What's covered

| File | Scope |
| --- | --- |
| `segment.tftest.hcl` | Payload encoding, path overrides, selector validation |
| `drop-rule.tftest.hcl` | Body construction, null-stripping, all variable validations, boundary values |
| `exemption.tftest.hcl` | Minimal/full payload, `update_data` symmetry, `id_attribute` path, selector + expires_at validation |
| `wrapper.tftest.hcl` | Output structure, `segment` key cross-reference resolution, validation propagation |

Each file uses `mock_provider "restapi" {}` so `restapi_object` resources plan without contacting Grafana. The wrapper test additionally uses `mock_resource` to inject a stable `id` so cross-reference assertions are deterministic.

## Adding tests

A test file is a series of `run "name" { ... }` blocks. Each block runs a fresh `terraform plan` (or `apply`) against the module under test and asserts on the result.

- **Validation tests**: use `expect_failures = [var.<name>]` to assert a validation block fires.
- **Encoding tests**: assert on `restapi_object.this.data` when the module under test is a sub-module (`module { source = "./modules/X" }`), or on `module.<name>.data` when testing the wrapper.
- **Output tests**: assert on `output.<name>` (current module) or `module.<child>.<output>` (child module).

The `data` output on each sub-module exists specifically to make payload introspection possible from tests and from `terraform output` for debugging.
