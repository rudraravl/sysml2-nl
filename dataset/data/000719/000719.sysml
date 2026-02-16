package OrchidometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TesticularVolume :> VolumeValue {
        doc /* Testicular volume measured in milliliters */
    }
    
    attribute def PraderStage :> Integer {
        doc /* Pubertal development stage classification (1-5) based on testicular volume */
    }
    
    attribute def BeadDiameter :> LengthValue {
        doc /* Diameter of reference bead in millimeters */
    }
    
    attribute def PatientAge :> Real {
        doc /* Patient age in years */
    }
    
    item def BeadSpecification {
        attribute volume : TesticularVolume;
        attribute diameter : BeadDiameter;
    }
    
    item def MeasurementRecord {
        attribute patientID : String;
        attribute leftTesticleVolume : TesticularVolume;
        attribute rightTesticleVolume : TesticularVolume;
        attribute praderStage : PraderStage;
        attribute timestamp : String;
    }
    
    part def ReferenceBeadChain {
        doc /* Chain of ellipsoidal beads with standardized volumes for comparison */
        
        attribute standardBeads : BeadSpecification[12] {
            doc /* Standard Prader orchidometer volumes: 1, 2, 3, 4, 5, 6, 8, 10, 12, 15, 20, 25 mL */
        }
        
        port beadInterface {
            out selectedBead : BeadSpecification;
        }
    }
    
    part def OrchidometerInstrument {
        doc /* Physical orchidometer device with reference bead chain */
        
        part beadChain : ReferenceBeadChain;
        
        port measurementPort {
            out estimatedVolume : TesticularVolume;
        }
    }
    
    part def Patient {
        doc /* Patient undergoing testicular volume assessment */
        
        attribute age : PatientAge;
        attribute patientIdentifier : String;
        
        port examinationPort {
            in leftTesticleVolume : TesticularVolume;
            in rightTesticleVolume : TesticularVolume;
            in developmentalStage : PraderStage;
        }
    }
    
    part def Clinician {
        doc /* Healthcare provider performing the examination */
        
        port operatorPort {
            in beadSelection : BeadSpecification;
            out visualAssessment : Real;
            out tactileAssessment : Real;
        }
    }
    
    part def RecordingSystem {
        doc /* Electronic or paper-based system for recording measurements */
        
        port dataPort {
            in measurementData : MeasurementRecord;
        }
    }
    
    action def PerformPalpation {
        doc /* Physical examination to assess testicular size and consistency */
        
        in patientAge : PatientAge;
        out estimatedVolume : TesticularVolume;
        out consistency : Real;
    }
    
    action def SelectMatchingBead {
        doc /* Select reference bead that most closely matches testicular size */
        
        in availableBeads : BeadSpecification[*];
        in estimatedSize : TesticularVolume;
        out matchedBead : BeadSpecification;
        
        first start;
        then action findClosest {
            private attribute closestBead : BeadSpecification;
            private attribute minDifference : Real := 1000.0;
            
            for bead in availableBeads {
                action compareBead {
                    private attribute currentVolume : Real;
                    private attribute targetVolume : Real;
                    private attribute difference : Real;
                    
                    first start;
                    then assign currentVolume := bead.volume;
                    then assign targetVolume := estimatedSize;
                    then decide;
                        if currentVolume > targetVolume then calculatePositiveDiff;
                        else calculateNegativeDiff;
                    
                    action calculatePositiveDiff {
                        assign difference := currentVolume - targetVolume;
                    }
                    action calculateNegativeDiff {
                        assign difference := targetVolume - currentVolume;
                    }
                    
                    then decide;
                        if difference < minDifference then updateClosest;
                        else continueSearch;
                    
                    action updateClosest {
                        assign minDifference := difference;
                        assign closestBead := bead;
                    }
                    action continueSearch;
                }
            }
            then assign matchedBead := closestBead;
        }
        then done;
    }
    
    action def PerformVisualComparison {
        doc /* Visual comparison of testis with selected reference bead */
        
        in testisSize : TesticularVolume;
        in referenceBead : BeadSpecification;
        out comparisonScore : Real;
        out finalVolume : TesticularVolume;
        
        first start;
        then action calculateScore {
            private attribute volumeDifference : Real;
            private attribute relativeError : Real;
            
            first start;
            then decide;
                if testisSize > referenceBead.volume then calcPositiveDiff;
                else calcNegativeDiff;
            
            action calcPositiveDiff {
                assign volumeDifference := testisSize - referenceBead.volume;
            }
            action calcNegativeDiff {
                assign volumeDifference := referenceBead.volume - testisSize;
            }
            
            then assign relativeError := volumeDifference / referenceBead.volume;
            then assign comparisonScore := 1.0 - relativeError;
        }
        then decide;
            if comparisonScore >= 0.9 then acceptBead;
            else adjustEstimate;
        
        action acceptBead {
            assign finalVolume := referenceBead.volume;
        }
        action adjustEstimate {
            assign finalVolume := (testisSize + referenceBead.volume) / 2.0;
        }
        then done;
    }
    
    action def ClassifyPubertalStage {
        doc /* Determine Prader stage based on larger testicular volume */
        
        in testicularVolume : TesticularVolume;
        out stage : PraderStage;
        
        first start;
        then decide;
            if testicularVolume < 4.0 then assignStage1;
            if testicularVolume >= 4.0 and testicularVolume < 8.0 then assignStage2;
            if testicularVolume >= 8.0 and testicularVolume < 12.0 then assignStage3;
            if testicularVolume >= 12.0 and testicularVolume < 20.0 then assignStage4;
            if testicularVolume >= 20.0 then assignStage5;
        
        action assignStage1 {
            assign stage := 1;
        }
        action assignStage2 {
            assign stage := 2;
        }
        action assignStage3 {
            assign stage := 3;
        }
        action assignStage4 {
            assign stage := 4;
        }
        action assignStage5 {
            assign stage := 5;
        }
        then done;
    }
    
    action def PerformOrchidometerAssessment {
        doc /* Complete orchidometer measurement procedure for bilateral testicular volume assessment */
        
        in patient : Patient;
        in orchidometer : OrchidometerInstrument;
        out leftVolume : TesticularVolume;
        out rightVolume : TesticularVolume;
        out praderStage : PraderStage;
        out measurementRecord : MeasurementRecord;
        
        first start;
        
        then action palpateLeftTesticle : PerformPalpation {
            in patientAge = patient.age;
            out estimatedVolume;
            out consistency;
        }
        
        then action selectLeftBead : SelectMatchingBead {
            in availableBeads = orchidometer.beadChain.standardBeads;
            in estimatedSize = palpateLeftTesticle.estimatedVolume;
            out matchedBead;
        }
        
        then action compareLeftTesticle : PerformVisualComparison {
            in testisSize = palpateLeftTesticle.estimatedVolume;
            in referenceBead = selectLeftBead.matchedBead;
            out finalVolume;
        }
        
        then assign leftVolume := compareLeftTesticle.finalVolume;
        
        then action palpateRightTesticle : PerformPalpation {
            in patientAge = patient.age;
            out estimatedVolume;
            out consistency;
        }
        
        then action selectRightBead : SelectMatchingBead {
            in availableBeads = orchidometer.beadChain.standardBeads;
            in estimatedSize = palpateRightTesticle.estimatedVolume;
            out matchedBead;
        }
        
        then action compareRightTesticle : PerformVisualComparison {
            in testisSize = palpateRightTesticle.estimatedVolume;
            in referenceBead = selectRightBead.matchedBead;
            out finalVolume;
        }
        
        then assign rightVolume := compareRightTesticle.finalVolume;
        
        then action determineLargerVolume {
            private attribute largerVolume : TesticularVolume;
            
            first start;
            then decide;
                if leftVolume >= rightVolume then useLeftVolume;
                else useRightVolume;
            
            action useLeftVolume {
                assign largerVolume := leftVolume;
            }
            action useRightVolume {
                assign largerVolume := rightVolume;
            }
            
            then action classifyStage : ClassifyPubertalStage {
                in testicularVolume = largerVolume;
                out stage;
            }
            
            then assign praderStage := classifyStage.stage;
        }
        
        then action createRecord {
            assign measurementRecord.patientID := patient.patientIdentifier;
            assign measurementRecord.leftTesticleVolume := leftVolume;
            assign measurementRecord.rightTesticleVolume := rightVolume;
            assign measurementRecord.praderStage := praderStage;
        }
        
        then done;
    }
    
    state def OrchidometerOperationStates {
        doc /* State machine governing orchidometer measurement workflow */
        
        entry; then idle;
        
        state idle {
            doc /* System ready for new measurement */
        }
        
        transition idle_to_preparing
            first idle
            then preparingExamination;
        
        state preparingExamination {
            doc /* Clinician preparing patient and instrument */
        }
        
        transition preparing_to_measuringLeft
            first preparingExamination
            then measuringLeft;
        
        state measuringLeft {
            doc /* Assessing left testicular volume */
        }
        
        transition measuringLeft_to_measuringRight
            first measuringLeft
            then measuringRight;
        
        state measuringRight {
            doc /* Assessing right testicular volume */
        }
        
        transition measuringRight_to_determiningStage
            first measuringRight
            then determiningStage;
        
        state determiningStage {
            doc /* Classifying pubertal development stage */
        }
        
        transition determiningStage_to_recordingResults
            first determiningStage
            then recordingResults;
        
        state recordingResults {
            doc /* Documenting measurement findings */
        }
        
        transition recordingResults_to_complete
            first recordingResults
            then complete;
        
        state complete {
            doc /* Measurement procedure finished */
        }
        
        transition complete_to_idle
            first complete
            then idle;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The orchidometer system shall measure testicular volume to assess pubertal development */
        
        subject system : OrchidometerMeasurementSystem;
        
        require constraint {
            doc /* System shall provide volume measurements for both testes */
        }
    }
    
    requirement def AccuracyRequirement {
        doc /* Orchidometer measurements shall be clinically accurate */
        
        subject instrument : OrchidometerInstrument;
        
        require constraint {
            doc /* Volume estimation error shall not exceed ±15% for clinical utility */
        }
    }
    
    requirement def BeadRangeRequirement {
        doc /* Orchidometer shall cover full range of testicular volumes */
        
        subject beadChain : ReferenceBeadChain;
        
        require constraint {
            beadChain.standardBeads->size() == 12
        }
    }
    
    requirement def StageClassificationRequirement {
        doc /* System shall accurately classify Prader pubertal development stage */
        
        assume constraint {
            doc /* Patient age is appropriate for pubertal assessment (typically 8-18 years) */
        }
        
        require constraint {
            doc /* Prader stage determination shall follow established clinical criteria */
        }
    }
    
    part def OrchidometerMeasurementSystem {
        doc /* Complete system for testicular volume measurement and pubertal assessment using orchidometer method */
        
        part instrument : OrchidometerInstrument;
        part patient : Patient;
        part clinician : Clinician;
        part recorder : RecordingSystem;
        
        connection beadToOperator
            connect instrument.beadChain.beadInterface.selectedBead
            to clinician.operatorPort.beadSelection;
        
        connection measurementToPatient
            connect instrument.measurementPort.estimatedVolume
            to patient.examinationPort.leftTesticleVolume;
        
        perform action assessmentProcedure : PerformOrchidometerAssessment {
            in patient = OrchidometerMeasurementSystem::patient;
            in orchidometer = instrument;
            out leftVolume;
            out rightVolume;
            out praderStage;
            out measurementRecord;
        }
        
        exhibit state operationFlow : OrchidometerOperationStates;
        
        satisfy PrimaryFunctionRequirement;
        satisfy AccuracyRequirement by instrument;
        satisfy BeadRangeRequirement by instrument.beadChain;
        satisfy StageClassificationRequirement;
    }
    
    part clinicalOrchidometerSystem : OrchidometerMeasurementSystem {
        doc /* Instantiated orchidometer system for clinical use in pediatric endocrinology */
    }
}
