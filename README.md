Movie Review Application – Full Stack DevOps Deployment on AWS
Project Overview

This project demonstrates the end-to-end deployment of a cloud-native application using modern DevOps practices. It combines Infrastructure as Code, CI/CD automation, secure cloud networking, and automated application deployment.

The application itself is a simple Movie Review platform where users can submit and view movie reviews. The primary goal of the project is not the complexity of the application logic but rather the engineering and operational processes used to build, deploy, and manage the infrastructure hosting it.

The entire infrastructure is provisioned automatically using Terraform, and the deployment pipeline is orchestrated using GitHub Actions workflows.

The project demonstrates how a real production-style system can be:

Provisioned automatically

Deployed consistently

Secured through proper network design

Destroyed cleanly to prevent cloud resource sprawl

Key Features

Infrastructure provisioned using Terraform

Remote Terraform state management with S3 and DynamoDB

Multi-tier AWS architecture

Public and private subnet isolation

Bastion host SSH access pattern

Application deployment using GitHub Actions CI/CD

Nginx reverse proxy for internal API routing

Node.js backend managed by PM2

MySQL database hosted on Amazon RDS

Full environment lifecycle including automated destruction

Application Architecture

The system follows a three-tier architecture separating presentation, application logic, and data storage.

Internet
   │
   ▼
Public Load Balancer
   │
   ▼
Web Tier (Public Subnet)
   - Nginx Reverse Proxy
   - Frontend Application
   - Bastion SSH Access
   │
   ▼
Internal Load Balancer
   │
   ▼
Backend Tier (Private Subnet)
   - Node.js REST API
   - PM2 Process Manager
   │
   ▼
Database Tier
   - Amazon RDS MySQL
System Components
Frontend

The frontend provides the user interface for submitting and viewing movie reviews.

Runs on:

EC2 web instances

Managed by Nginx

Served behind the Public Load Balancer

Responsibilities:

Display movie reviews

Submit new reviews through the backend API

Route API requests via /api endpoint

Backend API

The backend service processes application logic.

Technologies:

Node.js

Express API

PM2 process manager

Responsibilities:

Accept review submissions

Fetch stored reviews

Communicate with MySQL database

The backend runs on private EC2 instances, inaccessible directly from the internet.

Database

The database layer stores persistent application data.

Technology:

Amazon RDS

MySQL engine

Responsibilities:

Store user reviews

Maintain structured relational data

The database is not publicly accessible and only allows connections from backend servers.

Infrastructure Architecture

All infrastructure is defined using Terraform.

Terraform enables infrastructure to be treated as code, ensuring repeatable and version-controlled deployments.

Resources Provisioned
Networking

Custom VPC

Public Subnets

Private Subnets

Internet Gateway

Route Tables

Compute

Web Tier EC2 Instances

Backend Tier EC2 Instances

Load Balancing

Public Load Balancer (Frontend)

Internal Load Balancer (Backend)

Database

Amazon RDS MySQL Instance

Security

Security Groups

Bastion SSH access pattern

Terraform Remote State Management

Terraform state is stored remotely to allow safe and consistent infrastructure management.

Remote backend configuration:

S3 Bucket
   └── Stores terraform.tfstate

DynamoDB Table
   └── Provides state locking

State locking ensures multiple Terraform runs cannot modify infrastructure simultaneously.

CI/CD Pipeline

Deployment automation is handled through GitHub Actions.

Four workflows are used, each triggered manually using workflow_dispatch.

Workflow 1 – Configure Terraform Backend

Purpose:

Initialize Terraform remote state storage.

Creates:

S3 bucket

DynamoDB state lock table

Benefits:

Prevents local state conflicts

Enables team collaboration

Ensures reliable Terraform operations

Workflow 2 – Provision Infrastructure

Runs Terraform to create the AWS environment.

Commands executed:

terraform init
terraform plan
terraform apply

Resources created:

VPC

Subnets

EC2 instances

Load balancers

RDS database

Security groups

After completion, the infrastructure is ready for application deployment.

Workflow 3 – Deploy Application

This workflow deploys the application onto the provisioned infrastructure.

Deployment steps include:

SSH into web instances

Install system dependencies

Deploy frontend application

Configure Nginx

Deploy backend application

Configure environment variables

Start backend service with PM2

The web instance acts as a bastion host for deploying backend services in private subnets.

Workflow 4 – Destroy Infrastructure

This workflow removes all AWS resources.

Command executed:

terraform destroy

Resources removed:

EC2 instances

Load balancers

VPC

RDS database

security groups

This prevents unnecessary cloud costs by ensuring temporary environments are removed when no longer needed.

Major Challenges Encountered

During development several real-world DevOps challenges were encountered.

GitHub Actions Permission Issues

Error encountered:

HTTP 403: Resource not accessible by personal access token

Cause:

Insufficient permissions for GitHub workflow to access repository secrets.

Resolution:

Updated repository permissions and correctly configured workflow authentication.

SSH Authentication Failures

Error encountered:

Permission denied (publickey)

Cause:

SSH private key missing or incorrectly referenced.

Resolution:

Ensured .pem key was correctly available and used:

ssh -i connect.pem ubuntu@server-ip
Accessing Private Instances

Backend instances were located in private subnets and could not be accessed directly.

Solution:

Used the bastion host pattern via the web instance.

Example:

ssh -i connect.pem -J ubuntu@web-server ubuntu@private-backend-ip
Backend Service Not Running

The frontend deployed successfully but the backend service was not running.

Diagnosis:

pm2 status

Resolution:

Manually started backend and updated deployment script to ensure automatic startup.

Frontend Could Not Reach Backend

The frontend initially failed to submit reviews.

Root cause:

The frontend attempted to directly call the backend using a backend URL, but the backend was behind an internal load balancer inaccessible to the internet.

Final Fix – Nginx Reverse Proxy

Solution:

Configured Nginx to proxy API requests internally.

location /api {
    proxy_pass http://INTERNAL_CLB_DNS:3010/api;
}

Additionally:

BACKEND_URL=""

This forces the frontend to call /api, allowing Nginx to route the request to the backend through the internal load balancer.

Security Practices Implemented

Private backend servers
Database isolation
Bastion host SSH access
Internal load balancer architecture
Reverse proxy API routing

These practices significantly reduce the attack surface of the system.

Why This Project Matters

This project demonstrates real-world cloud engineering patterns used in production systems.

It showcases:

Infrastructure as Code

Automated deployment pipelines

Secure cloud network design

Multi-tier application architecture

Infrastructure lifecycle automation

Most importantly, it demonstrates how distributed systems require careful coordination between infrastructure, networking, application configuration, and automation pipelines.

Future Improvements

Possible extensions include:

Auto Scaling Groups

Docker containerization

Kubernetes orchestration

Monitoring with Prometheus/Grafana

Centralized logging

HTTPS with TLS certificates

Secrets management with AWS Secrets Manager