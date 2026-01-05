package LaserBeamProfilerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def BeamDiameter :> LengthValue;
    attribute def BeamPower :> PowerValue;
    attribute def BeamIntensity :> Real;
    attribute def BeamWavelength :> LengthValue;
    attribute def SpatialResolution :> LengthValue;
    attribute def FrameRate :> FrequencyValue;
    attribute def ExposureTime :> TimeValue;
    attribute def AttenuationFactor :> Real;
    
    enum def BeamProfileType {
        gaussian;
        topHat;
        multiMode;
        astigmatic;
    }
    
    enum def MeasurementMode {
        continuous;
        triggered;
        singleShot;
    }
    
    enum def SystemState {
        idle;
        calibrating;
        measuring;
        processing;
        error;
    }
    
    item def LaserBeam {
        attribute wavelength : BeamWavelength;
        attribute power : BeamPower;
        attribute diameter : BeamDiameter;
        attribute profileType : BeamProfileType;
    }
    
    item def RawImageData {
        attribute pixelData : Real[*];
        attribute timestamp : TimeValue;
        attribute exposureTime : ExposureTime;
    }
    
    item def BeamProfileData {
        attribute timestamp : TimeValue;
        attribute beamDiameter : BeamDiameter;
        attribute peakIntensity : BeamIntensity;
        attribute centroidX : LengthValue;
        attribute centroidY : LengthValue;
        attribute ellipticity : Real;
        attribute profileType : BeamProfileType;
        attribute intensityDistribution : Real[*];
    }
    
    port def OpticalInputPort {
        in item laserBeam : LaserBeam;
    }
    
    port def OpticalOutputPort {
        out item laserBeam : LaserBeam;
    }
    
    port def ImageDataPort {
        out item imageData : RawImageData;
    }
    
    port def ProfileDataPort {
        out item profileData : BeamProfileData;
    }
    
    port def ControlPort {
        in attribute measurementMode : MeasurementMode;
        in attribute exposureTime : ExposureTime;
        out attribute systemState : SystemState;
    }
    
    part def OpticalAttenuator {
        attribute attenuationFactor : AttenuationFactor;
        attribute maxInputPower : PowerValue;
        
        port opticalIn : OpticalInputPort;
        port opticalOut : OpticalOutputPort;
        
        action attenuateBeam {
            in incomingBeam : LaserBeam;
            out attenuatedBeam : LaserBeam;
        }
    }
    
    part def BeamSplitter {
        attribute splitRatio : Real;
        
        port opticalIn : OpticalInputPort;
        port opticalOut1 : OpticalOutputPort;
        port opticalOut2 : OpticalOutputPort;
        
        action splitBeam {
            in incomingBeam : LaserBeam;
            out beam1 : LaserBeam;
            out beam2 : LaserBeam;
        }
    }
    
    part def ImagingSensor {
        attribute pixelCount : Integer;
        attribute pixelSize : SpatialResolution;
        attribute dynamicRange : Real;
        attribute quantumEfficiency : Real;
        attribute currentExposure : ExposureTime;
        
        port opticalIn : OpticalInputPort;
        port imageOut : ImageDataPort;
        
        action captureImage {
            in beam : LaserBeam;
            in exposure : ExposureTime;
            out imageData : RawImageData;
        }
    }
    
    part def SignalProcessor {
        attribute processingSpeed : Real;
        attribute bufferSize : Integer;
        
        port imageIn : ImageDataPort;
        port profileOut : ProfileDataPort;
        
        action processImage {
            in rawImage : RawImageData;
            out profile : BeamProfileData;
        }
        
        action calculateCentroid {
            in imageData : RawImageData;
            out centroidX : LengthValue;
            out centroidY : LengthValue;
        }
        
        action calculateDiameter {
            in imageData : RawImageData;
            out diameter : BeamDiameter;
        }
        
        action calculateEllipticity {
            in imageData : RawImageData;
            out ellipticity : Real;
        }
    }
    
    part def CalibrationUnit {
        attribute calibrationDate : String;
        attribute calibrationValid : Boolean;
        
        action performCalibration {
            in exposureTime : ExposureTime;
            out calibrationData : BeamProfileData;
        }
    }
    
    part def UserInterface {
        attribute displayResolution : Integer;
        
        port controlOut : ControlPort;
        port dataIn : ProfileDataPort;
        
        action displayProfile {
            in profile : BeamProfileData;
        }
        
        action setMeasurementParameters {
            out mode : MeasurementMode;
            out exposure : ExposureTime;
        }
    }
    
    action def MeasureBeamProfile {
        in currentMode : MeasurementMode;
        
        first start;
        then merge checkMode;
        
        action checkMode {
            out mode : MeasurementMode = currentMode;
        }
        
        then decide;
            if checkMode.mode == MeasurementMode::continuous then continuousMeasure;
            if checkMode.mode == MeasurementMode::triggered then waitForTrigger;
            if checkMode.mode == MeasurementMode::singleShot then singleCapture;
        
        action waitForTrigger {
            out triggerReceived : Boolean;
        }
        then singleCapture;
        
        action continuousMeasure;
        then captureFrame;
        
        action singleCapture;
        then captureFrame;
        
        action captureFrame {
            in beam : LaserBeam;
            in exposure : ExposureTime;
            out rawData : RawImageData;
        }
        
        then processData;
        
        action processData {
            in rawData : RawImageData;
            out processedProfile : BeamProfileData;
        }
        
        then analyzeProfile;
        
        action analyzeProfile {
            in profile : BeamProfileData;
            out diameter : BeamDiameter;
            out centroidX : LengthValue;
            out centroidY : LengthValue;
            out ellipticity : Real;
        }
        
        then outputResults;
        
        action outputResults {
            in analysisResults : BeamProfileData;
        }
        
        then decide;
            if checkMode.mode == MeasurementMode::continuous then checkMode;
            if checkMode.mode == MeasurementMode::triggered then done;
            if checkMode.mode == MeasurementMode::singleShot then done;
    }
    
    state def ProfilerStateMachine {
        in attribute systemState : SystemState;
        
        entry; then idle;
        
        state idle;
        accept calibrationRequest
        then calibrating;
        
        state calibrating;
        accept calibrationComplete
        then idle;
        
        accept measurementStart at idle
        then measuring;
        
        state measuring;
        accept measurementStop
        then processing;
        
        state processing;
        accept processingComplete
        then idle;
        
        accept errorDetected at measuring
        then errorState;
        
        state errorState;
        accept errorCleared
        then idle;
    }
    
    part def LaserBeamProfiler {
        attribute systemState : SystemState;
        attribute measurementMode : MeasurementMode;
        attribute maxBeamPower : PowerValue;
        attribute minBeamDiameter : BeamDiameter;
        attribute maxBeamDiameter : BeamDiameter;
        
        port opticalInput : OpticalInputPort;
        port dataOutput : ProfileDataPort;
        port controlInterface : ControlPort;
        
        part attenuator : OpticalAttenuator {
            attribute :>> attenuationFactor = 0.1;
            attribute :>> maxInputPower = 1000.0 [mW];
        }
        
        part splitter : BeamSplitter {
            attribute :>> splitRatio = 0.95;
        }
        
        part sensor : ImagingSensor {
            attribute :>> pixelCount = 1048576;
            attribute :>> pixelSize = 5.5e-6 [m];
            attribute :>> dynamicRange = 60.0;
            attribute :>> quantumEfficiency = 0.65;
        }
        
        part processor : SignalProcessor {
            attribute :>> processingSpeed = 100.0;
            attribute :>> bufferSize = 256;
        }
        
        part calibration : CalibrationUnit {
            attribute :>> calibrationValid = true;
        }
        
        part ui : UserInterface {
            attribute :>> displayResolution = 2073600;
        }
        
        connection opticalPath1 connect 
            opticalInput to attenuator.opticalIn;
        
        connection opticalPath2 connect 
            attenuator.opticalOut to splitter.opticalIn;
        
        connection opticalPath3 connect 
            splitter.opticalOut1 to sensor.opticalIn;
        
        connection dataPath1 connect 
            sensor.imageOut to processor.imageIn;
        
        connection dataPath2 connect 
            processor.profileOut to dataOutput;
        
        connection dataPath3 connect 
            processor.profileOut to ui.dataIn;
        
        connection controlPath connect 
            ui.controlOut to controlInterface;
        
        perform action measurementAction : MeasureBeamProfile {
            in currentMode = measurementMode;
        }
        
        exhibit state profilerBehavior : ProfilerStateMachine {
            in systemState = systemState;
        }
    }
    
    requirement <'REQ-001'> primaryFunction {
        doc /* The laser beam profiler shall accurately measure and characterize 
             * the spatial intensity distribution of incident laser beams, providing 
             * comprehensive profile data including beam diameter, centroid position, 
             * ellipticity, and intensity distribution across a range of wavelengths 
             * and power levels.
             */
        subject profiler : LaserBeamProfiler;
    }
    
    requirement <'REQ-002'> spatialResolution {
        doc /* The profiler shall provide spatial resolution of at least 5.5 micrometers 
             * to accurately capture fine beam profile details.
             */
        subject sensor :>> LaserBeamProfiler::sensor;
        
        assert constraint {
            sensor.pixelSize <= 5.5e-6 [m]
        }
    }
    
    requirement <'REQ-003'> measurementRate {
        doc /* The profiler shall support continuous measurement at frame rates 
             * sufficient for real-time beam monitoring and dynamic beam analysis.
             */
        subject profiler : LaserBeamProfiler;
    }
    
    requirement <'REQ-004'> powerProtection {
        doc /* The profiler shall include optical attenuation to protect the sensor 
             * from high-power laser beams exceeding 1000 mW.
             */
        subject attenuator :>> LaserBeamProfiler::attenuator;
        
        assert constraint {
            attenuator.maxInputPower >= 1000.0 [mW]
        }
    }
    
    requirement <'REQ-005'> dataOutput {
        doc /* The profiler shall output comprehensive beam profile data including 
             * beam diameter, centroid position, ellipticity, and full intensity distribution.
             */
        subject profiler : LaserBeamProfiler;
    }
    
    requirement <'REQ-006'> dynamicRange {
        doc /* The imaging sensor shall provide a dynamic range of at least 60 dB 
             * to accurately measure beams with varying intensity distributions.
             */
        subject sensor :>> LaserBeamProfiler::sensor;
        
        assert constraint {
            sensor.dynamicRange >= 60.0
        }
    }
    
    part profilerSystem : LaserBeamProfiler {
        attribute :>> systemState = SystemState::idle;
        attribute :>> measurementMode = MeasurementMode::continuous;
        attribute :>> maxBeamPower = 1000.0 [mW];
        attribute :>> minBeamDiameter = 10.0e-6 [m];
        attribute :>> maxBeamDiameter = 10.0e-3 [m];
    }
    
    satisfy primaryFunction by profilerSystem;
    satisfy spatialResolution by profilerSystem.sensor;
    satisfy measurementRate by profilerSystem;
    satisfy powerProtection by profilerSystem.attenuator;
    satisfy dataOutput by profilerSystem;
    satisfy dynamicRange by profilerSystem.sensor;
}
