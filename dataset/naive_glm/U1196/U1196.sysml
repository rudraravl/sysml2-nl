package MobileManipulatorRobot {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value def Speed :> Real { unit 'm/s'; }
    value def Distance :> Real { unit 'm'; }
    value def Mass :> Real { unit 'kg'; }
    value def Force :> Real { unit 'N'; }
    value def Angle :> Real { unit 'deg'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real {> Real { unit 'A'; }
    value def Energy :> Real { unit 'J'; }
    value def Power :> Real { unit 'W'; }
    value def TimeDuration :> Real { unit 's'; }

    // ---- Items ----
    item def Workpiece {
        attribute weight : Mass;
        attribute detected : Boolean;
    }
    item def Obstacle;
    item def ImageData;
    item def PathPlan;
    item def TaskCommand {
        attribute targetId : String;
        attribute dropOffLocation : String;
    }
    item def GraspResult {
        attribute success : Boolean;
    }
    item def SafetyStatus {
        attribute safe : Boolean;
        attribute nearestObstacleDistance : Distance;
    }

    // ---- Port definitions ----
    port def PowerPort {
        out voltage : Voltage;
        out current : Current;
    }
    port def CommandPort {
        in command : String;
        out status : String;
    }
    port def DataPort {
        out data : Anything;
    }
    port def ImagePort {
        out image : ImageData;
    }
    port def SafetyPort {
        out alert : SafetyStatus;
    }

    // ---- Part definitions ----
    part def MobileBase {
        attribute maxSpeed : Speed = 1.5 [m/s];
        port cmdIn : CommandPort;
        port powerIn : PowerPort;
        port safetyIn : SafetyPort;
        attribute currentSpeed : Speed;
        attribute position : String;

        action def MoveTo {
            in target : String;
            in path : PathPlan;
        }
        action def Stop {
            attribute reason : String;
        }
    }

    part def ManipulatorArm {
        attribute reach : Distance = 1.2 [m];
        attribute maxPayload : Mass = 15 [kg];
        attribute jointCount : Integer = 6;
        port cmdIn : CommandPort;
        port powerIn : PowerPort;
        attribute jointAngles : Array[6] of Angle;

        action def MoveJoints {
            in targetAngles : Array[6] of Angle;
        }
        action def HoldPosition;
    }

    part def Gripper {
        attribute maxForce : Force = 80 [N];
        attribute currentForce : Force;
        port cmdIn : CommandPort;
        port powerIn : PowerPort;
        attribute holding : Boolean;

        action def Grasp {
            in force : Force;
            out result : GraspResult;
        }
        action def Release;
    }

    part def MasterController {
        port cmdIn : CommandPort;
        port visionIn : ImagePort;
        port safetyIn : SafetyPort;
        port baseCmdOut : CommandPort;
        port armCmdOut : CommandPort;
        port gripperCmdOut : CommandPort;
        port powerIn : PowerPort;

        action def ProcessTask {
            in task : TaskCommand;
        }
        action def PlanPath {
            in start : String;
            in goal : String;
            out plan : PathPlan;
        }
        action def DecideGraspForce {
            in attempt : Integer;
            out force : Force;
        }
    }

    part def VisionSystem {
        attribute resolution : String = "1920x1080";
        attribute frameRate : Integer = 30;
        port imageOut : ImagePort;
        port powerIn : PowerPort;
        port cmdIn : CommandPort;

        action def ScanEnvironment {
            out image : ImageData;
        }
        action def DetectObject {
            in image : ImageData;
            out detected : Boolean;
            out location : String;
        }
    }

    part def Battery {
        attribute capacity : Energy = 5000000 [J];
        attribute currentVoltage : Voltage = 48 [V];
        attribute chargeLevel : Real = 1.0;
        port powerOut : PowerPort;

        action def Discharge {
            out power : Power;
        }
        action def Recharge;
    }

    part def SafetyController {
        attribute safetyZoneRadius : Distance = 2.0 [m];
        port sensorIn : DataPort;
        port alertOut : SafetyPort;
        port powerIn : PowerPort;
        port baseEmergencyOut : CommandPort;
        port armEmergencyOut : CommandPort;
        attribute monitoring : Boolean = true;

        action def MonitorSurroundings {
            out status : SafetyStatus;
        }
        action def TriggerEmergencyStop {
            attribute reason : String;
        }
    }

    // ---- Robot assembly ----
    part def MobileManipulator {
        part base : MobileBase;
        part arm : ManipulatorArm;
        part gripper : Gripper;
        part controller : MasterController;
        part vision : VisionSystem;
        part battery : Battery;
        part safety : SafetyController;

        // Power distribution
        connection powerToController : PowerPort connect battery.powerOut to controller.powerIn;
        connection powerToBase : PowerPort connect battery.powerOut to base.powerIn;
        connection powerToArm : PowerPort connect battery.powerOut to arm.powerIn;
        connection powerToGripper : PowerPort connect battery.powerOut to gripper.powerIn;
        connection powerToVision : PowerPort connect battery.powerOut to vision.powerIn;
        connection powerToSafety : PowerPort connect battery.powerOut to safety.powerIn;

        // Command distribution
        connection controllerToBase : CommandPort connect controller.baseCmdOut to base.cmdIn;
        connection controllerToArm : CommandPort connect controller.armCmdOut to arm.cmdIn;
        connection controllerToGripper : CommandPort connect controller.gripperCmdOut to gripper.cmdIn;
        connection controllerToVision : CommandPort connect controller.cmdIn to vision.cmdIn;

        // Vision data
        connection visionToController : ImagePort connect vision.imageOut to controller.visionIn;

        // Safety
        connection safetyToController : SafetyPort connect safety.alertOut to controller.safetyIn;
        connection safetyToBase : SafetyPort connect safety.alertOut to base.safetyIn;
        connection safetyEmergencyBase : CommandPort connect safety.baseEmergencyOut to base.cmdIn;
        connection safetyEmergencyArm : CommandPort connect safety.armEmergencyOut to arm.cmdIn;

        // Sensor data to safety controller
        connection visionToSafety : DataPort connect vision.imageOut to safety.sensorIn;

        // ---- Operational state machine ----
        state def OperationalMode {
            state standby;
            state autonomous;
            state manual;
            state fault;

            transition standby_to_autonomous first standby if (taskAssigned) then autonomous;
            transition autonomous_to_standby first autonomous if (taskCompleted) then standby;
            transition standby_to_manual first standby if (manualOverride) then manual;
            transition manual_to_standby first manual if (manualReleased) then standby;
            transition any_to_fault first {standby, autonomous, manual} if (errorDetected) then fault;
            transition fault_to_standby first fault if (errorCleared) then standby;
        }

        // ---- Task execution state machine ----
        state def TaskExecution {
            state idle;
            state scanning;
            state pathPlanning;
            state moving;
            state grasping;
            state transportPlanning;
            state transporting;
            state releasing;
            state retryGrasp;

            transition idle_to_scanning first idle if (taskAssigned) then scanning;
            transition scanning_to_pathPlanning first scanning if (objectDetected) then pathPlanning;
            transition pathPlanning_to_moving first pathPlanning if (pathReady) then moving;
            transition moving_to_grasping first moving if (inPosition) then grasping;
            transition grasping_to_transportPlanning first grasping if (graspSucceeded) then transportPlanning;
            transition grasping_to_retryGrasp first grasping if (graspFailed and attemptCount < 3) then retryGrasp;
            transition retryGrasp_to_grasping first retryGrasp if (forceIncreased) then grasping;
            transition grasping_to_fault first grasping if (graspFailed and attemptCount >= 3) then idle;
            transition transportPlanning_to_transporting first transportPlanning if (transportPathReady) then transporting;
            transition transporting_to_releasing first transporting if (atDropOff) then releasing;
            transition releasing_to_idle first releasing if (objectReleased) then idle;
        }

        attribute taskAssigned : Boolean;
        attribute taskCompleted : Boolean;
        attribute manualOverride : Boolean;
        attribute manualReleased : Boolean;
        attribute errorDetected : Boolean;
        attribute errorCleared : Boolean;
        attribute objectDetected : Boolean;
        attribute pathReady : Boolean;
        attribute inPosition : Boolean;
        attribute graspSucceeded : Boolean;
        attribute graspFailed : Boolean;
        attribute attemptCount : Integer;
        attribute forceIncreased : Boolean;
        attribute transportPathReady : Boolean;
        attribute atDropOff : Boolean;
        attribute objectReleased : Boolean;
    }

    // ---- Requirements ----
    requirement def MobilityRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The robot shall navigate at speeds up to 1.5 m/s.">>
            robot.base.maxSpeed <= 1.5 [m/s];
        }
    }

    requirement def ManipulationRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The manipulator arm shall have a reach of 1.2 m and lift up to 15 kg.">>
            robot.arm.reach >= 1.2 [m] and robot.arm.maxPayload >= 15 [kg];
        }
    }

    requirement def GripperRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The gripper shall grasp and release objects with controlled force.">>
            robot.gripper.maxForce <= 80 [N];
        }
    }

    requirement def SafetyRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The safety controller shall monitor a 2-meter zone and trigger emergency stop upon intrusion.">>
            robot.safety.safetyZoneRadius >= 2.0 [m];
        }
    }

    requirement def AutonomyRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The robot shall perform pick-and-place tasks autonomously, including retry with increased force on grasp failure.">>
            robot.controller.ProcessTask.isInvoked;
        }
    }

    requirement def PowerRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The battery shall power all subsystems.">>
            robot.battery.capacity >= 5000000 [J];
        }
    }

    requirement def VisionRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The vision system shall detect and locate objects in real-time.">>
            robot.vision.frameRate >= 30;
        }
    }

    requirement def ModeRequirement {
        subject robot : MobileManipulator;
        objective {
            doc << "The robot shall support standby, autonomous, manual, and fault modes.">>
            robot.OperationalMode.states.includesAll({standby, autonomous, manual, fault});
        }
    }
}
