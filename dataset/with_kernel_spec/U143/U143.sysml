package AirtraqVideoLaryngoscope {

    private import ScalarValues::*;

    unit Volt;
    unit Lux;
    unit Degree;

    value def Voltage :> Real {
        :>> unit = Volt;
    }
    value def Illuminance :> Real {
        :>> unit = Lux;
    }
    value def Angle :> Real {
        :>> unit = Degree;
    }

    item def Power;
    item def Light;
    item def Scene;
    item def IlluminatedScene;
    item def OpticalImage;
    item def RawVideoFeed;
    item def EnhancedVideoFeed;
    item def EndotrachealTube;
    item def Patient;

    port def PowerPort;
    port def LightPort;
    port def OpticalPort;
    port def VideoPort;
    port def EnhancedVideoPort;

    part def Battery {
        port outPower : PowerPort;
        attribute voltage : Voltage;
    }

    part def LEDIllumination {
        port inPower : PowerPort;
        port outLight : LightPort;
        in item scene : Scene;
        out item illuminatedScene : IlluminatedScene;
    }

    part def PrismSystem {
        port inLight : LightPort;
        port outOpticalImage : OpticalPort;
        in item illuminatedScene : IlluminatedScene;
        out item opticalImage : OpticalImage;
    }

    part def MicroCamera {
        port inPower : PowerPort;
        port inOpticalImage : OpticalPort;
        port outRawVideo : VideoPort;
        in item opticalImage : OpticalImage;
        out item rawVideo : RawVideoFeed;
    }

    part def VideoProcessor {
        port inPower : PowerPort;
        port inRawVideo : VideoPort;
        port outEnhancedVideo : EnhancedVideoPort;
        in item rawVideo : RawVideoFeed;
        out item enhancedVideo : EnhancedVideoFeed;
    }

    part def DisplayScreen {
        port inPower : PowerPort;
        port inEnhancedVideo : EnhancedVideoPort;
        in item enhancedVideo : EnhancedVideoFeed;
    }

    part def GuidingChannel {
        ref item tube : EndotrachealTube;
        attribute guidingAngle : Angle;
    }

    part def Blade {
        ref item patient : Patient;
        part guidingChannel : GuidingChannel;
    }

    action def PowerOn;
    action def InsertBlade;
    action def NavigateAnatomy;
    action def Reposition;
    action def VisualizeGlottis;
    action def AdvanceTube;
    action def VerifyPlacement;
    action def RemoveDevice;
    action def PowerOff;

    action def Intubation {
        in ref item patient : Patient;
        in ref item tube : EndotrachealTube;
        then action powerOn : PowerOn;
        then action insertBlade : InsertBlade;
        then action navigateAnatomy : NavigateAnatomy;
        then action reposition : Reposition;
        then action visualizeGlottis : VisualizeGlottis;
        then action advanceTube : AdvanceTube;
        then action verifyPlacement : VerifyPlacement;
        then action removeDevice : RemoveDevice;
        then action powerOff : PowerOff;
    }

    state def IntubationProcedure {
        state off;
        state poweredOn;
        state inserted;
        state navigating;
        state glottisVisible;
        state tubeAdvanced;
        state placementVerified;
        state removed;
        state poweredOff;

        transition from off to poweredOn accept PowerOn;
        transition from poweredOn to inserted accept InsertBlade;
        transition from inserted to navigating accept NavigateAnatomy;
        transition from navigating to navigating accept Reposition;
        transition from navigating to glottisVisible accept VisualizeGlottis;
        transition from glottisVisible to tubeAdvanced accept AdvanceTube;
        transition from tubeAdvanced to placementVerified accept VerifyPlacement;
        transition from placementVerified to removed accept RemoveDevice;
        transition from removed to poweredOff accept PowerOff;
    }

    requirement def ProvideClearView {
        doc /1/ "The device shall provide a clear, indirect view of the patient's airway on the integrated display screen.";
    }
    requirement def IlluminateAirway {
        doc /1/ "The LED illumination system shall provide bright, cool light to illuminate the airway.";
    }
    requirement def CaptureOpticalImage {
        doc /1/ "The optical prism system shall relay the view from the blade tip to the micro-camera module.";
    }
    requirement def ProcessVideo {
        doc /1/ "The video processing unit shall enhance the raw video for clarity, brightness, and contrast before display.";
    }
    requirement def GuideEndotrachealTube {
        doc /1/ "The guiding channel shall hold and direct the endotracheal tube at a precise angle toward the vocal cords.";
    }
    requirement def OperateProcedurally {
        doc /1/ "The device shall support the intubation procedure from power on through device removal.";
    }

    part def AirtraqDevice {
        part battery : Battery;
        part led : LEDIllumination;
        part prism : PrismSystem;
        part camera : MicroCamera;
        part processor : VideoProcessor;
        part screen : DisplayScreen;
        part blade : Blade;

        ref item patient : Patient;
        ref item tube : EndotrachealTube;
        ref item scene : Scene;

        connect battery.outPower to led.inPower;
        connect battery.outPower to camera.inPower;
        connect battery.outPower to processor.inPower;
        connect battery.outPower to screen.inPower;

        connect led.outLight to prism.inLight;

        flow led.illuminatedScene to prism.illuminatedScene;
        flow prism.opticalImage to camera.opticalImage;
        flow camera.rawVideo to processor.rawVideo;
        flow processor.enhancedVideo to screen.enhancedVideo;

        perform action intubation : Intubation {
            in ref item patient = AirtraqDevice::patient;
            in ref item tube = AirtraqDevice::tube;
        }

        satisfy ProvideClearView;
        satisfy IlluminateAirway;
        satisfy CaptureOpticalImage;
        satisfy ProcessVideo;
        satisfy GuideEndotrachealTube;
        satisfy OperateProcedurally;
    }
}
