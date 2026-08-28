package 'Mechanical Lever System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQBase::*;
    private import SI::*;

    attribute def EffortForce :> ForceValue;
    attribute def LoadForce :> ForceValue;
    attribute def EffortArmLength :> LengthValue;
    attribute def LoadArmLength :> LengthValue;
    attribute def LiftHeight :> LengthValue;
    attribute def MechanicalAdvantageValue :> Real;

    attribute def AppliedEffortSignal;
    attribute def ReleaseEffortSignal;
    attribute def LiftSuccessSignal;
    attribute def LiftFailSignal;
    attribute def LowerCompleteSignal;

    port def EffortPort;
    port def LoadPort;
    port def PivotPort;

    constraint def LeverEquilibrium {
        in effortForce : EffortForce;
        in effortArm : EffortArmLength;
        in loadForce : LoadForce;
        in loadArm : LoadArmLength;
        effortForce * effortArm >= loadForce * loadArm
    }

    constraint def MechanicalAdvantageCalc {
        in effortArm : EffortArmLength;
        in loadArm : LoadArmLength;
        out ma : MechanicalAdvantageValue;
        ma == effortArm / loadArm
    }

    constraint def LiftSuccessConstraint {
        in amplifiedForce : LoadForce;
        in loadWeight : LoadForce;
        out success : Boolean;
        success == (amplifiedForce > loadWeight)
    }

    action def ApplyEffort {
        out effortForce : EffortForce;
    }

    action def TransferForce {
        in effortForce : EffortForce;
        in effortArm : EffortArmLength;
        in loadArm : LoadArmLength;
        out amplifiedForce : LoadForce;
        out ma : MechanicalAdvantageValue;
        assert constraint equilibrium : LeverEquilibrium {
            in effortForce = effortForce;
            in effortArm = effortArm;
            in loadForce = amplifiedForce;
            in loadArm = loadArm;
        }
        assert constraint advantage : MechanicalAdvantageCalc {
            in effortArm = effortArm;
            in loadArm = loadArm;
            out ma = ma;
        }
    }

    action def LiftLoad {
        in amplifiedForce : LoadForce;
        in loadWeight : LoadForce;
        out success : Boolean;
        assert constraint liftCheck : LiftSuccessConstraint {
            in amplifiedForce = amplifiedForce;
            in loadWeight = loadWeight;
            out success = success;
        }
    }

    action def HoldLoad {
        in height : LiftHeight;
    }

    action def LowerLoad {
        out height : LiftHeight;
    }

    part def Fulcrum {
        attribute isStationary : Boolean = true;
        port pivotPoint : PivotPort;
    }

    part def LeverArm {
        attribute effortArmLength : EffortArmLength = 2 [m];
        attribute loadArmLength : LoadArmLength = 0.5 [m];
        attribute maxBendingLoad : ForceValue = 5000 [N];
        attribute isStructurallySound : Boolean = true;
        port effortEnd : EffortPort;
        port loadEnd : LoadPort;
        port fulcrumJoint : PivotPort;
    }

    part def EffortSource {
        port effortOutput : EffortPort;
        perform action applyEffort : ApplyEffort;
    }

    part def LoadMass {
        attribute mass : MassValue = 100 [kg];
        attribute weight : LoadForce = 981 [N];
        attribute currentHeight : LiftHeight = 0 [m];
        port loadInput : LoadPort;
    }

    requirement def MechanicalAdvantageRequirement {
        doc /* The effort arm must be longer than the load arm to multiply the input force. */
    }

    requirement def ForceAmplificationRequirement {
        doc /* The amplified force must exceed the load weight for a successful lift. */
    }

    requirement def LeverArmIntegrityRequirement {
        doc /* The lever arm must not bend or break under the maximum applied load. */
    }

    requirement def FulcrumStabilityRequirement {
        doc /* The fulcrum must remain stationary and provide a stable pivot during all operations. */
    }

    part def LeverSystem {
        part fulcrum : Fulcrum;
        part leverArm : LeverArm;
        part effortSource : EffortSource;
        part loadMass : LoadMass;

        perform action transferForce : TransferForce;
        perform action liftLoad : LiftLoad;
        perform action holdLoad : HoldLoad;
        perform action lowerLoad : LowerLoad;

        connection effortConnection connect effortSource.effortOutput to leverArm.effortEnd;
        connection fulcrumConnection connect leverArm.fulcrumJoint to fulcrum.pivotPoint;
        connection loadConnection connect leverArm.loadEnd to loadMass.loadInput;

        exhibit state leverStates {
            entry; then resting;
            state resting;
            transition 'resting-to-active'
                first resting
                accept AppliedEffortSignal
                then active;
            state active {
                entry transferForce;
                do liftLoad;
            }
            transition 'active-to-lifted'
                first active
                accept LiftSuccessSignal
                then lifted;
            transition 'active-to-resting-fail'
                first active
                accept LiftFailSignal
                then resting;
            state lifted {
                do holdLoad;
            }
            transition 'lifted-to-lowering'
                first lifted
                accept ReleaseEffortSignal
                then lowering;
            state lowering {
                do lowerLoad;
            }
            transition 'lowering-to-resting'
                first lowering
                accept LowerCompleteSignal
                then resting;
        }

        requirement mechAdvReq : MechanicalAdvantageRequirement;
        requirement forceAmpReq : ForceAmplificationRequirement;
        requirement leverIntegReq : LeverArmIntegrityRequirement;
        requirement fulcrumStabReq : FulcrumStabilityRequirement;
        satisfy mechAdvReq;
        satisfy forceAmpReq;
        satisfy leverIntegReq;
        satisfy fulcrumStabReq;
    }

    part leverSystem : LeverSystem;
}
