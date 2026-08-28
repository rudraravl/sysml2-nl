package PrecisionTweezerSystem {
    import ISQ::*;
    import ScalarValues::*;

    attribute def Length :> Real { unit = "mm"; }
    attribute def Force :> Real { unit = "N"; }
    attribute def Mass :> Real { unit = "g"; }
    attribute def Stiffness :> Real { unit = "N/mm"; }
    attribute def Radius :> Real { unit = "mm"; }
    attribute def LeverRatio :> Real { }

    item def SmallObject {
        attribute size : Length;
        attribute mass : Mass;
        attribute fragility : Force;
    }

    requirement def HandleObjectSize {
        doc /* The system must handle objects within a specific size range (0.5 mm to 8 mm). */
        attribute minSize : Length = 0.5;
        attribute maxSize : Length = 8.0;
        subject object : SmallObject;
        constraint { minSize <= object.size <= maxSize }
    }

    requirement def ControlGripForce {
        doc /* The system must apply a controlled and precise grip force (0.5 N to 5.0 N). */
        attribute minForce : Force = 0.5;
        attribute maxForce : Force = 5.0;
        subject appliedForce : Force;
        constraint { minForce <= appliedForce <= maxForce }
    }

    requirement def SafeHandling {
        doc /* Ensure safe handling of delicate components through smooth tips and force limitations. */
        subject object : SmallObject;
        subject appliedForce : Force;
        constraint { appliedForce < object.fragility }
    }

    requirement def SymmetricalDesign {
        doc /* The symmetrical design of the arms is critical for maintaining precision alignment and a balanced grip. */
        subject leftArm : Arm;
        subject rightArm : Arm;
        constraint { leftArm.length == rightArm.length and leftArm.stiffness == rightArm.stiffness }
    }

    part def GripTip {
        attribute radius : Radius = 2.0;
        attribute smoothness : String = "polished";
        port contactSurface;
    }

    part def Arm {
        attribute length : Length = 120.0;
        attribute stiffness : Stiffness = 10.0;
        attribute leverRatio : LeverRatio = 3.0;
        
        port pivotPoint;
        port userGripPoint;
        port tipMount;
        
        part gripTip : GripTip {
            connect contactSurface to tipMount;
        }
    }

    part def PivotJoint {
        port leftPivot;
        port rightPivot;
        attribute friction : Real = 0.01;
    }

    part def PrecisionTweezers {
        port leftTipContact;
        port rightTipContact;
        
        part leftArm : Arm;
        part rightArm : Arm;
        part pivot : PivotJoint {
            connect leftPivot to leftArm.pivotPoint;
            connect rightPivot to rightArm.pivotPoint;
        }
        
        connect leftTipContact to leftArm.gripTip.contactSurface;
        connect rightTipContact to rightArm.gripTip.contactSurface;

        attribute currentTipGap : Length;
        attribute appliedForce : Force;

        item object : SmallObject;

        requirement objSizeReq : HandleObjectSize {
            subject :>> object = object;
        }
        requirement forceReq : ControlGripForce {
            subject :>> appliedForce = appliedForce;
        }
        requirement safeReq : SafeHandling {
            subject :>> object = object;
            subject :>> appliedForce = appliedForce;
        }
        requirement symReq : SymmetricalDesign {
            subject :>> leftArm = leftArm;
            subject :>> rightArm = rightArm;
        }

        action measureObjectSize {
            out objectSize : Length;
        }
        action positionAndAlign {
            in objectSize : Length;
            out tipGap : Length;
        }
        action applyGripForce {
            in tipGap : Length;
            out appliedForce : Force;
        }
        action verifyGrasp {
            in appliedForce : Force;
            in object : SmallObject;
            out isSecure : Boolean;
        }
        action transferObject {
            in isSecure : Boolean;
        }
        action releasePressure {
            out tipGap : Length;
        }

        flow measureObjectSize.objectSize to positionAndAlign.objectSize;
        flow positionAndAlign.tipGap to applyGripForce.tipGap;
        flow applyGripForce.appliedForce to verifyGrasp.appliedForce;
        flow verifyGrasp.isSecure to transferObject.isSecure;

        state machine tweezerStates {
            state idle;
            state approaching;
            state positioning;
            state gripping;
            state adjusting;
            state holding;
            state transferring;
            state releasing;

            transition idle_to_approaching first idle then approaching 
                when object.size > 0;
            transition approaching_to_positioning first approaching then positioning;
            transition positioning_to_gripping first positioning then gripping;
            transition gripping_to_adjusting first gripping then adjusting 
                when appliedForce > object.fragility or appliedForce < object.mass * 0.00981;
            transition adjusting_to_gripping first adjusting then gripping;
            transition gripping_to_holding first gripping then holding 
                when appliedForce <= object.fragility and appliedForce >= object.mass * 0.00981;
            transition holding_to_transferring first holding then transferring;
            transition transferring_to_releasing first transferring then releasing;
            transition releasing_to_idle first releasing then idle;
        }
    }
}
