package PessaryMechanicalSupportSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    value def Stiffness :> Real { unit N/m; }
    value def SupportForce :> Real { unit N; }
    value def ContactPressure :> Real { unit Pa; }
    value def Elevation :> Real { unit m; }
    value def RingDiameter :> Real {> Length { unit mm; } }
    value def RingCrossSection :> Real {> Length { unit mm; } }
    value def ComfortScore :> Real { unit "1"; min 0; max 10; }
    value def WearDuration :> Real { unit h; }
    value def StabilityIndex :> Real { unit "1"; min 0; max 1; }

    // ---- Item definitions ----
    item def PelvicOrgan {
        attribute normalPosition : Elevation;
        attribute prolapsedPosition : Elevation;
        attribute organMass : Mass;
        attribute currentElevation : Elevation;
    }
    item def Bladder :> PelvicOrgan;
    item def Uterus :> PelvicOrgan;
    item def Rectum :> PelvicOrgan;

    item def VaginalTissue {
        attribute tissueThickness : Length;
        attribute elasticity : Stiffness;
        attribute maxTolerablePressure : ContactPressure;
        attribute currentPressure : ContactPressure;
    }

    item def PelvicFloorMuscle {
        attribute restingTone : SupportForce;
        attribute contractionForce : SupportForce;
        attribute currentSupport : SupportForce;
    }

    // ---- Port definitions ----
    port def MechanicalSupportPort {
        out supportForce : SupportForce;
        in organLoad : SupportForce;
    }
    port def TissueContactPort {
        out contactPressure : ContactPressure;
        in tissueReaction : ContactPressure;
    }
    port def OrganInterfacePort {
        in appliedElevation : Elevation;
        out organWeight : SupportForce;
    }

    // ---- Pessary Device ----
    part def PessaryDevice {
        attribute ringDiameter : RingDiameter;
        attribute crossSectionDiameter : RingCrossSection;
        attribute materialStiffness : Stiffness;
        attribute materialElasticModulus : Pressure;
        attribute maxDeformation : Length;
        attribute currentDeformation : Length;
        attribute insertionState : InsertionState;

        enum def InsertionState { notInserted; beingInserted; inPlace; beingRemoved; }

        port organSupportPort : MechanicalSupportPort;
        port tissueContactPort : TissueContactPort;
        port bladderInterface : OrganInterfacePort;
        port uterusInterface : OrganInterfacePort;

        attribute generatedSupportForce : SupportForce;
        attribute appliedContactPressure : ContactPressure;

        action def GenerateSupport :> Action {
            in organLoad : SupportForce;
            out supportForce : SupportForce;
        }

        action def DistributePressure :> Action {
            in deformation : Length;
            out contactPressure : ContactPressure;
        }

        state def PessaryOperationalState {
            entry; then Idle;
            state Idle;
            state AssessingFit;
            state Inserting {
                entry;
                do insertDevice;
            }
            state Positioned {
                entry;
                do provideSupport;
            }
            state MonitoringStability {
                do checkStability;
            }
            state Adjusting;
            state Removing;
            transition idle_to_assess
                first Idle then AssessingFit
                when assessmentRequested;
            transition assess_to_insert
                first AssessingFit then Inserting
                when fitApproved;
            transition insert_to_positioned
                first Inserting then Positioned
                when insertionComplete;
            transition positioned_to_monitor
                first Positioned then MonitoringStability
                when patientActive;
            transition monitor_to_positioned
                first MonitoringStability then Positioned
                when stable;
            transition monitor_to_adjusting
                first MonitoringStability then Adjusting
                when instabilityDetected;
            transition adjusting_to_positioned
                first Adjusting then Positioned
                when adjustmentComplete;
            transition positioned_to_removing
                first Positioned then Removing
                when removalRequested;
            transition removing_to_idle
                first Removing then Idle
                when removalComplete;
        }

        action insertDevice :> Action;
        action provideSupport :> Action;
        action checkStability :> Action;
    }

    // ---- Patient anatomy ----
    part def PatientAnatomy {
        part bladder : Bladder {
            attribute normalPosition = 0.045 [m];
            attribute prolapsedPosition = 0.020 [m];
            attribute organMass = 0.050 [kg];
            attribute currentElevation : Elevation;
        }
        part uterus : Uterus {
            attribute normalPosition = 0.060 [m];
            attribute prolapsedPosition = 0.025 [m];
            attribute organMass = 0.080 [kg];
            attribute currentElevation : Elevation;
        }
        part vaginalWall : VaginalTissue {
            attribute tissueThickness = 0.004 [m];
            attribute elasticity = 5000 [N/m];
            attribute maxTolerablePressure = 35000 [Pa];
            attribute currentPressure : ContactPressure;
        }
        part pelvicFloor : PelvicFloorMuscle {
            attribute restingTone = 1.5 [N];
            attribute contractionForce = 8.0 [N];
            attribute currentSupport : SupportForce;
        }

        port organLoadPort : MechanicalSupportPort;
        port tissueInterfacePort : TissueContactPort;
    }

    // ---- Clinical workflow ----
    part def ClinicalAssessment {
        attribute prolapseGrade : Integer;
        attribute recommendedDiameter : RingDiameter;
        attribute patientComfortBaseline : ComfortScore;
        action assessPatient :> Action {
            out grade : Integer;
            out diameter : RingDiameter;
        }
    }

    // ---- Top-level system ----
    part def PessarySupportSystem {
        part pessary : PessaryDevice {
            attribute ringDiameter = 70 [mm];
            attribute crossSectionDiameter = 15 [mm];
            attribute materialStiffness = 1200 [N/m];
            attribute materialElasticModulus = 2.0e6 [Pa];
            attribute maxDeformation = 0.005 [m];
        }
        part patient : PatientAnatomy;
        part assessment : ClinicalAssessment {
            attribute prolapseGrade = 2;
            attribute recommendedDiameter = 70 [mm];
            attribute patientComfortBaseline = 6 [1];
        }

        connection organSupportConnection connect pessary.organSupportPort to patient.organLoadPort;
        connection tissueContactConnection connect pessary.tissueContactPort to patient.tissueInterfacePort;
        connection bladderSupport connect pessary.bladderInterface to patient.bladder;
        connection uterusSupport connect pessary.uterusInterface to patient.uterus;

        attribute systemComfortScore : ComfortScore;
        attribute systemStabilityIndex : StabilityIndex;
        attribute totalWearDuration : WearDuration;

        action def SystemOperation :> Action {
            in patientAnatomy : PatientAnatomy;
            in pessaryDevice : PessaryDevice;
            out supportResult : SupportForce;
            out comfortResult : ComfortScore;
            out stabilityResult : StabilityIndex;

            action assess;
            action insert;
            action support {
                out elevationAchieved : Elevation;
                out forceApplied : SupportForce;
            }
            action monitor {
                out comfort : ComfortScore;
                out stability : StabilityIndex;
            }
            action remove;

            flow assess.success to insert.ready;
            flow insert.complete to support.start;
            flow support.active to monitor.begin;
            flow monitor.complete to remove.start;
        }

        state def SystemLifecycle {
            entry; then Unassessed;
            state Unassessed;
            state Assessed;
            state Inserted;
            state ActiveSupport {
                do continuousSupport;
            }
            state Monitoring;
            state Removed;
            transition first Unassessed then Assessed when assessmentComplete;
            transition first Assessed then Inserted when insertionComplete;
            transition first Inserted then ActiveSupport when positioningConfirmed;
            transition first ActiveSupport then Monitoring when monitoringInterval;
            transition first Monitoring then ActiveSupport when stable;
            transition first ActiveSupport then Removed when removalRequested;
            transition first Monitoring then Removed when removalRequested;
        }

        action continuousSupport :> Action;
    }

    // ---- Requirements ----
    requirement def ProvideOrganSupport {
        subject pessary : PessaryDevice;
        objective {
            doc /* The pessary shall provide sufficient support force to elevate prolapsed organs. */
            pessary.generatedSupportForce >= 2.0 [N];
        }
    }

    requirement def MaintainComfort {
        subject pessary : PessaryDevice;
        subject tissue : VaginalTissue;
        objective {
            doc /* Contact pressure shall remain below tissue tolerance to prevent injury. */
            pessary.appliedContactPressure <= tissue.maxTolerablePressure;
        }
    }

    requirement def StabilityDuringActivity {
        subject system : PessarySupportSystem;
        objective {
            doc /* The pessary shall remain stable during daily activities. */
            system.systemStabilityIndex >= 0.85 [1];
        }
    }

    requirement def ExtendedWearComfort {
        subject system : PessarySupportSystem;
        objective {
            doc /* Comfort shall be maintained over extended wear periods. */
            system.systemComfortScore >= 6 [1];
            system.totalWearDuration >= 8 [h];
        }
    }

    requirement def MaterialFlexibility {
        subject pessary : PessaryDevice;
        objective {
            doc /* Material shall be stiff enough to support yet flexible enough for comfort. */
            pessary.materialStiffness >= 800 [N/m];
            pessary.materialStiffness <= 2000 [N/m];
        }
    }

    requirement def AnatomicalFit {
        subject pessary : PessaryDevice;
        subject patient : PatientAnatomy;
        objective {
            doc /* Ring diameter shall match patient anatomy. */
            pessary.ringDiameter <= 90 [mm];
            pessary.ringDiameter >= 55 [mm];
        }
    }

    requirement def NonSurgicalOperation {
        subject system : PessarySupportSystem;
        objective {
            doc /* The system shall provide non-surgical continuous physical support. */
            system.pessary.insertionState == PessaryDevice::InsertionState::inPlace;
        }
    }

    // ---- Requirement satisfaction ----
    satisfaction provideOrganSupportReq : ProvideOrganSupport by pessary;
    satisfaction maintainComfortReq : MaintainComfort by pessary, patient.vaginalWall;
    satisfaction stabilityReq : StabilityDuringActivity by pessary;
    satisfaction wearComfortReq : ExtendedWearComfort by pessary;
    satisfaction flexibilityReq : MaterialFlexibility by pessary;
    satisfaction fitReq : AnatomicalFit by pessary, patient;
    satisfaction nonSurgicalReq : NonSurgicalOperation by pessary;

}
