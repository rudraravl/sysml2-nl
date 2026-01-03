package TweezersSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def GripForce :> ISQ::ForceValue;
    attribute def TipGap :> ISQ::LengthValue;
    attribute def ObjectDimension :> ISQ::LengthValue;
    
    item def TargetObject {
        attribute width : ObjectDimension;
        attribute height : ObjectDimension;
        attribute mass : ISQ::MassValue;
        attribute fragility : Real;
    }
    
    port def GripInterface {
        out appliedForce : GripForce;
        in objectWidth : ObjectDimension;
        out tipSeparation : TipGap;
    }
    
    port def ActuationInterface {
        in userForce : ForceValue;
        out mechanicalAdvantage : Real;
    }
    
    part def TweezerArm {
        attribute armLength : LengthValue;
        attribute leverRatio : Real;
        attribute materialStiffness : Real;
        port tipEnd : GripInterface;
        port pivotEnd : ActuationInterface;
    }
    
    part def PivotJoint {
        attribute pivotAngle : Real;
        attribute frictionCoefficient : Real;
        attribute wearFactor : Real;
    }
    
    part def GripTip {
        attribute tipRadius : LengthValue;
        attribute surfaceRoughness : Real;
        attribute contactArea : ISQ::AreaValue;
    }
    
    part def Tweezers {
        doc /* A precision hand tool for grasping and manipulating small objects */
        
        attribute nominalTipGap : TipGap;
        attribute maxGripForce : GripForce;
        attribute minGripForce : GripForce;
        attribute operatingRange : TipGap;
        
        part leftArm : TweezerArm {
            attribute armLength = 75.0 [mm];
            attribute leverRatio = 2.5;
            attribute materialStiffness = 0.92;
        }
        
        part rightArm : TweezerArm {
            attribute armLength = 75.0 [mm];
            attribute leverRatio = 2.5;
            attribute materialStiffness = 0.92;
        }
        
        part centralPivot : PivotJoint {
            attribute pivotAngle = 0.0;
            attribute frictionCoefficient = 0.08;
            attribute wearFactor = 1.0;
        }
        
        part leftTip : GripTip {
            attribute tipRadius = 0.5 [mm];
            attribute surfaceRoughness = 0.02;
            attribute contactArea = 2.0 [mm^2];
        }
        
        part rightTip : GripTip {
            attribute tipRadius = 0.5 [mm];
            attribute surfaceRoughness = 0.02;
            attribute contactArea = 2.0 [mm^2];
        }
        
        connection pivotConnection1 connect leftArm.pivotEnd to centralPivot;
        connection pivotConnection2 connect rightArm.pivotEnd to centralPivot;
        connection tipConnection1 connect leftTip to leftArm.tipEnd;
        connection tipConnection2 connect rightTip to rightArm.tipEnd;
    }
    
    action def MeasureObjectSize {
        in targetObject : TargetObject;
        out measuredWidth : ObjectDimension;
        out measuredHeight : ObjectDimension;
    }
    
    action def PositionTips {
        in requiredGap : TipGap;
        in currentGap : TipGap;
        out adjustedGap : TipGap;
        out aligned : Boolean;
    }
    
    action def ApplyGrip {
        in userForce : ForceValue;
        in leverRatio : Real;
        out tipForce : GripForce;
        out tipGap : TipGap;
    }
    
    action def VerifyGrasp {
        in appliedForce : GripForce;
        in objectMass : ISQ::MassValue;
        in objectFragility : Real;
        out secured : Boolean;
        out safe : Boolean;
    }
    
    action def TransferObject {
        in startPosition : ISQ::LengthValue;
        in endPosition : ISQ::LengthValue;
        in graspForce : GripForce;
        out transferred : Boolean;
    }
    
    action def ReleaseGrasp {
        in currentForce : GripForce;
        out released : Boolean;
        out tipGap : TipGap;
    }
    
    action def ManipulateObject {
        in targetObject : TargetObject;
        in destinationPosition : ISQ::LengthValue;
        out operationSuccess : Boolean;
        
        first start;
        then merge approach;
        
        then action measure : MeasureObjectSize {
            in targetObject = ManipulateObject::targetObject;
            out measuredWidth;
            out measuredHeight;
        }
        
        then action position : PositionTips {
            in requiredGap = measure.measuredWidth * 0.85;
            in currentGap = 10.0 [mm];
            out adjustedGap;
            out aligned;
        }
        
        then decide;
            if position.aligned then grip;
            if not position.aligned then reposition;
        
        action reposition : PositionTips {
            in requiredGap = measure.measuredWidth * 0.9;
            in currentGap = position.adjustedGap;
            out adjustedGap;
            out aligned;
        }
        then approach;
        
        action grip : ApplyGrip {
            in userForce = 3.0 [N];
            in leverRatio = 2.5;
            out tipForce;
            out tipGap;
        }
        
        then action verifyGrasp : VerifyGrasp {
            in appliedForce = grip.tipForce;
            in objectMass = ManipulateObject::targetObject.mass;
            in objectFragility = ManipulateObject::targetObject.fragility;
            out secured;
            out safe;
        }
        
        then decide;
            if verifyGrasp.secured and verifyGrasp.safe then transfer;
        
        action transfer : TransferObject {
            in startPosition = 0.0 [mm];
            in endPosition = destinationPosition;
            in graspForce = verifyGrasp.appliedForce;
            out transferred;
        }
        
        then action release : ReleaseGrasp {
            in currentForce = verifyGrasp.appliedForce;
            out released;
            out tipGap;
        }
        
        then assign operationSuccess := transfer.transferred and release.released;
        then done;
    }
    
    state def TweezersOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* Tweezers at rest with tips open */
            entry assign currentGripForce = 0.0 [N];
            entry assign currentTipGap = 12.0 [mm];
        }
        
        transition idle_to_approaching
            first idle
            accept ObjectDetected
            then approaching;
        
        state approaching {
            doc /* Tips moving toward target object */
            entry assign tipsMoving = true;
            do action alignTips {
                doc /* Continuously adjust tip alignment */
            }
        }
        
        transition approaching_to_positioning
            first approaching
            accept AlignmentAchieved
            then positioning;
        
        state positioning {
            doc /* Fine adjustment of tip gap for object size */
            do action adjustGap {
                doc /* Modify tip separation to match object */
            }
        }
        
        transition positioning_to_gripping
            first positioning
            accept GapOptimal
            then gripping;
        
        state gripping {
            doc /* Applying controlled force to grasp object */
            entry assign currentGripForce = 2.8 [N];
            entry assign currentTipGap = 1.5 [mm];
            do action applyForce {
                doc /* Maintain steady grip force */
            }
        }
        
        transition gripping_to_holding
            first gripping
            if objectSecured
            then holding;
        
        transition gripping_to_adjusting
            first gripping
            if not objectSecured
            then adjusting;
        
        state adjusting {
            doc /* Modifying grip force for better hold */
            do action modifyForce {
                doc /* Increase or decrease force as needed */
            }
        }
        
        transition adjusting_to_gripping
            first adjusting
            then gripping;
        
        state holding {
            doc /* Maintaining stable grasp on object */
            do action sustainGrasp {
                doc /* Keep constant force and position */
            }
        }
        
        transition holding_to_transferring
            first holding
            accept TransferCommand
            then transferring;
        
        state transferring {
            doc /* Moving object while maintaining grasp */
            do action moveWithObject {
                doc /* Translate position while holding */
            }
        }
        
        transition transferring_to_releasing
            first transferring
            accept DestinationReached
            then releasing;
        
        state releasing {
            doc /* Controlled opening of tips to release object */
            entry assign currentGripForce = 0.0 [N];
            entry assign currentTipGap = 12.0 [mm];
            do action openTips {
                doc /* Gradually separate tips */
            }
        }
        
        transition releasing_to_idle
            first releasing
            accept ObjectReleased
            then idle;
        
        attribute currentGripForce : GripForce;
        attribute currentTipGap : TipGap;
        attribute tipsMoving : Boolean;
        attribute objectSecured : Boolean;
        
        signal ObjectDetected;
        signal AlignmentAchieved;
        signal GapOptimal;
        signal TransferCommand;
        signal DestinationReached;
        signal ObjectReleased;
    }
    
    part precisionTweezers : Tweezers {
        attribute nominalTipGap = 10.0 [mm];
        attribute maxGripForce = 5.0 [N];
        attribute minGripForce = 0.5 [N];
        attribute operatingRange = 15.0 [mm];
        
        perform action manipulate[*] ordered references ManipulateObject;
        exhibit state operationalBehavior : TweezersOperationalStates;
    }
    
    requirement def GraspingCapability {
        doc /* The tweezers shall grasp objects within specified size range */
        
        subject tweezersSystem : Tweezers;
        
        require constraint sizeRange {
            doc /* Shall handle objects from 0.5 mm to 8 mm width */
            tweezersSystem.nominalTipGap >= 0.5 [mm] and
            tweezersSystem.operatingRange <= 15.0 [mm]
        }
    }
    
    requirement def ForceControl {
        doc /* The tweezers shall provide controlled grip force */
        
        subject tweezersSystem : Tweezers;
        
        require constraint forceRange {
            doc /* Grip force shall be between 0.5 N and 5.0 N */
            tweezersSystem.minGripForce >= 0.5 [N] and
            tweezersSystem.maxGripForce <= 5.0 [N]
        }
        
        require constraint forcePrecision {
            doc /* Force control precision shall be within 0.1 N */
            tweezersSystem.maxGripForce - tweezersSystem.minGripForce >= 0.1 [N]
        }
    }
    
    requirement def SafeHandling {
        doc /* The tweezers shall handle delicate objects without damage */
        
        subject tweezersSystem : Tweezers;
        
        require constraint tipSmoothness {
            doc /* Tip surface shall be smooth to prevent scratching */
            tweezersSystem.leftTip.surfaceRoughness <= 0.05 and
            tweezersSystem.rightTip.surfaceRoughness <= 0.05
        }
        
        require constraint forceLimit {
            doc /* Maximum force shall not exceed safe threshold */
            tweezersSystem.maxGripForce <= 5.0 [N]
        }
    }
    
    requirement def PrecisionAlignment {
        doc /* The tweezers shall maintain precise tip alignment */
        
        subject tweezersSystem : Tweezers;
        
        require constraint armSymmetry {
            doc /* Arms shall be symmetric for balanced grip */
            tweezersSystem.leftArm.armLength == tweezersSystem.rightArm.armLength and
            tweezersSystem.leftArm.leverRatio == tweezersSystem.rightArm.leverRatio
        }
    }
    
    requirement primaryFunction {
        doc /* 
            The tweezers system shall grasp, hold, manipulate, and release small objects 
            with precision and control through coordinated mechanical action of opposing arms 
            that converge at fine tips, enabling delicate handling of components ranging from 
            sub-millimeter to several millimeters in size.
        */
        
        subject tweezersSystem : Tweezers;
        
        assume constraint operatingEnvironment {
            doc /* System operates in controlled environment with minimal vibration */
        }
        
        assume constraint userSkill {
            doc /* Operator has basic manual dexterity and training */
        }
        
        require graspCapability : GraspingCapability;
        require forceControl : ForceControl;
        require safeHandling : SafeHandling;
        require precisionAlignment : PrecisionAlignment;
    }
}
