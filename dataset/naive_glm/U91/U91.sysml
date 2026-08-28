package VeinFinderSystem {
    import ScalarValues::*;
    import ScalarFunctions::*;
    import ISQ::*;
    import ISQSpace::*;
    import ISQTime::*;
    import ISQElectricity::*;
    import ISQPower::*;

    // ---- Value Types ----
    attribute def Wavelength :> Real { unit 'nm'; }
    attribute def OpticalPower :> Real { unit 'mW'; }
    attribute def FrameRate :> Real { unit 'fps'; }
    attribute def BatteryCapacity :> Real { unit 'mAh'; }
    attribute def Duration :> Real { unit 'h'; }
    attribute def Voltage :> Real { unit 'V'; }
    attribute def Current :> Real { unit 'mA'; }
    attribute def Latency :> Real { unit 's'; }
    attribute def AlignmentError :> Real { unit 'mm'; }
    attribute def Contrast :> Real { unit '%'; }

    // ---- Item Types ----
    item def NIRLight {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
    }
    item def ReflectedNIRLight :> NIRLight {
        attribute reflectance : Real;
    }
    item def RawImageFrame {
        attribute width : Integer;
        attribute height : Integer;
        attribute contrast : Contrast;
        attribute timestamp : TimeValue;
    }
    item def ProcessedVeinMap {
        attribute confidence : Real;
        attribute veinCount : Integer;
        attribute timestamp : TimeValue;
    }
    item def ProjectedOverlay {
        attribute alignmentError : AlignmentError;
        attribute brightness : Real;
    }
    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    item def UserCommand {
        attribute commandKind : String;
    }
    item def FaultEvent {
        attribute faultCode : Integer;
        attribute description : String;
    }

    // ---- Port Definitions ----
    port def OpticalOutPort { out item : NIRLight; }
    port def OpticalInPort { in item : ReflectedNIRLight; }
    port def ImageOutPort { out item : RawImageFrame; }
    port def MapOutPort { out item : ProcessedVeinMap; }
    port def OverlayOutPort { out item : ProjectedOverlay; }
    port def PowerOutPort { out item : ElectricalEnergy; }
    port def CommandInPort { in item : UserCommand; }
    port def FaultOutPort { out item : FaultEvent; }

    // ---- NIR Illumination Module ----
    part def NIRIlluminationModule {
        attribute wavelength : Wavelength = 850;
        attribute ledCount : Integer = 6;
        attribute maxOpticalPower : OpticalPower = 5.0;
        attribute currentOutput : OpticalPower;
        attribute enabled : Boolean = false;

        port opticalOut : OpticalOutPort;
        port powerIn : PowerOutPort;
        port controlIn : CommandInPort;

        action def EmitNIRLight {
            in energy : ElectricalEnergy;
            out beam : NIRLight;
        }

        perform action emit : EmitNIRLight {
            when enabled;
        }

        action def RegulateOpticalPower {
            in measured : OpticalPower;
            out regulated : OpticalPower;
        }

        perform action regulate : RegulateOpticalPower;
    }

    // ---- NIR Camera Module ----
    part def NIRCameraModule {
        attribute frameRate : FrameRate = 30;
        attribute resolutionWidth : Integer = 640;
        attribute resolutionHeight : Integer = 480;
        attribute enabled : Boolean = false;

        port opticalIn : OpticalInPort;
        port imageOut : ImageOutPort;
        port powerIn : PowerOutPort;
        port controlIn : CommandInPort;

        action def CaptureFrame {
            in reflected : ReflectedNIRLight;
            out frame : RawImageFrame;
        }

        perform action capture : CaptureFrame {
            when enabled;
        }
    }

    // ---- Image Processing Unit ----
    part def ImageProcessingUnit {
        attribute processingLatency : Latency = 0.033;
        attribute enabled : Boolean = false;

        port imageIn : ImageOutPort;
        port mapOut : MapOutPort;
        port powerIn : PowerOutPort;
        port controlIn : CommandInPort;

        action def ProcessImage {
            in raw : RawImageFrame;
            out map : ProcessedVeinMap;
        }

        action def FilterNoise {
            in raw : RawImageFrame;
            out filtered : RawImageFrame;
        }

        action def EnhanceContrast {
            in filtered : RawImageFrame;
            out enhanced : RawImageFrame;
        }

        action def GenerateVeinMap {
            in enhanced : RawImageFrame;
            out map : ProcessedVeinMap;
        }

        perform action process : ProcessImage {
            when enabled;
            then action filter : FilterNoise;
            then action enhance : EnhanceContrast;
            then action generate : GenerateVeinMap;
        }
    }

    // ---- Projection Module ----
    part def ProjectionModule {
        attribute projectionColor : String = "green";
        attribute alignmentTolerance : AlignmentError = 1.5;
        attribute enabled : Boolean = false;

        port mapIn : MapOutPort;
        port overlayOut : OverlayOutPort;
        port powerIn : PowerOutPort;
        port controlIn : CommandInPort;

        action def ProjectOverlay {
            in map : ProcessedVeinMap;
            out overlay : ProjectedOverlay;
        }

        perform action project : ProjectOverlay {
            when enabled;
        }
    }

    // ---- Power Management System ----
    part def PowerManagementSystem {
        attribute batteryCapacity : BatteryCapacity = 2500;
        attribute minRuntime : Duration = 3.0;
        attribute outputVoltage : Voltage = 3.7;
        attribute chargeLevel : Real = 100;
        attribute enabled : Boolean = true;

        port powerOut : PowerOutPort;
        port controlIn : CommandInPort;

        state def BatteryState {
            entry; then Normal;
            state Normal {
                entry { chargeLevel >= 20; }
            }
            transition Normal to Low when chargeLevel < 20;
            state Low {
                entry { chargeLevel >= 5; }
            }
            transition Low to Critical when chargeLevel < 5;
            state Critical;
        }

        perform state batteryState : BatteryState;

        action def DistributePower {
            in source : ElectricalEnergy;
            out distributed : ElectricalEnergy;
        }

        perform action distribute : DistributePower;
    }

    // ---- System Controller ----
    part def SystemController {
        attribute selfCheckPassed : Boolean = false;
        attribute selfCheckFailed : Boolean = false;
        attribute scanTriggered : Boolean = false;
        attribute scanStopped : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute powerOff : Boolean = false;

        port commandIn : CommandInPort;
        port illuminationControl : CommandInPort;
        port cameraControl : CommandInPort;
        port processorControl : CommandInPort;
        port projectorControl : CommandInPort;
        port powerControl : CommandInPort;
        port faultOut : FaultOutPort;

        action def RunSelfCheck {
            out passed : Boolean;
            out failed : Boolean;
        }

        action def HandleUserCommand {
            in command : UserCommand;
            out triggerScan : Boolean;
            out stopScan : Boolean;
        }

        perform action selfCheck : RunSelfCheck;
        perform action handleCommand : HandleUserCommand;

        state def ControllerStateMachine {
            entry; then PowerOnSelfCheck;
            state PowerOnSelfCheck {
                entry { selfCheck.perform; }
            }
            transition PowerOnSelfCheck to Standby when selfCheckPassed;
            transition PowerOnSelfCheck to Error when selfCheckFailed;
            state Standby {
                entry {
                    illuminator.enabled = false;
                    camera.enabled = false;
                    processor.enabled = false;
                    projector.enabled = false;
                }
            }
            transition Standby to Scanning when scanTriggered;
            state Scanning {
                entry {
                    illuminator.enabled = true;
                    camera.enabled = true;
                    processor.enabled = true;
                    projector.enabled = true;
                }
                parallel IlluminationActive {
                    perform illuminator.emit;
                }
                parallel CameraActive {
                    perform camera.capture;
                }
                parallel ProcessingActive {
                    perform processor.process;
                }
                parallel ProjectionActive {
                    perform projector.project;
                }
            }
            transition Scanning to Standby when scanStopped;
            transition Scanning to Error when faultDetected;
            transition Standby to Error when faultDetected;
            state Error {
                entry {
                    illuminator.enabled = false;
                    projector.enabled = false;
                    faultOut.send(FaultEvent{faultCode = 1; description = "System fault detected";});
                }
            }
            transition Error to Off when powerOff;
            state Off {
                entry {
                    illuminator.enabled = false;
                    camera.enabled = false;
                    processor.enabled = false;
                    projector.enabled = false;
                    power.enabled = false;
                }
            }
        }

        perform state sm : ControllerStateMachine;
    }

    // ---- Top-Level Device ----
    part def VeinFinderDevice {
        attribute deviceName : String = "PortableNIRVeinFinder";
        attribute weight : Real = 0.35;
        attribute operatingTempMin : Temperature = 10;
        attribute operatingTempMax : Temperature = 40;

        part illuminator : NIRIlluminationModule;
        part camera : NIRCameraModule;
        part processor : ImageProcessingUnit;
        part projector : ProjectionModule;
        part power : PowerManagementSystem;
        part controller : SystemController;

        connection opticalPath from illuminator.opticalOut to camera.opticalIn;
        connection imageData from camera.imageOut to processor.imageIn;
        connection mapData from processor.mapOut to projector.mapIn;
        connection overlayProjection from projector.overlayOut to /* skin surface */ self;

        connection powerToIlluminator from power.powerOut to illuminator.powerIn;
        connection powerToCamera from power.powerOut to camera.powerIn;
        connection powerToProcessor from power.powerOut to processor.powerIn;
        connection powerToProjector from power.powerOut to projector.powerIn;

        connection controllerToIlluminator from controller.illuminationControl to illuminator.controlIn;
        connection controllerToCamera from controller.cameraControl to camera.controlIn;
        connection controllerToProcessor from controller.processorControl to processor.controlIn;
        connection controllerToProjector from controller.projectorControl to projector.controlIn;
        connection controllerToPower from controller.powerControl to power.controlIn;
    }

    // ---- Requirements ----
    requirement def PortableOperationRequirement {
        subject device : VeinFinderDevice;
        doc { "The device shall operate on battery power for at least 3 hours continuously on a single charge." }
        assume device.power.chargeLevel == 100;
        require device.power.minRuntime >= 3.0;
    }

    requirement def NIRIlluminationRequirement {
        subject illuminator : NIRIlluminationModule;
        doc { "The NIR illumination module shall emit near-infrared light at 850 nm with optical power not exceeding 5 mW." }
        require illuminator.wavelength == 850;
        require illuminator.maxOpticalPower <= 5.0;
    }

    requirement def CameraFrameRateRequirement {
        subject camera : NIRCameraModule;
        doc { "The NIR camera shall capture at least 30 frames per second to provide a live video feed." }
        require camera.frameRate >= 30;
    }

    requirement def RealTimeVisualizationRequirement {
        subject device : VeinFinderDevice;
        doc { "The device shall provide a real-time visual overlay of subcutaneous veins projected onto the skin." }
        require device.camera.frameRate >= 30;
        require device.processor.processingLatency <= 0.05;
        require device.projector.alignmentTolerance <= 2.0;
    }

    requirement def SafetyOpticalPowerRequirement {
        subject illuminator : NIRIlluminationModule;
        doc { "The optical power output shall remain within safe limits for patient exposure at all times." }
        require illuminator.maxOpticalPower <= 5.0;
        require illuminator.regulate.measured <= illuminator.maxOpticalPower;
    }

    requirement def ErrorHandlingRequirement {
        subject controller : SystemController;
        doc { "The system controller shall enter an error state upon detection of any fault and disable illumination and projection." }
        require controller.sm.Error.reached == true when controller.faultDetected;
        require controller.illuminator.enabled == false when controller.sm.Error.reached;
        require controller.projector.enabled == false when controller.sm.Error.reached;
    }

    requirement def ContinuousParallelCycleRequirement {
        subject device : VeinFinderDevice;
        doc { "During scanning, illumination, capture, processing, and projection shall operate in a continuous parallel cycle." }
        require device.controller.sm.Scanning.IlluminationActive.active == true when device.controller.sm.Scanning.active;
        require device.controller.sm.Scanning.CameraActive.active == true when device.controller.sm.Scanning.active;
        require device.controller.sm.Scanning.ProcessingActive.active == true when device.controller.sm.Scanning.active;
        require device.controller.sm.Scanning.ProjectionActive.active == true when device.controller.sm.Scanning.active;
    }

    requirement def VeinContrastEnhancementRequirement {
        subject processor : ImageProcessingUnit;
        doc { "The image processing unit shall filter noise and enhance contrast to produce a distinct digital vein map." }
        require processor.process.filter.active == true;
        require processor.process.enhance.active == true;
        require processor.process.generate.active == true;
    }

    requirement def SystemRequirements {
        subject device : VeinFinderDevice;
        requirement portableOperation : PortableOperationRequirement;
        requirement nirIllumination : NIRIlluminationRequirement;
        requirement cameraFrameRate : CameraFrameRateRequirement;
        requirement realTimeVisualization : RealTimeVisualizationRequirement;
        requirement safetyOpticalPower : SafetyOpticalPowerRequirement;
        requirement errorHandling : ErrorHandlingRequirement;
        requirement continuousParallelCycle : ContinuousParallelCycleRequirement;
        requirement veinContrastEnhancement : VeinContrastEnhancementRequirement;
    }
}
