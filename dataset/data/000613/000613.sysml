package 'Obstetrical Forceps System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ForceMagnitude :> Real;
    attribute def PressureLevel :> Real;
    attribute def PositionAngle :> Real;
    
    enum def BladePosition {
        unpositioned;
        leftApplied;
        rightApplied;
        articulated;
        locked;
    }
    
    enum def DeliveryPhase {
        assessment;
        application;
        traction;
        rotation;
        release;
        complete;
    }
    
    attribute def TractionForce :> ISQ::force;
    attribute def ContactPressure :> ISQ::pressure;
    attribute def RotationAngle :> ISQ::planeAngle;
    attribute def FetalHeadDiameter :> ISQ::length;
    attribute def DescentDistance :> ISQ::length;
    
    part def FetalHead {
        attribute diameter : FetalHeadDiameter;
        attribute position : DescentDistance;
        attribute orientation : RotationAngle;
        port headSurface {
            in appliedPressure : ContactPressure;
            in appliedRotation : RotationAngle;
        }
    }
    
    part def BirthCanal {
        attribute diameter : ISQ::length;
        attribute resistance : Real;
    }
    
    part def ForcepsBlade {
        attribute curvature : RotationAngle;
        attribute contactPressure : ContactPressure;
        attribute side : String;
        port bladeContact {
            out deliveredPressure : ContactPressure;
            out deliveredRotation : RotationAngle;
        }
        port shankConnection {
            in receivedForce : TractionForce;
            in receivedRotation : RotationAngle;
        }
    }
    
    part def LockMechanism {
        attribute engaged : Boolean;
        attribute alignment : RotationAngle;
        port leftShank {
            in leftForce : TractionForce;
        }
        port rightShank {
            in rightForce : TractionForce;
        }
        port lockOutput {
            out combinedForce : TractionForce;
        }
    }
    
    part def ForcepsHandle {
        attribute gripForce : TractionForce;
        attribute side : String;
        port handleGrip {
            in clinicianForce : TractionForce;
            in clinicianRotation : RotationAngle;
        }
        port handleShank {
            out transmittedForce : TractionForce;
            out transmittedRotation : RotationAngle;
        }
    }
    
    part def Clinician {
        attribute experience : Real;
        attribute appliedTraction : TractionForce;
        attribute appliedRotation : RotationAngle;
        port leftHand {
            out leftForce : TractionForce;
            out leftRotation : RotationAngle;
        }
        port rightHand {
            out rightForce : TractionForce;
            out rightRotation : RotationAngle;
        }
    }
    
    part def ObstetricalForceps {
        attribute bladeStatus : BladePosition;
        
        part leftBlade : ForcepsBlade {
            attribute side = "left";
        }
        part rightBlade : ForcepsBlade {
            attribute side = "right";
        }
        part lock : LockMechanism;
        part leftHandle : ForcepsHandle {
            attribute side = "left";
        }
        part rightHandle : ForcepsHandle {
            attribute side = "right";
        }
        
        connect leftBlade.shankConnection to lock.leftShank;
        connect rightBlade.shankConnection to lock.rightShank;
        connect leftHandle.handleShank to lock.leftShank;
        connect rightHandle.handleShank to lock.rightShank;
    }
    
    action def AssessFetalPosition {
        in headDiameter : FetalHeadDiameter;
        in headPosition : DescentDistance;
        in canalDiameter : ISQ::length;
        out applicationIndicated : Boolean;
        out requiredRotation : RotationAngle;
    }
    
    action def PositionBlade {
        in bladeSide : String;
        in headOrientation : RotationAngle;
        inout bladeStatus : BladePosition;
        out bladePositioned : Boolean;
    }
    
    action def ArticulateBlades {
        in leftPositioned : Boolean;
        in rightPositioned : Boolean;
        inout bladeStatus : BladePosition;
        out articulated : Boolean;
    }
    
    action def EngageLock {
        in articulated : Boolean;
        inout lockEngaged : Boolean;
        inout bladeStatus : BladePosition;
        out lockSecured : Boolean;
    }
    
    action def MonitorContactPressure {
        in leftPressure : ContactPressure;
        in rightPressure : ContactPressure;
        in maxSafePressure : ContactPressure;
        out pressureSafe : Boolean;
    }
    
    action def ApplyTraction {
        in tractionForce : TractionForce;
        in tractionAngle : RotationAngle;
        in currentPosition : DescentDistance;
        out newPosition : DescentDistance;
        out descentAchieved : Boolean;
    }
    
    action def ApplyRotation {
        in rotationAngle : RotationAngle;
        in currentOrientation : RotationAngle;
        out newOrientation : RotationAngle;
        out rotationComplete : Boolean;
    }
    
    action def DisengageLock {
        inout lockEngaged : Boolean;
        inout bladeStatus : BladePosition;
        out lockReleased : Boolean;
    }
    
    action def RemoveBlade {
        in bladeSide : String;
        inout bladeStatus : BladePosition;
        out bladeRemoved : Boolean;
    }
    
    action def AssistedDeliveryProcedure {
        in fetalHead : FetalHead;
        in birthCanal : BirthCanal;
        in forceps : ObstetricalForceps;
        in operator : Clinician;
        in maxSafePressure : ContactPressure;
        in targetDescent : DescentDistance;
        out deliverySuccessful : Boolean;
        
        private attribute currentPhase : DeliveryPhase := DeliveryPhase::assessment;
        private attribute currentPosition : DescentDistance := fetalHead.position;
        private attribute currentOrientation : RotationAngle := fetalHead.orientation;
        private attribute lockStatus : Boolean := false;
        private attribute bladeState : BladePosition := BladePosition::unpositioned;
        
        first start;
        then merge assessmentPoint;
        
        then action assess : AssessFetalPosition {
            in headDiameter = fetalHead.diameter;
            in headPosition = currentPosition;
            in canalDiameter = birthCanal.diameter;
            out applicationIndicated;
            out requiredRotation;
        }
        
        then assign currentPhase := DeliveryPhase::application;
        
        then decide;
            if assess.applicationIndicated then positionLeftBlade;
            if not assess.applicationIndicated then abortProcedure;
        
        action positionLeftBlade : PositionBlade {
            in bladeSide = "left";
            in headOrientation = currentOrientation;
            inout bladeStatus = bladeState;
            out bladePositioned;
        }
        
        then action positionRightBlade : PositionBlade {
            in bladeSide = "right";
            in headOrientation = currentOrientation;
            inout bladeStatus = bladeState;
            out bladePositioned;
        }
        
        then action articulateBlades : ArticulateBlades {
            in leftPositioned = positionLeftBlade.bladePositioned;
            in rightPositioned = positionRightBlade.bladePositioned;
            inout bladeStatus = bladeState;
            out articulated;
        }
        
        then action engageLock : EngageLock {
            in articulated = articulateBlades.articulated;
            inout lockEngaged = lockStatus;
            inout bladeStatus = bladeState;
            out lockSecured;
        }
        
        then assign currentPhase := DeliveryPhase::rotation;
        
        then decide;
            if assess.requiredRotation > 0.0 then performRotation;
            if assess.requiredRotation <= 0.0 then beginTraction;
        
        action performRotation : ApplyRotation {
            in rotationAngle = assess.requiredRotation;
            in currentOrientation = currentOrientation;
            out newOrientation;
            out rotationComplete;
        }
        
        then assign currentOrientation := performRotation.newOrientation;
        then beginTraction;
        
        merge beginTraction;
        then assign currentPhase := DeliveryPhase::traction;
        then merge tractionCycle;
        
        then action monitorPressure : MonitorContactPressure {
            in leftPressure = forceps.leftBlade.contactPressure;
            in rightPressure = forceps.rightBlade.contactPressure;
            in maxSafePressure = maxSafePressure;
            out pressureSafe;
        }
        
        then decide;
            if not monitorPressure.pressureSafe then adjustGrip;
            if monitorPressure.pressureSafe then applyTraction;
        
        action adjustGrip {
            in currentLeftPressure = forceps.leftBlade.contactPressure;
            in currentRightPressure = forceps.rightBlade.contactPressure;
            out gripAdjusted : Boolean;
        }
        
        then tractionCycle;
        
        action applyTraction : ApplyTraction {
            in tractionForce = operator.appliedTraction;
            in tractionAngle = 45.0;
            in currentPosition = currentPosition;
            out newPosition;
            out descentAchieved;
        }
        
        then assign currentPosition := applyTraction.newPosition;
        
        then action checkProgress {
            in currentDescent = currentPosition;
            in targetDescent = targetDescent;
            out deliveryAchieved : Boolean;
        }
        
        then decide;
            if not checkProgress.deliveryAchieved then tractionCycle;
            if checkProgress.deliveryAchieved then releaseInstrument;
        
        merge releaseInstrument;
        then assign currentPhase := DeliveryPhase::release;
        
        then action disengageLock : DisengageLock {
            inout lockEngaged = lockStatus;
            inout bladeStatus = bladeState;
            out lockReleased;
        }
        
        then action removeRightBlade : RemoveBlade {
            in bladeSide = "right";
            inout bladeStatus = bladeState;
            out bladeRemoved;
        }
        
        then action removeLeftBlade : RemoveBlade {
            in bladeSide = "left";
            inout bladeStatus = bladeState;
            out bladeRemoved;
        }
        
        then assign currentPhase := DeliveryPhase::complete;
        then assign deliverySuccessful := true;
        then done;
        
        action abortProcedure {
            out aborted : Boolean;
        }
        then assign deliverySuccessful := false;
        then done;
    }
    
    requirement def SafetyRequirement {
        doc /* The forceps shall not apply excessive pressure to the fetal head that could cause trauma. */
        subject forceps : ObstetricalForceps;
        require constraint {
            forceps.leftBlade.contactPressure < 50000.0 and
            forceps.rightBlade.contactPressure < 50000.0
        }
    }
    
    requirement def EffectivenessRequirement {
        doc /* The forceps shall enable controlled traction to achieve fetal descent through the birth canal. */
        subject delivery : AssistedDeliveryProcedure;
        require constraint {
            delivery.deliverySuccessful == true
        }
    }
    
    requirement def LockIntegrityRequirement {
        doc /* The lock mechanism shall maintain secure engagement during traction application. */
        subject lock : LockMechanism;
        require constraint {
            lock.engaged == true
        }
    }
    
    requirement def RotationalControlRequirement {
        doc /* The forceps shall enable controlled rotation of the fetal head when malposition is present. */
        subject procedure : AssistedDeliveryProcedure;
    }
    
    requirement <'OBF-PF-001'> primaryFunctionRequirement {
        doc /* The obstetrical forceps system shall safely grasp the fetal head and apply controlled 
                traction and rotation to assist delivery through the birth canal when maternal expulsive 
                efforts are insufficient or fetal descent is arrested, while maintaining contact pressures 
                within safe limits to prevent trauma. */
        
        require constraint safetyReq {
            doc /* Contact pressure limits must be maintained. */
        }
        require constraint effectivenessReq {
            doc /* Delivery must be successfully achieved. */
        }
        require constraint lockReq {
            doc /* Lock must remain engaged during traction. */
        }
        require constraint rotationReq {
            doc /* Rotation capability must be available when needed. */
        }
    }
    
    part deliveryScenario {
        part fetus : FetalHead {
            attribute diameter = 95.0;
            attribute position = 0.0;
            attribute orientation = 0.2617993877991494;
        }
        
        part canal : BirthCanal {
            attribute diameter = 110.0;
            attribute resistance = 0.4;
        }
        
        part forcepsInstrument : ObstetricalForceps {
            attribute bladeStatus = BladePosition::unpositioned;
        }
        
        part obstetrician : Clinician {
            attribute experience = 12.0;
            attribute appliedTraction = 120.0;
            attribute appliedRotation = 0.5235987755982988;
        }
        
        connect obstetrician.leftHand to forcepsInstrument.leftHandle.handleGrip;
        connect obstetrician.rightHand to forcepsInstrument.rightHandle.handleGrip;
        connect forcepsInstrument.leftBlade.bladeContact to fetus.headSurface;
        connect forcepsInstrument.rightBlade.bladeContact to fetus.headSurface;
        
        perform action assistedBirth : AssistedDeliveryProcedure {
            in fetalHead = fetus;
            in birthCanal = canal;
            in forceps = forcepsInstrument;
            in operator = obstetrician;
            in maxSafePressure = 45000.0;
            in targetDescent = 100.0;
            out deliverySuccessful;
        }
    }
}
