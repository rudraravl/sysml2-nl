package ProgrammableMatterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQElectromagnetism::*;
    private import SI::*;

    enum def BondAction {
        literal connect;
        literal disconnect;
    }

    enum def ModuleStateKind {
        literal idle;
        literal sensing;
        literal unbonding;
        literal moving;
        literal bonding;
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }

    item def Position3D {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }

    item def Orientation3D {
        attribute roll : AngleValue;
        attribute pitch : AngleValue;
        attribute yaw : AngleValue;
    }

    item def TargetShape {
        attribute shapeId : String;
        attribute description : String;
        attribute targetPositions : Position3D[1..*];
    }

    item def ModuleStatus {
        attribute moduleId : Natural;
        attribute currentPosition : Position3D;
        attribute currentOrientation : Orientation3D;
        attribute currentState : ModuleStateKind;
        attribute batteryLevel : Real;
    }

    item def ProximityData {
        attribute neighborDetected : Boolean;
        attribute distance : LengthValue;
        attribute faceId : Natural;
    }

    item def MovementCommand {
        attribute moduleId : Natural;
        attribute targetPosition : Position3D;
        attribute targetOrientation : Orientation3D;
        attribute stepSequence : Natural;
    }

    item def BondingCommand {
        attribute moduleId : Natural;
        attribute faceId : Natural;
        attribute bondAction : BondAction;
    }

    item def SynchronizationMessage {
        attribute timestamp : Real;
        attribute phase : String;
        attribute participantCount : Natural;
    }

    port def PowerPort {
        in energy : ElectricalEnergy;
    }

    port def CommandPort {
        in movementCmd : MovementCommand;
        in bondingCmd : BondingCommand;
        in syncMsg : SynchronizationMessage;
        out status : ModuleStatus;
        out proximity : ProximityData;
    }

    port def InterModuleCommPort {
        in neighborStatus : ModuleStatus;
        out selfStatus : ModuleStatus;
    }

    port def BondingInterfacePort {
        in bondCmd : BondingCommand;
        attribute faceId : Natural;
        attribute bondActive : Boolean;
    }

    port def ShapeInputPort {
        in targetShape : TargetShape;
    }

    interface def PowerDistributionInterface {
        end sourcePort : PowerPort;
        end unitPort : ~PowerPort;
        flow of ElectricalEnergy from sourcePort.energy to unitPort.energy;
    }

    interface def ControlInterface {
        end controlPort : CommandPort;
        end unitPort : ~CommandPort;
        flow of MovementCommand from controlPort.movementCmd to unitPort.movementCmd;
        flow of BondingCommand from controlPort.bondingCmd to unitPort.bondingCmd;
        flow of SynchronizationMessage from controlPort.syncMsg to unitPort.syncMsg;
        flow of ModuleStatus from unitPort.status to controlPort.status;
        flow of ProximityData from unitPort.proximity to controlPort.proximity;
    }

    interface def InterModuleInterface {
        end unitA : InterModuleCommPort;
        end unitB : ~InterModuleCommPort;
        flow of ModuleStatus from unitA.selfStatus to unitB.neighborStatus;
        flow of ModuleStatus from unitB.selfStatus to unitA.neighborStatus;
    }

    action def SenseNeighbors {
        out detectedProximity : ProximityData;
    }

    action def Move {
        in target : Position3D;
        in targetOrient : Orientation3D;
        out done : Boolean;
    }

    action def Bond {
        in face : Natural;
        out success : Boolean;
    }

    action def Unbond {
        in face : Natural;
        out success : Boolean;
    }

    action def AnalyzeShape {
        in desiredShape : TargetShape;
        out moduleAssignments : MovementCommand[1..*];
    }

    action def PlanPaths {
        in assignments : MovementCommand[1..*];
        out collisionFreePlan : MovementCommand[1..*];
    }

    action def SynchronizeModules {
        in plan : MovementCommand[1..*];
        out syncMessages : SynchronizationMessage[1..*];
    }

    action def DispatchCommands {
        in finalPlan : MovementCommand[1..*];
        in bondCommands : BondingCommand[1..*];
        in syncs : SynchronizationMessage[1..*];
    }

    action def MonitorProgress {
        in statuses : ModuleStatus[1..*];
        out complete : Boolean;
    }

    action def DistributePower {
        in demand : PowerValue[1..*];
        out supplied : ElectricalEnergy[1..*];
    }

    state def ModuleStateMachine {
        state idle;
        state sensing;
        state unbonding;
        state moving;
        state bonding;

        transition from idle to sensing;
        transition from sensing to unbonding;
        transition from unbonding to moving;
        transition from moving to bonding;
        transition from bonding to idle;
    }

    state def ControlStateMachine {
        state awaitingCommand;
        state planning;
        state executing;
        state monitoring;
        state complete;

        transition from awaitingCommand to planning;
        transition from planning to executing;
        transition from executing to monitoring;
        transition from monitoring to complete;
        transition from complete to awaitingCommand;
    }

    state def EnergyStateMachine {
        state nominal;
        state highDemand;
        state depleted;

        transition from nominal to highDemand;
        transition from highDemand to nominal;
        transition from highDemand to depleted;
    }

    part def ModularUnit {
        attribute moduleId : Natural;
        attribute position : Position3D;
        attribute orientation : Orientation3D;
        attribute currentState : ModuleStateKind default ModuleStateKind::idle;

        port powerIn : PowerPort;
        port controlPort : CommandPort;
        port commPort : InterModuleCommPort[0..6];
        port bondingFace : BondingInterfacePort[6];

        part processor {
            attribute clockFreq : FrequencyValue;
            attribute memory : Integer;
        }

        part sensingSystem {
            port proximityOut {
                out proximityData : ProximityData;
            }
            action senseNeighbors : SenseNeighbors;
        }

        part actuationSystem {
            port movementOut {
                out movementExecuted : Boolean;
            }
            attribute maxSpeed : SpeedValue;
            action move : Move;
        }

        part bondingMechanism {
            attribute bondType : String;
            attribute bondStrength : ForceValue;
            action bond : Bond;
            action unbond : Unbond;
        }

        state moduleBehavior : ModuleStateMachine;

        action executeReconfigurationStep {
            in cmd : MovementCommand;
            in bondCmds : BondingCommand[*];
            out statusReport : ModuleStatus;

            action sense : SenseNeighbors;
            action releaseBonds : Unbond;
            action moveToTarget : Move;
            action establishBonds : Bond;
            action reportStatus {
                out statusReport;
            }

            then sense;
            then releaseBonds;
            then moveToTarget;
            then establishBonds;
            then reportStatus;
        }
    }

    part def ControlSystem {
        port moduleControlPort : CommandPort[*];
        port shapeInputPort : ShapeInputPort;

        attribute currentPlan : MovementCommand[*];
        attribute activeBondCommands : BondingCommand[*];

        action orchestrateTransformation {
            in target : TargetShape;
            out plan : MovementCommand[*];
            out bondPlan : BondingCommand[*];

            action analyzeShape : AnalyzeShape;
            action planPaths : PlanPaths;
            action synchronizeModules : SynchronizeModules;
            action dispatchCommands : DispatchCommands;
            action monitorProgress : MonitorProgress;

            flow of MovementCommand from analyzeShape.moduleAssignments to planPaths.assignments;
            flow of MovementCommand from planPaths.collisionFreePlan to synchronizeModules.plan;
            flow of MovementCommand from synchronizeModules.plan to dispatchCommands.finalPlan;
            flow of SynchronizationMessage from synchronizeModules.syncMessages to dispatchCommands.syncs;

            then analyzeShape;
            then planPaths;
            then synchronizeModules;
            then dispatchCommands;
            then monitorProgress;
        }

        state controlBehavior : ControlStateMachine;
    }

    part def EnergySystem {
        port powerOutputPort : PowerPort[*];
        attribute totalCapacity : EnergyValue;
        attribute currentOutput : PowerValue;
        attribute distributionEfficiency : Real;

        action distributePower : DistributePower;

        state energyBehavior : EnergyStateMachine;
    }

    part def ProgrammableMatterRobot {
        part controlSystem : ControlSystem;
        part energySystem : EnergySystem;
        part modularUnits : ModularUnit[16..*];

        connect energySystem.powerOutputPort to modularUnits.powerIn;
        connect controlSystem.moduleControlPort to modularUnits.controlPort;

        action reconfigureToShape {
            in target : TargetShape;

            assert constraint shapeComplete {
                controlSystem.orchestrateTransformation.monitorProgress.complete == true
            }
        }
    }

    requirement def ReconfigurationRequirement {
        subject robot : ProgrammableMatterRobot;
        attribute maxReconfigurationTime : DurationValue;
        attribute minModuleCount : Natural = 16;
        require {
            robot.modularUnits->size() >= minModuleCount;
        }
    }

    requirement def ModuleAutonomyRequirement {
        subject unit : ModularUnit;
        attribute minMemory : Integer = 1024;
        require {
            unit.processor.memory >= minMemory;
        }
    }

    requirement def PowerDistributionRequirement {
        subject energy : EnergySystem;
        attribute minEfficiency : Real = 0.85;
        require {
            energy.distributionEfficiency >= minEfficiency;
        }
    }

    requirement def CollisionAvoidanceRequirement {
        subject control : ControlSystem;
        require {
            control.currentPlan->size() > 0;
        }
    }

    requirement def SixFaceBondingRequirement {
        subject unit : ModularUnit;
        require {
            unit.bondingFace->size() == 6;
        }
    }
}
