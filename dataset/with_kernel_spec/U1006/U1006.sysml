package 'Supervisory Bus Control System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQElectromagnetism::*;

	package Definitions {
		attribute def BusUtilization :> ScalarValues::Real;
		attribute def ErrorRate :> ScalarValues::Real;
		attribute def SignalQuality :> ScalarValues::Real;
		attribute def MessagePriority :> ScalarValues::Integer;

		item def BusMessage {
			attribute priority : MessagePriority;
			attribute senderId : ScalarValues::Integer;
			attribute timestamp : ISQ::TimeValue;
			attribute payload : ScalarValues::String;
		}

		item def DiagnosticReport {
			attribute utilization : BusUtilization;
			attribute errorRate : ErrorRate;
			attribute status : ScalarValues::String;
		}

		port def BusDataIF;
		port def PowerIF;
		port def HealthIF;

		part def ElectronicControlUnit {
			attribute ecuId : ScalarValues::Integer;
			port busIF : ~BusDataIF;
			port powerIn : ~PowerIF;
			perform action sendMessage : SendMessage;
			perform action receiveMessage : ReceiveMessage;
		}

		part def BusController {
			attribute maxUtilization : BusUtilization;
			attribute maxErrorRate : ErrorRate;
			attribute busUtilization : BusUtilization;
			attribute errorCount : ScalarValues::Integer;
			port transceiverIF : ~BusDataIF;
			port powerIn : ~PowerIF;
			port healthMonitor : ~HealthIF;
			perform action arbitrateMessages : ArbitrateMessages;
			perform action monitorHealth : MonitorHealth;
			exhibit state controllerStates : ControllerStates;
		}

		part def BusTransceiver {
			attribute signalQuality : SignalQuality;
			attribute errorRate : ErrorRate;
			port controllerIF : BusDataIF;
			port ecuIF1 : BusDataIF;
			port ecuIF2 : BusDataIF;
			port ecuIF3 : BusDataIF;
			port powerIn : ~PowerIF;
			port healthOut : HealthIF;
			perform action convertToElectrical : ConvertToElectrical;
			perform action convertToDigital : ConvertToDigital;
			perform action monitorSignalQuality : MonitorSignalQuality;
		}

		part def PowerManagementUnit {
			attribute nominalVoltage : ElectricPotentialValue;
			port powerOutController : PowerIF;
			port powerOutTransceiver : PowerIF;
			port powerOutECU1 : PowerIF;
			port powerOutECU2 : PowerIF;
			port powerOutECU3 : PowerIF;
			perform action regulatePower : RegulatePower;
		}

		part def SupervisoryBusSystem {
			part busController : BusController;
			part busTransceiver : BusTransceiver;
			part powerManagementUnit : PowerManagementUnit;
			part engineECU : ElectronicControlUnit;
			part brakeECU : ElectronicControlUnit;
			part sensorECU : ElectronicControlUnit;
			exhibit state systemStates : SystemStates;
		}

		action def SendMessage { out msg : BusMessage; }
		action def ReceiveMessage { in msg : BusMessage; }
		action def ArbitrateMessages { in msgQueue : BusMessage[0..*]; out selectedMsg : BusMessage; }
		action def MonitorHealth { out utilization : BusUtilization; out errorRate : ErrorRate; }
		action def ConvertToElectrical { in msg : BusMessage; out signal : ScalarValues::Real; }
		action def ConvertToDigital { in signal : ScalarValues::Real; out msg : BusMessage; }
		action def MonitorSignalQuality { out quality : SignalQuality; out errorRate : ErrorRate; }
		action def RegulatePower { out voltage : ElectricPotentialValue; out current : ElectricCurrentValue; }
		action def InitializeNetwork;
		action def RecoverCommunication;
		action def DiagnoseFault;

		attribute def PowerOnSignal;
		attribute def InitCompleteSignal;
		attribute def CommunicationErrorSignal;
		attribute def SevereFaultSignal;
		attribute def RecoverySignal;
		attribute def ResetSignal;

		state def SystemStates;
		state def ControllerStates;

		requirement def ReliableDataExchange {
			text "The supervisory bus system shall maintain reliable data exchange between all ECUs with a minimum reliability of 99.99 percent during normal operation.";
			attribute targetReliability : ScalarValues::Real;
		}

		requirement def DeterministicLatency {
			text "The bus controller shall provide deterministic message arbitration with bounded latency for critical messages.";
			attribute maxLatency : ISQ::TimeValue;
		}

		requirement def FaultTolerantOperation {
			text "The system shall detect communication faults and attempt recovery before entering a fault state, ensuring continued operation when possible.";
		}
	}

	package Usages {
		private import Definitions::*;

		action sendMessage : SendMessage;
		action receiveMessage : ReceiveMessage;
		action arbitrateMessages : ArbitrateMessages;
		action monitorHealth : MonitorHealth;
		action convertToElectrical : ConvertToElectrical;
		action convertToDigital : ConvertToDigital;
		action monitorSignalQuality : MonitorSignalQuality;
		action regulatePower : RegulatePower;
		action initializeNetwork : InitializeNetwork;
		action recoverCommunication : RecoverCommunication;
		action diagnoseFault : DiagnoseFault;

		state systemStates : SystemStates {
			in controller : BusController;
			in transceiver : BusTransceiver;
			in powerUnit : PowerManagementUnit;

			entry; then offline;

			state offline;
			accept PowerOnSignal
				then initializing;

			state initializing {
				entry initializeNetwork;
				do regulatePower;
				do monitorHealth;
			}
			accept InitCompleteSignal
				then normal;

			state normal {
				do arbitrateMessages;
				do sendMessage;
				do receiveMessage;
				do convertToElectrical;
				do convertToDigital;
				do monitorHealth;
				do monitorSignalQuality;
			}
			accept CommunicationErrorSignal
				then degraded;
			accept when controller.busUtilization > controller.maxUtilization
				then degraded;
			accept SevereFaultSignal
				then fault;

			state degraded {
				entry recoverCommunication;
				do monitorHealth;
				do monitorSignalQuality;
			}
			accept RecoverySignal
				then normal;
			accept SevereFaultSignal
				then fault;

			state fault {
				entry diagnoseFault;
				do monitorHealth;
			}
			accept ResetSignal
				then offline;
		}

		part supervisorySystem : SupervisoryBusSystem {
			connect powerManagementUnit.powerOutController to busController.powerIn;
			connect powerManagementUnit.powerOutTransceiver to busTransceiver.powerIn;
			connect powerManagementUnit.powerOutECU1 to engineECU.powerIn;
			connect powerManagementUnit.powerOutECU2 to brakeECU.powerIn;
			connect powerManagementUnit.powerOutECU3 to sensorECU.powerIn;

			connect busController.transceiverIF to busTransceiver.controllerIF;
			connect busTransceiver.ecuIF1 to engineECU.busIF;
			connect busTransceiver.ecuIF2 to brakeECU.busIF;
			connect busTransceiver.ecuIF3 to sensorECU.busIF;
			connect busTransceiver.healthOut to busController.healthMonitor;

			exhibit systemStates {
				in controller = busController;
				in transceiver = busTransceiver;
				in powerUnit = powerManagementUnit;
			}
		}

		requirement reliableDataExchange : ReliableDataExchange {
			targetReliability = 0.9999;
		}

		requirement deterministicLatency : DeterministicLatency {
			maxLatency = 10.0 * milli * second;
		}

		requirement faultTolerantOperation : FaultTolerantOperation;
	}
}
