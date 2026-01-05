package FDABreakthroughMedicalDevice {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def BloodGlucoseLevel :> Real;
    
    attribute def InsulinDosage :> Real;
    
    attribute def DeviceIdentification {
        attribute udiNumber : String;
        attribute serialNumber : String;
        attribute manufacturingDate : String;
    }
    
    enum def OperationalMode {
        initialization;
        continuousMonitoring;
        insulinDelivery;
        alerting;
        calibration;
        shutdown;
    }
    
    enum def AlertLevel {
        normal;
        warning;
        critical;
        emergency;
    }
    
    enum def RegulatoryClassification {
        breakthroughDesignated;
        investigationalUse;
        preMarketApproval;
        postMarketSurveillance;
    }
    
    item def PatientData {
        attribute glucoseLevel : BloodGlucoseLevel;
        attribute timestamp : String;
        attribute trendDirection : String;
        attribute rateOfChange : Real;
    }
    
    item def TherapyCommand {
        attribute dosage : InsulinDosage;
        attribute deliveryRate : Real;
        attribute duration : DurationValue;
    }
    
    item def AlertNotification {
        attribute level : AlertLevel;
        attribute messageText : String;
        attribute timestamp : String;
        attribute requiresAction : Boolean;
    }
    
    part def ContinuousGlucoseSensor {
        attribute sensorAccuracy : Real;
        attribute calibrationInterval : DurationValue;
        port glucoseDataOutput;
        
        action measureGlucose {
            out glucoseReading : BloodGlucoseLevel;
            out measurementQuality : Real;
        }
    }
    
    part def InsulinPump {
        attribute reservoirCapacity : InsulinDosage;
        attribute currentReservoirLevel : InsulinDosage;
        attribute maxDeliveryRate : Real;
        port therapyCommandInput;
        port insulinDeliveryOutput;
        
        action deliverInsulin {
            in command : TherapyCommand;
            out actualDelivery : InsulinDosage;
            out deliveryStatus : Boolean;
        }
    }
    
    part def ControlAlgorithmProcessor {
        attribute algorithmVersion : String;
        attribute predictionHorizon : DurationValue;
        attribute targetGlucoseRange : Real[2];
        port sensorDataInput;
        port therapyControlOutput;
        port alertOutput;
        
        action analyzeGlucoseData {
            in patientData : PatientData;
            out predictedGlucose : BloodGlucoseLevel;
            out insulinRequirement : InsulinDosage;
        }
        
        action calculateInsulinDose {
            in currentGlucose : BloodGlucoseLevel;
            in predictedGlucose : BloodGlucoseLevel;
            in targetRange : Real[2];
            out recommendedDose : InsulinDosage;
        }
        
        action generateAlert {
            in glucoseLevel : BloodGlucoseLevel;
            in trend : String;
            out alert : AlertNotification;
        }
    }
    
    part def SafetyMonitor {
        attribute maxSingleDose : InsulinDosage;
        attribute maxHourlyDose : InsulinDosage;
        attribute glucoseLowerLimit : BloodGlucoseLevel;
        port therapyMonitorInput;
        port safetyOverrideOutput;
        
        action validateTherapy {
            in proposedDose : InsulinDosage;
            in currentGlucose : BloodGlucoseLevel;
            out approved : Boolean;
            out safetyAlert : AlertNotification;
        }
    }
    
    part def UserInterface {
        attribute displayType : String;
        attribute touchEnabled : Boolean;
        port statusDisplayPort;
        port userInputPort;
        port alertDisplayPort;
        
        action displayStatus {
            in currentMode : OperationalMode;
            in glucoseLevel : BloodGlucoseLevel;
            in insulinOnBoard : InsulinDosage;
        }
        
        action acceptUserInput {
            out mealAnnouncement : Real;
            out manualBolusRequest : InsulinDosage;
            out systemCommand : String;
        }
        
        action displayAlert {
            in alert : AlertNotification;
        }
    }
    
    part def DataLogger {
        attribute storageCapacity : Real;
        attribute encryptionEnabled : Boolean;
        attribute dataRetentionPeriod : DurationValue;
        port dataRecordingInput;
        
        action logTherapyEvent {
            in timestamp : String;
            in glucoseLevel : BloodGlucoseLevel;
            in insulinDelivered : InsulinDosage;
            in systemMode : OperationalMode;
        }
    }
    
    part def WirelessCommunication {
        attribute communicationProtocol : String;
        attribute encryptionStandard : String;
        attribute transmissionRange : Real;
        port deviceDataPort;
        port externalSystemPort;
        
        action transmitData {
            in deviceData : PatientData;
            out encryptedTransmission : String;
        }
        
        action receiveRemoteCommand {
            in remoteSignal : String;
            out decodedCommand : String;
        }
    }
    
    part def AutomatedInsulinDeliverySystem {
        attribute deviceIdentification : DeviceIdentification;
        attribute regulatoryStatus : RegulatoryClassification = RegulatoryClassification::breakthroughDesignated;
        attribute currentMode : OperationalMode;
        attribute batteryLevel : Real;
        attribute systemUptime : DurationValue;
        
        part glucoseSensor : ContinuousGlucoseSensor {
            attribute :>> sensorAccuracy = 0.92;
            attribute :>> calibrationInterval = 12 [h];
        }
        
        part insulinPump : InsulinPump {
            attribute :>> reservoirCapacity = 300.0;
            attribute :>> currentReservoirLevel = 250.0;
            attribute :>> maxDeliveryRate = 25.0;
        }
        
        part controlProcessor : ControlAlgorithmProcessor {
            attribute :>> algorithmVersion = "AID-v3.2.1";
            attribute :>> predictionHorizon = 60 [min];
            attribute :>> targetGlucoseRange = (70.0, 180.0);
        }
        
        part safetyMonitor : SafetyMonitor {
            attribute :>> maxSingleDose = 10.0;
            attribute :>> maxHourlyDose = 25.0;
            attribute :>> glucoseLowerLimit = 70.0;
        }
        
        part userInterface : UserInterface {
            attribute :>> displayType = "color_touchscreen";
            attribute :>> touchEnabled = true;
        }
        
        part dataLogger : DataLogger {
            attribute :>> storageCapacity = 90000.0;
            attribute :>> encryptionEnabled = true;
            attribute :>> dataRetentionPeriod = 90 [day];
        }
        
        part wirelessModule : WirelessCommunication {
            attribute :>> communicationProtocol = "bluetooth_low_energy";
            attribute :>> encryptionStandard = "AES_256";
            attribute :>> transmissionRange = 10.0;
        }
        
        connection sensorToControl connect 
            glucoseSensor.glucoseDataOutput to controlProcessor.sensorDataInput;
        
        connection controlToSafety connect 
            controlProcessor.therapyControlOutput to safetyMonitor.therapyMonitorInput;
        
        connection safetyToPump connect 
            safetyMonitor.safetyOverrideOutput to insulinPump.therapyCommandInput;
        
        connection controlToAlert connect 
            controlProcessor.alertOutput to userInterface.alertDisplayPort;
        
        connection controlToLogger connect 
            controlProcessor.sensorDataInput to dataLogger.dataRecordingInput;
        
        connection loggerToWireless connect 
            dataLogger.dataRecordingInput to wirelessModule.deviceDataPort;
        
        connection uiToControl connect 
            userInterface.userInputPort to controlProcessor.sensorDataInput;
    }
    
    action def MonitorPatientGlucose {
        in patient : String;
        out glucoseData : PatientData;
        out sensorStatus : Boolean;
    }
    
    action def DetermineInsulinNeed {
        in glucoseData : PatientData;
        in targetRange : Real[2];
        out insulinRequired : Boolean;
        out recommendedDose : InsulinDosage;
    }
    
    action def DeliverAutomatedTherapy {
        in dosage : InsulinDosage;
        in safetyApproval : Boolean;
        out deliveryConfirmation : Boolean;
        out actualDoseDelivered : InsulinDosage;
    }
    
    action def AutomatedGlycemicControl {
        first start;
        
        then merge continuousControl;
        
        then action monitor : MonitorPatientGlucose {
            in patient : String;
            out currentGlucose : PatientData;
            out operational : Boolean;
        }
        
        then action determine : DetermineInsulinNeed {
            in glucoseData = monitor.currentGlucose;
            in targetRange = (70.0, 180.0);
            out needsInsulin : Boolean;
            out dose : InsulinDosage;
        }
        
        then decide;
            if determine.needsInsulin == true then deliverTherapy;
            if determine.needsInsulin == false then continuousControl;
        
        action deliverTherapy : DeliverAutomatedTherapy {
            in dosage = determine.dose;
            in safetyApproval : Boolean = true;
            out confirmed : Boolean;
            out delivered : InsulinDosage;
        }
        
        then action recordEvent {
            in timestamp : String;
            in glucoseLevel = monitor.currentGlucose.glucoseLevel;
            in insulinDelivered = deliverTherapy.delivered;
        }
        
        then continuousControl;
    }
    
    requirement def FDABreakthroughDeviceDesignation {
        doc /* 
         * Device must qualify for FDA Breakthrough Device designation by:
         * - Providing more effective treatment for life-threatening or 
         *   irreversibly debilitating disease
         * - Offering significant advantages over existing approved alternatives
         * - Demonstrating preliminary clinical evidence of benefit
         */
        subject device : AutomatedInsulinDeliverySystem;
    }
    
    requirement <'REQ-BTD-001'> breakthroughQualification : FDABreakthroughDeviceDesignation {
        doc /* 
         * The Automated Insulin Delivery System shall qualify as an FDA 
         * Breakthrough Device for treatment of Type 1 diabetes by providing 
         * continuous automated glycemic control without manual intervention.
         */
        subject device :>> AutomatedInsulinDeliverySystem;
    }
    
    requirement <'REQ-FUNC-001'> primarySystemFunction {
        doc /* 
         * The system shall continuously monitor blood glucose levels and 
         * automatically deliver precise insulin doses to maintain glucose 
         * within target range without requiring manual user intervention 
         * for routine therapy decisions.
         */
        subject device :>> AutomatedInsulinDeliverySystem;
        
        require <'REQ-FUNC-001.1'> continuousGlucoseMonitoring {
            doc /* 
             * The system shall measure interstitial glucose levels continuously 
             * with readings updated at least every 5 minutes.
             */
            assert constraint {
                device.glucoseSensor.sensorAccuracy >= 0.90
            }
        }
        
        require <'REQ-FUNC-001.2'> automatedInsulinDelivery {
            doc /* 
             * The system shall automatically calculate and deliver insulin 
             * doses based on current and predicted glucose levels without 
             * requiring user confirmation for basal adjustments.
             */
            assert constraint {
                device.controlProcessor.predictionHorizon >= 30 [min]
            }
        }
        
        require <'REQ-FUNC-001.3'> closedLoopControl {
            doc /* 
             * The system shall operate in closed-loop mode, continuously 
             * adjusting insulin delivery to maintain glucose within the 
             * target range of 70-180 mg/dL.
             */
            assert constraint {
                device.controlProcessor.targetGlucoseRange == (70.0, 180.0)
            }
        }
    }
    
    requirement <'REQ-SAFE-001'> patientSafetyProtection {
        doc /* 
         * The system shall incorporate multiple safety mechanisms to prevent 
         * hypoglycemia and insulin overdose during all operational modes.
         */
        subject device :>> AutomatedInsulinDeliverySystem;
        
        require <'REQ-SAFE-001.1'> doseLimits {
            doc /* 
             * Maximum single insulin dose shall not exceed 10 units and 
             * maximum hourly dose shall not exceed 25 units.
             */
            assert constraint {
                device.safetyMonitor.maxSingleDose <= 10.0 &&
                device.safetyMonitor.maxHourlyDose <= 25.0
            }
        }
        
        require <'REQ-SAFE-001.2'> hypoglycemiaProtection {
            doc /* 
             * The system shall suspend insulin delivery when glucose falls 
             * below 70 mg/dL or is predicted to fall below this threshold.
             */
            assert constraint {
                device.safetyMonitor.glucoseLowerLimit == 70.0
            }
        }
    }
    
    requirement <'REQ-DATA-001'> dataSecurityAndLogging {
        doc /* 
         * All patient data and therapy events shall be encrypted, logged, 
         * and retained for regulatory compliance and clinical analysis.
         */
        subject device :>> AutomatedInsulinDeliverySystem;
        
        assert constraint {
            device.dataLogger.encryptionEnabled == true &&
            device.dataLogger.dataRetentionPeriod >= 90 [day] &&
            device.wirelessModule.encryptionStandard == "AES_256"
        }
    }
    
    requirement <'REQ-PERF-001'> systemReliability {
        doc /* 
         * The system shall maintain continuous operation with sensor accuracy 
         * of at least 92% and insulin delivery precision within 5% of 
         * commanded dose.
         */
        subject device :>> AutomatedInsulinDeliverySystem;
        
        assert constraint {
            device.glucoseSensor.sensorAccuracy >= 0.92
        }
    }
    
    part automatedInsulinDeliveryDevice : AutomatedInsulinDeliverySystem {
        attribute :>> deviceIdentification {
            attribute :>> udiNumber = "FDA-BTD-2024-AID-7391";
            attribute :>> serialNumber = "AID-CL-205847";
            attribute :>> manufacturingDate = "2024-03-15";
        }
        attribute :>> regulatoryStatus = RegulatoryClassification::breakthroughDesignated;
        attribute :>> currentMode = OperationalMode::continuousMonitoring;
        attribute :>> batteryLevel = 87.0;
        attribute :>> systemUptime = 168 [h];
        
        perform action closedLoopControl[*] ordered references AutomatedGlycemicControl;
    }
    
    satisfy breakthroughQualification by automatedInsulinDeliveryDevice;
    satisfy primarySystemFunction by automatedInsulinDeliveryDevice;
    satisfy patientSafetyProtection by automatedInsulinDeliveryDevice;
    satisfy dataSecurityAndLogging by automatedInsulinDeliveryDevice;
    satisfy systemReliability by automatedInsulinDeliveryDevice;
}
