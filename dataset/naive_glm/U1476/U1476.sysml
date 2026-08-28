package CompoundPulleySystem {

    // ===== Value Types with Units =====
    package Units {
        scalar value type ForceValue :> Real {
            unit N;
        }
        scalar value type MassValue :> Real {
            unit kg;
        }
        scalar value type LengthValue :> Real {
            unit m;
        }
        scalar value type VelocityValue :> Real {
            unit m_per_s;
        }
        scalar value type DimensionlessValue :> Real {
            unit dimensionless;
        }
        scalar value type EfficiencyValue :> Real {
            unit percent;
        }
        scalar value type StressValue :> Real {
            unit MPa;
        }
        scalar value type AreaValue :> Real {
            unit mm2;
        }
    }

    // ===== Item Types =====
    item def RopeSegment {
        attribute tension : ForceValue;
    }

    // ===== Core Component Definitions =====
    part def Axle {
        attribute frictionCoefficient : DimensionlessValue = 0.05;
        attribute maxLoad : ForceValue = 5000.0 [N];
        port in bearingInput : ForceValue;
        port out frictionLoss : ForceValue;
    }

    part def Wheel {
        attribute diameter : LengthValue = 0.1 [m];
        attribute grooveWidth : LengthValue = 0.012 [m];
        port in rotationInput : ForceValue;
        port out rotationOutput : ForceValue;
    }

    part def Pulley {
        part wheel : Wheel;
        part axle : Axle;

        connection ropeContact connect wheel.rotationInput to wheel.rotationOutput;
        connection axleFriction connect axle.bearingInput to axle.frictionLoss;

        attribute efficiency : EfficiencyValue = 92.0 [percent];
    }

    part def FixedPley :> Pulley {
        attribute anchorPoint : String = "stationary";
        attribute directionChange : Boolean = true;
    }

    part def MovablePulley :> Pulley {
        attribute attachedToLoad : Boolean = true;
        attribute travelRange : LengthValue = 2.0 [m];
    }

    part def Rope {
        attribute length : LengthValue = 10.0 [m];
        attribute diameter : LengthValue = 0.008 [m];
        attribute tensileStrength : ForceValue = 12000.0 [N];
        attribute crossSectionArea : AreaValue = 50.27 [mm2];
        attribute currentTension : ForceValue;

        port in effortInput : ForceValue;
        port out tensionOutput : ForceValue;
        port out segment1Tension : ForceValue;
        port out segment2Tension : ForceValue;
    }

    part def Load {
        attribute mass : MassValue = 200.0 [kg];
        attribute weight : ForceValue = 1961.33 [N];
        attribute targetHeight : LengthValue = 1.5 [m];
        attribute currentHeight : LengthValue = 0.0 [m];

        port in liftingForce : ForceValue;
        port out loadWeight : ForceValue;
    }

    // ===== System Definition =====
    part def CompoundPulley {
        attribute mechanicalAdvantage : DimensionlessValue = 2.0;
        attribute systemEfficiency : EfficiencyValue;
        attribute currentRopeTension : ForceValue;

        part fixedPulley : FixedPley;
        part movablePulley : MovablePulley;
        part rope : Rope;
        part load : Load;

        port in userEffort : ForceValue;
        port out liftedLoad : ForceValue;

        // Connections
        connection effortToRope connect userEffort to rope.effortInput;
        connection ropeToFixedPulley connect rope.tensionOutput to fixedPulley.wheel.rotationInput;
        connection fixedToMovable connect fixedPulley.wheel.rotationOutput to movablePulley.wheel.rotationInput;
        connection movableToLoad connect movablePulley.wheel.rotationOutput to load.liftingForce;
        connection loadWeightFeedback connect load.loadWeight to rope.segment2Tension;

        // State Machine
        state def OperatingStates {
            entry;
            state idle {
                entry;
            }
            state loading {
                entry;
            }
            state lifting {
                entry;
            }
            state holding {
                entry;
            }
            state lowering {
                entry;
            }
            transition idle_to_loading
                from idle to loading
                when load.attachedToLoad == true;
            transition loading_to_lifting
                from loading to lifting
                when userEffort > 0.0 [N];
            transition lifting_to_holding
                from lifting to holding
                when load.currentHeight >= load.targetHeight;
            transition holding_to_lowering
                from holding to lowering
                when userEffort < load.weight / 2.0;
            transition lowering_to_idle
                from lowering to idle
                when load.currentHeight <= 0.0 [m];
        }

        // Action Behavior
        action def ComputeMechanicalAdvantage {
            in effort : ForceValue;
            in loadWeight : ForceValue;
            out advantage : DimensionlessValue;
            out efficiency : EfficiencyValue;
            out ropeTension : ForceValue;
        }

        action computeMA : ComputeMechanicalAdvantage {
            in effort = userEffort;
            in loadWeight = load.weight;
            out advantage = mechanicalAdvantage;
            out efficiency = systemEfficiency;
            out ropeTension = currentRopeTension;
        }

        exhibit state behavior : OperatingStates;
    }

    // ===== Requirements =====
    requirement def MechanicalAdvantageRequirement {
        subject pulleySystem : CompoundPulley;
        requirement {
            doc /* The system must provide a mechanical advantage of at least two,
                   effectively halving the force required to lift the load before
                   accounting for friction. */
            constraint { pulleySystem.mechanicalAdvantage >= 2.0 }
        }
    }

    requirement def EfficiencyRequirement {
        subject pulleySystem : CompoundPulley;
        requirement {
            doc /* The system must achieve a target efficiency of over 85%,
                   ensuring most of the user's effort is converted into useful
                   lifting work. */
            constraint { pulleySystem.systemEfficiency > 85.0 [percent] }
        }
    }

    requirement def RopeSafetyRequirement {
        subject pulleySystem : CompoundPulley;
        requirement {
            doc /* The tension experienced by the rope must always remain below
                   its maximum rated tensile strength to prevent failure. */
            constraint { pulleySystem.currentRopeTension < pulleySystem.rope.tensileStrength }
        }
    }

    requirement def LoadCapacityRequirement {
        subject pulleySystem : CompoundPulley;
        requirement {
            doc /* The system must be capable of lifting loads up to the rated
                   capacity of the weakest component. */
            constraint { pulleySystem.load.weight <= pulleySystem.fixedPulley.axle.maxLoad }
        }
    }

    // ===== Verification =====
    verification MechanicalAdvantageVerification
        verifies MechanicalAdvantageRequirement {
        subject testSystem : CompoundPulley;
        objective {
            doc /* Verify mechanical advantage is at least 2.0 under nominal load. */
        }
    }

    verification EfficiencyVerification
        verifies EfficiencyRequirement {
        subject testSystem : CompoundPulley;
        objective {
            doc /* Verify system efficiency exceeds 85% under operating conditions. */
        }
    }

    verification RopeSafetyVerification
        verifies RopeSafetyRequirement {
        subject testSystem : CompoundPulley;
        objective {
            doc /* Verify rope tension remains below tensile strength during all
                   operating states. */
        }
    }

}
