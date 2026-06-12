package EducationalRoboticsSystem {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def Percentage {
    :> Real;
    unit = "%";
  }

  attribute def ConfidenceScore {
    :> Real;
    range = "0..1";
  }

  attribute def BatteryCharge {
    :> Real;
    unit = "%";
    range = "0..100";
  }

  attribute def Distance {
    :> Real;
    unit = "m";
  }

  attribute def Speed {
    :> Real;
    unit = "m/s";
  }

  attribute def Angle {
    :> Real;
    unit = "deg";
  }

  attribute def Voltage {
    :> Real;
    unit = "V";
  }

  attribute def Current {
    :> Real;
    unit = "A";
  }

  attribute def DataRate {
    :> Real;
    unit = "Mb/s";
  }

  item def StudentCommand {
    attribute commandId : String;
    attribute commandType : CommandKind;
    attribute targetSpeed : Speed;
    attribute targetTurnAngle : Angle;
    attribute programText : String;
  }

  enum def CommandKind {
    enum idle;
    enum drive;
    enum turn;
    enum stop;
    enum runProgram;
    enum calibrate;
    enum requestStatus;
  }

  item def SensorObservation {
    attribute rangeToObstacle : Distance;
    attribute lineDetected : Boolean;
    attribute ambientLight : Illuminance;
    attribute accelerationMagnitude : Acceleration;
    attribute confidence : ConfidenceScore;
  }

  item def LearningFeedback {
    attribute message : String;
    attribute success : Boolean;
    attribute conceptTag : String;
    attribute hintLevel : Integer;
  }

  item def RobotStatus {
    attribute batteryLevel : BatteryCharge;
    attribute currentMode : RobotMode;
    attribute faultCode : String;
    attribute poseX : Distance;
    attribute poseY : Distance;
    attribute heading : Angle;
  }

  enum def RobotMode {
    enum poweredOff;
    enum booting;
    enum awaitingLesson;
    enum programming;
    enum executing;
    enum demonstratingConcept;
    enum paused;
    enum charging;
    enum fault;
  }

  item def MotorPower {
    attribute leftVoltage : Voltage;
    attribute rightVoltage : Voltage;
    attribute leftCurrentLimit : Current;
    attribute rightCurrentLimit : Current;
  }

  port def CommandPort {
    in command : StudentCommand;
  }

  port def TelemetryPort {
    out status : RobotStatus;
    out observation : SensorObservation;
  }

  port def FeedbackPort {
    out feedback : LearningFeedback;
  }

  port def PowerPort {
    in supplyVoltage : Voltage;
    out currentDraw : Current;
  }

  port def MotorDrivePort {
    out motorPower : MotorPower;
  }

  port def SensorDataPort {
    out observation : SensorObservation;
  }

  port def WirelessPort {
    in command : StudentCommand;
    out status : RobotStatus;
    out feedback : LearningFeedback;
    attribute dataRate : DataRate = 12.0 [SI::Unit::"Mb/s"];
  }

  part def EducationalRobot {
    attribute nominalMass : Mass = 1.2 [kg];
    attribute maximumSpeed : Speed = 0.45 [SI::Unit::"m/s"];
    attribute safeClassroomSpeed : Speed = 0.25 [SI::Unit::"m/s"];
    attribute minimumOperatingBattery : BatteryCharge = 15.0 [%];
    attribute mode : RobotMode = RobotMode::poweredOff;

    port commandPort : CommandPort;
    port telemetryPort : TelemetryPort;
    port feedbackPort : FeedbackPort;
    port powerIn : PowerPort;

    part controller : LearningController;
    part driveBase : DifferentialDriveBase;
    part sensorSuite : ClassroomSensorSuite;
    part batterySystem : RechargeableBatterySystem;
    part wirelessModule : ClassroomWirelessModule;
    part lessonInterface : StudentLessonInterface;
    part safetyMonitor : SafetyMonitor;

    connect commandPort.command to wirelessModule.wireless.command;
    connect wirelessModule.wireless.status to telemetryPort.status;
    connect controller.feedbackOut.feedback to feedbackPort.feedback;
    connect sensorSuite.sensorOut.observation to controller.sensorIn.observation;
    connect sensorSuite.sensorOut.observation to safetyMonitor.sensorIn.observation;
    connect controller.motorOut.motorPower to driveBase.driveIn.motorPower;
    connect safetyMonitor.safeMotorOut.motorPower to driveBase.driveIn.motorPower;
    connect batterySystem.powerOut.supplyVoltage to controller.powerIn.supplyVoltage;
    connect batterySystem.powerOut.supplyVoltage to driveBase.powerIn.supplyVoltage;
    connect batterySystem.powerOut.supplyVoltage to sensorSuite.powerIn.supplyVoltage;
    connect batterySystem.powerOut.supplyVoltage to wirelessModule.powerIn.supplyVoltage;
    connect controller.statusOut.status to wirelessModule.wireless.status;
    connect controller.feedbackOut.feedback to wirelessModule.wireless.feedback;
  }

  part def LearningController {
    attribute processorClock : Frequency = 120.0 [Hz];
    attribute activeLessonId : String;
    attribute commandQueueDepth : Integer = 16;
    attribute estimatedLearningProgress : Percentage;

    port commandIn : CommandPort;
    port sensorIn : SensorDataPort;
    port motorOut : MotorDrivePort;
    port statusOut : TelemetryPort;
    port feedbackOut : FeedbackPort;
    port powerIn : PowerPort;

    action parseStudentProgram {
      in rawCommand : StudentCommand;
      out accepted : Boolean;
      out feedback : LearningFeedback;
    }

    action planMotion {
      in command : StudentCommand;
      in observation : SensorObservation;
      out motorPower : MotorPower;
    }

    action assessLearningOutcome {
      in command : StudentCommand;
      in observation : SensorObservation;
      out feedback : LearningFeedback;
    }

    state def ControllerLifecycle {
      entry action initializeController;

      state off;
      state boot;
      state waitForLesson;
      state receiveProgram;
      state executeProgram;
      state provideFeedback;
      state paused;
      state faultHandling;

      transition first off then boot;
      transition boot_to_wait first boot then waitForLesson;
      transition lesson_selected first waitForLesson then receiveProgram
        accept commandIn.command
        if commandIn.command.commandType == CommandKind::runProgram;
      transition command_drive first receiveProgram then executeProgram
        accept commandIn.command
        if commandIn.command.commandType == CommandKind::drive or commandIn.command.commandType == CommandKind::turn;
      transition assessment first executeProgram then provideFeedback;
      transition next_iteration first provideFeedback then waitForLesson;
      transition pause_requested first executeProgram then paused
        accept commandIn.command
        if commandIn.command.commandType == CommandKind::stop;
      transition resume first paused then waitForLesson;
      transition fault_detected first waitForLesson then faultHandling;
      transition fault_during_execution first executeProgram then faultHandling;
    }

    perform behavior ControllerLifecycle;
  }

  part def DifferentialDriveBase {
    attribute wheelDiameter : Length = 0.066 [m];
    attribute axleTrack : Length = 0.145 [m];
    attribute maxWheelSpeed : Speed = 0.65 [SI::Unit::"m/s"];

    port driveIn : MotorDrivePort;
    port powerIn : PowerPort;

    part leftMotor : Motor;
    part rightMotor : Motor;
    part leftEncoder : WheelEncoder;
    part rightEncoder : WheelEncoder;

    connect driveIn.motorPower.leftVoltage to leftMotor.appliedVoltage;
    connect driveIn.motorPower.rightVoltage to rightMotor.appliedVoltage;
  }

  part def Motor {
    attribute appliedVoltage : Voltage;
    attribute stallCurrent : Current = 1.2 [A];
    attribute nominalTorque : Torque = 0.08 [SI::Unit::"N*m"];
  }

  part def WheelEncoder {
    attribute countsPerRevolution : Integer = 360;
    attribute measuredAngle : Angle;
    attribute measuredSpeed : Speed;
  }

  part def ClassroomSensorSuite {
    attribute obstacleDetectionRange : Distance = 1.5 [m];
    attribute lineSensorThreshold : Percentage = 55.0 [%];

    port sensorOut : SensorDataPort;
    port powerIn : PowerPort;

    part ultrasonicRangeSensor : RangeSensor;
    part opticalLineSensor : LineSensor;
    part inertialMeasurementUnit : InertialSensor;
    part lightSensor : AmbientLightSensor;
  }

  part def RangeSensor {
    attribute minimumRange : Distance = 0.03 [m];
    attribute maximumRange : Distance = 2.0 [m];
    attribute measuredRange : Distance;
  }

  part def LineSensor {
    attribute reflectance : Percentage;
    attribute lineDetected : Boolean;
  }

  part def InertialSensor {
    attribute accelerationMagnitude : Acceleration;
    attribute yawRate : AngularVelocity;
  }

  part def AmbientLightSensor {
    attribute measuredIlluminance : Illuminance;
  }

  part def RechargeableBatterySystem {
    attribute nominalVoltage : Voltage = 7.4 [V];
    attribute capacity : ElectricCharge = 2.2 [SI::Unit::"A*h"];
    attribute chargeLevel : BatteryCharge = 100.0 [%];

    port powerOut : PowerPort;
    port chargePort : PowerPort;

    state def BatteryLifecycle {
      state supplying;
      state lowBattery;
      state charging;
      state protectedShutdown;

      transition normal_to_low first supplying then lowBattery
        if chargeLevel <= 15.0 [%];
      transition low_to_shutdown first lowBattery then protectedShutdown
        if chargeLevel <= 5.0 [%];
      transition plug_in first supplying then charging;
      transition charged first charging then supplying
        if chargeLevel >= 95.0 [%];
    }

    perform behavior BatteryLifecycle;
  }

  part def ClassroomWirelessModule {
    attribute protocolName : String = "Classroom BLE";
    attribute nominalRange : Distance = 12.0 [m];

    port wireless : WirelessPort;
    port powerIn : PowerPort;
  }

  part def StudentLessonInterface {
    attribute displaySize : Length = 0.07 [m];
    attribute supportedLessons : Integer = 24;

    port studentCommandOut : CommandPort;
    port feedbackIn : FeedbackPort;
    port statusIn : TelemetryPort;
  }

  part def SafetyMonitor {
    attribute minimumObstacleDistance : Distance = 0.18 [m];
    attribute maximumTiltAngle : Angle = 35.0 [SI::Unit::"deg"];

    port sensorIn : SensorDataPort;
    port safeMotorOut : MotorDrivePort;

    action enforceClassroomSafety {
      in observation : SensorObservation;
      out motorPower : MotorPower;
      out safetyFeedback : LearningFeedback;
    }

    state def SafetyLifecycle {
      state monitoring;
      state obstacleStop;
      state tiltStop;
      state instructorResetRequired;

      transition obstacle_detected first monitoring then obstacleStop
        if sensorIn.observation.rangeToObstacle < minimumObstacleDistance;
      transition excessive_tilt first monitoring then tiltStop;
      transition cleared first obstacleStop then monitoring
        if sensorIn.observation.rangeToObstacle >= minimumObstacleDistance;
      transition reset_after_tilt first tiltStop then instructorResetRequired;
      transition instructor_reset first instructorResetRequired then monitoring;
    }

    perform behavior SafetyLifecycle;
  }

  requirement def PrimaryEducationalRoboticsFunction {
    doc "The educational robot shall provide a programmable classroom platform that helps students learn sequencing, sensing, feedback, and motion control by executing student-authored commands and returning immediate observable feedback.";

    subject robot : EducationalRobot;

    require constraint {
      robot.maximumSpeed <= 0.45 [SI::Unit::"m/s"]
    }
  }

  requirement def ClassroomSafetyRequirement {
    doc "The robot shall stop motor motion before contacting classroom obstacles detected within the minimum safe distance.";

    subject robot : EducationalRobot;

    require constraint {
      robot.safetyMonitor.minimumObstacleDistance >= 0.15 [m]
    }
  }

  requirement def LearningFeedbackRequirement {
    doc "The robot shall generate feedback after each completed student program run indicating whether the intended lesson concept was demonstrated.";

    subject controller : LearningController;

    require constraint {
      controller.commandQueueDepth >= 8
    }
  }

  requirement def BatteryEnduranceRequirement {
    doc "The robot shall support a typical classroom session without battery replacement.";

    subject battery : RechargeableBatterySystem;

    require constraint {
      battery.capacity >= 2.0 [SI::Unit::"A*h"]
    }
  }

  requirement def WirelessClassroomRequirement {
    doc "The robot shall communicate command, status, and learning feedback messages with a nearby student device in a classroom.";

    subject wireless : ClassroomWirelessModule;

    require constraint {
      wireless.nominalRange >= 10.0 [m]
    }
  }

  part educationalRoboticsPlatform : EducationalRobot;

  satisfy PrimaryEducationalRoboticsFunction by educationalRoboticsPlatform;
  satisfy ClassroomSafetyRequirement by educationalRoboticsPlatform;
  satisfy LearningFeedbackRequirement by educationalRoboticsPlatform.controller;
  satisfy BatteryEnduranceRequirement by educationalRoboticsPlatform.batterySystem;
  satisfy WirelessClassroomRequirement by educationalRoboticsPlatform.wirelessModule;
}