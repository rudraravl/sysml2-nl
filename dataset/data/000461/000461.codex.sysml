package ImplantableLoopRecorderSystem {

  import ScalarValues::*;
  import SI::*;

  attribute def Millivolt :> Real { doc "mV"; }
  attribute def Microampere :> Real { doc "uA"; }
  attribute def MilliampereHour :> Real { doc "mAh"; }
  attribute def Hertz :> Real { doc "Hz"; }
  attribute def BeatsPerMinute :> Real { doc "beats/min"; }
  attribute def Second :> Real { doc "s"; }
  attribute def Minute :> Real { doc "min"; }
  attribute def Day :> Real { doc "day"; }
  attribute def Celsius :> Real { doc "degC"; }
  attribute def ByteCount :> Integer { doc "byte"; }
  attribute def Percent :> Real { doc "%"; }

  enum def DeviceMode {
    enum standby;
    enum monitoring;
    enum eventRecording;
    enum telemetrySession;
    enum lowPower;
    enum endOfService;
    enum safeMode;
  }

  enum def ArrhythmiaKind {
    enum bradycardia;
    enum tachycardia;
    enum pause;
    enum atrialFibrillationSuspected;
    enum patientActivatedSymptom;
    enum noiseRejected;
  }

  enum def LeadContactQuality {
    enum good;
    enum marginal;
    enum poor;
    enum disconnected;
  }

  item def SubcutaneousCardiacSignal {
    attribute sensedAmplitude : Millivolt;
    attribute sampleRate : Hertz;
    attribute signalToNoiseRatio : Real;
    attribute timestampFromImplant : Second;
  }

  item def FilteredEcgSegment {
    attribute duration : Second;
    attribute sampleRate : Hertz;
    attribute minimumAmplitude : Millivolt;
    attribute maximumAmplitude : Millivolt;
    attribute baselineWanderIndex : Real;
  }

  item def ArrhythmiaEvent {
    attribute kind : ArrhythmiaKind;
    attribute startTimeFromImplant : Second;
    attribute duration : Second;
    attribute ventricularRate : BeatsPerMinute;
    attribute confidence : Percent;
    attribute patientActivated : Boolean;
  }

  item def StoredDiagnosticRecord {
    attribute event : ArrhythmiaEvent;
    attribute preTriggerDuration : Second;
    attribute postTriggerDuration : Second;
    attribute compressedSize : ByteCount;
    attribute retentionPriority : Integer;
  }

  item def BatteryStatus {
    attribute remainingCapacity : MilliampereHour;
    attribute stateOfCharge : Percent;
    attribute projectedRemainingServiceLife : Day;
    attribute replacementRecommended : Boolean;
  }

  item def DeviceHealthStatus {
    attribute mode : DeviceMode;
    attribute contactQuality : LeadContactQuality;
    attribute caseTemperature : Celsius;
    attribute battery : BatteryStatus;
    attribute memoryUsed : Percent;
    attribute lastSelfTestPassed : Boolean;
  }

  item def ClinicianCommand {
    attribute requestInterrogation : Boolean;
    attribute setBradyThreshold : BeatsPerMinute;
    attribute setTachyThreshold : BeatsPerMinute;
    attribute setPauseThreshold : Second;
    attribute eraseOldestNoncriticalRecords : Boolean;
  }

  item def PatientActivation {
    attribute activationTimeFromImplant : Second;
    attribute symptomMarkerRequested : Boolean;
  }

  item def TelemetryFrame {
    attribute payloadSize : ByteCount;
    attribute encrypted : Boolean;
    attribute sequenceNumber : Integer;
  }

  port def CardiacSensePort {
    out item cardiacSignal : SubcutaneousCardiacSignal;
  }

  port def AnalogSignalPort {
    in item rawSignal : SubcutaneousCardiacSignal;
    out item conditionedSignal : SubcutaneousCardiacSignal;
  }

  port def EventPort {
    out item detectedEvent : ArrhythmiaEvent;
  }

  port def MemoryWritePort {
    in item recordToStore : StoredDiagnosticRecord;
    out item memoryUsed : Percent;
  }

  port def TelemetryPort {
    in item command : ClinicianCommand;
    out item diagnosticRecord : StoredDiagnosticRecord;
    out item healthStatus : DeviceHealthStatus;
    in item patientActivation : PatientActivation;
    out item telemetryFrame : TelemetryFrame;
  }

  port def PowerPort {
    out item batteryStatus : BatteryStatus;
  }

  part def TitaniumHousing {
    attribute length : Real;
    attribute width : Real;
    attribute thickness : Real;
    attribute hermeticSealIntegrity : Percent;
    attribute biocompatible : Boolean;
  }

  part def SensingElectrode {
    attribute exposedSurfaceArea : Real;
    attribute polarizationImpedance : Real;
    attribute contactQuality : LeadContactQuality;
    port tissueInterface : CardiacSensePort;
  }

  part def AnalogFrontEnd {
    attribute gain : Real;
    attribute highPassCutoff : Hertz;
    attribute lowPassCutoff : Hertz;
    attribute inputReferredNoise : Millivolt;
    port input : AnalogSignalPort;
    port output : AnalogSignalPort;
  }

  part def EcgAcquisitionProcessor {
    attribute samplingRate : Hertz = 256.0;
    attribute adcResolutionBits : Integer = 12;
    port signalInput : AnalogSignalPort;
    port eventOutput : EventPort;
  }

  part def ArrhythmiaDetectionEngine {
    attribute bradyThreshold : BeatsPerMinute = 40.0;
    attribute tachyThreshold : BeatsPerMinute = 180.0;
    attribute pauseThreshold : Second = 3.0;
    attribute minimumEventConfidence : Percent = 85.0;
    port signalInput : AnalogSignalPort;
    port eventOutput : EventPort;
  }

  part def EventMemory {
    attribute totalCapacity : ByteCount = 8388608;
    attribute maximumStoredEvents : Integer = 120;
    attribute overwriteLowPriorityFirst : Boolean = true;
    port writePort : MemoryWritePort;
  }

  part def WirelessTelemetryModule {
    attribute carrierFrequencyMHz : Real = 402.0;
    attribute nominalRange : Real = 2.0;
    attribute encryptedLinkRequired : Boolean = true;
    port telemetry : TelemetryPort;
  }

  part def Battery {
    attribute nominalVoltage : Real = 3.0;
    attribute nominalCapacity : MilliampereHour = 220.0;
    attribute quiescentCurrent : Microampere = 8.0;
    port power : PowerPort;
  }

  part def PatientActivatorReceiver {
    attribute activationWindow : Second = 30.0;
    port telemetry : TelemetryPort;
  }

  action def AcquireAndConditionSignal {
    in item sensed : SubcutaneousCardiacSignal;
    out item conditioned : SubcutaneousCardiacSignal;
    attribute samplingRate : Hertz = 256.0;
    attribute minimumDetectableAmplitude : Millivolt = 0.05;
  }

  action def DetectArrhythmia {
    in item conditioned : SubcutaneousCardiacSignal;
    out item event : ArrhythmiaEvent;
    attribute bradyLimit : BeatsPerMinute = 40.0;
    attribute tachyLimit : BeatsPerMinute = 180.0;
    attribute pauseLimit : Second = 3.0;
  }

  action def StoreDiagnosticSegment {
    in item event : ArrhythmiaEvent;
    in item segment : FilteredEcgSegment;
    out item record : StoredDiagnosticRecord;
    attribute preTriggerCapture : Second = 30.0;
    attribute postTriggerCapture : Second = 30.0;
  }

  action def TransmitDiagnostics {
    in item command : ClinicianCommand;
    in item status : DeviceHealthStatus;
    in item record : StoredDiagnosticRecord;
    out item frame : TelemetryFrame;
  }

  state def RecorderLifeCycle {
    entry action initialize;
    state Standby;
    state ContinuousMonitoring;
    state RecordingEvent;
    state TelemetryActive;
    state LowPowerConservation;
    state EndOfService;
    state SafeMode;

    transition initial then Standby;
    transition Standby_to_Monitoring
      first Standby
      then ContinuousMonitoring;

    transition Monitoring_to_Record
      first ContinuousMonitoring
      accept ArrhythmiaEvent
      then RecordingEvent;

    transition Record_to_Monitoring
      first RecordingEvent
      then ContinuousMonitoring;

    transition Monitoring_to_Telemetry
      first ContinuousMonitoring
      accept ClinicianCommand
      then TelemetryActive;

    transition Telemetry_to_Monitoring
      first TelemetryActive
      then ContinuousMonitoring;

    transition Monitoring_to_LowPower
      first ContinuousMonitoring
      then LowPowerConservation;

    transition LowPower_to_EndOfService
      first LowPowerConservation
      then EndOfService;

    transition Any_to_SafeMode
      first ContinuousMonitoring
      then SafeMode;
  }

  part def ImplantableLoopRecorder {
    doc "Primary function: continuously sense the patient's subcutaneous cardiac electrical activity, automatically detect clinically relevant rhythm abnormalities, preserve ECG evidence around those events, and make diagnostics available through wireless interrogation."

    attribute implantServiceLife : Day = 1095.0;
    attribute maximumImplantTemperature : Celsius = 42.0;
    attribute ingressProtectionVerified : Boolean = true;
    attribute activeMode : DeviceMode;

    part housing : TitaniumHousing;
    part proximalElectrode : SensingElectrode;
    part distalElectrode : SensingElectrode;
    part analogFrontEnd : AnalogFrontEnd;
    part acquisitionProcessor : EcgAcquisitionProcessor;
    part detectionEngine : ArrhythmiaDetectionEngine;
    part eventMemory : EventMemory;
    part telemetryModule : WirelessTelemetryModule;
    part patientActivatorReceiver : PatientActivatorReceiver;
    part battery : Battery;

    port telemetry : TelemetryPort;
    port powerStatus : PowerPort;

    connection proximalSignal
      connect proximalElectrode.tissueInterface to analogFrontEnd.input;

    connection distalSignal
      connect distalElectrode.tissueInterface to analogFrontEnd.input;

    connection conditionedSignal
      connect analogFrontEnd.output to acquisitionProcessor.signalInput;

    connection detectionInput
      connect analogFrontEnd.output to detectionEngine.signalInput;

    connection detectedEventFlow
      connect detectionEngine.eventOutput to acquisitionProcessor.eventOutput;

    connection memoryWrite
      connect acquisitionProcessor.eventOutput to eventMemory.writePort;

    connection externalTelemetry
      connect telemetryModule.telemetry to telemetry;

    connection patientActivationLink
      connect patientActivatorReceiver.telemetry to telemetryModule.telemetry;

    connection batteryStatusLink
      connect battery.power to powerStatus;

    perform action acquire : AcquireAndConditionSignal;
    perform action detect : DetectArrhythmia;
    perform action store : StoreDiagnosticSegment;
    perform action transmit : TransmitDiagnostics;

    exhibit state lifeCycle : RecorderLifeCycle;
  }

  part def ExternalClinicalSystem {
    attribute authorizedClinicianPresent : Boolean;
    attribute sessionEncrypted : Boolean;
    port telemetry : TelemetryPort;
  }

  part def Patient {
    attribute restingHeartRate : BeatsPerMinute;
    attribute implanted : Boolean;
    port cardiacInterface : CardiacSensePort;
    port activatorUse : TelemetryPort;
  }

  part def ImplantableLoopRecorderClinicalUse {
    part patient : Patient;
    part recorder : ImplantableLoopRecorder;
    part programmer : ExternalClinicalSystem;

    connection tissueToElectrodes
      connect patient.cardiacInterface to recorder.proximalElectrode.tissueInterface;

    connection interrogation
      connect recorder.telemetry to programmer.telemetry;

    connection patientActivation
      connect patient.activatorUse to recorder.telemetry;
  }

  requirement def PrimaryFunctionRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The implantable loop recorder shall continuously monitor subcutaneous cardiac electrical activity and provide diagnostic ECG records for detected or patient-marked rhythm events.";
    require constraint {
      recorder.implantServiceLife >= 1095.0
    }
  }

  requirement def ContinuousSensingRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall acquire cardiac signal samples at not less than 128 Hz while in monitoring mode.";
    require constraint {
      recorder.acquisitionProcessor.samplingRate >= 128.0
    }
  }

  requirement def BradycardiaDetectionRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall identify bradycardia when ventricular rate remains below the configured bradycardia threshold.";
    require constraint {
      recorder.detectionEngine.bradyThreshold <= 50.0
    }
  }

  requirement def TachycardiaDetectionRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall identify tachycardia when ventricular rate exceeds the configured tachycardia threshold.";
    require constraint {
      recorder.detectionEngine.tachyThreshold >= 120.0
    }
  }

  requirement def PauseDetectionRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall identify cardiac pause events based on a programmable pause interval.";
    require constraint {
      recorder.detectionEngine.pauseThreshold >= 2.0 and recorder.detectionEngine.pauseThreshold <= 5.0
    }
  }

  requirement def EventStorageRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall retain diagnostic records containing ECG context before and after a detected event.";
    require constraint {
      recorder.eventMemory.maximumStoredEvents >= 60
    }
  }

  requirement def TelemetrySecurityRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall transmit diagnostic records and device status only over an encrypted telemetry session.";
    require constraint {
      recorder.telemetryModule.encryptedLinkRequired == true
    }
  }

  requirement def BatteryLifeRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall support at least three years of implanted monitoring under nominal use conditions.";
    require constraint {
      recorder.implantServiceLife >= 1095.0
    }
  }

  requirement def ThermalSafetyRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall limit exterior housing temperature during operation.";
    require constraint {
      recorder.maximumImplantTemperature <= 42.0
    }
  }

  requirement def PatientActivationRequirement {
    subject recorder : ImplantableLoopRecorder;
    doc "The recorder shall support patient-marked symptom events that trigger diagnostic ECG storage.";
    require constraint {
      recorder.patientActivatorReceiver.activationWindow >= 10.0
    }
  }

  satisfy PrimaryFunctionRequirement by ImplantableLoopRecorder;
  satisfy ContinuousSensingRequirement by EcgAcquisitionProcessor;
  satisfy BradycardiaDetectionRequirement by ArrhythmiaDetectionEngine;
  satisfy TachycardiaDetectionRequirement by ArrhythmiaDetectionEngine;
  satisfy PauseDetectionRequirement by ArrhythmiaDetectionEngine;
  satisfy EventStorageRequirement by EventMemory;
  satisfy TelemetrySecurityRequirement by WirelessTelemetryModule;
  satisfy BatteryLifeRequirement by Battery;
  satisfy ThermalSafetyRequirement by TitaniumHousing;
  satisfy PatientActivationRequirement by PatientActivatorReceiver;
}