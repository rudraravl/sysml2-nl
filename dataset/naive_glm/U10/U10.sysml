package RoboticWorkCell {
    import SI::N;
    import SI::m;
    import SI::V;
    import SI::Hz;
    import SI::kg;

    attribute def LengthUnit :> m;
    attribute def ForceUnit :> N;
    attribute def VoltageUnit :> V;
    attribute def FrequencyUnit :> Hz;
    attribute def MassUnit :> kg;

    item def Workpiece {
        attribute mass : MassUnit;
        attribute processed : Boolean;
    }

    item def Image {
        attribute resolution : Integer;
        attribute frameRate : FrequencyUnit;
    }

    item def ContactForce {
        attribute magnitude : ForceUnit;
    }

    item def Trajectory {
        attribute waypoints : Integer;
        attribute duration : TimeValue;
    }

    port def PowerPort {
        attribute voltage : VoltageUnit;
        out item electricalEnergy;
    }

    port def CommandPort {
        in item command : String;
        out item status : String;
    }

    port def SensorDataPort {
        out item image : Image;
        out item contact : ContactForce;
    }

    port def WorkpiecePort {
        out item workpiece : Workpiece;
        in item workpiece : Workpiece;
    }

    part def PowerSupply {
        attribute nominalVoltage : VoltageUnit = 24 [V];
        attribute maxCurrent : CurrentValue;
        port powerOut : PowerPort;
    }

    part def Joint {
        attribute name : String;
        attribute maxTorque : TorqueValue;
        attribute position : AngleValue;
        port powerIn : PowerPort;
        action def Actuate {
            in targetPosition : AngleValue;
            out actualPosition : AngleValue;
        }
        perform actuate : Actuate;
    }

    part def Gripper {
        attribute maxForce : ForceUnit = 150 [N];
        attribute gripForce : ForceUnit;
        port powerIn : PowerPort;
        port workpiecePort : WorkpiecePort;
        action def Grip {
            in workpiece : Workpiece;
            out success : Boolean;
        }
        action def Release {
            out workpiece : Workpiece;
        }
        perform grip : Grip;
        perform release : Release;
    }

    part def VisionSensor {
        attribute resolution : Integer = 4096;
        attribute frameRate : FrequencyUnit = 60 [Hz];
        port dataOut : SensorDataPort;
        action def Capture {
            out image : Image;
        }
        perform capture : Capture;
    }

    part def ForceSensor {
        attribute sensitivity : ForceUnit = 0.1 [N];
        port dataOut : SensorDataPort;
        action def DetectContact {
            out contact : ContactForce;
        }
        perform detectContact : DetectContact;
    }

    part def Controller {
        attribute clockFrequency : FrequencyUnit = 1000 [Hz];
        port commandPort : CommandPort;
        port sensorDataIn : SensorDataPort;
        action def PlanTrajectory {
            in image : Image;
            in contact : ContactForce;
            out trajectory : Trajectory;
        }
        action def ExecuteTrajectory {
            in trajectory : Trajectory;
            out done : Boolean;
        }
        perform planTrajectory : PlanTrajectory;
        perform executeTrajectory : ExecuteTrajectory;
    }

    part def RobotArm {
        attribute reach : LengthUnit = 1.2 [m];
        part base : Joint { attribute name = "base"; }
        part shoulder : Joint { attribute name = "shoulder"; }
        part elbow : Joint { attribute name = "elbow"; }
        part wrist : Joint { attribute name = "wrist"; }
        part gripper : Gripper;
        port powerIn : PowerPort;
        port workpiecePort : WorkpiecePort;
        connection powerBase : PowerPort connect powerIn to base.powerIn;
        connection powerShoulder : PowerPort connect base.powerIn to shoulder.powerIn;
        connection powerElbow : PowerPort connect shoulder.powerIn to elbow.powerIn;
        connection powerWrist : PowerPort connect elbow.powerIn to wrist.powerIn;
        connection powerGripper : PowerPort connect wrist.powerIn to gripper.powerIn;
        connection workpieceFlow : WorkpiecePort connect gripper.workpiecePort to workpiecePort;
    }

    part def IndustrialRobot {
        part arm : RobotArm;
        part visionSensor : VisionSensor;
        part forceSensor : ForceSensor;
        part controller : Controller;
        part powerSupply : PowerSupply;
        port commandPort : CommandPort;
        port workpiecePort : WorkpiecePort;
        connection powerToArm : PowerPort connect powerSupply.powerOut to arm.powerIn;
        connection visionToController : SensorDataPort connect visionSensor.dataOut to controller.sensorDataIn;
        connection forceToController : SensorDataPort connect forceSensor.dataOut to controller.sensorDataIn;
        connection commandToController : CommandPort connect commandPort to controller.commandPort;
        connection workpieceToArm : WorkpiecePort connect workpiecePort to arm.workpiecePort;

        state def RobotStateMachine {
            state idle;
            state perceiving;
            state planning;
            state movingToTarget;
            state gripping;
            state processing;
            state movingToRelease;
            state releasing;
            state error;

            transition idle_to_perceiving
                first idle
                if commandPort.command.command == "start"
                then perceiving;

            transition perceiving_to_planning
                first perceiving
                if controller.planTrajectory.image != null
                then planning;

            transition planning_to_movingToTarget
                first planning
                if controller.planTrajectory.trajectory != null
                then movingToTarget;

            transition movingToTarget_to_gripping
                first movingToTarget
                if controller.executeTrajectory.done == true
                then gripping;

            transition gripping_to_processing
                first gripping
                if arm.gripper.grip.success == true
                then processing;

            transition gripping_to_error
                first gripping
                if arm.gripper.grip.success == false
                then error;

            transition processing_to_movingToRelease
                first processing
                if arm.gripper.workpiecePort.workpiece.processed == true
                then movingToRelease;

            transition movingToRelease_to_releasing
                first movingToRelease
                if controller.executeTrajectory.done == true
                then releasing;

            transition releasing_to_idle
                first releasing
                if arm.gripper.release.workpiece != null
                then idle;

            transition error_to_idle
                first error
                if commandPort.command.command == "reset"
                then idle;

            transition anyState_to_error
                first {perceiving, planning, movingToTarget, gripping, processing, movingToRelease, releasing}
                if forceSensor.detectContact.contact.magnitude > 150 [N]
                then error;
        }

        perform robotStateMachine : RobotStateMachine;
    }

    part def WorkCell {
        part robot : IndustrialRobot;
        part conveyorIn {
            port workpieceOut : WorkpiecePort;
        }
        part conveyorOut {
            port workpieceIn : WorkpiecePort;
        }
        part operatorPanel {
            port commandOut : CommandPort;
        }
        connection workpieceInput : WorkpiecePort connect conveyorIn.workpieceOut to robot.workpiecePort;
        connection workpieceOutput : WorkpiecePort connect robot.workpiecePort to conveyorOut.workpieceIn;
        connection commandFlow : CommandPort connect operatorPanel.commandOut to robot.commandPort;
    }

    requirement def RobotReachRequirement {
        subject robot : IndustrialRobot;
        require robot.arm.reach >= 1.2 [m];
    }

    requirement def GripperForceRequirement {
        subject gripper : Gripper;
        require gripper.maxForce >= 150 [N];
    }

    requirement def PowerSupplyRequirement {
        subject powerSupply : PowerSupply;
        require powerSupply.nominalVoltage == 24 [V];
    }

    requirement def ControllerFrequencyRequirement {
        subject controller : Controller;
        require controller.clockFrequency >= 1000 [Hz];
    }

    requirement def TaskCompletionRequirement {
        subject robot : IndustrialRobot;
        require robot.robotStateMachine.idle.isReached after robot.robotStateMachine.releasing;
    }

    requirement def ErrorHandlingRequirement {
        subject robot : IndustrialRobot;
        require robot.robotStateMachine.error.isReached when robot.forceSensor.detectContact.contact.magnitude > 150 [N];
    }

    part workCellInstance : WorkCell {
        part robotInstance : IndustrialRobot {
            part armInstance : RobotArm {
                attribute reach = 1.2 [m];
                part baseJoint : Joint { attribute name = "base"; }
                part shoulderJoint : Joint { attribute name = "shoulder"; }
                part elbowJoint : Joint { attribute name = "elbow"; }
                part wristJoint : Joint { attribute name = "wrist"; }
                part gripperInstance : Gripper {
                    attribute maxForce = 150 [N];
                }
            }
            part visionSensorInstance : VisionSensor {
                attribute resolution = 4096;
                attribute frameRate = 60 [Hz];
            }
            part forceSensorInstance : ForceSensor {
                attribute sensitivity = 0.1 [N];
            }
            part controllerInstance : Controller {
                attribute clockFrequency = 1000 [Hz];
            }
            part powerSupplyInstance : PowerSupply {
                attribute nominalVoltage = 24 [V];
            }
        }
        part conveyorInInstance {
            port workpieceOut : WorkpiecePort;
        }
        part conveyorOutInstance {
            port workpieceIn : WorkpiecePort;
        }
        part operatorPanelInstance {
            port commandOut : CommandPort;
        }
        satisfy RobotReachRequirement by robotInstance;
        satisfy GripperForceRequirement by robotInstance.armInstance.gripperInstance;
        satisfy PowerSupplyRequirement by robotInstance.powerSupplyInstance;
        satisfy ControllerFrequencyRequirement by robotInstance.controllerInstance;
        satisfy TaskCompletionRequirement by robotInstance;
        satisfy ErrorHandlingRequirement by robotInstance;
    }
}
