package LightSensingUnitModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Illuminance :> Real {
    doc "Illuminance measured in lux (lx).";
  }

  attribute def OpticalPower :> Real {
    doc "Incident optical power measured in microwatts (uW).";
  }

  attribute def Wavelength :> Real {
    doc "Optical wavelength measured in nanometers (nm).";
  }

  attribute def Voltage :> Real {
    doc "Electrical potential measured in volts (V).";
  }

  attribute def Current :> Real {
    doc "Electrical current measured in microamperes (uA).";
  }

  attribute def DigitalCount :> Integer {
    doc "Unsigned analog-to-digital converter output count.";
  }

  attribute def Temperature :> Real {
    doc "Temperature measured in degrees Celsius (degC).";
  }

  attribute def TimeDuration :> Real {
    doc "Duration measured in seconds (s).";
  }

  attribute def Frequency :> Real {
    doc "Frequency measured in hertz (Hz).";
  }

  attribute def Percent :> Real {
    doc "Percentage measured in percent (%).";
  }

  attribute def StatusCode :> String {
    doc "Operational status code.";
  }

  attribute def BooleanFlag :> Boolean;

  item def IncidentLight {
    attribute illuminance: Illuminance;
    attribute dominantWavelength: Wavelength;
    attribute opticalPower: OpticalPower;
    attribute incidenceAngle_deg: Real;
  }

  item def PhotodiodeCurrent {
    attribute photocurrent: Current;
    attribute darkCurrent: Current;
    attribute junctionTemperature: Temperature;
  }

  item def AnalogLightSignal {
    attribute voltage: Voltage;
    attribute noiseRms: Voltage;
    attribute gain: Real;
  }

  item def DigitalLightSignal {
    attribute adcCount: DigitalCount;
    attribute adcResolution_bits: Integer;
    attribute referenceVoltage: Voltage;
  }

  item def IlluminanceSample {
    attribute illuminance: Illuminance;
    attribute sampleAge: TimeDuration;
    attribute quality: Percent;
    attribute saturated: BooleanFlag;
    attribute valid: BooleanFlag;
  }

  item def DiagnosticReport {
    attribute status: StatusCode;
    attribute supplyVoltage: Voltage;
    attribute sensorTemperature: Temperature;
    attribute opticalPathObstructed: BooleanFlag;
    attribute lastMeasuredIlluminance: Illuminance;
  }

  item def ElectricalPower {
    attribute voltage: Voltage;
    attribute currentLimit: Current;
  }

  item def ConfigurationCommand {
    attribute requestedSamplePeriod: TimeDuration;
    attribute requestedGain: Real;
    attribute selfTestRequested: BooleanFlag;
  }

  port def OpticalInputPort {
    in item light: IncidentLight;
  }

  port def PhotocurrentPort {
    out item currentSignal: PhotodiodeCurrent;
  }

  port def AnalogSignalPort {
    in item analogIn: AnalogLightSignal;
    out item analogOut: AnalogLightSignal;
  }

  port def DigitalSignalPort {
    in item digitalIn: DigitalLightSignal;
    out item digitalOut: DigitalLightSignal;
  }

  port def MeasurementOutputPort {
    out item sample: IlluminanceSample;
  }

  port def DiagnosticPort {
    out item diagnostic: DiagnosticReport;
  }

  port def PowerInputPort {
    in item power: ElectricalPower;
  }

  port def ConfigurationPort {
    in item command: ConfigurationCommand;
  }

  port def ThermalPort {
    out item sensedTemperature: Temperature;
  }

  part def OpticalWindow {
    attribute transmission: Percent = 92.0;
    attribute clearApertureDiameter_mm: Real = 5.0;
    attribute antiReflectionCoated: Boolean = true;
    port externalLight: OpticalInputPort;
    port internalLight: OpticalInputPort;
  }

  part def LightSensor {
    doc "Solid-state light sensor that converts incident light into photocurrent.";
    attribute spectralRangeMin: Wavelength = 400.0;
    attribute spectralRangeMax: Wavelength = 700.0;
    attribute responsivity_uA_per_lx: Real = 0.42;
    attribute saturationIlluminance: Illuminance = 100000.0;
    attribute darkCurrent: Current = 0.03;
    port opticalIn: OpticalInputPort;
    port photocurrentOut: PhotocurrentPort;
    port temperatureOut: ThermalPort;
  }

  part def TransimpedanceAmplifier {
    attribute feedbackResistance_kOhm: Real = 100.0;
    attribute bandwidth: Frequency = 1000.0;
    attribute outputOffset: Voltage = 0.0;
    port currentIn: PhotocurrentPort;
    port analogOut: AnalogSignalPort;
  }

  part def LowPassFilter {
    attribute cutoffFrequency: Frequency = 25.0;
    attribute attenuationAtMains: Percent = 95.0;
    port analogIn: AnalogSignalPort;
    port analogOut: AnalogSignalPort;
  }

  part def AnalogToDigitalConverter {
    attribute resolution_bits: Integer = 16;
    attribute referenceVoltage: Voltage = 3.3;
    attribute conversionTime: TimeDuration = 0.002;
    port analogIn: AnalogSignalPort;
    port digitalOut: DigitalSignalPort;
  }

  part def CalibrationMemory {
    attribute gainCorrection: Real = 1.018;
    attribute offsetCorrection_lx: Illuminance = -0.7;
    attribute temperatureCoefficient_percent_per_degC: Real = 0.08;
    attribute calibrationIlluminanceLow: Illuminance = 10.0;
    attribute calibrationIlluminanceHigh: Illuminance = 50000.0;
  }

  part def MeasurementProcessor {
    attribute samplePeriod: TimeDuration = 0.100;
    attribute minimumIlluminance: Illuminance = 0.1;
    attribute maximumIlluminance: Illuminance = 100000.0;
    attribute outputResolution: Illuminance = 0.1;
    attribute averagingWindowSamples: Integer = 8;
    attribute latestIlluminance: Illuminance = 0.0;
    attribute latestQuality: Percent = 0.0;
    port digitalIn: DigitalSignalPort;
    port configurationIn: ConfigurationPort;
    port measurementOut: MeasurementOutputPort;
    port diagnosticOut: DiagnosticPort;
  }

  part def PowerConditioner {
    attribute nominalInputVoltage: Voltage = 5.0;
    attribute regulatedVoltage: Voltage = 3.3;
    attribute maximumSupplyCurrent: Current = 25.0;
    attribute undervoltageThreshold: Voltage = 3.0;
    port powerIn: PowerInputPort;
  }

  action def ConvertLightToPhotocurrent {
    in item incident: IncidentLight;
    in attribute responsivity_uA_per_lx: Real;
    in attribute darkCurrent: Current;
    out item current: PhotodiodeCurrent;
    constraint conversionEquation {
      current.photocurrent == incident.illuminance * responsivity_uA_per_lx + darkCurrent
    }
  }

  action def AmplifyPhotocurrent {
    in item current: PhotodiodeCurrent;
    in attribute feedbackResistance_kOhm: Real;
    out item analog: AnalogLightSignal;
    constraint amplifierEquation {
      analog.voltage == current.photocurrent * feedbackResistance_kOhm / 1000.0
    }
  }

  action def FilterAnalogSignal {
    in item unfiltered: AnalogLightSignal;
    in attribute cutoffFrequency: Frequency;
    out item filtered: AnalogLightSignal;
    constraint noiseReduction {
      filtered.noiseRms <= unfiltered.noiseRms
    }
  }

  action def DigitizeAnalogSignal {
    in item analog: AnalogLightSignal;
    in attribute referenceVoltage: Voltage;
    in attribute resolution_bits: Integer;
    out item digital: DigitalLightSignal;
    constraint adcRange {
      digital.adcCount >= 0
    }
  }

  action def ApplyCalibration {
    in item digital: DigitalLightSignal;
    in attribute gainCorrection: Real;
    in attribute offsetCorrection_lx: Illuminance;
    in attribute temperature_degC: Temperature;
    out item sample: IlluminanceSample;
    constraint calibratedRange {
      sample.illuminance >= 0.0
    }
  }

  action def ValidateIlluminanceSample {
    in item sampleIn: IlluminanceSample;
    in attribute minimumIlluminance: Illuminance;
    in attribute maximumIlluminance: Illuminance;
    out item sampleOut: IlluminanceSample;
    constraint validityRule {
      sampleOut.valid == (sampleIn.illuminance >= minimumIlluminance and sampleIn.illuminance <= maximumIlluminance)
    }
    constraint saturationRule {
      sampleOut.saturated == (sampleIn.illuminance >= maximumIlluminance)
    }
  }

  action def LightMeasurementCycle {
    in item incidentLight: IncidentLight;
    out item measuredSample: IlluminanceSample;

    action sense: ConvertLightToPhotocurrent;
    action amplify: AmplifyPhotocurrent;
    action filter: FilterAnalogSignal;
    action convert: DigitizeAnalogSignal;
    action calibrate: ApplyCalibration;
    action validate: ValidateIlluminanceSample;

    flow incidentLight to sense.incident;
    flow sense.current to amplify.current;
    flow amplify.analog to filter.unfiltered;
    flow filter.filtered to convert.analog;
    flow convert.digital to calibrate.digital;
    flow calibrate.sample to validate.sampleIn;
    flow validate.sampleOut to measuredSample;
  }

  state def SensingUnitStateMachine {
    attribute initialized: Boolean = false;
    attribute faultPresent: Boolean = false;
    attribute measurementEnabled: Boolean = false;

    state off;
    state initializing;
    state idle;
    state measuring;
    state reporting;
    state selfTesting;
    state fault;

    transition startUp first off then initializing;
    transition initializationComplete
      first initializing
      then idle
      if initialized and not faultPresent;

    transition initializationFailed
      first initializing
      then fault
      if faultPresent;

    transition beginMeasurement
      first idle
      then measuring
      if measurementEnabled and not faultPresent;

    transition measurementReady
      first measuring
      then reporting
      if not faultPresent;

    transition reportComplete
      first reporting
      then idle
      if not faultPresent;

    transition requestSelfTest
      first idle
      then selfTesting;

    transition selfTestPassed
      first selfTesting
      then idle
      if not faultPresent;

    transition selfTestFailed
      first selfTesting
      then fault
      if faultPresent;

    transition detectedFault
      first idle
      then fault
      if faultPresent;

    transition detectedFaultDuringMeasurement
      first measuring
      then fault
      if faultPresent;

    transition resetFault
      first fault
      then initializing
      if not faultPresent;
  }

  part def LightSensingUnit {
    doc "A sensing unit that measures illuminance using a light sensor and outputs calibrated illuminance samples.";

    attribute supportedQuantity: String = "Illuminance";
    attribute measurementUnit: String = "lux";
    attribute nominalSamplePeriod: TimeDuration = 0.100;
    attribute measurementRangeLow: Illuminance = 0.1;
    attribute measurementRangeHigh: Illuminance = 100000.0;
    attribute accuracy_percentOfReading: Percent = 5.0;
    attribute responseTime: TimeDuration = 0.250;
    attribute operatingTemperatureMin: Temperature = -20.0;
    attribute operatingTemperatureMax: Temperature = 70.0;

    port ambientLightIn: OpticalInputPort;
    port powerIn: PowerInputPort;
    port configurationIn: ConfigurationPort;
    port illuminanceOut: MeasurementOutputPort;
    port diagnosticOut: DiagnosticPort;

    part window: OpticalWindow;
    part sensor: LightSensor;
    part amplifier: TransimpedanceAmplifier;
    part filter: LowPassFilter;
    part adc: AnalogToDigitalConverter;
    part calibration: CalibrationMemory;
    part processor: MeasurementProcessor;
    part power: PowerConditioner;

    perform action measurementCycle: LightMeasurementCycle;
    exhibit state operationalStates: SensingUnitStateMachine;

    connect ambientOpticalPath connect ambientLightIn to window.externalLight;
    connect conditionedOpticalPath connect window.internalLight to sensor.opticalIn;
    connect photocurrentPath connect sensor.photocurrentOut to amplifier.currentIn;
    connect amplifiedSignalPath connect amplifier.analogOut to filter.analogIn;
    connect filteredSignalPath connect filter.analogOut to adc.analogIn;
    connect digitalSignalPath connect adc.digitalOut to processor.digitalIn;
    connect commandPath connect configurationIn to processor.configurationIn;
    connect samplePath connect processor.measurementOut to illuminanceOut;
    connect diagnosticPath connect processor.diagnosticOut to diagnosticOut;
    connect supplyPath connect powerIn to power.powerIn;

    constraint measurementRangeConstraint {
      measurementRangeLow <= measurementCycle.measuredSample.illuminance and
      measurementCycle.measuredSample.illuminance <= measurementRangeHigh
    }

    constraint responseTimeConstraint {
      responseTime <= 0.250
    }

    constraint samplePeriodConstraint {
      nominalSamplePeriod == processor.samplePeriod
    }

    constraint sensorCoverageConstraint {
      sensor.saturationIlluminance >= measurementRangeHigh
    }
  }

  requirement def RelevantQuantityRequirement {
    doc "The sensing unit shall measure the relevant optical quantity as illuminance.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.supportedQuantity == "Illuminance"
    }
  }

  requirement def LightSensorUseRequirement {
    doc "The sensing unit shall use a light sensor as the primary transduction element.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.sensor.responsivity_uA_per_lx > 0.0
    }
  }

  requirement def IlluminanceRangeRequirement {
    doc "The sensing unit shall measure illuminance from 0.1 lx to 100000 lx.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.measurementRangeLow <= 0.1 and unit.measurementRangeHigh >= 100000.0
    }
  }

  requirement def AccuracyRequirement {
    doc "The sensing unit shall provide calibrated illuminance with accuracy of 5 percent of reading or better.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.accuracy_percentOfReading <= 5.0
    }
  }

  requirement def ResponseTimeRequirement {
    doc "The sensing unit shall produce a valid illuminance sample within 250 ms.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.responseTime <= 0.250
    }
  }

  requirement def DigitalOutputRequirement {
    doc "The sensing unit shall output validated illuminance samples containing value, quality, validity, and saturation indication.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.processor.outputResolution <= 0.1
    }
  }

  requirement def OpticalFilteringRequirement {
    doc "The sensing unit shall limit measurement bandwidth to reduce flicker and electrical noise.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.filter.cutoffFrequency <= 25.0
    }
  }

  requirement def PowerRequirement {
    doc "The sensing unit shall operate from a nominal 5 V supply and regulate internal electronics to 3.3 V.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.power.nominalInputVoltage == 5.0 and unit.power.regulatedVoltage == 3.3
    }
  }

  requirement def DiagnosticRequirement {
    doc "The sensing unit shall provide diagnostics for supply voltage, sensor temperature, optical obstruction, and last measured illuminance.";
    subject unit: LightSensingUnit;
    require constraint {
      unit.diagnosticOut != null
    }
  }

  part lightSensingUnit: LightSensingUnit;

  satisfy RelevantQuantityRequirement by lightSensingUnit;
  satisfy LightSensorUseRequirement by lightSensingUnit;
  satisfy IlluminanceRangeRequirement by lightSensingUnit;
  satisfy AccuracyRequirement by lightSensingUnit;
  satisfy ResponseTimeRequirement by lightSensingUnit;
  satisfy DigitalOutputRequirement by lightSensingUnit;
  satisfy OpticalFilteringRequirement by lightSensingUnit;
  satisfy PowerRequirement by lightSensingUnit;
  satisfy DiagnosticRequirement by lightSensingUnit;
}
