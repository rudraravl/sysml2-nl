package UI_System {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Units ----
    unit ms;
    unit Hz;
    unit percent;
    unit pixel;

    // ---- Value Types ----
    value type TimeValue :> Real { unit ms; }
    value type FrequencyValue :> Real { unit Hz; }
    value type AccuracyValue :> Real { unit percent; }
    value type PixelValue :> Integer { unit pixel; }

    value type ResolutionValue {
        attribute width : PixelValue;
        attribute height : PixelValue;
    }

    // ---- Items ----
    item def UserCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute payload : String;
        attribute timestamp : TimeValue;
    }

    item def ValidatedCommand {
        attribute commandId : String;
        attribute commandType : String;
        attribute payload : String;
        attribute validatedAt : TimeValue;
        attribute valid : Boolean;
    }

    item def DisplayContent {
        attribute frameId : Integer;
        attribute resolution : ResolutionValue;
        attribute pixelData : String;
    }

    item def AudioFeedback {
        attribute toneId : Integer;
        attribute duration : TimeValue;
        attribute volume : Real;
    }

    item def ErrorEvent {
        attribute errorCode : Integer;
        attribute message : String;
        attribute source : String;
    }

    item def ControlState {
        attribute stateName : String;
    }

    // ---- Ports ----
    port def UserCommandPort { inout userCommand : UserCommand; }
    port def ValidatedCommandPort { inout validatedCommand : ValidatedCommand; }
    port def DisplayContentPort { inout displayContent : DisplayContent; }
    port def AudioFeedbackPort { inout audioFeedback : AudioFeedback; }
    port def ErrorPort { inout errorEvent : ErrorEvent; }
    port def ControlStatePort { inout controlState : ControlState; }

    // ---- Requirements ----
    requirement def InputAccuracyRequirement {
        attribute minAccuracy : AccuracyValue = 98;
        subject inputProcessor : InputProcessor;
        constraint { inputProcessor.accuracy >= minAccuracy }
    }

    requirement def InputLatencyRequirement {
        attribute maxProcessingTime : TimeValue = 50;
        subject inputProcessor : InputProcessor;
        constraint { inputProcessor.maxProcessingTime <= maxProcessingTime }
    }

    requirement def DisplayResolutionRequirement {
        attribute requiredWidth : PixelValue = 1920;
        attribute requiredHeight : PixelValue = 1080;
        subject displayManager : DisplayManager;
        constraint { displayManager.resolution.width == requiredWidth and displayManager.resolution.height == requiredHeight }
    }

    requirement def DisplayRefreshRequirement {
        attribute minRefreshRate : FrequencyValue = 60;
        subject displayManager : DisplayManager;
        constraint { displayManager.refreshRate >= minRefreshRate }
    }

    requirement def OverallResponseTimeRequirement {
        attribute maxResponseTime : TimeValue = 200;
        subject uiSystem : UISystem;
        constraint { uiSystem.maxResponseTime <= maxResponseTime }
    }

    // ---- Parts ----
    part def User {
        port commandOut : UserCommandPort;
        attribute userId : String;
        action generateCommand {
            out command : UserCommand;
        }
    }

    part def InputProcessor {
        port commandIn : UserCommandPort;
        port commandOut : ValidatedCommandPort;
        port errorOut : ErrorPort;
        attribute accuracy : AccuracyValue = 98.5;
        attribute maxProcessingTime : TimeValue = 50;
        attribute commandsProcessed : Integer = 0;

        action validate {
            in rawCommand : UserCommand;
            out validatedCommand : ValidatedCommand;
            out error : ErrorEvent;
        }

        action capture {
            in rawCommand : UserCommand;
            out captured : UserCommand;
        }
    }

    part def ApplicationCore {
        port commandIn : ValidatedCommandPort;
        port contentOut : DisplayContentPort;
        port audioOut : AudioFeedbackPort;
        port errorOut : ErrorPort;
        attribute sessionActive : Boolean = false;
        attribute sessionId : String;
        attribute commandsHandled : Integer = 0;

        action processCommand {
            in validated : ValidatedCommand;
            out content : DisplayContent;
            out audio : AudioFeedback;
        }

        action manageSession {
            in validated : ValidatedCommand;
            out sessionActive : Boolean;
        }
    }

    part def DisplayManager {
        port contentIn : DisplayContentPort;
        port contentOut : DisplayContentPort;
        attribute resolution : ResolutionValue = (width = 1920, height = 1080);
        attribute refreshRate : FrequencyValue = 60;
        attribute framesRendered : Integer = 0;

        action render {
            in content : DisplayContent;
            out rendered : DisplayContent;
        }

        action refresh {
            in content : DisplayContent;
            out displayed : DisplayContent;
        }
    }

    part def InterfaceController {
        port stateOut : ControlStatePort;
        port errorIn : ErrorPort;
        attribute maxResponseTime : TimeValue = 200;
        attribute currentState : String = "idle";

        state machine def InterfaceStateMachine {
            state idle;
            state active;
            state error;

            transition idle_to_active
                first idle
                when errorIn.errorEvent == null
                then active;

            transition active_to_idle
                first active
                when errorIn.errorEvent == null
                then idle;

            transition idle_to_error
                first idle
                when errorIn.errorEvent != null
                then error;

            transition active_to_error
                first active
                when errorIn.errorEvent != null
                then error;

            transition error_to_idle
                first error
                when errorIn.errorEvent == null
                then idle;
        }

        action monitorErrors {
            in error : ErrorEvent;
            out state : ControlState;
        }
    }

    part def Display {
        port contentIn : DisplayContentPort;
        attribute width : PixelValue = 1920;
        attribute height : PixelValue = 1080;
        attribute powered : Boolean = true;

        action show {
            in content : DisplayContent;
        }
    }

    part def Speaker {
        port audioIn : AudioFeedbackPort;
        attribute volume : Real = 0.5;
        attribute muted : Boolean = false;

        action play {
            in audio : AudioFeedback;
        }
    }

    // ---- System Assembly ----
    part def UISystem {
        attribute maxResponseTime : TimeValue = 200;
        attribute systemId : String;

        part user : User;
        part inputProcessor : InputProcessor;
        part applicationCore : ApplicationCore;
        part displayManager : DisplayManager;
        part interfaceController : InterfaceController;
        part display : Display;
        part speaker : Speaker;

        connection userToInput connect user.commandOut to inputProcessor.commandIn;
        connection inputToCore connect inputProcessor.commandOut to applicationCore.commandIn;
        connection coreToDisplayManager connect applicationCore.contentOut to displayManager.contentIn;
        connection displayManagerToDisplay connect displayManager.contentOut to display.contentIn;
        connection coreToSpeaker connect applicationCore.audioOut to speaker.audioIn;
        connection inputErrorToController connect inputProcessor.errorOut to interfaceController.errorIn;
        connection coreErrorToController connect applicationCore.errorOut to interfaceController.errorIn;
        connection controllerStateOut connect interfaceController.stateOut to applicationCore.commandIn;

        // Requirement satisfactions
        satisfy InputAccuracyRequirement by inputProcessor;
        satisfy InputLatencyRequirement by inputProcessor;
        satisfy DisplayResolutionRequirement by displayManager;
        satisfy DisplayRefreshRequirement by displayManager;
        satisfy OverallResponseTimeRequirement by UISystem;
    }
}
