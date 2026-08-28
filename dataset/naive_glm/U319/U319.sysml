package NailClipperModel {
    import ScalarValues::*;
    
    attribute def Newton;
    attribute def Millimeter;
    attribute def MegaPascal;
    attribute def Degree;
    
    value type ForceValue :> Real {
        unit = Newton;
    }
    
    value type LengthValue :> Real {
        unit = Millimeter;
    }
    
    value type StressValue :> Real {
        unit = MegaPascal;
    }
    
    value type AngleValue :> Real {
        unit = Degree;
    }
    
    item def Nail {
        attribute thickness : LengthValue;
        attribute shearStrength : StressValue = 50.0;
    }
    
    item def NailFragment {
        attribute thickness : LengthValue;
    }
    
    requirement def CuttingPerformanceRequirement {
        subject clipper : NailClipper;
        requirement {
            constraint { clipper.maxNailThickness <= 2.0 }
            constraint { clipper.maxGripForce <= 50.0 }
        }
    }
    
    requirement def PivotPinRobustnessRequirement {
        subject pin : PivotPin;
        requirement {
            constraint { pin.yieldStrength >= 600.0 }
            constraint { pin.safetyFactor >= 2.0 }
        }
    }
    
    part def PivotPin {
        attribute diameter : LengthValue = 1.5;
        attribute yieldStrength : StressValue = 800.0;
        attribute safetyFactor : Real = 3.0;
        port in shearForceIn : ForceValue;
    }
    
    part def UpperLever {
        attribute leverArm : LengthValue = 40.0;
        attribute contactArm : LengthValue = 5.0;
        
        port in userGripForce : ForceValue;
        port out contactForce : ForceValue;
    }
    
    part def FixedBlade {
        attribute edgeAngle : AngleValue = 45.0;
        port in bladeReactionForce : ForceValue;
    }
    
    part def LowerLeverAndMovingBlade {
        attribute leverArm : LengthValue = 40.0;
        attribute contactArm : LengthValue = 5.0;
        attribute bladeEdgeAngle : AngleValue = 45.0;
        
        port in userGripForce : ForceValue;
        port in upperLeverContactForce : ForceValue;
        port out bladeForce : ForceValue;
        port out pivotPinShearForce : ForceValue;
    }
    
    action def CutNailAction {
        in appliedForce : ForceValue;
        in nail : Nail;
        out fragment : NailFragment;
    }
    
    part def NailClipper {
        attribute maxNailThickness : LengthValue = 2.0;
        attribute maxGripForce : ForceValue = 50.0;
        
        part upperLever : UpperLever;
        part lowerLeverBlade : LowerLeverAndMovingBlade;
        part fixedBlade : FixedBlade;
        part pivotPin : PivotPin;
        
        item in nailToCut : Nail;
        item out cutFragment : NailFragment;
        
        port in gripForceUpper : ForceValue;
        port in gripForceLower : ForceValue;
        
        connect gripForceUpper to upperLever.userGripForce;
        connect gripForceLower to lowerLeverBlade.userGripForce;
        connect upperLever.contactForce to lowerLeverBlade.upperLeverContactForce;
        connect lowerLeverBlade.bladeForce to fixedBlade.bladeReactionForce;
        connect lowerLeverBlade.pivotPinShearForce to pivotPin.shearForceIn;
        
        state clipperStateMachine {
            state Open;
            state Cutting {
                action cutNail : CutNailAction {
                    in appliedForce = lowerLeverBlade.bladeForce;
                    in nail = nailToCut;
                    out fragment = cutFragment;
                }
            }
            transition from Open to Cutting when (gripForceUpper > 5.0 && nailToCut != null);
            transition from Cutting to Open when (gripForceUpper < 1.0);
        }
        
        requirement cuttingReq : CuttingPerformanceRequirement {
            subject clipper = this;
        }
        
        requirement pinReq : PivotPinRobustnessRequirement {
            subject pin = pivotPin;
        }
    }
}
