package LaserBeamProfiler {
    import ScalarValues::*;
    import ISQ::*;
    import ISQSpace::*;
    
    // ===== Value Types =====
    attribute def PowerValue :> Real { unit = "W"; }
    attribute def AttenuationFactor :> Real { unit = "1"; }
    attribute def PixelSize :> Real { unit = "um"; }
    attribute def Wavelength :> Real { unit = "nm"; }
    attribute def FrameRate :> Real { unit = "Hz"; }
    attribute def DynamicRange :> Real { unit = "dB"; }
    attribute def BeamDiameter :> Real { unit = "um"; }
    attribute def Ellipticity :> Real { unit = "1"; }
    attribute def CentroidX :> Real { unit = "px"; }
    attribute def CentroidY :> Real { unit = "px"; }
    attribute def Intensity :> Real { unit = "W/m^2"; }
    
    // ===== Item Types =====
    item def LaserBeam {
        attribute power : PowerValue;
        attribute wavelength : Wavelength;
    }
    
    item def AttenuatedBeam :> LaserBeam {
        attribute attenuationFactor : AttenuationFactor;
    }
    
    item def RawImageData {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelSize : PixelSize := 5.5;
        attribute dynamicRange : DynamicRange;
        attribute pixelValues : Real[0..*];
    }
    
    item def BeamProfileData {
        attribute beamDiameter : BeamDiameter;
        attribute centroidX : CentroidX;
        attribute centroidY : CentroidY;
        attribute ellipticity : Ellipticity;
        attribute peakIntensity : Intensity;
        attribute timestamp : DateTime;
    }
    
    item def MeasurementParameters {
        attribute mode : MeasurementMode;
        attribute exposureTime : Real;
        attribute gain : Real;
        attribute triggerDelay : Real;
    }
    
    enum def MeasurementMode {
        continuous = 0;
        triggered = 1;
        singleShot = 2;
    }
    
    enum def OperationalState {
        idle = 0;
        calibrating = 1;
        measuring = 2;
        processing = 3;
        error = 4;
    }
    
    item def TriggerSignal {
        attribute source : String;
        attribute timestamp : DateTime;
    }
    
    item def CalibrationData {
        attribute darkOffset : Real[0..*];
        attribute flatField : Real[0..*];
        attribute calibrationDate : DateTime;
    }
    
    item def DisplayData {
        attribute profile : BeamProfileData;
        attribute image : RawImageData;
        attribute statusMessage : String;
    }
    
    // ===== Port Definitions =====
    port def OpticalInputPort {
        in beam : LaserBeam;
    }
    
    port def OpticalOutputPort {
        out beam : LaserBeam;
    }
    
    port def ImageDataPort {
        out imageData : RawImageData;
    }
    
    port def ImageDataInPort {
        in imageData : RawImageData;
    }
    
    port def ProfileDataPort {
        out profileData : BeamProfileData;
    }
    
    port def ProfileDataInPort {
        in profileData : BeamProfileData;
    }
    
    port def ControlPort {
        in parameters : MeasurementParameters;
        out status : OperationalState;
    }
    
    port def TriggerPort {
        in trigger : TriggerSignal;
    }
    
    port def CalibrationPort {
        out calibrationData : CalibrationData;
    }
    
    port def CalibrationInPort {
        in calibrationData : CalibrationData;
    }
    
    port def DisplayPort {
        out displayData : DisplayData;
        in userCommands : MeasurementParameters;
    }
    
    // ===== Requirements =====
    requirement def SafePowerLevelRequirement {
        doc "The optical attenuator must reduce beam power to a safe level for internal optics."
        attribute maxSafePower : PowerValue = 0.001;
        subject attenuatedBeam : AttenuatedBeam;
        require attenuatedBeam.power <= maxSafePower;
    }
    
    requirement def SensorResolutionRequirement {
        doc "The imaging sensor must have a pixel size of 5.5 micrometers."
        attribute requiredPixelSize : PixelSize = 5.5;
        subject sensor : ImagingSensor;
        require sensor.pixelSize == requiredPixelSize;
    }
    
    requirement def BeamParameterCalculationRequirement {
        doc "The signal processor must calculate beam diameter, centroid, and ellipticity."
        subject processor : SignalProcessor;
        require processor.profilesGenerated == true;
    }
    
    requirement def MeasurementModeRequirement {
        doc "The profiler must support continuous, triggered, and single-shot modes."
        subject profiler : LaserBeamProfilerSystem;
        require profiler.supportedModes == MeasurementMode::continuous | MeasurementMode::triggered | MeasurementMode::singleShot;
    }
    
    requirement def DynamicRangeRequirement {
        doc "The imaging sensor must have a high dynamic range."
        attribute minDynamicRange : DynamicRange = 60.0;
        subject sensor : ImagingSensor;
        require sensor.dynamicRange >= minDynamicRange;
    }
    
    // ===== Part Definitions =====
    part def OpticalAttenuator {
        attribute attenuationFactor : AttenuationFactor = 0.01;
        attribute maxInputPower : PowerValue = 10.0;
        attribute maxOutputPower : PowerValue = 0.001;
        
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        
        action attenuateBeam {
            in incoming : LaserBeam;
            out attenuated : AttenuatedBeam;
            
            perform {
                attenuated.power = incoming.power * attenuationFactor;
                attenuated.wavelength = incoming.wavelength;
                attenuated.attenuationFactor = attenuationFactor;
            }
        }
    }
    
    part def BeamSplitter {
        attribute transmissionRatio : Real = 0.9;
        attribute reflectionRatio : Real = 0.1;
        
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        port monitorOut : OpticalOutputPort;
        
        action splitBeam {
            in incoming : LaserBeam;
            out primary : LaserBeam;
            out monitor : LaserBeam;
            
            perform {
                primary.power = incoming.power * transmissionRatio;
                monitor.power = incoming.power * reflectionRatio;
                primary.wavelength = incoming.wavelength;
                monitor.wavelength = incoming.wavelength;
            }
        }
    }
    
    part def ImagingSensor {
        attribute pixelSize : PixelSize = 5.5;
        attribute dynamicRange : DynamicRange = 72.0;
        attribute resolutionWidth : Integer = 2048;
        attribute resolutionHeight : Integer = 2048;
        attribute maxFrameRate : FrameRate = 30.0;
        attribute currentExposureTime : Real = 0.001;
        attribute currentGain : Real = 1.0;
        
        port opticalIn : OpticalInputPort;
        port imageOut : ImageDataPort;
        
        action captureImage {
            in incoming : LaserBeam;
            out rawImage : RawImageData;
            
            perform {
                rawImage.width = resolutionWidth;
                rawImage.height = resolutionHeight;
                rawImage.pixelSize = pixelSize;
                rawImage.dynamicRange = dynamicRange;
            }
        }
    }
    
    part def SignalProcessor {
        attribute processingClockRate : Real = 200e6;
        attribute profilesGenerated : Boolean = false;
        
        port imageIn : ImageDataInPort;
        port profileOut : ProfileDataPort;
        port calibrationIn : CalibrationInPort;
        
        action analyzeImage {
            in rawImage : RawImageData;
            in calibration : CalibrationData;
            out profile : BeamProfileData;
            
            perform {
                // Calculate beam diameter using second moment
                profile.beamDiameter = 0.0;
                // Calculate centroid position
                profile.centroidX = 0.0;
                profile.centroidY = 0.0;
                // Calculate ellipticity from major/minor axis ratio
                profile.ellipticity = 1.0;
                // Determine peak intensity
                profile.peakIntensity = 0.0;
                profilesGenerated = true;
            }
        }
        
        action compileReport {
            in profile : BeamProfileData;
            out report : BeamProfileData;
            
            perform {
                report = profile;
            }
        }
    }
    
    part def UserInterface {
        attribute displayResolution : String = "1920x1080";
        attribute refreshRate : FrameRate = 60.0;
        
        port displayOut : DisplayPort;
        port controlOut : ControlPort;
        
        action setParameters {
            out params : MeasurementParameters;
        }
        
        action displayProfile {
            in displayData : DisplayData;
        }
    }
    
    part def CalibrationUnit {
        attribute calibrationInterval : Real = 3600.0;
        attribute lastCalibration : DateTime;
        attribute isCalibrated : Boolean = false;
        
        port calibrationOut : CalibrationPort;
        
        action performCalibration {
            out calibrationData : CalibrationData;
            
            perform {
                calibrationData.darkOffset = Sequence{0.0};
                calibrationData.flatField = Sequence{1.0};
                isCalibrated = true;
            }
        }
    }
    
    part def TriggerInterface {
        attribute triggerMode : MeasurementMode = MeasurementMode::continuous;
        attribute triggerDelay : Real = 0.0;
        
        port triggerIn : TriggerPort;
        port triggerOut : TriggerPort;
        
        action receiveTrigger {
            in trigger : TriggerSignal;
            out forwardedTrigger : TriggerSignal;
        }
    }
    
    part def SystemController {
        attribute currentState : OperationalState = OperationalState::idle;
        attribute currentMode : MeasurementMode = MeasurementMode::continuous;
        attribute errorCount : Integer = 0;
        attribute maxErrors : Integer = 5;
        
        port controlIn : ControlPort;
        port triggerIn : TriggerPort;
        port calibrationIn : CalibrationInPort;
        
        state machine ControllerStateMachine {
            entry;
            
            state idle {
                entry action { currentState = OperationalState::idle; }
                transition idle_to_calibrating 
                    from idle to calibrating 
                    when (controlIn.parameters.mode != currentMode) 
                    do action { currentMode = controlIn.parameters.mode; };
                transition idle_to_measuring 
                    from idle to measuring 
                    when (currentMode == MeasurementMode::continuous or triggerIn.trigger != null)
                    do action { currentState = OperationalState::measuring; };
            }
            
            state calibrating {
                entry action { currentState = OperationalState::calibrating; }
                do action { 
                    // Initiate calibration sequence
                }
                transition calibrating_to_measuring 
                    from calibrating to measuring 
                    when (calibrationIn.calibrationData != null)
                    do action { currentState = OperationalState::measuring; };
                transition calibrating_to_error 
                    from calibrating to error 
                    when (errorCount >= maxErrors);
            }
            
            state measuring {
                entry action { currentState = OperationalState::measuring; }
                do action {
                    // Capture image from sensor
                }
                transition measuring_to_processing 
                    from measuring to processing 
                    when (true)
                    do action { currentState = OperationalState::processing; };
                transition measuring_to_error 
                    from measuring to error 
                    when (errorCount >= maxErrors);
            }
            
            state processing {
                entry action { currentState = OperationalState::processing; }
                do action {
                    // Process image data and generate profile
                }
                transition processing_to_idle 
                    from processing to idle 
                    when (currentMode == MeasurementMode::singleShot)
                    do action { currentState = OperationalState::idle; };
                transition processing_to_measuring 
                    from processing to measuring 
                    when (currentMode == MeasurementMode::continuous)
                    do action { currentState = OperationalState::measuring; };
                transition processing_to_error 
                    from processing to error 
                    when (errorCount >= maxErrors);
            }
            
            state error {
                entry action { currentState = OperationalState::error; }
                do action {
                    // Handle error, log details, attempt recovery
                    errorCount = errorCount + 1;
                }
                transition error_to_idle 
                    from error to idle 
                    when (errorCount < maxErrors)
                    do action { currentState = OperationalState::idle; };
            }
        }
    }
    
    // ===== System Definition =====
    part def LaserBeamProfilerSystem {
        attribute systemName : String = "LBP-2000";
        attribute supportedModes : MeasurementMode = MeasurementMode::continuous;
        attribute maxInputPower : PowerValue = 10.0;
        attribute operatingWavelength : Wavelength = 1064.0;
        
        port laserInput : OpticalInputPort;
        port triggerInput : TriggerPort;
        port userInterfacePort : DisplayPort;
        
        satisfy SafePowerLevelRequirement {
            subject attenuatedBeam :> attenuator.opticalOut.beam;
        }
        
        satisfy SensorResolutionRequirement {
            subject sensor :> imagingSensor;
        }
        
        satisfy BeamParameterCalculationRequirement {
            subject processor :> signalProcessor;
        }
        
        satisfy MeasurementModeRequirement {
            subject profiler :> this;
        }
        
        satisfy DynamicRangeRequirement {
            subject sensor :> imagingSensor;
        }
        
        part attenuator : OpticalAttenuator {
            port opticalIn :>> laserInput;
        }
        
        part beamSplitter : BeamSplitter {
            port opticalIn : OpticalInputPort;
            port opticalOut : OpticalOutputPort;
            port monitorOut : OpticalOutputPort;
        }
        
        part imagingSensor : ImagingSensor {
            port opticalIn : OpticalInputPort;
            port imageOut : ImageDataPort;
        }
        
        part signalProcessor : SignalProcessor {
            port imageIn : ImageDataInPort;
            port profileOut : ProfileDataPort;
            port calibrationIn : CalibrationInPort;
        }
        
        part userInterface : UserInterface {
            port displayOut : DisplayPort;
            port controlOut : ControlPort;
        }
        
        part calibrationUnit : CalibrationUnit {
            port calibrationOut : CalibrationPort;
        }
        
        part triggerInterface : TriggerInterface {
            port triggerIn :>> triggerInput;
            port triggerOut : TriggerPort;
        }
        
        part systemController : SystemController {
            port controlIn : ControlPort;
            port triggerIn : TriggerPort;
            port calibrationIn : CalibrationInPort;
        }
        
        // ===== Connections =====
        connection opticalPath1 connect attenuator.opticalOut to beamSplitter.opticalIn {
            item beamFlow : LaserBeam;
        }
        
        connection opticalPath2 connect beamSplitter.opticalOut to imagingSensor.opticalIn {
            item beamFlow : LaserBeam;
        }
        
        connection monitorPath connect beamSplitter.monitorOut to calibrationUnit.calibrationOut {
            item monitorBeam : LaserBeam;
        }
        
        connection imageDataFlow connect imagingSensor.imageOut to signalProcessor.imageIn {
            item imageFlow : RawImageData;
        }
        
        connection profileDataFlow connect signalProcessor.profileOut to userInterface.displayOut {
            item profileFlow : BeamProfileData;
        }
        
        connection calibrationDataFlow connect calibrationUnit.calibrationOut to signalProcessor.calibrationIn {
            item calibrationFlow : CalibrationData;
        }
        
        connection controllerCalibrationFlow connect calibrationUnit.calibrationOut to systemController.calibrationIn {
            item calibrationFlow : CalibrationData;
        }
        
        connection triggerFlow connect triggerInterface.triggerOut to systemController.triggerIn {
            item triggerSignal : TriggerSignal;
        }
        
        connection controlFlow connect userInterface.controlOut to systemController.controlIn {
            item parameterFlow : MeasurementParameters;
        }
        
        // ===== System-level Behavior =====
        action measureBeam {
            in incomingBeam : LaserBeam;
            out profileReport : BeamProfileData;
            
            perform attenuator.attenuateBeam {
                in incoming = incomingBeam;
                out attenuated = attenuatedBeam;
            }
            
            perform beamSplitter.splitBeam {
                in incoming = attenuatedBeam;
                out primary = primaryBeam;
                out monitor = monitorBeam;
            }
            
            perform imagingSensor.captureImage {
                in incoming = primaryBeam;
                out rawImage = capturedImage;
            }
            
            perform signalProcessor.analyzeImage {
                in rawImage = capturedImage;
                in calibration = calibrationData;
                out profile = beamProfile;
            }
            
            perform signalProcessor.compileReport {
                in profile = beamProfile;
                out report = profileReport;
            }
        }
        
        state machine SystemOperationStateMachine {
            entry;
            
            state idle;
            state calibrating;
            state measuring;
            state processing;
            state errorHandling;
            
            transition initCalibration from idle to calibrating 
                when (triggerInput.trigger != null and triggerInput.trigger.source == "calibration");
            
            transition startMeasurement from idle to measuring 
                when (triggerInput.trigger != null and triggerInput.trigger.source == "measure");
            
            transition calibrationComplete from calibrating to idle 
                when (calibrationUnit.isCalibrated == true);
            
            transition measurementComplete from measuring to processing 
                when (signalProcessor.profilesGenerated == true);
            
            transition processingComplete from processing to idle 
                when (true);
            
            transition measurementError from measuring to errorHandling 
                when (systemController.errorCount >= systemController.maxErrors);
            
            transition processingError from processing to errorHandling 
                when (systemController.errorCount >= systemController.maxErrors);
            
            transition errorRecovery from errorHandling to idle 
                when (systemController.errorCount < systemController.maxErrors);
        }
    }
}
