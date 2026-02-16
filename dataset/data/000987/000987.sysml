package BhangmeterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def IntensityLevel specializes LuminousIntensityValue;
    attribute def TimestampValue specializes TimeValue;
    
    attribute def LocationCoordinates {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }
    
    attribute def NuclearEventSignature {
        attribute firstPeakIntensity : IntensityLevel;
        attribute secondPeakIntensity : IntensityLevel;
        attribute timeBetweenPeaks : DurationValue;
        attribute eventLocation : LocationCoordinates;
        attribute detectionTimestamp : TimestampValue;
        attribute estimatedYield : EnergyValue;
    }
    
    attribute def OpticalBandwidth {
        attribute lowerWavelength : LengthValue;
        attribute upperWavelength : LengthValue;
    }
    
    item def OpticalSensor {
        attribute bandwidth : OpticalBandwidth;
        attribute sensitivity : Real;
        attribute samplingRate : FrequencyValue;
    }
    
    item def SignalProcessor {
        attribute processingSpeed : FrequencyValue;
        attribute bufferSize : Real;
    }
    
    item def DataStorage {
        attribute capacity : Real;
        attribute writeSpeed : Real;
    }
    
    item def CommunicationModule {
        attribute transmissionRate : Real;
        attribute encryptionEnabled : Boolean;
    }
    
    port def OpticalInputPort {
        in item lightIntensity : IntensityLevel;
    }
    
    port def DataOutputPort {
        out item eventData : NuclearEventSignature;
    }
    
    port def PowerInputPort {
        in item powerSupply : PowerValue;
    }
    
    action def CaptureOpticalSignal {
        in lightInput : IntensityLevel;
        out rawSignal : IntensityLevel;
        out captureTime : TimestampValue;
    }
    
    action def AnalyzeDoubleFlash {
        in signalStream : IntensityLevel[*];
        in timestamps : TimestampValue[*];
        out firstPeak : IntensityLevel;
        out secondPeak : IntensityLevel;
        out peakSeparation : DurationValue;
        out isNuclearEvent : Boolean;
    }
    
    action def DetermineEventLocation {
        in detectionTime : TimestampValue;
        in sensorPosition : LocationCoordinates;
        out eventLocation : LocationCoordinates;
    }
    
    action def EstimateYield {
        in firstPeak : IntensityLevel;
        in secondPeak : IntensityLevel;
        in peakSeparation : DurationValue;
        out estimatedYield : EnergyValue;
    }
    
    action def TransmitEventData {
        in eventSignature : NuclearEventSignature;
        out transmissionStatus : Boolean;
    }
    
    action def MonitorAtmosphere {
        out continuousSignal : IntensityLevel;
        out signalTimestamp : TimestampValue;
    }
    
    action def BufferSignals {
        in signal : IntensityLevel;
        in timestamp : TimestampValue;
        out signalBuffer : IntensityLevel[*];
        out timestampBuffer : TimestampValue[*];
    }
    
    action def GenerateEventSignature {
        in firstPeak : IntensityLevel;
        in secondPeak : IntensityLevel;
        in timeBetween : DurationValue;
        in location : LocationCoordinates;
        in timestamp : TimestampValue;
        in yield : EnergyValue;
        out signature : NuclearEventSignature;
    }
    
    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def FlashDetectedSignal;
    
    state def BhangmeterOperationalStates {
        entry; then idle;
        
        state idle {
            entry assign systemStatus := "Standby";
        }
        
        transition idle_to_monitoring
            first idle
            accept powerOnEvent : PowerOnSignal
            then monitoring;
        
        state monitoring {
            entry assign systemStatus := "Active Monitoring";
            do action continuousMonitor : MonitorAtmosphere;
        }
        
        transition monitoring_to_analyzing
            first monitoring
            accept flashEvent : FlashDetectedSignal
            then analyzing;
        
        state analyzing {
            entry assign systemStatus := "Analyzing Event";
            do action performAnalysis : AnalyzeDoubleFlash;
        }
        
        transition analyzing_to_transmitting
            first analyzing
            if analyzing.performAnalysis.isNuclearEvent
            then transmitting;
        
        transition analyzing_to_monitoring
            first analyzing
            if not analyzing.performAnalysis.isNuclearEvent
            then monitoring;
        
        state transmitting {
            entry assign systemStatus := "Transmitting Data";
            do action sendData : TransmitEventData;
        }
        
        transition transmitting_to_monitoring
            first transmitting
            then monitoring;
        
        transition monitoring_to_idle
            first monitoring
            accept powerOffEvent : PowerOffSignal
            then idle;
        
        attribute systemStatus : String;
    }
    
    action def DetectNuclearDetonation {
        in powerInput : PowerValue;
        out detectedEvent : NuclearEventSignature;
        out alertStatus : Boolean;
        
        first start;
        then merge continuousOperation;
        
        action monitor : MonitorAtmosphere {
            out continuousSignal;
            out signalTimestamp;
        }
        
        then action capture : CaptureOpticalSignal {
            in lightInput = monitor.continuousSignal;
            out rawSignal;
            out captureTime;
        }
        
        then action buffer : BufferSignals {
            in signal = capture.rawSignal;
            in timestamp = capture.captureTime;
            out signalBuffer : IntensityLevel[*];
            out timestampBuffer : TimestampValue[*];
        }
        
        then action analyze : AnalyzeDoubleFlash {
            in signalStream = buffer.signalBuffer;
            in timestamps = buffer.timestampBuffer;
            out firstPeak;
            out secondPeak;
            out peakSeparation;
            out isNuclearEvent;
        }
        
        then decide;
            if analyze.isNuclearEvent then processEvent;
            if not analyze.isNuclearEvent then continuousOperation;
        
        action processEvent {
            action locate : DetermineEventLocation {
                in detectionTime = capture.captureTime;
                in sensorPosition;
                out eventLocation;
            }
            
            then action calculateYield : EstimateYield {
                in firstPeak = analyze.firstPeak;
                in secondPeak = analyze.secondPeak;
                in peakSeparation = analyze.peakSeparation;
                out estimatedYield;
            }
            
            then action createSignature : GenerateEventSignature {
                in firstPeak = analyze.firstPeak;
                in secondPeak = analyze.secondPeak;
                in timeBetween = analyze.peakSeparation;
                in location = locate.eventLocation;
                in timestamp = capture.captureTime;
                in yield = calculateYield.estimatedYield;
                out signature : NuclearEventSignature;
            }
            
            then action transmit : TransmitEventData {
                in eventSignature = createSignature.signature;
                out transmissionStatus;
            }
            
            then assign detectedEvent := createSignature.signature;
            then assign alertStatus := true;
        }
        
        then continuousOperation;
        then done;
    }
    
    part def Bhangmeter {
        attribute operatingAltitude : LengthValue;
        attribute fieldOfView : Real;
        attribute detectionRange : LengthValue;
        
        port opticalInput : OpticalInputPort;
        port dataOutput : DataOutputPort;
        port powerInput : PowerInputPort;
        
        part sensor : OpticalSensor {
            attribute bandwidth : OpticalBandwidth {
                attribute lowerWavelength = 400.0 [nm];
                attribute upperWavelength = 700.0 [nm];
            }
            attribute sensitivity = 0.95;
            attribute samplingRate = 1000.0 [Hz];
        }
        
        part processor : SignalProcessor {
            attribute processingSpeed = 2.0e9 [Hz];
            attribute bufferSize = 1024.0;
        }
        
        part storage : DataStorage {
            attribute capacity = 1.0e9;
            attribute writeSpeed = 1.0e6;
        }
        
        part communicator : CommunicationModule {
            attribute transmissionRate = 1.0e6;
            attribute encryptionEnabled = true;
        }
        
        perform action detectDetonation : DetectNuclearDetonation {
            in powerInput;
            out detectedEvent;
            out alertStatus;
        }
    }
    
    part bhangmeterSystem : Bhangmeter {
        attribute operatingAltitude = 35786.0 [km];
        attribute fieldOfView = 120.0;
        attribute detectionRange = 50000.0 [km];
        
        attribute currentPosition : LocationCoordinates {
            attribute latitude = 0.0;
            attribute longitude = 75.0;
            attribute altitude = operatingAltitude;
        }
    }
    
    requirement def <'REQ-001'> NuclearDetonationDetectionRequirement {
        doc /* The Bhangmeter system shall detect and characterize nuclear detonations 
             in the atmosphere by identifying the distinctive double-flash optical signature. */
        
        require constraint doubleFlashDetection {
            doc /* The system shall detect both the first and second optical peaks 
                 characteristic of nuclear detonations. */
        }
        
        require constraint timingAccuracy {
            doc /* The system shall measure the time separation between peaks 
                 with accuracy sufficient to distinguish nuclear events. */
        }
        
        require constraint continuousMonitoring {
            doc /* The system shall continuously monitor the atmosphere 
                 for optical anomalies. */
        }
    }
    
    requirement def <'REQ-002'> DataTransmissionRequirement {
        doc /* The Bhangmeter system shall transmit detected nuclear event data 
             to ground stations in real-time. */
        
        require constraint transmissionReliability {
            doc /* Event data transmission shall have 99.9% reliability. */
        }
        
        require constraint dataEncryption {
            doc /* All transmitted data shall be encrypted for security. */
        }
    }
    
    requirement def <'REQ-003'> OpticalSensitivityRequirement {
        doc /* The optical sensor shall have sufficient sensitivity to detect 
             nuclear detonations at specified ranges. */
        
        require constraint spectralRange {
            doc /* The sensor shall operate in the visible spectrum 
                 from 400nm to 700nm. */
        }
        
        require constraint samplingFrequency {
            doc /* The sensor shall sample at minimum 1000 Hz to capture 
                 rapid intensity changes. */
        }
    }
    
    requirement missionRequirement {
        doc /* The Bhangmeter system provides space-based detection and monitoring 
             of nuclear detonations by observing the characteristic double-flash 
             optical signature produced by atmospheric nuclear explosions. */
        
        assume constraint operationalEnvironment {
            doc /* The system operates in geostationary orbit at approximately 
                 35,786 km altitude with continuous Earth observation capability. */
        }
        
        require NuclearDetonationDetectionRequirement;
        require DataTransmissionRequirement;
        require OpticalSensitivityRequirement;
    }
}
