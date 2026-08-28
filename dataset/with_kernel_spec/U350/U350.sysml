package PedorthicCareSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def FootMeasurements {
        attribute footLength : Length;
        attribute footWidth : Length;
        attribute archHeight : Length;
    }

    item def GaitData {
        attribute strideLength : Length;
        attribute cadence : Real;
        attribute pronationAngle : Real;
    }

    item def PressureMap {
        attribute peakPressure : Real;
        attribute distributionProfile : String;
    }

    item def AssessmentData {
        attribute measurements : FootMeasurements;
        attribute gait : GaitData;
        attribute pressure : PressureMap;
    }

    item def Diagnosis {
        attribute condition : String;
        attribute severity : String;
    }

    item def TreatmentPlan {
        attribute goals : String;
        attribute recommendations : String;
    }

    item def Prescription {
        attribute deviceType : String;
        attribute material : String;
        attribute thickness : Length;
        attribute supportLevel : String;
    }

    item def CustomDevice {
        attribute deviceID : String;
        attribute deviceType : String;
        attribute material : String;
        attribute thickness : Length;
    }

    item def FitFeedback {
        attribute comfortable : Boolean;
        attribute effective : Boolean;
        attribute comfortRating : Real;
    }

    item def PatientEducation {
        attribute usageInstructions : String;
        attribute careInstructions : String;
    }

    item def FollowUpSchedule {
        attribute appointmentDate : String;
        attribute notes : String;
    }

    port def AssessmentDataOut {
        out item data : AssessmentData;
    }

    port def PrescriptionOut {
        out item prescription : Prescription;
    }

    port def DeviceOut {
        out item device : CustomDevice;
    }

    port def FeedbackOut {
        out item feedback : FitFeedback;
    }

    port def EducationOut {
        out item education : PatientEducation;
    }

    port def FollowUpOut {
        out item followUp : FollowUpSchedule;
    }

    part def Patient {
        out port feedbackOut : FeedbackOut;
        in port educationIn : ~EducationOut;
        in port followUpIn : ~FollowUpOut;
    }

    part def AssessmentEquipment {
        out port dataOut : AssessmentDataOut;
        state machine assessmentProcess {
            state idle;
            state measuring;
            state analyzingGait;
            state mappingPressure;
            transition from idle to measuring;
            transition from measuring to analyzingGait;
            transition from analyzingGait to mappingPressure;
            transition from mappingPressure to idle;
        }
    }

    part def FabricationLab {
        in port prescriptionIn : ~PrescriptionOut;
        out port deviceOut : DeviceOut;
        state machine manufacturingProcess {
            state idle;
            state manufacturing;
            transition from idle to manufacturing;
            transition from manufacturing to idle;
        }
    }

    action def AnalyzeBiomechanics {
        in data : AssessmentData;
        out diagnosis : Diagnosis;
        out treatmentPlan : TreatmentPlan;
    }

    action def CreatePrescription {
        in treatmentPlan : TreatmentPlan;
        out prescription : Prescription;
    }

    action def FitDevice {
        in device : CustomDevice;
        out feedback : FitFeedback;
    }

    action def AdjustDevice {
        in device : CustomDevice;
        out adjustedDevice : CustomDevice;
    }

    action def EducatePatient {
        out education : PatientEducation;
    }

    action def ScheduleFollowUp {
        out followUp : FollowUpSchedule;
    }

    action def PedorthicCareWorkflow {
        in assessmentData : AssessmentData;
        in manufacturedDevice : CustomDevice;
        out prescriptionResult : Prescription;
        out educationResult : PatientEducation;
        out followUpResult : FollowUpSchedule;

        first start;
        then action analyze : AnalyzeBiomechanics {
            in data = assessmentData;
        }
        then action prescribe : CreatePrescription {
            in treatmentPlan = analyze.treatmentPlan;
            out prescription = prescriptionResult;
        }
        then merge fittingLoop;
        then action fit : FitDevice {
            in device = manufacturedDevice;
        }
        then decide;
            if fit.feedback.comfortable then educate;
            if fit.feedback.comfortable == false then adjust;
        action adjust : AdjustDevice {
            in device = manufacturedDevice;
        }
        then fittingLoop;
        action educate : EducatePatient {
            out education = educationResult;
        }
        then action schedule : ScheduleFollowUp {
            out followUp = followUpResult;
        }
        then done;
    }

    part def Pedorthist {
        in port dataIn : ~AssessmentDataOut;
        in port deviceIn : ~DeviceOut;
        in port feedbackIn : ~FeedbackOut;
        out port prescriptionOut : PrescriptionOut;
        out port educationOut : EducationOut;
        out port followUpOut : FollowUpOut;
    }

    part def PedorthicCareSystem {
        part patient : Patient;
        part equipment : AssessmentEquipment;
        part pedorthist : Pedorthist;
        part lab : FabricationLab;

        connect equipment.dataOut to pedorthist.dataIn;
        connect pedorthist.prescriptionOut to lab.prescriptionIn;
        connect lab.deviceOut to pedorthist.deviceIn;
        connect patient.feedbackOut to pedorthist.feedbackIn;
        connect pedorthist.educationOut to patient.educationIn;
        connect pedorthist.followUpOut to patient.followUpIn;
    }

    requirement def ProvideComprehensiveCare {
        doc /* The system shall provide a complete workflow for assessment, treatment, and management of foot and lower limb conditions. */
    }

    requirement def CaptureAccurateMeasurements {
        doc /* The assessment equipment shall capture foot measurements with an accuracy of plus or minus 1 mm. */
    }

    requirement def PerformBiomechanicalAnalysis {
        doc /* The pedorthist shall perform a biomechanical analysis using all collected assessment data to produce a diagnosis and treatment plan. */
    }

    requirement def ManufactureToSpecification {
        doc /* The fabrication lab shall manufacture devices strictly according to the prescription specifications including material, thickness, and support level. */
    }

    requirement def AchieveComfortableFit {
        doc /* The pedorthist shall fit and adjust the device until a safe, comfortable, and effective fit is achieved. */
    }

    requirement def ProvidePatientEducation {
        doc /* The pedorthist shall educate the patient on proper use and care of the device and schedule a follow-up appointment. */
    }
}
