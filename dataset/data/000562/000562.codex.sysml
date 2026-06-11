package CancerVisionGogglesModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Wavelength {
        :> ScalarValues::Real;
        unit = "nm";
    }

    attribute def OpticalPower {
        :> ScalarValues::Real;
        unit = "mW";
    }

    attribute def Irradiance {
        :> ScalarValues::Real;
        unit = "mW/cm^2";
    }

    attribute def FrameRate {
        :> ScalarValues::Real;
        unit = "Hz";
    }

    attribute def Latency {
        :> ScalarValues::Real;
        unit = "ms";
    }

    attribute def Confidence {
        :> ScalarValues::Real;
        range = "0..1";
    }

    attribute def TemperatureCelsius {
        :> ScalarValues::Real;
        unit = "degC";
    }

    attribute def BatteryCharge {
        :> ScalarValues::Real;
        unit = "percent";
        range = "0..100";
    }

    attribute def Mass {
        :> ScalarValues::Real;
        unit = "g";
    }

    attribute def Voltage {
        :> ScalarValues::Real;
        unit = "V";
    }

    attribute def Current {
        :> ScalarValues::Real;
        unit = "A";
    }

    attribute def DataRate {
        :> ScalarValues::Real;
        unit = "Mb/s";
    }

    item def ExcitationLight {
        attribute wavelength : Wavelength;
        attribute opticalPower : OpticalPower;
        attribute irradianceAtTissue : Irradiance;
        attribute modulationFrequency : FrameRate;
    }

    item def FluorescenceSignal {
        attribute emissionWavelength : Wavelength;
        attribute intensity : ScalarValues::Real;
        attribute exposureTime : ScalarValues::Real;
        attribute signalToNoiseRatio : ScalarValues::Real;
    }

    item def VisibleLightImage {
        attribute widthPixels : ScalarValues::Integer;
        attribute heightPixels : ScalarValues::Integer;
        attribute frameRate : FrameRate;
        attribute exposureTimeMs : Latency;
    }

    item def TissueClassificationMap {
        attribute widthPixels : ScalarValues::Integer;
        attribute heightPixels : ScalarValues::Integer;
        attribute tumorProbabilityMean : Confidence;
        attribute tumorBoundaryConfidence : Confidence;
        attribute generationLatency : Latency;
    }

    item def AugmentedDisplayFrame {
        attribute widthPixels : ScalarValues::Integer;
        attribute heightPixels : ScalarValues::Integer;
        attribute frameRate : FrameRate;
        attribute overlayOpacity : ScalarValues::Real;
        attribute displayLatency : Latency;
    }

    item def SurgeonCommand {
        attribute commandId : ScalarValues::String;
        attribute issuedAtMs : ScalarValues::Real;
    }

    item def SystemAlert {
        attribute severity : ScalarValues::String;
        attribute message : ScalarValues::String;
        attribute timestampMs : ScalarValues::Real;
    }

    item def PowerFlow {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute remainingCharge : BatteryCharge;
    }

    item def ThermalStatus {
        attribute processorTemperature : TemperatureCelsius;
        attribute illuminatorTemperature : TemperatureCelsius;
        attribute displayTemperature : TemperatureCelsius;
    }

    port def OpticalEmissionPort {
        out item excitation : ExcitationLight;
    }

    port def OpticalCollectionPort {
        in item fluorescence : FluorescenceSignal;
        in item visibleImage : VisibleLightImage;
    }

    port def ImageDataOutPort {
        out item visibleImage : VisibleLightImage;
        out item fluorescence : FluorescenceSignal;
    }

    port def AnalysisDataPort {
        in item visibleImage : VisibleLightImage;
        in item fluorescence : FluorescenceSignal;
        out item classificationMap : TissueClassificationMap;
    }

    port def DisplayInputPort {
        in item visibleImage : VisibleLightImage;
        in item classificationMap : TissueClassificationMap;
        out item displayFrame : AugmentedDisplayFrame;
    }

    port def UserControlPort {
        in item surgeonCommand : SurgeonCommand;
        out item alert : SystemAlert;
    }

    port def PowerPort {
        inout item power : PowerFlow;
    }

    port def ThermalPort {
        out item thermalStatus : ThermalStatus;
    }

    part def NearInfraredIlluminator {
        attribute centerWavelength : Wavelength = 785;
        attribute bandwidth : Wavelength = 10;
        attribute maximumOpticalPower : OpticalPower = 250;
        attribute nominalIrradianceAtTissue : Irradiance = 5;
        attribute modulationRate : FrameRate = 60;

        port opticalOut : OpticalEmissionPort;
        port powerIn : PowerPort;
        port thermalOut : ThermalPort;

        action def EmitExcitationLight {
            in desiredPower : OpticalPower;
            out excitation : ExcitationLight;
        }

        state def IlluminatorStateMachine {
            state off;
            state selfTest;
            state standby;
            state emitting;
            state fault;

            transition first off;
            transition off_to_selfTest first off then selfTest;
            transition selfTest_to_standby first selfTest then standby;
            transition standby_to_emitting first standby then emitting;
            transition emitting_to_standby first emitting then standby;
            transition emitting_to_fault first emitting then fault;
            transition fault_to_off first fault then off;
        }
    }

    part def MultispectralCamera {
        attribute visibleResolutionX : ScalarValues::Integer = 1920;
        attribute visibleResolutionY : ScalarValues::Integer = 1080;
        attribute fluorescenceResolutionX : ScalarValues::Integer = 1280;
        attribute fluorescenceResolutionY : ScalarValues::Integer = 1024;
        attribute nominalFrameRate : FrameRate = 60;
        attribute fluorescenceEmissionWavelength : Wavelength = 820;
        attribute minimumSignalToNoiseRatio : ScalarValues::Real = 12;

        port opticalIn : OpticalCollectionPort;
        port imageOut : ImageDataOutPort;
        port powerIn : PowerPort;
        port thermalOut : ThermalPort;

        action def CaptureVisibleAndFluorescence {
            in excitation : ExcitationLight;
            out visibleImage : VisibleLightImage;
            out fluorescence : FluorescenceSignal;
        }

        state def CameraStateMachine {
            state poweredOff;
            state calibratingDarkFrame;
            state ready;
            state acquiring;
            state degraded;
            state fault;

            transition first poweredOff;
            transition poweredOff_to_calibratingDarkFrame first poweredOff then calibratingDarkFrame;
            transition calibratingDarkFrame_to_ready first calibratingDarkFrame then ready;
            transition ready_to_acquiring first ready then acquiring;
            transition acquiring_to_ready first acquiring then ready;
            transition acquiring_to_degraded first acquiring then degraded;
            transition degraded_to_ready first degraded then ready;
            transition degraded_to_fault first degraded then fault;
        }
    }

    part def CancerVisionProcessor {
        attribute inferenceFrameRate : FrameRate = 30;
        attribute maximumInferenceLatency : Latency = 75;
        attribute tumorDetectionThreshold : Confidence = 0.72;
        attribute boundaryConfidenceThreshold : Confidence = 0.65;
        attribute modelVersion : ScalarValues::String = "CancerVision-NIR-Classifier-3.2";
        attribute processorMass : Mass = 85;

        port analysis : AnalysisDataPort;
        port powerIn : PowerPort;
        port thermalOut : ThermalPort;

        action def RegisterImages {
            in visibleImage : VisibleLightImage;
            in fluorescence : FluorescenceSignal;
            out registeredVisibleImage : VisibleLightImage;
            out registeredFluorescence : FluorescenceSignal;
        }

        action def ClassifyTissue {
            in registeredVisibleImage : VisibleLightImage;
            in registeredFluorescence : FluorescenceSignal;
            out classificationMap : TissueClassificationMap;
        }

        action def EstimateTumorBoundary {
            in classificationMap : TissueClassificationMap;
            out refinedClassificationMap : TissueClassificationMap;
        }

        action def GenerateCancerVisionMap {
            action register : RegisterImages;
            action classify : ClassifyTissue;
            action refine : EstimateTumorBoundary;

            flow register.registeredVisibleImage to classify.registeredVisibleImage;
            flow register.registeredFluorescence to classify.registeredFluorescence;
            flow classify.classificationMap to refine.classificationMap;
        }

        state def ProcessingStateMachine {
            state off;
            state loadingModel;
            state idle;
            state analyzing;
            state thermalThrottle;
            state fault;

            transition first off;
            transition off_to_loadingModel first off then loadingModel;
            transition loadingModel_to_idle first loadingModel then idle;
            transition idle_to_analyzing first idle then analyzing;
            transition analyzing_to_idle first analyzing then idle;
            transition analyzing_to_thermalThrottle first analyzing then thermalThrottle;
            transition thermalThrottle_to_analyzing first thermalThrottle then analyzing;
            transition thermalThrottle_to_fault first thermalThrottle then fault;
        }
    }

    part def AugmentedRealityDisplay {
        attribute resolutionX : ScalarValues::Integer = 1920;
        attribute resolutionY : ScalarValues::Integer = 1080;
        attribute refreshRate : FrameRate = 60;
        attribute maximumDisplayLatency : Latency = 25;
        attribute nominalOverlayOpacity : ScalarValues::Real = 0.55;
        attribute brightnessNits : ScalarValues::Real = 900;

        port displayIn : DisplayInputPort;
        port powerIn : PowerPort;
        port thermalOut : ThermalPort;

        action def RenderOverlay {
            in visibleImage : VisibleLightImage;
            in classificationMap : TissueClassificationMap;
            out displayFrame : AugmentedDisplayFrame;
        }

        state def DisplayStateMachine {
            state off;
            state initializing;
            state clearView;
            state overlayView;
            state alertView;
            state fault;

            transition first off;
            transition off_to_initializing first off then initializing;
            transition initializing_to_clearView first initializing then clearView;
            transition clearView_to_overlayView first clearView then overlayView;
            transition overlayView_to_clearView first overlayView then clearView;
            transition overlayView_to_alertView first overlayView then alertView;
            transition alertView_to_overlayView first alertView then overlayView;
            transition alertView_to_fault first alertView then fault;
        }
    }

    part def SurgeonInterface {
        attribute supportsVoiceCommands : ScalarValues::Boolean = true;
        attribute supportsSterileTouchpad : ScalarValues::Boolean = true;
        attribute supportsFootSwitch : ScalarValues::Boolean = true;

        port controls : UserControlPort;
        port powerIn : PowerPort;

        action def InterpretCommand {
            in rawCommand : SurgeonCommand;
            out validatedCommand : SurgeonCommand;
        }
    }

    part def BatteryPowerModule {
        attribute nominalVoltage : Voltage = 14.8;
        attribute capacityWh : ScalarValues::Real = 98;
        attribute minimumOperatingCharge : BatteryCharge = 15;
        attribute maximumContinuousCurrent : Current = 8;
        attribute moduleMass : Mass = 420;

        port powerOut : PowerPort;
        port user : UserControlPort;

        action def SupplyRegulatedPower {
            out power : PowerFlow;
        }

        state def PowerStateMachine {
            state disconnected;
            state booting;
            state supplying;
            state lowBattery;
            state shutdown;
            state fault;

            transition first disconnected;
            transition disconnected_to_booting first disconnected then booting;
            transition booting_to_supplying first booting then supplying;
            transition supplying_to_lowBattery first supplying then lowBattery;
            transition lowBattery_to_shutdown first lowBattery then shutdown;
            transition supplying_to_fault first supplying then fault;
        }
    }

    part def ThermalManagementModule {
        attribute maximumProcessorTemperature : TemperatureCelsius = 70;
        attribute maximumIlluminatorTemperature : TemperatureCelsius = 55;
        attribute maximumDisplayTemperature : TemperatureCelsius = 50;
        attribute fanNoiseLimitDba : ScalarValues::Real = 35;

        port thermalInFromIlluminator : ThermalPort;
        port thermalInFromCamera : ThermalPort;
        port thermalInFromProcessor : ThermalPort;
        port thermalInFromDisplay : ThermalPort;
        port user : UserControlPort;

        action def MonitorThermalStatus {
            in illuminatorThermal : ThermalStatus;
            in cameraThermal : ThermalStatus;
            in processorThermal : ThermalStatus;
            in displayThermal : ThermalStatus;
            out alert : SystemAlert;
        }
    }

    part def SterileGoggleFrame {
        attribute totalMassWithoutBattery : Mass = 620;
        attribute interpupillaryDistanceMinMm : ScalarValues::Real = 54;
        attribute interpupillaryDistanceMaxMm : ScalarValues::Real = 74;
        attribute ingressProtectionRating : ScalarValues::String = "IP54";
        attribute sterilizableDrapeCompatible : ScalarValues::Boolean = true;

        part illuminator : NearInfraredIlluminator;
        part camera : MultispectralCamera;
        part processor : CancerVisionProcessor;
        part display : AugmentedRealityDisplay;
        part controls : SurgeonInterface;
        part thermalManager : ThermalManagementModule;
    }

    part def CancerVisionGoggles {
        attribute systemMassWithBattery : Mass = 1040;
        attribute primaryFunction : ScalarValues::String = "Provide real-time augmented visualization of suspected cancerous tissue boundaries during surgery by combining near-infrared fluorescence imaging, visible-light imaging, onboard tissue classification, and heads-up overlay display.";
        attribute endToEndOverlayLatency : Latency = 120;
        attribute operatingTimeMinutes : ScalarValues::Real = 150;
        attribute minimumTumorBoundaryConfidence : Confidence = 0.65;
        attribute targetDetectionSensitivity : ScalarValues::Real = 0.92;
        attribute targetDetectionSpecificity : ScalarValues::Real = 0.88;

        part frame : SterileGoggleFrame;
        part battery : BatteryPowerModule;

        port surgeonControls : UserControlPort;
        port emittedLight : OpticalEmissionPort;
        port collectedOptics : OpticalCollectionPort;

        connection powerToIlluminator connect battery.powerOut to frame.illuminator.powerIn;
        connection powerToCamera connect battery.powerOut to frame.camera.powerIn;
        connection powerToProcessor connect battery.powerOut to frame.processor.powerIn;
        connection powerToDisplay connect battery.powerOut to frame.display.powerIn;
        connection powerToControls connect battery.powerOut to frame.controls.powerIn;

        connection illuminationPath connect frame.illuminator.opticalOut to emittedLight;
        connection collectionPath connect collectedOptics to frame.camera.opticalIn;

        connection imageToProcessor connect frame.camera.imageOut to frame.processor.analysis;
        connection processorToDisplay connect frame.processor.analysis to frame.display.displayIn;

        connection userCommandPath connect surgeonControls to frame.controls.controls;
        connection batteryAlertPath connect battery.user to surgeonControls;
        connection thermalAlertPath connect frame.thermalManager.user to surgeonControls;

        connection illuminatorThermalMonitor connect frame.illuminator.thermalOut to frame.thermalManager.thermalInFromIlluminator;
        connection cameraThermalMonitor connect frame.camera.thermalOut to frame.thermalManager.thermalInFromCamera;
        connection processorThermalMonitor connect frame.processor.thermalOut to frame.thermalManager.thermalInFromProcessor;
        connection displayThermalMonitor connect frame.display.thermalOut to frame.thermalManager.thermalInFromDisplay;

        action def PerformCancerVisionOperation {
            action emit : NearInfraredIlluminator::EmitExcitationLight;
            action capture : MultispectralCamera::CaptureVisibleAndFluorescence;
            action analyze : CancerVisionProcessor::GenerateCancerVisionMap;
            action render : AugmentedRealityDisplay::RenderOverlay;

            flow emit.excitation to capture.excitation;
            flow capture.visibleImage to analyze.register.visibleImage;
            flow capture.fluorescence to analyze.register.fluorescence;
            flow analyze.refine.refinedClassificationMap to render.classificationMap;
            flow capture.visibleImage to render.visibleImage;
        }

        state def SystemStateMachine {
            state poweredOff;
            state booting;
            state selfTest;
            state calibration;
            state ready;
            state imaging;
            state overlayActive;
            state lowBattery;
            state overTemperature;
            state degradedImaging;
            state fault;
            state shutdown;

            transition first poweredOff;
            transition poweredOff_to_booting first poweredOff then booting;
            transition booting_to_selfTest first booting then selfTest;
            transition selfTest_to_calibration first selfTest then calibration;
            transition calibration_to_ready first calibration then ready;
            transition ready_to_imaging first ready then imaging;
            transition imaging_to_overlayActive first imaging then overlayActive;
            transition overlayActive_to_imaging first overlayActive then imaging;
            transition overlayActive_to_lowBattery first overlayActive then lowBattery;
            transition overlayActive_to_overTemperature first overlayActive then overTemperature;
            transition overlayActive_to_degradedImaging first overlayActive then degradedImaging;
            transition degradedImaging_to_overlayActive first degradedImaging then overlayActive;
            transition overTemperature_to_shutdown first overTemperature then shutdown;
            transition lowBattery_to_shutdown first lowBattery then shutdown;
            transition imaging_to_fault first imaging then fault;
            transition fault_to_shutdown first fault then shutdown;
            transition shutdown_to_poweredOff first shutdown then poweredOff;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The CancerVision Goggles shall provide the surgeon with a real-time heads-up visualization that highlights suspected cancerous tissue and estimated tumor boundaries over the direct surgical field of view. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.endToEndOverlayLatency <= 120 and
            goggles.minimumTumorBoundaryConfidence >= 0.65
        }
    }

    requirement def ImagingRequirement {
        doc /* The system shall acquire synchronized visible-light and near-infrared fluorescence imagery while illuminating tissue at a controlled near-infrared wavelength suitable for tumor-marker fluorescence excitation. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.frame.camera.nominalFrameRate >= 30 and
            goggles.frame.illuminator.centerWavelength >= 760 and
            goggles.frame.illuminator.centerWavelength <= 810 and
            goggles.frame.illuminator.nominalIrradianceAtTissue <= 10
        }
    }

    requirement def OverlayLatencyRequirement {
        doc /* The system shall render the cancer visualization overlay with sufficiently low latency to support hand-guided surgical navigation. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.endToEndOverlayLatency <= 120 and
            goggles.frame.processor.maximumInferenceLatency <= 75 and
            goggles.frame.display.maximumDisplayLatency <= 25
        }
    }

    requirement def DetectionPerformanceRequirement {
        doc /* The tissue classification function shall meet target sensitivity and specificity for supported fluorescent tumor markers under calibrated operating conditions. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.targetDetectionSensitivity >= 0.90 and
            goggles.targetDetectionSpecificity >= 0.85
        }
    }

    requirement def WearabilityRequirement {
        doc /* The wearable system shall remain light enough for continuous surgical use during a typical procedure. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.systemMassWithBattery <= 1100 and
            goggles.frame.totalMassWithoutBattery <= 700
        }
    }

    requirement def BatteryOperationRequirement {
        doc /* The goggles shall support untethered operation for a complete surgical imaging session. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.operatingTimeMinutes >= 120 and
            goggles.battery.capacityWh >= 90 and
            goggles.battery.minimumOperatingCharge >= 10
        }
    }

    requirement def ThermalSafetyRequirement {
        doc /* The system shall monitor heat-generating components and alert the surgeon before component temperatures exceed safe operating limits. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.frame.thermalManager.maximumProcessorTemperature <= 70 and
            goggles.frame.thermalManager.maximumIlluminatorTemperature <= 55 and
            goggles.frame.thermalManager.maximumDisplayTemperature <= 50
        }
    }

    requirement def SurgicalUsabilityRequirement {
        doc /* The surgeon shall be able to toggle overlay display, adjust overlay opacity, and acknowledge alerts using sterile-compatible controls without breaking line of sight. */
        subject goggles : CancerVisionGoggles;
        require constraint {
            goggles.frame.controls.supportsVoiceCommands == true and
            goggles.frame.controls.supportsSterileTouchpad == true and
            goggles.frame.display.nominalOverlayOpacity >= 0.30 and
            goggles.frame.display.nominalOverlayOpacity <= 0.80
        }
    }

    satisfy PrimaryFunctionSatisfaction by CancerVisionGoggles satisfies PrimaryFunctionRequirement;
    satisfy ImagingSatisfaction by CancerVisionGoggles::frame::camera satisfies ImagingRequirement;
    satisfy IlluminationSatisfaction by CancerVisionGoggles::frame::illuminator satisfies ImagingRequirement;
    satisfy OverlayLatencySatisfaction by CancerVisionGoggles::frame::processor satisfies OverlayLatencyRequirement;
    satisfy DisplayLatencySatisfaction by CancerVisionGoggles::frame::display satisfies OverlayLatencyRequirement;
    satisfy BatterySatisfaction by CancerVisionGoggles::battery satisfies BatteryOperationRequirement;
    satisfy ThermalSatisfaction by CancerVisionGoggles::frame::thermalManager satisfies ThermalSafetyRequirement;
    satisfy UsabilitySatisfaction by CancerVisionGoggles::frame::controls satisfies SurgicalUsabilityRequirement;

}