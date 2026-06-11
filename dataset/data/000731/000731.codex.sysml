package PerineometerSystem {

  enum def PressureUnit {
    enum kPa;
    enum mmHg;
  }

  enum def ForceUnit {
    enum N;
  }

  enum def TimeUnit {
    enum s;
    enum ms;
  }

  enum def BatteryUnit {
    enum percent;
    enum V;
  }

  enum def UserPromptKind {
    enum relax;
    enum contract;
    enum hold;
    enum rest;
    enum calibrationRequired;
    enum sessionComplete;
  }

  attribute def PressureValue {
    attribute magnitude : Real;
    attribute unit : PressureUnit = PressureUnit::kPa;
  }

  attribute def ForceValue {
    attribute magnitude : Real;
    attribute unit : ForceUnit = ForceUnit::N;
  }

  attribute def DurationValue {
    attribute magnitude : Real;
    attribute unit : TimeUnit = TimeUnit::s;
  }

  attribute def BatteryLevelValue {
    attribute magnitude : Real;
    attribute unit : BatteryUnit = BatteryUnit::percent;
  }

  attribute def SampleRateValue {
    attribute magnitude : Real;
    attribute unit : TimeUnit = TimeUnit::ms;
  }

  item def IntravaginalPressure {
    attribute pressure : PressureValue;
    attribute timestamp : DurationValue;
  }

  item def SensorVoltage {
    attribute voltage : Real;
    attribute timestamp : DurationValue;
  }

  item def DigitalPressureSample {
    attribute pressure : PressureValue;
    attribute baselineCorrected : Boolean;
    attribute timestamp : DurationValue;
  }

  item def MuscleContractionMetric {
    attribute peakPressure : PressureValue;
    attribute averagePressure : PressureValue;
    attribute holdDuration : DurationValue;
    attribute relaxationPressure : PressureValue;
    attribute contractionDetected : Boolean;
  }

  item def UserPrompt {
    attribute kind : UserPromptKind;
    attribute duration : DurationValue;
  }

  item def SessionSummary {
    attribute maximumPeakPressure : PressureValue;
    attribute meanPeakPressure : PressureValue;
    attribute completedContractions : Integer;
    attribute totalSessionTime : DurationValue;
  }

  item def BatteryStatus {
    attribute level : BatteryLevelValue;
    attribute lowBattery : Boolean;
  }

  port def PressureInputPort {
    in item pressure : IntravaginalPressure;
  }

  port def AnalogSignalPort {
    out item voltage : SensorVoltage;
  }

  port def DigitalSamplePort {
    out item sample : DigitalPressureSample;
  }

  port def MetricPort {
    out item metric : MuscleContractionMetric;
  }

  port def PromptPort {
    out item prompt : UserPrompt;
  }

  port def DisplayDataPort {
    in item metric : MuscleContractionMetric;
    in item prompt : UserPrompt;
    in item summary : SessionSummary;
    in item battery : BatteryStatus;
  }

  port def StoragePort {
    in item metric : MuscleContractionMetric;
    in item summary : SessionSummary;
  }

  port def PowerPort {
    out item battery : BatteryStatus;
  }

  part def VaginalPressureProbe {
    attribute outerDiameter : Real;
    attribute compliantSurfacePressureLimit : PressureValue;
    attribute sterilizable : Boolean;
    port pressureIn : PressureInputPort;
    port analogOut : AnalogSignalPort;
  }

  part def PressureTransducer {
    attribute measurementRangeMin : PressureValue;
    attribute measurementRangeMax : PressureValue;
    attribute accuracy : PressureValue;
    attribute samplingInterval : SampleRateValue;
    port analogIn : AnalogSignalPort;
    port digitalOut : DigitalSamplePort;
  }

  part def SignalProcessor {
    attribute baselinePressure : PressureValue;
    attribute contractionThreshold : PressureValue;
    attribute minimumHoldTime : DurationValue;
    port sampleIn : DigitalSamplePort;
    port metricOut : MetricPort;
  }

  part def TherapySessionController {
    attribute targetRepetitions : Integer;
    attribute contractionTime : DurationValue;
    attribute restTime : DurationValue;
    attribute sessionActive : Boolean;
    port metricIn : MetricPort;
    port promptOut : PromptPort;
    port summaryOut : DisplayDataPort;
  }

  part def UserDisplay {
    attribute showsLivePressure : Boolean;
    attribute showsContractionScore : Boolean;
    attribute showsGuidedPrompts : Boolean;
    port dataIn : DisplayDataPort;
  }

  part def SessionMemory {
    attribute retainedSessionCount : Integer;
    port storageIn : StoragePort;
  }

  part def BatteryModule {
    attribute nominalVoltage : Real;
    attribute minimumOperatingLevel : BatteryLevelValue;
    port powerStatusOut : PowerPort;
  }

  part def Perineometer {
    doc /* Primary function: measure pelvic floor muscle contraction by sensing intravaginal pressure changes, converting them into calibrated pressure metrics, and guiding the user through contraction and relaxation exercises. */

    attribute operatingPressureMin : PressureValue = (magnitude = 0.0, unit = PressureUnit::kPa);
    attribute operatingPressureMax : PressureValue = (magnitude = 25.0, unit = PressureUnit::kPa);
    attribute defaultSampleInterval : SampleRateValue = (magnitude = 20.0, unit = TimeUnit::ms);

    part probe : VaginalPressureProbe {
      attribute outerDiameter = 28.0;
      attribute compliantSurfacePressureLimit = (magnitude = 30.0, unit = PressureUnit::kPa);
      attribute sterilizable = true;
    }

    part transducer : PressureTransducer {
      attribute measurementRangeMin = (magnitude = 0.0, unit = PressureUnit::kPa);
      attribute measurementRangeMax = (magnitude = 25.0, unit = PressureUnit::kPa);
      attribute accuracy = (magnitude = 0.2, unit = PressureUnit::kPa);
      attribute samplingInterval = (magnitude = 20.0, unit = TimeUnit::ms);
    }

    part processor : SignalProcessor {
      attribute baselinePressure = (magnitude = 0.0, unit = PressureUnit::kPa);
      attribute contractionThreshold = (magnitude = 2.0, unit = PressureUnit::kPa);
      attribute minimumHoldTime = (magnitude = 2.0, unit = TimeUnit::s);
    }

    part controller : TherapySessionController {
      attribute targetRepetitions = 10;
      attribute contractionTime = (magnitude = 5.0, unit = TimeUnit::s);
      attribute restTime = (magnitude = 5.0, unit = TimeUnit::s);
      attribute sessionActive = false;
    }

    part display : UserDisplay {
      attribute showsLivePressure = true;
      attribute showsContractionScore = true;
      attribute showsGuidedPrompts = true;
    }

    part memory : SessionMemory {
      attribute retainedSessionCount = 100;
    }

    part battery : BatteryModule {
      attribute nominalVoltage = 3.7;
      attribute minimumOperatingLevel = (magnitude = 15.0, unit = BatteryUnit::percent);
    }

    connect probe.analogOut to transducer.analogIn;
    connect transducer.digitalOut to processor.sampleIn;
    connect processor.metricOut to controller.metricIn;
    connect controller.promptOut to display.dataIn;
    connect processor.metricOut to memory.storageIn;
    connect battery.powerStatusOut to display.dataIn;
  }

  action def CalibrateBaseline {
    in item rawSample : DigitalPressureSample;
    out item calibratedSample : DigitalPressureSample;
    attribute calibrationWindow : DurationValue = (magnitude = 3.0, unit = TimeUnit::s);
  }

  action def DetectContraction {
    in item sample : DigitalPressureSample;
    out item metric : MuscleContractionMetric;
    attribute threshold : PressureValue = (magnitude = 2.0, unit = PressureUnit::kPa);
  }

  action def GuideExercise {
    in item metric : MuscleContractionMetric;
    out item prompt : UserPrompt;
    attribute prescribedHold : DurationValue = (magnitude = 5.0, unit = TimeUnit::s);
    attribute prescribedRest : DurationValue = (magnitude = 5.0, unit = TimeUnit::s);
  }

  action def StoreSessionResult {
    in item metric : MuscleContractionMetric;
    out item summary : SessionSummary;
  }

  state def PerineometerOperatingState {
    state Off;
    state SelfTest;
    state Calibration;
    state Ready;
    state Measuring;
    state ExerciseGuidance;
    state SessionReview;
    state LowBatteryLockout;
    state Fault;

    transition first Off;
    transition Off to SelfTest
      accept PowerButtonPressed;

    transition SelfTest to Calibration
      accept SelfTestPassed;

    transition SelfTest to Fault
      accept SelfTestFailed;

    transition Calibration to Ready
      accept BaselineStable;

    transition Calibration to Fault
      accept BaselineOutOfRange;

    transition Ready to Measuring
      accept ProbeInserted;

    transition Measuring to ExerciseGuidance
      accept SessionStarted;

    transition ExerciseGuidance to SessionReview
      accept TargetRepetitionsCompleted;

    transition SessionReview to Ready
      accept SummaryAcknowledged;

    transition Ready to LowBatteryLockout
      accept BatteryBelowMinimum;

    transition Measuring to LowBatteryLockout
      accept BatteryBelowMinimum;

    transition ExerciseGuidance to LowBatteryLockout
      accept BatteryBelowMinimum;

    transition LowBatteryLockout to Off
      accept PowerRemoved;

    transition Fault to Off
      accept PowerRemoved;
  }

  requirement def MeasurePelvicFloorContraction {
    subject device : Perineometer;
    require constraint {
      device.operatingPressureMin.magnitude <= 0.0 and
      device.operatingPressureMax.magnitude >= 25.0
    }
  }

  requirement def PressureAccuracyRequirement {
    subject transducer : PressureTransducer;
    require constraint {
      transducer.accuracy.magnitude <= 0.5
    }
  }

  requirement def SamplingRequirement {
    subject transducer : PressureTransducer;
    require constraint {
      transducer.samplingInterval.magnitude <= 50.0
    }
  }

  requirement def GuidedExerciseRequirement {
    subject controller : TherapySessionController;
    require constraint {
      controller.targetRepetitions >= 5 and
      controller.contractionTime.magnitude >= 3.0 and
      controller.restTime.magnitude >= 3.0
    }
  }

  requirement def LowBatterySafetyRequirement {
    subject battery : BatteryModule;
    require constraint {
      battery.minimumOperatingLevel.magnitude >= 10.0
    }
  }

  requirement def SessionRetentionRequirement {
    subject memory : SessionMemory;
    require constraint {
      memory.retainedSessionCount >= 30
    }
  }

  part perineometerSystem : Perineometer;

  satisfy MeasurePelvicFloorContraction by perineometerSystem;
  satisfy PressureAccuracyRequirement by perineometerSystem.transducer;
  satisfy SamplingRequirement by perineometerSystem.transducer;
  satisfy GuidedExerciseRequirement by perineometerSystem.controller;
  satisfy LowBatterySafetyRequirement by perineometerSystem.battery;
  satisfy SessionRetentionRequirement by perineometerSystem.memory;
}