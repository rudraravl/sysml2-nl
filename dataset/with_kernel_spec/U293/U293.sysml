package MediastinoscopeSystem {
    private import ScalarValues::Real;

    item def RawVideo;
    item def HDVideo;
    item def TissueSample;
    item def Illumination {
        attribute intensity : Real;
        attribute colorTemp : Real;
    }

    enum def ControlCommand {
        PowerOn;
        PowerOff;
        InsertScope;
        Examine;
        StartBiopsy;
        StopBiopsy;
        WithdrawScope;
    }

    port def VideoOutPort { out item video : RawVideo; }
    port def VideoInPort { in item video : RawVideo; }
    port def HDVideoOutPort { out item video : HDVideo; }
    port def HDVideoInPort { in item video : HDVideo; }
    port def LightOutPort { out item light : Illumination; }
    port def LightInPort { in item light : Illumination; }
    port def ControlOutPort { out item command : ControlCommand; }
    port def ControlInPort { in item command : ControlCommand; }
    port def BiopsyOutPort { out item sample : TissueSample; }

    action def CaptureVideo {
        in item light : Illumination;
        out item video : RawVideo;
    }
    action def ProcessVideo {
        in item raw : RawVideo;
        out item hd : HDVideo;
    }
    action def DisplayVideo {
        in item hd : HDVideo;
    }
    action def CollectBiopsy {
        in item command : ControlCommand;
        out item sample : TissueSample;
    }

    state def BiopsyInstrumentSM {
        state Idle;
        state Collecting;
        transition first Idle then Collecting;
        transition first Collecting then Idle;
    }

    state def SystemControllerSM {
        state Off;
        state PoweredOn;
        state Ready;
        state ScopeInserted;
        state Examining;
        state BiopsyActive;
        state ScopeWithdrawn;
        state ShuttingDown;
        transition first Off then PoweredOn;
        transition first PoweredOn then Ready;
        transition first Ready then ScopeInserted;
        transition first ScopeInserted then Examining;
        transition first Examining then BiopsyActive;
        transition first BiopsyActive then Examining;
        transition first Examining then ScopeWithdrawn;
        transition first ScopeWithdrawn then ShuttingDown;
        transition first ShuttingDown then Off;
    }

    part def LightSource {
        port lightOut : LightOutPort;
        attribute intensity : Real = 1000;
        attribute colorTemp : Real = 5600;
    }

    part def OpticalSystem {
        port lightIn : LightInPort;
        port videoOut : VideoOutPort;
        action captureVideo : CaptureVideo {
            in light = lightIn.light;
            out video = videoOut.video;
        }
    }

    part def BiopsyInstrument {
        port controlIn : ControlInPort;
        port sampleOut : BiopsyOutPort;
        action collectBiopsy : CollectBiopsy {
            in command = controlIn.command;
            out sample = sampleOut.sample;
        }
        exhibit state biopsySM : BiopsyInstrumentSM;
    }

    part def InsertionTube {
        port videoOut : VideoOutPort;
        port controlIn : ControlInPort;
        port sampleOut : BiopsyOutPort;

        part lightSource : LightSource;
        part opticalSystem : OpticalSystem;
        part biopsyInstrument : BiopsyInstrument;

        flow of Illumination from lightSource.lightOut.light to opticalSystem.lightIn.light;
        flow of RawVideo from opticalSystem.videoOut.video to videoOut.video;
        flow of ControlCommand from controlIn.command to biopsyInstrument.controlIn.command;
        flow of TissueSample from biopsyInstrument.sampleOut.sample to sampleOut.sample;
    }

    part def VideoProcessor {
        port videoIn : VideoInPort;
        port hdVideoOut : HDVideoOutPort;
        action processVideo : ProcessVideo {
            in raw = videoIn.video;
            out hd = hdVideoOut.video;
        }
    }

    part def ControlConsole {
        port hdVideoIn : HDVideoInPort;
        port controlOut : ControlOutPort;
        action displayVideo : DisplayVideo {
            in hd = hdVideoIn.video;
        }
    }

    part def SystemController {
        port controlIn : ControlInPort;
        port scopeControlOut : ControlOutPort;
        exhibit state controllerSM : SystemControllerSM;
    }

    requirement def ProvideHDVideo {
        doc /* The Video Processor shall output high-definition video of the mediastinum. */
    }
    requirement def ProvideDaylightIllumination {
        doc /* The Light Source shall provide daylight-colored illumination of the surgical area. */
    }
    requirement def EnableBiopsy {
        doc /* The system shall allow the surgeon to precisely collect tissue samples. */
    }

    requirement provideHDVideo : ProvideHDVideo;
    requirement provideDaylightIllumination : ProvideDaylightIllumination;
    requirement enableBiopsy : EnableBiopsy;

    part def MediastinoscopeSystem {
        part insertionTube : InsertionTube;
        part videoProcessor : VideoProcessor;
        part controlConsole : ControlConsole;
        part controller : SystemController;

        flow of RawVideo from insertionTube.videoOut.video to videoProcessor.videoIn.video;
        flow of HDVideo from videoProcessor.hdVideoOut.video to controlConsole.hdVideoIn.video;
        flow of ControlCommand from controlConsole.controlOut.command to controller.controlIn.command;
        flow of ControlCommand from controller.scopeControlOut.command to insertionTube.controlIn.command;

        satisfy provideHDVideo by videoProcessor;
        satisfy provideDaylightIllumination by insertionTube.lightSource;
        satisfy enableBiopsy by insertionTube.biopsyInstrument;
    }
}
