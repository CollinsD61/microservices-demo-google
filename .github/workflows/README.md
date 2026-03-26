# GitHub Actions Workflows

This directory uses numbered workflow files so the execution intent is easy to read in repository order.

## Workflow order

1. `10-pr-ci.yml`: PR validation and preview deployment checks.
2. `15-helm-chart-ci.yml`: Helm chart lint and render checks.
3. `17-kubevious-manifests-ci.yml`: Helm manifest static checks.
4. `20-main-ci.yml`: Main/release branch integration checks.
5. `30-gitops-update.yml`: Update GitOps image tag after successful main CI.
6. `40-terraform-validate.yml`: Terraform syntax and validation checks.
7. `60-cleanup-preview.yml`: Cleanup PR preview namespace on close.

## Why numbered names

- Faster navigation in monorepo CI/CD.
- Clear separation of app CI, platform validation, and GitOps automation.
- Aligns with EKS + ECR + ArgoCD model where GitHub Actions updates Git state and ArgoCD reconciles runtime state.

## GitOps note

`30-gitops-update.yml` is intentionally separated from the build/test workflows.
This keeps deployment mechanics in GitOps (manifest updates in Git) and leaves runtime sync to ArgoCD.
