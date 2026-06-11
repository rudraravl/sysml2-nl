package MotorolaAPCORBasedSystem {

  value def Voltage_mV;
  value def Frequency_Hz;
  value def Power_W;
  value def Time_s;
  value def Energy_Wh;
  value def DataRate_bps;
  value def Percentage;

  item def ECGSignal {
    attribute amplitude : Voltage_mV;
    attribute bandwidth : Frequency_Hz;
    attribute leadCount : Integer;
  }

  item def VoiceAudio {
    attribute level : Voltage_mV;
    attribute bandwidth : Frequency_Hz;
  }

  item def TelemetryFrame {
    attribute carrierFrequency : Frequency_Hz;
    attribute transmitPower : Power_W;
    attribute dataRate : DataRate_bps;
    attribute frameDuration : Time_s;
  }

  item def ControlCommand {
    attribute commandCode : Integer;
    attribute priority : Integer;
  }

  item def BatteryEnergy {
    attribute storedEnergy : Energy_Wh;
    attribute stateOfCharge : Percentage;
  }

  port def PatientElectrodePort {
    in item ecg : ECGSignal;
  }

  port def AudioPort {
    in item microphoneAudio : VoiceAudio;
    out item speakerAudio : VoiceAudio;
  }

  port def RadioTelemetryPort {
    out item uplinkTelemetry : TelemetryFrame;
    in item downlinkCommand : ControlCommand;
  }

  port def PowerPort {
    in item batteryEnergy : BatteryEnergy;
  }

  port def DisplayPort {
    out item displayedECG : ECGSignal;
  }

  action def AcquireECG {
    in item rawECG : ECGSignal;
    out item conditionedECG : ECGSignal;
  }

  action def EncodeTelemetry {
    in item conditionedECG : ECGSignal;
    in item voice : VoiceAudio;
    out item frame : TelemetryFrame;
  }

  action def TransmitTelemetry {
    in item frame : TelemetryFrame;
    out item rfFrame : TelemetryFrame;
  }

  action def ReceiveMedicalCommand {
    in item command : ControlCommand;
    out item acceptedCommand : ControlCommand;
  }

  action def MonitorPower {
    in item energy : BatteryEnergy;
    out attribute lowPowerWarning : Boolean;
  }

  state def APCOROperationalStates {
    state off;
    state selfTest;
    state standby;
    state acquirePatientSignal;
    state transmitBiotelemetry;
    state receiveMedicalDirection;
    state lowPower;
    state fault;

    entry action initialPowerCheck : MonitorPower;

    transition first off then selfTest;
    transition selfTest then standby;
    transition standby then acquirePatientSignal;
    transition acquirePatientSignal then transmitBiotelemetry;
    transition transmitBiotelemetry then receiveMedicalDirection;
    transition receiveMedicalDirection then acquirePatientSignal;
    transition transmitBiotelemetry then lowPower;
    transition lowPower then standby;
    transition selfTest then fault;
    transition acquirePatientSignal then fault;
  }

  part def ElectrodeLeadSet {
    port patientInterface : PatientElectrodePort;
    attribute leadCount : Integer = 3;
    attribute nominalSignalAmplitude : Voltage_mV;
  }

  part def ECGConditioner {
    port input : PatientElectrodePort;
    port output : DisplayPort;
    attribute lowCutFrequency : Frequency_Hz;
    attribute highCutFrequency : Frequency_Hz;
    attribute gain : Real;
    action filterAndAmplify : AcquireECG;
  }

  part def AudioSubsystem {
    port crewAudio : AudioPort;
    attribute audioBandwidth : Frequency_Hz;
  }

  part def TelemetryEncoder {
    port ecgInput : DisplayPort;
    port audioInput : AudioPort;
    port encodedOutput : RadioTelemetryPort;
    action encode : EncodeTelemetry;
  }

  part def VHFTransceiver {
    port telemetry : RadioTelemetryPort;
    attribute carrierFrequency : Frequency_Hz;
    attribute nominalTransmitPower : Power_W;
    attribute receiverSensitivity : Voltage_mV;
    action transmit : TransmitTelemetry;
    action receiveCommand : ReceiveMedicalCommand;
  }

  part def BatteryPack {
    port powerOutput : PowerPort;
    attribute capacity : Energy_Wh;
    attribute nominalVoltage : Voltage_mV;
    action supervisePower : MonitorPower;
  }

  part def OperatorDisplay {
    port displayInput : DisplayPort;
    attribute refreshPeriod : Time_s;
  }

  part def MotorolaAPCORBasedEmergencyTelemetrySystem {
    port patientPort : PatientElectrodePort;
    port crewAudioPort : AudioPort;
    port hospitalRadioPort : RadioTelemetryPort;
    port externalPowerPort : PowerPort;

    part leads : ElectrodeLeadSet;
    part conditioner : ECGConditioner;
    part audio : AudioSubsystem;
    part encoder : TelemetryEncoder;
    part transceiver : VHFTransceiver;
    part battery : BatteryPack;
    part display : OperatorDisplay;

    state operationalBehavior : APCOROperationalStates;

    connect patientPort to leads.patientInterface;
    connect leads.patientInterface to conditioner.input;
    connect conditioner.output to display.displayInput;
    connect conditioner.output to encoder.ecgInput;
    connect crewAudioPort to audio.crewAudio;
    connect audio.crewAudio to encoder.audioInput;
    connect encoder.encodedOutput to transceiver.telemetry;
    connect transceiver.telemetry to hospitalRadioPort;
    connect battery.powerOutput to externalPowerPort;

    attribute primaryFunction : String =
      "Acquire a patient's cardiac electrical activity in the field, condition it for clinical interpretation, and transmit ECG and voice telemetry to a remote medical facility for physician-directed emergency care.";
  }

  requirement def PrimaryFunctionRequirement {
    subject system : MotorolaAPCORBasedEmergencyTelemetrySystem;
    require constraint {
      system.primaryFunction ==
      "Acquire a patient's cardiac electrical activity in the field, condition it for clinical interpretation, and transmit ECG and voice telemetry to a remote medical facility for physician-directed emergency care."
    }
  }

  requirement def ECGAcquisitionRequirement {
    subject system : MotorolaAPCORBasedEmergencyTelemetrySystem;
    require constraint {
      system.leads.leadCount >= 3
    }
  }

  requirement def TelemetryTransmissionRequirement {
    subject system : MotorolaAPCORBasedEmergencyTelemetrySystem;
    require constraint {
      system.transceiver.nominalTransmitPower > 0
    }
  }

  requirement def PortableOperationRequirement {
    subject system : MotorolaAPCORBasedEmergencyTelemetrySystem;
    require constraint {
      system.battery.capacity > 0
    }
  }

  requirement def ClinicalCommunicationRequirement {
    subject system : MotorolaAPCORBasedEmergencyTelemetrySystem;
    require constraint {
      system.audio.audioBandwidth > 0
    }
  }

  part apcorEmergencyTelemetrySystem : MotorolaAPCORBasedEmergencyTelemetrySystem {
    :>> leads.leadCount = 3;
    :>> conditioner.gain = 1000.0;
    :>> transceiver.nominalTransmitPower = 5.0;
    :>> battery.capacity = 120.0;
    :>> display.refreshPeriod = 0.5;
  }
}