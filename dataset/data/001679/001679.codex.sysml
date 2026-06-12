package ResponsiveArchitectureDesign {
  import ScalarValues::*;
  import SI::*;

  value def Millisecond :> Real {
    unit = "ms";
  }

  value def Percent :> Real {
    unit = "%";
  }

  value def Watt :> Real {
    unit = "W";
  }

  value def Celsius :> Real {
    unit = "degC";
  }

  value def RequestRate :> Real {
    unit = "requests/s";
  }

  value def Confidence :> Real {
    unit = "1";
  }

  item def UserRequest {
    attribute requestId : String;
    attribute priority : Integer;
    attribute submittedAt : Millisecond;
  }

  item def ContextObservation {
    attribute load : Percent;
    attribute latency : Millisecond;
    attribute temperature : Celsius;
    attribute demand : RequestRate;
    attribute confidence : Confidence;
  }

  item def AdaptationCommand {
    attribute targetCapacity : Percent;
    attribute targetMode : String;
    attribute issuedAt : Millisecond;
  }

  item def ServiceResponse {
    attribute requestId : String;
    attribute responseTime : Millisecond;
    attribute success : Boolean;
  }

  port def RequestPort {
    in item request : UserRequest;
  }

  port def ResponsePort {
    out item response : ServiceResponse;
  }

  port def ObservationPort {
    out item observation : ContextObservation;
  }

  port def ObservationInPort {
    in item observation : ContextObservation;
  }

  port def CommandPort {
    out item command : AdaptationCommand;
  }

  port def CommandInPort {
    in item command : AdaptationCommand;
  }

  part def SensorLayer {
    port observations : ObservationPort;

    attribute samplingPeriod : Millisecond = 100.0;
    attribute measurementConfidence : Confidence = 0.97;

    action collectContext {
      out item observation : ContextObservation;
    }
  }

  part def ResponsiveController {
    port contextIn : ObservationInPort;
    port commandOut : CommandPort;

    attribute maximumDecisionLatency : Millisecond = 50.0;
    attribute overloadThreshold : Percent = 80.0;
    attribute degradedThreshold : Percent = 95.0;

    action evaluateContext {
      in item observation : ContextObservation;
      out item command : AdaptationCommand;
    }

    state def ControlState {
      state monitoring;
      state scaling;
      state degraded;
      state recovery;

      initial then monitoring;

      transition monitoring_to_scaling
        first monitoring
        accept ContextObservation
        if observation.load >= 80.0
        then scaling;

      transition scaling_to_monitoring
        first scaling
        accept ContextObservation
        if observation.load < 70.0 and observation.latency < 200.0
        then monitoring;

      transition scaling_to_degraded
        first scaling
        accept ContextObservation
        if observation.load >= 95.0 or observation.latency >= 500.0
        then degraded;

      transition degraded_to_recovery
        first degraded
        accept ContextObservation
        if observation.load < 85.0 and observation.latency < 350.0
        then recovery;

      transition recovery_to_monitoring
        first recovery
        accept ContextObservation
        if observation.load < 70.0 and observation.latency < 200.0
        then monitoring;
    }

    exhibit state controlState : ControlState;
  }

  part def AdaptiveResourcePool {
    port commandIn : CommandInPort;
    port requestIn : RequestPort;
    port responseOut : ResponsePort;

    attribute activeCapacity : Percent = 60.0;
    attribute maximumPowerDraw : Watt = 1200.0;
    attribute nominalResponseTime : Millisecond = 120.0;

    action allocateCapacity {
      in item command : AdaptationCommand;
    }

    action serveRequest {
      in item request : UserRequest;
      out item response : ServiceResponse;
    }

    state def ResourceMode {
      state nominal;
      state expanded;
      state protected;

      initial then nominal;

      transition nominal_to_expanded
        first nominal
        accept AdaptationCommand
        if command.targetCapacity > 70.0
        then expanded;

      transition expanded_to_nominal
        first expanded
        accept AdaptationCommand
        if command.targetCapacity <= 70.0
        then nominal;

      transition expanded_to_protected
        first expanded
        accept AdaptationCommand
        if command.targetMode == "degraded"
        then protected;

      transition protected_to_expanded
        first protected
        accept AdaptationCommand
        if command.targetMode == "recovery"
        then expanded;
    }

    exhibit state resourceMode : ResourceMode;
  }

  part def FeedbackMonitor {
    port observationIn : ObservationInPort;

    attribute availability : Percent = 99.95;
    attribute targetLatency : Millisecond = 200.0;

    action assessPerformance {
      in item observation : ContextObservation;
    }
  }

  part def ResponsiveServiceSystem {
    port userRequest : RequestPort;
    port userResponse : ResponsePort;

    part sensors : SensorLayer;
    part controller : ResponsiveController;
    part resources : AdaptiveResourcePool;
    part feedback : FeedbackMonitor;

    attribute primaryFunction : String =
      "Maintain useful service delivery by sensing changing operating conditions, deciding appropriate adaptations, and reconfiguring resources before users experience unacceptable degradation.";

    connect sensors.observations to controller.contextIn;
    connect sensors.observations to feedback.observationIn;
    connect controller.commandOut to resources.commandIn;
    connect userRequest to resources.requestIn;
    connect resources.responseOut to userResponse;

    perform action operateResponsively {
      in item request : UserRequest;
      out item response : ServiceResponse;

      first collectContext;
      then evaluateContext;
      then allocateCapacity;
      then serveRequest;
      then assessPerformance;
    }
  }

  requirement def ResponsivenessRequirement {
    subject system : ResponsiveServiceSystem;

    require constraint {
      system.controller.maximumDecisionLatency <= 50.0
    }
  }

  requirement def LatencyRequirement {
    subject system : ResponsiveServiceSystem;

    require constraint {
      system.resources.nominalResponseTime <= 200.0
    }
  }

  requirement def AvailabilityRequirement {
    subject system : ResponsiveServiceSystem;

    require constraint {
      system.feedback.availability >= 99.9
    }
  }

  requirement def AdaptiveCapacityRequirement {
    subject system : ResponsiveServiceSystem;

    require constraint {
      system.resources.activeCapacity >= 30.0 and
      system.resources.activeCapacity <= 100.0
    }
  }

  requirement def PowerLimitRequirement {
    subject system : ResponsiveServiceSystem;

    require constraint {
      system.resources.maximumPowerDraw <= 1500.0
    }
  }

  part responsiveArchitecture : ResponsiveServiceSystem;

  requirement responsiveness : ResponsivenessRequirement {
    subject system = responsiveArchitecture;
  }

  requirement latency : LatencyRequirement {
    subject system = responsiveArchitecture;
  }

  requirement availability : AvailabilityRequirement {
    subject system = responsiveArchitecture;
  }

  requirement adaptiveCapacity : AdaptiveCapacityRequirement {
    subject system = responsiveArchitecture;
  }

  requirement powerLimit : PowerLimitRequirement {
    subject system = responsiveArchitecture;
  }
}