/**
 * X Viper Alexa Skill Lambda Function with Secure Cognito Authentication
 */
const Alexa = require('ask-sdk-core');
const viperApi = require('./viperApi');
const secureCognitoHandler = require('./secureCognitoHandler');

// LAUNCH REQUEST HANDLER
const LaunchRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'LaunchRequest';
    },
    async handle(handlerInput) {
        const userId = handlerInput.requestEnvelope.session.user.userId;
        console.log(Launch request from user: );

        try {
            // Check if user is authenticated via account linking
            const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
            
            if (!accessToken) {
                // User needs to link their account
                return handlerInput.responseBuilder
                    .speak("Welcome to X Viper control. To get started, please link your account in the Alexa app.")
                    .withLinkAccountCard()
                    .getResponse();
            }
            
            // Process the authenticated request
            const { viperToken, defaultVehicle } = await secureCognitoHandler.processAuthenticatedRequest(
                accessToken,
                userId
            );
            
            if (defaultVehicle) {
                return handlerInput.responseBuilder
                    .speak(Welcome to X Viper control. You can ask me to lock, unlock, or control your . What would you like me to do?)
                    .reprompt('What would you like me to do with your vehicle?')
                    .getResponse();
            } else {
                return handlerInput.responseBuilder
                    .speak("Welcome to X Viper control. I couldn't find any vehicles associated with your account. Please check your X Viper account and try again.")
                    .getResponse();
            }
        } catch (error) {
            console.error('Error in LaunchIntent:', error);
            
            // If token is invalid, ask user to link account again
            if (error.message.includes('token') || error.name === 'NotAuthorizedException') {
                return handlerInput.responseBuilder
                    .speak("I'm having trouble accessing your X Viper account. Please link your account again in the Alexa app.")
                    .withLinkAccountCard()
                    .getResponse();
            }
            
            return handlerInput.responseBuilder
                .speak("I'm sorry, I'm having trouble connecting to your X Viper account right now. Please try again later.")
                .getResponse();
        }
    }
};

// LOCK VEHICLE INTENT
const LockVehicleIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'LockVehicleIntent';
    },
    async handle(handlerInput) {
        const userId = handlerInput.requestEnvelope.session.user.userId;
        console.log(Lock vehicle intent from user: );

        try {
            // Check if user is authenticated
            const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
            
            if (!accessToken) {
                return handlerInput.responseBuilder
                    .speak("To control your vehicle, you need to link your account first. I've sent a card to your Alexa app to help you do this.")
                    .withLinkAccountCard()
                    .getResponse();
            }
            
            // Process the authenticated request
            const { viperToken, defaultVehicle } = await secureCognitoHandler.processAuthenticatedRequest(
                accessToken,
                userId
            );
            
            if (!viperToken || !defaultVehicle) {
                return handlerInput.responseBuilder
                    .speak("I couldn't find a vehicle associated with your account. Please check your X Viper account and try again.")
                    .getResponse();
            }

            // Send lock command
            await viperApi.lockVehicle(viperToken, defaultVehicle.deviceId);
            
            return handlerInput.responseBuilder
                .speak(I've locked your  for you.)
                .getResponse();
        } catch (error) {
            console.error('Error in LockVehicleIntent:', error);
            
            // If token is invalid, ask user to link account again
            if (error.message.includes('token') || error.name === 'NotAuthorizedException') {
                return handlerInput.responseBuilder
                    .speak("I'm having trouble accessing your X Viper account. Please link your account again in the Alexa app.")
                    .withLinkAccountCard()
                    .getResponse();
            }
            
            return handlerInput.responseBuilder
                .speak(I'm sorry, I couldn't lock your vehicle. )
                .getResponse();
        }
    }
};

// UNLOCK VEHICLE INTENT
const UnlockVehicleIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'UnlockVehicleIntent';
    },
    async handle(handlerInput) {
        const userId = handlerInput.requestEnvelope.session.user.userId;
        console.log(Unlock vehicle intent from user: );

        try {
            // Check if user is authenticated
            const accessToken = handlerInput.requestEnvelope.session.user.accessToken;
            
            if (!accessToken) {
                return handlerInput.responseBuilder
                    .speak("To control your vehicle, you need to link your account first. I've sent a card to your Alexa app to help you do this.")
                    .withLinkAccountCard()
                    .getResponse();
            }
            
            // Process the authenticated request
            const { viperToken, defaultVehicle } = await secureCognitoHandler.processAuthenticatedRequest(
                accessToken,
                userId
            );
            
            if (!viperToken || !defaultVehicle) {
                return handlerInput.responseBuilder
                    .speak("I couldn't find a vehicle associated with your account. Please check your X Viper account and try again.")
                    .getResponse();
            }

            // Send unlock command
            await viperApi.unlockVehicle(viperToken, defaultVehicle.deviceId);
            
            return handlerInput.responseBuilder
                .speak(I've unlocked your  for you.)
                .getResponse();
        } catch (error) {
            console.error('Error in UnlockVehicleIntent:', error);
            
            // If token is invalid, ask user to link account again
            if (error.message.includes('token') || error.name === 'NotAuthorizedException') {
                return handlerInput.responseBuilder
                    .speak("I'm having trouble accessing your X Viper account. Please link your account again in the Alexa app.")
                    .withLinkAccountCard()
                    .getResponse();
            }
            
            return handlerInput.responseBuilder
                .speak(I'm sorry, I couldn't unlock your vehicle. )
                .getResponse();
        }
    }
};

// Add other intent handlers for start engine, stop engine, etc.

// STANDARD ALEXA BUILT-IN INTENTS
const HelpIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.HelpIntent';
    },
    handle(handlerInput) {
        const speechText = 'You can ask me to lock or unlock your vehicle, start or stop the engine, or open the trunk. For example, say "lock my car" or "start my car engine".';

        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt(speechText)
            .getResponse();
    }
};

const CancelAndStopIntentHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'IntentRequest'
            && (Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.CancelIntent'
                || Alexa.getIntentName(handlerInput.requestEnvelope) === 'AMAZON.StopIntent');
    },
    handle(handlerInput) {
        const speechText = 'Goodbye!';

        return handlerInput.responseBuilder
            .speak(speechText)
            .getResponse();
    }
};

const SessionEndedRequestHandler = {
    canHandle(handlerInput) {
        return Alexa.getRequestType(handlerInput.requestEnvelope) === 'SessionEndedRequest';
    },
    handle(handlerInput) {
        // Any cleanup logic goes here
        console.log(Session ended with reason: );
        return handlerInput.responseBuilder.getResponse();
    }
};

// ERROR HANDLER
const ErrorHandler = {
    canHandle() {
        return true;
    },
    handle(handlerInput, error) {
        console.error(Error handled: , error.stack);
        const speechText = Sorry, I had trouble doing what you asked. Please try again.;

        return handlerInput.responseBuilder
            .speak(speechText)
            .reprompt(speechText)
            .getResponse();
    }
};

// LAMBDA HANDLER
exports.handler = Alexa.SkillBuilders.custom()
    .addRequestHandlers(
        LaunchRequestHandler,
        LockVehicleIntentHandler,
        UnlockVehicleIntentHandler,
        HelpIntentHandler,
        CancelAndStopIntentHandler,
        SessionEndedRequestHandler
    )
    .addErrorHandlers(ErrorHandler)
    .lambda();
