# Design decisions

Short notes on why the pipeline is built the way it is.

## 1. The image tag is the commit hash

**Choice:** every image is tagged `sha-<commit>`, and the commit is also baked
into the image and shown at `/api/info`.

**Why:** you can always answer "what is running in production right now?" and
trace it back to one exact commit. A tag like `latest` cannot do that, because
it points to something different every day.

**Trade-off:** `latest` is still pushed for convenience, but the deployment
never uses it.

## 2. Test, then build, then scan, then publish

**Choice:** the image is built and started on the build machine first. It is
only pushed to the registry after it has answered its health check and passed
the vulnerability scan.

**Why:** a registry should only contain images you would be willing to run.
Scanning after publishing means a vulnerable image is already available to
pull.

## 3. Multi-stage build and a non-root user

**Choice:** dependencies are installed in a first stage; only the result is
copied into the final image, which runs as user 10001.

**Why:** the final image contains no build tools or caches, which makes it
smaller and gives an attacker less to work with. Running as non-root limits
the damage if the application is compromised. The pipeline checks this on
every build, so it cannot be removed by accident.

## 4. The scan fails only on critical vulnerabilities that have a fix

**Choice:** `severity-cutoff: critical` with `only-fixed: true`.

**Why:** a gate that fails on every finding is ignored within a week. This
setting blocks the cases where there is something concrete to do (update the
base image or a dependency) and does not block on issues nobody can fix yet.

**Trade-off:** lower-severity findings are reported but do not stop the
release. A stricter team would lower the cutoff to `high`.

## 5. Azure Container Apps instead of Kubernetes or App Service

**Choice:** Azure Container Apps.

**Why:** it runs containers with HTTPS, autoscaling and zero-downtime
revisions, without having to manage a cluster. It also scales to zero, which
keeps a demo almost free.

**Trade-off:** less control than AKS (no custom networking plugins, no direct
access to the Kubernetes API). For a single stateless web service that control
is not needed.

## 6. Bicep for the infrastructure

**Choice:** one Bicep file, deployed by the pipeline.

**Why:** Bicep is Azure's own language, needs no state file and is supported
directly by the Azure CLI, so the pipeline needs no extra tooling. For a small
Azure-only deployment that is the simplest option.

**Trade-off:** Bicep only works for Azure. For multi-cloud or larger
environments with shared state, Terraform is the better fit. That is what my
`azure-secure-webapp-terraform` repository uses.

## 7. OIDC instead of a stored secret

**Choice:** GitHub Actions logs in to Azure with OpenID Connect.

**Why:** no client secret in GitHub that could leak or expire. Azure trusts a
short-lived token that GitHub issues only for this repository.

## 8. A smoke test that checks the commit, not just "200 OK"

**Choice:** after deploying, the pipeline polls `/api/info` until it reports
the commit that was just built.

**Why:** a plain health check can be answered by the *previous* version while
the new one is still starting or has failed. Checking the commit proves the
new version is the one that is live.

## 9. Pinned dependency versions

**Choice:** exact versions in `requirements.txt`.

**Why:** the same commit always builds the same application. Updates happen
deliberately, in a commit that goes through the pipeline, instead of silently
on the next build.

## What would change for production

- Separate dev, test and production environments, with a manual approval
  before production.
- Pin the base image and GitHub Actions by digest instead of by tag.
- Sign the image and generate an SBOM, so the origin can be verified.
- A private registry with a managed identity for pulling images.
- Alerts on error rate and response time, not only logs.
- Gradual rollout (for example 10% of traffic first) instead of all at once.
