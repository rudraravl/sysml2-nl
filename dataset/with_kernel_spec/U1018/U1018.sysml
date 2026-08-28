package 'IR Remote Control System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def ButtonId :> Integer;
		attribute def DeviceAddress :> Integer;
		attribute def FunctionCode :> String;

		attribute def ButtonPress {
			attribute buttonId : ButtonId;
		}

		attribute def IRCommand {
			attribute address : DeviceAddress;
			attribute functionCode : FunctionCode;
		}

		attribute def IRSignal {
			attribute command : IRCommand;
			attribute carrierFrequency : FrequencyValue;
		}

		port def IRTransmitterPort {
			out signal : IRSignal;
		}

		port def IRReceiverPort {
			in signal : IRSignal;
		}

		action def GenerateCommand {
			in buttonPress : ButtonPress;
			out command : IRCommand;
		}

		action def ModulateIRSignal {
			in command : IRCommand;
			out irSignal : IRSignal;
		}

		action def DetectIRSignal {
			in incomingSignal : IRSignal;
			out detectedCommand : IRCommand;
		}

		action def ValidateCommand {
			in command : IRCommand;
			out valid : Boolean;
		}

		action def ExecuteTVAction {
			in command : IRCommand;
		}

		part def Button {
			attribute buttonId : ButtonId;
		}

		part def Microcontroller {
			perform action 'generate command' : GenerateCommand;
		}

		part def IREmitter {
			attribute carrierFrequency : FrequencyValue = 38 [kHz];
			perform action 'modulate signal' : ModulateIRSignal;
			port transmitter : IRTransmitterPort;
		}

		part def IRPhotodetector {
			attribute maxRange : LengthValue = 12 [m];
			port receiver : IRReceiverPort;
		}

		part def Demodulator {
			perform action 'detect signal' : DetectIRSignal;
			perform action 'validate command' : ValidateCommand;
		}

		part def ReceiverModule {
			part photodetector : IRPhotodetector;
			part demodulator : Demodulator;
			port irInput : IRReceiverPort;
			connection irInputToPhotodetector connect irInput to photodetector.receiver;
		}

		part def RemoteControl {
			attribute buttonCount : Integer = 25;
			part buttons : Button[25];
			part microcontroller : Microcontroller;
			part emitter : IREmitter;
			port irOutput : IRTransmitterPort;
			exhibit state 'remote states' : RemoteStates;
			connection emitterToOutput connect emitter.transmitter to irOutput;
		}

		part def Television {
			part receiver : ReceiverModule;
			port irInput : IRReceiverPort;
			perform action 'execute action' : ExecuteTVAction;
			exhibit state 'tv states' : TVStates;
			connection irInputToReceiver connect irInput to receiver.irInput;
		}

		state def RemoteStates;
		state def TVStates;
	}

	package Requirements {
		private import Definitions::*;

		requirement def 'Button Count Requirement' {
			doc /* The remote control shall have 25 buttons for user input. */
			attribute buttonCount : Integer = 25;
			constraint { buttonCount == 25 }
		}

		requirement def 'Carrier Frequency Requirement' {
			doc /* The IR signal shall be transmitted at a carrier frequency of 38 kHz. */
			attribute carrierFrequency : FrequencyValue = 38 [kHz];
			constraint { carrierFrequency == 38 [kHz] }
		}

		requirement def 'Detection Range Requirement' {
			doc /* The IR photodetector shall detect IR signals from up to 12 meters away. */
			attribute maxRange : LengthValue = 12 [m];
			constraint { maxRange >= 12 [m] }
		}

		requirement def 'Latency Requirement' {
			doc /* The latency from button press to TV response shall be less than 100 milliseconds. */
			attribute maxLatency : TimeDurationValue = 100 [ms];
			constraint { maxLatency < 100 [ms] }
		}
	}

	package Usages {
		private import Definitions::*;
		private import Requirements::*;

		action 'generate command' : GenerateCommand;
		action 'modulate signal' : ModulateIRSignal;
		action 'detect signal' : DetectIRSignal;
		action 'validate command' : ValidateCommand;
		action 'execute action' : ExecuteTVAction;

		part 'remote control' : RemoteControl;
		part television : Television;

		connection irLink connect 'remote control'.irOutput to television.irInput;

		state 'remote states' : RemoteStates {
			entry; then idle;
			state idle;
			accept press : ButtonPress
				do 'generate command'
				then transmitting;
			state transmitting {
				do 'modulate signal';
			}
			transition
				first transmitting
				then idle;
		}

		state 'tv states' : TVStates {
			entry; then 'Power Off';
			state 'Power Off';
			accept cmd : IRCommand
				if cmd.functionCode == "powerOn"
				do 'execute action'
				then 'Standby';
			state 'Standby';
			accept cmd : IRCommand
				if cmd.functionCode == "powerOn"
				do 'execute action'
				then 'Active';
			accept cmd : IRCommand
				if cmd.functionCode == "powerOff"
				do 'execute action'
				then 'Power Off';
			state 'Active';
			accept cmd : IRCommand
				if cmd.functionCode == "powerOff"
				do 'execute action'
				then 'Standby';
			accept cmd : IRCommand
				if cmd.functionCode != "powerOff" and cmd.functionCode != "powerOn"
				do 'execute action'
				then 'Active';
		}

		requirement 'button count requirement' : 'Button Count Requirement';
		requirement 'carrier frequency requirement' : 'Carrier Frequency Requirement';
		requirement 'detection range requirement' : 'Detection Range Requirement';
		requirement 'latency requirement' : 'Latency Requirement';

		satisfy 'button count requirement' by 'remote control';
		satisfy 'carrier frequency requirement' by 'remote control';
		satisfy 'detection range requirement' by television;
		satisfy 'latency requirement' by television;
	}
}
