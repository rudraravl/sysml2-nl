package RadioDirectionFinder {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def AngleValue :> ScalarValues::Real;

	item def RFSignal {
		attribute frequency : ISQ::FrequencyValue;
		attribute phase : AngleValue;
		attribute amplitude : Real;
	}

	item def ReceivedSignal {
		attribute phase : AngleValue;
		attribute amplitude : Real;
	}

	item def BearingResult {
		attribute bearing : AngleValue;
		attribute confidence : Real;
	}

	item def TargetFrequencyCommand {
		attribute frequency : ISQ::FrequencyValue;
	}

	item def PowerOnCommand;
	item def PowerOffCommand;
	item def TestComplete;
	item def StartTrackingCommand;
	item def StopTrackingCommand;
	item def SignalDetected;

	action def SelfTest;
	action def Scan;
	action def ProcessSignals;
	action def UpdateDisplay;

	part def AntennaElement {
		port rfOut {
			out signal : RFSignal;
		}
	}

	part def RFReceiver {
		port rfIn {
			in signal : RFSignal;
		}
		port dataOut {
			out receivedSignal : ReceivedSignal;
		}
		port controlIn {
			in command : TargetFrequencyCommand;
		}
		attribute tunedFrequency : ISQ::FrequencyValue;
	}

	part def SignalProcessor {
		port dataIn1 {
			in receivedSignal : ReceivedSignal;
		}
		port dataIn2 {
			in receivedSignal : ReceivedSignal;
		}
		port dataIn3 {
			in receivedSignal : ReceivedSignal;
		}
		port dataIn4 {
			in receivedSignal : ReceivedSignal;
		}
		port bearingOut {
			out result : BearingResult;
		}
		attribute antennaSpacing : ISQ::LengthValue;
	}

	part def DisplayUnit {
		port displayIn {
			in result : BearingResult;
		}
	}

	part def ControlUnit {
		port freqOut {
			out command : TargetFrequencyCommand;
		}
		port powerOnOut {
			out command : PowerOnCommand;
		}
		port powerOffOut {
			out command : PowerOffCommand;
		}
		port startTrackingOut {
			out command : StartTrackingCommand;
		}
		port stopTrackingOut {
			out command : StopTrackingCommand;
		}
	}

	part def RDFSystem {
		part controlUnit : ControlUnit;
		part antenna1 : AntennaElement;
		part antenna2 : AntennaElement;
		part antenna3 : AntennaElement;
		part antenna4 : AntennaElement;
		part receiver1 : RFReceiver;
		part receiver2 : RFReceiver;
		part receiver3 : RFReceiver;
		part receiver4 : RFReceiver;
		part processor : SignalProcessor;
		part display : DisplayUnit;

		flow rfFlow1 of RFSignal from antenna1.rfOut.signal to receiver1.rfIn.signal;
		flow rfFlow2 of RFSignal from antenna2.rfOut.signal to receiver2.rfIn.signal;
		flow rfFlow3 of RFSignal from antenna3.rfOut.signal to receiver3.rfIn.signal;
		flow rfFlow4 of RFSignal from antenna4.rfOut.signal to receiver4.rfIn.signal;

		flow dataFlow1 of ReceivedSignal from receiver1.dataOut.receivedSignal to processor.dataIn1.receivedSignal;
		flow dataFlow2 of ReceivedSignal from receiver2.dataOut.receivedSignal to processor.dataIn2.receivedSignal;
		flow dataFlow3 of ReceivedSignal from receiver3.dataOut.receivedSignal to processor.dataIn3.receivedSignal;
		flow dataFlow4 of ReceivedSignal from receiver4.dataOut.receivedSignal to processor.dataIn4.receivedSignal;

		flow bearingFlow of BearingResult from processor.bearingOut.result to display.displayIn.result;

		flow freqFlow1 of TargetFrequencyCommand from controlUnit.freqOut.command to receiver1.controlIn.command;
		flow freqFlow2 of TargetFrequencyCommand from controlUnit.freqOut.command to receiver2.controlIn.command;
		flow freqFlow3 of TargetFrequencyCommand from controlUnit.freqOut.command to receiver3.controlIn.command;
		flow freqFlow4 of TargetFrequencyCommand from controlUnit.freqOut.command to receiver4.controlIn.command;

		state RDFBehavior {
			entry; then powerOff;
			state powerOff;
			transition first powerOff accept cmd : PowerOnCommand via controlUnit.powerOnOut then standby;
			state standby {
				entry; do action selfTest : SelfTest;
			}
			transition first standby accept sig : TestComplete then ready;
			state ready;
			transition first ready accept cmd : StartTrackingCommand via controlUnit.startTrackingOut then tracking;
			transition first ready accept cmd : PowerOffCommand via controlUnit.powerOffOut then powerOff;
			state tracking {
				entry; then scanning;
				state scanning {
					do action scan : Scan;
				}
				transition first scanning accept sig : SignalDetected then processing;
				state processing {
					do action processSignals : ProcessSignals;
				}
				transition first processing then updating;
				state updating {
					do action updateDisplay : UpdateDisplay;
				}
				transition first updating then scanning;
			}
			transition first tracking accept cmd : StopTrackingCommand via controlUnit.stopTrackingOut then ready;
			transition first tracking accept cmd : PowerOffCommand via controlUnit.powerOffOut then powerOff;
		}
	}

	requirement def BearingAccuracy {
		attribute maxError : AngleValue;
	}
	requirement def FrequencyCoverage {
		attribute minFrequency : ISQ::FrequencyValue;
		attribute maxFrequency : ISQ::FrequencyValue;
	}
	requirement def UpdateRate {
		attribute rate : ISQ::FrequencyValue;
	}

	requirement 'RDF Bearing Accuracy' : BearingAccuracy {
		attribute maxError = 0.0174533 [SI::rad];
	}
	requirement 'RDF Frequency Coverage' : FrequencyCoverage {
		attribute minFrequency = 3000000.0 [SI::Hz];
		attribute maxFrequency = 3000000000.0 [SI::Hz];
	}
	requirement 'RDF Update Rate' : UpdateRate {
		attribute rate = 10.0 [SI::Hz];
	}

	part rdfSystem : RDFSystem;
}
