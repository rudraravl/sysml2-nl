package ParadromicsNeuralInterface {
	private import ScalarValues::*;
	
	package Definitions {
		private import ScalarValues::*;
		
		attribute def DataRate :> ScalarValues::Real {
			attribute unit : String = "Gbps";
		}
		attribute def SamplingRate :> ScalarValues::Real {
			attribute unit : String = "Hz";
		}
		attribute def AmplificationFactor :> ScalarValues::Real;
		attribute def Voltage :> ScalarValues::Real {
			attribute unit : String = "V";
		}
		attribute def Current :> ScalarValues::Real {
			attribute unit : String = "A";
		}
		attribute def Length :> ScalarValues::Real {
			attribute unit : String = "mm";
		}
		attribute def Frequency :> ScalarValues::Real {
			attribute unit : String = "GHz";
		}
		
		item def NeuralSignal {
			attribute voltage : Voltage;
		}
		item def DigitalNeuralData {
			attribute sampleRate : SamplingRate;
			attribute payload : ScalarValues::Integer[0..*];
		}
		item def StimulationCommand {
			attribute electrodeIndices : ScalarValues::Integer[0..*];
			attribute amplitudes : Current[0..*];
			attribute durations : ScalarValues::Real[0..*];
		}
		item def ElectricalStimulation {
			attribute current : Current;
			attribute frequency : Frequency;
		}
		
		attribute def StartRecording;
		attribute def StopRecording;
		attribute def DataReady;
		attribute def TransmitComplete;
		attribute def CommandReceived;
		attribute def FeedbackReady;
		
		port def NeuralSignalPort {
			out item signal : NeuralSignal;
		}
		port def StimulationPort {
			out item stimulation : ElectricalStimulation;
		}
		port def DigitalDataPort {
			out item data : DigitalNeuralData;
		}
		port def CommandDataPort {
			out item command : StimulationCommand;
		}
		port def WirelessLinkPort {
			out item neuralData : DigitalNeuralData;
			in item feedbackCmd : StimulationCommand;
		}
		
		action def ListenToNeurons {
			out item rawSignal : NeuralSignal;
		}
		action def DeliverStimulation {
			in item stim : ElectricalStimulation;
		}
		action def AmplifyAndDigitize {
			in item analogIn : NeuralSignal;
			attribute gain : AmplificationFactor;
			attribute rate : SamplingRate;
			out item digitalOut : DigitalNeuralData;
		}
		action def TransmitData {
			in item data : DigitalNeuralData;
		}
		action def ReceiveData {
			in item data : DigitalNeuralData;
		}
		action def ReceiveCommands {
			out item command : StimulationCommand;
		}
		action def DecodeIntent {
			in item neuralData : DigitalNeuralData;
			out attribute intent : String;
		}
		action def GenerateFeedback {
			in attribute intent : String;
			out item feedback : StimulationCommand;
		}
		
		part def Brain {
			port neuralOut : NeuralSignalPort;
			port stimIn : ~StimulationPort;
		}
		
		part def MicroelectrodeArray {
			attribute electrodeCount : ScalarValues::Integer = 1600;
			attribute insertionDepth : Length = 1.5;
			port brainIn : ~NeuralSignalPort;
			port asicOut : NeuralSignalPort;
			port cmdIn : ~CommandDataPort;
			port brainStimOut : StimulationPort;
			perform action listenToNeurons : ListenToNeurons;
			perform action deliverStimulation : DeliverStimulation;
		}
		
		part def ASIC {
			attribute amplification : AmplificationFactor = 1000;
			attribute samplingRate : SamplingRate = 30000;
			attribute resolution : ScalarValues::Integer = 16;
			port arrayIn : ~NeuralSignalPort;
			port dataOut : DigitalDataPort;
			perform action amplifyAndDigitize : AmplifyAndDigitize;
		}
		
		part def WirelessTransceiver {
			attribute dataRate : DataRate = 1000000000;
			attribute carrierFrequency : Frequency = 2.4;
			port dataIn : ~DigitalDataPort;
			port cmdOut : CommandDataPort;
			port wirelessPort : WirelessLinkPort;
			perform action transmitData : TransmitData;
			perform action receiveCommands : ReceiveCommands;
		}
		
		part def BiocompatiblePackaging {
			attribute material : String = "Parylene-C";
			attribute thickness : Length = 10;
			attribute hermeticSeal : Boolean = true;
		}
		
		part def ImplantedDevice {
			part microelectrodeArray : MicroelectrodeArray;
			part asic : ASIC;
			part transceiver : WirelessTransceiver;
			part packaging : BiocompatiblePackaging;
			port wirelessPort : WirelessLinkPort;
			
			connection arrayToAsic connect microelectrodeArray.asicOut to asic.arrayIn;
			connection asicToTransceiver connect asic.dataOut to transceiver.dataIn;
			connection transceiverToArray connect transceiver.cmdOut to microelectrodeArray.cmdIn;
			connection transceiverToPort connect transceiver.wirelessPort to wirelessPort;
			
			exhibit state implantStates {
				entry; then standby;
				state standby;
				accept StartRecording then active;
				state active {
					entry microelectrodeArray.listenToNeurons;
					do asic.amplifyAndDigitize;
				}
				accept DataReady then transmitting;
				state transmitting {
					do transceiver.transmitData;
				}
				accept TransmitComplete then active;
				accept StopRecording then standby;
			}
		}
		
		part def ExternalReceiver {
			port wirelessRx : ~WirelessLinkPort;
			port dataToDecoder : DigitalDataPort;
			port cmdFromGen : ~CommandDataPort;
			perform action receiveData : ReceiveData;
		}
		
		part def NeuralDecoder {
			port dataIn : ~DigitalDataPort;
			perform action decodeIntent : DecodeIntent;
		}
		
		part def CommandGenerator {
			port cmdOut : CommandDataPort;
			perform action generateFeedback : GenerateFeedback;
		}
		
		part def ExternalSystem {
			part receiver : ExternalReceiver;
			part decoder : NeuralDecoder;
			part commandGen : CommandGenerator;
			port wirelessPort : ~WirelessLinkPort;
			
			connection receiverToDecoder connect receiver.dataToDecoder to decoder.dataIn;
			connection genToReceiver connect commandGen.cmdOut to receiver.cmdFromGen;
			connection portToReceiver connect wirelessPort to receiver.wirelessRx;
			
			exhibit state externalStates {
				entry; then idle;
				state idle;
				accept CommandReceived then decoding;
				state decoding {
					do decoder.decodeIntent;
				}
				accept FeedbackReady then sendingFeedback;
				state sendingFeedback {
					do commandGen.generateFeedback;
				}
				then idle;
			}
		}
		
		requirement def HighBandwidthRequirement {
			doc /* The BCI system shall support high-bandwidth data transmission of at least 1 Gbps. */
			subject transceiver : WirelessTransceiver;
			constraint { transceiver.dataRate >= 1000000000 }
		}
		
		requirement def HighDensityRecordingRequirement {
			doc /* The microelectrode array shall contain at least 1600 electrodes. */
			subject array : MicroelectrodeArray;
			constraint { array.electrodeCount >= 1600 }
		}
		
		requirement def BiocompatibilityRequirement {
			doc /* All implanted materials shall be biocompatible and hermetically sealed. */
			subject packaging : BiocompatiblePackaging;
			constraint { packaging.material == "Parylene-C" and packaging.hermeticSeal }
		}
		
		requirement def BidirectionalLinkRequirement {
			doc /* The system shall support bidirectional communication between brain and external devices. */
			subject implant : ImplantedDevice;
		}
		
		requirement def LongTermImplantationRequirement {
			doc /* The device shall be safe for long-term implantation up to 10 years. */
			subject implant : ImplantedDevice;
			attribute durationYears : ScalarValues::Real = 10.0;
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part paradigmronicsBCI {
			part brain : Brain;
			part implant : ImplantedDevice;
			part external : ExternalSystem;
			
			requirement highBandwidth : HighBandwidthRequirement;
			satisfy highBandwidth by implant.transceiver;
			
			requirement highDensity : HighDensityRecordingRequirement;
			satisfy highDensity by implant.microelectrodeArray;
			
			requirement biocompatibility : BiocompatibilityRequirement;
			satisfy biocompatibility by implant.packaging;
			
			requirement bidirectionalLink : BidirectionalLinkRequirement;
			satisfy bidirectionalLink by implant;
			
			requirement longTerm : LongTermImplantationRequirement;
			satisfy longTerm by implant;
			
			connection brainToArray connect brain.neuralOut to implant.microelectrodeArray.brainIn;
			connection arrayToBrain connect implant.microelectrodeArray.brainStimOut to brain.stimIn;
			connection wirelessLink connect implant.wirelessPort to external.wirelessPort;
		}
	}
}
