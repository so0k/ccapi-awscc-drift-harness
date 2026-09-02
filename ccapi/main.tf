terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "6.62.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_cloudcontrolapi_resource" "x" {
  type_name = "AWS::ECS::Cluster"

  desired_state = jsonencode({
    ClusterName     = "cdktn-harness-ccapi"
    ClusterSettings = [
      {
        Name  = "containerInsights"
        Value = "enabled"
      }
    ]
    Tags = [
      {
        Key   = "purpose"
        Value = "cdktn-state-harness"
      }
    ]
  })
}

output "cluster_arn" {
  value = jsondecode(aws_cloudcontrolapi_resource.x.properties)["Arn"]
}
