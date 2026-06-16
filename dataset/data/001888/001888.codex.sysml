package WaterHammerSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Pressure :> ISQ::pressure {
    unit = "Pa";
  }

  attribute def FlowRate {
    unit = "m^3/s";
  }

  attribute def Velocity {
    unit = "m/s";
  }

  attribute def PipeLength {
    unit = "m";
  }

  attribute def PipeDiameter {
    unit = "m";
  }

  attribute def TimeDuration {
    unit = "s";
  }

  attribute def ValveOpening {
    unit = "1";
  }

  attribute def Temperature {
    unit = "K";
  }

  attribute def Energy {
    unit = "J";
  }

  item def Water {
    attribute density : Real = 998.0;
    attribute bulkModulus : Pressure = 2.2e9;
    attribute temperature : Temperature;
  }

  item def HydraulicTransient {
    attribute peakPressure : Pressure;
    attribute minimumPressure : Pressure;
    attribute waveSpeed : Velocity;
    attribute arrivalTime : TimeDuration;
    attribute surgeEnergy : Energy;
  }

  item def PressureSignal {
    attribute measuredPressure : Pressure;
    attribute sampleTime : TimeDuration;
    attribute sensorStatus : SensorHealth;
  }

  item def ValveCommand {
    attribute targetOpening : ValveOpening;
    attribute closureTime : TimeDuration;
  }

  item def ReliefCommand {
    attribute openRelief : Boolean;
    attribute reliefSetPressure : Pressure;
  }

  enum def SensorHealth {
    enum ok;
    enum degraded;
    enum failed;
  }

  enum def OperatingMode {
    enum startup;
    enum steadyFlow;
    enum transientDetected;
    enum surgeRelief;
    enum shutdown;
    enum fault;
  }

  port def HydraulicPort {
    inout fluid : Water;
    inout pressure : Pressure;
    inout flow : FlowRate;
  }

  port def SignalOutPort {
    out signal : PressureSignal;
  }

  port def SignalInPort {
    in signal : PressureSignal;
  }

  port def ValveCommandPort {
    in command : ValveCommand;
  }

  port def ReliefCommandPort {
    in command : ReliefCommand;
  }

  part def Reservoir {
    attribute staticHeadPressure : Pressure = 450000.0;
    port outlet : HydraulicPort;
  }

  part def Pipeline {
    attribute length : PipeLength = 1200.0;
    attribute insideDiameter : PipeDiameter = 0.35;
    attribute waveSpeed : Velocity = 1030.0;
    attribute allowablePressure : Pressure = 1200000.0;
    attribute nominalFlow : FlowRate = 0.12;

    port upstream : HydraulicPort;
    port downstream : HydraulicPort;

    part wall {
      attribute elasticModulus : Pressure = 2.0e11;
      attribute thickness : PipeDiameter = 0.012;
    }
  }

  part def FastClosingValve {
    attribute opening : ValveOpening = 1.0;
    attribute minimumClosureTime : TimeDuration = 0.15;
    attribute commandedClosureTime : TimeDuration = 0.30;

    port inlet : HydraulicPort;
    port outlet : HydraulicPort;
    port control : ValveCommandPort;
  }

  part def PressureSensor {
    attribute rangeMaximum : Pressure = 2000000.0;
    attribute responseTime : TimeDuration = 0.002;
    attribute accuracy : Pressure = 2500.0;
    attribute health : SensorHealth = SensorHealth::ok;

    port tap : HydraulicPort;
    port output : SignalOutPort;
  }

  part def SurgeReliefValve {
    attribute setPressure : Pressure = 950000.0;
    attribute fullOpenPressure : Pressure = 1100000.0;
    attribute reliefCapacity : FlowRate = 0.20;
    attribute open : Boolean = false;

    port inlet : HydraulicPort;
    port discharge : HydraulicPort;
    port control : ReliefCommandPort;
  }

  part def ExpansionTank {
    attribute gasPrechargePressure : Pressure = 380000.0;
    attribute waterVolumeCapacity {
      unit = "m^3";
    } = 1.5;
    attribute dampingCoefficient : Real = 0.72;

    port connection : HydraulicPort;
  }

  part def Controller {
    attribute mode : OperatingMode = OperatingMode::startup;
    attribute highPressureThreshold : Pressure = 850000.0;
    attribute lowPressureThreshold : Pressure = 120000.0;
    attribute emergencyPressureThreshold : Pressure = 1050000.0;
    attribute maximumPressureRiseRate {
      unit = "Pa/s";
    } = 8.0e6;

    port pressureInput : SignalInPort;
    port valveOutput : ValveCommandPort;
    port reliefOutput : ReliefCommandPort;

    action def EvaluatePressureSignal {
      in currentSignal : PressureSignal;
      out transient : HydraulicTransient;
      out reliefCommand : ReliefCommand;
      out valveCommand : ValveCommand;
    }

    state def ControlStateMachine {
      entry; then Startup;

      state Startup;
      state SteadyFlow;
      state TransientDetected;
      state SurgeRelief;
      state Shutdown;
      state Fault;

      transition Startup_to_SteadyFlow
        first Startup
        then SteadyFlow
        accept after 5.0 [s];

      transition SteadyFlow_to_TransientDetected
        first SteadyFlow
        then TransientDetected
        accept pressureInput.signal
        if pressureInput.signal.measuredPressure > highPressureThreshold;

      transition TransientDetected_to_SurgeRelief
        first TransientDetected
        then SurgeRelief
        if pressureInput.signal.measuredPressure > emergencyPressureThreshold;

      transition TransientDetected_to_SteadyFlow
        first TransientDetected
        then SteadyFlow
        accept after 2.0 [s]
        if pressureInput.signal.measuredPressure <= highPressureThreshold;

      transition SurgeRelief_to_SteadyFlow
        first SurgeRelief
        then SteadyFlow
        accept after 4.0 [s]
        if pressureInput.signal.measuredPressure < highPressureThreshold;

      transition Any_to_Fault
        first SteadyFlow
        then Fault
        if pressureInput.signal.sensorStatus == SensorHealth::failed;

      transition SteadyFlow_to_Shutdown
        first SteadyFlow
        then Shutdown
        accept ValveCommand;
    }
  }

  part def DischargeSink {
    attribute ambientPressure : Pressure = 101325.0;
    port inlet : HydraulicPort;
  }

  part def WaterHammerProtectionSystem {
    attribute primaryFunction : String =
      "Detect rapid hydraulic pressure transients caused by sudden flow changes and protect the pipeline by commanding controlled valve motion, opening surge relief, and absorbing transient energy.";

    part supplyReservoir : Reservoir;
    part mainPipeline : Pipeline;
    part terminalValve : FastClosingValve;
    part pressureSensorUpstream : PressureSensor;
    part pressureSensorNearValve : PressureSensor;
    part reliefValve : SurgeReliefValve;
    part expansionTank : ExpansionTank;
    part controller : Controller;
    part dischargeSink : DischargeSink;

    port sourceInterface : HydraulicPort;
    port outletInterface : HydraulicPort;

    connection source_to_reservoir
      connect sourceInterface to supplyReservoir.outlet;

    connection reservoir_to_pipeline
      connect supplyReservoir.outlet to mainPipeline.upstream;

    connection pipeline_to_valve
      connect mainPipeline.downstream to terminalValve.inlet;

    connection valve_to_outlet
      connect terminalValve.outlet to outletInterface;

    connection upstream_sensor_tap
      connect pressureSensorUpstream.tap to mainPipeline.upstream;

    connection near_valve_sensor_tap
      connect pressureSensorNearValve.tap to mainPipeline.downstream;

    connection sensor_to_controller
      connect pressureSensorNearValve.output to controller.pressureInput;

    connection controller_to_valve
      connect controller.valveOutput to terminalValve.control;

    connection controller_to_relief
      connect controller.reliefOutput to reliefValve.control;

    connection relief_to_pipeline
      connect reliefValve.inlet to mainPipeline.downstream;

    connection relief_to_sink
      connect reliefValve.discharge to dischargeSink.inlet;

    connection tank_to_pipeline
      connect expansionTank.connection to mainPipeline.downstream;

    action def OperateSystem {
      first startFlow;
      then maintainSteadyFlow;
      then monitorPressure;
      then detectTransient;
      then mitigateSurge;
      then restoreSteadyFlow;

      action startFlow {
        out command : ValveCommand;
      }

      action maintainSteadyFlow {
        in flow : FlowRate;
        in pressure : Pressure;
      }

      action monitorPressure {
        out signal : PressureSignal;
      }

      action detectTransient {
        in signal : PressureSignal;
        out transient : HydraulicTransient;
      }

      action mitigateSurge {
        in transient : HydraulicTransient;
        out reliefCommand : ReliefCommand;
        out valveCommand : ValveCommand;
      }

      action restoreSteadyFlow {
        out command : ValveCommand;
      }
    }
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall perform the high-level primary function of protecting a water pipeline from water hammer by detecting rapid pressure transients and reducing damaging surge pressure before structural limits are exceeded. */
    subject protectedSystem : WaterHammerProtectionSystem;

    require constraint {
      protectedSystem.mainPipeline.allowablePressure >= 1200000.0
    }
  }

  requirement def SurgePressureLimitRequirement {
    doc /* During a fast valve closure event, peak pressure at the downstream end of the pipeline shall remain below the allowable pipe pressure. */
    subject protectedSystem : WaterHammerProtectionSystem;

    require constraint {
      protectedSystem.pressureSensorNearValve.tap.pressure <= protectedSystem.mainPipeline.allowablePressure
    }
  }

  requirement def DetectionResponseRequirement {
    doc /* The controller shall identify a water hammer transient and issue a relief command within 20 milliseconds after measured pressure exceeds the high-pressure threshold. */
    subject protectedSystem : WaterHammerProtectionSystem;

    require constraint {
      protectedSystem.controller.pressureInput.signal.sampleTime <= 0.020
    }
  }

  requirement def ReliefCapacityRequirement {
    doc /* The surge relief valve shall provide enough discharge capacity to reduce transient pressure while preserving forward flow stability. */
    subject protectedSystem : WaterHammerProtectionSystem;

    require constraint {
      protectedSystem.reliefValve.reliefCapacity >= 0.15
    }
  }

  requirement def ExpansionTankEnergyRequirement {
    doc /* The expansion tank shall absorb a portion of transient hydraulic energy so that repeated pressure reflections are damped. */
    subject protectedSystem : WaterHammerProtectionSystem;

    require constraint {
      protectedSystem.expansionTank.dampingCoefficient >= 0.60
    }
  }

  requirement def ControlledValveClosureRequirement {
    doc /* The terminal valve shall avoid closures faster than the minimum permitted closure time commanded by the controller. */
    subject protectedSystem : WaterHammerProtectionSystem;

    require constraint {
      protectedSystem.terminalValve.commandedClosureTime >= protectedSystem.terminalValve.minimumClosureTime
    }
  }

  satisfy PrimaryFunctionSatisfaction
    by WaterHammerProtectionSystem
    of PrimaryFunctionRequirement;

  satisfy SurgePressureLimitSatisfaction
    by WaterHammerProtectionSystem::reliefValve
    of SurgePressureLimitRequirement;

  satisfy DetectionResponseSatisfaction
    by WaterHammerProtectionSystem::controller
    of DetectionResponseRequirement;

  satisfy ReliefCapacitySatisfaction
    by WaterHammerProtectionSystem::reliefValve
    of ReliefCapacityRequirement;

  satisfy ExpansionTankSatisfaction
    by WaterHammerProtectionSystem::expansionTank
    of ExpansionTankEnergyRequirement;

  satisfy ValveClosureSatisfaction
    by WaterHammerProtectionSystem::terminalValve
    of ControlledValveClosureRequirement;

  analysis def WaterHammerTransientAnalysis {
    subject system : WaterHammerProtectionSystem;

    attribute initialFlowVelocity : Velocity = 1.25;
    attribute suddenVelocityChange : Velocity = 1.00;
    attribute predictedPressureRise : Pressure;
    attribute predictedPeakPressure : Pressure;

    action computeJoukowskyPressureRise {
      in density : Real;
      in waveSpeed : Velocity;
      in velocityChange : Velocity;
      out pressureRise : Pressure;
    }

    action compareWithAllowablePressure {
      in peakPressure : Pressure;
      in allowablePressure : Pressure;
      out acceptable : Boolean;
    }
  }

  verification def SurgePressureVerification {
    subject system : WaterHammerProtectionSystem;
    objective {
      verify SurgePressureLimitRequirement;
    }

    action injectFastClosureEvent {
      out command : ValveCommand;
    }

    action recordPeakPressure {
      in signal : PressureSignal;
      out peakPressure : Pressure;
    }

    action passFailEvaluation {
      in peakPressure : Pressure;
      in allowablePressure : Pressure;
      out passed : Boolean;
    }
  }

}