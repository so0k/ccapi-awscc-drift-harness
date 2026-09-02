# 02 — Unrelated edit vs. reference knowability

**Goal**: after both clusters exist, add an unrelated tag to each config and see whether the
derived `cluster_arn` output stays known or goes unknown again.

Both configs got a second tag added:
```hcl
# awscc/main.tf
tags = [
  { key = "purpose", value = "cdktn-state-harness" },
  { key = "extra",   value = "claim1-check" },
]
```
```hcl
# ccapi/main.tf desired_state.Tags
Tags = [
  { Key = "purpose", Value = "cdktn-state-harness" },
  { Key = "extra",   Value = "claim1-check" },
]
```

## awscc

```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
awscc_ecs_cluster.x: Refreshing state... [id=cdktn-harness-awscc]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # awscc_ecs_cluster.x will be updated in-place
  ~ resource "awscc_ecs_cluster" "x" {
        id               = "cdktn-harness-awscc"
      ~ tags             = [
            {
                key   = "purpose"
                value = "cdktn-state-harness"
            },
          + {
              + key   = "extra"
              + value = "claim1-check"
            },
        ]
        # (3 unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```
No `Changes to Outputs` section at all -- `cluster_arn` is untouched by the plan because only
`tags` changed, and `arn` doesn't depend on `tags`.

## ccapi

```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
aws_cloudcontrolapi_resource.x: Refreshing state... [id=cdktn-harness-ccapi]

Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  ~ update in-place

Terraform will perform the following actions:

  # aws_cloudcontrolapi_resource.x will be updated in-place
  ~ resource "aws_cloudcontrolapi_resource" "x" {
      ~ desired_state = jsonencode(
          ~ {
              ~ Tags            = [
                    {
                        Key   = "purpose"
                        Value = "cdktn-state-harness"
                    },
                  + {
                      + Key   = "extra"
                      + Value = "claim1-check"
                    },
                ]
                # (2 unchanged attributes hidden)
            }
        )
        id            = "cdktn-harness-ccapi"
      ~ properties    = jsonencode(
            {
              - Arn                             = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi"
              - CapacityProviders               = []
              - ClusterName                     = "cdktn-harness-ccapi"
              - ClusterSettings                 = [
                  - {
                      - Name  = "containerInsights"
                      - Value = "enabled"
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

Plan: 0 to add, 1 to change, 0 to destroy.

Changes to Outputs:
  ~ cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi" -> (known after apply)
```

The load-bearing line (account id redacted here per the public-repo redaction rule; the real
plan showed the literal account number in the ARN):
```
~ cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi" -> (known after apply)
```

Any `desired_state` edit -- even one unrelated key inside the JSON blob -- forces the entire
`properties` attribute (and therefore every output derived from it) back to unknown, because
`properties` is recomputed as a single unit on any create/update call, not diffed key-by-key
against the prior value.

This tag change was **not applied** -- reverted immediately after capturing the plan, to keep
the harness at its original baseline for the drift scenario.

**Takeaway**: awscc's typed schema lets Terraform know precisely which computed attributes are
affected by a change and leaves everything else (including `arn`) known; ccapi's single-string
`desired_state`/`properties` pair means any edit -- however small or unrelated -- reintroduces
unknown-ness across every value derived from the resource.
