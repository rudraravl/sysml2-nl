package ElectrochemicalGasSensingUnitModel {

  enum def GasSpecies {
    enum carbonMonoxide;
    enum hydrogenSulfide;
    enum oxygen;
    enum nitrogenDioxide;
    enum sulfurDioxide;
    enum chlorine;
    enum volatileOrganicInterferent;
    enum cleanAir;
  }

  enum def ConcentrationUnit {
    enum ppm;
    enum ppb;
    enum percentVolume;
    enum mgPerCubicMeter;
  }

  enum def TemperatureUnit {
    enum degC;
    enum kelvin;
  }

  enum def PressureUnit {
    enum kPa;
    enum Pa;
  }

  enum def HumidityUnit {
    enum percentRH;
  }

  enum def TimeUnit {
    enum second;
    enum millisecond;
    enum minute;
    enum hour;
  }

  enum def VoltageUnit {
    enum volt;
    enum millivolt;
  }

  enum def CurrentUnit {
    enum ampere;
    enum microampere;
    enum nanoampere;
  }

  enum def ResistanceUnit {
    enum ohm;
    enum kiloohm;
  }

  enum def PowerUnit {
    enum watt;
    enum milliwatt;
  }

  enum def DigitalBusKind {
    enum i2c;
    enum spi;
    enum uart;
  }

  enum def SensorHealthCode {
    enum normal;
    enum warmup;
    enum calibrationDue;
    enum overRange;
    enum sensorOpenCircuit;
    enum sensorShortCircuit;
    enum electrolyteDepleted;
    enum excessiveTemperature;
    enum excessiveHumidity;
    enum powerFault;
    enum measurementInvalid;
  }

  attribute def GasConcentration {
    attribute value : Real;
    attribute unit : ConcentrationUnit;
  }

  attribute def Temperature {
    attribute value : Real;
    attribute unit : TemperatureUnit;
  }

  attribute def Pressure {
    attribute value : Real;
    attribute unit : PressureUnit;
  }

  attribute def RelativeHumidity {
    attribute value : Real;
    attribute unit : HumidityUnit;
  }

  attribute def Duration {
    attribute value : Real;
    attribute unit : TimeUnit;
  }

  attribute def Voltage {
    attribute value : Real;
    attribute unit : VoltageUnit;
  }

  attribute def ElectricCurrent {
    attribute value : Real;
    attribute unit : CurrentUnit;
  }

  attribute def ElectricalResistance {
    attribute value : Real;
    attribute unit : ResistanceUnit;
  }

  attribute def ElectricalPower {
    attribute value : Real;
    attribute unit : PowerUnit;
  }

  attribute def Fraction {
    attribute value : Real;
  }

  item def GasMixture {
    attribute targetGas : GasSpecies;
    attribute targetConcentration : GasConcentration;
    attribute oxygenConcentration : GasConcentration;
    attribute temperature : Temperature;
    attribute pressure : Pressure;
    attribute relativeHumidity : RelativeHumidity;
    attribute interferingGasConcentration : GasConcentration;
  }

  item def ElectricalSupply {
    attribute nominalVoltage : Voltage;
    attribute availableCurrent : ElectricCurrent;
    attribute powerGood : Boolean;
  }

  item def BiasCommand {
    attribute workingElectrodeBias : Voltage;
    attribute counterElectrodeDriveLimit : Voltage;
    attribute enabled : Boolean;
  }

  item def SensorCurrentSignal {
    attribute measuredCurrent : ElectricCurrent;
    attribute noiseRms : ElectricCurrent;
    attribute saturated : Boolean;
    attribute timestampSeconds : Real;
  }

  item def AnalogVoltageSignal {
    attribute voltage : Voltage;
    attribute valid : Boolean;
  }

  item def DigitalSample {
    attribute rawAdcCode : Integer;
    attribute adcResolutionBits : Integer;
    attribute samplePeriod : Duration;
    attribute valid : Boolean;
  }

  item def EnvironmentalSample {
    attribute temperature : Temperature;
    attribute relativeHumidity : RelativeHumidity;
    attribute pressure : Pressure;
    attribute valid : Boolean;
  }

  item def GasMeasurementFrame {
    attribute gas : GasSpecies;
    attribute concentration : GasConcentration;
    attribute compensatedConcentration : GasConcentration;
    attribute temperature : Temperature;
    attribute relativeHumidity : RelativeHumidity;
    attribute pressure : Pressure;
    attribute responseTime : Duration;
    attribute health : SensorHealthCode;
    attribute calibrationAge : Duration;
    attribute sequenceNumber : Integer;
    attribute valid : Boolean;
  }

  item def CalibrationRecord {
    attribute gas : GasSpecies;
    attribute zeroOffsetCurrent : ElectricCurrent;
    attribute sensitivity : Real;
    attribute sensitivityUnit : String;
    attribute temperatureCoefficient : Real;
    attribute humidityCoefficient : Real;
    attribute spanGasConcentration : GasConcentration;
    attribute calibrationInterval : Duration;
    attribute age : Duration;
    attribute valid : Boolean;
  }

  item def DiagnosticEvent {
    attribute health : SensorHealthCode;
    attribute severity : Integer;
    attribute latched : Boolean;
    attribute messageId : Integer;
  }

  port def GasInletPort {
    in item gas : GasMixture;
  }

  port def VentPort {
    out item gas : GasMixture;
  }

  port def PowerInputPort {
    in item supply : ElectricalSupply;
  }

  port def BiasControlPort {
    in item command : BiasCommand;
  }

  port def ElectrodeCurrentPort {
    out item signal : SensorCurrentSignal;
  }

  port def AnalogVoltagePort {
    out item signal : AnalogVoltageSignal;
  }

  port def DigitalSamplePort {
    out item sample : DigitalSample;
  }

  port def EnvironmentalPort {
    out item environment : EnvironmentalSample;
  }

  port def MeasurementDataPort {
    out item frame : GasMeasurementFrame;
  }

  port def DiagnosticPort {
    out item event : DiagnosticEvent;
  }

  port def CalibrationPort {
    in item record : CalibrationRecord;
  }

  port def DigitalControlPort {
    attribute busKind : DigitalBusKind;
    in item commandFrame : String;
    out item responseFrame : String;
  }

  constraint def WithinConcentrationRange {
    in c : GasConcentration;
    in lower : GasConcentration;
    in upper : GasConcentration;
    constraint { c.value >= lower.value and c.value <= upper.value }
  }

  constraint def MeetsAccuracy {
    in indicated : GasConcentration;
    in reference : GasConcentration;
    in allowableError : GasConcentration;
    constraint { indicated.value - reference.value <= allowableError.value and reference.value - indicated.value <= allowableError.value }
  }

  constraint def ValidOperatingEnvironment {
    in t : Temperature;
    in rh : RelativeHumidity;
    in p : Pressure;
    constraint { t.value >= -20.0 and t.value <= 50.0 and rh.value >= 15.0 and rh.value <= 95.0 and p.value >= 80.0 and p.value <= 120.0 }
  }

  action def PolarizeElectrochemicalCell {
    in item supply : ElectricalSupply;
    in item calibration : CalibrationRecord;
    out item bias : BiasCommand;
    attribute requiredBias : Voltage = (value = 0.0, unit = VoltageUnit::millivolt);
    attribute stabilizationTime : Duration = (value = 60.0, unit = TimeUnit::second);
  }

  action def SampleSensorCurrent {
    in item current : SensorCurrentSignal;
    out item digital : DigitalSample;
    attribute oversampleCount : Integer = 32;
    attribute samplePeriod : Duration = (value = 1.0, unit = TimeUnit::second);
  }

  action def ConvertCurrentToConcentration {
    in item current : SensorCurrentSignal;
    in item calibration : CalibrationRecord;
    out item concentration : GasConcentration;
    attribute conversionLaw : String = "concentration_ppm = (current_uA - zeroOffset_uA) / sensitivity_uA_per_ppm";
  }

  action def CompensateForEnvironment {
    in item uncompensated : GasConcentration;
    in item environment : EnvironmentalSample;
    in item calibration : CalibrationRecord;
    out item compensated : GasConcentration;
    attribute compensationLaw : String = "compensated = uncompensated / (1 + temperatureCoefficient*(T_C-20) + humidityCoefficient*(RH_percent-50))";
  }

  action def EvaluateDiagnostics {
    in item current : SensorCurrentSignal;
    in item environment : EnvironmentalSample;
    in item concentration : GasConcentration;
    in item calibration : CalibrationRecord;
    out item event : DiagnosticEvent;
  }

  action def PublishMeasurement {
    in item concentration : GasConcentration;
    in item compensated : GasConcentration;
    in item environment : EnvironmentalSample;
    in item diagnostic : DiagnosticEvent;
    out item frame : GasMeasurementFrame;
  }

  action def MeasurementCycle {
    in item gas : GasMixture;
    in item supply : ElectricalSupply;
    in item calibration : CalibrationRecord;
    out item measurement : GasMeasurementFrame;

    action polarize : PolarizeElectrochemicalCell;
    action sample : SampleSensorCurrent;
    action convert : ConvertCurrentToConcentration;
    action compensate : CompensateForEnvironment;
    action diagnose : EvaluateDiagnostics;
    action publish : PublishMeasurement;

    flow supply to polarize.supply;
    flow calibration to polarize.calibration;
    flow calibration to convert.calibration;
    flow calibration to compensate.calibration;
    flow calibration to diagnose.calibration;
    flow sample.current to convert.current;
    flow convert.concentration to compensate.uncompensated;
    flow convert.concentration to diagnose.concentration;
    flow compensate.compensated to publish.compensated;
    flow convert.concentration to publish.concentration;
    flow diagnose.event to publish.diagnostic;
    flow publish.frame to measurement;
  }

  state def SensingUnitStateMachine {
    state off;
    state powerValidation;
    state sensorWarmup;
    state zeroStabilization;
    state measuring;
    state diagnosticHold;
    state calibrationMode;
    state faultLatched;

    transition initial then off;
    transition off_to_powerValidation first off then powerValidation;
    transition powerValidation_to_sensorWarmup first powerValidation then sensorWarmup;
    transition sensorWarmup_to_zeroStabilization first sensorWarmup then zeroStabilization;
    transition zeroStabilization_to_measuring first zeroStabilization then measuring;
    transition measuring_to_diagnosticHold first measuring then diagnosticHold;
    transition diagnosticHold_to_measuring first diagnosticHold then measuring;
    transition measuring_to_calibrationMode first measuring then calibrationMode;
    transition calibrationMode_to_zeroStabilization first calibrationMode then zeroStabilization;
    transition powerValidation_to_faultLatched first powerValidation then faultLatched;
    transition measuring_to_faultLatched first measuring then faultLatched;
    transition faultLatched_to_off first faultLatched then off;
  }

  part def DiffusionBarrier {
    attribute poreDiameter : Real = 0.25;
    attribute poreDiameterUnit : String = "mm";
    attribute hydrophobic : Boolean = true;
    attribute dustRetentionEfficiency : Fraction = (value = 0.95);
    port ambientGas : GasInletPort;
    port filteredGas : VentPort;
  }

  part def ElectrochemicalGasSensor {
    attribute sensedQuantity : String = "target gas concentration";
    attribute sensorPrinciple : String = "electrochemical amperometric cell";
    attribute targetGas : GasSpecies = GasSpecies::carbonMonoxide;
    attribute measurementRangeLower : GasConcentration = (value = 0.0, unit = ConcentrationUnit::ppm);
    attribute measurementRangeUpper : GasConcentration = (value = 500.0, unit = ConcentrationUnit::ppm);
    attribute detectionLimit : GasConcentration = (value = 1.0, unit = ConcentrationUnit::ppm);
    attribute nominalSensitivity : Real = 0.070;
    attribute nominalSensitivityUnit : String = "microampere_per_ppm";
    attribute t90ResponseTime : Duration = (value = 30.0, unit = TimeUnit::second);
    attribute expectedLife : Duration = (value = 24.0, unit = TimeUnit::month);
    attribute requiredBias : Voltage = (value = 0.0, unit = VoltageUnit::millivolt);
    attribute electrolytePresent : Boolean = true;
    attribute crossSensitivityToHydrogen : Fraction = (value = 0.15);

    part workingElectrode;
    part counterElectrode;
    part referenceElectrode;
    part electrolyteReservoir;
    part gasDiffusionMembrane;

    port gasExposure : GasInletPort;
    port bias : BiasControlPort;
    port cellCurrent : ElectrodeCurrentPort;
    port exhaust : VentPort;
  }

  part def PotentiostatAnalogFrontEnd {
    attribute transimpedanceResistance : ElectricalResistance = (value = 100.0, unit = ResistanceUnit::kiloohm);
    attribute inputBiasCurrent : ElectricCurrent = (value = 5.0, unit = CurrentUnit::nanoampere);
    attribute outputNoiseRms : Voltage = (value = 1.0, unit = VoltageUnit::millivolt);
    attribute maintainsReferencePotential : Boolean = true;

    port power : PowerInputPort;
    port biasOut : BiasControlPort;
    port currentIn : ElectrodeCurrentPort;
    port voltageOut : AnalogVoltagePort;
  }

  part def AnalogToDigitalConverter {
    attribute resolutionBits : Integer = 16;
    attribute referenceVoltage : Voltage = (value = 2.5, unit = VoltageUnit::volt);
    attribute sampleRate : Real = 4.0;
    attribute sampleRateUnit : String = "samples_per_second";

    port analogIn : AnalogVoltagePort;
    port sampleOut : DigitalSamplePort;
    port power : PowerInputPort;
  }

  part def TemperatureHumidityPressureSensor {
    attribute temperatureAccuracy : Temperature = (value = 0.5, unit = TemperatureUnit::degC);
    attribute humidityAccuracy : RelativeHumidity = (value = 3.0, unit = HumidityUnit::percentRH);
    attribute pressureAccuracy : Pressure = (value = 1.0, unit = PressureUnit::kPa);

    port environmentOut : EnvironmentalPort;
    port power : PowerInputPort;
  }

  part def Microcontroller {
    attribute clockFrequencyMHz : Real = 48.0;
    attribute firmwareName : String = "ElectrochemicalGasMeasurementFirmware";
    attribute firmwareVersion : String = "1.2.0";
    attribute outputUpdatePeriod : Duration = (value = 1.0, unit = TimeUnit::second);
    attribute diagnosticPeriod : Duration = (value = 5.0, unit = TimeUnit::second);

    port power : PowerInputPort;
    port adcIn : DigitalSamplePort;
    port environmentIn : EnvironmentalPort;
    port calibrationIn : CalibrationPort;
    port hostBus : DigitalControlPort;
    port measurementOut : MeasurementDataPort;
    port diagnosticOut : DiagnosticPort;

    perform action measurementCycle : MeasurementCycle;
    exhibit state behavior : SensingUnitStateMachine;
  }

  part def CalibrationMemory {
    attribute nonvolatile : Boolean = true;
    attribute retainedRecord : CalibrationRecord = (
      gas = GasSpecies::carbonMonoxide,
      zeroOffsetCurrent = (value = 0.020, unit = CurrentUnit::microampere),
      sensitivity = 0.070,
      sensitivityUnit = "microampere_per_ppm",
      temperatureCoefficient = 0.004,
      humidityCoefficient = 0.001,
      spanGasConcentration = (value = 100.0, unit = ConcentrationUnit::ppm),
      calibrationInterval = (value = 180.0, unit = TimeUnit::day),
      age = (value = 15.0, unit = TimeUnit::day),
      valid = true
    );

    port calibrationOut : CalibrationPort;
    port power : PowerInputPort;
  }

  part def PowerConditioner {
    attribute inputVoltageMin : Voltage = (value = 3.0, unit = VoltageUnit::volt);
    attribute inputVoltageMax : Voltage = (value = 5.5, unit = VoltageUnit::volt);
    attribute regulatedVoltage : Voltage = (value = 3.3, unit = VoltageUnit::volt);
    attribute maximumOutputCurrent : ElectricCurrent = (value = 50.0, unit = CurrentUnit::milliampere);
    attribute quiescentPower : ElectricalPower = (value = 5.0, unit = PowerUnit::milliwatt);

    port unregulatedPower : PowerInputPort;
    port regulatedPower : PowerInputPort;
    port diagnosticOut : DiagnosticPort;
  }

  part def GasSensingUnit {
    attribute measuredQuantity : String = "concentration of target gas in ambient air";
    attribute targetGas : GasSpecies = GasSpecies::carbonMonoxide;
    attribute concentrationRangeLower : GasConcentration = (value = 0.0, unit = ConcentrationUnit::ppm);
    attribute concentrationRangeUpper : GasConcentration = (value = 500.0, unit = ConcentrationUnit::ppm);
    attribute maximumAllowedError : GasConcentration = (value = 5.0, unit = ConcentrationUnit::ppm);
    attribute maximumT90ResponseTime : Duration = (value = 45.0, unit = TimeUnit::second);
    attribute outputPeriod : Duration = (value = 1.0, unit = TimeUnit::second);
    attribute operatingTemperatureMin : Temperature = (value = -20.0, unit = TemperatureUnit::degC);
    attribute operatingTemperatureMax : Temperature = (value = 50.0, unit = TemperatureUnit::degC);
    attribute operatingHumidityMin : RelativeHumidity = (value = 15.0, unit = HumidityUnit::percentRH);
    attribute operatingHumidityMax : RelativeHumidity = (value = 95.0, unit = HumidityUnit::percentRH);

    port ambientGasIn : GasInletPort;
    port gasVent : VentPort;
    port inputPower : PowerInputPort;
    port hostInterface : DigitalControlPort {
      :>> busKind = DigitalBusKind::i2c;
    }
    port measurementOut : MeasurementDataPort;
    port diagnosticsOut : DiagnosticPort;
    port calibrationIn : CalibrationPort;

    part inletFilter : DiffusionBarrier;
    part electrochemicalSensor : ElectrochemicalGasSensor;
    part potentiostat : PotentiostatAnalogFrontEnd;
    part adc : AnalogToDigitalConverter;
    part environmentSensor : TemperatureHumidityPressureSensor;
    part controller : Microcontroller;
    part calibrationMemory : CalibrationMemory;
    part powerConditioner : PowerConditioner;

    connect ambientGasIn to inletFilter.ambientGas;
    connect inletFilter.filteredGas to electrochemicalSensor.gasExposure;
    connect electrochemicalSensor.exhaust to gasVent;

    connect inputPower to powerConditioner.unregulatedPower;
    connect powerConditioner.regulatedPower to potentiostat.power;
    connect powerConditioner.regulatedPower to adc.power;
    connect powerConditioner.regulatedPower to environmentSensor.power;
    connect powerConditioner.regulatedPower to controller.power;
    connect powerConditioner.regulatedPower to calibrationMemory.power;

    connect potentiostat.biasOut to electrochemicalSensor.bias;
    connect electrochemicalSensor.cellCurrent to potentiostat.currentIn;
    connect potentiostat.voltageOut to adc.analogIn;
    connect adc.sampleOut to controller.adcIn;
    connect environmentSensor.environmentOut to controller.environmentIn;
    connect calibrationMemory.calibrationOut to controller.calibrationIn;
    connect calibrationIn to controller.calibrationIn;
    connect controller.hostBus to hostInterface;
    connect controller.measurementOut to measurementOut;
    connect controller.diagnosticOut to diagnosticsOut;
    connect powerConditioner.diagnosticOut to diagnosticsOut;

    perform action measurementCycle : MeasurementCycle;
    exhibit state operatingState : SensingUnitStateMachine;
  }

  requirement def UseElectrochemicalGasSensorRequirement {
    subject unit : GasSensingUnit;
    require constraint { unit.electrochemicalSensor.sensorPrinciple == "electrochemical amperometric cell" }
  }

  requirement def MeasureGasConcentrationRequirement {
    subject unit : GasSensingUnit;
    require constraint { unit.measuredQuantity == "concentration of target gas in ambient air" }
  }

  requirement def MeasurementRangeRequirement {
    subject unit : GasSensingUnit;
    require constraint {
      unit.concentrationRangeLower.value <= 0.0 and unit.concentrationRangeUpper.value >= 500.0
    }
  }

  requirement def AccuracyRequirement {
    subject unit : GasSensingUnit;
    require constraint { unit.maximumAllowedError.value <= 5.0 }
  }

  requirement def ResponseTimeRequirement {
    subject unit : GasSensingUnit;
    require constraint { unit.maximumT90ResponseTime.value <= 45.0 }
  }

  requirement def EnvironmentalCompensationRequirement {
    subject unit : GasSensingUnit;
    require constraint {
      unit.environmentSensor.temperatureAccuracy.value <= 0.5 and
      unit.environmentSensor.humidityAccuracy.value <= 3.0 and
      unit.environmentSensor.pressureAccuracy.value <= 1.0
    }
  }

  requirement def DiagnosticRequirement {
    subject unit : GasSensingUnit;
    require constraint {
      unit.controller.diagnosticPeriod.value <= 5.0
    }
  }

  requirement def OutputUpdateRequirement {
    subject unit : GasSensingUnit;
    require constraint { unit.outputPeriod.value <= 1.0 }
  }

  requirement useElectrochemicalGasSensor : UseElectrochemicalGasSensorRequirement {
    subject unit = sensingUnit;
  }

  requirement measureGasConcentration : MeasureGasConcentrationRequirement {
    subject unit = sensingUnit;
  }

  requirement measurementRange : MeasurementRangeRequirement {
    subject unit = sensingUnit;
  }

  requirement accuracy : AccuracyRequirement {
    subject unit = sensingUnit;
  }

  requirement responseTime : ResponseTimeRequirement {
    subject unit = sensingUnit;
  }

  requirement environmentalCompensation : EnvironmentalCompensationRequirement {
    subject unit = sensingUnit;
  }

  requirement diagnostics : DiagnosticRequirement {
    subject unit = sensingUnit;
  }

  requirement outputUpdate : OutputUpdateRequirement {
    subject unit = sensingUnit;
  }

  part sensingUnit : GasSensingUnit;

  satisfy useElectrochemicalGasSensor by sensingUnit.electrochemicalSensor;
  satisfy measureGasConcentration by sensingUnit;
  satisfy measurementRange by sensingUnit.electrochemicalSensor;
  satisfy accuracy by sensingUnit.controller;
  satisfy responseTime by sensingUnit.electrochemicalSensor;
  satisfy environmentalCompensation by sensingUnit.environmentSensor;
  satisfy diagnostics by sensingUnit.controller;
  satisfy outputUpdate by sensingUnit.controller;
}
