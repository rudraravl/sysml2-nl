package OxygenSensingUnitModel {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  value def PercentO2 {
    :> Real;
    unit = "%";
  }

  value def Pascal {
    :> Real;
    unit = "Pa";
  }

  value def DegreeCelsius {
    :> Real;
    unit = "degC";
  }

  value def Volt {
    :> Real;
    unit = "V";
  }

  value def Milliampere {
    :> Real;
    unit = "mA";
  }

  value def Second {
    :> Real;
    unit = "s";
  }

  value def Confidence {
    :> Real;
    range = "0..1";
  }

  item def AmbientGasSample {
    attribute oxygenVolumeFraction : PercentO2;
    attribute oxygenPartialPressure : Pascal;
    attribute temperature : DegreeCelsius;
    attribute pressure : Pascal;
  }

  item def RawOxygenSensorSignal {
    attribute voltage : Volt;
    attribute sensorCurrent : Milliampere;
    attribute sampleTime : Second;
  }

  item def OxygenMeasurement {
    attribute oxygenVolumeFraction : PercentO2;
    attribute oxygenPartialPressure : Pascal;
    attribute temperatureCompensated : Boolean;
    attribute pressureCompensated : Boolean;
    attribute confidence : Confidence;
    attribute timestamp : Second;
  }

  item def DiagnosticStatus {
    attribute sensorPresent : Boolean;
    attribute warmupComplete : Boolean;
    attribute calibrationValid : Boolean;
    attribute faultActive : Boolean;
    attribute faultCode : Integer;
  }

  port def GasInletPort {
    in item gasSample : AmbientGasSample;
  }

  port def AnalogSignalPort {
    out item rawSignal : RawOxygenSensorSignal;
  }

  port def MeasurementOutputPort {
    out item measurement : OxygenMeasurement;
    out item status : DiagnosticStatus;
  }

  port def PowerInputPort {
    in attribute supplyVoltage : Volt;
    in attribute supplyCurrentLimit : Milliampere;
  }

  part def OxygenSensor {
    port gasInlet : GasInletPort;
    port analogOut : AnalogSignalPort;
    port power : PowerInputPort;

    attribute operatingTemperature : DegreeCelsius = 25;
    attribute nominalSensitivity : Volt = 0.010;
    attribute responseTimeT90 : Second = 8;
    attribute minimumOxygenFraction : PercentO2 = 0;
    attribute maximumOxygenFraction : PercentO2 = 25;
    attribute heaterEnabled : Boolean = false;

    perform action SenseOxygen {
      in item gas : AmbientGasSample;
      out item raw : RawOxygenSensorSignal;

      action convertChemicalPotentialToElectricalSignal;
      action filterSensorNoise;
      action emitAnalogSignal;

      flow gas to convertChemicalPotentialToElectricalSignal.gas;
      flow convertChemicalPotentialToElectricalSignal.rawSignal to filterSensorNoise.rawSignal;
      flow filterSensorNoise.filteredSignal to emitAnalogSignal.raw;
      flow emitAnalogSignal.raw to raw;
    }

    state sensorState {
      state Off;
      state Warmup;
      state Ready;
      state Degraded;
      state Failed;

      initial then Off;

      transition Off_to_Warmup
        first Off
        accept PowerApplied
        then Warmup;

      transition Warmup_to_Ready
        first Warmup
        accept WarmupTimerExpired
        if heaterEnabled == true
        then Ready;

      transition Ready_to_Degraded
        first Ready
        accept SignalOutOfTolerance
        then Degraded;

      transition Degraded_to_Ready
        first Degraded
        accept SignalRecovered
        then Ready;

      transition Ready_to_Failed
        first Ready
        accept SensorOpenCircuit
        then Failed;

      transition Degraded_to_Failed
        first Degraded
        accept SensorOpenCircuit
        then Failed;
    }
  }

  part def TemperatureSensor {
    attribute measuredTemperature : DegreeCelsius;
    port measurementOut : MeasurementOutputPort;
  }

  part def PressureSensor {
    attribute measuredPressure : Pascal;
    port measurementOut : MeasurementOutputPort;
  }

  part def SignalConditioner {
    port analogIn : AnalogSignalPort;
    port conditionedOut : AnalogSignalPort;

    attribute lowPassCutoffFrequency : Real = 2.0;
    attribute gain : Real = 100.0;
    attribute offsetVoltage : Volt = 0.0;

    perform action ConditionRawSignal {
      in item raw : RawOxygenSensorSignal;
      out item conditioned : RawOxygenSensorSignal;

      action amplify;
      action removeOffset;
      action lowPassFilter;

      flow raw to amplify.raw;
      flow amplify.amplified to removeOffset.signal;
      flow removeOffset.adjusted to lowPassFilter.signal;
      flow lowPassFilter.filtered to conditioned;
    }
  }

  part def MeasurementProcessor {
    port conditionedInput : AnalogSignalPort;
    port measurementOutput : MeasurementOutputPort;

    attribute calibrationSlope : Real = 1.000;
    attribute calibrationOffset : PercentO2 = 0.000;
    attribute lastValidMeasurement : PercentO2;
    attribute samplePeriod : Second = 1.0;

    perform action ComputeOxygenMeasurement {
      in item conditionedSignal : RawOxygenSensorSignal;
      in attribute ambientTemperature : DegreeCelsius;
      in attribute ambientPressure : Pascal;
      out item oxygenMeasurement : OxygenMeasurement;
      out item diagnosticStatus : DiagnosticStatus;

      action validateSignalRange;
      action applyCalibration;
      action compensateTemperature;
      action compensatePressure;
      action computeConfidence;
      action publishMeasurement;

      flow conditionedSignal to validateSignalRange.signal;
      flow validateSignalRange.validSignal to applyCalibration.signal;
      flow applyCalibration.calibratedFraction to compensateTemperature.oxygenFraction;
      flow ambientTemperature to compensateTemperature.temperature;
      flow compensateTemperature.temperatureCompensatedFraction to compensatePressure.oxygenFraction;
      flow ambientPressure to compensatePressure.pressure;
      flow compensatePressure.pressureCompensatedMeasurement to computeConfidence.measurement;
      flow computeConfidence.measurementWithConfidence to publishMeasurement.measurement;
      flow publishMeasurement.measurement to oxygenMeasurement;
      flow publishMeasurement.status to diagnosticStatus;
    }

    state processingState {
      state Initializing;
      state Sampling;
      state Measuring;
      state Calibrating;
      state Reporting;
      state Faulted;

      initial then Initializing;

      transition Initializing_to_Sampling
        first Initializing
        accept InitializationComplete
        then Sampling;

      transition Sampling_to_Measuring
        first Sampling
        accept SampleAcquired
        then Measuring;

      transition Measuring_to_Reporting
        first Measuring
        accept MeasurementComputed
        then Reporting;

      transition Reporting_to_Sampling
        first Reporting
        accept ReportPublished
        then Sampling;

      transition Sampling_to_Calibrating
        first Sampling
        accept CalibrationRequested
        then Calibrating;

      transition Calibrating_to_Sampling
        first Calibrating
        accept CalibrationAccepted
        then Sampling;

      transition Measuring_to_Faulted
        first Measuring
        accept InvalidSignalDetected
        then Faulted;

      transition Faulted_to_Sampling
        first Faulted
        accept FaultCleared
        then Sampling;
    }
  }

  part def OxygenSensingUnit {
    port gasInput : GasInletPort;
    port powerInput : PowerInputPort;
    port oxygenOutput : MeasurementOutputPort;

    part oxygenSensor : OxygenSensor;
    part temperatureSensor : TemperatureSensor;
    part pressureSensor : PressureSensor;
    part signalConditioner : SignalConditioner;
    part processor : MeasurementProcessor;

    attribute measurementRangeMin : PercentO2 = 0;
    attribute measurementRangeMax : PercentO2 = 25;
    attribute accuracyAtNominalConditions : PercentO2 = 0.5;
    attribute updatePeriod : Second = 1.0;
    attribute warmupTime : Second = 30.0;
    attribute faultLatched : Boolean = false;

    connect gasInput.gasSample to oxygenSensor.gasInlet.gasSample;
    connect powerInput.supplyVoltage to oxygenSensor.power.supplyVoltage;
    connect powerInput.supplyCurrentLimit to oxygenSensor.power.supplyCurrentLimit;
    connect oxygenSensor.analogOut.rawSignal to signalConditioner.analogIn.rawSignal;
    connect signalConditioner.conditionedOut.rawSignal to processor.conditionedInput.rawSignal;
    connect processor.measurementOutput.measurement to oxygenOutput.measurement;
    connect processor.measurementOutput.status to oxygenOutput.status;

    perform action MeasureAmbientOxygen {
      in item gas : AmbientGasSample;
      out item measurement : OxygenMeasurement;
      out item status : DiagnosticStatus;

      action admitGasSample;
      action senseOxygen;
      action conditionSignal;
      action calculateConcentration;
      action publishResult;

      flow gas to admitGasSample.gas;
      flow admitGasSample.gasAtSensor to senseOxygen.gas;
      flow senseOxygen.rawSignal to conditionSignal.rawSignal;
      flow conditionSignal.conditionedSignal to calculateConcentration.conditionedSignal;
      flow calculateConcentration.measurement to publishResult.measurement;
      flow calculateConcentration.status to publishResult.status;
      flow publishResult.measurement to measurement;
      flow publishResult.status to status;
    }

    state unitState {
      state Unpowered;
      state Starting;
      state Stabilizing;
      state Operational;
      state CalibrationMode;
      state Fault;

      initial then Unpowered;

      transition Unpowered_to_Starting
        first Unpowered
        accept ValidPowerApplied
        then Starting;

      transition Starting_to_Stabilizing
        first Starting
        accept ElectronicsInitialized
        then Stabilizing;

      transition Stabilizing_to_Operational
        first Stabilizing
        accept SensorWarmupComplete
        then Operational;

      transition Operational_to_CalibrationMode
        first Operational
        accept CalibrationCommandReceived
        then CalibrationMode;

      transition CalibrationMode_to_Operational
        first CalibrationMode
        accept CalibrationCompleted
        then Operational;

      transition Operational_to_Fault
        first Operational
        accept FaultDetected
        then Fault;

      transition Stabilizing_to_Fault
        first Stabilizing
        accept FaultDetected
        then Fault;

      transition Fault_to_Starting
        first Fault
        accept ResetCommandReceived
        then Starting;
    }
  }

  requirement def MeasureOxygenRequirement {
    subject sensingUnit : OxygenSensingUnit;

    require constraint {
      sensingUnit.measurementRangeMin <= 0 and
      sensingUnit.measurementRangeMax >= 20.9
    }

    doc /* The sensing unit shall measure oxygen concentration in an ambient gas sample using an oxygen sensor. */
  }

  requirement def AccuracyRequirement {
    subject sensingUnit : OxygenSensingUnit;

    require constraint {
      sensingUnit.accuracyAtNominalConditions <= 0.5
    }

    doc /* The sensing unit shall report oxygen volume fraction with accuracy of plus or minus 0.5 percent oxygen at nominal temperature and pressure. */
  }

  requirement def UpdateRateRequirement {
    subject sensingUnit : OxygenSensingUnit;

    require constraint {
      sensingUnit.updatePeriod <= 1.0
    }

    doc /* The sensing unit shall publish a compensated oxygen measurement at least once every second while operational. */
  }

  requirement def WarmupRequirement {
    subject sensingUnit : OxygenSensingUnit;

    require constraint {
      sensingUnit.warmupTime <= 30.0
    }

    doc /* The sensing unit shall become operational within 30 seconds after valid power is applied. */
  }

  requirement def DiagnosticRequirement {
    subject sensingUnit : OxygenSensingUnit;

    require constraint {
      sensingUnit.faultLatched == true implies sensingUnit.oxygenOutput.status.faultActive == true
    }

    doc /* The sensing unit shall report diagnostic status indicating sensor presence, calibration validity, warmup state, and active faults. */
  }

  satisfy MeasureOxygenRequirement by OxygenSensingUnit;
  satisfy AccuracyRequirement by OxygenSensingUnit;
  satisfy UpdateRateRequirement by OxygenSensingUnit;
  satisfy WarmupRequirement by OxygenSensingUnit;
  satisfy DiagnosticRequirement by OxygenSensingUnit;

}