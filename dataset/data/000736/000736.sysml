package PlethysmographSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VolumeChangeRate :> ISQ::VolumeValue;
    attribute def BloodFlowRate :> ISQ::VolumeValue;
    attribute def PressureLevel :> ISQ::PressureValue;
    attribute def ResistanceLevel :> ISQ::ResistanceValue;
    attribute def CalibrationFactor :> Real;
    attribute def SignalQuality :> Real;
    attribute def WaveformAmplitude :> Real;
    
    item def PhysiologicalSignal {
        attribute amplitude : WaveformAmplitude;
        attribute frequency : ISQ::FrequencyValue;
        attribute quality : SignalQuality;
    }
    
    item def VolumeData {
        attribute baselineVolume : ISQ::VolumeValue;
        attribute currentVolume : ISQ::VolumeValue;
        attribute changeRate : VolumeChangeRate;
    }
    
    item def MeasurementResult {
        attribute volumeChange : ISQ::VolumeValue;
        attribute bloodFlow : BloodFlowRate;
        attribute timestamp : ISQ::TimeValue;
        attribute validity : Boolean;
    }
    
    attribute def MeasurementMode {
        attribute isImpedance : Boolean;
        attribute isPhotoelectric : Boolean;
        attribute isStrain : Boolean;
    }
    
    port def SensorPort {
        out volumeSignal : VolumeChangeRate;
        out pressureSignal : PressureLevel;
        out resistanceSignal : ResistanceLevel;
    }
    
    port def DataPort {
        in rawSignal : PhysiologicalSignal;
        out processedData : MeasurementResult;
        out qualityMetric : SignalQuality;
    }
    
    port def ControlPort {
        in calibrationCommand : CalibrationFactor;
        in measurementMode : MeasurementMode;
        out systemStatus : Boolean;
    }
    
    port def DisplayPort {
        in measurementData : MeasurementResult;
        in waveformData : PhysiologicalSignal;
    }
    
    part def TransducerAssembly {
        doc /* Converts physiological volume changes into measurable electrical signals */
        
        port sensorOutput : SensorPort;
        
        attribute sensitivity : Real;
        attribute operatingRange : ISQ::VolumeValue;
        
        part pressureSensor {
            attribute maxPressure : PressureLevel;
            out pressure : PressureLevel;
        }
        
        part strainGauge {
            attribute gaugeResistance : ResistanceLevel;
            out resistance : ResistanceLevel;
        }
        
        part volumeDetector {
            attribute detectionThreshold : VolumeChangeRate;
            out volumeChange : VolumeChangeRate;
        }
        
        action def AcquireSensorData {
            out pressureReading : PressureLevel;
            out resistanceReading : ResistanceLevel;
            out volumeReading : VolumeChangeRate;
        }
    }
    
    part def SignalProcessor {
        doc /* Processes raw sensor signals to extract meaningful physiological measurements */
        
        port dataInput : ~DataPort;
        port dataOutput : DataPort;
        
        attribute filterCutoff : ISQ::FrequencyValue;
        attribute amplificationGain : Real;
        attribute samplingRate : ISQ::FrequencyValue;
        
        action def ProcessSignal {
            in rawInput : PhysiologicalSignal;
            out filteredOutput : MeasurementResult;
            out quality : SignalQuality;
        }
        
        action def AmplifySignal {
            in signal : PhysiologicalSignal;
            out amplified : PhysiologicalSignal;
        }
        
        action def FilterSignal {
            in amplified : PhysiologicalSignal;
            out filtered : PhysiologicalSignal;
        }
        
        action def ExtractFeatures {
            in filtered : PhysiologicalSignal;
            out volumeChange : ISQ::VolumeValue;
            out bloodFlow : BloodFlowRate;
        }
        
        action def ValidateQuality {
            in volumeChange : ISQ::VolumeValue;
            out qualityScore : SignalQuality;
        }
        
        action def PackageResult {
            in volumeChange : ISQ::VolumeValue;
            in bloodFlow : BloodFlowRate;
            in qualityScore : SignalQuality;
            out result : MeasurementResult;
        }
    }
    
    part def ControlUnit {
        doc /* Manages system operation modes and calibration */
        
        port controlInterface : ~ControlPort;
        
        attribute currentMode : MeasurementMode;
        attribute calibrationState : CalibrationFactor;
        attribute systemReady : Boolean;
        
        state machine OperationalStates {
            initial state PowerOff;
            
            state Initializing {
                entry action performSelfTest;
            }
            
            state Calibrating {
                entry action runCalibration;
            }
            
            state Ready;
            
            state Measuring {
                entry action startMeasurement;
                do action continuousMeasure;
            }
            
            state Error {
                entry action logError;
            }
            
            transition powerOn from PowerOff to Initializing;
            transition selfTestPass from Initializing to Calibrating;
            transition selfTestFail from Initializing to Error;
            transition calibrationComplete from Calibrating to Ready;
            transition startMeasure from Ready to Measuring;
            transition stopMeasure from Measuring to Ready;
            transition errorDetected from Measuring to Error;
            transition reset from Error to Initializing;
            transition shutdown from Ready to PowerOff;
        }
        
        action def ManageOperation {
            out operationStatus : Boolean;
        }
        
        action def InitializeSystem {
            out initialized : Boolean;
        }
        
        action def CheckMode {
            out mode : MeasurementMode;
        }
        
        action def ConfigureImpedance {
            out configured : Boolean;
        }
        
        action def ConfigurePhotoelectric {
            out configured : Boolean;
        }
        
        action def ConfigureStrain {
            out configured : Boolean;
        }
    }
    
    part def DisplayInterface {
        doc /* Presents measurement data and waveforms to the user */
        
        port dataReceive : ~DisplayPort;
        
        attribute waveformData : PhysiologicalSignal[*];
        attribute numericReadings : MeasurementResult[*];
        attribute displayRefreshRate : ISQ::FrequencyValue;
        
        action def UpdateDisplay {
            in newData : MeasurementResult;
            in newWaveform : PhysiologicalSignal;
        }
        
        action def RenderWaveform {
            in waveform : PhysiologicalSignal;
        }
        
        action def UpdateNumeric {
            in data : MeasurementResult;
        }
        
        action def RefreshScreen;
    }
    
    part def Plethysmograph {
        doc /* 
            A plethysmograph is a medical instrument that measures and records changes 
            in volume within an organ or body segment. It detects variations in blood flow, 
            tissue expansion, or air displacement to assess physiological parameters such as 
            vascular compliance, respiratory function, and peripheral circulation.
        */
        
        port measurementOutput : DataPort;
        port systemControl : ControlPort;
        port displayOutput : DisplayPort;
        
        part transducer : TransducerAssembly {
            port :>> sensorOutput;
        }
        
        part processor : SignalProcessor {
            port :>> dataInput;
            port :>> dataOutput;
        }
        
        part controller : ControlUnit {
            port :>> controlInterface;
        }
        
        part display : DisplayInterface {
            port :>> dataReceive;
        }
        
        connect transducer.sensorOutput to processor.dataInput;
        connect processor.dataOutput to display.dataReceive;
        connect processor.dataOutput to measurementOutput;
        connect controller.controlInterface to systemControl;
        
        action def MeasureVolumeChanges {
            doc /* 
                Primary function: Continuously monitor and quantify volume variations 
                in biological tissues or body segments to assess physiological parameters 
                including blood flow dynamics, vascular compliance, respiratory patterns, 
                and peripheral circulation status through non-invasive detection methods.
            */
            
            out measurementComplete : Boolean;
        }
        
        action def CalibrateSystem {
            out baselineVolume : ISQ::VolumeValue;
            out calibrationComplete : Boolean;
        }
        
        action def AcquireSignal {
            out sensorData : VolumeChangeRate;
            out pressureData : PressureLevel;
            out resistanceData : ResistanceLevel;
        }
        
        action def ProcessData {
            in rawVolume : VolumeChangeRate;
            in rawPressure : PressureLevel;
            in rawResistance : ResistanceLevel;
            out volumeChange : ISQ::VolumeValue;
            out bloodFlow : BloodFlowRate;
            out signalQuality : Real;
        }
        
        action def RecordMeasurement {
            in volume : ISQ::VolumeValue;
            in flow : BloodFlowRate;
            out recorded : Boolean;
        }
        
        action def DisplayResults {
            in measurement : MeasurementResult;
        }
        
        action def AdjustSensitivity {
            out adjusted : Boolean;
        }
        
        action measurementSequence : MeasureVolumeChanges {
            first start;
            then action calibrate : CalibrateSystem;
            then merge continuousMeasurement;
            then action acquire : AcquireSignal;
            then action process : ProcessData;
            then decide;
                if process.signalQuality >= 0.8 then record;
                if process.signalQuality < 0.8 then adjust;
            action record : RecordMeasurement;
            then action displayRes : DisplayResults;
            then continuousMeasurement;
            action adjust : AdjustSensitivity;
            then continuousMeasurement;
        }
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* The plethysmograph shall measure volume changes with accuracy within 2% of actual values across the operating range. */
        
        subject plethysmograph : Plethysmograph;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall process and display volume changes within 100 milliseconds of detection to enable real-time monitoring. */
        
        subject plethysmograph : Plethysmograph;
    }
    
    requirement def CalibrationRequirement {
        doc /* The plethysmograph shall maintain calibration accuracy for at least 8 hours of continuous operation without recalibration. */
        
        subject plethysmograph : Plethysmograph;
    }
    
    requirement def SignalQualityRequirement {
        doc /* The system shall provide signal quality indicators and reject measurements below 80% quality threshold. */
        
        subject plethysmograph : Plethysmograph;
    }
    
    requirement def SafetyRequirement {
        doc /* The plethysmograph shall operate within safe electrical and pressure limits for patient contact applications. */
        
        subject plethysmograph : Plethysmograph;
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for plethysmograph system operation, performance, and safety. */
        
        require measurementAccuracy : MeasurementAccuracyRequirement;
        require responseTime : ResponseTimeRequirement;
        require calibration : CalibrationRequirement;
        require signalQuality : SignalQualityRequirement;
        require safety : SafetyRequirement;
    }
    
    part plethysmographInstance : Plethysmograph {
        satisfy systemRequirements;
    }
}
