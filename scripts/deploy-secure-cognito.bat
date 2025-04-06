@echo off
echo Deploying Secure Cognito Lambda Function
echo =====================================
echo.
echo This script will:
echo 1. Create a Lambda function that works with Cognito account linking
echo 2. Uses proper user authentication (NO hardcoded credentials)
echo 3. Package it with all dependencies
echo 4. Deploy it to AWS
echo 5. Set up environment variables
echo.

set REGION=us-east-1
set LAMBDA_FUNCTION_NAME=xviper-alexa-skill
set S3_BUCKET=xviper-us-east1-965239903867
set USER_POOL_ID=us-east-1_fhjkxtlkb

echo Creating temporary directory...
if exist lambda-secure rmdir /s /q lambda-secure
mkdir lambda-secure

echo Copying files...
xcopy /s /y lambda\*.* lambda-secure\
copy /y lambda\secureCognitoHandler.js lambda-secure\

echo Creating secure index.js...
echo /**
echo  * X Viper Alexa Skill Lambda Function with Secure Cognito Authentication
echo  */
echo const Alexa = require('ask-sdk-core');
echo const viperApi = require('./viperApi');
echo const secureCognitoHandler = require('./secureCognitoHandler');
echo.
echo // LAUNCH REQUEST HANDLER
echo const LaunchRequestHandler = {
echo     canHandle(handlerInput) {
echo         return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
echo     },
echo     async handle(handlerInput) {
echo         const userId = handlerInput.requestEnvelope.session.user.userId;
echo         console.log(`Launch request from user: ${userId}`);
echo.
echo         try {
echo             // Check if user is authenticated via account linking
echo             const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
echo             
echo             if (!accessToken) {
echo                 // User needs to link their account
echo                 return handlerInput.responseBuilder
echo                     .speak("Welcome to X Viper control. To get started, please link your account in the Alexa app.")
echo                     .withLinkAccountCard()
echo                     .getResponse();
echo             }
echo             
echo             // Process the authenticated request
echo             const { viperToken, defaultVehicle } = await secureCognitoHandler.processAuthenticatedRequest(
echo                 accessToken,
echo                 userId
echo             );
echo             
echo             if (defaultVehicle) {
echo                 return handlerInput.responseBuilder
echo                     .speak(`Welcome to X Viper control. You can ask me to lock, unlock, or control your ${defaultVehicle.vehicleName}. What would you like me to do?`)
echo                     .reprompt('What would you like me to do with your vehicle?')
echo                     .getResponse();
echo             } else {
echo                 return handlerInput.responseBuilder
echo                     .speak("Welcome to X Viper control. I couldn't find any vehicles associated with your account. Please check your X Viper account and try again.")
echo                     .getResponse();
echo             }
echo         } catch (error) {
echo             console.error('Error in LaunchIntent:', error);
echo             
echo             // If token is invalid, ask user to link account again
echo             if (error.message.includes('token') ^|^| error.name === 'NotAuthorizedException') {
echo                 return handlerInput.responseBuilder
echo                     .speak("I'm having trouble accessing your X Viper account. Please link your account again in the Alexa app.")
echo                     .withLinkAccountCard()
echo                     .getResponse();
echo             }
echo             
echo             return handlerInput.responseBuilder
echo                 .speak("I'm sorry, I'm having trouble connecting to your X Viper account right now. Please try again later.")
echo                 .getResponse();
echo         }
echo     }
echo };
echo.
echo // LOCK VEHICLE INTENT
echo const LockVehicleIntentHandler = {
echo     canHandle(handlerInput) {
echo         return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
echo             ^&^& Alexa.getIntentName(handlerInput.requestEnvelope) === 'LockVehicleIntent';
echo     },
echo     async handle(handlerInput) {
echo         const userId = handlerInput.requestEnvelope.session.user.userId;
echo         console.log(`Lock vehicle intent from user: ${userId}`);
echo.
echo         try {
echo             // Check if user is authenticated
echo             const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
echo             
echo             if (!accessToken) {
echo                 return handlerInput.responseBuilder
echo                     .speak("To control your vehicle, you need to link your account first. I've sent a card to your Alexa app to help you do this.")
echo                     .withLinkAccountCard()
echo                     .getResponse();
echo             }
echo             
echo             // Process the authenticated request
echo             const { viperToken, defaultVehicle } = await secureCognitoHandler.processAuthenticatedRequest(
echo                 accessToken,
echo                 userId
echo             );
echo             
echo             if (!viperToken ^|^| !defaultVehicle) {
echo                 return handlerInput.responseBuilder
echo                     .speak("I couldn't find a vehicle associated with your account. Please check your X Viper account and try again.")
echo                     .getResponse();
echo             }
echo.
echo             // Send lock command
echo             await viperApi.lockVehicle(viperToken, defaultVehicle.deviceId);
echo             
echo             return handlerInput.responseBuilder
echo                 .speak(`I've locked your ${defaultVehicle.vehicleName} for you.`)
echo                 .getResponse();
echo         } catch (error) {
echo             console.error('Error in LockVehicleIntent:', error);
echo             
echo             // If token is invalid, ask user to link account again
echo             if (error.message.includes('token') ^|^| error.name === 'NotAuthorizedException') {
echo                 return handlerInput.responseBuilder
echo                     .speak("I'm having trouble accessing your X Viper account. Please link your account again in the Alexa app.")
echo                     .withLinkAccountCard()
echo                     .getResponse();
echo             }
echo             
echo             return handlerInput.responseBuilder
echo                 .speak(`I'm sorry, I couldn't lock your vehicle. ${error.message}`)
echo                 .getResponse();
echo         }
echo     }
echo };
echo.
echo // [Add more intent handlers here for unlock, start, stop, etc.]
echo.
echo // ERROR HANDLER
echo const ErrorHandler = {
echo     canHandle() {
echo         return true;
echo     },
echo     handle(handlerInput, error) {
echo         console.error(`Error handled: ${error.message}`, error.stack);
echo         const speechText = `Sorry, I had trouble doing what you asked. Please try again.`;
echo.
echo         return handlerInput.responseBuilder
echo             .speak(speechText)
echo             .reprompt(speechText)
echo             .getResponse();
echo     }
echo };
echo.
echo // LAMBDA HANDLER
echo exports.handler = Alexa.SkillBuilders.custom()
echo     .addRequestHandlers(
echo         LaunchRequestHandler,
echo         LockVehicleIntentHandler
echo         // Add other intent handlers here
echo     )
echo     .addErrorHandlers(ErrorHandler)
echo     .lambda();
> lambda-secure\index.js

echo Installing dependencies...
cd lambda-secure
call npm install aws-sdk ask-sdk-core axios --save
cd ..

echo Creating deployment package...
if exist secure-cognito-deployment.zip del secure-cognito-deployment.zip

cd lambda-secure
powershell -Command "Compress-Archive -Path * -DestinationPath ..\secure-cognito-deployment.zip -Force"
cd ..

echo Uploading to S3...
aws s3 cp secure-cognito-deployment.zip s3://%S3_BUCKET%/secure-cognito-deployment.zip --region %REGION%

echo Updating Lambda function...
aws lambda update-function-code --function-name %LAMBDA_FUNCTION_NAME% --s3-bucket %S3_BUCKET% --s3-key secure-cognito-deployment.zip --region %REGION%

echo Setting environment variables...
aws lambda update-function-configuration --function-name %LAMBDA_FUNCTION_NAME% --environment "Variables={COGNITO_USER_POOL_ID=%USER_POOL_ID%,USER_MAPPING_TABLE=XviperUserMappings}" --region %REGION%

echo Done!
echo.
echo Your Lambda function is now set up for secure authentication!
echo.
echo IMPORTANT NEXT STEPS:
echo 1. Follow the instructions in setup-secure-cognito.md
echo 2. Make sure your Cognito User Pool has custom attributes for Viper credentials
echo 3. Set up a user registration process that collects Viper credentials
echo 4. Ensure your Lambda execution role has permission to call Cognito APIs
echo.
pause