package AutonomousMobileRobot {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQElectricity::*;
    import ISQEnergy::*;

    // ---------- Value types ----------
    value def Length12m :> Real {
        unit m;
    }
    value def Distance :> Real {
        unit m;
    }
    value def LinearVelocity :> Real {
        unit 'm/s';
    }
    value def AngularVelocity :> Real {
        unit 'rad/s';
    }
    value def RotationRate :> Real {
        unit 'rev/min';
    }
    value def Angle :> Real {
        unit rad;
    }
    value def Voltage :> Real {
        unit V;
    }
    value def Current :> Real {
        unit A;
    }
    value def Charge :> Real {
        unit C;
    }
    value def BatteryLevel :> Real {
        unit '%';
    }
    value def Power :> Real {
        unit W;
    }
    value def Mass :> Real {
        unit kg;
    }
    value def Frequency :> Real {
        unit Hz;
    }
    value def DataRate :> Real {
        unit 'Mb/s';
    }

    item def Pose {
        attribute x : Distance;
        attribute y : Distance;
        attribute theta : Angle;
    }

    item def OdometryMsg {
        attribute pose : Pose;
        attribute linearVelocity : LinearVelocity;
        attribute angularVelocity : AngularVelocity;
    }

    item def LaserScan {
        attribute angleMin : Angle;
        attribute angleMax : Angle;
        attribute angleIncrement : Angle;
        attribute rangeMax : Distance = 12 [m];
        attribute ranges : Distance[0..*];
        attribute timestamp : TimeValue;
    }

    item def OccupancyGrid {
        attribute resolution : Distance;
        attribute width : Positive;
        attribute height : Positive;
        attribute data : Real[0..*];
    }

    item def GoalPose {
        attribute target : Pose;
    }

    item def TwistCommand {
        attribute linear : LinearVelocity;
        attribute angular : AngularVelocity;
    }

    item def BatteryStatus {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute charge : Charge;
        attribute level : BatteryLevel;
    }

    item def PowerCommand {
        attribute mode : PowerMode;
    }

    enum def PowerMode {
        normal;
        lowPower;
        critical;
    }

    // ---------- Ports ----------
    port def LidarDataPort {
        out scan : LaserScan;
    }

    port def EncoderDataPort {
        out odom : OdometryMsg;
    }

    port def MotorCommandPort {
        in cmd : TwistCommand;
    }

    port def BatteryMonitorPort {
        out status : BatteryStatus;
    }

    port def PowerOutputPort {
        out voltage : Voltage;
        out current : Current;
    }

    port def PowerInputPort {
        in voltage : Voltage;
        in current : Current;
    }

    port def GoalPort {
        in goal : GoalPose;
    }

    port def MapPort {
        out map : OccupancyGrid;
    }

    // ---------- Requirements ----------
    requirement def NavigationRequirement {
        doc <<The robot shall autonomously navigate unknown indoor environments using SLAM.>>
        subject robot : AutonomousRobot;
        objective {
            doc <<Build a map while localizing and reach a goal without collision.>>
        }
        require robot.base.driveSystem.kind == 'differential';
        require robot.lidar.rangeMax >= 12 [m];
        require robot.compute.os == 'Ubuntu';
        require robot.compute.framework == 'ROS2';
    }

    requirement def ObstacleAvoidanceRequirement {
        doc <<The robot shall detect and avoid obstacles up to 12 m away.>>
        subject robot : AutonomousRobot;
        require robot.lidar.fov == 360 [deg];
        require robot.compute.pathPlanner.collisionFree == true;
    }

    requirement def PowerManagementRequirement {
        doc <<The robot shall monitor battery and enter low-power mode when low.>>
        subject robot : AutonomousRobot;
        require robot.battery.monitoringEnabled == true;
        require if robot.battery.level < 20 [%] then robot.powerMode == PowerMode::lowPower;
        require if robot.battery.level < 5 [%] then robot.seekCharger == true;
    }

    requirement def OdometryRequirement {
        doc <<Wheel encoders shall continuously track rotation to compute odometry.>>
        subject robot : AutonomousRobot;
        require robot.base.leftWheel.encoder.present == true;
        require robot.base.rightWheel.encoder.present == true;
        require robot.base.odometryUpdateRate >= 50 [Hz];
    }

    // ---------- Parts: Wheel ----------
    part def Wheel {
        attribute radius : Distance = 0.05 [m];
        port encoderOut : EncoderDataPort;
        part encoder : WheelEncoder;
        part motor : WheelMotor;

        action def Spin {
            in angularVelocity : AngularVelocity;
        }
    }

    part def WheelEncoder {
        attribute ticksPerRev : Positive = 1024;
        attribute present : Boolean = true;
        attribute lastTick : Integer = 0;
        compute updateOdom {
            // produce OdometryMsg based on tick count
        }
    }

    part def WheelMotor {
        attribute nominalVoltage : Voltage = 12 [V];
        attribute maxRpm : RotationRate = 200 [rev/min];
        in cmd : TwistCommand;
    }

    // ---------- Parts: Differential Drive Base ----------
    part def DifferentialDriveBase {
        attribute wheelBase : Distance = 0.30 [m];
        attribute odometryUpdateRate : Frequency = 50 [Hz];
        attribute driveSystemKind : String = 'differential';

        port leftEncoder : EncoderDataPort;
        port rightEncoder : EncoderDataPort;
        port motorCmd : MotorCommandPort;

        part leftWheel : Wheel {
            redefines encoderOut = base::leftEncoder;
        }
        part rightWheel : Wheel {
            redefines encoderOut = base::rightEncoder;
        }

        action def ComputeOdometry {
            in leftOdom : OdometryMsg;
            in rightOdom : OdometryMsg;
            out combinedOdom : OdometryMsg;
        }

        action def ApplyTwist {
            in cmd : TwistCommand;
            out leftCmd : TwistCommand;
            out rightCmd : TwistCommand;
        }
    }

    // ---------- Parts: Lidar ----------
    part def LidarSensor {
        attribute rangeMax : Distance = 12 [m];
        attribute fov : Angle = 360 [deg];
        attribute scanRate : Frequency = 10 [Hz];
        attribute angularResolution : Angle = 1 [deg];
        attribute powerConsumption : Power = 2.5 [W];

        port dataOut : LidarDataPort;
        port powerIn : PowerInputPort;

        action def Scan {
            out scan : LaserScan;
        }

        perform scan : Scan {
            out dataOut.scan;
        }
    }

    // ---------- Parts: Compute Module ----------
    part def ComputeModule {
        attribute os : String = 'Ubuntu';
        attribute framework : String = 'ROS2';
        attribute cpuCores : Positive = 4;
        attribute ram : Mass = 8 [GB] /* conceptual */;
        attribute powerConsumption : Power = 10 [W];

        port lidarIn : LidarDataPort;
        port odomIn : EncoderDataPort;
        port motorOut : MotorCommandPort;
        port goalIn : GoalPort;
        port mapOut : MapPort;
        port batteryIn : BatteryMonitorPort;
        port powerIn : PowerInputPort;

        part slamNode : SlamNode;
        part pathPlanner : PathPlanner;
        part motorController : MotorControllerNode;
        part batteryMonitor : BatteryMonitorNode;

        state def ComputeStates {
            entry; then initializing;
            state initializing;
            transition from initializing to ready
                when lidarIn.scan.ranges->size() > 0;
            state ready;
            transition from ready to navigating
                when goalIn.goal.target.x != 0 [m] or goalIn.goal.target.y != 0 [m];
            state navigating;
            transition from navigating to ready
                when goalReached;
            attribute goalReached : Boolean = false;
        }

        exhibit stateBehavior : ComputeStates;
    }

    part def SlamNode {
        attribute mapResolution : Distance = 0.05 [m];
        port scanIn : LidarDataPort;
        port odomIn : EncoderDataPort;
        port mapOut : MapPort;

        action def BuildMap {
            in scan : LaserScan;
            in odom : OdometryMsg;
            out map : OccupancyGrid;
            out pose : Pose;
        }
    }

    part def PathPlanner {
        attribute collisionFree : Boolean = true;
        attribute algorithm : String = 'A*';
        port mapIn : MapPort;
        port goalIn : GoalPort;
        port cmdOut : MotorCommandPort;

        action def PlanPath {
            in map : OccupancyGrid;
            in goal : GoalPose;
            out cmd : TwistCommand;
        }
    }

    part def MotorControllerNode {
        port cmdIn : MotorCommandPort;
        port cmdOut : MotorCommandPort;

        action def ConvertTwist {
            in cmd : TwistCommand;
            out motorCmd : TwistCommand;
        }
    }

    part def BatteryMonitorNode {
        port statusIn : BatteryMonitorPort;
        attribute thresholdLow : BatteryLevel = 20 [%];
        attribute thresholdCritical : BatteryLevel = 5 [%];
        attribute currentMode : PowerMode = PowerMode::normal;

        action def EvaluatePower {
            in status : BatteryStatus;
            out mode : PowerMode;
        }
    }

    // ---------- Parts: Battery ----------
    part def BatteryPack {
        attribute nominalVoltage : Voltage = 12 [V];
        attribute capacity : Charge = 5000 [C] * 3600 /* mAh equivalent */;
        attribute level : BatteryLevel = 100 [%];
        attribute monitoringEnabled : Boolean = true;
        attribute powerConsumption : Power = 0 [W];

        port monitorOut : BatteryMonitorPort;
        port powerOut : PowerOutputPort;

        action def Discharge {
            in load : Power;
            out status : BatteryStatus;
        }

        action def Charge {
            in voltage : Voltage;
            in current : Current;
            out status : BatteryStatus;
        }

        perform discharge : Discharge {
            out monitorOut.status;
        }
    }

    // ---------- Parts: Charging Station ----------
    part def ChargingStation {
        attribute outputVoltage : Voltage = 12 [V];
        attribute outputCurrent : Current = 2 [A];
        port powerOut : PowerOutputPort;

        action def ProvideCharge {
            out voltage : Voltage;
            out current : Current;
        }
    }

    // ---------- Top-level Robot ----------
    part def AutonomousRobot {
        attribute mass : Mass = 5 [kg];
        attribute powerMode : PowerMode = PowerMode::normal;
        attribute seekCharger : Boolean = false;

        port goalPort : GoalPort;
        port mapPort : MapPort;

        part base : DifferentialDriveBase;
        part lidar : LidarSensor;
        part compute : ComputeModule;
        part battery : BatteryPack;
        part charger : ChargingStation;

        // Power distribution
        connection battery.powerOut to lidar.powerIn;
        connection battery.powerOut to compute.powerIn;

        // Data flow: sensors to compute
        connection lidar.dataOut to compute.lidarIn;
        connection base.leftEncoder to compute.odomIn;
        connection base.rightEncoder to compute.odomIn;

        // Data flow: compute to motors
        connection compute.motorOut to base.motorCmd;

        // Goal and map
        connection goalPort to compute.goalIn;
        connection compute.mapOut to mapPort;

        // Battery monitoring
        connection battery.monitorOut to compute.batteryIn;

        // Charging station connection (when docked)
        connection charger.powerOut to battery.powerOut;

        // Robot-level state machine
        state def RobotStates {
            entry; then Initializing;
            state Initializing {
                entry {
                    powerMode = PowerMode::normal;
                }
            }
            transition from Initializing to Standby
                when compute.stateBehavior.ready;
            state Standby;
            transition from Standby to ActiveNavigation
                when goalPort.goal.target.x != 0 [m] or goalPort.goal.target.y != 0 [m];
            state ActiveNavigation;
            transition from ActiveNavigation to LowPower
                when battery.level < 20 [%];
            transition from Standby to LowPower
                when battery.level < 20 [%];
            state LowPower {
                entry {
                    powerMode = PowerMode::lowPower;
                    seekCharger = true;
                }
            }
            transition from LowPower to SeekingCharger
                when seekCharger == true;
            state SeekingCharger;
            transition from SeekingCharger to Charging
                when docked;
            attribute docked : Boolean = false;
            state Charging;
            transition from Charging to Standby
                when battery.level >= 95 [%];
            transition from any to CriticalShutdown
                when battery.level < 5 [%];
            state CriticalShutdown {
                entry {
                    powerMode = PowerMode::critical;
                }
            }
        }

        exhibit robotStateMachine : RobotStates;

        satisfy NavigationRequirement by robot;
        satisfy ObstacleAvoidanceRequirement by robot;
        satisfy PowerManagementRequirement by robot;
        satisfy OdometryRequirement by robot;
    }

    // ---------- Instance ----------
    part researchRobot : AutonomousRobot {
        attribute name : String = 'OSMR-1';
        attribute purpose : String = 'research and education';
    }
}
