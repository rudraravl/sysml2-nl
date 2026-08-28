package VideoscopeSystem {
    import ScalarFunctions::*;
    import ISQ::*;

    // ===== Value Types =====
    attribute def Length :> Real { unit = 'm'; }
    attribute def Diameter :> Real { unit = 'mm'; }
    attribute def Voltage :> Real { unit = 'V'; }
    attribute def Brightness :> Real { unit = 'cd'; }
    attribute def Angle :> Real { unit = 'deg'; }
    attribute def Depth :> Real { unit = 'm'; }
    attribute def ResolutionWidth :> Integer;
    attribute def ResolutionHeight :> Integer;
    attribute def DisplaySize :> Real { unit = 'in'; }

    // ===== Item Types =====
    item def RawVideoFrame;
    item def ProcessedVideoFrame;
    item def DefectAlert;
    item def ControlCommand {
        attribute commandType : String;
        attribute value : Real;
    }
    item def PowerSignal {
        attribute voltage : Voltage;
    }

    // ===== Port Definitions =====
    port def ControlPort {
        out controlCommands : ControlCommand;
    }
    port def VideoInPort {
        in rawVideo : RawVideoFrame;
    }
    port def VideoOutPort {
        out processedVideo : ProcessedVideoFrame;
    }
    port def RawVideoOutPort {
        out rawVideo : RawVideoFrame;
    }
    port def PowerPort {
        in power : PowerSignal;
    }
    port def ArticulationControlPort {
        out articulationCommand : ControlCommand;
    }
    port def DepthControlPort {
        out depthCommand : ControlCommand;
    }
    port def BrightnessControlPort {
        out brightnessCommand : ControlCommand;
    }
    port def DefectAlertPort {
        out defectAlert : DefectAlert;
    }

    // ===== Requirements =====
    requirement def InsertionTubeSpec {
        attribute tubeLength : Length = 2.5;
        attribute tubeDiameter : Diameter = 6.0;
        attribute maxArticulationAngle : Angle = 180.0;
        requirement LengthRequirement { require tubeLength == 2.5; }
        requirement DiameterRequirement { require tubeDiameter == 6.0; }
        requirement ArticulationRequirement { require maxArticulationAngle == 180.0; }
    }

    requirement def ImageSensorSpec {
        attribute width : ResolutionWidth = 1920;
        attribute height : ResolutionHeight = 1080;
        requirement ResolutionRequirement { require width == 1920 and height == 1080; }
    }

    requirement def DisplaySpec {
        attribute displaySize : DisplaySize = 10.0;
        requirement DisplaySizeRequirement { require displaySize == 10.0; }
    }

    requirement def PowerSupplySpec {
        attribute nominalVoltage : Voltage = 12.0;
        requirement VoltageRequirement { require nominalVoltage == 12.0; }
    }

    requirement def VideoscopeSystemRequirements {
        requirement InsertionTube : InsertionTubeSpec;
        requirement ImageSensor : ImageSensorSpec;
        requirement Display : DisplaySpec;
        requirement Power : PowerSupplySpec;
    }

    // ===== Parts =====

    part def PowerSupply {
        attribute nominalVoltage : Voltage = 12.0;
        port powerOut : PowerPort;
        satisfy PowerSupplySpec;
    }

    part def LEDLightSource {
        attribute currentBrightness : Brightness = 0.0;
        attribute maxBrightness : Brightness = 1000.0;
        port powerIn : PowerPort;
        port brightnessControl : BrightnessControlPort;
        action def SetBrightness {
            in brightnessValue : Brightness;
        }
    }

    part def CMOSImageSensor {
        attribute width : ResolutionWidth = 1920;
        attribute height : ResolutionHeight = 1080;
        port powerIn : PowerPort;
        port videoOut : RawVideoOutPort;
        satisfy ImageSensorSpec;
        action def CaptureFrame {
            out frame : RawVideoFrame;
        }
    }

    part def ArticulationMechanism {
        attribute currentAngle : Angle = 0.0;
        attribute maxAngle : Angle = 180.0;
        port articulationControl : ArticulationControlPort;
        action def Steer {
            in targetAngle : Angle;
        }
    }

    part def InsertionTube {
        attribute tubeLength : Length = 2.5;
        attribute tubeDiameter : Diameter = 6.0;
        attribute currentDepth : Depth = 0.0;
        port depthControl : DepthControlPort;
        part tip : ArticulationMechanism;
        part imageSensor : CMOSImageSensor;
        part ledLight : LEDLightSource;
        satisfy InsertionTubeSpec;
        action def Advance {
            in distance : Depth;
        }
        action def Retract {
            in distance : Depth;
        }
    }

    part def VideoProcessingUnit {
        port videoIn : VideoInPort;
        port videoOut : VideoOutPort;
        port defectAlertOut : DefectAlertPort;
        action def EnhanceImage {
            in raw : RawVideoFrame;
            out processed : ProcessedVideoFrame;
        }
        action def DetectDefects {
            in processed : ProcessedVideoFrame;
            out alert : DefectAlert;
        }
    }

    part def Monitor {
        attribute displaySize : DisplaySize = 10.0;
        port videoIn : VideoInPort;
        satisfy DisplaySpec;
        action def DisplayVideo {
            in video : ProcessedVideoFrame;
        }
    }

    part def OperatorConsole {
        port controlOut : ControlPort;
        action def IssueControlCommand {
            out command : ControlCommand;
        }
    }

    part def Operator {
        action def GuideProbe;
        action def ObserveFeed;
        action def ConcludeInspection;
    }

    part def VideoscopeSystem {
        satisfy VideoscopeSystemRequirements;

        part powerSupply : PowerSupply;
        part insertionTube : InsertionTube;
        part videoProcessor : VideoProcessingUnit;
        part monitor : Monitor;
        part console : OperatorConsole;
        part operator : Operator;

        connection powerToTube : PowerPort connect powerSupply.powerOut to insertionTube.imageSensor.powerIn;
        connection powerToLED : PowerPort connect powerSupply.powerOut to insertionTube.ledLight.powerIn;
        connection sensorToProcessor : RawVideoOutPort connect insertionTube.imageSensor.videoOut to videoProcessor.videoIn;
        connection processorToMonitor : VideoOutPort connect videoProcessor.videoOut to monitor.videoIn;
        connection consoleToDepth : DepthControlPort connect console.controlOut to insertionTube.depthControl;
        connection consoleToArticulation : ArticulationControlPort connect console.controlOut to insertionTube.tip.articulationControl;
        connection consoleToBrightness : BrightnessControlPort connect console.controlOut to insertionTube.ledLight.brightnessControl;

        // ===== State Machine =====
        state def InspectionLifecycle {
            entry action { /* initialize system */ }
            state Idle {
                entry action { /* system ready */ }
                transition to Guiding
                    when console.controlOut.controlCommands.commandType == "start";
            }
            state Guiding {
                entry action { operator.GuideProbe(); }
                do action { insertionTube.Advance(0.01); }
                transition to Observing
                    when insertionTube.currentDepth > 0.0;
            }
            state Observing {
                entry action { operator.ObserveFeed(); }
                do action { monitor.DisplayVideo(videoProcessor.videoOut.processedVideo); }
                transition to DefectDetected
                    when videoProcessor.defectAlertOut.defectAlert != null;
                transition to Concluded
                    when console.controlOut.controlCommands.commandType == "complete";
            }
            state DefectDetected {
                entry action { /* alert operator */ }
                transition to Concluded
                    when console.controlOut.controlCommands.commandType == "acknowledge";
            }
            state Concluded {
                entry action { operator.ConcludeInspection(); }
                transition to Idle
                    when console.controlOut.controlCommands.commandType == "reset";
            }
        }

        behavior inspectionProcess : InspectionLifecycle;
    }
}
