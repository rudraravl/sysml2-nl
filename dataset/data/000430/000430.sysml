package CancerDiagnosticProbeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def ConcentrationValue :> Real;
    attribute def SignalStrengthValue :> Real;
    
    enum def TissueClassification {
        benign;
        suspicious;
        malignant;
    }
    
    enum def ProbeStatus {
        idle;
        calibrating;
        scanning;
        analyzing;
        complete;
        fault;
    }
    
    item def TissueSample {
        attribute biomarkerConcentration : ConcentrationValue;
        attribute cellularDensity : Real;
        attribute temperature : TemperatureValue;
    }
    
    item def DiagnosticData {
        attribute classification : TissueClassification;
        attribute confidenceLevel : Real;
        attribute detectedBiomarkers : ConcentrationValue;
        attribute scanTimestamp : Time::DateTime;
    }
    
    item def CalibrationCommand;
    item def ScanCommand;
    item def ResetCommand;
    item def PowerDownCommand;
    item def ClearFaultCommand;
    
    port def SensorDataPort {
        out signalStrength : SignalStrengthValue;
        out temperature : TemperatureValue;
    }
    
    port def AnalysisPort {
        in rawData : SignalStrengthValue;
        out diagnosticResult : DiagnosticData;
    }
    
    port def PowerPort {
        in voltage : ElectricPotentialValue;
        in current : ElectricCurrentValue;
    }
    
    port def CommunicationPort {
        out diagnosticData : DiagnosticData;
        in controlCommand : String;
    }
    
    part def OpticalBiosensor {
        port sensorOutput : SensorDataPort;
        
        attribute wavelength : LengthValue = 630[nm];
        attribute sensitivity : Real = 0.98;
        attribute detectionRangeMin : ConcentrationValue = 0.1;
        attribute detectionRangeMax : ConcentrationValue = 1000.0;
        
        perform action detectBiomarkers {
            in sample : TissueSample;
            out signal : SignalStrengthValue;
        }
    }
    
    part def ThermalSensor {
        port thermalOutput : SensorDataPort;
        
        attribute accuracy : TemperatureValue = 0.1[K];
        attribute responseTime : TimeValue = 0.5[s];
        
        perform action measureTemperature {
            in sample : TissueSample;
            out temp : TemperatureValue;
        }
    }
    
    part def SignalProcessingUnit {
        port dataIn : AnalysisPort;
        port dataOut : AnalysisPort;
        port power : PowerPort;
        
        attribute processingRate : Real = 2000.0;
        attribute filterBandwidth : Real = 100.0;
        
        perform action processSignal {
            in rawSignal : SignalStrengthValue;
            in temperature : TemperatureValue;
            out filteredData : SignalStrengthValue;
        }
    }
    
    part def DiagnosticAlgorithm {
        attribute thresholdBenign : Real = 0.3;
        attribute thresholdMalignant : Real = 0.7;
        attribute minimumConfidence : Real = 0.85;
        
        perform action classifyTissue {
            in biomarkerLevel : ConcentrationValue;
            in signalData : SignalStrengthValue;
            out classification : TissueClassification;
            out confidence : Real;
        }
    }
    
    part def BatteryPack {
        port powerOut : PowerPort;
        
        attribute capacity : ElectricChargeValue = 5000[mA*h];
        attribute voltage : ElectricPotentialValue = 7.4[V];
        attribute remainingCharge : Real;
    }
    
    part def WirelessTransceiver {
        port commPort : CommunicationPort;
        port power : PowerPort;
        
        attribute transmissionRange : LengthValue = 10[m];
        attribute dataRate : Real = 2.0;
        attribute protocol : String = "Bluetooth 5.0";
    }
    
    part def ProbeTip {
        part opticalSensor : OpticalBiosensor;
        part thermalSensor : ThermalSensor;
        
        attribute tipDiameter : LengthValue = 3.0[mm];
        attribute insertionDepth : LengthValue = 20[mm];
        attribute biocompatible : Boolean = true;
    }
    
    part def CancerDiagnosticProbe {
        attribute deviceID : String;
        attribute calibrationDate : Time::DateTime;
        attribute totalMass : MassValue = 150[g];
        attribute calibrationSuccessful : Boolean;
        attribute calibrationFailed : Boolean;
        attribute dataAcquisitionComplete : Boolean;
        attribute analysisComplete : Boolean;
        attribute confidenceSufficient : Boolean;
        attribute confidenceInsufficient : Boolean;
        
        part probeTip : ProbeTip;
        part processor : SignalProcessingUnit;
        part algorithm : DiagnosticAlgorithm;
        part battery : BatteryPack;
        part transceiver : WirelessTransceiver;
        
        connection opticalDataFlow connect 
            probeTip.opticalSensor.sensorOutput to processor.dataIn;
        
        connection thermalDataFlow connect 
            probeTip.thermalSensor.thermalOutput to processor.dataIn;
        
        connection processedDataFlow connect 
            processor.dataOut to algorithm;
        
        connection powerToProcessor connect 
            battery.powerOut to processor.power;
        
        connection powerToTransceiver connect 
            battery.powerOut to transceiver.power;
        
        perform action performDiagnosis {
            first start;
            
            then action initialize {
                doc /* Initialize probe systems and perform self-test */
            }
            
            then action calibrate {
                doc /* Calibrate sensors against known reference */
            }
            
            then action positionProbe {
                doc /* Position probe tip at target tissue location */
            }
            
            then action acquireSensorData {
                doc /* Collect optical and thermal data from tissue */
                out opticalSignal : SignalStrengthValue;
                out thermalReading : TemperatureValue;
            }
            
            then action processData {
                doc /* Filter and process raw sensor signals */
                in opticalInput = acquireSensorData.opticalSignal;
                in thermalInput = acquireSensorData.thermalReading;
                out processedSignal : SignalStrengthValue;
            }
            
            then action analyzeAndClassify {
                doc /* Apply diagnostic algorithm to classify tissue */
                in signalInput = processData.processedSignal;
                out result : DiagnosticData;
            }
            
            then decide;
                if analyzeAndClassify.result.confidenceLevel >= 0.85 then transmitResult;
                if analyzeAndClassify.result.confidenceLevel < 0.85 then repeatScan;
            
            action repeatScan {
                doc /* Repeat measurement if confidence is insufficient */
            }
            then acquireSensorData;
            
            action transmitResult {
                doc /* Transmit diagnostic result to external system */
                in finalResult = analyzeAndClassify.result;
            }
            
            then done;
        }
        
        state probeOperationalStateMachine {
            entry; then idle;
            
            state idle {
                doc /* Probe is powered on but inactive */
            }
            
            state calibrating {
                doc /* Probe is performing sensor calibration */
                entry; do probeTip.opticalSensor.detectBiomarkers;
                do probeTip.thermalSensor.measureTemperature;
            }
            
            state ready {
                doc /* Probe is calibrated and ready for scanning */
            }
            
            state scanning {
                doc /* Probe is actively acquiring tissue data */
                entry; do probeTip.opticalSensor.detectBiomarkers;
                do probeTip.thermalSensor.measureTemperature;
            }
            
            state analyzing {
                doc /* Processing and analyzing collected data */
                entry; do processor.processSignal;
                do algorithm.classifyTissue;
            }
            
            state complete {
                doc /* Diagnosis complete, result transmitted */
            }
            
            state fault {
                doc /* Probe has encountered an error condition */
            }
            
            transition idle_to_calibrating
                first idle
                accept CalibrationCommand
                then calibrating;
            
            transition calibrating_to_ready
                first calibrating
                if calibrationSuccessful
                then ready;
            
            transition calibrating_to_fault
                first calibrating
                if calibrationFailed
                then fault;
            
            transition ready_to_scanning
                first ready
                accept ScanCommand
                then scanning;
            
            transition scanning_to_analyzing
                first scanning
                if dataAcquisitionComplete
                then analyzing;
            
            transition analyzing_to_complete
                first analyzing
                if analysisComplete
                if confidenceSufficient
                then complete;
            
            transition analyzing_to_scanning
                first analyzing
                if analysisComplete
                if confidenceInsufficient
                then scanning;
            
            transition complete_to_ready
                first complete
                accept ResetCommand
                then ready;
            
            transition complete_to_idle
                first complete
                accept PowerDownCommand
                then idle;
            
            transition fault_to_idle
                first fault
                accept ClearFaultCommand
                then idle;
        }
    }
    
    requirement <'REQ-CDP-1000'> primaryDiagnosticCapability {
        doc /* The Cancer Diagnostic Probe shall detect and classify tissue 
             * as benign, suspicious, or malignant through real-time biomarker 
             * analysis and optical signal processing to enable early cancer detection. */
        subject probe : CancerDiagnosticProbe;
        
        require <'REQ-CDP-1100'> biomarkerSensitivity {
            doc /* The probe shall detect cancer biomarkers with minimum 
                 * sensitivity of 0.98 across the specified concentration range */
            subject sensor :>> probe.probeTip.opticalSensor;
            assert constraint {
                sensor.sensitivity >= 0.98
            }
        }
        
        require <'REQ-CDP-1200'> classificationConfidence {
            doc /* The tissue classification shall achieve minimum confidence 
                 * level of 85% before reporting results */
            subject algo :>> probe.algorithm;
            assert constraint {
                algo.minimumConfidence >= 0.85
            }
        }
        
        require <'REQ-CDP-1300'> thermalAccuracy {
            doc /* The probe shall monitor tissue temperature with accuracy 
                 * of 0.1 Kelvin to detect metabolic anomalies */
            subject thermal :>> probe.probeTip.thermalSensor;
            assert constraint {
                thermal.accuracy <= 0.1[K]
            }
        }
        
        require <'REQ-CDP-1400'> batteryCapacity {
            doc /* The probe shall operate on battery power with minimum 
                 * capacity of 5000 mAh for extended diagnostic sessions */
            subject power :>> probe.battery;
            assert constraint {
                power.capacity >= 5000[mA*h]
            }
        }
        
        require <'REQ-CDP-1500'> massLimit {
            doc /* The probe total mass shall not exceed 200 grams for 
                 * ease of handling and patient comfort */
            subject device :>> probe;
            assert constraint {
                device.totalMass <= 200[g]
            }
        }
    }
    
    requirement <'REQ-CDP-2000'> operationalWorkflow {
        doc /* The probe shall execute a complete diagnostic workflow including 
             * initialization, calibration, data acquisition, analysis, and 
             * result transmission in a controlled sequence */
        subject probe :>> CancerDiagnosticProbe;
        
        require <'REQ-CDP-2100'> diagnosticSequence {
            doc /* The probe shall perform diagnostic steps in proper order */
            assert constraint {
                probe.performDiagnosis != null
            }
        }
        
        require <'REQ-CDP-2200'> stateManagement {
            doc /* The probe shall maintain proper operational states */
            assert constraint {
                probe.probeOperationalStateMachine != null
            }
        }
    }
    
    part diagnosticProbeInstance : CancerDiagnosticProbe {
        :>> deviceID = "CDP-2025-001";
        :>> totalMass = 145[g];
        
        part :>> probeTip {
            part :>> opticalSensor {
                :>> wavelength = 635[nm];
                :>> sensitivity = 0.99;
            }
            part :>> thermalSensor {
                :>> accuracy = 0.08[K];
                :>> responseTime = 0.4[s];
            }
            :>> tipDiameter = 2.8[mm];
            :>> insertionDepth = 18[mm];
        }
        
        part :>> processor {
            :>> processingRate = 2500.0;
            :>> filterBandwidth = 120.0;
        }
        
        part :>> algorithm {
            :>> thresholdBenign = 0.28;
            :>> thresholdMalignant = 0.72;
            :>> minimumConfidence = 0.87;
        }
        
        part :>> battery {
            :>> capacity = 5500[mA*h];
            :>> voltage = 7.4[V];
            :>> remainingCharge = 1.0;
        }
        
        part :>> transceiver {
            :>> transmissionRange = 12[m];
            :>> dataRate = 2.4;
        }
    }
    
    satisfy primaryDiagnosticCapability by diagnosticProbeInstance;
    satisfy operationalWorkflow by diagnosticProbeInstance;
}
