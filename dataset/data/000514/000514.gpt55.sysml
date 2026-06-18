package TranscranialDirectCurrentStimulationSystemModel {

  import ScalarValues::*;

  unit def mA;
  unit def V;
  unit def kOhm;
  unit def min;
  unit def s;
  unit def degC;
  unit def percent;

  attribute def Current_mA :> Real {
    attribute unitSymbol : String = "mA";
  }

  attribute def Voltage_V :> Real {
    attribute unitSymbol : String = "V";
  }

  attribute def Impedance_kOhm :> Real {
    attribute unitSymbol : String = "kOhm";
  }

  attribute def Duration_min :> Real {
    attribute unitSymbol : String = "min";
  }

  attribute def Time_s :> Real {
    attribute unitSymbol : String = "s";
  }

  attribute def Temperature_degC :> Real {
    attribute unitSymbol : String = "degC";
  }

  attribute def StateOfCharge_percent :> Real {
    attribute unitSymbol : String = "%";
  }

  enum def PolarityKind {
    enum anodal;
    enum cathodal;
    enum off;
  }

  enum def OperationalMode {
    enum poweredOff;
    enum booting;
    enum ready;
    enum electrodeCheck;
    enum rampUp;
    enum stimulation;
    enum rampDown;
    enum paused;
    enum completed;
    enum fault;
  }

  enum def FaultKind {
    enum none;
    enum batteryLow;
    enum electrodeOpenCircuit;
    enum electrodeShortCircuit;
    enum overCurrent;
    enum overVoltage;
    enum excessiveTemperature;
    enum sessionExpired;
    enum controllerWatchdogTimeout;
  }

  item def ElectricalEnergy {
    attribute voltage : Voltage_V;
    attribute availableCharge : StateOfCharge_percent;
  }

  item def DirectCurrentStimulus {
    attribute current : Current_mA;
    attribute complianceVoltage : Voltage_V;
    attribute polarity : PolarityKind;
    attribute elapsedTime : Time_s;
  }

  item def StimulationPrescription {
    attribute targetCurrent : Current_mA = 1.5 [mA];
    attribute maximumCurrent : Current_mA = 2.0 [mA];
    attribute rampUpTime : Time_s = 30.0 [s];
    attribute rampDownTime : Time_s = 30.0 [s];
    attribute therapyDuration : Duration_min = 20.0 [min];
    attribute anodePolarity : PolarityKind = PolarityKind::anodal;
    attribute cathodePolarity : PolarityKind = PolarityKind::cathodal;
  }

  item def ElectrodeImpedanceMeasurement {
    attribute anodeImpedance : Impedance_kOhm;
    attribute cathodeImpedance : Impedance_kOhm;
    attribute totalPathImpedance : Impedance_kOhm;
  }

  item def SafetyStatus {
    attribute fault : FaultKind;
    attribute therapyAllowed : Boolean;
    attribute measuredCurrent : Current_mA;
    attribute measuredVoltage : Voltage_V;
    attribute measuredImpedance : Impedance_kOhm;
    attribute electronicsTemperature : Temperature_degC;
  }

  item def UserCommand {
    attribute startRequested : Boolean;
    attribute pauseRequested : Boolean;
    attribute stopRequested : Boolean;
    attribute acknowledgeFault : Boolean;
  }

  item def ClinicianProgram {
    attribute prescription : StimulationPrescription;
    attribute programLocked : Boolean = true;
  }

  item def SessionRecord {
    attribute deliveredCurrentAverage : Current_mA;
    attribute deliveredDuration : Duration_min;
    attribute maximumMeasuredVoltage : Voltage_V;
    attribute maximumMeasuredImpedance : Impedance_kOhm;
    attribute completedNormally : Boolean;
    attribute terminatingFault : FaultKind;
  }

  port def PowerInputPort {
    in item energy : ElectricalEnergy;
  }

  port def RegulatedPowerPort {
    out item energy : ElectricalEnergy;
  }

  port def PrescriptionPort {
    in item program : ClinicianProgram;
  }

  port def UserCommandPort {
    in item command : UserCommand;
  }

  port def ControllerCommandPort {
    out item prescription : StimulationPrescription;
    out item enableTherapy : Boolean;
    out item requestedMode : OperationalMode;
  }

  port def StimulatorControlPort {
    in item prescription : StimulationPrescription;
    in item enableTherapy : Boolean;
    in item requestedMode : OperationalMode;
  }

  port def StimulatorOutputPort {
    out item stimulus : DirectCurrentStimulus;
    in item impedanceFeedback : ElectrodeImpedanceMeasurement;
  }

  port def ElectrodeInputPort {
    in item stimulus : DirectCurrentStimulus;
    out item impedanceFeedback : ElectrodeImpedanceMeasurement;
  }

  port def SafetyTelemetryPort {
    in item impedance : ElectrodeImpedanceMeasurement;
    in item stimulus : DirectCurrentStimulus;
    out item status : SafetyStatus;
  }

  port def SafetyInterlockPort {
    in item status : SafetyStatus;
    out item therapyAllowed : Boolean;
  }

  port def DisplayPort {
    in item mode : OperationalMode;
    in item status : SafetyStatus;
    in item record : SessionRecord;
  }

  port def SessionDataPort {
    in item status : SafetyStatus;
    in item prescription : StimulationPrescription;
    out item record : SessionRecord;
  }

  part def RechargeableBattery {
    attribute nominalVoltage : Voltage_V = 7.4 [V];
    attribute stateOfCharge : StateOfCharge_percent = 100.0 [percent];
    attribute lowChargeThreshold : StateOfCharge_percent = 15.0 [percent];

    port powerOut : RegulatedPowerPort;
  }

  part def PowerRegulator {
    attribute regulatedVoltage : Voltage_V = 5.0 [V];
    attribute maximumRippleVoltage : Voltage_V = 0.05 [V];

    port rawPowerIn : PowerInputPort;
    port regulatedPowerOut : RegulatedPowerPort;
  }

  part def UserInterface {
    attribute displayedMode : OperationalMode = OperationalMode::poweredOff;
    attribute audibleAlarmEnabled : Boolean = true;

    port commandOut : UserCommandPort;
    port displayIn : DisplayPort;
  }

  part def ClinicianProgrammer {
    attribute defaultTargetCurrent : Current_mA = 1.5 [mA];
    attribute defaultDuration : Duration_min = 20.0 [min];

    port prescriptionOut : PrescriptionPort;
  }

  part def TherapyController {
    attribute activeMode : OperationalMode = OperationalMode::poweredOff;
    attribute selectedPrescription : StimulationPrescription;
    attribute watchdogTimeout : Time_s = 2.0 [s];
    attribute therapyElapsedTime : Time_s = 0.0 [s];

    port prescriptionIn : PrescriptionPort;
    port userCommandIn : UserCommandPort;
    port safetyIn : SafetyInterlockPort;
    port commandOut : ControllerCommandPort;
    port displayOut : DisplayPort;
    port logOut : SessionDataPort;

    exhibit state controllerLifecycle : TherapyLifecycle;
  }

  part def ConstantCurrentStimulator {
    attribute commandedCurrent : Current_mA = 0.0 [mA];
    attribute measuredOutputCurrent : Current_mA = 0.0 [mA];
    attribute maximumOutputCurrent : Current_mA = 2.0 [mA];
    attribute complianceVoltageLimit : Voltage_V = 24.0 [V];
    attribute outputEnabled : Boolean = false;

    port controlIn : StimulatorControlPort;
    port anodeOutput : StimulatorOutputPort;
    port cathodeOutput : StimulatorOutputPort;
    port safetyTelemetry : SafetyTelemetryPort;
  }

  part def ScalpElectrodeAssembly {
    attribute anodeGelHydrated : Boolean = true;
    attribute cathodeGelHydrated : Boolean = true;
    attribute anodeContactArea_cm2 : Real = 25.0;
    attribute cathodeContactArea_cm2 : Real = 25.0;
    attribute nominalAnodeImpedance : Impedance_kOhm = 4.0 [kOhm];
    attribute nominalCathodeImpedance : Impedance_kOhm = 4.0 [kOhm];

    part anodePad : ElectrodePad {
      attribute polarity : PolarityKind = PolarityKind::anodal;
    }

    part cathodePad : ElectrodePad {
      attribute polarity : PolarityKind = PolarityKind::cathodal;
    }

    port anodeInput : ElectrodeInputPort;
    port cathodeInput : ElectrodeInputPort;
    port impedanceOut : SafetyTelemetryPort;
  }

  part def ElectrodePad {
    attribute polarity : PolarityKind;
    attribute contactImpedance : Impedance_kOhm = 4.0 [kOhm];
    attribute maximumSafeCurrentDensity_mA_per_cm2 : Real = 0.08;
  }

  part def SafetyMonitor {
    attribute minimumValidImpedance : Impedance_kOhm = 1.0 [kOhm];
    attribute maximumValidImpedance : Impedance_kOhm = 10.0 [kOhm];
    attribute maximumCurrent : Current_mA = 2.0 [mA];
    attribute maximumComplianceVoltage : Voltage_V = 24.0 [V];
    attribute maximumElectronicsTemperature : Temperature_degC = 45.0 [degC];
    attribute currentFault : FaultKind = FaultKind::none;

    port telemetryIn : SafetyTelemetryPort;
    port interlockOut : SafetyInterlockPort;
  }

  part def SessionLogger {
    attribute nonvolatileStorageEnabled : Boolean = true;
    attribute lastRecord : SessionRecord;

    port dataIn : SessionDataPort;
  }

  action def MeasureElectrodeImpedance {
    in item injectedTestStimulus : DirectCurrentStimulus;
    out item impedance : ElectrodeImpedanceMeasurement;

    constraint validMeasurementRange {
      impedance.totalPathImpedance >= 0.0 [kOhm] and impedance.totalPathImpedance <= 50.0 [kOhm]
    }
  }

  action def CheckSafetyInterlocks {
    in item impedance : ElectrodeImpedanceMeasurement;
    in item stimulus : DirectCurrentStimulus;
    in item temperature : Temperature_degC;
    out item status : SafetyStatus;

    constraint impedanceIsAcceptable {
      status.therapyAllowed implies
        impedance.totalPathImpedance >= 1.0 [kOhm] and impedance.totalPathImpedance <= 10.0 [kOhm]
    }

    constraint currentIsAcceptable {
      status.therapyAllowed implies stimulus.current <= 2.0 [mA]
    }

    constraint voltageIsAcceptable {
      status.therapyAllowed implies stimulus.complianceVoltage <= 24.0 [V]
    }

    constraint temperatureIsAcceptable {
      status.therapyAllowed implies temperature <= 45.0 [degC]
    }
  }

  action def RampCurrent {
    in item targetCurrent : Current_mA;
    in item rampDuration : Time_s;
    out item currentCommand : Current_mA;

    constraint rampLimited {
      currentCommand >= 0.0 [mA] and currentCommand <= targetCurrent and rampDuration >= 10.0 [s]
    }
  }

  action def MaintainConstantCurrent {
    in item prescription : StimulationPrescription;
    in item impedance : ElectrodeImpedanceMeasurement;
    out item stimulus : DirectCurrentStimulus;

    constraint regulatedTherapyCurrent {
      stimulus.current >= prescription.targetCurrent - 0.05 [mA] and
      stimulus.current <= prescription.targetCurrent + 0.05 [mA]
    }

    constraint complianceVoltageLimit {
      stimulus.complianceVoltage <= 24.0 [V]
    }
  }

  action def TerminateStimulationSafely {
    in item reason : FaultKind;
    out item finalCurrent : Current_mA;

    constraint outputCurrentRemoved {
      finalCurrent == 0.0 [mA]
    }
  }

  action def ProvideTranscranialDirectCurrentStimulation {
    in item program : ClinicianProgram;
    in item userCommand : UserCommand;
    out item sessionRecord : SessionRecord;

    action verifyPrescription : CheckSafetyInterlocks;
    action measureContact : MeasureElectrodeImpedance;
    action rampUp : RampCurrent;
    action regulate : MaintainConstantCurrent;
    action rampDown : RampCurrent;
    action shutdown : TerminateStimulationSafely;

    objective primaryFunction {
      doc /* Deliver a low-amplitude controlled direct current between scalp electrodes according to a clinician-defined prescription to modulate cortical excitability while continuously limiting current, voltage, impedance, temperature, and session duration. */
    }
  }

  event def PowerButtonPressed;
  event def ValidProgramLoaded;
  event def StartCommandReceived;
  event def PauseCommandReceived;
  event def ResumeCommandReceived;
  event def StopCommandReceived;
  event def ElectrodeCheckPassed;
  event def ElectrodeCheckFailed;
  event def RampComplete;
  event def TherapyTimerExpired;
  event def FaultDetected;
  event def FaultAcknowledged;

  state def TherapyLifecycle {
    state off;
    state booting;
    state ready;
    state checkingElectrodes;
    state rampingUp;
    state stimulating;
    state paused;
    state rampingDown;
    state completed;
    state faulted;

    transition initialToOff first off;

    transition powerOn
      first off
      accept PowerButtonPressed
      then booting;

    transition bootComplete
      first booting
      accept ValidProgramLoaded
      then ready;

    transition beginElectrodeCheck
      first ready
      accept StartCommandReceived
      then checkingElectrodes;

    transition rejectPoorContact
      first checkingElectrodes
      accept ElectrodeCheckFailed
      then faulted;

    transition contactAccepted
      first checkingElectrodes
      accept ElectrodeCheckPassed
      then rampingUp;

    transition beginStimulation
      first rampingUp
      accept RampComplete
      then stimulating;

    transition pauseTherapy
      first stimulating
      accept PauseCommandReceived
      then paused;

    transition resumeTherapy
      first paused
      accept ResumeCommandReceived
      then rampingUp;

    transition stopFromStimulating
      first stimulating
      accept StopCommandReceived
      then rampingDown;

    transition timerExpired
      first stimulating
      accept TherapyTimerExpired
      then rampingDown;

    transition finishRampDown
      first rampingDown
      accept RampComplete
      then completed;

    transition faultFromReady
      first ready
      accept FaultDetected
      then faulted;

    transition faultFromRampUp
      first rampingUp
      accept FaultDetected
      then faulted;

    transition faultFromStimulating
      first stimulating
      accept FaultDetected
      then faulted;

    transition faultFromPaused
      first paused
      accept FaultDetected
      then faulted;

    transition acknowledgeFault
      first faulted
      accept FaultAcknowledged
      then ready;
  }

  part def TDCSSystem {
    attribute systemName : String = "Controlled Transcranial Direct-Current Stimulation System";
    attribute primaryFunctionStatement : String =
      "Provide clinician-prescribed, low-amplitude direct current through scalp electrodes to support noninvasive neuromodulation while enforcing electrical and physiological safety limits.";
    attribute operationalMode : OperationalMode = OperationalMode::poweredOff;
    attribute deliversControlledCurrent : Boolean = true;
    attribute maximumAllowedCurrent : Current_mA = 2.0 [mA];
    attribute maximumAllowedVoltage : Voltage_V = 24.0 [V];
    attribute maximumTherapyDuration : Duration_min = 30.0 [min];

    part battery : RechargeableBattery;
    part powerRegulator : PowerRegulator;
    part userInterface : UserInterface;
    part clinicianProgrammer : ClinicianProgrammer;
    part controller : TherapyController;
    part stimulator : ConstantCurrentStimulator;
    part electrodeAssembly : ScalpElectrodeAssembly;
    part safetyMonitor : SafetyMonitor;
    part sessionLogger : SessionLogger;

    port externalPrescription : PrescriptionPort;
    port externalUserCommand : UserCommandPort;

    connect battery.powerOut to powerRegulator.rawPowerIn;
    connect powerRegulator.regulatedPowerOut to controller.commandOut;
    connect clinicianProgrammer.prescriptionOut to controller.prescriptionIn;
    connect externalPrescription to controller.prescriptionIn;
    connect userInterface.commandOut to controller.userCommandIn;
    connect externalUserCommand to controller.userCommandIn;
    connect controller.commandOut to stimulator.controlIn;
    connect stimulator.anodeOutput to electrodeAssembly.anodeInput;
    connect stimulator.cathodeOutput to electrodeAssembly.cathodeInput;
    connect electrodeAssembly.impedanceOut to safetyMonitor.telemetryIn;
    connect stimulator.safetyTelemetry to safetyMonitor.telemetryIn;
    connect safetyMonitor.interlockOut to controller.safetyIn;
    connect controller.displayOut to userInterface.displayIn;
    connect controller.logOut to sessionLogger.dataIn;

    perform action primaryFunction : ProvideTranscranialDirectCurrentStimulation;
    exhibit state systemLifecycle : TherapyLifecycle;
  }

  requirement def PrimaryFunctionRequirement {
    subject system : TDCSSystem;

    doc /* The system shall provide transcranial direct-current stimulation by delivering controlled, low-amplitude direct current between an anode and cathode placed on the scalp according to a clinician prescription. */

    require constraint controlledNeuromodulation {
      system.deliversControlledCurrent == true
    }
  }

  requirement def CurrentLimitRequirement {
    subject system : TDCSSystem;

    doc /* The system shall prevent commanded or delivered stimulation current from exceeding 2.0 mA. */

    require constraint currentLimit {
      system.stimulator.maximumOutputCurrent <= 2.0 [mA] and
      system.maximumAllowedCurrent <= 2.0 [mA]
    }
  }

  requirement def VoltageComplianceRequirement {
    subject system : TDCSSystem;

    doc /* The system shall disable stimulation when compliance voltage exceeds the configured safe limit. */

    require constraint voltageLimit {
      system.stimulator.complianceVoltageLimit <= 24.0 [V] and
      system.maximumAllowedVoltage <= 24.0 [V]
    }
  }

  requirement def ElectrodeImpedanceRequirement {
    subject system : TDCSSystem;

    doc /* The system shall permit stimulation only when the measured electrode path impedance is between 1.0 kOhm and 10.0 kOhm. */

    require constraint impedanceWindow {
      system.safetyMonitor.minimumValidImpedance >= 1.0 [kOhm] and
      system.safetyMonitor.maximumValidImpedance <= 10.0 [kOhm]
    }
  }

  requirement def RampRequirement {
    subject system : TDCSSystem;

    doc /* The system shall ramp current up and down instead of applying or removing the prescribed current instantaneously. */

    require constraint rampDurations {
      system.controller.selectedPrescription.rampUpTime >= 10.0 [s] and
      system.controller.selectedPrescription.rampDownTime >= 10.0 [s]
    }
  }

  requirement def SessionDurationRequirement {
    subject system : TDCSSystem;

    doc /* The system shall limit a single stimulation session to no more than 30 minutes. */

    require constraint durationLimit {
      system.controller.selectedPrescription.therapyDuration <= system.maximumTherapyDuration
    }
  }

  requirement def FaultSafeRequirement {
    subject system : TDCSSystem;

    doc /* The system shall command zero output current when a safety fault is detected. */

    require constraint faultRemovesOutput {
      system.safetyMonitor.currentFault != FaultKind::none implies
      system.stimulator.commandedCurrent == 0.0 [mA]
    }
  }

  requirement def SessionRecordRequirement {
    subject system : TDCSSystem;

    doc /* The system shall record delivered current, duration, maximum voltage, maximum impedance, completion status, and terminating fault for each therapy session. */

    require constraint recordAvailable {
      system.sessionLogger.nonvolatileStorageEnabled == true
    }
  }

  satisfy PrimaryFunctionRequirement by TDCSSystem::primaryFunction;
  satisfy CurrentLimitRequirement by TDCSSystem::stimulator;
  satisfy VoltageComplianceRequirement by TDCSSystem::stimulator;
  satisfy ElectrodeImpedanceRequirement by TDCSSystem::safetyMonitor;
  satisfy RampRequirement by TDCSSystem::controller;
  satisfy SessionDurationRequirement by TDCSSystem::controller;
  satisfy FaultSafeRequirement by TDCSSystem::safetyMonitor;
  satisfy SessionRecordRequirement by TDCSSystem::sessionLogger;

}
