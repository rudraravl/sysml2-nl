package 'Velocity Receiver System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def VelocityComponent :> ScalarValues::Real;
	attribute def VelocityVector {
		attribute x : VelocityComponent;
		attribute y : VelocityComponent;
		attribute z : VelocityComponent;
	}
	attribute def ConfidenceScore :> ScalarValues::Real;
	enum def ReceiverStatus { idle; acquiring; tracking; }

	item def RawSignal;
	item def CleanedSignal;
	item def VelocityData {
		attribute velocity : VelocityVector;
		attribute confidence : ConfidenceScore;
		attribute status : ReceiverStatus;
	}
	item def Command;

	item def SignalDetected;
	item def LockAcquired;
	item def LockFailed;
	item def SignalLost;
	item def StartAcquisition;
	item def TrackingActive;
	item def CalibrationCommand;
	item def Stop;
	item def CalibrationComplete;

	port def RawSignalInPort { in rawSignal : RawSignal; }
	port def RawSignalOutPort { out acquiredSignal : RawSignal; }
	port def CleanedSignalInPort { in cleanedSignal : CleanedSignal; }
	port def CleanedSignalOutPort { out cleanedSignal : CleanedSignal; }
	port def VelocityDataInPort { in velocityData : VelocityData; }
	port def VelocityDataOutPort { out velocityData : VelocityData; }
	port def CommandInPort { in command : Command; }

	part def SignalAcquisitionUnit {
		port rawSignalIn : RawSignalInPort;
		port acquiredSignalOut : RawSignalOutPort;
		state def AcquisitionStates {
			entry; then searching;
			state searching;
			accept SignalDetected then locking;
			state locking;
			accept LockAcquired then tracking;
			accept LockFailed then searching;
			state tracking;
			accept SignalLost then searching;
		}
		exhibit state acquisitionState : AcquisitionStates;
	}

	part def SignalProcessor {
		port rawSignalIn : RawSignalInPort;
		port cleanedSignalOut : CleanedSignalOutPort;
		action def ProcessSignal {
			in sig : RawSignal;
			out clean : CleanedSignal;
		}
		action process : ProcessSignal;
	}

	part def VelocityEstimator {
		port cleanedSignalIn : CleanedSignalInPort;
		port velocityDataOut : VelocityDataOutPort;
		action def EstimateVelocity {
			in clean : CleanedSignal;
			out data : VelocityData;
		}
		action estimate : EstimateVelocity;
	}

	part def ReceiverController {
		port commandIn : CommandInPort;
		port velocityOut : VelocityDataOutPort;

		part acquisitionUnit : SignalAcquisitionUnit;
		part processor : SignalProcessor;
		part estimator : VelocityEstimator;

		connection rawSignalFlow connect acquisitionUnit.acquiredSignalOut to processor.rawSignalIn;
		connection cleanSignalFlow connect processor.cleanedSignalOut to estimator.cleanedSignalIn;
		connection velocityDataFlow connect estimator.velocityDataOut to velocityOut;

		state def ControllerStates {
			entry; then idle;
			state idle;
			accept StartAcquisition then acquiring;
			state acquiring;
			accept TrackingActive then tracking;
			accept CalibrationCommand then calibrating;
			state tracking;
			accept CalibrationCommand then calibrating;
			accept Stop then idle;
			state calibrating;
			accept CalibrationComplete then tracking;
		}
		exhibit state controllerState : ControllerStates;
	}

	part def VelocityReceiver {
		port rawSignalIn : RawSignalInPort;
		port commandIn : CommandInPort;
		port velocityOut : VelocityDataOutPort;

		part controller : ReceiverController;

		connection rawSignalInput connect rawSignalIn to controller.acquisitionUnit.rawSignalIn;
		connection commandInput connect commandIn to controller.commandIn;
		connection velocityOutput connect controller.velocityOut to velocityOut;
	}

	part def NavigationComputer {
		port velocityIn : VelocityDataInPort;
	}

	part receiverSystem : VelocityReceiver {
		part navComputer : NavigationComputer;
		connection velOutConn connect velocityOut to navComputer.velocityIn;
	}

	requirement def HighPrecisionVelocity {
		doc /* The system shall provide high-precision three-dimensional velocity data with a confidence score for navigation and guidance applications. */;
	}
	requirement def RealTimeOperation {
		doc /* The receiver shall operate continuously in real-time, providing frequent velocity updates. */;
	}
	requirement def SignalTrackingRobustness {
		doc /* The signal acquisition unit shall automatically return to searching state upon signal loss and re-acquire without manual intervention. */;
	}
	requirement def CalibrationManagement {
		doc /* The receiver controller shall manage internal calibration processes to maintain measurement accuracy. */;
	}

	requirement highPrecision : HighPrecisionVelocity {
		subject receiver : VelocityReceiver;
	}
	requirement realTime : RealTimeOperation {
		subject receiver : VelocityReceiver;
	}
	requirement trackingRobustness : SignalTrackingRobustness {
		subject acquisitionUnit : SignalAcquisitionUnit;
	}
	requirement calibrationMgmt : CalibrationManagement {
		subject controller : ReceiverController;
	}
}
