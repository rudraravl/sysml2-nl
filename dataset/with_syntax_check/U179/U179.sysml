package CancerVisionGogglesSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WavelengthValue :> LengthValue;
    attribute def IntensityValue :> Real;
    attribute def FrameRateValue :> FrequencyValue;
    attribute def ResolutionValue :> Integer;
    attribute def ConfidenceLevel :> Real;
    
    enum def TissueType {
        healthy;
        suspicious;
        malignant;
    }
    
    item def TissueRegion {
        attribute position : LengthValue[3];
        attribute classification : TissueType;
        attribute fluorescenceIntensity : IntensityValue;
    }
    
    item def OpticalSignal {
        attribute wavelength : WavelengthValue;
        attribute intensity : IntensityValue;
        attribute timestamp : TimeValue;
    }
    
    item def VideoFrame {
        attribute resolution : ResolutionValue[2];
        attribute captureTime : TimeValue;
        attribute rawData : Real[*];
    }
    
    item def AnnotatedFrame {
        attribute baseFrame : VideoFrame;
        attribute detectedRegions : TissueRegion[*];
        attribute overlayApplied : Boolean;
    }
    
    item def SurgicalGuidance {
        attribute tumorBoundaries : LengthValue[*];
        attribute resectionMargins : LengthValue;
        attribute confidenceScore : ConfidenceLevel;
    }
    
    port def PowerSupplyPort {
        out voltage : ElectricPotentialValue;
        out current : ElectricCurrentValue;
    }
    
    port def OpticalPort {
        out excitationLight : OpticalSignal;
        in fluorescenceSignal : OpticalSignal;
    }
    
    port def VideoDataPort {
        out videoStream : VideoFrame;
    }
    
    port def ProcessedDataPort {
        in rawFrames : VideoFrame;
        out annotatedFrames : AnnotatedFrame;
    }
    
    port def DisplayPort {
        in displayData : AnnotatedFrame;
    }
    
    port def GuidancePort {
        out surgicalInfo : SurgicalGuidance;
    }
    
    part def NIRIlluminationSource {
        attribute emissionWavelength : WavelengthValue;
        attribute outputPower : PowerValue;
        attribute modulationFrequency : FrequencyValue;
        port power : PowerSupplyPort;
        port opticalOutput : OpticalPort;
    }
    
    part def FluorescenceCamera {
        attribute spectralSensitivity : WavelengthValue[2];
        attribute quantumEfficiency : Real;
        attribute frameRate : FrameRateValue;
        attribute sensorResolution : ResolutionValue[2];
        port power : PowerSupplyPort;
        port opticalInput : OpticalPort;
        port videoOutput : VideoDataPort;
    }
    
    part def ImageProcessingUnit {
        attribute processingLatency : TimeValue;
        attribute algorithmVersion : String;
        attribute detectionThreshold : Real;
        port power : PowerSupplyPort;
        port dataInput : ProcessedDataPort;
        port dataOutput : ProcessedDataPort;
    }
    
    part def HeadMountedDisplay {
        attribute displayResolution : ResolutionValue[2];
        attribute refreshRate : FrameRateValue;
        attribute fieldOfView : Real;
        attribute brightness : IntensityValue;
        port power : PowerSupplyPort;
        port videoInput : DisplayPort;
    }
    
    part def TumorDetectionEngine {
        attribute mlModelVersion : String;
        attribute sensitivityLevel : ConfidenceLevel;
        attribute specificityLevel : ConfidenceLevel;
        port power : PowerSupplyPort;
        port analysisInput : ProcessedDataPort;
        port guidanceOutput : GuidancePort;
    }
    
    part def BatteryPack {
        attribute capacity : EnergyValue;
        attribute voltage : ElectricPotentialValue;
        attribute remainingCharge : Real;
        port powerOutput : PowerSupplyPort;
    }
    
    part def CancerVisionGoggles {
        doc /* 
            Wearable surgical visualization system that detects and highlights 
            cancerous tissue in real-time using near-infrared fluorescence imaging 
            to guide precise tumor resection during surgery.
        */
        
        attribute operatingTemperature : TemperatureValue;
        attribute totalWeight : MassValue;
        attribute continuousOperationTime : TimeValue;
        
        part illuminator : NIRIlluminationSource {
            attribute emissionWavelength = 780.0[SI::nm];
            attribute outputPower = 75.0[SI::W] * 0.001;
            attribute modulationFrequency = 10.0[SI::Hz];
        }
        
        part camera : FluorescenceCamera {
            attribute spectralSensitivity = (750.0[SI::nm], 850.0[SI::nm]);
            attribute quantumEfficiency = 0.85;
            attribute frameRate = 30.0[SI::Hz];
            attribute sensorResolution = (1920, 1080);
        }
        
        part processor : ImageProcessingUnit {
            attribute processingLatency = 25.0[SI::s] * 0.001;
            attribute algorithmVersion = "v3.2";
            attribute detectionThreshold = 0.70;
        }
        
        part display : HeadMountedDisplay {
            attribute displayResolution = (2560, 1440);
            attribute refreshRate = 90.0[SI::Hz];
            attribute fieldOfView = 110.0;
            attribute brightness = 800.0;
        }
        
        part detectionEngine : TumorDetectionEngine {
            attribute mlModelVersion = "TumorNet-v4.1";
            attribute sensitivityLevel = 0.96;
            attribute specificityLevel = 0.92;
        }
        
        part battery : BatteryPack {
            attribute capacity = 50.0[SI::W] * 3600.0[SI::s];
            attribute voltage = 12.0[SI::V];
            attribute remainingCharge = 1.0;
        }
        
        connect battery.powerOutput to illuminator.power;
        connect battery.powerOutput to camera.power;
        connect battery.powerOutput to processor.power;
        connect battery.powerOutput to display.power;
        connect battery.powerOutput to detectionEngine.power;
        
        connection opticalPath connect illuminator.opticalOutput to camera.opticalInput;
        connection videoProcessingPath connect camera.videoOutput to processor.dataInput;
        connection analysisPath connect processor.dataOutput to detectionEngine.analysisInput;
        connection displayPath connect processor.dataOutput to display.videoInput;
        
        perform action detectAndVisualizeCancer;
    }
    
    action def EmitNIRLight {
        in wavelength : WavelengthValue;
        in power : PowerValue;
        out excitationSignal : OpticalSignal;
    }
    
    action def CaptureFrame {
        in excitedTissue : OpticalSignal;
        out rawFrame : VideoFrame;
    }
    
    action def EnhanceImage {
        in rawFrame : VideoFrame;
        out enhancedFrame : VideoFrame;
    }
    
    action def DetectTumor {
        in enhancedFrame : VideoFrame;
        out detectedRegions : TissueRegion[*];
        out confidence : ConfidenceLevel;
    }
    
    action def GenerateOverlay {
        in baseFrame : VideoFrame;
        in tumorRegions : TissueRegion[*];
        out annotatedFrame : AnnotatedFrame;
    }
    
    action def ComputeGuidance {
        in tumorRegions : TissueRegion[*];
        out guidance : SurgicalGuidance;
    }
    
    action def RenderToDisplay {
        in annotatedFrame : AnnotatedFrame;
        in guidance : SurgicalGuidance;
    }
    
    action detectAndVisualizeCancer {
        doc /* 
            Primary operational behavior: Continuously illuminate tissue with NIR light,
            capture fluorescence emissions, detect cancerous regions using AI analysis,
            overlay visual markers on tumor boundaries, and display augmented surgical
            view to guide precise resection.
        */
        
        first start;
        
        then loop {
            action emit : EmitNIRLight {
                in wavelength = 780.0[SI::nm];
                in power = 75.0[SI::W] * 0.001;
                out excitationSignal;
            }
            
            then action capture : CaptureFrame {
                in excitedTissue = emit.excitationSignal;
                out rawFrame;
            }
            
            then action enhance : EnhanceImage {
                in rawFrame = capture.rawFrame;
                out enhancedFrame;
            }
            
            then action detect : DetectTumor {
                in enhancedFrame = enhance.enhancedFrame;
                out detectedRegions;
                out confidence;
            }
            
            then decide;
                if detect.confidence >= 0.75 then processDetection;
                if detect.confidence < 0.75 then continueMonitoring;
            
            action processDetection {
                action overlay : GenerateOverlay {
                    in baseFrame = enhance.enhancedFrame;
                    in tumorRegions = detect.detectedRegions;
                    out annotatedFrame;
                }
                
                flow overlay.annotatedFrame to computeGuidance.tumorRegions;
                
                action computeGuidance : ComputeGuidance {
                    in tumorRegions = detect.detectedRegions;
                    out guidance;
                }
                
                flow overlay.annotatedFrame to render.annotatedFrame;
                flow computeGuidance.guidance to render.guidance;
                
                action render : RenderToDisplay {
                    in annotatedFrame;
                    in guidance;
                }
            }
            
            action continueMonitoring {
                action render : RenderToDisplay {
                    in annotatedFrame;
                    in guidance;
                }
            }
        }
    }
    
    state def GogglesOperationalState {
        entry; then standby;
        
        state standby {
            entry assign powerMode := "low";
        }
        
        transition standby_to_calibration
            first standby
            accept calibrationRequest
            then calibration;
        
        state calibration {
            entry assign powerMode := "active";
            do action performSystemCalibration;
        }
        
        transition calibration_to_imaging
            first calibration
            if calibrationSuccessful
            then imaging;
        
        transition calibration_to_standby
            first calibration
            if calibrationFailed
            then standby;
        
        state imaging {
            entry assign powerMode := "full";
            do action detectAndVisualizeCancer;
        }
        
        transition imaging_to_standby
            first imaging
            accept stopCommand
            then standby;
        
        transition imaging_to_fault
            first imaging
            if systemError
            then fault;
        
        state fault {
            entry assign powerMode := "safe";
        }
        
        transition fault_to_standby
            first fault
            accept resetCommand
            then standby;
    }
    
    requirement def <'REQ-CVG-001'> PrimaryFunction {
        doc /* 
            The CancerVision Goggles shall provide real-time intraoperative 
            visualization of cancerous tissue using near-infrared fluorescence 
            imaging to enable precise surgical resection with clear tumor margin 
            delineation.
        */
        
        subject system : CancerVisionGoggles;
    }
    
    requirement def <'REQ-CVG-002'> DetectionPerformance {
        doc /* 
            The system shall detect cancerous tissue with minimum sensitivity 
            of 95% and specificity of 90% when used with FDA-approved 
            fluorescent contrast agents.
        */
        
        subject engine : TumorDetectionEngine;
        
        require constraint {
            engine.sensitivityLevel >= 0.95 and
            engine.specificityLevel >= 0.90
        }
    }
    
    requirement def <'REQ-CVG-003'> SystemLatency {
        doc /* 
            The system shall process and display fluorescence images with 
            end-to-end latency not exceeding 50 milliseconds from tissue 
            illumination to display output.
        */
        
        subject processor : ImageProcessingUnit;
        
        require constraint {
            processor.processingLatency <= 50.0[SI::s] * 0.001
        }
    }
    
    requirement def <'REQ-CVG-004'> OpticalSpecification {
        doc /* 
            The illumination source shall emit NIR light at 780±10 nm with 
            output power between 50-100 mW, and the camera shall capture 
            fluorescence in the 750-850 nm range at minimum 30 fps.
        */
        
        subject illuminator : NIRIlluminationSource;
        subject camera : FluorescenceCamera;
        
        require constraint {
            illuminator.emissionWavelength >= 770.0[SI::nm] and
            illuminator.emissionWavelength <= 790.0[SI::nm] and
            illuminator.outputPower >= 50.0[SI::W] * 0.001 and
            illuminator.outputPower <= 100.0[SI::W] * 0.001 and
            camera.frameRate >= 30.0[SI::Hz]
        }
    }
    
    requirement def <'REQ-CVG-005'> OperationalDuration {
        doc /* 
            The system shall operate continuously for minimum 4 hours on 
            battery power and weigh no more than 600 grams for surgical 
            ergonomics.
        */
        
        subject system : CancerVisionGoggles;
        
        require constraint {
            system.continuousOperationTime >= 4.0[SI::h] and
            system.totalWeight <= 600.0[SI::g]
        }
    }
    
    requirement def <'REQ-CVG-006'> DisplayQuality {
        doc /* 
            The head-mounted display shall provide minimum 2560x1440 resolution 
            at 90 Hz refresh rate with 110-degree field of view for immersive 
            surgical visualization.
        */
        
        subject display : HeadMountedDisplay;
        
        require constraint {
            display.displayResolution[1] >= 2560 and
            display.displayResolution[2] >= 1440 and
            display.refreshRate >= 90.0[SI::Hz] and
            display.fieldOfView >= 110.0
        }
    }
    
    requirement systemRequirements {
        doc /* 
            Top-level requirements governing the CancerVision Goggles system 
            to ensure safe, effective, and reliable intraoperative cancer 
            detection and surgical guidance.
        */
        
        require PrimaryFunction;
        require DetectionPerformance;
        require SystemLatency;
        require OpticalSpecification;
        require OperationalDuration;
        require DisplayQuality;
    }
    
    part cancerVisionSystem : CancerVisionGoggles {
        satisfy PrimaryFunction;
        satisfy systemRequirements;
    }
}
