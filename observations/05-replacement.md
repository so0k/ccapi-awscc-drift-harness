# 05 — Replacement semantics presentation

**Goal**: rename the cluster in each config (a ForceNew change) and see how each model presents
*which* attribute is driving the replacement. Plan-only — nothing was applied.

## awscc

```hcl
cluster_name = "cdktn-harness-awscc-renamed"  # was "cdktn-harness-awscc"
```
```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
awscc_ecs_cluster.x: Refreshing state... [id=cdktn-harness-awscc]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # awscc_ecs_cluster.x must be replaced
-/+ resource "awscc_ecs_cluster" "x" {
      ~ arn                                = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-awscc" -> (known after apply)
      + capacity_providers                 = (known after apply)
      ~ cluster_name                       = "cdktn-harness-awscc" -> "cdktn-harness-awscc-renamed" # forces replacement
      ~ cluster_settings                   = [
          ~ {
                name  = "containerInsights"
              ~ value = "disabled" -> "enabled"
            },
        ]
      + configuration                      = (known after apply)
      + default_capacity_provider_strategy = (known after apply)
      ~ id                                 = "cdktn-harness-awscc" -> (known after apply)
      + service_connect_defaults           = (known after apply)
        tags                               = [
            {
                key   = "purpose"
                value = "cdktn-state-harness"
            },
        ]
    }

Plan: 1 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  ~ cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-awscc" -> (known after apply)
```
The `# forces replacement` marker is pinned directly on the `cluster_name` line — the one
attribute that actually changed and actually forces a new resource. (The `cluster_settings`
line in this plan is unrelated leftover drift from scenario `03`, still present since that
change hadn't been applied or reverted yet.)

## ccapi

```hcl
ClusterName = "cdktn-harness-ccapi-renamed"  # was "cdktn-harness-ccapi"
```
```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
aws_cloudcontrolapi_resource.x: Refreshing state... [id=cdktn-harness-ccapi]

Note: Objects have changed outside of Terraform
...
Unless you have made equivalent changes to your configuration, or ignored the
relevant attributes using ignore_changes, the following plan may include
actions to undo or respond to these changes.

─────────────────────────────────────────────────────────────────────────────

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
-/+ destroy and then create replacement

Terraform will perform the following actions:

  # aws_cloudcontrolapi_resource.x must be replaced
-/+ resource "aws_cloudcontrolapi_resource" "x" {
      ~ desired_state = jsonencode(
          ~ {
              ~ ClusterName     = "cdktn-harness-ccapi" -> "cdktn-harness-ccapi-renamed"
                # (2 unchanged attributes hidden)
            } # forces replacement
        )
      ~ id            = "cdktn-harness-ccapi" -> (known after apply)
      ~ properties    = jsonencode(
            {
              - Arn                             = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi"
              - CapacityProviders               = []
              - ClusterName                     = "cdktn-harness-ccapi"
              - ClusterSettings                 = [
                  - {
                      - Name  = "containerInsights"
                      - Value = "disabled"
                    },
                ]
              - DefaultCapacityProviderStrategy = []
              - Tags                            = [
                  - {
                      - Key   = "purpose"
                      - Value = "cdktn-state-harness"
                    },
                ]
            }
        ) -> (known after apply)
        # (3 unchanged attributes hidden)
    }

Plan: 1 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  ~ cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi" -> (known after apply)
```
Even though the structured diff renderer shows `ClusterName` as the specific key that changed
inside the JSON, the `# forces replacement` tag is attached to the closing `}` of the whole
`jsonencode({...})` expression — i.e. to the entire `desired_state` envelope, not to the
`ClusterName` key itself. Terraform's replacement logic operates on the attribute
(`desired_state` as a whole), not on anything inside it.

Both configs were reverted to their original cluster names immediately after capturing these
plans. **Nothing was applied** in this scenario — no replacement actually occurred.

**Takeaway**: awscc can tell you, attribute-precisely, exactly which typed field forced the
replacement (`cluster_name`). ccapi can only tell you that the resource *as a whole* must be
replaced because *something* inside `desired_state` changed — the pretty structured-diff
rendering of the JSON is a display convenience, not a sign that Terraform is reasoning about
individual keys for replacement purposes.
