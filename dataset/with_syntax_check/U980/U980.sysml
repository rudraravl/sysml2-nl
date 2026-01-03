package AutomatedAttendantSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def PhoneNumber;
    attribute def ExtensionNumber;
    attribute def CallDuration :> ISQ::TimeValue;
    attribute def MaxWaitTime :> ISQ::TimeValue;
    
    enum def MenuOptionEnum {
        sales;
        support;
        billing;
        directory;
        operator;
        invalid;
    }
    
    item def IncomingCall {
        attribute callerID : PhoneNumber;
        attribute timestamp : ISQ::TimeValue;
        attribute callDuration : CallDuration;
    }
    
    item def VoicePrompt {
        attribute messageText : String;
        attribute playbackDuration : ISQ::TimeValue;
    }
    
    item def DTMFInput {
        attribute digitPressed : Integer;
        attribute inputTime : ISQ::TimeValue;
    }
    
    item def RoutingDecision {
        attribute selectedOption : MenuOptionEnum;
        attribute targetExtension : ExtensionNumber;
        attribute routingTime : ISQ::TimeValue;
    }
    
    item def CallRecord {
        attribute callInfo : IncomingCall;
        attribute menuSelection : MenuOptionEnum;
        attribute finalDestination : ExtensionNumber;
        attribute totalHandlingTime : CallDuration;
    }
    
    port def TelephonyPort {
        in item incomingCall : IncomingCall;
        out item routedCall : IncomingCall;
    }
    
    port def AudioPort {
        out item voicePrompt : VoicePrompt;
        in item dtmfInput : DTMFInput;
    }
    
    port def RoutingPort {
        out item routingCommand : RoutingDecision;
    }
    
    port def LoggingPort {
        out item callLog : CallRecord;
    }
    
    part def CallReceiver {
        port telephonyIn : TelephonyPort;
        
        action def AnswerCall {
            in call : IncomingCall;
            out answeredCall : IncomingCall;
        }
        
        perform action answerIncomingCall : AnswerCall[*] ordered;
    }
    
    part def PromptGenerator {
        port audioOut : AudioPort;
        
        attribute welcomeMessage : String := "Welcome. Please select from the following options.";
        attribute menuMessage : String := "Press 1 for Sales, 2 for Support, 3 for Billing, 4 for Directory, or 0 for Operator.";
        attribute invalidMessage : String := "Invalid selection. Please try again.";
        attribute transferMessage : String := "Please hold while we transfer your call.";
        
        action def GenerateWelcome {
            out prompt : VoicePrompt;
        }
        
        action def GenerateMenu {
            out prompt : VoicePrompt;
        }
        
        action def GenerateError {
            out prompt : VoicePrompt;
        }
        
        action def GenerateTransfer {
            out prompt : VoicePrompt;
        }
        
        perform action createPrompts[*];
    }
    
    part def InputProcessor {
        port audioIn : AudioPort;
        
        attribute maxRetries : Integer := 3;
        attribute inputTimeout : MaxWaitTime := 10.0 [SI::s];
        
        action def CaptureInput {
            in dtmf : DTMFInput;
            out capturedDigit : Integer;
        }
        
        action def ValidateInput {
            in digit : Integer;
            out isValid : Boolean;
            out option : MenuOptionEnum;
        }
        
        perform action processUserInput : CaptureInput[*];
        perform action validateUserInput : ValidateInput[*];
    }
    
    part def RoutingEngine {
        port routingOut : RoutingPort;
        
        attribute salesExtension : ExtensionNumber := "1001";
        attribute supportExtension : ExtensionNumber := "1002";
        attribute billingExtension : ExtensionNumber := "1003";
        attribute directoryExtension : ExtensionNumber := "1004";
        attribute operatorExtension : ExtensionNumber := "1000";
        
        action def DetermineRoute {
            in selectedOption : MenuOptionEnum;
            out destination : ExtensionNumber;
        }
        
        action def ExecuteTransfer {
            in call : IncomingCall;
            in destination : ExtensionNumber;
            out transferredCall : IncomingCall;
        }
        
        perform action calculateRoute : DetermineRoute[*];
        perform action transferCall : ExecuteTransfer[*];
    }
    
    part def CallLogger {
        port loggingOut : LoggingPort;
        
        attribute callHistory : CallRecord[*] := ();
        
        action def RecordCall {
            in callData : IncomingCall;
            in selection : MenuOptionEnum;
            in destination : ExtensionNumber;
            in duration : CallDuration;
            out logEntry : CallRecord;
        }
        
        action def StoreRecord {
            in record : CallRecord;
        }
        
        perform action logCallData : RecordCall[*];
        perform action archiveRecord : StoreRecord[*];
    }
    
    state def AttendantStateMachine {
        entry; then idle;
        
        state idle {
            entry action waitForIncomingCall;
        }
        
        transition idle_to_answering
            first idle
            accept incomingCall : IncomingCall
            then answering;
        
        state answering {
            entry action answerAndGreet;
        }
        
        transition answering_to_presenting
            first answering
            then presentingMenu;
        
        state presentingMenu {
            entry action playMenuPrompt;
        }
        
        transition presenting_to_collecting
            first presentingMenu
            then collectingInput;
        
        state collectingInput {
            entry action waitForDTMF;
        }
        
        transition collecting_to_validating
            first collectingInput
            accept userInput : DTMFInput
            then validating;
        
        state validating {
            entry action checkInputValidity;
        }
        
        transition validating_to_routing
            first validating
            then routing;
        
        transition validating_to_error
            first validating
            then errorHandling;
        
        transition validating_to_operator
            first validating
            then routingToOperator;
        
        state errorHandling {
            entry action playErrorPrompt;
            do action incrementRetryCounter;
        }
        
        transition error_to_presenting
            first errorHandling
            then presentingMenu;
        
        state routing {
            entry action determineDestination;
        }
        
        transition routing_to_transferring
            first routing
            then transferring;
        
        state routingToOperator {
            entry action setOperatorDestination;
        }
        
        transition operator_to_transferring
            first routingToOperator
            then transferring;
        
        state transferring {
            entry action executeCallTransfer;
        }
        
        transition transferring_to_logging
            first transferring
            then logging;
        
        state logging {
            entry action recordCallDetails;
        }
        
        transition logging_to_complete
            first logging
            then callComplete;
        
        state callComplete {
            entry action finalizeCall;
        }
        
        transition complete_to_idle
            first callComplete
            then idle;
    }
    
    action def ProcessCall {
        in call : IncomingCall;
        out finalRecord : CallRecord;
        
        private attribute currentRetries : Integer := 0;
        private attribute selectedOption : MenuOptionEnum;
        private attribute targetExtension : ExtensionNumber;
        
        first start;
        
        then action receiveCall {
            in incomingCall : IncomingCall = call;
            out receivedCall : IncomingCall;
        }
        
        then action playWelcome {
            out welcomePrompt : VoicePrompt;
        }
        
        then merge menuLoop;
        
        then action presentMenu {
            out menuPrompt : VoicePrompt;
        }
        
        then action collectInput {
            out userInput : DTMFInput;
        }
        
        then action validateSelection {
            in input : DTMFInput = collectInput.userInput;
            out valid : Boolean;
            out option : MenuOptionEnum;
        }
        
        then decide inputValidation;
            if validateSelection.valid then routeCall;
            if not validateSelection.valid and currentRetries < 3 then handleInvalidInput;
            if not validateSelection.valid and currentRetries >= 3 then routeToOperator;
        
        action handleInvalidInput {
            out errorPrompt : VoicePrompt;
        }
        then assign currentRetries := currentRetries + 1;
        then menuLoop;
        
        action routeCall {
            in option : MenuOptionEnum = validateSelection.option;
            out destination : ExtensionNumber;
        }
        then transferCall;
        
        action routeToOperator {
            out operatorDestination : ExtensionNumber;
        }
        then transferCall;
        
        join transferCall;
        then action executeTransfer {
            in callToTransfer : IncomingCall = receiveCall.receivedCall;
            in transferDestination : ExtensionNumber = routeCall.destination | routeToOperator.operatorDestination;
            out transferredCall : IncomingCall;
        }
        
        then action logCall {
            in callData : IncomingCall = executeTransfer.transferredCall;
            in selection : MenuOptionEnum = validateSelection.option;
            in destination : ExtensionNumber = executeTransfer.transferDestination;
            out record : CallRecord = finalRecord;
        }
        
        then done;
    }
    
    part def AutomatedAttendant {
        attribute systemName : String := "Enterprise Automated Attendant";
        attribute maxConcurrentCalls : Integer := 100;
        attribute averageHandlingTime : CallDuration := 45.0 [SI::s];
        attribute systemUptime : Real := 99.9;
        
        port mainTelephonyPort : TelephonyPort;
        port audioInterface : AudioPort;
        port routingInterface : RoutingPort;
        port loggingInterface : LoggingPort;
        
        part receiver : CallReceiver {
            :>> telephonyIn = mainTelephonyPort;
        }
        
        part promptGen : PromptGenerator {
            :>> audioOut = audioInterface;
        }
        
        part inputProc : InputProcessor {
            :>> audioIn = audioInterface;
        }
        
        part router : RoutingEngine {
            :>> routingOut = routingInterface;
        }
        
        part logger : CallLogger {
            :>> loggingOut = loggingInterface;
        }
        
        connection receiverToPrompt
            connect receiver.telephonyIn to promptGen.audioOut;
        
        connection promptToInput
            connect promptGen.audioOut to inputProc.audioIn;
        
        connection inputToRouter
            connect inputProc.audioIn to router.routingOut;
        
        connection routerToLogger
            connect router.routingOut to logger.loggingOut;
        
        perform action handleCall : ProcessCall[*] ordered;
        
        exhibit state systemBehavior : AttendantStateMachine;
    }
    
    requirement def <'ATT-REQ-001'> PrimaryFunctionRequirement {
        doc /* 
            The automated attendant system shall automatically answer incoming telephone calls,
            greet callers with a welcome message, present a menu of routing options,
            accept and validate caller input via DTMF tones, and route calls to the
            appropriate destination based on the caller's selection without human intervention.
        */
        
        subject attendant : AutomatedAttendant;
        
        require constraint automaticAnswering {
            doc /* The system shall answer all incoming calls automatically within 3 rings. */
        }
        
        require constraint menuPresentation {
            doc /* The system shall present a clear menu of available options to all callers. */
        }
        
        require constraint inputProcessing {
            doc /* The system shall accept and process DTMF input from callers. */
        }
        
        require constraint callRouting {
            doc /* The system shall route calls to the correct destination based on validated input. */
        }
    }
    
    requirement def <'ATT-REQ-002'> AvailabilityRequirement {
        doc /* The automated attendant system shall maintain 99.9% uptime during business hours. */
        
        subject attendant : AutomatedAttendant;
        
        require constraint uptimeConstraint {
            attendant.systemUptime >= 99.9
        }
    }
    
    requirement def <'ATT-REQ-003'> CapacityRequirement {
        doc /* The system shall handle at least 100 concurrent calls without performance degradation. */
        
        subject attendant : AutomatedAttendant;
        
        require constraint capacityConstraint {
            attendant.maxConcurrentCalls >= 100
        }
    }
    
    requirement def <'ATT-REQ-004'> ErrorHandlingRequirement {
        doc /* The system shall allow up to 3 retry attempts for invalid input before routing to an operator. */
        
        subject processor : InputProcessor;
        
        require constraint retryConstraint {
            processor.maxRetries == 3
        }
    }
    
    requirement def <'ATT-REQ-005'> ResponseTimeRequirement {
        doc /* The system shall process each call interaction within an average of 45 seconds. */
        
        subject attendant : AutomatedAttendant;
        
        require constraint responseConstraint {
            attendant.averageHandlingTime <= 60.0 [SI::s]
        }
    }
    
    requirement <'ATT-SYS-REQ'> automatedAttendantSystemRequirement {
        doc /* 
            The automated attendant system provides unattended call handling capability
            by automatically answering incoming calls, presenting menu options to callers,
            processing their selections, and routing calls to appropriate destinations
            based on caller input, thereby eliminating the need for human operators
            for routine call distribution tasks.
        */
        
        subject attendantSystem : AutomatedAttendant;
        
        assume constraint telephonyInfrastructure {
            doc /* Standard PSTN or VoIP telephony infrastructure is available and operational. */
        }
        
        assume constraint dtmfSupport {
            doc /* Caller telephone equipment supports DTMF tone generation. */
        }
        
        require PrimaryFunctionRequirement;
        require AvailabilityRequirement;
        require CapacityRequirement;
        require ErrorHandlingRequirement;
        require ResponseTimeRequirement;
    }
    
    part enterpriseAttendantSystem : AutomatedAttendant {
        :>> systemName = "Main Office Automated Attendant";
        :>> maxConcurrentCalls = 150;
        :>> averageHandlingTime = 42.0 [SI::s];
        :>> systemUptime = 99.95;
    }
}
