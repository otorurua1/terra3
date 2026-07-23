# Mario Game — Multi-Region, Multi-Environment Terraform Infrastructure

Deploys a small HTML5 platformer ("Super Terraform Bros") behind an
Application Load Balancer, in **two AWS regions** (`eu-west-1`,
`us-east-1`) across **two environments** (`dev`, `prod`) — 4
independent stacks built from the same four reusable modules
(`vpc`, `alb`, `ec2`, `monitoring`), each with its own ALB and its own
Terraform state file in one shared S3 bucket.

## Architecture

```
                 S3 bucket: tornike-state-s3-lock-12
        dev/eu · dev/us · prod/eu · prod/us  (state + native lock)
                              │
        ┌───────────┬────────┴────────┬───────────┐
        │           │                 │           │
   ┌────▼────┐ ┌────▼────┐      ┌─────▼────┐ ┌─────▼────┐
   │ dev-eu   │ │ dev-us   │      │ prod-eu  │ │ prod-us  │
   │eu-west-1 │ │us-east-1 │      │eu-west-1 │ │us-east-1 │
   │          │ │          │      │          │ │          │
   │ VPC      │ │ VPC      │      │ VPC      │ │ VPC      │
   │ 1× ALB   │ │ 1× ALB   │      │ 1× ALB   │ │ 1× ALB   │
   │ ASG 1x   │ │ ASG 1x   │      │ ASG 2-4x │ │ ASG 2-4x │
   │ t3.micro │ │ t3.micro │      │ t3.small │ │ t3.small │
   └──────────┘ └──────────┘      └──────────┘ └──────────┘
```

**4 stacks → 4 ALBs**, one per stack. ALBs are regional, so there's no
single load balancer spanning both regions — each stack is a fully
self-contained VPC + ALB + Auto Scaling Group. There's no cross-stack
traffic and no shared entry point (DNS/CloudFront) in front of them;
see "Not included" below if you want one.

## Repo layout

```
modules/
  vpc/          # VPC, IGW, public subnets, route table
  alb/           # ALB, target group, HTTP listener, ALB security group
  ec2/            # launch template, ASG, instance security group, IAM role, user_data
  monitoring/      # SNS topic + CloudWatch alarms
environments/
  dev-eu/  dev-us/  prod-eu/  prod-us/   # one dir per stack, 4 files each
    main.tf          # wires vpc → alb → ec2 → monitoring together
    variables.tf      # region, sizing, CIDR — the only thing that differs per stack
    outputs.tf
    providers.tf       # required_providers + backend "s3" {bucket/key/region} + provider "aws"
game/
  index.html        # the game — a self-contained HTML5/canvas page
```

Each stack's `providers.tf` hardcodes its own `bucket` / `key` /
`region` in the `backend "s3" {}` block (backend blocks can't take
variables, so there's nothing to gain from splitting that out). Just
`terraform init` and go — no extra flags, no files to copy first. None
of the four modules declare `required_providers`; they inherit the
`aws` provider from whichever stack calls them.

The four modules have a linear dependency chain — each stack's
`main.tf` calls them in this order, wiring one module's outputs into
the next module's inputs:

```
vpc  →  alb  →  ec2  →  monitoring
(vpc_id,       (alb_security_group_id,   (alb_arn_suffix,
 subnet_ids)    target_group_arn)         target_group_arn_suffix,
                                           autoscaling_group_name)
```

`alb` and `ec2` both depend on `vpc`, but not on each other's
resources — `ec2`'s instance security group only needs the *ALB's*
security group ID (not the ALB itself), and `alb`'s target group just
sits empty until `ec2`'s Auto Scaling Group attaches to it. Splitting
them this way means you could, for example, swap `ec2` for an ECS/
Fargate module later without touching `vpc`, `alb`, or `monitoring` at
all — `alb` just needs something to hand its `target_group_arn` to.

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) **>= 1.10** (needed for native S3 state locking; developed against 1.15.x)
- AWS CLI v2 with credentials that can create EC2/ALB/VPC/IAM/S3 resources
- AWS provider `~> 6.0` (Terraform installs this automatically)

## Setup

### 1. Create the state bucket (once, via AWS CLI)

```bash
BUCKET="tornike-state-s3-lock-12"
REGION="us-east-1"
```

```bash
# Create bucket
aws s3api create-bucket \
  --bucket "$BUCKET" \
  --region "$REGION"
```

```bash
# Enable versioning
aws s3api put-bucket-versioning \
  --bucket "$BUCKET" \
  --versioning-configuration Status=Enabled
```

```bash
# Enable server-side encryption
aws s3api put-bucket-encryption \
  --bucket "$BUCKET" \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

```bash
# Block all public access
aws s3api put-public-access-block \
  --bucket "$BUCKET" \
  --public-access-block-configuration \
BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

```bash
# Enforce HTTPS-only access
aws s3api put-bucket-policy \
  --bucket "$BUCKET" \
  --policy "$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Sid": "DenyInsecureTransport",
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:*",
    "Resource": [
      "arn:aws:s3:::$BUCKET",
      "arn:aws:s3:::$BUCKET/*"
    ],
    "Condition": {
      "Bool": {
        "aws:SecureTransport": "false"
      }
    }
  }]
}
EOF
)"
```

`tornike-state-s3-lock-12` is already hardcoded into every
`environments/*/providers.tf`, so using that exact name lets you skip
straight to step 2. Bucket names are global — if it's taken, pick
another and update `bucket` in each `providers.tf`. Creating it by
hand in the console works too, as long as it ends up **versioned** and
**private**.

### 2. Deploy a stack

```bash
cd environments/dev-eu
terraform init
terraform plan
terraform apply
```

To get email alerts from that stack's CloudWatch alarms (see
"Monitoring" below), set `alarm_email`:

```bash
terraform apply -var="alarm_email=you@example.com"
```

(AWS will send a subscription-confirmation email you have to click
before alerts actually start flowing.)

Repeat for `dev-us`, `prod-eu`, `prod-us` — deploy only what you need,
in any order. Each stack's `key` is different, so their state files
(and `use_lockfile` locks) never contend.

### 3. Play

```bash
terraform output game_url
```

Open it in a browser. Fresh instances take ~60–90s to pass the ALB
health check, so a 502 right after `apply` just means "not booted yet."

### Tearing down

```bash
cd environments/dev-eu && terraform destroy
```

Repeat per stack. The state bucket isn't managed by Terraform, so
delete it yourself via the CLI whenever you're done with it.

## Module reference

### `modules/vpc`
| Input | Default | Description |
|---|---|---|
| `name` | — | prefix for resource names/tags |
| `vpc_cidr` | `10.0.0.0/16` | VPC CIDR |
| `public_subnet_cidrs` | 2 CIDRs | one subnet per AZ |
| `az_count` | `2` | how many CIDRs/AZs to actually use |

Creates a VPC, IGW, public subnets, and a public route table. Outputs
`vpc_id`, `public_subnet_ids`, `availability_zones`.

### `modules/alb`
| Input | Description |
|---|---|
| `name` | prefix for resource names/tags |
| `vpc_id`, `public_subnet_ids` | from `modules/vpc` |

Creates the ALB security group (open on 80 to the internet), the ALB
itself, its target group, and an HTTP listener forwarding to that
target group. Outputs `alb_dns_name`, `alb_zone_id`, `alb_arn_suffix`,
`target_group_arn`, `target_group_arn_suffix`, `alb_security_group_id`.

### `modules/ec2`
| Input | Default | Description |
|---|---|---|
| `name` | — | prefix for resource names/tags |
| `vpc_id`, `public_subnet_ids` | — | from `modules/vpc` |
| `alb_security_group_id`, `target_group_arn` | — | from `modules/alb` |
| `instance_type` | `t3.micro` | ASG instance size |
| `min_size` / `max_size` / `desired_capacity` | `1` / `3` / `2` | ASG sizing |
| `game_index_html` | — | raw HTML served by every instance |
| `region_label` | — | written to `/region.json` so the page can show which stack answered |

Creates the instance security group (HTTP only from the ALB's
security group), an IAM role + instance profile with
`AmazonSSMManagedInstanceCore` (access via `aws ssm start-session` —
no SSH keys, no open port 22), a launch template (IMDSv2-only, latest
Amazon Linux 2023, nginx installed via `user_data`), and the Auto
Scaling Group. Outputs `autoscaling_group_name`,
`instance_security_group_id`.

### `modules/monitoring`
| Input | Default | Description |
|---|---|---|
| `name` | — | prefix for resource names/tags |
| `alb_arn_suffix`, `target_group_arn_suffix` | — | from `modules/alb` |
| `autoscaling_group_name` | — | from `modules/ec2` |
| `alarm_email` | `""` | email subscribed to the alarm SNS topic; blank = no subscription |

Creates one SNS topic + 3 CloudWatch alarms (see below). Outputs
`alerts_topic_arn`.

## Monitoring

Every stack gets its own SNS topic (`<stack>-alerts-...`) and three
CloudWatch alarms, all defined in `modules/monitoring`:

| Alarm | Fires when |
|---|---|
| `<stack>-unhealthy-hosts` | any target fails its ALB health check |
| `<stack>-target-5xx` | targets return >10 HTTP 5xx responses in 5 minutes |
| `<stack>-high-cpu` | ASG average CPU >80% for 10 minutes |

Alarms are per-stack (4 topics, 12 alarms total) — dev and prod alert
independently, matching each stack's own ALB and ASG. Subscribe an
email at deploy time with `-var="alarm_email=..."`, or subscribe
other endpoints later (Slack webhook via Lambda, PagerDuty, etc.) to
the `alerts_topic_arn` output.

## Adding a new region or environment

Copy any `environments/<env>-<region>` directory and change, in
`variables.tf`: `aws_region`, `region_short`, `environment` (if new),
`vpc_cidr`/`public_subnet_cidrs`, and sizing. In `providers.tf`, give
it a unique backend `key` (e.g. `staging/ap/terraform.tfstate`). No
module changes needed.

## CI/CD (GitHub Actions)

`.github/workflows/terraform.yml` is a manually-triggered workflow —
pick a stack and a command, it runs Terraform against that one stack.

**Setup (once):**
1. Add repo secrets `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` for
   an IAM user that can manage EC2/ALB/VPC/IAM/S3/CloudWatch/SNS
   resources (Settings → Secrets and variables → Actions).
2. (Recommended) Create a GitHub Environment named `prod` (Settings →
   Environments) with required reviewers. The workflow sets
   `environment: ${{ inputs.environment }}`, so any run against `prod`
   — plan, apply, *or* destroy — will pause for approval before it
   touches AWS. Do the same for `dev` if you want the same gate there.

**Run it:** Actions tab → "Terraform" → "Run workflow" → pick
`environment` (`dev`/`prod`), `region` (`eu`/`us`), and `command`
(`plan`/`apply`/`destroy`). Or from the CLI:

```bash
gh workflow run terraform.yml -f environment=dev -f region=eu -f command=plan
```

The job resolves those three inputs straight to a directory
(`environments/dev-eu`, etc.), runs `fmt -check`, `init`, `validate`,
then the chosen command. Runs against the same stack are serialized
(`concurrency:` group per environment+region) so two people can't
`apply` the same stack at once — on top of the `use_lockfile` locking
in the backend itself.

This uses long-lived access-key secrets for simplicity; swapping to
OIDC (`aws-actions/configure-aws-credentials` with `role-to-assume`,
no stored keys) is a natural next step once this is working.

## Design notes

- **One bucket, four keys.** Each stack gets its own state object, not
  its own bucket — fewer buckets to secure, and `use_lockfile` locking
  is per-key so stacks never contend.
- **S3 native locking, no DynamoDB.** Terraform 1.10+ locks state
  directly in S3 via conditional writes. For Terraform < 1.10, add a
  `dynamodb_table` setting to the backend block instead.
- **Directories, not workspaces, for dev/prod.** Workspaces share
  backend config and variable defaults, making it easy to `apply` dev
  values against prod state by mistake. Separate directories make that
  structurally impossible.
- **Public subnets, no NAT Gateway.** Keeps cost down; instances still
  aren't directly reachable (security group only allows the ALB in).
  For hardened production use, move the ASG into private subnets
  behind a NAT Gateway.
- **Game content is embedded, not fetched at runtime.** Base64'd into
  `user_data`, well under the 16KB limit — no runtime dependency on an
  external bucket/CDN.

## Not included / possible next steps

- Route53 (latency/geolocation routing) or CloudFront in front of the
  4 regional ALBs, for a single entry point
- HTTPS (ACM cert + listener + redirect from 80) — currently HTTP-only
- OIDC instead of long-lived AWS key secrets in the GitHub Actions workflow
- `terraform plan` on pull requests (currently manual/on-demand only,
  not PR-triggered)
- Dynamic autoscaling policies (target-tracking on CPU/request count) —
  ASG sizing is currently a static min/max/desired per environment

## Cost note

Running all four stacks continuously: 4× ALB (~$16/mo each) + dev
instances (2× `t3.micro`, ~$7-8/mo each) + prod instances (4-8×
`t3.small`, ~$15/mo each) + S3 (pennies) + CloudWatch alarms/SNS
(~$0.10/alarm/mo, 12 alarms total — a couple dollars). Destroy stacks
you're not actively using.
