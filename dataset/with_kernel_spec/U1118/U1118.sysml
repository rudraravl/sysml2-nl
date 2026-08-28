package QuadrupedRobotSystem {
    import ISQ::*;
    import ScalarValues::*;

    enum def TerrainKind { flat; rough; stairs; }
    enum def GaitKind { walk; trot; crawl; }
    enum def RobotModeKind { idle; navigating; executingTask; recovering; }
    enum def TaskKind { inspection; surveillance; payloadDelivery; }
    enum def JointKind { hip; knee; ankle; }
    enum def LegPositionKind { frontLeft; frontRight; rearLeft; rearRight; }

    requirement def BalanceRequirement {
        doc /* The robot shall maintain stability using IMU feedback. */
    }
    requirement def NavigationRequirement {
        doc /* The robot shall use LIDAR for obstacle avoidance and path planning. */
    }
    requirement def TaskExecutionRequirement {
        doc /* The robot shall execute assigned tasks upon arrival. */
    }
    requirement def ForceSensingRequirement {
        doc /* The robot shall detect ground contact and measure applied force in each foot. */
    }

    port def JointCommandPort {
        in attribute angleCommand : ISQ::AngleValue;
        in attribute forceCommand : ISQ::ForceValue;
    }
    port def JointSensorPort {
        out attribute measuredAngle : ISQ::AngleValue;
        out attribute measuredTorque : ISQ::ForceValue;
    }
    port def IMUDataPort {
        out attribute roll : ISQ::AngleValue;
        out attribute pitch : ISQ::AngleValue;
        out attribute yaw : ISQ::AngleValue;
    }
    port def LidarDataPort {
        out attribute pointCloud : ScalarValues::Real;
    }
    port def NavCommandPort {
        in attribute targetPosition : ISQ::LengthValue[3];
        in attribute targetVelocity : ISQ::SpeedValue;
        in attribute terrain : TerrainKind;
    }
    port def TaskCommandPort {
        in attribute task : TaskKind;
        in attribute targetLocation : ISQ::LengthValue[3];
    }
    port def StatusReportPort {
        out attribute mode : RobotModeKind;
        out attribute batteryLevel : ScalarValues::Real;
        out attribute stability : ScalarValues::Boolean;
    }
    port def TaskStatusPort {
        out attribute taskStatus : ScalarValues::String;
        out attribute taskProgress : ScalarValues::Real;
    }
    port def BatteryStatusPort {
        out attribute charge : ScalarValues::Real;
        out attribute lowBattery : ScalarValues::Boolean;
    }
    port def CorrectionPort {
        out attribute correctionForces : ISQ::ForceValue[4];
    }
    port def ForceSensorPort {
        out attribute force : ISQ::ForceValue;
    }

    part def Joint {
        attribute kind : JointKind;
        attribute currentAngle : ISQ::AngleValue;
        port commandPort : JointCommandPort;
        port sensorPort : JointSensorPort;
    }

    part def ForceSensor {
        attribute measuredForce : ISQ::ForceValue;
        port sensorPort : ForceSensorPort;
    }

    part def Leg {
        attribute legPosition : LegPositionKind;
        part hipJoint : Joint { :>> kind = JointKind::hip; }
        part kneeJoint : Joint { :>> kind = JointKind::knee; }
        part ankleJoint : Joint { :>> kind = JointKind::ankle; }
        part footForceSensor : ForceSensor;
    }

    part def IMUSensor {
        attribute roll : ISQ::AngleValue;
        attribute pitch : ISQ::AngleValue;
        attribute yaw : ISQ::AngleValue;
        port dataPort : IMUDataPort;
    }

    part def LidarSensor {
        attribute pointCloudData : ScalarValues::Real;
        port dataPort : LidarDataPort;
    }

    part def Battery {
        attribute chargeLevel : ScalarValues::Real;
        attribute capacity : ISQ::EnergyValue;
        port statusPort : BatteryStatusPort;
    }

    part def MotionPlanner {
        attribute selectedGait : GaitKind;
        port navCommandPort : NavCommandPort;
        port sensorDataPort : ~LidarDataPort;
        port correctionInputPort : ~CorrectionPort;
        port frontLeftHipOut : JointCommandPort;
        port frontLeftKneeOut : JointCommandPort;
        port frontLeftAnkleOut : JointCommandPort;
        port frontRightHipOut : JointCommandPort;
        port frontRightKneeOut : JointCommandPort;
        port frontRightAnkleOut : JointCommandPort;
        port rearLeftHipOut : JointCommandPort;
        port rearLeftKneeOut : JointCommandPort;
        port rearLeftAnkleOut : JointCommandPort;
        port rearRightHipOut : JointCommandPort;
        port rearRightKneeOut : JointCommandPort;
        port rearRightAnkleOut : JointCommandPort;
        port gaitStatusPort {
            out attribute currentGait : GaitKind;
        }
        perform action planMotion {
            in terrain : TerrainKind;
            in lidarData : ScalarValues::Real;
            out selectedGait : GaitKind;
            first start;
            then action chooseGait {
                in terrain : TerrainKind;
                out selectedGait : GaitKind;
            }
            then action computeLegCommands;
            then done;
        }
    }

    part def BalanceController {
        port imuDataPort : ~IMUDataPort;
        port correctionOutputPort : CorrectionPort;
        perform action maintainBalance {
            in roll : ISQ::AngleValue;
            in pitch : ISQ::AngleValue;
            in yaw : ISQ::AngleValue;
            out correctionForces : ISQ::ForceValue[4];
            first start;
            then action computeCorrections;
            then done;
        }
    }

    part def TaskExecutor {
        port taskCommandPort : TaskCommandPort;
        port taskStatusPort : TaskStatusPort;
        perform action executeTask {
            in task : TaskKind;
            in targetLocation : ISQ::LengthValue[3];
            out status : ScalarValues::String;
            out progress : ScalarValues::Real;
            first start;
            then action performTaskSteps;
            then done;
        }
    }

    part def QuadrupedRobot {
        attribute currentMode : RobotModeKind;
        attribute batteryLevel : ScalarValues::Real;
        attribute isStable : ScalarValues::Boolean;

        part frontLeftLeg : Leg { :>> legPosition = LegPositionKind::frontLeft; }
        part frontRightLeg : Leg { :>> legPosition = LegPositionKind::frontRight; }
        part rearLeftLeg : Leg { :>> legPosition = LegPositionKind::rearLeft; }
        part rearRightLeg : Leg { :>> legPosition = LegPositionKind::rearRight; }
        part imu : IMUSensor;
        part lidar : LidarSensor;
        part battery : Battery;
        part motionPlanner : MotionPlanner;
        part balanceController : BalanceController;
        part taskExecutor : TaskExecutor;

        port navCommandPort : NavCommandPort;
        port taskCommandPort : TaskCommandPort;
        port statusPort : StatusReportPort;
        port taskStatusPort : TaskStatusPort;

        connect imu.dataPort to balanceController.imuDataPort;
        connect lidar.dataPort to motionPlanner.sensorDataPort;
        connect balanceController.correctionOutputPort to motionPlanner.correctionInputPort;
        connect navCommandPort to motionPlanner.navCommandPort;
        connect taskCommandPort to taskExecutor.taskCommandPort;
        connect taskExecutor.taskStatusPort to taskStatusPort;

        connect motionPlanner.frontLeftHipOut to frontLeftLeg.hipJoint.commandPort;
        connect motionPlanner.frontLeftKneeOut to frontLeftLeg.kneeJoint.commandPort;
        connect motionPlanner.frontLeftAnkleOut to frontLeftLeg.ankleJoint.commandPort;
        connect motionPlanner.frontRightHipOut to frontRightLeg.hipJoint.commandPort;
        connect motionPlanner.frontRightKneeOut to frontRightLeg.kneeJoint.commandPort;
        connect motionPlanner.frontRightAnkleOut to frontRightLeg.ankleJoint.commandPort;
        connect motionPlanner.rearLeftHipOut to rearLeftLeg.hipJoint.commandPort;
        connect motionPlanner.rearLeftKneeOut to rearLeftLeg.kneeJoint.commandPort;
        connect motionPlanner.rearLeftAnkleOut to rearLeftLeg.ankleJoint.commandPort;
        connect motionPlanner.rearRightHipOut to rearRightLeg.hipJoint.commandPort;
        connect motionPlanner.rearRightKneeOut to rearRightLeg.kneeJoint.commandPort;
        connect motionPlanner.rearRightAnkleOut to rearRightLeg.ankleJoint.commandPort;

        bind currentMode = statusPort.mode;
        bind battery.statusPort.charge = statusPort.batteryLevel;
        bind isStable = statusPort.stability;

        attribute def SigNavigate;
        attribute def SigTask;
        attribute def SigRecover;
        attribute def SigComplete;
        attribute def SigStabilized;

        state robotStates {
            entry; then idle;
            state idle;
            accept SigNavigate then navigating;
            state navigating;
            accept SigTask then executingTask;
            accept SigRecover then recovering;
            state executingTask;
            accept SigComplete then idle;
            state recovering;
            accept SigStabilized then idle;
        }
    }

    part def ControlStation {
        port navCommandPort : ~NavCommandPort;
        port taskCommandPort : ~TaskCommandPort;
        port statusPort : ~StatusReportPort;
        port taskStatusPort : ~TaskStatusPort;
    }

    part def QuadrupedSystem {
        part robot : QuadrupedRobot;
        part controlStation : ControlStation;
        connect controlStation.navCommandPort to robot.navCommandPort;
        connect controlStation.taskCommandPort to robot.taskCommandPort;
        connect robot.statusPort to controlStation.statusPort;
        connect robot.taskStatusPort to controlStation.taskStatusPort;
    }
}
