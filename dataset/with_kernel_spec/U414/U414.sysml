package TissueDopplerEchocardiography {
    attribute def Frequency :> ScalarValues::Real;
    attribute def Velocity :> ScalarValues::Real;
    attribute def Depth :> ScalarValues::Real;
    attribute def Time :> ScalarValues::Real;
    attribute def Amplitude :> ScalarValues::Real;
    attribute def DopplerShift :> ScalarValues::Real;

    item def UltrasoundPulse {
        attribute frequency : Frequency;
        attribute amplitude : Amplitude;
        attribute targetDepth : Depth;
    }

    item def EchoSignal {
        attribute frequency : Frequency;
        attribute amplitude : Amplitude;
        attribute depth : Depth;
    }

    item def ProcessedSignal :> EchoSignal {
        attribute depthCompensated : Amplitude;
    }

    item def VelocityData {
        attribute velocity : Velocity;
        attribute direction : ScalarValues::Integer;
    }

    item def ImageFrame {
        attribute width : ScalarValues::Integer;
        attribute height : ScalarValues::Integer;
        attribute colorMap : ScalarValues::Integer[0..*];
        attribute timestamp : Time;
    }

    item def ControlCommand {
        attribute mode : ScalarValues::String;
    }

    port def PulseOutPort {
        out item pulse : UltrasoundPulse;
    }
    port def PulseInPort {
        in item pulse : UltrasoundPulse;
    }
    port def EchoOutPort {
        out item echo : EchoSignal;
    }
    port def EchoInPort {
        in item echo : EchoSignal;
    }
    port def ProcessedOutPort {
        out item processed : ProcessedSignal;
    }
    port def ProcessedInPort {
        in item processed : ProcessedSignal;
    }
    port def VelocityOutPort {
        out item velocity : VelocityData;
    }
    port def VelocityInPort {
        in item velocity : VelocityData;
    }
    port def ImageOutPort {
        out item image : ImageFrame;
    }
    port def ImageInPort {
        in item image : ImageFrame;
    }
    port def ControlOutPort {
        out item command : ControlCommand;
    }
    port def ControlInPort {
        in item command : ControlCommand;
    }

    action def TransmitPulse {
        in targetDepth : Depth;
        out item pulse : UltrasoundPulse;
    }
    action def AcquireEcho {
        out item echo : EchoSignal;
    }
    action def Beamform {
        in item echo : EchoSignal;
        out item beamformedSignal : EchoSignal;
    }
    action def AmplifyAndFilter {
        in item rawSignal : EchoSignal;
        out item processedSignal : ProcessedSignal;
    }
    action def ComputeDopplerShift {
        in item transmitted : UltrasoundPulse;
        in item received : ProcessedSignal;
        out item shift : DopplerShift;
    }
    action def ApplyWallFilter {
        in item shift : DopplerShift;
        out item filteredShift : DopplerShift;
    }
    action def CalculateVelocity {
        in item dopplerShift : DopplerShift;
        out item velocityData : VelocityData;
    }
    action def GenerateColorImage {
        in item velocity : VelocityData;
        out item image : ImageFrame;
    }
    action def DisplayImage {
        in item image : ImageFrame;
    }

    action def ImagingCycle {
        first start;
        then action tx : TransmitPulse;
        then action acq : AcquireEcho;
        then action bf : Beamform {
            in item echo = acq.echo;
        }
        then action amp : AmplifyAndFilter {
            in item rawSignal = bf.beamformedSignal;
        }
        then action dp : ComputeDopplerShift {
            in item transmitted = tx.pulse;
            in item received = amp.processedSignal;
        }
        then action wf : ApplyWallFilter {
            in item shift = dp.shift;
        }
        then action vel : CalculateVelocity {
            in item dopplerShift = wf.filteredShift;
        }
        then action img : GenerateColorImage {
            in item velocity = vel.velocityData;
        }
        then action disp : DisplayImage {
            in item image = img.image;
        }
    }

    part def TransducerArray {
        port pulseIn : PulseInPort;
        port echoOut : EchoOutPort;
        port ctrl : ControlInPort;
        action transmit : TransmitPulse;
        action receive : AcquireEcho;
    }

    part def BeamformingUnit {
        port pulseOut : PulseOutPort;
        port echoIn : EchoInPort;
        port signalOut : EchoOutPort;
        port ctrl : ControlInPort;
        action steerAndFocus;
        action beamform : Beamform;
    }

    part def SignalProcessor {
        port signalIn : EchoInPort;
        port signalOut : ProcessedOutPort;
        port ctrl : ControlInPort;
        action amplify : AmplifyAndFilter;
    }

    part def DopplerAnalyzer {
        port signalIn : ProcessedInPort;
        port velocityOut : VelocityOutPort;
        port ctrl : ControlInPort;
        action doppler : ComputeDopplerShift;
        action wallFilter : ApplyWallFilter;
        action velocity : CalculateVelocity;
    }

    part def ImageGenerator {
        port velocityIn : VelocityInPort;
        port imageOut : ImageOutPort;
        port ctrl : ControlInPort;
        action generate : GenerateColorImage;
    }

    part def Display {
        port imageIn : ImageInPort;
        port ctrl : ControlInPort;
        action display : DisplayImage;
    }

    part def SystemController {
        port cmdIn : ControlInPort;
        port ctrlOut : ControlOutPort;

        state controllerState {
            entry; then Standby;
            state Standby;
            state Imaging {
                do action imagingCycle : ImagingCycle;
            }
            state Frozen;
            state Review;
            transition first Standby accept cmd : ControlCommand via cmdIn if cmd.mode == "Start" then Imaging;
            transition first Imaging accept cmd : ControlCommand via cmdIn if cmd.mode == "Freeze" then Frozen;
            transition first Frozen accept cmd : ControlCommand via cmdIn if cmd.mode == "Resume" then Imaging;
            transition first Imaging accept cmd : ControlCommand via cmdIn if cmd.mode == "Stop" then Standby;
            transition first Standby accept cmd : ControlCommand via cmdIn if cmd.mode == "Review" then Review;
            transition first Review accept cmd : ControlCommand via cmdIn if cmd.mode == "ExitReview" then Standby;
        }
    }

    part tdeSystem {
        part transducer : TransducerArray;
        part beamformer : BeamformingUnit;
        part signalProc : SignalProcessor;
        part doppler : DopplerAnalyzer;
        part imgGen : ImageGenerator;
        part controller : SystemController;
        part display : Display;

        connect beamformer.pulseOut to transducer.pulseIn;
        connect transducer.echoOut to beamformer.echoIn;
        connect beamformer.signalOut to signalProc.signalIn;
        connect signalProc.signalOut to doppler.signalIn;
        connect doppler.velocityOut to imgGen.velocityIn;
        connect imgGen.imageOut to display.imageIn;
        connect controller.ctrlOut to transducer.ctrl;
        connect controller.ctrlOut to beamformer.ctrl;
        connect controller.ctrlOut to signalProc.ctrl;
        connect controller.ctrlOut to doppler.ctrl;
        connect controller.ctrlOut to imgGen.ctrl;
        connect controller.ctrlOut to display.ctrl;
    }

    requirement TissueVelocityMeasurement {
        doc /* The system shall measure myocardial tissue velocity with an accuracy of ±0.5 cm/s. */
    }

    requirement WallFiltering {
        doc /* The system shall filter out low-frequency signals from cardiac wall motion to isolate myocardial contraction velocities. */
    }

    requirement ColorMapping {
        doc /* The system shall map tissue velocities to a color scale (red toward probe, blue away). */
    }

    requirement RealTimeImaging {
        doc /* The system shall update the velocity image at a frame rate of at least 30 Hz. */
    }

    requirement ModeControl {
        doc /* The system shall support standby, imaging, frozen, and review modes. */
    }

    satisfy TissueVelocityMeasurement by tdeSystem.doppler;
    satisfy WallFiltering by tdeSystem.doppler.wallFilter;
    satisfy ColorMapping by tdeSystem.imgGen.generate;
    satisfy RealTimeImaging by tdeSystem.controller;
    satisfy ModeControl by tdeSystem.controller;
}
