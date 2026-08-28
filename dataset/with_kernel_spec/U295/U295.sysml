package MedicalCalculatorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQBase::*;

    value def AgeValue :> Real;
    value def WeightValue :> Mass;
    value def HeightValue :> Length;
    value def SerumCreatinineValue :> Real;
    value def CholesterolValue :> Real;
    value def BloodPressureValue :> Real;
    value def BMIValue :> Real;
    value def GFRValue :> Real;
    value def DoseValue :> Mass;
    value def RiskScoreValue :> Real;

    enum def GenderType {
        male;
        female;
    }

    enum def CalculationType {
        BMI;
        GFR;
        CardiacRisk;
        MedicationDosage;
    }

    item def PatientData {
        attribute patientID : String;
        attribute age : AgeValue;
        attribute gender : GenderType;
        attribute weight : WeightValue;
        attribute height : HeightValue;
        attribute serumCreatinine : SerumCreatinineValue;
        attribute totalCholesterol : CholesterolValue;
        attribute hdlCholesterol : CholesterolValue;
        attribute systolicBP : BloodPressureValue;
        attribute diastolicBP : BloodPressureValue;
        attribute isSmoker : Boolean;
        attribute isDiabetic : Boolean;
    }

    item def CalculationRequest {
        attribute calcType : CalculationType;
        attribute baseDose : DoseValue;
    }

    item def CalculationResult {
        attribute calcType : CalculationType;
        attribute resultValue : Real;
        attribute unitLabel : String;
        attribute timestamp : String;
        attribute interpretation : String;
        attribute isAbnormal : Boolean;
        attribute patientID : String;
    }

    item def ValidationError {
        attribute errorMessage : String;
        attribute fieldName : String;
        attribute patientID : String;
    }

    port def PatientDataInPort { in item patientData : PatientData; }
    port def PatientDataOutPort { out item patientData : PatientData; }
    port def RequestInPort { in item request : CalculationRequest; }
    port def ResultOutPort { out item result : CalculationResult; }
    port def ResultInPort { in item result : CalculationResult; }
    port def ErrorOutPort { out item error : ValidationError; }

    part def InputModule {
        port patientDataIn : PatientDataInPort;
        port patientDataOut : PatientDataOutPort;
        perform action captureData {
            in item data : PatientData;
            out item capturedData : PatientData;
        }
    }

    part def ValidationModule {
        port patientDataIn : PatientDataInPort;
        port validDataOut : PatientDataOutPort;
        port errorOut : ErrorOutPort;
        perform action validate {
            in item data : PatientData;
            out item validData : PatientData;
            out item error : ValidationError;
        }
    }

    part def BMICalculator {
        perform action calculateBMI {
            in item weight : WeightValue;
            in item height : HeightValue;
            out item bmi : BMIValue;
            out item interpretation : String;
            out item isAbnormal : Boolean;
        }
    }

    part def GFRCalculator {
        perform action calculateGFR {
            in item age : AgeValue;
            in item weight : WeightValue;
            in item serumCreatinine : SerumCreatinineValue;
            in item gender : GenderType;
            out item gfr : GFRValue;
            out item interpretation : String;
            out item isAbnormal : Boolean;
        }
    }

    part def CardiacRiskCalculator {
        perform action calculateCardiacRisk {
            in item age : AgeValue;
            in item gender : GenderType;
            in item systolicBP : BloodPressureValue;
            in item totalCholesterol : CholesterolValue;
            in item hdlCholesterol : CholesterolValue;
            in item isSmoker : Boolean;
            in item isDiabetic : Boolean;
            out item riskScore : RiskScoreValue;
            out item interpretation : String;
            out item isAbnormal : Boolean;
        }
    }

    part def DosageCalculator {
        perform action calculateDosage {
            in item weight : WeightValue;
            in item gfr : GFRValue;
            in item baseDose : DoseValue;
            out item adjustedDose : DoseValue;
            out item interpretation : String;
            out item isAbnormal : Boolean;
        }
    }

    part def ComputationEngine {
        port dataIn : PatientDataInPort;
        port requestIn : RequestInPort;
        port resultOut : ResultOutPort;
        perform action compute {
            in item data : PatientData;
            in item request : CalculationRequest;
            out item result : CalculationResult;
            action calculateBMI {
                in item weight : WeightValue;
                in item height : HeightValue;
                out item bmi : BMIValue;
                out item interpretation : String;
                out item isAbnormal : Boolean;
            }
            action calculateGFR {
                in item age : AgeValue;
                in item weight : WeightValue;
                in item serumCreatinine : SerumCreatinineValue;
                in item gender : GenderType;
                out item gfr : GFRValue;
                out item interpretation : String;
                out item isAbnormal : Boolean;
            }
            action calculateCardiacRisk {
                in item age : AgeValue;
                in item gender : GenderType;
                in item systolicBP : BloodPressureValue;
                in item totalCholesterol : CholesterolValue;
                in item hdlCholesterol : CholesterolValue;
                in item isSmoker : Boolean;
                in item isDiabetic : Boolean;
                out item riskScore : RiskScoreValue;
                out item interpretation : String;
                out item isAbnormal : Boolean;
            }
            action calculateDosage {
                in item weight : WeightValue;
                in item gfr : GFRValue;
                in item baseDose : DoseValue;
                out item adjustedDose : DoseValue;
                out item interpretation : String;
                out item isAbnormal : Boolean;
            }
        }
        part bmiCalc : BMICalculator {
            perform compute.calculateBMI;
        }
        part gfrCalc : GFRCalculator {
            perform compute.calculateGFR;
        }
        part cardiacRiskCalc : CardiacRiskCalculator {
            perform compute.calculateCardiacRisk;
        }
        part dosageCalc : DosageCalculator {
            perform compute.calculateDosage;
        }
    }

    part def DisplayModule {
        port resultIn : ResultInPort;
        perform action display {
            in item result : CalculationResult;
        }
    }

    part def StorageModule {
        port resultIn : ResultInPort;
        item storedResults : CalculationResult[*] ordered;
        perform action store {
            in item result : CalculationResult;
        }
    }

    state def OperationalStates {
        entry; then idle;
        state idle;
        state validating;
        state computing;
        state presenting;
        state storing;
        state error;
        transition t_idle_to_validating first idle then validating;
        transition t_validating_to_computing first validating then computing;
        transition t_validating_to_error first validating then error;
        transition t_computing_to_presenting first computing then presenting;
        transition t_presenting_to_storing first presenting then storing;
        transition t_storing_to_idle first storing then idle;
        transition t_error_to_idle first error then idle;
    }

    part def MedicalCalculator {
        port patientDataIn : PatientDataInPort;
        port calculationRequestIn : RequestInPort;
        port resultOut : ResultOutPort;
        port errorOut : ErrorOutPort;
        part inputModule : InputModule;
        part validationModule : ValidationModule;
        part computationEngine : ComputationEngine;
        part displayModule : DisplayModule;
        part storageModule : StorageModule;
        bind patientDataIn = inputModule.patientDataIn;
        connect inputModule.patientDataOut to validationModule.patientDataIn;
        connect validationModule.validDataOut to computationEngine.dataIn;
        bind calculationRequestIn = computationEngine.requestIn;
        connect computationEngine.resultOut to displayModule.resultIn;
        connect computationEngine.resultOut to storageModule.resultIn;
        bind resultOut = computationEngine.resultOut;
        bind errorOut = validationModule.errorOut;
        exhibit state OperationalStates;
    }

    requirement def MedicalCalculatorRequirements {
        doc
        /* Requirements for the Medical Calculator System. */
        requirement def DataInputRequirement {
            doc /* The system shall accept comprehensive patient data including patient ID, age, gender, weight, height, lab results, vital signs, and medical history. */
        }
        requirement def ValidationRequirement {
            doc /* The system shall validate all input data for completeness and clinical plausibility. */
            attribute maxAge : AgeValue = 150;
            attribute maxWeight : WeightValue = 500;
            attribute maxHeight : HeightValue = 3;
        }
        requirement def ComputationRequirement {
            doc /* The system shall perform BMI, GFR, Cardiac Risk, and Medication Dosage calculations. */
        }
        requirement def BMIResultRequirement {
            doc /* The system shall calculate BMI from weight and height in kg/m^2. */
        }
        requirement def GFRResultRequirement {
            doc /* The system shall estimate GFR using age, serum creatinine, gender, and weight, with different formulas for male and female patients. */
        }
        requirement def CardiacRiskResultRequirement {
            doc /* The system shall assess cardiovascular risk based on age, gender, blood pressure, cholesterol levels, and lifestyle factors. */
        }
        requirement def DosageResultRequirement {
            doc /* The system shall calculate adjusted medication dose based on weight and GFR. */
        }
        requirement def ResultFormatRequirement {
            doc /* The system shall produce a result containing calculation type, value with units, timestamp, clinical interpretation, and abnormal flag. */
        }
        requirement def DisplayRequirement {
            doc /* The system shall display results to the healthcare professional in a clear format. */
        }
        requirement def StorageRequirement {
            doc /* The system shall maintain a history of all calculations performed. */
        }
        requirement def StateMachineRequirement {
            doc /* The system shall manage operational flow through states: idle, validating, computing, presenting, storing, and error. */
        }
    }
}
