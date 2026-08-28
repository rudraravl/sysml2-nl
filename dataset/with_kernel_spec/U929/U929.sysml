package TurnCoordinatorSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def TurnRate :> Real;
	attribute def BankAngle :> Real;
	attribute def LateralAcceleration :> Real;
	attribute def BallDisplacement :> Real;

	item def GyroData {
		attribute turnRate : TurnRate;
		attribute bankAngle : BankAngle;
	}

	item def InclinometerData {
		attribute lateralAccel : LateralAcceleration;
	}

	item def DisplayCommand {
		attribute displayBankAngle : BankAngle;
		attribute ballPosition : BallDisplacement;
	}

	attribute def PowerOn;
	attribute def PowerOff;
	attribute def FailureDetected;
	attribute def FailureCleared;

	port def PowerPort {
		in power : Boolean;
	}
	port def GyroOutPort {
		out gyroData : GyroData;
	}
	port def InclinometerOutPort {
		out inclinometerData : InclinometerData;
	}
	port def ProcessorGyroInPort {
		in gyroData : GyroData;
	}
	port def ProcessorInclinometerInPort {
		in inclinometerData : InclinometerData;
	}
	port def DisplayOutPort {
		out displayCommand : DisplayCommand;
	}
	port def DisplayInPort {
		in displayCommand : DisplayCommand;
	}
	port def FailureOutPort {
		out failure : Boolean;
	}
	port def FailureInPort {
		in failure : Boolean;
	}

	action def SpinUpGyro;
	action def CalibrateSensors;
	action def SenseMotion {
		out gyroData : GyroData;
	}
	action def SenseLateralAccel {
		out inclinometerData : InclinometerData;
	}
	action def ProcessData {
		in gyroData : GyroData;
		in inclinometerData : InclinometerData;
		out displayCommand : DisplayCommand;
	}
	action def UpdateDisplay {
		in displayCommand : DisplayCommand;
	}
	action def HandlePowerLoss;
	action def IndicateFailure;

	part def RateGyroscope {
		port powerPort : PowerPort;
		port dataOut : GyroOutPort;
		perform action senseMotion : SenseMotion;
	}

	part def Inclinometer {
		port dataOut : InclinometerOutPort;
		perform action senseLateralAccel : SenseLateralAccel;
	}

	part def SignalProcessor {
		port powerPort : PowerPort;
		port gyroIn : ProcessorGyroInPort;
		port inclinometerIn : ProcessorInclinometerInPort;
		port displayOut : DisplayOutPort;
		port failureOut : FailureOutPort;
		perform action processData : ProcessData;
	}

	part def InstrumentDisplay {
		port powerPort : PowerPort;
		port displayIn : DisplayInPort;
		port failureIn : FailureInPort;
		perform action updateDisplay : UpdateDisplay;
	}

	state def TurnCoordinatorStates;

	part def TurnCoordinator {
		port powerPort : PowerPort;
		port failureOut : FailureOutPort;
		part rateGyroscope : RateGyroscope;
		part inclinometer : Inclinometer;
		part signalProcessor : SignalProcessor;
		part instrumentDisplay : InstrumentDisplay;
	}

	part turnCoordinator : TurnCoordinator {
		action spinUpGyro : SpinUpGyro;
		action calibrateSensors : CalibrateSensors;
		action processData : ProcessData;
		action handlePowerLoss : HandlePowerLoss;
		action indicateFailure : IndicateFailure;

		flow powerFlow1 of Boolean from powerPort.power to rateGyroscope.powerPort.power;
		flow powerFlow2 of Boolean from powerPort.power to signalProcessor.powerPort.power;
		flow powerFlow3 of Boolean from powerPort.power to instrumentDisplay.powerPort.power;
		flow gyroDataFlow of GyroData from rateGyroscope.dataOut.gyroData to signalProcessor.gyroIn.gyroData;
		flow inclinometerDataFlow of InclinometerData from inclinometer.dataOut.inclinometerData to signalProcessor.inclinometerIn.inclinometerData;
		flow displayCommandFlow of DisplayCommand from signalProcessor.displayOut.displayCommand to instrumentDisplay.displayIn.displayCommand;
		flow failureFlow of Boolean from signalProcessor.failureOut.failure to instrumentDisplay.failureIn.failure;
		flow failureIndicationFlow of Boolean from signalProcessor.failureOut.failure to failureOut.failure;

		exhibit state 'coordinator states' : TurnCoordinatorStates {
			entry; then off;
			state off;
			accept PowerOn then startup;
			state startup {
				entry spinUpGyro;
				then operational;
			}
			state operational {
				do processData;
				accept PowerOff
					do handlePowerLoss
					then powerLoss;
				accept FailureDetected
					do indicateFailure
					then failure;
			}
			state powerLoss;
			accept PowerOn then startup;
			state failure;
			accept FailureCleared then operational;
			accept PowerOff then off;
		}
	}

	requirement def TurnCoordinatorRequirement {
		doc /* The turn coordinator shall provide turn rate and coordination indication. */
		subject turnCoordinator : TurnCoordinator;
		constraint {
			doc /* The turn coordinator shall display turn rate and coordination to the pilot. */
			true
		}
	}

	requirement turnCoordinatorReq : TurnCoordinatorRequirement;

	satisfy turnCoordinatorReq by turnCoordinator;
}
