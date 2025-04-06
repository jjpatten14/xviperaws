#!/bin/bash
# Quick setup script for X Viper Alexa Skill

# Install dependencies for Lambda
echo "Installing Lambda dependencies..."
cd lambda
npm install

# Copy sample env file if .env doesn't exist
if [ ! -f "../.env" ]; then
  echo "Creating .env file from sample..."
  cp ../.env.sample ../.env
  echo "Please edit the .env file with your credentials"
fi

# Create a zip file for Lambda deployment
echo "Creating Lambda deployment package..."
zip -r ../deployment.zip *

cd ..
echo ""
echo "Setup complete!"
echo "Next steps:"
echo "1. Edit the .env file with your credentials"
echo "2. Run the deployment scripts in the scripts directory"
echo "3. Follow the instructions in README.md"
