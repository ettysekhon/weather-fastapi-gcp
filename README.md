# FastAPI deployed to Google Cloud Run via Terraform

This repository deploys a FastAPI application to Google Cloud Run using Terraform.
All Google Cloud resources are provisioned in a repeatable, automated way.
GitHub Actions can build and deploy new versions automatically.

## Why Terraform + GitHub Actions

- Infrastructure as Code — reproducible Cloud Run, Artifact Registry, IAM, and API enablement via Terraform.
- GitHub Actions — builds the Docker image, pushes to Artifact Registry, and runs terraform apply using Workload Identity Federation (no service account keys).
- No latest images — each CI build gets a unique tag to avoid accidental rollbacks.

## Prerequisites

1. Install Google Cloud CLI – [Instructions](https://cloud.google.com/sdk/docs/install)
2. Install Terraform – [Instructions](https://developer.hashicorp.com/terraform/install)
3. Authenticate with GCP:

    ```bash
    gcloud auth login
    gcloud auth application-default login
    ```

4. Have access to a GCP Billing Account and permissions to create projects & link billing.

    ```bash
    PROJECT_ID="weather-fastapi-gcp-$(openssl rand -hex 4)"
    BILLING_ACCOUNT="<YOUR_BILLING_ACCOUNT_ID>"

    gcloud projects create "$PROJECT_ID" --set-as-default
    gcloud beta billing projects link "$PROJECT_ID" --billing-account "$BILLING_ACCOUNT"
    ```

5. Clone this repository and set variables

```bash
git clone https://github.com/<your-user>/<your-repo>.git
cd <your-repo>
```

###  Enable required APIs

Terraform will automatically enable the required Google Cloud APIs via the google_project_service resource.
You do not need to run this manually unless you want to bootstrap your project before applying Terraform.

APIs enabled:

- run.googleapis.com
- artifactregistry.googleapis.com
- iamcredentials.googleapis.com
- iam.googleapis.com
- secretmanager.googleapis.com
- cloudresourcemanager.googleapis.com
- serviceusage.googleapis.com

To enable manually for bootstrapping:

```bash
gcloud services enable \
  run.googleapis.com \
  artifactregistry.googleapis.com \
  iamcredentials.googleapis.com \
  iam.googleapis.com \
  secretmanager.googleapis.com \
  cloudresourcemanager.googleapis.com \
  serviceusage.googleapis.com
```

### Service Accounts

Terraform will create the runtime service account used by Cloud Run.

You still need to create the deployer service account for GitHub Actions CI/CD, or add it to Terraform if you want full automation.

```bash
gcloud iam service-accounts create weather-api-deployer \
    --description="Deploys weather API to Cloud Run via GitHub Actions" \
    --display-name="Weather API Deployer"
```

Grant minimal roles

```bash
SA_EMAIL="weather-api-deployer@$PROJECT_ID.iam.gserviceaccount.com"
USER_EMAIL="$(gcloud config get-value account)"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/run.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/artifactregistry.admin"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="serviceAccount:$SA_EMAIL" \
    --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding "$PROJECT_ID" \
    --member="user:$USER_EMAIL" \
    --role="roles/iam.serviceAccountTokenCreator"

```

### Workload Identity for GitHub Actions

If you want GitHub Actions to deploy without storing GCP service account keys,
set up Workload Identity Federation:

```bash
POOL_ID="github-actions-pool"
PROVIDER_ID="github-provider"
GITHUB_REPO="YOUR_GITHUB_USER/YOUR_REPO_NAME"

gcloud iam workload-identity-pools create "$POOL_ID" \
    --location="global" \
    --display-name="GitHub Actions Pool"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
    --location="global" \
    --workload-identity-pool="$POOL_ID" \
    --display-name="GitHub Provider" \
    --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository" \
    --attribute-condition="attribute.repository==\"$GITHUB_REPO\"" \
    --issuer-uri="https://token.actions.githubusercontent.com"

gcloud iam service-accounts add-iam-policy-binding "$SA_EMAIL" \
    --role="roles/iam.workloadIdentityUser" \
    --member="principalSet://iam.googleapis.com/projects/$(gcloud projects describe "$PROJECT_ID" --format="value(projectNumber)")/locations/global/workloadIdentityPools/$POOL_ID/attribute.repository/$GITHUB_REPO"
```

### Environment Variables for Local & CI/CD

We recommend creating a `.env.cicd` file in the repo root for both local runs and GitHub Actions.
This file should not be committed to git if it contains sensitive values.

Example `.env.cicd`:

```bash
PROJECT_NUMBER=123456789
PROJECT_ID=weather-fastapi-gcp-e7eb8ad9
REGION=us-central1
SERVICE_NAME=weather-api
REPO_ID=weather-api
DEPLOYER_SA=weather-api-deployer@weather-fastapi-gcp-e7eb8ad9.iam.gserviceaccount.com
```

When running Terraform locally, you can load these variables with:

```bash
set -a && source .env.cicd && set +a
```

The GitHub Actions workflow will also load these values automatically before running any steps.

### Deploy with Terraform (local)

```bash
terraform init
terraform plan \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="service_name=${SERVICE_NAME}" \
  -var="repo_id=${REPO_ID}" \
  -var="image_tag=v1" \
  -var="impersonate_service_account=${DEPLOYER_SA}" \
  -var="allow_unauthenticated=true"

terraform apply -auto-approve \
  -var="project_id=${PROJECT_ID}" \
  -var="region=${REGION}" \
  -var="service_name=${SERVICE_NAME}" \
  -var="repo_id=${REPO_ID}" \
  -var="image_tag=v1" \
  -var="impersonate_service_account=${DEPLOYER_SA}" \
  -var="allow_unauthenticated=true"
```

### CI/CD (Automatic image_tag increment)

The GitHub Actions workflow:

- Loads .env.cicd or GitHub Secrets for configuration
- Builds the Docker image with a unique IMAGE_TAG based on the GitHub run number
- Pushes the image to Artifact Registry
- Runs terraform apply with the updated image_tag, which:
    1. Enables required APIs (if not already enabled)
    2. Creates/updates the Artifact Registry repository
    3. Creates/updates the Cloud Run service (public if allow_unauthenticated=true)
    4. Creates/updates the runtime service account and IAM bindings

Example outputs:

```text
Apply complete! Resources: {X} added, {Y} changed, {Z} destroyed.

Outputs:

cloud_run_uri = "https://weather-api-iohb7tr6la-uc.a.run.app"
image_url = "us-central1-docker.pkg.dev/weather-fastapi-gcp-e7eb8ad9/weather-api/weather-api:v5"
```
