package 'Spica Splint System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ImmobilizationAngle;
    attribute def CompressionLevel;
    attribute def HealingStatus;
    
    item def SpicaSplint;
    item def RigidShell;
    item def PaddingLayer;
    item def FasteningSystem;
    item def ThumbComponent;
    item def WristComponent;
    
    part def PatientLimb {
        part thumb;
        part wrist;
        part forearm;
        attribute currentAngle : ISQ::AngleValue;
        attribute swellingLevel : Real;
    }
    
    part def Patient {
        part affectedLimb : PatientLimb;
        attribute painLevel : Real;
        attribute mobilityRestriction : Real;
    }
    
    port def StabilizationInterface {
        attribute appliedPressure : ISQ::PressureValue;
        attribute contactForce : ISQ::ForceValue;
        attribute immobilizationEffectiveness : Real;
    }
    
    port def ComfortInterface {
        attribute paddingThickness : ISQ::LengthValue;
        attribute ventilation : Real;
        attribute pressureDistribution : Real;
    }
    
    part spicaSplintSystem : SpicaSplint {
        doc /*
        A Spica splint system designed to immobilize the thumb and wrist
        in a therapeutic position to facilitate healing of fractures, ligament injuries,
        or post-operative recovery. The system maintains anatomical alignment while
        restricting motion at the carpometacarpal and wrist joints.
        */
        
        part shellStructure : RigidShell {
            attribute material = "thermoplastic composite";
            attribute thickness : ISQ::LengthValue = 3.5;
            attribute structuralRigidity : Real = 0.92;
            attribute weight : ISQ::MassValue = 85.0;
        }
        
        part padding : PaddingLayer {
            attribute material = "closed-cell foam";
            attribute thickness : ISQ::LengthValue = 6.0;
            attribute compressionResistance : Real = 0.78;
            attribute moistureWicking : Real = 0.85;
        }
        
        part thumbSupport : ThumbComponent {
            attribute targetAngle : ISQ::AngleValue = 45.0;
            attribute supportLength : ISQ::LengthValue = 75.0;
            attribute abductionAngle : ISQ::AngleValue = 40.0;
            port thumbStabilization : StabilizationInterface;
        }
        
        part wristSupport : WristComponent {
            attribute targetAngle : ISQ::AngleValue = 20.0;
            attribute supportLength : ISQ::LengthValue = 140.0;
            attribute extensionAngle : ISQ::AngleValue = 15.0;
            port wristStabilization : StabilizationInterface;
        }
        
        part fasteningStraps : FasteningSystem {
            attribute strapCount : Integer = 4;
            attribute maxTension : ISQ::ForceValue = 60.0;
            attribute adjustmentRange : ISQ::LengthValue = 40.0;
            attribute securityLevel : Real = 0.95;
        }
        
        port comfortInterface : ComfortInterface;
        port primaryStabilization : StabilizationInterface;
        
        perform action maintainImmobilization[*] ordered;
    }
    
    action def EvaluateFit {
        in patient : Patient;
        in splint : SpicaSplint;
        out fitScore : Real;
        out pressurePoints : Real;
        out alignmentAccuracy : Real;
    }
    
    action def ApplySplintToLimb {
        in patient : Patient;
        in splint : SpicaSplint;
        in targetThumbAngle : ISQ::AngleValue;
        in targetWristAngle : ISQ::AngleValue;
        out applicationSuccess : Boolean;
    }
    
    action def MonitorTherapeuticProgress {
        in patient : Patient;
        in timeElapsed : ISQ::TimeValue;
        out healingRate : Real;
        out comfortScore : Real;
        out complianceLevel : Real;
    }
    
    action def AdjustCompression {
        in currentPressure : ISQ::PressureValue;
        in targetPressure : ISQ::PressureValue;
        in strapTension : ISQ::ForceValue;
        out adjustedTension : ISQ::ForceValue;
    }
    
    action def MaintainImmobilization {
        doc /*
        Primary therapeutic function: Immobilize the thumb and wrist in optimal
        anatomical positions to promote healing, reduce pain, and prevent further
        injury while maintaining adequate circulation and patient comfort throughout
        the treatment period.
        */
        
        first start;
        
        then action evaluateFit : EvaluateFit {
            in patient : Patient;
            in splint = spicaSplintSystem;
            out fitScore : Real;
            out pressurePoints : Real;
            out alignmentAccuracy : Real;
        }
        
        then decide;
            if evaluateFit.fitScore >= 0.80 and evaluateFit.alignmentAccuracy >= 0.85 then proceedWithApplication;
            if evaluateFit.fitScore < 0.80 or evaluateFit.alignmentAccuracy < 0.85 then adjustCompression;
        
        action adjustCompression : AdjustCompression {
            in currentPressure : ISQ::PressureValue;
            in targetPressure : ISQ::PressureValue = 25.0;
            in strapTension : ISQ::ForceValue;
            out adjustedTension : ISQ::ForceValue;
        }
        then evaluateFit;
        
        action proceedWithApplication : ApplySplintToLimb {
            in patient : Patient;
            in splint = spicaSplintSystem;
            in targetThumbAngle : ISQ::AngleValue = 45.0;
            in targetWristAngle : ISQ::AngleValue = 20.0;
            out applicationSuccess : Boolean;
        }
        
        then merge therapeuticMonitoring;
        
        then action monitorProgress : MonitorTherapeuticProgress {
            in patient : Patient;
            in timeElapsed : ISQ::TimeValue;
            out healingRate : Real;
            out comfortScore : Real;
            out complianceLevel : Real;
        }
        
        then decide;
            if monitorProgress.healingRate < 0.95 and monitorProgress.comfortScore >= 0.70 then therapeuticMonitoring;
            if monitorProgress.healingRate >= 0.95 then initiateRemoval;
            if monitorProgress.comfortScore < 0.70 then adjustCompression;
        
        action initiateRemoval;
        then done;
    }
    
    state def SplintLifecycle {
        entry; then unfitted;
        
        state unfitted;
        accept at unfitted then fitting via beginFitting;
        
        state fitting {
            entry; then action evaluateLimbDimensions;
        }
        accept at fitting then applied via fitAcceptable;
        
        state applied {
            do action maintainPosition;
            
            entry; then activeImmobilization;
            
            state activeImmobilization {
                entry; then thumbStabilized;
                state thumbStabilized;
                accept at thumbStabilized then wristStabilized;
                state wristStabilized;
                accept at wristStabilized then bothStabilized;
                state bothStabilized;
            }
        }
        accept at applied then monitoring via afterTwoHours;
        
        state monitoring {
            do action checkCirculation;
            do action assessComfort;
        }
        accept at monitoring then adjusting via discomfortDetected;
        accept at monitoring then applied via statusNormal;
        
        state adjusting {
            do action modifyCompression;
        }
        accept at adjusting then applied via adjustmentComplete;
        
        accept at applied then removed via treatmentComplete;
        
        state removed;
    }
    
    requirement <'SPLINT-REQ-001'> thumbImmobilizationRequirement {
        doc /*
        The splint shall immobilize the thumb in 40-50 degrees of palmar abduction
        and maintain the carpometacarpal joint in a position that minimizes stress
        on healing structures.
        */
        
        subject spicaSplintSystem;
        
        require constraint {
            spicaSplintSystem.thumbSupport.targetAngle >= 40.0 and
            spicaSplintSystem.thumbSupport.targetAngle <= 50.0 and
            spicaSplintSystem.thumbSupport.abductionAngle >= 35.0 and
            spicaSplintSystem.thumbSupport.abductionAngle <= 45.0
        }
    }
    
    requirement <'SPLINT-REQ-002'> wristImmobilizationRequirement {
        doc /*
        The splint shall immobilize the wrist in 15-25 degrees of extension
        to maintain optimal healing position and prevent flexion contracture.
        */
        
        subject spicaSplintSystem;
        
        require constraint {
            spicaSplintSystem.wristSupport.targetAngle >= 15.0 and
            spicaSplintSystem.wristSupport.targetAngle <= 25.0 and
            spicaSplintSystem.wristSupport.extensionAngle >= 10.0 and
            spicaSplintSystem.wristSupport.extensionAngle <= 20.0
        }
    }
    
    requirement <'SPLINT-REQ-003'> comfortAndSafetyRequirement {
        doc /*
        The splint shall provide adequate padding to prevent pressure ulcers
        and maintain contact pressure below circulatory compromise threshold
        during extended wear periods up to 6 weeks.
        */
        
        subject spicaSplintSystem;
        
        require constraint {
            spicaSplintSystem.padding.thickness >= 5.0 and
            spicaSplintSystem.padding.compressionResistance >= 0.75 and
            spicaSplintSystem.primaryStabilization.appliedPressure <= 30.0
        }
    }
    
    requirement <'SPLINT-REQ-004'> structuralIntegrityRequirement {
        doc /*
        The splint shall maintain structural rigidity sufficient to prevent
        unwanted motion while remaining lightweight to minimize patient burden
        and facilitate activities of daily living.
        */
        
        subject spicaSplintSystem;
        
        require constraint {
            spicaSplintSystem.shellStructure.structuralRigidity >= 0.90 and
            spicaSplintSystem.shellStructure.thickness >= 3.0 and
            spicaSplintSystem.shellStructure.weight <= 100.0
        }
    }
    
    requirement <'SPLINT-REQ-005'> adjustabilityRequirement {
        doc /*
        The splint shall provide adjustable fastening to accommodate varying
        limb dimensions, edema fluctuations, and individual patient anatomy
        throughout the healing process.
        */
        
        subject spicaSplintSystem;
        
        require constraint {
            spicaSplintSystem.fasteningStraps.strapCount >= 3 and
            spicaSplintSystem.fasteningStraps.adjustmentRange >= 30.0 and
            spicaSplintSystem.fasteningStraps.securityLevel >= 0.90
        }
    }
    
    requirement <'SPLINT-REQ-006'> primaryTherapeuticRequirement {
        doc /*
        The Spica splint system shall provide effective therapeutic immobilization
        of the thumb and wrist to facilitate healing of fractures, ligament injuries,
        or post-surgical conditions while maintaining patient comfort, preventing
        complications, and supporting functional recovery.
        */
        
        subject spicaSplintSystem;
        
        assume constraint patientCompliance {
            doc /* Patient adheres to prescribed wearing schedule and activity restrictions. */
        }
        
        assume constraint properApplication {
            doc /* Splint is applied by trained healthcare professional according to clinical guidelines. */
        }
        
        require thumbImmobilizationRequirement;
        require wristImmobilizationRequirement;
        require comfortAndSafetyRequirement;
        require structuralIntegrityRequirement;
        require adjustabilityRequirement;
    }
    
    part patient : Patient;
    
    connection limbToSplint connect 
        patient.affectedLimb to spicaSplintSystem.primaryStabilization;
    
    exhibit systemLifecycle : SplintLifecycle;
}
