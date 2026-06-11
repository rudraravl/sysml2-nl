package CranialElectrotherapyStimulationSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def ElectricCurrent :> ISQ::electricCurrent {
    unit = "mA";
  }

  attribute def ElectricPotential :> ISQ::electricPotential {
    unit = "V";
  }

  attribute def ElectricResistance :> ISQ::resistance {
    unit = "ohm";
  }

  attribute def Frequency :> ISQ::frequency {
    unit = "Hz";
  }

  attribute def Duration :> ISQ::time {
    unit = "min";
  }

  attribute def BatteryCharge {
    unit = "percent";
  }

  attribute def SkinContactQuality {
    unit = "percent";
  }

  attribute def StimulationIntensityLevel {
    unit = "level";
  }

  attribute def SessionIdentifier {
    : String;
  }

  attribute def TherapyModeKind {
    enum values {
      Calm;
      SleepSupport;
      FocusSupport;
      Custom;
    }
  }

  item def ElectricalPulse {
    attribute amplitude : ElectricCurrent;
    attribute pulseVoltage : ElectricPotential;
    attribute pulseFrequency : Frequency;
    attribute pulseWidth : ISQ::time;
    attribute polarityBalanced : Boolean;
  }

  item def ElectrodeContactStatus {
    attribute leftContact : SkinContactQuality;
    attribute rightContact : SkinContactQuality;
    attribute impedance : ElectricResistance;
    attribute acceptable : Boolean;
  }

  item def UserCommand {
    attribute requestedStart : Boolean;
    attribute requestedStop : Boolean;
    attribute requestedIntensity : StimulationIntensityLevel;
    attribute requestedDuration : Duration;
    attribute selectedMode : TherapyModeKind;
  }

  item def SessionRecord {
    attribute sessionId : SessionIdentifier;
    attribute deliveredDuration : Duration;
    attribute averageCurrent : ElectricCurrent;
    attribute selectedMode : TherapyModeKind;
    attribute endedNormally : Boolean;
    attribute safetyInterruption : Boolean;
  }

  port def PulseOutputPort {
    out pulse : ElectricalPulse;
    in contactStatus : ElectrodeContactStatus;
  }

  port def ElectrodeInterfacePort {
    in pulse : ElectricalPulse;
    out contactStatus : ElectrodeContactStatus;
  }

  port def UserInterfacePort {
    in command : UserCommand;
    out displayedIntensity : StimulationIntensityLevel;
    out displayedDuration : Duration;
    out displayedMode : TherapyModeKind;
    out alertMessage : String;
  }

  port def PowerPort {
    out supplyVoltage : ElectricPotential;
    out batteryCharge : BatteryCharge;
  }

  port def DataPort {
    out sessionRecord : SessionRecord;
  }

  part def RechargeableBattery {
    attribute nominalVoltage : ElectricPotential = 3.7 [V];
    attribute minimumOperatingVoltage : ElectricPotential = 3.2 [V];
    attribute chargeRemaining : BatteryCharge;
    port power : PowerPort;
  }

  part def CurrentRegulatedPulseGenerator {
    attribute maximumCurrent : ElectricCurrent = 0.5 [mA];
    attribute minimumCurrent : ElectricCurrent = 0.05 [mA];
    attribute operatingFrequency : Frequency = 0.5 [Hz];
    attribute outputVoltageLimit : ElectricPotential = 20 [V];
    attribute balancedWaveformRequired : Boolean = true;
    port output : PulseOutputPort;
    port powerIn : PowerPort;
  }

  part def ElectrodeLeadSet {
    attribute leadResistance : ElectricResistance;
    attribute insulationIntegrityOk : Boolean;
    port stimulatorSide : ElectrodeInterfacePort;
    port leftElectrodeSide : ElectrodeInterfacePort;
    port rightElectrodeSide : ElectrodeInterfacePort;
  }

  part def EarClipElectrode {
    attribute contactArea : ISQ::area;
    attribute hydratedPadPresent : Boolean;
    attribute measuredContactQuality : SkinContactQuality;
    port electricalInterface : ElectrodeInterfacePort;
  }

  part def ImpedanceMonitor {
    attribute maximumSafeImpedance : ElectricResistance = 10000 [ohm];
    attribute minimumValidImpedance : ElectricResistance = 500 [ohm];
    attribute measuredImpedance : ElectricResistance;
    attribute leftContactQuality : SkinContactQuality;
    attribute rightContactQuality : SkinContactQuality;
    port electrodeSense : ElectrodeInterfacePort;
  }

  part def TherapyController {
    attribute activeMode : TherapyModeKind;
    attribute targetCurrent : ElectricCurrent;
    attribute targetDuration : Duration;
    attribute elapsedDuration : Duration;
    attribute rampTime : ISQ::time = 30 [s];
    attribute therapyActive : Boolean;
    port pulseControl : PulseOutputPort;
    port userInterface : UserInterfacePort;
    port dataOut : DataPort;
  }

  part def SafetySupervisor {
    attribute overCurrentLimit : ElectricCurrent = 0.6 [mA];
    attribute lowBatteryThreshold : BatteryCharge = 15 [%];
    attribute maximumSessionDuration : Duration = 60 [min];
    attribute stimulationPermitted : Boolean;
    attribute lastFault : String;
    port pulseMonitor : PulseOutputPort;
    port batteryMonitor : PowerPort;
    port userAlert : UserInterfacePort;
  }

  part def UserDisplayAndControls {
    attribute shownMode : TherapyModeKind;
    attribute shownIntensity : StimulationIntensityLevel;
    attribute shownRemainingTime : Duration;
    attribute startStopButtonPressed : Boolean;
    attribute intensityStep : StimulationIntensityLevel;
    port ui : UserInterfacePort;
  }

  part def SessionLogger {
    attribute recordsStored : Integer;
    attribute memoryCapacity : Integer = 100;
    port logInput : DataPort;
  }

  action def ConfigureTherapySession {
    in command : UserCommand;
    out mode : TherapyModeKind;
    out requestedCurrent : ElectricCurrent;
    out requestedDuration : Duration;

    first start;
    then validateDuration;
    then mapIntensityToCurrent;
    then selectMode;
    then done;

    action validateDuration {
      in command : UserCommand;
      out requestedDuration : Duration;
    }

    action mapIntensityToCurrent {
      in command : UserCommand;
      out requestedCurrent : ElectricCurrent;
    }

    action selectMode {
      in command : UserCommand;
      out mode : TherapyModeKind;
    }
  }

  action def DeliverBalancedMicrocurrent {
    in requestedCurrent : ElectricCurrent;
    in frequency : Frequency;
    in duration : Duration;
    out deliveredPulse : ElectricalPulse;

    first rampUp;
    then regulateCurrent;
    then alternatePolarity;
    then rampDown;
    then complete;

    action rampUp;
    action regulateCurrent;
    action alternatePolarity;
    action rampDown;
  }

  action def MonitorElectrodeSafety {
    in contactStatus : ElectrodeContactStatus;
    in batteryCharge : BatteryCharge;
    out permitted : Boolean;
    out faultMessage : String;

    first sampleContact;
    then evaluateImpedance;
    then evaluateBattery;
    then issueDecision;

    action sampleContact;
    action evaluateImpedance;
    action evaluateBattery;
    action issueDecision;
  }

  state def CesOperatingStateMachine {
    entry action initializeDevice;

    state Off;
    state Standby;
    state ContactCheck;
    state Ready;
    state Stimulating;
    state PausedForFault;
    state SessionComplete;
    state Charging;

    transition powerOn first Off then Standby;
    transition attachElectrodes first Standby then ContactCheck;
    transition contactAcceptable first ContactCheck then Ready;
    transition contactUnacceptable first ContactCheck then PausedForFault;
    transition startSession first Ready then Stimulating;
    transition stopRequested first Stimulating then SessionComplete;
    transition sessionTimerExpired first Stimulating then SessionComplete;
    transition faultDetected first Stimulating then PausedForFault;
    transition faultCleared first PausedForFault then ContactCheck;
    transition powerOffFromStandby first Standby then Off;
    transition powerOffFromComplete first SessionComplete then Off;
    transition chargerConnectedFromOff first Off then Charging;
    transition chargerDisconnected first Charging then Standby;
  }

  part def CranialElectrotherapyStimulator {
    attribute primaryFunction : String =
      "Deliver controlled, low-level, balanced cranial electrical stimulation through external electrodes while monitoring contact quality, session timing, current limits, and power status.";

    attribute supportedModes : TherapyModeKind[4];
    attribute maxOutputCurrent : ElectricCurrent = 0.5 [mA];
    attribute defaultFrequency : Frequency = 0.5 [Hz];
    attribute defaultSessionDuration : Duration = 20 [min];
    attribute maximumSessionDuration : Duration = 60 [min];

    part battery : RechargeableBattery;
    part pulseGenerator : CurrentRegulatedPulseGenerator;
    part leadSet : ElectrodeLeadSet;
    part leftEarClip : EarClipElectrode;
    part rightEarClip : EarClipElectrode;
    part impedanceMonitor : ImpedanceMonitor;
    part controller : TherapyController;
    part safetySupervisor : SafetySupervisor;
    part userInterface : UserDisplayAndControls;
    part logger : SessionLogger;

    port userPort : UserInterfacePort;
    port recordPort : DataPort;

    connect battery.power to pulseGenerator.powerIn;
    connect battery.power to safetySupervisor.batteryMonitor;

    connect controller.pulseControl to pulseGenerator.output;
    connect pulseGenerator.output to leadSet.stimulatorSide;

    connect leadSet.leftElectrodeSide to leftEarClip.electricalInterface;
    connect leadSet.rightElectrodeSide to rightEarClip.electricalInterface;
    connect impedanceMonitor.electrodeSense to leadSet.stimulatorSide;

    connect safetySupervisor.pulseMonitor to pulseGenerator.output;
    connect userInterface.ui to controller.userInterface;
    connect userInterface.ui to safetySupervisor.userAlert;
    connect userPort to userInterface.ui;

    connect controller.dataOut to logger.logInput;
    connect controller.dataOut to recordPort;

    perform action configure : ConfigureTherapySession;
    perform action deliver : DeliverBalancedMicrocurrent;
    perform action monitor : MonitorElectrodeSafety;

    exhibit state machine CesOperatingStateMachine;
  }

  requirement def PrimaryFunctionRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    doc
      /*
       The system shall provide cranial electrotherapy stimulation by generating
       controlled, low-level, current-regulated, polarity-balanced electrical pulses
       through external cranial electrodes for a user-selected therapy session.
      */
  }

  requirement def CurrentLimitRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    attribute limit : ElectricCurrent = 0.5 [mA];
    doc
      /*
       The stimulation output shall not exceed 0.5 mA during normal operation.
      */
  }

  requirement def BalancedWaveformRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    doc
      /*
       The pulse generator shall use a polarity-balanced waveform to avoid net DC
       charge accumulation at the electrode interface.
      */
  }

  requirement def ContactMonitoringRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    attribute maximumAllowedImpedance : ElectricResistance = 10000 [ohm];
    doc
      /*
       The system shall verify acceptable electrode contact before stimulation and
       shall pause stimulation if electrode impedance exceeds the allowed range.
      */
  }

  requirement def SessionTimingRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    attribute maximumDuration : Duration = 60 [min];
    doc
      /*
       The controller shall limit a stimulation session to no more than 60 minutes
       and shall stop output when the selected session time has elapsed.
      */
  }

  requirement def UserControlRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    doc
      /*
       The user interface shall allow the user to select therapy mode, adjust
       stimulation intensity within permitted limits, start a session, stop a
       session, and view remaining session time.
      */
  }

  requirement def FaultInterruptionRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    doc
      /*
       The safety supervisor shall interrupt stimulation and alert the user when
       low battery, overcurrent, invalid electrode contact, or session limit faults
       are detected.
      */
  }

  requirement def SessionLoggingRequirement {
    subject stimulator : CranialElectrotherapyStimulator;
    doc
      /*
       The system shall store a session record containing selected mode, delivered
       duration, average current, normal completion status, and safety interruption
       status.
      */
  }

  satisfy PrimaryFunctionRequirement by CranialElectrotherapyStimulator;
  satisfy CurrentLimitRequirement by CurrentRegulatedPulseGenerator;
  satisfy BalancedWaveformRequirement by CurrentRegulatedPulseGenerator;
  satisfy ContactMonitoringRequirement by ImpedanceMonitor;
  satisfy SessionTimingRequirement by TherapyController;
  satisfy UserControlRequirement by UserDisplayAndControls;
  satisfy FaultInterruptionRequirement by SafetySupervisor;
  satisfy SessionLoggingRequirement by SessionLogger;

}