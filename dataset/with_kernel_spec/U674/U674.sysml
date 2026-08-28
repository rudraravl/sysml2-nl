package FineGuidanceSensorModel {
    private import ScalarValues::*;
    private import ISQ::*;
    
    package Definitions {
        item def Starlight;
        item def RawSignal {
            attribute intensity : Real;
            attribute pixelData : Real;
        }
        item def ProcessedImage {
            attribute noiseLevel : Real;
            attribute pixelData : Real;
        }
        item def CentroidData {
            attribute x : Real;
            attribute y : Real;
        }
        item def MotionData {
            attribute rateX : Real;
            attribute rateY : Real;
        }
        item def GuidanceData {
            attribute angularPosition : Real;
            attribute angularRate : Real;
        }
        item def ReferenceStarData {
            attribute starId : String;
            attribute magnitude : Real;
        }
        item def ControlCommand;
        item def ThermalCommand;
        
        attribute def StartAcquisition;
        attribute def StarFound;
        attribute def LockAchieved;
        attribute def StartCalibration;
        attribute def ErrorDetected;
        attribute def Reset;
        
        port def OpticalOutPort {
            out starlight : Starlight;
        }
        port def OpticalInPort {
            in starlight : Starlight;
        }
        port def SignalOutPort {
            out rawSignal : RawSignal;
        }
        port def SignalInPort {
            in rawSignal : RawSignal;
        }
        port def DataOutPort {
            out guidanceData : GuidanceData;
        }
        port def ControlPort {
            in command : ControlCommand;
        }
        port def ThermalPort {
            in thermalCommand : ThermalCommand;
        }
        
        action def CaptureLight {
            in starlight : Starlight;
            out focusedLight : Starlight;
        }
        action def ConvertSignal {
            in starlight : Starlight;
            out rawSignal : RawSignal;
        }
        action def ProcessSignal {
            in rawSignal : RawSignal;
            out guidanceData : GuidanceData;
        }
        action def CalculateCentroid {
            in image : ProcessedImage;
            out centroid : CentroidData;
        }
        action def TrackMotion {
            in centroid : CentroidData;
            out motion : MotionData;
        }
        action def Calibrate;
        action def ProvideGuidance {
            out data : GuidanceData;
        }
        
        part def Mirror;
        part def FilterWheel {
            attribute currentWavelength : Real;
        }
        part def CentroidEngine {
            perform action calculateCentroid : CalculateCentroid;
        }
        part def MotionTracker {
            perform action trackMotion : TrackMotion;
        }
        part def ThermalController {
            attribute targetTemperature : Real;
        }
        part def ModeController;
        
        part def OpticalAssembly {
            port opticalIn : OpticalInPort;
            port opticalOut : OpticalOutPort;
            part primaryMirror : Mirror;
            part secondaryMirror : Mirror;
            part filterWheel : FilterWheel;
            perform action captureLight : CaptureLight;
        }
        
        part def PhotoDetector {
            port opticalIn : OpticalInPort;
            port signalOut : SignalOutPort;
            perform action convertSignal : ConvertSignal;
        }
        
        part def SignalProcessor {
            port signalIn : SignalInPort;
            port dataOut : DataOutPort;
            part centroidEngine : CentroidEngine;
            part motionTracker : MotionTracker;
            perform action processSignal : ProcessSignal;
        }
        
        part def CalibrationUnit {
            ref item referenceStars : ReferenceStarData[*];
            perform action calibrate : Calibrate;
        }
        
        part def ControlUnit {
            part thermalController : ThermalController;
            part modeController : ModeController;
        }
        
        part def FineGuidanceSensor {
            port opticalIn : OpticalInPort;
            port dataOut : DataOutPort;
            port controlIn : ControlPort;
            
            part opticalAssembly : OpticalAssembly;
            part photoDetector : PhotoDetector;
            part signalProcessor : SignalProcessor;
            part calibrationUnit : CalibrationUnit;
            part controlUnit : ControlUnit;
            
            perform action provideGuidance : ProvideGuidance;
            
            exhibit state fgsMode {
                entry; then standby;
                state standby;
                accept StartAcquisition then acquiring;
                state acquiring {
                    do opticalAssembly.captureLight;
                }
                accept StarFound then tracking;
                state tracking {
                    do signalProcessor.processSignal;
                }
                accept LockAchieved then measuring;
                state measuring {
                    do provideGuidance;
                }
                accept StartCalibration then selfCalibration;
                state selfCalibration {
                    do calibrationUnit.calibrate;
                }
                accept ErrorDetected then fault;
                state fault;
                accept Reset then standby;
            }
        }
        
        requirement def AccuracyRequirement {
            attribute subPixelAccuracy : Real = 0.01;
            doc /* The sensor must calculate the star centroid with sub-pixel accuracy. */
        }
        requirement def ThermalStabilityRequirement {
            attribute temperatureStability : Real = 0.1;
            doc /* The sensor must maintain a stable temperature for low-noise performance. */
        }
        requirement def LockRequirement {
            doc /* The sensor must lock onto a celestial object and provide angular position and rate data. */
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part fgs : FineGuidanceSensor {
            connection opticalInToAssembly connect opticalIn to opticalAssembly.opticalIn;
            connection opticalToDetector connect opticalAssembly.opticalOut to photoDetector.opticalIn;
            connection detectorToProcessor connect photoDetector.signalOut to signalProcessor.signalIn;
            connection processorToOut connect signalProcessor.dataOut to dataOut;
        }
        
        requirement accuracyReq : AccuracyRequirement;
        requirement thermalReq : ThermalStabilityRequirement;
        requirement lockReq : LockRequirement;
    }
}
