package ElectroOpticalSensingUnitModel {

  import ScalarValues::*;
  import ISQ::*;

  attribute def Irradiance :> ISQ::radiantIntensity {
    unit = "W/m^2";
  }

  attribute def OpticalPower :> ISQ::power {
    unit = "W";
  }

  attribute def Wavelength :> ISQ::length {
    unit = "nm";
  }

  attribute def Voltage :> ISQ::electricPotential {
    unit = "V";
  }

  attribute def Current :> ISQ::electricCurrent {
    unit = "A";
  }

  attribute def Temperature :> ISQ::thermodynamicTemperature {
    unit = "degC";
  }

  attribute def SampleRate :> ISQ::frequency {
    unit = "Hz";
  }

  attribute def DigitalCount {
    count : Integer;
  }

  attribute def Confidence {
    value : Real;
  }

  item def IncidentOpticalSignal {
    irradiance : Irradiance;
    opticalPower : OpticalPower;
    centerWavelength : Wavelength;
    bandwidth : Wavelength;
    sourceTemperature : Temperature;
  }

  item def AnalogPhotoSignal {
    voltage : Voltage;
    current : Current;
    noiseVoltage : Voltage;
    detectorTemperature : Temperature;
  }

  item def DigitizedOpticalSample {
    rawCount : DigitalCount;
    sampleTime_s : Real;
    integrationTime_ms : Real;
    detectorTemperature : Temperature;
  }

  item def CalibratedMeasurement {
    measuredIrradiance : Irradiance;
    measuredOpticalPower : OpticalPower;
    wavelength : Wavelength;
    confidence : Confidence;
    valid : Boolean;
    timestamp_s : Real;
  }

  item def DiagnosticStatus {
    sensorHealthy : Boolean;
    saturationDetected : Boolean;
    temperatureCompensationActive : Boolean;
    faultCode : Integer;
  }

  port def OpticalInputPort {
    in incidentLight : IncidentOpticalSignal;
  }

  port def AnalogSignalPort {
    out analogSignal : AnalogPhotoSignal;
  }

  port def DigitalSamplePort {
    out digitalSample : DigitizedOpticalSample;
  }

  port def MeasurementPort {
    out measurement : CalibratedMeasurement;
  }

  port def DiagnosticPort {
    out status : DiagnosticStatus;
  }

  port def ElectricalPowerPort {
    in supplyVoltage : Voltage;
    in supplyCurrent : Current;
  }

  port def ControlPort {
    in enable : Boolean;
    in requestedSampleRate : SampleRate;
    in zeroCalibrationCommand : Boolean;
  }

  part def OpticalFilter {
    port opticalIn : OpticalInputPort;
    port opticalOut : OpticalInputPort;

    attribute passbandCenter : Wavelength = 850 [nm];
    attribute passbandWidth : Wavelength = 40 [nm];
    attribute outOfBandRejection_dB : Real = 45;
    attribute transmissionEfficiency : Real = 0.82;
  }

  part def LensAssembly {
    port opticalIn : OpticalInputPort;
    port opticalOut : OpticalInputPort;

    attribute apertureDiameter_mm : Real = 8.0;
    attribute focalLength_mm : Real = 16.0;
    attribute opticalEfficiency : Real = 0.88;
    attribute fieldOfView_deg : Real = 12.0;
  }

  part def PhotodiodeDetector {
    port opticalIn : OpticalInputPort;
    port analogOut : AnalogSignalPort;

    attribute activeArea_mm2 : Real = 3.2;
    attribute responsivity_A_per_W : Real = 0.62;
    attribute darkCurrent : Current = 2.5 [nA];
    attribute saturationCurrent : Current = 2.0 [mA];
    attribute operatingTemperature : Temperature;
  }

  part def TransimpedanceAmplifier {
    port analogIn : AnalogSignalPort;
    port analogOut : AnalogSignalPort;
    port power : ElectricalPowerPort;

    attribute feedbackResistance_ohm : Real = 1000000;
    attribute bandwidth_Hz : Real = 20000;
    attribute inputNoise_nV_per_sqrtHz : Real = 8.5;
    attribute outputSaturationVoltage : Voltage = 3.1 [V];
  }

  part def AnalogToDigitalConverter {
    port analogIn : AnalogSignalPort;
    port sampleOut : DigitalSamplePort;
    port control : ControlPort;
    port power : ElectricalPowerPort;

    attribute resolution_bits : Integer = 16;
    attribute referenceVoltage : Voltage = 3.3 [V];
    attribute maximumSampleRate : SampleRate = 5000 [Hz];
    attribute configuredSampleRate : SampleRate = 1000 [Hz];
  }

  part def TemperatureSensor {
    port diagnosticOut : DiagnosticPort;
    port power : ElectricalPowerPort;

    attribute measuredTemperature : Temperature;
    attribute accuracy_degC : Real = 0.5;
  }

  part def MeasurementProcessor {
    port sampleIn : DigitalSamplePort;
    port temperatureStatusIn : DiagnosticPort;
    port measurementOut : MeasurementPort;
    port diagnosticOut : DiagnosticPort;
    port control : ControlPort;
    port power : ElectricalPowerPort;

    attribute calibrationGain : Real = 1.000;
    attribute calibrationOffset_W_per_m2 : Real = 0.0;
    attribute linearityError_percent : Real = 0.8;
    attribute noiseEquivalentIrradiance_W_per_m2 : Real = 0.00015;
    attribute saturationThreshold_count : Integer = 64200;
    attribute validMeasurement : Boolean;
  }

  part def PowerConditioner {
    port externalPower : ElectricalPowerPort;
    port regulatedPower : ElectricalPowerPort;

    attribute inputVoltageMin : Voltage = 9.0 [V];
    attribute inputVoltageMax : Voltage = 36.0 [V];
    attribute regulatedVoltage : Voltage = 3.3 [V];
    attribute maxOutputCurrent : Current = 250 [mA];
    attribute rippleVoltage : Voltage = 8 [mV];
  }

  action def AcquireOpticalMeasurement {
    in incident : IncidentOpticalSignal;
    in sampleRate : SampleRate;
    out calibrated : CalibratedMeasurement;
    out status : DiagnosticStatus;

    first start;
    then filterLight;
    then focusLight;
    then convertPhotonFluxToCurrent;
    then amplifySignal;
    then digitizeSignal;
    then compensateTemperature;
    then applyCalibration;
    then validateMeasurement;
    then publishMeasurement;
    then done;

    action filterLight {
      in incident : IncidentOpticalSignal;
      out filtered : IncidentOpticalSignal;
    }

    action focusLight {
      in filtered : IncidentOpticalSignal;
      out focused : IncidentOpticalSignal;
    }

    action convertPhotonFluxToCurrent {
      in focused : IncidentOpticalSignal;
      out photoSignal : AnalogPhotoSignal;
    }

    action amplifySignal {
      in photoSignal : AnalogPhotoSignal;
      out amplifiedSignal : AnalogPhotoSignal;
    }

    action digitizeSignal {
      in amplifiedSignal : AnalogPhotoSignal;
      out sample : DigitizedOpticalSample;
    }

    action compensateTemperature {
      in sample : DigitizedOpticalSample;
      out compensatedSample : DigitizedOpticalSample;
    }

    action applyCalibration {
      in compensatedSample : DigitizedOpticalSample;
      out calibrated : CalibratedMeasurement;
    }

    action validateMeasurement {
      in calibrated : CalibratedMeasurement;
      out status : DiagnosticStatus;
    }

    action publishMeasurement {
      in calibrated : CalibratedMeasurement;
      in status : DiagnosticStatus;
    }
  }

  state def SensingUnitOperatingState {
    entry action initializeElectronics;
    state Off;
    state Initialization;
    state Standby;
    state Measuring;
    state Calibration;
    state Fault;

    transition first Off;
    transition Off_to_Initialization
      first Off
      accept enable
      then Initialization;

    transition Initialization_to_Standby
      first Initialization
      if selfTestPassed
      then Standby;

    transition Initialization_to_Fault
      first Initialization
      if not selfTestPassed
      then Fault;

    transition Standby_to_Measuring
      first Standby
      accept measurementRequested
      then Measuring;

    transition Measuring_to_Standby
      first Measuring
      accept measurementStopped
      then Standby;

    transition Measuring_to_Calibration
      first Measuring
      accept zeroCalibrationCommand
      then Calibration;

    transition Calibration_to_Standby
      first Calibration
      if calibrationComplete
      then Standby;

    transition Any_to_Fault
      first Standby
      if supplyOutOfRange or detectorSaturated or processorFault
      then Fault;

    transition Fault_to_Initialization
      first Fault
      accept reset
      then Initialization;
  }

  part def ElectroOpticalSensingUnit {
    port opticalInput : OpticalInputPort;
    port measurementOutput : MeasurementPort;
    port diagnostics : DiagnosticPort;
    port control : ControlPort;
    port powerInput : ElectricalPowerPort;

    part filter : OpticalFilter;
    part lens : LensAssembly;
    part detector : PhotodiodeDetector;
    part amplifier : TransimpedanceAmplifier;
    part adc : AnalogToDigitalConverter;
    part temperatureSensor : TemperatureSensor;
    part processor : MeasurementProcessor;
    part powerConditioner : PowerConditioner;

    attribute measurableQuantity : String = "spectrally filtered optical irradiance";
    attribute nominalWavelength : Wavelength = 850 [nm];
    attribute irradianceRangeMin : Irradiance = 0.0005 [W/m^2];
    attribute irradianceRangeMax : Irradiance = 1200 [W/m^2];
    attribute measurementAccuracy_percentOfReading : Real = 2.0;
    attribute measurementResolution : Irradiance = 0.0001 [W/m^2];
    attribute responseTime_ms : Real = 12.0;
    attribute operatingTemperatureMin : Temperature = -20 [degC];
    attribute operatingTemperatureMax : Temperature = 70 [degC];

    connect opticalInput to filter.opticalIn;
    connect filter.opticalOut to lens.opticalIn;
    connect lens.opticalOut to detector.opticalIn;
    connect detector.analogOut to amplifier.analogIn;
    connect amplifier.analogOut to adc.analogIn;
    connect adc.sampleOut to processor.sampleIn;
    connect temperatureSensor.diagnosticOut to processor.temperatureStatusIn;
    connect processor.measurementOut to measurementOutput;
    connect processor.diagnosticOut to diagnostics;
    connect control to adc.control;
    connect control to processor.control;
    connect powerInput to powerConditioner.externalPower;
    connect powerConditioner.regulatedPower to amplifier.power;
    connect powerConditioner.regulatedPower to adc.power;
    connect powerConditioner.regulatedPower to processor.power;
    connect powerConditioner.regulatedPower to temperatureSensor.power;

    perform acquisition : AcquireOpticalMeasurement;
    exhibit operatingState : SensingUnitOperatingState;
  }

  requirement def MeasureRelevantQuantityRequirement {
    subject unit : ElectroOpticalSensingUnit;

    require constraint {
      unit.measurableQuantity == "spectrally filtered optical irradiance"
    }

    require constraint {
      unit.nominalWavelength >= 830 [nm] and unit.nominalWavelength <= 870 [nm]
    }

    require constraint {
      unit.irradianceRangeMin <= 0.001 [W/m^2] and unit.irradianceRangeMax >= 1000 [W/m^2]
    }

    require constraint {
      unit.measurementAccuracy_percentOfReading <= 2.0
    }

    require constraint {
      unit.responseTime_ms <= 20.0
    }
  }

  requirement def ElectroOpticalSensorRequirement {
    subject unit : ElectroOpticalSensingUnit;

    require constraint {
      unit.detector.responsivity_A_per_W >= 0.5
    }

    require constraint {
      unit.filter.transmissionEfficiency >= 0.75
    }

    require constraint {
      unit.lens.opticalEfficiency >= 0.80
    }

    require constraint {
      unit.adc.resolution_bits >= 16
    }
  }

  requirement def ValidMeasurementOutputRequirement {
    subject unit : ElectroOpticalSensingUnit;

    require constraint {
      unit.measurementResolution <= 0.0001 [W/m^2]
    }

    require constraint {
      unit.processor.linearityError_percent <= 1.0
    }

    require constraint {
      unit.processor.noiseEquivalentIrradiance_W_per_m2 <= 0.0002
    }
  }

  requirement def EnvironmentalRequirement {
    subject unit : ElectroOpticalSensingUnit;

    require constraint {
      unit.operatingTemperatureMin <= -20 [degC]
    }

    require constraint {
      unit.operatingTemperatureMax >= 70 [degC]
    }

    require constraint {
      unit.powerConditioner.inputVoltageMin <= 9.0 [V] and unit.powerConditioner.inputVoltageMax >= 36.0 [V]
    }
  }

  part eoSensingUnit : ElectroOpticalSensingUnit;

  satisfy MeasureRelevantQuantityRequirement by eoSensingUnit;
  satisfy ElectroOpticalSensorRequirement by eoSensingUnit;
  satisfy ValidMeasurementOutputRequirement by eoSensingUnit;
  satisfy EnvironmentalRequirement by eoSensingUnit;
}