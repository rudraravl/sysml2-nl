package UCT_System {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def AngleValue :> Real;
    attribute def ScanCommand;
    attribute def UltrasoundPulse;
    attribute def EchoSignal;
    attribute def ProjectionData;
    attribute def TomographicImage;

    port def CommandPort { out cmd : ScanCommand; }
    port def ImageInPort { in image : TomographicImage; }
    port def ImageOutPort { out image : TomographicImage; }
    port def ControlPort { out angle : AngleValue; }
    port def PulsePort { out pulse : UltrasoundPulse; in echo : EchoSignal; }
    port def DataPort { out data : ProjectionData; }

    action def TransmitPulse { out pulse : UltrasoundPulse; }
    action def ReceiveEcho { in echo : EchoSignal; out rawSignal : EchoSignal; }
    action def ProcessSignal { in rawSignal : EchoSignal; out projection : ProjectionData; }
    action def RotateGantry { in angle : AngleValue; }
    action def ReconstructImage { 
        in projections : ProjectionData[0..*]; 
        out image : TomographicImage; 
        doc /* Uses Filtered Back-Projection algorithm */
    }
    action def DisplayImage { in image : TomographicImage; }

    state def UCT_States {
        entry; then idle;
        state idle;
        transition idle_to_ready first idle accept cmd : ScanCommand then ready;
        state ready;
        transition ready_to_scanning first ready accept cmd : ScanCommand then scanning;
        state scanning {
            entry; 
            do action rotateGantry : RotateGantry;
            do action transmitPulse : TransmitPulse;
            do action receiveEcho : ReceiveEcho;
            do action processSignal : ProcessSignal;
        }
        transition scanning_to_reconstructing first scanning accept cmd : ScanCommand then reconstructing;
        state reconstructing {
            do action reconstructImage : ReconstructImage;
        }
        transition reconstructing_to_displaying first reconstructing then displaying;
        state displaying {
            do action displayImage : DisplayImage;
        }
        transition displaying_to_ready first displaying then ready;
    }

    part def PatientPositioningTable;
    part def CouplingMediumTank {
        doc /* Typically filled with degassed water */
    }

    part def TransducerRing {
        port pulseOut : PulsePort;
        port pulseIn : PulsePort;
    }

    part def RotationalGantry {
        part transducerRing : TransducerRing;
        part couplingTank : CouplingMediumTank;
        port controlIn : ControlPort;
        port pulseOut : PulsePort;
        port pulseIn : PulsePort;
    }

    part def SignalProcessingUnit {
        port rawIn : PulsePort;
        port dataOut : DataPort;
    }

    part def ReconstructionProcessor {
        port dataIn : DataPort;
        port imageOut : ImageOutPort;
    }

    part def ImagingWorkstation {
        port cmdOut : CommandPort;
        port imgIn : ImageInPort;
    }

    part def AcquisitionController {
        port cmdIn : CommandPort;
        port controlOut : ControlPort;
        port dataIn : DataPort;
        port imageIn : ImageInPort;
        port imgOut : ImageOutPort;

        exhibit UCT_States;
    }

    part def UCTSystem {
        part table : PatientPositioningTable;
        part gantry : RotationalGantry;
        part spu : SignalProcessingUnit;
        part recon : ReconstructionProcessor;
        part workstation : ImagingWorkstation;
        part controller : AcquisitionController;

        connect workstation.cmdOut to controller.cmdIn;
        connect controller.controlOut to gantry.controlIn;
        connect gantry.pulseOut to spu.rawIn;
        connect spu.dataOut to recon.dataIn;
        connect recon.imageOut to controller.imageIn;
        connect controller.imgOut to workstation.imgIn;
    }

    requirement def ImagingRequirement {
        doc /* The UCT system must produce high-resolution cross-sectional images. */
    }

    requirement def SafetyRequirement {
        doc /* The system must ensure non-invasive operation using sound waves. */
    }
}
