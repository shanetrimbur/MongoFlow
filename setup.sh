#!/bin/bash

set -e

# Define color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== MongoFlow Repository Setup Script ===${NC}"
echo "This script will create the directory structure and basic files for the MongoFlow project."

# Create base directory
REPO_DIR="MongoFlow"
if [ -d "$REPO_DIR" ]; then
  echo -e "${YELLOW}Directory $REPO_DIR already exists. Do you want to overwrite it? (y/n)${NC}"
  read answer
  if [ "$answer" != "y" ]; then
    echo "Exiting without changes."
    exit 0
  fi
  rm -rf "$REPO_DIR"
fi

mkdir -p "$REPO_DIR"
cd "$REPO_DIR"

echo -e "${GREEN}Creating repository structure...${NC}"

# Create directory structure
mkdir -p .github/workflows
mkdir -p docs
mkdir -p iac/terraform
mkdir -p iac/cloudformation
mkdir -p services/python-service/tests
mkdir -p services/go-service/tests
mkdir -p frontend/src/components
mkdir -p frontend/src/services
mkdir -p frontend/public
mkdir -p scripts

echo -e "${GREEN}Creating GitHub Actions workflows...${NC}"

# Create GitHub Actions workflow files
cat > .github/workflows/ci-cd.yml << 'EOL'
name: MongoFlow CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      - name: Run Checkov for IaC scanning
        uses: bridgecrewio/checkov-action@master
        with:
          directory: iac/
          soft_fail: true
          framework: terraform,cloudformation

      - name: Run GitHub secret scanning
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

  terraform-deploy:
    name: Deploy MongoDB Atlas with Terraform
    needs: security-scan
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Terraform Init
        run: |
          cd iac/terraform
          terraform init
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          TF_VAR_mongodb_atlas_public_key: ${{ secrets.MONGODB_ATLAS_PUBLIC_KEY }}
          TF_VAR_mongodb_atlas_private_key: ${{ secrets.MONGODB_ATLAS_PRIVATE_KEY }}

      - name: Terraform Plan
        run: |
          cd iac/terraform
          terraform plan
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          TF_VAR_mongodb_atlas_public_key: ${{ secrets.MONGODB_ATLAS_PUBLIC_KEY }}
          TF_VAR_mongodb_atlas_private_key: ${{ secrets.MONGODB_ATLAS_PRIVATE_KEY }}

      - name: Terraform Apply
        if: github.ref == 'refs/heads/main' && github.event_name == 'push'
        run: |
          cd iac/terraform
          terraform apply -auto-approve
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          TF_VAR_mongodb_atlas_public_key: ${{ secrets.MONGODB_ATLAS_PUBLIC_KEY }}
          TF_VAR_mongodb_atlas_private_key: ${{ secrets.MONGODB_ATLAS_PRIVATE_KEY }}

  # Additional jobs omitted for brevity - refer to full workflow in repository
EOL

cat > .github/workflows/security-scans.yml << 'EOL'
name: Security Scans

on:
  schedule:
    - cron: '0 0 * * 0'  # Run every Sunday at midnight
  workflow_dispatch:     # Allow manual triggering

jobs:
  security-scan:
    name: Security Scanning
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Run Snyk to check for vulnerabilities
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=medium

      - name: Run Checkov for IaC scanning
        uses: bridgecrewio/checkov-action@master
        with:
          directory: iac/
          soft_fail: false
          framework: terraform,cloudformation
EOL

echo -e "${GREEN}Creating Terraform configuration files...${NC}"

# Create Terraform files
cat > iac/terraform/main.tf << 'EOL'
# main.tf - MongoFlow Terraform configuration

# Create a MongoDB Atlas Project
resource "mongodbatlas_project" "mongoflow_project" {
  name   = var.project_name
  org_id = var.atlas_org_id
}

# Create a MongoDB Atlas Cluster with M0 free tier
resource "mongodbatlas_cluster" "mongoflow_cluster" {
  project_id = mongodbatlas_project.mongoflow_project.id
  name       = var.cluster_name

  # Free tier M0 settings
  provider_name               = "TENANT"
  backing_provider_name       = "AWS"
  provider_region_name        = var.atlas_region
  provider_instance_size_name = "M0"

  # MongoDB version
  mongo_db_major_version = "6.0"

  # Backup settings
  auto_scaling_disk_gb_enabled = false
  
  # Advanced configurations
  advanced_configuration {
    javascript_enabled = true
    minimum_enabled_tls_protocol = "TLS1_2"
  }
}

# Additional resources omitted for brevity
EOL

cat > iac/terraform/variables.tf << 'EOL'
# variables.tf - MongoFlow Terraform variables

variable "project_name" {
  description = "The name of the MongoDB Atlas project"
  type        = string
  default     = "MongoFlow"
}

variable "atlas_org_id" {
  description = "MongoDB Atlas organization ID"
  type        = string
  sensitive   = true
}

variable "cluster_name" {
  description = "The name of the MongoDB Atlas cluster"
  type        = string
  default     = "mongoflow-cluster"
}

variable "atlas_region" {
  description = "The region where the MongoDB Atlas cluster will be deployed"
  type        = string
  default     = "US_EAST_1"
}

# Additional variables omitted for brevity
EOL

cat > iac/terraform/providers.tf << 'EOL'
# providers.tf - MongoFlow Terraform providers

terraform {
  required_providers {
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.10.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.67.0"
    }
  }
  required_version = ">= 1.0"
}

provider "mongodbatlas" {
  public_key  = var.mongodb_atlas_public_key
  private_key = var.mongodb_atlas_private_key
}

provider "aws" {
  region = "us-east-1"
  # AWS credentials are provided via environment variables or AWS profile
}
EOL

cat > iac/terraform/outputs.tf << 'EOL'
# outputs.tf - MongoFlow Terraform outputs

output "mongodb_connection_string" {
  value     = mongodbatlas_cluster.mongoflow_cluster.connection_strings[0].standard
  sensitive = true
}

output "cluster_id" {
  value = mongodbatlas_cluster.mongoflow_cluster.id
}
EOL

echo -e "${GREEN}Creating CloudFormation template...${NC}"

# Create CloudFormation template
cat > iac/cloudformation/stack.yaml << 'EOL'
AWSTemplateFormatVersion: '2010-09-09'
Description: 'MongoFlow - AWS Resources for MongoDB Atlas CI/CD Pipeline'

Parameters:
  MongoDBUri:
    Type: String
    Description: MongoDB Atlas connection string URI
    NoEcho: true
  
  Environment:
    Type: String
    Description: Deployment environment
    Default: production
    AllowedValues:
      - development
      - staging
      - production

Resources:
  # API Gateway for backend services
  MongoFlowApi:
    Type: AWS::ApiGateway::RestApi
    Properties:
      Name: MongoFlow API
      Description: API Gateway for MongoFlow backend services
      EndpointConfiguration:
        Types:
          - REGIONAL

  # Python Service Lambda Function
  PythonServiceLambda:
    Type: AWS::Lambda::Function
    Properties:
      FunctionName: mongoflow-python-service
      Handler: app.lambda_handler
      Role: !GetAtt LambdaExecutionRole.Arn
      Runtime: python3.10
      Timeout: 30
      MemorySize: 128
      Environment:
        Variables:
          MONGODB_URI: !Ref MongoDBUri
          ENVIRONMENT: !Ref Environment

  # Additional resources omitted for brevity

Outputs:
  ApiEndpoint:
    Description: URL of the API Gateway endpoint
    Value: !Sub https://${MongoFlowApi}.execute-api.${AWS::Region}.amazonaws.com/${Environment}
EOL

echo -e "${GREEN}Creating Python service files...${NC}"

# Create Python service files
cat > services/python-service/app.py << 'EOL'
# app.py - Python service with MongoDB Atlas integration
import os
import json
import logging
from typing import Dict, List, Any, Optional
from bson import ObjectId
import pymongo
from pymongo.errors import PyMongoError
from fastapi import FastAPI, HTTPException, Body
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from mangum import Mangum

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize FastAPI app
app = FastAPI(
    title="MongoFlow Python Service",
    description="Python microservice with MongoDB Atlas integration",
    version="1.0.0"
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # For production, specify actual origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# MongoDB Atlas connection
MONGODB_URI = os.environ.get("MONGODB_URI")
DB_NAME = os.environ.get("DB_NAME", "mongoflow")
COLLECTION_NAME = os.environ.get("COLLECTION_NAME", "items")

# Lambda handler
handler = Mangum(app)

def lambda_handler(event, context):
    return handler(event, context)

# API Routes
@app.get("/")
async def root():
    return {"message": "MongoFlow Python Service is running", "status": "ok"}
EOL

cat > services/python-service/requirements.txt << 'EOL'
fastapi==0.95.2
mangum==0.17.0
pymongo==4.3.3
pydantic==1.10.8
uvicorn==0.22.0
python-dotenv==1.0.0
EOL

cat > services/python-service/Dockerfile << 'EOL'
FROM python:3.10-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
EOL

echo -e "${GREEN}Creating Go service files...${NC}"

# Create Go service files
cat > services/go-service/main.go << 'EOL'
package main

import (
	"context"
	"log"
	"net/http"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/gin-gonic/gin"
	"github.com/aws/aws-sdk-go/aws"
	ginadapter "github.com/awslabs/aws-lambda-go-api-proxy/gin"
	"go.mongodb.org/mongo-driver/mongo"
	"go.mongodb.org/mongo-driver/mongo/options"
)

var ginLambda *ginadapter.GinLambda

// Initialize Gin router
func init() {
	r := gin.Default()

	// Routes
	r.GET("/", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"message": "MongoFlow Go Service is running",
			"status":  "ok",
		})
	})

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "healthy",
		})
	})

	// Initialize AWS Lambda adapter
	ginLambda = ginadapter.New(r)
}

// Lambda handler function
func Handler(ctx context.Context, req events.APIGatewayProxyRequest) (events.APIGatewayProxyResponse, error) {
	return ginLambda.ProxyWithContext(ctx, req)
}

func main() {
	// Check if running in Lambda or locally
	if os.Getenv("AWS_LAMBDA_FUNCTION_NAME") != "" {
		lambda.Start(Handler)
	} else {
		r := gin.Default()
		r.GET("/", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{
				"message": "MongoFlow Go Service is running locally",
				"status":  "ok",
			})
		})
		r.Run(":8080")
	}
}
EOL

cat > services/go-service/go.mod << 'EOL'
module github.com/your-org/mongoflow/go-service

go 1.20

require (
	github.com/aws/aws-lambda-go v1.41.0
	github.com/aws/aws-sdk-go v1.44.271
	github.com/awslabs/aws-lambda-go-api-proxy v0.14.0
	github.com/gin-gonic/gin v1.9.1
	go.mongodb.org/mongo-driver v1.12.0
)
EOL

cat > services/go-service/Dockerfile << 'EOL'
FROM golang:1.20-alpine as builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o main .

FROM alpine:latest

WORKDIR /app
COPY --from=builder /app/main .

EXPOSE 8080
CMD ["./main"]
EOL

echo -e "${GREEN}Creating frontend files...${NC}"

# Create frontend files
cat > frontend/package.json << 'EOL'
{
  "name": "mongoflow-frontend",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@testing-library/jest-dom": "^5.16.5",
    "@testing-library/react": "^13.4.0",
    "@testing-library/user-event": "^13.5.0",
    "axios": "^1.4.0",
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.11.2",
    "react-scripts": "5.0.1"
  },
  "scripts": {
    "start": "react-scripts start",
    "build": "react-scripts build",
    "test": "react-scripts test",
    "eject": "react-scripts eject"
  },
  "eslintConfig": {
    "extends": [
      "react-app",
      "react-app/jest"
    ]
  },
  "browserslist": {
    "production": [
      ">0.2%",
      "not dead",
      "not op_mini all"
    ],
    "development": [
      "last 1 chrome version",
      "last 1 firefox version",
      "last 1 safari version"
    ]
  }
}
EOL

cat > frontend/src/App.js << 'EOL'
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import Header from './components/Header';
import Dashboard from './components/Dashboard';
import ItemsList from './components/ItemsList';
import Footer from './components/Footer';
import './App.css';

function App() {
  return (
    <Router>
      <div className="App">
        <Header />
        <main className="App-main">
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/items" element={<ItemsList />} />
          </Routes>
        </main>
        <Footer />
      </div>
    </Router>
  );
}

export default App;
EOL

cat > frontend/src/components/Header.js << 'EOL'
import React from 'react';
import { Link } from 'react-router-dom';

function Header() {
  return (
    <header className="App-header">
      <div className="logo">MongoFlow</div>
      <nav>
        <Link to="/">Dashboard</Link>
        <Link to="/items">Items</Link>
      </nav>
    </header>
  );
}

export default Header;
EOL

cat > frontend/public/index.html << 'EOL'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <link rel="icon" href="%PUBLIC_URL%/favicon.ico" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <meta name="theme-color" content="#000000" />
    <meta
      name="description"
      content="MongoFlow - MongoDB Atlas CI/CD & DevSecOps Pipeline"
    />
    <link rel="apple-touch-icon" href="%PUBLIC_URL%/logo192.png" />
    <link rel="manifest" href="%PUBLIC_URL%/manifest.json" />
    <title>MongoFlow</title>
  </head>
  <body>
    <noscript>You need to enable JavaScript to run this app.</noscript>
    <div id="root"></div>
  </body>
</html>
EOL

cat > frontend/Dockerfile << 'EOL'
FROM node:18-alpine as build

WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOL

echo -e "${GREEN}Creating documentation files...${NC}"

# Create documentation
cat > docs/architecture.md << 'EOL'
# MongoFlow - Architecture Documentation

## Overview

MongoFlow follows a modular, cloud-native architecture to create a scalable, secure MongoDB Atlas deployment:

### Infrastructure as Code (IaC)

- **Terraform:** Provisions MongoDB Atlas, sets up users, networks, and authentication.
- **CloudFormation:** Deploys AWS resources (Lambdas, API Gateway, S3, IAM roles, CloudFront for UI hosting).
- **Secrets Management:** Uses GitHub Actions secrets for storing credentials securely.

### CI/CD Pipeline (GitHub Actions)

- **Automates Infrastructure Deployment:** Runs Terraform and CloudFormation on new commits.
- **Security Scanning:** Uses Snyk & Checkov to detect infrastructure and code vulnerabilities.
- **Automated Testing:** Linting, unit tests, and integration tests before deployment.
- **Multi-Environment Support:** Can be extended for staging, production, or multi-cloud setups.

### Application Layers

- **Backend:**
  - **Python Service** (FastAPI): CRUD operations with MongoDB Atlas.
  - **Go Service** (Gin): High-performance microservices interfacing with MongoDB.
  - **API Gateway (AWS):** Connects frontend to backend services.
- **Frontend:**
  - **React** Single-Page Application (SPA) with UI components.
  - **Static Hosting (AWS S3/CloudFront)** for cost-effective global distribution.

### Security & Compliance

- **Static Analysis:** Snyk, Bandit (Python), Gosec (Go) check for security flaws.
- **Infrastructure Scanning:** Checkov ensures Terraform/CloudFormation follow security best practices.
- **Automated Secret Scanning:** Prevents accidental exposure of sensitive credentials.
- **Role-Based IAM Policies:** Enforces least-privilege access for AWS resources.
EOL

cat > docs/deployment.md << 'EOL'
# MongoFlow - Deployment Guide

## Prerequisites

Ensure you have:

- **AWS Account** (for free-tier resources like Lambda, API Gateway, S3, CloudFront)
- **MongoDB Atlas Account** (free-tier M0 cluster)
- **GitHub Actions enabled** for CI/CD automation
- **Terraform, AWS CLI, Node.js, Go installed** for local testing (optional)

## Setup & Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/your-org/MongoFlow.git
   cd MongoFlow
   ```

2. **Set up secrets (GitHub or .env file locally):**
   ```bash
   export MONGODB_ATLAS_API_KEY=your_api_key
   export AWS_ACCESS_KEY_ID=your_aws_key
   export AWS_SECRET_ACCESS_KEY=your_aws_secret
   ```

3. **Deploy MongoDB Atlas infrastructure with Terraform:**
   ```bash
   cd iac/terraform
   terraform init
   terraform apply -auto-approve
   ```

4. **Deploy AWS infrastructure using CloudFormation:**
   ```bash
   cd iac/cloudformation
   aws cloudformation deploy --template-file stack.yaml --stack-name mongoflow-stack
   ```

5. **Deploy Application via GitHub Actions CI/CD** (automated when code is pushed to `main` branch)
   ```bash
   git push origin main
   ```

## Manual Testing

For local testing:

1. **Start Python service:**
   ```bash
   cd services/python-service
   pip install -r requirements.txt
   uvicorn app:app --reload
   ```

2. **Start Go service:**
   ```bash
   cd services/go-service
   go run main.go
   ```

3. **Start React frontend:**
   ```bash
   cd frontend
   npm install
   npm start
   ```
EOL

echo -e "${GREEN}Creating utility scripts...${NC}"

# Create utility scripts
cat > scripts/setup.sh << 'EOL'
#!/bin/bash

# MongoFlow Setup Script
echo "Setting up MongoFlow environment..."

# Check prerequisites
echo "Checking prerequisites..."
command -v aws >/dev/null 2>&1 || { echo "AWS CLI is required but not installed. Aborting."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo "Terraform is required but not installed. Aborting."; exit 1; }

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
  echo "Creating .env file..."
  cat > .env << DOTENV
# MongoDB Atlas credentials
MONGODB_ATLAS_PUBLIC_KEY=your_public_key
MONGODB_ATLAS_PRIVATE_KEY=your_private_key
MONGODB_ATLAS_ORG_ID=your_org_id

# AWS credentials
AWS_ACCESS_KEY_ID=your_access_key
AWS_SECRET_ACCESS_KEY=your_secret_key
AWS_REGION=us-east-1
DOTENV
  echo ".env file created. Please update it with your actual credentials."
else
  echo ".env file already exists."
fi

# Source environment variables
if [ -f .env ]; then
  echo "Loading environment variables..."
  export $(grep -v '^#' .env | xargs)
fi

echo "Setup complete! Follow the deployment instructions in docs/deployment.md to deploy the application."
EOL

cat > scripts/local-dev.sh << 'EOL'
#!/bin/bash

# MongoFlow Local Development Script
echo "Starting MongoFlow local development environment..."

# Check if running services are specified
if [ $# -eq 0 ]; then
  echo "Usage: $0 [all|frontend|python|go]"
  echo "  all      - Start all services"
  echo "  frontend - Start only the frontend"
  echo "  python   - Start only the Python service"
  echo "  go       - Start only the Go service"
  exit 1
fi

# Source environment variables if .env exists
if [ -f .env ]; then
  echo "Loading environment variables..."
  export $(grep -v '^#' .env | xargs)
fi

# Function to start the Python service
start_python() {
  echo "Starting Python service..."
  cd services/python-service
  pip install -r requirements.txt > /dev/null
  uvicorn app:app --reload --port 8000 &
  PYTHON_PID=$!
  cd ../..
  echo "Python service started on http://localhost:8000"
}

# Function to start the Go service
start_go() {
  echo "Starting Go service..."
  cd services/go-service
  go run main.go &
  GO_PID=$!
  cd ../..
  echo "Go service started on http://localhost:8080"
}

# Function to start the frontend
start_frontend() {
  echo "Starting React frontend..."
  cd frontend
  npm install > /dev/null
  npm start &
  FRONTEND_PID=$!
  cd ..
  echo "Frontend started on http://localhost:3000"
}

# Start services based on command line argument
case "$1" in
  all)
    start_python
    start_go
    start_frontend
    ;;
  python)
    start_python
    ;;
  go)
    start_go
    ;;
  frontend)
    start_frontend
    ;;
  *)
    echo "Unknown service: $1"
    exit 1
    ;;
esac

# Trap SIGINT to kill all background processes
trap "kill $PYTHON_PID $GO_PID $FRONTEND_PID 2>/dev/null" SIGINT

echo "Press Ctrl+C to stop all services"
wait
EOL

echo -e "${GREEN}Creating .gitignore...${NC}"

# Create .gitignore
cat > .gitignore << 'EOL'
# General
.DS_Store
.env
.env.local
.env.development.local
.env.test.local
.env.production.local
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# Node.js
node_modules/
coverage/
build/
dist/

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
*.egg-info/
.installed.cfg
*.egg

# Go
*.exe
*.exe~
*.dll
*.so
*.dylib
*.test
*.out
go.work

# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfplan
.terraformrc
terraform.rc

# AWS
.aws/
EOL

echo -e "${GREEN}Creating LICENSE...${NC}"

# Create LICENSE
cat > LICENSE << 'EOL'
MIT License

Copyright (c) 2023 MongoFlow Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOL

echo -e "${GREEN}Copying README.md...${NC}"

# Copy the existing README.md
cat > README.md << 'EOL'
# MongoFlow: Seamless MongoDB Atlas CI/CD & DevSecOps Pipeline

## 🚀 Overview

**MongoFlow** is a **production-ready, fully automated CI/CD pipeline** that integrates **MongoDB Atlas** with **Infrastructure as Code (IaC)** and **DevSecOps best practices**. It enables organizations to deploy **secure, scalable, and efficient cloud-native applications** while minimizing operational overhead and cost.

By combining **Terraform, AWS CloudFormation, Python, Go, and JavaScript**, this project automates:

- **MongoDB Atlas provisioning** via Terraform.
- **CI/CD deployments** using GitHub Actions.
- **Backend services in multiple languages** (Python, Go) connected to MongoDB Atlas.
- **A modern front-end application** hosted on AWS.
- **Security automation** through DevSecOps tools (Snyk, Checkov, GitHub security scans).
- **Zero-cost deployment** using free-tier cloud services.

---

## 🏆 Why This Project is Awesome

### **For Business Executives & Non-Technical Stakeholders**

✅ **Eliminates Manual Database Setup** – No more time wasted configuring MongoDB manually. ✅ **Reduces Deployment Risks** – Automates application deployment for reliability and speed. ✅ **Enhances Security & Compliance** – Built-in DevSecOps prevents security flaws from reaching production. ✅ **Boosts Operational Efficiency** – Developers focus on features instead of infrastructure headaches. ✅ **Minimizes Costs** – Uses cloud **free-tier resources**, making it ideal for startups or experimental projects. ✅ **Scales With Business Growth** – Modular, cloud-native architecture supports multi-cloud and hybrid setups.

### **For Developers & Engineers**

- **Terraform + CloudFormation** automates infrastructure provisioning and management
