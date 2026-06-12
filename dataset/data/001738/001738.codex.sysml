package BernoulliFlowMeasurementSystem {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Pressure :> Real {
    unit = "Pa";
  }

  attribute def Density :> Real {
    unit = "kg/m^3";
  }

  attribute def Velocity :> Real {
    unit = "m/s";
  }

  attribute def VolumetricFlowRate :> Real {
    unit = "m^3/s";
  }

  attribute def Area :> Real {
    unit = "m^2";
  }

  attribute def Height :> Real {
    unit = "m";
  }

  attribute def Time :> Real {
    unit = "s";
  }

  attribute def DischargeCoefficient :> Real {
    unit = "1";
  }

  item def WorkingFluid {
    attribute density : Density;
    attribute staticPressure : Pressure;
    attribute velocity : Velocity;
    attribute elevation : Height;
  }

  item def PressureSignal {
    attribute pressure : Pressure;
    attribute timestamp : Time;
    attribute valid : Boolean;
  }

  item def FlowEstimate {
    attribute differentialPressure : Pressure;
    attribute velocityAtThroat : Velocity;
    attribute volumetricFlow : VolumetricFlowRate;
    attribute timestamp : Time;
    attribute valid : Boolean;
  }

  port def FluidPort {
    inout item fluid : WorkingFluid;
  }

  port def PressureTapPort {
    out item signal : PressureSignal;
  }

  port def SignalInputPort {
    in item signal : PressureSignal;
  }

  port def FlowOutputPort {
    out item estimate : FlowEstimate;
  }

  action def SamplePressure {
    in item fluid : WorkingFluid;
    out item signal : PressureSignal;

    constraint signalPressure {
      signal.pressure == fluid.staticPressure;
    }
  }

  action def ComputeBernoulliFlow {
    in item upstreamPressure : PressureSignal;
    in item throatPressure : PressureSignal;
    in attribute fluidDensity : Density;
    in attribute upstreamArea : Area;
    in attribute throatArea : Area;
    in attribute dischargeCoefficient : DischargeCoefficient;
    out item estimate : FlowEstimate;

    attribute beta : Real;
    attribute dp : Pressure;

    constraint betaDefinition {
      beta == throatArea / upstreamArea;
    }

    constraint pressureDifference {
      dp == upstreamPressure.pressure - throatPressure.pressure;
    }

    constraint bernoulliVelocity {
      estimate.velocityAtThroat ==
        dischargeCoefficient * sqrt((2.0 * dp) / (fluidDensity * (1.0 - beta^4.0)));
    }

    constraint continuityFlow {
      estimate.volumetricFlow == throatArea * estimate.velocityAtThroat;
    }

    constraint validity {
      estimate.valid == upstreamPressure.valid and throatPressure.valid and dp > 0.0;
    }

    constraint outputPressureDifference {
      estimate.differentialPressure == dp;
    }
  }

  state def FlowComputerState {
    entry;
    state initializing;
    state waitingForSamples;
    state computingFlow;
    state publishingEstimate;
    state faulted;

    transition first initializing;
    transition initializing_to_waiting
      first initializing
      then waitingForSamples;

    transition samples_available
      first waitingForSamples
      if upstreamSample.valid and throatSample.valid
      then computingFlow;

    transition invalid_samples
      first waitingForSamples
      if not upstreamSample.valid or not throatSample.valid
      then faulted;

    transition computation_complete
      first computingFlow
      then publishingEstimate;

    transition publish_complete
      first publishingEstimate
      then waitingForSamples;

    transition reset_fault
      first faulted
      accept Reset
      then initializing;
  }

  part def VenturiFlowMeter {
    attribute upstreamArea : Area = 0.0120;
    attribute throatArea : Area = 0.00450;
    attribute meterElevation : Height = 0.0;
    attribute dischargeCoefficient : DischargeCoefficient = 0.985;
    attribute supportedDensityMinimum : Density = 950.0;
    attribute supportedDensityMaximum : Density = 1050.0;

    port inlet : FluidPort;
    port outlet : FluidPort;
    port upstreamTap : PressureTapPort;
    port throatTap : PressureTapPort;

    part convergingNozzle {
      attribute inletArea : Area = upstreamArea;
      attribute outletArea : Area = throatArea;
    }

    part throatSection {
      attribute flowArea : Area = throatArea;
      attribute elevation : Height = meterElevation;
    }

    part diffuser {
      attribute inletArea : Area = throatArea;
      attribute outletArea : Area = upstreamArea;
    }

    action upstreamPressureSampling : SamplePressure;
    action throatPressureSampling : SamplePressure;

    bind upstreamPressureSampling.fluid = inlet.fluid;
    bind upstreamPressureSampling.signal = upstreamTap.signal;

    bind throatPressureSampling.fluid = outlet.fluid;
    bind throatPressureSampling.signal = throatTap.signal;

    connection fluidPath1 connect inlet to convergingNozzle;
    connection fluidPath2 connect convergingNozzle to throatSection;
    connection fluidPath3 connect throatSection to diffuser;
    connection fluidPath4 connect diffuser to outlet;
  }

  part def DifferentialPressureTransmitter {
    attribute minimumDifferentialPressure : Pressure = 25.0;
    attribute maximumDifferentialPressure : Pressure = 250000.0;
    attribute responseTime : Time = 0.050;

    port highPressureInput : SignalInputPort;
    port lowPressureInput : SignalInputPort;
    port highPressureOutput : PressureTapPort;
    port lowPressureOutput : PressureTapPort;

    action validateHighPressure {
      in item rawSignal : PressureSignal;
      out item conditionedSignal : PressureSignal;

      constraint passPressure {
        conditionedSignal.pressure == rawSignal.pressure;
      }

      constraint passTime {
        conditionedSignal.timestamp == rawSignal.timestamp;
      }

      constraint pressureValid {
        conditionedSignal.valid == rawSignal.valid and rawSignal.pressure > 0.0;
      }
    }

    action validateLowPressure {
      in item rawSignal : PressureSignal;
      out item conditionedSignal : PressureSignal;

      constraint passPressure {
        conditionedSignal.pressure == rawSignal.pressure;
      }

      constraint passTime {
        conditionedSignal.timestamp == rawSignal.timestamp;
      }

      constraint pressureValid {
        conditionedSignal.valid == rawSignal.valid and rawSignal.pressure > 0.0;
      }
    }

    bind validateHighPressure.rawSignal = highPressureInput.signal;
    bind validateHighPressure.conditionedSignal = highPressureOutput.signal;

    bind validateLowPressure.rawSignal = lowPressureInput.signal;
    bind validateLowPressure.conditionedSignal = lowPressureOutput.signal;
  }

  part def BernoulliFlowComputer {
    attribute configuredDensity : Density = 998.2;
    attribute configuredUpstreamArea : Area = 0.0120;
    attribute configuredThroatArea : Area = 0.00450;
    attribute configuredDischargeCoefficient : DischargeCoefficient = 0.985;
    attribute samplePeriod : Time = 0.100;

    port upstreamPressureIn : SignalInputPort;
    port throatPressureIn : SignalInputPort;
    port flowEstimateOut : FlowOutputPort;

    item upstreamSample : PressureSignal;
    item throatSample : PressureSignal;

    action computeFlow : ComputeBernoulliFlow;

    state machine operatingState : FlowComputerState;

    bind upstreamSample = upstreamPressureIn.signal;
    bind throatSample = throatPressureIn.signal;

    bind computeFlow.upstreamPressure = upstreamPressureIn.signal;
    bind computeFlow.throatPressure = throatPressureIn.signal;
    bind computeFlow.fluidDensity = configuredDensity;
    bind computeFlow.upstreamArea = configuredUpstreamArea;
    bind computeFlow.throatArea = configuredThroatArea;
    bind computeFlow.dischargeCoefficient = configuredDischargeCoefficient;
    bind computeFlow.estimate = flowEstimateOut.estimate;
  }

  part def FlowDisplayAndController {
    attribute lowFlowAlarmThreshold : VolumetricFlowRate = 0.0020;
    attribute highFlowAlarmThreshold : VolumetricFlowRate = 0.0800;

    port measuredFlowIn : FlowOutputPort;

    item currentEstimate : FlowEstimate;

    state def DisplayState {
      entry;
      state blank;
      state showingFlow;
      state alarmLowFlow;
      state alarmHighFlow;
      state invalidMeasurement;

      transition start blank then showingFlow;

      transition low_alarm
        first showingFlow
        if currentEstimate.valid and currentEstimate.volumetricFlow < lowFlowAlarmThreshold
        then alarmLowFlow;

      transition high_alarm
        first showingFlow
        if currentEstimate.valid and currentEstimate.volumetricFlow > highFlowAlarmThreshold
        then alarmHighFlow;

      transition invalid
        first showingFlow
        if not currentEstimate.valid
        then invalidMeasurement;

      transition normal_from_low
        first alarmLowFlow
        if currentEstimate.valid and currentEstimate.volumetricFlow >= lowFlowAlarmThreshold
        then showingFlow;

      transition normal_from_high
        first alarmHighFlow
        if currentEstimate.valid and currentEstimate.volumetricFlow <= highFlowAlarmThreshold
        then showingFlow;

      transition valid_again
        first invalidMeasurement
        if currentEstimate.valid
        then showingFlow;
    }

    state machine displayBehavior : DisplayState;

    bind currentEstimate = measuredFlowIn.estimate;
  }

  part def BernoulliBasedFlowMeasurementSystem {
    attribute primaryFunction : String =
      "Measure volumetric flow rate by applying Bernoulli's equation to pressure difference across a venturi restriction.";

    port processInlet : FluidPort;
    port processOutlet : FluidPort;
    port measuredFlowOutput : FlowOutputPort;

    part venturiMeter : VenturiFlowMeter;
    part dpTransmitter : DifferentialPressureTransmitter;
    part flowComputer : BernoulliFlowComputer;
    part displayController : FlowDisplayAndController;

    connection inletConnection connect processInlet to venturiMeter.inlet;
    connection outletConnection connect venturiMeter.outlet to processOutlet;

    connection upstreamPressureLine connect venturiMeter.upstreamTap to dpTransmitter.highPressureInput;
    connection throatPressureLine connect venturiMeter.throatTap to dpTransmitter.lowPressureInput;

    connection conditionedHighPressure connect dpTransmitter.highPressureOutput to flowComputer.upstreamPressureIn;
    connection conditionedLowPressure connect dpTransmitter.lowPressureOutput to flowComputer.throatPressureIn;

    connection computedFlowSignal connect flowComputer.flowEstimateOut to displayController.measuredFlowIn;
    connection externalFlowOutput connect flowComputer.flowEstimateOut to measuredFlowOutput;

    constraint bernoulliEnergyBalance {
      processInlet.fluid.staticPressure
      + (0.5 * processInlet.fluid.density * processInlet.fluid.velocity^2.0)
      + (processInlet.fluid.density * 9.80665 * processInlet.fluid.elevation)
      ==
      processOutlet.fluid.staticPressure
      + (0.5 * processOutlet.fluid.density * processOutlet.fluid.velocity^2.0)
      + (processOutlet.fluid.density * 9.80665 * processOutlet.fluid.elevation);
    }

    constraint continuity {
      venturiMeter.upstreamArea * processInlet.fluid.velocity
      ==
      venturiMeter.throatArea * processOutlet.fluid.velocity;
    }
  }

  requirement def PrimaryFunctionRequirement {
    id = "REQ-BERN-001";
    text = "The system shall determine volumetric flow rate of an incompressible fluid by measuring differential pressure across a venturi meter and applying Bernoulli's equation with continuity.";
  }

  requirement def BernoulliEquationRequirement {
    id = "REQ-BERN-002";
    text = "The flow computer shall compute throat velocity from differential pressure using v = Cd * sqrt((2 * deltaP) / (rho * (1 - beta^4))).";
  }

  requirement def ContinuityRequirement {
    id = "REQ-BERN-003";
    text = "The system shall compute volumetric flow rate as throat area multiplied by throat velocity.";
  }

  requirement def ValidityRequirement {
    id = "REQ-BERN-004";
    text = "The system shall mark the flow estimate invalid when either pressure measurement is invalid or when measured upstream pressure is not greater than throat pressure.";
  }

  requirement def AlarmRequirement {
    id = "REQ-BERN-005";
    text = "The display controller shall indicate low-flow and high-flow alarm states when the computed volumetric flow rate crosses configured alarm thresholds.";
  }

  satisfy PrimaryFunctionRequirement by BernoulliBasedFlowMeasurementSystem;
  satisfy BernoulliEquationRequirement by BernoulliFlowComputer::computeFlow;
  satisfy ContinuityRequirement by BernoulliFlowComputer::computeFlow;
  satisfy ValidityRequirement by BernoulliFlowComputer::computeFlow;
  satisfy AlarmRequirement by FlowDisplayAndController;

  part systemUnderDesign : BernoulliBasedFlowMeasurementSystem;

}