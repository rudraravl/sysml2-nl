package Claytronics {

    import ScalarValues::*;
    import SI::kilogram;
    import SI::metre;
    import SI::newton;
    import SI::volt;
    import SI::ampere;
    import SI::joule;
    import SI::second;
    import SI::hertz;

    // ============================================================
    // Value Types and Units
    // ============================================================

    value type MassValue :> Real {
        unit kilogram;
    }

    value type LengthValue :> Real {
        unit metre;
    }

    value type ForceValue :> Real {
        unit newton;
    }

    value type VoltageValue :> Real {
        unit volt;
    }

    value type CurrentValue :> Real {
        unit ampere;
    }

    value type EnergyValue :> Real {
        unit joule;
    }

    value type TimeValue :> Real {
        unit second;
    }

    value type FrequencyValue :> Real {
        unit hertz;
    }

    value type CoordinateValue :> Real;

    attribute def Vector3D {
        attribute x : CoordinateValue;
        attribute y : CoordinateValue;
        attribute z : CoordinateValue;
    }

    value type Position3D :> Vector3D {
        unit metre;
    }

    // ============================================================
    // Item Definitions
    // ============================================================

    item def TargetShape {
        attribute name : String;
        attribute description : String;
        attribute catomCount : Integer;
        attribute boundingBox : Vector3D;
    }

    item def ReconfigurationCommand {
        attribute sequenceId : Integer;
        attribute targetPosition : Position3D;
        attribute priority : Integer;
        attribute timestamp : TimeValue;
    }

    item def NeighborMessage {
        attribute sourceId : Integer;
        attribute destinationId : Integer;
        attribute messageType : String;
        attribute payload : String;
    }

    item def BondStatusReport {
        attribute catomId : Integer;
        attribute portId : Integer;
        attribute bonded : Boolean;
        attribute bondForce : ForceValue;
    }

    item def CatomStateReport {
        attribute catomId : Integer;
        attribute state : String;
        attribute currentPosition : Position3D;
        attribute neighborCount : Integer;
        attribute targetReached : Boolean;
    }

    // ============================================================
    // Port Definitions
    // ============================================================

    port def CommandPort {
        in reconfigurationCommand : ReconfigurationCommand;
        in targetShape : TargetShape;
        out stateReport : CatomStateReport;
        out bondReport : BondStatusReport;
    }

    port def ElectromagneticPort {
        attribute portId : Integer;
        attribute bonded : Boolean = false;
        attribute bondForce : ForceValue;
        in neighborMessageIn : NeighborMessage;
        out neighborMessageOut : NeighborMessage;
    }

    port def ControllerPort {
        out reconfigurationCommand : ReconfigurationCommand;
        out targetShape : TargetShape;
        in stateReport : CatomStateReport;
        in bondReport : BondStatusReport;
    }

    port def SensePort {
        out neighborDetected : Boolean;
        out localPosition : Position3D;
    }

    port def PowerPort {
        out powerAvailable : Boolean;
        out voltageLevel : VoltageValue;
    }

    port def BondCommandPort {
        in command : ReconfigurationCommand;
        out bondReport : BondStatusReport;
    }

    // ============================================================
    // Sub-Part Definitions
    // ============================================================

    part def PowerSupply {
        attribute capacity : EnergyValue = 1.0;
        attribute currentLevel : EnergyValue = 1.0;
        attribute nominalVoltage : VoltageValue = 3.3;
        attribute maxDischargeCurrent : CurrentValue = 0.5;
        port powerOut : PowerPort;
    }

    part def CatomSensor {
        attribute sensingRange : LengthValue = 0.005;
        attribute samplingRate : FrequencyValue = 100;
        port senseOut : SensePort;
    }

    part def CatomProcessor {
        attribute clockFrequency : FrequencyValue = 100e6;
        attribute memorySize : Integer = 32;
        port powerIn : PowerPort;
        port senseIn : SensePort;
        port posFeedbackIn in currentPosition : Position3D;
        port bondStatusIn in bondReport : BondStatusReport;
        port cmdInterface : CommandPort;
        port actCmdOut out actuatorCommand : ReconfigurationCommand;
        port bondCmdOut out bondCommand : ReconfigurationCommand;
    }

    part def CatomActuator {
        attribute maxForce : ForceValue = 0.001;
        attribute pivotRadius : LengthValue = 0.001;
        port actIn in command : ReconfigurationCommand;
        port posOut out currentPosition : Position3D;
    }

    part def ElectromagneticBondPort {
        attribute portId : Integer;
        attribute active : Boolean = false;
        attribute maxBondForce : ForceValue = 0.05;
        attribute activationVoltage : VoltageValue = 5.0;
        attribute currentBondForce : ForceValue;
        port bondInterface : BondCommandPort;
        port emInterface : ElectromagneticPort;
    }

    // ============================================================
    // Catom
    // ============================================================

    part def Catom {
        attribute catomId : Integer;
        attribute radius : LengthValue = 0.001;
        attribute height : LengthValue = 0.001;
        attribute mass : MassValue = 1.5e-6;
        attribute currentPosition : Position3D;
        attribute targetPosition : Position3D;
        attribute neighborCount : Integer = 0;
        attribute allBondsReleased : Boolean = false;
        attribute finalPositionReached : Boolean = false;
        attribute commandReceived : Boolean = false;
        attribute commandSequenceId : Integer = 0;

        port controllerInterface : CommandPort;
        port emPorts[6] : ElectromagneticPort;

        part power : PowerSupply;
        part sensor : CatomSensor;
        part processor : CatomProcessor;
        part actuator : CatomActuator;
        part bondPorts[6] : ElectromagneticBondPort;

        // Internal connections
        connection powerToProcessor connect power.powerOut to processor.powerIn;
        connection senseToProcessor connect sensor.senseOut to processor.senseIn;
        connection actuatorToProcessor connect actuator.posOut to processor.posFeedbackIn;
        connection processorToActuator connect processor.actCmdOut to actuator.actIn;
        connection processorToBonds connect processor.bondCmdOut to bondPorts[*].bondInterface;
        connection bondsToProcessor connect bondPorts[*].bondInterface to processor.bondStatusIn;
        connection commandDelegation connect controllerInterface to processor.cmdInterface;
        connection emDelegation connect emPorts[*] to bondPorts[*].emInterface;

        state machine CatomStates {

            state idle {
                entry { commandReceived := false; finalPositionReached := false; }
            }

            state reconfiguring {

                state sensing {
                    entry { /* read local environment from sensor */ }
                }

                state detaching {
                    entry { /* release electromagnetic bonds on active ports */ }
                }

                state pivoting {
                    entry { /* pivot around neighbor into adjacent empty space */ }
                }

                state rebonding {
                    entry { /* re-establish electromagnetic bonds at new position */ }
                }

                transition initial to sensing;
                transition sensing to detaching when sensor.senseOut.neighborDetected == true;
                transition detaching to pivoting when allBondsReleased == true;
                transition pivoting to rebonding when currentPosition == targetPosition;
                transition rebonding to sensing when finalPositionReached == false;
            }

            state stable {
                entry { finalPositionReached := true; }
            }

            transition initial to idle;
            transition idle to reconfiguring when commandReceived == true;
            transition reconfiguring to stable when finalPositionReached == true;
            transition stable to reconfiguring when commandReceived == true;
        }
    }

    // ============================================================
    // Ensemble Controller
    // ============================================================

    part def EnsembleController {
        attribute controlledCatoms : Integer = 1000;
        attribute planningAlgorithm : String = "coordinated";
        attribute reconfigurationTimeLimit : TimeValue = 60.0;
        attribute targetShapeReceived : Boolean = false;
        attribute planComplete : Boolean = false;
        attribute allCommandsDispatched : Boolean = false;
        attribute allCatomsStable : Boolean = false;
        attribute shapeVerified : Boolean = false;
        attribute collisionAvoidanceEnabled : Boolean = true;

        port swarmPort[1000] : ControllerPort;

        state machine ControllerStates {

            state awaitingTarget {
                entry { targetShapeReceived := false; shapeVerified := false; }
            }

            state planning {
                entry { planComplete := false; /* calculate final destination for each catom */ }
            }

            state dispatching {
                entry { allCommandsDispatched := false; /* transmit commands to swarm */ }
            }

            state monitoring {
                entry { allCatomsStable := false; /* monitor swarm state reports */ }
            }

            state verified {
                entry { shapeVerified := true; }
            }

            transition initial to awaitingTarget;
            transition awaitingTarget to planning when targetShapeReceived == true;
            transition planning to dispatching when planComplete == true;
            transition dispatching to monitoring when allCommandsDispatched == true;
            transition monitoring to verified when allCatomsStable == true;
            transition verified to awaitingTarget when shapeVerified == true;
        }
    }

    // ============================================================
    // Claytronics System
    // ============================================================

    part def ClaytronicsSystem {
        attribute systemName : String = "ClaytronicsSystem";
        attribute totalCatoms : Integer = 1000;
        attribute initialShape : TargetShape;
        attribute currentTargetShape : TargetShape;

        part controller : EnsembleController;
        part swarm : Catom[1000];

        connection controlLinks connect controller.swarmPort[*] to swarm[*].controllerInterface;

        // Neighbor-to-neighbor electromagnetic bonds between adjacent catoms
        // (illustrative: in practice each catom bonds with up to 6 neighbors)
        connection neighborBonds connect swarm[*].emPorts[*] to swarm[*].emPorts[*];
    }

    // ============================================================
    // Requirements
    // ============================================================

    requirement def ShapeReconfigurationRequirement {
        subject system : ClaytronicsSystem;
        doc
            "The Claytronics system shall reconfigure its catom swarm from an initial three-dimensional shape to a target three-dimensional shape upon receiving a target shape command from the Ensemble Controller.";
    }

    requirement def CatomCountRequirement {
        subject system : ClaytronicsSystem;
        doc
            "The Claytronics system shall comprise a swarm of at least 1000 catoms.";
    }

    requirement def CatomStructureRequirement {
        subject catom : Catom;
        doc
            "Each catom shall be a self-contained cylindrical robot equipped with its own processor, sensors, power supply, and actuator.";
    }

    requirement def ElectromagneticPortRequirement {
        subject catom : Catom;
        doc
            "Each catom shall feature six electromagnetic ports used both to form strong bonds with adjacent catoms and to communicate with neighbors.";
    }

    requirement def CatomStateRequirement {
        subject catom : Catom;
        doc
            "Each catom shall operate in one of three states: idle while awaiting commands, reconfiguring by moving and re-bonding, or stable and bonded to maintain the final object shape.";
    }

    requirement def MovementMechanismRequirement {
        subject catom : Catom;
        doc
            "Each catom shall move by latching onto a neighbor, detaching its electromagnetic bonds, pivoting around the neighboring catom into an adjacent empty space, and re-establishing new bonds.";
    }

    requirement def CollisionAvoidanceRequirement {
        subject system : ClaytronicsSystem;
        doc
            "The Ensemble Controller shall coordinate reconfiguration across the entire swarm to prevent collisions between catoms during movement until the target shape is achieved.";
    }

    requirement def ControllerPlanningRequirement {
        subject controller : EnsembleController;
        doc
            "The Ensemble Controller shall calculate the final destination position for every catom given a target shape and transmit these as commands to the swarm.";
    }

    requirement def ShapeVerificationRequirement {
        subject controller : EnsembleController;
        doc
            "The Ensemble Controller shall verify that the target shape has been achieved by the swarm before completing the reconfiguration process.";
    }

    requirement def CommunicationRequirement {
        subject catom : Catom;
        doc
            "Catoms shall communicate with adjacent catoms through their electromagnetic ports using neighbor messages.";
    }

    requirement def ReconfigurationCycleRequirement {
        subject catom : Catom;
        doc
            "During reconfiguration, each catom shall execute a cycle of sensing its local environment, detaching electromagnetic bonds, pivoting around a neighboring catom, and re-establishing new bonds.";
    }

    // ============================================================
    // Satisfactions
    // ============================================================

    satisfy ShapeReconfigurationRequirement by ClaytronicsSystem;
    satisfy CatomCountRequirement by ClaytronicsSystem;
    satisfy CatomStructureRequirement by Catom;
    satisfy ElectromagneticPortRequirement by Catom;
    satisfy CatomStateRequirement by Catom;
    satisfy MovementMechanismRequirement by Catom;
    satisfy CollisionAvoidanceRequirement by ClaytronicsSystem;
    satisfy ControllerPlanningRequirement by EnsembleController;
    satisfy ShapeVerificationRequirement by EnsembleController;
    satisfy CommunicationRequirement by Catom;
    satisfy ReconfigurationCycleRequirement by Catom;
}
