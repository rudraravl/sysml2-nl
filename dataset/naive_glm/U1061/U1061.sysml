package TALON_System {

    // ---------- Value Types with Units ----------
    
    value def Length :> Real { unit 'mm'; }
    value def Distance :> Real { unit 'm'; }
    value def Speed :> Real { unit 'm/s'; }
    value def AngularVelocity :> Real { unit 'rad/s'; }
    value def Angle :> Real { unit 'deg'; }
    value def Mass :> Real { unit 'kg'; }
    value def Force :> Real { unit 'N'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def Energy :> Real { unit 'Wh'; }
    value def Temperature :> Real { unit 'degC'; }
    value def Frequency :> Real { unit 'MHz'; }
    value def Duration :> Real { unit 's'; }
    value def Percent :> Real { unit '%'; }
    value def BatteryStateOfCharge :> Real { unit '%'; }
    
    // ---------- Item Definitions ----------
    
    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    item def DriveCommand {
        attribute leftMotorSpeed : AngularVelocity;
        attribute rightMotorSpeed : AngularVelocity;
    }
    
    item def ManipulatorCommand {
        attribute joint1Target : Angle;
        attribute joint2Target : Angle;
        attribute joint3Target : Angle;
        attribute joint4Target : Angle;
        attribute gripperCommand : GripperActionKind;
    }
    
    enum def GripperActionKind { open; close; hold; }
    
    item def SensorReading {
        attribute obstacleDetected : Boolean;
        attribute distance : Distance;
    }
    
    item def ProximityAlert {
        attribute front : Boolean;
        attribute rear : Boolean;
    }
    
    item def VideoFrame {
        attribute sourceCameraId : String;
        attribute frameRate : Frequency;
        attribute resolution : String;
    }
    
    item def TelemetryData {
        attribute robotPosition : Distance;
        attribute leftTrackSpeed : Speed;
        attribute rightTrackSpeed : Speed;
        attribute armJoint1 : Angle;
        attribute armJoint2 : Angle;
        attribute armJoint3 : Angle;
        attribute armJoint4 : Angle;
        attribute gripperState : GripperActionKind;
        attribute batteryStateOfCharge : BatteryStateOfCharge;
    }
    
    item def OperatorCommand {
        attribute driveCommand : DriveCommand;
        attribute manipulatorCommand : ManipulatorCommand;
        attribute modeCommand : ModeCommandKind;
        attribute emergencyStopRequested : Boolean;
    }
    
    enum def ModeCommandKind { standby; activate; drive; manipulate; surveil; }
    
    item def RobotStatusReport {
        attribute currentMode : String;
        attribute telemetry : TelemetryData;
        attribute alerts : ProximityAlert;
        attribute safetyStatus : Boolean;
    }
    
    // ---------- Part Definitions ----------
    
    part def TALON_System {
        part talonRobot : TALON_Robot;
        part operatorConsole : Operator_Console;
        
        connection robotToConsole_Command : talonRobot.controlPort.outCommands <> operatorConsole.robotPort.inCommands;
        connection consoleToRobot_Command : operatorConsole.robotPort.outCommands <> talonRobot.controlPort.inCommands;
    }
    
    part def TALON_Robot {
        attribute weight : Mass = 45 [kg];
        attribute length : Length = 860 [mm];
        attribute width : Length = 530 [mm];
        attribute height : Length = 350 [mm];
        attribute maxSpeed : Speed = 8.2 [m/s];
        attribute operatingTemp : Temperature range = -20 [degC] .. 60 [degC];
        
        port controlPort : ControlPort;
        
        part leftDriveMotor : DriveMotor;
        part rightDriveMotor : DriveMotor;
        part leftTrack : Track;
        part rightTrack : Track;
        part batteryPack : BatteryPack;
        part manipulatorArm : ManipulatorArm;
        part primaryCamera : Camera {
            attribute cameraId : String = "primary";
            attribute purpose : String = "navigation";
            attribute fieldOfView : Angle = 110 [deg];
        }
        part armCamera : Camera {
            attribute cameraId : String = "arm";
            attribute purpose : String = "close-up";
            attribute fieldOfView : Angle = 75 [deg];
        }
        part frontProximitySensor : ProximitySensor;
        part rearProximitySensor : ProximitySensor;
        part mainController : MainController;
        part radioTransceiver : RadioTransceiver;
        
        connection batteryToController : batteryPack.powerOut <> mainController.powerIn;
        connection batteryToLeftMotor : batteryPack.powerOut <> leftDriveMotor.powerIn;
        connection batteryToRightMotor : batteryPack.powerOut <> rightDriveMotor.powerIn;
        connection batteryToArm : batteryPack.powerOut <> manipulatorArm.powerIn;
        connection batteryToRadio : batteryPack.powerOut <> radioTransceiver.powerIn;
        connection leftMotorToTrack : leftDriveMotor.mechanicalOut <> leftTrack.mechanicalIn;
        connection rightMotorToTrack : rightDriveMotor.mechanicalOut <> rightTrack.mechanicalIn;
        connection leftControllerToMotor : mainController.leftMotorControl <> leftDriveMotor.controlIn;
        connection rightControllerToMotor : mainController.rightMotorControl <> rightDriveMotor.controlIn;
        connection controllerToArm : mainController.armCommand <> manipulatorArm.commandIn;
        connection armMotorToJoints : manipulatorArm.mechanicalOut <> manipulatorArm.gripper.mechanicalIn;
        connection armCameraToController : armCamera.videoOut <> mainController.cameraVideoIn;
        connection primaryCameraToController : primaryCamera.videoOut <> mainController.cameraVideoIn;
        connection frontSensorToController : frontProximitySensor.dataOut <> mainController.sensorDataIn;
        connection rearSensorToController : rearProximitySensor.dataOut <> mainController.sensorDataIn;
        connection controllerToRadio : mainController.radioDataOut <> radioTransceiver.dataIn;
        connection radioToController : radioTransceiver.dataOut <> mainController.radioDataIn;
        connection radioToConsolePort : radioTransceiver.wirelessOut <> controlPort;
    }
    
    part def DriveMotor {
        attribute ratedPower : Power = 400 [W];
        attribute maxTorque : Force = 35 [N];
        attribute maxSpeed : AngularVelocity = 30 [rad/s];
        port powerIn : in ElectricalPower;
        port controlIn : in DriveCommand;
        port mechanicalOut : out AngularVelocity;
        attribute currentSpeed : AngularVelocity;
        compute updateSpeed(control : DriveCommand) : AngularVelocity {
            return control.leftMotorSpeed;
        }
    }
    
    part def Track {
        attribute type : String = "caterpillar";
        attribute treadWidth : Length = 50 [mm];
        port mechanicalIn : in AngularVelocity;
        attribute trackSpeed : Speed;
        compute linearSpeed(rotational : AngularVelocity) : Speed {
            return rotational * 0.1 [m];
        }
    }
    
    part def BatteryPack {
        attribute capacity : Energy = 300 [Wh];
        attribute nominalVoltage : Voltage = 24 [V];
        attribute stateOfCharge : BatteryStateOfCharge = 100 [%];
        port powerOut : out ElectricalPower;
        compute deliverPower() : ElectricalPower {
            return ElectricalPower{ voltage = nominalVoltage; current = 10 [A]; };
        }
    }
    
    part def ManipulatorArm {
        attribute maxReach : Distance = 1.2 [m];
        attribute maxLift : Mass = 5 [kg];
        attribute jointCount : Integer = 4;
        port powerIn : in ElectricalPower;
        port commandIn : in ManipulatorCommand;
        part joints[4] : Joint;
        part gripper : Gripper;
        port mechanicalOut : out Force;
        compute executeCommand(cmd : ManipulatorCommand) : Boolean {
            return true;
        }
    }
    
    part def Joint {
        attribute maxAngle : Angle = 180 [deg];
        attribute currentAngle : Angle;
        port mechanicalIn : in Force;
    }
    
    part def Gripper {
        attribute maxGripForce : Force = 50 [N];
        attribute state : GripperActionKind = hold;
        port mechanicalIn : in Force;
        compute grip(action : GripperActionKind) : GripperActionKind {
            return action;
        }
    }
    
    part def Camera {
        attribute cameraId : String;
        attribute purpose : String;
        attribute frameRate : Frequency = 30 [MHz];
        attribute fieldOfView : Angle;
        port powerIn : in ElectricalPower;
        port videoOut : out VideoFrame;
        compute captureFrame() : VideoFrame {
            return VideoFrame{ sourceCameraId = cameraId; frameRate = frameRate; resolution = "1080p"; };
        }
    }
    
    part def ProximitySensor {
        attribute range : Distance = 2.0 [m];
        attribute fieldOfView : Angle = 60 [deg];
        port powerIn : in ElectricalPower;
        port dataOut : out SensorReading;
        compute detect() : SensorReading {
            return SensorReading{ obstacleDetected = false; distance = range; };
        }
    }
    
    part def MainController {
        attribute processingFrequency : Frequency = 100 [MHz];
        attribute firmwareVersion : String = "4.2.1";
        port powerIn : in ElectricalPower;
        port leftMotorControl : out DriveCommand;
        port rightMotorControl : out DriveCommand;
        port armCommand : out ManipulatorCommand;
        port cameraVideoIn : in VideoFrame;
        port sensorDataIn : in SensorReading;
        port radioDataIn : in OperatorCommand;
        port radioDataOut : out RobotStatusReport;
        attribute currentDriveCommand : DriveCommand;
        attribute currentManipulatorCommand : ManipulatorCommand;
        compute processCommand(cmd : OperatorCommand) : RobotStatusReport {
            return RobotStatusReport{ currentMode = "operational"; telemetry = TelemetryData{ robotPosition = 0 [m]; leftTrackSpeed = 0 [m/s]; rightTrackSpeed = 0 [m/s]; armJoint1 = 0 [deg]; armJoint2 = 0 [deg]; armJoint3 = 0 [deg]; armJoint4 = 0 [deg]; gripperState = GripperActionKind::hold; batteryStateOfCharge = 100 [%]; }; alerts = ProximityAlert{ front = false; rear = false; }; safetyStatus = true; };
        }
        state def TALON_StateMachine;
        part controllerStateMachine : TALON_StateMachine;
    }
    
    part def RadioTransceiver {
        attribute operatingFrequency : Frequency = 900 [MHz];
        attribute range : Distance = 1000 [m];
        attribute dataRate : Frequency = 2 [MHz];
        port powerIn : in ElectricalPower;
        port dataIn : in RobotStatusReport;
        port dataOut : out OperatorCommand;
        port wirelessOut : out RobotStatusReport;
        compute transmit(report : RobotStatusReport) : RobotStatusReport {
            return report;
        }
        compute receive() : OperatorCommand {
            return OperatorCommand{ driveCommand = DriveCommand{ leftMotorSpeed = 0 [rad/s]; rightMotorSpeed = 0 [rad/s]; }; manipulatorCommand = ManipulatorCommand{ joint1Target = 0 [deg]; joint2Target = 0 [deg]; joint3Target = 0 [deg]; joint4Target = 0 [deg]; gripperCommand = GripperActionKind::hold; }; modeCommand = ModeCommandKind::standby; emergencyStopRequested = false; };
        }
    }
    
    part def Operator_Console {
        attribute weight : Mass = 5 [kg];
        attribute batteryBackup : Energy = 50 [Wh];
        port robotPort : OperatorConsolePort;
        part videoDisplay : VideoDisplay;
        part joystick : Joystick;
        part commandInterface : CommandInterface;
        part consoleRadio : RadioTransceiver;
        connection videoToDisplay : robotPort.inCommands2 <> videoDisplay.videoIn;
        connection joystickToInterface : joystick.position <> commandInterface.joystickInput;
        connection interfaceToRadio : commandInterface.outCommands <> consoleRadio.dataIn2;
        connection radioToConsole : consoleRadio.dataOut <> robotPort.outCommands;
    }
    
    part def VideoDisplay {
        attribute screenSize : Length = 280 [mm];
        attribute resolution : String = "1920x1080";
        port videoIn : in VideoFrame;
        compute render(frame : VideoFrame) : Boolean {
            return true;
        }
    }
    
    part def Joystick {
        attribute deadZone : Percent = 5 [%];
        attribute maxDeflection : Angle = 45 [deg];
        attribute position : DriveCommand;
        compute readPosition() : DriveCommand {
            return DriveCommand{ leftMotorSpeed = 0 [rad/s]; rightMotorSpeed = 0 [rad/s]; };
        }
    }
    
    part def CommandInterface {
        attribute modesSupported : Integer = 4;
        attribute language : String = "English";
        port joystickInput : in DriveCommand;
        port outCommands : out OperatorCommand;
        compute composeCommand(drive : DriveCommand) : OperatorCommand {
            return OperatorCommand{ driveCommand = drive; manipulatorCommand = ManipulatorCommand{ joint1Target = 0 [deg]; joint2Target = 0 [deg]; joint3Target = 0 [deg]; joint4Target = 0 [deg]; gripperCommand = GripperActionKind::hold; }; modeCommand = ModeCommandKind::drive; emergencyStopRequested = false; };
        }
    }
    
    // ---------- Port Definitions ----------
    
    port def ControlPort {
        in inCommands : OperatorCommand;
        out outCommands : RobotStatusReport;
    }
    
    port def OperatorConsolePort {
        in inCommands2 : RobotStatusReport;
        out outCommands : OperatorCommand;
    }
    
    // ---------- State Machine Definition ----------
    
    state def TALON_StateMachine {
        state standby;
        state operational;
        state emergencyStop;
        
        state operational {
            state driving;
            state manipulating;
            state surveillance;
            
            transition drivingToManipulating
                source driving
                target manipulating
                trigger modeCommand = ModeCommandKind::manipulate
                guard !emergencyStopRequested;
            
            transition manipulatingToDriving
                source manipulating
                target driving
                trigger modeCommand = ModeCommandKind::drive
                guard !emergencyStopRequested;
            
            transition toSurveillance
                source driving
                target surveillance
                trigger modeCommand = ModeCommandKind::surveil
                guard !emergencyStopRequested;
            
            transition fromSurveillanceToDriving
                source surveillance
                target driving
                trigger modeCommand = ModeCommandKind::drive
                guard !emergencyStopRequested;
            
            transition surveillanceToManipulating
                source surveillance
                target manipulating
                trigger modeCommand = ModeCommandKind::manipulate
                guard !emergencyStopRequested;
        }
        
        transition standbyToOperational
            source standby
            target operational.driving
            trigger modeCommand = ModeCommandKind::activate
            guard !emergencyStopRequested;
        
        transition operationalToStandby
            source operational
            target standby
            trigger modeCommand = ModeCommandKind::standby
            guard !emergencyStopRequested;
        
        transition toEmergencyStop
            source standby
            target emergencyStop
            trigger emergencyStopRequested = true;
        
        transition operationalToEmergency
            source operational
            target emergencyStop
            trigger emergencyStopRequested = true;
        
        transition emergencyToStandby
            source emergencyStop
            target standby
            trigger modeCommand = ModeCommandKind::standby
            guard !emergencyStopRequested;
        
        entry standby {
            effect { /* initialize systems, arm standby mode */ }
        }
        
        entry operational {
            effect { /* activate all subsystems */ }
        }
        
        entry driving {
            effect { /* enable drive motors, process drive commands */ }
        }
        
        entry manipulating {
            effect { /* activate manipulator arm, enable arm camera */ }
        }
        
        entry surveillance {
            effect { /* halt motors, maintain camera feed */ }
        }
        
        entry emergencyStop {
            effect { /* halt all motors, freeze arm, close gripper safely */ }
        }
    }
    
    // ---------- Requirements ----------
    
    requirement def TALON_Requirements {
        requirement RemoteControlCapability {
            doc « The system shall allow a human operator to control the TALON robot from a safe distance via wireless communication. »
            attribute minRange : Distance = 1000 [m];
        }
        
        requirement TrackedMobility {
            doc « The robot shall use caterpillar-style tracks driven by left and right motors to navigate difficult terrain including stairs and debris. »
            attribute maxSlope : Angle = 45 [deg];
        }
        
        requirement BatteryPowerSupply {
            doc « A central rechargeable battery pack shall provide power to all robot components for the duration of a mission. »
            attribute minRuntime : Duration = 7200 [s];
        }
        
        requirement ManipulatorArmCapability {
            doc « The robot shall be equipped with a multi-jointed manipulator arm capable of grasping, lifting, and precisely manipulating objects. »
            attribute minReach : Distance = 1.0 [m];
            attribute minLiftCapacity : Mass = 5 [kg];
        }
        
        requirement DualCameraVision {
            doc « The robot shall have a primary navigation camera and a manipulator-mounted close-up camera, with live feeds displayed to the operator. »
        }
        
        requirement ProximitySensing {
            doc « Front and rear proximity sensors shall detect obstacles to help avoid collisions. »
            attribute detectionRange : Distance = 2.0 [m];
        }
        
        requirement OnboardControllerProcessing {
            doc « The onboard main controller shall process operator commands, interpret sensor data, and control motors and the manipulator arm. »
        }
        
        requirement WirelessCommunication {
            doc « A radio transceiver shall establish a wireless link between the robot and operator console for bidirectional data transfer. »
            attribute operatingFrequency : Frequency = 900 [MHz];
        }
        
        requirement OperatorConsoleInterface {
            doc « The operator console shall include a video display, joystick, and command interface for control and situational awareness. »
        }
        
        requirement TelemetryStreaming {
            doc « The robot shall stream video and telemetry data back to the operator in real time. »
            attribute maxLatency : Duration = 0.5 [s];
        }
        
        requirement OperatingModes {
            doc « The system shall support standby, operational (driving, manipulating, surveillance), and emergency stop modes. »
        }
        
        requirement EmergencyStop {
            doc « An emergency stop shall be triggerable at any time to immediately halt all movement and freeze the manipulator. »
            attribute maxResponseTime : Duration = 0.1 [s];
        }
        
        requirement HazardousEnvironmentOperation {
            doc « The TALON shall be designed for EOD, reconnaissance, and hazardous material handling missions. »
            attribute operatingTempRange : Temperature range = -20 [degC] .. 60 [degC];
        }
    }
    
    // ---------- Satisfying relationships ----------
    
    satisfy TALON_System by TALON_Requirements::RemoteControlCapability;
    satisfy talonRobot by TALON_Requirements::TrackedMobility;
    satisfy talonRobot.batteryPack by TALON_Requirements::BatteryPowerSupply;
    satisfy talonRobot.manipulatorArm by TALON_Requirements::ManipulatorArmCapability;
    satisfy talonRobot.primaryCamera by TALON_Requirements::DualCameraVision;
    satisfy talonRobot.armCamera by TALON_Requirements::DualCameraVision;
    satisfy talonRobot.frontProximitySensor by TALON_Requirements::ProximitySensing;
    satisfy talonRobot.rearProximitySensor by TALON_Requirements::ProximitySensing;
    satisfy talonRobot.mainController by TALON_Requirements::OnboardControllerProcessing;
    satisfy talonRobot.radioTransceiver by TALON_Requirements::WirelessCommunication;
    satisfy operatorConsole by TALON_Requirements::OperatorConsoleInterface;
    satisfy talonRobot.radioTransceiver by TALON_Requirements::TelemetryStreaming;
    satisfy talonRobot.mainController.controllerStateMachine by TALON_Requirements::OperatingModes;
    satisfy talonRobot.mainController.controllerStateMachine by TALON_Requirements::EmergencyStop;
    satisfy talonRobot by TALON_Requirements::HazardousEnvironmentOperation;
}
