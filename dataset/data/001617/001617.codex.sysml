package UserInterfaceSystemModel {

  import ScalarValues::*;
  import SI::*;

  value def Percent {
    unit = "%";
    quantityKind = "ratio";
  }

  value def Pixel {
    unit = "px";
    quantityKind = "displayLength";
  }

  value def Millisecond {
    unit = "ms";
    quantityKind = "time";
  }

  value def Hertz {
    unit = "Hz";
    quantityKind = "frequency";
  }

  enum def InputModality {
    enum touch;
    enum pointer;
    enum keyboard;
    enum voice;
    enum assistiveSwitch;
  }

  enum def FeedbackPriority {
    enum informational;
    enum confirmation;
    enum warning;
    enum blockingError;
  }

  item def UserIntent {
    attribute intentId : String;
    attribute sourceModality : InputModality;
    attribute confidence : Percent;
    attribute capturedAt : Millisecond;
  }

  item def UserCommand {
    attribute commandName : String;
    attribute targetViewId : String;
    attribute requiresAuthentication : Boolean;
  }

  item def ViewModel {
    attribute viewId : String;
    attribute title : String;
    attribute isInteractive : Boolean;
    attribute contentVersion : Integer;
  }

  item def FeedbackMessage {
    attribute text : String;
    attribute priority : FeedbackPriority;
    attribute expiresAfter : Millisecond;
  }

  item def InteractionEvent {
    attribute eventName : String;
    attribute latency : Millisecond;
    attribute success : Boolean;
  }

  port def HumanInputPort {
    in item intent : UserIntent;
  }

  port def HumanOutputPort {
    out item view : ViewModel;
    out item feedback : FeedbackMessage;
  }

  port def ApplicationServicePort {
    out item command : UserCommand;
    in item viewUpdate : ViewModel;
    in item serviceFeedback : FeedbackMessage;
  }

  port def TelemetryPort {
    out item event : InteractionEvent;
  }

  part def DisplaySurface {
    attribute width : Pixel = 1920 [Pixel];
    attribute height : Pixel = 1080 [Pixel];
    attribute refreshRate : Hertz = 60 [Hertz];
    attribute brightness : Percent = 80 [%];

    port renderedOutput : HumanOutputPort;
  }

  part def InputController {
    attribute debounceTime : Millisecond = 50 [ms];
    attribute minimumConfidence : Percent = 70 [%];

    port capturedInput : HumanInputPort;
    port interpretedCommand : ApplicationServicePort;
  }

  part def InteractionManager {
    attribute maximumResponseTime : Millisecond = 250 [ms];
    attribute sessionActive : Boolean;

    port inputPort : HumanInputPort;
    port servicePort : ApplicationServicePort;
    port outputPort : HumanOutputPort;
    port telemetry : TelemetryPort;
  }

  part def AccessibilityAdapter {
    attribute highContrastEnabled : Boolean;
    attribute screenReaderEnabled : Boolean;
    attribute textScale : Percent = 100 [%];

    port accessibleInput : HumanInputPort;
    port accessibleOutput : HumanOutputPort;
  }

  part def UserInterfaceSystem {
    attribute primaryFunction : String =
      "Capture user intent, translate it into application commands, and present understandable feedback and system state to the user.";

    part display : DisplaySurface;
    part input : InputController;
    part interaction : InteractionManager;
    part accessibility : AccessibilityAdapter;

    port userInput : HumanInputPort;
    port userOutput : HumanOutputPort;
    port applicationApi : ApplicationServicePort;
    port telemetryOut : TelemetryPort;

    connect userInput to input.capturedInput;
    connect userInput to accessibility.accessibleInput;
    connect input.interpretedCommand to interaction.servicePort;
    connect interaction.outputPort to display.renderedOutput;
    connect display.renderedOutput to userOutput;
    connect accessibility.accessibleOutput to userOutput;
    connect interaction.servicePort to applicationApi;
    connect interaction.telemetry to telemetryOut;
  }

  action def CaptureIntent {
    in item rawIntent : UserIntent;
    out item validatedIntent : UserIntent;
  }

  action def TranslateIntentToCommand {
    in item validatedIntent : UserIntent;
    out item command : UserCommand;
  }

  action def RequestApplicationUpdate {
    in item command : UserCommand;
    out item updatedView : ViewModel;
  }

  action def PresentFeedback {
    in item updatedView : ViewModel;
    in item message : FeedbackMessage;
  }

  action def LogInteraction {
    in item event : InteractionEvent;
  }

  action def PrimaryInteractionFlow {
    in item userIntent : UserIntent;
    out item displayedView : ViewModel;

    action capture : CaptureIntent {
      in rawIntent = userIntent;
    }

    action translate : TranslateIntentToCommand {
      in validatedIntent = capture.validatedIntent;
    }

    action requestUpdate : RequestApplicationUpdate {
      in command = translate.command;
    }

    action present : PresentFeedback {
      in updatedView = requestUpdate.updatedView;
    }

    action log : LogInteraction;

    bind displayedView = requestUpdate.updatedView;
  }

  state def UserInterfaceOperationalStates {
    entry action initializeDisplay;
    entry action loadDefaultView;

    state idle;
    state receivingInput;
    state interpretingIntent;
    state waitingForApplication;
    state renderingFeedback;
    state errorRecovery;

    transition first idle;

    transition idle_to_receiving
      first idle
      then receivingInput
      accept UserIntent;

    transition receiving_to_interpreting
      first receivingInput
      then interpretingIntent;

    transition interpreting_to_waiting
      first interpretingIntent
      then waitingForApplication;

    transition waiting_to_rendering
      first waitingForApplication
      then renderingFeedback
      accept ViewModel;

    transition rendering_to_idle
      first renderingFeedback
      then idle;

    transition any_to_error
      first idle
      then errorRecovery
      accept FeedbackMessage;

    transition error_to_idle
      first errorRecovery
      then idle;
  }

  requirement def PrimaryFunctionRequirement {
    subject ui : UserInterfaceSystem;

    require constraint {
      ui.primaryFunction ==
      "Capture user intent, translate it into application commands, and present understandable feedback and system state to the user."
    }
  }

  requirement def ResponsivenessRequirement {
    subject ui : UserInterfaceSystem;

    require constraint {
      ui.interaction.maximumResponseTime <= 250 [ms]
    }
  }

  requirement def DisplayReadabilityRequirement {
    subject ui : UserInterfaceSystem;

    require constraint {
      ui.display.width >= 1280 [px] and
      ui.display.height >= 720 [px] and
      ui.display.refreshRate >= 60 [Hz]
    }
  }

  requirement def InputConfidenceRequirement {
    subject ui : UserInterfaceSystem;

    require constraint {
      ui.input.minimumConfidence >= 70 [%]
    }
  }

  requirement def AccessibilityRequirement {
    subject ui : UserInterfaceSystem;

    require constraint {
      ui.accessibility.textScale >= 100 [%]
    }
  }

  part userInterface : UserInterfaceSystem;

  satisfy PrimaryFunctionRequirement by userInterface;
  satisfy ResponsivenessRequirement by userInterface;
  satisfy DisplayReadabilityRequirement by userInterface;
  satisfy InputConfidenceRequirement by userInterface;
  satisfy AccessibilityRequirement by userInterface;
}