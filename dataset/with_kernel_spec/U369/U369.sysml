package 'Medical Rhinoscope System' {
    private import ScalarValues::*;
    
    /* ---- Attribute Definitions ---- */
    attribute def LuminousFlux :> Real {
        attribute unit : String = "lm";
    }
    attribute def FlowRate :> Real {
        attribute unit : String = "mL/s";
    }
    attribute def VacuumPressure :> Real {
        attribute unit : String = "kPa";
    }
    attribute def Volume :> Real {
        attribute unit : String = "mL";
    }
    
    /* ---- Items ---- */
    item def Illumination;
    item def OpticalImage;
    item def VideoData {
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
    }
    item def SterileFluid {
        attribute volume : Volume;
    }
    item def WasteMaterial {
        attribute volume : Volume;
    }
    item def Power;
    item def Command;
    
    /* ---- Ports ---- */
    port def LightOutPort {
        out item light : Illumination;
    }
    port def LightInPort {
        in item light : Illumination;
    }
    port def ImageOutPort {
        out item image : OpticalImage;
    }
    port def ImageInPort {
        in item image : OpticalImage;
    }
    port def VideoOutPort {
        out item video : VideoData;
    }
    port def VideoInPort {
        in item video : VideoData;
    }
    port def FluidOutPort {
        out item fluid : SterileFluid;
    }
    port def FluidInPort {
        in item fluid : SterileFluid;
    }
    port def WasteOutPort {
        out item waste : WasteMaterial;
    }
    port def WasteInPort {
        in item waste : WasteMaterial;
    }
    port def PowerOutPort {
        out item power : Power;
    }
    port def PowerInPort {
        in item power : Power;
    }
    port def CommandOutPort {
        out item command : Command;
    }
    port def CommandInPort {
        in item command : Command;
    }
    
    /* ---- Action Definitions ---- */
    action def SystemReady;
    action def StartExamination;
    action def StopExamination;
    action def StartIrrigation;
    action def StopIrrigation;
    action def StartSuction;
    action def StopSuction;
    
    /* ---- State Machine ---- */
    state def ControlStates {
        entry;
            then initializing;
        state initializing;
        transition init_to_ready
            first initializing
            accept SystemReady
            then ready;
        state ready;
        transition ready_to_examining
            first ready
            accept StartExamination
            then examining;
        state examining;
        transition examining_to_irrigating
            first examining
            accept StartIrrigation
            then irrigating;
        transition examining_to_suctioning
            first examining
            accept StartSuction
            then suctioning;
        transition examining_to_ready
            first examining
            accept StopExamination
            then ready;
        state irrigating;
        transition irrigating_to_examining
            first irrigating
            accept StopIrrigation
            then examining;
        state suctioning;
        transition suctioning_to_examining
            first suctioning
            accept StopSuction
            then examining;
    }
    
    /* ---- Part Definitions ---- */
    part def LightSource {
        attribute luminousFlux : LuminousFlux = 1000;
        attribute colorTemperature : Integer = 5600;
        port lightOut : LightOutPort;
        port powerIn : PowerInPort;
    }
    
    part def FiberOpticBundle {
        port lightIn : LightInPort;
        port lightOut : LightOutPort;
    }
    
    part def LensAssembly {
        port lightIn : LightInPort;
        port imageOut : ImageOutPort;
    }
    
    part def ImageSensor {
        attribute resolutionWidth : Integer = 1920;
        attribute resolutionHeight : Integer = 1080;
        port imageIn : ImageInPort;
        port videoOut : VideoOutPort;
    }
    
    part def VideoProcessor {
        attribute latency : Real = 0.03;
        port videoIn : VideoInPort;
        port videoOut : VideoOutPort;
    }
    
    part def DisplayMonitor {
        port videoIn : VideoInPort;
    }
    
    part def IrrigationPump {
        attribute flowRate : FlowRate = 5.0;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port powerIn : PowerInPort;
    }
    
    part def SuctionPump {
        attribute vacuumPressure : VacuumPressure = -50.0;
        port wasteIn : WasteInPort;
        port wasteOut : WasteOutPort;
        port powerIn : PowerInPort;
    }
    
    part def FluidReservoir {
        port fluidOut : FluidOutPort;
    }
    
    part def WasteContainer {
        port wasteIn : WasteInPort;
    }
    
    part def IrrigationChannel {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
    }
    
    part def SuctionChannel {
        port wasteIn : WasteInPort;
        port wasteOut : WasteOutPort;
    }
    
    part def InsertionTube {
        port lightIn : LightInPort;
        port videoOut : VideoOutPort;
        port irrigationIn : FluidInPort;
        port suctionOut : WasteOutPort;
        
        part fiberOpticBundle : FiberOpticBundle;
        part lensAssembly : LensAssembly;
        part imageSensor : ImageSensor;
        part irrigationChannel : IrrigationChannel;
        part suctionChannel : SuctionChannel;
        
        flow lightIn.light to fiberOpticBundle.lightIn.light;
        flow fiberOpticBundle.lightOut.light to lensAssembly.lightIn.light;
        flow lensAssembly.imageOut.image to imageSensor.imageIn.image;
        flow imageSensor.videoOut.video to videoOut.video;
        flow irrigationIn.fluid to irrigationChannel.fluidIn.fluid;
        flow suctionChannel.wasteOut.waste to suctionOut.waste;
    }
    
    part def ControlUnit {
        port commandIn : CommandInPort;
        port lightPowerOut : PowerOutPort;
        port irrigationPowerOut : PowerOutPort;
        port suctionPowerOut : PowerOutPort;
    }
    
    /* ---- Requirements ---- */
    requirement HighDefinitionVideoRequirement {
        doc /* The image sensor shall capture video at a resolution of 1920x1080 pixels. */
        attribute requiredWidth : Integer = 1920;
        attribute requiredHeight : Integer = 1080;
    }
    
    requirement IlluminationRequirement {
        doc /* The light source shall provide high-intensity, daylight-quality illumination at 5600K. */
        attribute minLuminousFlux : LuminousFlux = 800;
        attribute colorTemperature : Integer = 5600;
    }
    
    requirement LowLatencyRequirement {
        doc /* The video processor shall enhance images with minimal delay for real-time display. */
        attribute maxLatency : Real = 0.05;
    }
    
    requirement SterileIrrigationRequirement {
        doc /* The irrigation system shall pump sterile fluid to wash away mucus or blood. */
        attribute minFlowRate : FlowRate = 1.0;
    }
    
    requirement FlexibleTubeRequirement {
        doc /* The insertion tube shall be slender and flexible for safe patient insertion. */
    }
    
    /* ---- System Usage ---- */
    part rhinoscopeSystem {
        part controlUnit : ControlUnit {
            exhibit controlStates : ControlStates;
        }
        part lightSource : LightSource;
        part insertionTube : InsertionTube;
        part videoProcessor : VideoProcessor;
        part displayMonitor : DisplayMonitor;
        part irrigationPump : IrrigationPump;
        part suctionPump : SuctionPump;
        part fluidReservoir : FluidReservoir;
        part wasteContainer : WasteContainer;
        part operator {
            port commandOut : CommandOutPort;
        }
        
        /* Power Distribution */
        flow of power : Power
            from controlUnit.lightPowerOut.power to lightSource.powerIn.power;
        flow of power : Power
            from controlUnit.irrigationPowerOut.power to irrigationPump.powerIn.power;
        flow of power : Power
            from controlUnit.suctionPowerOut.power to suctionPump.powerIn.power;
        
        /* Operator Commands */
        flow of command : Command
            from operator.commandOut.command to controlUnit.commandIn.command;
        
        /* Light Path */
        flow of light : Illumination
            from lightSource.lightOut.light to insertionTube.lightIn.light;
        
        /* Video Path */
        flow of video : VideoData
            from insertionTube.videoOut.video to videoProcessor.videoIn.video;
        flow of video : VideoData
            from videoProcessor.videoOut.video to displayMonitor.videoIn.video;
        
        /* Irrigation Path */
        flow of fluid : SterileFluid
            from fluidReservoir.fluidOut.fluid to irrigationPump.fluidIn.fluid;
        flow of fluid : SterileFluid
            from irrigationPump.fluidOut.fluid to insertionTube.irrigationIn.fluid;
        
        /* Suction Path */
        flow of waste : WasteMaterial
            from insertionTube.suctionOut.waste to suctionPump.wasteIn.waste;
        flow of waste : WasteMaterial
            from suctionPump.wasteOut.waste to wasteContainer.wasteIn.waste;
        
        /* Satisfy Requirements */
        satisfy HighDefinitionVideoRequirement by insertionTube.imageSensor;
        satisfy IlluminationRequirement by lightSource;
        satisfy LowLatencyRequirement by videoProcessor;
        satisfy SterileIrrigationRequirement by irrigationPump;
        satisfy FlexibleTubeRequirement by insertionTube;
    }
}
