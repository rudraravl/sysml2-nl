package MedicalCalculator {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type MassKg :> Real { doc "Patient mass in kilograms (kg)"; }
    value type HeightM :> Real { doc "Patient height in meters (m)"; }
    value type AgeYears :> Real { doc "Patient age in years (yr)"; }
    value type CreatinineMgDl :> Real { doc "Serum creatinine in milligrams per deciliter (mg/dL)"; }
    value type CholesterolMgDl :> Real { doc "Cholesterol level in milligrams per deciliter (mg/dL)"; }
    value type BPSystolicMmHg :> Real { doc "Systolic blood pressure in millimeters of mercury (mmHg)"; }
    value type BPDiastolicMmHg :> Real { doc "Diastolic blood pressure in millimeters of mercury (mmHg)"; }
    value type BMIValueKgm2 :> Real { doc "Body Mass Index in kilograms per square meter (kg/m^2)"; }
    value type GFRValueMlMin :> Real { doc "Glomerular Filtration Rate in milliliters per minute (mL/min)"; }
    value type RiskScoreValue :> Real { doc "Cardiac risk score on a 0–100 scale"; }
    value type DoseValueMg :> Real { doc "Medication dose in milligrams (mg)"; }

    // ===== Enumerations =====
    enum Gender { male; female; }
    enum CalculationType { bmi; gfr; cardiacRisk; medicationDose; }

    // ===== Item Definitions =====
    item def PatientData {
        doc "Comprehensive set of patient data input to the calculator.";
        attribute patientId : String;
        attribute age : AgeYears;
        attribute gender : Gender;
        attribute weight : MassKg;
        attribute height : HeightM;
        attribute serumCreatinine : CreatinineMgDl;
        attribute totalCholesterol : CholesterolMgDl;
        attribute hdlCholesterol : CholesterolMgDl;
        attribute ldlCholesterol : CholesterolMgDl;
        attribute bpSystolic : BPSystolicMmHg;
        attribute bpDiastolic : BPDiastolicMmHg;
        attribute isSmoker : Boolean;
        attribute isDiabetic : Boolean;
    }

    item def ValidationReport {
        doc "Outcome of validating patient data, including any errors.";
        attribute isValid : Boolean;
        attribute errors : String[0..*];
        attribute validatedData : PatientData[0..1];
    }

    item def ComputationResult {
        doc "Detailed record returned by the Computation Engine.";
        attribute calcType : CalculationType;
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : String;
        attribute interpretation : String;
        attribute isAbnormal : Boolean;
    }

    item def StoredRecord {
        doc "Persistent record of a computation result linked to a patient.";
        attribute result : ComputationResult;
        attribute patientId : String;
    }

    // ===== Port Definitions =====
    port def PatientDataOut { out patientData : PatientData; }
    port def PatientDataIn { in patientData : PatientData; }
    port def ValidationReportOut { out report : ValidationReport; }
    port def ValidationReportIn2 { in report : ValidationReport; }
    port def CalculationRequestIn { in request : CalculationType; }
    port def ResultOut { out result : ComputationResult; }
    port def ResultIn2 { in result : ComputationResult; }

    // ===== Part Definitions =====
    part def InputModule {
        doc "Captures patient data from the healthcare professional.";
        port patientDataOut : PatientDataOut;
        attribute currentPatient : PatientData;

        action def capturePatientData {
            in patientId : String;
            in age : AgeYears;
            in gender : Gender;
            in weight : MassKg;
            in height : HeightM;
            in serumCreatinine : CreatinineMgDl;
            in totalCholesterol : CholesterolMgDl;
            in hdlCholesterol : CholesterolMgDl;
            in ldlCholesterol : CholesterolMgDl;
            in bpSystolic : BPSystolicMmHg;
            in bpDiastolic : BPDiastolicMmHg;
            in isSmoker : Boolean;
            in isDiabetic : Boolean;
            return patientData : PatientData;
        }
    }

    part def ValidationModule {
        doc "Validates patient data for completeness and clinical plausibility.";
        port dataIn : PatientDataIn;
        port reportOut : ValidationReportOut;

        attribute validAgeMin : AgeYears = 0;
        attribute validAgeMax : AgeYears = 120;
        attribute validWeightMin : MassKg = 0.5;
        attribute validWeightMax : MassKg = 500;
        attribute validHeightMin : HeightM = 0.3;
        attribute validHeightMax : HeightM = 2.5;
        attribute validCreatinineMin : CreatinineMgDl = 0.1;
        attribute validCreatinineMax : CreatinineMgDl = 20;
        attribute validCholesterolMin : CholesterolMgDl = 30;
        attribute validCholesterolMax : CholesterolMgDl = 1000;
        attribute validBPSysMin : BPSystolicMmHg = 40;
        attribute validBPSysMax : BPSystolicMmHg = 300;
        attribute validBPDiaMin : BPDiastolicMmHg = 20;
        attribute validBPDiaMax : BPDiastolicMmHg = 200;

        action def validateData {
            in patient : PatientData;
            return report : ValidationReport;
        }
    }

    part def ComputationEngine {
        doc "Performs clinical calculations on validated patient data.";
        port reportIn : ValidationReportIn2;
        port calcRequestIn : CalculationRequestIn;
        port resultOut : ResultOut;
        attribute lastResult : ComputationResult;
        attribute standardDose : DoseValueMg = 100;

        action def computeBMI {
            in weight : MassKg;
            in height : HeightM;
            return bmi : BMIValueKgm2;
        }

        action def computeGFR {
            in age : AgeYears;
            in serumCreatinine : CreatinineMgDl;
            in gender : Gender;
            in weight : MassKg;
            return gfr : GFRValueMlMin;
        }

        action def computeCardiacRisk {
            in age : AgeYears;
            in gender : Gender;
            in bpSystolic : BPSystolicMmHg;
            in totalCholesterol : CholesterolMgDl;
            in hdlCholesterol : CholesterolMgDl;
            in isSmoker : Boolean;
            in isDiabetic : Boolean;
            return riskScore : RiskScoreValue;
        }

        action def computeMedicationDose {
            in weight : MassKg;
            in gfr : GFRValueMlMin;
            in standardDose : DoseValueMg;
            return adjustedDose : DoseValueMg;
        }

        action def performCalculation {
            in patient : PatientData;
            in calcType : CalculationType;
            return result : ComputationResult;
        }
    }

    part def DisplayModule {
        doc "Presents computation results to the healthcare professional.";
        port resultIn : ResultIn2;

        action def formatResult {
            in result : ComputationResult;
            return formatted : String;
        }

        action def displayResult {
            in result : ComputationResult;
        }
    }

    part def StorageModule {
        doc "Maintains a history of all calculations performed.";
        port recordIn : ResultIn2;
        attribute storedRecords : StoredRecord[0..*];

        action def storeResult {
            in result : ComputationResult;
            in patientId : String;
        }

        action def retrieveHistory {
            in patientId : String;
            return records : StoredRecord[0..*];
        }
    }

    // ===== State Machine =====
    state def SystemStates {
        state idle {
            doc "System idle, awaiting new patient data input.";
        }
        state validating {
            doc "Validation Module checking input data.";
        }
        state computing {
            doc "Computation Engine performing requested calculation.";
        }
        state presenting {
            doc "Display Module presenting result to healthcare professional.";
        }
        state storing {
            doc "Storage Module persisting computation result.";
        }
        state errorState {
            doc "Error state for handling invalid input data gracefully.";
        }

        transition t_idle_validating first from idle to validating;
        transition t_validating_computing from validating to computing;
        transition t_validating_error from validating to errorState;
        transition t_computing_presenting from computing to presenting;
        transition t_computing_error from computing to errorState;
        transition t_presenting_storing from presenting to storing;
        transition t_storing_idle from storing to idle;
        transition t_error_idle from errorState to idle;
    }

    // ===== Main System =====
    part def CalculatorSystem {
        doc "Medical Calculator System for clinical calculations and patient care support.";
        part inputModule : InputModule;
        part validationModule : ValidationModule;
        part computationEngine : ComputationEngine;
        part displayModule : DisplayModule;
        part storageModule : StorageModule;

        connect inputModule.patientDataOut to validationModule.dataIn;
        connect validationModule.reportOut to computationEngine.reportIn;
        connect computationEngine.resultOut to displayModule.resultIn;
        connect computationEngine.resultOut to storageModule.recordIn;

        exhibit state SystemStates;
    }

    // ===== Requirements =====
    requirement def CapturePatientData {
        doc "The system shall capture comprehensive patient data including a unique patient ID, demographics (age, gender), physical measurements (weight, height), lab results (serum creatinine, cholesterol levels), vital signs (blood pressure), and medical history (smoker, diabetic status).";
    }

    requirement def ValidateData {
        doc "The system shall validate all input patient data for completeness and clinical plausibility before any computation is performed.";
    }

    requirement def ComputeBMIReq {
        doc "The system shall compute Body Mass Index (BMI) based on the patient's weight and height.";
    }

    requirement def ComputeGFRReq {
        doc "The system shall estimate Glomerular Filtration Rate using age, serum creatinine, gender, and weight, applying distinct formulas for male and female patients.";
    }

    requirement def ComputeCardiacRiskReq {
        doc "The system shall assess the patient's cardiac risk using a Framingham-style score based on age, gender, blood pressure, cholesterol levels, and lifestyle factors including smoking and diabetic status.";
    }

    requirement def ComputeMedicationDoseReq {
        doc "The system shall calculate an adjusted medication dose taking into account the patient's weight and kidney function (GFR) to ensure safety and efficacy.";
    }

    requirement def ProduceDetailedResult {
        doc "Each computation result shall include the calculation type, the resulting value with units, a timestamp, a clinical interpretation, and a flag indicating if the value is abnormal.";
    }

    requirement def DisplayAndStore {
        doc "The system shall simultaneously send each computation result to a Display Module for presentation to the healthcare professional and to a Storage Module for historical record keeping.";
    }

    requirement def ManageStates {
        doc "The system shall manage its operational flow through distinct states: idle, validating, computing, presenting, storing, and a dedicated error state for handling invalid input data gracefully.";
    }

    // ===== Requirement Group =====
    part def CalculatorSystemReqPack {
        requirement r01 : CapturePatientData;
        requirement r02 : ValidateData;
        requirement r03 : ComputeBMIReq;
        requirement r04 : ComputeGFRReq;
        requirement r05 : ComputeCardiacRiskReq;
        requirement r06 : ComputeMedicationDoseReq;
        requirement r07 : ProduceDetailedResult;
        requirement r08 : DisplayAndStore;
        requirement r09 : ManageStates;
    }
}
