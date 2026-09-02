# 06 — Cleanup: destroy + verification

**Goal**: tear down both harness clusters and confirm deletion against the live AWS account.

Configs were back at their original baseline (no `lifecycle` blocks, no renamed clusters, no
drift-inducing edits) before destroy — see `04` and `05` for reverts.

## destroy

```
$ aws-vault exec --no-session <profile> -- terraform destroy -auto-approve -no-color
```

### awscc

```
Terraform will perform the following actions:

  # awscc_ecs_cluster.x will be destroyed
  - resource "awscc_ecs_cluster" "x" {
      - arn              = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-awscc" -> null
      - cluster_name     = "cdktn-harness-awscc" -> null
      - cluster_settings = [
          - {
              - name  = "containerInsights" -> null
              - value = "disabled" -> null
            },
        ] -> null
      - id               = "cdktn-harness-awscc" -> null
      - tags             = [
          - {
              - key   = "purpose" -> null
              - value = "cdktn-state-harness" -> null
            },
        ] -> null
    }

Plan: 0 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  - cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-awscc" -> null
awscc_ecs_cluster.x: Destroying... [id=cdktn-harness-awscc]
awscc_ecs_cluster.x: Still destroying... [id=cdktn-harness-awscc, 00m10s elapsed]
awscc_ecs_cluster.x: Destruction complete after 16s

Destroy complete! Resources: 1 destroyed.
```

Note: `cluster_settings.value` still reads `"disabled"` here because the out-of-band drift from
scenario `03` was never applied/corrected in this config — it was left as real drift and simply
destroyed along with the resource, which is fine for a destroy.

### ccapi

> The full plan header for this destroy was not captured to a saved file and the shell output
> was viewed through `tail -30`, so the top of the destroy plan (before `ClusterName` below) is
> not available verbatim and is not reproduced here. What follows is the exact tail that was
> observed:

```
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
        ) -> null
      - region        = "us-east-1" -> null
      - schema        = (sensitive value) -> null
      - type_name     = "AWS::ECS::Cluster" -> null
    }

Plan: 0 to add, 0 to change, 1 to destroy.

Changes to Outputs:
  - cluster_arn = "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi" -> null
aws_cloudcontrolapi_resource.x: Destroying... [id=cdktn-harness-ccapi]
aws_cloudcontrolapi_resource.x: Still destroying... [id=cdktn-harness-ccapi, 00m10s elapsed]
aws_cloudcontrolapi_resource.x: Destruction complete after 15s

Destroy complete! Resources: 1 destroyed.
```

## verify deletion

```
$ aws-vault exec --no-session <profile> -- aws ecs describe-clusters \
    --clusters cdktn-harness-awscc cdktn-harness-ccapi --region us-east-1
```
```
{
    "clusters": [
        {
            "clusterArn": "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-ccapi",
            "clusterName": "cdktn-harness-ccapi",
            "status": "INACTIVE",
            "registeredContainerInstancesCount": 0,
            "runningTasksCount": 0,
            "pendingTasksCount": 0,
            "activeServicesCount": 0,
            "statistics": [],
            "tags": [],
            "settings": [],
            "capacityProviders": [],
            "defaultCapacityProviderStrategy": []
        },
        {
            "clusterArn": "arn:aws:ecs:us-east-1:<account-id>:cluster/cdktn-harness-awscc",
            "clusterName": "cdktn-harness-awscc",
            "status": "INACTIVE",
            "registeredContainerInstancesCount": 0,
            "runningTasksCount": 0,
            "pendingTasksCount": 0,
            "activeServicesCount": 0,
            "statistics": [],
            "tags": [],
            "settings": [],
            "capacityProviders": [],
            "defaultCapacityProviderStrategy": []
        }
    ],
    "failures": []
}
```
Both clusters report `"status": "INACTIVE"` with empty `tags` and `settings` — ECS's normal
post-deletion state (deleted clusters remain visible as `INACTIVE` for a retention window
rather than disappearing from `describe-clusters` immediately). No `failures` entries. Both
`terraform destroy` runs completed cleanly with no errors.

**Takeaway**: both harness resources were fully torn down and independently verified deleted
via the AWS API, regardless of which Terraform model created them. The `.tf` files and local
`terraform.tfstate` for both dirs were left in place (state now references destroyed
resources), per the run's instructions.
