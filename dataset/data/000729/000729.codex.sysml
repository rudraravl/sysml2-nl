package PeakExpiratoryFlowModel {

  import ScalarValues::*;
  import SI::*;

  value def Liter;
  value def Minute;
  value def LiterPerMinute {
    unit = Liter / Minute;
  }

  value def Millisecond;
  value def Percent;
  value def Pascal;
  value def DegreeCelsius;

  item def ExhaledAir {
    attribute instantaneousFlow: LiterPerMinute;
    attribute pressure: Pascal;
    attribute temperature: DegreeCelsius;
    attribute elapsedTime: Millisecond;
  }

  item def FlowSample {
    attribute sampleTime: Millisecond;
    attribute flow: LiterPerMinute;
  }

  item def PeakFlowReading {
    attribute peakFlow: LiterPerMinute;
    attribute measuredAt: Millisecond;
    attribute qualityScore: Percent;
    attribute maneuverAccepted: Boolean;
  }

  item def UserCommand {
    attribute startRequested: Boolean;
    attribute resetRequested: Boolean;
  }

  item def DisplayMessage {
    attribute shownPeakFlow: LiterPerMinute;
    attribute statusText: String;
  }

  port def BreathInputPort {
    in item breath: ExhaledAir;
  }

  port def FlowSignalPort {
    out item sample: FlowSample;
  }

  port def SampleInputPort {
    in item sample: FlowSample;
  }

  port def ReadingPort {
    out item reading: PeakFlowReading;
  }

  port def ReadingInputPort {
    in item reading: PeakFlowReading;
  }

  port def UserCommandPort {
    in item command: UserCommand;
  }

  port def DisplayOutputPort {
    out item message: DisplayMessage;
  }

  part def Mouthpiece {
    port breathIn: BreathInputPort;
    attribute internalDiameter: Length;
    attribute deadVolume: Liter;
  }

  part def FlowChannel {
    port inlet: BreathInputPort;
    port outlet: BreathInputPort;
    attribute flowResistance: Real;
    attribute maxSupportedFlow: LiterPerMinute;
  }

  part def FlowSensor {
    port sensedAir: BreathInputPort;
    port flowSignal: FlowSignalPort;

    attribute samplingPeriod: Millisecond;
    attribute measurementRangeMin: LiterPerMinute;
    attribute measurementRangeMax: LiterPerMinute;
    attribute accuracy: Percent;
    attribute responseTime: Millisecond;
  }

  part def PeakDetector {
    port sampleIn: SampleInputPort;
    port readingOut: ReadingPort;

    attribute currentPeak: LiterPerMinute;
    attribute minimumValidFlow: LiterPerMinute;
    attribute minimumManeuverDuration: Millisecond;
    attribute maximumManeuverDuration: Millisecond;
    attribute acceptedQualityThreshold: Percent;
  }

  part def DisplayUnit {
    port readingIn: ReadingInputPort;
    port displayOut: DisplayOutputPort;

    attribute refreshPeriod: Millisecond;
    attribute displayedValue: LiterPerMinute;
  }

  part def UserInterface {
    port commandIn: UserCommandPort;
    port displayMessageIn: ReadingInputPort;

    attribute lastDisplayedPeak: LiterPerMinute;
    attribute readyIndicator: Boolean;
    attribute errorIndicator: Boolean;
  }

  part def PowerSupply {
    attribute nominalVoltage: Real;
    attribute remainingCapacity: Percent;
    attribute lowPowerThreshold: Percent;
  }

  action def AcquireFlowSample {
    in air: ExhaledAir;
    out sample: FlowSample;

    action convertPressureToFlow;
    action timestampSample;
    action emitSample;

    first start then convertPressureToFlow;
    then timestampSample;
    then emitSample;
    then done;
  }

  action def DeterminePeakFlow {
    in sample: FlowSample;
    in currentPeak: LiterPerMinute;
    out updatedPeak: LiterPerMinute;

    action compareSampleToPeak;
    action retainHigherValue;

    first start then compareSampleToPeak;
    then retainHigherValue;
    then done;
  }

  action def ValidateExhalationManeuver {
    in peak: LiterPerMinute;
    in duration: Millisecond;
    out accepted: Boolean;
    out score: Percent;

    action checkMinimumFlow;
    action checkDurationWindow;
    action computeQualityScore;

    first start then checkMinimumFlow;
    then checkDurationWindow;
    then computeQualityScore;
    then done;
  }

  action def ReportPeakFlow {
    in reading: PeakFlowReading;
    out message: DisplayMessage;

    action formatNumericReading;
    action attachStatusText;
    action updateDisplay;

    first start then formatNumericReading;
    then attachStatusText;
    then updateDisplay;
    then done;
  }

  state def PeakFlowMeasurementStateMachine {
    state Off;
    state Ready;
    state Measuring;
    state Processing;
    state ShowingResult;
    state Error;

    transition initialToOff first Off;
    transition powerAvailable from Off to Ready;
    transition startMeasurement from Ready to Measuring;
    transition breathEnded from Measuring to Processing;
    transition validReading from Processing to ShowingResult;
    transition invalidManeuver from Processing to Error;
    transition resetAfterResult from ShowingResult to Ready;
    transition resetAfterError from Error to Ready;
    transition powerRemoved from Ready to Off;
  }

  part def PeakExpiratoryFlowSystem {
    port patientBreathIn: BreathInputPort;
    port userCommandIn: UserCommandPort;
    port displayOut: DisplayOutputPort;

    part mouthpiece: Mouthpiece {
      attribute internalDiameter = 0.022 [m];
      attribute deadVolume = 0.035 [Liter];
    }

    part flowChannel: FlowChannel {
      attribute maxSupportedFlow = 900 [LiterPerMinute];
    }

    part sensor: FlowSensor {
      attribute samplingPeriod = 10 [Millisecond];
      attribute measurementRangeMin = 0 [LiterPerMinute];
      attribute measurementRangeMax = 900 [LiterPerMinute];
      attribute accuracy = 5 [Percent];
      attribute responseTime = 30 [Millisecond];
    }

    part peakDetector: PeakDetector {
      attribute currentPeak = 0 [LiterPerMinute];
      attribute minimumValidFlow = 60 [LiterPerMinute];
      attribute minimumManeuverDuration = 200 [Millisecond];
      attribute maximumManeuverDuration = 5000 [Millisecond];
      attribute acceptedQualityThreshold = 80 [Percent];
    }

    part display: DisplayUnit {
      attribute refreshPeriod = 100 [Millisecond];
      attribute displayedValue = 0 [LiterPerMinute];
    }

    part userInterface: UserInterface {
      attribute readyIndicator = true;
      attribute errorIndicator = false;
    }

    part powerSupply: PowerSupply {
      attribute nominalVoltage = 3.0;
      attribute remainingCapacity = 100 [Percent];
      attribute lowPowerThreshold = 15 [Percent];
    }

    perform action acquireFlowSample: AcquireFlowSample;
    perform action determinePeakFlow: DeterminePeakFlow;
    perform action validateManeuver: ValidateExhalationManeuver;
    perform action reportPeakFlow: ReportPeakFlow;

    exhibit state measurementLifecycle: PeakFlowMeasurementStateMachine;

    connect patientBreathIn to mouthpiece.breathIn;
    connect mouthpiece.breathIn to flowChannel.inlet;
    connect flowChannel.outlet to sensor.sensedAir;
    connect sensor.flowSignal to peakDetector.sampleIn;
    connect peakDetector.readingOut to display.readingIn;
    connect peakDetector.readingOut to userInterface.displayMessageIn;
    connect userCommandIn to userInterface.commandIn;
    connect display.displayOut to displayOut;
  }

  requirement def PrimaryFunctionRequirement {
    subject system: PeakExpiratoryFlowSystem;

    doc
    /*
     The system shall measure the maximum expiratory airflow achieved during a forced exhalation and present the peak expiratory flow value to the user as a clinical respiratory performance indicator.
    */

    require constraint {
      system.sensor.measurementRangeMax >= 900 [LiterPerMinute]
    }
  }

  requirement def AccuracyRequirement {
    subject system: PeakExpiratoryFlowSystem;

    doc
    /*
     The system shall report peak expiratory flow with measurement accuracy sufficient for home or clinical screening use.
    */

    require constraint {
      system.sensor.accuracy <= 5 [Percent]
    }
  }

  requirement def ResponseRequirement {
    subject system: PeakExpiratoryFlowSystem;

    doc
    /*
     The system shall detect and update peak flow quickly enough to capture short forced expiratory maneuvers.
    */

    require constraint {
      system.sensor.responseTime <= 30 [Millisecond]
    }
  }

  requirement def ValidManeuverRequirement {
    subject system: PeakExpiratoryFlowSystem;

    doc
    /*
     The system shall reject exhalation maneuvers that are too weak or outside the valid duration window.
    */

    require constraint {
      system.peakDetector.minimumValidFlow >= 60 [LiterPerMinute] and
      system.peakDetector.minimumManeuverDuration >= 200 [Millisecond] and
      system.peakDetector.maximumManeuverDuration <= 5000 [Millisecond]
    }
  }

  requirement def DisplayRequirement {
    subject system: PeakExpiratoryFlowSystem;

    doc
    /*
     The system shall display the accepted peak expiratory flow reading after processing the forced exhalation.
    */

    require constraint {
      system.display.refreshPeriod <= 100 [Millisecond]
    }
  }

  satisfy PrimaryFunctionRequirement by PeakExpiratoryFlowSystem;
  satisfy AccuracyRequirement by PeakExpiratoryFlowSystem;
  satisfy ResponseRequirement by PeakExpiratoryFlowSystem;
  satisfy ValidManeuverRequirement by PeakExpiratoryFlowSystem;
  satisfy DisplayRequirement by PeakExpiratoryFlowSystem;
}