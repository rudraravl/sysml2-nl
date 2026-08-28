package LeverMechanicalSystem {

    import ScalarValues::Real;
    import ScalarValues::Boolean;
    import ScalarValues::String;
    import ScalarValues::Integer;

    // ============================================================
    // Unit Definitions
    // ============================================================
    unit N;
    unit m;
    unit kg;
    unit m_per_s2;

    // ============================================================
    // Value Type Definitions
    // ============================================================
    value def ForceValue :> Real {
        unit N;
    }

    value def DistanceValue :> Real {
        unit m;
    }

    value def MassValue :> Real {
        unit kg;
    }

    value def AccelerationValue :> Real {
        unit m_per_s2;
    }

    value def Dimensionless :> Real;

    // ============================================================
    // Item Definitions
    // ============================================================
    item def ForceFlow {
        attribute magnitude : ForceValue;
        attribute applicationPoint : DistanceValue;
        attribute direction : String;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def ForceOutputPort {
        out item forceFlow : ForceFlow;
    }

    port def ForceInputPort {
        in item forceFlow : ForceFlow;
    }

    port def FulcrumInterfacePort;

    // ============================================================
    // Part Definition: Fulcrum
    // ============================================================
    part def Fulcrum {
        attribute stable : Boolean = true;
        attribute fixed : Boolean = true;
        attribute maxReactionForce : ForceValue;
        attribute pivotPosition : DistanceValue = 0.0;
        attribute reactionForce : ForceValue = 0.0;

        port pivotInterface : FulcrumInterfacePort;

        action resistReaction {
            in appliedLoad : ForceValue;
            in effortInput : ForceValue;
            out reactionOut : ForceValue;
        }
    }

    // ============================================================
    // Part Definition: Lever Arm
    // ============================================================
    part def LeverArm {
        // Geometry
        attribute totalLength : DistanceValue;
        attribute effortArmLength : DistanceValue;
        attribute loadArmLength : DistanceValue;

        // Mechanical advantage (derived)
        attribute mechanicalAdvantage : Dimensionless = effortArmLength / loadArmLength;

        // Structural properties
        attribute maxBendingStress : ForceValue;
        attribute currentBendingStress : ForceValue = 0.0;
        attribute structurallySound : Boolean = true;

        // Operational values
        attribute inputForce : ForceValue = 0.0;
        attribute amplifiedForce : ForceValue = 0.0;
        attribute loadWeight : ForceValue;
        attribute effortApplied : Boolean = false;
        attribute atTargetHeight : Boolean = false;
        attribute effortReleased : Boolean = false;
        attribute loadSettled : Boolean = true;
        attribute liftSuccessful : Boolean = false;

        // Ports
        port effortEnd : ForceInputPort;
        port loadEnd : ForceOutputPort;
        port fulcrumContact : FulcrumInterfacePort;

        // Action: compute amplified force
        action computeAmplifiedForce {
            in inputForceVal : ForceValue;
            in ma : Dimensionless;
            out amplifiedForceOut : ForceValue;
        }

        // Action: compute bending stress on arm
        action computeBendingStress {
            in load : ForceValue;
            in armLength : DistanceValue;
            out stress : ForceValue;
        }

        // Action: check structural integrity
        action checkStructuralIntegrity {
            in stress : ForceValue;
            in maxStress : ForceValue;
            out sound : Boolean;
        }

        // State Machine: Lever Operation
        state machine LeverOperationStateMachine {
            initial;

            state Rest;
            state Active;
            state Lifting;
            state Holding;
            state Lowering;

            transition initial to Rest;
            transition Rest to Active when effortApplied;
            transition Active to Lifting when amplifiedForce > loadWeight;
            transition Lifting to Holding when atTargetHeight;
            transition Holding to Lowering when effortReleased;
            transition Lowering to Rest when loadSettled;
        }
    }

    // ============================================================
    // Part Definition: Effort Source
    // ============================================================
    part def EffortSource {
        attribute appliedForce : ForceValue;
        attribute effortPosition : DistanceValue;
        attribute sourceType : String;

        port outputPort : ForceOutputPort;

        action applyForce {
            out forceOutput : ForceFlow;
        }

        action releaseForce {
            out released : Boolean;
        }
    }

    // ============================================================
    // Part Definition: Load Mass
    // ============================================================
    part def LoadMass {
        attribute mass : MassValue;
        attribute weight : ForceValue;
        attribute currentHeight : DistanceValue = 0.0;
        attribute targetHeight : DistanceValue;
        attribute lifted : Boolean = false;

        port loadInterface : ForceInputPort;

        // Gravitational acceleration constant
        attribute gravitationalAcceleration : AccelerationValue = 9.8;

        action computeWeight {
            in massVal : MassValue;
            in g : AccelerationValue;
            out weightOut : ForceValue;
        }

        action updateHeight {
            in deltaHeight : DistanceValue;
            out newHeight : DistanceValue;
        }

        action checkLifted {
            in weight : ForceValue;
            in appliedForce : ForceValue;
            out isLifted : Boolean;
        }
    }

    // ============================================================
    // Part Definition: Lever System Assembly
    // ============================================================
    part def LeverSystemAssembly {

        part fulcrum : Fulcrum {
            attribute maxReactionForce : ForceValue = 10000.0;
            attribute stable : Boolean = true;
            attribute fixed : Boolean = true;
            attribute pivotPosition : DistanceValue = 0.0;
        }

        part leverArm : LeverArm {
            attribute totalLength : DistanceValue = 2.5;
            attribute effortArmLength : DistanceValue = 2.0;
            attribute loadArmLength : DistanceValue = 0.5;
            attribute maxBendingStress : ForceValue = 5000.0;
            attribute loadWeight : ForceValue = 980.0;
        }

        part effortSource : EffortSource {
            attribute appliedForce : ForceValue = 250.0;
            attribute effortPosition : DistanceValue = 2.0;
            attribute sourceType : String = "Human";
        }

        part loadMass : LoadMass {
            attribute mass : MassValue = 100.0;
            attribute weight : ForceValue = 980.0;
            attribute targetHeight : DistanceValue = 1.0;
            attribute currentHeight : DistanceValue = 0.0;
        }

        // Connections
        connect effortSource.outputPort to leverArm.effortEnd;
        connect leverArm.loadEnd to loadMass.loadInterface;
        connect leverArm.fulcrumContact to fulcrum.pivotInterface;
    }

    // ============================================================
    // Requirement Definitions
    // ============================================================
    requirement def StructuralIntegrityRequirement {
        doc "The lever arm must remain structurally sound without bending or breaking under load.";
        subject leverArm : LeverArm;
        constraint bendingStressConstraint {
            leverArm.currentBendingStress < leverArm.maxBendingStress
        }
        constraint structuralSoundnessConstraint {
            leverArm.structurallySound == true
        }
    }

    requirement def FulcrumStabilityRequirement {
        doc "The fulcrum provides a stable, unmoving pivot point for the entire operation.";
        subject fulcrum : Fulcrum;
        constraint stabilityConstraint {
            fulcrum.stable == true
        }
        constraint fixedConstraint {
            fulcrum.fixed == true
        }
        constraint reactionCapacityConstraint {
            fulcrum.reactionForce <= fulcrum.maxReactionForce
        }
    }

    requirement def MechanicalAdvantageRequirement {
        doc "The effort arm must be longer than the load arm to achieve mechanical advantage greater than one.";
        subject leverArm : LeverArm;
        constraint effortArmGreaterThanLoadArm {
            leverArm.effortArmLength > leverArm.loadArmLength
        }
        constraint advantageGreaterThanOne {
            leverArm.mechanicalAdvantage > 1.0
        }
    }

    requirement def LiftCapabilityRequirement {
        doc "The amplified effort force must exceed the load weight to successfully lift the load.";
        subject leverSystem : LeverSystemAssembly;
        constraint amplifiedForceExceedsLoad {
            leverSystem.effortSource.appliedForce * leverSystem.leverArm.mechanicalAdvantage > leverSystem.loadMass.weight
        }
    }

    requirement def StateBehaviorRequirement {
        doc "The lever must operate through the sequence: Rest, Active, Lifting, Holding, Lowering, and return to Rest.";
        subject leverArm : LeverArm;
        constraint restToActiveTransition {
            leverArm.effortApplied == true implies leverArm.loadSettled == false
        }
        constraint liftCondition {
            leverArm.amplifiedForce > leverArm.loadWeight implies leverArm.liftSuccessful == true
        }
    }
}
