# GitHub Actions Workflow for DockerHub Image Guard

This directory contains GitHub Actions workflow configuration for automatically building and pushing the DockerHub Image Guard Docker image to DockerHub.

## Workflow: `docker-build-push.yml`

This workflow builds and pushes the Docker image to DockerHub when:
- Code is pushed to the `main` branch
- A tag with prefix `v` is pushed (e.g., `v1.0.0`)
- The workflow is manually triggered using GitHub's "workflow_dispatch" event

### Required Secrets

Before using this workflow, you must set up the following secrets in your GitHub repository:

1. `DOCKERHUB_USERNAME`: Your DockerHub username
2. `DOCKERHUB_TOKEN`: Your DockerHub access token (not your password)

### Creating a DockerHub Access Token

1. Log in to your DockerHub account
2. Go to Account Settings → Security
3. Click "New Access Token"
4. Give your token a name (e.g., "GitHub Actions")
5. Copy the token immediately (it won't be shown again)

### Adding Secrets to Your GitHub Repository

1. Go to your repository on GitHub
2. Click on "Settings" → "Secrets and variables" → "Actions"
3. Click "New repository secret"
4. Add both `DOCKERHUB_USERNAME` and `DOCKERHUB_TOKEN` secrets

## Image Details

The Docker image will be published as:
- Repository: `techiescamp/kubeimageguard`
- Tag: `latest` (and also the Git tag name if triggered by a tag push)