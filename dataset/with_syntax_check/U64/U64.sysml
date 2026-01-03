package 'Gait Belt System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def BeltTension :> ForceValue;
    attribute def PatientWeight :> MassValue;
    attribute def GripForce :> ForceValue;
    attribute def WalkingSpeed :> SpeedValue;
    attribute def BalanceIndex :> Real;
    
    attribute def FitStatus {
        attribute isSecure : Boolean;
        attribute tensionLevel : BeltTension;
        attribute allowsTwoFingers : Boolean;
    }
    
    attribute def MobilityLevel {
        attribute canBearWeight : Boolean;
        attribute requiresMaximalAssist : Boolean;
        attribute balanceScore : BalanceIndex;
    }
    
    enum def TransferType {
        sitToStand;
        standToSit;
        ambulation;
        pivotTransfer;
    }
    
    item def Patient {
        attribute weight : PatientWeight;
        attribute mobilityLevel : MobilityLevel;
        attribute currentPosture : String;
    }
    
    item def Caregiver {
        attribute gripStrength : GripForce;
        attribute isProperlyPositioned : Boolean;
        attribute handPlacement : String;
    }
    
    part def WebbingMaterial {
        attribute width : LengthValue;
        attribute thickness : LengthValue;
        attribute tensileStrength : ForceValue;
        attribute material : String;
    }
    
    part def BuckleAssembly {
        attribute buckleType : String;
        attribute releaseForce : ForceValue;
        attribute isLocked : Boolean;
    }
    
    part def GripHandle {
        attribute location : String;
        attribute surfaceTexture : String;
    }
    
    part def GaitBeltDevice {
        attribute totalLength : LengthValue;
        attribute maxLoadCapacity : ForceValue;
        attribute currentTension : BeltTension;
        
        part webbing : WebbingMaterial {
            attribute width = 50.0[SI::mm];
            attribute thickness = 3.0[SI::mm];
            attribute tensileStrength = 2200.0[SI::N];
            attribute material = "reinforced nylon";
        }
        
        part buckle : BuckleAssembly {
            attribute buckleType = "quick-release metal";
            attribute releaseForce = 35.0[SI::N];
            attribute isLocked = false;
        }
        
        part handles : GripHandle[0..2] {
            attribute location = "center back";
            attribute surfaceTexture = "non-slip";
        }
    }
    
    port def PhysicalSupportInterface {
        attribute supportForce : ForceValue;
        attribute contactPressure : PressureValue;
    }
    
    port def CaregiverGripInterface {
        attribute appliedGripForce : GripForce;
        attribute handPosition : String;
    }
    
    port def PatientContactInterface {
        attribute distributedLoad : ForceValue;
        attribute comfortLevel : Real;
    }
    
    action def AssessPatientMobility {
        in patient : Patient;
        out assessment : MobilityLevel;
        out transferType : TransferType;
        
        first start;
        then action evaluateWeightBearing {
            doc /* Determine if patient can bear own weight */
        }
        then action evaluateBalance {
            doc /* Assess patient balance and stability */
        }
        then action determineAssistLevel {
            doc /* Determine level of assistance required */
        }
        then done;
    }
    
    action def ApplyGaitBelt {
        in patient : Patient;
        in belt : GaitBeltDevice;
        out fitStatus : FitStatus;
        out beltSecured : Boolean;
        
        first start;
        then action positionBeltAtWaist {
            doc /* Position belt around patient waist above iliac crest */
        }
        then action threadThroughBuckle {
            doc /* Thread webbing through buckle mechanism */
        }
        then action adjustForProperFit {
            doc /* Tighten to snug fit allowing two fingers underneath */
        }
        then action lockBuckle {
            doc /* Secure buckle in locked position */
        }
        then action verifySecurement {
            doc /* Verify belt will not slip and buckle is secure */
        }
        then done;
    }
    
    action def EstablishCaregiverGrip {
        in belt : GaitBeltDevice;
        in caregiver : Caregiver;
        out gripSecure : Boolean;
        out gripPosition : String;
        
        first start;
        then action positionBehindPatient {
            doc /* Position caregiver behind or to side of patient */
        }
        then action graspWithUndergripBothHands {
            doc /* Use underhand grip with both hands, knuckles up */
        }
        then action maintainElbowFlexion {
            doc /* Keep elbows bent to maintain mechanical advantage */
        }
        then action verifyFirmGrip {
            doc /* Ensure firm, secure grip on belt */
        }
        then done;
    }
    
    action def ProvideMobilitySupport {
        in patient : Patient;
        in supportForce : BeltTension;
        in walkingSpeed : WalkingSpeed;
        out stabilizationLevel : BalanceIndex;
        out supportVector : String;
        
        first start;
        then action maintainCloseProximity {
            doc /* Stay close to patient during movement */
        }
        then action applyUpwardLift {
            doc /* Apply gentle upward and forward force through belt */
        }
        then action matchPatientPace {
            doc /* Move in sync with patient walking speed */
        }
        then action provideCounterbalance {
            doc /* Provide stabilizing force to prevent falls */
        }
        then done;
    }
    
    action def MonitorPatientStatus {
        in patient : Patient;
        out fatigueIndicator : Real;
        out balanceStatus : BalanceIndex;
        out requiresRest : Boolean;
        out showsDistress : Boolean;
        
        first start;
        then action observeGaitPattern {
            doc /* Monitor patient walking pattern and stability */
        }
        then action assessFatigueLevel {
            doc /* Evaluate signs of patient fatigue */
        }
        then action checkVitalSigns {
            doc /* Monitor breathing, color, verbal responses */
        }
        then action evaluateContinuation {
            doc /* Determine if activity should continue */
        }
        then done;
    }
    
    action def RespondToInstability {
        in balanceStatus : BalanceIndex;
        in currentSupport : BeltTension;
        out correctionForce : ForceValue;
        out correctionDirection : String;
        out emergencyStop : Boolean;
        
        first start;
        then decide;
            if balanceStatus < 0.3 then initiateEmergencyStop;
            if balanceStatus >= 0.3 and balanceStatus < 0.6 then applyStabilization;
            if balanceStatus >= 0.6 then maintainCurrentSupport;
        
        action initiateEmergencyStop {
            doc /* Safely lower patient to nearest surface */
        }
        then done;
        
        action applyStabilization {
            doc /* Increase support force and adjust position */
        }
        then done;
        
        action maintainCurrentSupport {
            doc /* Continue current support level */
        }
        then done;
    }
    
    action def RemoveGaitBelt {
        in patient : Patient;
        in belt : GaitBeltDevice;
        out beltRemoved : Boolean;
        
        first start;
        then action ensurePatientSeated {
            doc /* Verify patient is safely seated or lying */
        }
        then action releaseBuckle {
            doc /* Release buckle mechanism */
        }
        then action removeFromPatient {
            doc /* Carefully remove belt from patient */
        }
        then action inspectBelt {
            doc /* Check belt for wear or damage */
        }
        then done;
    }
    
    state def GaitBeltOperationalStates {
        entry; then assessment;
        
        state assessment {
            do action assessAction : AssessPatientMobility;
        }
        
        transition assessmentToApplication
            first assessment
            if assessAction.assessment.requiresMaximalAssist
            then application;
        
        state application {
            do action applyAction : ApplyGaitBelt;
        }
        
        transition applicationToGripPreparation
            first application
            if applyAction.beltSecured
            then gripPreparation;
        
        state gripPreparation {
            do action gripAction : EstablishCaregiverGrip;
        }
        
        transition gripPreparationToActiveSupport
            first gripPreparation
            if gripAction.gripSecure
            then activeSupport;
        
        state activeSupport {
            do action supportAction : ProvideMobilitySupport;
            do action monitorAction : MonitorPatientStatus;
            
            state normalAmbulation {
                do action maintainSupport : ProvideMobilitySupport;
            }
            
            state stabilizingPatient {
                do action stabilizeAction : RespondToInstability;
            }
            
            state emergencyResponse {
                do action emergencyStopAction : RespondToInstability;
            }
            
            transition normalToStabilizing
                first normalAmbulation
                if monitorAction.balanceStatus < 0.6
                then stabilizingPatient;
            
            transition stabilizingToNormal
                first stabilizingPatient
                if stabilizeAction.correctionForce > 0.0[SI::N] and not stabilizeAction.emergencyStop
                then normalAmbulation;
            
            transition toEmergency
                first normalAmbulation
                if monitorAction.balanceStatus < 0.3
                then emergencyResponse;
        }
        
        transition activeSupportToRemoval
            first activeSupport
            if monitorAction.requiresRest or monitorAction.showsDistress
            then removal;
        
        state removal {
            do action removeAction : RemoveGaitBelt;
        }
        
        transition removalToComplete
            first removal
            then complete;
        
        state complete;
    }
    
    action def PerformAssistedTransfer {
        in patient : Patient;
        in caregiver : Caregiver;
        in gaitBelt : GaitBeltDevice;
        in transferType : TransferType;
        out transferCompleted : Boolean;
        out patientSafety : FitStatus;
        
        first start;
        then merge continueTransfer;
        
        then action assessMobility : AssessPatientMobility {
            in patient = PerformAssistedTransfer::patient;
            out assessment;
            out transferType;
        }
        
        then action applyBelt : ApplyGaitBelt {
            in patient = PerformAssistedTransfer::patient;
            in belt = gaitBelt;
            out fitStatus;
            out beltSecured;
        }
        
        then action establishGrip : EstablishCaregiverGrip {
            in belt = gaitBelt;
            in caregiver = PerformAssistedTransfer::caregiver;
            out gripSecure;
            out gripPosition;
        }
        
        then action provideSupport : ProvideMobilitySupport {
            in patient = PerformAssistedTransfer::patient;
            in supportForce = applyBelt.fitStatus.tensionLevel;
            in walkingSpeed;
            out stabilizationLevel;
            out supportVector;
        }
        
        then action monitorPatient : MonitorPatientStatus {
            in patient = PerformAssistedTransfer::patient;
            out fatigueIndicator;
            out balanceStatus;
            out requiresRest;
            out showsDistress;
        }
        
        then decide;
            if monitorPatient.balanceStatus < 0.3 then emergencyResponse;
            if monitorPatient.balanceStatus >= 0.3 and monitorPatient.balanceStatus < 0.6 then correctInstability;
            if monitorPatient.requiresRest or monitorPatient.showsDistress then completeTransfer;
            if monitorPatient.balanceStatus >= 0.6 and not monitorPatient.requiresRest then continueTransfer;
        
        action emergencyResponse : RespondToInstability {
            in balanceStatus = monitorPatient.balanceStatus;
            in currentSupport = applyBelt.fitStatus.tensionLevel;
            out correctionForce;
            out correctionDirection;
            out emergencyStop;
        }
        then completeTransfer;
        
        action correctInstability : RespondToInstability {
            in balanceStatus = monitorPatient.balanceStatus;
            in currentSupport = applyBelt.fitStatus.tensionLevel;
            out correctionForce;
            out correctionDirection;
            out emergencyStop;
        }
        then continueTransfer;
        
        action completeTransfer {
            doc /* Safely complete transfer and remove belt */
        }
        then action removeBelt : RemoveGaitBelt {
            in patient = PerformAssistedTransfer::patient;
            in belt = gaitBelt;
            out beltRemoved;
        }
        then done;
    }
    
    part gaitBeltSystem {
        doc /* 
            The gait belt system provides safe physical support and mobility assistance
            to patients with limited strength, balance, or endurance during transfers and
            ambulation activities. The system enables caregivers to safely guide and stabilize
            patients while reducing fall risk and preventing injury to both patient and caregiver
            through proper body mechanics and controlled support.
        */
        
        part belt : GaitBeltDevice {
            attribute totalLength = 1.5[SI::m];
            attribute maxLoadCapacity = 1800.0[SI::N];
            attribute currentTension = 0.0[SI::N];
        }
        
        port patientInterface : PatientContactInterface {
            attribute distributedLoad;
            attribute comfortLevel;
        }
        
        port caregiverInterface : CaregiverGripInterface {
            attribute appliedGripForce;
            attribute handPosition;
        }
        
        port supportInterface : PhysicalSupportInterface {
            attribute supportForce;
            attribute contactPressure;
        }
        
        perform action assistedTransfer : PerformAssistedTransfer;
    }
    
    requirement def StructuralIntegrityRequirement {
        doc /* Requirements for gait belt structural integrity */
        subject gaitBeltSystem;
    }
    
    requirement <'GB-REQ-001'> loadCapacityRequirement : StructuralIntegrityRequirement {
        doc /* The gait belt shall withstand loads up to maximum capacity without failure */
        require constraint {
            gaitBeltSystem.belt.webbing.tensileStrength >= gaitBeltSystem.belt.maxLoadCapacity
        }
    }
    
    requirement <'GB-REQ-002'> properFitRequirement : StructuralIntegrityRequirement {
        doc /* The gait belt shall be applied snugly allowing two fingers clearance */
        assume constraint {
            gaitBeltSystem.patientInterface.distributedLoad > 0.0[SI::N]
        }
    }
    
    requirement <'GB-REQ-003'> secureGripRequirement : StructuralIntegrityRequirement {
        doc /* Caregiver shall maintain firm underhand grip during all transfers */
        require constraint {
            gaitBeltSystem.caregiverInterface.appliedGripForce > 60.0[SI::N]
        }
    }
    
    requirement <'GB-REQ-004'> continuousMonitoringRequirement : StructuralIntegrityRequirement {
        doc /* Patient status shall be continuously monitored during mobility assistance */
    }
    
    requirement <'GB-REQ-005'> buckleSecurityRequirement : StructuralIntegrityRequirement {
        doc /* Buckle shall remain locked during transfer activities */
        require constraint {
            gaitBeltSystem.belt.buckle.isLocked == true
        }
    }
    
    requirement primaryMissionRequirement {
        doc /* 
            The gait belt system shall provide safe, effective physical support to enable
            mobility assistance for patients with impaired strength, balance, or endurance,
            allowing caregivers to safely guide and stabilize patients during transfers and
            ambulation while minimizing fall risk and preventing musculoskeletal injury to
            both patient and caregiver through proper biomechanical support techniques.
        */
        
        subject gaitBeltSystem;
        
        require loadCapacityRequirement;
        require properFitRequirement;
        require secureGripRequirement;
        require continuousMonitoringRequirement;
        require buckleSecurityRequirement;
    }
}
