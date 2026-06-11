package EndoscopeSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def LengthValue {
        value : Real;
        unit : LengthUnit;
    }

    attribute def AngleValue {
        value : Real;
        unit : PlaneAngleUnit;
    }

    attribute def TemperatureValue {
        value : Real;
        unit : TemperatureUnit;
    }

    attribute def PressureValue {
        value : Real;
        unit : PressureUnit;
    }

    attribute def FlowRateValue {
        value : Real;
        unit : VolumeFlowRateUnit;
    }

    attribute def PowerValue {
        value : Real;
        unit : PowerUnit;
    }

    attribute def VoltageValue {
        value : Real;
        unit : ElectricPotentialUnit;
    }

    attribute def ResolutionValue {
        horizontalPixels : Integer;
        verticalPixels : Integer;
    }

    item def TissueImageFrame {
        attribute timestamp_s : Real;
        attribute resolution : ResolutionValue;
        attribute frameRate_Hz : Real;
        attribute colorDepth_bits : Integer;
    }

    item def IlluminationCommand {
        attribute requestedIntensity_percent : Real;
        attribute requestedColorTemperature_K : Real;
    }

    item def IrrigationFluid {
        attribute fluidType : String;
        attribute temperature : TemperatureValue;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }

    item def SuctionFlow {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    item def InsertionForce {
        attribute axialForce_N : Real;
        attribute bendingMoment_Nm : Real;
    }

    item def OperatorCommand {
        attribute commandName : String;
        attribute commandValue : Real;
    }

    item def PatientTissueContact {
        attribute contactDetected : Boolean;
        attribute contactForce_N : Real;
    }

    port def OpticalImageOutPort {
        out item imageFrame : TissueImageFrame;
    }

    port def LightOutPort {
        out item lightCommand : IlluminationCommand;
    }

    port def FluidOutPort {
        out item irrigation : IrrigationFluid;
    }

    port def SuctionInPort {
        in item suction : SuctionFlow;
    }

    port def CommandInPort {
        in item command : OperatorCommand;
    }

    port def ForceSenseOutPort {
        out item insertionForce : InsertionForce;
        out item tissueContact : PatientTissueContact;
    }

    port def PowerInPort {
        in attribute supplyVoltage : VoltageValue;
        in attribute supplyPower : PowerValue;
    }

    part def Endoscope {
        attribute insertionTubeLength : LengthValue;
        attribute insertionTubeDiameter : LengthValue;
        attribute distalTipBendAngle : AngleValue;
        attribute distalTipTemperature : TemperatureValue;
        attribute sterile : Boolean;
        attribute powered : Boolean;
        attribute imagingActive : Boolean;

        port powerInput : PowerInPort;
        port operatorInput : CommandInPort;
        port imageOutput : OpticalImageOutPort;
        port illuminationOutput : LightOutPort;
        port irrigationOutput : FluidOutPort;
        port suctionInput : SuctionInPort;
        port forceFeedback : ForceSenseOutPort;

        part insertionTube : InsertionTube;
        part distalTip : DistalTip;
        part imagingSubsystem : ImagingSubsystem;
        part illuminationSubsystem : IlluminationSubsystem;
        part workingChannel : WorkingChannel;
        part controlHandle : ControlHandle;
        part processingUnit : VideoProcessingUnit;

        connect powerInput to processingUnit.powerInput;
        connect operatorInput to controlHandle.operatorInput;
        connect controlHandle.imagingCommandOutput to imagingSubsystem.commandInput;
        connect controlHandle.lightCommandOutput to illuminationSubsystem.commandInput;
        connect imagingSubsystem.rawImageOutput to processingUnit.rawImageInput;
        connect processingUnit.processedImageOutput to imageOutput;
        connect illuminationSubsystem.lightOutput to illuminationOutput;
        connect workingChannel.irrigationOutput to irrigationOutput;
        connect suctionInput to workingChannel.suctionInput;
        connect insertionTube.forceFeedback to forceFeedback;

        perform action InspectInternalAnatomy;
        exhibit state EndoscopeOperationalStates;
    }

    part def InsertionTube {
        attribute outerDiameter : LengthValue;
        attribute usableLength : LengthValue;
        attribute minimumBendRadius : LengthValue;
        attribute torsionalStiffness_NmPerRad : Real;

        port forceFeedback : ForceSenseOutPort;

        part articulationSection : ArticulationSection;
        part protectiveSheath : ProtectiveSheath;

        connect articulationSection.forceFeedback to forceFeedback;
    }

    part def ArticulationSection {
        attribute maxUpAngle : AngleValue;
        attribute maxDownAngle : AngleValue;
        attribute maxLeftAngle : AngleValue;
        attribute maxRightAngle : AngleValue;
        attribute currentPitchAngle : AngleValue;
        attribute currentYawAngle : AngleValue;

        port forceFeedback : ForceSenseOutPort;
    }

    part def ProtectiveSheath {
        attribute biocompatible : Boolean;
        attribute leakTight : Boolean;
        attribute surfaceRoughness_um : Real;
    }

    part def DistalTip {
        attribute tipDiameter : LengthValue;
        attribute windowTemperature : TemperatureValue;
        attribute lensFieldOfView : AngleValue;

        part objectiveLens : ObjectiveLens;
        part lightWindow : LightWindow;
        part cameraSensor : CameraSensor;
        part channelExit : ChannelExit;
    }

    part def ObjectiveLens {
        attribute focalLength : LengthValue;
        attribute fieldOfView : AngleValue;
        attribute antiFogCoated : Boolean;
    }

    part def LightWindow {
        attribute transmission_percent : Real;
        attribute scratchResistant : Boolean;
    }

    part def CameraSensor {
        attribute resolution : ResolutionValue;
        attribute frameRate_Hz : Real;
        attribute lowLightSensitivity_lux : Real;
        attribute sensorTemperature : TemperatureValue;

        port rawImageOutput : OpticalImageOutPort;
    }

    part def ChannelExit {
        attribute exitDiameter : LengthValue;
    }

    part def ImagingSubsystem {
        attribute active : Boolean;
        attribute targetFrameRate_Hz : Real;
        attribute exposureTime_ms : Real;

        port commandInput : CommandInPort;
        port rawImageOutput : OpticalImageOutPort;

        part camera : CameraSensor;
        part lens : ObjectiveLens;

        connect camera.rawImageOutput to rawImageOutput;
    }

    part def IlluminationSubsystem {
        attribute active : Boolean;
        attribute intensity_percent : Real;
        attribute colorTemperature_K : Real;
        attribute thermalLimit : TemperatureValue;

        port commandInput : CommandInPort;
        port lightOutput : LightOutPort;

        part ledSource : LedLightSource;
        part lightGuide : FiberOpticLightGuide;
    }

    part def LedLightSource {
        attribute electricalPower : PowerValue;
        attribute luminousFlux_lm : Real;
        attribute colorTemperature_K : Real;
        attribute maxCaseTemperature : TemperatureValue;
    }

    part def FiberOpticLightGuide {
        attribute length : LengthValue;
        attribute transmissionEfficiency_percent : Real;
        attribute minimumBendRadius : LengthValue;
    }

    part def WorkingChannel {
        attribute innerDiameter : LengthValue;
        attribute channelLength : LengthValue;
        attribute compatibleInstrumentDiameter : LengthValue;

        port irrigationOutput : FluidOutPort;
        port suctionInput : SuctionInPort;

        part irrigationPath : IrrigationPath;
        part suctionPath : SuctionPath;

        connect irrigationPath.irrigationOutput to irrigationOutput;
        connect suctionInput to suctionPath.suctionInput;
    }

    part def IrrigationPath {
        attribute maxFlowRate : FlowRateValue;
        attribute maxPressure : PressureValue;

        port irrigationOutput : FluidOutPort;
    }

    part def SuctionPath {
        attribute nominalVacuumPressure : PressureValue;
        attribute maxFlowRate : FlowRateValue;

        port suctionInput : SuctionInPort;
    }

    part def ControlHandle {
        attribute gripDiameter : LengthValue;
        attribute angulationLocked : Boolean;
        attribute imageCaptureRequested : Boolean;

        port operatorInput : CommandInPort;
        port imagingCommandOutput : CommandInPort;
        port lightCommandOutput : CommandInPort;

        part angulationKnob : AngulationKnob;
        part imageButton : ImageCaptureButton;
        part lightButton : IlluminationButton;
        part channelValve : ChannelValve;
    }

    part def AngulationKnob {
        attribute pitchRequest_deg : Real;
        attribute yawRequest_deg : Real;
        attribute lockEnabled : Boolean;
    }

    part def ImageCaptureButton {
        attribute pressed : Boolean;
    }

    part def IlluminationButton {
        attribute pressed : Boolean;
        attribute intensityStep_percent : Real;
    }

    part def ChannelValve {
        attribute suctionEnabled : Boolean;
        attribute irrigationEnabled : Boolean;
    }

    part def VideoProcessingUnit {
        attribute powered : Boolean;
        attribute imageEnhancementEnabled : Boolean;
        attribute whiteBalanceEnabled : Boolean;
        attribute outputLatency_ms : Real;

        port powerInput : PowerInPort;
        port rawImageInput : OpticalImageOutPort;
        port processedImageOutput : OpticalImageOutPort;
    }

    action def InspectInternalAnatomy {
        in item operatorCommand : OperatorCommand;
        in item patientContact : PatientTissueContact;
        out item displayedImage : TissueImageFrame;

        first start;
        then prepareEndoscope;
        then insertDistalTip;
        then illuminateTarget;
        then captureImage;
        then processImage;
        then displayImage;
        then supportTherapyIfRequested;
        then withdrawEndoscope;
        then finish;

        action prepareEndoscope {
            out attribute ready : Boolean;
        }

        action insertDistalTip {
            in item force : InsertionForce;
            out attribute insertionDepth_mm : Real;
        }

        action illuminateTarget {
            in item command : IlluminationCommand;
            out attribute illuminated : Boolean;
        }

        action captureImage {
            out item rawFrame : TissueImageFrame;
        }

        action processImage {
            in item rawFrame : TissueImageFrame;
            out item enhancedFrame : TissueImageFrame;
        }

        action displayImage {
            in item enhancedFrame : TissueImageFrame;
            out item displayedImage : TissueImageFrame;
        }

        action supportTherapyIfRequested {
            in item command : OperatorCommand;
            inout item irrigation : IrrigationFluid;
            inout item suction : SuctionFlow;
        }

        action withdrawEndoscope {
            out attribute removed : Boolean;
        }
    }

    state def EndoscopeOperationalStates {
        entry;
        then Off;

        state Off;
        state PowerOnSelfTest;
        state Ready;
        state Inserted;
        state Imaging;
        state Irrigating;
        state Suctioning;
        state Fault;
        state ReprocessingRequired;

        transition Off_to_POST
            first Off
            accept OperatorCommand
            if commandName == "PowerOn"
            then PowerOnSelfTest;

        transition POST_to_Ready
            first PowerOnSelfTest
            if powered == true and sterile == true
            then Ready;

        transition Ready_to_Inserted
            first Ready
            accept OperatorCommand
            if commandName == "Insert"
            then Inserted;

        transition Inserted_to_Imaging
            first Inserted
            accept OperatorCommand
            if commandName == "StartImaging"
            then Imaging;

        transition Imaging_to_Irrigating
            first Imaging
            accept OperatorCommand
            if commandName == "Irrigate"
            then Irrigating;

        transition Irrigating_to_Imaging
            first Irrigating
            accept OperatorCommand
            if commandName == "StopIrrigation"
            then Imaging;

        transition Imaging_to_Suctioning
            first Imaging
            accept OperatorCommand
            if commandName == "Suction"
            then Suctioning;

        transition Suctioning_to_Imaging
            first Suctioning
            accept OperatorCommand
            if commandName == "StopSuction"
            then Imaging;

        transition Imaging_to_Inserted
            first Imaging
            accept OperatorCommand
            if commandName == "StopImaging"
            then Inserted;

        transition Inserted_to_ReprocessingRequired
            first Inserted
            accept OperatorCommand
            if commandName == "Withdraw"
            then ReprocessingRequired;

        transition Any_to_Fault
            first Off, PowerOnSelfTest, Ready, Inserted, Imaging, Irrigating, Suctioning
            if distalTipTemperature.value > 41.0
            then Fault;

        transition Fault_to_Off
            first Fault
            accept OperatorCommand
            if commandName == "PowerOff"
            then Off;
    }

    requirement def PrimaryFunctionRequirement {
        subject endoscope : Endoscope;

        doc /* The endoscope shall enable a clinician to inspect internal anatomy by entering a natural or surgical access path, illuminating tissue, capturing real-time images at the distal tip, transmitting the images to a processing unit, and providing visual output for diagnosis or procedure guidance. */

        require constraint {
            endoscope.imagingActive == true implies
            endoscope.processingUnit.outputLatency_ms <= 150.0
        }
    }

    requirement def IlluminationRequirement {
        subject endoscope : Endoscope;

        doc /* The endoscope shall provide controlled illumination at the distal tip sufficient for tissue visualization without exceeding patient-contact thermal limits. */

        require constraint {
            endoscope.illuminationSubsystem.intensity_percent >= 5.0 and
            endoscope.illuminationSubsystem.intensity_percent <= 100.0 and
            endoscope.distalTipTemperature.value <= 41.0
        }
    }

    requirement def ImagingRequirement {
        subject endoscope : Endoscope;

        doc /* The endoscope shall produce real-time color image frames for clinical viewing. */

        require constraint {
            endoscope.imagingSubsystem.targetFrameRate_Hz >= 30.0 and
            endoscope.distalTip.cameraSensor.resolution.horizontalPixels >= 1920 and
            endoscope.distalTip.cameraSensor.resolution.verticalPixels >= 1080
        }
    }

    requirement def InsertionRequirement {
        subject endoscope : Endoscope;

        doc /* The endoscope insertion tube shall be narrow, flexible, and steerable enough to navigate the intended anatomical passage. */

        require constraint {
            endoscope.insertionTube.outerDiameter.value <= 12.0 and
            endoscope.insertionTube.articulationSection.currentPitchAngle.value <=
            endoscope.insertionTube.articulationSection.maxUpAngle.value
        }
    }

    requirement def WorkingChannelRequirement {
        subject endoscope : Endoscope;

        doc /* The endoscope shall support irrigation and suction through a working channel while maintaining image-guided operation. */

        require constraint {
            endoscope.workingChannel.innerDiameter.value >= 2.0 and
            endoscope.workingChannel.irrigationPath.maxFlowRate.value >= 20.0 and
            endoscope.workingChannel.suctionPath.maxFlowRate.value >= 15.0
        }
    }

    requirement def SterilityRequirement {
        subject endoscope : Endoscope;

        doc /* The endoscope shall not be used for patient insertion unless it is sterile or has completed validated reprocessing. */

        require constraint {
            endoscope.sterile == true
        }
    }

    part endoscopeSystem : Endoscope {
        attribute insertionTubeLength = LengthValue { value = 1000.0; unit = mm; }
        attribute insertionTubeDiameter = LengthValue { value = 9.8; unit = mm; }
        attribute distalTipBendAngle = AngleValue { value = 180.0; unit = deg; }
        attribute distalTipTemperature = TemperatureValue { value = 37.0; unit = K; }
        attribute sterile = true;
        attribute powered = false;
        attribute imagingActive = false;

        part insertionTube {
            attribute outerDiameter = LengthValue { value = 9.8; unit = mm; }
            attribute usableLength = LengthValue { value = 1000.0; unit = mm; }
            attribute minimumBendRadius = LengthValue { value = 35.0; unit = mm; }
            attribute torsionalStiffness_NmPerRad = 0.18;

            part articulationSection {
                attribute maxUpAngle = AngleValue { value = 180.0; unit = deg; }
                attribute maxDownAngle = AngleValue { value = 180.0; unit = deg; }
                attribute maxLeftAngle = AngleValue { value = 160.0; unit = deg; }
                attribute maxRightAngle = AngleValue { value = 160.0; unit = deg; }
                attribute currentPitchAngle = AngleValue { value = 0.0; unit = deg; }
                attribute currentYawAngle = AngleValue { value = 0.0; unit = deg; }
            }

            part protectiveSheath {
                attribute biocompatible = true;
                attribute leakTight = true;
                attribute surfaceRoughness_um = 0.4;
            }
        }

        part distalTip {
            attribute tipDiameter = LengthValue { value = 10.2; unit = mm; }
            attribute windowTemperature = TemperatureValue { value = 37.0; unit = K; }
            attribute lensFieldOfView = AngleValue { value = 140.0; unit = deg; }

            part objectiveLens {
                attribute focalLength = LengthValue { value = 1.4; unit = mm; }
                attribute fieldOfView = AngleValue { value = 140.0; unit = deg; }
                attribute antiFogCoated = true;
            }

            part lightWindow {
                attribute transmission_percent = 92.0;
                attribute scratchResistant = true;
            }

            part cameraSensor {
                attribute resolution = ResolutionValue { horizontalPixels = 1920; verticalPixels = 1080; }
                attribute frameRate_Hz = 60.0;
                attribute lowLightSensitivity_lux = 0.8;
                attribute sensorTemperature = TemperatureValue { value = 38.0; unit = K; }
            }

            part channelExit {
                attribute exitDiameter = LengthValue { value = 2.8; unit = mm; }
            }
        }

        part imagingSubsystem {
            attribute active = false;
            attribute targetFrameRate_Hz = 60.0;
            attribute exposureTime_ms = 8.0;
        }

        part illuminationSubsystem {
            attribute active = false;
            attribute intensity_percent = 55.0;
            attribute colorTemperature_K = 5600.0;
            attribute thermalLimit = TemperatureValue { value = 41.0; unit = K; }

            part ledSource {
                attribute electricalPower = PowerValue { value = 8.0; unit = W; }
                attribute luminousFlux_lm = 650.0;
                attribute colorTemperature_K = 5600.0;
                attribute maxCaseTemperature = TemperatureValue { value = 60.0; unit = K; }
            }

            part lightGuide {
                attribute length = LengthValue { value = 1100.0; unit = mm; }
                attribute transmissionEfficiency_percent = 78.0;
                attribute minimumBendRadius = LengthValue { value = 25.0; unit = mm; }
            }
        }

        part workingChannel {
            attribute innerDiameter = LengthValue { value = 2.8; unit = mm; }
            attribute channelLength = LengthValue { value = 1100.0; unit = mm; }
            attribute compatibleInstrumentDiameter = LengthValue { value = 2.4; unit = mm; }

            part irrigationPath {
                attribute maxFlowRate = FlowRateValue { value = 30.0; unit = ml / s; }
                attribute maxPressure = PressureValue { value = 40.0; unit = kPa; }
            }

            part suctionPath {
                attribute nominalVacuumPressure = PressureValue { value = -55.0; unit = kPa; }
                attribute maxFlowRate = FlowRateValue { value = 25.0; unit = ml / s; }
            }
        }

        part controlHandle {
            attribute gripDiameter = LengthValue { value = 34.0; unit = mm; }
            attribute angulationLocked = false;
            attribute imageCaptureRequested = false;

            part angulationKnob {
                attribute pitchRequest_deg = 0.0;
                attribute yawRequest_deg = 0.0;
                attribute lockEnabled = false;
            }

            part imageButton {
                attribute pressed = false;
            }

            part lightButton {
                attribute pressed = false;
                attribute intensityStep_percent = 10.0;
            }

            part channelValve {
                attribute suctionEnabled = false;
                attribute irrigationEnabled = false;
            }
        }

        part processingUnit {
            attribute powered = false;
            attribute imageEnhancementEnabled = true;
            attribute whiteBalanceEnabled = true;
            attribute outputLatency_ms = 80.0;
        }
    }

    satisfy PrimaryFunctionRequirement by endoscopeSystem;
    satisfy IlluminationRequirement by endoscopeSystem;
    satisfy ImagingRequirement by endoscopeSystem;
    satisfy InsertionRequirement by endoscopeSystem;
    satisfy WorkingChannelRequirement by endoscopeSystem;
    satisfy SterilityRequirement by endoscopeSystem;
}