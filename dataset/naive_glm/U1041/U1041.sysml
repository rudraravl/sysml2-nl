package EducationalRobot {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ============ Value Types ============

    value type Voltage :> Real {
        unit : Volt;
        min : 0;
        max : 12;
    }

    value type Current :> Real {
        unit : Ampere;
        min : 0;
    }

    value type Distance :> Real {
        unit : Meter;
        min : 0;
    }

    value type LinearSpeed :> Real {
        unit : MeterPerSecond;
        min : 0;
    }

    value type RotationalSpeed :> Real {
        unit : Hertz;
        min : 0;
    }

    value type AngularVelocity :> Real {
        min : 0;
    }

    value type BatteryLevel :> Real {
        min : 0;
        max : 100;
    }

    value type FrequencyValue :> Real {
        unit : Hertz;
        min : 0;
    }

    value type TimeStamp :> Real {
        unit : Second;
        min : 0;
    }

    value type Duration :> Real {
        unit : Second;
        min : 0;
    }

    // ============ Enumerations ============

    enum def RobotOperatingMode {
        standby;
        programming;
        mission;
        charging;
    }

    enum def MotorDirection {
        forward;
        backward;
        stopped;
    }

    enum def SensorPosition {
        front;
        left;
        right;
    }

    enum def LinePosition {
        onLine;
        leftOfLine;
        rightOfLine;
        offLine;
    }

    // ============ Item Definitions ============

    item def UltrasonicReading {
        attribute measuredDistance : Distance;
        attribute isValid : Boolean;
        attribute timestamp : TimeStamp;
    }

    item def LineReading {
        attribute linePosition : LinePosition;
        attribute leftSensorValue : Real;
        attribute rightSensorValue : Real;
        attribute timestamp : TimeStamp;
    }

    item def MotorCommand {
        attribute direction : MotorDirection;
        attribute speed : RotationalSpeed;
    }

    item def DifferentialDriveCommand {
        attribute leftMotorCommand : MotorCommand;
        attribute rightMotorCommand : MotorCommand;
    }

    item def StudentProgram {
        attribute programName : String;
        attribute programCode : String;
        attribute lineCount : Integer;
        attribute verified : Boolean;
    }

    item def DisplayUpdate {
        attribute line1 : String;
        attribute line2 : String;
        attribute currentMode : RobotOperatingMode;
        attribute batteryPercentage : BatteryLevel;
        attribute timestamp : TimeStamp;
    }

    item def PowerState {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute level : BatteryLevel;
    }

    item def SoundWave {
        attribute frequency : FrequencyValue;
        attribute amplitude : Real;
    }

    item def LightIntensity {
        attribute intensity : Real;
        attribute wavelength : Real;
    }

    // ============ Port Definitions ============

    port def PowerOutputPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def PowerInputPort {
        in voltage : Voltage;
        in current : Current;
    }

    port def ChargingInputPort {
        in power : PowerState;
    }

    port def UltrasonicDataOutPort {
        out reading : UltrasonicReading;
    }

    port def UltrasonicDataInPort {
        in reading : UltrasonicReading;
    }

    port def LineDataOutPort {
        out reading : LineReading;
    }

    port def LineDataInPort {
        in reading : LineReading;
    }

    port def MotorCommandOutPort {
        out command : MotorCommand;
    }

    port def MotorCommandInPort {
        in command : MotorCommand;
    }

    port def DisplayOutPort {
        out update : DisplayUpdate;
    }

    port def DisplayInPort {
        in update : DisplayUpdate;
    }

    port def ProgramInPort {
        in program : StudentProgram;
    }

    port def SoundWavePort {
        in echo : SoundWave;
    }

    port def LightSensingPort {
        in reflectedLight : LightIntensity;
    }

    // ============ Action Definitions ============

    action def MeasureDistance {
        in maxRange : Distance;
        out reading : UltrasonicReading;

        action emitPulse;
        action waitForEcho;
        action calculateDistance;

        succession emitPulse to waitForEcho;
        succession waitForEcho to calculateDistance;
    }

    action def DetectLine {
        out reading : LineReading;

        action sampleLeft;
        action sampleRight;
        action determinePosition;

        succession sampleLeft to sampleRight;
        succession sampleRight to determinePosition;
    }

    action def RotateMotor {
        in command : MotorCommand;

        action setDirection;
        action setSpeed;

        succession setDirection to setSpeed;
    }

    action def RollWheel {
        in rotationalSpeed : RotationalSpeed;
        in diameter : Distance;
        out linearSpeed : LinearSpeed;
    }

    action def DriveWheelAssembly {
        in command : MotorCommand;
        in wheelDiameter : Distance;

        action rotateMotor : RotateMotor;
        action rollWheel : RollWheel;

        succession rotateMotor to rollWheel;
    }

    action def DriveForward {
        in speed : RotationalSpeed;
        out leftCommand : MotorCommand;
        out rightCommand : MotorCommand;
    }

    action def DriveBackward {
        in speed : RotationalSpeed;
        out leftCommand : MotorCommand;
        out rightCommand : MotorCommand;
    }

    action def TurnLeft {
        in speed : RotationalSpeed;
        out leftCommand : MotorCommand;
        out rightCommand : MotorCommand;
    }

    action def TurnRight {
        in speed : RotationalSpeed;
        out leftCommand : MotorCommand;
        out rightCommand : MotorCommand;
    }

    action def StopMotors {
        out leftCommand : MotorCommand;
        out rightCommand : MotorCommand;
    }

    action def SupplyPower {
        out power : PowerState;
    }

    action def ChargeBattery {
        in power : PowerState;

        action monitorCharging;
        action updateLevel;

        succession monitorCharging to updateLevel;
    }

    action def ShowDisplay {
        in update : DisplayUpdate;

        action clearScreen;
        action writeLine1;
        action writeLine2;

        succession clearScreen to writeLine1;
        succession writeLine1 to writeLine2;
    }

    action def ReadAllSensors {
        out frontReading : UltrasonicReading;
        out leftReading : UltrasonicReading;
        out rightReading : UltrasonicReading;
        out lineReading : LineReading;

        action readFront;
        action readLeft;
        action readRight;
        action readLine;

        succession readFront to readLeft;
        succession readLeft to readRight;
        succession readRight to readLine;
    }

    action def ProcessSensorData {
        in program : StudentProgram;
        in frontReading : UltrasonicReading;
        in leftReading : UltrasonicReading;
        in rightReading : UltrasonicReading;
        in lineReading : LineReading;
        out driveCommand : DifferentialDriveCommand;

        action interpretProgram;
        action computeMovement;

        succession interpretProgram to computeMovement;
    }

    action def SendMotorCommands {
        in command : DifferentialDriveCommand;

        action sendLeft;
        action sendRight;

        succession sendLeft to sendRight;
    }

    action def LoadProgram {
        in program : StudentProgram;
        out loaded : Boolean;

        action receiveProgram;
        action validateProgram;
        action storeProgram;

        succession receiveProgram to validateProgram;
        succession validateProgram to storeProgram;
    }

    action def UpdateDisplay {
        in mode : RobotOperatingMode;
        in level : BatteryLevel;
        out update : DisplayUpdate;
    }

    action def SenseProcessActuate {
        action sense : ReadAllSensors;
        action process : ProcessSensorData;
        action actuate : SendMotorCommands;

        succession sense to process;
        succession process to actuate;
        succession actuate to sense;
    }

    // ============ State Machine Definition ============

    state def RobotOperatingStateMachine {
        attribute programRequested : Boolean = false;
        attribute programLoaded : Boolean = false;
        attribute missionStartRequested : Boolean = false;
        attribute missionComplete : Boolean = false;
        attribute missionAborted : Boolean = false;
        attribute chargerConnected : Boolean = false;
        attribute chargerDisconnected : Boolean = false;
        attribute chargingComplete : Boolean = false;
        attribute batteryLevel : BatteryLevel = 100;
        attribute lowBatteryThreshold : BatteryLevel = 20;
        attribute criticalBatteryThreshold : BatteryLevel = 10;

        succession first to standby;

        state standby {
            entry action enterStandby;
            do action idleMonitor;
            exit action leaveStandby;
        }

        state programming {
            entry action enterProgramming;
            do action acceptProgram;
            exit action exitProgramming;
        }

        state mission {
            entry action startMission;
            exit action stopMission;

            state sensing {
                entry action readSensors;
            }

            state processing {
                entry action processData;
            }

            state actuating {
                entry action commandMotors;
            }

            succession sensing to processing;
            succession processing to actuating;
            succession actuating to sensing;
        }

        state charging {
            entry action enterCharging;
            do action monitorCharge;
            exit action exitCharging;
        }

        transition from standby to programming
            when programRequested;

        transition from programming to standby
            when !programRequested;

        transition from standby to mission
            when missionStartRequested;

        transition from mission to standby
            when missionComplete;

        transition from mission to standby
            when missionAborted;

        transition from mission to charging
            when batteryLevel <= criticalBatteryThreshold;

        transition from standby to charging
            when chargerConnected;

        transition from charging to standby
            when chargerDisconnected;

        transition from charging to standby
            when chargingComplete;
    }

    // ============ Part Definitions ============

    part def UltrasonicSensor {
        attribute position : SensorPosition;
        attribute maxRange : Distance = 2;
        attribute minRange : Distance = 0.02;
        attribute beamAngleDeg : Real = 15;

        port powerIn : PowerInputPort;
        port dataOut : UltrasonicDataOutPort;
        port environment : SoundWavePort;

        action measure : MeasureDistance;
    }

    part def LineFollowingSensor {
        attribute sensorCount : Integer = 2;
        attribute sampleRate : FrequencyValue = 100;
        attribute mountingLocation : String = "underneath";

        port powerIn : PowerInputPort;
        port dataOut : LineDataOutPort;
        port environment : LightSensingPort;

        action detect : DetectLine;
    }

    part def DCMotor {
        attribute nominalVoltage : Voltage = 6;
        attribute stallCurrent : Current = 1.5;
        attribute maxRotationalSpeed : RotationalSpeed = 200;
        attribute currentDirection : MotorDirection = stopped;
        attribute currentSpeed : RotationalSpeed = 0;

        port powerIn : PowerInputPort;
        port commandIn : MotorCommandInPort;

        action rotate : RotateMotor;
    }

    part def Wheel {
        attribute diameter : Distance = 0.065;
        attribute width : Distance = 0.025;
        attribute material : String = "rubber";
        attribute currentLinearSpeed : LinearSpeed = 0;

        action roll : RollWheel;
    }

    part def WheelAssembly {
        part motor : DCMotor;
        part wheel : Wheel;

        port powerIn : PowerInputPort;
        port commandIn : MotorCommandInPort;

        connection powerIn to motor.powerIn;
        connection commandIn to motor.commandIn;

        action drive : DriveWheelAssembly;
    }

    part def DifferentialDrive {
        part leftAssembly : WheelAssembly;
        part rightAssembly : WheelAssembly;

        attribute trackWidth : Distance = 0.15;
        attribute maxSpeed : LinearSpeed = 0.5;

        port powerIn : PowerInputPort;
        port leftCommand : MotorCommandInPort;
        port rightCommand : MotorCommandInPort;

        connection powerIn to leftAssembly.powerIn;
        connection powerIn to rightAssembly.powerIn;
        connection leftCommand to leftAssembly.commandIn;
        connection rightCommand to rightAssembly.commandIn;

        action driveForward : DriveForward;
        action driveBackward : DriveBackward;
        action turnLeft : TurnLeft;
        action turnRight : TurnRight;
        action stop : StopMotors;
    }

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 7.4;
        attribute capacityAh : Real = 2.0;
        attribute level : BatteryLevel = 100;
        attribute isCharging : Boolean = false;
        attribute chargeCycles : Integer = 0;

        port powerOut : PowerOutputPort;
        port chargingIn : ChargingInputPort;

        action supplyPower : SupplyPower;
        action charge : ChargeBattery;
    }

    part def DisplayModule {
        attribute displayType : String = "LCD";
        attribute numLines : Integer = 2;
        attribute charactersPerLine : Integer = 16;
        attribute backlightOn : Boolean = true;

        port powerIn : PowerInputPort;
        port displayIn : DisplayInPort;

        action show : ShowDisplay;
    }

    part def Microcontroller {
        attribute clockSpeedHz : FrequencyValue = 16000000;
        attribute programMemoryBytes : Integer = 32768;
        attribute ramBytes : Integer = 2048;
        attribute currentMode : RobotOperatingMode = standby;
        attribute loadedProgram : StudentProgram;
        attribute batteryLevel : BatteryLevel = 100;

        port powerIn : PowerInputPort;
        port frontSensorIn : UltrasonicDataInPort;
        port leftSensorIn : UltrasonicDataInPort;
        port rightSensorIn : UltrasonicDataInPort;
        port lineSensorIn : LineDataInPort;
        port leftMotorOut : MotorCommandOutPort;
        port rightMotorOut : MotorCommandOutPort;
        port displayOut : DisplayOutPort;
        port programIn : ProgramInPort;

        exhibit operatingState : RobotOperatingStateMachine;

        action readSensors : ReadAllSensors;
        action processData : ProcessSensorData;
        action commandMotors : SendMotorCommands;
        action loadProgram : LoadProgram;
        action updateDisplay : UpdateDisplay;
    }

    // ============ Top-Level Robot ============

    part def EducationalRobot {
        attribute name : String = "EduBot";
        attribute version : String = "1.0";
        attribute maxSpeed : LinearSpeed = 0.5;
        attribute bodyMaterial : String = "ABS plastic";
        attribute wheelbase : Distance = 0.15;
        attribute weightKg : Real = 0.5;

        port programInput : ProgramInPort;
        port chargingInput : ChargingInputPort;

        part controller : Microcontroller;
        part drive : DifferentialDrive;
        part frontUltrasonic : UltrasonicSensor {
            :>> position = SensorPosition::front;
        }
        part leftUltrasonic : UltrasonicSensor {
            :>> position = SensorPosition::left;
        }
        part rightUltrasonic : UltrasonicSensor {
            :>> position = SensorPosition::right;
        }
        part lineSensor : LineFollowingSensor;
        part battery : BatteryPack;
        part display : DisplayModule;

        connection frontUltrasonic.dataOut to controller.frontSensorIn;
        connection leftUltrasonic.dataOut to controller.leftSensorIn;
        connection rightUltrasonic.dataOut to controller.rightSensorIn;
        connection lineSensor.dataOut to controller.lineSensorIn;

        connection controller.leftMotorOut to drive.leftCommand;
        connection controller.rightMotorOut to drive.rightCommand;

        connection controller.displayOut to display.displayIn;

        binding programInput to controller.programIn;
        binding chargingInput to battery.chargingIn;

        connection battery.powerOut to controller.powerIn;
        connection battery.powerOut to frontUltrasonic.powerIn;
        connection battery.powerOut to leftUltrasonic.powerIn;
        connection battery.powerOut to rightUltrasonic.powerIn;
        connection battery.powerOut to lineSensor.powerIn;
        connection battery.powerOut to drive.powerIn;
        connection battery.powerOut to display.powerIn;
    }

    // ============ Requirements ============

    requirement def EducationalRobotRequirement {
        doc "Base requirement for the educational robot system.";
    }

    requirement selfContained :> EducationalRobotRequirement {
        doc "The robot shall be a self-contained, battery-powered unit.";
    }

    requirement classroomSuitable :> EducationalRobotRequirement {
        doc "The robot shall be designed for use in classroom environments.";
        attribute maxNoiseLevelDb : Real = 50;
        attribute safeForAges : Integer = 8;
    }

    requirement stemPlatform :> EducationalRobotRequirement {
        doc "The robot shall serve as a hands-on platform for teaching STEM concepts including programming, robotics, and problem-solving.";
    }

    requirement centralProcessing :> EducationalRobotRequirement {
        doc "The robot shall have a central microcontroller that executes programs created by students.";
    }

    requirement differentialDriveSystem :> EducationalRobotRequirement {
        doc "The robot shall use a two-wheeled differential drive system with each wheel assembly powered by its own DC motor.";
        attribute wheelCount : Integer = 2;
        attribute motorCount : Integer = 2;
    }

    requirement maneuverability :> EducationalRobotRequirement {
        doc "The robot shall be able to drive forward, backward, and turn in both directions.";
    }

    requirement ultrasonicSensing :> EducationalRobotRequirement {
        doc "The robot shall have three ultrasonic sensors: one facing forward and one on each side, to detect and measure distances to obstacles.";
        attribute sensorCount : Integer = 3;
        attribute frontSensorPresent : Boolean = true;
        attribute leftSensorPresent : Boolean = true;
        attribute rightSensorPresent : Boolean = true;
    }

    requirement obstacleAvoidance :> EducationalRobotRequirement {
        doc "The robot shall use ultrasonic sensor data to navigate a maze and avoid collisions.";
        attribute minDetectionRange : Distance = 0.02;
        attribute maxDetectionRange : Distance = 2;
    }

    requirement lineFollowingCapability :> EducationalRobotRequirement {
        doc "The robot shall have a dedicated line-following sensor underneath that detects and tracks a line on the floor.";
    }

    requirement powerSystem :> EducationalRobotRequirement {
        doc "The robot shall have a rechargeable battery pack that powers all electronic components including the microcontroller, sensors, motors, and display module.";
        attribute minBatteryLifeHours : Duration = 7200;
        attribute maxChargeTimeHours : Duration = 14400;
    }

    requirement displayInterface :> EducationalRobotRequirement {
        doc "The robot shall have a display module that provides status updates and serves as an interface for loading student-written programs.";
    }

    requirement operatingModes :> EducationalRobotRequirement {
        doc "The robot shall operate in four distinct modes: standby, programming, mission execution, and charging.";
        attribute modeCount : Integer = 4;
    }

    requirement missionExecutionCycle :> EducationalRobotRequirement {
        doc "During mission execution, the robot shall continuously cycle through sensing its environment, processing that data based on its program, and actuating its motors to move accordingly.";
    }

    requirement safetyReliability :> EducationalRobotRequirement {
        doc "The robot shall be engaging, safe, and reliable for students of various skill levels.";
        attribute maxSafeSpeed : LinearSpeed = 0.5;
        attribute lowBatteryCutoff : BatteryLevel = 10;
    }

    requirement interactiveLearning :> EducationalRobotRequirement {
        doc "The robot shall allow students to see their code come to life in a physical, interactive way.";
    }

    // ============ Requirement Satisfaction ============

    satisfy selfContained by EducationalRobot;
    satisfy classroomSuitable by EducationalRobot;
    satisfy stemPlatform by EducationalRobot;
    satisfy centralProcessing by EducationalRobot::controller;
    satisfy differentialDriveSystem by EducationalRobot::drive;
    satisfy maneuverability by EducationalRobot::drive;
    satisfy ultrasonicSensing by EducationalRobot::frontUltrasonic;
    satisfy ultrasonicSensing by EducationalRobot::leftUltrasonic;
    satisfy ultrasonicSensing by EducationalRobot::rightUltrasonic;
    satisfy obstacleAvoidance by EducationalRobot::controller;
    satisfy lineFollowingCapability by EducationalRobot::lineSensor;
    satisfy powerSystem by EducationalRobot::battery;
    satisfy displayInterface by EducationalRobot::display;
    satisfy operatingModes by EducationalRobot::controller;
    satisfy missionExecutionCycle by EducationalRobot::controller;
    satisfy safetyReliability by EducationalRobot;
    satisfy interactiveLearning by EducationalRobot;
}
