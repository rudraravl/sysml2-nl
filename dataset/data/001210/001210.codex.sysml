package PyrgeometerHighLevelModel {

  enum def OperatingMode {
    enum off;
    enum standby;
    enum warmUp;
    enum measuring;
    enum selfTest;
    enum fault;
  }

  enum def HealthStatus {
    enum nominal;
    enum degraded;
    enum failed;
  }

  enum def SkyConditionEstimate {
    enum clear;
    enum partlyCloudy;
    enum overcast;
    enum precipitationSuspected;
    enum unknown;
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : String = "K";
  }

  attribute def Irradiance {
    attribute value : Real;
    attribute unit : String = "W/m^2";
  }

  attribute def Voltage {
    attribute value : Real;
    attribute unit : String = "V";
  }

  attribute def ElectricCurrent {
    attribute value : Real;
    attribute unit : String = "A";
  }

  attribute def ElectricPower {
    attribute value : Real;
    attribute unit : String = "W";
  }

  attribute def Resistance {
    attribute value : Real;
    attribute unit : String = "ohm";
  }

  attribute def TimeDuration {
    attribute value : Real;
    attribute unit : String = "s";
  }

  attribute def Wavelength {
    attribute value : Real;
    attribute unit : String = "um";
  }

  attribute def SampleRate {
    attribute value : Real;
    attribute unit : String = "Hz";
  }

  attribute def CalibrationCoefficient {
    attribute value : Real;
    attribute unit : String = "W/(m^2*V)";
  }

  attribute def Emissivity {
    attribute value : Real;
    attribute unit : String = "1";
  }

  attribute def SerialNumber {
    attribute value : String;
  }

  item def LongwaveInfraredRadiation {
    attribute lowerWavelength : Wavelength;
    attribute upperWavelength : Wavelength;
    attribute hemisphericalIrradiance : Irradiance;
    attribute sourceTemperatureEstimate : Temperature;
  }

  item def ThermalSignal {
    attribute thermopileVoltage : Voltage;
    attribute thermopileHotJunctionTemperature : Temperature;
    attribute thermopileColdJunctionTemperature : Temperature;
  }

  item def DomeTemperatureSignal {
    attribute innerDomeTemperature : Temperature;
    attribute outerDomeTemperature : Temperature;
  }

  item def ElectricalSupply {
    attribute supplyVoltage : Voltage;
    attribute availableCurrent : ElectricCurrent;
    attribute maximumPower : ElectricPower;
  }

  item def PyrgeometerMeasurement {
    attribute timestampSeconds : TimeDuration;
    attribute longwaveIrradiance : Irradiance;
    attribute bodyTemperature : Temperature;
    attribute domeTemperature : Temperature;
    attribute thermopileVoltage : Voltage;
    attribute skyConditionEstimate : SkyConditionEstimate;
    attribute health : HealthStatus;
  }

  port def RadiationInputPort {
    in incidentLongwaveRadiation : LongwaveInfraredRadiation;
  }

  port def ThermalExchangePort {
    inout thermalEnergyFlow : ThermalSignal;
  }

  port def DomeThermalPort {
    out domeTemperatureSignal : DomeTemperatureSignal;
  }

  port def PowerInputPort {
    in electricalSupply : ElectricalSupply;
  }

  port def MeasurementOutputPort {
    out measurement : PyrgeometerMeasurement;
  }

  port def MaintenancePort {
    in command : String;
    out response : String;
  }

  part def HemisphericalDome {
    attribute material : String = "silicon or coated glass";
    attribute longwaveTransmission : Real = 0.75;
    attribute fieldOfView : Real = 180.0;
    attribute lowerSpectralLimit : Wavelength = (value = 4.5; unit = "um");
    attribute upperSpectralLimit : Wavelength = (value = 45.0; unit = "um");
    attribute domeEmissivity : Emissivity = (value = 0.02; unit = "1");

    port skySide : RadiationInputPort;
    port sensorSide : RadiationInputPort;
    port domeThermalOutput : DomeThermalPort;
  }

  part def ThermopileDetector {
    attribute sensitivity : CalibrationCoefficient = (value = 100.0; unit = "W/(m^2*V)");
    attribute nominalResistance : Resistance = (value = 1000.0; unit = "ohm");
    attribute noiseEquivalentIrradiance : Irradiance = (value = 1.0; unit = "W/m^2");
    attribute responseTime : TimeDuration = (value = 18.0; unit = "s");

    port opticalInput : RadiationInputPort;
    port thermalOutput : ThermalExchangePort;
  }

  part def BodyTemperatureSensor {
    attribute accuracy : Temperature = (value = 0.1; unit = "K");
    attribute sampleRate : SampleRate = (value = 1.0; unit = "Hz");

    port thermalOutput : ThermalExchangePort;
  }

  part def DomeTemperatureSensor {
    attribute accuracy : Temperature = (value = 0.2; unit = "K");
    attribute sampleRate : SampleRate = (value = 1.0; unit = "Hz");

    port domeInput : DomeThermalPort;
  }

  part def SignalConditioner {
    attribute inputVoltageRange : Voltage = (value = 0.02; unit = "V");
    attribute amplifierGain : Real = 1000.0;
    attribute lowPassCutoff : Real = 0.1;
    attribute analogToDigitalResolutionBits : Integer = 24;

    port thermopileInput : ThermalExchangePort;
    port bodyTemperatureInput : ThermalExchangePort;
    port domeTemperatureInput : DomeThermalPort;
  }

  part def IrradianceProcessor {
    attribute sampleRate : SampleRate = (value = 1.0; unit = "Hz");
    attribute calibrationConstant : CalibrationCoefficient = (value = 100.0; unit = "W/(m^2*V)");
    attribute stefanBoltzmannConstant : Real = 5.670374419e-8;
    attribute bodyEmissivityCorrection : Emissivity = (value = 1.0; unit = "1");
    attribute domeCorrectionEnabled : Boolean = true;

    port measurementOutput : MeasurementOutputPort;
  }

  part def PowerController {
    attribute nominalInputVoltage : Voltage = (value = 12.0; unit = "V");
    attribute nominalPowerConsumption : ElectricPower = (value = 2.5; unit = "W");
    attribute heaterPowerLimit : ElectricPower = (value = 5.0; unit = "W");

    port powerInput : PowerInputPort;
  }

  part def DesiccantAndHousing {
    attribute ingressProtectionRating : String = "IP67";
    attribute internalHumidityLimitPercent : Real = 20.0;
    attribute bodyEmissivity : Emissivity = (value = 0.98; unit = "1");
  }

  action def AcquireRawSignals {
    in radiation : LongwaveInfraredRadiation;
    out thermalSignal : ThermalSignal;
    out domeSignal : DomeTemperatureSignal;
  }

  action def CalculateLongwaveIrradiance {
    in thermalSignal : ThermalSignal;
    in domeSignal : DomeTemperatureSignal;
    in bodyTemperature : Temperature;
    in calibrationConstant : CalibrationCoefficient;
    out correctedIrradiance : Irradiance;
  }

  action def EstimateSkyCondition {
    in correctedIrradiance : Irradiance;
    in bodyTemperature : Temperature;
    out estimate : SkyConditionEstimate;
  }

  action def PublishMeasurement {
    in correctedIrradiance : Irradiance;
    in health : HealthStatus;
    out measurement : PyrgeometerMeasurement;
  }

  action def PerformSelfTest {
    out health : HealthStatus;
  }

  action def MeasureAtmosphericLongwaveRadiation {
    in incomingRadiation : LongwaveInfraredRadiation;
    out reportedMeasurement : PyrgeometerMeasurement;

    action acquire : AcquireRawSignals;
    action calculate : CalculateLongwaveIrradiance;
    action estimate : EstimateSkyCondition;
    action publish : PublishMeasurement;

    flow incomingRadiation to acquire.radiation;
    flow acquire.thermalSignal to calculate.thermalSignal;
    flow acquire.domeSignal to calculate.domeSignal;
    flow calculate.correctedIrradiance to estimate.correctedIrradiance;
    flow calculate.correctedIrradiance to publish.correctedIrradiance;
    flow publish.measurement to reportedMeasurement;
  }

  state def PyrgeometerOperationalState {
    attribute mode : OperatingMode;
    attribute health : HealthStatus;

    state off;
    state standby;
    state warmUp;
    state measuring;
    state selfTest;
    state fault;

    transition initialToOff first off;
    transition powerApplied first off then standby;
    transition startWarmUp first standby then warmUp;
    transition warmUpComplete first warmUp then measuring;
    transition requestSelfTest first standby then selfTest;
    transition selfTestPassed first selfTest then standby;
    transition selfTestFailed first selfTest then fault;
    transition measurementFault first measuring then fault;
    transition resetFault first fault then standby;
    transition powerRemoved first standby then off;
    transition shutdownFromMeasuring first measuring then standby;
  }

  part def Pyrgeometer {
    attribute serialNumber : SerialNumber = (value = "PYR-LW-0001");
    attribute primaryFunction : String = "Measure downwelling hemispherical atmospheric longwave infrared irradiance at the Earth's surface.";
    attribute operatingMode : OperatingMode = OperatingMode::off;
    attribute healthStatus : HealthStatus = HealthStatus::nominal;
    attribute measurementBandLower : Wavelength = (value = 4.5; unit = "um");
    attribute measurementBandUpper : Wavelength = (value = 45.0; unit = "um");
    attribute measurementRangeMinimum : Irradiance = (value = 0.0; unit = "W/m^2");
    attribute measurementRangeMaximum : Irradiance = (value = 700.0; unit = "W/m^2");
    attribute requiredAccuracy : Irradiance = (value = 5.0; unit = "W/m^2");
    attribute outputSampleRate : SampleRate = (value = 1.0; unit = "Hz");

    port skyView : RadiationInputPort;
    port power : PowerInputPort;
    port measurementData : MeasurementOutputPort;
    port maintenance : MaintenancePort;

    part dome : HemisphericalDome;
    part thermopile : ThermopileDetector;
    part bodyTemperatureSensor : BodyTemperatureSensor;
    part domeTemperatureSensor : DomeTemperatureSensor;
    part signalConditioner : SignalConditioner;
    part processor : IrradianceProcessor;
    part powerController : PowerController;
    part housing : DesiccantAndHousing;

    perform measurementBehavior : MeasureAtmosphericLongwaveRadiation;
    exhibit operationalState : PyrgeometerOperationalState;

    connect skyView to dome.skySide;
    connect dome.sensorSide to thermopile.opticalInput;
    connect thermopile.thermalOutput to signalConditioner.thermopileInput;
    connect bodyTemperatureSensor.thermalOutput to signalConditioner.bodyTemperatureInput;
    connect dome.domeThermalOutput to domeTemperatureSensor.domeInput;
    connect dome.domeThermalOutput to signalConditioner.domeTemperatureInput;
    connect processor.measurementOutput to measurementData;
    connect power to powerController.powerInput;
  }

  part def SurfaceMeteorologicalStation {
    attribute siteIdentifier : String = "SURFRAD-like fixed station";
    attribute latitudeDegrees : Real;
    attribute longitudeDegrees : Real;
    attribute elevationMeters : Real;

    port stationPower : PowerInputPort;
    port longwaveRadiationData : MeasurementOutputPort;

    part pyrgeometer : Pyrgeometer;

    connect stationPower to pyrgeometer.power;
    connect pyrgeometer.measurementData to longwaveRadiationData;
  }

  requirement def PrimaryFunctionRequirement {
    subject instrument : Pyrgeometer;
    require constraint {
      instrument.primaryFunction == "Measure downwelling hemispherical atmospheric longwave infrared irradiance at the Earth's surface."
    }
  }

  requirement def SpectralBandRequirement {
    subject instrument : Pyrgeometer;
    require constraint {
      instrument.measurementBandLower.value <= 4.5 and instrument.measurementBandUpper.value >= 45.0
    }
  }

  requirement def IrradianceRangeRequirement {
    subject instrument : Pyrgeometer;
    require constraint {
      instrument.measurementRangeMinimum.value <= 0.0 and instrument.measurementRangeMaximum.value >= 700.0
    }
  }

  requirement def AccuracyRequirement {
    subject instrument : Pyrgeometer;
    require constraint {
      instrument.requiredAccuracy.value <= 5.0
    }
  }

  requirement def SampleRateRequirement {
    subject instrument : Pyrgeometer;
    require constraint {
      instrument.outputSampleRate.value >= 1.0
    }
  }

  requirement def EnvironmentalProtectionRequirement {
    subject housing : DesiccantAndHousing;
    require constraint {
      housing.internalHumidityLimitPercent <= 20.0
    }
  }

  requirement def PowerRequirement {
    subject controller : PowerController;
    require constraint {
      controller.nominalInputVoltage.value == 12.0 and controller.nominalPowerConsumption.value <= 2.5
    }
  }

  satisfy PrimaryFunctionRequirement by Pyrgeometer;
  satisfy SpectralBandRequirement by Pyrgeometer;
  satisfy IrradianceRangeRequirement by Pyrgeometer;
  satisfy AccuracyRequirement by Pyrgeometer;
  satisfy SampleRateRequirement by Pyrgeometer;
  satisfy EnvironmentalProtectionRequirement by DesiccantAndHousing;
  satisfy PowerRequirement by PowerController;

}