package LeverSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length :> ISQ::length;
    attribute def Force :> ISQ::force;
    attribute def Torque :> ISQ::torque;
    attribute def Angle :> ISQ::planeAngle;
    attribute def Mass :> ISQ::mass;

    item def MechanicalForce {
        attribute magnitude : Force;
        attribute directionAngle : Angle;
        attribute applicationPointDistance : Length;
    }

    item def MechanicalRotation {
        attribute angularDisplacement : Angle;
        attribute angularVelocity;
    }

    item def MechanicalEnergy {
        attribute work;
    }

    port def ForcePort {
        in item appliedForce : MechanicalForce;
        out item reactionForce : MechanicalForce;
    }

    port def LoadPort {
        out item outputForce : MechanicalForce;
        in item loadReaction : MechanicalForce;
    }

    port def PivotPort {
        inout item supportReaction : MechanicalForce;
        inout item rotation : MechanicalRotation;
    }

    part def Fulcrum {
        attribute supportStiffness;
        attribute frictionTorque : Torque = 0.2 [N*m];

        port pivot : PivotPort;
    }

    part def LeverArm {
        attribute totalLength : Length = 1.2 [m];
        attribute effortArmLength : Length = 0.9 [m];
        attribute loadArmLength : Length = 0.3 [m];
        attribute mass : Mass = 2.0 [kg];
        attribute currentAngle : Angle = 0 [rad];
        attribute mechanicalAdvantage = effortArmLength / loadArmLength;

        port effortEnd : ForcePort;
        port fulcrumInterface : PivotPort;
        port loadEnd : LoadPort;

        action computeTorqueBalance {
            in item effort : MechanicalForce;
            in item loadReaction : MechanicalForce;
            out attribute netTorque : Torque;

            netTorque = effort.magnitude * effortArmLength
                      - loadReaction.magnitude * loadArmLength;
        }

        action transmitForce {
            in item effort : MechanicalForce;
            out item loadForce : MechanicalForce;

            loadForce.magnitude = effort.magnitude * mechanicalAdvantage;
            loadForce.applicationPointDistance = loadArmLength;
            loadForce.directionAngle = effort.directionAngle + 3.14159 [rad];
        }
    }

    part def EffortHandle {
        attribute gripLength : Length = 0.15 [m];

        port userInput : ForcePort;
        port leverInterface : ForcePort;

        connection inputToLever connect userInput to leverInterface;
    }

    part def LoadContact {
        attribute contactPadWidth : Length = 0.08 [m];

        port leverOutput : LoadPort;
        port externalLoad : LoadPort;

        connection outputToLoad connect leverOutput to externalLoad;
    }

    part def Lever {
        attribute nominalEffortForce : Force = 120 [N];
        attribute nominalOutputForce : Force = 360 [N];
        attribute nominalMechanicalAdvantage = 3.0;

        part arm : LeverArm;
        part fulcrum : Fulcrum;
        part handle : EffortHandle;
        part contact : LoadContact;

        port effortInput : ForcePort;
        port loadOutput : LoadPort;
        port groundSupport : PivotPort;

        connection effortPath connect effortInput to handle.userInput;
        connection handleToArm connect handle.leverInterface to arm.effortEnd;
        connection armToFulcrum connect arm.fulcrumInterface to fulcrum.pivot;
        connection fulcrumToGround connect fulcrum.pivot to groundSupport;
        connection armToContact connect arm.loadEnd to contact.leverOutput;
        connection contactToOutput connect contact.externalLoad to loadOutput;

        action amplifyInputForce {
            in item inputForce : MechanicalForce;
            out item amplifiedForce : MechanicalForce;

            amplifiedForce.magnitude = inputForce.magnitude * arm.mechanicalAdvantage;
            amplifiedForce.applicationPointDistance = arm.loadArmLength;
            amplifiedForce.directionAngle = inputForce.directionAngle + 3.14159 [rad];
        }

        state def LeverOperatingStates {
            entry action initialize {
                arm.currentAngle = 0 [rad];
            }

            state Idle;
            state EffortApplied;
            state LoadMoving;
            state Balanced;
            state Released;

            transition initial then Idle;

            transition Idle_to_EffortApplied
                first Idle
                accept item input : MechanicalForce
                if input.magnitude > 0 [N]
                then EffortApplied;

            transition EffortApplied_to_LoadMoving
                first EffortApplied
                if nominalOutputForce > 0 [N]
                then LoadMoving;

            transition LoadMoving_to_Balanced
                first LoadMoving
                if arm.currentAngle >= 0.35 [rad]
                then Balanced;

            transition Balanced_to_Released
                first Balanced
                accept item releaseCommand
                then Released;

            transition Released_to_Idle
                first Released
                then Idle;
        }
    }

    part def LeverBasedSystem {
        attribute systemPurpose = "Use rotation about a fulcrum to convert an applied effort force into a larger output force over a shorter distance.";
        attribute primaryFunction = "Amplify and redirect human or actuator input force to move or lift a load.";

        part lever : Lever;

        port operatorEffort : ForcePort;
        port supportedGround : PivotPort;
        port actedUponLoad : LoadPort;

        connection operatorToLever connect operatorEffort to lever.effortInput;
        connection leverToGround connect supportedGround to lever.groundSupport;
        connection leverToLoad connect actedUponLoad to lever.loadOutput;

        action performPrimaryFunction {
            in item effortForce : MechanicalForce;
            out item loadForce : MechanicalForce;

            loadForce.magnitude = effortForce.magnitude
                                * lever.arm.effortArmLength
                                / lever.arm.loadArmLength;
            loadForce.applicationPointDistance = lever.arm.loadArmLength;
            loadForce.directionAngle = effortForce.directionAngle + 3.14159 [rad];
        }
    }

    requirement def ForceAmplificationRequirement {
        subject leverSystem : LeverBasedSystem;

        require constraint {
            leverSystem.lever.arm.mechanicalAdvantage >= 2.5
        }

        doc /* The lever shall provide useful force amplification by maintaining an effort arm substantially longer than the load arm. */
    }

    requirement def StableFulcrumRequirement {
        subject leverSystem : LeverBasedSystem;

        require constraint {
            leverSystem.lever.fulcrum.frictionTorque <= 0.5 [N*m]
        }

        doc /* The fulcrum shall allow rotation with limited friction while providing a stable support reaction. */
    }

    requirement def PrimaryFunctionRequirement {
        subject leverSystem : LeverBasedSystem;

        require constraint {
            leverSystem.primaryFunction == "Amplify and redirect human or actuator input force to move or lift a load."
        }

        doc /* The system shall perform the high-level function of transforming effort force into load-moving output force through lever action. */
    }

    requirement def GeometryRequirement {
        subject leverSystem : LeverBasedSystem;

        require constraint {
            leverSystem.lever.arm.effortArmLength + leverSystem.lever.arm.loadArmLength
            == leverSystem.lever.arm.totalLength
        }

        doc /* The total lever arm length shall equal the sum of the effort-side and load-side arm lengths. */
    }

    satisfy ForceAmplificationRequirement by LeverBasedSystem::lever;
    satisfy StableFulcrumRequirement by LeverBasedSystem::lever::fulcrum;
    satisfy PrimaryFunctionRequirement by LeverBasedSystem;
    satisfy GeometryRequirement by LeverBasedSystem::lever::arm;
}