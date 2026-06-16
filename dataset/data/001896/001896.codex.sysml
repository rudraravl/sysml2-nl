package WedgeSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Angle {
        :> scalarValues::Real;
        unit = "deg";
    }

    attribute def Length {
        :> scalarValues::Real;
        unit = "m";
    }

    attribute def Mass {
        :> scalarValues::Real;
        unit = "kg";
    }

    attribute def Force {
        :> scalarValues::Real;
        unit = "N";
    }

    attribute def FrictionCoefficient {
        :> scalarValues::Real;
    }

    attribute def Efficiency {
        :> scalarValues::Real;
    }

    item def LoadItem {
        attribute loadMass : Mass;
        attribute loadWeight : Force;
        attribute contactWidth : Length;
    }

    item def InputPush {
        attribute appliedForce : Force;
        attribute travelDistance : Length;
    }

    item def LiftOutput {
        attribute liftedHeight : Length;
        attribute outputForce : Force;
    }

    port def ForceInputPort {
        in item push : InputPush;
    }

    port def LoadSupportPort {
        inout item supportedLoad : LoadItem;
        out item liftResult : LiftOutput;
    }

    port def GroundReactionPort {
        out attribute normalReaction : Force;
        out attribute frictionReaction : Force;
    }

    port def ContactPort {
        inout attribute normalForce : Force;
        inout attribute tangentialForce : Force;
    }

    part def Wedge {
        attribute length : Length;
        attribute width : Length;
        attribute height : Length;
        attribute slopeAngle : Angle;
        attribute surfaceFriction : FrictionCoefficient;
        attribute mechanicalAdvantage : Real;
        attribute estimatedEfficiency : Efficiency;

        port inputEnd : ForceInputPort;
        port inclinedFace : ContactPort;
        port bottomFace : GroundReactionPort;

        perform action convertHorizontalInputToVerticalLift {
            in item input : InputPush;
            in item load : LoadItem;
            out item result : LiftOutput;

            action computeMechanicalAdvantage {
                in angle : Angle = slopeAngle;
                out advantage : Real;
            }

            action estimateOutputForce {
                in inputForce : Force = input.appliedForce;
                in advantage : Real = mechanicalAdvantage;
                in friction : FrictionCoefficient = surfaceFriction;
                out force : Force;
            }

            action estimateLiftHeight {
                in travel : Length = input.travelDistance;
                in angle : Angle = slopeAngle;
                out heightGain : Length;
            }

            bind result.outputForce = estimatedOutputForce.force;
            bind result.liftedHeight = estimatedLiftHeight.heightGain;
        }

        state def WedgeOperatingStates {
            state idle;
            state engagingLoad;
            state slidingUnderLoad;
            state liftingLoad;
            state holdingPosition;
            state retracting;
            state faultExcessForce;

            entry; then idle;

            transition idle_to_engaging
                first idle
                accept InputPush
                then engagingLoad;

            transition engaging_to_sliding
                first engagingLoad
                if inputEnd.push.appliedForce > 0 [N]
                then slidingUnderLoad;

            transition sliding_to_lifting
                first slidingUnderLoad
                if inclinedFace.normalForce > 0 [N]
                then liftingLoad;

            transition lifting_to_holding
                first liftingLoad
                if inputEnd.push.travelDistance >= length
                then holdingPosition;

            transition holding_to_retracting
                first holdingPosition
                accept InputPush
                then retracting;

            transition overload
                first liftingLoad
                if inputEnd.push.appliedForce > 1200 [N]
                then faultExcessForce;

            transition reset_fault
                first faultExcessForce
                accept InputPush
                then idle;
        }
    }

    part def Load {
        attribute mass : Mass;
        attribute weight : Force;
        attribute baseContactWidth : Length;

        port lowerContact : ContactPort;
        port supportInterface : LoadSupportPort;
    }

    part def Actuator {
        attribute maximumPushForce : Force;
        attribute strokeLength : Length;
        attribute commandedForce : Force;

        port pushPort : ForceInputPort;

        perform action applyPush {
            in desiredForce : Force;
            in desiredTravel : Length;
            out item pushCommand : InputPush;

            bind pushCommand.appliedForce = desiredForce;
            bind pushCommand.travelDistance = desiredTravel;
        }

        state def ActuatorStates {
            state ready;
            state extending;
            state forceLimited;
            state holding;
            state retracting;

            entry; then ready;

            transition start_push
                first ready
                accept InputPush
                then extending;

            transition limit_force
                first extending
                if commandedForce >= maximumPushForce
                then forceLimited;

            transition hold_at_stroke
                first extending
                if pushPort.push.travelDistance >= strokeLength
                then holding;

            transition retract_command
                first holding
                accept InputPush
                then retracting;

            transition retracted
                first retracting
                then ready;
        }
    }

    part def BaseSurface {
        attribute allowableNormalReaction : Force;
        attribute surfaceFriction : FrictionCoefficient;

        port groundContact : GroundReactionPort;
    }

    part def WedgeLiftingSystem {
        attribute requiredLiftHeight : Length = 0.25 [m];
        attribute maximumInputForce : Force = 1000 [N];
        attribute nominalLoadMass : Mass = 100 [kg];

        part wedge : Wedge {
            attribute length = 1.0 [m];
            attribute width = 0.30 [m];
            attribute height = 0.25 [m];
            attribute slopeAngle = 14.0 [deg];
            attribute surfaceFriction = 0.18;
            attribute mechanicalAdvantage = 4.0;
            attribute estimatedEfficiency = 0.78;
        }

        part load : Load {
            attribute mass = 100 [kg];
            attribute weight = 981 [N];
            attribute baseContactWidth = 0.28 [m];
        }

        part actuator : Actuator {
            attribute maximumPushForce = 1000 [N];
            attribute strokeLength = 1.0 [m];
            attribute commandedForce = 300 [N];
        }

        part base : BaseSurface {
            attribute allowableNormalReaction = 2500 [N];
            attribute surfaceFriction = 0.45;
        }

        connect actuator.pushPort to wedge.inputEnd;
        connect wedge.inclinedFace to load.lowerContact;
        connect wedge.bottomFace to base.groundContact;

        perform action liftLoadWithWedge {
            in item command : InputPush;
            in item objectToLift : LoadItem;
            out item lift : LiftOutput;

            first actuator.applyPush(
                desiredForce = command.appliedForce,
                desiredTravel = command.travelDistance
            );

            then wedge.convertHorizontalInputToVerticalLift(
                input = command,
                load = objectToLift
            );

            then action transferLiftToLoad {
                in item wedgeOutput : LiftOutput = wedge.convertHorizontalInputToVerticalLift.result;
                out item deliveredLift : LiftOutput;
                bind deliveredLift.outputForce = wedgeOutput.outputForce;
                bind deliveredLift.liftedHeight = wedgeOutput.liftedHeight;
            }

            bind lift = transferLiftToLoad.deliveredLift;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The wedge system shall transform an applied horizontal pushing force into a vertical lifting force by sliding an inclined rigid body beneath a load. */
        subject system : WedgeLiftingSystem;

        require constraint {
            system.wedge.mechanicalAdvantage > 1.0
        }
    }

    requirement def LiftHeightRequirement {
        doc /* The wedge shall provide the required vertical lift height when driven through its full stroke. */
        subject system : WedgeLiftingSystem;

        require constraint {
            system.wedge.height >= system.requiredLiftHeight
        }
    }

    requirement def InputForceRequirement {
        doc /* The actuator force needed for nominal lifting shall remain within the maximum available input force. */
        subject system : WedgeLiftingSystem;

        require constraint {
            system.actuator.commandedForce <= system.maximumInputForce
        }
    }

    requirement def LoadSupportRequirement {
        doc /* The wedge shall support the nominal load without exceeding the allowable ground reaction. */
        subject system : WedgeLiftingSystem;

        require constraint {
            system.load.weight <= system.base.allowableNormalReaction
        }
    }

    requirement def StableContactRequirement {
        doc /* The wedge shall maintain contact with both the load and base surface during lifting. */
        subject system : WedgeLiftingSystem;

        require constraint {
            system.wedge.width >= system.load.baseContactWidth
        }
    }

    requirement def FrictionEfficiencyRequirement {
        doc /* The wedge shall account for sliding friction while maintaining useful lifting efficiency. */
        subject system : WedgeLiftingSystem;

        require constraint {
            system.wedge.estimatedEfficiency >= 0.70
        }
    }

    satisfy PrimaryFunctionRequirement by WedgeLiftingSystem::liftLoadWithWedge;
    satisfy LiftHeightRequirement by WedgeLiftingSystem::wedge;
    satisfy InputForceRequirement by WedgeLiftingSystem::actuator;
    satisfy LoadSupportRequirement by WedgeLiftingSystem::base;
    satisfy StableContactRequirement by WedgeLiftingSystem::wedge;
    satisfy FrictionEfficiencyRequirement by WedgeLiftingSystem::wedge;

    analysis def WedgePerformanceAnalysis {
        subject system : WedgeLiftingSystem;

        attribute idealMechanicalAdvantage : Real;
        attribute estimatedInputForce : Force;
        attribute availableLiftForce : Force;

        constraint idealAdvantage {
            idealMechanicalAdvantage == system.wedge.length / system.wedge.height
        }

        constraint forceBalance {
            availableLiftForce == system.actuator.commandedForce * system.wedge.mechanicalAdvantage * system.wedge.estimatedEfficiency
        }

        constraint sufficientLift {
            availableLiftForce >= system.load.weight
        }
    }
}