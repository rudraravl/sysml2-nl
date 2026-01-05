package GeneralMedicalInstrumentSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package ValueDefinitions {
        attribute def BodyTemperature {
            attribute value :> ISQ::ThermodynamicTemperatureValue;
            attribute normalMin : Real = 36.1;
            attribute normalMax : Real = 37.2;
        }
        
        attribute def BloodPressureMeasurement {
            attribute systolic :> ISQ::PressureValue;
            attribute diastolic :> ISQ::PressureValue;
            attribute meanArterial :> ISQ::PressureValue;
            attribute normalSystolicMin : Real = 90.0;
            attribute normalSystolicMax : Real = 120.0;
            attribute normalDiastolicMin : Real = 60.0;
            attribute normalDiastolicMax : Real = 80.0;
        }
        
        attribute def HeartRateMeasurement {
            attribute beatsPerMinute : Real;
            attribute normalMin : Real = 60.0;
            attribute normalMax : Real = 100.0;
        }
        
        attribute def RespiratoryRateMeasurement {
            attribute breathsPerMinute : Real;
            attribute normalMin : Real = 12.0;
            attribute normalMax : Real = 20.0;
        }
        
        attribute def OxygenSaturation {
            attribute percentage : Real;
            attribute normalMin : Real = 95.0;
            attribute normalMax : Real = 100.0;
        }
        
        item def VitalSignsData {
            attribute temperature : BodyTemperature;
            attribute bloodPressure : BloodPressureMeasurement;
            attribute heartRate : HeartRateMeasurement;
            attribute respiratoryRate : RespiratoryRateMeasurement;
            attribute oxygenSaturation : OxygenSaturation;
            attribute timestamp :> ISQ::TimeValue;
            attribute patientId : String;
        }
        
        item def DiagnosticResult {
            attribute assessment : String;
            attribute abnormalFlags : Boolean[*];
            attribute severity : SeverityLevel;
            attribute recommendations : String[*];
        }
        
        enum def SeverityLevel {
            enum normal;
            enum mild;
            enum moderate;
            enum severe;
            enum critical;
        }
    }
    
    package PortDefinitions {
        private import ValueDefinitions::*;
        
        port def VitalSignsOutputPort {
            out item vitals : VitalSignsData;
        }
        
        port def VitalSignsInputPort {
            in item vitals : VitalSignsData;
        }
        
        port def DiagnosticOutputPort {
            out item diagnosis : DiagnosticResult;
        }
        
        port def PowerSupplyPort {
            attribute voltage :> ISQ::VoltageValue;
            attribute current :> ISQ::ElectricCurrentValue;
        }
        
        port def DataStoragePort {
            in item dataToStore : VitalSignsData;
            out item retrievedData : VitalSignsData[*];
        }
    }
    
    package ComponentDefinitions {
        private import ValueDefinitions::*;
        private import PortDefinitions::*;
        
        part def DigitalThermometer {
            port measurementOut : VitalSignsOutputPort;
            port power : PowerSupplyPort;
            
            attribute sensorType : String = "Infrared";
            attribute accuracy : Real = 0.1;
            attribute measurementRangeMin : Real = 32.0;
            attribute measurementRangeMax : Real = 42.0;
            
            perform action measureTemperature {
                out tempReading : BodyTemperature;
            }
        }
        
        part def Sphygmomanometer {
            port measurementOut : VitalSignsOutputPort;
            port power : PowerSupplyPort;
            
            attribute measurementType : String = "Oscillometric";
            attribute cuffSize : String;
            
            perform action measureBloodPressure {
                out bpReading : BloodPressureMeasurement;
            }
        }
        
        part def PulseOximeter {
            port measurementOut : VitalSignsOutputPort;
            port power : PowerSupplyPort;
            
            attribute wavelengths : String[2] = ("660nm", "940nm");
            
            perform action measureOxygenAndPulse {
                out spo2Reading : OxygenSaturation;
                out pulseReading : HeartRateMeasurement;
            }
        }
        
        part def Stethoscope {
            attribute acousticType : String = "Dual-head";
            attribute diaphragmDiameter :> ISQ::LengthValue;
            
            perform action auscultate {
                out heartSounds : String;
                out lungSounds : String;
                out estimatedRespRate : RespiratoryRateMeasurement;
            }
        }
        
        part def CentralMonitoringUnit {
            port vitalsIn : VitalSignsInputPort;
            port diagnosticOut : DiagnosticOutputPort;
            port storage : DataStoragePort;
            port power : PowerSupplyPort;
            
            attribute processingCapacity : Real;
            attribute displayResolution : String;
            
            perform action analyzeVitalSigns {
                in vitals : VitalSignsData;
                out diagnosis : DiagnosticResult;
            }
        }
        
        part def DataRecorder {
            port dataIn : ~DataStoragePort;
            port power : PowerSupplyPort;
            
            attribute storageCapacity :> ISQ::MassValue;
            attribute recordingInterval :> ISQ::TimeValue;
            
            perform action recordData {
                in data : VitalSignsData;
            }
            
            perform action retrieveHistoricalData {
                in patientId : String;
                in timeRangeStart :> ISQ::TimeValue;
                in timeRangeEnd :> ISQ::TimeValue;
                out historicalData : VitalSignsData[*];
            }
        }
        
        part def PowerDistributionUnit {
            port mainPower : PowerSupplyPort;
            port outlet1 : ~PowerSupplyPort;
            port outlet2 : ~PowerSupplyPort;
            port outlet3 : ~PowerSupplyPort;
            port outlet4 : ~PowerSupplyPort;
            port outlet5 : ~PowerSupplyPort;
            
            attribute inputVoltage : Real = 120.0;
            attribute outputVoltage : Real = 12.0;
        }
    }
    
    package BehaviorDefinitions {
        private import ValueDefinitions::*;
        private import ComponentDefinitions::*;
        
        action def PerformComprehensiveExamination {
            in patientId : String;
            out examinationReport : DiagnosticResult;
            
            first start;
            then merge beginMeasurements;
            
            action measureTemp : DigitalThermometer::measureTemperature {
                out tempReading : BodyTemperature;
            }
            
            action measureBP : Sphygmomanometer::measureBloodPressure {
                out bpReading : BloodPressureMeasurement;
            }
            
            action measureOxygen : PulseOximeter::measureOxygenAndPulse {
                out spo2Reading : OxygenSaturation;
                out pulseReading : HeartRateMeasurement;
            }
            
            action listenToPatient : Stethoscope::auscultate {
                out heartSounds : String;
                out lungSounds : String;
                out estimatedRespRate : RespiratoryRateMeasurement;
            }
            
            then merge aggregateMeasurements;
            
            action compileVitals {
                in temperature = measureTemp.tempReading;
                in bloodPressure = measureBP.bpReading;
                in oxygenSat = measureOxygen.spo2Reading;
                in heartRate = measureOxygen.pulseReading;
                in respRate = listenToPatient.estimatedRespRate;
                in patId = patientId;
                out vitalSigns : VitalSignsData;
            }
            
            then action analyzeResults : CentralMonitoringUnit::analyzeVitalSigns {
                in vitals = compileVitals.vitalSigns;
                out diagnosis : DiagnosticResult;
            }
            
            then action storeResults : DataRecorder::recordData {
                in data = compileVitals.vitalSigns;
            }
            
            then decide;
                if analyzeResults.diagnosis.severity == SeverityLevel::critical then emergencyResponse;
                if analyzeResults.diagnosis.severity == SeverityLevel::severe then urgentResponse;
                if analyzeResults.diagnosis.severity == SeverityLevel::moderate then standardResponse;
                if analyzeResults.diagnosis.severity == SeverityLevel::mild then standardResponse;
                if analyzeResults.diagnosis.severity == SeverityLevel::normal then standardResponse;
            
            action emergencyResponse {
                in criticalDiagnosis = analyzeResults.diagnosis;
            }
            then completeExam;
            
            action urgentResponse {
                in urgentDiagnosis = analyzeResults.diagnosis;
            }
            then completeExam;
            
            action standardResponse {
                in standardDiagnosis = analyzeResults.diagnosis;
            }
            then completeExam;
            
            action completeExam {
                in finalDiagnosis = analyzeResults.diagnosis;
                out report = examinationReport;
            }
            then done;
        }
        
        state def MonitoringStateMachine {
            entry action initializeSystem;
            do action continuousMonitoring;
            exit action shutdownSystem;
            
            state Idle {
                entry action displayReady;
            }
            
            state Measuring {
                entry action startMeasurementSequence;
                do action acquireVitalSigns;
                exit action finalizeMeasurements;
            }
            
            state Analyzing {
                entry action beginAnalysis;
                do action processVitalSigns;
                exit action completeAnalysis;
            }
            
            state Alerting {
                entry action activateAlarm;
                do action displayCriticalAlert;
                exit action acknowledgeAlert;
            }
            
            state Recording {
                entry action prepareStorage;
                do action saveData;
                exit action confirmStorage;
            }
            
            transition idleToMeasuring
                first Idle
                accept StartMeasurement
                then Measuring;
            
            transition measuringToAnalyzing
                first Measuring
                accept MeasurementsComplete
                then Analyzing;
            
            transition analyzingToAlerting
                first Analyzing
                if abnormalDetected
                then Alerting;
            
            transition analyzingToRecording
                first Analyzing
                if normalDetected
                then Recording;
            
            transition alertingToRecording
                first Alerting
                accept AlertAcknowledged
                then Recording;
            
            transition recordingToIdle
                first Recording
                accept StorageComplete
                then Idle;
        }
        
        action def StartMeasurement;
        action def MeasurementsComplete;
        action def AlertAcknowledged;
        action def StorageComplete;
        
        attribute def abnormalDetected : Boolean;
        attribute def normalDetected : Boolean;
    }
    
    package SystemDefinition {
        private import ComponentDefinitions::*;
        private import BehaviorDefinitions::*;
        private import ValueDefinitions::*;
        
        part def MedicalExaminationStation {
            part thermometer : DigitalThermometer;
            part bpMonitor : Sphygmomanometer;
            part oximeter : PulseOximeter;
            part stethoscope : Stethoscope;
            part monitor : CentralMonitoringUnit;
            part recorder : DataRecorder;
            part powerUnit : PowerDistributionUnit;
            
            connection powerToThermometer connect powerUnit.outlet1 to thermometer.power;
            connection powerToBPMonitor connect powerUnit.outlet2 to bpMonitor.power;
            connection powerToOximeter connect powerUnit.outlet3 to oximeter.power;
            connection powerToMonitor connect powerUnit.outlet4 to monitor.power;
            connection powerToRecorder connect powerUnit.outlet5 to recorder.power;
            
            connection thermometerData connect thermometer.measurementOut to monitor.vitalsIn;
            connection bpMonitorData connect bpMonitor.measurementOut to monitor.vitalsIn;
            connection oximeterData connect oximeter.measurementOut to monitor.vitalsIn;
            
            connection storageLink connect monitor.storage to recorder.dataIn;
            
            exhibit state monitoringBehavior : MonitoringStateMachine;
            
            perform action conductExamination[*] ordered : PerformComprehensiveExamination;
        }
    }
    
    package RequirementsSpecification {
        private import SystemDefinition::*;
        private import ValueDefinitions::*;
        
        requirement def FunctionalRequirements {
            doc /* Top-level functional requirements for the medical examination station */
        }
        
        requirement primaryFunction : FunctionalRequirements {
            doc /* The system shall acquire, analyze, and record patient vital signs to support comprehensive medical examinations */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement vitalSignsAcquisition : FunctionalRequirements {
            doc /* The system shall measure body temperature, blood pressure, heart rate, respiratory rate, and oxygen saturation */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement dataAnalysis : FunctionalRequirements {
            doc /* The system shall analyze vital signs against normal ranges and generate diagnostic assessments */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement dataRecording : FunctionalRequirements {
            doc /* The system shall record all measurements with timestamps and patient identification */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement def PerformanceRequirements {
            doc /* Performance requirements for the medical examination station */
        }
        
        requirement measurementAccuracy : PerformanceRequirements {
            doc /* Temperature accuracy shall be within ±0.1°C, blood pressure within ±3 mmHg, SpO2 within ±2% */
            subject examinationStation : MedicalExaminationStation;
            
            require constraint {
                examinationStation.thermometer.accuracy <= 0.1
            }
        }
        
        requirement measurementSpeed : PerformanceRequirements {
            doc /* Complete vital signs assessment shall be completed within 5 minutes */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement alertResponseTime : PerformanceRequirements {
            doc /* Critical abnormalities shall trigger alerts within 2 seconds of detection */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement def SafetyRequirements {
            doc /* Safety requirements for patient and operator protection */
        }
        
        requirement electricalSafety : SafetyRequirements {
            doc /* All patient-contact instruments shall meet IEC 60601-1 electrical safety standards */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement dataPrivacy : SafetyRequirements {
            doc /* Patient data shall be encrypted and access-controlled per HIPAA requirements */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement def UsabilityRequirements {
            doc /* Usability requirements for clinical workflow integration */
        }
        
        requirement operatorInterface : UsabilityRequirements {
            doc /* The system shall provide intuitive controls operable by trained medical personnel */
            subject examinationStation : MedicalExaminationStation;
        }
        
        requirement dataRetrieval : UsabilityRequirements {
            doc /* Historical patient data shall be retrievable within 10 seconds */
            subject examinationStation : MedicalExaminationStation;
        }
    }
    
    package SystemInstance {
        private import SystemDefinition::*;
        private import RequirementsSpecification::*;
        
        part clinicalExaminationStation : MedicalExaminationStation {
            satisfy primaryFunction by conductExamination;
            satisfy vitalSignsAcquisition by thermometer;
            satisfy vitalSignsAcquisition by bpMonitor;
            satisfy vitalSignsAcquisition by oximeter;
            satisfy dataAnalysis by monitor;
            satisfy dataRecording by recorder;
            satisfy measurementAccuracy by thermometer;
            satisfy measurementSpeed by conductExamination;
            satisfy alertResponseTime by monitor;
            satisfy electricalSafety by powerUnit;
            satisfy dataPrivacy by recorder;
            satisfy operatorInterface by monitor;
            satisfy dataRetrieval by recorder;
        }
    }
}
