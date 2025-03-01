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
