package HyfrecatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def AC_Power;
	item def DC_Power;
	item def RF_Signal {
		attribute frequency :> ISQ::frequency;
		attribute powerLevel :> ISQ::power;
	}
	item def TissueContactSignal;
	item def UserCommand;
	item def StartCommand :> UserCommand;
	item def StopCommand :> UserCommand;
	item def ModeSelectCommand :> UserCommand {
		attribute mode : String;
	}
	item def PowerSelectCommand :> UserCommand {
		attribute level :> ISQ::power;
	}
	item def ControlSignal {
		attribute mode : String;
		attribute powerLevel :> ISQ::power;
	}
	item def ShutdownSignal;
	item def SafetyStatus {
		attribute temperature :> ISQ::temperature;
		attribute current :> ISQ::electricCurrent;
		attribute power :> ISQ::power;
	}

	port def ACPowerPort { in acPower : AC_Power; }
	port def DCPowerOutPort { out dcPower : DC_Power; }
	port def DCPowerInPort { in dcPower : DC_Power; }
	port def RFSignalOutPort { out rfSignal : RF_Signal; }
	port def RFSignalInPort { in rfSignal : RF_Signal; }
	port def CommandInPort { in command : UserCommand; }
	port def ControlOutPort { out signal : ControlSignal; }
	port def ControlInPort { in signal : ControlSignal; }
	port def TissueContactOutPort { out contact : TissueContactSignal; }
	port def TissueContactInPort { in contact : TissueContactSignal; }
	port def SafetyMonitorOutPort { out status : SafetyStatus; out shutdown : ShutdownSignal; }
	port def SafetyMonitorInPort { in status : SafetyStatus; in shutdown : ShutdownSignal; }

	part def PowerSupply {
		port acIn : ACPowerPort;
		port dcOut : DCPowerOutPort;
		attribute outputVoltage : Real;
		perform action convertACtoDC;
	}

	part def RFOscillator {
		port dcIn : DCPowerInPort;
		port rfOut : RFSignalOutPort;
		port controlIn : ControlInPort;
		attribute frequency :> ISQ::frequency;
		perform action generateSignal;
	}

	part def ControlUnit {
		port userCommandIn : CommandInPort;
		port oscillatorControlOut : ControlOutPort;
		port safetyMonitorIn : SafetyMonitorInPort;
		port handpieceIn : TissueContactInPort;
		exhibit state ControlUnitStates {
			entry; then off;
			state off;
			accept StartCommand via userCommandIn then ready;
			state ready;
			accept ModeSelectCommand via userCommandIn then ready;
			accept PowerSelectCommand via userCommandIn then ready;
			accept TissueContactSignal via handpieceIn then activeTreatment;
			state activeTreatment;
			accept StopCommand via userCommandIn then off;
			accept ShutdownSignal via safetyMonitorIn then fault;
			state fault;
		}
	}

	part def Handpiece {
		port rfIn : RFSignalInPort;
		port contactOut : TissueContactOutPort;
		part electrode : Electrode;
		perform action deliverEnergy;
	}

	part def Electrode {
		attribute impedance : Real;
	}

	part def SafetyMonitor {
		port rfIn : RFSignalInPort;
		port monitorOut : SafetyMonitorOutPort;
		attribute maxTemp :> ISQ::temperature = 373.15 [K];
		attribute maxCurrent :> ISQ::electricCurrent = 2 [A];
		attribute maxPower :> ISQ::power = 50 [W];
		perform action monitorParameters;
	}

	part def Hyfrecator {
		part powerSupply : PowerSupply;
		part rfOscillator : RFOscillator;
		part controlUnit : ControlUnit;
		part handpiece : Handpiece;
		part safetyMonitor : SafetyMonitor;

		flow dcPowerFlow of DC_Power
			from powerSupply.dcOut.dcPower to rfOscillator.dcIn.dcPower;
		flow rfSignalFlow of RF_Signal
			from rfOscillator.rfOut.rfSignal to handpiece.rfIn.rfSignal;
		flow rfMonitorFlow of RF_Signal
			from rfOscillator.rfOut.rfSignal to safetyMonitor.rfIn.rfSignal;
		flow contactFlow of TissueContactSignal
			from handpiece.contactOut.contact to controlUnit.handpieceIn.contact;
		flow safetyStatusFlow of SafetyStatus
			from safetyMonitor.monitorOut.status to controlUnit.safetyMonitorIn.status;
		flow shutdownFlow of ShutdownSignal
			from safetyMonitor.monitorOut.shutdown to controlUnit.safetyMonitorIn.shutdown;
		flow controlFlow of ControlSignal
			from controlUnit.oscillatorControlOut.signal to rfOscillator.controlIn.signal;
	}

	action def convertACtoDC {
		in acPower : AC_Power;
		out dcPower : DC_Power;
	}

	action def generateSignal {
		in dcPower : DC_Power;
		in controlSignal : ControlSignal;
		out rfSignal : RF_Signal;
	}

	action def deliverEnergy {
		in rfSignal : RF_Signal;
		out contact : TissueContactSignal;
	}

	action def monitorParameters {
		in rfSignal : RF_Signal;
		out safetyStatus : SafetyStatus;
		out shutdown : ShutdownSignal;
	}

	requirement def SafetyRequirements {
		subject hyfrecator : Hyfrecator;
		requirement tempLimit {
			doc /* The tissue temperature must not exceed 100 degC. */
			attribute limitTemp :> ISQ::temperature = 373.15 [K];
			constraint { hyfrecator.safetyMonitor.maxTemp <= limitTemp }
		}
		requirement currentLimit {
			doc /* The electrical current must not exceed 2 A. */
			attribute limitCurrent :> ISQ::electricCurrent = 2 [A];
			constraint { hyfrecator.safetyMonitor.maxCurrent <= limitCurrent }
		}
		requirement powerLimit {
			doc /* The power output must not exceed 50 W. */
			attribute limitPower :> ISQ::power = 50 [W];
			constraint { hyfrecator.safetyMonitor.maxPower <= limitPower }
		}
	}
}
