package OrchidometrySystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type TesticularVolume :> Real {
        :>> unit = "mL";
    }

    value type BeadVolume :> TesticularVolume;
    value type PatientID :> String;
    value type PatientName :> String;

    enumeration def PraderStage {
        :>> stage1 = 1; // Prepubertal: < 4 mL
        :>> stage2 = 2; // Early pubertal: 4–8 mL
        :>> stage3 = 3; // Mid pubertal: 9–12 mL
        :>> stage4 = 4; // Late pubertal: 13–20 mL
        :>> stage5 = 5; // Adult: > 20 mL
    }

    enumeration def TesticleSide {
        left;
        right;
    }

    enumeration def WorkflowState {
        preparing;
        examiningLeft;
        examiningRight;
        classifying;
        documenting;
        complete;
    }

    item def MeasurementRecord {
        attribute patientId : PatientID;
        attribute patientName : PatientName;
        attribute leftVolume : TesticularVolume;
        attribute rightVolume : TesticularVolume;
        attribute maxVolume : TesticularVolume;
        attribute praderStage : PraderStage;
        attribute timestamp : DateTime;
    }

    // ===== Physical Orchidometer =====
    part def OrchidometerBead {
        attribute volume : BeadVolume;
        attribute beadId : Integer;
        attribute isEllipsoidal : Boolean = true;
    }

    part def Orchidometer {
        attribute instrumentName : String = "Prader Orchidometer";
        part beads : OrchidometerBead[12] ordered {
            part bead1 : OrchidometerBead { :>> volume = 1::mL; :>> beadId = 1; }
            part bead2 : OrchidometerBead { :>> volume = 2::mL; :>> beadId = 2; }
            part bead3 : OrchidometerBead { :>> volume = 3::mL; :>> beadId = 3; }
            part bead4 : OrchidometerBead { :>> volume = 4::mL; :>> beadId = 4; }
            part bead5 : OrchidometerBead { :>> volume = 5::mL; :>> beadId = 5; }
            part bead6 : OrchidometerBead { :>> volume = 6::mL; :>> beadId = 6; }
            part bead7 : OrchidometerBead { :>> volume = 8::mL; :>> beadId = 7; }
            part bead8 : OrchidometerBead { :>> volume = 10::mL; :>> beadId = 8; }
            part bead9 : OrchidometerBead { :>> volume = 12::mL; :>> beadId = 9; }
            part bead10 : OrchidometerBead { :>> volume = 15::mL; :>> beadId = 10; }
            part bead11 : OrchidometerBead { :>> volume = 20::mL; :>> beadId = 11; }
            part bead12 : OrchidometerBead { :>> volume = 25::mL; :>> beadId = 12; }
        }

        action def selectBead(in targetVolume : TesticularVolume) : OrchidometerBead {
            // Select the bead whose volume most closely matches the target
        }
    }

    // ===== Patient =====
    part def Patient {
        attribute patientId : PatientID;
        attribute patientName : PatientName;
        attribute age : Real;
        port leftTesticle : TesticleRef;
        port rightTesticle : TesticleRef;
    }

    part def TesticleRef {
        attribute side : TesticleSide;
        attribute actualVolume : TesticularVolume;
    }

    // ===== Clinician =====
    part def Clinician {
        attribute clinicianName : String;
        attribute clinicianId : String;
        port examinationHand : ExaminationPort;
    }

    port def ExaminationPort {
        attribute active : Boolean;
    }

    // ===== Electronic Health Record =====
    part def ElectronicHealthRecord {
        attribute systemName : String = "EHR System";
        attribute records : MeasurementRecord[0..*];
        in port recordInput : RecordSubmissionPort;
    }

    port def RecordSubmissionPort {
        attribute ready : Boolean = true;
    }

    // ===== Assessment Procedure =====
    action def Palpation {
        in side : TesticleSide;
        out estimatedVolume : TesticularVolume;
    }

    action def BeadSelection {
        in estimatedVolume : TesticularVolume;
        in orchidometer : Orchidometer;
        out selectedBead : OrchidometerBead;
    }

    action def TactileVisualComparison {
        in selectedBead : OrchidometerBead;
        in side : TesticleSide;
        out finalVolume : TesticularVolume;
    }

    action def MeasureTesticle {
        in side : TesticleSide;
        in patient : Patient;
        in orchidometer : Orchidometer;
        out measuredVolume : TesticularVolume;

        action palpate : Palpation {
            in side = MeasureTesticle::side;
            out estimatedVolume;
        }
        action selectBead : BeadSelection {
            in estimatedVolume = palpate.estimatedVolume;
            in orchidometer = MeasureTesticle::orchidometer;
            out selectedBead;
        }
        action compare : TactileVisualComparison {
            in selectedBead = selectBead.selectedBead;
            in side = MeasureTesticle::side;
            out finalVolume;
        }
        flow from compare.finalVolume to MeasureTesticle::measuredVolume;
    }

    action def DetermineMaxVolume {
        in leftVolume : TesticularVolume;
        in rightVolume : TesticularVolume;
        out maxVolume : TesticularVolume;
    }

    action def ClassifyPraderStage {
        in maxVolume : TesticularVolume;
        out stage : PraderStage;

        if maxVolume < 4::mL {
            :>> stage = PraderStage::stage1;
        } else if maxVolume >= 4::mL & maxVolume <= 8::mL {
            :>> stage = PraderStage::stage2;
        } else if maxVolume > 8::mL & maxVolume <= 12::mL {
            :>> stage = PraderStage::stage3;
        } else if maxVolume > 12::mL & maxVolume <= 20::mL {
            :>> stage = PraderStage::stage4;
        } else {
            :>> stage = PraderStage::stage5;
        }
    }

    action def CreateRecord {
        in patientId : PatientID;
        in patientName : PatientName;
        in leftVolume : TesticularVolume;
        in rightVolume : TesticularVolume;
        in maxVolume : TesticularVolume;
        in praderStage : PraderStage;
        out record : MeasurementRecord;
    }

    action def StoreRecord {
        in record : MeasurementRecord;
        in ehr : ElectronicHealthRecord;
    }

    action def OrchidometryProcedure {
        in patient : Patient;
        in clinician : Clinician;
        in orchidometer : Orchidometer;
        in ehr : ElectronicHealthRecord;

        attribute currentState : WorkflowState = WorkflowState::preparing;

        action prepareExamination {
            out ready : Boolean = true;
        }

        action measureLeft : MeasureTesticle {
            in side = TesticleSide::left;
            in patient = OrchidometryProcedure::patient;
            in orchidometer = OrchidometryProcedure::orchidometer;
            out leftVolume;
        }

        action measureRight : MeasureTesticle {
            in side = TesticleSide::right;
            in patient = OrchidometryProcedure::patient;
            in orchidometer = OrchidometryProcedure::orchidometer;
            out rightVolume;
        }

        action determineMax : DetermineMaxVolume {
            in leftVolume = measureLeft.leftVolume;
            in rightVolume = measureRight.rightVolume;
            out maxVolume;
        }

        action classify : ClassifyPraderStage {
            in maxVolume = determineMax.maxVolume;
            out stage;
        }

        action createRecord : CreateRecord {
            in patientId = OrchidometryProcedure::patient.patientId;
            in patientName = OrchidometryProcedure::patient.patientName;
            in leftVolume = measureLeft.leftVolume;
            in rightVolume = measureRight.rightVolume;
            in maxVolume = determineMax.maxVolume;
            in praderStage = classify.stage;
            out record;
        }

        action storeRecord : StoreRecord {
            in record = createRecord.record;
            in ehr = OrchidometryProcedure::ehr;
        }

        succession prepareExamination then measureLeft;
        succession measureLeft then measureRight;
        succession measureRight then determineMax;
        succession determineMax then classify;
        succession classify then createRecord;
        succession createRecord then storeRecord;
    }

    // ===== State Machine for Workflow =====
    state def OrchidometryWorkflow {
        entry action { :>> currentState = WorkflowState::preparing; }

        state preparing {
            entry action { /* Prepare patient and instruments */ }
            transition to examiningLeft
                when prepareExamination.ready == true;
        }

        state examiningLeft {
            entry action { :>> currentState = WorkflowState::examiningLeft; }
            do action { /* Perform left testicle measurement */ }
            transition to examiningRight
                when measureLeft.leftVolume.isSet;
        }

        state examiningRight {
            entry action { :>> currentState = WorkflowState::examiningRight; }
            do action { /* Perform right testicle measurement */ }
            transition to classifying
                when measureRight.rightVolume.isSet;
        }

        state classifying {
            entry action { :>> currentState = WorkflowState::classifying; }
            do action { /* Determine max volume and classify Prader stage */ }
            transition to documenting
                when classify.stage.isSet;
        }

        state documenting {
            entry action { :>> currentState = WorkflowState::documenting; }
            do action { /* Create and store measurement record */ }
            transition to complete
                when storeRecord.done;
        }

        state complete {
            entry action { :>> currentState = WorkflowState::complete; }
        }
    }

    // ===== Requirements =====
    requirement def ShallMeasureTesticularVolume {
        doc /* The system shall measure the testicular volume of both testicles using an orchidometer. */
        subject : OrchidometryProcedure;
        objective {
            measureLeft.leftVolume.isSet &
            measureRight.rightVolume.isSet &
            measureLeft.leftVolume >= 1::mL &
            measureLeft.leftVolume <= 25::mL &
            measureRight.rightVolume >= 1::mL &
            measureRight.rightVolume <= 25::mL
        }
    }

    requirement def ShallUseStandardizedBeads {
        doc /* The orchidometer shall consist of 12 standardized ellipsoidal beads ranging from 1 mL to 25 mL. */
        subject : Orchidometer;
        objective {
            beads.size == 12 &
            beads.volume.min() == 1::mL &
            beads.volume.max() == 25::mL
        }
    }

    requirement def ShallClassifyPraderStage {
        doc /* The system shall classify the patient's pubertal development into one of five Prader stages based on the larger of the two measured volumes. */
        subject : OrchidometryProcedure;
        objective {
            classify.stage.isSet &
            classify.stage == PraderStage::stage1 |
            classify.stage == PraderStage::stage2 |
            classify.stage == PraderStage::stage3 |
            classify.stage == PraderStage::stage4 |
            classify.stage == PraderStage::stage5
        }
    }

    requirement def ShallCreateAndStoreRecord {
        doc /* The system shall create a complete measurement record and store it in an electronic health record system. */
        subject : OrchidometryProcedure;
        objective {
            createRecord.record.isSet &
            createRecord.record.patientId.isSet &
            createRecord.record.patientName.isSet &
            createRecord.record.leftVolume.isSet &
            createRecord.record.rightVolume.isSet &
            createRecord.record.maxVolume.isSet &
            createRecord.record.praderStage.isSet &
            storeRecord.done
        }
    }

    requirement def ShallFollowDefinedWorkflow {
        doc /* The system shall follow a defined workflow from preparation through documentation. */
        subject : OrchidometryWorkflow;
        objective {
            currentState == WorkflowState::complete
        }
    }

    // ===== Top-level System Assembly =====
    part def ClinicalOrchidometrySystem {
        attribute systemName : String = "Clinical Orchidometry System";

        part orchidometer : Orchidometer;
        part clinician : Clinician;
        part patient : Patient;
        part ehr : ElectronicHealthRecord;

        connection clinician.examinationHand to patient.leftTesticle;
        connection clinician.examinationHand to patient.rightTesticle;
        connection ehr.recordInput to clinician.examinationHand;

        perform action procedure : OrchidometryProcedure {
            in patient = ClinicalOrchidometrySystem::patient;
            in clinician = ClinicalOrchidometrySystem::clinician;
            in orchidometer = ClinicalOrchidometrySystem::orchidometer;
            in ehr = ClinicalOrchidometrySystem::ehr;
        }

        exhibit state workflow : OrchidometryWorkflow;

        satisfy ShallUseStandardizedBeads by orchidometer;
        satisfy ShallMeasureTesticularVolume by procedure;
        satisfy ShallClassifyPraderStage by procedure;
        satisfy ShallCreateAndStoreRecord by procedure;
        satisfy ShallFollowDefinedWorkflow by workflow;
    }
}
