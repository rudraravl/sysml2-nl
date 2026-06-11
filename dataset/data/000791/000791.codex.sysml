package TGuardSystemModel {

  import ScalarValues::*;
  import SI::*;
  import ISQ::*;

  attribute def Celsius :> Real {
    unit = "degC";
  }

  attribute def Percent :> Real {
    unit = "%";
  }

  attribute def Volt :> Real {
    unit = "V";
  }

  attribute def AmpereHour :> Real {
    unit = "A.h";
  }

  attribute def Meter :> Real {
    unit = "m";
  }

  attribute def Second :> Real {
    unit = "s";
  }

  attribute def Decibel :> Real {
    unit = "dB";
  }

  attribute def RiskScore :> Real {
    unit = "1";
  }

  item def ThermalSample {
    attribute surfaceTemperature : Celsius;
    attribute ambientTemperature : Celsius;
    attribute humidity : Percent;
    attribute sampleTime : Second;
  }

  item def MotionSample {
    attribute distanceToTarget : Meter;
    attribute relativeSpeed : Real;
    attribute confidence : Percent;
    attribute sampleTime : Second;
  }

  item def GuardAssessment {
    attribute threatDetected : Boolean;
    attribute overheatingDetected : Boolean;
    attribute tamperDetected : Boolean;
    attribute risk : RiskScore;
    attribute message : String;
  }

  item def AlertCommand {
    attribute audibleLevel : Decibel;
    attribute visualEnabled : Boolean;
    attribute networkNotificationEnabled : Boolean;
    attribute priority : Integer;
  }

  item def PowerFlow {
    attribute voltage : Volt;
    attribute current : Real;
  }

  port def SensorDataPort {
    out item thermal : ThermalSample;
    out item motion : MotionSample;
  }

  port def AssessmentPort {
    out item assessment : GuardAssessment;
  }

  port def AlertPort {
    in item command : AlertCommand;
  }

  port def PowerPort {
    in item power : PowerFlow;
  }

  action def AcquireSensorData {
    out thermal : ThermalSample;
    out motion : MotionSample;
  }

  action def AssessGuardCondition {
    in thermal : ThermalSample;
    in motion : MotionSample;
    out assessment : GuardAssessment;
  }

  action def IssueAlert {
    in assessment : GuardAssessment;
    out command : AlertCommand;
  }

  action def ReportStatus {
    in assessment : GuardAssessment;
  }

  part def ThermalSensor {
    port data : SensorDataPort;
    attribute measurementRangeLow : Celsius = -40.0;
    attribute measurementRangeHigh : Celsius = 125.0;
    attribute accuracy : Celsius = 1.5;

    perform action acquireThermal {
      out sample : ThermalSample;
    }
  }

  part def MotionSensor {
    port data : SensorDataPort;
    attribute maximumDetectionRange : Meter = 12.0;
    attribute minimumDetectionRange : Meter = 0.2;
    attribute confidenceThreshold : Percent = 75.0;

    perform action acquireMotion {
      out sample : MotionSample;
    }
  }

  part def TamperSensor {
    attribute enclosureOpen : Boolean = false;
    attribute vibrationDetected : Boolean = false;
    attribute tamperLatched : Boolean = false;
  }

  part def BatteryPack {
    port output : PowerPort;
    attribute nominalVoltage : Volt = 12.0;
    attribute capacity : AmpereHour = 8.0;
    attribute stateOfCharge : Percent = 100.0;
    attribute lowBatteryThreshold : Percent = 20.0;
  }

  part def GuardController {
    port sensorInput : SensorDataPort;
    port assessmentOutput : AssessmentPort;
    port alertOutput : AlertPort;

    attribute thermalTripLimit : Celsius = 70.0;
    attribute motionRiskDistance : Meter = 2.0;
    attribute highRiskThreshold : RiskScore = 0.75;
    attribute currentRisk : RiskScore = 0.0;
    attribute enabled : Boolean = true;

    perform action acquire : AcquireSensorData;
    perform action assess : AssessGuardCondition;
    perform action alert : IssueAlert;
    perform action report : ReportStatus;

    state def OperatingState {
      entry action initialize {
        enabled = true;
        currentRisk = 0.0;
      }

      state Monitoring;
      state Evaluating;
      state Alerting;
      state Faulted;
      state Standby;

      initial then Monitoring;

      transition Monitoring_to_Evaluating
        first Monitoring
        accept thermal : ThermalSample
        then Evaluating;

      transition Evaluating_to_Alerting
        first Evaluating
        if currentRisk >= highRiskThreshold
        then Alerting;

      transition Evaluating_to_Monitoring
        first Evaluating
        if currentRisk < highRiskThreshold
        then Monitoring;

      transition Alerting_to_Monitoring
        first Alerting
        accept reset : Boolean
        if reset == true
        then Monitoring;

      transition Any_to_Faulted
        first Monitoring
        accept faultDetected : Boolean
        if faultDetected == true
        then Faulted;

      transition Faulted_to_Standby
        first Faulted
        accept acknowledge : Boolean
        if acknowledge == true
        then Standby;

      transition Standby_to_Monitoring
        first Standby
        accept enableCommand : Boolean
        if enableCommand == true
        then Monitoring;
    }
  }

  part def AudibleVisualAlarm {
    port alertInput : AlertPort;
    attribute maximumSoundLevel : Decibel = 95.0;
    attribute strobeEnabled : Boolean = true;
    attribute active : Boolean = false;

    perform action activate {
      in command : AlertCommand;
    }

    perform action deactivate;
  }

  part def CommunicationModule {
    port alertInput : AlertPort;
    attribute networkConnected : Boolean = true;
    attribute retryCount : Integer = 3;
    attribute lastMessageDelivered : Boolean = false;

    perform action transmitAlert {
      in assessment : GuardAssessment;
    }
  }

  part def Enclosure {
    attribute ingressProtectionRating : String = "IP65";
    attribute locked : Boolean = true;
    attribute tamperResistant : Boolean = true;
  }

  part def TGuard {
    doc
    /* TGuard is an autonomous protective monitoring system whose primary high-level function is to continuously guard a protected asset or zone by sensing thermal, motion, and tamper conditions, assessing risk, and issuing local and remote alerts when unsafe or unauthorized conditions are detected. */

    port powerInput : PowerPort;
    port assessmentOutput : AssessmentPort;

    part battery : BatteryPack;
    part thermalSensor : ThermalSensor;
    part motionSensor : MotionSensor;
    part tamperSensor : TamperSensor;
    part controller : GuardController;
    part alarm : AudibleVisualAlarm;
    part comms : CommunicationModule;
    part enclosure : Enclosure;

    attribute protectedZoneRadius : Meter = 5.0;
    attribute nominalScanPeriod : Second = 1.0;
    attribute operatingTemperatureLow : Celsius = -20.0;
    attribute operatingTemperatureHigh : Celsius = 60.0;
    attribute systemEnabled : Boolean = true;

    connect battery.output to controller.sensorInput;
    connect thermalSensor.data to controller.sensorInput;
    connect motionSensor.data to controller.sensorInput;
    connect controller.alertOutput to alarm.alertInput;
    connect controller.alertOutput to comms.alertInput;
    connect controller.assessmentOutput to assessmentOutput;

    perform action guardProtectedZone {
      first start;
      then acquire : AcquireSensorData;
      then assess : AssessGuardCondition;
      then decide;

      if assess.assessment.threatDetected or assess.assessment.overheatingDetected or assess.assessment.tamperDetected {
        then alert : IssueAlert;
        then report : ReportStatus;
      } else {
        then reportNormal : ReportStatus;
      }

      then done;
    }
  }

  requirement def PrimaryFunctionRequirement {
    subject guardedSystem : TGuard;
    doc
    /* The TGuard shall continuously monitor the protected zone and provide timely alerts when hazardous heat, unauthorized motion, or physical tampering is detected. */
  }

  requirement def ThermalDetectionRequirement {
    subject guardedSystem : TGuard;
    require constraint {
      guardedSystem.controller.thermalTripLimit <= 70.0
    }
    doc
    /* The TGuard shall classify surface temperatures at or above 70 degC as an overheating condition. */
  }

  requirement def MotionDetectionRequirement {
    subject guardedSystem : TGuard;
    require constraint {
      guardedSystem.motionSensor.maximumDetectionRange >= guardedSystem.protectedZoneRadius
    }
    doc
    /* The motion sensor shall cover the full protected zone radius. */
  }

  requirement def AlertRequirement {
    subject guardedSystem : TGuard;
    require constraint {
      guardedSystem.alarm.maximumSoundLevel >= 90.0
    }
    doc
    /* The TGuard shall provide an audible alert of at least 90 dB for high-risk conditions. */
  }

  requirement def PowerEnduranceRequirement {
    subject guardedSystem : TGuard;
    require constraint {
      guardedSystem.battery.capacity >= 8.0
    }
    doc
    /* The battery pack shall support autonomous operation with a capacity of at least 8 A.h. */
  }

  requirement def EnvironmentalRequirement {
    subject guardedSystem : TGuard;
    require constraint {
      guardedSystem.operatingTemperatureLow <= -20.0 and guardedSystem.operatingTemperatureHigh >= 60.0
    }
    doc
    /* The TGuard shall operate across the expected outdoor environmental temperature range. */
  }

  requirement def TamperRequirement {
    subject guardedSystem : TGuard;
    doc
    /* The TGuard shall latch and report a tamper condition when enclosure opening or abnormal vibration is detected. */
  }

  satisfy PrimaryFunctionRequirement by TGuard;
  satisfy ThermalDetectionRequirement by TGuard;
  satisfy MotionDetectionRequirement by TGuard;
  satisfy AlertRequirement by TGuard;
  satisfy PowerEnduranceRequirement by TGuard;
  satisfy EnvironmentalRequirement by TGuard;
  satisfy TamperRequirement by TGuard;

  part tguardSystem : TGuard {
    attribute protectedZoneRadius = 5.0;
    attribute nominalScanPeriod = 1.0;
    attribute systemEnabled = true;
  }
}