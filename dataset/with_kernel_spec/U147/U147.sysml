package 'Argus Retinal Prosthesis System' {
    private import ScalarValues::Real;
    private import ScalarValues::Integer;

    item def VideoFrame {
        attribute width : Integer;
        attribute height : Integer;
        attribute frameRate : Real; /* Hz */
    }
    item def StimulationInstruction {
        attribute electrodeId : Integer;
        attribute amplitude : Real; /* mA */
        attribute pulseWidth : Real; /* ms */
        attribute frequency : Real; /* Hz */
    }
    item def WirelessPowerAndData {
        attribute voltage : Real; /* V */
        attribute current : Real; /* mA */
        attribute instruction : StimulationInstruction;
    }
    item def ElectricalPulse {
        attribute amplitude : Real; /* mA */
        attribute duration : Real; /* ms */
    }
    item def NeuralSignal {
        attribute spikeRate : Real; /* Hz */
    }

    port def VideoOutPort { out item video : VideoFrame; }
    port def VideoInPort { in item video : VideoFrame; }
    port def InstructionOutPort { out item instructions : StimulationInstruction; }
    port def InstructionInPort { in item instructions : StimulationInstruction; }
    port def WirelessOutPort { out item signal : WirelessPowerAndData; }
    port def WirelessInPort { in item signal : WirelessPowerAndData; }
    port def PulseOutPort { out item pulse : ElectricalPulse; }
    port def PulseInPort { in item pulse : ElectricalPulse; }
    port def NeuralOutPort { out item signal : NeuralSignal; }
    port def NeuralInPort { in item signal : NeuralSignal; }

    action def ProcessVideo {
        in video : VideoFrame;
        out instructions : StimulationInstruction;
    }
    action def GeneratePulses {
        in instructions : StimulationInstruction;
        out pulse : ElectricalPulse;
    }
    action def StimulateRetina {
        in pulse : ElectricalPulse;
        out signal : NeuralSignal;
    }

    part def VideoCamera {
        port videoOut : VideoOutPort;
    }
    part def VideoProcessingUnit {
        port videoIn : VideoInPort;
        port instructionOut : InstructionOutPort;
        perform action processVideo : ProcessVideo {
            in video = videoIn.video;
            out instructions = instructionOut.instructions;
        }
        state vpuStates {
            state idle;
            state processing;
            transition startProcessing from idle to processing;
            transition completeProcessing from processing to idle;
        }
    }
    part def TransmitterCoil {
        port instructionIn : InstructionInPort;
        port wirelessOut : WirelessOutPort;
    }
    part def ReceiverCoil {
        port wirelessIn : WirelessInPort;
        port instructionOut : InstructionOutPort;
    }
    part def Stimulator {
        port instructionIn : InstructionInPort;
        port pulseOut : PulseOutPort;
        perform action generatePulses : GeneratePulses {
            in instructions = instructionIn.instructions;
            out pulse = pulseOut.pulse;
        }
        state stimulatorStates {
            state standby;
            state active;
            transition activate from standby to active;
            transition deactivate from active to standby;
        }
    }
    part def ElectrodeArray {
        attribute rows : Integer = 6;
        attribute columns : Integer = 10;
        attribute totalElectrodes : Integer = 60;
        port pulseIn : PulseInPort;
        port neuralOut : NeuralOutPort;
        perform action stimulate : StimulateRetina {
            in pulse = pulseIn.pulse;
            out signal = neuralOut.signal;
        }
    }
    part def Retina {
        port neuralIn : NeuralInPort;
        port opticNerveOut : NeuralOutPort;
    }
    part def OpticNerve {
        port neuralIn : NeuralInPort;
        port neuralOut : NeuralOutPort;
    }
    part def Brain {
        port neuralIn : NeuralInPort;
    }

    requirement def RestoreFunctionalVision {
        doc /* The system shall restore a degree of functional vision to patients with degenerative retinal diseases by bypassing damaged photoreceptors and directly stimulating viable retinal nerve cells. */
    }
    requirement def ElectrodeArraySpec {
        doc /* The implanted electrode array shall consist of a 6x10 grid of 60 microelectrodes surgically secured to the retinal surface. */
        attribute electrodeCount : Integer = 60;
    }
    requirement def PowerDeliverySpec {
        doc /* The wireless link shall deliver sufficient power to operate the implanted stimulator and electrode array continuously during use. */
    }

    requirement restoreVision : RestoreFunctionalVision;
    requirement electrodeSpec : ElectrodeArraySpec;
    requirement powerSpec : PowerDeliverySpec;

    part argusSystem {
        satisfy restoreVision;
        satisfy electrodeSpec;
        satisfy powerSpec;

        part externalSubsystem {
            part camera : VideoCamera;
            part vpu : VideoProcessingUnit;
            part txCoil : TransmitterCoil;
            
            flow of video : VideoFrame from camera.videoOut.video to vpu.videoIn.video;
            flow of instructions : StimulationInstruction from vpu.instructionOut.instructions to txCoil.instructionIn.instructions;
        }
        part internalSubsystem {
            part rxCoil : ReceiverCoil;
            part stimulator : Stimulator;
            part electrodeArray : ElectrodeArray;
            
            flow of instructions : StimulationInstruction from rxCoil.instructionOut.instructions to stimulator.instructionIn.instructions;
            flow of pulse : ElectricalPulse from stimulator.pulseOut.pulse to electrodeArray.pulseIn.pulse;
        }
        part retina : Retina;
        part opticNerve : OpticNerve;
        part brain : Brain;

        flow of signal : WirelessPowerAndData from externalSubsystem.txCoil.wirelessOut.signal to internalSubsystem.rxCoil.wirelessIn.signal;
        flow of signal : NeuralSignal from internalSubsystem.electrodeArray.neuralOut.signal to retina.neuralIn.signal;
        flow of signal : NeuralSignal from retina.opticNerveOut.signal to opticNerve.neuralIn.signal;
        flow of signal : NeuralSignal from opticNerve.neuralOut.signal to brain.neuralIn.signal;
    }
}
