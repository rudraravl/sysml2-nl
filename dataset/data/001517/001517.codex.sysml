package OpenSourceRobotics_TurtleBot3_WafflePi_Model {

    doc /* 
     * High-level function: the open-source TurtleBot3 Waffle Pi mobile robot autonomously
     * perceives an indoor environment, localizes itself, plans safe motion, and drives a
     * differential-drive base to navigate toward operator-selected goals while reporting
     * telemetry and accepting supervisory commands.
     */

    import ScalarValues::*;
    import ISQ::*;

    attribute def Percent :> Real {
        doc /* Ratio expressed from 0 to 100 percent. */
    }

    attribute def Volt :> Real;
    attribute def Ampere :> Real;
    attribute def Watt :> Real;
    attribute def Meter :> Real;
    attribute def MeterPerSecond :> Real;
    attribute def Radian :> Real;
    attribute def RadianPerSecond :> Real;
    attribute def Hertz :> Real;
    attribute def Second :> Real;
    attribute def Celsius :> Real;
    attribute def BytePerSecond :> Real;

    item def Pose2D {
        attribute x : Meter;
        attribute y : Meter;
        attribute yaw : Radian;
    }

    item def Twist2D {
        attribute linearVelocity : MeterPerSecond;
        attribute angularVelocity : RadianPerSecond;
    }

    item def LaserScan {
        attribute scanRate : Hertz;
        attribute minRange : Meter;
        attribute maxRange : Meter;
        attribute angularResolution : Radian;
        attribute obstacleDistances : Meter[*];
    }

    item def CameraFrame {
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : Hertz;
        attribute encodedSize : BytePerSecond;
    }

    item def Odometry {
        attribute pose : Pose2D;
        attribute twist : Twist2D;
        attribute covarianceTrace : Real;
    }

    item def BatteryStatus {
        attribute voltage : Volt;
        attribute current : Ampere;
        attribute stateOfCharge : Percent;
        attribute temperature : Celsius;
    }

    item def WheelCommand {
        attribute leftWheelAngularVelocity : RadianPerSecond;
        attribute rightWheelAngularVelocity : RadianPerSecond;
    }

    item def MotorTelemetry {
        attribute leftWheelAngularVelocity : RadianPerSecond;
        attribute rightWheelAngularVelocity : RadianPerSecond;
        attribute leftMotorCurrent : Ampere;
        attribute rightMotorCurrent : Ampere;
    }

    item def NavigationGoal {
        attribute targetPose : Pose2D;
        attribute tolerance : Meter;
        attribute maximumSpeed : MeterPerSecond;
    }

    item def HealthReport {
        attribute battery : BatteryStatus;
        attribute cpuTemperature : Celsius;
        attribute localizationConfidence : Percent;
        attribute emergencyStopActive : Boolean;
    }

    item def SupervisorCommand {
        attribute enableAutonomy : Boolean;
        attribute pauseNavigation : Boolean;
        attribute resetLocalization : Boolean;
        attribute emergencyStop : Boolean;
    }

    port def PowerSourcePort {
        out item power : BatteryStatus;
    }

    port def PowerLoadPort {
        in item power : BatteryStatus;
    }

    port def LaserScanPort {
        out item scan : LaserScan;
    }

    port def CameraFramePort {
        out item frame : CameraFrame;
    }

    port def OdometryPort {
        out item odometry : Odometry;
    }

    port def WheelCommandPort {
        in item command : WheelCommand;
    }

    port def MotorTelemetryPort {
        out item telemetry : MotorTelemetry;
    }

    port def NavigationGoalPort {
        in item goal : NavigationGoal;
    }

    port def SupervisorCommandPort {
        in item command : SupervisorCommand;
    }

    port def TelemetryPort {
        out item health : HealthReport;
        out item odometry : Odometry;
    }

    part def LithiumIonBatteryPack {
        attribute nominalVoltage : Volt = 11.1;
        attribute capacityAmpHours : Real = 1.8;
        attribute maximumContinuousCurrent : Ampere = 5.0;
        attribute shutdownThreshold : Percent = 10.0;
        attribute chargeState : BatteryStatus;

        port powerOut : PowerSourcePort;

        action providePower {
            out item reportedStatus : BatteryStatus;
            first start;
            then sampleBattery;
            then publishStatus;
            then done;

            action sampleBattery;
            action publishStatus;
        }
    }

    part def RaspberryPiComputer {
        attribute processorClock : Hertz = 1.5e9;
        attribute memoryBytes : Integer = 4294967296;
        attribute rosDistribution : String = "ROS 2";
        attribute cpuTemperature : Celsius;
        attribute commandUpdateRate : Hertz = 20.0;

        port powerIn : PowerLoadPort;
        port scanIn {
            in item scan : LaserScan;
        }
        port frameIn {
            in item frame : CameraFrame;
        }
        port odometryIn {
            in item odometry : Odometry;
        }
        port goalIn : NavigationGoalPort;
        port supervisorIn : SupervisorCommandPort;
        port wheelCommandOut {
            out item command : WheelCommand;
        }
        port telemetryOut : TelemetryPort;

        part localizationNode : LocalizationNode;
        part mappingNode : MappingNode;
        part planningNode : PlanningNode;
        part safetyMonitor : SafetyMonitor;

        connect scanIn to mappingNode.scanInput;
        connect frameIn to mappingNode.cameraInput;
        connect odometryIn to localizationNode.odometryInput;
        connect mappingNode.mapOutput to planningNode.mapInput;
        connect localizationNode.poseOutput to planningNode.poseInput;
        connect goalIn to planningNode.goalInput;
        connect supervisorIn to safetyMonitor.commandInput;
        connect safetyMonitor.safeVelocityOutput to planningNode.safetyLimitInput;
        connect planningNode.wheelCommandOutput to wheelCommandOut;

        action computeNavigationCommand {
            in item goal : NavigationGoal;
            in item scan : LaserScan;
            in item odometry : Odometry;
            out item command : WheelCommand;

            first receiveGoal;
            then estimatePose;
            then updateLocalMap;
            then planVelocity;
            then convertToWheelCommand;
            then publishCommand;
            then done;

            action receiveGoal;
            action estimatePose;
            action updateLocalMap;
            action planVelocity;
            action convertToWheelCommand;
            action publishCommand;
        }
    }

    part def LocalizationNode {
        attribute updateRate : Hertz = 30.0;
        attribute minimumConfidence : Percent = 70.0;

        port odometryInput {
            in item odometry : Odometry;
        }
        port poseOutput {
            out item pose : Pose2D;
        }

        action estimatePose {
            in item odometry : Odometry;
            out item estimatedPose : Pose2D;
        }
    }

    part def MappingNode {
        attribute mapResolution : Meter = 0.05;
        attribute localMapRadius : Meter = 3.5;

        port scanInput {
            in item scan : LaserScan;
        }
        port cameraInput {
            in item frame : CameraFrame;
        }
        port mapOutput {
            out item occupancyGrid : Real[*];
        }

        action updateOccupancyGrid {
            in item scan : LaserScan;
            in item frame : CameraFrame;
            out item occupancyGrid : Real[*];
        }
    }

    part def PlanningNode {
        attribute planningRate : Hertz = 10.0;
        attribute nominalLinearSpeed : MeterPerSecond = 0.22;
        attribute nominalAngularSpeed : RadianPerSecond = 2.84;
        attribute goalTolerance : Meter = 0.10;

        port goalInput : NavigationGoalPort;
        port poseInput {
            in item pose : Pose2D;
        }
        port mapInput {
            in item occupancyGrid : Real[*];
        }
        port safetyLimitInput {
            in item limitedTwist : Twist2D;
        }
        port wheelCommandOutput {
            out item command : WheelCommand;
        }

        action planPathAndVelocity {
            in item goal : NavigationGoal;
            in item pose : Pose2D;
            in item occupancyGrid : Real[*];
            out item command : WheelCommand;
        }
    }

    part def SafetyMonitor {
        attribute obstacleStopDistance : Meter = 0.22;
        attribute lowBatteryThreshold : Percent = 15.0;
        attribute watchdogTimeout : Second = 0.5;

        port commandInput : SupervisorCommandPort;
        port scanInput {
            in item scan : LaserScan;
        }
        port batteryInput {
            in item battery : BatteryStatus;
        }
        port safeVelocityOutput {
            out item limitedTwist : Twist2D;
        }

        state def SafetyStateMachine {
            state operational;
            state paused;
            state obstacleStop;
            state lowBatteryReturn;
            state emergencyStopped;

            entry action initializeSafetyMonitoring;

            transition first operational;
            transition operational to paused
                if commandInput.command.pauseNavigation;
            transition paused to operational
                if commandInput.command.enableAutonomy and not commandInput.command.pauseNavigation;
            transition operational to obstacleStop
                if scanInput.scan.obstacleDistances->exists(d | d < obstacleStopDistance);
            transition obstacleStop to operational
                if scanInput.scan.obstacleDistances->forAll(d | d >= obstacleStopDistance);
            transition operational to lowBatteryReturn
                if batteryInput.battery.stateOfCharge < lowBatteryThreshold;
            transition operational to emergencyStopped
                if commandInput.command.emergencyStop;
            transition paused to emergencyStopped
                if commandInput.command.emergencyStop;
            transition obstacleStop to emergencyStopped
                if commandInput.command.emergencyStop;
        }
    }

    part def RPLidarA1Sensor {
        attribute scanRate : Hertz = 5.5;
        attribute minimumRange : Meter = 0.12;
        attribute maximumRange : Meter = 12.0;
        attribute angularResolution : Radian = 0.01745;
        attribute powerDraw : Watt = 2.0;

        port powerIn : PowerLoadPort;
        port scanOut : LaserScanPort;

        action acquireLaserScan {
            out item scan : LaserScan;
        }
    }

    part def PiCameraModule {
        attribute frameRate : Hertz = 30.0;
        attribute horizontalPixels : Integer = 640;
        attribute verticalPixels : Integer = 480;
        attribute powerDraw : Watt = 1.2;

        port powerIn : PowerLoadPort;
        port frameOut : CameraFramePort;

        action acquireImage {
            out item frame : CameraFrame;
        }
    }

    part def OpenCRController {
        attribute controlLoopRate : Hertz = 100.0;
        attribute wheelRadius : Meter = 0.033;
        attribute wheelSeparation : Meter = 0.160;
        attribute maximumMotorCurrent : Ampere = 2.8;

        port powerIn : PowerLoadPort;
        port commandIn : WheelCommandPort;
        port telemetryOut : MotorTelemetryPort;
        port odometryOut : OdometryPort;

        part leftMotor : DynamixelWheelMotor {
            attribute side : String = "left";
        }
        part rightMotor : DynamixelWheelMotor {
            attribute side : String = "right";
        }

        connect commandIn to leftMotor.commandIn;
        connect commandIn to rightMotor.commandIn;
        connect leftMotor.telemetryOut to telemetryOut;
        connect rightMotor.telemetryOut to telemetryOut;

        action executeWheelControl {
            in item command : WheelCommand;
            out item odometry : Odometry;

            first receiveWheelCommand;
            then regulateLeftMotor;
            then regulateRightMotor;
            then integrateOdometry;
            then publishMotorTelemetry;
            then done;

            action receiveWheelCommand;
            action regulateLeftMotor;
            action regulateRightMotor;
            action integrateOdometry;
            action publishMotorTelemetry;
        }
    }

    part def DynamixelWheelMotor {
        attribute side : String;
        attribute maximumAngularVelocity : RadianPerSecond = 6.67;
        attribute stallTorqueNewtonMeter : Real = 1.5;
        attribute encoderResolutionTicks : Integer = 4096;

        port commandIn : WheelCommandPort;
        port telemetryOut : MotorTelemetryPort;

        action rotateWheel {
            in item command : WheelCommand;
            out item telemetry : MotorTelemetry;
        }
    }

    part def DifferentialDriveBase {
        attribute wheelRadius : Meter = 0.033;
        attribute wheelSeparation : Meter = 0.160;
        attribute maximumLinearVelocity : MeterPerSecond = 0.26;
        attribute maximumAngularVelocity : RadianPerSecond = 2.84;

        part controller : OpenCRController;
        port powerIn : PowerLoadPort;
        port commandIn : WheelCommandPort;
        port odometryOut : OdometryPort;
        port motorTelemetryOut : MotorTelemetryPort;

        connect powerIn to controller.powerIn;
        connect commandIn to controller.commandIn;
        connect controller.odometryOut to odometryOut;
        connect controller.telemetryOut to motorTelemetryOut;
    }

    part def TurtleBot3WafflePi {
        attribute robotName : String = "TurtleBot3 Waffle Pi";
        attribute platformLicense : String = "Open-source hardware and software platform";
        attribute mass : Real = 1.8;
        attribute primaryFunction : String = "Autonomous indoor mobile navigation, perception, and robotics research";

        part battery : LithiumIonBatteryPack;
        part onboardComputer : RaspberryPiComputer;
        part lidar : RPLidarA1Sensor;
        part camera : PiCameraModule;
        part driveBase : DifferentialDriveBase;

        port externalGoalIn : NavigationGoalPort;
        port supervisorCommandIn : SupervisorCommandPort;
        port robotTelemetryOut : TelemetryPort;

        connect battery.powerOut to onboardComputer.powerIn;
        connect battery.powerOut to lidar.powerIn;
        connect battery.powerOut to camera.powerIn;
        connect battery.powerOut to driveBase.powerIn;

        connect lidar.scanOut to onboardComputer.scanIn;
        connect camera.frameOut to onboardComputer.frameIn;
        connect driveBase.odometryOut to onboardComputer.odometryIn;

        connect externalGoalIn to onboardComputer.goalIn;
        connect supervisorCommandIn to onboardComputer.supervisorIn;
        connect onboardComputer.wheelCommandOut to driveBase.commandIn;
        connect onboardComputer.telemetryOut to robotTelemetryOut;

        perform action autonomousIndoorNavigation {
            first powerOn;
            then bootRobotSoftware;
            then awaitGoal;
            then perceiveEnvironment;
            then localizeRobot;
            then planMotion;
            then driveTowardGoal;
            then reportTelemetry;
            then done;

            action powerOn;
            action bootRobotSoftware;
            action awaitGoal;
            action perceiveEnvironment;
            action localizeRobot;
            action planMotion;
            action driveTowardGoal;
            action reportTelemetry;
        }

        state def MissionStateMachine {
            state off;
            state booting;
            state idle;
            state navigating;
            state paused;
            state goalReached;
            state fault;
            state emergencyStop;

            transition first off;
            transition off to booting
                if battery.chargeState.stateOfCharge > 10.0;
            transition booting to idle
                after 8.0 [Second];
            transition idle to navigating
                if externalGoalIn.goal.maximumSpeed > 0.0 and supervisorCommandIn.command.enableAutonomy;
            transition navigating to goalReached
                if externalGoalIn.goal.tolerance <= onboardComputer.planningNode.goalTolerance;
            transition navigating to paused
                if supervisorCommandIn.command.pauseNavigation;
            transition paused to navigating
                if supervisorCommandIn.command.enableAutonomy and not supervisorCommandIn.command.pauseNavigation;
            transition navigating to fault
                if battery.chargeState.stateOfCharge < battery.shutdownThreshold;
            transition idle to emergencyStop
                if supervisorCommandIn.command.emergencyStop;
            transition navigating to emergencyStop
                if supervisorCommandIn.command.emergencyStop;
            transition paused to emergencyStop
                if supervisorCommandIn.command.emergencyStop;
        }
    }

    requirement def NavigateIndoorEnvironmentRequirement {
        subject robot : TurtleBot3WafflePi;

        require constraint {
            robot.primaryFunction == "Autonomous indoor mobile navigation, perception, and robotics research"
        }

        doc /* The robot shall navigate an indoor environment by accepting a goal pose, perceiving obstacles, estimating pose, planning motion, and commanding its differential drive base. */
    }

    requirement def ObstacleAvoidanceRequirement {
        subject robot : TurtleBot3WafflePi;

        require constraint {
            robot.onboardComputer.safetyMonitor.obstacleStopDistance >= 0.20
        }

        doc /* The robot shall stop commanded forward motion when an obstacle is detected within the configured safety stop distance. */
    }

    requirement def SpeedLimitRequirement {
        subject robot : TurtleBot3WafflePi;

        require constraint {
            robot.driveBase.maximumLinearVelocity <= 0.26 and
            robot.driveBase.maximumAngularVelocity <= 2.84
        }

        doc /* The robot shall limit commanded motion to the physical limits of the TurtleBot3 Waffle Pi differential drive base. */
    }

    requirement def TelemetryRequirement {
        subject robot : TurtleBot3WafflePi;

        require constraint {
            robot.onboardComputer.commandUpdateRate >= 10.0
        }

        doc /* The robot shall publish odometry, health, and battery telemetry at a rate sufficient for supervisory monitoring. */
    }

    requirement def BatteryProtectionRequirement {
        subject robot : TurtleBot3WafflePi;

        require constraint {
            robot.battery.shutdownThreshold >= 10.0 and
            robot.onboardComputer.safetyMonitor.lowBatteryThreshold >= 15.0
        }

        doc /* The robot shall preserve battery health by warning at low charge and preventing continued autonomous operation below the shutdown threshold. */
    }

    requirement def OpenSourcePlatformRequirement {
        subject robot : TurtleBot3WafflePi;

        require constraint {
            robot.platformLicense == "Open-source hardware and software platform"
        }

        doc /* The modeled system shall represent an open-source robotics platform suitable for education, prototyping, and research. */
    }

    satisfy NavigateIndoorEnvironmentRequirement by TurtleBot3WafflePi::autonomousIndoorNavigation;
    satisfy ObstacleAvoidanceRequirement by TurtleBot3WafflePi::onboardComputer::safetyMonitor;
    satisfy SpeedLimitRequirement by TurtleBot3WafflePi::driveBase;
    satisfy TelemetryRequirement by TurtleBot3WafflePi::onboardComputer;
    satisfy BatteryProtectionRequirement by TurtleBot3WafflePi::battery;
    satisfy OpenSourcePlatformRequirement by TurtleBot3WafflePi;

    part turtleBot3System : TurtleBot3WafflePi;

}