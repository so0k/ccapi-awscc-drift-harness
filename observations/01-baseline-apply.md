# 01 — Baseline: init, first plan, apply

**Goal**: stand up both models from scratch and confirm the expected pre-create baseline —
both `cluster_arn` outputs are `(known after apply)` before anything exists.

## init

```
$ aws-vault exec --no-session <profile> -- terraform init -no-color
```
(run in `awscc/`)
```
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/awscc versions matching "1.99.0"...
- Installing hashicorp/awscc v1.99.0...
- Installed hashicorp/awscc v1.99.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
```

(run in `ccapi/`, same command)
```
Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "6.62.0"...
- Installing hashicorp/aws v6.62.0...
- Installed hashicorp/aws v6.62.0 (signed by HashiCorp)

Terraform has created a lock file .terraform.lock.hcl to record the provider
selections it made above. Include this file in your version control repository
so that Terraform can guarantee to make the same selections by default when
you run "terraform init" in the future.

Terraform has been successfully initialized!
```

## first plan (pre-create)

```
$ aws-vault exec --no-session <profile> -- terraform plan -no-color -out=preapply.tfplan
```
(`awscc/`)
```
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # awscc_ecs_cluster.x will be created
  + resource "awscc_ecs_cluster" "x" {
      + arn                                = (known after apply)
      + capacity_providers                 = (known after apply)
      + cluster_name                       = "cdktn-harness-awscc"
      + cluster_settings                   = [
          + {
              + name  = "containerInsights"
              + value = "enabled"
            },
        ]
      ...
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cluster_arn = (known after apply)
```

(`ccapi/`)
```
Terraform used the selected providers to generate the following execution
plan. Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  # aws_cloudcontrolapi_resource.x will be created
  + resource "aws_cloudcontrolapi_resource" "x" {
      + desired_state = jsonencode(
            {
              + ClusterName     = "cdktn-harness-ccapi"
              + ClusterSettings = [
                  + {
                      + Name  = "containerInsights"
                      + Value = "enabled"
                    },
                ]
              + Tags            = [
                  + {
                      + Key   = "purpose"
                      + Value = "cdktn-state-harness"
                    },
                ]
            }
        )
      + id            = (known after apply)
      + properties    = (known after apply)
      + region        = "us-east-1"
      + schema        = (sensitive value)
      + type_name     = "AWS::ECS::Cluster"
    }

Plan: 1 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + cluster_arn = (known after apply)
```

Both models agree pre-create: nothing exists yet, so the ARN output is `(known after apply)`
in both. Note ccapi's whole `desired_state` envelope is already visible as a single
`jsonencode(...)` blob even at this stage, vs awscc's per-key plan.

## apply

```
$ aws-vault exec --no-session <profile> -- terraform apply -no-color -auto-approve preapply.tfplan
```
(`awscc/`)
```
awscc_ecs_cluster.x: Creating...
awscc_ecs_cluster.x: Creation complete after 7s [id=cdktn-harness-awscc]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-awscc"
```

(`ccapi/`)
```
aws_cloudcontrolapi_resource.x: Creating...
aws_cloudcontrolapi_resource.x: Creation complete after 5s [id=cdktn-harness-ccapi]

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:

cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi"
```

## verification

```
$ aws-vault exec --no-session <profile> -- aws ecs describe-clusters \
    --clusters cdktn-harness-awscc cdktn-harness-ccapi --include TAGS SETTINGS --region us-east-1
```
Both clusters came back `"status": "ACTIVE"` with `tags: [{"key":"purpose","value":"cdktn-state-harness"}]`
and `settings: [{"name":"containerInsights","value":"enabled"}]` — config applied correctly on
both sides.

**Takeaway**: pre-create, both models are indistinguishable — both computed ARNs are unknown
until apply. The only visible difference at this stage is *shape*: ccapi's plan already shows
the payload as one opaque `jsonencode(...)` string rather than individually typed attributes.
