package MedicalUltrasoundImagingSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    
    attribute def UltrasoundFrequency :> FrequencyValue {
        doc /* Medical ultrasound operates between 2-18 MHz for diagnostic imaging */
    }
    
    attribute def AcousticIntensity :> PowerValue;
    attribute def ImageDepth :> LengthValue;
    attribute def ScanLineCount :> Integer;
    attribute def FrameRateValue :> Real;
    
    item def UltrasoundPulse {
        attribute frequency : UltrasoundFrequency;
        attribute duration : DurationValue;
        attribute intensity : AcousticIntensity;
    }
    
    item def EchoData {
        attribute amplitude : Real;
        attribute timeOfFlight : DurationValue;
        attribute phaseShift : Real;
    }
    
    item def RFSignal {
        attribute carrierFrequency : UltrasoundFrequency;
        attribute envelopeData : Real;
        attribute timestamp : DurationValue;
    }
    
    item def ImageFrame {
        attribute pixelData : Real;
        attribute depth : ImageDepth;
        attribute width : LengthValue;
        attribute frameNumber : Integer;
    }
    
    item def ScanParameters {
        attribute mode : ScanMode;
        attribute frequency : UltrasoundFrequency;
        attribute focusDepth : ImageDepth;
        attribute gain : Real;
        attribute dynamicRange : Real;
    }
    
    enumeration ScanMode {
        BMode;
        MMode;
        DopplerMode;
        CompoundMode;
    }
    
    port def AcousticPort {
        out transmitPulse : UltrasoundPulse;
        in receivedEcho : EchoData;
    }
    
    port def SignalPort {
        out rfOutput : RFSignal;
        in rfInput : RFSignal;
    }
    
    port def ImagePort {
        out imageData : ImageFrame;
    }
    
    port def ControlPort {
        in scanParams : ScanParameters;
    }
    
    part def TransducerProbe {
        doc /* Piezoelectric array that converts electrical signals to acoustic waves and vice versa */
        
        attribute elementCount : Integer;
        attribute centerFrequency : UltrasoundFrequency;
        attribute bandwidth : FrequencyValue;
        attribute aperture : LengthValue;
        
        port acousticInterface : AcousticPort;
        port electricalInterface : SignalPort;
        
        action def TransmitAcousticPulse {
            in electricalExcitation : RFSignal;
            out acousticWave : UltrasoundPulse;
        }
        
        action def ReceiveEcho {
            in reflectedWave : EchoData;
            out electricalResponse : RFSignal;
        }
    }
    
    part def TransmitBeamformer {
        doc /* Controls phasing and timing of transducer elements for transmit beam focusing and steering */
        
        attribute focalDepth : ImageDepth;
        attribute steeringAngle : Real;
        attribute apodizationValue : Real;
        
        action def CalculateDelays {
            in targetDepth : ImageDepth;
            in angle : Real;
            out elementDelay : DurationValue;
        }
        
        action def GenerateExcitation {
            in delays : DurationValue;
            in baseFrequency : UltrasoundFrequency;
            out excitationSignal : RFSignal;
        }
    }
    
    part def ReceiveBeamformer {
        doc /* Combines echo signals from array elements with dynamic focusing */
        
        attribute dynamicFocusing : Boolean;
        attribute receiveAperture : Integer;
        
        action def ApplyReceiveDelays {
            in echoSignal : RFSignal;
            in focusDepth : ImageDepth;
            out delayedSignal : RFSignal;
        }
        
        action def SumChannels {
            in alignedSignal : RFSignal;
            out beamformedSignal : RFSignal;
        }
    }
    
    part def SignalProcessingUnit {
        doc /* Processes RF echo data through filtering, demodulation, and compression */
        
        attribute filterBandwidth : FrequencyValue;
        attribute compressionRatio : Real;
        
        action def BandpassFilter {
            in rawSignal : RFSignal;
            in centerFreq : UltrasoundFrequency;
            out filteredSignal : RFSignal;
        }
        
        action def EnvelopeDetection {
            in rfSignal : RFSignal;
            out envelopeSignal : Real;
        }
        
        action def LogCompression {
            in linearData : Real;
            in dynamicRange : Real;
            out compressedData : Real;
        }
        
        action def TimeGainCompensation {
            in signal : Real;
            in depth : ImageDepth;
            out compensatedSignal : Real;
        }
    }
    
    part def ScanConverter {
        doc /* Transforms polar scan data to Cartesian coordinate system for display */
        
        attribute outputResolutionX : Integer;
        attribute outputResolutionY : Integer;
        attribute interpolationMethod : String;
        
        action def CoordinateTransform {
            in scanLineData : Real;
            in geometry : ScanParameters;
            out cartesianImage : Real;
        }
        
        action def Interpolate {
            in sparseData : Real;
            out denseImage : Real;
        }
    }
    
    part def ImageProcessor {
        doc /* Applies post-processing including edge enhancement and speckle reduction */
        
        attribute edgeEnhancement : Boolean;
        attribute speckleReduction : Boolean;
        
        action def ApplyFilters {
            in rawImage : ImageFrame;
            out enhancedImage : ImageFrame;
        }
        
        action def AdjustContrast {
            in image : ImageFrame;
            in contrastLevel : Real;
            out adjustedImage : ImageFrame;
        }
    }
    
    part def DisplayMonitor {
        doc /* Renders processed ultrasound images for clinical interpretation */
        
        attribute screenSizeX : LengthValue;
        attribute screenSizeY : LengthValue;
        attribute resolutionX : Integer;
        attribute resolutionY : Integer;
        attribute brightness : Real;
        attribute contrast : Real;
        
        port imageInput : ImagePort;
        
        action def RenderFrame {
            in imageData : ImageFrame;
            out displayBuffer : Real;
        }
        
        action def OverlayAnnotations {
            in baseImage : Real;
            in measurement : Real;
            out annotatedImage : Real;
        }
    }
    
    part def ControlConsole {
        doc /* User interface for configuring scan parameters and system settings */
        
        port controlOutput : ControlPort;
        
        action def SetScanMode {
            in userSelection : String;
            out mode : ScanMode;
        }
        
        action def AdjustFrequency {
            in desiredFrequency : Real;
            out frequency : UltrasoundFrequency;
        }
        
        action def ConfigureFocus {
            in depth : Real;
            out focusDepth : ImageDepth;
        }
    }
    
    action def AcquireScanLine {
        in scanParams : ScanParameters;
        in lineIndex : Integer;
        out lineData : Real;
    }
    
    action def BuildImageFrame {
        in scanLineData : Real;
        in params : ScanParameters;
        out frame : ImageFrame;
    }
    
    part def UltrasoundImagingSystem {
        attribute operatingFrequency : UltrasoundFrequency;
        attribute maximumDepth : ImageDepth;
        attribute frameRate : FrameRateValue;
        attribute scanLineCount : ScanLineCount;
    }
    
    part ultrasoundImager : UltrasoundImagingSystem {
        doc /* 
            Complete medical ultrasound imaging system for diagnostic visualization.
            Primary function: Generate real-time cross-sectional images of internal anatomy
            by transmitting focused ultrasound pulses into tissue, receiving reflected echoes
            from acoustic impedance boundaries, and processing echo patterns to create
            diagnostic quality images for clinical assessment of organs, vessels, and soft tissues.
        */
        
        attribute operatingFrequency : UltrasoundFrequency;
        attribute maximumDepth : ImageDepth;
        attribute frameRate : FrameRateValue;
        attribute scanLineCount : ScanLineCount;
        
        part probe : TransducerProbe {
            attribute elementCount = 128;
            attribute centerFrequency = 5.0;
            attribute bandwidth = 3.0;
            attribute aperture = 38.0;
        }
        
        part txBeamformer : TransmitBeamformer {
            attribute focalDepth = 60.0;
            attribute steeringAngle = 0.0;
        }
        
        part rxBeamformer : ReceiveBeamformer {
            attribute dynamicFocusing = true;
            attribute receiveAperture = 64;
        }
        
        part signalProcessor : SignalProcessingUnit {
            attribute filterBandwidth = 4.0;
            attribute compressionRatio = 50.0;
        }
        
        part scanConverter : ScanConverter {
            attribute outputResolutionX = 512;
            attribute outputResolutionY = 512;
            attribute interpolationMethod = "bilinear";
        }
        
        part imageProcessor : ImageProcessor {
            attribute edgeEnhancement = true;
            attribute speckleReduction = true;
        }
        
        part display : DisplayMonitor {
            attribute screenSizeX = 300.0;
            attribute screenSizeY = 225.0;
            attribute resolutionX = 1024;
            attribute resolutionY = 768;
            attribute brightness = 0.75;
            attribute contrast = 0.65;
        }
        
        part console : ControlConsole;
        
        connect console.controlOutput to ultrasoundImager;
        connect txBeamformer to probe.electricalInterface;
        connect probe.acousticInterface to rxBeamformer;
        connect rxBeamformer to signalProcessor;
        connect signalProcessor to scanConverter;
        connect scanConverter to imageProcessor;
        connect imageProcessor to display.imageInput;
        
        perform action continuousImaging {
            first start;
            then merge scanLoop;
            
            action configureScan {
                in userParams : ScanParameters;
                out systemConfig : ScanParameters;
            }
            
            then action acquireFrame {
                in config : ScanParameters = configureScan.systemConfig;
                out frameData : ImageFrame;
                
                private attribute currentLine : Integer := 0;
                private attribute accumulatedData : Real := 0.0;
                
                action transmitPulse {
                    in lineIndex : Integer;
                    in params : ScanParameters;
                    out pulse : UltrasoundPulse;
                }
                
                flow transmitPulse.pulse to propagateAndReceive.transmittedPulse;
                
                then action propagateAndReceive {
                    in transmittedPulse : UltrasoundPulse;
                    out echoData : EchoData;
                }
                
                flow propagateAndReceive.echoData to processLine.rawEcho;
                
                then action processLine {
                    in rawEcho : EchoData;
                    out processedLine : Real;
                }
                
                then action constructFrame : BuildImageFrame {
                    in scanLineData = processLine.processedLine;
                    in params = config;
                    out frame;
                }
                
                then assign frameData := constructFrame.frame;
            }
            
            flow acquireFrame.frameData to displayFrame.inputFrame;
            
            then action displayFrame {
                in inputFrame : ImageFrame;
            }
            
            then decide;
                if displayFrame.inputFrame.frameNumber < 1000 then scanLoop;
                if displayFrame.inputFrame.frameNumber >= 1000 then done;
            
            then scanLoop;
        }
    }
    
    requirement def ImageQualityRequirement {
        doc /* System shall produce diagnostic quality images */
        
        require constraint axialResolution {
            doc /* Axial resolution shall be better than 0.5mm at 5MHz */
            attribute resolution : LengthValue;
            resolution <= 0.5
        }
        
        require constraint lateralResolution {
            doc /* Lateral resolution shall be better than 1.5mm at focal depth */
            attribute resolution : LengthValue;
            resolution <= 1.5
        }
        
        require constraint penetrationDepth {
            doc /* System shall image tissue to at least 200mm depth */
            attribute depth : ImageDepth;
            depth >= 200.0
        }
        
        require constraint temporalResolution {
            doc /* Frame rate shall exceed 30 fps for real-time imaging */
            attribute rate : FrameRateValue;
            rate >= 30.0
        }
    }
    
    requirement def SafetyRequirement {
        doc /* System shall comply with acoustic output safety standards */
        
        require constraint mechanicalIndex {
            doc /* Mechanical index shall not exceed 1.9 */
            attribute mi : Real;
            mi <= 1.9
        }
        
        require constraint thermalIndex {
            doc /* Thermal index shall not exceed 6.0 */
            attribute ti : Real;
            ti <= 6.0
        }
        
        require constraint spatialPeakIntensity {
            doc /* ISPTA shall not exceed 720 mW/cm² */
            attribute ispta : AcousticIntensity;
            ispta <= 720.0
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* System shall meet clinical performance specifications */
        
        require constraint systemLatency {
            doc /* Image display latency shall be less than 100ms */
            attribute latency : DurationValue;
            latency < 100.0
        }
        
        require constraint dynamicRange {
            doc /* System dynamic range shall exceed 60 dB */
            attribute range : Real;
            range >= 60.0
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level requirements for medical ultrasound imaging system */
        
        subject system : UltrasoundImagingSystem;
        
        require imageQuality : ImageQualityRequirement;
        require safety : SafetyRequirement;
        require performance : PerformanceRequirement;
        
        assume constraint operatingEnvironment {
            doc /* System operates in controlled clinical environment */
            attribute temperature : ThermodynamicTemperatureValue;
            attribute humidity : Real;
            temperature >= 15.0 and temperature <= 30.0 and
            humidity >= 0.3 and humidity <= 0.75
        }
    }
    
    satisfy systemRequirements by ultrasoundImager;
}
