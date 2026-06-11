package CrosbyKuglerCapsuleSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure;
    attribute def Force;
    attribute def Length;
    attribute def Volume;
    attribute def Time;
    attribute def Mass;
    attribute def Temperature;

    item def TissueSample {
        attribute sampleMass : Mass;
        attribute sampleDiameter : Length;
        attribute sampleDepth : Length;
        attribute mucosalIntegrity : Real;
        attribute contaminationRisk : Real;
    }

    item def SuctionFlow {
        attribute flowRate : Real;
        attribute vacuumPressure : Pressure;
        attribute duration : Time;
    }

    item def ControlSignal {
        attribute command : String;
        attribute issuedAt : Time;
    }

    item def CapsulePosition {
        attribute distanceFromMouth : Length;
        attribute orientationAngle : Real;
        attribute locatedInTargetSite : Boolean;
    }

    value def BiopsyMode {
        enum idle;
        enum positioned;
        enum suctionApplied;
        enum tissueCaptured;
        enum bladeTriggered;
        enum sampleSecured;
        enum retrieval;
        enum complete;
        enum fault;
    }

    part def CrosbyKuglerCapsule {
        attribute capsuleLength : Length = 18 [SI::mm];
        attribute capsuleOuterDiameter : Length = 8 [SI::mm];
        attribute biopsyPortDiameter : Length = 3 [SI::mm];
        attribute chamberVolume : Volume = 0.06 [SI::mL];
        attribute sterile : Boolean = true;
        attribute reusableAfterSterilization : Boolean = true;

        port suctionPort;
        port guideTubePort;
        port triggerPort;
        port samplePort;
        port positionPort;

        part capsuleShell {
            attribute material : String = "medical grade stainless steel";
            attribute roundedAtraumaticNose : Boolean = true;
            attribute sideWindowPresent : Boolean = true;
        }

        part biopsyWindow {
            attribute apertureDiameter : Length = 3 [SI::mm];
            attribute edgeRounded : Boolean = true;
            attribute targetContactArea : Length = 4 [SI::mm];
        }

        part sampleChamber {
            attribute retainedSample : TissueSample;
            attribute sealedDuringRetrieval : Boolean = true;
            attribute minimumSampleMass : Mass = 5 [SI::mg];
        }

        part springLoadedKnife {
            attribute storedSpringForce : Force = 2.5 [SI::N];
            attribute bladeTravel : Length = 3 [SI::mm];
            attribute bladeSharpnessIndex : Real = 0.95;
            attribute lockedBeforeTrigger : Boolean = true;
        }

        part triggerWireInterface {
            attribute triggerTravelRequired : Length = 12 [SI::mm];
            attribute accidentalReleasePrevented : Boolean = true;
        }

        action def CaptureMucosalSample {
            in suction : SuctionFlow;
            out specimen : TissueSample;

            first start;
            then verifyPosition;
            then drawMucosaIntoWindow;
            then releaseKnife;
            then transferTissueToChamber;
            then confirmSampleRetained;
            then done;

            flow start to verifyPosition;
            flow verifyPosition to drawMucosaIntoWindow;
            flow drawMucosaIntoWindow to releaseKnife;
            flow releaseKnife to transferTissueToChamber;
            flow transferTissueToChamber to confirmSampleRetained;
            flow confirmSampleRetained to done;
        }

        state def CapsuleOperatingState {
            entry action Initialize {
                out mode : BiopsyMode = BiopsyMode::idle;
            }

            state Idle;
            state Positioned;
            state SuctionApplied;
            state TissueCaptured;
            state BladeTriggered;
            state SampleSecured;
            state Retrieval;
            state Complete;
            state Fault;

            transition first Idle;
            transition Idle_to_Positioned
                first Idle
                then Positioned
                accept ControlSignal
                if command == "confirm target position";

            transition Positioned_to_SuctionApplied
                first Positioned
                then SuctionApplied
                accept SuctionFlow
                if vacuumPressure <= -50 [SI::kPa];

            transition SuctionApplied_to_TissueCaptured
                first SuctionApplied
                then TissueCaptured
                if duration >= 1 [SI::s];

            transition TissueCaptured_to_BladeTriggered
                first TissueCaptured
                then BladeTriggered
                accept ControlSignal
                if command == "fire blade";

            transition BladeTriggered_to_SampleSecured
                first BladeTriggered
                then SampleSecured;

            transition SampleSecured_to_Retrieval
                first SampleSecured
                then Retrieval
                accept ControlSignal
                if command == "retrieve capsule";

            transition Retrieval_to_Complete
                first Retrieval
                then Complete;

            transition Any_to_Fault
                first Idle
                then Fault
                accept ControlSignal
                if command == "abort";
        }
    }

    part def BiopsyControlAssembly {
        port clinicianCommandPort;
        port triggerWirePort;
        port suctionCommandPort;

        part triggerHandle {
            attribute triggerForce : Force = 8 [SI::N];
            attribute guardedRelease : Boolean = true;
            attribute tactileReleaseFeedback : Boolean = true;
        }

        part vacuumController {
            attribute nominalVacuumPressure : Pressure = -60 [SI::kPa];
            attribute maximumVacuumPressure : Pressure = -80 [SI::kPa];
            attribute suctionDuration : Time = 2 [SI::s];
            attribute pressureReliefValvePresent : Boolean = true;
        }

        action def ApplyBiopsyCommand {
            in command : ControlSignal;
            out suction : SuctionFlow;
            out triggerRelease : ControlSignal;
        }
    }

    part def PatientInterface {
        port oralInsertionPort;
        port intestinalContactPort;
        port sampleRetrievalPort;

        part flexibleGuideTube {
            attribute tubeLength : Length = 1500 [SI::mm];
            attribute tubeOuterDiameter : Length = 3 [SI::mm];
            attribute suctionLumenPresent : Boolean = true;
            attribute triggerWireLumenPresent : Boolean = true;
        }

        part positioningProcess {
            attribute targetRegion : String = "proximal small intestine";
            attribute fluoroscopicOrClinicalConfirmation : Boolean = true;
            attribute insertionTraumaRisk : Real = 0.02;
        }
    }

    part def CrosbyKuglerBiopsySystem {
        attribute primaryFunction : String =
            "Obtain a small mucosal biopsy specimen from the small intestine by positioning an ingestible capsule at a target site, applying suction to draw tissue into a side window, cutting the captured tissue with a spring-loaded knife, retaining the specimen, and retrieving it through the attached tube.";

        part capsule : CrosbyKuglerCapsule;
        part controller : BiopsyControlAssembly;
        part patientInterface : PatientInterface;

        port operatorInput;
        port suctionSource;
        port specimenOutput;
        port patientAccess;

        connection suctionLine
            connect controller.suctionCommandPort to capsule.suctionPort;

        connection triggerLine
            connect controller.triggerWirePort to capsule.triggerPort;

        connection guideTubeConnection
            connect patientInterface.flexibleGuideTube to capsule.guideTubePort;

        connection specimenPath
            connect capsule.samplePort to specimenOutput;

        connection patientRoute
            connect patientAccess to patientInterface.oralInsertionPort;

        action def PerformCapsuleBiopsy {
            in targetPosition : CapsulePosition;
            out biopsySpecimen : TissueSample;

            first prepareDevice;
            then insertCapsule;
            then positionAtTarget;
            then applyControlledSuction;
            then captureTissue;
            then actuateBlade;
            then secureSpecimen;
            then retrieveCapsule;
            then transferSpecimen;
            then finish;

            flow prepareDevice to insertCapsule;
            flow insertCapsule to positionAtTarget;
            flow positionAtTarget to applyControlledSuction;
            flow applyControlledSuction to captureTissue;
            flow captureTissue to actuateBlade;
            flow actuateBlade to secureSpecimen;
            flow secureSpecimen to retrieveCapsule;
            flow retrieveCapsule to transferSpecimen;
            flow transferSpecimen to finish;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : CrosbyKuglerBiopsySystem;
        doc
            /* The system shall obtain a diagnostically useful mucosal tissue sample from a target region of the small intestine using a suction-assisted capsule biopsy mechanism. */
    }

    requirement def TissueCaptureRequirement {
        subject capsule : CrosbyKuglerCapsule;
        require constraint {
            capsule.sampleChamber.minimumSampleMass >= 5 [SI::mg]
        }
        doc
            /* The capsule shall retain a tissue sample of sufficient mass for histologic evaluation after blade actuation and retrieval. */
    }

    requirement def SuctionSafetyRequirement {
        subject controller : BiopsyControlAssembly;
        require constraint {
            controller.vacuumController.maximumVacuumPressure >= -80 [SI::kPa]
        }
        doc
            /* The vacuum controller shall limit suction to prevent excessive mucosal injury while still drawing tissue into the biopsy window. */
    }

    requirement def MechanicalTriggerRequirement {
        subject capsule : CrosbyKuglerCapsule;
        require constraint {
            capsule.springLoadedKnife.bladeTravel >= capsule.biopsyWindow.apertureDiameter
        }
        doc
            /* The spring-loaded knife shall travel far enough to sever tissue drawn through the biopsy window. */
    }

    requirement def RetrievalRequirement {
        subject system : CrosbyKuglerBiopsySystem;
        doc
            /* The system shall keep the capsule mechanically attached to the guide tube so the capsule and retained specimen can be withdrawn after sampling. */
    }

    requirement def SterilityRequirement {
        subject capsule : CrosbyKuglerCapsule;
        require constraint {
            capsule.sterile == true
        }
        doc
            /* Patient-contacting capsule surfaces shall be sterile before insertion. */
    }

    satisfy PrimaryFunctionRequirement by CrosbyKuglerBiopsySystem;
    satisfy TissueCaptureRequirement by CrosbyKuglerCapsule;
    satisfy SuctionSafetyRequirement by BiopsyControlAssembly;
    satisfy MechanicalTriggerRequirement by CrosbyKuglerCapsule;
    satisfy RetrievalRequirement by CrosbyKuglerBiopsySystem;
    satisfy SterilityRequirement by CrosbyKuglerCapsule;

    part system : CrosbyKuglerBiopsySystem;

}