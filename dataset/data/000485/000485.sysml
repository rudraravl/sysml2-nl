package ParadromicsNeuralInterfaceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ChannelCount;
	attribute def SignalQuality;
	attribute def DataThroughput;
	
	item def NeuralSignal {
		attribute amplitude : ISQ::ElectricPotentialValue;
		attribute frequency : ISQ::FrequencyValue;
		attribute channelId : ScalarValues::Integer;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def DigitalNeuralData {
		attribute samplingRate : ISQ::FrequencyValue;
		attribute bitDepth : ScalarValues::Integer;
		attribute channelCount : ScalarValues::Integer;
		attribute dataPayload : ScalarValues::String;
	}
	
	item def StimulusCommand {
		attribute pulseWidth : ISQ::TimeValue;
		attribute amplitude : ISQ::ElectricCurrentValue;
		attribute targetChannels : ScalarValues::Integer[*];
	}
	
	port def NeuralPort {
		in item neuralSignals : NeuralSignal[*];
		out item stimulusCommands : StimulusCommand[*];
	}
	
	port def DataPort {
		out item digitalData : DigitalNeuralData[*];
		in item controlCommands : ScalarValues::String[*];
	}
	
	port def PowerPort {
		in attribute voltage : ISQ::ElectricPotentialValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	part def MicroelectrodeArray {
		attribute electrodeCount : ScalarValues::Integer;
		attribute electrodeDensity : ScalarValues::Real;
		attribute penetrationDepth : ISQ::LengthValue;
		
		port neuralInterface : NeuralPort;
		
		action acquireNeuralSignals {
			in attribute corticalRegion : ScalarValues::String;
			out signals : NeuralSignal[*];
		}
		
		action deliverStimulation {
			in stimulus : StimulusCommand;
			out attribute delivered : ScalarValues::Boolean;
		}
	}
	
	part def SignalProcessingASIC {
		attribute processingChannels : ScalarValues::Integer;
		attribute samplingRate : ISQ::FrequencyValue;
		attribute amplificationGain : ScalarValues::Real;
		
		port dataOut : DataPort;
		port powerIn : PowerPort;
		
		action amplifySignals {
			in rawSignals : NeuralSignal[*];
			out amplifiedSignals : NeuralSignal[*];
		}
		
		action filterSignals {
			in noisySignals : NeuralSignal[*];
			out filteredSignals : NeuralSignal[*];
			attribute bandpassLow : ISQ::FrequencyValue;
			attribute bandpassHigh : ISQ::FrequencyValue;
		}
		
		action digitizeSignals {
			in analogSignals : NeuralSignal[*];
			out digitalData : DigitalNeuralData;
		}
	}
	
	part def WirelessTransceiver {
		attribute carrierFrequency : ISQ::FrequencyValue;
		attribute bandwidth : ISQ::FrequencyValue;
		attribute transmitPower : ISQ::PowerValue;
		attribute dataRate : ScalarValues::Real;
		
		port dataIn : DataPort;
		port powerIn : PowerPort;
		
		action transmitData {
			in data : DigitalNeuralData;
			out attribute success : ScalarValues::Boolean;
		}
		
		action receiveCommands {
			out commands : ScalarValues::String[*];
		}
	}
	
	part def BiocompatiblePackaging {
		attribute material : ScalarValues::String;
		attribute thickness : ISQ::LengthValue;
		attribute hermeticSeal : ScalarValues::Boolean;
		
		action protectElectronics {
			in attribute exposure : ScalarValues::Real;
			out attribute protectionLevel : ScalarValues::Real;
		}
	}
	
	part def ExternalReceiver {
		attribute receiverSensitivity : ScalarValues::Real;
		
		action receiveNeuralData {
			out receivedData : DigitalNeuralData[*];
		}
		
		action decodeData {
			in encodedData : DigitalNeuralData;
			out decodedSignals : NeuralSignal[*];
		}
	}
	
	part def ParadromicsImplant {
		part electrodes : MicroelectrodeArray {
			attribute :>> electrodeCount = 1600;
			attribute :>> electrodeDensity = 400.0;
			attribute :>> penetrationDepth = 1.5 [SI::mm];
		}
		
		part asic : SignalProcessingASIC {
			attribute :>> processingChannels = 1600;
			attribute :>> samplingRate = 30000.0 [SI::Hz];
			attribute :>> amplificationGain = 1000.0;
		}
		
		part transceiver : WirelessTransceiver {
			attribute :>> carrierFrequency = 2.4e9 [SI::Hz];
			attribute :>> bandwidth = 100.0e6 [SI::Hz];
			attribute :>> transmitPower = 10.0 [SI::mW];
			attribute :>> dataRate = 1.0e9;
		}
		
		part packaging : BiocompatiblePackaging {
			attribute :>> material = "Parylene-C";
			attribute :>> thickness = 10.0e-6 [SI::m];
			attribute :>> hermeticSeal = true;
		}
		
		connection neuralToASIC connect electrodes.neuralInterface to asic;
		connection asicToTransceiver connect asic.dataOut to transceiver.dataIn;
	}
	
	part def ExternalSystem {
		part receiver : ExternalReceiver;
		
		action interpretNeuralData {
			in neuralData : DigitalNeuralData[*];
			out interpretedIntent : ScalarValues::String[*];
		}
		
		action generateFeedback {
			in userIntent : ScalarValues::String;
			out feedbackCommands : StimulusCommand[*];
		}
	}
	
	action def AcquireAndProcessNeuralActivity {
		in corticalTarget : ScalarValues::String;
		out processedData : DigitalNeuralData;
		
		first start;
		then action acquire {
			out rawSignals : NeuralSignal[*];
		}
		then action amplifyAction {
			in signals = acquire.rawSignals;
			out amplifiedSignals : NeuralSignal[*];
		}
		then action filterAction {
			in signals = amplifyAction.amplifiedSignals;
			out filteredSignals : NeuralSignal[*];
		}
		then action digitize {
			in signals = filterAction.filteredSignals;
			out digitalData : DigitalNeuralData;
		}
		then assign processedData := digitize.digitalData;
		then done;
	}
	
	action def TransmitNeuralData {
		in neuralData : DigitalNeuralData;
		out transmissionComplete : ScalarValues::Boolean;
		
		first start;
		then action encode {
			in data = neuralData;
			out encodedData : DigitalNeuralData;
		}
		then action transmit {
			in data = encode.encodedData;
			out success : ScalarValues::Boolean;
		}
		then assign transmissionComplete := transmit.success;
		then done;
	}
	
	state def ImplantOperationalStates {
		entry; then standby;
		
		state standby;
		
		transition standby_to_active
			first standby
			accept event StartRecording
			then active;
		
		state active;
		
		transition active_to_transmitting
			first active
			accept event DataReady
			then transmitting;
		
		state transmitting;
		
		transition transmitting_to_active
			first transmitting
			accept event TransmissionComplete
			then active;
		
		transition active_to_standby
			first active
			accept event StopRecording
			then standby;
		
		state fault;
		
		transition any_to_fault
			accept event SystemError
			then fault;
	}
	
	requirement def HighChannelCountRequirement {
		doc /* The system shall simultaneously record from at least 1000 independent neural channels. */
		
		subject implant : ParadromicsImplant;
		
		require constraint {
			implant.electrodes.electrodeCount >= 1000
		}
	}
	
	requirement def HighBandwidthRequirement {
		doc /* The system shall transmit neural data at a minimum rate of 1 Gbps to support high-density recording. */
		
		subject transceiver : WirelessTransceiver;
		
		require constraint {
			transceiver.dataRate >= 1.0e9
		}
	}
	
	requirement def BiocompatibilityRequirement {
		doc /* The implant shall use biocompatible materials suitable for chronic implantation. */
		
		subject packaging : BiocompatiblePackaging;
		
		require constraint {
			packaging.material == "Parylene-C" or 
			packaging.material == "Titanium" or
			packaging.material == "PDMS"
		}
	}
	
	requirement def SignalQualityRequirement {
		doc /* The system shall maintain signal-to-noise ratio sufficient for single-unit neural spike detection. */
		
		subject asic : SignalProcessingASIC;
		
		require constraint {
			asic.samplingRate >= 20000.0 [SI::Hz] and
			asic.amplificationGain >= 100.0
		}
	}
	
	requirement <'PARA-SYS-001'> primarySystemRequirement {
		doc /* The Paradromics neural interface system shall enable high-bandwidth, bidirectional communication 
		     between the brain and external digital systems by recording neural activity from thousands of 
		     channels simultaneously and wirelessly transmitting the data for real-time processing. */
		
		assume constraint corticalAccessAssumption {
			doc /* Assumes safe surgical access to target cortical regions is achievable. */
		}
		
		require highChannelCount : HighChannelCountRequirement;
		require highBandwidth : HighBandwidthRequirement;
		require biocompatibility : BiocompatibilityRequirement;
		require signalQuality : SignalQualityRequirement;
	}
	
	part paradromicsSystem {
		part implantedDevice : ParadromicsImplant;
		
		part externalProcessing : ExternalSystem;
		
		connection wirelessDataLink connect 
			implantedDevice.transceiver to externalProcessing.receiver;
	}
	
	occurrence def NeuralRecordingOperation {
		ref part system :>> paradromicsSystem;
		
		first start;
		then event occurrence recordingStarted;
		then event occurrence neuralActivityAcquired;
		then event occurrence signalsAmplified;
		then event occurrence signalsFiltered;
		then event occurrence signalsDigitized;
		then event occurrence dataEncoded;
		then event occurrence dataTransmitted;
		then event occurrence dataReceived;
		then event occurrence intentDecoded;
		then done;
	}
}
