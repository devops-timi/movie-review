# 🎬 Movie Review App — Full Stack 3-Tier AWS Deployment

A production-style, full-stack movie review web application built to demonstrate end-to-end cloud engineering — from application development to infrastructure provisioning with Terraform, to fully automated deployment via GitHub Actions CI/CD pipelines.

This project showcases real-world DevOps and cloud engineering practices: a custom VPC with layered network segmentation, EC2 instances across multiple tiers, a managed RDS MySQL database, Classic Load Balancers for traffic distribution, and zero-touch deployment automation — all provisioned and deployed through code.

---

## 📌 Table of Contents

- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [Application Stack](#application-stack)
- [Infrastructure](#infrastructure)
- [GitHub Actions Workflows](#github-actions-workflows)
- [Repository Structure](#repository-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Secrets Configuration](#secrets-configuration)
- [Workflow Execution Order](#workflow-execution-order)
- [Security Design](#security-design)
- [Networking Design](#networking-design)

---

## Project Overview

The Movie Review App allows users to submit and view movie reviews — each with a title, star rating (1–5), and a comment. Simple in function, but deep in infrastructure. The goal of this project is not the app itself, but the full cloud delivery pipeline behind it:

- The **frontend** is a Next.js application served by Nginx on EC2 instances in a public subnet
- The **backend** is a Node.js/Express REST API running on EC2 instances in a private subnet
- The **database** is a MySQL 8.4 instance on Amazon RDS in an isolated DB subnet
- All infrastructure is provisioned with **Terraform**, organized into reusable modules
- All deployments are triggered via **GitHub Actions** workflows with no manual SSH steps required in normal operation

---

## Architecture

```
Internet
    │
    ▼
Public CLB (port 80)
    │
    ▼
Web Tier — EC2 (public subnets, 2 AZs)
  ├── Nginx (reverse proxy, port 80)
  └── Next.js (port 3000, managed by PM2)
    │
    │  /api/* requests proxied by Nginx
    ▼
Internal CLB (port 3010)
    │
    ▼
App Tier — EC2 (private subnets, 2 AZs)
  └── Node.js/Express (port 3010, managed by PM2)
    │
    ▼
DB Tier — RDS MySQL 8.4 (private DB subnets, 2 AZs)
```

Traffic flow:
1. A user's browser hits the **Public CLB** on port 80
2. The CLB forwards requests to a **web tier EC2** instance
3. Nginx on the web instance serves the Next.js frontend on `/` and proxies `/api/*` requests to the **Internal CLB** on port 3010
4. The Internal CLB forwards API requests to a **app tier EC2** instance running the Node.js backend
5. The backend reads/writes to **RDS MySQL** in the isolated DB subnet

No app tier or DB tier resource is directly accessible from the internet.

---

## Application Stack

### Frontend — `frontend/`

Built with **Next.js** and served via **PM2** on port 3000. Nginx sits in front and handles routing.

**Key files:**
- `pages/index.js` — Single-page React app. Fetches and submits reviews via `/api/reviews`. `BACKEND_URL` is an empty string so all API calls go to the same host, letting Nginx proxy them internally.
- `styles/Home.module.css` — CSS Modules for scoped component styling. Global element styles (inputs, buttons) live in `globals.css` to avoid CSS Modules purity errors.
- `next.config.js` — Next.js configuration

**Why `BACKEND_URL = ''`?**
The internal CLB DNS is only resolvable from within the VPC. Setting `BACKEND_URL` to an empty string means the browser calls `/api/reviews` on the same hostname it loaded the page from (the public CLB). Nginx intercepts `/api/` requests and proxies them to the internal CLB — the browser never needs to know the internal CLB exists.

### Backend — `backend/`

A **Node.js/Express** REST API running on port 3010.

**Key files:**
- `server.js` — Express app entry point. Mounts the reviews router at `/api/reviews` and exposes a `/health` endpoint for load balancer health checks
- `db.js` — MySQL2 connection pool. Reads all DB connection config from environment variables (`DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_NAME`, `DB_PORT`)
- `routes/reviews.js` — Defines `GET /` and `POST /` routes
- `controllers/reviewsController.js` — `getReviews` queries all reviews ordered by newest first; `createReview` inserts a new review
- `.env.example` — Template showing required environment variables

**API Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/reviews` | Returns all reviews, newest first |
| POST | `/api/reviews` | Creates a new review (`title`, `rating`, `comment`) |
| GET | `/health` | Health check endpoint for CLB |

### Database — `database/`

- `schema.sql` — Creates the `moviedb` database and `reviews` table if they don't already exist. Run idempotently on every deploy via `mysql --force`.

```sql
CREATE TABLE IF NOT EXISTS reviews (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  rating INT NOT NULL,
  comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Nginx — `nginx/`

- `nginx.conf` — Configured as a reverse proxy. Routes `/api/` traffic to the internal CLB and all other traffic to the local Next.js instance on port 3000. The placeholder `INTERNAL-CLB-DNS` is replaced at deploy time via `sed`.

```nginx
server {
    listen 80;
    server_name _;

    location /api/ {
        proxy_pass http://<INTERNAL_CLB_DNS>:3010/api/;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

---

## Infrastructure

All AWS infrastructure is defined as code in `terraform-3tier/` using a modular Terraform structure.

### Modules

#### `modules/vpc/`
Provisions the entire network layer:
- A VPC (`10.0.0.0/16`) with DNS support and hostnames enabled
- **2 public subnets** for the web tier (`10.0.1.0/24`, `10.0.2.0/24`) across 2 AZs
- **2 private subnets** for the app tier (`10.0.11.0/24`, `10.0.12.0/24`) across 2 AZs
- **2 private subnets** for the DB tier (`10.0.21.0/24`, `10.0.22.0/24`) across 2 AZs
- An **Internet Gateway** for public subnet outbound access
- A **NAT Gateway** (with Elastic IP) in the first web subnet, allowing app and DB instances to reach the internet (e.g. for package installs) without being publicly accessible
- A **public route table** routing `0.0.0.0/0` to the IGW, associated with web subnets
- A **private route table** routing `0.0.0.0/0` to the NAT gateway, associated with app and DB subnets

#### `modules/security-groups/`
Defines five security groups with strict, principle-of-least-privilege rules:

| Security Group | Inbound | Purpose |
|---|---|---|
| `public-alb-sg` | 80, 443 from `0.0.0.0/0` | Accepts public HTTP/HTTPS |
| `web-sg` | 80 from public ALB SG; 22 from `0.0.0.0/0` (managed dynamically by deploy workflow) | Web EC2 instances |
| `internal-alb-sg` | 3010 from web SG | Internal CLB |
| `app-sg` | 3010 from internal ALB SG; 22 from web SG | App EC2 instances (SSH via ProxyJump only) |
| `db-sg` | 3306 from app SG only | RDS MySQL |

The web SG port 22 rule is opened temporarily by the deploy workflow using the GitHub Actions runner's public IP, and revoked at the end of the workflow (`if: always()`).

#### `modules/clbs/`
Provisions two Classic Load Balancers (chosen for free-tier compatibility):

**Public CLB** — Internet-facing, in web subnets
- Listens on port 80 (HTTP)
- Forwards to web instances on port 80
- Health check: `HTTP:80/`

**Internal CLB** — Internal, in app subnets
- Listens on port 3010 (HTTP)
- Forwards to app instances on port 3010
- Health check: `HTTP:3010/health`

#### `modules/ec2/`
Provisions EC2 instances for both tiers:

- **Web tier**: 2 × `t3.small` Ubuntu 24.04 instances in public subnets, attached to the public CLB
- **App tier**: 2 × `t3.small` Ubuntu 24.04 instances in private subnets, attached to the internal CLB
- AMIs are dynamically resolved using `data.tf` — always fetching the latest Ubuntu 24.04 LTS (Noble Numbat) from Canonical's official AWS account (`099720109477`), supporting both `x86_64` and `arm64` architectures

#### `modules/rds/`
Provisions a MySQL 8.4 RDS instance:
- `db.t3.micro` instance class
- 20GB `gp2` storage
- Placed in a dedicated DB subnet group spanning 2 AZs
- Not publicly accessible
- Deletion protection disabled (for demo use — enable in production)
- Maintenance window set to Monday 04:00–05:00 UTC

### State Management

Terraform state is stored remotely in **Amazon S3** with **DynamoDB state locking** to prevent concurrent applies.

The `bootstrap-state.sh` script creates the required S3 bucket and DynamoDB table before first use:
- S3 bucket with versioning enabled, AES-256 encryption, and all public access blocked
- DynamoDB table (`movie-review-lock`) with `LockID` as hash key, using on-demand billing

The backend is configured in `backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "movie-review-state"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "movie-review-lock"
    encrypt        = true
  }
}
```

### Outputs

After `terraform apply`, the following outputs are captured and automatically written to GitHub Secrets:

| Output | Description |
|---|---|
| `public_clb_dns` | Public CLB DNS — the app's public URL |
| `internal_clb_dns` | Internal CLB DNS — used by Nginx to proxy API requests |
| `rds_primary_endpoint` | RDS write endpoint |
| `web_instance_ips` | JSON array of web EC2 public IPs |
| `app_instance_ips` | JSON array of app EC2 private IPs |
| `web_sg_id` | Web security group ID — used to temporarily open SSH |

---

## GitHub Actions Workflows

There are four workflows, each manually triggered (`workflow_dispatch`).

### 1. `state-lock.yml` — Bootstrap Terraform Backend

Runs `bootstrap-state.sh` to create the S3 bucket and DynamoDB table for Terraform remote state. **Run this once before anything else.**

### 2. `infra.yml` — Terraform Infrastructure

Provisions all AWS infrastructure:

1. Configures AWS credentials
2. Sets up Terraform with `terraform_wrapper: false` (required for clean `terraform output` parsing)
3. Runs `terraform init`, `terraform plan`, and `terraform apply -auto-approve`
4. Captures all Terraform outputs and writes them to GitHub repository secrets using the GitHub CLI (`gh secret set`) authenticated with a fine-grained PAT (`GH_PAT`)

The outputs written as secrets (`WEB_INSTANCE_IPS`, `APP_INSTANCE_IPS`, `DB_HOST`, `PUBLIC_CLB_DNS`, `INTERNAL_CLB_DNS`, `WEB_SG_ID`) are then consumed by the deploy workflow — creating a clean pipeline handoff between infrastructure and deployment.

### 3. `deploy-app.yml` — Deploy Application

Deploys the application to all EC2 instances over SSH:

**Step 1 — SSH key setup**: Writes the private key to `~/.ssh/connect.pem` with `chmod 600`.

**Step 2 — Dynamic SG rule**: Gets the GitHub Actions runner's public IP via `ifconfig.me` and adds it as a temporary inbound SSH rule on the web security group.

**Step 3 — Configure web instances**: For each web instance IP:
- Installs git, Nginx, Node.js 20.x, and PM2
- Clones or pulls the repo to `/app`
- Replaces the `INTERNAL-CLB-DNS` placeholder in `nginx.conf` with the real internal CLB DNS
- Enables and restarts Nginx
- Installs frontend dependencies, builds Next.js, and starts the frontend process with PM2

**Step 4 — Configure app instances**: For each app instance (accessed via ProxyJump through the web instance):
- `eval $(ssh-agent -s)` and `ssh-add` are run in the same shell step so the SSH agent is available for `ForwardAgent=yes`
- SSH uses `-o ProxyJump=ubuntu@<WEB_IP> -o ForwardAgent=yes` to tunnel through the web instance
- Installs git, Node.js 20.x, PM2, and mysql-client
- Clones or pulls the repo to `/app`
- Writes `/app/backend/.env` with all DB credentials using `printf | tee`
- Runs `schema.sql` against RDS with `mysql --force` (idempotent)
- Installs backend dependencies and starts the backend with PM2

**Step 5 — Cleanup**: The runner's IP is always revoked from the web SG using `if: always()` — even if the workflow fails.

### 4. `destroy.yml` — Terraform Destroy

Tears down all AWS infrastructure with `terraform destroy -auto-approve`. Use to avoid AWS costs when the infrastructure is no longer needed.

---

## Repository Structure

```
movie-review/
├── .github/
│   └── workflows/
│       ├── state-lock.yml        # Bootstrap S3/DynamoDB for Terraform state
│       ├── infra.yml             # Provision AWS infrastructure with Terraform
│       ├── deploy-app.yml        # Deploy app to EC2 instances via SSH
│       └── destroy.yml           # Destroy all AWS infrastructure
│
├── backend/
│   ├── controllers/
│   │   └── reviewsController.js  # GET and POST review logic
│   ├── routes/
│   │   └── reviews.js            # Express router
│   ├── db.js                     # MySQL2 connection pool
│   ├── server.js                 # Express app entry point
│   ├── package.json
│   ├── .env.example              # Environment variable template
│   └── .env                      # Runtime env (generated by deploy workflow)
│
├── frontend/
│   ├── pages/
│   │   └── index.js              # Main React page
│   ├── styles/
│   │   └── Home.module.css       # Scoped CSS
│   ├── next.config.js
│   └── package.json
│
├── database/
│   └── schema.sql                # Idempotent DB + table creation
│
├── nginx/
│   └── nginx.conf                # Reverse proxy config (INTERNAL-CLB-DNS placeholder)
│
└── terraform-3tier/
    ├── main.tf                   # Root module — wires all modules together
    ├── variables.tf              # Input variables
    ├── outputs.tf                # Outputs captured as GitHub Secrets
    ├── backend.tf                # S3 remote state configuration
    ├── data.tf                   # Dynamic AMI lookup
    ├── bootstrap-state.sh        # One-time S3/DynamoDB setup script
    └── modules/
        ├── vpc/                  # VPC, subnets, IGW, NAT, route tables
        ├── security-groups/      # All 5 security groups
        ├── clbs/                 # Public and internal Classic Load Balancers
        ├── ec2/                  # Web and app tier EC2 instances
        └── rds/                  # RDS MySQL with subnet group
```

---

## Prerequisites

- An AWS account with programmatic access (Access Key ID + Secret Access Key)
- A GitHub repository with Actions enabled
- An EC2 key pair created in AWS (`connect` by default, configurable via `KEY_NAME`)
- A fine-grained GitHub PAT with **Secrets: Read & Write** permission on this repository

---

## Getting Started

### 1. Fork or clone this repository

### 2. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add the following secrets:

| Secret | Description |
|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key |
| `AWS_REGION` | AWS region (e.g. `us-east-1`) |
| `DB_USERNAME` | RDS master username |
| `DB_PASSWORD` | RDS master password |
| `KEY_NAME` | EC2 key pair name |
| `SSH_PRIVATE_KEY` | Contents of the `.pem` private key file |
| `GH_PAT` | Fine-grained GitHub PAT (Secrets: Read & Write) |

### 3. Bootstrap Terraform state storage

Run the **Bootstrap Terraform Backend** workflow (`state-lock.yml`) once. This creates the S3 bucket and DynamoDB table.

### 4. Provision infrastructure

Run the **Terraform Infrastructure** workflow (`infra.yml`). This provisions all AWS resources and automatically writes infrastructure outputs as GitHub Secrets.

### 5. Deploy the application

Run the **Deploy Application** workflow (`deploy-app.yml`). This configures all EC2 instances, deploys the app code, and starts all services.

### 6. Access the app

After the deploy workflow completes, the app is accessible at:
```
http://<PUBLIC_CLB_DNS>
```
The `PUBLIC_CLB_DNS` value is available in your GitHub Secrets after step 4.

---

## Secrets Configuration

After running the infrastructure workflow, the following secrets are automatically added to the repository:

| Secret | Source |
|---|---|
| `WEB_INSTANCE_IPS` | JSON array of web EC2 public IPs |
| `APP_INSTANCE_IPS` | JSON array of app EC2 private IPs |
| `DB_HOST` | RDS primary endpoint |
| `PUBLIC_CLB_DNS` | Public-facing CLB DNS |
| `INTERNAL_CLB_DNS` | Internal CLB DNS (used by Nginx) |
| `WEB_SG_ID` | Web security group ID |

These secrets are consumed by the deploy workflow — no manual copying of values is required.

---

## Workflow Execution Order

```
1. state-lock.yml      → Creates S3 + DynamoDB for Terraform state (run once)
2. infra.yml           → Provisions all AWS infrastructure
3. deploy-app.yml      → Deploys app to EC2 instances
4. destroy.yml         → Tears down all infrastructure (when done)
```

---

## Security Design

- **No hardcoded credentials** anywhere in the codebase — all secrets injected via GitHub Actions secrets or environment variables
- **Principle of least privilege** — each security group only allows traffic from the specific source that needs it
- **App tier is never directly internet-accessible** — all access goes through the web tier
- **Database is isolated** — only the app SG can reach port 3306; no public access
- **SSH is ephemeral** — the deploy workflow dynamically adds the runner's IP to the web SG and always removes it on completion, even on failure
- **App instances accessed via ProxyJump** — SSH to app instances tunnels through a web instance; app instances have no public IPs and no direct internet-facing SSH exposure
- **Terraform state is encrypted** — S3 backend uses AES-256 encryption with versioning enabled
- **State locking** — DynamoDB prevents concurrent Terraform operations from corrupting state
- **Fine-grained PAT** — the GitHub PAT used to write secrets has only `Secrets: Read & Write` and `Metadata: Read` permissions, scoped to this repository only