package TweezersSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def LengthValue :> ISQ::length {
        unit = SI::millimetre;
    }

    attribute def ForceValue :> ISQ::force {
        unit = SI::newton;
    }

    attribute def StiffnessValue {
        :>> scalarType = Real;
        unit = "N/mm";
    }

    attribute def AngleValue :> ISQ::planeAngle {
        unit = SI::degree;
    }

    attribute def MassValue :> ISQ::mass {
        unit = SI::gram;
    }

    attribute def CoefficientValue {
        :>> scalarType = Real;
    }

    attribute def BooleanStatus {
        :>> scalarType = Boolean;
    }

    item def SmallObject {
        attribute mass : MassValue;
        attribute width : LengthValue;
        attribute fragile : BooleanStatus;
    }

    item def UserFingerForce {
        attribute magnitude : ForceValue;
        attribute leftArmShare : ForceValue;
        attribute rightArmShare : ForceValue;
    }

    item def GripForce {
        attribute magnitude : ForceValue;
        attribute normalComponent : ForceValue;
        attribute frictionComponent : ForceValue;
    }

    item def ObjectTransfer {
        attribute held : BooleanStatus;
        attribute centeredBetweenTips : BooleanStatus;
    }

    port def FingerContactPort {
        in item appliedForce : UserFingerForce;
    }

    port def TipContactPort {
        inout item workpiece : SmallObject;
        out item deliveredGripForce : GripForce;
    }

    port def StructuralJoinPort {
        in item armReaction : GripForce;
        out item restoringForce : GripForce;
    }

    part def TweezersArm {
        attribute armLength : LengthValue;
        attribute armThickness : LengthValue;
        attribute armWidth : LengthValue;
        attribute elasticStiffness : StiffnessValue;
        attribute lateralDeflection : LengthValue;
        attribute materialFrictionCoefficient : CoefficientValue;

        port fingerPad : FingerContactPort;
        port pivotEnd : StructuralJoinPort;
        port grippingTip : TipContactPort;

        action def BendUnderFingerLoad {
            in item fingerInput : UserFingerForce;
            out item tipMotion : ObjectTransfer;

            first start;
            then receiveFingerForce;
            then flexArm;
            then moveTipTowardOppositeTip;
            then done;

            action receiveFingerForce;
            action flexArm;
            action moveTipTowardOppositeTip;
            action done;
        }
    }

    part def LeftArm :> TweezersArm {
        :>> armLength = 95 [SI::millimetre];
        :>> armThickness = 1.2 [SI::millimetre];
        :>> armWidth = 7.0 [SI::millimetre];
        :>> elasticStiffness = 0.42 ["N/mm"];
        :>> materialFrictionCoefficient = 0.45;
    }

    part def RightArm :> TweezersArm {
        :>> armLength = 95 [SI::millimetre];
        :>> armThickness = 1.2 [SI::millimetre];
        :>> armWidth = 7.0 [SI::millimetre];
        :>> elasticStiffness = 0.42 ["N/mm"];
        :>> materialFrictionCoefficient = 0.45;
    }

    part def SpringBackBridge {
        attribute bridgeLength : LengthValue;
        attribute bridgeRadius : LengthValue;
        attribute preloadAngle : AngleValue;
        attribute restoringStiffness : StiffnessValue;

        port leftJoin : StructuralJoinPort;
        port rightJoin : StructuralJoinPort;

        action def RestoreOpenShape {
            in item releasedGrip : GripForce;
            out item restoringGrip : GripForce;

            first start;
            then detectReducedFingerForce;
            then generateElasticRestoringForce;
            then separateTips;
            then done;

            action detectReducedFingerForce;
            action generateElasticRestoringForce;
            action separateTips;
            action done;
        }
    }

    part def SerratedTip {
        attribute tipLength : LengthValue;
        attribute tipWidth : LengthValue;
        attribute contactRadius : LengthValue;
        attribute toothPitch : LengthValue;
        attribute surfaceFrictionCoefficient : CoefficientValue;

        port contact : TipContactPort;

        action def ApplyLocalizedGrip {
            inout item target : SmallObject;
            in item closingForce : GripForce;
            out item controlledGrip : GripForce;

            first start;
            then alignContactFaces;
            then applyNormalForce;
            then resistSlipByFriction;
            then done;

            action alignContactFaces;
            action applyNormalForce;
            action resistSlipByFriction;
            action done;
        }
    }

    part def FingerPad {
        attribute padLength : LengthValue;
        attribute padWidth : LengthValue;
        attribute textureFrictionCoefficient : CoefficientValue;

        port userInterface : FingerContactPort;

        action def ReceiveSqueezeInput {
            in item fingerForce : UserFingerForce;
            out item distributedForce : UserFingerForce;

            first start;
            then spreadFingerLoad;
            then transmitLoadToArm;
            then done;

            action spreadFingerLoad;
            action transmitLoadToArm;
            action done;
        }
    }

    part def Tweezers {
        attribute totalLength : LengthValue = 100 [SI::millimetre];
        attribute nominalOpenTipGap : LengthValue = 8 [SI::millimetre];
        attribute minimumClosedTipGap : LengthValue = 0.2 [SI::millimetre];
        attribute mass : MassValue = 18 [SI::gram];
        attribute maximumRecommendedFingerForce : ForceValue = 18 [SI::newton];
        attribute nominalGripForce : ForceValue = 3.5 [SI::newton];
        attribute safeObjectMassLimit : MassValue = 25 [SI::gram];

        part leftArm : LeftArm;
        part rightArm : RightArm;
        part springBackBridge : SpringBackBridge {
            :>> bridgeLength = 10 [SI::millimetre];
            :>> bridgeRadius = 3 [SI::millimetre];
            :>> preloadAngle = 7 [SI::degree];
            :>> restoringStiffness = 0.84 ["N/mm"];
        }

        part leftTip : SerratedTip {
            :>> tipLength = 12 [SI::millimetre];
            :>> tipWidth = 1.5 [SI::millimetre];
            :>> contactRadius = 0.35 [SI::millimetre];
            :>> toothPitch = 0.5 [SI::millimetre];
            :>> surfaceFrictionCoefficient = 0.55;
        }

        part rightTip : SerratedTip {
            :>> tipLength = 12 [SI::millimetre];
            :>> tipWidth = 1.5 [SI::millimetre];
            :>> contactRadius = 0.35 [SI::millimetre];
            :>> toothPitch = 0.5 [SI::millimetre];
            :>> surfaceFrictionCoefficient = 0.55;
        }

        part leftFingerPad : FingerPad {
            :>> padLength = 38 [SI::millimetre];
            :>> padWidth = 8 [SI::millimetre];
            :>> textureFrictionCoefficient = 0.60;
        }

        part rightFingerPad : FingerPad {
            :>> padLength = 38 [SI::millimetre];
            :>> padWidth = 8 [SI::millimetre];
            :>> textureFrictionCoefficient = 0.60;
        }

        port leftFingerInput : FingerContactPort;
        port rightFingerInput : FingerContactPort;
        port leftWorkpieceContact : TipContactPort;
        port rightWorkpieceContact : TipContactPort;

        connect leftFingerInput to leftFingerPad.userInterface;
        connect rightFingerInput to rightFingerPad.userInterface;
        connect leftFingerPad.userInterface to leftArm.fingerPad;
        connect rightFingerPad.userInterface to rightArm.fingerPad;
        connect leftArm.pivotEnd to springBackBridge.leftJoin;
        connect rightArm.pivotEnd to springBackBridge.rightJoin;
        connect leftArm.grippingTip to leftTip.contact;
        connect rightArm.grippingTip to rightTip.contact;
        connect leftTip.contact to leftWorkpieceContact;
        connect rightTip.contact to rightWorkpieceContact;

        action def PickAndHoldSmallObject {
            in item objectToPick : SmallObject;
            in item squeeze : UserFingerForce;
            out item transfer : ObjectTransfer;

            first start;
            then receiveSqueeze;
            then elasticallyDeflectArms;
            then closeTipGap;
            then contactObject;
            then generateOpposedGripForces;
            then holdObjectWhileFingerForceMaintained;
            then releaseWhenSqueezeIsRemoved;
            then done;

            action receiveSqueeze;
            action elasticallyDeflectArms;
            action closeTipGap;
            action contactObject;
            action generateOpposedGripForces;
            action holdObjectWhileFingerForceMaintained;
            action releaseWhenSqueezeIsRemoved;
            action done;
        }

        state def TweezersOperationalState {
            state Open;
            state Closing;
            state Gripping;
            state Holding;
            state Releasing;
            state ReturnedOpen;

            entry action initializeOpenGap;
            transition first Open;
            transition Open to Closing
                accept UserFingerForce
                if appliedForce.magnitude > 0.5 [SI::newton];

            transition Closing to Gripping
                accept SmallObject
                if nominalOpenTipGap > minimumClosedTipGap;

            transition Gripping to Holding
                if nominalGripForce >= 1.0 [SI::newton];

            transition Holding to Releasing
                accept UserFingerForce
                if appliedForce.magnitude <= 0.5 [SI::newton];

            transition Releasing to ReturnedOpen
                if nominalOpenTipGap == 8 [SI::millimetre];

            transition ReturnedOpen to Closing
                accept UserFingerForce
                if appliedForce.magnitude > 0.5 [SI::newton];

            action initializeOpenGap;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The tweezers shall allow a user to pick up, position, hold, and release a small object by converting opposed finger squeeze force into controlled tip gripping force. */

        subject tweezers : Tweezers;

        require constraint {
            tweezers.nominalOpenTipGap >= 6 [SI::millimetre] and
            tweezers.minimumClosedTipGap <= 0.5 [SI::millimetre] and
            tweezers.nominalGripForce >= 1 [SI::newton]
        }
    }

    requirement def ElasticReturnRequirement {
        doc /* When finger force is removed, the tweezers shall return the tips to the open position without external reset. */

        subject tweezers : Tweezers;

        require constraint {
            tweezers.nominalOpenTipGap == 8 [SI::millimetre]
        }
    }

    requirement def ObjectProtectionRequirement {
        doc /* The tweezers shall provide sufficient grip for small-object manipulation while limiting recommended user squeeze force to avoid crushing fragile objects. */

        subject tweezers : Tweezers;

        require constraint {
            tweezers.maximumRecommendedFingerForce <= 18 [SI::newton] and
            tweezers.safeObjectMassLimit >= 10 [SI::gram]
        }
    }

    requirement def TipAlignmentRequirement {
        doc /* Opposing tips shall remain aligned during closure so that the workpiece is contacted from both sides at the same manipulation point. */

        subject tweezers : Tweezers;

        require constraint {
            tweezers.leftTip.tipWidth == tweezers.rightTip.tipWidth and
            tweezers.leftTip.contactRadius == tweezers.rightTip.contactRadius
        }
    }

    part tweezersSystem : Tweezers;

    satisfy PrimaryFunctionRequirement by tweezersSystem;
    satisfy ElasticReturnRequirement by tweezersSystem.springBackBridge;
    satisfy ObjectProtectionRequirement by tweezersSystem;
    satisfy TipAlignmentRequirement by tweezersSystem.leftTip, tweezersSystem.rightTip;
}