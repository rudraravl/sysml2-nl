package IVRSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQBase::*;

    // ---------- Value types ----------
    value def AvailabilityPercent :> Real {
        unit %;
    }
    value def CallCount :> Integer;
    value def ExtensionNumber :> String;
    value def PhoneNumber :> String;
    value def DurationSeconds :> Real {
        unit 's';
    }
    value def DtmfKey :> String;
    value def PromptId :> String;

    // ---------- Item definitions ----------
    item def IncomingCall {
        attribute callerNumber : PhoneNumber;
        attribute arrivalTime : DateTime;
        attribute callId : String;
    }
    item def AnsweredCall {
        attribute callerNumber : PhoneNumber;
        attribute answeredAt : DateTime;
        attribute callId : String;
    }
    item def AudioPrompt {
        attribute id : PromptId;
        attribute text : String;
        attribute duration : DurationSeconds;
    }
    item def MenuSelection {
        attribute key : DtmfKey;
        attribute attempt : Integer;
        attribute callId : String;
    }
    item def RoutingDecision {
        attribute selection : MenuSelection;
        attribute targetExtension : ExtensionNumber;
        attribute callId : String;
    }
    item def TransferRequest {
        attribute callId : String;
        attribute targetExtension : ExtensionNumber;
        attribute callerNumber : PhoneNumber;
    }
    item def LogEntry {
        attribute callerNumber : PhoneNumber;
        attribute selection : DtmfKey;
        attribute destination : ExtensionNumber;
        attribute duration : DurationSeconds;
        attribute timestamp : DateTime;
        attribute callId : String;
    }

    // ---------- Port definitions ----------
    port def TelephonyLinePort {
        out item call : IncomingCall;
    }
    port def CallEventPort {
        out item answered : AnsweredCall;
    }
    port def AudioOutPort {
        out item prompt : AudioPrompt;
    }
    port def DtmfInPort {
        in item key : DtmfKey;
    }
    port def SelectionPort {
        out item selection : MenuSelection;
    }
    port def RoutingPort {
        out item decision : RoutingDecision;
    }
    port def TransferPort {
        out item request : TransferRequest;
    }
    port def LogPort {
        out item entry : LogEntry;
    }

    // ---------- Requirements ----------
    requirement def HighAvailability {
        attribute minUptime : AvailabilityPercent = 99.9;
        subject system : IVRSystem;
        objective {
            system.uptime >= minUptime
        }
    }
    requirement def ConcurrentCallCapacity {
        attribute minCalls : CallCount = 100;
        subject system : IVRSystem;
        objective {
            system.concurrentCalls >= minCalls
        }
    }
    requirement def AutoAttendantFunction {
        subject system : IVRSystem;
        objective {
            system.automaticallyDirectsCalls == true
        }
    }
    requirement def MaxAttemptsRequirement {
        attribute maxAttempts : Integer = 3;
        subject processor : InputProcessor;
        objective {
            processor.maxAttempts == maxAttempts
        }
    }
    requirement def CallLoggingRequirement {
        subject logger : CallLogger;
        objective {
            logger.logsAllInteractions == true
        }
    }

    // ---------- Functional parts ----------

    part def CallReceiver {
        port lineIn : TelephonyLinePort;
        port callOut : CallEventPort;
        attribute activeCalls : CallCount = 0;
        attribute maxCalls : CallCount = 100;

        action def DetectIncoming {
            out item call : IncomingCall;
        }
        action def AnswerCall {
            in item incoming : IncomingCall;
            out item answered : AnsweredCall;
        }

        perform action detect : DetectIncoming;
        perform action answer : AnswerCall;

        satisfy AutoAttendantFunction;

        state machine def ReceiverBehavior {
            state Idle;
            state Ringing;
            state Answering;
            state Active;
            transition from Idle to Ringing when lineIn.call->notEmpty();
            transition from Ringing to Answering;
            transition from Answering to Active {
                perform answer;
            }
            transition from Active to Idle when activeCalls == 0;
        }
    }

    part def PromptGenerator {
        port promptOut : AudioOutPort;
        attribute welcomeGreeting : AudioPrompt = AudioPrompt { id = "welcome"; text = "Welcome to the company."; duration = 3.0; };
        attribute menuPrompt : AudioPrompt = AudioPrompt { id = "menu"; text = "Press 1 for Sales, 2 for Support."; duration = 5.0; };
        attribute invalidPrompt : AudioPrompt = AudioPrompt { id = "invalid"; text = "Invalid selection, please try again."; duration = 2.0; };
        attribute transferPrompt : AudioPrompt = AudioPrompt { id = "transfer"; text = "Transferring your call."; duration = 2.0; };
        attribute operatorPrompt : AudioPrompt = AudioPrompt { id = "operator"; text = "Routing you to a human operator."; duration = 2.0; };

        action def PlayPrompt {
            in item promptId : PromptId;
            out item prompt : AudioPrompt;
        }

        perform action play : PlayPrompt;

        action def PlayWelcome :> PlayPrompt {
            in item promptId : PromptId = "welcome";
        }
        action def PlayMenu :> PlayPrompt {
            in item promptId : PromptId = "menu";
        }
        action def PlayInvalid :> PlayPrompt {
            in item promptId : PromptId = "invalid";
        }
        action def PlayTransfer :> PlayPrompt {
            in item promptId : PromptId = "transfer";
        }
    }

    part def InputProcessor {
        port dtmfIn : DtmfInPort;
        port selectionOut : SelectionPort;
        attribute maxAttempts : Integer = 3;
        attribute timeout : DurationSeconds = 5.0;
        attribute currentAttempt : Integer = 0;
        attribute validKeys : DtmfKey[0..*] = ("1", "2", "3", "0");

        action def ListenForInput {
            out item key : DtmfKey;
        }
        action def ValidateInput {
            in item key : DtmfKey;
            out item selection : MenuSelection;
            out item isValid : Boolean;
        }
        action def RouteToOperator {
            out item selection : MenuSelection;
        }

        perform action listen : ListenForInput;
        perform action validate : ValidateInput;

        satisfy MaxAttemptsRequirement;

        state machine def InputBehavior {
            entry;
            state AwaitingInput;
            state Validating;
            state InvalidInput;
            state ValidInput;
            state Exhausted;
            state OperatorRoute;

            transition from entry to AwaitingInput;
            transition from AwaitingInput to Validating when dtmfIn.key->notEmpty();
            transition from Validating to ValidInput when validate.isValid == true;
            transition from Validating to InvalidInput when validate.isValid == false;
            transition from InvalidInput to AwaitingInput when currentAttempt < maxAttempts {
                currentAttempt := currentAttempt + 1;
            }
            transition from InvalidInput to Exhausted when currentAttempt >= maxAttempts;
            transition from Exhausted to OperatorRoute;
            transition from ValidInput to done;
            transition from OperatorRoute to done;
        }
    }

    part def RoutingEngine {
        port selectionIn : SelectionPort;
        port transferOut : TransferPort;
        attribute extensionMap : DtmfKey[0..*] = ("1", "2", "3", "0");
        attribute salesExtension : ExtensionNumber = "1001";
        attribute supportExtension : ExtensionNumber = "1002";
        attribute billingExtension : ExtensionNumber = "1003";
        attribute operatorExtension : ExtensionNumber = "1000";

        action def ResolveDestination {
            in item selection : MenuSelection;
            out item decision : RoutingDecision;
        }
        action def ExecuteTransfer {
            in item decision : RoutingDecision;
            out item request : TransferRequest;
        }

        perform action resolve : ResolveDestination;
        perform action transfer : ExecuteTransfer;

        state machine def RoutingBehavior {
            state Idle;
            state Resolving;
            state Transferring;
            state Completed;
            transition from Idle to Resolving when selectionIn.selection->notEmpty();
            transition from Resolving to Transferring;
            transition from Transferring to Completed;
            transition from Completed to Idle;
        }
    }

    part def CallLogger {
        port logIn : LogPort;
        attribute entries : LogEntry[0..*];
        attribute logsAllInteractions : Boolean = true;

        action def RecordEntry {
            in item entry : LogEntry;
        }
        action def ComputeDuration {
            in item start : DateTime;
            in item end : DateTime;
            out item duration : DurationSeconds;
        }

        perform action record : RecordEntry;
        perform action compute : ComputeDuration;

        satisfy CallLoggingRequirement;
    }

    // ---------- Composite system ----------
    part def IVRSystem {
        attribute uptime : AvailabilityPercent = 99.95;
        attribute concurrentCalls : CallCount = 100;
        attribute automaticallyDirectsCalls : Boolean = true;

        port externalLine : TelephonyLinePort;
        port transferLine : TransferPort;
        port adminLog : LogPort;

        part callReceiver : CallReceiver {
            port lineIn : TelephonyLinePort;
            port callOut : CallEventPort;
        }
        part promptGenerator : PromptGenerator {
            port promptOut : AudioOutPort;
        }
        part inputProcessor : InputProcessor {
            port dtmfIn : DtmfInPort;
            port selectionOut : SelectionPort;
        }
        part routingEngine : RoutingEngine {
            port selectionIn : SelectionPort;
            port transferOut : TransferPort;
        }
        part callLogger : CallLogger {
            port logIn : LogPort;
        }

        satisfy HighAvailability;
        satisfy ConcurrentCallCapacity;
        satisfy AutoAttendantFunction;

        connection def CallFlow {
            from externalLine to callReceiver.lineIn;
        }
        connection def AnsweredFlow {
            from callReceiver.callOut to promptGenerator.promptOut;
        }
        connection def PromptToCaller {
            from promptGenerator.promptOut to externalLine;
        }
        connection def DtmfFlow {
            from externalLine to inputProcessor.dtmfIn;
        }
        connection def SelectionFlow {
            from inputProcessor.selectionOut to routingEngine.selectionIn;
        }
        connection def TransferFlow {
            from routingEngine.transferOut to transferLine;
        }
        connection def LogFlow {
            from routingEngine.transferOut to callLogger.logIn;
        }
        connection def AdminLogFlow {
            from callLogger.logIn to adminLog;
        }

        state machine def CallHandling {
            entry;
            state Answering;
            state Greeting;
            state MenuPresentation;
            state AwaitingInput;
            state Validating;
            state Routing;
            state Transferring;
            state Logging;
            state Done;

            transition from entry to Answering;
            transition from Answering to Greeting {
                perform callReceiver.answer;
            }
            transition from Greeting to MenuPresentation {
                perform promptGenerator.PlayWelcome;
            }
            transition from MenuPresentation to AwaitingInput {
                perform promptGenerator.PlayMenu;
            }
            transition from AwaitingInput to Validating when inputProcessor.dtmfIn.key->notEmpty();
            transition from Validating to Routing when inputProcessor.validate.isValid == true;
            transition from Validating to AwaitingInput when inputProcessor.validate.isValid == false and inputProcessor.currentAttempt < inputProcessor.maxAttempts {
                perform promptGenerator.PlayInvalid;
            }
            transition from Validating to Routing when inputProcessor.currentAttempt >= inputProcessor.maxAttempts {
                perform promptGenerator.PlayOperator;
            }
            transition from Routing to Transferring {
                perform routingEngine.resolve;
                perform promptGenerator.PlayTransfer;
            }
            transition from Transferring to Logging {
                perform routingEngine.transfer;
            }
            transition from Logging to Done {
                perform callLogger.record;
            }
            transition from Done to entry;
        }
    }
}
