package 'AN/APG-77 Radar System' {
	private import ISQ::*;
	private import ScalarValues::*;

	package ValueTypes {
		item def RFPulse {
			attribute power : PowerValue;
			attribute frequency : FrequencyValue;
			attribute pulseWidth : TimeValue;
		}
		item def EchoSignal {
			attribute amplitude : PowerValue;
			attribute timeDelay : TimeValue;
			attribute dopplerShift : FrequencyValue;
			attribute azimuth : PlaneAngleValue;
			attribute elevation : PlaneAngleValue;
		}
		item def TargetData {
			attribute range : LengthValue;
			attribute velocity : SpeedValue;
			attribute azimuth : PlaneAngleValue;
			attribute elevation : PlaneAngleValue;
		}
		item def ModeCommand {
			attribute mode : RadarMode;
		}
		enum def RadarMode {
			standby;
			search;
			track;
		}
	}

	package ComponentDefinitions {
		private import ValueTypes::*;

		part def ModeController {
			port cmdPort { in modeCmd : ModeCommand; }
			port radarModePort { out radarMode : RadarMode; }

			exhibit state ModeStateMachine {
				entry; then standby;
				state standby;
				transition t1
					source standby
					target search
					accept modeCmd : ModeCommand;
				state search;
				transition t2
					source search
					target track
					accept modeCmd : ModeCommand;
				state track;
				transition t3
					source track
					target standby
					accept modeCmd : ModeCommand;
			}
		}

		part def Transmitter {
			port modePort { in radarMode : RadarMode; }
			port rfPulsePort { out rfPulse : RFPulse; }

			exhibit state TransmitterStates {
				entry; then idle;
				state idle;
				transition t1
					source idle
					target transmitting
					accept radarMode : RadarMode;
				state transmitting;
				transition t2
					source transmitting
					target idle
					accept radarMode : RadarMode;
			}
		}

		part def Antenna {
			port txPulsePort { in txPulse : RFPulse; }
			port rxEchoPort { out echo : EchoSignal; }
			attribute steeringAzimuth : PlaneAngleValue;
			attribute steeringElevation : PlaneAngleValue;
		}

		part def Receiver {
			port echoPort { in echo : EchoSignal; }
			port amplifiedEchoPort { out amplifiedEcho : EchoSignal; }
		}

		part def SignalProcessor {
			port echoPort { in echo : EchoSignal; }
			port targetDataPort { out targetData : TargetData; }

			calc def CalculateRange {
				in timeDelay : TimeValue;
				return range : LengthValue;
			}

			calc def CalculateVelocity {
				in dopplerShift : FrequencyValue;
				return velocity : SpeedValue;
			}

			action def ProcessEcho {
				in echo : EchoSignal;
				out targetData : TargetData;
			}
		}
	}

	package SystemDefinition {
		private import ValueTypes::*;
		private import ComponentDefinitions::*;

		part def RadarSystem {
			port cmdPort { in modeCmd : ModeCommand; }
			port dataPort { out targetData : TargetData; }

			part modeController : ModeController;
			part transmitter : Transmitter;
			part antenna : Antenna;
			part receiver : Receiver;
			part signalProcessor : SignalProcessor;

			flow modeCmdFlow of ModeCommand 
				from cmdPort.modeCmd to modeController.cmdPort.modeCmd;
			flow radarModeFlow of RadarMode 
				from modeController.radarModePort.radarMode to transmitter.modePort.radarMode;

			flow rfPulseFlow of RFPulse 
				from transmitter.rfPulsePort.rfPulse to antenna.txPulsePort.txPulse;
			flow echoFlow of EchoSignal 
				from antenna.rxEchoPort.echo to receiver.echoPort.echo;
			flow amplifiedEchoFlow of EchoSignal 
				from receiver.amplifiedEchoPort.amplifiedEcho to signalProcessor.echoPort.echo;
			flow targetDataFlow of TargetData 
				from signalProcessor.targetDataPort.targetData to dataPort.targetData;
		}
	}

	package Requirements {
		private import ValueTypes::*;
		private import SystemDefinition::*;

		requirement def DetectTargets {
			doc /* The system shall detect airborne and surface targets. */
		}
		requirement def TrackTargets {
			doc /* The system shall track targets in Track mode. */
		}
		requirement def OperationalModes {
			doc /* The system shall operate in Standby, Search, and Track modes. */
		}

		part radar : RadarSystem;
		satisfy DetectTargets by radar;
		satisfy TrackTargets by radar;
		satisfy OperationalModes by radar;
	}
}
