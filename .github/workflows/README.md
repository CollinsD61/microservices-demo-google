# GitHub Actions Workflows

This directory uses numbered workflow files so the execution intent is easy to read in repository order.

## Workflow order

1. `10-pr-ci.yml`: PR validation and preview deployment checks.
2. `15-helm-chart-ci.yml`: Helm chart lint and render checks.
3. `17-kubevious-manifests-ci.yml`: Helm manifest static checks.
4. `20-main-ci.yml`: Main/release branch integration checks.
5. `30-gitops-update.yml`: Update GitOps image tag after successful main CI.
6. `40-terraform-validate.yml`: Terraform syntax and validation checks.
7. `50-pr-preview-deploy.yml`: Deploy PR preview to EKS with Helm after PR CI succeeds.
8. `60-cleanup-preview.yml`: Cleanup PR preview namespace on close.

## Why numbered names

- Faster navigation in monorepo CI/CD.
- Clear separation of app CI, platform validation, and GitOps automation.
- Aligns with EKS + ECR + ArgoCD model where GitHub Actions updates Git state and ArgoCD reconciles runtime state.

## GitOps note

`30-gitops-update.yml` is intentionally separated from the build/test workflows.
This keeps deployment mechanics in GitOps (manifest updates in Git) and leaves runtime sync to ArgoCD.

## Required repository variables

Set these repository variables in GitHub to avoid hardcoding infrastructure values inside workflows:

- `AWS_REGION` (example: `ap-southeast-1`)
- `AWS_ROLE_TO_ASSUME` (OIDC role ARN for Actions)
- `ECR_REPOSITORY` (example: `879381260173.dkr.ecr.ap-southeast-1.amazonaws.com/online-boutique`)
- `EKS_CLUSTER_NAME` (example: `online-boutique-eks`)
