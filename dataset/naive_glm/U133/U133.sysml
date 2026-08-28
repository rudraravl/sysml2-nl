package ValvulotomeSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====

    value def Force :> Real {
        unit N;
    }

    value def RotationalSpeed :> Real {
        unit rpm;
    }

    value def Length :> Real {
        unit mm;
    }

    value def Angle :> Real {
        unit '°';
    }

    value def Pressure :> Real {
        unit Pa;
    }

    value def Power :> Real {
        unit W;
    }

    value def Duration :> Real {
        unit s;
    }

    // ===== Item Types =====

    item def Blood {
        attribute viscosity : Real;
        attribute flowRate : Real;
    }

    item def VenousValve {
        attribute leafletThickness : Length;
        attribute competency : Boolean;
        attribute location : Length;
    }

    item def Tissue;

    // ===== Enumeration Types =====

    enum def DeviceState {
        standby;
        navigating;
        positioned;
        bladeDeployed;
        cutting;
        bladeRetracted;
        withdrawn;
    }

    enum def DeploymentCommand {
        none;
        deploy;
        retract;
    }

    enum def RotationCommand {
        off;
        on;
    }

    // ===== Requirements =====

    requirement def 'Valvulotomy Requirement' {
        doc /* The system shall perform a valvulotomy to treat chronic venous insufficiency. */
        subject device : Valvulotome;
        objective {
            perform valvulotomy on incompetent venous valves to restore blood flow.
        }
    }

    requirement def 'Precise Cutting Requirement' {
        doc /* The cutting blade shall precisely incise valve leaflets without damaging the vessel wall. */
        subject blade : CuttingBlade;
        attribute maxCuttingForce : Force = 2.0 [N];
        constraint { blade.appliedForce <= maxCuttingForce }
    }

    requirement def 'Force Feedback Requirement' {
        doc /* The system shall provide feedback on applied forces to prevent vessel perforation. */
        subject sensor : ForceSensor;
        attribute forceThreshold : Force = 1.5 [N];
        constraint { sensor.measuredForce <= forceThreshold }
    }

    requirement def 'Safe Navigation Requirement' {
        doc /* The blade shall remain retracted during navigation. */
        subject blade : CuttingBlade;
        constraint { blade.isRettracted == true when device.state == DeviceState::navigating }
    }

    requirement def 'Controlled Rotation Requirement' {
        doc /* The rotational mechanism shall spin the blade at a controlled speed. */
        subject rotor : RotationalMechanism;
        attribute targetSpeed : RotationalSpeed = 500 [rpm];
        attribute speedTolerance : RotationalSpeed = 50 [rpm];
        constraint { abs(rotor.currentSpeed - targetSpeed) <= speedTolerance }
    }

    requirement def 'Flexibility Requirement' {
        doc /* The catheter shaft shall be flexible enough to navigate complex venous networks. */
        subject shaft : CatheterShaft;
        attribute minBendRadius : Length = 15.0 [mm];
        constraint { shaft.bendRadius >= minBendRadius }
    }

    requirement def 'Ergonomic Requirement' {
        doc /* The handle assembly shall provide ergonomic grip and precise controls. */
        subject handle : HandleAssembly;
        attribute maxGripForce : Force = 10.0 [N];
        constraint { handle.requiredGripForce <= maxGripForce }
    }

    // ===== Port Definitions =====

    port def MechanicalInterface {
        in item command;
        out item feedback;
    }

    port def ControlInterface {
        in attribute command;
        out attribute status;
    }

    port def ForceFeedbackPort {
        out attribute measuredForce : Force;
    }

    port def RotationDrivePort {
        in attribute speed : RotationalSpeed;
        out attribute torque : Real;
    }

    port def DeploymentPort {
        in attribute deploymentCommand : DeploymentCommand;
        out attribute deploymentStatus : Boolean;
    }

    port def BloodFlowPort {
        in item blood : Blood;
        out item blood : Blood;
    }

    // ===== Main Components =====

    part def HandleAssembly {
        port controlPort : ControlInterface;
        port deploymentControl : DeploymentPort;
        port rotationControl : RotationDrivePort;
        port forceFeedbackIn : ForceFeedbackPort;

        attribute gripForce : Force;
        attribute leverPosition : Angle;
        attribute isErgonomic : Boolean;

        part grip {
            attribute material : String = "MedicalGradePolymer";
            attribute surfaceTexture : String = "Textured";
        }

        part lever {
            attribute travelRange : Angle = 30 ['°'];
            attribute currentAngle : Angle;
        }

        part display {
            attribute forceReading : Force;
            attribute statusMessage : String;
        }

        action def actuateLever {
            in command : DeploymentCommand;
            out deploymentStatus : Boolean;
        }

        action def activateRotation {
            in command : RotationCommand;
            out speed : RotationalSpeed;
        }

        action def displayForceFeedback {
            in force : Force;
        }

        exhibit state HandleStateMachine {
            entry; then idle;
            state idle;
            state deploying {
                entry { send deploy to deploymentControl; }
            }
            state retracting {
                entry { send retract to deploymentControl; }
            }
            state rotating {
                entry { send on to rotationControl; }
            }
            transition from idle to deploying when lever.currentAngle > 10 ['°'];
            transition from deploying to rotating when deploymentControl.deploymentStatus == true;
            transition from rotating to retracting when lever.currentAngle < 5 ['°'];
            transition from retracting to idle when deploymentControl.deploymentStatus == false;
        }
    }

    part def CatheterShaft {
        port proximalEnd : MechanicalInterface;
        port distalEnd : MechanicalInterface;
        port bloodFlow : BloodFlowPort;

        attribute length : Length = 800 [mm];
        attribute outerDiameter : Length = 3.0 [mm];
        attribute innerDiameter : Length = 2.0 [mm];
        attribute bendRadius : Length;
        attribute flexibility : Real;
        attribute material : String = "Polyurethane";

        part outerLayer {
            attribute material : String = "Polyurethane";
            attribute thickness : Length = 0.5 [mm];
        }

        part innerLumen {
            attribute diameter : Length = 2.0 [mm];
            attribute lubricity : Real;
        }

        part reinforcementCoil {
            attribute material : String = "Nitinol";
            attribute pitch : Length = 1.0 [mm];
        }

        action def navigate {
            in targetLocation : Length;
            in currentLocation : Length;
            out pathComplete : Boolean;
        }

        action def transmitTorque {
            in torque : Real;
            out torque : Real;
        }

        action def transmitForce {
            in force : Force;
            out force : Force;
        }
    }

    part def RotationalMechanism {
        port driveInput : RotationDrivePort;
        port bladeConnection : MechanicalInterface;
        port forceOutput : ForceFeedbackPort;

        attribute currentSpeed : RotationalSpeed;
        attribute targetSpeed : RotationalSpeed = 500 [rpm];
        attribute torque : Real;
        attribute powerConsumption : Power;
        attribute isActivated : Boolean;

        part motor {
            attribute type : String = "MicroDC";
            attribute maxSpeed : RotationalSpeed = 1000 [rpm];
            attribute stallTorque : Real;
        }

        part gearbox {
            attribute gearRatio : Real = 10.0;
            attribute efficiency : Real = 0.85;
        }

        part bearing {
            attribute type : String = "Ceramic";
            attribute frictionCoefficient : Real = 0.02;
        }

        part forceSensor {
            attribute measuredForce : Force;
            attribute sensitivity : Real = 0.01;
            attribute range : Force = 5.0 [N];
        }

        action def spinBlade {
            in speed : RotationalSpeed;
            out torque : Real;
            out measuredForce : Force;
        }

        action def measureForce {
            out force : Force;
        }

        action def stopRotation {
            out speed : RotationalSpeed = 0 [rpm];
        }

        exhibit state RotationStateMachine {
            entry; then stopped;
            state stopped {
                entry { currentSpeed = 0 [rpm]; isActivated = false; }
            }
            state accelerating {
                entry { currentSpeed = targetSpeed; }
            }
            state spinning {
                entry { isActivated = true; }
            }
            state decelerating {
                entry { currentSpeed = currentSpeed * 0.5; }
            }
            transition from stopped to accelerating when driveInput.speed > 0 [rpm];
            transition from accelerating to spinning when currentSpeed >= targetSpeed;
            transition from spinning to decelerating when driveInput.speed == 0 [rpm];
            transition from decelerating to stopped when currentSpeed == 0 [rpm];
        }
    }

    part def CuttingBlade {
        port mechanicalInput : MechanicalInterface;
        port tissueInterface;

        attribute isDeployed : Boolean;
        attribute isRettracted : Boolean;
        attribute sharpness : Real;
        attribute bladeLength : Length = 2.5 [mm];
        attribute bladeWidth : Length = 1.0 [mm];
        attribute material : String = "SurgicalSteel";
        attribute appliedForce : Force;
        attribute cuttingDepth : Length;

        part cuttingEdge {
            attribute edgeAngle : Angle = 20 ['°'];
            attribute edgeRadius : Length = 0.005 [mm];
        }

        part bladeBody {
            attribute thickness : Length = 0.2 [mm];
            attribute coating : String = "DiamondLikeCarbon";
        }

        part deploymentSheath {
            attribute innerDiameter : Length = 1.2 [mm];
            attribute isRetracted : Boolean;
        }

        action def deploy {
            in command : DeploymentCommand;
            out isDeployed : Boolean;
        }

        action def retract {
            in command : DeploymentCommand;
            out isRettracted : Boolean;
        }

        action def cut {
            in target : VenousValve;
            in speed : RotationalSpeed;
            out incisionComplete : Boolean;
            out appliedForce : Force;
        }

        exhibit state BladeStateMachine {
            entry; then retracted;
            state retracted {
                entry { isRettracted = true; isDeployed = false; }
            }
            state deploying {
                entry { isRettracted = false; }
            }
            state deployed {
                entry { isDeployed = true; isRettracted = false; }
            }
            state cutting {
                entry { perform cut; }
            }
            state retracting {
                entry { isDeployed = false; }
            }
            transition from retracted to deploying when mechanicalInput.command == DeploymentCommand::deploy;
            transition from deploying to deployed when deploymentSheath.isRetracted == true;
            transition from deployed to cutting when mechanicalInput.command == RotationCommand::on;
            transition from cutting to deployed when appliedForce > 1.5 [N];
            transition from deployed to retracting when mechanicalInput.command == DeploymentCommand::retract;
            transition from retracting to retracted when deploymentSheath.isRetracted == false;
        }
    }

    // ===== Patient Context =====

    part def Patient {
        part venousSystem {
            part targetVein {
                attribute diameter : Length = 5.0 [mm];
                attribute wallThickness : Length = 0.5 [mm];
                port bloodFlow : BloodFlowPort;
            }
            part incompetentValve : VenousValve {
                attribute leafletThickness : Length = 0.3 [mm];
                attribute competency : Boolean = false;
                attribute location : Length = 400 [mm];
            }
        }
        item blood : Blood {
            attribute viscosity : Real = 0.004;
            attribute flowRate : Real = 0.0;
        }
    }

    // ===== Top-Level System =====

    part def Valvulotome {
        port insertionPort : BloodFlowPort;
        port surgeonInterface : ControlInterface;

        attribute state : DeviceState;
        attribute procedureStartTime : Duration;
        attribute procedureDuration : Duration;

        part handleAssembly : HandleAssembly;
        part catheterShaft : CatheterShaft;
        part rotationalMechanism : RotationalMechanism;
        part cuttingBlade : CuttingBlade;

        // Internal connections
        connection handleToShaft connect handleAssembly.controlPort to catheterShaft.proximalEnd;
        connection shaftToRotor connect catheterShaft.distalEnd to rotationalMechanism.bladeConnection;
        connection rotorToBlade connect rotationalMechanism.bladeConnection to cuttingBlade.mechanicalInput;
        connection forceFeedback connect rotationalMechanism.forceOutput to handleAssembly.forceFeedbackIn;
        connection deploymentControl connect handleAssembly.deploymentControl to cuttingBlade.mechanicalInput;
        connection rotationControl connect handleAssembly.rotationControl to rotationalMechanism.driveInput;

        // Requirements satisfaction
        satisfy 'Valvulotomy Requirement' by valvulotomyProcedure;
        satisfy 'Precise Cutting Requirement' by cuttingBlade;
        satisfy 'Force Feedback Requirement' by rotationalMechanism.forceSensor;
        satisfy 'Safe Navigation Requirement' by cuttingBlade;
        satisfy 'Controlled Rotation Requirement' by rotationalMechanism;
        satisfy 'Flexibility Requirement' by catheterShaft;
        satisfy 'Ergonomic Requirement' by handleAssembly;

        action def valvulotomyProcedure {
            in patient : Patient;
            in targetValve : VenousValve;

            action insertCatheter {
                out insertionComplete : Boolean;
            }

            action navigateToValve {
                in targetLocation : Length;
                out positioned : Boolean;
            }

            action deployBlade {
                in command : DeploymentCommand;
                out deployed : Boolean;
            }

            action activateRotation {
                in speed : RotationalSpeed;
                out cuttingComplete : Boolean;
                out appliedForce : Force;
            }

            action verifyBloodFlow {
                in blood : Blood;
                out flowImproved : Boolean;
            }

            action retractBlade {
                in command : DeploymentCommand;
                out retracted : Boolean;
            }

            action withdrawDevice {
                out withdrawn : Boolean;
            }

            // Action flow
            first insertCatheter;
            then navigateToValve;
            then deployBlade;
            then activateRotation;
            then verifyBloodFlow;
            then retractBlade;
            then withdrawDevice;
        }

        exhibit state DeviceStateMachine {
            entry; then standby;

            state standby {
                entry { state = DeviceState::standby; }
            }

            state navigating {
                entry { state = DeviceState::navigating; }
                do { catheterShaft.navigate; }
            }

            state positioned {
                entry { state = DeviceState::positioned; }
            }

            state bladeDeployed {
                entry { state = DeviceState::bladeDeployed; }
                do { cuttingBlade.deploy; }
            }

            state cutting {
                entry { state = DeviceState::cutting; }
                do { rotationalMechanism.spinBlade; }
            }

            state bladeRetracted {
                entry { state = DeviceState::bladeRetracted; }
                do { cuttingBlade.retract; }
            }

            state withdrawn {
                entry { state = DeviceState::withdrawn; }
            }

            transition from standby to navigating when surgeonInterface.command == "start";
            transition from navigating to positioned when catheterShaft.distalEnd.feedback == "positioned";
            transition from positioned to bladeDeployed when handleAssembly.deploymentControl.deploymentStatus == true;
            transition from bladeDeployed to cutting when rotationalMechanism.isActivated == true;
            transition from cutting to bladeRetracted when cuttingBlade.appliedForce > 1.5 [N] or surgeonInterface.command == "stop";
            transition from bladeRetracted to withdrawn when surgeonInterface.command == "withdraw";
            transition from withdrawn to standby when surgeonInterface.command == "reset";
        }
    }

    // ===== System Usage =====

    part valvulotomeSystem : Valvulotome {
        part patient : Patient;

        connection deviceToPatient connect valvulotomeSystem.insertionPort to patient.venousSystem.targetVein.bloodFlow;

        requirement 'System Performance Requirement' {
            doc /* The complete valvulotome system shall restore blood flow through incompetent venous valves. */
            subject system : Valvulotome;
            attribute maxProcedureTime : Duration = 600 [s];
            constraint { system.procedureDuration <= maxProcedureTime }
        }
    }

}
