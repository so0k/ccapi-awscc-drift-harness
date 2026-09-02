# 03 — Out-of-band drift (core scenario)

**Goal**: drift `containerInsights` on both clusters directly via the ECS API (bypassing
Terraform entirely), then check what `-refresh-only` and a plain `terraform plan` say in each
model, and whether the drift actually lands in local state.

Configs were reverted to baseline (`enabled`) before this step — see `02`.

## inject drift

```
$ aws-vault exec --no-session <profile> -- aws ecs update-cluster-settings \
    --cluster cdktn-harness-awscc --settings name=containerInsights,value=disabled --region us-east-1
```
```
{
    "cluster": {
        "clusterArn": "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-awscc",
        "clusterName": "cdktn-harness-awscc",
        "status": "ACTIVE",
        ...
        "settings": [
            {
                "name": "containerInsights",
                "value": "disabled"
            }
        ],
        ...
    }
}
```

```
$ aws-vault exec --no-session <profile> -- aws ecs update-cluster-settings \
    --cluster cdktn-harness-ccapi --settings name=containerInsights,value=disabled --region us-east-1
```
```
{
    "cluster": {
        "clusterArn": "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi",
        "clusterName": "cdktn-harness-ccapi",
        "status": "ACTIVE",
        ...
        "settings": [
            {
                "name": "containerInsights",
                "value": "disabled"
            }
        ],
        ...
    }
}
```

Both clusters now have `containerInsights=disabled` in the real ECS API; Terraform config and
last-known state on both sides still say `enabled`.

## `terraform plan -refresh-only`

### awscc

```
$ aws-vault exec --no-session <profile> -- terraform plan -refresh-only -no-color
```
```
awscc_ecs_cluster.x: Refreshing state... [id=cdktn-harness-awscc]

Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the
last "terraform apply" which may have affected this plan:

  # awscc_ecs_cluster.x has changed
  ~ resource "awscc_ecs_cluster" "x" {
      ~ cluster_settings = [
          ~ {
                name  = "containerInsights"
              ~ value = "enabled" -> "disabled"
            },
        ]
        id               = "cdktn-harness-awscc"
        tags             = [
            {
                key   = "purpose"
                value = "cdktn-state-harness"
            },
        ]
        # (2 unchanged attributes hidden)
    }


This is a refresh-only plan, so Terraform will not take any actions to undo
these. If you were expecting these changes then you can apply this plan to
record the updated values in the Terraform state without changing any remote
objects.
```

### ccapi

```
$ aws-vault exec --no-session <profile> -- terraform plan -refresh-only -no-color
```
```
aws_cloudcontrolapi_resource.x: Refreshing state... [id=cdktn-harness-ccapi]

Note: Objects have changed outside of Terraform

Terraform detected the following changes made outside of Terraform since the
last "terraform apply" which may have affected this plan:

  # aws_cloudcontrolapi_resource.x has changed
  ~ resource "aws_cloudcontrolapi_resource" "x" {
        id            = "cdktn-harness-ccapi"
      ~ properties    = jsonencode(
          ~ {
              ~ ClusterSettings                 = [
                  ~ {
                      ~ Value = "enabled" -> "disabled"
                        # (1 unchanged attribute hidden)
                    },
                ]
                # (5 unchanged attributes hidden)
            }
        )
        # (4 unchanged attributes hidden)
    }


This is a refresh-only plan, so Terraform will not take any actions to undo
these. If you were expecting these changes then you can apply this plan to
record the updated values in the Terraform state without changing any remote
objects.
```

**Important**: `-refresh-only` shows drift in *both* providers. ccapi's `Read()` does see the
drifted value — it just surfaces inside the computed `properties` attribute, not `desired_state`
(the field that config actually targets).

## plain `terraform plan`

### awscc

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
      ~ cluster_settings = [
          ~ {
                name  = "containerInsights"
              ~ value = "disabled" -> "enabled"
            },
        ]
        id               = "cdktn-harness-awscc"
        tags             = [
            {
                key   = "purpose"
                value = "cdktn-state-harness"
            },
        ]
        # (2 unchanged attributes hidden)
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```
awscc proposes a corrective, attribute-level update back to `enabled`. Drift is visible and
actionable.

### ccapi

```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color
```
```
aws_cloudcontrolapi_resource.x: Refreshing state... [id=cdktn-harness-ccapi]

No changes. Your infrastructure matches the configuration.

Terraform has compared your real infrastructure against your configuration
and found no differences, so no changes are needed.
```
ccapi reports **no changes at all**. `desired_state` (the only field diffed against config)
never changed — it is a static write of the config's `jsonencode(...)`, not derived from the
Read. Drift is invisible in the normal (non-`-refresh-only`) workflow.

## does the drift land in local state?

Checked whether the plain `terraform plan` above silently updated ccapi's on-disk
`terraform.tfstate` with the drifted value, even though no diff was printed:

```
$ cd ccapi && grep -o '"Value":"disabled"\|"Value":"enabled"\|containerInsights' terraform.tfstate | sort -u
```
```
containerInsights
```
(no `"Value":"disabled"` match at all in the state file)

```
$ python3 -c "
import json
d = json.load(open('terraform.tfstate'))
r = d['resources'][0]['instances'][0]['attributes']
props = json.loads(r['properties'])
print('properties.ClusterSettings:', props.get('ClusterSettings'))
print('desired_state:', r['desired_state'])
"
```
```
properties.ClusterSettings: [{'Value': 'enabled', 'Name': 'containerInsights'}]
desired_state: {"ClusterName":"cdktn-harness-ccapi","ClusterSettings":[{"Name":"containerInsights","Value":"enabled"}],"Tags":[{"Key":"purpose","Value":"cdktn-state-harness"}]}
```

Both `properties.ClusterSettings` and `desired_state` in the state file still say `enabled` —
the actual cluster is `disabled`. The refresh performed during a plain `terraform plan` is
in-memory only; it is never persisted to the local state file without running an
`apply` (including `terraform apply -refresh-only`, or a full `apply`). So after the plain
plan, both the diff engine *and* the persisted state remain blind to the drift on the ccapi
side.

**Takeaway**: this is the core, most consequential difference between the two models. awscc
treats drift as a first-class, correctable condition surfaced by ordinary `plan`. ccapi's
`Read()` does fetch the true remote state (confirmed via `-refresh-only`), but because
`desired_state` is a static config echo rather than a value derived from that Read, ordinary
`plan`/`apply` cycles never see or correct the drift, and it isn't even persisted to state
without an explicit refresh-and-apply step.
