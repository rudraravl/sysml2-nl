package AngularRateSensingUnitSpecification {

  import ScalarValues::*;

  unit def rad;
  unit def s;
  unit def ms;
  unit def Hz;
  unit def V;
  unit def mA;
  unit def degC;
  unit def bit;
  unit def rad_per_s;
  unit def rad_per_s_per_s;
  unit def rad_per_s_per_sqrt_Hz;

  attribute def Time :> Real {
    attribute unit: String = "s";
  }

  attribute def Frequency :> Real {
    attribute unit: String = "Hz";
  }

  attribute def Voltage :> Real {
    attribute unit: String = "V";
  }

  attribute def Current :> Real {
    attribute unit: String = "mA";
  }

  attribute def Temperature :> Real {
    attribute unit: String = "degC";
  }

  attribute def AngularRate :> Real {
    attribute unit: String = "rad/s";
  }

  attribute def AngularAcceleration :> Real {
    attribute unit: String = "rad/s^2";
  }

  attribute def AngularRateNoiseDensity :> Real {
    attribute unit: String = "rad/s/sqrt(Hz)";
  }

  attribute def Resolution :> Real {
    attribute unit: String = "bit";
  }

  enum def AxisKind {
    enum x;
    enum y;
    enum z;
  }

  enum def SampleStatus {
    enum valid;
    enum invalid;
    enum saturatedHigh;
    enum saturatedLow;
    enum selfTestFailed;
    enum initializing;
  }

  enum def HealthLevel {
    enum nominal;
    enum degraded;
    enum failed;
  }

  enum def CommandKind {
    enum startMeasurement;
    enum stopMeasurement;
    enum calibrateBias;
    enum runSelfTest;
    enum resetFault;
    enum setSampleRate;
  }

  item def RotationalMotion {
    attribute axis: AxisKind;
    attribute angularRate: AngularRate;
    attribute angularAcceleration: AngularAcceleration;
    attribute timestamp: Time;
  }

  item def AnalogAngularRateVoltage {
    attribute voltage: Voltage;
    attribute sensitivity: Real;
    attribute offsetVoltage: Voltage;
    attribute timestamp: Time;
    attribute status: SampleStatus;
  }

  item def DigitalAngularRateCode {
    attribute code: Integer;
    attribute resolution: Resolution;
    attribute referenceVoltage: Voltage;
    attribute timestamp: Time;
    attribute status: SampleStatus;
  }

  item def AngularRateSample {
    attribute axis: AxisKind;
    attribute angularRate: AngularRate;
    attribute timestamp: Time;
    attribute samplePeriod: Time;
    attribute temperature: Temperature;
    attribute status: SampleStatus;
    attribute sequenceCounter: Integer;
  }

  item def ElectricalPower {
    attribute supplyVoltage: Voltage;
    attribute supplyCurrent: Current;
    attribute powerGood: Boolean;
  }

  item def SensingUnitCommand {
    attribute kind: CommandKind;
    attribute requestedSampleRate: Frequency;
    attribute commandId: Integer;
  }

  item def DiagnosticReport {
    attribute health: HealthLevel;
    attribute sensorSelfTestPassed: Boolean;
    attribute biasEstimate: AngularRate;
    attribute temperature: Temperature;
    attribute lastFaultCode: Integer;
    attribute timestamp: Time;
  }

  port def RotationalMotionInputPort {
    in item motion: RotationalMotion;
  }

  port def AnalogRateOutputPort {
    out item analogRate: AnalogAngularRateVoltage;
  }

  port def AnalogRateInputPort {
    in item analogRate: AnalogAngularRateVoltage;
  }

  port def DigitalCodeOutputPort {
    out item code: DigitalAngularRateCode;
  }

  port def DigitalCodeInputPort {
    in item code: DigitalAngularRateCode;
  }

  port def AngularRateSampleOutputPort {
    out item sample: AngularRateSample;
  }

  port def AngularRateSampleInputPort {
    in item sample: AngularRateSample;
  }

  port def PowerInputPort {
    in item power: ElectricalPower;
  }

  port def CommandInputPort {
    in item command: SensingUnitCommand;
  }

  port def DiagnosticOutputPort {
    out item report: DiagnosticReport;
  }

  port def ThermalSensePort {
    out item temperatureSample: Temperature;
  }

  constraint def AngularRateWithinMeasuringRange {
    in rate: AngularRate;
    in lowerLimit: AngularRate;
    in upperLimit: AngularRate;
    constraint validRange {
      rate >= lowerLimit and rate <= upperLimit
    }
  }

  constraint def SupplyVoltageWithinLimits {
    in voltage: Voltage;
    constraint validSupply {
      voltage >= 4.75 and voltage <= 5.25
    }
  }

  constraint def SamplePeriodMatchesRate {
    in period: Time;
    in rate: Frequency;
    constraint relationship {
      period * rate >= 0.999 and period * rate <= 1.001
    }
  }

  action def PerformSensorSelfTest {
    in item power: ElectricalPower;
    out item report: DiagnosticReport;

    attribute excitationRate: AngularRate = 0.174533;
    attribute maximumAllowedError: AngularRate = 0.008727;

    action applyInternalElectrostaticExcitation;
    action readSelfTestResponse;
    action compareResponseToLimit;

    then applyInternalElectrostaticExcitation;
    then readSelfTestResponse;
    then compareResponseToLimit;
  }

  action def SenseAngularMotion {
    in item motion: RotationalMotion;
    out item analogRate: AnalogAngularRateVoltage;

    attribute measurementAxis: AxisKind = AxisKind::z;
    attribute scaleFactor: Real = 0.0572958;
    attribute nominalOffsetVoltage: Voltage = 2.5;

    action rejectOffAxisMotion;
    action transduceCoriolisResponse;
    action generateProportionalVoltage;

    then rejectOffAxisMotion;
    then transduceCoriolisResponse;
    then generateProportionalVoltage;
  }

  action def ConditionAnalogSignal {
    in item rawAnalogRate: AnalogAngularRateVoltage;
    out item conditionedAnalogRate: AnalogAngularRateVoltage;

    attribute lowPassCutoff: Frequency = 100.0;
    attribute gain: Real = 1.0;

    action removeHighFrequencyNoise;
    action applyAntiAliasFilter;
    action clampOutOfRangeVoltage;

    then removeHighFrequencyNoise;
    then applyAntiAliasFilter;
    then clampOutOfRangeVoltage;
  }

  action def ConvertAnalogToDigital {
    in item analogRate: AnalogAngularRateVoltage;
    out item digitalCode: DigitalAngularRateCode;

    attribute conversionResolution: Resolution = 16.0;
    attribute referenceVoltage: Voltage = 5.0;
    attribute conversionTime: Time = 0.000020;

    action sampleAndHold;
    action quantizeVoltage;
    action appendTimestamp;

    then sampleAndHold;
    then quantizeVoltage;
    then appendTimestamp;
  }

  action def ComputeAngularRateSample {
    in item code: DigitalAngularRateCode;
    in item temperature: Temperature;
    out item sample: AngularRateSample;

    attribute calibratedBias: AngularRate = 0.0;
    attribute scaleFactor: AngularRate = 0.0002663;
    attribute samplePeriod: Time = 0.001;

    action subtractBias;
    action compensateTemperatureDrift;
    action detectSaturation;
    action publishAngularRate;

    then subtractBias;
    then compensateTemperatureDrift;
    then detectSaturation;
    then publishAngularRate;
  }

  action def CalibrateZeroRateBias {
    in item stationaryMotion: RotationalMotion;
    out item report: DiagnosticReport;

    attribute calibrationDuration: Time = 5.0;
    attribute maximumPermittedMotion: AngularRate = 0.001745;

    action verifyStationaryCondition;
    action averageZeroRateSamples;
    action storeBiasEstimate;
    action emitCalibrationReport;

    then verifyStationaryCondition;
    then averageZeroRateSamples;
    then storeBiasEstimate;
    then emitCalibrationReport;
  }

  action def MeasureAngularRate {
    in item motion: RotationalMotion;
    in item power: ElectricalPower;
    out item sample: AngularRateSample;
    out item report: DiagnosticReport;

    action selfTest: PerformSensorSelfTest;
    action sensing: SenseAngularMotion;
    action filtering: ConditionAnalogSignal;
    action conversion: ConvertAnalogToDigital;
    action computation: ComputeAngularRateSample;

    flow power to selfTest.power;
    flow selfTest.report to report;
    flow motion to sensing.motion;
    flow sensing.analogRate to filtering.rawAnalogRate;
    flow filtering.conditionedAnalogRate to conversion.analogRate;
    flow conversion.digitalCode to computation.code;
    flow computation.sample to sample;

    then selfTest;
    then sensing;
    then filtering;
    then conversion;
    then computation;
  }

  state def SensingUnitOperationalStates {
    entry action initializeDiagnosticDefaults;

    state off;
    state initializing;
    state selfTesting;
    state calibrating;
    state measuring;
    state degraded;
    state fault;

    transition initial then off;

    transition powerApplied
      first off
      then initializing;

    transition initializationComplete
      first initializing
      then selfTesting;

    transition selfTestPassed
      first selfTesting
      then measuring;

    transition calibrationRequested
      first measuring
      then calibrating;

    transition calibrationComplete
      first calibrating
      then measuring;

    transition selfTestFailed
      first selfTesting
      then fault;

    transition excessiveBiasDetected
      first measuring
      then degraded;

    transition recoveredWithinLimits
      first degraded
      then measuring;

    transition unrecoverableFailure
      first degraded
      then fault;

    transition resetAccepted
      first fault
      then initializing;

    transition powerRemoved
      first initializing
      then off;

    transition powerRemovedFromMeasuring
      first measuring
      then off;

    transition powerRemovedFromFault
      first fault
      then off;
  }

  part def AngularRateSensor {
    port motionIn: RotationalMotionInputPort;
    port powerIn: PowerInputPort;
    port analogOut: AnalogRateOutputPort;
    port commandIn: CommandInputPort;
    port diagnosticOut: DiagnosticOutputPort;

    attribute measurementAxis: AxisKind = AxisKind::z;
    attribute lowerMeasurementLimit: AngularRate = -8.726646;
    attribute upperMeasurementLimit: AngularRate = 8.726646;
    attribute nominalSensitivity: Real = 0.0572958;
    attribute zeroRateOutputVoltage: Voltage = 2.5;
    attribute bandwidth: Frequency = 100.0;
    attribute biasInstability: AngularRate = 0.000873;
    attribute noiseDensity: AngularRateNoiseDensity = 0.0001745;
    attribute operatingTemperatureMin: Temperature = -40.0;
    attribute operatingTemperatureMax: Temperature = 85.0;
    attribute requiredSupplyVoltage: Voltage = 5.0;
    attribute nominalSupplyCurrent: Current = 18.0;

    perform action selfTest: PerformSensorSelfTest;
    perform action sense: SenseAngularMotion;

    assert constraint supplyVoltageLimit: SupplyVoltageWithinLimits {
      in voltage = powerIn.power.supplyVoltage;
    }

    assert constraint rangeLimit: AngularRateWithinMeasuringRange {
      in rate = motionIn.motion.angularRate;
      in lowerLimit = lowerMeasurementLimit;
      in upperLimit = upperMeasurementLimit;
    }
  }

  part def AntiAliasFilter {
    port analogIn: AnalogRateInputPort;
    port analogOut: AnalogRateOutputPort;
    port powerIn: PowerInputPort;

    attribute filterOrder: Integer = 2;
    attribute cutoffFrequency: Frequency = 100.0;
    attribute passbandRipple: Real = 0.5;
    attribute attenuationAtNyquist: Real = 40.0;
    attribute groupDelay: Time = 0.0015;

    perform action conditioning: ConditionAnalogSignal;
  }

  part def AnalogToDigitalConverter {
    port analogIn: AnalogRateInputPort;
    port digitalOut: DigitalCodeOutputPort;
    port powerIn: PowerInputPort;

    attribute resolution: Resolution = 16.0;
    attribute referenceVoltage: Voltage = 5.0;
    attribute samplingFrequency: Frequency = 1000.0;
    attribute samplePeriod: Time = 0.001;
    attribute conversionLatency: Time = 0.000020;

    perform action conversion: ConvertAnalogToDigital;

    assert constraint samplingRelation: SamplePeriodMatchesRate {
      in period = samplePeriod;
      in rate = samplingFrequency;
    }
  }

  part def TemperatureSensor {
    port powerIn: PowerInputPort;
    port temperatureOut: ThermalSensePort;

    attribute measurementRangeMin: Temperature = -40.0;
    attribute measurementRangeMax: Temperature = 125.0;
    attribute accuracy: Temperature = 1.0;
    attribute updateRate: Frequency = 10.0;
  }

  part def BiasAndScaleCompensator {
    port digitalIn: DigitalCodeInputPort;
    port rateOut: AngularRateSampleOutputPort;
    port diagnosticOut: DiagnosticOutputPort;

    attribute storedBias: AngularRate = 0.0;
    attribute scaleFactor: AngularRate = 0.0002663;
    attribute temperatureCoefficient: AngularRate = 0.00001745;
    attribute saturationThresholdHigh: AngularRate = 8.72;
    attribute saturationThresholdLow: AngularRate = -8.72;
    attribute outputSampleRate: Frequency = 1000.0;
    attribute outputSamplePeriod: Time = 0.001;

    perform action computeSample: ComputeAngularRateSample;
    perform action biasCalibration: CalibrateZeroRateBias;
  }

  part def DigitalInterface {
    port sampleIn: AngularRateSampleInputPort;
    port sampleOut: AngularRateSampleOutputPort;
    port commandIn: CommandInputPort;
    port diagnosticOut: DiagnosticOutputPort;
    port powerIn: PowerInputPort;

    attribute interfaceLatency: Time = 0.0005;
    attribute maximumOutputJitter: Time = 0.0001;
    attribute outputFrameRate: Frequency = 1000.0;
    attribute sequenceCounterWidth: Resolution = 16.0;
  }

  part def PowerRegulator {
    port externalPowerIn: PowerInputPort;
    port regulatedPowerOut: PowerInputPort;
    port diagnosticOut: DiagnosticOutputPort;

    attribute inputVoltageMin: Voltage = 4.75;
    attribute inputVoltageMax: Voltage = 5.25;
    attribute regulatedVoltage: Voltage = 5.0;
    attribute maximumOutputCurrent: Current = 150.0;
    attribute powerGoodThreshold: Voltage = 4.65;

    assert constraint inputVoltageLimit: SupplyVoltageWithinLimits {
      in voltage = externalPowerIn.power.supplyVoltage;
    }
  }

  part def AngularRateSensingUnit {
    port measuredMotionIn: RotationalMotionInputPort;
    port electricalPowerIn: PowerInputPort;
    port commandIn: CommandInputPort;
    port angularRateOut: AngularRateSampleOutputPort;
    port diagnosticOut: DiagnosticOutputPort;

    part regulator: PowerRegulator;
    part sensor: AngularRateSensor;
    part filter: AntiAliasFilter;
    part adc: AnalogToDigitalConverter;
    part temperatureSensor: TemperatureSensor;
    part compensator: BiasAndScaleCompensator;
    part interface: DigitalInterface;

    attribute relevantMeasuredQuantity: String = "angular rate";
    attribute configuredMeasurementAxis: AxisKind = AxisKind::z;
    attribute measurementRangeMin: AngularRate = -8.726646;
    attribute measurementRangeMax: AngularRate = 8.726646;
    attribute nominalOutputRate: Frequency = 1000.0;
    attribute nominalSamplePeriod: Time = 0.001;
    attribute endToEndLatency: Time = 0.003;
    attribute totalSupplyCurrent: Current = 60.0;
    attribute health: HealthLevel = HealthLevel::nominal;

    connection externalPowerToRegulator
      connect electricalPowerIn to regulator.externalPowerIn;

    connection regulatedPowerToSensor
      connect regulator.regulatedPowerOut to sensor.powerIn;

    connection regulatedPowerToFilter
      connect regulator.regulatedPowerOut to filter.powerIn;

    connection regulatedPowerToAdc
      connect regulator.regulatedPowerOut to adc.powerIn;

    connection regulatedPowerToTemperatureSensor
      connect regulator.regulatedPowerOut to temperatureSensor.powerIn;

    connection regulatedPowerToInterface
      connect regulator.regulatedPowerOut to interface.powerIn;

    connection motionToAngularRateSensor
      connect measuredMotionIn to sensor.motionIn;

    connection rawAnalogRateToFilter
      connect sensor.analogOut to filter.analogIn;

    connection conditionedAnalogRateToAdc
      connect filter.analogOut to adc.analogIn;

    connection digitalCodeToCompensator
      connect adc.digitalOut to compensator.digitalIn;

    connection compensatedSampleToInterface
      connect compensator.rateOut to interface.sampleIn;

    connection interfaceToExternalOutput
      connect interface.sampleOut to angularRateOut;

    connection externalCommandsToSensor
      connect commandIn to sensor.commandIn;

    connection externalCommandsToInterface
      connect commandIn to interface.commandIn;

    connection sensorDiagnosticsToUnitDiagnostics
      connect sensor.diagnosticOut to diagnosticOut;

    connection compensatorDiagnosticsToUnitDiagnostics
      connect compensator.diagnosticOut to diagnosticOut;

    connection interfaceDiagnosticsToUnitDiagnostics
      connect interface.diagnosticOut to diagnosticOut;

    connection regulatorDiagnosticsToUnitDiagnostics
      connect regulator.diagnosticOut to diagnosticOut;

    exhibit state operationalBehavior: SensingUnitOperationalStates;

    perform action measurementFunction: MeasureAngularRate;

    assert constraint unitRangeLimit: AngularRateWithinMeasuringRange {
      in rate = measuredMotionIn.motion.angularRate;
      in lowerLimit = measurementRangeMin;
      in upperLimit = measurementRangeMax;
    }

    assert constraint outputSamplingRelation: SamplePeriodMatchesRate {
      in period = nominalSamplePeriod;
      in rate = nominalOutputRate;
    }
  }

  requirement def AngularRateQuantityRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint measuredQuantity {
      unit.relevantMeasuredQuantity == "angular rate"
    }
  }

  requirement def AngularRateSensorUsageRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint containsAngularRateSensor {
      unit.sensor.measurementAxis == unit.configuredMeasurementAxis
    }
  }

  requirement def MeasurementRangeRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint rangeAtLeastPlusMinusFiveHundredDegreesPerSecond {
      unit.measurementRangeMin <= -8.726646 and unit.measurementRangeMax >= 8.726646
    }
  }

  requirement def OutputRateRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint outputRateOneKilohertz {
      unit.nominalOutputRate == 1000.0 and unit.nominalSamplePeriod == 0.001
    }
  }

  requirement def EndToEndLatencyRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint latencyNoGreaterThanThreeMilliseconds {
      unit.endToEndLatency <= 0.003
    }
  }

  requirement def SupplyRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint fiveVoltSupply {
      unit.electricalPowerIn.power.supplyVoltage >= 4.75 and
      unit.electricalPowerIn.power.supplyVoltage <= 5.25 and
      unit.totalSupplyCurrent <= 100.0
    }
  }

  requirement def ValidSampleRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint validSampleWhenPoweredAndInRange {
      unit.electricalPowerIn.power.powerGood implies
      unit.angularRateOut.sample.status == SampleStatus::valid
    }
  }

  requirement def SelfTestRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint reportsSelfTestResult {
      unit.diagnosticOut.report.sensorSelfTestPassed == true implies
      unit.diagnosticOut.report.health != HealthLevel::failed
    }
  }

  requirement def TemperatureCompensationRequirement {
    subject unit: AngularRateSensingUnit;

    require constraint supportsOperatingTemperatureRange {
      unit.sensor.operatingTemperatureMin <= -40.0 and
      unit.sensor.operatingTemperatureMax >= 85.0
    }
  }

  part angularRateSensingUnit: AngularRateSensingUnit;

}
