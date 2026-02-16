package 'Medical Device Data and Interoperability System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def DeviceID;
    attribute def PatientID;
    attribute def Timestamp;
    attribute def AlarmSignal;
    attribute def SystemStart;
    attribute def SystemShutdown;
    
    value type HeartRateValue :> ISQ::FrequencyValue {
        doc /* Heart rate measured in beats per minute */
    }
    
    value type BloodPressureValue :> ISQ::PressureValue {
        doc /* Blood pressure measured in mmHg */
    }
    
    value type OxygenSaturationValue :> Real {
        doc /* Oxygen saturation as percentage */
    }
    
    value type TemperatureValue :> ISQ::ThermodynamicTemperatureValue {
        doc /* Body temperature */
    }
    
    item def VitalSignsData {
        attribute deviceID : DeviceID;
        attribute patientID : PatientID;
        attribute timestamp : Timestamp;
        attribute heartRate : HeartRateValue;
        attribute bloodPressure : BloodPressureValue;
        attribute oxygenSaturation : OxygenSaturationValue;
        attribute temperature : TemperatureValue;
    }
    
    item def AggregatedPatientData {
        attribute patientID : PatientID;
        attribute vitalSigns : VitalSignsData[*];
        attribute alertLevel : Real;
    }
    
    requirement def MDDIRequirement {
        doc /* Top-level requirements for Medical Device Data and Interoperability system */
    }
    
    requirement <'MDDI-001'> primaryFunction : MDDIRequirement {
        doc /* The MD&DI system shall acquire, aggregate, process, store, and display 
             medical device data from multiple sources while maintaining data integrity 
             and enabling interoperability across healthcare systems */
        
        require dataAcquisition;
        require dataAggregation;
        require dataProcessing;
        require dataStorage;
        require dataDisplay;
        require interoperability;
    }
    
    requirement <'MDDI-002'> dataAcquisition {
        doc /* The system shall acquire data from multiple medical devices in real-time 
             with latency not exceeding 500 milliseconds */
    }
    
    requirement <'MDDI-003'> dataAggregation {
        doc /* The system shall aggregate data from multiple sources and correlate 
             by patient identifier and timestamp */
    }
    
    requirement <'MDDI-004'> dataProcessing {
        doc /* The system shall process vital signs data and detect abnormal conditions 
             requiring clinical attention */
    }
    
    requirement <'MDDI-005'> dataStorage {
        doc /* The system shall store all acquired medical device data with complete 
             audit trail for minimum 7 years */
    }
    
    requirement <'MDDI-006'> dataDisplay {
        doc /* The system shall display current and historical patient data in 
             standardized clinical format */
    }
    
    requirement <'MDDI-007'> interoperability {
        doc /* The system shall support HL7 FHIR and DICOM standards for data exchange 
             with external healthcare information systems */
    }
    
    requirement <'MDDI-008'> dataIntegrity {
        doc /* The system shall not alter the clinical meaning or value of any 
             medical device data during transfer, storage, or display */
    }
    
    requirement <'MDDI-009'> safetyConstraint {
        doc /* The system shall generate alarms when vital signs exceed defined 
             thresholds within 2 seconds of detection */
    }
    
    part def MedicalDeviceInterface {
        attribute deviceType : String;
        attribute samplingRate : ISQ::FrequencyValue;
        out port dataOut;
    }
    
    part def DataAggregator {
        attribute bufferSize : Integer;
        in port deviceData1;
        in port deviceData2;
        in port deviceData3;
        out port aggregatedDataOut;
    }
    
    part def ClinicalDataProcessor {
        attribute heartRateThresholdLow : HeartRateValue;
        attribute heartRateThresholdHigh : HeartRateValue;
        attribute oxygenSaturationThreshold : OxygenSaturationValue;
        in port dataIn;
        out port processedDataOut;
        out port alarmOut;
    }
    
    part def DataRepository {
        attribute storageCapacity : ISQ::VolumeValue;
        attribute retentionPeriod : ISQ::TimeValue;
        in port dataIn;
        out port queryOut;
    }
    
    part def ClinicalDisplay {
        attribute refreshRate : ISQ::FrequencyValue;
        attribute displayResolution : String;
        in port dataIn;
        in port alarmIn;
    }
    
    part def InteroperabilityGateway {
        attribute supportedProtocols : String[*];
        in port internalDataIn;
        out port externalDataOut;
        in port externalDataIn;
        out port internalDataOut;
    }
    
    action def AcquireVitalSigns {
        in deviceID : DeviceID;
        in patientID : PatientID;
        out vitalSignsData : VitalSignsData;
    }
    
    action def AggregateData {
        in deviceData1 : VitalSignsData;
        in deviceData2 : VitalSignsData;
        in deviceData3 : VitalSignsData;
        out aggregatedData : AggregatedPatientData;
    }
    
    action def ProcessVitalSigns {
        in patientData : AggregatedPatientData;
        in thresholdLow : Real;
        in thresholdHigh : Real;
        out processedData : AggregatedPatientData;
        out alarmTriggered : Boolean;
    }
    
    action def StoreData {
        in dataToStore : AggregatedPatientData;
        out storageConfirmation : Boolean;
    }
    
    action def DisplayPatientData {
        in displayData : AggregatedPatientData;
        in alarmStatus : Boolean;
    }
    
    action def ExchangeData {
        in internalData : AggregatedPatientData;
        out externalData : String;
    }
    
    action def MDDIOperation {
        doc /* Primary operational behavior of the MD&DI system coordinating 
             data flow from acquisition through display and storage */
        
        first start;
        then accept systemStart : SystemStart;
        
        then merge continuousOperation;
        
        then fork parallelProcessing;
        
        action acquireFromDevice1 : AcquireVitalSigns {
            in deviceID : DeviceID;
            in patientID : PatientID;
            out vitalSignsData : VitalSignsData;
        }
        then join dataCollection;
        
        action acquireFromDevice2 : AcquireVitalSigns {
            in deviceID : DeviceID;
            in patientID : PatientID;
            out vitalSignsData : VitalSignsData;
        }
        then dataCollection;
        
        action acquireFromDevice3 : AcquireVitalSigns {
            in deviceID : DeviceID;
            in patientID : PatientID;
            out vitalSignsData : VitalSignsData;
        }
        then dataCollection;
        
        then action aggregate : AggregateData {
            in deviceData1 : VitalSignsData;
            in deviceData2 : VitalSignsData;
            in deviceData3 : VitalSignsData;
            out aggregatedData : AggregatedPatientData;
        }
        
        then action process : ProcessVitalSigns {
            in patientData : AggregatedPatientData;
            in thresholdLow : Real;
            in thresholdHigh : Real;
            out processedData : AggregatedPatientData;
            out alarmTriggered : Boolean;
        }
        
        then fork dataDistribution;
        
        action store : StoreData {
            in dataToStore : AggregatedPatientData;
            out storageConfirmation : Boolean;
        }
        then join afterDistribution;
        
        action display : DisplayPatientData {
            in displayData : AggregatedPatientData;
            in alarmStatus : Boolean;
        }
        then afterDistribution;
        
        action exchange : ExchangeData {
            in internalData : AggregatedPatientData;
            out externalData : String;
        }
        then afterDistribution;
        
        then decide;
            if process.alarmTriggered then handleAlarm;
            else continuousOperation;
        
        action handleAlarm {
            first accept alarm : AlarmSignal;
            then continuousOperation;
        }
    }
    
    part medicalDeviceDataSystem : MDDIIntegratedSystem {
        doc /* Integrated Medical Device Data and Interoperability system for 
             comprehensive patient monitoring and data management */
        
        satisfy primaryFunction;
        
        perform action operation : MDDIOperation;
        
        part ecgMonitor : MedicalDeviceInterface {
            attribute :>> deviceType = "ECG";
            attribute :>> samplingRate = 500 [SI::Hz];
            perform operation.acquireFromDevice1;
        }
        
        part bpMonitor : MedicalDeviceInterface {
            attribute :>> deviceType = "Blood Pressure";
            attribute :>> samplingRate = 1 [SI::Hz];
            perform operation.acquireFromDevice2;
        }
        
        part pulseOximeter : MedicalDeviceInterface {
            attribute :>> deviceType = "Pulse Oximeter";
            attribute :>> samplingRate = 10 [SI::Hz];
            perform operation.acquireFromDevice3;
        }
        
        part aggregator : DataAggregator {
            attribute :>> bufferSize = 1000;
            perform operation.aggregate;
        }
        
        part processor : ClinicalDataProcessor {
            perform operation.process;
        }
        
        part repository : DataRepository {
            attribute :>> retentionPeriod = 2555 [SI::d];
            perform operation.store;
        }
        
        part clinicalDisplay : ClinicalDisplay {
            attribute :>> refreshRate = 30 [SI::Hz];
            attribute :>> displayResolution = "1920x1080";
            perform operation.display;
        }
        
        part gateway : InteroperabilityGateway {
            attribute :>> supportedProtocols = ("HL7 FHIR", "DICOM", "IEEE 11073");
            perform operation.exchange;
        }
        
        connect ecgMonitor.dataOut to aggregator.deviceData1;
        connect bpMonitor.dataOut to aggregator.deviceData2;
        connect pulseOximeter.dataOut to aggregator.deviceData3;
        connect aggregator.aggregatedDataOut to processor.dataIn;
        connect processor.processedDataOut to repository.dataIn;
        connect processor.processedDataOut to clinicalDisplay.dataIn;
        connect processor.alarmOut to clinicalDisplay.alarmIn;
        connect processor.processedDataOut to gateway.internalDataIn;
    }
    
    part def MDDIIntegratedSystem {
        doc /* Complete Medical Device Data and Interoperability system integrating 
             acquisition, aggregation, processing, storage, display, and external 
             data exchange capabilities */
    }
}
