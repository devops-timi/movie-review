# Movie Review Application – Full Stack DevOps Deployment on AWS

## Project Overview

This project demonstrates the end-to-end deployment of a cloud-native application using modern DevOps practices. It combines Infrastructure as Code, CI/CD automation, secure cloud networking, and automated application deployment.

The application itself is a simple Movie Review platform where users can submit and view movie reviews — including a movie title, star rating (1–5), and a written comment. The primary goal of the project is not the complexity of the application logic but rather the engineering and operational processes used to build, deploy, and manage the infrastructure hosting it.

The entire infrastructure is provisioned automatically using Terraform, and the deployment pipeline is orchestrated using GitHub Actions workflows.

The project demonstrates how a real production-style system can be:

- Provisioned automatically
- Deployed consistently
- Secured through proper network design
- Destroyed cleanly to prevent cloud resource sprawl

---

## Key Features

- Infrastructure provisioned using Terraform with a modular structure
- Remote Terraform state management with S3 and DynamoDB locking
- Multi-tier AWS architecture across multiple Availability Zones
- Public and private subnet isolation
- Bastion host SSH access pattern with ProxyJump agent forwarding
- Terraform outputs automatically written to GitHub Secrets post-apply
- Application deployment using GitHub Actions CI/CD workflows
- Nginx reverse proxy for internal API routing
- Node.js backend managed by PM2
- MySQL 8.4 database hosted on Amazon RDS
- Full environment lifecycle including automated destruction

---

## Application Architecture

The system follows a three-tier architecture separating presentation, application logic, and data storage.

```
Internet
   │
   ▼
Public Classic Load Balancer (port 80)
   │
   ▼
Web Tier — EC2 (Public Subnets, 2 AZs)
   ├── Nginx Reverse Proxy (port 80)
   └── Next.js Frontend (port 3000, managed by PM2)
   │
   │   /api/* requests proxied by Nginx
   ▼
Internal Classic Load Balancer (port 3010)
   │
   ▼
App Tier — EC2 (Private Subnets, 2 AZs)
   └── Node.js REST API (port 3010, managed by PM2)
   │
   ▼
Database Tier — Amazon RDS MySQL 8.4 (Private DB Subnets, 2 AZs)
```

---

## System Components

### Frontend

The frontend provides the user interface for submitting and viewing movie reviews. Built with **Next.js** and managed by **PM2** on port 3000.

Runs on:
- EC2 web instances in public subnets
- Served through Nginx on port 80
- Exposed to the internet via the Public Classic Load Balancer

Responsibilities:
- Display all submitted movie reviews, ordered newest first
- Submit new reviews through the backend API
- Route API requests through Nginx using the `/api` path

**Key design decision:** `BACKEND_URL` is set to an empty string in the frontend code. This means the browser calls `/api/reviews` on the same host it loaded from (the public CLB), and Nginx intercepts and proxies those requests internally to the backend. The browser never directly contacts the internal load balancer, which is unreachable from the public internet.

### Backend API

The backend service processes all application logic and communicates with the database.

Technologies:
- Node.js with Express
- MySQL2 connection pool
- PM2 process manager
- dotenv for environment variable management

**API Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| GET | `/api/reviews` | Returns all reviews, ordered by newest first |
| POST | `/api/reviews` | Creates a new review (`title`, `rating`, `comment`) |
| GET | `/health` | Health check endpoint used by the internal load balancer |

Responsibilities:
- Accept and validate review submissions
- Fetch stored reviews from the database
- Communicate with the RDS MySQL instance using a connection pool

The backend runs on private EC2 instances in private subnets with no public IP addresses, inaccessible directly from the internet.

**Environment variables required (written by deploy workflow):**

```
PORT=3010
DB_NAME=moviedb
DB_HOST=<rds-endpoint>
DB_PORT=3306
DB_USER=<username>
DB_PASSWORD=<password>
```

### Database

The database layer stores all persistent application data.

Technology:
- Amazon RDS MySQL 8.4
- Deployed into a dedicated DB subnet group spanning 2 Availability Zones

**Schema:**

```sql
CREATE DATABASE IF NOT EXISTS moviedb;
USE moviedb;

CREATE TABLE IF NOT EXISTS reviews (
  id INT AUTO_INCREMENT PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  rating INT NOT NULL,
  comment TEXT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

The schema is applied idempotently on every deploy using `mysql --force`, meaning re-running it on an existing database is safe.

The database is not publicly accessible and only allows connections from the app tier security group on port 3306.

### Nginx

Nginx runs on each web tier EC2 instance as a reverse proxy.

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

The `INTERNAL_CLB_DNS` placeholder is replaced at deploy time using `sed`. All `/api/` requests are forwarded to the internal load balancer and on to the backend. All other requests are forwarded to the Next.js app on port 3000.

---

## Infrastructure Architecture

All infrastructure is defined using Terraform, organized into reusable modules. Terraform enables infrastructure to be treated as code, ensuring repeatable, version-controlled, and reviewable deployments.

### Resources Provisioned

#### Networking — `modules/vpc/`

- Custom VPC (`10.0.0.0/16`) with DNS support and hostnames enabled
- **2 public subnets** for the web tier (`10.0.1.0/24`, `10.0.2.0/24`) across 2 AZs
- **2 private subnets** for the app tier (`10.0.11.0/24`, `10.0.12.0/24`) across 2 AZs
- **2 private subnets** for the DB tier (`10.0.21.0/24`, `10.0.22.0/24`) across 2 AZs
- Internet Gateway for public subnet outbound access
- NAT Gateway (with Elastic IP) in the first web subnet, allowing app and DB instances to reach the internet for package installs without being publicly accessible
- Public route table (`0.0.0.0/0` → IGW) associated with web subnets
- Private route table (`0.0.0.0/0` → NAT) associated with app and DB subnets

#### Security — `modules/security-groups/`

Five security groups enforce strict, least-privilege traffic rules:

| Security Group | Inbound Allowed | Purpose |
|---|---|---|
| `public-alb-sg` | Port 80/443 from `0.0.0.0/0` | Public CLB |
| `web-sg` | Port 80 from public ALB SG; Port 22 (dynamic, managed by deploy workflow) | Web EC2 instances |
| `internal-alb-sg` | Port 3010 from web SG | Internal CLB |
| `app-sg` | Port 3010 from internal ALB SG; Port 22 from web SG | App EC2 instances |
| `db-sg` | Port 3306 from app SG only | RDS MySQL |

#### Compute — `modules/ec2/`

- **Web tier**: 2 × `t3.small` Ubuntu 24.04 LTS instances in public subnets, attached to the public CLB
- **App tier**: 2 × `t3.small` Ubuntu 24.04 LTS instances in private subnets, attached to the internal CLB
- AMIs are dynamically resolved — always fetching the latest Ubuntu 24.04 (Noble Numbat) from Canonical's official AWS account, supporting both `x86_64` and `arm64` architectures

#### Load Balancing — `modules/clbs/`

**Public CLB** (internet-facing):
- Listens on port 80, forwards to web instances on port 80
- Health check: `HTTP:80/`

**Internal CLB** (private):
- Listens on port 3010, forwards to app instances on port 3010
- Health check: `HTTP:3010/health`

#### Database — `modules/rds/`

- MySQL 8.4 on `db.t3.micro`, 20GB `gp2` storage
- DB subnet group spanning 2 AZs
- Not publicly accessible; deletion protection disabled (enable in production)

### Terraform Remote State Management

Terraform state is stored remotely to allow safe and consistent infrastructure management.

```
S3 Bucket (movie-review-state)
   └── prod/terraform.tfstate   ← encrypted, versioned

DynamoDB Table (movie-review-lock)
   └── LockID (hash key)        ← prevents concurrent applies
```

The S3 bucket is configured with versioning enabled, AES-256 server-side encryption, and all public access blocked.

State locking ensures multiple Terraform runs cannot modify infrastructure simultaneously, preventing state corruption.

### Terraform Outputs

After `terraform apply`, the following values are captured and automatically written to GitHub Secrets by the infrastructure workflow:

| Output | Written as Secret | Used By |
|---|---|---|
| Public CLB DNS | `PUBLIC_CLB_DNS` | App access URL |
| Internal CLB DNS | `INTERNAL_CLB_DNS` | Nginx config replacement |
| RDS endpoint | `DB_HOST` | Backend `.env` |
| Web EC2 public IPs | `WEB_INSTANCE_IPS` | SSH targets |
| App EC2 private IPs | `APP_INSTANCE_IPS` | SSH targets via ProxyJump |
| Web security group ID | `WEB_SG_ID` | Dynamic SSH rule management |

---

## CI/CD Pipeline

Deployment automation is handled through GitHub Actions. Four workflows are used, each triggered manually using `workflow_dispatch`.

### Workflow 1 – Bootstrap Terraform Backend (`state-lock.yml`)

**Purpose:** Initialize Terraform remote state storage.

Creates:
- S3 bucket with versioning, encryption, and public access blocked
- DynamoDB state lock table with on-demand billing

> **Run this once before any other workflow.**

### Workflow 2 – Provision Infrastructure (`infra.yml`)

Runs Terraform to create the entire AWS environment.

Commands executed:
```
terraform init
terraform plan
terraform apply -auto-approve
```

Resources created: VPC, subnets, IGW, NAT gateway, route tables, security groups, EC2 instances, Classic Load Balancers, RDS instance.

After apply, all infrastructure outputs are written directly to GitHub repository secrets using the GitHub CLI (`gh secret set`), authenticated with a fine-grained PAT. This eliminates any manual step between infrastructure provisioning and application deployment.

### Workflow 3 – Deploy Application (`deploy-app.yml`)

This workflow deploys the application onto the provisioned infrastructure entirely over SSH, with no manual intervention.

**Step 1 – SSH Key Setup:** Writes the private key to `~/.ssh/connect.pem` with `chmod 600`.

**Step 2 – Dynamic Security Group Rule:** Fetches the GitHub Actions runner's public IP via `ifconfig.me` and adds it as a temporary inbound SSH rule on the web security group.

**Step 3 – Configure Web Instances:** For each web instance IP:
- Installs git, Nginx, Node.js 20.x, and PM2
- Clones or pulls the repository to `/app`
- Replaces the `INTERNAL-CLB-DNS` placeholder in `nginx.conf` using `sed`
- Configures and restarts Nginx
- Builds the Next.js application and starts it with PM2

**Step 4 – Configure App Instances (via ProxyJump):** The `eval $(ssh-agent -s)` and `ssh-add` are run in the same shell step as the SSH command so the agent is available for forwarding. App instances are accessed using:

```bash
ssh -i connect.pem -o ForwardAgent=yes -o ProxyJump=ubuntu@<WEB_IP> ubuntu@<APP_IP>
```

For each app instance:
- Installs git, Node.js 20.x, PM2, and mysql-client
- Clones or pulls the repository to `/app`
- Writes `/app/backend/.env` with all database credentials
- Runs `schema.sql` against RDS idempotently using `mysql --force`
- Installs dependencies and starts the backend with PM2

**Step 5 – Cleanup:** The runner's IP is always revoked from the web security group using `if: always()` — even if the workflow fails midway.

### Workflow 4 – Destroy Infrastructure (`destroy.yml`)

This workflow removes all AWS resources.

Command executed:
```
terraform destroy -auto-approve
```

Resources removed: EC2 instances, load balancers, RDS, security groups, NAT gateway, subnets, VPC.

This prevents unnecessary cloud costs by ensuring temporary environments are removed when no longer needed.

---

## Repository Structure

```
movie-review/
├── .github/
│   └── workflows/
│       ├── state-lock.yml        # Bootstrap S3 + DynamoDB for Terraform state
│       ├── infra.yml             # Provision all AWS infrastructure
│       ├── deploy-app.yml        # Deploy application to EC2 via SSH
│       └── destroy.yml           # Destroy all infrastructure
│
├── backend/
│   ├── controllers/
│   │   └── reviewsController.js  # GET and POST review handlers
│   ├── routes/
│   │   └── reviews.js            # Express router
│   ├── db.js                     # MySQL2 connection pool
│   ├── server.js                 # Express entry point, /health endpoint
│   ├── package.json
│   └── .env.example              # Environment variable template
│
├── frontend/
│   ├── pages/
│   │   └── index.js              # Main React page (reviews form + list)
│   ├── styles/
│   │   └── Home.module.css       # Scoped CSS modules
│   ├── next.config.js
│   └── package.json
│
├── database/
│   └── schema.sql                # Idempotent DB and table creation
│
├── nginx/
│   └── nginx.conf                # Reverse proxy (INTERNAL-CLB-DNS placeholder)
│
└── terraform-3tier/
    ├── main.tf                   # Root module — wires all modules together
    ├── variables.tf              # Input variables with defaults
    ├── outputs.tf                # Outputs written as GitHub Secrets
    ├── backend.tf                # S3 remote state config
    ├── data.tf                   # Dynamic Ubuntu AMI lookup
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
- An EC2 key pair created in AWS (default name: `connect`)
- A fine-grained GitHub PAT with **Secrets: Read & Write** and **Metadata: Read** permissions scoped to this repository

---

## Getting Started

### 1. Fork or clone this repository

### 2. Configure GitHub Secrets

Go to **Settings → Secrets and variables → Actions** and add:

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

### 3. Run workflows in order

```
1. Bootstrap Terraform Backend  (state-lock.yml)   — run once
2. Terraform Infrastructure     (infra.yml)
3. Deploy Application           (deploy-app.yml)
4. Destroy Infrastructure       (destroy.yml)       — when done
```

### 4. Access the application

After the deploy workflow completes, the app is accessible at:
```
http://<PUBLIC_CLB_DNS>
```
The public CLB DNS is available in your GitHub Secrets as `PUBLIC_CLB_DNS` after the infrastructure workflow runs.

---

## Major Challenges Encountered

During development, several real-world DevOps challenges were encountered and resolved.

### GitHub Actions Permission Issues

**Error:**
```
HTTP 403: Resource not accessible by personal access token
```

**Cause:** Insufficient permissions on the GitHub PAT used to write secrets.

**Resolution:** Created a fine-grained PAT scoped specifically to the repository with only **Secrets: Read & Write** and **Metadata: Read** permissions — the minimum required for `gh secret set`.

---

### SSH Authentication Failures

**Error:**
```
Permission denied (publickey)
```

**Cause:** SSH private key not correctly written to disk, or incorrect permissions on the key file.

**Resolution:** Ensured the key was written to `~/.ssh/connect.pem` with `chmod 600` and explicitly referenced with `-i`:

```bash
ssh -i ~/.ssh/connect.pem ubuntu@<server-ip>
```

---

### Accessing Private App Instances

Backend instances are in private subnets with no public IPs and cannot be reached directly from the internet.

**Solution:** Used the web instance as a bastion host via ProxyJump with SSH agent forwarding:

```bash
eval $(ssh-agent -s)
ssh-add ~/.ssh/connect.pem

ssh -i ~/.ssh/connect.pem \
    -o ForwardAgent=yes \
    -o ProxyJump=ubuntu@<WEB_IP> \
    ubuntu@<APP_PRIVATE_IP>
```

The `eval $(ssh-agent -s)` and `ssh-add` must be in the **same shell step** as the SSH command — each GitHub Actions `run:` step is a separate shell process, so agent environment variables do not persist between steps.

---

### Backend Service Not Running

The frontend deployed successfully but reviews could not be submitted.

**Diagnosis:**
```bash
pm2 status
pm2 logs backend --lines 50
curl http://localhost:3010/api/reviews
```

**Root cause:** The `DB_NAME` environment variable was missing from the `.env` file, causing the MySQL connection pool to error with `No database selected`.

**Resolution:** Added `DB_NAME=moviedb` to the `printf` command that writes the `.env` file in the deploy workflow.

---

### Frontend Could Not Reach Backend

The frontend deployed and loaded, but submitting or fetching reviews failed with `ERR_CONNECTION_TIMED_OUT`.

**Root cause:** The frontend `BACKEND_URL` was set to the internal CLB DNS. The browser tried to call that URL directly — but the internal CLB is only resolvable and reachable from within the VPC. The browser, running on a user's machine outside the VPC, could never reach it.

**Final Fix – Nginx Reverse Proxy + Empty BACKEND_URL**

Set `BACKEND_URL` to an empty string in the frontend:

```javascript
const BACKEND_URL = '';
```

This makes the browser call `/api/reviews` on the same hostname it loaded the page from (the public CLB). Nginx on the web instance intercepts `/api/` requests and proxies them to the internal CLB:

```nginx
location /api/ {
    proxy_pass http://<INTERNAL_CLB_DNS>:3010/api/;
}
```

The browser never needs to know the internal load balancer exists. All backend communication happens server-side within the VPC.

---

## Security Practices Implemented

- **Private backend servers** — App tier EC2 instances have no public IPs and are not directly reachable from the internet
- **Database isolation** — RDS only accepts connections from the app security group on port 3306; no public access
- **Bastion host SSH pattern** — App instances accessed only via ProxyJump through web instances; never directly
- **Ephemeral SSH rules** — The deploy workflow dynamically adds the runner's IP to the web SG and always revokes it on completion, even on failure (`if: always()`)
- **Internal load balancer** — Backend traffic never traverses the public internet
- **Nginx reverse proxy routing** — Internal infrastructure DNS is never exposed to browser clients
- **No hardcoded credentials** — All secrets injected via GitHub Actions secrets or environment variables
- **Least-privilege PAT** — The GitHub PAT has only the minimum required permissions
- **Encrypted remote state** — Terraform state stored in S3 with AES-256 encryption, versioning, and DynamoDB state locking

---

## Why This Project Matters

This project demonstrates real-world cloud engineering patterns used in production systems.

It showcases:

- **Infrastructure as Code** — every resource is defined, versioned, and repeatable
- **Automated deployment pipelines** — from infrastructure provisioning to application delivery with no manual steps
- **Secure cloud network design** — proper subnet isolation, security group chaining, and bastion host patterns
- **Multi-tier application architecture** — clear separation of presentation, logic, and data layers
- **Infrastructure lifecycle automation** — provision, deploy, and destroy entirely through code

Most importantly, it demonstrates how distributed systems require careful coordination between infrastructure, networking, application configuration, and automation pipelines. Real problems like private subnet access, internal DNS resolution, SSH agent forwarding, and environment variable propagation were encountered and solved through systematic debugging — not avoided.

---

## Future Improvements

- Auto Scaling Groups for the web and app tiers
- Docker containerization of frontend and backend
- Kubernetes orchestration with EKS
- HTTPS with TLS certificates via ACM and a custom domain
- Monitoring with CloudWatch or Prometheus/Grafana
- Centralized logging with the ELK stack or CloudWatch Logs
- Secrets management with AWS Secrets Manager instead of GitHub Secrets
- Blue/green or rolling deployments for zero-downtime updates