package AutonomousMobileRobot {
    public import ISQ::*;
    public import SI::*;
    public import ScalarValues::*;

    package Definitions {
        public import ISQ::*;
        public import SI::*;
        public import ScalarValues::*;

        attribute def ChargeLevel :> Real;

        item def Pose {
            attribute x : Length;
            attribute y : Length;
            attribute theta : PlaneAngle;
        }
        item def Odometry {
            attribute pose : Pose;
            attribute linearVelocity : Speed;
            attribute angularVelocity : AngularVelocity;
        }
        item def LaserScan {
            attribute ranges : Length[0..*];
            attribute angleMin : PlaneAngle;
            attribute angleMax : PlaneAngle;
        }
        item def Twist {
            attribute linear : Speed;
            attribute angular : AngularVelocity;
        }
        item def OccupancyGridMap {
            attribute resolution : Length;
            attribute width : Integer;
            attribute height : Integer;
            attribute data : Real[0..*];
        }
        item def Path {
            attribute poses : Pose[0..*];
        }

        attribute def InitializationComplete;
        attribute def NavigationGoal {
            attribute goal : Pose;
        }
        attribute def GoalReached;
        attribute def StopCommand;
        attribute def BatteryLowSignal;
        attribute def SeekChargerSignal;
        attribute def ChargingCompleteSignal;

        port def LidarPort {
            out scan : LaserScan;
        }
        port def EncoderPort {
            out odom : Odometry;
        }
        port def MotorCmdPort {
            in cmd : Twist;
        }
        port def BatteryStatusPort {
            out charge : ChargeLevel;
        }
        port def PowerPort {
            out voltage : ElectricPotential;
        }

        action def PerformSLAM {
            in scan : LaserScan;
            in leftOdom : Odometry;
            in rightOdom : Odometry;
            out map : OccupancyGridMap;
            out pose : Pose;
        }
        action def PlanPath {
            in map : OccupancyGridMap;
            in currentPose : Pose;
            in goal : Pose;
            out path : Path;
        }
        action def AvoidObstacles {
            in scan : LaserScan;
            in path : Path;
            out safePath : Path;
        }
        action def ComputeVelocityCmd {
            in path : Path;
            in currentPose : Pose;
            out leftCmd : Twist;
            out rightCmd : Twist;
        }
        action def Navigate {
            in goal : Pose;
            in scan : LaserScan;
            in leftOdom : Odometry;
            in rightOdom : Odometry;
            out leftCmd : Twist;
            out rightCmd : Twist;
            action slam : PerformSLAM;
            action plan : PlanPath;
            action avoid : AvoidObstacles;
            action control : ComputeVelocityCmd;
            flow scan to slam.scan;
            flow leftOdom to slam.leftOdom;
            flow rightOdom to slam.rightOdom;
            flow slam.map to plan.map;
            flow slam.pose to plan.currentPose;
            flow goal to plan.goal;
            flow plan.path to avoid.path;
            flow scan to avoid.scan;
            flow avoid.safePath to control.path;
            flow slam.pose to control.currentPose;
            flow control.leftCmd to leftCmd;
            flow control.rightCmd to rightCmd;
        }
        action def SeekChargingStation {
            in map : OccupancyGridMap;
            in currentPose : Pose;
            out path : Path;
        }
        action def InitializeSystems;
        action def AssessPower;
        action def SeekCharger;

        part def Wheel {
            attribute radius : Length;
        }
        part def WheelEncoder {
            port dataOut : EncoderPort;
        }
        part def MotorDriver {
            port cmdIn : MotorCmdPort;
            port powerIn : ~PowerPort;
        }
        part def MobileBase {
            part leftWheel : Wheel;
            part rightWheel : Wheel;
            part leftEncoder : WheelEncoder;
            part rightEncoder : WheelEncoder;
            part leftMotor : MotorDriver;
            part rightMotor : MotorDriver;
            attribute wheelBase : Length;
        }
        part def LidarSensor {
            attribute maxRange : Length = 12 [m];
            attribute scanRate : Frequency;
            port scanOut : LidarPort;
            port powerIn : ~PowerPort;
        }
        part def ComputeModule {
            attribute os : String = "Ubuntu";
            attribute framework : String = "ROS 2";
            port scanIn : ~LidarPort;
            port leftOdomIn : ~EncoderPort;
            port rightOdomIn : ~EncoderPort;
            port leftCmdOut : ~MotorCmdPort;
            port rightCmdOut : ~MotorCmdPort;
            port batteryStatusIn : ~BatteryStatusPort;
            port powerIn : ~PowerPort;
        }
        part def BatteryPack {
            attribute capacity : Energy;
            attribute currentCharge : ChargeLevel;
            port chargeOut : BatteryStatusPort;
            port powerOut : PowerPort;
        }
        part def Robot {
            part base : MobileBase;
            part lidar : LidarSensor;
            part compute : ComputeModule;
            part battery : BatteryPack;
        }

        state def RobotStates {
            in robot : Robot;
            entry; then initializing;
            state initializing {
                entry action initialize : InitializeSystems;
            }
            state standby;
            state activeNavigation {
                do action navigate : Navigate;
            }
            state lowPower {
                do action assess : AssessPower;
            }
            state seekingCharger {
                do action seek : SeekCharger;
            }
            transition init_to_standby
                first initializing
                accept InitializationComplete
                then standby;
            transition standby_to_active
                first standby
                accept goal : NavigationGoal
                then activeNavigation;
            transition active_to_standby_goal
                first activeNavigation
                accept GoalReached
                then standby;
            transition active_to_standby_stop
                first activeNavigation
                accept StopCommand
                then standby;
            transition active_to_lowPower
                first activeNavigation
                accept BatteryLowSignal
                then lowPower;
            transition standby_to_lowPower
                first standby
                accept BatteryLowSignal
                then lowPower;
            transition lowPower_to_seeking
                first lowPower
                accept SeekChargerSignal
                then seekingCharger;
            transition seeking_to_standby
                first seekingCharger
                accept ChargingCompleteSignal
                then standby;
        }

        requirement def SLAMCapability {
            subject robot : Robot;
            requirement {
                robot.compute shall perform SLAM using data from robot.lidar and robot.base.leftEncoder to navigate unknown indoor environments autonomously.
            }
        }
        requirement def ObstacleAvoidanceCapability {
            subject robot : Robot;
            requirement {
                robot.compute shall detect obstacles within a 12 m range using robot.lidar and plan collision-free paths to the navigation goal.
            }
        }
        requirement def DifferentialDriveMobility {
            subject robot : Robot;
            requirement {
                robot.base shall use a two-wheeled differential drive system to move forward, backward, and turn in place.
            }
        }
        requirement def PowerManagementCapability {
            subject robot : Robot;
            requirement {
                robot.battery shall continuously monitor charge levels and the robot shall enter low-power mode to seek a charging station before critical depletion.
            }
        }
    }

    public import Definitions::*;

    package Usages {
        public import Definitions::*;

        part robot : Robot {
            part base : MobileBase {
                part leftWheel : Wheel {
                    attribute radius = 0.05 [m];
                }
                part rightWheel : Wheel {
                    attribute radius = 0.05 [m];
                }
                attribute wheelBase = 0.3 [m];
            }
            part lidar : LidarSensor {
                attribute maxRange = 12 [m];
                attribute scanRate = 10 [Hz];
            }
            part compute : ComputeModule;
            part battery : BatteryPack {
                attribute capacity = 360000 [J];
                attribute currentCharge = 1.0;
            }

            connect lidar.scanOut to compute.scanIn;
            connect base.leftEncoder.dataOut to compute.leftOdomIn;
            connect base.rightEncoder.dataOut to compute.rightOdomIn;
            connect compute.leftCmdOut to base.leftMotor.cmdIn;
            connect compute.rightCmdOut to base.rightMotor.cmdIn;
            connect battery.chargeOut to compute.batteryStatusIn;
            connect battery.powerOut to compute.powerIn;
            connect battery.powerOut to lidar.powerIn;
            connect battery.powerOut to base.leftMotor.powerIn;
            connect battery.powerOut to base.rightMotor.powerIn;

            exhibit state robotStates : RobotStates {
                in robot = robot;
            }

            satisfy SLAMCapability {
                subject robot = robot;
            }
            satisfy ObstacleAvoidanceCapability {
                subject robot = robot;
            }
            satisfy DifferentialDriveMobility {
                subject robot = robot;
            }
            satisfy PowerManagementCapability {
                subject robot = robot;
            }
        }
    }
}
