import ScalarValues::*;

package BorescopyInspectionSystem {
    attribute def Length;
    attribute def Angle;
    attribute def Illuminance;
    attribute def Brightness;
    attribute def Contrast;
    attribute def Severity;
    attribute def Duration;

    item def RawVideo;
    item def EnhancedVideo;
    item def OverlayVideo;
    item def DefectData {
        attribute defectType : String;
        attribute location : String;
        attribute severity : Severity;
    }
    item def ControlCommand {
        attribute insertionDepth : Length;
        attribute rotation : Angle;
        attribute bendAngle : Angle;
        attribute illumination : Illuminance;
    }
    item def InspectionSession {
        attribute sessionId : String;
        attribute startTime : String;
        attribute endTime : String;
    }
    item def StillImage;
    item def SessionLog {
        attribute session : InspectionSession;
        item video : EnhancedVideo[0..*];
        item images : StillImage[0..*];
        item defects : DefectData[0..*];
    }

    port def ControlPort {
        in item command : ControlCommand;
    }
    port def RawVideoPort {
        out item video : RawVideo;
    }
    port def EnhancedVideoPort {
        out item video : EnhancedVideo;
    }
    port def OverlayVideoPort {
        out item video : OverlayVideo;
    }
    port def DefectDataPort {
        out item defects : DefectData[0..*];
    }
    port def EnhancedVideoInPort {
        in item video : EnhancedVideo;
    }
    port def DefectDataInPort {
        in item defects : DefectData[0..*];
    }
    port def DisplayPort {
        in item overlayVideo : OverlayVideo;
        in item defects : DefectData[0..*];
    }

    action def Prepare {
        out item session : InspectionSession;
    }
    action def InsertProbe {
        in item command : ControlCommand;
        in item session : InspectionSession;
        out item session : InspectionSession;
    }
    action def Scan {
        in item command : ControlCommand;
        out item rawVideo : RawVideo;
    }
    action def EnhanceImage {
        in item rawVideo : RawVideo;
        attribute brightness : Brightness;
        attribute contrast : Contrast;
        out item enhancedVideo : EnhancedVideo;
    }
    action def AnalyzeImages {
        in item video : EnhancedVideo;
        out item defects : DefectData[0..*];
    }
    action def OverlayDefects {
        in item video : EnhancedVideo;
        in item defects : DefectData[0..*];
        out item overlayVideo : OverlayVideo;
    }
    action def RecordData {
        in item video : EnhancedVideo;
        in item defects : DefectData[0..*];
        in item session : InspectionSession;
        out item log : SessionLog;
    }
    action def RetractProbe {
        in item session : InspectionSession;
    }

    part def ImagingSensor {
        port videoOut : RawVideoPort;
    }
    part def LEDLightSource {
        attribute illumination : Illuminance;
    }
    part def SteerableTip {
        attribute bendAngle : Angle;
        attribute rotation : Angle;
    }
    part def InsertionProbe {
        attribute insertionDepth : Length;
        part camera : ImagingSensor;
        part light : LEDLightSource;
        part tip : SteerableTip;
        port controlIn : ControlPort;
        port videoOut : RawVideoPort;
        flow from camera.videoOut.video to videoOut.video;
    }
    part def OperatorInterface {
        port controlOut : ControlPort;
    }
    part def ProcessingUnit {
        port videoIn : RawVideoPort;
        port videoOut : EnhancedVideoPort;
        action enhance : EnhanceImage {
            in item rawVideo = videoIn.video;
            out item enhancedVideo;
        }
        flow from enhance.enhancedVideo to videoOut.video;
    }
    part def AnalysisModule {
        port videoIn : EnhancedVideoPort;
        port defectOut : DefectDataPort;
        port overlayOut : OverlayVideoPort;
        action analyze : AnalyzeImages {
            in item video = videoIn.video;
            out item defects;
        }
        action overlay : OverlayDefects {
            in item video = videoIn.video;
            in item defects = analyze.defects;
            out item overlayVideo;
        }
        flow from analyze.defects to defectOut.defects;
        flow from overlay.overlayVideo to overlayOut.video;
    }
    part def DisplayConsole {
        port enhancedVideoIn : EnhancedVideoInPort;
        port displayIn : DisplayPort;
        attribute overlayEnabled : Boolean;
    }
    part def RecordingSystem {
        port videoIn : EnhancedVideoInPort;
        port defectIn : DefectDataInPort;
        action record : RecordData {
            in item video = videoIn.video;
            in item defects = defectIn.defects;
            out item log;
        }
    }

    state machine def InspectionStateMachine {
        entry; then idle;
        state idle;
        transition idle to preparing;
        state preparing;
        transition preparing to probeInserted;
        state probeInserted;
        transition probeInserted to scanning;
        state scanning;
        transition scanning to analyzing;
        state analyzing;
        transition analyzing to recording;
        state recording;
        transition recording to scanning;
        transition recording to probeRetracted;
        state probeRetracted;
        transition probeRetracted to idle;
    }

    part def BorescopySystem {
        part operatorInterface : OperatorInterface;
        part probe : InsertionProbe;
        part processingUnit : ProcessingUnit;
        part analysisModule : AnalysisModule;
        part displayConsole : DisplayConsole;
        part recordingSystem : RecordingSystem;

        connection operatorToProbe connect operatorInterface.controlOut to probe.controlIn;
        connection cameraToProcessing connect probe.camera.videoOut to processingUnit.videoIn;
        connection processingToAnalysis connect processingUnit.videoOut to analysisModule.videoIn;
        connection processingToDisplay connect processingUnit.videoOut to displayConsole.enhancedVideoIn;
        connection processingToRecording connect processingUnit.videoOut to recordingSystem.videoIn;
        connection analysisToDisplayVideo connect analysisModule.overlayOut to displayConsole.displayIn;
        connection analysisToDisplayDefects connect analysisModule.defectOut to displayConsole.displayIn;
        connection analysisToRecording connect analysisModule.defectOut to recordingSystem.defectIn;

        exhibit InspectionStateMachine;

        action def InspectionProcess;
        action inspectionProcess : InspectionProcess {
            first start;
            then action prepare : Prepare {
                out item session;
            }
            then action insert : InsertProbe {
                in item command;
                in item session = prepare.session;
                out item session;
            }
            then action scan : Scan {
                in item command;
                out item rawVideo;
            }
            then action enhance : EnhanceImage {
                in item rawVideo = scan.rawVideo;
                attribute brightness;
                attribute contrast;
                out item enhancedVideo;
            }
            then action analyze : AnalyzeImages {
                in item video = enhance.enhancedVideo;
                out item defects;
            }
            then action overlay : OverlayDefects {
                in item video = enhance.enhancedVideo;
                in item defects = analyze.defects;
                out item overlayVideo;
            }
            then action record : RecordData {
                in item video = enhance.enhancedVideo;
                in item defects = analyze.defects;
                in item session = insert.session;
                out item log;
            }
            then action retract : RetractProbe {
                in item session = insert.session;
            }
            then done;
        }
    }
}
