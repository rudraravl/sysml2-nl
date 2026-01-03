package NailClipperSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    item def NailFragment {
        attribute length : ISQ::LengthValue;
        attribute thickness : ISQ::LengthValue;
    }
    
    port def MechanicalInterface;
    port def CuttingInterface;
    port def ForceInterface;
    
    part def UpperLever {
        attribute leverLength : ISQ::LengthValue;
        port gripPoint : MechanicalInterface;
        port pivotPoint : MechanicalInterface;
    }
    
    part def LowerLever {
        attribute leverLength : ISQ::LengthValue;
        port gripPoint : MechanicalInterface;
        port pivotPoint : MechanicalInterface;
        port bladeMount : MechanicalInterface;
    }
    
    part def MovingBlade {
        attribute bladeWidth : ISQ::LengthValue;
        attribute edgeAngle : ISQ::AngleValue;
        port cuttingEdge : CuttingInterface;
        port mountPoint : MechanicalInterface;
    }
    
    part def FixedBlade {
        attribute bladeWidth : ISQ::LengthValue;
        attribute edgeAngle : ISQ::AngleValue;
        port cuttingEdge : CuttingInterface;
        port baseMount : MechanicalInterface;
    }
    
    part def PivotPin {
        attribute diameter : ISQ::LengthValue;
        port upperJoint : MechanicalInterface;
        port lowerJoint : MechanicalInterface;
    }
    
    part def BaseBody {
        port fixedBladeMount : MechanicalInterface;
        port lowerLeverMount : MechanicalInterface;
    }
    
    action def PositionNail {
        in nailLength : ISQ::LengthValue;
        out nailPositioned : Boolean;
    }
    
    action def ApplySqueezeForce {
        in userForce : ISQ::ForceValue;
        in leverRatio : Real;
        out amplifiedForce : ISQ::ForceValue;
    }
    
    action def ConvergeBlades {
        in appliedForce : ISQ::ForceValue;
        in currentGap : ISQ::LengthValue;
        out bladeGap : ISQ::LengthValue;
    }
    
    action def ShearNail {
        in bladeGap : ISQ::LengthValue;
        in nailThickness : ISQ::LengthValue;
        in cuttingPressure : ISQ::PressureValue;
        out nailSevered : Boolean;
        out fragment : NailFragment;
    }
    
    action def ReleaseGrip {
        out leversReset : Boolean;
    }
    
    action def ClipNailProcess {
        in userAppliedForce : ISQ::ForceValue;
        in nailThickness : ISQ::LengthValue;
        in leverMechanicalAdvantage : Real;
        out clippedFragment : NailFragment;
        
        first start;
        
        then action positionNail : PositionNail {
            in nailLength = 5.0 [SI::mm];
            out nailPositioned;
        }
        
        then action applyForce : ApplySqueezeForce {
            in userForce = userAppliedForce;
            in leverRatio = leverMechanicalAdvantage;
            out amplifiedForce;
        }
        
        then action closeBlades : ConvergeBlades {
            in appliedForce = applyForce.amplifiedForce;
            in currentGap = 1.0 [SI::mm];
            out bladeGap;
        }
        
        then action shearNail : ShearNail {
            in bladeGap = closeBlades.bladeGap;
            in nailThickness = nailThickness;
            in cuttingPressure = 50.0 [SI::MPa];
            out nailSevered;
            out fragment;
        }
        
        then decide;
            if shearNail.nailSevered then releaseGrip;
            if not shearNail.nailSevered then applyForce;
        
        action releaseGrip : ReleaseGrip {
            out leversReset;
        }
        
        then assign clippedFragment := shearNail.fragment;
        
        then done;
    }
    
    state def ClipperOperationalStates {
        entry; then open;
        
        state open {
            doc /* Clipper is in open position, ready to receive nail */
        }
        
        transition open_to_closing
            first open
            accept ApplySqueezeForce
            then closing;
        
        state closing {
            doc /* Levers are being squeezed, blades converging */
        }
        
        transition closing_to_cutting
            first closing
            if "blades contact nail"
            then cutting;
        
        state cutting {
            doc /* Blades are actively shearing through nail material */
        }
        
        transition cutting_to_releasing
            first cutting
            if "nail fully severed"
            then releasing;
        
        transition cutting_to_closing
            first cutting
            if "insufficient force applied"
            then closing;
        
        state releasing {
            doc /* User releases grip, spring returns levers to open */
        }
        
        transition releasing_to_open
            first releasing
            then open;
    }
    
    part def NailClipper {
        attribute leverRatio : Real;
        attribute maxCuttingForce : ISQ::ForceValue;
        
        part upperLever : UpperLever {
            attribute :>> leverLength = 45.0 [SI::mm];
        }
        
        part lowerLever : LowerLever {
            attribute :>> leverLength = 40.0 [SI::mm];
        }
        
        part movingBlade : MovingBlade {
            attribute :>> bladeWidth = 12.0 [SI::mm];
            attribute :>> edgeAngle = 35.0 [SI::'°'];
        }
        
        part fixedBlade : FixedBlade {
            attribute :>> bladeWidth = 12.0 [SI::mm];
            attribute :>> edgeAngle = 35.0 [SI::'°'];
        }
        
        part pivot : PivotPin {
            attribute :>> diameter = 2.5 [SI::mm];
        }
        
        part base : BaseBody;
        
        connection upperPivotConnection connect upperLever.pivotPoint to pivot.upperJoint;
        connection lowerPivotConnection connect lowerLever.pivotPoint to pivot.lowerJoint;
        connection movingBladeConnection connect movingBlade.mountPoint to lowerLever.bladeMount;
        connection fixedBladeConnection connect fixedBlade.baseMount to base.fixedBladeMount;
        connection baseToLowerConnection connect base.lowerLeverMount to lowerLever.pivotPoint;
        
        perform action clipOperation[*] ordered;
        
        exhibit state operationalBehavior : ClipperOperationalStates;
    }
    
    part clipperInstance : NailClipper {
        attribute :>> leverRatio = 1.6;
        attribute :>> maxCuttingForce = 85.0 [SI::N];
    }
    
    requirement def FunctionalRequirement;
    requirement def SafetyRequirement;
    requirement def PerformanceRequirement;
    
    requirement <'NC-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* The nail clipper shall trim fingernails and toenails by applying mechanical shearing force through lever-actuated cutting blades. */
        
        subject clipper : NailClipper;
        
        require constraint {
            clipper.leverRatio >= 1.2 and clipper.leverRatio <= 2.0
        }
    }
    
    requirement <'NC-REQ-002'> cuttingCapability : PerformanceRequirement {
        doc /* The nail clipper shall cleanly sever nails up to 1.2mm thickness with user force not exceeding 20N. */
        
        subject clipper : NailClipper;
        
        require constraint {
            clipper.maxCuttingForce >= 60.0 [SI::N] and
            clipper.movingBlade.edgeAngle >= 30.0 [SI::'°'] and
            clipper.movingBlade.edgeAngle <= 40.0 [SI::'°']
        }
    }
    
    requirement <'NC-REQ-003'> safeOperation : SafetyRequirement {
        doc /* The nail clipper shall operate without sharp edges exposed during normal use and prevent pinching of user skin. */
        
        subject clipper : NailClipper;
        
        require constraint {
            clipper.pivot.diameter >= 2.0 [SI::mm]
        }
    }
    
    requirement <'NC-REQ-004'> systemRequirements {
        doc /* The nail clipper system shall meet all functional, performance, and safety requirements. */
        
        require primaryFunction;
        require cuttingCapability;
        require safeOperation;
    }
}
