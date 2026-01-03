package 'Magnetic Anomaly Detector System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def MagneticFluxDensity :> ISQ::MagneticFluxDensityValue {
        doc /* Magnetic field strength measured in Tesla */
    }
    
    attribute def AnomalyThreshold :> MagneticFluxDensity;
    
    attribute def GeographicPosition {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : ISQ::LengthValue;
    }
    
    attribute def AnomalyRecord {
        attribute detectedField : MagneticFluxDensity;
        attribute position : GeographicPosition;
        attribute timestamp : ISQ::TimeValue;
        attribute deviationMagnitude : MagneticFluxDensity;
    }
    
    attribute def SensorCommand;
    attribute def CalibrationCommand;
    attribute def SystemActivate;
    attribute def SystemDeactivate;
    
    port def MagneticFieldPort {
        out fieldMeasurement : MagneticFluxDensity;
    }
    
    port def ProcessedDataPort {
        in rawData : MagneticFluxDensity;
        out filteredData : MagneticFluxDensity;
    }
    
    port def AnomalyReportPort {
        out anomalyDetected : Boolean;
        out anomalyRecord : AnomalyRecord;
    }
    
    port def PositionPort {
        out currentPosition : GeographicPosition;
    }
    
    part def Magnetometer {
        doc /* High-sensitivity magnetometer for measuring Earth's magnetic field */
        attribute sensitivity : MagneticFluxDensity;
        attribute noiseLevel : MagneticFluxDensity;
        attribute samplingFrequency : ISQ::FrequencyValue;
        
        port fieldOutput : MagneticFieldPort;
        
        action measureMagneticField {
            in command : SensorCommand;
            out measurement : MagneticFluxDensity;
        }
    }
    
    part def SignalConditioner {
        doc /* Filters and amplifies magnetic field measurements */
        attribute filterBandwidth : ISQ::FrequencyValue;
        attribute gainFactor : Real;
        
        port dataInput : ProcessedDataPort;
        
        action filterSignal {
            in rawSignal : MagneticFluxDensity;
            out cleanSignal : MagneticFluxDensity;
        }
        
        action amplifySignal {
            in signal : MagneticFluxDensity;
            out amplifiedSignal : MagneticFluxDensity;
        }
    }
    
    part def AnomalyAnalyzer {
        doc /* Compares measurements against baseline to detect anomalies */
        attribute referenceField : MagneticFluxDensity;
        attribute threshold : AnomalyThreshold;
        attribute confidenceLevel : Real;
        
        action calculateDeviation {
            in measuredField : MagneticFluxDensity;
            in baseline : MagneticFluxDensity;
            out deviation : MagneticFluxDensity;
        }
        
        action assessAnomaly {
            in deviation : MagneticFluxDensity;
            in threshold : AnomalyThreshold;
            out isAnomaly : Boolean;
        }
    }
    
    part def PositionTracker {
        doc /* Provides geographic position for anomaly correlation */
        attribute updateRate : ISQ::FrequencyValue;
        
        port positionOutput : PositionPort;
        
        action getCurrentPosition {
            out position : GeographicPosition;
        }
    }
    
    part def DataRecorder {
        doc /* Logs detected anomalies with position and time data */
        attribute storageCapacity : Real;
        attribute recordCount : Integer;
        
        action storeAnomaly {
            in record : AnomalyRecord;
            out success : Boolean;
        }
    }
    
    action def MeasureField {
        in cmd : SensorCommand;
        out fieldStrength : MagneticFluxDensity;
    }
    
    action def ConditionSignal {
        in rawField : MagneticFluxDensity;
        out processedField : MagneticFluxDensity;
    }
    
    action def AnalyzeForAnomaly {
        in processedField : MagneticFluxDensity;
        in referenceField : MagneticFluxDensity;
        in threshold : AnomalyThreshold;
        out anomalyFlag : Boolean;
        out deviation : MagneticFluxDensity;
    }
    
    action def RecordDetection {
        in anomalyData : AnomalyRecord;
        out logged : Boolean;
    }
    
    action def EstablishBaseline {
        in calibrationCmd : CalibrationCommand;
        out baselineField : MagneticFluxDensity;
    }
    
    action def PerformMagneticAnomalyDetection {
        doc /* 
            Primary operational behavior: continuously monitors magnetic field,
            compares against baseline, and reports deviations exceeding threshold
        */
        in activate : SystemActivate;
        in deactivate : SystemDeactivate;
        in detectionThreshold : AnomalyThreshold;
        out detectedAnomalies : AnomalyRecord[*];
        
        private attribute baseline : MagneticFluxDensity;
        private attribute anomalyLog : AnomalyRecord[*] := ();
        
        first start;
        then accept activationSignal : SystemActivate;
        
        then action calibrate : EstablishBaseline {
            in calibrationCmd;
            out baselineField;
        }
        
        then assign baseline := calibrate.baselineField;
        then merge monitoringLoop;
        
        loop {
            action detectionCycle {
                action measure : MeasureField {
                    in cmd;
                    out fieldStrength;
                }
                
                flow measure.fieldStrength to condition.rawField;
                
                action condition : ConditionSignal {
                    in rawField;
                    out processedField;
                }
                
                flow condition.processedField to analyze.processedField;
                
                action analyze : AnalyzeForAnomaly {
                    in processedField;
                    in referenceField = baseline;
                    in threshold = detectionThreshold;
                    out anomalyFlag;
                    out deviation;
                }
                
                then decide;
                if analyze.anomalyFlag then recordAnomaly;
                if !analyze.anomalyFlag then monitoringLoop;
                
                action recordAnomaly {
                    action getPosition {
                        out currentPos : GeographicPosition;
                    }
                    
                    action createRecord {
                        in field : MagneticFluxDensity = analyze.processedField;
                        in pos : GeographicPosition = getPosition.currentPos;
                        in dev : MagneticFluxDensity = analyze.deviation;
                        out record : AnomalyRecord;
                    }
                    
                    action log : RecordDetection {
                        in anomalyData = createRecord.record;
                        out logged;
                    }
                    
                    then assign anomalyLog := anomalyLog->including(createRecord.record);
                }
                
                then monitoringLoop;
            }
            
            accept deactivationSignal : SystemDeactivate;
            then assign detectedAnomalies := anomalyLog;
            then done;
        }
    }
    
    part def MagneticAnomalyDetector {
        doc /* 
            A magnetic anomaly detector (MAD) system that continuously monitors
            variations in Earth's magnetic field to identify localized disturbances
            caused by ferromagnetic objects such as submarines, unexploded ordnance,
            or mineral deposits. The system measures ambient magnetic flux density,
            establishes a baseline reference, filters environmental noise, and reports
            deviations exceeding a configurable threshold with precise position data.
        */
        
        attribute operationalAltitude : ISQ::LengthValue;
        attribute detectionRadius : ISQ::LengthValue;
        attribute systemThreshold : AnomalyThreshold;
        
        part magnetometer : Magnetometer {
            attribute :>> sensitivity = 0.001[SI::T];
            attribute :>> noiseLevel = 0.0001[SI::T];
            attribute :>> samplingFrequency = 100.0[SI::Hz];
        }
        
        part conditioner : SignalConditioner {
            attribute :>> filterBandwidth = 50.0[SI::Hz];
            attribute :>> gainFactor = 10.0;
        }
        
        part analyzer : AnomalyAnalyzer {
            attribute :>> referenceField = 50.0e-6[SI::T];
            attribute :>> threshold = 0.5e-9[SI::T];
            attribute :>> confidenceLevel = 0.85;
        }
        
        part tracker : PositionTracker {
            attribute :>> updateRate = 10.0[SI::Hz];
        }
        
        part recorder : DataRecorder {
            attribute :>> storageCapacity = 10000000.0;
            attribute :>> recordCount = 0;
        }
        
        connection magnetometerToConditioner connect 
            magnetometer.fieldOutput to conditioner.dataInput;
        
        perform action operation : PerformMagneticAnomalyDetection {
            in activate;
            in deactivate;
            in detectionThreshold = systemThreshold;
            out detectedAnomalies;
        }
    }
    
    requirement <'MAD-REQ-001'> primaryFunctionRequirement {
        doc /* 
            The magnetic anomaly detector system shall detect and report
            localized variations in Earth's magnetic field caused by
            ferromagnetic objects or geological formations.
        */
        
        subject madSystem : MagneticAnomalyDetector;
    }
    
    requirement <'MAD-REQ-002'> continuousSensingRequirement {
        doc /* 
            The system shall continuously measure magnetic field strength
            at a minimum rate of 100 Hz to ensure detection of transient anomalies.
        */
        
        subject madSystem : MagneticAnomalyDetector;
        
        require constraint {
            madSystem.magnetometer.samplingFrequency >= 100.0[SI::Hz]
        }
    }
    
    requirement <'MAD-REQ-003'> sensitivityRequirement {
        doc /* 
            The system shall detect magnetic field deviations as small as
            0.5 nanoTesla from the established baseline.
        */
        
        subject madSystem : MagneticAnomalyDetector;
        
        require constraint {
            madSystem.analyzer.threshold <= 1.0e-9[SI::T]
        }
    }
    
    requirement <'MAD-REQ-004'> dataLoggingRequirement {
        doc /* 
            All detected anomalies shall be logged with timestamp, geographic
            position, field strength, and deviation magnitude.
        */
        
        subject madSystem : MagneticAnomalyDetector;
    }
    
    requirement <'MAD-REQ-005'> operationalRequirement {
        doc /* 
            The system shall operate continuously from activation until
            deactivation, maintaining baseline calibration and reporting
            all anomalies exceeding the configured threshold.
        */
        
        subject madSystem : MagneticAnomalyDetector;
        
        assume constraint {
            madSystem.systemThreshold > 0.0[SI::T]
        }
        
        require continuousSensingRequirement;
        require sensitivityRequirement;
        require dataLoggingRequirement;
    }
    
    part madSystem : MagneticAnomalyDetector {
        attribute :>> operationalAltitude = 100.0[SI::m];
        attribute :>> detectionRadius = 500.0[SI::m];
        attribute :>> systemThreshold = 0.5e-9[SI::T];
        
        satisfy primaryFunctionRequirement;
        satisfy operationalRequirement;
    }
}
