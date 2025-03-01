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
