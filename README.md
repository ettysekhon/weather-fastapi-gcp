# FastAPI deployed through CDK for Terraform CDKTF (Python)

The purpose of this repo is to understand how CDK for Terraform works and how we can deploy to Cloud using it.

Link to [CDK for Terraform documentation](https://developer.hashicorp.com/terraform/cdktf).

You may ask why use CDK for Terraform? For me I would rather use a familiar language like TypeScript or Python instead of HCL. You are able to use loops, functions, classes and it can integrate with application code. Under the hood it still generates Terraform configurations and can keep all the plan/apply workflows.

A good place to understand how to implement CDKTF is through the [AWS CDK Examples](https://github.com/aws-samples/aws-cdk-examples).
