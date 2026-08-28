package AutomatedPickAndPlaceWorkCell {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def Position {
            attribute x : LengthValue;
            attribute y : LengthValue;
            attribute z : LengthValue;
        }
        attribute def Orientation {
            attribute roll : Real;
            attribute pitch : Real;
            attribute yaw : Real;
        }
        attribute def Pose {
            attribute position : Position;
            attribute orientation : Orientation;
        }
        attribute def Trajectory {
            attribute waypoints : Pose[0..*] ordered;
        }
        attribute def SensorData {
            attribute workpiecePose : Pose;
            attribute obstacles : Pose[0..*];
        }
        attribute def TaskCommand {
            attribute targetPose : Pose;
            attribute workpieceId : String;
        }
        attribute def MotionCommand {
            attribute trajectory : Trajectory;
        }
        attribute def MotionStatus {
            attribute isComplete : Boolean;
            attribute currentPose : Pose;
        }
        attribute def GripperCommand {
            attribute force : ForceValue;
            attribute isCloseCommand : Boolean;
        }
        attribute def GripperStatus {
            attribute isGripped : Boolean;
            attribute appliedForce : ForceValue;
        }
        attribute def PowerSpec {
            attribute voltage : ElectricPotentialValue;
            attribute current : ElectricCurrentValue;
        }

        attribute def StartTask;
        attribute def SensorDataReady;
        attribute def TrajectoryPlanned;
        attribute def MotionComplete;
        attribute def GripSuccess;
        attribute def GripFailure;
        attribute def ReleaseComplete;
        attribute def ErrorSignal;
        attribute def ResetSignal;

        item def Workpiece;

        part def ForceSensor {
            port forceOut {
                out force : ForceValue;
            }
            attribute measuredForce : ForceValue := 0.0;
        }

        part def Gripper {
            attribute isTwoFingered : Boolean := true;
            attribute maxSafeForce : ForceValue := 50.0;
            part forceSensor : ForceSensor;
            port commandPort {
                in command : GripperCommand;
            }
            port statusPort {
                out status : GripperStatus;
            }
            port workpiecePort {
                in workpieceIn : Workpiece;
                out workpieceOut : Workpiece;
            }
            attribute isClosed : Boolean := false;
            attribute currentForce : ForceValue := 0.0;

            action grip {
                in workpiece : Workpiece;
                in commandedForce : ForceValue;
                assign isClosed := true;
                assign currentForce := commandedForce;
                assign forceSensor.measuredForce := commandedForce;
            }
            action release {
                in workpiece : Workpiece;
                assign isClosed := false;
                assign currentForce := 0.0;
                assign forceSensor.measuredForce := 0.0;
            }
        }

        part def SixAxisRoboticArm {
            attribute axisCount : Integer := 6;
            attribute jointAngles : Real[6];
            attribute currentPose : Pose;
            part gripper : Gripper;
            port motionCommandPort {
                in command : MotionCommand;
            }
            port motionStatusPort {
                out status : MotionStatus;
            }
            port powerPort {
                in power : PowerSpec;
            }
            action executeMotion {
                in trajectory : Trajectory;
            }
        }

        part def VisionSensor3D {
            port dataPort {
                out data : SensorData;
            }
            port powerPort {
                in power : PowerSpec;
            }
            action scan {
                out data : SensorData;
            }
        }

        part def MotionController {
            port taskCommandPort {
                in command : TaskCommand;
            }
            port sensorDataPort {
                in data : SensorData;
            }
            port trajectoryPort {
                out trajectory : Trajectory;
            }
            port motionCommandPort {
                out command : MotionCommand;
            }
            port motionStatusPort {
                in status : MotionStatus;
            }
            port gripperCommandPort {
                out command : GripperCommand;
            }
            port gripperStatusPort {
                in status : GripperStatus;
            }
            port powerPort {
                in power : PowerSpec;
            }
            action planTrajectory {
                in targetPose : Pose;
                in sensorData : SensorData;
                out trajectory : Trajectory;
            }
        }

        part def Conveyor {
            attribute direction : String;
            port workpiecePort {
                in workpieceIn : Workpiece;
                out workpieceOut : Workpiece;
            }
            port powerPort {
                in power : PowerSpec;
            }
            attribute isRunning : Boolean := false;
            action advance {
                assign isRunning := true;
            }
            action stop {
                assign isRunning := false;
            }
        }

        part def PowerSupply {
            port powerPort {
                out power : PowerSpec;
            }
            attribute ratedVoltage : ElectricPotentialValue := 24.0;
            attribute ratedCurrent : ElectricCurrentValue := 20.0;
            attribute isPowered : Boolean := false;
            action applyPower {
                assign isPowered := true;
            }
        }

        part def WorkCell {
            part controller : MotionController;
            part arm : SixAxisRoboticArm;
            part visionSensor : VisionSensor3D;
            part inputConveyor : Conveyor {
                attribute direction := "input";
            }
            part outputConveyor : Conveyor {
                attribute direction := "output";
            }
            part powerSupply : PowerSupply;

            flow sensorDataFlow of SensorData
                from visionSensor.dataPort.data to controller.sensorDataPort.data;
            flow motionCommandFlow of MotionCommand
                from controller.motionCommandPort.command to arm.motionCommandPort.command;
            flow motionStatusFlow of MotionStatus
                from arm.motionStatusPort.status to controller.motionStatusPort.status;
            flow gripperCommandFlow of GripperCommand
                from controller.gripperCommandPort.command to arm.gripper.commandPort.command;
            flow gripperStatusFlow of GripperStatus
                from arm.gripper.statusPort.status to controller.gripperStatusPort.status;
            flow powerToController of PowerSpec
                from powerSupply.powerPort.power to controller.powerPort.power;
            flow powerToArm of PowerSpec
                from powerSupply.powerPort.power to arm.powerPort.power;
            flow powerToSensor of PowerSpec
                from powerSupply.powerPort.power to visionSensor.powerPort.power;
            flow powerToInputConveyor of PowerSpec
                from powerSupply.powerPort.power to inputConveyor.powerPort.power;
            flow powerToOutputConveyor of PowerSpec
                from powerSupply.powerPort.power to outputConveyor.powerPort.power;
            flow workpieceInFlow of Workpiece
                from inputConveyor.workpiecePort.workpieceOut to arm.gripper.workpiecePort.workpieceIn;
            flow workpieceOutFlow of Workpiece
                from arm.gripper.workpiecePort.workpieceOut to outputConveyor.workpiecePort.workpieceIn;
        }

        action def PickAndPlaceTask {
            in taskCommand : TaskCommand;
            out success : Boolean;

            action sense : VisionSensor3D::scan {
                out data : SensorData;
            }
            action plan : MotionController::planTrajectory {
                in sensorData : SensorData;
                in targetPose : Pose;
                out trajectory : Trajectory;
            }
            action moveToPick : SixAxisRoboticArm::executeMotion {
                in trajectory : Trajectory;
            }
            action grip : Gripper::grip {
                in workpiece : Workpiece;
                in commandedForce : ForceValue;
            }
            action moveToPlace : SixAxisRoboticArm::executeMotion {
                in trajectory : Trajectory;
            }
            action release : Gripper::release {
                in workpiece : Workpiece;
            }
            action done {
                out success : Boolean;
                assign success := true;
            }

            first start then sense;
            first sense then plan;
            first plan then moveToPick;
            first moveToPick then grip;
            first grip then moveToPlace;
            first moveToPlace then release;
            first release then done;

            flow sense.data to plan.sensorData;
            flow plan.trajectory to moveToPick.trajectory;
            bind plan.targetPose = taskCommand.targetPose;
        }

        state def WorkCellStateMachine {
            in cell : WorkCell;
            in taskCommand : TaskCommand;
            entry; then idle;

            state idle;
            accept StartTask then sensing;

            state sensing;
            accept SensorDataReady then planning;

            state planning;
            accept TrajectoryPlanned then movingToPick;

            state movingToPick;
            accept MotionComplete then gripping;

            state gripping;
            accept GripSuccess then movingToPlace;
            accept GripFailure then error;

            state movingToPlace;
            accept MotionComplete then releasing;

            state releasing;
            accept ReleaseComplete then idle;

            state error;
            accept ResetSignal then idle;
            accept ErrorSignal then error;
        }

        requirement def SafeGripForceRequirement {
            doc /* The gripper shall not apply more than 50 Newtons of force to prevent workpiece damage. */;
            attribute maxGripForce : ForceValue := 50.0;
            subject gripper : Gripper;
            constraint { gripper.currentForce <= maxGripForce }
        }

        requirement def ObstacleAvoidanceRequirement {
            doc /* The motion controller shall plan trajectories that avoid all detected obstacles. */;
            subject controller : MotionController;
        }

        requirement def PowerSupplyRequirement {
            doc /* The system shall be powered by a dedicated 24V DC, 20A power supply. */;
            attribute requiredVoltage : ElectricPotentialValue := 24.0;
            attribute requiredCurrent : ElectricCurrentValue := 20.0;
            subject powerSupply : PowerSupply;
            constraint { powerSupply.ratedVoltage == requiredVoltage }
            constraint { powerSupply.ratedCurrent == requiredCurrent }
        }

        requirement def OperationalCycleRequirement {
            doc /* The system shall execute a state-driven cycle: idle, sensing, planning, motion, gripping, motion, releasing, with error handling. */;
            subject cell : WorkCell;
        }
    }

    package Usages {
        private import Definitions::*;

        part workCellInstance : WorkCell {
            attribute cellId : String := "WorkCell-001";
        }

        action performTask : PickAndPlaceTask {
            in taskCommand : TaskCommand;
            out success : Boolean;
        }

        state workCellOperation : WorkCellStateMachine {
            in cell := workCellInstance;
            in taskCommand : TaskCommand;
        }

        requirement safeGrip : SafeGripForceRequirement {
            subject gripper := workCellInstance.arm.gripper;
        }
        requirement obstacleAvoidance : ObstacleAvoidanceRequirement {
            subject controller := workCellInstance.controller;
        }
        requirement powerSpec : PowerSupplyRequirement {
            subject powerSupply := workCellInstance.powerSupply;
        }
        requirement operationalCycle : OperationalCycleRequirement {
            subject cell := workCellInstance;
        }
    }
}
