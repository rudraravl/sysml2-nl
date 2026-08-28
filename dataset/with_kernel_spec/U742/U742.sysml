package LaserBeamProfiler {
    private import ScalarValues::*;
    
    attribute def Micrometer;
    attribute def Milliwatt;
    attribute def Nanometer;
    attribute def Decibel;
    attribute def Millisecond;
    
    item def LaserBeam {
        attribute power : Milliwatt;
        attribute wavelength : Nanometer;
    }
    item def AttenuatedBeam :> LaserBeam;
    item def SplitBeam :> AttenuatedBeam;
    item def RawImage {
        attribute width : Integer;
        attribute height : Integer;
        attribute pixelSize : Micrometer = 5.5;
        attribute dynamicRange : Decibel = 60;
        attribute intensityMap : Real[*];
    }
    item def BeamProfile {
        attribute diameter : Micrometer;
        attribute centroidX : Micrometer;
        attribute centroidY : Micrometer;
        attribute ellipticity : Real;
        attribute peakIntensity : Real;
    }
    item def MeasurementSettings {
        attribute mode : OperationMode;
        attribute exposureTime : Millisecond;
    }
    
    enum def OperationMode {
        Continuous;
        Triggered;
        SingleShot;
    }
    
    item def Command;
    item def StartCommand :> Command;
    item def StopCommand :> Command;
    item def CalibrateCommand :> Command;
    item def ResetCommand :> Command;
    item def ExternalTrigger;
    item def ErrorSignal;
    
    port def LaserInPort { in item beam : LaserBeam; }
    port def AttenuatedOutPort { out item beam : AttenuatedBeam; }
    port def AttenuatedInPort { in item beam : AttenuatedBeam; }
    port def SplitOutPort { out item beam : SplitBeam; }
    port def SplitInPort { in item beam : SplitBeam; }
    port def ImageOutPort { out item image : RawImage; }
    port def ImageInPort { in item image : RawImage; }
    port def ProfileOutPort { out item profile : BeamProfile; }
    port def ProfileInPort { in item profile : BeamProfile; }
    port def CommandInPort { in item command : Command; }
    port def TriggerInPort { in item trig : ExternalTrigger; }
    port def SettingsOutPort { out item settings : MeasurementSettings; }
    port def SettingsInPort { in item settings : MeasurementSettings; }
    
    action def Attenuate {
        in item laser : LaserBeam;
        out item beam : AttenuatedBeam;
    }
    action def Split {
        in item beam : AttenuatedBeam;
        out item splitBeam : SplitBeam;
    }
    action def Capture {
        in item beam : SplitBeam;
        out item image : RawImage;
    }
    action def Process {
        in item image : RawImage;
        out item profile : BeamProfile;
    }
    action def Calibrate {
        out item status : Boolean;
    }
    action def HandleError;
    
    action def MeasureSequence {
        in item laser : LaserBeam;
        out item profile : BeamProfile;
        action attenuate : Attenuate {
            in item laser;
            out item beam;
        }
        succession flow from attenuate.beam to split.beam;
        action split : Split {
            in item beam;
            out item splitBeam;
        }
        succession flow from split.splitBeam to capture.beam;
        action capture : Capture {
            in item beam;
            out item image;
        }
        succession flow from capture.image to process.image;
        action process : Process {
            in item image;
            out item profile;
        }
        bind process.profile = profile;
    }
    
    state def BeamProfilerStates {
        attribute mode : OperationMode = OperationMode::Continuous;
        
        state idle;
        state calibrating {
            do action calibrateAction : Calibrate;
        }
        state measuring {
            do action measureSeq : MeasureSequence;
        }
        state processing;
        state errorState {
            do action handleError : HandleError;
        }
        
        transition first idle accept CalibrateCommand then calibrating;
        transition first idle accept StartCommand then measuring;
        transition first idle accept ExternalTrigger then measuring;
        
        transition first calibrating then idle;
        transition first measuring then processing;
        
        transition first processing if mode == OperationMode::Continuous then measuring;
        transition first processing if mode == OperationMode::Triggered then idle;
        transition first processing if mode == OperationMode::SingleShot then idle;
        
        transition first measuring accept StopCommand then idle;
        transition first processing accept StopCommand then idle;
        
        transition first idle accept ErrorSignal then errorState;
        transition first measuring accept ErrorSignal then errorState;
        transition first processing accept ErrorSignal then errorState;
        transition first calibrating accept ErrorSignal then errorState;
        transition first errorState accept ResetCommand then idle;
    }
    
    part def OpticalAttenuator {
        port inOptic : LaserInPort;
        port outOptic : AttenuatedOutPort;
        perform action attenuate : Attenuate {
            in item laser = inOptic.beam;
            out item beam = outOptic.beam;
        }
    }
    part def BeamSplitter {
        port inOptic : AttenuatedInPort;
        port outOptic : SplitOutPort;
        perform action split : Split {
            in item beam = inOptic.beam;
            out item splitBeam = outOptic.beam;
        }
    }
    part def ImagingSensor {
        port inOptic : SplitInPort;
        port outData : ImageOutPort;
        attribute pixelSize : Micrometer = 5.5;
        attribute dynamicRange : Decibel = 60;
        perform action capture : Capture {
            in item beam = inOptic.beam;
            out item image = outData.image;
        }
    }
    part def SignalProcessor {
        port inData : ImageInPort;
        port outData : ProfileOutPort;
        perform action process : Process {
            in item image = inData.image;
            out item profile = outData.profile;
        }
    }
    part def UserInterface {
        port inProfile : ProfileInPort;
        port inCommand : CommandInPort;
        port outSettings : SettingsOutPort;
    }
    part def CalibrationUnit {
        perform action calibrate : Calibrate;
    }
    
    part BeamProfiler {
        port laserIn : LaserInPort;
        port triggerIn : TriggerInPort;
        port operatorCommand : CommandInPort;
        port profileOut : ProfileOutPort;
        
        part attenuator : OpticalAttenuator;
        part splitter : BeamSplitter;
        part sensor : ImagingSensor;
        part processor : SignalProcessor;
        part ui : UserInterface;
        part calib : CalibrationUnit;
        
        flow from laserIn.beam to attenuator.inOptic.beam;
        flow from attenuator.outOptic.beam to splitter.inOptic.beam;
        flow from splitter.outOptic.beam to sensor.inOptic.beam;
        flow from sensor.outData.image to processor.inData.image;
        flow from processor.outData.profile to ui.inProfile.profile;
        flow from processor.outData.profile to profileOut.profile;
        flow from operatorCommand.command to ui.inCommand.command;
        
        state profilerState : BeamProfilerStates;
    }
    
    requirement def LaserProfilerRequirement {
        doc /* This is a Laser Beam Profiler system designed to accurately measure and analyze the spatial characteristics of an incident laser beam. Its primary function is to capture the cross-section of a laser beam and provide detailed data about its size, shape, intensity, and position. */;
        requirement def OpticalPathReq {
            doc /* An incoming laser beam first enters an optical attenuator, which reduces the beam power to a safe level to protect the sensitive internal optics. The attenuated beam then passes through a beam splitter, which directs the majority of the light onto a high-resolution imaging sensor. */;
        }
        requirement def DataProcessingReq {
            doc /* This raw image data is then transferred to a dedicated signal processor. The processor analyzes the image to calculate critical beam parameters, including the precise beam diameter, its center point centroid, and its roundness ellipticity. It compiles this information into a comprehensive beam profile data report. */;
        }
        requirement def UserInteractionReq {
            doc /* An operator interacts with the system through a user interface, which is used to set measurement parameters and to display the final analyzed beam profile. */;
        }
        requirement def CalibrationReq {
            doc /* The system also includes a calibration unit to ensure measurement accuracy. */;
        }
        requirement def OperationalModesReq {
            doc /* The profiler can operate in different modes, including a continuous mode for real-time monitoring, a triggered mode that initiates a measurement on an external signal, or a single-shot mode for taking one-off captures. */;
        }
        requirement def StateCycleReq {
            doc /* The entire system operates through a cycle of states, including idle, calibrating, measuring, and processing, with built-in error handling. */;
        }
    }
}
