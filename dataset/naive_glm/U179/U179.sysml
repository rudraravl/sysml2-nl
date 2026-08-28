package CancerVisionGoggles {
    public import ISQ::*;
    public import ScalarValues::*;

    // ===== Value Types =====
    value def Power :> Real { unit "W"; }
    value def Energy :> Real { unit "J"; }
    value def Voltage :> Real { unit "V"; }
    value def Current :> Real { unit "A"; }
    value def Wavelength :> Real { unit "nm"; }
    value def Frequency :> Real { unit "Hz"; }
    value def LuminousFlux :> Real { unit "lm"; }
    value def Duration :> Real { unit "s"; }
    value def Latency :> Real { unit "ms"; }
    value def Temperature :> Real { unit "degC"; }
    value def Mass :> Real { unit "kg"; }
    value def ConfidenceScore :> Real { unit "1"; }
    value def FrameRate :> Real { unit "fps"; }
    value def ResolutionWidth :> Integer;
    value def ResolutionHeight :> Integer;
    value def PixelCount :> Integer;
    value def MarginDistance :> Real { unit "mm"; }

    // ===== Item Types =====
    item def NIRLight;
    item def FluorescenceEmission;
    item def AmbientLight;
    item def RawVideoFrame;
    item def EnhancedVideoFrame;
    item def TumorDetectionResult {
        attribute confidence : ConfidenceScore;
        attribute margin : MarginDistance;
        attribute boundaryPolygon : String;
    }
    item def OverlayImage;
    item def CompositeVideoFrame;
    item def VisibleVideoFrame;
    item def CalibrationData;
    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def FluorescentDye;

    // ===== Port Definitions =====
    port def NIRLightOut { out item : NIRLight; }
    port def FluorescenceIn { in item : FluorescenceEmission; }
    port def AmbientLightIn { in item : AmbientLight; }
    port def VisibleLightIn { in item : AmbientLight; }
    port def RawVideoOut { out item : RawVideoFrame; }
    port def RawVideoIn { in item : RawVideoFrame; }
    port def EnhancedVideoOut { out item : EnhancedVideoFrame; }
    port def EnhancedVideoIn { in item : EnhancedVideoFrame; }
    port def DetectionResultOut { out item : TumorDetectionResult; }
    port def DetectionResultIn { in item : TumorDetectionResult; }
    port def OverlayOut { out item : OverlayImage; }
    port def OverlayIn { in item : OverlayImage; }
    port def VisibleVideoOut { out item : VisibleVideoFrame; }
    port def VisibleVideoIn { in item : VisibleVideoFrame; }
    port def CompositeVideoOut { out item : CompositeVideoFrame; }
    port def CompositeVideoIn { in item : CompositeVideoFrame; }
    port def PowerOut { out item : PowerSignal; }
    port def PowerIn { in item : PowerSignal; }
    port def CalibrationOut { out item : CalibrationData; }
    port def CalibrationIn { in item : CalibrationData; }

    // ===== Part Definitions =====

    part def BatteryPack {
        attribute nominalVoltage : Voltage = 12.0;
        attribute capacity : Energy = 120000.0;
        attribute maxRuntime : Duration = 14400.0;
        attribute chargeLevel : Real = 1.0;
        port powerOut : PowerOut;
        exhibit state batteryState {
            in entry action { send PowerSignal(voltage := nominalVoltage, current := 2.0) via powerOut; }
            state Charging;
            state Discharging {
                entry action { chargeLevel := chargeLevel - 0.0001; }
            }
            transition Charging to Discharging when chargeLevel >= 0.99;
            transition Discharging to Charging when chargeLevel <= 0.05;
        }
    }

    part def NIRLightSource {
        attribute wavelength : Wavelength = 780.0;
        attribute irradiance : Power = 5.0;
        attribute enabled : Boolean = false;
        port lightOut : NIRLightOut;
        port powerIn : PowerIn;
        exhibit state illuminationState {
            state Off;
            state On {
                entry action {
                    enabled := true;
                    send NIRLight() via lightOut;
                }
                do action { send NIRLight() via lightOut; }
            }
            transition Off to On when enabled;
            transition On to Off when !enabled;
        }
    }

    part def FluorescenceCamera {
        attribute resolutionW : ResolutionWidth = 1920;
        attribute resolutionH : ResolutionHeight = 1080;
        attribute frameRate : FrameRate = 60.0;
        attribute detectionWavelength : Wavelength = 820.0;
        attribute sensitivity : Real = 0.95;
        port fluorescenceIn : FluorescenceIn;
        port videoOut : RawVideoOut;
        port powerIn : PowerIn;
        exhibit state cameraState {
            state Idle;
            state Capturing {
                do action {
                    while true {
                        send RawVideoFrame() via videoOut;
                    }
                }
            }
            transition Idle to Capturing when true;
        }
    }

    part def VisibleLightCamera {
        attribute resolutionW : ResolutionWidth = 1920;
        attribute resolutionH : ResolutionHeight = 1080;
        attribute frameRate : FrameRate = 60.0;
        port lightIn : VisibleLightIn;
        port videoOut : VisibleVideoOut;
        port powerIn : PowerIn;
        exhibit state cameraState {
            state Idle;
            state Streaming {
                do action {
                    while true {
                        send VisibleVideoFrame() via videoOut;
                    }
                }
            }
            transition Idle to Streaming when true;
        }
    }

    part def ImageProcessingUnit {
        attribute enhancementGain : Real = 3.0;
        attribute noiseReductionLevel : Real = 0.8;
        attribute processingLatency : Latency = 8.0;
        port rawVideoIn : RawVideoIn;
        port enhancedVideoOut : EnhancedVideoOut;
        port powerIn : PowerIn;
        exhibit state processingState {
            state Inactive;
            state Enhancing {
                do action {
                    while true {
                        receive rawFrame : RawVideoFrame via rawVideoIn;
                        send EnhancedVideoFrame() via enhancedVideoOut;
                    }
                }
            }
            transition Inactive to Enhancing when true;
        }
    }

    part def TumorDetectionEngine {
        attribute modelVersion : String = "CancerNet-v3.1";
        attribute minConfidenceThreshold : ConfidenceScore = 0.75;
        attribute inferenceLatency : Latency = 12.0;
        port enhancedVideoIn : EnhancedVideoIn;
        port detectionResultOut : DetectionResultOut;
        port powerIn : PowerIn;
        exhibit state detectionState {
            state Standby;
            state Inferring {
                do action {
                    while true {
                        receive frame : EnhancedVideoFrame via enhancedVideoIn;
                        attribute detectedConfidence : ConfidenceScore = 0.0;
                        attribute detectedMargin : MarginDistance = 0.0;
                        send TumorDetectionResult(confidence := detectedConfidence, margin := detectedMargin, boundaryPolygon := "polygon") via detectionResultOut;
                    }
                }
            }
            transition Standby to Inferring when true;
        }
    }

    part def OverlayGenerator {
        attribute overlayColor : String = "red";
        attribute opacity : Real = 0.4;
        port detectionResultIn : DetectionResultIn;
        port overlayOut : OverlayOut;
        port powerIn : PowerIn;
        exhibit state overlayState {
            state Idle;
            state Generating {
                do action {
                    while true {
                        receive result : TumorDetectionResult via detectionResultIn;
                        send OverlayImage() via overlayOut;
                    }
                }
            }
            transition Idle to Generating when true;
        }
    }

    part def DisplayCompositor {
        attribute compositingLatency : Latency = 4.0;
        port visibleVideoIn : VisibleVideoIn;
        port overlayIn : OverlayIn;
        port compositeVideoOut : CompositeVideoOut;
        port powerIn : PowerIn;
        exhibit state compositingState {
            state Idle;
            state Compositing {
                do action {
                    while true {
                        receive visibleFrame : VisibleVideoFrame via visibleVideoIn;
                        receive overlay : OverlayImage via overlayIn;
                        send CompositeVideoFrame() via compositeVideoOut;
                    }
                }
            }
            transition Idle to Compositing when true;
        }
    }

    part def HeadMountedDisplay {
        attribute displayWidth : ResolutionWidth = 2560;
        attribute displayHeight : ResolutionHeight = 1440;
        attribute refreshRate : Frequency = 120.0;
        attribute fieldOfView : Real = 90.0;
        port compositeVideoIn : CompositeVideoIn;
        port powerIn : PowerIn;
        exhibit state displayState {
            state Blank;
            state Rendering {
                do action {
                    while true {
                        receive frame : CompositeVideoFrame via compositeVideoIn;
                    }
                }
            }
            transition Blank to Rendering when true;
        }
    }

    part def CalibrationModule {
        attribute calibrationAccuracy : Real = 0.98;
        attribute calibrationDuration : Duration = 30.0;
        port calibrationOut : CalibrationOut;
        port powerIn : PowerIn;
        exhibit state calibrationState {
            state Uncalibrated;
            state Calibrating {
                entry action { 
                    // Perform spatial and color calibration
                }
                do action {
                    wait calibrationDuration;
                    send CalibrationData() via calibrationOut;
                }
            }
            state Calibrated;
            transition Uncalibrated to Calibrating when true;
            transition Calibrating to Calibrated after calibrationDuration;
        }
    }

    part def PowerController {
        attribute totalPowerBudget : Power = 25.0;
        port powerIn : PowerIn;
        port powerOut : PowerOut;
        exhibit state powerState {
            state Active {
                do action {
                    while true {
                        receive pwr : PowerSignal via powerIn;
                        send PowerSignal(voltage := pwr.voltage, current := pwr.current) via powerOut;
                    }
                }
            }
        }
    }

    part def Surgeon {
        attribute name : String;
        port lineOfSight : CompositeVideoIn;
    }

    // ===== Top-level System =====
    part def CancerVisionGogglesSystem {
        attribute systemMass : Mass = 0.45;
        attribute operatingTemperature : Temperature = 37.0;
        attribute maxEndToEndLatency : Latency = 30.0;
        attribute firmwareVersion : String = "1.0.0";

        port surgicalFieldNIR : NIRLightOut;
        port surgicalFieldFluorescence : FluorescenceIn;
        port surgicalFieldVisible : VisibleLightIn;
        port surgeonView : CompositeVideoOut;

        part battery : BatteryPack;
        part powerController : PowerController;
        part nirSource : NIRLightSource;
        part fluorescenceCamera : FluorescenceCamera;
        part visibleCamera : VisibleLightCamera;
        part imageProcessor : ImageProcessingUnit;
        part tumorEngine : TumorDetectionEngine;
        part overlayGen : OverlayGenerator;
        part compositor : DisplayCompositor;
        part hmd : HeadMountedDisplay;
        part calibration : CalibrationModule;

        // Power distribution
        connect battery.powerOut to powerController.powerIn;
        connect powerController.powerOut to nirSource.powerIn;
        connect powerController.powerOut to fluorescenceCamera.powerIn;
        connect powerController.powerOut to visibleCamera.powerIn;
        connect powerController.powerOut to imageProcessor.powerIn;
        connect powerController.powerOut to tumorEngine.powerIn;
        connect powerController.powerOut to overlayGen.powerIn;
        connect powerController.powerOut to compositor.powerIn;
        connect powerController.powerOut to hmd.powerIn;
        connect powerController.powerOut to calibration.powerIn;

        // NIR illumination path
        connect nirSource.lightOut to surgicalFieldNIR;
        connect surgicalFieldFluorescence to fluorescenceCamera.fluorescenceIn;

        // Visible light path
        connect surgicalFieldVisible to visibleCamera.lightIn;

        // Video processing chain
        connect fluorescenceCamera.videoOut to imageProcessor.rawVideoIn;
        connect imageProcessor.enhancedVideoOut to tumorEngine.enhancedVideoIn;
        connect tumorEngine.detectionResultOut to overlayGen.detectionResultIn;
        connect overlayGen.overlayOut to compositor.overlayIn;
        connect visibleCamera.videoOut to compositor.visibleVideoIn;
        connect compositor.compositeVideoOut to hmd.compositeVideoIn;
        connect hmd.compositeVideoIn to surgeonView;

        // Calibration
        connect calibration.calibrationOut to overlayGen.powerIn;

        exhibit state systemOperatingMode {
            state Standby {
                entry action {
                    nirSource.enabled := false;
                }
            }
            state Calibration {
                entry action {
                    calibration.calibrationState.transition();
                }
            }
            state ActiveImaging {
                entry action {
                    nirSource.enabled := true;
                }
                do action {
                    // Continuous real-time augmented reality imaging
                }
            }
            state Fault {
                entry action {
                    nirSource.enabled := false;
                }
            }
            transition Standby to Calibration when true;
            transition Calibration to ActiveImaging when calibration.calibrationState.Calibrated.isActive;
            transition ActiveImaging to Standby when false;
            transition any to Fault when battery.chargeLevel <= 0.05;
            transition Fault to Standby when battery.chargeLevel >= 0.5;
        }
    }

    // ===== Requirements =====
    requirement def shallProvideNIRIllumination {
        doc /* The system shall illuminate the surgical field with NIR light to excite fluorescent dye in cancer cells. */
        attribute wavelength : Wavelength = 780.0;
        attribute minIrradiance : Power = 3.0;
        subject goggles : CancerVisionGogglesSystem;
        require goggles.nirSource.wavelength == wavelength;
        require goggles.nirSource.irradiance >= minIrradiance;
    }

    requirement def shallDetectFluorescence {
        doc /* The system shall detect fluorescence emissions from cancer cells. */
        attribute detectionWavelength : Wavelength = 820.0;
        attribute minSensitivity : Real = 0.90;
        subject goggles : CancerVisionGogglesSystem;
        require goggles.fluorescenceCamera.detectionWavelength == detectionWavelength;
        require goggles.fluorescenceCamera.sensitivity >= minSensitivity;
    }

    requirement def shallDetectTumorBoundaries {
        doc /* The system shall identify tumor boundaries and calculate resection margins in real time. */
        attribute minConfidence : ConfidenceScore = 0.75;
        attribute maxInferenceLatency : Latency = 15.0;
        subject goggles : CancerVisionGogglesSystem;
        require goggles.tumorEngine.minConfidenceThreshold >= minConfidence;
        require goggles.tumorEngine.inferenceLatency <= maxInferenceLatency;
    }

    requirement def shallProvideAROverlay {
        doc /* The system shall generate and display an augmented reality overlay highlighting cancerous regions. */
        subject goggles : CancerVisionGogglesSystem;
        require goggles.hmd.displayWidth >= 2560;
        require goggles.hmd.displayHeight >= 1440;
        require goggles.hmd.refreshRate >= 120.0;
    }

    requirement def shallOperateOnBattery {
        doc /* The system shall operate on battery power for several hours continuously. */
        attribute minRuntime : Duration = 10800.0;
        subject goggles : CancerVisionVisionGogglesSystem;
        require goggles.battery.maxRuntime >= minRuntime;
    }

    requirement def shallMeetLatencyBudget {
        doc /* The end-to-end latency from image capture to display shall be low enough for surgical use. */
        attribute maxLatency : Latency = 30.0;
        subject goggles : CancerVisionGogglesSystem;
        require goggles.maxEndToEndLatency <= maxLatency;
    }

    requirement def shallSupportOperatingModes {
        doc /* The system shall support standby, calibration, and active imaging modes. */
        subject goggles : CancerVisionGogglesSystem;
        require goggles.systemOperatingMode.Standby.occurrences() > 0;
        require goggles.systemOperatingMode.Calibration.occurrences() > 0;
        require goggles.systemOperatingMode.ActiveImaging.occurrences() > 0;
    }

    requirement CancerVisionRequirements {
        doc /* Top-level requirements for the CancerVision Goggles system. */
        satisfy shallProvideNIRIllumination by CancerVisionGogglesSystem;
        satisfy shallDetectFluorescence by CancerVisionGogglesSystem;
        satisfy shallDetectTumorBoundaries by CancerVisionGogglesSystem;
        satisfy shallProvideAROverlay by CancerVisionGogglesSystem;
        satisfy shallOperateOnBattery by CancerVisionGogglesSystem;
        satisfy shallMeetLatencyBudget by CancerVisionGogglesSystem;
        satisfy shallSupportOperatingModes by CancerVisionGogglesSystem;
    }
}
