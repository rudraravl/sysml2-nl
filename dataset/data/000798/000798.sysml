package TractionSplintSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def TractionForceValue :> ForceValue;
    attribute def LimbLengthValue :> LengthValue;
    attribute def PressureValue :> PressureValue;
    attribute def AngleValue :> AngleValue;

    enum def SplintOperationalState {
        stowed;
        positioned;
        anchored;
        tensioned;
        secured;
        monitoring;
        released;
    }

    enum def FractureSeverity {
        closed;
        open;
        comminuted;
        displaced;
    }

    item def InjuredLimb {
        attribute limbLength : LimbLengthValue;
        attribute fractureLocation : LimbLengthValue;
        attribute fractureSeverity : FractureSeverity;
        attribute currentAlignment : AngleValue;
        attribute targetAlignment : AngleValue;
    }

    item def Patient {
        attribute bodyMass : MassValue;
        attribute legLength : LimbLengthValue;
        part injuredLimb : InjuredLimb;
    }

    part def ProximalAnchorPad {
        attribute padWidth : LimbLengthValue;
        attribute contactPressure : PressureValue;
        attribute isSecured : Boolean;
        port ischialInterface;
    }

    part def DistalAnkleHitch {
        attribute hitchDiameter : LimbLengthValue;
        attribute maxTensileLoad : TractionForceValue;
        attribute isAttached : Boolean;
        port ankleInterface;
    }

    part def TellescopicFrame {
        attribute minLength : LimbLengthValue;
        attribute maxLength : LimbLengthValue;
        attribute currentLength : LimbLengthValue;
        attribute frameMass : MassValue;
        port proximalMount;
        port distalMount;
    }

    part def RatchetWindlass {
        attribute appliedTraction : TractionForceValue;
        attribute maxTraction : TractionForceValue;
        attribute ratchetPosition : Integer;
        attribute isLocked : Boolean;
        port windlassControl;
        port forceOutput;
    }

    part def SupportStraps {
        attribute numberOfStraps : Integer;
        attribute strapTension : TractionForceValue;
        attribute allSecured : Boolean;
    }

    part def TensionIndicator {
        attribute currentReading : TractionForceValue;
        attribute calibrationStatus : Boolean;
        port sensorInterface;
    }

    action def AssessPatient {
        in patient : Patient;
        out requiresTraction : Boolean;
        out targetTractionForce : TractionForceValue;
    }

    action def PositionFrame {
        in frame : TellescopicFrame;
        in targetLength : LimbLengthValue;
        out framePositioned : Boolean;
    }

    action def SecureProximalAnchor {
        in anchor : ProximalAnchorPad;
        in patient : Patient;
        out anchorSecured : Boolean;
    }

    action def AttachDistalHitch {
        in hitch : DistalAnkleHitch;
        in limb : InjuredLimb;
        out hitchAttached : Boolean;
    }

    action def ApplyTractionForce {
        in windlass : RatchetWindlass;
        in targetForce : TractionForceValue;
        out actualForce : TractionForceValue;
        out alignmentAchieved : Boolean;
    }

    action def SecureLimbWithStraps {
        in straps : SupportStraps;
        out strapsSecured : Boolean;
    }

    action def MonitorTractionLevel {
        in indicator : TensionIndicator;
        in targetForce : TractionForceValue;
        out forceWithinRange : Boolean;
        out currentForce : TractionForceValue;
    }

    action def AdjustTraction {
        in windlass : RatchetWindlass;
        in currentForce : TractionForceValue;
        in targetForce : TractionForceValue;
        out adjustedForce : TractionForceValue;
    }

    action def ReleaseTractionSystem {
        in windlass : RatchetWindlass;
        out systemReleased : Boolean;
    }

    action def DeploySplint {
        first start;
        then action assess : AssessPatient;
        then decide;
            if assess.requiresTraction then positionFrame;
            if !assess.requiresTraction then abortAction;
        action positionFrame : PositionFrame;
        then action secureAnchor : SecureProximalAnchor;
        then action attachHitch : AttachDistalHitch;
        then action applyTraction : ApplyTractionForce;
        then action secureStraps : SecureLimbWithStraps;
        then merge monitoringLoop;
        action monitor : MonitorTractionLevel;
        then decide;
            if monitor.forceWithinRange then monitoringLoop;
            if !monitor.forceWithinRange then adjustAction;
        action adjustAction : AdjustTraction;
        then monitoringLoop;
        action abortAction;
        then done;
    }

    state def TractionSplintStateMachine {
        entry; then stowed;
        
        state stowed;
        transition stowed_to_positioning
            first stowed
            then positioning;
        
        state positioning;
        transition positioning_to_attaching
            first positioning
            then attaching;
        
        state attaching;
        transition attaching_to_tensioning
            first attaching
            then tensioning;
        
        state tensioning;
        transition tensioning_to_securing
            first tensioning
            then securing;
        
        state securing;
        transition securing_to_monitoring
            first securing
            then monitoring;
        
        state monitoring;
        transition monitoring_to_releasing
            first monitoring
            then releasing;
        
        state releasing;
        transition releasing_to_stowed
            first releasing
            then stowed;
    }

    part def TractionSplint {
        attribute totalMass : MassValue;
        attribute operationalState : SplintOperationalState;
        attribute targetTractionForce : TractionForceValue;
        attribute maxAllowableTraction : TractionForceValue;

        part proximalAnchor : ProximalAnchorPad {
            attribute :>> padWidth = 120 [mm];
            attribute :>> contactPressure : PressureValue;
            attribute :>> isSecured = false;
        }

        part distalHitch : DistalAnkleHitch {
            attribute :>> hitchDiameter = 80 [mm];
            attribute :>> maxTensileLoad = 180 [N];
            attribute :>> isAttached = false;
        }

        part frame : TellescopicFrame {
            attribute :>> minLength = 750 [mm];
            attribute :>> maxLength = 1150 [mm];
            attribute :>> currentLength = 900 [mm];
            attribute :>> frameMass = 1.2 [kg];
        }

        part windlass : RatchetWindlass {
            attribute :>> appliedTraction : TractionForceValue;
            attribute :>> maxTraction = 180 [N];
            attribute :>> ratchetPosition = 0;
            attribute :>> isLocked = false;
        }

        part straps : SupportStraps {
            attribute :>> numberOfStraps = 4;
            attribute :>> strapTension : TractionForceValue;
            attribute :>> allSecured = false;
        }

        part tensionIndicator : TensionIndicator {
            attribute :>> currentReading : TractionForceValue;
            attribute :>> calibrationStatus = true;
        }

        connection anchorToFrame
            connect proximalAnchor.ischialInterface to frame.proximalMount;

        connection hitchToWindlass
            connect distalHitch.ankleInterface to windlass.forceOutput;

        connection windlassToFrame
            connect windlass.windlassControl to frame.distalMount;

        connection indicatorToWindlass
            connect tensionIndicator.sensorInterface to windlass.forceOutput;

        perform action deploymentSequence : DeploySplint;

        exhibit state operationalBehavior : TractionSplintStateMachine;

        assert constraint tractionForceLimit {
            windlass.appliedTraction <= maxAllowableTraction
        }

        assert constraint massLimit {
            totalMass <= 2.5 [kg]
        }

        assert constraint lengthRange {
            frame.currentLength >= frame.minLength and
            frame.currentLength <= frame.maxLength
        }
    }

    requirement <'REQ-TS-100'> primaryFunctionRequirement {
        doc /* The traction splint system shall immobilize and apply controlled 
             * longitudinal traction to a fractured femur to reduce pain, prevent 
             * further tissue damage, minimize blood loss, and maintain bone 
             * alignment by counteracting muscle spasm during emergency transport.
             */
        subject splint : TractionSplint;
    }

    requirement <'REQ-TS-101'> tractionForceControl {
        doc /* The traction splint shall apply and maintain a controlled traction 
             * force between 50 N and 180 N to effectively counteract muscle spasm 
             * without causing additional injury.
             */
        subject windlass :>> TractionSplint::windlass;
        assert constraint {
            windlass.appliedTraction >= 50 [N] and
            windlass.appliedTraction <= windlass.maxTraction
        }
    }

    requirement <'REQ-TS-102'> lengthAdjustability {
        doc /* The traction splint frame shall be adjustable to accommodate patient 
             * limb lengths from 750 mm to 1150 mm to fit a wide range of adult 
             * patients.
             */
        subject frame :>> TractionSplint::frame;
        assert constraint {
            frame.minLength == 750 [mm] and
            frame.maxLength == 1150 [mm]
        }
    }

    requirement <'REQ-TS-103'> portabilityRequirement {
        doc /* The total mass of the traction splint system shall not exceed 2.5 kg 
             * to ensure portability and ease of deployment in emergency field 
             * conditions.
             */
        subject splint : TractionSplint;
        require splint.massLimit;
    }

    requirement <'REQ-TS-104'> stabilizationRequirement {
        doc /* The traction splint shall provide at least four securing straps to 
             * stabilize the injured limb and prevent rotation or lateral movement 
             * during patient transport.
             */
        subject straps :>> TractionSplint::straps;
        assert constraint {
            straps.numberOfStraps >= 4 and
            straps.allSecured == true
        }
    }

    requirement <'REQ-TS-105'> tensionMonitoring {
        doc /* The traction splint shall include a tension indicator to allow 
             * continuous monitoring of applied traction force and ensure it remains 
             * within therapeutic range.
             */
        subject indicator :>> TractionSplint::tensionIndicator;
        assert constraint {
            indicator.calibrationStatus == true
        }
    }

    part tractionSplintSystem : TractionSplint {
        attribute :>> totalMass = 2.3 [kg];
        attribute :>> operationalState = SplintOperationalState::stowed;
        attribute :>> targetTractionForce = 90 [N];
        attribute :>> maxAllowableTraction = 180 [N];
    }

    satisfy primaryFunctionRequirement by tractionSplintSystem;
    satisfy tractionForceControl by tractionSplintSystem.windlass;
    satisfy lengthAdjustability by tractionSplintSystem.frame;
    satisfy portabilityRequirement by tractionSplintSystem;
    satisfy stabilizationRequirement by tractionSplintSystem.straps;
    satisfy tensionMonitoring by tractionSplintSystem.tensionIndicator;
}
