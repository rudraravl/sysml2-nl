package StandingFrameSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AngleValue :> Real;
    
    item def Patient {
        attribute bodyMass : MassValue;
        attribute height : LengthValue;
        attribute mobilityLevel : Real;
    }
    
    port def MechanicalSupportPort {
        attribute appliedLoad : ForceValue;
        attribute contactPressure : PressureValue;
    }
    
    port def ControlPort {
        in attribute commandSignal : Real;
        out attribute statusFeedback : Real;
    }
    
    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    part def StructuralFrame {
        attribute frameHeight : LengthValue;
        attribute frameWidth : LengthValue;
        attribute loadCapacity : ForceValue;
        
        part baseAssembly {
            attribute baseWidth : LengthValue;
            attribute stabilityFactor : Real;
        }
        
        part verticalSupports[2] {
            attribute supportHeight : LengthValue;
            attribute crossSection : AreaValue;
        }
    }
    
    part def TiltMechanism {
        attribute currentAngle : AngleValue;
        attribute minAngle : AngleValue;
        attribute maxAngle : AngleValue;
        attribute angularVelocity : Real;
        
        port mechanicalPort : MechanicalSupportPort;
        port controlPort : ControlPort;
        
        part actuator {
            attribute maxForce : ForceValue;
            attribute strokeLength : LengthValue;
        }
        
        part lockingSystem {
            attribute isLocked : Boolean;
            attribute lockingForce : ForceValue;
        }
    }
    
    part def SupportPlatform {
        attribute platformArea : AreaValue;
        attribute tiltAngle : AngleValue;
        
        port supportPort : MechanicalSupportPort;
        
        part footPlate {
            attribute plateAngle : AngleValue;
            attribute surfaceArea : AreaValue;
        }
        
        part kneeSupport {
            attribute paddingThickness : LengthValue;
            attribute supportHeight : LengthValue;
        }
        
        part chestPad {
            attribute padWidth : LengthValue;
            attribute padHeight : LengthValue;
        }
    }
    
    part def RestraintSystem {
        attribute maxTensileLoad : ForceValue;
        
        part pelvisStrap {
            attribute isSecured : Boolean;
            attribute strapWidth : LengthValue;
        }
        
        part chestStrap {
            attribute isSecured : Boolean;
            attribute tensionLevel : ForceValue;
        }
        
        part footStraps[2] {
            attribute isSecured : Boolean;
        }
    }
    
    part def ControlSystem {
        attribute operatingVoltage : ElectricPotentialValue;
        
        port controlOutput : ControlPort;
        port powerInput : PowerPort;
        
        part userInterface {
            attribute buttonCount : Integer;
            attribute displayType : String;
        }
        
        part safetyController {
            attribute emergencyStopActive : Boolean;
            attribute maxTiltRate : Real;
        }
    }
    
    part def PowerSupply {
        attribute nominalVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        attribute batteryCapacity : Real;
        
        port powerOutput : PowerPort;
    }
    
    part def StandingFrame {
        attribute totalMass : MassValue;
        attribute maxUserMass : MassValue;
        attribute overallHeight : LengthValue;
        attribute overallWidth : LengthValue;
        
        part structuralFrame : StructuralFrame {
            attribute frameHeight = 1900 [mm];
            attribute frameWidth = 850 [mm];
            attribute loadCapacity = 2000 [N];
        }
        
        part tiltSystem : TiltMechanism {
            attribute currentAngle = 0;
            attribute minAngle = 0;
            attribute maxAngle = 85;
            attribute angularVelocity = 2.5;
        }
        
        part platform : SupportPlatform {
            attribute platformArea = 0.3 [m^2];
            attribute tiltAngle = 0;
        }
        
        part restraints : RestraintSystem {
            attribute maxTensileLoad = 1200 [N];
        }
        
        part controller : ControlSystem {
            attribute operatingVoltage = 24 [V];
        }
        
        part power : PowerSupply {
            attribute nominalVoltage = 24 [V];
            attribute maxCurrent = 15 [A];
            attribute batteryCapacity = 7200;
        }
        
        connection platformToTilt connect platform.supportPort to tiltSystem.mechanicalPort;
        connection controlToTilt connect controller.controlOutput to tiltSystem.controlPort;
        connection powerToController connect power.powerOutput to controller.powerInput;
    }
    
    action def SecurePatient {
        in patient : Patient;
        out allSecured : Boolean;
        
        action positionPatient {
            doc /* Position patient against support platform with proper alignment */
        }
        
        then action attachPelvisStrap {
            doc /* Secure pelvis strap around patient waist */
        }
        
        then action attachChestStrap {
            doc /* Secure chest strap across patient torso */
        }
        
        then action attachFootStraps {
            doc /* Secure both foot straps to stabilize feet on footplate */
        }
        
        then action verifyAllRestraints {
            doc /* Verify all restraints are properly fastened and tensioned */
        }
        
        then assign allSecured := true;
    }
    
    action def AdjustTiltAngle {
        in targetAngle : AngleValue;
        in currentAngle : AngleValue;
        in maxRate : Real;
        out finalAngle : AngleValue;
        
        action releaseLock {
            doc /* Disengage locking mechanism to allow tilt adjustment */
        }
        
        then action activateActuator {
            doc /* Activate linear actuator to change platform angle */
        }
        
        then action monitorAngle {
            doc /* Continuously monitor angle during adjustment */
        }
        
        then action engageLock {
            doc /* Engage locking mechanism at target angle */
        }
        
        then assign finalAngle := targetAngle;
    }
    
    action def ProvideStandingSupport {
        in patient : Patient;
        in standingDuration : DurationValue;
        in targetTiltAngle : AngleValue;
        out supportCompleted : Boolean;
        
        first start;
        
        then action securePatientAction : SecurePatient {
            in patient = patient;
            out allSecured;
        }
        
        then decide;
            if securePatientAction.allSecured then proceedToTilt;
            if not securePatientAction.allSecured then abortOperation;
        
        action proceedToTilt : AdjustTiltAngle {
            in targetAngle = targetTiltAngle;
            in currentAngle = 0;
            in maxRate = 2.5;
            out finalAngle;
        }
        
        then action maintainStandingPosition {
            doc /* Maintain patient in standing position for therapeutic duration */
        }
        
        then action monitorPatientStability {
            doc /* Continuously monitor patient stability and vital signs */
        }
        
        then action returnToSeated : AdjustTiltAngle {
            in targetAngle = 0;
            in currentAngle = proceedToTilt.finalAngle;
            in maxRate = 2.5;
            out finalAngle;
        }
        
        then action releasePatient {
            doc /* Release all restraints and assist patient exit */
        }
        
        then assign supportCompleted := true;
        then done;
        
        action abortOperation {
            doc /* Safely abort operation and return to initial state */
        }
        
        then done;
    }
    
    state def StandingFrameStateMachine {
        in patientSecured : Boolean;
        in currentAngle : AngleValue;
        in targetAngle : AngleValue;
        in emergencyStop : Boolean;
        
        entry; then idle;
        
        state idle {
            doc /* Frame is in resting position, ready for patient */
        }
        
        accept at idle
            if patientSecured
            then patientLoading;
        
        state patientLoading {
            doc /* Patient is being positioned and secured */
            entry action { doc /* Activate safety interlocks */ }
        }
        
        accept at patientLoading
            if patientSecured and currentAngle < targetAngle
            then tiltingUp;
        
        state tiltingUp {
            doc /* Platform is tilting to standing position */
            entry action { doc /* Begin controlled tilt motion */ }
        }
        
        accept at tiltingUp
            if currentAngle >= targetAngle
            then standingPosition;
        
        accept at tiltingUp
            if emergencyStop
            then emergency;
        
        state standingPosition {
            doc /* Patient is in full standing position */
            entry action { doc /* Lock platform at standing angle */ }
        }
        
        accept at standingPosition
            if currentAngle > 0
            then tiltingDown;
        
        accept at standingPosition
            if emergencyStop
            then emergency;
        
        state tiltingDown {
            doc /* Platform is returning to seated position */
            entry action { doc /* Begin controlled descent */ }
        }
        
        accept at tiltingDown
            if currentAngle <= 0
            then idle;
        
        accept at tiltingDown
            if emergencyStop
            then emergency;
        
        state emergency {
            doc /* Emergency stop activated */
            entry action { doc /* Halt all motion immediately */ }
        }
        
        accept at emergency
            if not emergencyStop
            then idle;
    }
    
    requirement <'REQ-SF-001'> primaryFunction {
        doc /* The standing frame shall provide safe therapeutic support
             * to enable patients with limited mobility to achieve and maintain
             * an upright standing position for medical, therapeutic, and
             * functional benefits including improved circulation, bone density,
             * and digestive function.
             */
        subject standingFrame : StandingFrame;
    }
    
    requirement <'REQ-SF-002'> tiltAngleRange {
        doc /* The standing frame shall provide adjustable tilt angle
             * from 0 degrees (seated) to at least 85 degrees (near-vertical standing).
             */
        subject tiltSystem :>> StandingFrame::tiltSystem;
        
        assert constraint {
            tiltSystem.minAngle == 0 and
            tiltSystem.maxAngle >= 85
        }
    }
    
    requirement <'REQ-SF-003'> patientLoadCapacity {
        doc /* The standing frame shall safely support patients
             * with body mass up to 150 kg.
             */
        subject structuralFrame :>> StandingFrame::structuralFrame;
        
        assert constraint {
            structuralFrame.loadCapacity >= 1500
        }
    }
    
    requirement <'REQ-SF-004'> restraintSystemRequirement {
        doc /* The standing frame shall include a comprehensive restraint
             * system with pelvis, chest, and foot straps to ensure patient
             * safety during standing.
             */
        subject restraints :>> StandingFrame::restraints;
        
        assert constraint {
            restraints.pelvisStrap.isSecured and
            restraints.chestStrap.isSecured and
            restraints.footStraps->forAll(s | s.isSecured)
        }
    }
    
    requirement <'REQ-SF-005'> controlledTiltRate {
        doc /* The standing frame shall control tilt rate to not exceed
             * 3 degrees per second to ensure patient comfort and safety.
             */
        subject tiltSystem :>> StandingFrame::tiltSystem;
        
        assert constraint {
            tiltSystem.angularVelocity <= 3.0
        }
    }
    
    requirement <'REQ-SF-006'> emergencyStopCapability {
        doc /* The standing frame shall provide emergency stop capability
             * that immediately halts all motion when activated.
             */
        subject controller :>> StandingFrame::controller;
        
        assert constraint {
            controller.safetyController.emergencyStopActive implies
            tiltSystem.angularVelocity == 0
        }
    }
    
    requirement <'REQ-SF-007'> structuralStability {
        doc /* The standing frame base shall maintain stability under
             * maximum load conditions with adequate safety margin.
             */
        subject baseAssembly :>> StandingFrame::structuralFrame.baseAssembly;
        
        assert constraint {
            baseAssembly.stabilityFactor >= 1.5
        }
    }
    
    part standingFrameInstance : StandingFrame {
        attribute totalMass = 85 [kg];
        attribute maxUserMass = 150 [kg];
        attribute overallHeight = 1900 [mm];
        attribute overallWidth = 850 [mm];
        
        perform action therapeuticSupport[*] ordered references ProvideStandingSupport;
    }
    
    satisfy primaryFunction by standingFrameInstance;
    satisfy tiltAngleRange by standingFrameInstance;
    satisfy patientLoadCapacity by standingFrameInstance;
    satisfy restraintSystemRequirement by standingFrameInstance;
    satisfy controlledTiltRate by standingFrameInstance;
    satisfy emergencyStopCapability by standingFrameInstance;
    satisfy structuralStability by standingFrameInstance;
}
