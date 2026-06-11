package FiberscopeSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def LengthValue :> ISQ::length;
    attribute def MassValue :> ISQ::mass;
    attribute def TimeValue :> ISQ::time;
    attribute def PowerValue :> ISQ::power;
    attribute def ElectricPotentialValue :> ISQ::electricPotential;
    attribute def TemperatureValue :> ISQ::thermodynamicTemperature;
    attribute def IlluminanceValue;
    attribute def PixelCount;
    attribute def BendAngleValue;
    attribute def ImageFrameRate;

    enum def InspectionMode {
        enum idle;
        enum visualSurvey;
        enum closeInspection;
        enum imageCapture;
        enum videoRecording;
        enum withdrawal;
        enum fault;
    }

    enum def SterilityState {
        enum sterile;
        enum clean;
        enum contaminated;
    }

    enum def ScopeHealth {
        enum nominal;
        enum degradedIllumination;
        enum fiberDamageDetected;
        enum articulationFault;
        enum overheating;
        enum powerFault;
    }

    item def ElectricalEnergy {
        attribute voltage : ElectricPotentialValue;
        attribute power : PowerValue;
    }

    item def OpticalIllumination {
        attribute illuminance : IlluminanceValue;
        attribute wavelength : LengthValue;
        attribute adjustable : Boolean;
    }

    item def ReflectedImageLight {
        attribute fieldOfView : BendAngleValue;
        attribute depthOfField : LengthValue;
        attribute spectralBandStart : LengthValue;
        attribute spectralBandEnd : LengthValue;
    }

    item def ImageFrame {
        attribute widthPixels : PixelCount;
        attribute heightPixels : PixelCount;
        attribute frameRate : ImageFrameRate;
        attribute timestamp : TimeValue;
    }

    item def ControlCommand {
        attribute requestedMode : InspectionMode;
        attribute illuminationLevelPercent : Real;
        attribute articulationUpDown : BendAngleValue;
        attribute articulationLeftRight : BendAngleValue;
        attribute captureStill : Boolean;
        attribute recordVideo : Boolean;
    }

    item def OperatorFeedback {
        attribute currentMode : InspectionMode;
        attribute health : ScopeHealth;
        attribute insertionDepth : LengthValue;
        attribute tipTemperature : TemperatureValue;
        attribute imageAvailable : Boolean;
    }

    port def PowerInputPort {
        in energy : ElectricalEnergy;
    }

    port def IlluminationOutputPort {
        out light : OpticalIllumination;
    }

    port def ImageLightInputPort {
        in imageLight : ReflectedImageLight;
    }

    port def ImageOutputPort {
        out frame : ImageFrame;
    }

    port def CommandInputPort {
        in command : ControlCommand;
    }

    port def FeedbackOutputPort {
        out feedback : OperatorFeedback;
    }

    port def MechanicalInsertionPort {
        inout insertionDepth : LengthValue;
        inout distalBendAngle : BendAngleValue;
    }

    part def FiberscopeSystem {
        attribute primaryFunction : String = "Provide remote visual inspection of otherwise inaccessible internal spaces by transmitting illumination to the inspection site, collecting reflected optical information through a flexible scope, and presenting usable images to an operator.";
        attribute totalMass : MassValue;
        attribute maximumInsertionLength : LengthValue;
        attribute minimumBendRadius : LengthValue;
        attribute operatingTemperatureMin : TemperatureValue;
        attribute operatingTemperatureMax : TemperatureValue;
        attribute currentMode : InspectionMode;
        attribute sterilityState : SterilityState;
        attribute health : ScopeHealth;

        port powerIn : PowerInputPort;
        port operatorCommandIn : CommandInputPort;
        port operatorFeedbackOut : FeedbackOutputPort;
        port imageOut : ImageOutputPort;
        port insertionInterface : MechanicalInsertionPort;

        part controlHandle : ControlHandle;
        part flexibleInsertionTube : FlexibleInsertionTube;
        part distalTip : DistalTipAssembly;
        part illuminationSubsystem : IlluminationSubsystem;
        part imagingSubsystem : ImagingSubsystem;
        part displayAndRecorder : DisplayAndRecorder;
        part powerSubsystem : PowerSubsystem;

        connection powerFeed connect powerIn to powerSubsystem.externalPowerIn;
        connection regulatedPowerToLight connect powerSubsystem.regulatedPowerOut to illuminationSubsystem.powerIn;
        connection regulatedPowerToImaging connect powerSubsystem.regulatedPowerOut to imagingSubsystem.powerIn;
        connection regulatedPowerToDisplay connect powerSubsystem.regulatedPowerOut to displayAndRecorder.powerIn;
        connection commandToHandle connect operatorCommandIn to controlHandle.commandIn;
        connection handleToTip connect controlHandle.articulationOut to flexibleInsertionTube.articulationIn;
        connection tubeToTipArticulation connect flexibleInsertionTube.articulationOut to distalTip.articulationIn;
        connection lightToTube connect illuminationSubsystem.lightOut to flexibleInsertionTube.lightIn;
        connection lightToTip connect flexibleInsertionTube.lightOut to distalTip.lightIn;
        connection reflectedLightToTube connect distalTip.imageLightOut to flexibleInsertionTube.imageLightIn;
        connection reflectedLightToImager connect flexibleInsertionTube.imageLightOut to imagingSubsystem.imageLightIn;
        connection imageToDisplay connect imagingSubsystem.imageOut to displayAndRecorder.imageIn;
        connection systemImageOutput connect displayAndRecorder.imageOut to imageOut;
        connection insertionDepthInterface connect insertionInterface to flexibleInsertionTube.insertionPort;
        connection feedbackFromDisplay connect displayAndRecorder.feedbackOut to operatorFeedbackOut;

        action performInspection {
            in command : ControlCommand;
            out frame : ImageFrame;
            first start;
            then initializePower;
            then setIllumination;
            then articulateDistalTip;
            then transmitLight;
            then collectReflectedImage;
            then renderImage;
            then provideOperatorFeedback;
            then done;

            action initializePower;
            action setIllumination;
            action articulateDistalTip;
            action transmitLight;
            action collectReflectedImage;
            action renderImage;
            action provideOperatorFeedback;
        }

        state inspectionStateMachine {
            entry; then Off;

            state Off;
            state Standby;
            state Inserted;
            state Inspecting;
            state CapturingImage;
            state RecordingVideo;
            state Withdrawing;
            state Faulted;

            transition powerApplied
                first Off
                accept ElectricalEnergy
                then Standby;

            transition insertScope
                first Standby
                accept ControlCommand
                if command.requestedMode == InspectionMode::visualSurvey
                then Inserted;

            transition beginInspection
                first Inserted
                then Inspecting;

            transition captureStillImage
                first Inspecting
                accept ControlCommand
                if command.captureStill == true
                then CapturingImage;

            transition stillImageComplete
                first CapturingImage
                then Inspecting;

            transition startRecording
                first Inspecting
                accept ControlCommand
                if command.recordVideo == true
                then RecordingVideo;

            transition stopRecording
                first RecordingVideo
                accept ControlCommand
                if command.recordVideo == false
                then Inspecting;

            transition withdraw
                first Inspecting
                accept ControlCommand
                if command.requestedMode == InspectionMode::withdrawal
                then Withdrawing;

            transition withdrawalComplete
                first Withdrawing
                then Standby;

            transition faultDetected
                first Standby
                then Faulted;

            transition faultDetectedDuringInspection
                first Inspecting
                then Faulted;

            transition resetFault
                first Faulted
                accept ControlCommand
                if command.requestedMode == InspectionMode::idle
                then Standby;
        }
    }

    part def ControlHandle {
        attribute gripLength : LengthValue;
        attribute hasFocusControl : Boolean;
        attribute hasIlluminationControl : Boolean;
        attribute articulationCommandUpDown : BendAngleValue;
        attribute articulationCommandLeftRight : BendAngleValue;

        port commandIn : CommandInputPort;
        port articulationOut : MechanicalInsertionPort;
        port feedbackOut : FeedbackOutputPort;

        action interpretOperatorInput {
            in command : ControlCommand;
            out requestedUpDown : BendAngleValue;
            out requestedLeftRight : BendAngleValue;
            out requestedIlluminationPercent : Real;
        }
    }

    part def FlexibleInsertionTube {
        attribute insertionLength : LengthValue;
        attribute outerDiameter : LengthValue;
        attribute minimumBendRadius : LengthValue;
        attribute workingChannelDiameter : LengthValue;
        attribute fiberBundleCoreCount : Integer;
        attribute insertionDepth : LengthValue;

        port insertionPort : MechanicalInsertionPort;
        port articulationIn : MechanicalInsertionPort;
        port articulationOut : MechanicalInsertionPort;
        port lightIn : IlluminationOutputPort;
        port lightOut : IlluminationOutputPort;
        port imageLightIn : ImageLightInputPort;
        port imageLightOut : ImageLightInputPort;

        part protectiveSheath : ProtectiveSheath;
        part illuminationFiberBundle : IlluminationFiberBundle;
        part imagingFiberBundle : ImagingFiberBundle;
        part articulationCableSet : ArticulationCableSet;
    }

    part def ProtectiveSheath {
        attribute material : String = "medical-grade polymer over braided stainless reinforcement";
        attribute outerDiameter : LengthValue;
        attribute abrasionResistanceRated : Boolean;
        attribute fluidIngressProtected : Boolean;
    }

    part def IlluminationFiberBundle {
        attribute fiberCount : Integer;
        attribute numericalAperture : Real;
        attribute transmissionEfficiency : Real;
        port lightIn : IlluminationOutputPort;
        port lightOut : IlluminationOutputPort;
    }

    part def ImagingFiberBundle {
        attribute fiberCount : Integer;
        attribute effectiveResolutionWidth : PixelCount;
        attribute effectiveResolutionHeight : PixelCount;
        attribute transmissionEfficiency : Real;
        port imageLightIn : ImageLightInputPort;
        port imageLightOut : ImageLightInputPort;
    }

    part def ArticulationCableSet {
        attribute cableCount : Integer = 4;
        attribute maximumTipDeflection : BendAngleValue;
        attribute backlashLimit : BendAngleValue;
        port articulationIn : MechanicalInsertionPort;
        port articulationOut : MechanicalInsertionPort;
    }

    part def DistalTipAssembly {
        attribute tipOuterDiameter : LengthValue;
        attribute tipLength : LengthValue;
        attribute maximumSurfaceTemperature : TemperatureValue;
        attribute fieldOfView : BendAngleValue;
        attribute depthOfFieldNear : LengthValue;
        attribute depthOfFieldFar : LengthValue;

        port articulationIn : MechanicalInsertionPort;
        port lightIn : IlluminationOutputPort;
        port imageLightOut : ImageLightInputPort;

        part objectiveLens : ObjectiveLens;
        part illuminationWindow : IlluminationWindow;
        part bendingSection : BendingSection;

        action illuminateTarget {
            in illumination : OpticalIllumination;
            out reflectedImageLight : ReflectedImageLight;
        }
    }

    part def ObjectiveLens {
        attribute focalLength : LengthValue;
        attribute apertureDiameter : LengthValue;
        attribute fieldOfView : BendAngleValue;
        attribute focusFixed : Boolean = true;
    }

    part def IlluminationWindow {
        attribute windowMaterial : String = "sapphire";
        attribute opticalTransmission : Real;
        attribute scratchResistant : Boolean = true;
    }

    part def BendingSection {
        attribute maximumUpDeflection : BendAngleValue;
        attribute maximumDownDeflection : BendAngleValue;
        attribute maximumLeftDeflection : BendAngleValue;
        attribute maximumRightDeflection : BendAngleValue;
        attribute commandedUpDown : BendAngleValue;
        attribute commandedLeftRight : BendAngleValue;
    }

    part def IlluminationSubsystem {
        attribute maximumOpticalPower : PowerValue;
        attribute colorTemperature : TemperatureValue;
        attribute illuminationLevelPercent : Real;
        attribute automaticBrightnessEnabled : Boolean;

        port powerIn : PowerInputPort;
        port lightOut : IlluminationOutputPort;

        part ledSource : HighIntensityLEDSource;
        part lightGuideCoupler : LightGuideCoupler;

        action regulateIllumination {
            in command : ControlCommand;
            out illumination : OpticalIllumination;
        }
    }

    part def HighIntensityLEDSource {
        attribute electricalPowerDraw : PowerValue;
        attribute emittedOpticalPower : PowerValue;
        attribute wavelengthPeak : LengthValue;
        attribute thermalLimit : TemperatureValue;
    }

    part def LightGuideCoupler {
        attribute couplingEfficiency : Real;
        attribute alignmentTolerance : LengthValue;
    }

    part def ImagingSubsystem {
        attribute sensorWidthPixels : PixelCount;
        attribute sensorHeightPixels : PixelCount;
        attribute frameRate : ImageFrameRate;
        attribute exposureTime : TimeValue;
        attribute automaticGainEnabled : Boolean;

        port powerIn : PowerInputPort;
        port imageLightIn : ImageLightInputPort;
        port imageOut : ImageOutputPort;

        part imageSensor : ImageSensor;
        part imageProcessor : ImageProcessor;

        action convertOpticalImageToDigitalFrame {
            in opticalImage : ReflectedImageLight;
            out digitalFrame : ImageFrame;
        }
    }

    part def ImageSensor {
        attribute widthPixels : PixelCount;
        attribute heightPixels : PixelCount;
        attribute quantumEfficiency : Real;
        attribute lowLightModeAvailable : Boolean;
    }

    part def ImageProcessor {
        attribute performsWhiteBalance : Boolean = true;
        attribute performsNoiseReduction : Boolean = true;
        attribute performsEdgeEnhancement : Boolean = true;
        attribute outputFrameRate : ImageFrameRate;
    }

    part def DisplayAndRecorder {
        attribute displayDiagonal : LengthValue;
        attribute displayBrightness : IlluminanceValue;
        attribute storageCapacityFrames : Integer;
        attribute recordingEnabled : Boolean;

        port powerIn : PowerInputPort;
        port imageIn : ImageOutputPort;
        port imageOut : ImageOutputPort;
        port feedbackOut : FeedbackOutputPort;

        action presentImageToOperator {
            in frame : ImageFrame;
            out feedback : OperatorFeedback;
        }

        action recordInspectionMedia {
            in frame : ImageFrame;
            in recordingRequested : Boolean;
        }
    }

    part def PowerSubsystem {
        attribute inputVoltage : ElectricPotentialValue;
        attribute regulatedVoltage : ElectricPotentialValue;
        attribute maximumContinuousPower : PowerValue;
        attribute batteryRuntime : TimeValue;
        attribute batteryPowered : Boolean;

        port externalPowerIn : PowerInputPort;
        port regulatedPowerOut : PowerInputPort;

        action regulatePower {
            in externalEnergy : ElectricalEnergy;
            out regulatedEnergy : ElectricalEnergy;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /* The fiberscope system shall provide remote visual inspection of enclosed or difficult-to-access internal spaces at a high level by delivering illumination to the target region, receiving reflected image light through a flexible insertion tube, and presenting real-time imagery to an operator. */

        subject system : FiberscopeSystem;

        require constraint {
            system.currentMode == InspectionMode::visualSurvey or
            system.currentMode == InspectionMode::closeInspection or
            system.currentMode == InspectionMode::imageCapture or
            system.currentMode == InspectionMode::videoRecording
        }
    }

    requirement def FlexibleAccessRequirement {
        doc
        /* The fiberscope shall allow the operator to insert and steer the distal tip through constrained passages without direct line-of-sight access. */

        subject tube : FlexibleInsertionTube;

        require constraint {
            tube.insertionLength >= 1.0 [m] and
            tube.outerDiameter <= 8.0 [mm] and
            tube.minimumBendRadius <= 50.0 [mm]
        }
    }

    requirement def IlluminationRequirement {
        doc
        /* The fiberscope shall provide adjustable illumination sufficient for visual inspection at the distal tip. */

        subject illumination : IlluminationSubsystem;

        require constraint {
            illumination.maximumOpticalPower >= 0.5 [W] and
            illumination.illuminationLevelPercent >= 0.0 and
            illumination.illuminationLevelPercent <= 100.0
        }
    }

    requirement def ImagingRequirement {
        doc
        /* The fiberscope shall generate real-time digital image frames for operator viewing. */

        subject imaging : ImagingSubsystem;

        require constraint {
            imaging.sensorWidthPixels >= 1280 and
            imaging.sensorHeightPixels >= 720 and
            imaging.frameRate >= 30
        }
    }

    requirement def ThermalSafetyRequirement {
        doc
        /* The distal tip surface temperature shall remain within safe operating limits during inspection. */

        subject tip : DistalTipAssembly;

        require constraint {
            tip.maximumSurfaceTemperature <= 318.15 [K]
        }
    }

    requirement def ArticulationRequirement {
        doc
        /* The distal tip shall articulate in two axes to support visual surveying around obstructions. */

        subject bending : BendingSection;

        require constraint {
            bending.maximumUpDeflection >= 120 [deg] and
            bending.maximumDownDeflection >= 120 [deg] and
            bending.maximumLeftDeflection >= 90 [deg] and
            bending.maximumRightDeflection >= 90 [deg]
        }
    }

    part fiberscopeInspectionSystem : FiberscopeSystem {
        attribute totalMass = 1.8 [kg];
        attribute maximumInsertionLength = 1.5 [m];
        attribute minimumBendRadius = 35.0 [mm];
        attribute operatingTemperatureMin = 273.15 [K];
        attribute operatingTemperatureMax = 313.15 [K];
        attribute currentMode = InspectionMode::idle;
        attribute sterilityState = SterilityState::clean;
        attribute health = ScopeHealth::nominal;

        part flexibleInsertionTube {
            attribute insertionLength = 1.5 [m];
            attribute outerDiameter = 6.0 [mm];
            attribute minimumBendRadius = 35.0 [mm];
            attribute workingChannelDiameter = 2.0 [mm];
            attribute fiberBundleCoreCount = 30000;
            attribute insertionDepth = 0.0 [m];

            part protectiveSheath {
                attribute outerDiameter = 6.0 [mm];
                attribute abrasionResistanceRated = true;
                attribute fluidIngressProtected = true;
            }

            part illuminationFiberBundle {
                attribute fiberCount = 1200;
                attribute numericalAperture = 0.55;
                attribute transmissionEfficiency = 0.72;
            }

            part imagingFiberBundle {
                attribute fiberCount = 30000;
                attribute effectiveResolutionWidth = 1280;
                attribute effectiveResolutionHeight = 720;
                attribute transmissionEfficiency = 0.68;
            }

            part articulationCableSet {
                attribute maximumTipDeflection = 120 [deg];
                attribute backlashLimit = 3 [deg];
            }
        }

        part distalTip {
            attribute tipOuterDiameter = 6.0 [mm];
            attribute tipLength = 18.0 [mm];
            attribute maximumSurfaceTemperature = 315.15 [K];
            attribute fieldOfView = 90 [deg];
            attribute depthOfFieldNear = 5.0 [mm];
            attribute depthOfFieldFar = 80.0 [mm];

            part objectiveLens {
                attribute focalLength = 1.2 [mm];
                attribute apertureDiameter = 0.8 [mm];
                attribute fieldOfView = 90 [deg];
            }

            part illuminationWindow {
                attribute opticalTransmission = 0.92;
            }

            part bendingSection {
                attribute maximumUpDeflection = 130 [deg];
                attribute maximumDownDeflection = 130 [deg];
                attribute maximumLeftDeflection = 100 [deg];
                attribute maximumRightDeflection = 100 [deg];
                attribute commandedUpDown = 0 [deg];
                attribute commandedLeftRight = 0 [deg];
            }
        }

        part illuminationSubsystem {
            attribute maximumOpticalPower = 0.8 [W];
            attribute colorTemperature = 5600 [K];
            attribute illuminationLevelPercent = 50.0;
            attribute automaticBrightnessEnabled = true;

            part ledSource {
                attribute electricalPowerDraw = 4.0 [W];
                attribute emittedOpticalPower = 0.8 [W];
                attribute wavelengthPeak = 550 [nm];
                attribute thermalLimit = 333.15 [K];
            }

            part lightGuideCoupler {
                attribute couplingEfficiency = 0.81;
                attribute alignmentTolerance = 0.05 [mm];
            }
        }

        part imagingSubsystem {
            attribute sensorWidthPixels = 1280;
            attribute sensorHeightPixels = 720;
            attribute frameRate = 30;
            attribute exposureTime = 0.01 [s];
            attribute automaticGainEnabled = true;

            part imageSensor {
                attribute widthPixels = 1280;
                attribute heightPixels = 720;
                attribute quantumEfficiency = 0.61;
                attribute lowLightModeAvailable = true;
            }

            part imageProcessor {
                attribute outputFrameRate = 30;
            }
        }

        part displayAndRecorder {
            attribute displayDiagonal = 127 [mm];
            attribute displayBrightness = 600;
            attribute storageCapacityFrames = 540000;
            attribute recordingEnabled = true;
        }

        part powerSubsystem {
            attribute inputVoltage = 12 [V];
            attribute regulatedVoltage = 5 [V];
            attribute maximumContinuousPower = 12 [W];
            attribute batteryRuntime = 7200 [s];
            attribute batteryPowered = true;
        }

        part controlHandle {
            attribute gripLength = 140 [mm];
            attribute hasFocusControl = false;
            attribute hasIlluminationControl = true;
            attribute articulationCommandUpDown = 0 [deg];
            attribute articulationCommandLeftRight = 0 [deg];
        }
    }

    satisfy primaryFunctionSatisfied by fiberscopeInspectionSystem;
}