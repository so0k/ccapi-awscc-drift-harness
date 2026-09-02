terraform {
  required_providers {
    awscc = {
      source  = "hashicorp/awscc"
      version = "1.99.0"
    }
  }
}

provider "awscc" {
  region = "us-east-1"
}

resource "awscc_ecs_cluster" "x" {
  cluster_name = "cdktn-harness-awscc"

  cluster_settings = [
    {
      name  = "containerInsights"
      value = "enabled"
    }
  ]

  tags = [
    {
      key   = "purpose"
      value = "cdktn-state-harness"
    }
  ]
}

output "cluster_arn" {
  value = awscc_ecs_cluster.x.arn
}
