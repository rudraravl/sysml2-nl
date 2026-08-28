package ParadromicsNeuralInterface {
    import ScalarValues::*;
    
    // ==========================================
    // Value Types
    // ==========================================
    
    value type Microvolt :> Real {
        doc /* Unit for neural signal amplitude in microvolts. */
    }
    
    value type Millivolt :> Real {
        doc /* Unit for amplified signal amplitude in millivolts. */
    }
    
    value type Microamp :> Real {
        doc /* Unit for stimulation current in microamps. */
    }
    
    value type Kilohertz :> Real {
        doc /* Unit for frequency in kilohertz. */
    }
    
    value type SamplesPerSecond :> Real {
        doc /* Unit for sampling rate in samples per second. */
    }
    
    value type GigabitPerSecond :> Real {
        doc /* Unit for data rate in gigabits per second. */
    }
    
    value type Micrometer :> Real {
        doc /* Unit for length in micrometers. */
    }
    
    value type Millimeter :> Real {
        doc /* Unit for length in millimeters. */
    }
    
    value type Milliwatt :> Real {
        doc /* Unit for power in milliwatts. */
    }
    
    value type ElectrodeCount :> Integer {
        doc /* Count of electrodes in the array. */
    }
    
    value type GainFactor :> Real {
        doc /* Dimensionless amplification factor. */
    }
    
    value type BitDepth :> Integer {
        doc /* Number of bits per sample. */
    }
    
    // ==========================================
    // Item Definitions
    // ==========================================
    
    item def NeuralSignal {
        attribute electrodeId : Integer;
        attribute amplitude : Microvolt;
        attribute timestamp : Real;
    }
    
    item def RawNeuralSignal :> NeuralSignal {
        doc /* Faint electrical signal recorded directly from a neuron. */
        attribute noiseFloor : Microvolt;
        attribute sourceDepth : Micrometer;
    }
    
    item def AmplifiedSignal :> NeuralSignal {
        doc /* Neural signal after analog amplification by the ASIC. */
        attribute amplifiedAmplitude : Millivolt;
        attribute gainApplied : GainFactor;
    }
    
    item def FilteredSignal :> NeuralSignal {
        doc /* Neural signal after noise filtering. */
        attribute filteredAmplitude : Millivolt;
        attribute bandwidthLow : Kilohertz;
        attribute bandwidthHigh : Kilohertz;
    }
    
    item def DigitalNeuralSample {
        doc /* A single digitized sample from one electrode channel. */
        attribute electrodeId : Integer;
        attribute sampleValue : Integer;
        attribute timestamp : Real;
        attribute samplingRate : SamplesPerSecond;
        attribute bitResolution : BitDepth;
    }
    
    item def DigitalNeuralDataPacket {
        doc /* A packet of digitized neural data from all electrodes. */
        attribute packetId : Integer;
        attribute samples : DigitalNeuralSample[0..*];
        attribute packetSize : Integer;
        attribute timestamp : Real;
    }
    
    item def StimulationPulse :> NeuralSignal {
        doc /* Electrical stimulation pulse to be delivered to a neuron. */
        attribute pulseAmplitude : Microamp;
        attribute pulseDuration : Real;
        attribute pulseFrequency : Kilohertz;
    }
    
    item def StimulationCommand {
        doc /* Command from external system to stimulate specific neurons. */
        attribute targetElectrodeIds : Integer[0..*];
        attribute pulses : StimulationPulse[0..*];
        attribute commandId : Integer;
    }
    
    item def DecodedIntent {
        doc /* Decoded user intent from neural activity. */
        attribute intentType : String;
        attribute confidence : Real;
        attribute cursorX : Real;
        attribute cursorY : Real;
        attribute selectedCharacter : String;
    }
    
    item def UserAction {
        doc /* Output action derived from decoded intent. */
        attribute actionType : String;
        attribute parameters : String;
    }
    
    item def FeedbackCommand {
        doc /* Feedback command sent from external system to implant for sensory stimulation. */
        attribute commandId : Integer;
        attribute targetElectrodeIds : Integer[0..*];
        attribute stimulationPulse : StimulationPulse;
    }
    
    // ==========================================
    // Requirements
    // ==========================================
    
    requirement def BidirectionalCommunicationReq {
        doc /* The system shall establish a direct, bidirectional communication link between the human brain and external digital devices. */
    }
    
    requirement def ElectrodeDensityRequirement {
        doc /* The microelectrode array shall have at least 1600 electrodes penetrating the cerebral cortex. */
        attribute minElectrodeCount : ElectrodeCount = 1600;
        attribute maxPenetrationDepth : Micrometer = 2000;
    }
    
    requirement def RecordingRateRequirement {
        doc /* The signal processing ASIC shall sample each electrode channel at 30,000 samples per second. */
        attribute minSamplingRate : SamplesPerSecond = 30000;
    }
    
    requirement def AmplificationRequirement {
        doc /* The signal processing ASIC shall amplify neural signals by a factor of 1000. */
        attribute minGain : GainFactor = 1000;
    }
    
    requirement def WirelessDataRateRequirement {
        doc /* The wireless transceiver shall transmit neural data at a minimum rate of 1 Gbps. */
        attribute minDataRate : GigabitPerSecond = 1.0;
    }
    
    requirement def BiocompatibilityRequirement {
        doc /* The packaging shall be hermetically sealed using Parylene-C for safe long-term implantation. */
        attribute material : String = "Parylene-C";
        attribute hermeticSeal : Boolean = true;
    }
    
    requirement def LongTermImplantationRequirement {
        doc /* The implanted device shall be designed for long-term clinical use in restoring communication or motor function. */
        attribute designLifeYears : Real = 10.0;
    }
    
    requirement def IntentDecodingRequirement {
        doc /* The external system shall decode neural signals to interpret user intent such as cursor movement or letter selection. */
        attribute minDecodingLatencyMs : Real = 50.0;
    }
    
    requirement def SensoryFeedbackRequirement {
        doc /* The system shall generate and deliver feedback commands to stimulate specific neurons for creating sensations such as touch. */
    }
    
    // ==========================================
    // Port Definitions
    // ==========================================
    
    port def NeuralTissuePort {
        doc /* Port interfacing with brain tissue for recording and stimulation. */
        out item rawSignals : RawNeuralSignal[0..*];
        in item stimulationPulses : StimulationPulse[0..*];
    }
    
    port def ElectrodeArrayPort {
        doc /* Port on the electrode array connecting to the ASIC. */
        out item rawSignals : RawNeuralSignal[0..*];
        in item stimulationPulses : StimulationPulse[0..*];
    }
    
    port def ASICInputPort {
        doc /* Analog input port on the ASIC from the electrode array. */
        in item rawSignals : RawNeuralSignal[0..*];
        out item stimulationPulses : StimulationPulse[0..*];
    }
    
    port def ASICOutputPort {
        doc /* Digital output port on the ASIC to the wireless transceiver. */
        out item digitalPackets : DigitalNeuralDataPacket[0..*];
        in item stimulationCommands : StimulationCommand[0..*];
    }
    
    port def WirelessUplinkPort {
        doc /* Port carrying neural data from implant to external system. */
        out item digitalPackets : DigitalNeuralDataPacket[0..*];
    }
    
    port def WirelessDownlinkPort {
        doc /* Port carrying commands from external system to implant. */
        in item feedbackCommands : FeedbackCommand[0..*];
        in item stimulationCommands : StimulationCommand[0..*];
    }
    
    port def ExternalWirelessPort {
        doc /* Port on the external system communicating with the implant. */
        in item digitalPackets : DigitalNeuralDataPacket[0..*];
        out item feedbackCommands : FeedbackCommand[0..*];
        out item stimulationCommands : StimulationCommand[0..*];
    }
    
    port def DecodedIntentPort {
        doc /* Port carrying decoded intent to the user interface. */
        out item decodedIntent : DecodedIntent;
    }
    
    // ==========================================
    // Action Definitions
    // ==========================================
    
    action def AmplifyAnalogSignal {
        doc /* Amplify the weak analog neural signal by a factor of 1000. */
        in rawSignal : RawNeuralSignal;
        out amplifiedSignal : AmplifiedSignal;
        attribute gain : GainFactor = 1000;
    }
    
    action def FilterAnalogNoise {
        doc /* Filter out unwanted noise from the amplified signal. */
        in amplifiedSignal : AmplifiedSignal;
        out filteredSignal : FilteredSignal;
        attribute lowCutoff : Kilohertz = 0.1;
        attribute highCutoff : Kilohertz = 7.5;
    }
    
    action def AnalogToDigitalConversion {
        doc /* Convert the filtered analog signal to a digital data stream. */
        in filteredSignal : FilteredSignal;
        out digitalSample : DigitalNeuralSample;
        attribute samplingRate : SamplesPerSecond = 30000;
        attribute bitResolution : BitDepth = 16;
    }
    
    action def PacketizeDigitalData {
        doc /* Package digital samples from all electrode channels into data packets. */
        in digitalSamples : DigitalNeuralSample[0..*];
        out dataPacket : DigitalNeuralDataPacket;
    }
    
    action def TransmitWirelessData {
        doc /* Transmit digital neural data packets wirelessly to the external system. */
        in dataPackets : DigitalNeuralDataPacket[0..*];
        attribute dataRate : GigabitPerSecond = 1.0;
    }
    
    action def ReceiveWirelessCommands {
        doc /* Receive wireless commands from the external system. */
        out feedbackCommand : FeedbackCommand;
        out stimulationCommand : StimulationCommand;
    }
    
    action def DecodeNeuralIntent {
        doc /* Interpret neural signals to determine the user's intent. */
        in neuralData : DigitalNeuralDataPacket[0..*];
        out decodedIntent : DecodedIntent;
    }
    
    action def GenerateFeedbackCommand {
        doc /* Generate stimulation commands for sensory feedback based on decoded intent. */
        in decodedIntent : DecodedIntent;
        out feedbackCommand : FeedbackCommand;
    }
    
    action def DeliverStimulation {
        doc /* Deliver electrical stimulation to specific neurons through the electrode array. */
        in stimulationPulse : StimulationPulse;
        attribute targetElectrodeId : Integer;
    }
    
    // ==========================================
    // State Machine Definition
    // ==========================================
    
    state def ImplantOperationalState {
        doc /* Operational state machine for the implanted device. */
        
        entry;
        
        state standby {
            doc /* Low-power standby mode. The implant waits in a minimal power state. */
            entry;
            exit;
            attribute powerConsumption : Milliwatt = 0.5;
        }
        
        state active {
            doc /* Active recording state. Neural signals are being recorded and processed. */
            entry;
            exit;
            attribute powerConsumption : Milliwatt = 15.0;
        }
        
        state transmitting {
            doc /* Transmitting state. Digital neural data is being sent to the external system. */
            entry;
            exit;
            attribute powerConsumption : Milliwatt = 25.0;
        }
        
        transition from entry to standby;
        transition from standby to active when activateCommand;
        transition from active to transmitting when dataBufferFull;
        transition from transmitting to active when transmissionComplete;
        transition from active to standby when deactivateCommand;
    }
    
    // ==========================================
    // Part Definitions — Implanted Device Components
    // ==========================================
    
    part def MicroelectrodeArray {
        doc /* High-density microelectrode array with 1600 electrodes for neural recording and stimulation. */
        
        satisfy ElectrodeDensityRequirement;
        
        attribute electrodeCount : ElectrodeCount = 1600;
        attribute penetrationDepth : Micrometer = 1500;
        attribute electrodeSpacing : Micrometer = 50;
        
        port tissueInterface : NeuralTissuePort;
        port arrayOutput : ElectrodeArrayPort;
        
        action recordNeuralActivity {
            doc /* Simultaneously listen to electrical signals from individual neurons. */
            out rawSignals : RawNeuralSignal[0..*];
        }
        
        action deliverElectricalStimulation {
            doc /* Deliver precise electrical stimulation to neurons when commanded. */
            in stimulationPulses : StimulationPulse[0..*];
        }
        
        connection from tissueInterface to arrayOutput;
    }
    
    part def SignalProcessingASIC {
        doc /* Custom signal processing chip for amplification, filtering, and digitization of neural signals. */
        
        satisfy RecordingRateRequirement;
        satisfy AmplificationRequirement;
        
        attribute gain : GainFactor = 1000;
        attribute samplingRate : SamplesPerSecond = 30000;
        attribute bitResolution : BitDepth = 16;
        attribute channelCount : ElectrodeCount = 1600;
        attribute powerConsumption : Milliwatt = 10.0;
        
        port analogInput : ASICInputPort;
        port digitalOutput : ASICOutputPort;
        
        action processNeuralSignals {
            doc /* Complete signal processing pipeline: amplify, filter, digitize, and packetize. */
            in rawSignals : RawNeuralSignal[0..*];
            out digitalPackets : DigitalNeuralDataPacket[0..*];
            
            perform AmplifyAnalogSignal;
            perform FilterAnalogNoise;
            perform AnalogToDigitalConversion;
            perform PacketizeDigitalData;
        }
        
        action routeStimulationCommands {
            doc /* Route received stimulation commands to the electrode array. */
            in stimulationCommands : StimulationCommand[0..*];
            out stimulationPulses : StimulationPulse[0..*];
        }
        
        connection from analogInput to digitalOutput;
    }
    
    part def WirelessTransceiver {
        doc /* High-speed wireless transceiver for transmitting neural data and receiving commands. */
        
        satisfy WirelessDataRateRequirement;
        
        attribute uplinkDataRate : GigabitPerSecond = 1.0;
        attribute downlinkDataRate : GigabitPerSecond = 0.01;
        attribute operatingFrequency : Kilohertz = 2400;
        attribute powerConsumption : Milliwatt = 15.0;
        
        port digitalInput : ASICOutputPort;
        port wirelessUplink : WirelessUplinkPort;
        port wirelessDownlink : WirelessDownlinkPort;
        
        action transmitNeuralData {
            doc /* Transmit digital neural data wirelessly out of the body. */
            in dataPackets : DigitalNeuralDataPacket[0..*];
        }
        
        action receiveExternalCommands {
            doc /* Receive commands from the external system. */
            out feedbackCommands : FeedbackCommand[0..*];
            out stimulationCommands : StimulationCommand[0..*];
        }
    }
    
    part def BiocompatiblePackaging {
        doc /* Hermetically sealed Parylene-C packaging for protecting implant electronics. */
        
        satisfy BiocompatibilityRequirement;
        
        attribute material : String = "Parylene-C";
        attribute thickness : Micrometer = 5;
        attribute hermeticSeal : Boolean = true;
        attribute biocompatible : Boolean = true;
        attribute sterilizationMethod : String = "Ethylene Oxide";
    }
    
    // ==========================================
    // Part Definition — Implanted Device
    // ==========================================
    
    part def ImplantedDevice {
        doc /* Fully implanted device containing the microelectrode array, ASIC, wireless transceiver, and biocompatible packaging. */
        
        satisfy LongTermImplantationRequirement;
        
        port brainInterface : NeuralTissuePort;
        port externalLinkUplink : WirelessUplinkPort;
        port externalLinkDownlink : WirelessDownlinkPort;
        
        part microelectrodeArray : MicroelectrodeArray;
        part signalProcessingChip : SignalProcessingASIC;
        part wirelessTransceiver : WirelessTransceiver;
        part packaging : BiocompatiblePackaging;
        
        // Connection: Electrode array to ASIC (analog signals and stimulation routing)
        connection arrayToASIC {
            from microelectrodeArray.arrayOutput to signalProcessingChip.analogInput;
            item rawSignals : RawNeuralSignal[0..*];
        }
        
        // Connection: ASIC to wireless transceiver (digital data and commands)
        connection ASICtoTransceiver {
            from signalProcessingChip.digitalOutput to wirelessTransceiver.digitalInput;
            item digitalPackets : DigitalNeuralDataPacket[0..*];
            item stimulationCommands : StimulationCommand[0..*];
        }
        
        // Connection: Wireless transceiver uplink to external port
        connection transceiverUplink {
            from wirelessTransceiver.wirelessUplink to externalLinkUplink;
            item digitalPackets : DigitalNeuralDataPacket[0..*];
        }
        
        // Connection: External downlink to wireless transceiver
        connection externalDownlink {
            from externalLinkDownlink to wirelessTransceiver.wirelessDownlink;
            item feedbackCommands : FeedbackCommand[0..*];
            item stimulationCommands : StimulationCommand[0..*];
        }
        
        // Connection: Brain tissue to electrode array
        connection brainToElectrodes {
            from brainInterface to microelectrodeArray.tissueInterface;
            item rawSignals : RawNeuralSignal[0..*];
            item stimulationPulses : StimulationPulse[0..*];
        }
        
        // State machine for implant operational states
        state operationalState : ImplantOperationalState;
    }
    
    // ==========================================
    // Part Definitions — External System Components
    // ==========================================
    
    part def WirelessReceiver {
        doc /* External wireless receiver that captures neural data transmitted from the implant. */
        
        port wirelessInput : WirelessUplinkPort;
        port dataOutput : ExternalWirelessPort;
        
        attribute antennaGain : Real = 3.0;
        attribute sensitivity : Microvolt = 1.0;
        
        action receiveNeuralData {
            doc /* Capture and demodulate wireless neural data from the implant. */
            in wirelessSignal : DigitalNeuralDataPacket[0..*];
            out recoveredData : DigitalNeuralDataPacket[0..*];
        }
    }
    
    part def NeuralSignalDecoder {
        doc /* Computational unit for interpreting neural signals to understand user intent. */
        
        satisfy IntentDecodingRequirement;
        
        attribute processingCapability : String = "GPU-accelerated deep learning";
        attribute modelType : String = "Recurrent Neural Network";
        attribute trainingDataset : String = "Calibration-based per user";
        
        action decodeIntent {
            doc /* Decode brain activity corresponding to desires such as cursor movement or letter selection. */
            in neuralData : DigitalNeuralDataPacket[0..*];
            out decodedIntent : DecodedIntent;
        }
        
        action calibrateDecoder {
            doc /* Calibrate the neural decoder for a specific user. */
            in calibrationData : DigitalNeuralDataPacket[0..*];
        }
    }
    
    part def FeedbackCommandGenerator {
        doc /* Generates feedback commands for sensory stimulation based on decoded intent. */
        
        satisfy SensoryFeedbackRequirement;
        
        action generateSensoryFeedback {
            doc /* Generate commands to stimulate specific neurons to create sensations such as touch. */
            in decodedIntent : DecodedIntent;
            out feedbackCommand : FeedbackCommand;
        }
    }
    
    part def UserInterface {
        doc /* External interface for the user to interact with digital devices. */
        
        port intentOutput : DecodedIntentPort;
        
        action displayCursor {
            doc /* Display cursor position based on decoded motor intent. */
            in decodedIntent : DecodedIntent;
        }
        
        action selectCharacter {
            doc /* Select and type a character based on decoded intent. */
            in decodedIntent : DecodedIntent;
            out selectedCharacter : String;
        }
    }
    
    // ==========================================
    // Part Definition — External System
    // ==========================================
    
    part def ExternalSystem {
        doc /* External processing system that communicates wirelessly with the implant and interprets neural signals. */
        
        satisfy IntentDecodingRequirement;
        satisfy SensoryFeedbackRequirement;
        
        port implantUplink : WirelessUplinkPort;
        port implantDownlink : WirelessDownlinkPort;
        port userOutput : DecodedIntentPort;
        
        part wirelessReceiver : WirelessReceiver;
        part neuralDecoder : NeuralSignalDecoder;
        part feedbackGenerator : FeedbackCommandGenerator;
        part userInterface : UserInterface;
        
        // Connection: Wireless receiver to neural decoder
        connection receiverToDecoder {
            from wirelessReceiver.dataOutput to neuralDecoder;
            item neuralData : DigitalNeuralDataPacket[0..*];
        }
        
        // Connection: Neural decoder to feedback generator
        connection decoderToFeedback {
            from neuralDecoder to feedbackGenerator;
            item decodedIntent : DecodedIntent;
        }
        
        // Connection: Neural decoder to user interface
        connection decoderToUserInterface {
            from neuralDecoder to userInterface;
            item decodedIntent : DecodedIntent;
        }
        
        // Connection: Feedback generator to wireless downlink
        connection feedbackToDownlink {
            from feedbackGenerator to implantDownlink;
            item feedbackCommands : FeedbackCommand[0..*];
        }
        
        // Connection: External wireless input to receiver
        connection uplinkToReceiver {
            from implantUplink to wirelessReceiver.wirelessInput;
            item digitalPackets : DigitalNeuralDataPacket[0..*];
        }
        
        // Connection: User interface output
        connection userInterfaceOutput {
            from userInterface.intentOutput to userOutput;
            item decodedIntent : DecodedIntent;
        }
    }
    
    // ==========================================
    // Top-Level System
    // ==========================================
    
    part def ParadromicsNeuralInterfaceSystem {
        doc /* The complete Paradromics Neural Interface System providing bidirectional brain-computer communication. */
        
        satisfy BidirectionalCommunicationReq;
        satisfy LongTermImplantationRequirement;
        
        attribute systemName : String = "Paradromics Neural Interface System";
        attribute applicationDomain : String = "Clinical BCI for severe paralysis";
        attribute bidirectional : Boolean = true;
        
        part implant : ImplantedDevice;
        part external : ExternalSystem;
        
        // Wireless uplink: implant to external (neural data)
        connection wirelessUplink {
            from implant.externalLinkUplink to external.implantUplink;
            item digitalPackets : DigitalNeuralDataPacket[0..*];
        }
        
        // Wireless downlink: external to implant (commands and feedback)
        connection wirelessDownlink {
            from external.implantDownlink to implant.externalLinkDownlink;
            item feedbackCommands : FeedbackCommand[0..*];
            item stimulationCommands : StimulationCommand[0..*];
        }
    }
    
    // ==========================================
    // Configuration Instances
    // ==========================================
    
    part def SystemConfiguration :> ParadromicsNeuralInterfaceSystem {
        doc /* Specific configuration instance for a single-user clinical deployment. */
        
        attribute patientId : String;
        attribute implantDate : Real;
        attribute calibrationDate : Real;
        
        part implant {
            part microelectrodeArray {
                attribute electrodeCount : ElectrodeCount = 1600;
                attribute penetrationDepth : Micrometer = 1500;
            }
            part signalProcessingChip {
                attribute gain : GainFactor = 1000;
                attribute samplingRate : SamplesPerSecond = 30000;
            }
            part wirelessTransceiver {
                attribute uplinkDataRate : GigabitPerSecond = 1.0;
            }
            part packaging {
                attribute material : String = "Parylene-C";
            }
            state operationalState {
                first standby;
            }
        }
        
        part external {
            part neuralDecoder {
                attribute modelType : String = "RNN";
            }
        }
    }
}
