package PhotoionizationDetectorModel {

  import ScalarValues::*;

  attribute def Voltage_V :> Real;
  attribute def Current_nA :> Real;
  attribute def Concentration_ppm :> Real;
  attribute def FlowRate_mL_per_min :> Real;
  attribute def Temperature_degC :> Real;
  attribute def Pressure_kPa :> Real;
  attribute def Energy_eV :> Real;
  attribute def Time_s :> Real;
  attribute def Percent :> Real;

  item def AmbientAirSample {
    attribute vocConcentration : Concentration_ppm;
    attribute humidity : Percent;
    attribute temperature : Temperature_degC;
    attribute pressure : Pressure_kPa;
    attribute flowRate : FlowRate_mL_per_min;
  }

  item def IonizedGas {
    attribute ionCurrent : Current_nA;
    attribute residualVocConcentration : Concentration_ppm;
  }

  item def DetectionResult {
    attribute measuredVocConcentration : Concentration_ppm;
    attribute rawIonCurrent : Current_nA;
    attribute confidence : Percent;
    attribute alarmActive : Boolean;
  }

  item def ElectricalPower {
    attribute supplyVoltage : Voltage_V;
    attribute availableCurrent : Current_nA;
  }

  item def ControlCommand {
    attribute enableMeasurement : Boolean;
    attribute requestCalibration : Boolean;
    attribute alarmThreshold : Concentration_ppm;
  }

  port def GasInletPort {
    in item sample : AmbientAirSample;
  }

  port def GasOutletPort {
    out item exhaust : AmbientAirSample;
  }

  port def IonSignalPort {
    out item ionizedGasSignal : IonizedGas;
  }

  port def ResultPort {
    out item result : DetectionResult;
  }

  port def PowerPort {
    in item power : ElectricalPower;
  }

  port def CommandPort {
    in item command : ControlCommand;
  }

  part def PhotoionizationDetector {

    attribute primaryFunction : String =
      "Detect volatile organic compounds in sampled air by exposing the sample to ultraviolet photons, collecting the resulting ionization current, and converting that signal into a gas concentration estimate.";

    attribute measurementRangeLow : Concentration_ppm = 0.0;
    attribute measurementRangeHigh : Concentration_ppm = 2000.0;
    attribute alarmThreshold : Concentration_ppm = 50.0;
    attribute responseTime : Time_s = 3.0;

    port gasIn : GasInletPort;
    port gasOut : GasOutletPort;
    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port resultOut : ResultPort;

    part pump : SamplingPump;
    part filter : ParticulateFilter;
    part uvLamp : UltravioletLamp;
    part ionizationChamber : IonizationChamber;
    part electrodes : CollectorElectrodes;
    part amplifier : ElectrometerAmplifier;
    part processor : SignalProcessor;
    part alarm : AlarmIndicator;
    part enclosure : ProtectiveEnclosure;

    connect gasIn to filter.sampleIn;
    connect filter.sampleOut to pump.sampleIn;
    connect pump.sampleOut to ionizationChamber.sampleIn;
    connect ionizationChamber.sampleOut to gasOut;

    connect uvLamp.photonOutput to ionizationChamber.photonInput;
    connect ionizationChamber.ionSignal to electrodes.ionInput;
    connect electrodes.currentOutput to amplifier.currentInput;
    connect amplifier.voltageOutput to processor.signalInput;
    connect processor.resultOutput to resultOut;
    connect processor.alarmOutput to alarm.alarmInput;

    connect powerIn to pump.powerIn;
    connect powerIn to uvLamp.powerIn;
    connect powerIn to amplifier.powerIn;
    connect powerIn to processor.powerIn;
    connect powerIn to alarm.powerIn;

    connect commandIn to processor.commandIn;

    perform action analyzeSample : AnalyzeAirSample;
    exhibit state operatingState : PIDOperatingState;
  }

  part def SamplingPump {
    attribute nominalFlowRate : FlowRate_mL_per_min = 500.0;
    attribute flowTolerance : Percent = 10.0;

    port sampleIn : GasInletPort;
    port sampleOut : GasOutletPort;
    port powerIn : PowerPort;
  }

  part def ParticulateFilter {
    attribute removalEfficiency : Percent = 95.0;

    port sampleIn : GasInletPort;
    port sampleOut : GasOutletPort;
  }

  part def UltravioletLamp {
    attribute photonEnergy : Energy_eV = 10.6;
    attribute warmupTime : Time_s = 30.0;
    attribute lampIntensity : Real = 1.0;

    port powerIn : PowerPort;
    port photonOutput : PhotonPort;
  }

  port def PhotonPort {
    out item photons : UltravioletPhotonFlux;
  }

  item def UltravioletPhotonFlux {
    attribute photonEnergy : Energy_eV;
    attribute relativeIntensity : Real;
  }

  part def IonizationChamber {
    attribute chamberPressure : Pressure_kPa = 101.3;
    attribute chamberTemperature : Temperature_degC = 25.0;

    port sampleIn : GasInletPort;
    port sampleOut : GasOutletPort;
    port photonInput : PhotonPort;
    port ionSignal : IonSignalPort;
  }

  part def CollectorElectrodes {
    attribute biasVoltage : Voltage_V = 120.0;

    port ionInput : IonSignalPort;
    port currentOutput : CurrentSignalPort;
  }

  port def CurrentSignalPort {
    out item signal : IonCurrentSignal;
  }

  item def IonCurrentSignal {
    attribute current : Current_nA;
    attribute noise : Current_nA;
  }

  part def ElectrometerAmplifier {
    attribute gain : Real = 1000000000.0;
    attribute inputBiasCurrent : Current_nA = 0.01;

    port powerIn : PowerPort;
    port currentInput : CurrentSignalPort;
    port voltageOutput : VoltageSignalPort;
  }

  port def VoltageSignalPort {
    out item signal : VoltageSignal;
  }

  item def VoltageSignal {
    attribute voltage : Voltage_V;
    attribute offset : Voltage_V;
  }

  part def SignalProcessor {
    attribute calibrationSlope : Real = 1.0;
    attribute calibrationOffset : Concentration_ppm = 0.0;
    attribute alarmThreshold : Concentration_ppm = 50.0;

    port powerIn : PowerPort;
    port commandIn : CommandPort;
    port signalInput : VoltageSignalPort;
    port resultOutput : ResultPort;
    port alarmOutput : AlarmCommandPort;
  }

  port def AlarmCommandPort {
    out item alarmCommand : AlarmCommand;
  }

  item def AlarmCommand {
    attribute active : Boolean;
    attribute measuredConcentration : Concentration_ppm;
  }

  part def AlarmIndicator {
    port powerIn : PowerPort;
    port alarmInput : AlarmCommandPort;

    attribute audibleLevelEnabled : Boolean = true;
    attribute visualIndicatorEnabled : Boolean = true;
  }

  part def ProtectiveEnclosure {
    attribute ingressProtectionRating : String = "IP54";
    attribute operatingTemperatureLow : Temperature_degC = -10.0;
    attribute operatingTemperatureHigh : Temperature_degC = 45.0;
  }

  action def AnalyzeAirSample {
    in item sample : AmbientAirSample;
    in item command : ControlCommand;
    out item result : DetectionResult;

    action drawSample;
    action removeParticulates;
    action exposeToUvPhotons;
    action collectIonCurrent;
    action amplifySignal;
    action compensateForHumidityAndTemperature;
    action convertSignalToConcentration;
    action compareToAlarmThreshold;

    first start;
    then drawSample;
    then removeParticulates;
    then exposeToUvPhotons;
    then collectIonCurrent;
    then amplifySignal;
    then compensateForHumidityAndTemperature;
    then convertSignalToConcentration;
    then compareToAlarmThreshold;
    then done;
  }

  state def PIDOperatingState {
    state off;
    state warmup;
    state ready;
    state sampling;
    state alarm;
    state calibration;
    state fault;

    transition initial then off;

    transition powerApplied
      first off
      then warmup;

    transition lampStable
      first warmup
      then ready;

    transition measurementEnabled
      first ready
      then sampling;

    transition concentrationBelowThreshold
      first sampling
      then ready;

    transition concentrationAboveThreshold
      first sampling
      then alarm;

    transition alarmCleared
      first alarm
      then ready;

    transition calibrationRequested
      first ready
      then calibration;

    transition calibrationComplete
      first calibration
      then ready;

    transition unrecoverableFailure
      first warmup
      then fault;

    transition sensorFailure
      first sampling
      then fault;

    transition powerRemoved
      first ready
      then off;
  }

  requirement def PrimaryFunctionRequirement {
    doc
      /* The photoionization detector shall provide high-level detection of volatile organic compounds in ambient air by drawing a sample, ionizing compounds whose ionization potential is below the ultraviolet lamp photon energy, measuring ion current, and reporting concentration. */

    subject detector : PhotoionizationDetector;

    require constraint {
      detector.measurementRangeLow <= 0.0 and
      detector.measurementRangeHigh >= 2000.0 and
      detector.responseTime <= 3.0
    }
  }

  requirement def FlowControlRequirement {
    subject pump : SamplingPump;

    require constraint {
      pump.nominalFlowRate >= 450.0 and
      pump.nominalFlowRate <= 550.0
    }
  }

  requirement def LampEnergyRequirement {
    subject lamp : UltravioletLamp;

    require constraint {
      lamp.photonEnergy == 10.6
    }
  }

  requirement def AlarmRequirement {
    subject detector : PhotoionizationDetector;

    require constraint {
      detector.alarmThreshold >= detector.measurementRangeLow and
      detector.alarmThreshold <= detector.measurementRangeHigh
    }
  }

  part pidSystem : PhotoionizationDetector {
    attribute measurementRangeLow = 0.0;
    attribute measurementRangeHigh = 2000.0;
    attribute alarmThreshold = 50.0;
    attribute responseTime = 3.0;
  }

}