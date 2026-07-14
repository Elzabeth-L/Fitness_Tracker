# Operations Runbook

This runbook describes the intended operating model. Commands and resource
names must be finalized and tested during implementation before production use.

## One-time bootstrap

The current owner-approved exception uses the AWS root session for the one-time
local bootstrap only. Root credentials must never be placed in GitHub or used
by routine deployments; the bootstrap-created GitHub OIDC roles are the
automation identities.

1. Authenticate the local AWS CLI using an approved short-lived profile such as
   AWS SSO; do not create an IAM access key for automation.
2. Confirm identity and account before planning.
3. Run formatting, initialization, validation, and plan in
   `infrastructure/bootstrap`.
4. Review account, region, bucket name, ECR, OIDC trust conditions, IAM policy,
   budget email/amount, and tags.
5. Apply only the reviewed plan.
6. Populate the bootstrap-created `jwt` and transitional `mongodb` secret
   values through the AWS console or another approved secret-entry mechanism.
   Never put the values in Terraform, GitHub variables, shell history, or this
   repository. The JWT key must contain at least 32 random characters; the
   MongoDB secret may be a raw URI or JSON with `MONGODB_URI`.
7. Record non-sensitive outputs in GitHub repository/environment variables.
8. Migrate bootstrap state to S3 according to the implemented backend process.
9. Confirm the local state file is no longer the active source of truth and
   dispose of redundant copies securely after verification.

Required GitHub `dev` environment/repository variables are `AWS_REGION`,
`AWS_PLAN_ROLE_ARN`, `AWS_DEPLOY_ROLE_ARN`, `ECR_REPOSITORY_URL`,
`TF_STATE_BUCKET`, `JWT_SECRET_ARN`, and `MONGODB_SECRET_ARN`. The last two are
ARNs only, never secret values.

### Bootstrap command sequence

After `aws login` succeeds, create an ignored
`infrastructure/bootstrap/terraform.tfvars` from the example and replace its
two placeholders. Then run:

```powershell
terraform -chdir=infrastructure/bootstrap init -backend=false
terraform -chdir=infrastructure/bootstrap fmt -check
terraform -chdir=infrastructure/bootstrap validate
terraform -chdir=infrastructure/bootstrap plan -out=bootstrap.tfplan
terraform -chdir=infrastructure/bootstrap apply bootstrap.tfplan
```

Read the output bucket name, then migrate bootstrap state into that newly
created bucket:

```powershell
Copy-Item infrastructure/bootstrap/backend.tf.example infrastructure/bootstrap/backend.tf
terraform -chdir=infrastructure/bootstrap init -migrate-state -backend-config="bucket=REPLACE_WITH_OUTPUT_BUCKET"
```

`backend.tf` is intentionally ignored. The committed template avoids the
bootstrap cycle where Terraform would try to initialize a bucket before the
first local-state apply has created it.

Do not run application apply until both secret values are populated and all
seven GitHub variables are configured. The normal deployment workflow then
builds/pushes the first image and supplies its digest to the application stack.

## Normal deployment

The supported path is a merge/push to the protected deployment branch:

1. PR checks pass.
2. Deployment job receives any required `dev` approval.
3. OIDC obtains a short-lived deployment role.
4. Image is built, scanned, SHA-tagged, pushed, and resolved to a digest.
5. Terraform plans and applies the digest URI.
6. Health and negative authentication checks pass.
7. Job summary records version and digest.

Do not manually retag images, update Lambda to `latest`, or apply from an
unreviewed local working tree.

## Health verification

Deployment checks `GET /health` with a bounded retry window. A valid response
must include:

- HTTP `200`
- `status=ok`
- `environment=dev`
- deployed application version/commit
- no secret or internal connectivity detail

Health success does not replace authenticated functional smoke tests.

## Observability

### Logs

- Lambda application log group: seven-day retention.
- API access log group: seven-day retention.
- Structured JSON fields enable filtering by request ID, route, status, version,
  and duration.
- Never extend logging to bodies/headers to troubleshoot authentication.

### Metrics to review

- Lambda: Invocations, Errors, Throttles, Duration, ConcurrentExecutions,
  InitDuration.
- API Gateway: Count, 4XX, 5XX, integration latency, total latency.
- DynamoDB: consumed capacity, throttled requests, system/user errors.
- ECR: scan findings and repository storage.
- Billing: budget actual and forecast notifications.

### Initial alert recommendations

After notification routing is approved:

- Lambda Errors greater than zero over a useful window.
- API 5XX greater than zero or a small threshold.
- DynamoDB throttling sustained beyond a transient request.
- Budget thresholds at 50%, 80%, and 100%.

Avoid noisy paid alarms until baseline behavior is known.

## Rollback

### Application-only failure

1. Identify last known-good Lambda version and ECR digest from the deployment
   summary.
2. Confirm the previous version is compatible with the current database schema.
3. Move the `dev` alias to the prior published version using the approved
   Terraform rollback input/configuration.
4. Re-run health and functional smoke tests.
5. Record the incident and failed digest.
6. Do not overwrite or delete the failed immutable image until investigation
   ends.

### Infrastructure failure

- Do not rerun apply repeatedly without reading the failure and current state.
- Run a new plan to understand partial creation.
- Import or remove orphaned resources only through a reviewed recovery plan.
- Never edit the remote state object manually.

### State lock recovery

Force-unlock only after confirming no Terraform process/workflow is active.
Record the lock ID, failed run URL, investigation, and approver.

## Database migration rollback

During the cutover window:

- preserve a source backup,
- make the source read-only where feasible,
- avoid schema/API changes that the prior version cannot understand,
- record cutover timestamp and reconciliation results,
- define whether writes after cutover can be replayed backward.

If reverse synchronization is not implemented, rollback may lose post-cutover
writes. This must be explicitly accepted before cutover.

## Backup and recovery

### Terraform state

- S3 versioning is the recovery mechanism.
- Periodically confirm versions exist and access is restricted.
- Restore through a documented version recovery process, never by copying
  unreviewed local state over remote state.

### DynamoDB

- PITR is disabled in `dev` to control cost.
- Take a deliberate on-demand backup before destructive migration or a major
  schema/access-pattern change.
- Record backup ARN/time and delete according to the agreed retention period.

### ECR

- Retain enough immutable images for rollback.
- Lifecycle rules must not delete the currently deployed or immediately prior
  digest.

## Cost response

When a budget alert fires:

1. Confirm account and time range in Billing/Cost Explorer.
2. Group cost by service and region.
3. Check Lambda invocations/duration, API request count, log ingestion, ECR/S3
   storage, DynamoDB backup/capacity, data transfer, and secrets.
4. If traffic is unexpected, reduce API throttling or set Lambda reserved
   concurrency to zero as an emergency stop, understanding this causes outage.
5. Preserve evidence before destroying resources.
6. Document cause and prevention.

Budgets notify; they do not guarantee a spending cap.

## Routine maintenance

Monthly or after meaningful changes:

- review AWS costs and Free Tier/credit status,
- review IAM last-used/access analyzer findings,
- review ECR scan findings and base-image updates,
- update Node/Terraform/provider/action pins through PRs,
- test health and rollback,
- inspect CloudWatch retention and volume,
- review DynamoDB capacity/throttling,
- verify repository secret scanning,
- confirm legacy deployment paths remain clearly unsupported.

## Destroy application environment

1. Confirm this is `dev` and record owner approval.
2. Back up data if retention is required.
3. Confirm the Terraform workspace/backend key.
4. Run and review `terraform plan -destroy` for application state only.
5. Apply the reviewed destroy plan.
6. Verify API, Lambda, log groups, and DynamoDB resources are removed as
   intended.
7. Leave bootstrap state bucket, OIDC roles, ECR, and budget intact unless a
   separate bootstrap teardown is approved.

## Destroy bootstrap

Bootstrap teardown is exceptional:

1. Destroy application environments first.
2. Export/retain required state and images.
3. Remove GitHub variables that reference roles/resources.
4. Review all bucket object versions and ECR images.
5. Obtain explicit owner approval for permanent deletion.
6. Handle non-empty protected resources deliberately.
7. Verify no other repository/environment depends on the OIDC provider or
   shared resources.

Never use broad recursive deletion or force-destroy settings as a convenience.

## Incident priorities

1. Protect credentials and stop unauthorized access.
2. Contain cost amplification.
3. Preserve logs/state/evidence.
4. Restore a known-good immutable version.
5. Reconcile data integrity.
6. Document root cause and update the decision/runbook/test set.
