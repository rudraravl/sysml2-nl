package 'Precision Tweezer System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    public import Definitions::*;
    public import Usages::*;

    package Definitions {
        attribute def LengthValue :> ISQ::LengthValue;
        attribute def ForceValue :> ISQ::ForceValue;
        attribute def MassValue :> ISQ::MassValue;
        attribute def StiffnessValue :> Real;
        attribute def RadiusValue :> ISQ::LengthValue;
        attribute def LeverRatio :> Real;

        item def TargetObject {
            attribute size : LengthValue;
            attribute mass : MassValue;
            attribute fragility : Real;
        }

        part def GripTip {
            attribute tipRadius : RadiusValue;
            attribute surfaceRoughness : LengthValue;
        }

        part def TweezerArm {
            attribute armLength : LengthValue;
            attribute stiffness : StiffnessValue;
            attribute leverRatio : LeverRatio;
            part tip : GripTip[1];
        }

        part def PivotJoint {
            attribute frictionCoefficient : Real;
        }

        connection def ArmToPivot {
            end arm : TweezerArm[1];
            end joint : PivotJoint[1];
        }

        part def PrecisionTweezer {
            attribute maxObjectSize : LengthValue = 8.0 [mm];
            attribute minObjectSize : LengthValue = 0.5 [mm];
            attribute maxGripForce : ForceValue = 5.0 [N];
            attribute minGripForce : ForceValue = 0.5 [N];

            part leftArm : TweezerArm[1];
            part rightArm : TweezerArm[1];
            part pivot : PivotJoint[1];
        }

        action def 'Measure Object' {
            in target : TargetObject;
            out requiredTipGap : LengthValue;
        }

        action def 'Position Tips' {
            in requiredTipGap : LengthValue;
            out aligned : Boolean;
        }

        action def 'Apply Grip Force' {
            in userSqueezeForce : ForceValue;
            in leverRatio : LeverRatio;
            out appliedGripForce : ForceValue;
        }

        action def 'Verify Grasp' {
            in appliedGripForce : ForceValue;
            in objectMass : MassValue;
            in objectFragility : Real;
            out graspSecure : Boolean;
            out graspSafe : Boolean;
        }

        action def 'Adjust Force' {
            in currentGripForce : ForceValue;
            out adjustedGripForce : ForceValue;
        }

        action def 'Transfer Object' {
            in target : TargetObject;
            out destinationReached : Boolean;
        }

        action def 'Release Object' {
            out released : Boolean;
        }

        action def 'Manipulate Object' {
            in target : TargetObject;
            out released : Boolean;
        }

        item def TaskBeginSignal;
        item def AlignedSignal;
        item def GripAppliedSignal;
        item def GraspVerifiedSignal;
        item def GraspFailedSignal;
        item def HoldReadySignal;
        item def TransferCompleteSignal;
        item def ReleaseCompleteSignal;

        state def TweezerStates {
            entry; then idle;
            state idle;
            state approaching;
            state positioning;
            state gripping;
            state adjusting;
            state holding;
            state transferring;
            state releasing;

            transition idle_to_approaching
                first idle accept TaskBeginSignal then approaching;

            transition approaching_to_positioning
                first approaching accept AlignedSignal then positioning;

            transition positioning_to_gripping
                first positioning accept GripAppliedSignal then gripping;

            transition gripping_to_adjusting
                first gripping accept GraspFailedSignal then adjusting;

            transition adjusting_to_gripping
                first adjusting accept GripAppliedSignal then gripping;

            transition gripping_to_holding
                first gripping accept GraspVerifiedSignal then holding;

            transition holding_to_transferring
                first holding accept HoldReadySignal then transferring;

            transition transferring_to_releasing
                first transferring accept TransferCompleteSignal then releasing;

            transition releasing_to_idle
                first releasing accept ReleaseCompleteSignal then idle;
        }

        requirement def 'Size Range Requirement' {
            doc /* The tweezers must handle objects between 0.5 mm and 8 mm. */
            subject tweezer : PrecisionTweezer;
            constraint { 0.5 [mm] <= tweezer.minObjectSize and tweezer.maxObjectSize <= 8.0 [mm] }
        }

        requirement def 'Grip Force Requirement' {
            doc /* The grip force must be between 0.5 N and 5.0 N. */
            subject tweezer : PrecisionTweezer;
            constraint { 0.5 [N] <= tweezer.minGripForce and tweezer.maxGripForce <= 5.0 [N] }
        }

        requirement def 'Safe Handling Requirement' {
            doc /* Tips must be smooth and force limited to avoid damaging delicate components. */
            subject tip : GripTip;
            constraint { tip.surfaceRoughness <= 0.0001 [mm] }
        }

        requirement def 'Symmetrical Design Requirement' {
            doc /* Arms must be symmetrical for precision alignment and balanced grip. */
            subject tweezer : PrecisionTweezer;
            constraint { tweezer.leftArm.armLength == tweezer.rightArm.armLength }
            constraint { tweezer.leftArm.stiffness == tweezer.rightArm.stiffness }
            constraint { tweezer.leftArm.leverRatio == tweezer.rightArm.leverRatio }
        }
    }

    package Usages {
        part precisionTweezer : Definitions::PrecisionTweezer {
            part leftArm : Definitions::TweezerArm {
                attribute armLength : Definitions::LengthValue = 120.0 [mm];
                attribute stiffness : Definitions::StiffnessValue = 50.0;
                attribute leverRatio : Definitions::LeverRatio = 3.0;
                part tip : Definitions::GripTip {
                    attribute tipRadius : Definitions::RadiusValue = 0.5 [mm];
                    attribute surfaceRoughness : Definitions::LengthValue = 0.0001 [mm];
                }
            }
            part rightArm : Definitions::TweezerArm {
                attribute armLength : Definitions::LengthValue = 120.0 [mm];
                attribute stiffness : Definitions::StiffnessValue = 50.0;
                attribute leverRatio : Definitions::LeverRatio = 3.0;
                part tip : Definitions::GripTip {
                    attribute tipRadius : Definitions::RadiusValue = 0.5 [mm];
                    attribute surfaceRoughness : Definitions::LengthValue = 0.0001 [mm];
                }
            }
            part pivot : Definitions::PivotJoint {
                attribute frictionCoefficient : Real = 0.02;
            }

            connection : Definitions::ArmToPivot connect leftArm to pivot;
            connection : Definitions::ArmToPivot connect rightArm to pivot;

            exhibit state tweezerBehavior : Definitions::TweezerStates;

            perform action 'manipulate object' : Definitions::'Manipulate Object' {
                in target : Definitions::TargetObject;
                out released : Boolean;

                action 'measure object' : Definitions::'Measure Object' {
                    in target = 'manipulate object'.target;
                }
                action 'position tips' : Definitions::'Position Tips';
                action 'apply grip force' : Definitions::'Apply Grip Force' {
                    in leverRatio = precisionTweezer.leftArm.leverRatio;
                }
                action 'verify grasp' : Definitions::'Verify Grasp' {
                    in objectMass = 'manipulate object'.target.mass;
                    in objectFragility = 'manipulate object'.target.fragility;
                }
                action 'adjust force' : Definitions::'Adjust Force';
                action 'transfer object' : Definitions::'Transfer Object' {
                    in target = 'manipulate object'.target;
                }
                action 'release object' : Definitions::'Release Object' {
                    out released = 'manipulate object'.released;
                }

                flow 'measure object'.requiredTipGap to 'position tips'.requiredTipGap;
                flow 'apply grip force'.appliedGripForce to 'verify grasp'.appliedGripForce;
                flow 'adjust force'.adjustedGripForce to 'apply grip force'.userSqueezeForce;

                first start;
                then 'measure object';
                then 'position tips';
                then merge applyGrip;
                then 'apply grip force';
                then 'verify grasp';
                then decide;
                    if 'verify grasp'.graspSecure and 'verify grasp'.graspSafe then 'transfer object';
                    else 'adjust force';
                first 'adjust force' then applyGrip;
                first 'transfer object' then 'release object';
                first 'release object' then done;
            }

            requirement 'size range req' : Definitions::'Size Range Requirement' {
                subject tweezer = precisionTweezer;
            }
            requirement 'grip force req' : Definitions::'Grip Force Requirement' {
                subject tweezer = precisionTweezer;
            }
            requirement 'safe handling req' : Definitions::'Safe Handling Requirement' {
                subject tip = leftArm.tip;
            }
            requirement 'symmetrical design req' : Definitions::'Symmetrical Design Requirement' {
                subject tweezer = precisionTweezer;
            }
        }
    }
}
