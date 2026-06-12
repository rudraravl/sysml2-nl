package PyranometerSystemModel {

  import ScalarValues::*;
  import SI::*;

  value type Irradiance :> Real {
    unit = "W/m^2";
  }

  value type Voltage :> Real {
    unit = "V";
  }

  value type Current :> Real {
    unit = "mA";
  }

  value type Temperature :> Real {
    unit = "degC";
  }

  value type TimeInterval :> Real {
    unit = "s";
  }

  value type Percent :> Real {
    unit = "%";
  }

  value type DigitalCount :> Integer;

  item def SolarRadiation {
    attribute globalHorizontalIrradiance : Irradiance;
    attribute spectralRangeStart : Real = 300.0;
    attribute spectralRangeEnd : Real = 2800.0;
  }

  item def ThermalSignal {
    attribute thermopileVoltage : Voltage;
    attribute sensorTemperature : Temperature;
  }

  item def ConditionedSignal {
    attribute amplifiedVoltage : Voltage;
    attribute offsetCorrectedVoltage : Voltage;
    attribute signalQuality : Percent;
  }

  item def IrradianceMeasurement {
    attribute irradiance : Irradiance;
    attribute temperature : Temperature;
    attribute timestamp : TimeInterval;
    attribute uncertainty : Percent;
  }

  item def Power {
    attribute supplyVoltage : Voltage;
    attribute supplyCurrent : Current;
  }

  port def RadiationPort {
    in radiation : SolarRadiation;
  }

  port def AnalogSignalPort {
    out signal : ThermalSignal;
  }

  port def ConditionedSignalPort {
    in rawSignal : ThermalSignal;
    out conditionedSignal : ConditionedSignal;
  }

  port def MeasurementPort {
    out measurement : IrradianceMeasurement;
  }

  port def PowerPort {
    in power : Power;
  }

  port def DataPort {
    out measurement : IrradianceMeasurement;
  }

  action def AbsorbSolarRadiation {
    in radiation : SolarRadiation;
    out thermalGradient : Temperature;
  }

  action def GenerateThermopileVoltage {
    in thermalGradient : Temperature;
    out signal : ThermalSignal;
  }

  action def ConditionAnalogSignal {
    in rawSignal : ThermalSignal;
    out conditionedSignal : ConditionedSignal;
  }

  action def ConvertToIrradiance {
    in conditionedSignal : ConditionedSignal;
    in calibrationSensitivity : Real;
    out measurement : IrradianceMeasurement;
  }

  action def ReportMeasurement {
    in measurement : IrradianceMeasurement;
    out publishedMeasurement : IrradianceMeasurement;
  }

  state def PyranometerOperatingState {
    entry action initializeElectronics;
    state Off;
    state Startup;
    state Measuring;
    state Fault;
    state Calibration;

    transition initial then Off;

    transition powerApplied
      first Off
      then Startup;

    transition startupComplete
      first Startup
      then Measuring;

    transition calibrationRequested
      first Measuring
      then Calibration;

    transition calibrationComplete
      first Calibration
      then Measuring;

    transition faultDetected
      first Measuring
      then Fault;

    transition faultCleared
      first Fault
      then Startup;

    transition powerRemoved
      first Measuring
      then Off;
  }

  part def Dome {
    port aperture : RadiationPort;
    attribute transmittance : Percent = 92.0;
    attribute hemisphericalFieldOfView : Real = 180.0;
    attribute material : String = "optical glass";
  }

  part def BlackAbsorber {
    port incidentRadiation : RadiationPort;
    attribute absorptance : Percent = 97.0;
    attribute thermalMass : Real = 0.8;
    perform action absorb : AbsorbSolarRadiation;
  }

  part def ThermopileSensor {
    port analogOutput : AnalogSignalPort;
    attribute sensitivity : Real = 10.0;
    attribute responseTime : TimeInterval = 5.0;
    attribute operatingTemperatureMin : Temperature = -40.0;
    attribute operatingTemperatureMax : Temperature = 80.0;
    perform action generateVoltage : GenerateThermopileVoltage;
  }

  part def TemperatureSensor {
    attribute measuredTemperature : Temperature;
    attribute accuracy : Temperature = 0.3;
  }

  part def SignalConditioner {
    port inputOutput : ConditionedSignalPort;
    attribute gain : Real = 1000.0;
    attribute offsetVoltage : Voltage = 0.0;
    attribute noiseRejection : Percent = 95.0;
    perform action condition : ConditionAnalogSignal;
  }

  part def AnalogToDigitalConverter {
    attribute resolution : DigitalCount = 24;
    attribute referenceVoltage : Voltage = 2.5;
    attribute sampleInterval : TimeInterval = 1.0;
  }

  part def ProcessingUnit {
    port measurementOutput : MeasurementPort;
    attribute calibrationSensitivity : Real = 10.0;
    attribute temperatureCompensationEnabled : Boolean = true;
    attribute measurementUpdatePeriod : TimeInterval = 1.0;
    perform action convert : ConvertToIrradiance;
    perform action report : ReportMeasurement;
  }

  part def PowerRegulator {
    port powerInput : PowerPort;
    attribute nominalInputVoltage : Voltage = 12.0;
    attribute regulatedVoltage : Voltage = 3.3;
    attribute maximumCurrent : Current = 100.0;
  }

  part def CommunicationsInterface {
    port dataOutput : DataPort;
    attribute protocol : String = "RS-485 Modbus";
    attribute baudRate : Integer = 9600;
  }

  part def PyranometerSystem {
    port radiationInput : RadiationPort;
    port powerInput : PowerPort;
    port dataOutput : DataPort;

    part dome : Dome;
    part absorber : BlackAbsorber;
    part thermopile : ThermopileSensor;
    part temperatureSensor : TemperatureSensor;
    part conditioner : SignalConditioner;
    part adc : AnalogToDigitalConverter;
    part processor : ProcessingUnit;
    part regulator : PowerRegulator;
    part communications : CommunicationsInterface;

    exhibit state operatingState : PyranometerOperatingState;

    attribute measurementRangeMin : Irradiance = 0.0;
    attribute measurementRangeMax : Irradiance = 1400.0;
    attribute primaryFunction : String =
      "Measure incoming hemispherical solar irradiance on a horizontal plane and provide a calibrated digital irradiance measurement.";

    connect radiationInput to dome.aperture;
    connect dome.aperture to absorber.incidentRadiation;
    connect thermopile.analogOutput to conditioner.inputOutput;
    connect processor.measurementOutput to communications.dataOutput;
    connect powerInput to regulator.powerInput;
    connect communications.dataOutput to dataOutput;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : PyranometerSystem;
    doc /* The pyranometer system shall measure incident solar radiation and produce calibrated irradiance measurements for external monitoring equipment. */
    require constraint {
      system.measurementRangeMin <= 0.0 and
      system.measurementRangeMax >= 1000.0
    }
  }

  requirement def SpectralResponseRequirement {
    subject dome : Dome;
    doc /* The optical dome shall transmit solar radiation across the shortwave solar spectrum used for pyranometer irradiance measurement. */
    require constraint {
      dome.transmittance >= 90.0
    }
  }

  requirement def ResponseTimeRequirement {
    subject thermopile : ThermopileSensor;
    doc /* The thermopile sensor shall respond quickly enough for environmental monitoring applications. */
    require constraint {
      thermopile.responseTime <= 10.0
    }
  }

  requirement def SignalQualityRequirement {
    subject conditioner : SignalConditioner;
    doc /* The signal conditioner shall suppress electrical noise before digitization. */
    require constraint {
      conditioner.noiseRejection >= 90.0
    }
  }

  requirement def MeasurementUpdateRequirement {
    subject processor : ProcessingUnit;
    doc /* The processing unit shall publish one calibrated irradiance measurement at least every second during normal operation. */
    require constraint {
      processor.measurementUpdatePeriod <= 1.0
    }
  }

  requirement def PowerRequirement {
    subject regulator : PowerRegulator;
    doc /* The pyranometer system shall operate from a nominal low-voltage external supply. */
    require constraint {
      regulator.nominalInputVoltage == 12.0 and
      regulator.regulatedVoltage == 3.3
    }
  }

  satisfy PrimaryFunctionRequirement by PyranometerSystem;
  satisfy SpectralResponseRequirement by Dome;
  satisfy ResponseTimeRequirement by ThermopileSensor;
  satisfy SignalQualityRequirement by SignalConditioner;
  satisfy MeasurementUpdateRequirement by ProcessingUnit;
  satisfy PowerRequirement by PowerRegulator;

}