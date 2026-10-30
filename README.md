# aws-lambda-terraform-api

A template for a Node.js API on AWS: a Lambda function behind API Gateway on your own domain, deployed by GitHub Actions, with every AWS resource in Terraform except the Route53 hosted zone, which you bring.

- **App:** Node 24, TypeScript, esbuild, Vitest, ESLint, Yarn 4.
- **Hosting:**
  - A Lambda function on arm64, logging JSON to a log group with 30-day retention.
  - An API Gateway HTTP API that sends every request to the function, which routes in code.
  - Your domain only: the default `execute-api` URL is off.
  - A regional ACM certificate, TLS 1.2+.
  - Access logs and request throttling.
- **CI/CD:** GitHub Actions over OIDC, with no stored AWS keys.
  - Pull requests run checks and a read-only `terraform plan`.
  - `main` builds, applies and smoke-tests `/health`.

## Using the template

You need an AWS account with a public Route53 hosted zone for your domain, already delegated from your registrar, plus the AWS CLI, Terraform 1.17+, `gh`, and Node 24 with Corepack.

1. **Create your repo** with **Use this template** on GitHub, and clone it.

2. **Bootstrap AWS, once,** with admin credentials for the account. This creates:
   - an S3 bucket for Terraform state;
   - GitHub's OIDC provider;
   - a **deploy** role that only `main` can assume, scoped to this API's function, its role and log groups, its zone records, and API Gateway and ACM in its region;
   - a read-only **plan** role for pull requests.

   ```sh
   cd infrastructure/terraform/bootstrap
   cp terraform.tfvars.example terraform.tfvars   # set github_repository, domain_name and hosted_zone_name
   terraform init
   terraform apply
   ```

   If the account already has GitHub's OIDC provider, set `create_github_oidc_provider = false`.

3. **Point GitHub at it.** The `github_variables` output is a list of ready-to-run commands:

   ```sh
   terraform output -raw github_variables | sh
   ```

   | Variable | Required | Purpose |
   | --- | --- | --- |
   | `AWS_DEPLOY_ROLE_ARN` | yes | Role `main` assumes to apply |
   | `AWS_PLAN_ROLE_ARN` | yes | Read-only role pull requests assume to plan |
   | `TF_STATE_BUCKET` | yes | Bucket for the API's Terraform state |
   | `DOMAIN_NAME` | yes | Hostname to serve, e.g. `api.example.com` |
   | `HOSTED_ZONE_NAME` | no | Zone holding `DOMAIN_NAME`, if it isn't `DOMAIN_NAME` itself |
   | `AWS_REGION` | no | Region for everything (default `us-west-2`) |

4. **Push to `main`.** The first deploy creates everything and takes a few minutes, mostly certificate validation. After that, deploys take about a minute.

Until `AWS_DEPLOY_ROLE_ARN` and `AWS_PLAN_ROLE_ARN` are set, CI only lints, tests and builds. That's why this template repo itself never deploys.

## Local development

```sh
corepack enable
yarn install
yarn dev        # http://localhost:3000, restarts on changes
yarn lint
yarn test:ci
yarn build      # dist/index.mjs
```

`yarn dev` runs the handler behind a small local server that shapes requests the way API Gateway does, so `curl localhost:3000/hello?name=you` behaves as it will in AWS.

To run the API's Terraform locally, build first, then use the same backend and variables CI does:

```sh
yarn build
cd infrastructure/terraform/api
cp terraform.tfvars.example terraform.tfvars
terraform init -backend-config="bucket=<TF_STATE_BUCKET>" -backend-config="key=api/terraform.tfstate" -backend-config="region=us-west-2"
terraform plan
```

## Layout

| Path | What |
| --- | --- |
| `src/handler.ts` | The Lambda handler and its routes. |
| `src/local.ts` | The local server behind `yarn dev`. Never deployed. |
| `infrastructure/terraform/bootstrap/` | One-time setup: state bucket, OIDC provider, deploy and plan roles. Local state. |
| `infrastructure/terraform/api/` | The API: function, HTTP API, certificate, DNS records. Applied by CI. |
| `.github/workflows/` | `on-pr.yml` checks and plans; `on-push.yml` checks and deploys `main`. |

## Things to know

- **Routes live in code.** API Gateway sends every request to the function, so adding an endpoint means adding a `"METHOD /path"` entry to `routes` in [`src/handler.ts`](src/handler.ts), with no Terraform change. Unknown routes get a JSON 404.
- **AWS access from the handler.** The function's role can only write its own logs. Grant anything else it needs (a DynamoDB table, a queue) in [`api/lambda.tf`](infrastructure/terraform/api/lambda.tf), and add the new resource types to the deploy role in [`bootstrap/roles.tf`](infrastructure/terraform/bootstrap/roles.tf). The bootstrap must be re-applied for that.
- **Dependencies are bundled.** esbuild bundles `src/` and everything it imports into one file, so runtime packages go in `dependencies` and nothing else ships. The AWS SDK v3 is already in the Lambda runtime, but bundling the clients you use keeps their versions pinned.
- **CORS** is off, which is right for server-to-server callers. If a browser app on another origin calls the API, set `cors_allow_origins` in [`api/variables.tf`](infrastructure/terraform/api/variables.tf).
- **Limits.** API Gateway answers `429` above 50 requests per second (bursts of 100), and gives up on the function after 30 seconds. The function times out after 10. All of these are variables in `api/variables.tf`.
- **Logs.** `aws logs tail /aws/lambda/<function_name> --follow` for the function, `/aws/apigateway/<function_name>` for access logs. Uncaught errors are logged with the request ID and return a generic 500.
- **Bootstrap state** lives in `bootstrap/terraform.tfstate` on the machine that ran it. It only describes the bucket and roles, so losing it isn't fatal: re-import them, or recreate the roles. To keep it with everything else, add `backend "s3" {}` to `bootstrap/versions.tf` and run `terraform init -migrate-state` with the same `-backend-config` flags and `key=bootstrap/terraform.tfstate`.
- **Tearing down.**
  - Run `terraform destroy` in `api/`.
  - The state bucket has `prevent_destroy`; remove it deliberately to destroy `bootstrap/`.
