package BorescopeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Length;
    attribute def Diameter;
    attribute def Angle;
    attribute def Temperature;
    attribute def Pressure;
    attribute def Voltage;
    attribute def Current;
    attribute def Power;
    attribute def LuminousFlux;
    attribute def FrameRate;
    attribute def DataRate;
    attribute def Resolution;
    attribute def Time;
    attribute def Force;
    attribute def Percent;

    item def OpticalImage {
        attribute widthPixels : Integer;
        attribute heightPixels : Integer;
        attribute frameRate : FrameRate;
        attribute fieldOfView : Angle;
        attribute timestamp : Time;
    }

    item def VideoStream {
        attribute resolutionWidth : Integer;
        attribute resolutionHeight : Integer;
        attribute frameRate : FrameRate;
        attribute encodedBitRate : DataRate;
        attribute latency : Time;
    }

    item def IlluminationCommand {
        attribute requestedBrightness : Percent;
    }

    item def ArticulationCommand {
        attribute bendAngle : Angle;
        attribute bendDirection : String;
    }

    item def CaptureCommand {
        attribute captureStillImage : Boolean;
        attribute recordVideo : Boolean;
    }

    item def InspectionReport {
        attribute inspectionId : String;
        attribute defectDetected : Boolean;
        attribute defectLocationFromTip : Length;
        attribute operatorNote : String;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def ControlSignal {
        attribute commandId : String;
        attribute commandValue : Real;
    }

    port def PowerInputPort {
        in item powerIn : ElectricalPower;
    }

    port def PowerOutputPort {
        out item powerOut : ElectricalPower;
    }

    port def VideoOutputPort {
        out item videoOut : VideoStream;
    }

    port def ImageInputPort {
        in item imageIn : OpticalImage;
    }

    port def ImageOutputPort {
        out item imageOut : OpticalImage;
    }

    port def CommandInputPort {
        in item illuminationCommand : IlluminationCommand;
        in item articulationCommand : ArticulationCommand;
        in item captureCommand : CaptureCommand;
    }

    port def CommandOutputPort {
        out item illuminationCommand : IlluminationCommand;
        out item articulationCommand : ArticulationCommand;
        out item captureCommand : CaptureCommand;
    }

    port def ReportOutputPort {
        out item reportOut : InspectionReport;
    }

    port def MechanicalAccessPort {
        inout attribute insertionDepth : Length;
        inout attribute tipOrientation : Angle;
        inout attribute insertionForce : Force;
    }

    port def LightOutputPort {
        out attribute luminousFlux : LuminousFlux;
        out attribute beamAngle : Angle;
    }

    port def LightInputPort {
        in attribute luminousFlux : LuminousFlux;
        in attribute beamAngle : Angle;
    }

    part def BorescopeSystem {
        attribute primaryFunction : String = "Provide remote visual inspection of inaccessible internal spaces by inserting a narrow optical probe, illuminating the target area, capturing images at the distal tip, and presenting live video and recorded evidence to an operator.";
        attribute maximumInsertionLength : Length = 2.0 [m];
        attribute probeOuterDiameter : Diameter = 6.0 [mm];
        attribute minimumBendRadius : Length = 30.0 [mm];
        attribute operatingTemperatureMin : Temperature = -10.0 [K];
        attribute operatingTemperatureMax : Temperature = 333.15 [K];
        attribute ingressProtectionRating : String = "IP67";
        attribute nominalPowerConsumption : Power = 12.0 [W];

        port powerInput : PowerInputPort;
        port operatorCommands : CommandInputPort;
        port liveVideo : VideoOutputPort;
        port inspectionReport : ReportOutputPort;
        port accessInterface : MechanicalAccessPort;

        part handle : OperatorHandle;
        part insertionTube : FlexibleInsertionTube;
        part distalTip : ImagingTipAssembly;
        part processor : ImageProcessingUnit;
        part display : DisplayAndRecorder;
        part powerSubsystem : PowerSubsystem;

        connection powerInput.powerIn to powerSubsystem.externalPower.powerIn;
        connection powerSubsystem.regulatedPower.powerOut to handle.power.powerIn;
        connection powerSubsystem.regulatedPower.powerOut to processor.power.powerIn;
        connection powerSubsystem.regulatedPower.powerOut to display.power.powerIn;
        connection powerSubsystem.regulatedPower.powerOut to distalTip.power.powerIn;

        connection operatorCommands.illuminationCommand to handle.commands.illuminationCommand;
        connection operatorCommands.articulationCommand to handle.commands.articulationCommand;
        connection operatorCommands.captureCommand to handle.commands.captureCommand;

        connection handle.tipCommands.illuminationCommand to distalTip.commands.illuminationCommand;
        connection handle.tipCommands.articulationCommand to insertionTube.articulationInput.articulationCommand;
        connection handle.captureCommands.captureCommand to display.captureInput.captureCommand;

        connection accessInterface to insertionTube.accessPort;
        connection insertionTube.tipMount to distalTip.mechanicalMount;

        connection distalTip.rawImage.imageOut to processor.rawImage.imageIn;
        connection processor.processedVideo.videoOut to display.videoInput.videoOut;
        connection display.externalVideo.videoOut to liveVideo.videoOut;
        connection display.report.reportOut to inspectionReport.reportOut;
    }

    part def OperatorHandle {
        attribute gripLength : Length = 155.0 [mm];
        attribute mass : Real = 0.42;
        attribute hasArticulationJoystick : Boolean = true;
        attribute hasCaptureButton : Boolean = true;
        attribute hasBrightnessControl : Boolean = true;

        port power : PowerInputPort;
        port commands : CommandInputPort;
        port tipCommands : CommandOutputPort;
        port captureCommands : CommandOutputPort;

        action relayOperatorCommands {
            in item requestedIllumination : IlluminationCommand;
            in item requestedArticulation : ArticulationCommand;
            in item requestedCapture : CaptureCommand;
            out item forwardedIllumination : IlluminationCommand;
            out item forwardedArticulation : ArticulationCommand;
            out item forwardedCapture : CaptureCommand;
        }
    }

    part def FlexibleInsertionTube {
        attribute length : Length = 1.5 [m];
        attribute outerDiameter : Diameter = 6.0 [mm];
        attribute workingLengthMarkingInterval : Length = 10.0 [mm];
        attribute maximumArticulationAngle : Angle = 160.0 [deg];
        attribute sheathMaterial : String = "Tungsten braided polymer jacket";
        attribute fluidResistance : String = "Water, light oil, and mild cleaning agents";

        port accessPort : MechanicalAccessPort;
        port articulationInput : CommandInputPort;
        port tipMount : MechanicalAccessPort;

        part articulationCableSet : ArticulationCableSet;
        part imageCable : DigitalImageCable;
        part powerCable : TipPowerCable;

        connection articulationInput.articulationCommand to articulationCableSet.commandInput.articulationCommand;

        action transmitTipArticulation {
            in item command : ArticulationCommand;
            out attribute resultingTipAngle : Angle;
        }
    }

    part def ArticulationCableSet {
        attribute cableCount : Integer = 4;
        attribute maximumTension : Force = 18.0 [N];
        attribute backlash : Angle = 2.0 [deg];

        port commandInput : CommandInputPort;

        action bendDistalTip {
            in item command : ArticulationCommand;
            out attribute achievedAngle : Angle;
        }
    }

    part def DigitalImageCable {
        attribute supportedDataRate : DataRate = 1.5;
        attribute shielded : Boolean = true;
    }

    part def TipPowerCable {
        attribute maximumCurrent : Current = 1.0 [A];
        attribute conductorResistance : Real = 0.25;
    }

    part def ImagingTipAssembly {
        attribute tipOuterDiameter : Diameter = 5.8 [mm];
        attribute tipLength : Length = 18.0 [mm];
        attribute fieldOfView : Angle = 90.0 [deg];
        attribute depthOfFieldNear : Length = 8.0 [mm];
        attribute depthOfFieldFar : Length = 80.0 [mm];
        attribute articulationAngle : Angle = 0.0 [deg];

        port power : PowerInputPort;
        port commands : CommandInputPort;
        port rawImage : ImageOutputPort;
        port mechanicalMount : MechanicalAccessPort;

        part camera : MiniatureCameraModule;
        part lens : ObjectiveLens;
        part illuminator : LedIlluminationRing;
        part temperatureSensor : TipTemperatureSensor;

        connection commands.illuminationCommand to illuminator.commandInput.illuminationCommand;
        connection illuminator.lightOut to lens.sceneLightInput;
        connection lens.focusedImage.imageOut to camera.opticalInput.imageIn;
        connection camera.digitalImage.imageOut to rawImage.imageOut;

        action captureRemoteImage {
            in attribute sceneIllumination : LuminousFlux;
            out item capturedImage : OpticalImage;
        }
    }

    part def MiniatureCameraModule {
        attribute sensorType : String = "CMOS";
        attribute widthPixels : Integer = 1280;
        attribute heightPixels : Integer = 720;
        attribute maximumFrameRate : FrameRate = 30.0;
        attribute minimumIllumination : LuminousFlux = 2.0 [lm];
        attribute operatingVoltage : Voltage = 5.0 [V];

        port power : PowerInputPort;
        port opticalInput : ImageInputPort;
        port digitalImage : ImageOutputPort;

        action convertPhotonsToDigitalImage {
            in item opticalImage : OpticalImage;
            out item digitalImage : OpticalImage;
        }
    }

    part def ObjectiveLens {
        attribute focalLength : Length = 1.9 [mm];
        attribute apertureNumber : Real = 2.8;
        attribute fieldOfView : Angle = 90.0 [deg];
        attribute focusMode : String = "Fixed focus";

        port sceneLightInput : LightInputPort;
        port focusedImage : ImageOutputPort;
    }

    part def LedIlluminationRing {
        attribute ledCount : Integer = 6;
        attribute maximumLuminousFlux : LuminousFlux = 120.0 [lm];
        attribute brightnessSetting : Percent = 60.0;
        attribute colorTemperature : Temperature = 5600.0 [K];
        attribute maximumPower : Power = 4.0 [W];

        port power : PowerInputPort;
        port commandInput : CommandInputPort;
        port lightOut : LightOutputPort;

        action regulateBrightness {
            in item command : IlluminationCommand;
            out attribute luminousFlux : LuminousFlux;
        }
    }

    part def TipTemperatureSensor {
        attribute measurementRangeMin : Temperature = 253.15 [K];
        attribute measurementRangeMax : Temperature = 373.15 [K];
        attribute accuracy : Temperature = 1.5 [K];

        action measureTipTemperature {
            out attribute measuredTemperature : Temperature;
        }
    }

    part def ImageProcessingUnit {
        attribute processorType : String = "Embedded video processor";
        attribute maximumInputResolutionWidth : Integer = 1920;
        attribute maximumInputResolutionHeight : Integer = 1080;
        attribute processingLatency : Time = 80.0 [ms];
        attribute supportsDefectEnhancement : Boolean = true;
        attribute supportsTimestampOverlay : Boolean = true;

        port power : PowerInputPort;
        port rawImage : ImageInputPort;
        port processedVideo : VideoOutputPort;

        action processImageStream {
            in item rawImage : OpticalImage;
            out item enhancedVideo : VideoStream;
        }

        action enhanceDefectVisibility {
            in item rawFrame : OpticalImage;
            out item enhancedFrame : OpticalImage;
        }
    }

    part def DisplayAndRecorder {
        attribute displayDiagonal : Length = 127.0 [mm];
        attribute displayResolutionWidth : Integer = 1280;
        attribute displayResolutionHeight : Integer = 720;
        attribute storageCapacity : Real = 64.0;
        attribute supportedRecordingFormat : String = "H.264 MP4";
        attribute maximumRecordingDuration : Time = 28800.0 [s];

        port power : PowerInputPort;
        port videoInput : VideoOutputPort;
        port captureInput : CommandInputPort;
        port externalVideo : VideoOutputPort;
        port report : ReportOutputPort;

        action displayLiveVideo {
            in item video : VideoStream;
        }

        action recordInspectionEvidence {
            in item video : VideoStream;
            in item command : CaptureCommand;
            out item report : InspectionReport;
        }
    }

    part def PowerSubsystem {
        attribute externalVoltageMin : Voltage = 9.0 [V];
        attribute externalVoltageMax : Voltage = 24.0 [V];
        attribute regulatedVoltage : Voltage = 5.0 [V];
        attribute batteryCapacity : Real = 38.0;
        attribute nominalRuntime : Time = 7200.0 [s];

        port externalPower : PowerInputPort;
        port regulatedPower : PowerOutputPort;

        part battery : RechargeableBattery;
        part regulator : VoltageRegulator;

        connection externalPower.powerIn to regulator.inputPower.powerIn;
        connection battery.batteryOutput.powerOut to regulator.inputPower.powerIn;
        connection regulator.outputPower.powerOut to regulatedPower.powerOut;
    }

    part def RechargeableBattery {
        attribute chemistry : String = "Lithium ion";
        attribute nominalVoltage : Voltage = 11.1 [V];
        attribute capacity : Real = 3.4;
        attribute maximumDischargeCurrent : Current = 3.0 [A];

        port batteryOutput : PowerOutputPort;
    }

    part def VoltageRegulator {
        attribute outputVoltage : Voltage = 5.0 [V];
        attribute maximumOutputCurrent : Current = 2.4 [A];
        attribute efficiency : Percent = 88.0;

        port inputPower : PowerInputPort;
        port outputPower : PowerOutputPort;
    }

    action def PerformBorescopeInspection {
        in item illuminationCommand : IlluminationCommand;
        in item articulationCommand : ArticulationCommand;
        in item captureCommand : CaptureCommand;
        out item liveVideo : VideoStream;
        out item report : InspectionReport;

        first startInspection;
        then insertProbe;
        then illuminateScene;
        then articulateTip;
        then acquireImage;
        then processVideo;
        then displayVideo;
        then recordEvidence;
        then completeInspection;

        action startInspection;
        action insertProbe;
        action illuminateScene;
        action articulateTip;
        action acquireImage;
        action processVideo;
        action displayVideo;
        action recordEvidence;
        action completeInspection;
    }

    state def BorescopeOperationalState {
        entry action initializeElectronics;
        exit action storeSessionMetadata;

        state Off;
        state SelfTest;
        state Ready;
        state Inserting;
        state Inspecting;
        state Recording;
        state Fault;
        state Shutdown;

        transition first Off then SelfTest
            accept PowerApplied;

        transition SelfTest then Ready
            accept SelfTestPassed;

        transition SelfTest then Fault
            accept SelfTestFailed;

        transition Ready then Inserting
            accept ProbeInsertionStarted;

        transition Inserting then Inspecting
            accept TargetAreaVisible;

        transition Inspecting then Recording
            accept RecordCommanded;

        transition Recording then Inspecting
            accept RecordStopped;

        transition Inspecting then Ready
            accept ProbeWithdrawn;

        transition Ready then Shutdown
            accept PowerRemoved;

        transition Inspecting then Fault
            accept OverTemperatureDetected;

        transition Recording then Fault
            accept StorageWriteFailure;

        transition Fault then Shutdown
            accept OperatorAcknowledgedFault;
    }

    requirement def PrimaryFunctionRequirement {
        subject borescope : BorescopeSystem;
        require constraint {
            borescope.primaryFunction == "Provide remote visual inspection of inaccessible internal spaces by inserting a narrow optical probe, illuminating the target area, capturing images at the distal tip, and presenting live video and recorded evidence to an operator."
        }
    }

    requirement def ProbeAccessRequirement {
        subject borescope : BorescopeSystem;
        require constraint {
            borescope.probeOuterDiameter <= 6.0 [mm] and
            borescope.maximumInsertionLength >= 1.5 [m]
        }
    }

    requirement def VideoPerformanceRequirement {
        subject processor : ImageProcessingUnit;
        require constraint {
            processor.maximumInputResolutionWidth >= 1280 and
            processor.maximumInputResolutionHeight >= 720 and
            processor.processingLatency <= 100.0 [ms]
        }
    }

    requirement def IlluminationRequirement {
        subject tip : ImagingTipAssembly;
        require constraint {
            tip.illuminator.maximumLuminousFlux >= 100.0 [lm]
        }
    }

    requirement def ArticulationRequirement {
        subject tube : FlexibleInsertionTube;
        require constraint {
            tube.maximumArticulationAngle >= 120.0 [deg]
        }
    }

    requirement def RuntimeRequirement {
        subject power : PowerSubsystem;
        require constraint {
            power.nominalRuntime >= 7200.0 [s]
        }
    }

    requirement def EnvironmentalRequirement {
        subject borescope : BorescopeSystem;
        require constraint {
            borescope.ingressProtectionRating == "IP67"
        }
    }

    satisfy PrimaryFunctionRequirement by BorescopeSystem;
    satisfy ProbeAccessRequirement by BorescopeSystem;
    satisfy VideoPerformanceRequirement by ImageProcessingUnit;
    satisfy IlluminationRequirement by ImagingTipAssembly;
    satisfy ArticulationRequirement by FlexibleInsertionTube;
    satisfy RuntimeRequirement by PowerSubsystem;
    satisfy EnvironmentalRequirement by BorescopeSystem;

    part borescope : BorescopeSystem;

    action inspectionUseCase : PerformBorescopeInspection;

}