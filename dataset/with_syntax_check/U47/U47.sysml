package 'Cochlear Implant System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SoundPressureLevel :> Real;
	attribute def FrequencyBand :> ISQ::FrequencyValue;
	attribute def ChannelNumber :> Integer;
	
	item def AcousticSignal {
		attribute pressureLevel : SoundPressureLevel;
		attribute frequency : FrequencyBand;
		attribute timestamp : ISQ::TimeValue;
	}
	
	item def DigitalAudioData {
		attribute samples : Real[*];
		attribute sampleRate : ISQ::FrequencyValue;
		attribute bitDepth : Integer;
	}
	
	item def EncodedStimulusPattern {
		attribute channelMap : ChannelNumber[*];
		attribute amplitudes : ISQ::ElectricCurrentValue[*];
		attribute pulseRates : ISQ::FrequencyValue[*];
		attribute pulseDurations : ISQ::TimeValue[*];
	}
	
	item def ElectricalStimulus {
		attribute current : ISQ::ElectricCurrentValue;
		attribute channel : ChannelNumber;
		attribute pulseWidth : ISQ::TimeValue;
	}
	
	port def AcousticPort {
		in acousticWave : AcousticSignal;
	}
	
	port def AnalogSignalPort {
		out audioSignal : DigitalAudioData;
	}
	
	port def DigitalDataPort {
		in digitalData : DigitalAudioData;
		out digitalData : DigitalAudioData;
	}
	
	port def RFTransmissionPort {
		out encodedData : EncodedStimulusPattern;
	}
	
	port def RFReceptionPort {
		in encodedData : EncodedStimulusPattern;
	}
	
	port def StimulationPort {
		out stimulus : ElectricalStimulus;
	}
	
	port def NeuralInterfacePort {
		in stimulus : ElectricalStimulus;
	}
	
	part def Microphone {
		doc /* Captures ambient sound and converts acoustic energy to electrical signals */
		port acousticIn : AcousticPort;
		port signalOut : AnalogSignalPort;
		attribute sensitivityRange : SoundPressureLevel[2];
		attribute frequencyResponse : FrequencyBand[2];
	}
	
	part def SpeechProcessor {
		doc /* Analyzes audio signals and extracts speech features for encoding */
		port audioIn : DigitalDataPort;
		port dataOut : DigitalDataPort;
		attribute numberOfChannels : ChannelNumber;
		attribute processingStrategy : String;
		attribute filterBankSize : Integer;
	}
	
	part def ExternalTransmitter {
		doc /* Wirelessly transmits encoded stimulation patterns to internal receiver */
		port dataIn : DigitalDataPort;
		port rfOut : RFTransmissionPort;
		attribute carrierFrequency : ISQ::FrequencyValue;
		attribute transmitPower : ISQ::PowerValue;
	}
	
	part def InternalReceiver {
		doc /* Receives RF signals and demodulates stimulation commands */
		port rfIn : RFReceptionPort;
		port stimDataOut : DigitalDataPort;
		attribute receiverSensitivity : ISQ::PowerValue;
	}
	
	part def CurrentStimulator {
		doc /* Generates precise electrical current pulses for neural stimulation */
		port commandIn : DigitalDataPort;
		port stimOut : StimulationPort;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		attribute complianceVoltage : ISQ::ElectricPotentialValue;
	}
	
	part def ElectrodeArray {
		doc /* Delivers electrical stimulation to specific regions of the cochlea */
		port stimIn : StimulationPort;
		port neuralOut : NeuralInterfacePort;
		attribute numberOfElectrodes : ChannelNumber;
		attribute arrayLength : ISQ::LengthValue;
		attribute electrodeSpacing : ISQ::LengthValue;
	}
	
	part def AuditoryNerve {
		doc /* Biological auditory nerve that receives electrical stimulation */
		port neuralIn : NeuralInterfacePort;
	}
	
	action def CaptureAcousticSignal {
		in ambientSound : AcousticSignal;
		out capturedAudio : DigitalAudioData;
	}
	
	action def AnalyzeAndEncode {
		in audioData : DigitalAudioData;
		out stimulusPattern : EncodedStimulusPattern;
	}
	
	action def TransmitWirelessly {
		in stimulusPattern : EncodedStimulusPattern;
		out rfSignal : EncodedStimulusPattern;
	}
	
	action def ReceiveAndDecode {
		in rfSignal : EncodedStimulusPattern;
		out decodedPattern : EncodedStimulusPattern;
	}
	
	action def GenerateStimulation {
		in stimulusPattern : EncodedStimulusPattern;
		out electricalPulses : ElectricalStimulus[*];
	}
	
	action def DeliverNeuralStimulation {
		in electricalPulses : ElectricalStimulus[*];
	}
	
	action def ConvertSoundToNeuralStimulation {
		doc /* Primary system function: convert acoustic sound to neural stimulation */
		in ambientSound : AcousticSignal;
		
		first start;
		then action capture : CaptureAcousticSignal {
			in ambientSound = ConvertSoundToNeuralStimulation::ambientSound;
			out capturedAudio : DigitalAudioData;
		}
		then action encode : AnalyzeAndEncode {
			in audioData = capture.capturedAudio;
			out stimulusPattern : EncodedStimulusPattern;
		}
		then action transmit : TransmitWirelessly {
			in stimulusPattern = encode.stimulusPattern;
			out rfSignal : EncodedStimulusPattern;
		}
		then action receive : ReceiveAndDecode {
			in rfSignal = transmit.rfSignal;
			out decodedPattern : EncodedStimulusPattern;
		}
		then action generate : GenerateStimulation {
			in stimulusPattern = receive.decodedPattern;
			out electricalPulses : ElectricalStimulus[*];
		}
		then action deliver : DeliverNeuralStimulation {
			in electricalPulses = generate.electricalPulses;
		}
		then done;
	}
	
	part def ExternalComponent {
		doc /* Wearable external unit containing microphone, processor, and transmitter */
		part microphone : Microphone {
			attribute sensitivityRange = (20.0, 120.0);
			attribute frequencyResponse = (100.0 [SI::Hz], 8000.0 [SI::Hz]);
		}
		part processor : SpeechProcessor {
			attribute numberOfChannels = 22;
			attribute processingStrategy = "ACE";
			attribute filterBankSize = 22;
		}
		part transmitter : ExternalTransmitter {
			attribute carrierFrequency = 5.0e6 [SI::Hz];
			attribute transmitPower = 50.0e-3 [SI::W];
		}
		
		connect microphone.signalOut to processor.audioIn;
		connect processor.dataOut to transmitter.dataIn;
	}
	
	part def InternalComponent {
		doc /* Surgically implanted unit containing receiver, stimulator, and electrodes */
		part receiver : InternalReceiver {
			attribute receiverSensitivity = 1.0e-6 [SI::W];
		}
		part stimulator : CurrentStimulator {
			attribute maxCurrent = 1.75e-3 [SI::A];
			attribute complianceVoltage = 8.0 [SI::V];
		}
		part electrodes : ElectrodeArray {
			attribute numberOfElectrodes = 22;
			attribute arrayLength = 25.0 [SI::mm];
			attribute electrodeSpacing = 0.75 [SI::mm];
		}
		
		connect receiver.stimDataOut to stimulator.commandIn;
		connect stimulator.stimOut to electrodes.stimIn;
	}
	
	part def CochlearImplantSystem;
	
	part cochlearImplantSystem : CochlearImplantSystem {
		doc /* 
			Complete cochlear implant system that restores hearing by bypassing 
			damaged hair cells and directly stimulating the auditory nerve with 
			electrical signals derived from environmental sounds.
		*/
		
		part externalUnit : ExternalComponent {
			perform action captureAndProcess[*] ordered;
		}
		
		part internalUnit : InternalComponent {
			perform action receiveAndStimulate[*] ordered;
		}
		
		part auditoryNerve : AuditoryNerve;
		
		connect internalUnit.electrodes.neuralOut to auditoryNerve.neuralIn;
		
		perform action primaryFunction : ConvertSoundToNeuralStimulation[*] {
			in ambientSound : AcousticSignal;
		}
	}
	
	requirement <'CI-REQ-001'> acousticCaptureRequirement {
		doc /* 
			The system shall capture acoustic signals across the speech frequency 
			range of 100 Hz to 8000 Hz with sensitivity from 20 dB to 120 dB SPL.
		*/
		subject mic : Microphone;
		require constraint {
			mic.frequencyResponse[1] <= 100.0 [SI::Hz] and
			mic.frequencyResponse[2] >= 8000.0 [SI::Hz] and
			mic.sensitivityRange[1] <= 20.0 and
			mic.sensitivityRange[2] >= 120.0
		}
	}
	
	requirement <'CI-REQ-002'> signalProcessingRequirement {
		doc /* 
			The speech processor shall decompose audio signals into at least 
			16 independent frequency channels for tonotopic stimulation mapping.
		*/
		subject proc : SpeechProcessor;
		require constraint {
			proc.numberOfChannels >= 16 and
			proc.filterBankSize >= 16
		}
	}
	
	requirement <'CI-REQ-003'> stimulationSafetyRequirement {
		doc /* 
			The current stimulator shall limit maximum output current to safe 
			levels not exceeding 1.75 mA per electrode to prevent tissue damage.
		*/
		subject stim : CurrentStimulator;
		require constraint {
			stim.maxCurrent <= 1.75e-3 [SI::A]
		}
	}
	
	requirement <'CI-REQ-004'> electrodeArrayRequirement {
		doc /* 
			The electrode array shall provide at least 12 independent stimulation 
			sites distributed along the cochlear spiral to enable frequency discrimination.
		*/
		subject array : ElectrodeArray;
		require constraint {
			array.numberOfElectrodes >= 12
		}
	}
	
	requirement <'CI-REQ-005'> primaryFunctionRequirement {
		doc /* 
			The cochlear implant system shall convert environmental acoustic signals 
			into spatially and temporally patterned electrical stimulation of the 
			auditory nerve to restore functional hearing perception in individuals 
			with severe to profound sensorineural hearing loss.
		*/
		subject system : CochlearImplantSystem;
		assume constraint {
			doc /* Environmental sound is present and auditory nerve is responsive */
		}
		require acousticCaptureRequirement;
		require signalProcessingRequirement;
		require stimulationSafetyRequirement;
		require electrodeArrayRequirement;
	}
	
	state def SystemOperationalStates {
		entry; then powerOff;
		
		state powerOff;
		
		transition powerOff_to_standby
			first powerOff
			accept powerOn
			then standby;
		
		state standby;
		
		transition standby_to_active
			first standby
			accept soundDetected
			then active;
		
		state active {
			entry; then capturing;
			
			state capturing;
			
			transition capturing_to_processing
				first capturing
				then processing;
			
			state processing;
			
			transition processing_to_transmitting
				first processing
				then transmitting;
			
			state transmitting;
			
			transition transmitting_to_receiving
				first transmitting
				then receiving;
			
			state receiving;
			
			transition receiving_to_stimulating
				first receiving
				then stimulating;
			
			state stimulating;
			
			transition stimulating_to_capturing
				first stimulating
				then capturing;
		}
		
		transition active_to_standby
			first active
			accept silenceDetected
			then standby;
		
		transition standby_to_powerOff
			first standby
			accept powerOff
			then powerOff;
	}
	
	action operateImplantSystem {
		in soundInput : AcousticSignal;
		
		first start;
		then merge continuousOperation;
		then action monitorEnvironment {
			in sound = soundInput;
			out soundPresent : Boolean;
			out soundLevel : SoundPressureLevel;
		}
		then decide;
			if monitorEnvironment.soundPresent and monitorEnvironment.soundLevel >= 25.0 
				then processAndStimulate;
			if not monitorEnvironment.soundPresent or monitorEnvironment.soundLevel < 25.0 
				then enterStandby;
		action processAndStimulate : ConvertSoundToNeuralStimulation {
			in ambientSound = soundInput;
		}
		then continuousOperation;
		action enterStandby;
		then continuousOperation;
	}
}
