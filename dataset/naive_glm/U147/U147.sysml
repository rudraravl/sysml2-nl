package ArgusRetinalProsthesis {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types with Units =====
    
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "uA"; }
    value type Frequency :> Real { unit "Hz"; }
    value type DataRate :> Real { unit "Mbps"; }
    value type PixelCount :> Integer;
    value type ElectrodeCount :> Integer;
    value type PulseDuration :> Real { unit "us"; }
    value type Distance :> Real { unit "mm"; }
    value type Power :> Real { unit "mW"; }
    value type Temperature :> Real { unit "degC"; }
    
    // ===== Item Types =====
    
    item def VideoFrame {
        attribute width : PixelCount = 640;
        attribute height : PixelCount = 480;
        attribute frameRate : Frequency = 30.0;
        attribute pixelData : List<Real> [0..*];
    }
    
    item def StimulationInstruction {
        attribute electrodeID : Integer;
        attribute pulseAmplitude : Current;
        attribute pulseDuration : PulseDuration;
        attribute pulseFrequency : Frequency;
        attribute active : Boolean;
    }
    
    item def StimulationPattern {
        attribute instructions : List<StimulationInstruction> [0..*];
        attribute timestamp : Real;
    }
    
    item def ElectricalPulse {
        attribute amplitude : Current;
        attribute duration : PulseDuration;
        attribute frequency : Frequency;
        attribute polarity : ScalarValues::Boolean;
    }
    
    item def WirelessSignal {
        attribute dataPayload : List<StimulationInstruction> [0..*];
        attribute powerLevel : Power;
        attribute carrierFrequency : Frequency;
    }
    
    item def PowerSignal {
        attribute voltage : Voltage;
        attribute current : Current;
    }
    
    item def NeuralSignal {
        attribute intensity : Real;
        attribute electrodeID : Integer;
    }
    
    // ===== Port Definitions =====
    
    port def VideoPort {
        out item video : VideoFrame;
    }
    
    port def InstructionPort {
        out item pattern : StimulationPattern;
    }
    
    port def WirelessLinkPort {
        out item signal : WirelessSignal;
        in item ack : Boolean;
    }
    
    port def ReceiverPort {
        in item signal : WirelessSignal;
        out item ack : Boolean;
    }
    
    port def StimulatorControlPort {
        in item pattern : StimulationPattern;
        in item power : PowerSignal;
    }
    
    port def ElectrodeDrivePort {
        out item pulse : ElectricalPulse;
    }
    
    port def NeuralInterfacePort {
        out item neuralSignal : NeuralSignal;
    }
    
    // ===== Requirements =====
    
    requirement def RestoreFunctionalVision {
        doc "The system shall restore a degree of functional vision to users blinded by retinal degenerative diseases."
        attribute targetUsers : String = "retinitis pigmentosa patients";
        attribute perceptionCapability : String = "shapes, movement, contrast";
    }
    
    requirement def WirelessDataPowerTransfer {
        doc "The system shall transmit stimulation instructions and power wirelessly from external to implanted components."
        attribute carrierFrequency : Frequency = 125.0;
        attribute maxPowerTransfer : Power = 250.0;
        attribute maxRange : Distance = 25.0;
    }
    
    requirement def ElectrodeArraySpec {
        doc "The implanted electrode array shall consist of 60 electrodes in a 6x10 configuration."
        attribute rows : Integer = 6;
        attribute columns : Integer = 10;
        attribute totalElectrodes : ElectrodeCount = 60;
        attribute maxStimulationCurrent : Current = 1000.0;
        attribute maxPulseDuration : PulseDuration = 500.0;
    }
    
    requirement def VideoProcessingLatency {
        doc "The VPU shall process video frames with end-to-end latency not exceeding 50 ms."
        attribute maxLatency : Real = 50.0;
        attribute frameRate : Frequency = 30.0;
    }
    
    requirement def ImplantBiocompatibility {
        doc "All implanted components shall be biocompatible and operate within safe temperature limits."
        attribute maxOperatingTemp : Temperature = 40.0;
        attribute implantLifetimeYears : Integer = 5;
    }
    
    // ===== External Subsystem Parts =====
    
    part def Eyeglasses {
        attribute weight : Real = 50.0;
        attribute frameMaterial : String = "Titanium";
        port videoOut : VideoPort;
        port wirelessOut : WirelessLinkPort;
        
        part camera : MiniatureCamera {
            port videoOut : VideoPort;
            attribute resolution : PixelCount = 307200;
            attribute frameRate : Frequency = 30.0;
            attribute fieldOfView : Real = 60.0;
            
            state def CameraState {
                entry; then Operational;
                state Operational;
                transition Operational to Operational
                    on videoOut.video;
                transition Operational to Operational
                    on powerLoss;
            }
            
            perform action captureFrame {
                out frame : VideoFrame;
            }
        }
        
        part transmitterCoil : TransmitterCoil {
            port wirelessOut : WirelessLinkPort;
            port instructionIn : InstructionPort;
            attribute carrierFrequency : Frequency = 125.0;
            attribute transmitPower : Power = 250.0;
            attribute coilDiameter : Distance = 30.0;
            
            perform action modulateSignal {
                in pattern : StimulationPattern;
                out signal : WirelessSignal;
            }
        }
        
        connection camera.videoOut to videoOut;
        connection transmitterCoil.wirelessOut to wirelessOut;
    }
    
    part def MiniatureCamera {
        port videoOut : VideoPort;
        attribute resolution : PixelCount;
        attribute frameRate : Frequency;
        attribute fieldOfView : Real;
        attribute powerConsumption : Power = 50.0;
        
        perform action captureVideo {
            out video : VideoFrame;
        }
    }
    
    part def TransmitterCoil {
        port wirelessOut : WirelessLinkPort;
        port instructionIn : InstructionPort;
        attribute carrierFrequency : Frequency;
        attribute transmitPower : Power;
        attribute coilDiameter : Distance;
        
        perform action transmitWireless {
            in pattern : StimulationPattern;
            out signal : WirelessSignal;
        }
    }
    
    part def VideoProcessingUnit {
        port videoIn : VideoPort;
        port instructionOut : InstructionPort;
        port powerOut : ~InstructionPort;
        attribute processingLatency : Real = 35.0;
        attribute weight : Real = 120.0;
        attribute batteryLife : Real = 8.0;
        attribute algorithm : String = "Custom retinal mapping";
        
        perform action processVideo {
            in video : VideoFrame;
            out pattern : StimulationPattern;
            
            // Decompose into sub-actions
            action preprocessFrame {
                in rawFrame : VideoFrame;
                out processedFrame : VideoFrame;
            }
            action mapToElectrodes {
                in frame : VideoFrame;
                out instructions : List<StimulationInstruction>;
            }
            action assemblePattern {
                in instructions : List<StimulationInstruction>;
                out pattern : StimulationPattern;
            }
            
            flow preprocessFrame.processedFrame to mapToElectrodes.frame;
            flow mapToElectrodes.instructions to assemblePattern.instructions;
            flow assemblePattern.pattern to pattern;
        }
        
        state def VPUState {
            entry; then Idle;
            state Idle;
            state Processing;
            state LowBattery;
            state Fault;
            
            transition Idle to Processing
                on videoIn.video
                guard batteryLife > 0.1;
            transition Processing to Idle
                on instructionOut.pattern;
            transition Processing to Fault
                on error;
            transition Idle to LowBattery
                guard batteryLife <= 0.1;
            transition LowBattery to Idle
                guard batteryLife > 0.5;
        }
    }
    
    // ===== Internal Subsystem Parts =====
    
    part def ReceiverCoil {
        port receiverIn : ReceiverPort;
        port signalOut : ~StimulatorControlPort;
        attribute carrierFrequency : Frequency = 125.0;
        attribute coilDiameter : Distance = 25.0;
        attribute alignmentTolerance : Distance = 5.0;
        
        perform action receiveWireless {
            in incoming : WirelessSignal;
            out pattern : StimulationPattern;
            out power : PowerSignal;
        }
    }
    
    part def ElectronicsCase {
        port controlIn : StimulatorControlPort;
        port electrodeOut : ElectrodeDrivePort;
        attribute caseMaterial : String = "Hermetic titanium";
        attribute dimensions : String = "25x25x5 mm";
        attribute implantLocation : String = "Scleral surface";
        
        part stimulator : Stimulator {
            port controlIn : StimulatorControlPort;
            port electrodeOut : ElectrodeDrivePort;
            attribute maxChannels : ElectrodeCount = 60;
            attribute outputVoltageRange : Voltage = 20.0;
            attribute pulseResolution : PulseDuration = 1.0;
            
            perform action generatePulses {
                in pattern : StimulationPattern;
                out pulses : List<ElectricalPulse>;
                
                action decodeInstructions {
                    in pattern : StimulationPattern;
                    out instructions : List<StimulationInstruction>;
                }
                action convertToPulses {
                    in instructions : List<StimulationInstruction>;
                    out pulses : List<ElectricalPulse>;
                }
                
                flow decodeInstructions.instructions to convertToPulses.instructions;
                flow convertToPulses.pulses to pulses;
            }
            
            state def StimulatorState {
                entry; then Standby;
                state Standby;
                state Active;
                state Error;
                
                transition Standby to Active
                    on controlIn.pattern;
                transition Active to Standby
                    guard controlIn.pattern == null;
                transition Active to Error
                    on fault;
                transition Error to Standby
                    on reset;
            }
        }
        
        connection stimulator.controlIn to controlIn;
        connection stimulator.electrodeOut to electrodeOut;
    }
    
    part def Stimulator {
        port controlIn : StimulatorControlPort;
        port electrodeOut : ElectrodeDrivePort;
        attribute maxChannels : ElectrodeCount;
        attribute outputVoltageRange : Voltage;
        attribute pulseResolution : PulseDuration;
        
        perform action generatePulses {
            in pattern : StimulationPattern;
            out pulses : List<ElectricalPulse>;
        }
    }
    
    part def ElectrodeArray {
        port driveIn : ElectrodeDrivePort;
        port neuralOut : NeuralInterfacePort;
        attribute rows : Integer = 6;
        attribute columns : Integer = 10;
        attribute electrodeCount : ElectrodeCount = 60;
        attribute electrodeDiameter : Distance = 0.2;
        attribute arrayDimensions : String = "5x3 mm";
        attribute implantLocation : String = "Epiretinal surface";
        
        part electrodes : Electrode[60] {
            port driveIn : ElectrodeDrivePort;
            port neuralOut : NeuralInterfacePort;
            attribute rowID : Integer;
            attribute columnID : Integer;
            attribute impedance : Real = 1000.0;
            attribute maxCurrent : Current = 1000.0;
            
            perform action stimulateTissue {
                in pulse : ElectricalPulse;
                out neuralSignal : NeuralSignal;
            }
        }
        
        perform action deliverStimulation {
            in pulse : ElectricalPulse;
            out neuralSignals : List<NeuralSignal>;
            
            action distributePulse {
                in pulse : ElectricalPulse;
                out distributedPulses : List<ElectricalPulse>;
            }
            action activateElectrodes {
                in pulses : List<ElectricalPulse>;
                out signals : List<NeuralSignal>;
            }
            
            flow distributePulse.distributedPulses to activateElectrodes.pulses;
            flow activateElectrodes.signals to neuralSignals;
        }
    }
    
    part def Electrode {
        port driveIn : ElectrodeDrivePort;
        port neuralOut : NeuralInterfacePort;
        attribute rowID : Integer;
        attribute columnID : Integer;
        attribute impedance : Real;
        attribute maxCurrent : Current;
        attribute material : String = "Platinum-iridium";
        
        perform action stimulateTissue {
            in pulse : ElectricalPulse;
            out neuralSignal : NeuralSignal;
        }
    }
    
    // ===== Biological Components =====
    
    part def Retina {
        port neuralIn : NeuralInterfacePort;
        attribute viableCells : Integer;
        attribute location : String = "Posterior eye";
        
        part nerveCells : RetinalNerveCell[0..*] {
            port neuralIn : NeuralInterfacePort;
            attribute cellType : String = "Ganglion/Bipolar";
            attribute activationThreshold : Current = 10.0;
            
            perform action transmitSignal {
                in neuralSignal : NeuralSignal;
                out opticNerveSignal : NeuralSignal;
            }
        }
        
        perform action processStimulation {
            in neuralSignals : List<NeuralSignal>;
            out opticNerveSignals : List<NeuralSignal>;
        }
    }
    
    part def RetinalNerveCell {
        port neuralIn : NeuralInterfacePort;
        attribute cellType : String;
        attribute activationThreshold : Current;
        
        perform action transmitSignal {
            in neuralSignal : NeuralSignal;
            out opticNerveSignal : NeuralSignal;
        }
    }
    
    part def OpticNerve {
        port nerveIn : NeuralInterfacePort;
        port nerveOut : NeuralInterfacePort;
        attribute fiberCount : Integer = 1200000;
        
        perform action conductSignals {
            in inputSignals : List<NeuralSignal>;
            out outputSignals : List<NeuralSignal>;
        }
    }
    
    part def VisualCortex {
        port nerveIn : NeuralInterfacePort;
        attribute location : String = "Occipital lobe";
        
        perform action interpretSignals {
            in nerveSignals : List<NeuralSignal>;
            out perception : String;
        }
        
        state def PerceptionState {
            entry; then Receiving;
            state Receiving;
            state Perceiving;
            state NoSignal;
            
            transition Receiving to Perceiving
                on nerveIn.neuralSignal;
            transition Perceiving to Receiving
                guard nerveIn.neuralSignal == null;
            transition Receiving to NoSignal
                after 1000 [ms];
            transition NoSignal to Receiving
                on nerveIn.neuralSignal;
        }
    }
    
    // ===== Top-Level System =====
    
    part def ArgusSystem {
        satisfy RestoreFunctionalVision;
        satisfy WirelessDataPowerTransfer;
        satisfy ElectrodeArraySpec;
        satisfy VideoProcessingLatency;
        satisfy ImplantBiocompatibility;
        
        attribute systemName : String = "Argus II Retinal Prosthesis";
        attribute systemVersion : String = "2.0";
        attribute patientID : String;
        
        part externalSubsystem : ExternalSubsystem {
            port videoOut : VideoPort;
            port wirelessOut : WirelessLinkPort;
            
            part eyeglasses : Eyeglasses {
                port videoOut : VideoPort;
                port wirelessOut : WirelessLinkPort;
            }
            
            part vpu : VideoProcessingUnit {
                port videoIn : VideoPort;
                port instructionOut : InstructionPort;
            }
            
            connection eyeglasses.camera.videoOut to vpu.videoIn;
            connection vpu.instructionOut to eyeglasses.transmitterCoil.instructionIn;
            connection eyeglasses.videoOut to videoOut;
            connection eyeglasses.wirelessOut to wirelessOut;
        }
        
        part internalSubsystem : InternalSubsystem {
            port wirelessIn : ReceiverPort;
            port neuralOut : NeuralInterfacePort;
            
            part receiverCoil : ReceiverCoil {
                port receiverIn : ReceiverPort;
                port signalOut : StimulatorControlPort;
            }
            
            part electronicsCase : ElectronicsCase {
                port controlIn : StimulatorControlPort;
                port electrodeOut : ElectrodeDrivePort;
            }
            
            part electrodeArray : ElectrodeArray {
                port driveIn : ElectrodeDrivePort;
                port neuralOut : NeuralInterfacePort;
            }
            
            connection receiverCoil.signalOut to electronicsCase.controlIn;
            connection electronicsCase.electrodeOut to electrodeArray.driveIn;
            connection receiverCoil.receiverIn to wirelessIn;
            connection electrodeArray.neuralOut to neuralOut;
        }
        
        part biologicalInterface : BiologicalInterface {
            port neuralIn : NeuralInterfacePort;
            
            part retina : Retina {
                port neuralIn : NeuralInterfacePort;
            }
            
            part opticNerve : OpticNerve {
                port nerveIn : NeuralInterfacePort;
                port nerveOut : NeuralInterfacePort;
            }
            
            part visualCortex : VisualCortex {
                port nerveIn : NeuralInterfacePort;
            }
            
            connection retina.neuralIn to neuralIn;
            connection retina to opticNerve.nerveIn;
            connection opticNerve.nerveOut to visualCortex.nerveIn;
        }
        
        // System-level connections
        connection externalSubsystem.wirelessOut to internalSubsystem.wirelessIn;
        connection internalSubsystem.neuralOut to biologicalInterface.neuralIn;
        
        // System-level behavior
        perform action systemOperation {
            in environment : VideoFrame;
            out perception : String;
            
            action captureEnvironment {
                in env : VideoFrame;
                out frame : VideoFrame;
            }
            action processAndTransmit {
                in frame : VideoFrame;
                out signal : WirelessSignal;
            }
            action receiveAndStimulate {
                in signal : WirelessSignal;
                out neuralSignals : List<NeuralSignal>;
            }
            action biologicalPerception {
                in neuralSignals : List<NeuralSignal>;
                out perception : String;
            }
            
            flow captureEnvironment.frame to processAndTransmit.frame;
            flow processAndTransmit.signal to receiveAndStimulate.signal;
            flow receiveAndStimulate.neuralSignals to biologicalPerception.neuralSignals;
            flow biologicalPerception.perception to perception;
        }
        
        state def SystemState {
            entry; then Initializing;
            state Initializing;
            state Operational;
            state Standby;
            state Fault;
            state Calibration;
            
            transition Initializing to Operational
                when (externalSubsystem.vpu.batteryLife > 0.5 && internalSubsystem.receiverCoil.alignmentTolerance < 5.0);
            transition Operational to Standby
                on userCommand;
            transition Standby to Operational
                on userCommand;
            transition Operational to Calibration
                on calibrateRequest;
            transition Calibration to Operational
                on calibrationComplete;
            transition Operational to Fault
                on systemError;
            transition Fault to Initializing
                on reset;
        }
    }
    
    // ===== Verification =====
    
    verification VerifyWirelessTransfer {
        subject : WirelessDataPowerTransfer;
        objective {
            doc "Verify wireless data and power transfer meets specification."
        }
        return success : Boolean;
    }
    
    verification VerifyElectrodeCount {
        subject : ElectrodeArraySpec;
        objective {
            doc "Verify electrode array has exactly 60 electrodes in 6x10 configuration."
        }
        return success : Boolean;
    }
    
    verification VerifyProcessingLatency {
        subject : VideoProcessingLatency;
        objective {
            doc "Verify VPU processing latency does not exceed 50 ms."
        }
        return success : Boolean;
    }
}
