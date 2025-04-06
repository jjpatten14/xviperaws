# X Viper Alexa Skill

This repository contains all the code and configuration needed to create and deploy an Alexa skill that controls Viper-equipped vehicles using voice commands.

![Viper Logo](https://www.viper.com/images/logo.png)

## Features

- **Control Your Vehicle with Voice**: Lock, unlock, start/stop engine, open trunk
- **AWS Serverless Architecture**: Uses Lambda functions, DynamoDB, and S3
- **Secure Authentication**: Integrates with Amazon Cognito for secure credential management
- **One-Click Deployment**: Complete automated setup scripts for Windows

## 🚗 Voice Commands

After setup, you can use these commands with your Alexa device:

- "Alexa, ask X Viper to lock my car"
- "Alexa, ask X Viper to unlock my car"
- "Alexa, ask X Viper to start my engine"
- "Alexa, ask X Viper to stop my engine"
- "Alexa, ask X Viper to open my trunk"
- "Alexa, ask X Viper to list my vehicles"

## 🔧 Quick Start

### Prerequisites

- Windows 10 or 11
- AWS account with appropriate permissions
- AWS CLI installed and configured
- Node.js and npm installed
- Viper Connect account with at least one connected vehicle
- Amazon Developer account

### One-Click Setup

1. Clone this repository:
   ```
   git clone https://github.com/yourusername/xviper.git
   cd xviper
   ```

2. Run the one-click deployment script:
   ```
   one-click-recreate.bat
   ```

3. Follow the on-screen instructions to:
   - Enter your Viper account credentials
   - Create AWS resources
   - Configure the Alexa skill

4. Test your skill by saying "Alexa, ask X Viper to lock my car"

## 📁 Repository Structure

- `/lambda` - Lambda function code for the Alexa skill
- `/scripts` - PowerShell and Batch deployment scripts
- `/models` - Alexa skill interaction model
- `/alexa-skill-config` - Alexa skill configuration files
- `/cloudformation.yaml` - AWS resource definitions

## 🛠️ Manual Setup

If you prefer to go through the setup process manually:

1. Create AWS resources:
   ```
   .\scripts\1-create-bucket.bat
   ```

2. Deploy the Lambda function:
   ```
   .\scripts\2-create-lambda.bat
   ```

3. Configure the Alexa skill:
   ```
   .\scripts\2-deploy-skill.bat
   ```

4. Complete the setup in the Alexa Developer Console using the provided instructions

## 🔒 Security

- All credentials are securely stored in AWS Cognito
- API tokens are handled securely and temporarily cached
- Communications with Viper API are encrypted

## 🔍 Troubleshooting

If you encounter issues during setup:

1. Check AWS permissions and configuration:
   ```
   .\scripts\check-aws-config.bat
   ```

2. Review Cognito setup:
   ```
   .\scripts\fix-cognito-permissions.bat
   ```

3. See the Lambda logs:
   ```
   .\scripts\check-lambda-logs.bat
   ```

For detailed troubleshooting, see [COGNITO_PERMISSIONS_FIX.md](COGNITO_PERMISSIONS_FIX.md).

## 📚 Documentation

- [Deployment Summary](DEPLOYMENT_SUMMARY.md)
- [Cognito Permissions Fix](COGNITO_PERMISSIONS_FIX.md)
- [Testing Guide](TESTING_GUIDE.md)

## 🤝 Contributing

Contributions welcome! If you'd like to improve this project:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
