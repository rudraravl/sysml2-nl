package GyroscopicSensingUnitModel {

  import ScalarValues::*;
  import SI::*;

  attribute def angularVelocity :> ISQ::angularVelocity {
    unit = "rad/s";
  }

  attribute def angularAcceleration :> ISQ::angularAcceleration {
    unit = "rad/s^2";
  }

  attribute def angle :> ISQ::planeAngle {
    unit = "rad";
  }

  attribute def temperature :> ISQ::thermodynamicTemperature {
    unit = "K";
  }

  attribute def voltage :> ISQ::electricPotential {
    unit = "V";
  }

  attribute def current :> ISQ::electricCurrent {
    unit = "A";
  }

  attribute def power :> ISQ::power {
    unit = "W";
  }

  attribute def frequency :> ISQ::frequency {
    unit = "Hz";
  }

  attribute def timeDuration :> ISQ::time {
    unit = "s";
  }

  attribute def dataRate :> ScalarValues::Real {
    unit = "sample/s";
  }

  attribute def bitCount :> ScalarValues::Integer {
    unit = "bit";
  }

  attribute def errorPercent :> ScalarValues::Real {
    unit = "%";
  }

  attribute def AxisKind :> ScalarValues::String;

  item def AngularRateSample {
    attribute xRate : angularVelocity;
    attribute yRate : angularVelocity;
    attribute zRate : angularVelocity;
    attribute temperatureReading : temperature;
    attribute sampleTime : timeDuration;
    attribute validity : Boolean;
  }

  item def OrientationEstimate {
    attribute roll : angle;
    attribute pitch : angle;
    attribute yaw : angle;
    attribute updateTime : timeDuration;
    attribute confidence : errorPercent;
  }

  item def RawGyroFrame {
    attribute rawX : Integer;
    attribute rawY : Integer;
    attribute rawZ : Integer;
    attribute rawTemperature : Integer;
    attribute frameCounter : Integer;
  }

  item def ConfigurationCommand {
    attribute outputRate : dataRate;
    attribute fullScaleRange : angularVelocity;
    attribute lowPassCutoff : frequency;
    attribute selfTestEnabled : Boolean;
  }

  item def DiagnosticReport {
    attribute sensorHealthy : Boolean;
    attribute communicationHealthy : Boolean;
    attribute temperatureHealthy : Boolean;
    attribute biasWithinLimit : Boolean;
    attribute message : String;
  }

  port def PowerInputPort {
    in item supplyVoltage : voltage;
    in item supplyCurrent : current;
  }

  port def GroundPort {
    inout item referencePotential : voltage;
  }

  port def DigitalCommandPort {
    in item command : ConfigurationCommand;
  }

  port def AngularRateOutputPort {
    out item angularRate : AngularRateSample;
  }

  port def OrientationOutputPort {
    out item orientation : OrientationEstimate;
  }

  port def DiagnosticOutputPort {
    out item diagnostic : DiagnosticReport;
  }

  port def RawSensorBusPort {
    out item rawFrame : RawGyroFrame;
    in item command : ConfigurationCommand;
  }

  port def ProcessedDataPort {
    in item angularRate : AngularRateSample;
    out item orientation : OrientationEstimate;
  }

  port def ThermalMonitorPort {
    out item measuredTemperature : temperature;
  }

  part def MEMSGyroscopicSensor {
    attribute measurableQuantity : String = "angular velocity";
    attribute numberOfAxes : Integer = 3;
    attribute xAxisName : AxisKind = "roll rate";
    attribute yAxisName : AxisKind = "pitch rate";
    attribute zAxisName : AxisKind = "yaw rate";
    attribute fullScaleRange : angularVelocity = 34.9066 [rad/s];
    attribute noiseDensity : angularVelocity = 0.0008727 [rad/s];
    attribute zeroRateBias : angularVelocity = 0.0087266 [rad/s];
    attribute biasStability : angularVelocity = 0.0003491 [rad/s];
    attribute bandwidth : frequency = 200 [Hz];
    attribute maximumOutputRate : dataRate = 1000 [sample/s];
    attribute operatingTemperatureMin : temperature = 233.15 [K];
    attribute operatingTemperatureMax : temperature = 358.15 [K];
    attribute supplyVoltageNominal : voltage = 3.3 [V];
    attribute activeCurrent : current = 0.006 [A];

    port power : PowerInputPort;
    port ground : GroundPort;
    port rawBus : RawSensorBusPort;
    port thermal : ThermalMonitorPort;

    perform action senseAngularVelocity {
      in item actualXRate : angularVelocity;
      in item actualYRate : angularVelocity;
      in item actualZRate : angularVelocity;
      out item rawFrame : RawGyroFrame;

      first start;
      then sampleVibratingProofMass;
      then convertCoriolisDeflectionToElectricalSignal;
      then digitizeThreeAxisRates;
      then publishRawFrame;
      then done;

      action sampleVibratingProofMass;
      action convertCoriolisDeflectionToElectricalSignal;
      action digitizeThreeAxisRates;
      action publishRawFrame;
    }

    state def SensorLifecycle {
      state Off;
      state PowerStabilizing;
      state SelfTest;
      state Measuring;
      state Fault;

      entry;
      then Off;

      transition Off_to_PowerStabilizing
        first Off
        accept powerApplied
        then PowerStabilizing;

      transition PowerStabilizing_to_SelfTest
        first PowerStabilizing
        accept supplyStable
        then SelfTest;

      transition SelfTest_to_Measuring
        first SelfTest
        accept selfTestPassed
        then Measuring;

      transition SelfTest_to_Fault
        first SelfTest
        accept selfTestFailed
        then Fault;

      transition Measuring_to_Fault
        first Measuring
        accept sensorSignalInvalid
        then Fault;

      transition Fault_to_SelfTest
        first Fault
        accept resetCommanded
        then SelfTest;
    }
  }

  part def SignalConditioningElectronics {
    attribute antiAliasCutoff : frequency = 250 [Hz];
    attribute adcResolution : bitCount = 16 [bit];
    attribute samplingRate : dataRate = 1000 [sample/s];
    attribute inputNoiseLimit : angularVelocity = 0.0017453 [rad/s];
    attribute gainErrorLimit : errorPercent = 0.5 [%];

    port rawInput : RawSensorBusPort;
    port conditionedOutput : AngularRateOutputPort;

    perform action conditionRawGyroSignal {
      in item rawFrame : RawGyroFrame;
      out item angularRate : AngularRateSample;

      first receiveRawFrame;
      then removeOffset;
      then applyScaleFactor;
      then applyDigitalLowPassFilter;
      then compensateTemperatureSensitivity;
      then validateSample;
      then emitAngularRateSample;
      then done;

      action receiveRawFrame;
      action removeOffset;
      action applyScaleFactor;
      action applyDigitalLowPassFilter;
      action compensateTemperatureSensitivity;
      action validateSample;
      action emitAngularRateSample;
    }
  }

  part def MicrocontrollerProcessor {
    attribute clockFrequency : frequency = 48000000 [Hz];
    attribute orientationUpdateRate : dataRate = 200 [sample/s];
    attribute maxComputationLatency : timeDuration = 0.002 [s];
    attribute calibrationSampleCount : Integer = 1024;
    attribute biasEstimateX : angularVelocity = 0 [rad/s];
    attribute biasEstimateY : angularVelocity = 0 [rad/s];
    attribute biasEstimateZ : angularVelocity = 0 [rad/s];

    port processedData : ProcessedDataPort;
    port commandInput : DigitalCommandPort;
    port diagnosticOutput : DiagnosticOutputPort;

    perform action estimateOrientationFromAngularRate {
      in item angularRate : AngularRateSample;
      out item orientation : OrientationEstimate;

      first readAngularRateSample;
      then subtractEstimatedBias;
      then integrateBodyRates;
      then normalizeOrientationState;
      then estimateConfidence;
      then publishOrientation;
      then done;

      action readAngularRateSample;
      action subtractEstimatedBias;
      action integrateBodyRates;
      action normalizeOrientationState;
      action estimateConfidence;
      action publishOrientation;
    }

    perform action calibrateZeroRateBias {
      out item diagnostic : DiagnosticReport;

      first holdUnitStationary;
      then collectCalibrationSamples;
      then computeMeanBiasForEachAxis;
      then storeBiasEstimate;
      then verifyBiasWithinLimit;
      then done;

      action holdUnitStationary;
      action collectCalibrationSamples;
      action computeMeanBiasForEachAxis;
      action storeBiasEstimate;
      action verifyBiasWithinLimit;
    }

    state def ProcessingLifecycle {
      state Boot;
      state ConfigureSensor;
      state Calibrate;
      state StreamRates;
      state EstimateOrientation;
      state DegradedMode;

      entry;
      then Boot;

      transition Boot_to_ConfigureSensor
        first Boot
        accept firmwareReady
        then ConfigureSensor;

      transition ConfigureSensor_to_Calibrate
        first ConfigureSensor
        accept sensorConfigured
        then Calibrate;

      transition Calibrate_to_StreamRates
        first Calibrate
        accept calibrationValid
        then StreamRates;

      transition StreamRates_to_EstimateOrientation
        first StreamRates
        accept orientationRequested
        then EstimateOrientation;

      transition EstimateOrientation_to_StreamRates
        first EstimateOrientation
        accept rateOnlyRequested
        then StreamRates;

      transition StreamRates_to_DegradedMode
        first StreamRates
        accept diagnosticWarning
        then DegradedMode;

      transition DegradedMode_to_Calibrate
        first DegradedMode
        accept recalibrationRequested
        then Calibrate;
    }
  }

  part def PowerRegulator {
    attribute inputVoltageMin : voltage = 4.5 [V];
    attribute inputVoltageMax : voltage = 5.5 [V];
    attribute regulatedVoltage : voltage = 3.3 [V];
    attribute maxOutputCurrent : current = 0.05 [A];
    attribute maxOutputPower : power = 0.165 [W];
    attribute rippleLimit : voltage = 0.01 [V];

    port inputPower : PowerInputPort;
    port sensorPower : PowerInputPort;
    port digitalPower : PowerInputPort;
    port ground : GroundPort;
  }

  part def CommunicationInterface {
    attribute protocol : String = "I2C";
    attribute busClock : frequency = 400000 [Hz];
    attribute address : Integer = 104;
    attribute maxFrameLatency : timeDuration = 0.005 [s];

    port commandInput : DigitalCommandPort;
    port rateOutput : AngularRateOutputPort;
    port orientationOutput : OrientationOutputPort;
    port diagnosticOutput : DiagnosticOutputPort;
  }

  part def GyroscopicSensingUnit {
    attribute measuredQuantity : String = "three-axis angular velocity";
    attribute rateMeasurementRange : angularVelocity = 34.9066 [rad/s];
    attribute rateAccuracy : angularVelocity = 0.0174533 [rad/s];
    attribute outputDataRate : dataRate = 200 [sample/s];
    attribute startupTime : timeDuration = 0.25 [s];
    attribute totalPowerLimit : power = 0.1 [W];
    attribute operatingTemperatureMin : temperature = 253.15 [K];
    attribute operatingTemperatureMax : temperature = 343.15 [K];

    port externalPower : PowerInputPort;
    port externalGround : GroundPort;
    port externalCommand : DigitalCommandPort;
    port angularRateOutput : AngularRateOutputPort;
    port orientationOutput : OrientationOutputPort;
    port diagnosticOutput : DiagnosticOutputPort;

    part regulator : PowerRegulator;
    part gyroSensor : MEMSGyroscopicSensor;
    part conditioner : SignalConditioningElectronics;
    part processor : MicrocontrollerProcessor;
    part interface : CommunicationInterface;

    connect externalPower to regulator.inputPower;
    connect externalGround to regulator.ground;
    connect regulator.sensorPower to gyroSensor.power;
    connect regulator.digitalPower to processor.commandInput;
    connect gyroSensor.ground to externalGround;
    connect gyroSensor.rawBus to conditioner.rawInput;
    connect conditioner.conditionedOutput to processor.processedData;
    connect processor.processedData to orientationOutput;
    connect externalCommand to interface.commandInput;
    connect interface.commandInput to processor.commandInput;
    connect conditioner.conditionedOutput to angularRateOutput;
    connect processor.diagnosticOutput to diagnosticOutput;
    connect processor.diagnosticOutput to interface.diagnosticOutput;
    connect angularRateOutput to interface.rateOutput;
    connect orientationOutput to interface.orientationOutput;

    perform action operateSensingUnit {
      first receivePower;
      then stabilizeRegulatedSupplies;
      then configureGyroscopicSensor;
      then executeSelfTest;
      then calibrateBias;
      then measureAngularVelocityContinuously;
      then provideRateAndOrientationOutputs;
      then done;

      action receivePower;
      action stabilizeRegulatedSupplies;
      action configureGyroscopicSensor;
      action executeSelfTest;
      action calibrateBias;
      action measureAngularVelocityContinuously;
      action provideRateAndOrientationOutputs;
    }

    state def UnitLifecycle {
      state Unpowered;
      state Initializing;
      state SelfChecking;
      state Calibrating;
      state MeasuringAngularRate;
      state ReportingFault;
      state Shutdown;

      entry;
      then Unpowered;

      transition Unpowered_to_Initializing
        first Unpowered
        accept validPowerPresent
        then Initializing;

      transition Initializing_to_SelfChecking
        first Initializing
        accept initializationComplete
        then SelfChecking;

      transition SelfChecking_to_Calibrating
        first SelfChecking
        accept selfCheckPassed
        then Calibrating;

      transition SelfChecking_to_ReportingFault
        first SelfChecking
        accept selfCheckFailed
        then ReportingFault;

      transition Calibrating_to_MeasuringAngularRate
        first Calibrating
        accept calibrationComplete
        then MeasuringAngularRate;

      transition MeasuringAngularRate_to_ReportingFault
        first MeasuringAngularRate
        accept measurementInvalid
        then ReportingFault;

      transition ReportingFault_to_Initializing
        first ReportingFault
        accept resetRequested
        then Initializing;

      transition MeasuringAngularRate_to_Shutdown
        first MeasuringAngularRate
        accept powerRemovalRequested
        then Shutdown;

      transition Shutdown_to_Unpowered
        first Shutdown
        accept suppliesDischarged
        then Unpowered;
    }
  }

  requirement def MeasureAngularVelocityRequirement {
    doc /* The sensing unit shall measure angular velocity about three orthogonal axes using a gyroscopic sensor. */
    subject unit : GyroscopicSensingUnit;
    require constraint {
      unit.measuredQuantity == "three-axis angular velocity"
    }
  }

  requirement def MeasurementRangeRequirement {
    doc /* The sensing unit shall measure angular velocity over at least +/-34.9066 rad/s about each axis. */
    subject unit : GyroscopicSensingUnit;
    require constraint {
      unit.rateMeasurementRange >= 34.9066 [rad/s]
    }
  }

  requirement def AccuracyRequirement {
    doc /* The sensing unit shall report angular velocity with an error not exceeding 0.0174533 rad/s after calibration. */
    subject unit : GyroscopicSensingUnit;
    require constraint {
      unit.rateAccuracy <= 0.0174533 [rad/s]
    }
  }

  requirement def OutputRateRequirement {
    doc /* The sensing unit shall output validated angular-rate samples at no less than 200 samples per second. */
    subject unit : GyroscopicSensingUnit;
    require constraint {
      unit.outputDataRate >= 200 [sample/s]
    }
  }

  requirement def StartupRequirement {
    doc /* The sensing unit shall transition from valid applied power to calibrated measurement in no more than 0.25 seconds. */
    subject unit : GyroscopicSensingUnit;
    require constraint {
      unit.startupTime <= 0.25 [s]
    }
  }

  requirement def PowerRequirement {
    doc /* The sensing unit shall consume no more than 0.1 W during continuous measurement. */
    subject unit : GyroscopicSensingUnit;
    require constraint {
      unit.totalPowerLimit <= 0.1 [W]
    }
  }

  requirement def ThermalOperationRequirement {
    doc /* The sensing unit shall operate over the required ambient temperature interval. */
    subject unit : GyroscopicSensingUnit;
    require constraint {
      unit.operatingTemperatureMin <= 253.15 [K] and unit.operatingTemperatureMax >= 343.15 [K]
    }
  }

  requirement def DiagnosticRequirement {
    doc /* The sensing unit shall report diagnostic status for sensor health, communication health, temperature health, and bias validity. */
    subject unit : GyroscopicSensingUnit;
  }

  satisfy MeasureAngularVelocityRequirement by GyroscopicSensingUnit;
  satisfy MeasurementRangeRequirement by GyroscopicSensingUnit;
  satisfy AccuracyRequirement by GyroscopicSensingUnit;
  satisfy OutputRateRequirement by GyroscopicSensingUnit;
  satisfy StartupRequirement by GyroscopicSensingUnit;
  satisfy PowerRequirement by GyroscopicSensingUnit;
  satisfy ThermalOperationRequirement by GyroscopicSensingUnit;
  satisfy DiagnosticRequirement by GyroscopicSensingUnit;
}