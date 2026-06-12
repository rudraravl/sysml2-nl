package GlassBreakDetectorModel {

  import ScalarValues::*;
  import SI::*;

  unit decibelSymbol: Unit {
    symbol = "dB";
  }

  unit hertzSymbol: Unit {
    symbol = "Hz";
  }

  unit millisecondSymbol: Unit {
    symbol = "ms";
  }

  value def SoundPressureLevel :> Real {
    unit = decibelSymbol;
  }

  value def Frequency :> Real {
    unit = hertzSymbol;
  }

  value def Duration :> Real {
    unit = millisecondSymbol;
  }

  value def ConfidenceScore :> Real {
    range = "0.0..1.0";
  }

  value def BatteryChargePercent :> Real {
    unit = "%";
    range = "0..100";
  }

  enum def DetectorMode {
    enum idle;
    enum armed;
    enum analyzing;
    enum alarmed;
    enum faulted;
    enum muted;
  }

  enum def AlarmSeverity {
    enum none;
    enum warning;
    enum intrusionAlarm;
    enum tamperAlarm;
    enum maintenanceFault;
  }

  item def AcousticWave {
    attribute peakLevel: SoundPressureLevel;
    attribute dominantFrequency: Frequency;
    attribute duration: Duration;
  }

  item def AcousticSample {
    attribute sampleRate: Frequency;
    attribute measuredLevel: SoundPressureLevel;
    attribute spectralCentroid: Frequency;
    attribute sampleWindow: Duration;
  }

  item def GlassBreakSignature {
    attribute lowFrequencyImpactLevel: SoundPressureLevel;
    attribute highFrequencyShatterLevel: SoundPressureLevel;
    attribute timeBetweenImpactAndShatter: Duration;
    attribute confidence: ConfidenceScore;
  }

  item def AlarmCommand {
    attribute severity: AlarmSeverity;
    attribute confidence: ConfidenceScore;
    attribute message: String;
  }

  item def StatusReport {
    attribute mode: DetectorMode;
    attribute batteryCharge: BatteryChargePercent;
    attribute sensorHealthy: Boolean;
    attribute networkConnected: Boolean;
  }

  item def PowerEnergy {
    attribute voltage: Real;
    attribute current: Real;
  }

  port def AcousticInputPort {
    in item acousticWave: AcousticWave;
  }

  port def SampleOutputPort {
    out item acousticSample: AcousticSample;
  }

  port def SampleInputPort {
    in item acousticSample: AcousticSample;
  }

  port def AlarmOutputPort {
    out item alarmCommand: AlarmCommand;
  }

  port def AlarmInputPort {
    in item alarmCommand: AlarmCommand;
  }

  port def StatusOutputPort {
    out item statusReport: StatusReport;
  }

  port def PowerInputPort {
    in item power: PowerEnergy;
  }

  part def MEMSMicrophone {
    attribute sensitivity: Real = -38.0;
    attribute minimumDetectableLevel: SoundPressureLevel = 35.0;
    attribute maximumDetectableLevel: SoundPressureLevel = 120.0;
    attribute frequencyLowLimit: Frequency = 20.0;
    attribute frequencyHighLimit: Frequency = 20000.0;

    port acousticIn: AcousticInputPort;
    port samplesOut: SampleOutputPort;

    action digitizeAcousticWave {
      in item incomingWave: AcousticWave;
      out item digitizedSample: AcousticSample;

      objective {
        convert incomingWave into digitizedSample with sampleRate >= 44100.0;
      }
    }
  }

  part def SignalConditioner {
    attribute highPassCutoff: Frequency = 80.0;
    attribute lowPassCutoff: Frequency = 18000.0;
    attribute gain: Real = 12.0;

    port rawSampleIn: SampleInputPort;
    port conditionedSampleOut: SampleOutputPort;

    action filterAndNormalize {
      in item rawSample: AcousticSample;
      out item conditionedSample: AcousticSample;

      objective {
        reduce steady environmental noise and preserve impact and shatter transients;
      }
    }
  }

  part def GlassBreakClassifier {
    attribute impactBandLow: Frequency = 80.0;
    attribute impactBandHigh: Frequency = 600.0;
    attribute shatterBandLow: Frequency = 3000.0;
    attribute shatterBandHigh: Frequency = 16000.0;
    attribute minimumAlarmConfidence: ConfidenceScore = 0.82;
    attribute maximumCorrelationWindow: Duration = 300.0;

    port sampleIn: SampleInputPort;
    port alarmOut: AlarmOutputPort;
    port statusOut: StatusOutputPort;

    action estimateSignature {
      in item conditionedSample: AcousticSample;
      out item signature: GlassBreakSignature;

      objective {
        detect paired low-frequency impact and high-frequency shatter patterns within maximumCorrelationWindow;
      }
    }

    action classifyEvent {
      in item signature: GlassBreakSignature;
      out item command: AlarmCommand;

      objective {
        command.severity =
          if signature.confidence >= minimumAlarmConfidence
          then AlarmSeverity::intrusionAlarm
          else AlarmSeverity::none;
      }
    }
  }

  part def AlarmAnnunciator {
    attribute sirenLevel: SoundPressureLevel = 85.0;
    attribute visualIndicatorEnabled: Boolean = true;

    port alarmIn: AlarmInputPort;

    action activateLocalAlarm {
      in item alarmCommand: AlarmCommand;

      objective {
        produce audible and visual alert when alarmCommand.severity == AlarmSeverity::intrusionAlarm;
      }
    }
  }

  part def SecurityPanelInterface {
    attribute wirelessRange: Real = 30.0;
    attribute heartbeatInterval: Duration = 60000.0;

    port alarmIn: AlarmInputPort;
    port statusIn: StatusOutputPort;

    action transmitAlarm {
      in item alarmCommand: AlarmCommand;

      objective {
        send alarmCommand to external security panel with severity and confidence;
      }
    }

    action transmitStatus {
      in item statusReport: StatusReport;

      objective {
        periodically report detector mode, battery level, sensor health, and network connectivity;
      }
    }
  }

  part def PowerSupply {
    attribute nominalVoltage: Real = 3.0;
    attribute lowBatteryThreshold: BatteryChargePercent = 15.0;
    attribute batteryCharge: BatteryChargePercent = 100.0;

    port powerOut: PowerInputPort;

    action monitorBattery {
      out item statusReport: StatusReport;

      objective {
        report maintenance fault when batteryCharge <= lowBatteryThreshold;
      }
    }
  }

  part def TamperSensor {
    attribute enclosureClosed: Boolean = true;

    port alarmOut: AlarmOutputPort;

    action detectTamper {
      out item tamperAlarm: AlarmCommand;

      objective {
        set tamperAlarm.severity = AlarmSeverity::tamperAlarm when enclosureClosed == false;
      }
    }
  }

  part def GlassBreakDetector {
    attribute primaryFunction: String =
      "Monitor acoustic energy in a protected room and issue an intrusion alarm when sound patterns match breaking glass.";
    attribute currentMode: DetectorMode = DetectorMode::idle;
    attribute coveredRadius: Real = 7.5;

    port roomAcoustics: AcousticInputPort;
    port alarmToPanel: AlarmOutputPort;
    port healthStatus: StatusOutputPort;
    port powerInput: PowerInputPort;

    part microphone: MEMSMicrophone;
    part conditioner: SignalConditioner;
    part classifier: GlassBreakClassifier;
    part annunciator: AlarmAnnunciator;
    part panelInterface: SecurityPanelInterface;
    part powerSupply: PowerSupply;
    part tamperSensor: TamperSensor;

    connect roomAcoustics to microphone.acousticIn;
    connect microphone.samplesOut to conditioner.rawSampleIn;
    connect conditioner.conditionedSampleOut to classifier.sampleIn;
    connect classifier.alarmOut to annunciator.alarmIn;
    connect classifier.alarmOut to panelInterface.alarmIn;
    connect classifier.alarmOut to alarmToPanel;
    connect classifier.statusOut to panelInterface.statusIn;
    connect classifier.statusOut to healthStatus;
    connect powerInput to powerSupply.powerOut;
    connect tamperSensor.alarmOut to panelInterface.alarmIn;
    connect tamperSensor.alarmOut to alarmToPanel;

    action monitorProtectedSpace {
      in item roomSound: AcousticWave;
      out item alarmDecision: AlarmCommand;

      first start;
      then sampleSound;
      then conditionSignal;
      then identifyGlassSignature;
      then decideAlarm;
      then publishStatus;

      action sampleSound {
        objective {
          microphone.digitizeAcousticWave converts roomSound into AcousticSample;
        }
      }

      action conditionSignal {
        objective {
          conditioner.filterAndNormalize removes non-glass ambient noise;
        }
      }

      action identifyGlassSignature {
        objective {
          classifier.estimateSignature identifies impact-shatter correlation;
        }
      }

      action decideAlarm {
        objective {
          classifier.classifyEvent emits intrusion alarm only when confidence is sufficient;
        }
      }

      action publishStatus {
        objective {
          panelInterface.transmitStatus reports operational health after each analysis cycle;
        }
      }
    }

    state def OperatingStateMachine {
      state Initializing;
      state Idle;
      state Armed;
      state Analyzing;
      state Alarmed;
      state Muted;
      state Faulted;

      transition first Initializing;
      transition Initializing then Idle;
      transition Idle then Armed
        if currentMode == DetectorMode::armed;
      transition Armed then Analyzing
        if roomAcoustics.acousticWave.peakLevel >= 70.0;
      transition Analyzing then Alarmed
        if classifier.minimumAlarmConfidence <= 1.0;
      transition Analyzing then Armed
        if classifier.minimumAlarmConfidence > 1.0;
      transition Alarmed then Muted
        if currentMode == DetectorMode::muted;
      transition Muted then Armed
        if currentMode == DetectorMode::armed;
      transition Armed then Faulted
        if powerSupply.batteryCharge <= powerSupply.lowBatteryThreshold;
      transition Faulted then Idle
        if powerSupply.batteryCharge > powerSupply.lowBatteryThreshold;
    }
  }

  part protectedRoom {
    attribute roomName: String = "Perimeter living area";
    attribute glassSurfaceArea: Real = 12.0;

    port acousticEnvironment: AcousticInputPort;
  }

  part installedDetector: GlassBreakDetector {
    attribute coveredRadius = 7.5;
  }

  connect protectedRoom.acousticEnvironment to installedDetector.roomAcoustics;

  requirement def PrimaryFunctionRequirement {
    subject detector: GlassBreakDetector;

    require constraint {
      detector.primaryFunction ==
      "Monitor acoustic energy in a protected room and issue an intrusion alarm when sound patterns match breaking glass."
    }
  }

  requirement def DetectionPerformanceRequirement {
    subject detector: GlassBreakDetector;

    require constraint {
      detector.classifier.minimumAlarmConfidence >= 0.80 and
      detector.classifier.maximumCorrelationWindow <= 300.0
    }
  }

  requirement def AcousticCoverageRequirement {
    subject detector: GlassBreakDetector;

    require constraint {
      detector.coveredRadius >= 7.5 and
      detector.microphone.frequencyLowLimit <= 80.0 and
      detector.microphone.frequencyHighLimit >= 16000.0
    }
  }

  requirement def FalseAlarmReductionRequirement {
    subject detector: GlassBreakDetector;

    require constraint {
      detector.conditioner.highPassCutoff >= 60.0 and
      detector.classifier.impactBandHigh < detector.classifier.shatterBandLow
    }
  }

  requirement def AlarmOutputRequirement {
    subject detector: GlassBreakDetector;

    require constraint {
      detector.annunciator.sirenLevel >= 85.0
    }
  }

  requirement def BatteryMonitoringRequirement {
    subject detector: GlassBreakDetector;

    require constraint {
      detector.powerSupply.lowBatteryThreshold >= 10.0 and
      detector.powerSupply.lowBatteryThreshold <= 20.0
    }
  }

  satisfy PrimaryFunctionRequirement by installedDetector;
  satisfy DetectionPerformanceRequirement by installedDetector;
  satisfy AcousticCoverageRequirement by installedDetector;
  satisfy FalseAlarmReductionRequirement by installedDetector;
  satisfy AlarmOutputRequirement by installedDetector;
  satisfy BatteryMonitoringRequirement by installedDetector;
}