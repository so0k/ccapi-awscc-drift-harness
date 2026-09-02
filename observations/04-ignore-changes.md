# 04 — `ignore_changes` granularity

**Goal**: with the drift from `03` still in place (`containerInsights=disabled` on both real
clusters, config still says `enabled`), test how precisely each model's `lifecycle.ignore_changes`
can be scoped.

## awscc — attribute-level

```hcl
lifecycle {
  ignore_changes = [cluster_settings]
}
```
```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
awscc_ecs_cluster.x: Refreshing state... [id=cdktn-harness-awscc]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```
Ignoring the whole `cluster_settings` attribute suppresses the drift-correction plan from `03`.

## awscc — nested path

```hcl
lifecycle {
  ignore_changes = [cluster_settings[0].value]
}
```
```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
awscc_ecs_cluster.x: Refreshing state... [id=cdktn-harness-awscc]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```
Terraform **accepts** the nested attribute-path address `cluster_settings[0].value` and it
equally suppresses the drift-correction plan — genuine sub-attribute granularity is possible
because `cluster_settings` is a typed, structured list attribute.

(the `lifecycle` block was removed from `awscc/main.tf` again after this test)

## ccapi — nested path rejected

```hcl
lifecycle {
  ignore_changes = [desired_state.ClusterSettings]
}
```
```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
Error: Unsupported attribute

  on main.tf line 34, in resource "aws_cloudcontrolapi_resource" "x":
  34:     ignore_changes = [desired_state.ClusterSettings]

Can't access attributes on a primitive-typed value (string).
```
Rejected outright at plan time, because `desired_state` is a plain string (a JSON-encoded blob),
not a structured/object-typed attribute — there is no sub-key to address.

## ccapi — whole-attribute, all-or-nothing

```hcl
lifecycle {
  ignore_changes = [desired_state]
}
```
```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
aws_cloudcontrolapi_resource.x: Refreshing state... [id=cdktn-harness-ccapi]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```
This variant is accepted. To confirm it suppresses *all* config edits (not just the drifted
setting), `ClusterSettings[0].Value` in the config itself was then changed from `"enabled"` to
`"disabled"` (a real config edit, unrelated to the out-of-band drift):
```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
aws_cloudcontrolapi_resource.x: Refreshing state... [id=cdktn-harness-ccapi]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```
Still "No changes" — with `ignore_changes = [desired_state]`, Terraform will never again notice
*any* edit to *any* key inside the JSON blob, whether it originates from drift or from a
deliberate config change. There is no way to ignore just one key.

(the `lifecycle` block was removed and the config value reverted to `"enabled"` after this test)

**Takeaway**: awscc's `ignore_changes` can be scoped down to a single nested field
(`cluster_settings[0].value`) while leaving Terraform sensitive to every other change. ccapi
offers exactly one working granularity for `ignore_changes`: the entire `desired_state` string,
which blinds Terraform to every property inside the resource, not just the one you meant to
exempt.
