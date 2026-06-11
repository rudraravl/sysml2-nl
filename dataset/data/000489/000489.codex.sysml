package PenningtonClampSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def ForceValue :> ISQ::force {
        unit = "N";
    }

    attribute def LengthValue :> ISQ::length {
        unit = "mm";
    }

    attribute def AngleValue {
        unit = "deg";
    }

    attribute def PressureValue {
        unit = "kPa";
    }

    attribute def SterilityState {
        enum sterile;
        enum nonSterile;
        enum contaminated;
    }

    item def BiologicalTissue {
        attribute tissueThickness : LengthValue;
        attribute maxSafeCompressionPressure : PressureValue;
        attribute isPerfused : Boolean;
    }

    item def ClampedTissue :> BiologicalTissue {
        attribute retainedWithoutSlippage : Boolean;
        attribute compressionPressure : PressureValue;
    }

    item def SurgeonInput {
        attribute fingerLoopClosureForce : ForceValue;
        attribute requestedJawAngle : AngleValue;
    }

    item def ClampFeedback {
        attribute jawGap : LengthValue;
        attribute ratchetToothEngaged : Integer;
        attribute estimatedTissuePressure : PressureValue;
    }

    port def FingerLoopPort {
        in item input : SurgeonInput;
    }

    port def TissueInterfacePort {
        in item targetTissue : BiologicalTissue;
        out item heldTissue : ClampedTissue;
    }

    port def FeedbackPort {
        out item feedback : ClampFeedback;
    }

    part def PenningtonClamp {
        attribute totalLength : LengthValue = 190 [mm];
        attribute jawLength : LengthValue = 42 [mm];
        attribute maxJawOpeningAngle : AngleValue = 38 [deg];
        attribute maxTipCompressionForce : ForceValue = 28 [N];
        attribute sterility : SterilityState = SterilityState::sterile;

        port leftFingerLoop : FingerLoopPort;
        port rightFingerLoop : FingerLoopPort;
        port tissuePort : TissueInterfacePort;
        port feedbackPort : FeedbackPort;

        part leftHandle {
            attribute loopInnerDiameter : LengthValue = 24 [mm];
            attribute gripSurfaceRoughness : LengthValue = 0.4 [mm];
        }

        part rightHandle {
            attribute loopInnerDiameter : LengthValue = 24 [mm];
            attribute gripSurfaceRoughness : LengthValue = 0.4 [mm];
        }

        part boxLockPivot {
            attribute pivotPinDiameter : LengthValue = 4.5 [mm];
            attribute allowableLateralPlay : LengthValue = 0.15 [mm];
        }

        part ratchetLock {
            attribute toothCount : Integer = 3;
            attribute engagedTooth : Integer = 0;
            attribute releaseForce : ForceValue = 6 [N];
        }

        part shankAssembly {
            attribute leftShankLength : LengthValue = 105 [mm];
            attribute rightShankLength : LengthValue = 105 [mm];
            attribute mechanicalAdvantage : Real = 5.2;
        }

        part triangularJawAssembly {
            attribute closedTipGap : LengthValue = 0.2 [mm];
            attribute fenestrationWidth : LengthValue = 12 [mm];
            attribute fenestrationLength : LengthValue = 24 [mm];
            attribute serrationPitch : LengthValue = 1.2 [mm];

            part leftTriangularJaw {
                attribute jawFaceAngle : AngleValue = 60 [deg];
                attribute contactEdgeRadius : LengthValue = 0.6 [mm];
            }

            part rightTriangularJaw {
                attribute jawFaceAngle : AngleValue = 60 [deg];
                attribute contactEdgeRadius : LengthValue = 0.6 [mm];
            }
        }

        connect leftHandle to shankAssembly;
        connect rightHandle to shankAssembly;
        connect shankAssembly to boxLockPivot;
        connect boxLockPivot to triangularJawAssembly;
        connect rightHandle to ratchetLock;
        connect leftHandle to ratchetLock;
        connect triangularJawAssembly to tissuePort;
        connect ratchetLock to feedbackPort;

        action def ApplyFingerForce {
            in item surgeonCommand : SurgeonInput;
            out attribute jawAngle : AngleValue;
            out attribute tipForce : ForceValue;

            action computeJawClosure {
                in item surgeonCommand;
                out attribute jawAngle;
                out attribute tipForce;
            }
        }

        action def GraspTissue {
            in item target : BiologicalTissue;
            in attribute tipForce : ForceValue;
            out item grasped : ClampedTissue;

            action distributeCompression {
                in item target;
                in attribute tipForce;
                out item grasped;
            }
        }

        action def LockRatchet {
            in attribute tipForce : ForceValue;
            out attribute engagedTooth : Integer;

            action selectTooth {
                in attribute tipForce;
                out attribute engagedTooth;
            }
        }

        state def ClampOperationalState {
            state open;
            state positioning;
            state closing;
            state lockedHolding;
            state releasing;
            state cleaningRequired;

            initial then open;

            transition open_to_positioning
                first open
                accept SurgeonInput
                then positioning;

            transition positioning_to_closing
                first positioning
                accept SurgeonInput
                then closing;

            transition closing_to_locked
                first closing
                if ratchetLock.engagedTooth > 0
                then lockedHolding;

            transition locked_to_releasing
                first lockedHolding
                accept SurgeonInput
                then releasing;

            transition releasing_to_open
                first releasing
                then open;

            transition any_to_cleaning
                first open
                if sterility == SterilityState::contaminated
                then cleaningRequired;
        }

        perform action ApplyFingerForce;
        perform action GraspTissue;
        perform action LockRatchet;
        exhibit state ClampOperationalState;
    }

    part def SurgicalUseContext {
        part clamp : PenningtonClamp;

        part surgeon {
            port leftHandCommand : FingerLoopPort;
            port rightHandCommand : FingerLoopPort;
        }

        part operativeField {
            port tissueAccess : TissueInterfacePort;
            item bowelWall : BiologicalTissue {
                attribute tissueThickness = 3.0 [mm];
                attribute maxSafeCompressionPressure = 75 [kPa];
                attribute isPerfused = true;
            }
        }

        connect surgeon.leftHandCommand to clamp.leftFingerLoop;
        connect surgeon.rightHandCommand to clamp.rightFingerLoop;
        connect clamp.tissuePort to operativeField.tissueAccess;
    }

    requirement def PrimaryFunctionRequirement {
        subject clamp : PenningtonClamp;

        doc /* The Pennington clamp shall provide a high-level function of grasping, holding, and manipulating delicate tissue using fenestrated triangular jaws while limiting localized compression. */

        require constraint {
            clamp.maxTipCompressionForce <= 28 [N]
        }
    }

    requirement def AtraumaticGraspRequirement {
        subject clamp : PenningtonClamp;

        doc /* The clamp shall spread jaw contact over triangular fenestrated surfaces to reduce focal pressure on delicate tissue. */

        require constraint {
            clamp.triangularJawAssembly.serrationPitch >= 1.0 [mm] and
            clamp.triangularJawAssembly.leftTriangularJaw.contactEdgeRadius >= 0.5 [mm]
        }
    }

    requirement def RatchetHoldingRequirement {
        subject clamp : PenningtonClamp;

        doc /* The ratchet shall maintain a selected jaw closure without continuous surgeon hand force. */

        require constraint {
            clamp.ratchetLock.toothCount >= 3 and
            clamp.ratchetLock.releaseForce >= 5 [N]
        }
    }

    requirement def JawOpeningRequirement {
        subject clamp : PenningtonClamp;

        doc /* The jaw assembly shall open widely enough to position around a tissue fold before closure. */

        require constraint {
            clamp.maxJawOpeningAngle >= 35 [deg]
        }
    }

    requirement def SterilityRequirement {
        subject clamp : PenningtonClamp;

        doc /* The clamp shall be sterile before contact with the operative field. */

        require constraint {
            clamp.sterility == SterilityState::sterile
        }
    }

    satisfy PrimaryFunctionRequirement by PenningtonClamp;
    satisfy AtraumaticGraspRequirement by PenningtonClamp::triangularJawAssembly;
    satisfy RatchetHoldingRequirement by PenningtonClamp::ratchetLock;
    satisfy JawOpeningRequirement by PenningtonClamp::triangularJawAssembly;
    satisfy SterilityRequirement by PenningtonClamp;
}