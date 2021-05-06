# TODO: Update the following variables to the respective values when installing this in your repository.
export DOCKER_REPO_URL="ECR_REPO_URL"
export REPO_HTTP="https://github.com/YOUR_ORG/YOUR_REPO.git"
# AWS Account ID of the account that owns the ECR repo.
export SHARED_SERVICES_ACCOUNT_ID="0000000000"
# The relative path from the git repository root in the application repo to the docker build context. The Docker build
# context is the working directory of the docker image build process.
export DOCKER_CONTEXT_PATH="relpath/to/docker/context"
# The branch to use when committing to infrastructure-live.
export DEFAULT_INFRA_LIVE_BRANCH="main"
