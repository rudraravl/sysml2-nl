package DodrillGMRSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def MagneticFluxDensity :> Real {
    unit = "tesla";
  }

  attribute def MicroTesla :> MagneticFluxDensity {
    unit = "uT";
  }

  attribute def ElectricPotential :> Real {
    unit = "V";
  }

  attribute def ElectricCurrent :> Real {
    unit = "A";
  }

  attribute def Resistance :> Real {
    unit = "ohm";
  }

  attribute def Temperature :> Real {
    unit = "degC";
  }

  attribute def Frequency :> Real {
    unit = "Hz";
  }

  attribute def DataRate :> Real {
    unit = "sample/s";
  }

  attribute def Percent :> Real {
    unit = "%";
  }

  attribute def TimeDuration :> Real {
    unit = "s";
  }

  item def MagneticField {
    attribute bx : MicroTesla;
    attribute by : MicroTesla;
    attribute bz : MicroTesla;
    attribute magnitude : MicroTesla;
  }

  item def BridgeVoltageSignal {
    attribute differentialVoltage : ElectricPotential;
    attribute commonModeVoltage : ElectricPotential;
    attribute noiseDensity : Real;
  }

  item def DigitalFieldSample {
    attribute bx : MicroTesla;
    attribute by : MicroTesla;
    attribute bz : MicroTesla;
    attribute temperature : Temperature;
    attribute timestamp : TimeDuration;
    attribute valid : Boolean;
  }

  item def HealthStatus {
    attribute bridgeOpenCircuit : Boolean;
    attribute bridgeShortCircuit : Boolean;
    attribute saturationDetected : Boolean;
    attribute calibrationValid : Boolean;
    attribute diagnosticCoverage : Percent;
  }

  port def MagneticFieldPort {
    in item field : MagneticField;
  }

  port def AnalogSignalPort {
    out item signal : BridgeVoltageSignal;
  }

  port def DigitalSamplePort {
    out item sample : DigitalFieldSample;
  }

  port def HealthPort {
    out item health : HealthStatus;
  }

  port def PowerPort {
    in attribute supplyVoltage : ElectricPotential;
    in attribute supplyCurrent : ElectricCurrent;
  }

  port def CommandPort {
    in attribute enable : Boolean;
    in attribute calibrate : Boolean;
    in attribute resetFault : Boolean;
  }

  port def TelemetryPort {
    out item sample : DigitalFieldSample;
    out item health : HealthStatus;
  }

  part def DodrillGMRBridge {
    attribute nominalResistance : Resistance = 500.0;
    attribute bridgeBiasVoltage : ElectricPotential = 5.0;
    attribute sensitivity : Real = 0.85;
    attribute linearRange : MicroTesla = 1000.0;
    attribute offsetVoltage : ElectricPotential;
    attribute operatingTemperature : Temperature;

    port magneticInput : MagneticFieldPort;
    port analogOutput : AnalogSignalPort;
    port power : PowerPort;

    action senseMagneticField {
      in item appliedField : MagneticField;
      out item bridgeSignal : BridgeVoltageSignal;
    }
  }

  part def SetResetCoil {
    attribute pulseCurrent : ElectricCurrent = 1.2;
    attribute pulseDuration : TimeDuration = 0.00001;
    attribute repetitionRate : Frequency = 10.0;

    port power : PowerPort;

    action alignMagneticDomains {
      out attribute completed : Boolean;
    }
  }

  part def InstrumentationAmplifier {
    attribute gain : Real = 80.0;
    attribute bandwidth : Frequency = 25000.0;
    attribute inputOffset : ElectricPotential;

    port analogInput : AnalogSignalPort;
    port analogOutput : AnalogSignalPort;
    port power : PowerPort;

    action amplify {
      in item rawSignal : BridgeVoltageSignal;
      out item conditionedSignal : BridgeVoltageSignal;
    }
  }

  part def LowPassFilter {
    attribute cutoffFrequency : Frequency = 500.0;
    attribute order : Integer = 4;

    port analogInput : AnalogSignalPort;
    port analogOutput : AnalogSignalPort;

    action rejectHighFrequencyNoise {
      in item amplifiedSignal : BridgeVoltageSignal;
      out item filteredSignal : BridgeVoltageSignal;
    }
  }

  part def AnalogToDigitalConverter {
    attribute resolutionBits : Integer = 16;
    attribute sampleRate : DataRate = 2000.0;
    attribute referenceVoltage : ElectricPotential = 3.3;

    port analogInput : AnalogSignalPort;
    port digitalOutput : DigitalSamplePort;
    port power : PowerPort;

    action digitize {
      in item filteredSignal : BridgeVoltageSignal;
      out item rawSample : DigitalFieldSample;
    }
  }

  part def TemperatureSensor {
    attribute accuracy : Temperature = 0.5;
    attribute updateRate : DataRate = 10.0;

    port power : PowerPort;

    action measureTemperature {
      out attribute temperature : Temperature;
    }
  }

  part def SignalProcessor {
    attribute offsetCompensationEnabled : Boolean = true;
    attribute temperatureCompensationEnabled : Boolean = true;
    attribute calibrationScaleX : Real = 1.0;
    attribute calibrationScaleY : Real = 1.0;
    attribute calibrationScaleZ : Real = 1.0;
    attribute saturationThreshold : MicroTesla = 950.0;

    port sampleInput : DigitalSamplePort;
    port healthOutput : HealthPort;
    port telemetryOutput : TelemetryPort;
    port commandInput : CommandPort;

    action compensateAndEstimateField {
      in item rawSample : DigitalFieldSample;
      in attribute measuredTemperature : Temperature;
      out item correctedSample : DigitalFieldSample;
    }

    action runDiagnostics {
      in item correctedSample : DigitalFieldSample;
      out item status : HealthStatus;
    }
  }

  part def PowerConditioner {
    attribute inputVoltage : ElectricPotential = 12.0;
    attribute analogRailVoltage : ElectricPotential = 5.0;
    attribute digitalRailVoltage : ElectricPotential = 3.3;
    attribute maximumCurrent : ElectricCurrent = 0.5;
    attribute ripple : ElectricPotential = 0.005;

    port inputPower : PowerPort;
    port analogPower : PowerPort;
    port digitalPower : PowerPort;

    action regulatePower {
      out attribute analogReady : Boolean;
      out attribute digitalReady : Boolean;
    }
  }

  part def DodrillGMRMagneticFieldSystem {
    doc /* Primary function: sense an external magnetic field using a Dodrill-GMR bridge, condition the bridge response, convert it to calibrated digital magnetic-field telemetry, and report diagnostic health at a system level. */

    attribute measurementRange : MicroTesla = 1000.0;
    attribute fieldResolution : MicroTesla = 0.05;
    attribute outputRate : DataRate = 100.0;
    attribute startupTime : TimeDuration = 0.25;

    port fieldEnvironment : MagneticFieldPort;
    port externalPower : PowerPort;
    port command : CommandPort;
    port telemetry : TelemetryPort;

    part powerConditioner : PowerConditioner;
    part gmrBridgeX : DodrillGMRBridge;
    part gmrBridgeY : DodrillGMRBridge;
    part gmrBridgeZ : DodrillGMRBridge;
    part setResetCoil : SetResetCoil;
    part amplifierX : InstrumentationAmplifier;
    part amplifierY : InstrumentationAmplifier;
    part amplifierZ : InstrumentationAmplifier;
    part filterX : LowPassFilter;
    part filterY : LowPassFilter;
    part filterZ : LowPassFilter;
    part adcX : AnalogToDigitalConverter;
    part adcY : AnalogToDigitalConverter;
    part adcZ : AnalogToDigitalConverter;
    part temperatureSensor : TemperatureSensor;
    part processor : SignalProcessor;

    connect externalPower to powerConditioner.inputPower;
    connect powerConditioner.analogPower to gmrBridgeX.power;
    connect powerConditioner.analogPower to gmrBridgeY.power;
    connect powerConditioner.analogPower to gmrBridgeZ.power;
    connect powerConditioner.analogPower to amplifierX.power;
    connect powerConditioner.analogPower to amplifierY.power;
    connect powerConditioner.analogPower to amplifierZ.power;
    connect powerConditioner.digitalPower to adcX.power;
    connect powerConditioner.digitalPower to adcY.power;
    connect powerConditioner.digitalPower to adcZ.power;
    connect powerConditioner.digitalPower to temperatureSensor.power;
    connect powerConditioner.analogPower to setResetCoil.power;

    connect fieldEnvironment to gmrBridgeX.magneticInput;
    connect fieldEnvironment to gmrBridgeY.magneticInput;
    connect fieldEnvironment to gmrBridgeZ.magneticInput;

    connect gmrBridgeX.analogOutput to amplifierX.analogInput;
    connect gmrBridgeY.analogOutput to amplifierY.analogInput;
    connect gmrBridgeZ.analogOutput to amplifierZ.analogInput;

    connect amplifierX.analogOutput to filterX.analogInput;
    connect amplifierY.analogOutput to filterY.analogInput;
    connect amplifierZ.analogOutput to filterZ.analogInput;

    connect filterX.analogOutput to adcX.analogInput;
    connect filterY.analogOutput to adcY.analogInput;
    connect filterZ.analogOutput to adcZ.analogInput;

    connect adcX.digitalOutput to processor.sampleInput;
    connect adcY.digitalOutput to processor.sampleInput;
    connect adcZ.digitalOutput to processor.sampleInput;

    connect command to processor.commandInput;
    connect processor.telemetryOutput to telemetry;

    action performPrimaryFunction {
      first startPower : powerConditioner.regulatePower;
      then initializeDomains : setResetCoil.alignMagneticDomains;
      then senseX : gmrBridgeX.senseMagneticField;
      then senseY : gmrBridgeY.senseMagneticField;
      then senseZ : gmrBridgeZ.senseMagneticField;
      then amplifyX : amplifierX.amplify;
      then amplifyY : amplifierY.amplify;
      then amplifyZ : amplifierZ.amplify;
      then filterSignalX : filterX.rejectHighFrequencyNoise;
      then filterSignalY : filterY.rejectHighFrequencyNoise;
      then filterSignalZ : filterZ.rejectHighFrequencyNoise;
      then convertX : adcX.digitize;
      then convertY : adcY.digitize;
      then convertZ : adcZ.digitize;
      then estimateField : processor.compensateAndEstimateField;
      then diagnose : processor.runDiagnostics;
    }

    state def OperationalStateMachine {
      state Off;
      state Powering;
      state Initializing;
      state Measuring;
      state Calibrating;
      state Faulted;

      transition first Off then Powering
        accept command.enable
        do powerConditioner.regulatePower;

      transition Powering then Initializing
        if powerConditioner.analogRailVoltage == 5.0 and powerConditioner.digitalRailVoltage == 3.3
        do setResetCoil.alignMagneticDomains;

      transition Initializing then Measuring
        if command.enable == true;

      transition Measuring then Calibrating
        accept command.calibrate
        do processor.compensateAndEstimateField;

      transition Calibrating then Measuring
        if processor.calibrationScaleX > 0.0 and processor.calibrationScaleY > 0.0 and processor.calibrationScaleZ > 0.0;

      transition Measuring then Faulted
        if processor.saturationThreshold < fieldEnvironment.field.magnitude;

      transition Faulted then Initializing
        accept command.resetFault
        do setResetCoil.alignMagneticDomains;

      transition Measuring then Off
        if command.enable == false;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject system : DodrillGMRMagneticFieldSystem;
    require constraint {
      system.outputRate >= 100.0 and
      system.fieldResolution <= 0.05 and
      system.measurementRange >= 1000.0
    }
  }

  requirement def MagneticSensingRequirement {
    subject bridge : DodrillGMRBridge;
    require constraint {
      bridge.bridgeBiasVoltage == 5.0 and
      bridge.linearRange >= 1000.0
    }
  }

  requirement def SignalConditioningRequirement {
    subject amplifier : InstrumentationAmplifier;
    subject filter : LowPassFilter;
    require constraint {
      amplifier.gain >= 40.0 and
      amplifier.bandwidth >= 10000.0 and
      filter.cutoffFrequency <= 500.0
    }
  }

  requirement def DigitizationRequirement {
    subject adc : AnalogToDigitalConverter;
    require constraint {
      adc.resolutionBits >= 16 and
      adc.sampleRate >= 1000.0
    }
  }

  requirement def HealthMonitoringRequirement {
    subject processor : SignalProcessor;
    require constraint {
      processor.saturationThreshold <= 950.0
    }
  }

  requirement def PowerQualityRequirement {
    subject power : PowerConditioner;
    require constraint {
      power.analogRailVoltage == 5.0 and
      power.digitalRailVoltage == 3.3 and
      power.ripple <= 0.005
    }
  }

  satisfy PrimaryFunctionRequirement by DodrillGMRMagneticFieldSystem;
  satisfy MagneticSensingRequirement by DodrillGMRBridge;
  satisfy SignalConditioningRequirement by InstrumentationAmplifier;
  satisfy SignalConditioningRequirement by LowPassFilter;
  satisfy DigitizationRequirement by AnalogToDigitalConverter;
  satisfy HealthMonitoringRequirement by SignalProcessor;
  satisfy PowerQualityRequirement by PowerConditioner;
}