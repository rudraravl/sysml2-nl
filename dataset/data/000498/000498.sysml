package ScoliometerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SpinalRotationAngle :> AngleValue;
    attribute def TrunkRotationAngle :> AngleValue;
    attribute def CalibrationOffset :> AngleValue;
    attribute def MeasurementTimestamp :> TimeValue;
    
    attribute def MeasurementRecord {
        attribute angle : TrunkRotationAngle;
        attribute timestamp : MeasurementTimestamp;
        attribute vertebralLevel : String;
        attribute patientPosition : String;
    }
    
    attribute def SeverityClassification {
        attribute isNormal : Boolean;
        attribute requiresMonitoring : Boolean;
        attribute requiresReferral : Boolean;
    }
    
    attribute def ATRAngle :> TrunkRotationAngle;
    attribute def DisplayBrightness :> Real;
    
    item def Patient {
        attribute patientID : String;
        attribute age : Real;
        attribute posture : String;
    }
    
    port def SensorOutputPort {
        out rawAngle : SpinalRotationAngle;
        out sensorStatus : Boolean;
    }
    
    port def ProcessorInputPort {
        in rawAngle : SpinalRotationAngle;
    }
    
    port def ProcessorOutputPort {
        out calibratedAngle : ATRAngle;
        out classification : SeverityClassification;
    }
    
    port def DisplayInputPort {
        in displayAngle : ATRAngle;
        in classification : SeverityClassification;
    }
    
    part def InclinometerSensor {
        doc /* Dual-axis inclinometer that measures trunk rotation relative to vertical plane. */
        
        port sensorOut : SensorOutputPort;
        
        attribute sensorRange : SpinalRotationAngle;
        attribute resolution : SpinalRotationAngle;
        attribute calibrationValue : CalibrationOffset;
        
        action acquireMeasurement {
            out measuredAngle : SpinalRotationAngle;
            out isValid : Boolean;
        }
    }
    
    part def SignalProcessor {
        doc /* Processes raw sensor data and applies calibration corrections. */
        
        port processorIn : ~ProcessorInputPort;
        port processorOut : ProcessorOutputPort;
        
        attribute filterCoefficient : Real;
        attribute calibrationMatrix : Real[*];
        
        action processSignal {
            in rawAngle : SpinalRotationAngle;
            out correctedAngle : ATRAngle;
            
            action applyCalibration {
                in inputAngle : SpinalRotationAngle;
                out calibratedValue : ATRAngle;
            }
            then action filterNoise {
                in noisySignal : ATRAngle;
                out cleanSignal : ATRAngle;
            }
        }
        
        action classifySeverity {
            in atrAngle : ATRAngle;
            out severity : SeverityClassification;
            
            decide;
                if atrAngle < 5.0 then markNormal;
                if atrAngle >= 5.0 and atrAngle < 7.0 then markMonitoring;
                if atrAngle >= 7.0 then markReferral;
                
            action markNormal;
            action markMonitoring;
            action markReferral;
        }
    }
    
    part def DigitalDisplay {
        doc /* LCD display showing angle measurement and severity indication. */
        
        port displayIn : ~DisplayInputPort;
        
        attribute brightness : DisplayBrightness;
        attribute displayMode : String;
        
        action renderMeasurement {
            in angle : ATRAngle;
            in severity : SeverityClassification;
        }
        
        action updateDisplay {
            in newAngle : ATRAngle;
        }
    }
    
    part def DataLogger {
        doc /* Stores measurement history for patient tracking and analysis. */
        
        attribute measurementHistory : MeasurementRecord[*];
        attribute storageCapacity : Integer;
        
        action recordMeasurement {
            in measurement : MeasurementRecord;
            out recordSuccess : Boolean;
        }
        
        action retrieveHistory {
            in patientID : String;
            out records : MeasurementRecord[*];
        }
    }
    
    part def PowerSupply {
        doc /* Battery power system for portable operation. */
        
        attribute batteryLevel : Real;
        attribute voltage : VoltageValue;
        
        action monitorPower {
            out remainingCharge : Real;
            out lowBatteryWarning : Boolean;
        }
    }
    
    part def Scoliometer {
        doc /* Medical screening device for detecting spinal asymmetry by measuring Angle of Trunk Rotation (ATR). */
        
        part sensor : InclinometerSensor;
        part processor : SignalProcessor;
        part display : DigitalDisplay;
        part logger : DataLogger;
        part power : PowerSupply;
        
        connection sensorToProcessor connect 
            sensor.sensorOut.rawAngle to processor.processorIn.rawAngle;
        
        connection processorToDisplay connect 
            processor.processorOut.calibratedAngle to display.displayIn.displayAngle;
        
        connection severityToDisplay connect
            processor.processorOut.classification to display.displayIn.classification;
        
        action screenForScoliosis {
            in patient : Patient;
            out atrMeasurement : ATRAngle;
            out severityAssessment : SeverityClassification;
            out measurementRecord : MeasurementRecord;
            
            first start;
            then action prepareDevice {
                doc /* Power on device and verify calibration status. */
            }
            then action positionPatient {
                doc /* Instruct patient to perform forward bend test. */
            }
            then action placeScoliometer {
                doc /* Position device on patient's back at specified vertebral level. */
            }
            then action captureMeasurement {
                out measuredAngle : SpinalRotationAngle;
                out isValid : Boolean;
            }
            then action processMeasurement {
                in rawAngle = captureMeasurement.measuredAngle;
                out correctedAngle : ATRAngle;
            }
            then action assessSeverity {
                in atrAngle = processMeasurement.correctedAngle;
                out severity : SeverityClassification;
            }
            then action showResult {
                in angle = processMeasurement.correctedAngle;
                in severity = assessSeverity.severity;
            }
            then action logResult {
                in measurement : MeasurementRecord;
                out recordSuccess : Boolean;
            }
            then done;
        }
    }
    
    state def ScoliometerOperationalStates {
        entry; then off;
        
        state off {
            doc /* Device is powered off. */
        }
        
        transition off_to_initializing
            first off
            accept powerOn
            then initializing;
        
        state initializing {
            doc /* Device is performing self-test and calibration verification. */
        }
        
        transition initializing_to_ready
            first initializing
            then ready;
        
        state ready {
            doc /* Device is calibrated and ready for measurement. */
        }
        
        transition ready_to_measuring
            first ready
            accept startMeasurement
            then measuring;
        
        state measuring {
            doc /* Device is actively acquiring trunk rotation angle. */
        }
        
        transition measuring_to_processing
            first measuring
            then processing;
        
        state processing {
            doc /* Device is processing and calibrating raw sensor data. */
        }
        
        transition processing_to_displaying
            first processing
            then displaying;
        
        state displaying {
            doc /* Device is showing measurement result to clinician. */
        }
        
        transition displaying_to_ready
            first displaying
            accept measurementAcknowledged
            then ready;
        
        state error {
            doc /* Device has detected a fault condition. */
        }
        
        transition error_to_off
            first error
            accept resetDevice
            then off;
    }
    
    part scoliometerDevice : Scoliometer {
        attribute deviceSerialNumber : String;
        attribute lastCalibrationDate : MeasurementTimestamp;
        attribute firmwareVersion : String;
        
        exhibit state deviceState : ScoliometerOperationalStates;
    }
    
    requirement def AccuracyRequirement {
        doc /* The scoliometer shall provide accurate angle measurements for clinical screening. */
        
        subject device : Scoliometer;
        
        require constraint measurementAccuracy {
            doc /* ATR measurement accuracy shall be within ±1 degree across full range. */
        }
        
        require constraint repeatability {
            doc /* Repeated measurements on same patient shall vary by no more than 0.5 degrees. */
        }
    }
    
    requirement def RangeRequirement {
        doc /* The scoliometer shall measure trunk rotation across clinically relevant range. */
        
        subject device : Scoliometer;
        
        require constraint angularRange {
            doc /* Device shall measure ATR from -30 to +30 degrees. */
        }
    }
    
    requirement def UsabilityRequirement {
        doc /* The scoliometer shall be easy to use in clinical screening environment. */
        
        subject device : Scoliometer;
        
        require constraint measurementSpeed {
            doc /* Complete measurement cycle shall take less than 15 seconds. */
        }
        
        require constraint displayClarity {
            doc /* Measurement results shall be clearly visible in typical clinical lighting. */
        }
        
        require constraint portability {
            doc /* Device shall operate on battery power for minimum 8 hours continuous use. */
        }
    }
    
    requirement def ClinicalRequirement {
        doc /* The scoliometer shall support evidence-based scoliosis screening protocols. */
        
        subject device : Scoliometer;
        
        require constraint screeningSensitivity {
            doc /* Device shall detect ATR ≥5 degrees with 90% sensitivity. */
        }
        
        require constraint dataRetention {
            doc /* Device shall store minimum 1000 patient measurements. */
        }
    }
    
    requirement <'SCOL-SYS-001'> primarySystemRequirement {
        doc /* The scoliometer system shall accurately measure Angle of Trunk Rotation during forward bend test to screen for spinal asymmetry indicative of scoliosis. */
        
        subject scoliometerDevice;
        
        require accuracy : AccuracyRequirement;
        require range : RangeRequirement;
        require usability : UsabilityRequirement;
        require clinical : ClinicalRequirement;
    }
}
