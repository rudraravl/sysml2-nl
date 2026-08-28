package 'Motorola APCOR Radio' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	attribute def AnalogAudio;
	attribute def DigitalVoiceData;
	attribute def ModulatedRFSignal;
	attribute def RFSignal;
	attribute def UserCommand;
	attribute def 'PTT';
	attribute def 'PTT Release';
	attribute def 'Incoming Call';
	attribute def 'Call End';
	attribute def 'Channel Change';
	attribute def 'Initiate Call';
	
	part def Microphone {
		port txOutPort { out audioOut: AnalogAudio; }
	}
	part def AudioProcessor {
		port txInPort { in audioIn: AnalogAudio; }
		port txOutPort { out audioOut: AnalogAudio; }
		port rxInPort { in audioIn: AnalogAudio; }
		port rxOutPort { out audioOut: AnalogAudio; }
	}
	part def Vocoder {
		port txInPort { in audioIn: AnalogAudio; }
		port txOutPort { out dataOut: DigitalVoiceData; }
		port rxInPort { in dataIn: DigitalVoiceData; }
		port rxOutPort { out audioOut: AnalogAudio; }
	}
	part def DSP {
		port txInPort { in dataIn: DigitalVoiceData; }
		port txOutPort { out modulatedOut: ModulatedRFSignal; }
		port rxInPort { in rfIn: RFSignal; }
		port rxOutPort { out dataOut: DigitalVoiceData; }
	}
	part def RFTransceiver {
		port txInPort { in modulatedIn: ModulatedRFSignal; }
		port txOutPort { out rfOut: ModulatedRFSignal; }
		port rxInPort { in rfIn: RFSignal; }
		port rxOutPort { out tunedOut: RFSignal; }
	}
	part def PowerAmplifier {
		port txInPort { in modulatedIn: ModulatedRFSignal; }
		port txOutPort { out amplifiedOut: RFSignal; }
	}
	part def Antenna {
		port txPort { in rfIn: RFSignal; }
		port rxPort { out rfOut: RFSignal; }
	}
	part def Speaker {
		port rxInPort { in audioIn: AnalogAudio; }
	}
	part def Controller {
		port commandPort { in commandIn: UserCommand; }
		exhibit state 'controller states': 'Controller States' {
			entry; then idle;
			state idle;
			accept 'Channel Change' then idle;
			accept 'Initiate Call' then active;
			state active;
			accept 'Call End' then idle;
		}
	}
	part def BatteryPack {
		attribute isRechargeable: Boolean = true;
		port powerPort { out voltage: ElectricPotentialValue; }
	}
	
	state def 'Radio States';
	state def 'Controller States';
	
	action def 'Capture Voice' { out audio: AnalogAudio; }
	action def 'Condition Audio' { in audioIn: AnalogAudio; out audioOut: AnalogAudio; }
	action def 'Encode Voice' { in audio: AnalogAudio; out data: DigitalVoiceData; }
	action def 'Modulate Signal' { in data: DigitalVoiceData; out modulated: ModulatedRFSignal; }
	action def 'Prepare for Broadcast' { in modulated: ModulatedRFSignal; out prepared: ModulatedRFSignal; }
	action def 'Amplify Signal' { in modulated: ModulatedRFSignal; out amplified: RFSignal; }
	action def 'Broadcast Signal' { in rf: RFSignal; }
	
	action def 'Receive Signal' { out rf: RFSignal; }
	action def 'Tune Frequency' { in rf: RFSignal; out tuned: RFSignal; }
	action def 'Demodulate Signal' { in rf: RFSignal; out data: DigitalVoiceData; }
	action def 'Decode Voice' { in data: DigitalVoiceData; out audio: AnalogAudio; }
	action def 'Play Audio' { in audio: AnalogAudio; }
	
	action def 'Transmit Voice';
	action def 'Receive Voice';
	
	requirement def 'Communication Requirement' {
		doc /* The radio shall provide secure and reliable voice communication. */
	}
	requirement def 'Power Requirement' {
		doc /* The radio shall be powered by a rechargeable battery pack. */
	}
	
	part def Radio {
		doc /* Motorola APCOR digital two-way radio */
		
		part mic: Microphone;
		part audioProc: AudioProcessor;
		part vocoder: Vocoder;
		part dsp: DSP;
		part rfXcvr: RFTransceiver;
		part pa: PowerAmplifier;
		part ant: Antenna;
		part speaker: Speaker;
		part controller: Controller;
		part battery: BatteryPack;
		
		flow mic.txOutPort.audioOut to audioProc.txInPort.audioIn;
		flow audioProc.txOutPort.audioOut to vocoder.txInPort.audioIn;
		flow vocoder.txOutPort.dataOut to dsp.txInPort.dataIn;
		flow dsp.txOutPort.modulatedOut to rfXcvr.txInPort.modulatedIn;
		flow rfXcvr.txOutPort.rfOut to pa.txInPort.modulatedIn;
		flow pa.txOutPort.amplifiedOut to ant.txPort.rfIn;
		
		flow ant.rxPort.rfOut to rfXcvr.rxInPort.rfIn;
		flow rfXcvr.rxOutPort.tunedOut to dsp.rxInPort.rfIn;
		flow dsp.rxOutPort.dataOut to vocoder.rxInPort.dataIn;
		flow vocoder.rxOutPort.audioOut to audioProc.rxInPort.audioIn;
		flow audioProc.rxOutPort.audioOut to speaker.rxInPort.audioIn;
		
		action 'transmit voice': 'Transmit Voice' {
			action 'capture voice': 'Capture Voice';
			flow 'capture voice'.audio to 'condition audio'.audioIn;
			action 'condition audio': 'Condition Audio';
			flow 'condition audio'.audioOut to 'encode voice'.audio;
			action 'encode voice': 'Encode Voice';
			flow 'encode voice'.data to 'modulate signal'.data;
			action 'modulate signal': 'Modulate Signal';
			flow 'modulate signal'.modulated to 'prepare for broadcast'.modulated;
			action 'prepare for broadcast': 'Prepare for Broadcast';
			flow 'prepare for broadcast'.prepared to 'amplify signal'.modulated;
			action 'amplify signal': 'Amplify Signal';
			flow 'amplify signal'.amplified to 'broadcast signal'.rf;
			action 'broadcast signal': 'Broadcast Signal';
			
			first start;
			then 'capture voice';
			then 'condition audio';
			then 'encode voice';
			then 'modulate signal';
			then 'prepare for broadcast';
			then 'amplify signal';
			then 'broadcast signal';
		}
		
		action 'receive voice': 'Receive Voice' {
			action 'receive signal': 'Receive Signal';
			flow 'receive signal'.rf to 'tune frequency'.rf;
			action 'tune frequency': 'Tune Frequency';
			flow 'tune frequency'.tuned to 'demodulate signal'.rf;
			action 'demodulate signal': 'Demodulate Signal';
			flow 'demodulate signal'.data to 'decode voice'.data;
			action 'decode voice': 'Decode Voice';
			flow 'decode voice'.audio to 'play audio'.audio;
			action 'play audio': 'Play Audio';
			
			first start;
			then 'receive signal';
			then 'tune frequency';
			then 'demodulate signal';
			then 'decode voice';
			then 'play audio';
		}
		
		exhibit state 'radio states': 'Radio States' {
			entry; then idle;
			state idle;
			accept 'PTT' then transmitting;
			state transmitting {
				do 'transmit voice';
			}
			accept 'PTT Release' then idle;
			accept 'Incoming Call' then receiving;
			state receiving {
				do 'receive voice';
			}
			accept 'Call End' then idle;
		}
	}
}
