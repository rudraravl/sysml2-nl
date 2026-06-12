package CrankshaftPositionSensingUnitModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def degree :> ISQ::planeAngleUnit {
    symbol = "deg";
  }

  attribute def revolutionPerMinute :> ISQ::angularVelocityUnit {
    symbol = "rpm";
  }

  attribute def volt :> ISQ::electricPotentialUnit {
    symbol = "V";
  }

  attribute def milliampere :> ISQ::electricCurrentUnit {
    symbol = "mA";
  }

  attribute def millimeter :> ISQ::lengthUnit {
    symbol = "mm";
  }

  attribute def microsecond :> SI::timeUnit {
    symbol = "us";
  }

  value def AngularPosition {
    :>> unit = degree;
    :>> quantityKind = ISQ::planeAngle;
  }

  value def AngularVelocity {
    :>> unit = revolutionPerMinute;
    :>> quantityKind = ISQ::angularVelocity;
  }

  value def AirGap {
    :>> unit = millimeter;
    :>> quantityKind = ISQ::length;
  }

  value def SupplyVoltage {
    :>> unit = volt;
    :>> quantityKind = ISQ::electricPotential;
  }

  value def SupplyCurrent {
    :>> unit = milliampere;
    :>> quantityKind = ISQ::electricCurrent;
  }

  value def Timestamp {
    :>> unit = microsecond;
    :>> quantityKind = SI::time;
  }

  item def CrankToothPassing {
    attribute toothIndex : Integer;
    attribute missingToothWindow : Boolean;
    attribute edgeTime : Timestamp;
    attribute magneticFluxLevel : Real;
  }

  item def SensorPulse {
    attribute toothIndex : Integer;
    attribute edgeTime : Timestamp;
    attribute amplitude : SupplyVoltage;
    attribute validEdge : Boolean;
  }

  item def CrankshaftMeasurement {
    attribute crankAngle : AngularPosition;
    attribute crankSpeed : AngularVelocity;
    attribute referenceSynchronized : Boolean;
    attribute timestamp : Timestamp;
    attribute signalQuality : Real;
  }

  item def DiagnosticStatus {
    attribute sensorOpenCircuit : Boolean;
    attribute sensorShortCircuit : Boolean;
    attribute missingToothDetected : Boolean;
    attribute airGapOutOfRange : Boolean;
    attribute synchronized : Boolean;
    attribute faultPresent : Boolean;
  }

  port def MechanicalRotationPort {
    in item toothPassing : CrankToothPassing;
  }

  port def ElectricalPowerPort {
    in attribute supplyVoltage : SupplyVoltage;
    in attribute supplyCurrentLimit : SupplyCurrent;
  }

  port def PulseSignalPort {
    out item pulse : SensorPulse;
  }

  port def MeasurementPort {
    out item measurement : CrankshaftMeasurement;
  }

  port def DiagnosticPort {
    out item diagnostic : DiagnosticStatus;
  }

  port def ConfigurationPort {
    in attribute toothCount : Integer;
    in attribute missingToothCount : Integer;
    in attribute nominalAirGap : AirGap;
    in attribute triggerWheelOffset : AngularPosition;
  }

  action def SenseMagneticTooth {
    in item toothPassing : CrankToothPassing;
    in attribute airGap : AirGap;
    out item pulse : SensorPulse;

    first start;
    then evaluateFlux;
    then generatePulse;
    then done;

    action evaluateFlux {
      in item toothPassing;
      in attribute airGap;
      out attribute fluxSufficient : Boolean;
    }

    action generatePulse {
      in item toothPassing;
      in attribute fluxSufficient : Boolean;
      out item pulse;
    }
  }

  action def DecodeCrankPosition {
    in item pulse : SensorPulse;
    in attribute toothCount : Integer;
    in attribute missingToothCount : Integer;
    in attribute triggerWheelOffset : AngularPosition;
    out item measurement : CrankshaftMeasurement;
    out item diagnostic : DiagnosticStatus;

    first start;
    then validateEdge;
    then detectReferenceGap;
    then computeAngle;
    then computeSpeed;
    then publishResult;
    then done;

    action validateEdge {
      in item pulse;
      out attribute valid : Boolean;
    }

    action detectReferenceGap {
      in item pulse;
      in attribute missingToothCount;
      out attribute synchronized : Boolean;
      out attribute missingToothDetected : Boolean;
    }

    action computeAngle {
      in item pulse;
      in attribute toothCount;
      in attribute triggerWheelOffset;
      in attribute synchronized : Boolean;
      out attribute crankAngle : AngularPosition;
    }

    action computeSpeed {
      in item pulse;
      out attribute crankSpeed : AngularVelocity;
    }

    action publishResult {
      in attribute crankAngle;
      in attribute crankSpeed;
      in attribute synchronized;
      out item measurement;
      out item diagnostic;
    }
  }

  state def SensingUnitStateMachine {
    entry; then Initializing;

    state Initializing;
    state AwaitingCrankMotion;
    state AcquiringReference;
    state SynchronizedMeasurement;
    state DegradedMeasurement;
    state FaultLatched;

    transition Initializing_to_Awaiting
      first Initializing
      accept after 20 [SI::ms]
      then AwaitingCrankMotion;

    transition Awaiting_to_Acquiring
      first AwaitingCrankMotion
      accept CrankToothPassing
      then AcquiringReference;

    transition Acquiring_to_Synchronized
      first AcquiringReference
      if missingToothDetected == true
      then SynchronizedMeasurement;

    transition Acquiring_to_Degraded
      first AcquiringReference
      if missingToothDetected == false
      then DegradedMeasurement;

    transition Synchronized_to_Degraded
      first SynchronizedMeasurement
      if signalQuality < 0.65
      then DegradedMeasurement;

    transition Degraded_to_Synchronized
      first DegradedMeasurement
      if missingToothDetected == true and signalQuality >= 0.85
      then SynchronizedMeasurement;

    transition Any_to_Fault
      first Initializing, AwaitingCrankMotion, AcquiringReference, SynchronizedMeasurement, DegradedMeasurement
      if sensorOpenCircuit == true or sensorShortCircuit == true
      then FaultLatched;
  }

  part def Crankshaft {
    attribute instantaneousAngle : AngularPosition;
    attribute instantaneousSpeed : AngularVelocity;

    port rotationOut : MechanicalRotationPort;
  }

  part def FerromagneticTriggerWheel {
    attribute toothCount : Integer = 60;
    attribute missingToothCount : Integer = 2;
    attribute toothPitch : AngularPosition = 6 [degree];
    attribute referenceGapWidth : AngularPosition = 18 [degree];
    attribute triggerWheelOffset : AngularPosition = 84 [degree];

    port crankRotationIn : MechanicalRotationPort;
    port toothEventOut : MechanicalRotationPort;
  }

  part def CrankshaftPositionSensor {
    attribute sensorTechnology : String = "variable reluctance magnetic crankshaft position sensor";
    attribute operatingAirGap : AirGap = 0.8 [millimeter];
    attribute minimumAirGap : AirGap = 0.3 [millimeter];
    attribute maximumAirGap : AirGap = 1.5 [millimeter];
    attribute minimumPulseAmplitude : SupplyVoltage = 0.25 [volt];
    attribute maximumPulseAmplitude : SupplyVoltage = 80 [volt];

    port toothInput : MechanicalRotationPort;
    port sensorPower : ElectricalPowerPort;
    port rawPulseOut : PulseSignalPort;

    perform action sense : SenseMagneticTooth {
      toothPassing = toothInput.toothPassing;
      airGap = operatingAirGap;
      pulse = rawPulseOut.pulse;
    }
  }

  part def SignalConditioner {
    attribute hysteresisThreshold : SupplyVoltage = 0.08 [volt];
    attribute debounceTime : Timestamp = 50 [microsecond];
    attribute supplyVoltageNominal : SupplyVoltage = 5 [volt];
    attribute supplyCurrentNominal : SupplyCurrent = 20 [milliampere];

    port powerIn : ElectricalPowerPort;
    port rawPulseIn : PulseSignalPort;
    port conditionedPulseOut : PulseSignalPort;
    port diagnosticOut : DiagnosticPort;
  }

  part def CrankPositionProcessor {
    attribute configuredToothCount : Integer = 60;
    attribute configuredMissingToothCount : Integer = 2;
    attribute configuredOffset : AngularPosition = 84 [degree];
    attribute lastEdgeTime : Timestamp;
    attribute currentAngle : AngularPosition;
    attribute currentSpeed : AngularVelocity;
    attribute synchronized : Boolean = false;

    port configurationIn : ConfigurationPort;
    port conditionedPulseIn : PulseSignalPort;
    port measurementOut : MeasurementPort;
    port diagnosticOut : DiagnosticPort;

    perform action decode : DecodeCrankPosition {
      pulse = conditionedPulseIn.pulse;
      toothCount = configuredToothCount;
      missingToothCount = configuredMissingToothCount;
      triggerWheelOffset = configuredOffset;
      measurement = measurementOut.measurement;
      diagnostic = diagnosticOut.diagnostic;
    }
  }

  part def EngineControlUnit {
    port crankMeasurementIn : MeasurementPort;
    port crankDiagnosticIn : DiagnosticPort;
  }

  part def CrankshaftPositionSensingUnit {
    attribute supplyVoltageNominal : SupplyVoltage = 5 [volt];
    attribute supplyCurrentMaximum : SupplyCurrent = 50 [milliampere];
    attribute measurementAngleResolution : AngularPosition = 1 [degree];
    attribute speedMeasurementRangeLow : AngularVelocity = 0 [revolutionPerMinute];
    attribute speedMeasurementRangeHigh : AngularVelocity = 8000 [revolutionPerMinute];

    port rotationInput : MechanicalRotationPort;
    port powerInput : ElectricalPowerPort;
    port configurationInput : ConfigurationPort;
    port measurementOutput : MeasurementPort;
    port diagnosticOutput : DiagnosticPort;

    part triggerWheel : FerromagneticTriggerWheel;
    part sensor : CrankshaftPositionSensor;
    part conditioner : SignalConditioner;
    part processor : CrankPositionProcessor;

    bind triggerWheel.toothCount = configurationInput.toothCount;
    bind triggerWheel.missingToothCount = configurationInput.missingToothCount;
    bind triggerWheel.triggerWheelOffset = configurationInput.triggerWheelOffset;
    bind sensor.operatingAirGap = configurationInput.nominalAirGap;
    bind processor.configuredToothCount = configurationInput.toothCount;
    bind processor.configuredMissingToothCount = configurationInput.missingToothCount;
    bind processor.configuredOffset = configurationInput.triggerWheelOffset;

    connect rotationInput to triggerWheel.crankRotationIn;
    connect triggerWheel.toothEventOut to sensor.toothInput;
    connect powerInput to sensor.sensorPower;
    connect powerInput to conditioner.powerIn;
    connect sensor.rawPulseOut to conditioner.rawPulseIn;
    connect conditioner.conditionedPulseOut to processor.conditionedPulseIn;
    connect processor.measurementOut to measurementOutput;
    connect processor.diagnosticOut to diagnosticOutput;

    exhibit state behavior : SensingUnitStateMachine;
  }

  part def EngineCrankshaftPositionSensingInstallation {
    part crankshaft : Crankshaft;
    part sensingUnit : CrankshaftPositionSensingUnit;
    part ecu : EngineControlUnit;

    connect crankshaft.rotationOut to sensingUnit.rotationInput;
    connect sensingUnit.measurementOutput to ecu.crankMeasurementIn;
    connect sensingUnit.diagnosticOutput to ecu.crankDiagnosticIn;
  }

  requirement def MeasureCrankshaftPositionRequirement {
    subject sensingUnit : CrankshaftPositionSensingUnit;

    require constraint {
      sensingUnit.measurementAngleResolution <= 1 [degree]
    }

    doc /* The sensing unit shall measure crankshaft angular position from the crankshaft position sensor signal with resolution of 1 degree crank angle or better after reference synchronization. */
  }

  requirement def MeasureCrankshaftSpeedRequirement {
    subject sensingUnit : CrankshaftPositionSensingUnit;

    require constraint {
      sensingUnit.speedMeasurementRangeLow <= 0 [revolutionPerMinute] and
      sensingUnit.speedMeasurementRangeHigh >= 8000 [revolutionPerMinute]
    }

    doc /* The sensing unit shall derive crankshaft rotational speed from successive crankshaft position sensor tooth edges over the operating range from stall through 8000 rpm. */
  }

  requirement def DetectReferenceGapRequirement {
    subject sensingUnit : CrankshaftPositionSensingUnit;

    require constraint {
      sensingUnit.processor.configuredMissingToothCount == 2 and
      sensingUnit.processor.configuredToothCount == 60
    }

    doc /* The sensing unit shall identify the missing-tooth reference gap of a 60-2 trigger wheel and use it to synchronize absolute crankshaft angular position. */
  }

  requirement def ElectricalInterfaceRequirement {
    subject sensingUnit : CrankshaftPositionSensingUnit;

    require constraint {
      sensingUnit.supplyVoltageNominal == 5 [volt] and
      sensingUnit.supplyCurrentMaximum <= 50 [milliampere]
    }

    doc /* The sensing unit shall operate from a nominal 5 V electrical supply and draw no more than 50 mA during normal measurement. */
  }

  requirement def AirGapRequirement {
    subject sensingUnit : CrankshaftPositionSensingUnit;

    require constraint {
      sensingUnit.sensor.minimumAirGap <= sensingUnit.sensor.operatingAirGap and
      sensingUnit.sensor.operatingAirGap <= sensingUnit.sensor.maximumAirGap
    }

    doc /* The crankshaft position sensor shall produce valid tooth-passing pulses when mounted with an air gap from 0.3 mm to 1.5 mm. */
  }

  requirement def DiagnosticRequirement {
    subject sensingUnit : CrankshaftPositionSensingUnit;

    require constraint {
      sensingUnit.diagnosticOutput.diagnostic.faultPresent ==
      (sensingUnit.diagnosticOutput.diagnostic.sensorOpenCircuit or
       sensingUnit.diagnosticOutput.diagnostic.sensorShortCircuit or
       sensingUnit.diagnosticOutput.diagnostic.airGapOutOfRange)
    }

    doc /* The sensing unit shall report diagnostic status for sensor open circuit, sensor short circuit, air-gap fault, reference synchronization, and missing-tooth detection. */
  }

  satisfy MeasureCrankshaftPositionRequirement by CrankshaftPositionSensingUnit;
  satisfy MeasureCrankshaftSpeedRequirement by CrankshaftPositionSensingUnit;
  satisfy DetectReferenceGapRequirement by CrankshaftPositionSensingUnit;
  satisfy ElectricalInterfaceRequirement by CrankshaftPositionSensingUnit;
  satisfy AirGapRequirement by CrankshaftPositionSensor;
  satisfy DiagnosticRequirement by CrankshaftPositionSensingUnit;
}