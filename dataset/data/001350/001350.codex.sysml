package AutomatedAttendantSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def PhoneNumber {
        attribute countryCode : Integer;
        attribute areaCode : Integer;
        attribute localNumber : String;
    }

    attribute def MenuDigit {
        attribute value : Integer;
    }

    attribute def ConfidenceScore {
        attribute value : Real;
    }

    attribute def QueuePosition {
        attribute value : Integer;
    }

    attribute def CallDuration {
        attribute value : Real;
        unit = s;
    }

    attribute def PromptDuration {
        attribute value : Real;
        unit = s;
    }

    attribute def AudioLevel {
        attribute value : Real;
        unit = dB;
    }

    attribute def TimeLimit {
        attribute value : Real;
        unit = s;
    }

    item def VoiceAudio {
        attribute level : AudioLevel;
        attribute duration : CallDuration;
        attribute encoding : String;
    }

    item def DtmfTone {
        attribute digit : MenuDigit;
        attribute duration : PromptDuration;
    }

    item def SpeechIntent {
        attribute name : String;
        attribute confidence : ConfidenceScore;
    }

    item def CallerIdentity {
        attribute callerNumber : PhoneNumber;
        attribute verified : Boolean;
        attribute customerId : String;
    }

    item def MenuSelection {
        attribute selectedOption : MenuDigit;
        attribute selectedIntent : String;
    }

    item def RoutingDecision {
        attribute destinationQueue : String;
        attribute priority : Integer;
        attribute requiresAgent : Boolean;
    }

    item def AgentAvailability {
        attribute queueName : String;
        attribute availableAgents : Integer;
        attribute estimatedWait : TimeLimit;
    }

    item def CallRecord {
        attribute caller : CallerIdentity;
        attribute startTime : String;
        attribute duration : CallDuration;
        attribute finalDisposition : String;
    }

    port def TelephonyPort {
        in item inboundAudio : VoiceAudio;
        in item inboundTone : DtmfTone;
        out item outboundAudio : VoiceAudio;
    }

    port def RecognitionPort {
        out item audioToRecognize : VoiceAudio;
        in item recognizedIntent : SpeechIntent;
    }

    port def DirectoryPort {
        out item lookupIdentity : CallerIdentity;
        in item resolvedIdentity : CallerIdentity;
    }

    port def RoutingPort {
        out item routeRequest : RoutingDecision;
        in item queueStatus : AgentAvailability;
    }

    port def AgentTransferPort {
        out item transferDecision : RoutingDecision;
        out item callContext : CallRecord;
    }

    part def AudioPromptPlayer {
        port promptOut : TelephonyPort;

        attribute greetingDuration : PromptDuration = 6 [s];
        attribute menuPromptDuration : PromptDuration = 12 [s];
        attribute retryPromptDuration : PromptDuration = 5 [s];
        attribute goodbyePromptDuration : PromptDuration = 4 [s];

        action playGreeting {
            out item greetingAudio : VoiceAudio;
        }

        action playMainMenu {
            out item menuAudio : VoiceAudio;
        }

        action playRetryPrompt {
            out item retryAudio : VoiceAudio;
        }

        action playTransferPrompt {
            in item decision : RoutingDecision;
            out item transferAudio : VoiceAudio;
        }

        action playGoodbye {
            out item goodbyeAudio : VoiceAudio;
        }
    }

    part def InputCollector {
        port callerMedia : TelephonyPort;
        port recognition : RecognitionPort;

        attribute digitTimeout : TimeLimit = 7 [s];
        attribute speechTimeout : TimeLimit = 8 [s];
        attribute maximumRetries : Integer = 3;

        action collectDtmf {
            in item tone : DtmfTone;
            out item selection : MenuSelection;
        }

        action collectSpeech {
            in item spokenAudio : VoiceAudio;
            out item intent : SpeechIntent;
        }

        action normalizeSelection {
            in item selection : MenuSelection;
            in item intent : SpeechIntent;
            out item normalizedSelection : MenuSelection;
        }
    }

    part def CallerVerifier {
        port directory : DirectoryPort;

        attribute verificationTimeout : TimeLimit = 10 [s];

        action identifyCaller {
            in item callingNumber : PhoneNumber;
            out item identity : CallerIdentity;
        }

        action verifyCaller {
            in item identity : CallerIdentity;
            out item verifiedIdentity : CallerIdentity;
        }
    }

    part def MenuManager {
        attribute salesDigit : MenuDigit = 1;
        attribute supportDigit : MenuDigit = 2;
        attribute billingDigit : MenuDigit = 3;
        attribute operatorDigit : MenuDigit = 0;
        attribute repeatDigit : MenuDigit = 9;

        action mapSelectionToRoute {
            in item selection : MenuSelection;
            in item caller : CallerIdentity;
            out item routingDecision : RoutingDecision;
        }

        action determineInvalidSelection {
            in item selection : MenuSelection;
            out item invalid : Boolean;
        }
    }

    part def QueueRouter {
        port routingStatus : RoutingPort;
        port transferOut : AgentTransferPort;

        attribute defaultPriority : Integer = 5;
        attribute verifiedCustomerPriorityBoost : Integer = 2;
        attribute maximumAcceptableWait : TimeLimit = 300 [s];

        action requestQueueStatus {
            in item decision : RoutingDecision;
            out item status : AgentAvailability;
        }

        action adjustPriority {
            in item caller : CallerIdentity;
            in item decision : RoutingDecision;
            out item prioritizedDecision : RoutingDecision;
        }

        action transferCall {
            in item prioritizedDecision : RoutingDecision;
            in item record : CallRecord;
        }
    }

    part def CallLogger {
        attribute retentionPeriodDays : Integer = 730;

        action startRecord {
            in item caller : CallerIdentity;
            out item record : CallRecord;
        }

        action updateDisposition {
            in item record : CallRecord;
            in item decision : RoutingDecision;
            out item completedRecord : CallRecord;
        }

        action closeRecord {
            in item completedRecord : CallRecord;
        }
    }

    part def AutomatedAttendant {
        port telephony : TelephonyPort;
        port speechRecognition : RecognitionPort;
        port customerDirectory : DirectoryPort;
        port workforceRouting : RoutingPort;
        port agentTransfer : AgentTransferPort;

        part promptPlayer : AudioPromptPlayer;
        part inputCollector : InputCollector;
        part callerVerifier : CallerVerifier;
        part menuManager : MenuManager;
        part queueRouter : QueueRouter;
        part callLogger : CallLogger;

        attribute maxCallSetupTime : TimeLimit = 3 [s];
        attribute maxMenuRetries : Integer = 3;
        attribute minimumRecognitionConfidence : ConfidenceScore;
        attribute targetContainmentRate : Real = 0.35;

        connect telephony to promptPlayer.promptOut;
        connect telephony to inputCollector.callerMedia;
        connect speechRecognition to inputCollector.recognition;
        connect customerDirectory to callerVerifier.directory;
        connect workforceRouting to queueRouter.routingStatus;
        connect agentTransfer to queueRouter.transferOut;

        action handleIncomingCall {
            in item inboundAudio : VoiceAudio;
            in item callingNumber : PhoneNumber;
            out item finalRecord : CallRecord;

            first start;
            then identifyCaller;
            then playGreeting;
            then presentMenu;
            then collectInput;
            then evaluateInput;

            action identifyCaller {
                out item caller : CallerIdentity;
            }

            action playGreeting {
                in item caller : CallerIdentity;
            }

            action presentMenu {
                out item menuAudio : VoiceAudio;
            }

            action collectInput {
                out item selection : MenuSelection;
            }

            action evaluateInput {
                in item selection : MenuSelection;
                out item decision : RoutingDecision;
            }

            action routeOrRetry {
                in item decision : RoutingDecision;
                out item routed : Boolean;
            }

            action closeCall {
                in item decision : RoutingDecision;
                out item finalRecord : CallRecord;
            }

            flow identifyCaller.caller to playGreeting.caller;
            flow presentMenu.menuAudio to collectInput;
            flow collectInput.selection to evaluateInput.selection;
            flow evaluateInput.decision to routeOrRetry.decision;
            flow evaluateInput.decision to closeCall.decision;
        }

        state def CallHandlingStateMachine {
            entry action initializeCall;
            exit action finalizeCallRecord;

            state Idle;
            state Answering;
            state GreetingCaller;
            state VerifyingCaller;
            state PresentingMenu;
            state CollectingInput;
            state InterpretingInput;
            state RoutingCall;
            state TransferringToAgent;
            state RetryingInput;
            state TerminatingCall;

            transition first Idle;
            transition Idle_to_Answering
                first Idle
                then Answering
                accept CallArrived;

            transition Answering_to_GreetingCaller
                first Answering
                then GreetingCaller
                accept CallAnswered;

            transition GreetingCaller_to_VerifyingCaller
                first GreetingCaller
                then VerifyingCaller
                accept GreetingComplete;

            transition VerifyingCaller_to_PresentingMenu
                first VerifyingCaller
                then PresentingMenu
                accept CallerVerified;

            transition PresentingMenu_to_CollectingInput
                first PresentingMenu
                then CollectingInput
                accept MenuPromptComplete;

            transition CollectingInput_to_InterpretingInput
                first CollectingInput
                then InterpretingInput
                accept InputReceived;

            transition InterpretingInput_to_RoutingCall
                first InterpretingInput
                then RoutingCall
                accept ValidSelection;

            transition InterpretingInput_to_RetryingInput
                first InterpretingInput
                then RetryingInput
                accept InvalidSelection;

            transition RetryingInput_to_PresentingMenu
                first RetryingInput
                then PresentingMenu
                accept RetryAvailable;

            transition RetryingInput_to_TerminatingCall
                first RetryingInput
                then TerminatingCall
                accept RetryLimitReached;

            transition RoutingCall_to_TransferringToAgent
                first RoutingCall
                then TransferringToAgent
                accept AgentQueueSelected;

            transition RoutingCall_to_TerminatingCall
                first RoutingCall
                then TerminatingCall
                accept SelfServiceCompleted;

            transition TransferringToAgent_to_TerminatingCall
                first TransferringToAgent
                then TerminatingCall
                accept TransferComplete;

            transition TerminatingCall_to_Idle
                first TerminatingCall
                then Idle
                accept CallReleased;
        }
    }

    part automatedAttendantSystem : AutomatedAttendant {
        attribute minimumRecognitionConfidence : ConfidenceScore {
            :>> value = 0.78;
        }
    }

    requirement def HighLevelFunctionRequirement {
        subject system : AutomatedAttendant;
        doc /* The automated attendant shall answer inbound calls, greet callers, identify caller intent using speech or keypad input, provide menu-driven self-service navigation, and route callers to the appropriate queue or agent with call context. */
    }

    requirement def AvailabilityRequirement {
        subject system : AutomatedAttendant;
        attribute requiredAvailability : Real = 0.995;
        doc /* The automated attendant shall be available to answer inbound calls at least 99.5 percent of scheduled operating time. */
    }

    requirement def AnswerTimeRequirement {
        subject system : AutomatedAttendant;
        attribute maximumAnswerTime : TimeLimit = 3 [s];
        doc /* The automated attendant shall answer an inbound call within 3 seconds after receiving the call arrival event. */
    }

    requirement def InputRecognitionRequirement {
        subject system : AutomatedAttendant;
        attribute minimumConfidence : Real = 0.78;
        doc /* The automated attendant shall accept a spoken intent only when recognition confidence is at least 0.78, otherwise it shall retry or request keypad input. */
    }

    requirement def RetryLimitRequirement {
        subject system : AutomatedAttendant;
        attribute maximumRetries : Integer = 3;
        doc /* The automated attendant shall attempt no more than three input retries before routing the caller to an operator or terminating according to configured policy. */
    }

    requirement def CallContextTransferRequirement {
        subject system : AutomatedAttendant;
        doc /* The automated attendant shall transfer caller identity, selected intent, routing decision, and call history to the receiving agent queue. */
    }

    requirement def AuditLoggingRequirement {
        subject system : AutomatedAttendant;
        attribute minimumRetentionDays : Integer = 730;
        doc /* The automated attendant shall create and retain a call record for each handled call for at least 730 days. */
    }

    satisfy HighLevelFunctionRequirement by automatedAttendantSystem;
    satisfy AvailabilityRequirement by automatedAttendantSystem;
    satisfy AnswerTimeRequirement by automatedAttendantSystem;
    satisfy InputRecognitionRequirement by automatedAttendantSystem;
    satisfy RetryLimitRequirement by automatedAttendantSystem;
    satisfy CallContextTransferRequirement by automatedAttendantSystem;
    satisfy AuditLoggingRequirement by automatedAttendantSystem;
}