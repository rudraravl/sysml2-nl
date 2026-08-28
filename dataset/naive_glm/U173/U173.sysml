package BorescopyInspectionSystem {
    import ScalarValues::*;

    value def IlluminationIntensity > Real { unit 'lux'; }
    value def DepthMeasure > Real { unit 'mm'; }
    value def RotationAngle > Real { unit 'deg'; }
    value def BendAngle > Real { unit 'deg'; }
    value def BrightnessLevel > Real { unit 'cd/m2'; }
    value def ContrastLevel > Real { unit '1'; }
    value def FrameRate > Real { unit 'fps'; }
    value def Resolution > Integer;

    enum def DefectType { cracks; corrosion; foreignDebris; wear; deformation; }
    enum def DefectSeverity { low; medium; high; critical; }

    item def VideoFrame {
        attribute resolution : Resolution;
        attribute frameRate : FrameRate;
        attribute timestamp : String;
    }

    item def EnhancedVideoFrame :> VideoFrame {
        attribute brightness : BrightnessLevel;
        attribute contrast : ContrastLevel;
    }

    item def DefectMarker {
        attribute defectType : DefectType;
        attribute severity : DefectSeverity;
        attribute locationX : DepthMeasure;
        attribute locationY : DepthMeasure;
        attribute measuredSize : DepthMeasure;
    }

    item def InspectionReport {
        attribute sessionId : String;
        attribute timestamp : String;
        attribute defects : DefectMarker[0..*];
    }

    item def ControlCommand {
        attribute targetDepth : DepthMeasure;
        attribute targetRotation : RotationAngle;
        attribute targetBendAngle : BendAngle;
        attribute targetIllumination : IlluminationIntensity;
    }

    port def VideoOutPort {
        out videoFrame : VideoFrame;
    }

    port def VideoInPort {
        in videoFrame : VideoFrame;
    }

    port def EnhancedVideoOutPort {
        out enhancedFrame : EnhancedVideoFrame;
    }

    port def EnhancedVideoInPort {
        in enhancedFrame : EnhancedVideoFrame;
    }

    port def ControlOutPort {
        out command : ControlCommand;
    }

    port def ControlInPort {
        in command : ControlCommand;
    }

    port def DefectOutPort {
        out defectMarker : DefectMarker;
    }

    port def DefectInPort {
        in defectMarker : DefectMarker;
    }

    part def ImagingSensor {
        port videoOut : VideoOutPort;
        attribute resolution : Resolution = 1920;
        attribute frameRate : FrameRate = 30;

        action def CaptureFrame {
            out frame : VideoFrame;
        }
        perform capture : CaptureFrame;
    }

    part def LEDLightSource {
        attribute intensity : IlluminationIntensity = 1000;

        action def AdjustIntensity {
            in newIntensity : IlluminationIntensity;
        }
        perform adjust : AdjustIntensity;
    }

    part def SteerableTip {
        attribute currentBendAngle : BendAngle = 0;
        attribute currentRotation : RotationAngle = 0;

        action def Steer {
            in bendAngle : BendAngle;
            in rotation : RotationAngle;
        }
        perform steer : Steer;
    }

    part def InsertionProbe {
        port controlIn : ControlInPort;
        port videoOut : VideoOutPort;

        part imagingSensor : ImagingSensor;
        part ledLight : LEDLightSource;
        part steerableTip : SteerableTip;
        attribute currentDepth : DepthMeasure = 0;

        action def Insert {
            in depth : DepthMeasure;
        }
        action def Retract {
            in depth : DepthMeasure;
        }
        action def Navigate {
            in command : ControlCommand;
        }
        perform insert : Insert;
        perform retract : Retract;
        perform navigate : Navigate;

        connection cameraVideo connect imagingSensor.videoOut to videoOut;
    }

    part def OperatorInterface {
        port controlOut : ControlOutPort;

        action def GenerateCommand {
            out command : ControlCommand;
        }
        perform generate : GenerateCommand;
    }

    part def ProcessingUnit {
        port videoIn : VideoInPort;
        port enhancedVideoOut : EnhancedVideoOutPort;

        action def EnhanceImage {
            in rawFrame : VideoFrame;
            out enhancedFrame : EnhancedVideoFrame;
        }
        perform enhance : EnhanceImage;
    }

    part def AnalysisModule {
        port videoIn : EnhancedVideoInPort;
        port defectDataOut : DefectOutPort;

        action def DetectDefect {
            in frame : EnhancedVideoFrame;
            out defect : DefectMarker;
        }
        action def ClassifyDefect {
            in defect : DefectMarker;
            out classifiedDefect : DefectMarker;
        }
        action def MeasureDefect {
            in defect : DefectMarker;
            out measuredDefect : DefectMarker;
        }
        perform detect : DetectDefect;
        perform classify : ClassifyDefect;
        perform measure : MeasureDefect;
    }

    part def DisplayConsole {
        port enhancedVideoIn : EnhancedVideoInPort;
        port defectDataIn : DefectInPort;

        action def RenderOverlay {
            in frame : EnhancedVideoFrame;
            in defect : DefectMarker;
        }
        perform render : RenderOverlay;
    }

    part def RecordingSystem {
        port enhancedVideoIn : EnhancedVideoInPort;
        port defectDataIn : DefectInPort;

        action def LogSession {
            in frame : EnhancedVideoFrame;
            in defect : DefectMarker;
        }
        action def GenerateReport {
            out report : InspectionReport;
        }
        perform log : LogSession;
        perform generateReport : GenerateReport;
    }

    part def BorescopyInspectionSystem {
        port operatorControl : ControlInPort;

        part probe : InsertionProbe;
        part operatorInterface : OperatorInterface;
        part processingUnit : ProcessingUnit;
        part analysisModule : AnalysisModule;
        part displayConsole : DisplayConsole;
        part recordingSystem : RecordingSystem;

        connection controlLink connect operatorInterface.controlOut to probe.controlIn;
        connection rawVideoLink connect probe.videoOut to processingUnit.videoIn;
        connection enhancedVideoToAnalysis connect processingUnit.enhancedVideoOut to analysisModule.videoIn;
        connection enhancedVideoToDisplay connect processingUnit.enhancedVideoOut to displayConsole.enhancedVideoIn;
        connection defectDataToDisplay connect analysisModule.defectDataOut to displayConsole.defectDataIn;
        connection enhancedVideoToRecording connect processingUnit.enhancedVideoOut to recordingSystem.enhancedVideoIn;
        connection defectDataToRecording connect analysisModule.defectDataOut to recordingSystem.defectDataIn;

        state machine InspectionStates {
            initial state Idle;

            state Preparation {
                entry action powerOn { }
                do action initialize { }
            }

            state Insertion {
                entry action startInsertion { }
                do action guideProbe { }
            }

            state Inspection {
                initial state Scanning;
                state Scanning {
                    do action scanArea { }
                }
                state Analyzing {
                    do action analyzeImages { }
                }
                state Recording {
                    do action recordData { }
                }
                transition from Scanning to Analyzing;
                transition from Analyzing to Recording;
                transition from Recording to Scanning;
            }

            state Retraction {
                entry action startRetraction { }
                do action retractProbe { }
            }

            transition from Idle to Preparation;
            transition from Preparation to Insertion;
            transition from Insertion to Inspection;
            transition from Inspection to Retraction;
            transition from Retraction to Idle;
        }
    }

    requirement def InspectionQualityRequirement {
        subject system : BorescopyInspectionSystem;
        doc "The system shall provide enhanced video with minimum resolution of 1920 pixels and 30 fps.";
    }

    requirement def DefectDetectionRequirement {
        subject analysisModule : AnalysisModule;
        doc "The system shall detect, classify, and measure defects in real-time.";
    }

    requirement def ProbeManeuverabilityRequirement {
        subject probe : InsertionProbe;
        doc "The probe shall support insertion depth, rotation, and bend angle control.";
    }

    requirement def RecordingComplianceRequirement {
        subject recordingSystem : RecordingSystem;
        doc "The system shall log video, still images, and defect data for compliance and later review.";
    }

    requirement def IlluminationControlRequirement {
        subject ledLight : LEDLightSource;
        doc "The operator shall adjust LED intensity for optimal image quality.";
    }

    requirement def OperatorGuidanceRequirement {
        subject operatorInterface : OperatorInterface;
        doc "The operator interface shall allow precise control of probe position and illumination.";
    }
}
