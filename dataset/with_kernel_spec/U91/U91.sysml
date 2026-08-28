package NIRVeinFinderSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def WavelengthValue :> ISQ::LengthValue;
    attribute def FrameRateValue :> ISQ::FrequencyValue;
    attribute def OpticalPowerValue :> ISQ::PowerValue;
    attribute def IrradianceValue :> ISQ::IrradianceValue;
    attribute def DurationValue :> ISQ::TimeValue;
    attribute def BatteryCapacityValue :> ISQ::ElectricChargeValue;
    
    item def NIRLight {
        attribute wavelength : WavelengthValue;
        attribute power : OpticalPowerValue;
    }
    item def ReflectedLight;
    item def RawImage {
        attribute frameRate : FrameRateValue;
    }
    item def VeinMap;
    item def VisibleLight;
    item def ElectricalPower;
    
    attribute def PowerOnSignal;
    attribute def PowerOffSignal;
    attribute def StartScanSignal;
    attribute def StopScanSignal;
    attribute def FaultSignal;
    attribute def ResetSignal;
    
    requirement def VeinVisualizationRequirement {
        doc /* The device shall provide a real-time visual map of subcutaneous veins projected onto the skin. */
    }
    requirement def NIRWavelengthRequirement {
        doc /* The NIR illumination module shall emit light at a wavelength of 850 nm. */
    }
    requirement def FrameRateRequirement {
        doc /* The NIR camera module shall capture images at 30 frames per second. */
    }
    requirement def BatteryLifeRequirement {
        doc /* The device shall run continuously for over 3 hours on a single charge. */
    }
    requirement def SafetyRequirement {
        doc /* The system shall manage optical power output and enter an error state upon fault detection. */
    }
    requirement def AlignmentRequirement {
        doc /* The projected vein map shall be accurately aligned with the actual position of veins. */
    }
    
    action def PerformSelfCheck {
        action checkIllumination;
        action checkCamera;
        action checkProcessor;
        action checkProjector;
        action checkPower;
        first start;
        then checkIllumination;
        then checkCamera;
        then checkProcessor;
        then checkProjector;
        then checkPower;
        then done;
    }
    
    action def EmitNIRLight {
        out light : NIRLight;
    }
    action def CaptureImage {
        in light : ReflectedLight;
        out image : RawImage;
    }
    action def ProcessImage {
        in raw : RawImage;
        out map : VeinMap;
        action filterNoise;
        action boostContrast;
        action generateVeinMap;
        first start;
        then filterNoise;
        then boostContrast;
        then generateVeinMap;
        then done;
    }
    action def ProjectVeinMap {
        in map : VeinMap;
        out light : VisibleLight;
    }
    action def RegulateOpticalPower {
        out actualPower : OpticalPowerValue;
        action measurePower;
        action compareWithLimit;
        action adjustCurrent;
        first start;
        then measurePower;
        then compareWithLimit;
        then adjustCurrent;
        then done;
    }
    action def ShutdownComponents;
    action def SupplyPower {
        out power : ElectricalPower;
    }
    
    part def PatientSkin {
        port nirIn : NIRLight;
        port visibleIn : VisibleLight;
        port reflectedOut : ReflectedLight;
    }
    
    part def NIRIlluminationModule {
        port nirOut : NIRLight;
        port powerIn : ElectricalPower;
        port controlIn : StartScanSignal;
        port statusOut : FaultSignal;
        attribute wavelength : WavelengthValue = 850.0;
        attribute maxPower : OpticalPowerValue = 5.0;
        attribute maxSafeIrradiance : IrradianceValue;
        part leds[8];
        perform action emitNIRLight : EmitNIRLight {
            out light : NIRLight = nirOut;
        }
        perform action regulateOutput : RegulateOpticalPower;
    }
    
    part def NIRCameraModule {
        port lightIn : ReflectedLight;
        port imageOut : RawImage;
        port powerIn : ElectricalPower;
        port controlIn : StartScanSignal;
        port statusOut : FaultSignal;
        attribute frameRate : FrameRateValue = 30.0;
        perform action captureImage : CaptureImage {
            in light : ReflectedLight = lightIn;
            out image : RawImage = imageOut;
        }
    }
    
    part def ImageProcessingUnit {
        port imageIn : RawImage;
        port mapOut : VeinMap;
        port powerIn : ElectricalPower;
        port statusOut : FaultSignal;
        perform action processImage : ProcessImage {
            in raw : RawImage = imageIn;
            out map : VeinMap = mapOut;
        }
    }
    
    part def ProjectionModule {
        port mapIn : VeinMap;
        port lightOut : VisibleLight;
        port powerIn : ElectricalPower;
        port controlIn : StartScanSignal;
        port statusOut : FaultSignal;
        perform action projectVeinMap : ProjectVeinMap {
            in map : VeinMap = mapIn;
            out light : VisibleLight = lightOut;
        }
    }
    
    part def PowerManagementSystem {
        port powerOut : ElectricalPower;
        port statusOut : FaultSignal;
        attribute batteryLife : DurationValue = 3.5;
        attribute batteryCapacity : BatteryCapacityValue;
        perform action supplyPower : SupplyPower {
            out power : ElectricalPower = powerOut;
        }
    }
    
    part def UserControlPanel {
        port scanOut : StartScanSignal;
        port stopOut : StopScanSignal;
        port powerOnOut : PowerOnSignal;
        port powerOffOut : PowerOffSignal;
        port resetOut : ResetSignal;
        part scanButton;
        part stopButton;
        part powerButton;
        part resetButton;
    }
    
    part def SystemController {
        port powerIn : ElectricalPower;
        port scanIn : StartScanSignal;
        port stopIn : StopScanSignal;
        port powerOnIn : PowerOnSignal;
        port powerOffIn : PowerOffSignal;
        port faultIn : FaultSignal;
        port resetIn : ResetSignal;
        port illumCtrlOut : StartScanSignal;
        port cameraCtrlOut : StartScanSignal;
        port projectorCtrlOut : StartScanSignal;
        
        perform action selfTest : PerformSelfCheck;
        perform action shutdownComponents : ShutdownComponents;
    }
    
    part def NIRVeinFinder {
        part illuminator : NIRIlluminationModule;
        part camera : NIRCameraModule;
        part processor : ImageProcessingUnit;
        part projector : ProjectionModule;
        part powerSystem : PowerManagementSystem;
        part controller : SystemController;
        part controlPanel : UserControlPanel;
        part skin : PatientSkin;
        part housing;
        part opticalWindow;
        
        satisfy VeinVisualizationRequirement;
        satisfy NIRWavelengthRequirement;
        satisfy FrameRateRequirement;
        satisfy BatteryLifeRequirement;
        satisfy SafetyRequirement;
        satisfy AlignmentRequirement;
        
        exhibit state operationalStates {
            entry; then off;
            state off;
            accept PowerOnSignal via controlPanel.powerOnOut
                do controller.selfTest
                then standby;
            state standby;
            accept StartScanSignal via controlPanel.scanOut
                then scanning;
            state scanning parallel {
                state illuminationState {
                    do illuminator.emitNIRLight;
                }
                state cameraState {
                    do camera.captureImage;
                }
                state processingState {
                    do processor.processImage;
                }
                state projectionState {
                    do projector.projectVeinMap;
                }
            }
            accept StopScanSignal via controlPanel.stopOut
                then standby;
            accept FaultSignal via illuminator.statusOut
                do controller.shutdownComponents
                then error;
            state error;
            accept ResetSignal via controlPanel.resetOut
                then standby;
            accept PowerOffSignal via controlPanel.powerOffOut
                then done;
        }
        
        connect controlPanel.powerOnOut to controller.powerOnIn;
        connect controlPanel.powerOffOut to controller.powerOffIn;
        connect controlPanel.scanOut to controller.scanIn;
        connect controlPanel.stopOut to controller.stopIn;
        connect controlPanel.resetOut to controller.resetIn;
        
        connect controller.illumCtrlOut to illuminator.controlIn;
        connect controller.cameraCtrlOut to camera.controlIn;
        connect controller.projectorCtrlOut to projector.controlIn;
        
        connect illuminator.nirOut to skin.nirIn;
        connect skin.reflectedOut to camera.lightIn;
        connect camera.imageOut to processor.imageIn;
        connect processor.mapOut to projector.mapIn;
        connect projector.lightOut to skin.visibleIn;
        
        connect powerSystem.powerOut to illuminator.powerIn;
        connect powerSystem.powerOut to camera.powerIn;
        connect powerSystem.powerOut to processor.powerIn;
        connect powerSystem.powerOut to projector.powerIn;
        connect powerSystem.powerOut to controller.powerIn;
        
        connect illuminator.statusOut to controller.faultIn;
        connect camera.statusOut to controller.faultIn;
        connect processor.statusOut to controller.faultIn;
        connect projector.statusOut to controller.faultIn;
        connect powerSystem.statusOut to controller.faultIn;
    }
}
