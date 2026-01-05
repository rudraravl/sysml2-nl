package UserInterfaceSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ResponseTime :> Real {
        doc /* Time in milliseconds for system to respond to user input */
    }
    
    attribute def InputAccuracy :> Real {
        doc /* Percentage accuracy of input recognition */
    }
    
    item def UserInput {
        attribute inputType : String;
        attribute timestamp : Real;
        attribute inputData : String;
    }
    
    item def SystemResponse {
        attribute responseType : String;
        attribute timestamp : Real;
        attribute responseData : String;
        attribute success : Boolean;
    }
    
    item def DisplayContent {
        attribute contentType : String;
        attribute visualData : String;
        attribute audioData : String;
    }
    
    port def UserInputPort {
        in item userInput : UserInput;
    }
    
    port def DisplayOutputPort {
        out item displayContent : DisplayContent;
    }
    
    port def SystemFeedbackPort {
        out item systemResponse : SystemResponse;
    }
    
    part def InputProcessor {
        port inputPort : UserInputPort;
        port feedbackPort : SystemFeedbackPort;
        
        attribute processingDelay : ResponseTime;
        attribute accuracy : InputAccuracy;
        
        perform action processInput {
            in receivedInput : UserInput;
            out processedResponse : SystemResponse;
            
            first start;
            then action validateInput {
                in input : UserInput = receivedInput;
                out isValid : Boolean;
            }
            then decide;
                if validateInput.isValid then executeCommand;
                if not validateInput.isValid then rejectInput;
            action executeCommand {
                in validInput : UserInput = receivedInput;
                out commandResponse : SystemResponse;
            }
            then merge complete;
            action rejectInput {
                out errorResponse : SystemResponse;
            }
            then complete;
            then done;
        }
    }
    
    part def DisplayManager {
        port outputPort : DisplayOutputPort;
        
        attribute refreshRate : Real;
        attribute resolution : String;
        
        perform action updateDisplay {
            in content : DisplayContent;
            
            first start;
            then action renderContent {
                in displayData : DisplayContent = content;
            }
            then action transmitToScreen {
                in renderedData : DisplayContent = content;
            }
            then done;
        }
    }
    
    part def ApplicationCore {
        attribute currentState : String;
        attribute sessionActive : Boolean;
        
        perform action manageSession {
            first start;
            then merge awaitInput;
            then action receiveUserCommand;
            then decide;
                if sessionActive then processCommand;
                if not sessionActive then terminateSession;
            action processCommand {
                then action executeBusinessLogic;
                then action generateResponse;
            }
            then awaitInput;
            action terminateSession;
            then done;
        }
    }
    
    state def InterfaceState {
        entry action initializeInterface;
        do action monitorUserActivity;
        exit action cleanupResources;
        
        state idle {
            entry action displayIdleScreen;
        }
        
        state active {
            entry action enableInputs;
            
            state processingInput;
            state displayingOutput;
            state waitingForUser;
            
            transition first idle then processingInput;
            transition processingInput then displayingOutput;
            transition displayingOutput then waitingForUser;
            transition waitingForUser then processingInput;
        }
        
        state error {
            entry action displayErrorMessage;
            do action logError;
        }
        
        transition first idle then active;
        transition active then error;
        transition error then idle;
    }
    
    part def UserInterfaceSystem {
        attribute maxResponseTime : ResponseTime = 200.0;
        attribute minAccuracy : InputAccuracy = 95.0;
        attribute activeUsers : Integer;
        
        part inputProcessor : InputProcessor {
            attribute :>> processingDelay = 50.0;
            attribute :>> accuracy = 98.5;
        }
        
        part displayManager : DisplayManager {
            attribute :>> refreshRate = 60.0;
            attribute :>> resolution = "1920x1080";
        }
        
        part applicationCore : ApplicationCore {
            attribute :>> currentState = "initialized";
            attribute :>> sessionActive = true;
        }
        
        part interfaceController {
            perform stateBehavior : InterfaceState;
        }
        
        connection userInputFlow connect 
            inputProcessor.inputPort to applicationCore;
        
        connection displayOutputFlow connect 
            applicationCore to displayManager.outputPort;
        
        connection feedbackFlow connect 
            inputProcessor.feedbackPort to applicationCore;
    }
    
    requirement <'REQ-UI-001'> primaryFunction {
        doc /* The user interface system shall provide an interactive 
             * mechanism for users to input commands and receive visual 
             * and auditory feedback, enabling effective human-computer 
             * interaction through a responsive and intuitive interface.
             */
        subject uiSystem : UserInterfaceSystem;
    }
    
    requirement <'REQ-UI-002'> responseTimeRequirement {
        doc /* The system shall respond to user input within the 
             * maximum allowed response time.
             */
        subject uiSystem : UserInterfaceSystem;
        assert constraint {
            uiSystem.inputProcessor.processingDelay <= uiSystem.maxResponseTime
        }
    }
    
    requirement <'REQ-UI-003'> inputAccuracyRequirement {
        doc /* The input processor shall maintain minimum accuracy 
             * for recognizing and processing user inputs.
             */
        subject uiSystem : UserInterfaceSystem;
        assert constraint {
            uiSystem.inputProcessor.accuracy >= uiSystem.minAccuracy
        }
    }
    
    requirement <'REQ-UI-004'> displayRefreshRequirement {
        doc /* The display manager shall maintain adequate refresh 
             * rate for smooth visual presentation.
             */
        subject uiSystem : UserInterfaceSystem;
        assert constraint {
            uiSystem.displayManager.refreshRate >= 30.0
        }
    }
    
    part userInterfaceSystemInstance : UserInterfaceSystem {
        :>> maxResponseTime = 200.0;
        :>> minAccuracy = 95.0;
        :>> activeUsers = 1;
    }
    
    satisfy primaryFunction by userInterfaceSystemInstance;
    satisfy responseTimeRequirement by userInterfaceSystemInstance;
    satisfy inputAccuracyRequirement by userInterfaceSystemInstance;
    satisfy displayRefreshRequirement by userInterfaceSystemInstance;
    
    action def UserInteractionSequence {
        first start;
        then action userProvidesInput {
            out input : UserInput;
        }
        then action systemProcessesInput {
            in receivedInput : UserInput = userProvidesInput.input;
            out response : SystemResponse;
        }
        then action systemUpdatesDisplay {
            in content : DisplayContent;
        }
        then action userReceivesFeedback {
            in feedback : SystemResponse = systemProcessesInput.response;
        }
        then done;
    }
}
