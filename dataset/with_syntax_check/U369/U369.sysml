package RhinoscopeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import SequenceFunctions::*;
    
    attribute def IlluminationIntensity :> LuminousIntensityValue;
    attribute def ImageResolution {
        attribute horizontalPixels : Integer;
        attribute verticalPixels : Integer;
    }
    attribute def ViewingAngle :> ISQ::AngleValue;
    attribute def FlowRate :> VolumeFlowRateValue;
    
    item def OpticalSignal {
        attribute brightness : IlluminationIntensity;
        attribute wavelength : LengthValue;
    }
    
    item def VideoData {
        attribute resolution : ImageResolution;
        attribute frameRate : FrequencyValue;
    }
    
    item def IrrigationFluid {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute flowRate : FlowRate;
    }
    
    item def SuctionedMaterial {
        attribute volume : VolumeValue;
    }
    
    port def LightOutputPort {
        out lightSignal : OpticalSignal;
    }
    
    port def VideoOutputPort {
        out videoStream : VideoData;
    }
    
    port def IrrigationPort {
        out fluid : IrrigationFluid;
    }
    
    port def SuctionPort {
        in material : SuctionedMaterial;
        attribute vacuumPressure : PressureValue;
    }
    
    port def PowerInputPort {
        in power : PowerValue;
    }
    
    part def LightSource {
        attribute nominalPower : PowerValue;
        attribute colorTemperature : ThermodynamicTemperatureValue;
        port lightOut : LightOutputPort;
        port powerIn : PowerInputPort;
        
        action def GenerateIllumination {
            in powerLevel : PowerValue;
            out illumination : OpticalSignal;
        }
    }
    
    part def FiberOpticBundle {
        attribute fiberCount : Integer;
        attribute transmissionEfficiency : Real;
        port lightIn : LightOutputPort;
        port lightOut : LightOutputPort;
        
        action def TransmitLight {
            in inputLight : OpticalSignal;
            out outputLight : OpticalSignal;
        }
    }
    
    part def ImageSensor {
        attribute sensorType : String;
        attribute resolution : ImageResolution;
        port videoOut : VideoOutputPort;
        
        action def CaptureImage {
            in illuminatedScene : OpticalSignal;
            out imageData : VideoData;
        }
    }
    
    part def LensAssembly {
        attribute focalLength : LengthValue;
        attribute viewAngle : ViewingAngle;
        attribute magnification : Real;
        
        action def FocusLight {
            in incomingLight : OpticalSignal;
            out focusedImage : OpticalSignal;
        }
    }
    
    part def InsertionTube {
        attribute outerDiameter : LengthValue;
        attribute workingLength : LengthValue;
        attribute flexibility : Real;
        port fiberInput : LightOutputPort;
        port fiberOutput : LightOutputPort;
        port irrigationChannel : IrrigationPort;
        port suctionChannel : SuctionPort;
    }
    
    part def IrrigationSystem {
        attribute reservoirCapacity : VolumeValue;
        attribute maxFlowRate : FlowRate;
        port fluidOut : IrrigationPort;
        port powerIn : PowerInputPort;
        
        action def DeliverFluid {
            in requestedFlow : FlowRate;
            out deliveredFluid : IrrigationFluid;
        }
    }
    
    part def SuctionSystem {
        attribute maxVacuum : PressureValue;
        attribute collectionCapacity : VolumeValue;
        port suctionIn : SuctionPort;
        port powerIn : PowerInputPort;
        
        action def RemoveMaterial {
            in vacuumLevel : PressureValue;
            out materialRemoved : SuctionedMaterial;
        }
    }
    
    part def VideoProcessor {
        attribute processingLatency : DurationValue;
        port videoIn : VideoOutputPort;
        port videoOut : VideoOutputPort;
        
        action def ProcessVideo {
            in rawVideo : VideoData;
            out enhancedVideo : VideoData;
        }
    }
    
    part def DisplayMonitor {
        attribute screenSize : LengthValue;
        attribute displayResolution : ImageResolution;
        port videoIn : VideoOutputPort;
        port powerIn : PowerInputPort;
        
        action def RenderImage {
            in videoInput : VideoData;
        }
    }
    
    part def ControlUnit {
        attribute operatingVoltage : ElectricPotentialValue;
        port powerIn : PowerInputPort;
        port lightControlOut : PowerInputPort;
        port irrigationControlOut : PowerInputPort;
        port suctionControlOut : PowerInputPort;
        
        action def ManageSubsystems {
            in userCommands : String;
            out systemStatus : String;
        }
    }
    
    part def Rhinoscope {
        doc /* 
            A medical endoscopic instrument designed for visual examination 
            of the nasal cavity, nasopharynx, and related anatomical structures.
            Primary function: Provide illuminated, magnified visualization of 
            nasal passages to enable diagnostic assessment and therapeutic procedures.
        */
        
        attribute overallLength : LengthValue;
        attribute insertionDiameter : LengthValue;
        
        port mainPowerInput : PowerInputPort;
        port displayOutput : VideoOutputPort;
        
        part lightingSystem : LightSource {
            attribute redefines nominalPower = 150.0 [W];
            attribute redefines colorTemperature = 5600.0 [K];
        }
        
        part fiberOptics : FiberOpticBundle {
            attribute redefines fiberCount = 10000;
            attribute redefines transmissionEfficiency = 0.92;
        }
        
        part distalLens : LensAssembly {
            attribute redefines focalLength = 3.5 [mm];
            attribute redefines viewAngle = 70.0 ['°'];
            attribute redefines magnification = 1.5;
        }
        
        part imagingSensor : ImageSensor {
            attribute redefines sensorType = "CMOS";
            attribute redefines resolution {
                attribute redefines horizontalPixels = 1920;
                attribute redefines verticalPixels = 1080;
            }
        }
        
        part insertionScope : InsertionTube {
            attribute redefines outerDiameter = 4.0 [mm];
            attribute redefines workingLength = 300.0 [mm];
            attribute redefines flexibility = 0.7;
        }
        
        part irrigation : IrrigationSystem {
            attribute redefines reservoirCapacity = 500.0 [mL];
            attribute redefines maxFlowRate = 50.0 [mL/min];
        }
        
        part suction : SuctionSystem {
            attribute redefines maxVacuum = -60.0 [kPa];
            attribute redefines collectionCapacity = 200.0 [mL];
        }
        
        part videoProcessing : VideoProcessor {
            attribute redefines processingLatency = 16.0 [ms];
        }
        
        part monitor : DisplayMonitor {
            attribute redefines screenSize = 21.0 ['in'];
            attribute redefines displayResolution {
                attribute redefines horizontalPixels = 1920;
                attribute redefines verticalPixels = 1080;
            }
        }
        
        part controller : ControlUnit {
            attribute redefines operatingVoltage = 24.0 [V];
        }
        
        connection powerDistribution connect mainPowerInput to controller.powerIn;
        connection lightPower connect controller.lightControlOut to lightingSystem.powerIn;
        connection irrigationPower connect controller.irrigationControlOut to irrigation.powerIn;
        connection suctionPower connect controller.suctionControlOut to suction.powerIn;
        connection monitorPower connect mainPowerInput to monitor.powerIn;
        
        flow lightingSystem.lightOut to fiberOptics.lightIn;
        flow fiberOptics.lightOut to insertionScope.fiberInput;
        flow insertionScope.fiberOutput to distalLens;
        flow distalLens to imagingSensor;
        flow imagingSensor.videoOut to videoProcessing.videoIn;
        flow videoProcessing.videoOut to monitor.videoIn;
        
        flow irrigation.fluidOut to insertionScope.irrigationChannel;
        flow insertionScope.suctionChannel to suction.suctionIn;
        
        perform action nasalExamination[*] ordered references PerformNasalExamination;
    }
    
    action def InitializeSystem {
        out systemReady : Boolean;
        
        action activatePower {
            out powerStable : Boolean;
        }
        then action calibrateSensors {
            out sensorsCalibrated : Boolean;
        }
        then action warmUpLight {
            out lightStabilized : Boolean;
        }
        then assign systemReady := true;
    }
    
    action def PositionInstrument {
        in targetDepth : LengthValue;
        in approachAngle : ISQ::AngleValue;
        out positioned : Boolean;
    }
    
    action def AdjustIllumination {
        in desiredIntensity : IlluminationIntensity;
        out currentIntensity : IlluminationIntensity;
    }
    
    action def CaptureVideoFrame {
        out frame : VideoData;
    }
    
    action def ApplyIrrigation {
        in flowRate : FlowRate;
        out fluidDelivered : IrrigationFluid;
    }
    
    action def ActivateSuction {
        in vacuumLevel : PressureValue;
        out materialRemoved : SuctionedMaterial;
    }
    
    action def WithdrawInstrument {
        out withdrawn : Boolean;
    }
    
    action def PerformNasalExamination {
        doc /* 
            Primary operational sequence for rhinoscopic examination:
            Illuminate nasal cavity, capture high-resolution video imagery,
            optionally irrigate and suction as needed, and provide real-time
            visualization to enable clinical assessment.
        */
        
        in examinationDepth : LengthValue;
        in lightIntensity : IlluminationIntensity;
        in requireIrrigation : Boolean;
        out capturedFrames : VideoData[*] := ( );
        out examinationComplete : Boolean;
        
        first start;
        
        then action initialize : InitializeSystem {
            out systemReady;
        }
        
        then action position : PositionInstrument {
            in targetDepth = examinationDepth;
            in approachAngle = 30.0 ['°'];
            out positioned;
        }
        
        then action setLight : AdjustIllumination {
            in desiredIntensity = lightIntensity;
            out currentIntensity;
        }
        
        then merge continuousImaging;
        
        then loop {
            action captureFrame : CaptureVideoFrame {
                out frame;
            }
            then assign capturedFrames := capturedFrames->including(captureFrame.frame);
            
            then decide;
                if requireIrrigation then irrigate;
                else checkCompletion;
            
            action irrigate : ApplyIrrigation {
                in flowRate = 30.0 [mL/min];
                out fluidDelivered;
            }
            then action applySuction : ActivateSuction {
                in vacuumLevel = -40.0 [kPa];
                out materialRemoved;
            }
            then checkCompletion;
            
            action checkCompletion {
                out continueExam : Boolean;
            }
            then decide;
                if checkCompletion.continueExam then continuousImaging;
                else exitLoop;
            
            action exitLoop;
            then break;
        }
        
        then action withdraw : WithdrawInstrument {
            out withdrawn;
        }
        
        then assign examinationComplete := true;
        
        then done;
    }
    
    state def RhinoscopeOperationalStates {
        entry; then idle;
        
        state idle {
            doc /* System powered but not actively examining */
        }
        
        state initializing {
            doc /* System startup and calibration in progress */
        }
        
        state ready {
            doc /* System prepared for examination */
        }
        
        state examining {
            doc /* Active visualization and data capture */
        }
        
        state irrigating {
            doc /* Fluid delivery active */
        }
        
        state suctioning {
            doc /* Material removal active */
        }
        
        state shutdown {
            doc /* System powering down */
        }
        
        transition idle_to_init
            first idle
            then initializing;
        
        transition init_to_ready
            first initializing
            then ready;
        
        transition ready_to_exam
            first ready
            then examining;
        
        transition exam_to_irrigate
            first examining
            then irrigating;
        
        transition irrigate_to_suction
            first irrigating
            then suctioning;
        
        transition suction_to_exam
            first suctioning
            then examining;
        
        transition exam_to_ready
            first examining
            then ready;
        
        transition ready_to_shutdown
            first ready
            then shutdown;
        
        transition shutdown_to_idle
            first shutdown
            then idle;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    requirement def UsabilityRequirement;
    
    requirement <'FR-001'> visualizationCapability : FunctionalRequirement {
        doc /* 
            The rhinoscope shall provide continuous, real-time visualization 
            of nasal cavity structures with sufficient illumination and image quality 
            to enable diagnostic assessment.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.imagingSensor.resolution.horizontalPixels >= 1920 and
            rhinoscope.imagingSensor.resolution.verticalPixels >= 1080
        }
    }
    
    requirement <'FR-002'> irrigationCapability : FunctionalRequirement {
        doc /* 
            The rhinoscope shall provide controlled irrigation to clear 
            secretions and maintain visibility during examination.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.irrigation.maxFlowRate >= 30.0 [mL/min]
        }
    }
    
    requirement <'FR-003'> suctionCapability : FunctionalRequirement {
        doc /* 
            The rhinoscope shall provide suction capability to remove 
            fluids and debris from the examination field.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.suction.maxVacuum <= -50.0 [kPa]
        }
    }
    
    requirement <'PR-001'> videoLatency : PerformanceRequirement {
        doc /* 
            The video processing latency shall not exceed 20 milliseconds 
            to ensure real-time visualization during procedures.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.videoProcessing.processingLatency <= 20.0 [ms]
        }
    }
    
    requirement <'PR-002'> illuminationQuality : PerformanceRequirement {
        doc /* 
            The light source shall provide sufficient illumination intensity 
            and appropriate color temperature for accurate tissue visualization.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.lightingSystem.nominalPower >= 100.0 [W] and
            rhinoscope.lightingSystem.colorTemperature >= 5000.0 [K] and
            rhinoscope.lightingSystem.colorTemperature <= 6500.0 [K]
        }
    }
    
    requirement <'SR-001'> insertionDiameterLimit : SafetyRequirement {
        doc /* 
            The insertion tube outer diameter shall not exceed 5mm 
            to ensure safe passage through nasal anatomy.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.insertionScope.outerDiameter <= 5.0 [mm]
        }
    }
    
    requirement <'SR-002'> suctionPressureLimit : SafetyRequirement {
        doc /* 
            The maximum suction vacuum pressure shall not exceed -80 kPa 
            to prevent tissue trauma.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.suction.maxVacuum >= -80.0 [kPa]
        }
    }
    
    requirement <'UR-001'> displaySize : UsabilityRequirement {
        doc /* 
            The display monitor shall provide a screen size of at least 
            19 inches diagonal to ensure adequate visualization for the operator.
        */
        subject rhinoscope : Rhinoscope;
        require constraint {
            rhinoscope.monitor.screenSize >= 19.0 ['in']
        }
    }
    
    requirement rhinoscopeSystemRequirements {
        doc /* 
            Top-level requirements for the rhinoscope system encompassing 
            functional capabilities, performance specifications, safety constraints, 
            and usability criteria.
        */
        subject rhinoscope : Rhinoscope;
        
        require visualizationCapability;
        require irrigationCapability;
        require suctionCapability;
        require videoLatency;
        require illuminationQuality;
        require insertionDiameterLimit;
        require suctionPressureLimit;
        require displaySize;
    }
}
