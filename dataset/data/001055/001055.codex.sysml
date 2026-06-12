package FlowSensingUnitModel {

  item def Fluid {
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute density : Density;
  }

  item def FlowSample {
    attribute rawPulseCount : Integer;
    attribute samplePeriod : Time;
    attribute measuredFlowRate : VolumetricFlowRate;
    attribute confidence : Percent;
  }

  value type VolumetricFlowRate {
    unit L_per_min;
    quantity kind volumeFlowRate;
  }

  value type Volume {
    unit L;
    quantity kind volume;
  }

  value type Pressure {
    unit kPa;
    quantity kind pressure;
  }

  value type Temperature {
    unit degC;
    quantity kind thermodynamicTemperature;
  }

  value type Density {
    unit kg_per_m3;
    quantity kind density;
  }

  value type Time {
    unit s;
    quantity kind time;
  }

  value type Voltage {
    unit V;
    quantity kind electricPotential;
  }

  value type Current {
    unit mA;
    quantity kind electricCurrent;
  }

  value type Percent {
    unit percent;
    quantity kind dimensionless;
  }

  port def FluidPort {
    inout item fluid : Fluid;
  }

  port def ElectricalPowerPort {
    in attribute voltage : Voltage;
    in attribute current : Current;
  }

  port def DigitalSignalPort {
    out attribute pulseCount : Integer;
    out attribute pulseFrequency : Real;
  }

  port def MeasurementOutputPort {
    out item sample : FlowSample;
  }

  part def FlowSensor {
    port inlet : FluidPort;
    port outlet : FluidPort;
    port signalOut : DigitalSignalPort;
    port powerIn : ElectricalPowerPort;

    attribute calibrationFactor : Real = 7.5;
    attribute minimumFlow : VolumetricFlowRate = 0.3 [L_per_min];
    attribute maximumFlow : VolumetricFlowRate = 30.0 [L_per_min];
    attribute pressureDropAtMaxFlow : Pressure = 12.0 [kPa];
    attribute operatingVoltage : Voltage = 5.0 [V];

    action senseFlow {
      in item incomingFluid : Fluid;
      in attribute pulseWindow : Time;
      out item sample : FlowSample;

      first start;
      then countPulses;
      then computeFrequency;
      then convertToFlowRate;
      then validateRange;
      then done;

      action countPulses {
        out attribute pulses : Integer;
      }

      action computeFrequency {
        in attribute pulses : Integer;
        in attribute pulseWindow : Time;
        out attribute frequency : Real;
      }

      action convertToFlowRate {
        in attribute frequency : Real;
        out attribute flowRate : VolumetricFlowRate;
      }

      action validateRange {
        in attribute flowRate : VolumetricFlowRate;
        out attribute confidence : Percent;
      }
    }
  }

  part def SignalConditioner {
    port rawSignalIn : DigitalSignalPort;
    port conditionedSignalOut : DigitalSignalPort;
    port powerIn : ElectricalPowerPort;

    attribute debounceTime : Time = 0.002 [s];
    attribute minimumValidFrequency : Real = 2.0;
    attribute maximumValidFrequency : Real = 250.0;

    action conditionSignal {
      in attribute rawPulseCount : Integer;
      in attribute rawPulseFrequency : Real;
      out attribute validPulseCount : Integer;
      out attribute validPulseFrequency : Real;
    }
  }

  part def MeasurementController {
    port sensorSignalIn : DigitalSignalPort;
    port measurementOut : MeasurementOutputPort;
    port powerIn : ElectricalPowerPort;

    attribute samplePeriod : Time = 1.0 [s];
    attribute zeroFlowTimeout : Time = 5.0 [s];
    attribute lastMeasuredFlow : VolumetricFlowRate;
    attribute totalizedVolume : Volume;

    action acquireMeasurement {
      in attribute pulseCount : Integer;
      in attribute pulseFrequency : Real;
      out item sample : FlowSample;

      first beginSampleWindow;
      then readPulseCounter;
      then calculateFlowRate;
      then updateTotalizer;
      then publishSample;
      then complete;

      action beginSampleWindow;
      action readPulseCounter {
        out attribute count : Integer;
      }
      action calculateFlowRate {
        in attribute count : Integer;
        out attribute rate : VolumetricFlowRate;
      }
      action updateTotalizer {
        in attribute rate : VolumetricFlowRate;
        in attribute period : Time;
        out attribute accumulatedVolume : Volume;
      }
      action publishSample {
        in attribute rate : VolumetricFlowRate;
        out item sample : FlowSample;
      }
    }

    state def ControllerStates {
      entry action initialize;

      state Off;
      state Initializing;
      state Ready;
      state Measuring;
      state Faulted;

      transition powerApplied first Off then Initializing;
      transition initialized first Initializing then Ready;
      transition sampleTimerElapsed first Ready then Measuring;
      transition sampleComplete first Measuring then Ready;
      transition signalInvalid first Measuring then Faulted;
      transition resetCommanded first Faulted then Initializing;
      transition powerRemoved first Ready then Off;
      transition powerRemovedDuringMeasure first Measuring then Off;
    }
  }

  part def PowerRegulator {
    port supplyIn : ElectricalPowerPort;
    port sensorPowerOut : ElectricalPowerPort;
    port controllerPowerOut : ElectricalPowerPort;

    attribute inputVoltage : Voltage = 12.0 [V];
    attribute regulatedVoltage : Voltage = 5.0 [V];
    attribute maximumCurrent : Current = 250.0 [mA];

    action regulatePower {
      in attribute supplyVoltage : Voltage;
      out attribute regulatedVoltage : Voltage;
    }
  }

  part def FlowSensingUnit {
    port fluidIn : FluidPort;
    port fluidOut : FluidPort;
    port powerIn : ElectricalPowerPort;
    port measurementOut : MeasurementOutputPort;

    part sensor : FlowSensor;
    part conditioner : SignalConditioner;
    part controller : MeasurementController;
    part regulator : PowerRegulator;

    connect fluidIn to sensor.inlet;
    connect sensor.outlet to fluidOut;
    connect powerIn to regulator.supplyIn;
    connect regulator.sensorPowerOut to sensor.powerIn;
    connect regulator.sensorPowerOut to conditioner.powerIn;
    connect regulator.controllerPowerOut to controller.powerIn;
    connect sensor.signalOut to conditioner.rawSignalIn;
    connect conditioner.conditionedSignalOut to controller.sensorSignalIn;
    connect controller.measurementOut to measurementOut;

    attribute measuredQuantity : VolumetricFlowRate;
    attribute measurementRangeLow : VolumetricFlowRate = 0.3 [L_per_min];
    attribute measurementRangeHigh : VolumetricFlowRate = 30.0 [L_per_min];
    attribute requiredAccuracy : Percent = 2.0 [percent];
    attribute outputUpdatePeriod : Time = 1.0 [s];

    action measureFlow {
      in item processFluid : Fluid;
      out item measuredSample : FlowSample;

      first powerCheck;
      then routeFluidThroughSensor;
      then senseFlowUsingSensor;
      then conditionPulseSignal;
      then computeMeasurement;
      then outputMeasurement;
      then endMeasurement;

      action powerCheck;
      action routeFluidThroughSensor {
        in item processFluid : Fluid;
        out item sensedFluid : Fluid;
      }
      action senseFlowUsingSensor {
        in item sensedFluid : Fluid;
        out item rawSample : FlowSample;
      }
      action conditionPulseSignal;
      action computeMeasurement {
        out item measuredSample : FlowSample;
      }
      action outputMeasurement {
        in item measuredSample : FlowSample;
      }
    }

    state def UnitOperatingStates {
      state Unpowered;
      state Starting;
      state SelfTest;
      state Standby;
      state Measuring;
      state Degraded;
      state Failed;

      transition applyPower first Unpowered then Starting;
      transition startupComplete first Starting then SelfTest;
      transition selfTestPassed first SelfTest then Standby;
      transition flowDetected first Standby then Measuring;
      transition noFlowDetected first Measuring then Standby;
      transition lowConfidenceMeasurement first Measuring then Degraded;
      transition confidenceRestored first Degraded then Measuring;
      transition unrecoverableFault first SelfTest then Failed;
      transition sensorFault first Measuring then Failed;
      transition removePower first Standby then Unpowered;
      transition removePowerWhileMeasuring first Measuring then Unpowered;
    }
  }

  requirement def MeasureFlowRequirement {
    subject sensingUnit : FlowSensingUnit;

    attribute requiredRangeLow : VolumetricFlowRate = 0.3 [L_per_min];
    attribute requiredRangeHigh : VolumetricFlowRate = 30.0 [L_per_min];
    attribute maximumError : Percent = 2.0 [percent];
    attribute maximumUpdatePeriod : Time = 1.0 [s];

    require constraint {
      sensingUnit.measurementRangeLow <= requiredRangeLow and
      sensingUnit.measurementRangeHigh >= requiredRangeHigh and
      sensingUnit.requiredAccuracy <= maximumError and
      sensingUnit.outputUpdatePeriod <= maximumUpdatePeriod
    }
  }

  requirement def FlowSensorUsageRequirement {
    subject sensingUnit : FlowSensingUnit;

    require constraint {
      sensingUnit.sensor.maximumFlow >= sensingUnit.measurementRangeHigh and
      sensingUnit.sensor.minimumFlow <= sensingUnit.measurementRangeLow
    }
  }

  requirement def FluidContinuityRequirement {
    subject sensingUnit : FlowSensingUnit;

    require constraint {
      sensingUnit.fluidIn.fluid == sensingUnit.sensor.inlet.fluid and
      sensingUnit.sensor.outlet.fluid == sensingUnit.fluidOut.fluid
    }
  }

  requirement def PowerRequirement {
    subject sensingUnit : FlowSensingUnit;

    attribute nominalInputVoltage : Voltage = 12.0 [V];
    attribute regulatedSensorVoltage : Voltage = 5.0 [V];

    require constraint {
      sensingUnit.regulator.inputVoltage == nominalInputVoltage and
      sensingUnit.regulator.regulatedVoltage == regulatedSensorVoltage
    }
  }

  part flowSensingUnit : FlowSensingUnit;

  requirement measureFlowRequirement : MeasureFlowRequirement {
    subject = flowSensingUnit;
  }

  requirement flowSensorUsageRequirement : FlowSensorUsageRequirement {
    subject = flowSensingUnit;
  }

  requirement fluidContinuityRequirement : FluidContinuityRequirement {
    subject = flowSensingUnit;
  }

  requirement powerRequirement : PowerRequirement {
    subject = flowSensingUnit;
  }

}