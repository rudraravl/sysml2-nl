package QuadrupedRobotSystem {
    public import ISQ::*;
    public import ScalarValues::*;

    attribute def AngleValue :> Real {
        unit 'rad';
    }
    attribute def ForceValue :> Real {
        unit 'N';
    }
    attribute def TorqueValue :> Real {
        unit 'N*m';
    }
    attribute def PowerValue :> Real {
        unit 'W';
    }
    attribute def EnergyValue :> Real {
        unit 'J';
    }
    attribute def VoltageValue :> Real {
        unit 'V';
    }
    attribute def ChargeValue :> Real {
        unit 'C';
    }
    attribute def MassValue :> Real {
        unit 'kg';
    }
    attribute def DistanceValue :> Real {
        unit 'm';
    }
    attribute def AngularVelocityValue :> Real {
        unit 'rad/s';
    }
    attribute def LinearVelocityValue :> Real {
        unit 'm/s';
    }

    item def JointAngleCommand {
        attribute hipAngle : AngleValue;
        attribute kneeAngle : AngleValue;
        attribute ankleAngle : AngleValue;
    }
    item def JointForceCommand {
        attribute hipForce : ForceValue;
        attribute kneeForce : ForceValue;
        attribute ankleForce : ForceValue;
    }
    item def FootForceReading {
        attribute contactForce : ForceValue;
        attribute inContact : Boolean;
    }
    item def IMUReading {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
        attribute rollRate : AngularVelocityValue;
        attribute pitchRate : AngularVelocityValue;
        attribute yawRate : AngularVelocityValue;
    }
    item def LidarScan {
        attribute pointCount : Integer;
        attribute ranges : Real[0..*] 'm';
        attribute angularResolution : AngleValue;
    }
    item def TerrainMap {
        attribute resolution : DistanceValue;
        attribute obstacleCount : Integer;
    }
    item def NavigationCommand {
        attribute targetX : DistanceValue;
        attribute targetY : DistanceValue;
        attribute targetZ : DistanceValue;
        attribute desiredSpeed : LinearVelocityValue;
    }
    item def TaskCommand {
        attribute taskName : String;
        attribute priority : Integer;
    }
    item def StatusReport {
        attribute mode : String;
        attribute batteryLevel : Real '%';
        attribute stabilityIndex : Real;
        attribute currentPositionX : DistanceValue;
        attribute currentPositionY : DistanceValue;
    }
    item def GaitSelection {
        attribute gait : GaitKind;
        attribute terrain : TerrainKind;
    }
    item def BalanceCorrection {
        attribute rollCorrection : TorqueValue;
        attribute pitchCorrection : TorqueValue;
        attribute yawCorrection : TorqueValue;
    }

    enum def GaitKind { walking, trotting, crawling, bounding }
    enum def TerrainKind { flat, rough, stairs, slope, gravel }
    enum def RobotMode { idle, navigating, executingTask, recovering }

    port def JointCommandPort {
        out angleCommand : JointAngleCommand;
        out forceCommand : JointForceCommand;
        in footForce : FootForceReading;
    }
    port def IMUPort { out imuData : IMUReading; }
    port def LidarPort { out scan : LidarScan; }
    port def MapPort { out terrainMap : TerrainMap; }
    port def NavCommandPort { in navCommand : NavigationCommand; }
    port def TaskCommandPort { in taskCommand : TaskCommand; }
    port def StatusPort { out status : StatusReport; }
    port def GaitPort { out gaitSelection : GaitSelection; }
    port def BalancePort { out correction : BalanceCorrection; }
    port def PowerPort { out voltage : VoltageValue; out charge : ChargeValue; }

    requirement def RobotSystemRequirements {
        subject robot : QuadrupedRobot;
        subject station : ControlStation;
        requirement R1_Navigation {
            doc /* The robot shall navigate complex and varied environments. */
        }
        requirement R2_TaskExecution {
            doc /* The robot shall perform specific tasks at designated locations. */
        }
        requirement R3_Balance {
            doc /* The balance controller shall maintain stability during movement. */
        }
        requirement R4_Sensing {
            doc /* The robot shall sense orientation and environment. */
        }
        requirement R5_Telemetry {
            doc /* The control station shall receive status reports. */
        }
    }

    part def Joint {
        attribute name : String;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute maxTorque : TorqueValue;
        attribute currentAngle : AngleValue;
        attribute appliedForce : ForceValue;
        in angleCommand : JointAngleCommand;
        in forceCommand : JointForceCommand;
        in correction : BalanceCorrection;
        action UpdateJoint {
            in cmd : JointAngleCommand;
            in frc : JointForceCommand;
            in corr : BalanceCorrection;
        }
    }

    part def Foot {
        attribute name : String;
        out footForce : FootForceReading;
        action SenseContact {
            out reading : FootForceReading;
        }
    }

    part def Leg {
        attribute name : String;
        part hip : Joint { attribute name = "hip"; }
        part knee : Joint { attribute name = "knee"; }
        part ankle : Joint { attribute name = "ankle"; }
        part foot : Foot;
        port jointCmd : JointCommandPort;
        flow jointCmd.angleCommand to hip.angleCommand;
        flow jointCmd.angleCommand to knee.angleCommand;
        flow jointCmd.angleCommand to ankle.angleCommand;
        flow jointCmd.forceCommand to hip.forceCommand;
        flow jointCmd.forceCommand to knee.forceCommand;
        flow jointCmd.forceCommand to ankle.forceCommand;
        flow foot.footForce to jointCmd.footForce;
    }

    part def IMU {
        out imuData : IMUReading via IMUPort;
        action Sample {
            out reading : IMUReading;
        }
    }

    part def Lidar {
        out scan : LidarScan via LidarPort;
        action ScanEnvironment {
            out scanData : LidarScan;
        }
    }

    part def Battery {
        attribute capacity : ChargeValue;
        attribute currentCharge : ChargeValue;
        attribute nominalVoltage : VoltageValue;
        attribute stateOfCharge : Real '%';
        out power : PowerPort;
        action Discharge {
            out v : VoltageValue;
            out c : ChargeValue;
        }
        action Recharge {
            in supplyVoltage : VoltageValue;
        }
    }

    part def MotionPlanner {
        in navCommand : NavigationCommand;
        in imuData : IMUReading;
        in terrainMap : TerrainMap;
        in footForces : FootForceReading[4];
        out gaitSelection : GaitSelection via GaitPort;
        out flCmd : JointAngleCommand;
        out frCmd : JointAngleCommand;
        out rlCmd : JointAngleCommand;
        out rrCmd : JointAngleCommand;
        out flForce : JointForceCommand;
        out frForce : JointForceCommand;
        out rlForce : JointForceCommand;
        out rrForce : JointForceCommand;
        attribute selectedGait : GaitKind;
        attribute detectedTerrain : TerrainKind;
        action PlanGait {
            in terrain : TerrainMap;
            in imu : IMUReading;
            out gait : GaitSelection;
        }
        action GenerateJointCommands {
            in gait : GaitSelection;
            in nav : NavigationCommand;
            out fl : JointAngleCommand;
            out fr : JointAngleCommand;
            out rl : JointAngleCommand;
            out rr : JointAngleCommand;
        }
    }

    part def BalanceController {
        in imuData : IMUReading;
        in footForces : FootForceReading[4];
        out correction : BalanceCorrection via BalancePort;
        attribute stabilityIndex : Real;
        action MonitorStability {
            in imu : IMUReading;
            in forces : FootForceReading[4];
            out corr : BalanceCorrection;
            out index : Real;
        }
        action MicroAdjust {
            in corr : BalanceCorrection;
        }
    }

    part def TaskExecutor {
        in taskCommand : TaskCommand;
        attribute currentTask : String;
        attribute taskProgress : Real '%';
        action ExecuteTask {
            in task : TaskCommand;
            out progress : Real;
        }
        action AbortTask;
    }

    part def ControlStation {
        out navCommand : NavigationCommand via NavCommandPort;
        out taskCommand : TaskCommand via TaskCommandPort;
        in status : StatusReport via StatusPort;
        attribute operatorName : String;
        action IssueNavigationCommand {
            out cmd : NavigationCommand;
        }
        action IssueTaskCommand {
            out cmd : TaskCommand;
        }
        action DisplayStatus {
            in report : StatusReport;
        }
    }

    part def QuadrupedRobot {
        attribute robotId : String;
        attribute mode : RobotMode = RobotMode::idle;
        part frontLeftLeg : Leg { attribute name = "front-left"; }
        part frontRightLeg : Leg { attribute name = "front-right"; }
        part rearLeftLeg : Leg { attribute name = "rear-left"; }
        part rearRightLeg : Leg { attribute name = "rear-right"; }
        part imu : IMU;
        part lidar : Lidar;
        part battery : Battery;
        part motionPlanner : MotionPlanner;
        part balanceController : BalanceController;
        part taskExecutor : TaskExecutor;
        port navIn : NavCommandPort;
        port taskIn : TaskCommandPort;
        port statusOut : StatusPort;
        flow navIn.navCommand to motionPlanner.navCommand;
        flow taskIn.taskCommand to taskExecutor.taskCommand;
        flow imu.imuData to motionPlanner.imuData;
        flow imu.imuData to balanceController.imuData;
        flow lidar.scan to motionPlanner.terrainMap;
        flow frontLeftLeg.jointCmd.footForce to motionPlanner.footForces[1];
        flow frontRightLeg.jointCmd.footForce to motionPlanner.footForces[2];
        flow rearLeftLeg.jointCmd.footForce to motionPlanner.footForces[3];
        flow rearRightLeg.jointCmd.footForce to motionPlanner.footForces[4];
        flow frontLeftLeg.jointCmd.footForce to balanceController.footForces[1];
        flow frontRightLeg.jointCmd.footForce to balanceController.footForces[2];
        flow rearLeftLeg.jointCmd.footForce to balanceController.footForces[3];
        flow rearRightLeg.jointCmd.footForce to balanceController.footForces[4];
        flow motionPlanner.flCmd to frontLeftLeg.jointCmd.angleCommand;
        flow motionPlanner.frCmd to frontRightLeg.jointCmd.angleCommand;
        flow motionPlanner.rlCmd to rearLeftLeg.jointCmd.angleCommand;
        flow motionPlanner.rrCmd to rearRightLeg.jointCmd.angleCommand;
        flow motionPlanner.flForce to frontLeftLeg.jointCmd.forceCommand;
        flow motionPlanner.frForce to frontRightLeg.jointCmd.forceCommand;
        flow motionPlanner.rlForce to rearLeftLeg.jointCmd.forceCommand;
        flow motionPlanner.rrForce to rearRightLeg.jointCmd.forceCommand;
        flow balanceController.correction to frontLeftLeg.hip.correction;
        flow balanceController.correction to frontRightLeg.hip.correction;
        flow balanceController.correction to rearLeftLeg.hip.correction;
        flow balanceController.correction to rearRightLeg.hip.correction;
        flow battery.power to motionPlanner;
        flow battery.power to balanceController;
        flow battery.power to taskExecutor;
        flow battery.power to imu;
        flow battery.power to lidar;
        action ReportStatus {
            out report : StatusReport;
        }
        state def RobotStateMachine {
            idle;
            navigating;
            executingTask;
            recovering;
            transition idle to navigating when navIn.navCommand.targetX > 0;
            transition navigating to executingTask when taskExecutor.taskProgress > 0;
            transition executingTask to idle when taskExecutor.taskProgress >= 100;
            transition navigating to recovering when balanceController.stabilityIndex < 0.3;
            transition executingTask to recovering when balanceController.stabilityIndex < 0.3;
            transition recovering to idle when balanceController.stabilityIndex >= 0.8;
        }
        state robotState : RobotStateMachine;
    }

    part def QuadrupedSystem {
        part robot : QuadrupedRobot;
        part station : ControlStation;
        flow station.navCommand to robot.navIn;
        flow station.taskCommand to robot.taskIn;
        flow robot.statusOut.status to station.status;
        satisfy RobotSystemRequirements {
            subject robot = robot;
            subject station = station;
        }
    }
}
