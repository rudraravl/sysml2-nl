package StaringArraySurveillanceSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        value def TemperatureK :> Real;
        value def FrameRate :> Real;
        value def SNR :> Real;
        value def ConfidenceLevel :> Real;
        value def PixelCount :> Integer;
        value def Wavelength :> Real;
        value def Intensity :> Real;

        item def RawImage {
            attribute width : PixelCount = 1920;
            attribute height : PixelCount = 1080;
            attribute pixelData : Real[0..*];
        }
        item def ProcessedImage {
            attribute width : PixelCount = 1920;
            attribute height : PixelCount = 1080;
            attribute enhancedData : Real[0..*];
            attribute noiseLevel : Real;
        }
        item def TargetReport {
            attribute targetId : String;
            attribute locationX : Real;
            attribute locationY : Real;
            attribute intensity : Intensity;
            attribute confidence : ConfidenceLevel;
            attribute sizePixels : PixelCount;
            attribute snr : SNR;
        }
        item def OperatorCommand {
            attribute commandType : String;
            attribute frameRateSetting : FrameRate;
        }
        item def HealthStatus {
            attribute componentId : String;
            attribute status : String;
            attribute temperature : TemperatureK;
        }

        attribute def StartCommand;
        attribute def StopCommand;
        attribute def Reset;
        attribute def CoolerFailure;
        attribute def FPAFailure;
        attribute def ProcessorFailure;
        attribute def DetectorFailure;

        action def CaptureImage {
            out rawImage : RawImage;
        }
        action def ProcessImage {
            in rawImage : RawImage;
            out processedImage : ProcessedImage;
        }
        action def DetectTargets {
            in processedImage : ProcessedImage;
            out reports : TargetReport[0..*];
        }
        action def CoolFPA {
            out currentTemp : TemperatureK;
        }
        action def MonitorHealth {
            out status : HealthStatus;
        }

        state def SystemStates;

        part def FocalPlaneArray {
            attribute resolutionWidth : PixelCount = 1920;
            attribute resolutionHeight : PixelCount = 1080;
            attribute operatingTemp : TemperatureK = 77;
            attribute spectralRangeMin : Wavelength = 3.0;
            attribute spectralRangeMax : Wavelength = 5.0;
            attribute currentTemp : TemperatureK;
            attribute maxTemp : TemperatureK = 85;
            out item rawImage : RawImage;
            perform action capture : CaptureImage;
        }

        part def CryogenicCooler {
            attribute targetTemp : TemperatureK = 77;
            attribute currentTemp : TemperatureK;
            attribute coolingRate : Real;
            perform action cool : CoolFPA;
        }

        part def ImageProcessor {
            attribute filterType : String = "spatial";
            attribute noiseReductionEnabled : Boolean = true;
            in item rawImage : RawImage;
            out item processedImage : ProcessedImage;
            perform action process : ProcessImage;
        }

        part def TargetDetectionUnit {
            attribute minSNR : SNR = 10.0;
            attribute minConfidence : ConfidenceLevel = 75.0;
            attribute minSize : PixelCount = 5;
            in item processedImage : ProcessedImage;
            out item reports : TargetReport[0..*];
            perform action detect : DetectTargets;
        }

        part def SystemController {
            attribute frameRate : FrameRate = 30.0;
            attribute mode : String;
            in item command : OperatorCommand;
            out item healthStatus : HealthStatus;
            perform action monitor : MonitorHealth;
        }

        part def StaringArraySensor {
            attribute fieldOfViewDeg : Real = 45.0;
            attribute fieldOfViewVerticalDeg : Real = 25.3;
            in item command : OperatorCommand;
            out item targetReports : TargetReport[0..*];
            out item healthStatus : HealthStatus;
            part fpa : FocalPlaneArray;
            part cooler : CryogenicCooler;
            part imageProcessor : ImageProcessor;
            part targetDetector : TargetDetectionUnit;
            part controller : SystemController;
        }
    }

    package Usages {
        private import Definitions::*;

        part surveillanceSystem : StaringArraySensor {
            flow command to controller.command;
            flow fpa.rawImage to imageProcessor.rawImage;
            flow imageProcessor.processedImage to targetDetector.processedImage;
            flow targetDetector.reports to targetReports;
            flow controller.healthStatus to healthStatus;

            state systemStates : SystemStates parallel {
                state operationalStates {
                    entry; then initialization;
                    state initialization {
                        do cooler.cool;
                    }
                    accept when cooler.currentTemp <= fpa.operatingTemp
                        then standby;
                    state standby {
                        do controller.monitor;
                    }
                    accept StartCommand
                        then activeSurveillance;
                    state activeSurveillance {
                        do fpa.capture;
                        do imageProcessor.process;
                        do targetDetector.detect;
                        do controller.monitor;
                    }
                    accept StopCommand
                        then standby;
                    accept CoolerFailure then fault;
                    accept FPAFailure then fault;
                    accept ProcessorFailure then fault;
                    accept DetectorFailure then fault;
                    state fault;
                    accept Reset then initialization;
                }
                state healthStates {
                    entry; then normal;
                    do controller.monitor;
                    state normal;
                    accept when cooler.currentTemp > fpa.maxTemp
                        then degraded;
                    accept CoolerFailure
                        then faulted;
                    accept FPAFailure
                        then faulted;
                    accept ProcessorFailure
                        then faulted;
                    accept DetectorFailure
                        then faulted;
                    state degraded;
                    accept when cooler.currentTemp <= fpa.operatingTemp
                        then normal;
                    state faulted;
                    accept Reset
                        then normal;
                }
            }
        }

        action captureImage : CaptureImage;
        action processImage : ProcessImage;
        action detectTargets : DetectTargets;
        action coolFPA : CoolFPA;
        action monitorHealth : MonitorHealth;
    }

    package Requirements {
        private import Definitions::*;
        private import Usages::*;

        requirement def SurveillanceRequirement {
            doc /* The staring array surveillance system shall automatically detect, locate, and characterize targets of interest within its fixed field of view. */
        }

        requirement def CryogenicTempRequirement {
            doc /* The FPA shall be maintained at 77 Kelvin by the cryogenic cooler during active surveillance operations. */
        }

        requirement def ResolutionRequirement {
            doc /* The FPA shall have a minimum resolution of 1920x1080 pixels. */
        }

        requirement def DetectionRequirement {
            doc /* The target detection unit shall identify targets with SNR above 10 dB, minimum size of 5 pixels, and confidence level above 75 percent. */
        }

        requirement def RealTimeRequirement {
            doc /* The system shall process from photon capture to target report generation in near real-time at a minimum frame rate of 30 Hz. */
        }

        requirement def MWIRRequirement {
            doc /* The FPA shall be sensitive to mid-wave infrared light in the 3.0 to 5.0 micrometer wavelength range. */
        }

        requirement surveillanceReq : SurveillanceRequirement {
            subject system : StaringArraySensor;
        }

        requirement cryoTempReq : CryogenicTempRequirement {
            subject system : StaringArraySensor;
        }

        requirement resolutionReq : ResolutionRequirement {
            subject system : StaringArraySensor;
        }

        requirement detectionReq : DetectionRequirement {
            subject system : StaringArraySensor;
        }

        requirement realTimeReq : RealTimeRequirement {
            subject system : StaringArraySensor;
        }

        requirement mwirReq : MWIRRequirement {
            subject system : StaringArraySensor;
        }

        satisfy surveillanceReq by surveillanceSystem;
        satisfy cryoTempReq by surveillanceSystem.cooler;
        satisfy resolutionReq by surveillanceSystem.fpa;
        satisfy detectionReq by surveillanceSystem.targetDetector;
        satisfy realTimeReq by surveillanceSystem.controller;
        satisfy mwirReq by surveillanceSystem.fpa;
    }
}
