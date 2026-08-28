package MedicalEndoscopeSystem {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::String;
    private import ScalarValues::Boolean;

    unit mm;
    unit deg;
    unit fps;
    unit lumen;
    unit ml;
    unit ml_per_min;

    value type Length :> Real { unit = mm; }
    value type Diameter :> Real { unit = mm; }
    value type Angle :> Real { unit = deg; }
    value type FrameRate :> Real { unit = fps; }
    value type LightIntensity :> Real { unit = lumen; }
    value type FluidVolume :> Real { unit = ml; }
    value type FlowRate :> Real { unit = ml_per_min; }

    item def Light {
        attribute intensity : LightIntensity;
    }
    item def VideoFrame {
        attribute width : Integer = 1920;
        attribute height : Integer = 1080;
        attribute frameRate : FrameRate = 60 [fps];
    }
    item def EnhancedFrame {
        attribute width : Integer = 1920;
        attribute height : Integer = 1080;
        attribute frameRate : FrameRate = 60 [fps];
    }
    item def Fluid {
        attribute volume : FluidVolume;
        attribute fluidType : String;
    }
    item def SuctionedMaterial {
        attribute volume : FluidVolume;
    }
    item def ControlCommand {
        attribute bendAngle : Angle;
        attribute direction : String;
    }

    port def LightOutPort {
        out item light : Light;
    }
    port def LightInPort {
        in item light : Light;
    }
    port def VideoOutPort {
        out item videoFrame : VideoFrame;
    }
    port def VideoInPort {
        in item videoFrame : VideoFrame;
    }
    port def EnhancedVideoOutPort {
        out item enhancedFrame : EnhancedFrame;
    }
    port def EnhancedVideoInPort {
        in item enhancedFrame : EnhancedFrame;
    }
    port def ControlOutPort {
        out item command : ControlCommand;
    }
    port def ControlInPort {
        in item command : ControlCommand;
    }
    port def FluidOutPort {
        out item fluid : Fluid;
    }
    port def FluidInPort {
        in item fluid : Fluid;
    }
    port def SuctionOutPort {
        out item suctionFluid : SuctionedMaterial;
    }
    port def SuctionInPort {
        in item suctionFluid : SuctionedMaterial;
    }

    part def ImageSensor {
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute frameRate : FrameRate = 60 [fps];
        port lightIn : LightInPort;
        port videoOut : VideoOutPort;
    }

    part def ArticulationSection {
        attribute maxBendAngle : Angle = 210 [deg];
        port controlIn : ControlInPort;
    }

    part def FiberOpticBundles {
        port lightIn : LightInPort;
        port lightOut : LightOutPort;
    }

    part def WorkingChannel {
        port fluidIn : FluidInPort;
        port suctionOut : SuctionOutPort;
    }

    part def InsertionTube {
        attribute length : Length = 1200 [mm];
        attribute diameter : Diameter = 9.5 [mm];
        port lightIn : LightInPort;
        port videoOut : VideoOutPort;
        port controlIn : ControlInPort;
        port fluidIn : FluidInPort;
        port suctionOut : SuctionOutPort;

        part imageSensor : ImageSensor;
        part articulationSection : ArticulationSection;
        part fiberOpticBundles : FiberOpticBundles;
        part workingChannel : WorkingChannel;

        flow from lightIn.light to fiberOpticBundles.lightIn.light;
        flow from fiberOpticBundles.lightOut.light to imageSensor.lightIn.light;
        flow from imageSensor.videoOut.videoFrame to videoOut.videoFrame;
        flow from controlIn.command to articulationSection.controlIn.command;
        flow from fluidIn.fluid to workingChannel.fluidIn.fluid;
        flow from workingChannel.suctionOut.suctionFluid to suctionOut.suctionFluid;
    }

    part def LightSource {
        attribute maxIntensity : LightIntensity = 300 [lumen];
        port lightOut : LightOutPort;
    }

    action def EnhanceVideo {
        in item rawVideo : VideoFrame;
        out item enhancedFrame : EnhancedFrame;
    }

    part def VideoProcessor {
        port videoIn : VideoInPort;
        port enhancedVideoOut : EnhancedVideoOutPort;
        perform action enhance : EnhanceVideo {
            in item rawVideo = videoIn.videoFrame;
            out item enhancedFrame = enhancedVideoOut.enhancedFrame;
        }
    }

    part def ControlConsole {
        port enhancedVideoIn : EnhancedVideoInPort;
        port controlOut : ControlOutPort;
        action displayFeed {
            in item image : EnhancedFrame = enhancedVideoIn.enhancedFrame;
        }
        action generateControl {
            out item command : ControlCommand = controlOut.command;
        }
    }

    part def IrrigationSystem {
        port fluidOut : FluidOutPort;
        port suctionIn : SuctionInPort;
        action deliverFluid {
            out item fluid : Fluid = fluidOut.fluid;
        }
        action applySuction {
            in item debris : SuctionedMaterial = suctionIn.suctionFluid;
        }
    }

    part def Endoscope {
        part insertionTube : InsertionTube;
        part lightSource : LightSource;
        part videoProcessor : VideoProcessor;
        part controlConsole : ControlConsole;
        part irrigationSystem : IrrigationSystem;

        flow from lightSource.lightOut.light to insertionTube.lightIn.light;
        flow from insertionTube.videoOut.videoFrame to videoProcessor.videoIn.videoFrame;
        flow from videoProcessor.enhancedVideoOut.enhancedFrame to controlConsole.enhancedVideoIn.enhancedFrame;
        flow from controlConsole.controlOut.command to insertionTube.controlIn.command;
        flow from irrigationSystem.fluidOut.fluid to insertionTube.fluidIn.fluid;
        flow from insertionTube.suctionOut.suctionFluid to irrigationSystem.suctionIn.suctionFluid;
    }

    action def InitializeSystem;
    action def InsertTube;
    action def NavigateScope;
    action def ExamineSite;
    action def AdjustLighting;
    action def IrrigateArea;
    action def ApplySuction;
    action def PerformIntervention;
    action def CaptureMedia;
    action def WithdrawScope;
    action def CompleteProcedure;

    action def ClinicalProcedure {
        action init : InitializeSystem;
        action insert : InsertTube;
        action navigate : NavigateScope;
        action examine : ExamineSite;
        action adjustLight : AdjustLighting;
        action irrigate : IrrigateArea;
        action suction : ApplySuction;
        action intervene : PerformIntervention;
        action capture : CaptureMedia;
        action withdraw : WithdrawScope;
        action complete : CompleteProcedure;

        succession first init then insert;
        succession first insert then navigate;
        succession first navigate then examine;
        succession first examine then adjustLight;
        succession first adjustLight then irrigate;
        succession first irrigate then suction;
        succession first suction then intervene;
        succession first intervene then capture;
        succession first capture then withdraw;
        succession first withdraw then complete;
    }

    state def EndoscopeOperationalState {
        initial state idle;
        state initialized;
        state inserted;
        state navigating;
        state examining;
        state adjusting;
        state irrigating;
        state suctioning;
        state intervening;
        state capturing;
        state withdrawing;
        state completed;

        transition from idle to initialized on InitializeSystem;
        transition from initialized to inserted on InsertTube;
        transition from inserted to navigating on NavigateScope;
        transition from navigating to examining on ExamineSite;
        transition from examining to adjusting on AdjustLighting;
        transition from adjusting to irrigating on IrrigateArea;
        transition from irrigating to suctioning on ApplySuction;
        transition from suctioning to intervening on PerformIntervention;
        transition from intervening to capturing on CaptureMedia;
        transition from capturing to withdrawing on WithdrawScope;
        transition from withdrawing to completed on CompleteProcedure;
        transition from completed to idle;
    }

    requirement def Req_InsertionTubeDimensions {
        doc /* The insertion tube shall be approximately 1.2 meters long and 9.5 mm in diameter. */
        attribute length : Length = 1200 [mm];
        attribute diameter : Diameter = 9.5 [mm];
    }
    requirement def Req_ImageSensorPerformance {
        doc /* The image sensor shall capture video at 1920x1080 resolution and 60 frames per second. */
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        attribute frameRate : FrameRate = 60 [fps];
    }
    requirement def Req_ArticulationRange {
        doc /* The articulation section shall bend up to 210 degrees. */
        attribute maxBendAngle : Angle = 210 [deg];
    }
    requirement def Req_LightSourceIntensity {
        doc /* The light source shall provide sufficient illumination for internal examination. */
        attribute minIntensity : LightIntensity = 300 [lumen];
    }
    requirement def Req_ClinicalWorkflowSupport {
        doc /* The system shall support initialization, insertion, navigation, examination, irrigation, intervention, capture, and withdrawal. */
    }

    actor def Clinician;

    part systemInstance : Endoscope {
        satisfy Req_InsertionTubeDimensions by insertionTube;
        satisfy Req_ImageSensorPerformance by insertionTube.imageSensor;
        satisfy Req_ArticulationRange by insertionTube.articulationSection;
        satisfy Req_LightSourceIntensity by lightSource;
        satisfy Req_ClinicalWorkflowSupport;
        perform ClinicalProcedure;
        state operationalState : EndoscopeOperationalState;
    }

    actor clinician : Clinician;
}
