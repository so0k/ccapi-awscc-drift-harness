# ccapi vs awscc — Terraform state-handling harness

Two minimal root modules managing the **same** resource (`AWS::ECS::Cluster`, empty, free)
through the **same** backend (AWS Cloud Control API), differing only in the Terraform-side model:

| dir | provider | model |
|---|---|---|
| `ccapi/` | `hashicorp/aws` 6.62.0 | `aws_cloudcontrolapi_resource` — opaque `desired_state` JSON string |
| `awscc/` | `hashicorp/awscc` 1.99.0 | `awscc_ecs_cluster` — schema generated from the CloudFormation registry |

Built to empirically verify claims about drift detection, `ignore_changes` granularity,
plan-time reference knowability, diff readability, and replacement presentation.

## Findings (verified 2026-09-02, Terraform 1.15.8, us-east-1)

1. **References**: any `desired_state` edit — even an unrelated tag — recomputes the whole
   computed `properties` blob, re-marking every derived output `(known after apply)`.
   awscc's typed `arn` stays known through unrelated edits.
2. **Drift** (out-of-band `aws ecs update-cluster-settings … containerInsights=disabled`):
   awscc plans a corrective `cluster_settings[0].value` change. ccapi's plain plan says
   *"No changes"* — its `Read()` does fetch the drifted state, but only into the computed
   `properties` attribute; `desired_state` (the one field diffed against config) is a static
   config write, so drift is invisible to the plan/apply diff engine, and the refresh is not
   persisted to state without an apply.
3. **`ignore_changes`**: awscc accepts and honors nested paths down to
   `cluster_settings[0].value`. ccapi rejects `desired_state.ClusterSettings` with
   `Can't access attributes on a primitive-typed value (string)`; only the all-or-nothing
   `[desired_state]` works.
4. **Replacement**: awscc pins `# forces replacement` on `cluster_name`; ccapi attaches it to
   the entire `desired_state` block even when only `ClusterName` changed inside it.

## Running it

Requires AWS credentials (e.g. `aws-vault exec <profile> --`) with ECS + Cloud Control
permissions. Creates only two empty, tagged ECS clusters; `terraform destroy` both when done.

```sh
cd awscc && terraform init && terraform plan
cd ccapi && terraform init && terraform plan
# drift injection:
aws ecs update-cluster-settings --cluster <name> --settings name=containerInsights,value=disabled
```

State is local and gitignored. Part of the cdktn bridge planning work (CDK → Terraform via
awscc + cfncompat).
