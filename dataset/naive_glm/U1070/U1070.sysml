package HDHyundaiRobotCell {
    import ScalarValues::*;

    // ---- Units ----
    unit mm;
    unit kg;
    unit N;
    unit V;
    unit deg;
    unit mps;

    // ---- Value Types ----
    value type Length_mm > Real {
        unit mm;
    }
    value type Mass_kg > Real {
        unit kg;
    }
    value type Force_N > Real {
        unit N;
    }
    value type Voltage_V > Real {
        unit V;
    }
    value type Angle_deg > Real {
        unit deg;
    }
    value type Speed_mps > Real {
        unit mps;
    }
    value type Repeatability_mm > Real {
        unit mm;
    }

    // ---- Item Definitions ----
    item def Power {
        attribute voltage : Voltage_V;
        attribute current : Real;
    }

    item def Workpiece {
        attribute mass : Mass_kg;
        attribute width : Length_mm;
        attribute detected : Boolean;
    }

    item def VisionData {
        attribute workpiecePosition : Length_mm[3];
        attribute workpieceOrientation : Angle_deg[3];
        attribute confidence : Real;
    }

    item def MotionCommand {
        attribute targetPosition : Length_mm[6];
        attribute speed : Speed_mps;
    }

    item def GripCommand {
        attribute targetForce : Force_N;
        attribute targetOpening : Length_mm;
    }

    item def ArmStatus {
        attribute speed : Speed_mps;
        attribute position : Length_mm[3];
    }

    item def SafetyStatus {
        attribute speed : Speed_mps;
        attribute position : Length_mm[3];
        attribute emergencyStop : Boolean;
        attribute collisionDetected : Boolean;
    }

    // ---- Port Definitions ----
    port def PowerPort {
        out item power : Power;
    }

    port def VisionDataPort {
        out item visionData : VisionData;
    }

    port def MotionCommandPort {
        out item motionCommand : MotionCommand;
    }

    port def GripCommandPort {
        out item gripCommand : GripCommand;
    }

    port def ArmStatusPort {
        out item armStatus : ArmStatus;
    }

    port def SafetyStatusPort {
        out item safetyStatus : SafetyStatus;
    }

    // ---- Part Definitions ----
    part def Joint {
        attribute axisNumber : Integer;
        attribute currentAngle : Angle_deg;
        attribute maxAngle : Angle_deg;
        attribute maxTorque : Real;
    }

    part def ManipulatorArm {
        attribute reach : Length_mm = 1700;
        attribute maxPayload : Mass_kg = 25;
        attribute repeatability : Repeatability_mm = 0.03;
        attribute numAxes : Integer = 6;

        port powerIn : ~PowerPort;
        port motionCommandIn : ~MotionCommandPort;
        port armStatusOut : ArmStatusPort;

        part joints : Joint[6];

        action def MoveTo {
            in target : Length_mm[6];
            in speed : Speed_mps;
        }

        action def ReturnHome;

        action def StopMotion;
    }

    part def Gripper {
        attribute maxOpening : Length_mm = 180;
        attribute maxGripForce : Force_N = 600;
        attribute currentOpening : Length_mm;
        attribute currentForce : Force_N;

        port powerIn : ~PowerPort;
        port gripCommandIn : ~GripCommandPort;

        action def Grasp {
            in targetForce : Force_N;
            in opening : Length_mm;
        }

        action def Release;
    }

    part def VisionSensor {
        attribute resolution : Real = 12.0;
        attribute scanRate : Real = 60.0;
        attribute fieldOfView : Angle_deg;

        port powerIn : ~PowerPort;
        port visionDataOut : VisionDataPort;

        action def ScanWorkspace {
            out data : VisionData;
        }
    }

    part def RobotController {
        attribute processingSpeed : Real = 2.0;
        attribute trajectoryCacheSize : Integer;

        port powerIn : ~PowerPort;
        port visionDataIn : ~VisionDataPort;
        port motionCommandOut : MotionCommandPort;
        port gripCommandOut : GripCommandPort;
        port safetyStatusIn : ~SafetyStatusPort;

        action def ProcessVisionData {
            in visionData : VisionData;
            out workpiecePosition : Length_mm[3];
            out workpieceOrientation : Angle_deg[3];
        }

        action def PlanTrajectory {
            in startPosition : Length_mm[6];
            in targetPosition : Length_mm[6];
            out motionCommand : MotionCommand;
        }

        action def PlanGrip {
            in workpieceWidth : Length_mm;
            out gripCommand : GripCommand;
        }

        action def SendMotionCommand {
            in motionCommand : MotionCommand;
        }

        action def SendGripCommand {
            in gripCommand : GripCommand;
        }
    }

    part def SafetyController {
        attribute safetyZoneRadius : Length_mm = 1500;
        attribute maxSpeed : Speed_mps = 2.0;
        attribute emergencyStopActive : Boolean = false;

        port powerIn : ~PowerPort;
        port armStatusIn : ~ArmStatusPort;
        port safetyStatusOut : SafetyStatusPort;

        action def Monitor {
            in armStatus : ArmStatus;
            out status : SafetyStatus;
        }

        action def DetectCollision {
            in position : Length_mm[3];
            out collisionDetected : Boolean;
        }

        action def TriggerEmergencyStop {
            out status : SafetyStatus;
        }

        action def EvaluateSafetyZone {
            in position : Length_mm[3];
            in speed : Speed_mps;
            out withinZone : Boolean;
        }
    }

    part def PowerDistribution {
        attribute inputVoltage : Voltage_V = 400;
        attribute outputVoltageArm : Voltage_V = 230;
        attribute outputVoltageSensors : Voltage_V = 24;
        attribute outputVoltageControllers : Voltage_V = 24;

        port industrialSupply : ~PowerPort;
        port armPower : PowerPort;
        port gripperPower : PowerPort;
        port visionPower : PowerPort;
        port controllerPower : PowerPort;
        port safetyControllerPower : PowerPort;

        action def DistributePower {
            in input : Power;
            out armOutput : Power;
            out gripperOutput : Power;
            out sensorOutput : Power;
            out controllerOutput : Power;
            out safetyControllerOutput : Power;
        }

        action def MonitorPowerQuality {
            in input : Power;
            out qualityOK : Boolean;
        }
    }

    // ---- State Machine Definition ----
    state def OperationalStates {
        state idle {
            entry action logIdle;
        }
        state initializing {
            entry action startInitialization;
            action calibrateJoints;
            action verifySafetyController;
        }
        state ready {
            entry action logReady;
        }
        state operating {
            entry action startOperation;
        }
        state paused {
            entry action logPaused;
        }
        state error {
            entry action logError;
            action diagnoseFault;
        }
        state emergencyStop {
            entry action haltAllMotion;
            action logEmergency;
        }

        transition from initial to idle;
        transition from idle to initializing;
        transition from initializing to ready;
        transition from ready to operating;
        transition from operating to paused;
        transition from paused to operating;
        transition from operating to ready;
        transition from operating to error;
        transition from error to idle;
        transition from operating to emergencyStop;
        transition from paused to emergencyStop;
        transition from ready to emergencyStop;
        transition from idle to emergencyStop;
        transition from emergencyStop to idle;
    }

    // ---- Operational Cycle Action ----
    action def OperationalCycle {
        in workpiece : Workpiece;

        action safetyCheck {
            out safetyOK : Boolean;
        }
        action locateWorkpiece {
            in safetyOK : Boolean;
            out visionData : VisionData;
        }
        action planPickTrajectory {
            in visionData : VisionData;
            out motionCommand : MotionCommand;
        }
        action moveToPickup {
            in motionCommand : MotionCommand;
            out arrivalConfirmed : Boolean;
        }
        action graspWorkpiece {
            in arrivalConfirmed : Boolean;
            out gripConfirmed : Boolean;
        }
        action planPlaceTrajectory {
            in gripConfirmed : Boolean;
            out placeMotionCommand : MotionCommand;
        }
        action moveToDestination {
            in placeMotionCommand : MotionCommand;
            out destinationReached : Boolean;
        }
        action releaseWorkpiece {
            in destinationReached : Boolean;
            out releaseConfirmed : Boolean;
        }
        action returnHome {
            in releaseConfirmed : Boolean;
            out homeReached : Boolean;
        }

        succession from safetyCheck to locateWorkpiece;
        succession from locateWorkpiece to planPickTrajectory;
        succession from planPickTrajectory to moveToPickup;
        succession from moveToPickup to graspWorkpiece;
        succession from graspWorkpiece to planPlaceTrajectory;
        succession from planPlaceTrajectory to moveToDestination;
        succession from moveToDestination to releaseWorkpiece;
        succession from releaseWorkpiece to returnHome;
    }

    // ---- Robot Cell Composition ----
    part def RobotCell {
        attribute manufacturer : String = "HD Hyundai";
        attribute cellId : String;
        attribute safetyZoneRadius : Length_mm = 1500;

        part arm : ManipulatorArm;
        part gripper : Gripper;
        part visionSensor : VisionSensor;
        part robotController : RobotController;
        part safetyController : SafetyController;
        part powerDistribution : PowerDistribution;

        // Power connections
        connection supplyToPowerDist connect powerDistribution.industrialSupply to powerDistribution.industrialSupply;
        connection powerToArm connect powerDistribution.armPower to arm.powerIn;
        connection powerToGripper connect powerDistribution.gripperPower to gripper.powerIn;
        connection powerToVision connect powerDistribution.visionPower to visionSensor.powerIn;
        connection powerToController connect powerDistribution.controllerPower to robotController.powerIn;
        connection powerToSafetyController connect powerDistribution.safetyControllerPower to safetyController.powerIn;

        // Data connections
        connection visionDataToController connect visionSensor.visionDataOut to robotController.visionDataIn;
        connection motionCommandToArm connect robotController.motionCommandOut to arm.motionCommandIn;
        connection gripCommandToGripper connect robotController.gripCommandOut to gripper.gripCommandIn;
        connection armStatusToSafetyController connect arm.armStatusOut to safetyController.armStatusIn;
        connection safetyStatusToController connect safetyController.safetyStatusOut to robotController.safetyStatusIn;

        exhibit operationalStates : OperationalStates;
        perform operationalCycle : OperationalCycle;
    }

    // ---- Requirements ----
    requirement def ManipulatorArmRequirement {
        subject arm : ManipulatorArm;
        require arm.reach == 1700 [mm];
        require arm.maxPayload == 25 [kg];
        require arm.repeatability <= 0.03 [mm];
        require arm.numAxes == 6;
    }

    requirement def GripperRequirement {
        subject gripper : Gripper;
        require gripper.maxOpening == 180 [mm];
        require gripper.maxGripForce == 600 [N];
    }

    requirement def VisionSensorRequirement {
        subject visionSensor : VisionSensor;
        require visionSensor.resolution >= 12.0;
        require visionSensor.scanRate >= 60.0;
    }

    requirement def SafetyControllerRequirement {
        subject safetyController : SafetyController;
        require safetyController.safetyZoneRadius == 1500 [mm];
        require safetyController.maxSpeed <= 2.0 [mps];
    }

    requirement def PowerDistributionRequirement {
        subject powerDistribution : PowerDistribution;
        require powerDistribution.inputVoltage == 400 [V];
    }

    requirement def RobotCellSystemRequirement {
        subject robotCell : RobotCell;
        require robotCell.arm.reach == 1700 [mm];
        require robotCell.arm.maxPayload == 25 [kg];
        require robotCell.arm.repeatability <= 0.03 [mm];
        require robotCell.gripper.maxOpening == 180 [mm];
        require robotCell.gripper.maxGripForce == 600 [N];
        require robotCell.safetyController.safetyZoneRadius == 1500 [mm];
        require robotCell.powerDistribution.inputVoltage == 400 [V];
        require robotCell.manufacturer == "HD Hyundai";
    }

    requirement def OperationalCycleRequirement {
        subject operationalCycle : OperationalCycle;
        require operationalCycle.safetyCheck.safetyOK == true;
        require operationalCycle.locateWorkpiece.visionData.confidence >= 0.95;
    }
}
