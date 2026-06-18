package GeigerCounterSystemModel {

  import ScalarValues::*;
  import SI::*;

  doc /*
   A portable Geiger counter whose primary function is to detect incident ionizing
   radiation with a Geiger-Mueller tube, convert detector discharges into counted
   pulses, estimate count rate and dose-equivalent rate, and report radiation
   status to the user through visual and audible outputs.
  */

  package Units {
    unit def count;
    unit def countPerSecond;
    unit def countPerMinute;
    unit def electronVolt;
    unit def kiloElectronVolt;
    unit def sievert;
    unit def microSievert;
    unit def microSievertPerHour;
    unit def volt;
    unit def milliVolt;
    unit def ampere;
    unit def milliAmpere;
    unit def microAmpere;
    unit def ohm;
    unit def second;
    unit def millisecond;
    unit def microsecond;
    unit def hour;
    unit def percent;
    unit def decibel;
    unit def lumen;
    unit def byte;
    unit def degreeCelsius;
  }

  enum def RadiationKind {
    enum alpha;
    enum beta;
    enum gamma;
    enum xRay;
    enum neutron;
    enum mixed;
  }

  enum def UserCommandKind {
    enum powerOn;
    enum powerOff;
    enum muteAlarm;
    enum unmuteAlarm;
    enum resetDose;
    enum startSelfTest;
    enum changeDisplayMode;
  }

  enum def DisplayMode {
    enum doseRate;
    enum countRate;
    enum accumulatedDose;
    enum diagnostic;
  }

  enum def AlarmLevel {
    enum normal;
    enum elevated;
    enum high;
    enum critical;
    enum fault;
  }

  enum def HealthState {
    enum healthy;
    enum degraded;
    enum failed;
  }

  attribute def CountRate :> Real;
  attribute def DoseEquivalentRate :> Real;
  attribute def AccumulatedDose :> Real;
  attribute def ElectricalVoltage :> Real;
  attribute def ElectricalCurrent :> Real;
  attribute def TimeDuration :> Real;
  attribute def RadiationEnergy :> Real;
  attribute def Probability :> Real;
  attribute def SoundPressureLevel :> Real;
  attribute def Temperature :> Real;

  item def IonizingRadiation {
    attribute kind : RadiationKind = RadiationKind::mixed;
    attribute averageEnergy : RadiationEnergy = 662 [Units::kiloElectronVolt];
    attribute fluenceRate : Real = 0.0;
    attribute ambientDoseEquivalentRate : DoseEquivalentRate = 0.0 [Units::microSievertPerHour];
  }

  item def DetectorPulse {
    attribute amplitude : ElectricalVoltage = 5.0 [Units::volt];
    attribute width : TimeDuration = 120 [Units::microsecond];
    attribute timestamp : TimeDuration = 0 [Units::millisecond];
    attribute accepted : Boolean = true;
  }

  item def LogicPulse {
    attribute levelHigh : ElectricalVoltage = 3.3 [Units::volt];
    attribute width : TimeDuration = 2 [Units::millisecond];
    attribute timestamp : TimeDuration = 0 [Units::millisecond];
  }

  item def ElectricalPower {
    attribute voltage : ElectricalVoltage = 3.7 [Units::volt];
    attribute currentLimit : ElectricalCurrent = 500 [Units::milliAmpere];
    attribute available : Boolean = true;
  }

  item def HighVoltageBias {
    attribute voltage : ElectricalVoltage = 400 [Units::volt];
    attribute currentLimit : ElectricalCurrent = 50 [Units::microAmpere];
    attribute ripple : ElectricalVoltage = 5 [Units::volt];
    attribute enabled : Boolean = true;
  }

  item def UserCommand {
    attribute kind : UserCommandKind;
    attribute requestedDisplayMode : DisplayMode = DisplayMode::doseRate;
  }

  item def RadiationReading {
    attribute countRate : CountRate = 0.0 [Units::countPerSecond];
    attribute doseEquivalentRate : DoseEquivalentRate = 0.0 [Units::microSievertPerHour];
    attribute accumulatedDose : AccumulatedDose = 0.0 [Units::microSievert];
    attribute alarmLevel : AlarmLevel = AlarmLevel::normal;
    attribute displayMode : DisplayMode = DisplayMode::doseRate;
    attribute valid : Boolean = false;
  }

  item def AlarmSignal {
    attribute level : AlarmLevel = AlarmLevel::normal;
    attribute audibleEnabled : Boolean = true;
    attribute soundLevel : SoundPressureLevel = 0 [Units::decibel];
    attribute pulsePeriod : TimeDuration = 1000 [Units::millisecond];
  }

  item def DiagnosticStatus {
    attribute health : HealthState = HealthState::healthy;
    attribute batteryVoltage : ElectricalVoltage = 3.7 [Units::volt];
    attribute detectorVoltage : ElectricalVoltage = 400 [Units::volt];
    attribute backgroundCountRate : CountRate = 0.2 [Units::countPerSecond];
    attribute faultCode : Integer = 0;
  }

  port def RadiationInputPort {
    in item incidentRadiation : IonizingRadiation;
  }

  port def RawPulseOutputPort {
    out item detectorPulse : DetectorPulse;
  }

  port def RawPulseInputPort {
    in item detectorPulse : DetectorPulse;
  }

  port def LogicPulseOutputPort {
    out item logicPulse : LogicPulse;
  }

  port def LogicPulseInputPort {
    in item logicPulse : LogicPulse;
  }

  port def LowVoltagePowerOutputPort {
    out item power : ElectricalPower;
  }

  port def LowVoltagePowerInputPort {
    in item power : ElectricalPower;
  }

  port def HighVoltageOutputPort {
    out item bias : HighVoltageBias;
  }

  port def HighVoltageInputPort {
    in item bias : HighVoltageBias;
  }

  port def UserControlInputPort {
    in item command : UserCommand;
  }

  port def ReadingOutputPort {
    out item reading : RadiationReading;
  }

  port def ReadingInputPort {
    in item reading : RadiationReading;
  }

  port def AlarmOutputPort {
    out item alarm : AlarmSignal;
  }

  port def AlarmInputPort {
    in item alarm : AlarmSignal;
  }

  port def DiagnosticOutputPort {
    out item status : DiagnosticStatus;
  }

  action def IonizationToPulse {
    in item radiation : IonizingRadiation;
    in item bias : HighVoltageBias;
    out item pulse : DetectorPulse;

    attribute tubeTriggered : Boolean;
    attribute avalancheQuenched : Boolean;
    attribute deadTime : TimeDuration = 90 [Units::microsecond];

    doc /*
     Incident ionizing radiation creates primary ionization in the fill gas.
     With the high-voltage bias in the Geiger plateau, the tube produces a
     standardized discharge pulse that is independent of particle energy.
    */
  }

  action def ShapeDetectorPulse {
    in item rawPulse : DetectorPulse;
    out item logicPulse : LogicPulse;

    attribute threshold : ElectricalVoltage = 80 [Units::milliVolt];
    attribute debounceTime : TimeDuration = 120 [Units::microsecond];
    attribute rejectAfterpulseWindow : TimeDuration = 250 [Units::microsecond];
  }

  action def ComputeDoseEquivalentRate {
    in item pulse : LogicPulse;
    out item reading : RadiationReading;

    attribute integrationWindow : TimeDuration = 10 [Units::second];
    attribute calibrationFactor : Real = 0.0057;
    attribute backgroundCountRate : CountRate = 0.20 [Units::countPerSecond];
    attribute deadTimeCompensation : Boolean = true;

    doc /*
     Counts accepted logic pulses over a rolling window, compensates for tube
     dead time, subtracts stored background estimate, and applies the tube
     calibration factor to estimate dose-equivalent rate in microSievert per hour.
    */
  }

  action def PresentRadiationStatus {
    in item reading : RadiationReading;
    out item displayReading : RadiationReading;
    out item alarm : AlarmSignal;

    attribute normalThreshold : DoseEquivalentRate = 0.50 [Units::microSievertPerHour];
    attribute elevatedThreshold : DoseEquivalentRate = 1.00 [Units::microSievertPerHour];
    attribute highThreshold : DoseEquivalentRate = 10.0 [Units::microSievertPerHour];
    attribute criticalThreshold : DoseEquivalentRate = 100.0 [Units::microSievertPerHour];
  }

  action def RunSelfTest {
    out item status : DiagnosticStatus;

    attribute verifyBattery : Boolean = true;
    attribute verifyHighVoltage : Boolean = true;
    attribute injectTestPulse : Boolean = true;
    attribute verifyDisplay : Boolean = true;
    attribute verifyAudio : Boolean = true;
    attribute maximumDuration : TimeDuration = 5 [Units::second];
  }

  action def DetectAndReportIonizingRadiation {
    in item incidentRadiation : IonizingRadiation;
    in item command : UserCommand;
    out item displayedReading : RadiationReading;
    out item audibleAlarm : AlarmSignal;
    out item diagnosticStatus : DiagnosticStatus;

    action createPulse : IonizationToPulse;
    action conditionPulse : ShapeDetectorPulse;
    action calculateReading : ComputeDoseEquivalentRate;
    action presentStatus : PresentRadiationStatus;
    action selfTest : RunSelfTest;

    flow createPulse.pulse to conditionPulse.rawPulse;
    flow conditionPulse.logicPulse to calculateReading.pulse;
    flow calculateReading.reading to presentStatus.reading;
    flow presentStatus.displayReading to displayedReading;
    flow presentStatus.alarm to audibleAlarm;
    flow selfTest.status to diagnosticStatus;

    doc /*
     High-level primary function: sense ionizing radiation, count radiation-driven
     tube pulses, convert count rate to a calibrated radiation indication, and
     alert the user when the indicated radiation exceeds configured thresholds.
    */
  }

  state def GeigerCounterOperatingStates {
    entry; then Off;

    state Off {
      entry action {
        doc /* Low-voltage electronics are inactive, high voltage is disabled, and no measurement is reported. */
      }
    }

    state SelfTest {
      entry action runSelfTest : RunSelfTest;
    }

    state StabilizingHighVoltage {
      entry action {
        doc /* High-voltage converter ramps the Geiger-Mueller tube bias into the operating plateau. */
      }
    }

    state Measuring {
      entry action primaryFunction : DetectAndReportIonizingRadiation;
    }

    state Alarmed {
      entry action {
        doc /* Measurement continues while visual and audible alarms identify elevated radiation. */
      }
    }

    state Fault {
      entry action {
        doc /* A detected internal fault prevents trustworthy radiation indication. */
      }
    }

    transition powerOn
      first Off
      accept UserCommand
      if command.kind == UserCommandKind::powerOn
      then SelfTest;

    transition selfTestPassed
      first SelfTest
      if status.health == HealthState::healthy
      then StabilizingHighVoltage;

    transition selfTestFailed
      first SelfTest
      if status.health == HealthState::failed
      then Fault;

    transition voltageStable
      first StabilizingHighVoltage
      if detectorBias.voltage >= 380 [Units::volt] and detectorBias.voltage <= 460 [Units::volt]
      then Measuring;

    transition radiationAlarm
      first Measuring
      if reading.alarmLevel == AlarmLevel::elevated or reading.alarmLevel == AlarmLevel::high or reading.alarmLevel == AlarmLevel::critical
      then Alarmed;

    transition radiationNormal
      first Alarmed
      if reading.alarmLevel == AlarmLevel::normal
      then Measuring;

    transition faultDetectedFromMeasuring
      first Measuring
      if status.health == HealthState::failed
      then Fault;

    transition powerOffFromMeasuring
      first Measuring
      accept UserCommand
      if command.kind == UserCommandKind::powerOff
      then Off;

    transition powerOffFromAlarm
      first Alarmed
      accept UserCommand
      if command.kind == UserCommandKind::powerOff
      then Off;

    transition powerOffFromFault
      first Fault
      accept UserCommand
      if command.kind == UserCommandKind::powerOff
      then Off;
  }

  state def HighVoltageSupplyStates {
    entry; then Disabled;

    state Disabled;
    state RampUp;
    state Regulated;
    state Overload;

    transition enable
      first Disabled
      if inputPower.available == true
      then RampUp;

    transition regulationReached
      first RampUp
      if outputBias.voltage >= 380 [Units::volt]
      then Regulated;

    transition overloadDetected
      first Regulated
      if outputBias.currentLimit > 50 [Units::microAmpere]
      then Overload;

    transition disableFromRegulated
      first Regulated
      if inputPower.available == false
      then Disabled;
  }

  part def GeigerMuellerTube {
    port radiationIn : RadiationInputPort;
    port highVoltageIn : HighVoltageInputPort;
    port pulseOut : RawPulseOutputPort;

    attribute operatingVoltage : ElectricalVoltage = 400 [Units::volt];
    attribute minimumPlateauVoltage : ElectricalVoltage = 380 [Units::volt];
    attribute maximumPlateauVoltage : ElectricalVoltage = 460 [Units::volt];
    attribute deadTime : TimeDuration = 90 [Units::microsecond];
    attribute recoveryTime : TimeDuration = 190 [Units::microsecond];
    attribute betaEfficiency : Probability = 0.35;
    attribute gammaEfficiency : Probability = 0.015;
    attribute minimumDetectableEnergy : RadiationEnergy = 50 [Units::kiloElectronVolt];
    attribute health : HealthState = HealthState::healthy;

    perform action convertRadiationToPulse : IonizationToPulse;
  }

  part def HighVoltageSupply {
    port lowVoltageIn : LowVoltagePowerInputPort;
    port highVoltageOut : HighVoltageOutputPort;
    port diagnosticOut : DiagnosticOutputPort;

    attribute nominalInputVoltage : ElectricalVoltage = 3.7 [Units::volt];
    attribute regulatedOutputVoltage : ElectricalVoltage = 400 [Units::volt];
    attribute outputTolerance : ElectricalVoltage = 20 [Units::volt];
    attribute maximumOutputCurrent : ElectricalCurrent = 50 [Units::microAmpere];
    attribute startUpTime : TimeDuration = 2 [Units::second];
    attribute conversionEfficiency : Probability = 0.78;
    attribute health : HealthState = HealthState::healthy;

    exhibit state hvState : HighVoltageSupplyStates;
  }

  part def PulseConditioner {
    port rawPulseIn : RawPulseInputPort;
    port logicPulseOut : LogicPulseOutputPort;
    port powerIn : LowVoltagePowerInputPort;

    attribute discriminatorThreshold : ElectricalVoltage = 80 [Units::milliVolt];
    attribute logicHighVoltage : ElectricalVoltage = 3.3 [Units::volt];
    attribute minimumAcceptedPulseWidth : TimeDuration = 20 [Units::microsecond];
    attribute afterpulseRejectionWindow : TimeDuration = 250 [Units::microsecond];
    attribute health : HealthState = HealthState::healthy;

    perform action shapePulse : ShapeDetectorPulse;
  }

  part def ProcessingUnit {
    port pulseIn : LogicPulseInputPort;
    port controlIn : UserControlInputPort;
    port displayOut : ReadingOutputPort;
    port alarmOut : AlarmOutputPort;
    port diagnosticOut : DiagnosticOutputPort;
    port powerIn : LowVoltagePowerInputPort;

    attribute integrationWindow : TimeDuration = 10 [Units::second];
    attribute fastUpdatePeriod : TimeDuration = 1 [Units::second];
    attribute calibrationFactor : Real = 0.0057;
    attribute backgroundEstimate : CountRate = 0.20 [Units::countPerSecond];
    attribute deadTimeCompensationEnabled : Boolean = true;
    attribute alarmThresholdElevated : DoseEquivalentRate = 1.0 [Units::microSievertPerHour];
    attribute alarmThresholdHigh : DoseEquivalentRate = 10.0 [Units::microSievertPerHour];
    attribute alarmThresholdCritical : DoseEquivalentRate = 100.0 [Units::microSievertPerHour];
    attribute storedAccumulatedDose : AccumulatedDose = 0.0 [Units::microSievert];
    attribute health : HealthState = HealthState::healthy;

    perform action computeDoseRate : ComputeDoseEquivalentRate;
    perform action manageOutputs : PresentRadiationStatus;
  }

  part def DisplayModule {
    port readingIn : ReadingInputPort;
    port visualOut : ReadingOutputPort;
    port powerIn : LowVoltagePowerInputPort;

    attribute updatePeriod : TimeDuration = 1 [Units::second];
    attribute minimumReadableDoseRate : DoseEquivalentRate = 0.01 [Units::microSievertPerHour];
    attribute maximumDisplayedDoseRate : DoseEquivalentRate = 9999 [Units::microSievertPerHour];
    attribute backlightIntensity : Real = 0.75;
    attribute health : HealthState = HealthState::healthy;
  }

  part def AudibleAnnunciator {
    port alarmIn : AlarmInputPort;
    port audioOut : AlarmOutputPort;
    port powerIn : LowVoltagePowerInputPort;

    attribute normalClickSoundLevel : SoundPressureLevel = 35 [Units::decibel];
    attribute alarmSoundLevel : SoundPressureLevel = 85 [Units::decibel];
    attribute maximumPulseRate : CountRate = 20 [Units::countPerSecond];
    attribute muted : Boolean = false;
    attribute health : HealthState = HealthState::healthy;
  }

  part def UserInterface {
    port commandOut : UserControlInputPort;
    port displayedReadingIn : ReadingInputPort;
    port alarmIn : AlarmInputPort;

    attribute selectedDisplayMode : DisplayMode = DisplayMode::doseRate;
    attribute alarmMuteTimeout : TimeDuration = 120 [Units::second];
  }

  part def BatteryPack {
    port powerOut : LowVoltagePowerOutputPort;
    port diagnosticOut : DiagnosticOutputPort;

    attribute nominalVoltage : ElectricalVoltage = 3.7 [Units::volt];
    attribute minimumOperatingVoltage : ElectricalVoltage = 3.2 [Units::volt];
    attribute capacity : Real = 2600;
    attribute maximumContinuousCurrent : ElectricalCurrent = 800 [Units::milliAmpere];
    attribute estimatedRunTime : TimeDuration = 12 [Units::hour];
    attribute health : HealthState = HealthState::healthy;
  }

  part def Enclosure {
    attribute ingressProtectionAchieved : Boolean = true;
    attribute operatingTemperatureMin : Temperature = -10 [Units::degreeCelsius];
    attribute operatingTemperatureMax : Temperature = 50 [Units::degreeCelsius];
    attribute detectorWindowOpenArea : Real = 12.0;
    attribute userSafeHighVoltageIsolation : Boolean = true;
  }

  part def GeigerCounter {
    port radiationIn : RadiationInputPort;
    port userControls : UserControlInputPort;
    port visualIndication : ReadingOutputPort;
    port audibleIndication : AlarmOutputPort;
    port diagnosticOutput : DiagnosticOutputPort;

    part detector : GeigerMuellerTube;
    part highVoltageSupply : HighVoltageSupply;
    part pulseConditioner : PulseConditioner;
    part controller : ProcessingUnit;
    part display : DisplayModule;
    part annunciator : AudibleAnnunciator;
    part userInterface : UserInterface;
    part battery : BatteryPack;
    part enclosure : Enclosure;

    attribute minimumDetectableEnergy : RadiationEnergy = 50 [Units::kiloElectronVolt];
    attribute measurableDoseRateMin : DoseEquivalentRate = 0.05 [Units::microSievertPerHour];
    attribute measurableDoseRateMax : DoseEquivalentRate = 10000 [Units::microSievertPerHour];
    attribute countRateUpdatePeriod : TimeDuration = 1 [Units::second];
    attribute maximumMeasurementAvailableTime : TimeDuration = 5 [Units::second];
    attribute alarmThreshold : DoseEquivalentRate = 1.0 [Units::microSievertPerHour];
    attribute highVoltageUserAccessible : Boolean = false;
    attribute primaryFunctionEnabled : Boolean = true;

    connection incidentRadiationPath connect radiationIn to detector.radiationIn;
    connection batteryToHighVoltage connect battery.powerOut to highVoltageSupply.lowVoltageIn;
    connection batteryToConditioner connect battery.powerOut to pulseConditioner.powerIn;
    connection batteryToController connect battery.powerOut to controller.powerIn;
    connection batteryToDisplay connect battery.powerOut to display.powerIn;
    connection batteryToAnnunciator connect battery.powerOut to annunciator.powerIn;
    connection detectorBiasPath connect highVoltageSupply.highVoltageOut to detector.highVoltageIn;
    connection rawPulsePath connect detector.pulseOut to pulseConditioner.rawPulseIn;
    connection logicPulsePath connect pulseConditioner.logicPulseOut to controller.pulseIn;
    connection externalControlPath connect userControls to controller.controlIn;
    connection userInterfaceControlPath connect userInterface.commandOut to controller.controlIn;
    connection displayReadingPath connect controller.displayOut to display.readingIn;
    connection visualOutputPath connect display.visualOut to visualIndication;
    connection alarmCommandPath connect controller.alarmOut to annunciator.alarmIn;
    connection audibleOutputPath connect annunciator.audioOut to audibleIndication;
    connection controllerDiagnosticPath connect controller.diagnosticOut to diagnosticOutput;
    connection highVoltageDiagnosticPath connect highVoltageSupply.diagnosticOut to diagnosticOutput;
    connection batteryDiagnosticPath connect battery.diagnosticOut to diagnosticOutput;
    connection uiDisplayFeedback connect display.visualOut to userInterface.displayedReadingIn;
    connection uiAlarmFeedback connect annunciator.audioOut to userInterface.alarmIn;

    perform action primaryOperation : DetectAndReportIonizingRadiation;

    exhibit state operatingState : GeigerCounterOperatingStates;
  }

  requirement def PrimaryFunctionRequirement {
    subject counter : GeigerCounter;

    doc /*
     The Geiger counter shall detect ionizing radiation and provide a high-level
     user indication of radiation intensity by displaying dose-equivalent rate,
     accumulated dose, and alarm status.
    */

    require constraint {
      counter.primaryFunctionEnabled == true
    }

    require constraint {
      counter.measurableDoseRateMin <= 0.05 [Units::microSievertPerHour] and
      counter.measurableDoseRateMax >= 10000 [Units::microSievertPerHour]
    }
  }

  requirement def DetectionEnergyRequirement {
    subject counter : GeigerCounter;

    doc /*
     The detector shall respond to gamma or beta radiation with average energy
     at or above the specified minimum detectable energy.
    */

    require constraint {
      counter.minimumDetectableEnergy <= 50 [Units::kiloElectronVolt]
    }
  }

  requirement def DisplayUpdateRequirement {
    subject counter : GeigerCounter;

    doc /*
     The displayed radiation indication shall be refreshed often enough for a
     user to recognize changing radiation fields during handheld survey use.
    */

    require constraint {
      counter.countRateUpdatePeriod <= 1 [Units::second]
    }
  }

  requirement def MeasurementAvailabilityRequirement {
    subject counter : GeigerCounter;

    doc /*
     After power-on self-test and high-voltage stabilization, the first valid
     radiation indication shall be available within the allocated time.
    */

    require constraint {
      counter.maximumMeasurementAvailableTime <= 5 [Units::second]
    }
  }

  requirement def AlarmRequirement {
    subject counter : GeigerCounter;

    doc /*
     The system shall provide audible and visual alarm indication when the
     estimated dose-equivalent rate exceeds the configured elevated threshold.
    */

    require constraint {
      counter.alarmThreshold <= 1.0 [Units::microSievertPerHour]
    }
  }

  requirement def HighVoltageSafetyRequirement {
    subject counter : GeigerCounter;

    doc /*
     The Geiger-Mueller high-voltage bias shall not be user-accessible during
     normal operation, battery replacement, or alarm acknowledgment.
    */

    require constraint {
      counter.highVoltageUserAccessible == false
    }
  }

  requirement def DetectorPlateauRequirement {
    subject tube : GeigerMuellerTube;

    doc /*
     The Geiger-Mueller tube operating voltage shall remain inside the specified
     plateau range to maintain stable pulse generation.
    */

    require constraint {
      tube.operatingVoltage >= tube.minimumPlateauVoltage and
      tube.operatingVoltage <= tube.maximumPlateauVoltage
    }
  }

  requirement def DeadTimeRequirement {
    subject tube : GeigerMuellerTube;

    doc /*
     Detector dead time shall be characterized so that the processing unit can
     compensate count rate at elevated radiation levels.
    */

    require constraint {
      tube.deadTime <= 100 [Units::microsecond]
    }
  }

  requirement def BatteryRuntimeRequirement {
    subject battery : BatteryPack;

    doc /*
     The battery subsystem shall support portable survey operation for at least
     one work shift.
    */

    require constraint {
      battery.estimatedRunTime >= 8 [Units::hour]
    }
  }

  requirement def AudibleAlarmLevelRequirement {
    subject annunciator : AudibleAnnunciator;

    doc /*
     The audible alarm shall be loud enough to notify a nearby operator in a
     typical indoor survey environment.
    */

    require constraint {
      annunciator.alarmSoundLevel >= 80 [Units::decibel]
    }
  }

  requirement primaryFunctionReq : PrimaryFunctionRequirement {
    subject counter = portableGeigerCounter;
  }

  requirement detectionEnergyReq : DetectionEnergyRequirement {
    subject counter = portableGeigerCounter;
  }

  requirement displayUpdateReq : DisplayUpdateRequirement {
    subject counter = portableGeigerCounter;
  }

  requirement measurementAvailabilityReq : MeasurementAvailabilityRequirement {
    subject counter = portableGeigerCounter;
  }

  requirement alarmReq : AlarmRequirement {
    subject counter = portableGeigerCounter;
  }

  requirement highVoltageSafetyReq : HighVoltageSafetyRequirement {
    subject counter = portableGeigerCounter;
  }

  requirement detectorPlateauReq : DetectorPlateauRequirement {
    subject tube = portableGeigerCounter.detector;
  }

  requirement deadTimeReq : DeadTimeRequirement {
    subject tube = portableGeigerCounter.detector;
  }

  requirement batteryRuntimeReq : BatteryRuntimeRequirement {
    subject battery = portableGeigerCounter.battery;
  }

  requirement audibleAlarmLevelReq : AudibleAlarmLevelRequirement {
    subject annunciator = portableGeigerCounter.annunciator;
  }

  part portableGeigerCounter : GeigerCounter;

}
