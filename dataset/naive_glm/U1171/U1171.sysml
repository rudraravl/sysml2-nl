package ProgrammableMatterSystem {
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value type Length :> Real { unit 'm'; }
    value type Mass :> Real { unit 'kg'; }
    value type Power :> Real { unit 'W'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Force :> Real { unit 'N'; }
    value type Duration :> Real { unit 's'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Angle :> Real { unit 'rad'; }
    value type DataRate :> Real { unit 'bit/s'; }
    value type Energy :> Real { unit 'J'; }

    // ---- Enumerations ----
    enum Face { top, bottom, front, back, left, right; }
    enum BondType { mechanical, magnetic, electrostatic; }
    enum ModuleState { idle, sensing, moving, bonding, unbonding; }
    enum CommandKind { move, bond, unbond, sense, report, synchronize; }
    enum ControlState { waiting, planning, executing, verifying, complete; }

    // ---- Composite Value Types ----
    value type Position {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }

    value type Orientation {
        attribute roll : Angle;
        attribute pitch : Angle;
        attribute yaw : Angle;
    }

    value type VelocityVector {
        attribute vx : Length;
        attribute vy : Length;
        attribute vz : Length;
    }

    // ---- Item Definitions ----
    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute available : Boolean;
    }

    item def CommandMessage {
        attribute commandId : String;
        attribute kind : CommandKind;
        attribute targetModuleId : String;
        attribute targetPosition : Position;
        attribute targetOrientation : Orientation;
        attribute facesToBond : Face[0..*];
        attribute facesToUnbond : Face[0..*];
        attribute timestamp : Duration;
    }

    item def StatusMessage {
        attribute moduleId : String;
        attribute state : ModuleState;
        attribute position : Position;
        attribute orientation : Orientation;
        attribute bondedFaces : Face[0..*];
        attribute neighborIds : String[0..*];
        attribute energyLevel : Real;
        attribute stepComplete : Boolean;
    }

    item def SensorData {
        attribute moduleId : String;
        attribute proximityDistances : Length[6];
        attribute detectedNeighborIds : String[0..*];
        attribute detectedFaces : Face[0..*];
    }

    item def SyncToken {
        attribute cycleId : Integer;
        attribute phase : String;
        attribute participantCount : Integer;
    }

    // ---- Requirements ----
    requirement def ReconfigurableShapeRequirement {
        doc /* The system shall autonomously change its overall physical shape in response to digital commands. */
        attribute targetShape : String;
        attribute maxReconfigTime : Duration = 300.0;
        subject system : Anything;
        objective {
            system.currentShape == targetShape and
            system.reconfigTime <= maxReconfigTime
        }
    }

    requirement def ModuleBondingRequirement {
        doc /* Each modular unit shall connect to and disconnect from neighbors on any of its six faces. */
        attribute requiredFaces : Integer = 6;
        subject module : Anything;
        objective {
            module.bondingFaceCount == requiredFaces
        }
    }

    requirement def CollisionAvoidanceRequirement {
        doc /* The control system shall plan movement paths that avoid collisions between modules. */
        subject controlSystem : Anything;
        objective {
            controlSystem.collisionFreePaths == true
        }
    }

    requirement def PowerDistributionRequirement {
        doc /* The energy system shall distribute sufficient electrical energy to all modules throughout reconfiguration. */
        attribute minVoltage : Voltage = 10.0;
        subject energySystem : Anything;
        objective {
            energySystem.totalPower >= energySystem.requiredPower and
            energySystem.outputVoltage >= minVoltage
        }
    }

    requirement def CommunicationRequirement {
        doc /* Modules shall be in constant communication with the control system and each other. */
        attribute minDataRate : DataRate = 1000.0;
        subject module : Anything;
        objective {
            module.communicationActive == true and
            module.dataRate >= minDataRate
        }
    }

    requirement def SynchronizationRequirement {
        doc /* The control system shall coordinate module actions through a synchronization protocol. */
        subject controlSystem : Anything;
        objective {
            controlSystem.synchronized == true
        }
    }

    // ---- Port Definitions ----
    port def PowerPort {
        in item power : PowerSignal;
    }

    port def CommandPort {
        out item command : CommandMessage;
        in item status : StatusMessage;
        in item sensorData : SensorData;
        out item sync : SyncToken;
    }

    port def ModuleCommPort {
        out item outgoingStatus : StatusMessage;
        in item incomingStatus : StatusMessage;
        out item outgoingSensor : SensorData;
        in item incomingSensor : SensorData;
    }

    port def BondingPort {
        attribute face : Face;
        attribute bondType : BondType;
        attribute engaged : Boolean;
        attribute bondForce : Force;
    }

    // ---- Action Definitions ----
    action def PlanReconfiguration {
        in targetShape : String;
        in currentPositions : Position[0..*];
        out plan : CommandMessage[0..*];
        out collisionFree : Boolean;
        doc /* Analyzes desired final configuration and plans efficient collision-free movement paths. */
    }

    action def ExecuteStep {
        in command : CommandMessage;
        out status : StatusMessage;
        doc /* Module executes a single movement, bonding, or unbonding step. */
    }

    action def SynchronizeModules {
        in cycleId : Integer;
        in statuses : StatusMessage[0..*];
        out syncToken : SyncToken;
        out synchronized : Boolean;
        doc /* Coordinates module actions through a synchronization protocol. */
    }

    action def DistributePower {
        in load : Current;
        out powerSignals : PowerSignal[0..*];
        doc /* Distributes electrical energy to all connected modules. */
    }

    action def SenseNeighbors {
        in moduleId : String;
        out sensorData : SensorData;
        doc /* Detects proximity to other modules on all six faces. */
    }

    action def MoveToPosition {
        in targetPosition : Position;
        in targetOrientation : Orientation;
        out arrived : Boolean;
        doc /* Physically moves the module a short distance to the designated position. */
    }

    action def EstablishBond {
        in face : Face;
        in bondType : BondType;
        out engaged : Boolean;
        doc /* Establishes a physical bond with a neighbor on the specified face. */
    }

    action def ReleaseBond {
        in face : Face;
        out released : Boolean;
        doc /* Releases a physical bond from a neighbor on the specified face. */
    }

    // ---- Subsystem Part Definitions ----

    part def SensingSystem {
        attribute proximityRange : Length = 0.05;
        attribute scanFrequency : Frequency = 50.0;
        port sensorOut : CommandPort;
        action sense : SenseNeighbors;
    }

    part def ActuationSystem {
        attribute maxForce : Force = 2.0;
        attribute maxSpeed : Length = 0.01;
        attribute powerConsumption : Power = 0.5;
        action move : MoveToPosition;
    }

    part def BondingMechanism {
        attribute bondType : BondType = magnetic;
        attribute bondStrength : Force = 5.0;
        attribute powerPerBond : Power = 0.2;
        port bondingFaces : BondingPort[6];
        action bond : EstablishBond;
        action unbond : ReleaseBond;
    }

    part def ModuleProcessor {
        attribute clockSpeed : Frequency = 100e6;
        attribute memory : Integer = 256;
        attribute dataRate : DataRate = 2000.0;
        action processCommand {
            in command : CommandMessage;
            out status : StatusMessage;
        }
    }

    part def CommunicationInterface {
        attribute dataRate : DataRate = 2000.0;
        attribute range : Length = 0.5;
        attribute active : Boolean = true;
    }

    // ---- Modular Unit ----
    part def ModularUnit {
        attribute moduleId : String;
        attribute position : Position;
        attribute orientation : Orientation;
        attribute velocity : VelocityVector;
        attribute state : ModuleState = idle;
        attribute bondingFaceCount : Integer = 6;
        attribute communicationActive : Boolean = true;
        attribute energyLevel : Real = 1.0;
        attribute stepComplete : Boolean = false;

        port powerIn : PowerPort;
        port controlLink : CommandPort;
        port neighborComm : ModuleCommPort[0..6];
        port bondingInterfaces : BondingPort[6];

        part sensing : SensingSystem;
        part actuation : ActuationSystem;
        part bonding : BondingMechanism;
        part processor : ModuleProcessor;
        part comm : CommunicationInterface;

        satisfy ModuleBondingRequirement {
            subject module = ModularUnit::this;
        }

        satisfy CommunicationRequirement {
            subject module = ModularUnit::this;
        }

        state machine ModuleStateMachine {
            entry action { /* initialize module to idle */ }

            state idle {
                entry action { state = ModuleState::idle; }
            }
            state sensing {
                entry action { state = ModuleState::sensing; }
                do action { sensing.sense(); }
            }
            state moving {
                entry action { state = ModuleState::moving; }
                do action { actuation.move(); }
            }
            state bonding {
                entry action { state = ModuleState::bonding; }
                do action { bonding.bond(); }
            }
            state unbonding {
                entry action { state = ModuleState::unbonding; }
                do action { bonding.unbond(); }
            }

            transition idle_to_sensing
                first idle then sensing
                when controlLink.command.kind == CommandKind::sense;

            transition sensing_to_idle
                first sensing then idle
                when stepComplete == true;

            transition idle_to_unbonding
                first idle then unbonding
                when controlLink.command.kind == CommandKind::unbond;

            transition unbonding_to_moving
                first unbonding then moving
                when controlLink.command.kind == CommandKind::move;

            transition idle_to_moving
                first idle then moving
                when controlLink.command.kind == CommandKind::move and bonding.bondingFaces.engaged == false;

            transition moving_to_bonding
                first moving then bonding
                when controlLink.command.kind == CommandKind::bond;

            transition bonding_to_idle
                first bonding then idle
                when stepComplete == true;
        }
    }

    // ---- Control System ----
    part def ControlSystem {
        attribute targetShape : String;
        attribute currentShape : String;
        attribute planGenerated : Boolean = false;
        attribute collisionFreePaths : Boolean = true;
        attribute synchronized : Boolean = false;
        attribute allModulesIdle : Boolean = false;
        attribute shapeComplete : Boolean = false;
        attribute cycleId : Integer = 0;
        attribute maxModules : Integer = 1000;

        port moduleLinks : CommandPort[0..*];

        action plan : PlanReconfiguration {
            in targetShape = ControlSystem::this.targetShape;
        }

        action synchronize : SynchronizeModules;

        action sendCommands {
            in plan : CommandMessage[0..*];
        }

        action receiveStatus {
            in statuses : StatusMessage[0..*];
        }

        action verifyShape {
            in statuses : StatusMessage[0..*];
            out complete : Boolean;
        }

        satisfy CollisionAvoidanceRequirement {
            subject controlSystem = ControlSystem::this;
        }

        satisfy SynchronizationRequirement {
            subject controlSystem = ControlSystem::this;
        }

        state machine ControlStateMachine {
            state waiting {
                entry action { /* await target shape command */ }
            }
            state planning {
                entry action { plan(); }
                do action { plan(); }
            }
            state executing {
                entry action { sendCommands(); }
                do action { receiveStatus(); }
            }
            state verifying {
                entry action { verifyShape(); }
            }
            state complete {
                entry action { shapeComplete = true; }
            }

            transition wait_to_plan
                first waiting then planning
                when targetShape != null;

            transition plan_to_execute
                first planning then executing
                when planGenerated == true;

            transition execute_to_verify
                first executing then verifying
                when allModulesIdle == true;

            transition verify_to_complete
                first verifying then complete
                when shapeComplete == true;

            transition verify_to_execute
                first verifying then executing
                when shapeComplete == false;
        }
    }

    // ---- Energy System ----
    part def EnergySystem {
        attribute totalPower : Power = 500.0;
        attribute requiredPower : Power = 400.0;
        attribute outputVoltage : Voltage = 12.0;
        attribute maxCurrent : Current = 50.0;
        attribute distributionEfficiency : Real = 0.95;
        attribute energyReserve : Energy = 100000.0;

        port powerOut : PowerPort[0..*];

        action distribute : DistributePower;
        action monitorLoad {
            in currentDraw : Current;
        }

        satisfy PowerDistributionRequirement {
            subject energySystem = EnergySystem::this;
        }

        state machine EnergyStateMachine {
            state normal {
                entry action { distribute(); }
            }
            state highLoad {
                entry action { monitorLoad(); }
            }
            state depleted {
                entry action { /* alert control system */ }
            }

            transition normal_to_highLoad
                first normal then highLoad
                when requiredPower > 350.0;

            transition highLoad_to_normal
                first highLoad then normal
                when requiredPower <= 350.0;

            transition normal_to_depleted
                first normal then depleted
                when energyReserve < 1000.0;
        }
    }

    // ---- Top-Level System ----
    part def ProgrammableMatterRobot {
        attribute systemId : String;
        attribute currentShape : String;
        attribute targetShape : String;
        attribute reconfigTime : Duration = 0.0;
        attribute moduleCount : Integer = 100;

        part controlSystem : ControlSystem;
        part energySystem : EnergySystem;
        part modules : ModularUnit[100];

        satisfy ReconfigurableShapeRequirement {
            subject system = ProgrammableMatterRobot::this;
            attribute targetShape = ProgrammableMatterRobot::this.targetShape;
        }

        connection powerDistribution connect energySystem.powerOut to modules.powerIn;
        connection commandNetwork connect controlSystem.moduleLinks to modules.controlLink;
        connection interModuleComm connect modules.neighborComm to modules.neighborComm;

        action def ReconfigureSequence {
            in targetShape : String;
            in currentPositions : Position[0..*];
            out shapeComplete : Boolean;

            action generatePlan : PlanReconfiguration {
                in targetShape = ReconfigureSequence::targetShape;
                in currentPositions = ReconfigureSequence::currentPositions;
            }

            action syncInitial : SynchronizeModules {
                in cycleId = 0;
            }

            action executeSteps {
                in plan = generatePlan.plan;
                fork {
                    action moduleSteps[100] : ExecuteStep;
                }
            }

            action syncFinal : SynchronizeModules {
                in cycleId = 1;
                in statuses = executeSteps.moduleSteps.status;
            }

            action verify : verifyShape {
                in statuses = executeSteps.moduleSteps.status;
                out complete;
            }

            flow generatePlan.plan to executeSteps.plan;
            flow executeSteps.moduleSteps.status to syncFinal.statuses;
            flow syncFinal.syncToken to executeSteps;
            flow verify.complete to ReconfigureSequence.shapeComplete;
        }

        action reconfigure : ReconfigureSequence {
            in targetShape = ProgrammableMatterRobot::this.targetShape;
        }
    }
}
