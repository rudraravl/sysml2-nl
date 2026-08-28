package ReviventSystem {
    import ScalarValues::*;
    import SI::*;

    //---------------------------------------------------------------------
    // Value Types (with units)
    //---------------------------------------------------------------------
    value type LengthValue :> Length { unit 'mm'; }
    value type ForceValue :> Force { unit 'N'; }
    value type PressureValue :> Pressure { unit 'Pa'; }
    value type VolumeValue :> Volume { unit 'mL'; }
    value type TimeValue :> Time { unit 's'; }
    value type AngleValue :> PlaneAngle { unit 'deg'; }
    value type EjectionFractionValue :> Real { unit '%'; }
    value type TensionValue :> Force { unit 'N'; }
    value type FluoroscopyDose :> Energy { unit 'mGy'; }

    //---------------------------------------------------------------------
    // Item Types
    //---------------------------------------------------------------------
    item def Blood;
    item def XRayImage;
    item def TensionCommand {
        attribute magnitude : TensionValue;
    }
    item def DeploymentCommand {
        attribute pairIndex : Integer;
    }
    item def LockCommand {
        attribute pairIndex : Integer;
    }
    item def AnchorPlacementData {
        attribute pairIndex : Integer;
        attribute positionError : LengthValue;
        attribute embedded : Boolean;
    }
    item def VerificationResult {
        attribute pairIndex : Integer;
        attribute residualVolume : VolumeValue;
        attribute ejectionFraction : EjectionFractionValue;
        attribute accepted : Boolean;
    }
    item def PhysiologicalFeedback {
        attribute heartRate : Real { unit 'bpm'; }
        attribute bloodPressure : PressureValue;
    }

    //---------------------------------------------------------------------
    // Port Definitions
    //---------------------------------------------------------------------
    port def ImagePort {
        out item XRayImage;
    }
    port def CommandPort {
        in item DeploymentCommand;
        in item TensionCommand;
        in item LockCommand;
    }
    port def FeedbackPort {
        out item AnchorPlacementData;
        out item VerificationResult;
        out item PhysiologicalFeedback;
    }
    port def BloodFlowPort {
        in item Blood;
        out item Blood;
    }
    port def AnchorMechanicalPort {
        attribute tension : TensionValue;
        attribute locked : Boolean;
    }

    //---------------------------------------------------------------------
    // Requirements
    //---------------------------------------------------------------------
    requirement def RestoreVentricularVolume {
        subject heart : PatientHeart;
        objective {
            doc /* Reduce left ventricular end-systolic volume by at least 30%. */
            heart.reducedVolume >= 0.30 * heart.initialVolume
        }
    }

    requirement def ImproveEjectionFraction {
        subject heart : PatientHeart;
        objective {
            heart.postProcedureEF >= 35.0 [%]
        }
    }

    requirement def MinimallyInvasiveProcedure {
        subject procedure : ProcedureController;
        objective {
            procedure.openHeartSurgeryPerformed == false
        }
    }

    requirement def AnchorDeploymentAccuracy {
        subject anchor : MicroAnchor;
        objective {
            anchor.placementError <= 2.0 [mm]
        }
    }

    requirement def TensionRange {
        subject mechanism : TensioningMechanism;
        objective {
            mechanism.appliedTension >= 0.5 [N] and mechanism.appliedTension <= 5.0 [N]
        }
    }

    requirement def FluoroscopyVisibility {
        subject fluoroscopy : FluoroscopyGuidanceSystem;
        objective {
            fluoroscopy.frameRate >= 15.0 [frame/s]
        }
    }

    requirement def ProcedureCompletion {
        subject controller : ProcedureController;
        objective {
            controller.allPairsLocked == true and
            controller.catheterWithdrawn == true
        }
    }

    //---------------------------------------------------------------------
    // Part Definitions
    //---------------------------------------------------------------------
    part def MicroAnchor {
        attribute identifier : String;
        attribute embedded : Boolean = false;
        attribute locked : Boolean = false;
        attribute placementError : LengthValue = 0.0 [mm];
        attribute deploymentDepth : LengthValue = 3.0 [mm];
        port mechanical : AnchorMechanicalPort;

        action def Embed :> Action {
            in targetDepth : LengthValue;
            out placement : AnchorPlacementData;
        }

        action def Lock :> Action {
            out confirmed : Boolean;
        }

        perform action embed : Embed;
        perform action lock : Lock;
    }

    part def MicroAnchorArray {
        attribute pairCount : Integer = 0;
        part anchorPairs : MicroAnchor[2..*] ordered;

        action def DeployPair :> Action {
            in pairIndex : Integer;
            in site : LengthValue;
            out placement : AnchorPlacementData;
        }

        action def TensionPair :> Action {
            in pairIndex : Integer;
            in targetTension : TensionValue;
            out achieved : Boolean;
        }

        action def LockPair :> Action {
            in pairIndex : Integer;
            out locked : Boolean;
        }

        perform action deploy : DeployPair;
        perform action tension : TensionPair;
        perform action lockPair : LockPair;
    }

    part def DeliveryCatheter {
        attribute length : LengthValue = 1100.0 [mm];
        attribute outerDiameter : LengthValue = 3.3 [mm];
        attribute insertionSite : String = "femoralVein";
        attribute navigated : Boolean = false;
        attribute withdrawn : Boolean = false;

        port proximalCommand : CommandPort;
        port distalFeedback : FeedbackPort;
        port imageFeed : ImagePort;

        part def CatheterHandle {
            attribute tensionDialPosition : AngleValue = 0.0 [deg];
            attribute deploymentTrigger : Boolean = false;
            attribute lockSwitch : Boolean = false;

            action def AdjustTension :> Action {
                in delta : AngleValue;
                out command : TensionCommand;
            }

            action def TriggerDeployment :> Action {
                out command : DeploymentCommand;
            }

            action def EngageLock :> Action {
                out command : LockCommand;
            }

            perform action adjust : AdjustTension;
            perform action trigger : TriggerDeployment;
            perform action engage : EngageLock;
        }

        part def CatheterShaft {
            attribute flexible : Boolean = true;
            attribute trackedPosition : LengthValue = 0.0 [mm];
        }

        part handle : CatheterHandle;
        part shaft : CatheterShaft;

        action def Navigate :> Action {
            in targetSite : LengthValue;
            out arrived : Boolean;
        }

        action def Withdraw :> Action {
            out withdrawn : Boolean;
        }

        perform action navigate : Navigate;
        perform action withdraw : Withdraw;
    }

    part def TensioningMechanism {
        attribute appliedTension : TensionValue = 0.0 [N];
        attribute maxTension : TensionValue = 5.0 [N];
        attribute resolution : TensionValue = 0.1 [N];
        port commandInput : CommandPort;
        port mechanicalOutput : AnchorMechanicalPort;

        action def ApplyTension :> Action {
            in command : TensionCommand;
            out achieved : Boolean;
        }

        action def ReleaseTension :> Action {
            out released : Boolean;
        }

        perform action apply : ApplyTension;
        perform action release : ReleaseTension;
    }

    part def FluoroscopyGuidanceSystem {
        attribute frameRate : Real = 30.0 { unit 'frame/s'; };
        attribute resolution : LengthValue = 0.5 [mm];
        attribute cumulativeDose : FluoroscopyDose = 0.0 [mGy];
        port imageOutput : ImagePort;

        action def AcquireImage :> Action {
            in exposureTime : TimeValue;
            out image : XRayImage;
        }

        action def TrackCatheter :> Action {
            in image : XRayImage;
            out position : LengthValue;
        }

        perform action acquire : AcquireImage;
        perform action track : TrackCatheter;
    }

    part def PatientHeart {
        attribute initialVolume : VolumeValue = 220.0 [mL];
        attribute reducedVolume : VolumeValue = 0.0 [mL];
        attribute preProcedureEF : EjectionFractionValue = 25.0 [%];
        attribute postProcedureEF : EjectionFractionValue = 25.0 [%];
        attribute scarTissueArea : LengthValue = 1500.0 [mm²];
        port bloodFlow : BloodFlowPort;
        port physiologicalOut : FeedbackPort;

        part def LeftVentricle {
            attribute endSystolicVolume : VolumeValue;
            attribute endDiastolicVolume : VolumeValue;
            attribute wallThickness : LengthValue = 8.0 [mm];
            port flow : BloodFlowPort;
        }

        part leftVentricle : LeftVentricle;

        action def Contract :> Action {
            in bloodIn : Blood;
            out bloodOut : Blood;
        }

        action def Reshape :> Action {
            in foldDepth : LengthValue;
            out newVolume : VolumeValue;
        }

        perform action contract : Contract;
        perform action reshape : Reshape;
    }

    part def ProcedureController {
        attribute openHeartSurgeryPerformed : Boolean = false;
        attribute allPairsLocked : Boolean = false;
        attribute catheterWithdrawn : Boolean = false;
        attribute currentPhase : String = "Idle";
        attribute targetPairs : Integer = 4;
        attribute completedPairs : Integer = 0;

        port commandOut : CommandPort;
        port feedbackIn : FeedbackPort;
        port imageIn : ImagePort;

        action def ExecuteProcedure :> Action {
            in patient : PatientHeart;
            out result : VerificationResult;
        }

        perform action execute : ExecuteProcedure;
    }

    //---------------------------------------------------------------------
    // State Machine for Procedure Phases
    //---------------------------------------------------------------------
    state machine def ProcedureStateMachine {
        attribute phase : String;

        state Idle;
        state Navigating {
            entry { phase = "Navigating"; }
            do action navigateCatheter : DeliveryCatheter::Navigate;
        }
        state Deploying {
            entry { phase = "Deploying"; }
            do action deployPair : MicroAnchorArray::DeployPair;
        }
        state Tensioning {
            entry { phase = "Tensioning"; }
            do action tensionPair : MicroAnchorArray::TensionPair;
        }
        state Verifying {
            entry { phase = "Verifying"; }
            do action verifyResult : Action {
                out verification : VerificationResult;
            }
        }
        state Locking {
            entry { phase = "Locking"; }
            do action lockPair : MicroAnchorArray::LockPair;
        }
        state Advancing {
            entry { phase = "Advancing"; }
        }
        state Completing {
            entry { phase = "Completing"; }
            do action withdrawCatheter : DeliveryCatheter::Withdraw;
        }
        state Done {
            entry { phase = "Done"; }
        }

        transition Idle -> Navigating
            when (true)
            accept StartProcedure;

        transition Navigating -> Deploying
            when (DeliveryCatheter.navigated == true)
            accept ArrivalAtTarget;

        transition Deploying -> Tensioning
            when (MicroAnchorArray.anchorPairs->forAll(a | a.embedded == true))
            accept PairDeployed;

        transition Tensioning -> Verifying
            when (TensioningMechanism.appliedTension >= 0.5 [N])
            accept TensionApplied;

        transition Verifying -> Locking
            when (VerificationResult.accepted == true)
            accept VerificationPassed;

        transition Verifying -> Tensioning
            when (VerificationResult.accepted == false)
            accept VerificationFailed;

        transition Locking -> Advancing
            when (MicroAnchorArray.anchorPairs->forAll(a | a.locked == true))
            accept PairLocked;

        transition Advancing -> Deploying
            when (ProcedureController.completedPairs < ProcedureController.targetPairs)
            accept NextPair;

        transition Advancing -> Completing
            when (ProcedureController.completedPairs == ProcedureController.targetPairs)
            accept AllPairsComplete;

        transition Completing -> Done
            when (DeliveryCatheter.withdrawn == true)
            accept CatheterWithdrawn;
    }

    //---------------------------------------------------------------------
    // Top-level System Assembly
    //---------------------------------------------------------------------
    part reviventSystem :> ReviventSystem {
        part deliveryCatheter : DeliveryCatheter;
        part microAnchorArray : MicroAnchorArray {
            part anchorPairs : MicroAnchor[8] ordered;
        }
        part fluoroscopy : FluoroscopyGuidanceSystem;
        part tensioningMechanism : TensioningMechanism;
        part patientHeart : PatientHeart;
        part controller : ProcedureController;

        // Requirement satisfactions
        satisfy RestoreVentricularVolume by patientHeart;
        satisfy ImproveEjectionFraction by patientHeart;
        satisfy MinimallyInvasiveProcedure by controller;
        satisfy AnchorDeploymentAccuracy by microAnchorArray.anchorPairs;
        satisfy TensionRange by tensioningMechanism;
        satisfy FluoroscopyVisibility by fluoroscopy;
        satisfy ProcedureCompletion by controller;

        // Connections
        connection fluoroscopy.imageOutput to controller.imageIn;
        connection fluoroscopy.imageOutput to deliveryCatheter.imageFeed;
        connection controller.commandOut to deliveryCatheter.proximalCommand;
        connection deliveryCatheter.distalFeedback to controller.feedbackIn;
        connection deliveryCatheter.proximalCommand to tensioningMechanism.commandInput;
        connection tensioningMechanism.mechanicalOutput to microAnchorArray.anchorPairs.mechanical;
        connection microAnchorArray.anchorPairs.mechanical to patientHeart.leftVentricle.flow;
        connection patientHeart.physiologicalOut to controller.feedbackIn;

        // State machine instance
        part procedureState : ProcedureStateMachine;

        // Procedure execution action
        action performProcedure : ProcedureController::ExecuteProcedure {
            in patient = patientHeart;
            out result;
        }
    }
}
