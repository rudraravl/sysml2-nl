package IVRSystem {
    private import ScalarValues::*;
    private import SI::*;
    
    doc /* Automated Attendant (IVR) System for a business telephone network. */
    
    attribute def UptimePercentage :> Real;
    attribute def CallCount :> Integer;
    attribute def ExtensionNumber :> String;
    attribute def PhoneNumber :> String;
    attribute def MenuOption :> Integer;
    attribute def DurationValue :> Real;
    
    attribute def IncomingCall {
        attribute callerId : PhoneNumber;
        attribute arrivalTime : String;
    }
    attribute def DTMFInput {
        attribute digit : MenuOption;
    }
    attribute def AudioPrompt {
        attribute messageName : String;
        attribute content : String;
    }
    attribute def RoutingDecision {
        attribute option : MenuOption;
        attribute extension : ExtensionNumber;
        attribute department : String;
    }
    attribute def CallLogEntry {
        attribute callerId : PhoneNumber;
        attribute selection : MenuOption;
        attribute destination : ExtensionNumber;
        attribute handlingTime : DurationValue;
        attribute success : Boolean;
    }
    
    port def TelephonyPort {
        in call : IncomingCall;
        out answered : Boolean;
    }
    port def AudioPort {
        out prompt : AudioPrompt;
    }
    port def DTMFPort {
        in tone : DTMFInput;
    }
    port def RoutingPort {
        in decision : RoutingDecision;
    }
    port def LoggingPort {
        in logEntry : CallLogEntry;
    }
    
    part def CallReceiver {
        doc /* Entry point for detecting and answering incoming phone calls. */
        port telephonyIn : TelephonyPort;
        attribute activeCalls : CallCount = 0;
        state ReceiverBehavior {
            entry then Idle;
            state Idle {
                accept c : IncomingCall via telephonyIn
                then Answering;
            }
            state Answering {
                then Idle;
            }
        }
    }
    
    part def PromptGenerator {
        doc /* Plays pre-recorded audio messages to the caller. */
        attribute welcomeMessage : String = "Welcome to our company.";
        attribute menuMessage : String = "Press 1 for Sales, 2 for Support, 3 for Billing, 0 for Operator.";
        attribute invalidMessage : String = "Invalid selection. Please try again.";
        attribute transferMessage : String = "Transferring your call, please hold.";
        state GeneratorBehavior {
            entry then Idle;
            state Idle;
        }
    }
    
    part def InputProcessor {
        doc /* Listens for DTMF tones with timeout and retry logic. */
        port dtmfIn : DTMFPort;
        attribute timeoutDuration : DurationValue = 10[s];
        attribute maxAttempts : Integer = 3;
        attribute currentAttempts : Integer = 0;
        state InputBehavior {
            entry then Listening;
            state Listening {
                accept t : DTMFInput via dtmfIn
                then decide;
                    if t.digit >= 0 and t.digit <= 3 then ValidInput;
                    else InvalidInput;
                accept after 10[s]
                then RoutingToOperator;
            }
            state ValidInput;
            state InvalidInput {
                then Listening;
            }
            state RoutingToOperator;
        }
    }
    
    part def RoutingEngine {
        doc /* Maps menu choices to internal phone extensions. */
        port routingIn : RoutingPort;
        attribute salesExtension : ExtensionNumber = "1001";
        attribute supportExtension : ExtensionNumber = "1002";
        attribute billingExtension : ExtensionNumber = "1003";
        attribute operatorExtension : ExtensionNumber = "1000";
        state EngineBehavior {
            entry then Idle;
            state Idle;
        }
    }
    
    part def CallLogger {
        doc /* Records details of every call interaction. */
        port logIn : LoggingPort;
        state LoggerBehavior {
            entry then Idle;
            state Idle {
                accept e : CallLogEntry via logIn
                then Idle;
            }
        }
    }
    
    part def IVRController {
        doc /* Main controller orchestrating call handling flow. */
        attribute uptime : UptimePercentage = 99.95;
        attribute maxConcurrentCalls : CallCount = 120;
        port externalLine : TelephonyPort;
        port audioOut : AudioPort;
        port dtmfIn : DTMFPort;
        port routingIn : RoutingPort;
        port logIn : LoggingPort;
        part callReceiver : CallReceiver;
        part promptGenerator : PromptGenerator;
        part inputProcessor : InputProcessor;
        part routingEngine : RoutingEngine;
        part callLogger : CallLogger;
        connect externalLine to callReceiver.telephonyIn;
        connect dtmfIn to inputProcessor.dtmfIn;
        connect routingIn to routingEngine.routingIn;
        connect logIn to callLogger.logIn;
        state IVROperational {
            entry then Idle;
            state Idle {
                accept c : IncomingCall via externalLine
                then Greeting;
            }
            state Greeting {
                entry send new AudioPrompt("welcome", promptGenerator.welcomeMessage) via audioOut;
                then MenuPresentation;
            }
            state MenuPresentation {
                entry send new AudioPrompt("menu", promptGenerator.menuMessage) via audioOut;
                then WaitingForInput;
            }
            state WaitingForInput {
                accept t : DTMFInput via dtmfIn
                then decide;
                    if t.digit >= 0 and t.digit <= 3 then Routing;
                    else InvalidInput;
                accept after 10[s]
                then RoutingToOperator;
            }
            state InvalidInput {
                entry send new AudioPrompt("invalid", promptGenerator.invalidMessage) via audioOut;
                then WaitingForInput;
            }
            state Routing {
                entry send new AudioPrompt("transfer", promptGenerator.transferMessage) via audioOut;
                then Logging;
            }
            state RoutingToOperator {
                entry send new AudioPrompt("transfer", promptGenerator.transferMessage) via audioOut;
                then Logging;
            }
            state Logging {
                entry send new CallLogEntry("", 0, "", 0[s], true) via logIn;
                then Idle;
            }
        }
    }
    
    requirement def HighAvailability {
        doc /* The system must maintain 99.9% uptime. */
        attribute minUptime : UptimePercentage = 99.9;
        subject ivr : IVRController;
        constraint { ivr.uptime >= minUptime }
    }
    
    requirement def ConcurrentCallCapacity {
        doc /* The system must handle at least 100 concurrent calls. */
        attribute minCalls : CallCount = 100;
        subject ivr : IVRController;
        constraint { ivr.maxConcurrentCalls >= minCalls }
    }
    
    requirement def InputAttemptLimit {
        doc /* The caller must be allowed up to 3 attempts. */
        attribute maxAttempts : Integer = 3;
        subject ip : InputProcessor;
        constraint { ip.maxAttempts <= maxAttempts }
    }
    
    part ivrSystem : IVRController {
        satisfy HighAvailability;
        satisfy ConcurrentCallCapacity;
        part :>> callReceiver {
            attribute :>> activeCalls = 0;
        }
        part :>> promptGenerator {
            attribute :>> welcomeMessage = "Thank you for calling Acme Corp.";
        }
        part :>> inputProcessor {
            attribute :>> timeoutDuration = 8[s];
            attribute :>> maxAttempts = 3;
        }
        part :>> routingEngine {
            attribute :>> salesExtension = "1001";
            attribute :>> supportExtension = "1002";
            attribute :>> billingExtension = "1003";
            attribute :>> operatorExtension = "1000";
        }
        part :>> callLogger;
    }
}
