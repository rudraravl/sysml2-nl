package 'Pennington Clamp System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ClampState;
    attribute def OpenState :> ClampState;
    attribute def ClosingState :> ClampState;
    attribute def ClosedState :> ClampState;
    attribute def LockedState :> ClampState;
    
    item def TissueSegment {
        attribute diameter : LengthValue;
        attribute compressibility : Real;
    }
    
    port def TissueContactPort {
        in tissue : TissueSegment;
        out appliedPressure : PressureValue;
        out contactForce : ForceValue;
    }
    
    port def OperatorControlPort {
        in squeezeForce : ForceValue;
        in releaseCommand : Boolean;
        out currentState : ClampState;
        out jawPosition : LengthValue;
    }
    
    part def Jaw {
        doc /* Serrated jaw component that contacts and grips tissue. */
        
        attribute jawLength : LengthValue;
        attribute jawWidth : LengthValue;
        attribute serrationDepth : LengthValue;
        attribute tipArea : AreaValue;
        
        port tissueContact : TissueContactPort;
        
        part grippingSurface {
            attribute serrationPattern : String;
            attribute surfaceFinish : String;
        }
    }
    
    part def Handle {
        doc /* Ergonomic handle for operator force application. */
        
        attribute handleLength : LengthValue;
        attribute gripDiameter : LengthValue;
        attribute ergonomicProfile : String;
        
        port mechanicalInterface {
            out transmittedForce : ForceValue;
        }
    }
    
    part def PivotJoint {
        doc /* Central pivot allowing jaw articulation. */
        
        attribute pivotAngle : AngleValue;
        attribute mechanicalAdvantage : Real;
        attribute frictionCoefficient : Real;
        
        action def TransmitForce {
            in inputForce : ForceValue;
            in leverRatio : Real;
            out outputForce : ForceValue;
        }
    }
    
    part def RatchetLock {
        doc /* Ratchet mechanism maintaining clamping force without continuous hand pressure. */
        
        attribute numberOfTeeth : Integer;
        attribute currentPosition : Integer;
        attribute engaged : Boolean;
        attribute holdingForce : ForceValue;
        
        action def Engage {
            in clampingForce : ForceValue;
            out lockEngaged : Boolean;
        }
        
        action def Release {
            in releaseForce : ForceValue;
            out lockDisengaged : Boolean;
        }
    }
    
    part def PenningtonClamp {
        doc /* Surgical clamp for atraumatic grasping and holding of soft tissue. */
        
        attribute maxClampingForce : ForceValue;
        attribute minJawSeparation : LengthValue;
        attribute maxJawSeparation : LengthValue;
        attribute currentJawSeparation : LengthValue;
        attribute appliedForce : ForceValue;
        attribute operationalState : ClampState;
        
        part upperJaw : Jaw {
            attribute :>> jawLength = 50.0 [SI::mm];
            attribute :>> jawWidth = 8.0 [SI::mm];
            attribute :>> serrationDepth = 0.5 [SI::mm];
            attribute :>> tipArea = 40.0 [SI::mm^2];
        }
        
        part lowerJaw : Jaw {
            attribute :>> jawLength = 50.0 [SI::mm];
            attribute :>> jawWidth = 8.0 [SI::mm];
            attribute :>> serrationDepth = 0.5 [SI::mm];
            attribute :>> tipArea = 40.0 [SI::mm^2];
        }
        
        part upperHandle : Handle {
            attribute :>> handleLength = 140.0 [SI::mm];
            attribute :>> gripDiameter = 12.0 [SI::mm];
        }
        
        part lowerHandle : Handle {
            attribute :>> handleLength = 140.0 [SI::mm];
            attribute :>> gripDiameter = 12.0 [SI::mm];
        }
        
        part pivot : PivotJoint {
            attribute :>> mechanicalAdvantage = 4.5;
            attribute :>> frictionCoefficient = 0.15;
        }
        
        part lock : RatchetLock {
            attribute :>> numberOfTeeth = 8;
            attribute :>> currentPosition = 0;
            attribute :>> engaged = false;
        }
        
        port operatorInterface : OperatorControlPort;
        port upperTissueContact : TissueContactPort;
        port lowerTissueContact : TissueContactPort;
        
        connection handleToPivot connect upperHandle.mechanicalInterface to pivot;
        connection pivotToJaws connect pivot to upperJaw;
        connection jawsToTissue connect upperJaw.tissueContact to upperTissueContact;
        connection lockToHandle connect lock to upperHandle;
    }
    
    action def GraspTissue {
        doc /* Primary action to grasp and hold tissue segment. */
        
        in targetTissue : TissueSegment;
        in desiredPressure : PressureValue;
        out graspAchieved : Boolean;
        out finalForce : ForceValue;
        
        first start;
        then merge awaitCommand;
        
        action awaitCommand {
            accept operatorInput;
        }
        
        then action positionJaws {
            in tissue = targetTissue;
            out jawsAligned : Boolean;
        }
        
        then action applyCompression {
            in tissue = targetTissue;
            in targetPressure = desiredPressure;
            out compressionForce : ForceValue;
            out pressureAchieved : Boolean;
        }
        
        then decide;
            if applyCompression.pressureAchieved then engageLock;
            if !applyCompression.pressureAchieved then adjustForce;
        
        action adjustForce {
            in currentForce = applyCompression.compressionForce;
            in requiredPressure = desiredPressure;
            out adjustedForce : ForceValue;
        }
        then applyCompression;
        
        action engageLock {
            in clampForce = applyCompression.compressionForce;
            out lockSet : Boolean;
        }
        
        then action maintainGrasp {
            in holdingForce = applyCompression.compressionForce;
            out tissueSecured : Boolean;
        }
        
        then merge holdOrRelease;
        
        action holdOrRelease {
            accept releaseSignal;
        }
        
        then action releaseGrasp {
            out jawsReleased : Boolean;
        }
        
        then assign graspAchieved := false;
        then assign finalForce := 0.0 [SI::N];
        then done;
    }
    
    part penningtonClampInstance : PenningtonClamp {
        doc /* Operational instance of Pennington clamp for tissue manipulation. */
        
        attribute :>> maxClampingForce = 25.0 [SI::N];
        attribute :>> minJawSeparation = 0.0 [SI::mm];
        attribute :>> maxJawSeparation = 15.0 [SI::mm];
        attribute :>> currentJawSeparation = 15.0 [SI::mm];
        
        perform action graspOperation : GraspTissue {
            in targetTissue : TissueSegment;
            in desiredPressure : PressureValue;
            out graspAchieved : Boolean;
            out finalForce : ForceValue;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The Pennington clamp shall atraumatically grasp, hold, and manipulate 
               soft tissue during surgical procedures using opposing serrated jaws 
               with a self-locking ratchet mechanism. */
        
        subject clamp : PenningtonClamp;
        
        require constraint {
            clamp.appliedForce > 0.0 [SI::N] and 
            clamp.appliedForce <= clamp.maxClampingForce
        }
    }
    
    requirement def TissueProtectionRequirement {
        doc /* The clamp shall apply controlled pressure to prevent tissue damage 
               while maintaining secure grip. */
        
        subject clamp : PenningtonClamp;
        
        attribute maxAllowablePressure : PressureValue;
        
        require constraint {
            clamp.upperJaw.tissueContact.appliedPressure <= maxAllowablePressure and
            clamp.lowerJaw.tissueContact.appliedPressure <= maxAllowablePressure
        }
    }
    
    requirement def LockingMechanismRequirement {
        doc /* The ratchet lock shall maintain clamping force without continuous 
               operator input throughout the procedure. */
        
        subject lockMech : RatchetLock;
        
        require constraint {
            lockMech.engaged implies lockMech.holdingForce > 0.0 [SI::N]
        }
    }
    
    requirement def GraspReliabilityRequirement {
        doc /* The clamp shall securely hold tissue without slippage under 
               normal surgical conditions. */
        
        subject clamp : PenningtonClamp;
        
        require constraint {
            clamp.operationalState == LockedState implies 
            clamp.lock.engaged == true
        }
    }
    
    requirement <'PC-REQ-001'> systemRequirement {
        doc /* The Pennington Clamp System shall function as a surgical instrument 
               to atraumatically grasp, securely hold, and precisely manipulate 
               biological soft tissue through user-operated, self-locking jaws. */
        
        subject penningtonClampInstance;
        
        require primaryFunction : PrimaryFunctionRequirement {
            subject clamp = penningtonClampInstance;
        }
        
        require tissueProtection : TissueProtectionRequirement {
            subject clamp = penningtonClampInstance;
            attribute :>> maxAllowablePressure = 150.0 [SI::kPa];
        }
        
        require lockingMechanism : LockingMechanismRequirement {
            subject lockMech = penningtonClampInstance.lock;
        }
        
        require graspReliability : GraspReliabilityRequirement {
            subject clamp = penningtonClampInstance;
        }
    }
}
