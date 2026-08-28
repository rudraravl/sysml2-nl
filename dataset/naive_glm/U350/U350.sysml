package PedorthicCareSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def LengthMeasure :> Real { unit 'mm'; }
    value def WidthMeasure :> Real { unit 'mm'; }
    value def HeightMeasure :> Real { unit 'mm'; }
    value def ThicknessMeasure :> Real {> Real { unit 'steps/min'; }
    value def PronationAngle :> Real { unit 'deg'; }
    value def PressureMeasure :> Real { unit 'kPa'; }
    value def StrideLength :> Real { unit 'm'; }
    value def BodyMass :> Real { unit 'kg'; }

    // ===== Enumerations =====
    enum def FootCondition {
        flatFoot = 0,
        highArch = 1,
        plantarFasciitis = 2,
        diabeticFoot = 3,
        halluxValgus = 4,
        metatarsalgia = 5,
        achillesTendinitis = 6,
        normal = 7
    }

    enum def DeviceType {
        customFootOrthotic = 0,
        therapeuticFootwear = 1,
        ankleFootOrthosis = 2
    }

    enum def OrthoticMaterial {
        EVA = 0,
        polypropylene = 1,
        carbonFiber = 2,
        cork = 3,
        leather = 4,
        silicone = 5
    }

    enum def SupportLevel {
        rigid = 0,
        semiRigid = 1,
        soft = 2,
        accommodative = 3
    }

    enum def FitStatus {
        pending = 0,
        comfortable = 1,
        needsAdjustment = 2,
        effective = 3
    }

    enum def AssessmentStatus {
        notStarted = 0,
        inProgress = 1,
        completed = 2
    }

    // ===== Item Definitions =====
    item def PatientRecord {
        attribute patientId : String;
        attribute patientName : String;
        attribute age : Integer;
        attribute mass : BodyMass;
        attribute medicalHistory : String;
        attribute referringPhysician : String;
    }

    item def FootMeasurement {
        attribute footLength : LengthMeasure;
        attribute footWidth : WidthMeasure;
        attribute archHeight : HeightMeasure;
        attribute heelWidth : WidthMeasure;
        attribute ballCircumference : LengthMeasure;
    }

    item def GaitAnalysisData {
        attribute strideLength : StrideLength;
        attribute cadence : CadenceMeasure;
        attribute pronationAngle : PronationAngle;
        attribute stancePhaseDuration : Real; // percentage
        attribute swingPhaseDuration : Real; // percentage
        attribute symmetryIndex : Real;
    }

    item def PressureDistribution {
        attribute heelPressure : PressureMeasure;
        attribute midfootPressure : PressureMeasure;
        attribute forefootPressure : PressureMeasure;
        attribute toePressure : PressureMeasure;
        attribute peakPressure : PressureMeasure;
        attribute pressureMap : String; // reference to image/data file
    }

    item def BiomechanicalReport {
        attribute diagnosedCondition : FootCondition;
        attribute severity : Real; // 0.0 to 1.0
        attribute asymmetryNotes : String;
        attribute riskFactors : String;
        attribute recommendedDevice : DeviceType;
        attribute clinicalJustification : String;
    }

    item def Prescription {
        attribute prescriptionId : String;
        attribute deviceType : DeviceType;
        attribute material : OrthoticMaterial;
        attribute thickness : ThicknessMeasure;
        attribute supportLevel : SupportLevel;
        attribute archCorrection : PronationAngle;
        attribute metatarsalPad : Boolean;
        attribute heelCupDepth : HeightMeasure;
        attribute notes : String;
    }

    item def FabricatedDevice {
        attribute deviceId : String;
        attribute deviceType : DeviceType;
        attribute material : OrthoticMaterial;
        attribute thickness : ThicknessMeasure;
        attribute supportLevel : SupportLevel;
        attribute fabricationDate : String;
        attribute qualityCheckPassed : Boolean;
    }

    item def FitEvaluation {
        attribute comfortScore : Integer; // 1-10
        attribute pressurePoints : String;
        attribute alignmentCorrect : Boolean;
        attribute fitStatus : FitStatus;
        attribute adjustmentNotes : String;
    }

    item def FollowUpPlan {
        attribute followUpDate : String;
        attribute monitoringGoals : String;
        attribute wearSchedule : String;
        attribute warningSigns : String;
    }

    // ===== Port Definitions =====
    port def AssessmentDataOut {
        out footMeasurement : FootMeasurement;
        out gaitData : GaitAnalysisData;
        out pressureData : PressureDistribution;
    }

    port def AssessmentDataIn {
        in footMeasurement : FootMeasurement;
        in gaitData : GaitAnalysisData;
        in pressureData : PressureDistribution;
    }

    port def PrescriptionOut {
        out prescription : Prescription;
    }

    port def PrescriptionIn {
        in prescription : Prescription;
    }

    port def DeviceOut {
        out device : FabricatedDevice;
    }

    port def DeviceIn {
        in device : FabricatedDevice;
    }

    port def PatientInteractionPort {
        in patientRecord : PatientRecord;
        out followUpPlan : FollowUpPlan;
        out educationMaterial : String;
    }

    // ===== Parts =====
    part def Patient {
        attribute record : PatientRecord;
        port interactionPort : PatientInteractionPort;
        attribute currentCondition : FootCondition;
        attribute satisfactionLevel : Integer;
    }

    part def Pedorthist {
        attribute name : String;
        attribute certificationId : String;
        attribute yearsOfExperience : Integer;

        port assessmentDataPort : AssessmentDataIn;
        port prescriptionPort : PrescriptionOut;
        port deviceReceivePort : DeviceIn;
        port patientPort : PatientInteractionPort;

        attribute biomechanicalReport : BiomechanicalReport;
        attribute currentFitEvaluation : FitEvaluation;

        action def conductAssessment {
            in patient : Patient;
            out measurement : FootMeasurement;
            out gaitData : GaitAnalysisData;
            out pressureData : PressureDistribution;
        }

        action def performBiomechanicalAnalysis {
            in measurement : FootMeasurement;
            in gaitData : GaitAnalysisData;
            in pressureData : PressureDistribution;
            out report : BiomechanicalReport;
        }

        action def createPrescription {
            in report : BiomechanicalReport;
            out prescription : Prescription;
        }

        action def fitDevice {
            in device : FabricatedDevice;
            in patient : Patient;
            out evaluation : FitEvaluation;
        }

        action def adjustDevice {
            in device : FabricatedDevice;
            in evaluation : FitEvaluation;
            out adjustedDevice : FabricatedDevice;
        }

        action def educatePatient {
            in patient : Patient;
            in device : FabricatedDevice;
            out educationMaterial : String;
            out followUp : FollowUpPlan;
        }
    }

    part def FootMeasurementDevice {
        attribute calibrationDate : String;
        attribute accuracy : LengthMeasure;
        port dataOut : AssessmentDataOut;

        action def captureFootGeometry {
            in patient : Patient;
            out measurement : FootMeasurement;
        }
    }

    part def GaitAnalysisSystem {
        attribute sensorCount : Integer;
        attribute samplingRate : Real; // Hz
        port dataOut : AssessmentDataOut;

        action def analyzeGait {
            in patient : Patient;
            out gaitData : GaitAnalysisData;
        }
    }

    part def PressureMappingSystem {
        attribute sensorMatrixSize : String;
        port dataOut : AssessmentDataOut;

        action def mapPressure {
            in patient : Patient;
            out pressureData : PressureDistribution;
        }
    }

    part def AssessmentStation {
        part footMeasurementDevice : FootMeasurementDevice;
        part gaitAnalysisSystem : GaitAnalysisSystem;
        part pressureMappingSystem : PressureMappingSystem;

        port combinedDataOut : AssessmentDataOut;

        action def performFullAssessment {
            in patient : Patient;
            out measurement : FootMeasurement;
            out gaitData : GaitAnalysisData;
            out pressureData : PressureDistribution;

            perform footMeasurementDevice.captureFootGeometry;
            perform gaitAnalysisSystem.analyzeGait;
            perform pressureMappingSystem.mapPressure;
        }
    }

    part def FabricationLaboratory {
        attribute labId : String;
        attribute capacity : Integer;
        port prescriptionIn : PrescriptionIn;
        port deviceOut : DeviceOut;

        attribute materialInventory : OrthoticMaterial[0..*];
        attribute pendingOrders : Prescription[0..*];

        action def manufactureDevice {
            in prescription : Prescription;
            out device : FabricatedDevice;

            first moldCreation;
            then materialSelection;
            then forming;
            then finishing;
            then qualityInspection;

            action moldCreation {
                in prescription : Prescription;
                out moldId : String;
            }
            action materialSelection {
                in prescription : Prescription;
                out selectedMaterial : OrthoticMaterial;
            }
            action forming {
                in moldId : String;
                in selectedMaterial : OrthoticMaterial;
                out rawDevice : FabricatedDevice;
            }
            action finishing {
                in rawDevice : FabricatedDevice;
                out finishedDevice : FabricatedDevice;
            }
            action qualityInspection {
                in finishedDevice : FabricatedDevice;
                out device : FabricatedDevice;
            }
        }
    }

    part def FittingRoom {
        attribute roomId : String;
        part adjustmentTools[0..*];
        port deviceIn : DeviceIn;

        action def conductFittingSession {
            in device : FabricatedDevice;
            in patient : Patient;
            out evaluation : FitEvaluation;
        }
    }

    // ===== Top-level System =====
    part def PedorthicCareSystem {
        part patient : Patient;
        part pedorthist : Pedorthist;
        part assessmentStation : AssessmentStation;
        part fabricationLab : FabricationLaboratory;
        part fittingRoom : FittingRoom;

        // Connections
        connection assessmentDataFlow connect assessmentStation.combinedDataOut to pedorthist.assessmentDataPort;
        connection prescriptionFlow connect pedorthist.prescriptionPort to fabricationLab.prescriptionIn;
        connection deviceDelivery connect fabricationLab.deviceOut to pedorthist.deviceReceivePort;
        connection patientInteraction connect pedorthist.patientPort to patient.interactionPort;

        // Internal connections within assessment station
        connection footMeasurementData connect assessmentStation.footMeasurementDevice.dataOut to assessmentStation.combinedDataOut;
        connection gaitAnalysisData connect assessmentStation.gaitAnalysisSystem.dataOut to assessmentStation.combinedDataOut;
        connection pressureMappingData connect assessmentStation.pressureMappingSystem.dataOut to assessmentStation.combinedDataOut;

        // ===== State Machine for Care Process =====
        state def CareProcessStateMachine {
            entry; then awaitingPatient;

            state awaitingPatient {
                entry action { /* Patient scheduled, waiting for arrival */ }
            }

            transition await_to_assess
                first awaitingPatient
                accept PatientArrival
                then conductingAssessment;

            state conductingAssessment {
                entry action { assessmentStation.performFullAssessment; }
                do action { pedorthist.conductAssessment; }
                exit action { /* Assessment data collected */ }
            }

            transition assess_to_analyze
                first conductingAssessment
                accept AssessmentComplete
                then performingBiomechanicalAnalysis;

            state performingBiomechanicalAnalysis {
                entry action { pedorthist.performBiomechanicalAnalysis; }
                do action { /* Diagnose condition, determine treatment needs */ }
                exit action { /* Biomechanical report generated */ }
            }

            transition analyze_to_prescribe
                first performingBiomechanicalAnalysis
                accept AnalysisComplete
                then developingTreatmentPlan;

            state developingTreatmentPlan {
                entry action { pedorthist.createPrescription; }
                do action { /* Formal treatment plan and prescription created */ }
                exit action { /* Prescription finalized */ }
            }

            transition prescribe_to_fabricate
                first developingTreatmentPlan
                accept PrescriptionReady
                then fabricatingDevice;

            state fabricatingDevice {
                entry action { fabricationLab.manufactureDevice; }
                do action { /* Device manufactured per specifications */ }
                exit action { /* Quality-checked device ready */ }
            }

            transition fabricate_to_fit
                first fabricatingDevice
                accept DeviceReady
                then fittingAndAdjustment;

            state fittingAndAdjustment {
                entry action { pedorthist.fitDevice; }

                do action { /* Fit device, evaluate comfort and effectiveness */ }

                choice checkFit {
                    if (currentFitEvaluation.fitStatus == FitStatus::comfortable and currentFitEvaluation.fitStatus == FitStatus::effective)
                        then fittingComplete;
                    if (currentFitEvaluation.fitStatus == FitStatus::needsAdjustment)
                        then adjustingDevice;
                }

                state adjustingDevice {
                    entry action { pedorthist.adjustDevice; }
                    do action { /* Make necessary adjustments to device */ }
                    exit action { /* Device adjusted, re-evaluate fit */ }
                }

                transition adjust_to_fit
                    first adjustingDevice
                    accept AdjustmentComplete
                    then fittingAndAdjustment;
            }

            transition fit_to_educate
                first fittingAndAdjustment
                accept FitAchieved
                then patientEducation;

            state patientEducation {
                entry action { pedorthist.educatePatient; }
                do action { /* Educate patient on use and care of device */ }
                exit action { /* Patient educated, follow-up scheduled */ }
            }

            transition educate_to_followup
                first patientEducation
                accept EducationComplete
                then schedulingFollowUp;

            state schedulingFollowUp {
                entry action { /* Schedule future follow-up appointment */ }
                do action { /* Set monitoring goals and wear schedule */ }
                exit action { /* Follow-up plan delivered to patient */ }
            }

            transition followup_to_complete
                first schedulingFollowUp
                accept FollowUpScheduled
                then careComplete;

            state careComplete {
                entry action { /* Care cycle complete, patient discharged with device */ }
            }

            transition complete_to_await
                first careComplete
                accept NewPatientCycle
                then awaitingPatient;
        }

        // ===== Requirements =====
        requirement def AssessmentAccuracyRequirement {
            doc /* The assessment equipment must capture foot measurements within specified tolerance. */
            attribute measurementTolerance : LengthMeasure = 1.0[mm];
            subject assessmentEquipment : AssessmentStation;
            requirement {
                subject assessmentEquipment.footMeasurementDevice.accuracy <= measurementTolerance;
            }
        }

        requirement def GaitAnalysisRequirement {
            doc /* The gait analysis system must capture stride, cadence, and pronation data. */
            subject gaitSystem : GaitAnalysisSystem;
            requirement {
                subject gaitSystem.samplingRate >= 100.0;
            }
        }

        requirement def FabricationSpecificationRequirement {
            doc /* Fabricated devices must match prescription specifications exactly. */
            subject device : FabricatedDevice;
            subject prescription : Prescription;
            requirement {
                subject device.material == prescription.material and
                subject device.thickness == prescription.thickness and
                subject device.supportLevel == prescription.supportLevel and
                subject device.qualityCheckPassed == true;
            }
        }

        requirement def FitQualityRequirement {
            doc /* The fitted device must achieve a comfortable and effective fit before process completion. */
            subject evaluation : FitEvaluation;
            requirement {
                subject evaluation.fitStatus == FitStatus::comfortable or
                subject evaluation.fitStatus == FitStatus::effective;
            }
        }

        requirement def PatientEducationRequirement {
            doc /* The patient must receive education on proper use and care of the device. */
            subject pedorthist : Pedorthist;
            requirement {
                subject pedorthist.educatePatient.isExecuted == true;
            }
        }

        requirement def FollowUpRequirement {
            doc /* A follow-up appointment must be scheduled before care cycle completion. */
            subject followUpPlan : FollowUpPlan;
            requirement {
                subject followUpPlan.followUpDate.isNotEmpty == true;
            }
        }

        requirement def ComprehensiveCareRequirement {
            doc /* The system must provide a complete workflow from assessment through follow-up. */
            subject system : PedorthicCareSystem;
            requirement {
                subject system.assessmentStation.isOperational == true and
                subject system.fabricationLab.isOperational == true and
                subject system.fittingRoom.isOperational == true;
            }
        }

        // Satisfaction of requirements
        satisfy AssessmentAccuracyRequirement by assessmentStation;
        satisfy GaitAnalysisRequirement by assessmentStation.gaitAnalysisSystem;
        satisfy FabricationSpecificationRequirement by fabricationLab;
        satisfy FitQualityRequirement by pedorthist;
        satisfy PatientEducationRequirement by pedorthist;
        satisfy FollowUpRequirement by pedorthist;
        satisfy ComprehensiveCareRequirement by self;
    }
}
