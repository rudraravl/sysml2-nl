package 'Federal Signal Emergency Warning System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def SystemOff;
		attribute def FaultDetected;
		attribute def FaultCleared;
		attribute def PowerFailure;
		attribute def PowerRestored;

		item def OperatorCommand {
			attribute priority : String;
			attribute sirenTone : String;
			attribute lightPattern : String;
		}
		item def SirenInstruction {
			attribute tone : String;
		}
		item def LightInstruction {
			attribute pattern : String;
		}
		item def PowerSignal {
			attribute voltage : ElectricPotentialValue;
			attribute current : ElectricCurrentValue;
		}
		item def SirenSignal {
			attribute frequency : FrequencyValue;
			attribute amplitude : PowerValue;
		}
		item def LightControlSignal {
			attribute pattern : String;
			attribute dutyCycle : Real;
		}
		item def DiagnosticFeedback {
			attribute status : String;
			attribute faultCode : Integer;
		}

		part def Operator {
			port commandPort {
				out cmd : OperatorCommand;
			}
		}

		part def ControlProcessor {
			port commandPort {
				in cmd : OperatorCommand;
			}
			port powerPort {
				in pwr : PowerSignal;
			}
			port sirenCmdPort {
				out sirenCmd : SirenInstruction;
			}
			port lightCmdPort {
				out lightCmd : LightInstruction;
			}
			port diagPort {
				out diag : DiagnosticFeedback;
			}

			exhibit state 'Control Processor States' parallel {
				state 'Operational States' {
					entry; then standby;
					state standby;
					accept OperatorCommand
						then active;
					state active;
					accept SystemOff
						then standby;
				}
				state 'Health States' {
					entry; then normal;
					state normal;
					accept FaultDetected
						do send new DiagnosticFeedback() via diagPort
						then degraded;
					state degraded;
					accept FaultCleared
						then normal;
				}
			}
		}

		part def PowerSupplyUnit {
			port vehiclePowerPort {
				in vPwr : PowerSignal;
			}
			port systemPowerPort {
				out sPwr : PowerSignal;
			}
			attribute backupBatteryCapacity : EnergyValue;

			exhibit state 'Power Supply States' {
				entry; then normal;
				state normal;
				accept PowerFailure
					then backup;
				state backup;
				accept PowerRestored
					then normal;
			}
		}

		part def SirenDriver {
			port cmdPort {
				in cmd : SirenInstruction;
			}
			port powerPort {
				in pwr : PowerSignal;
			}
			port signalPort {
				out sig : SirenSignal;
			}
		}

		part def SpeakerArray {
			port signalPort {
				in sig : SirenSignal;
			}
		}

		part def LightController {
			port cmdPort {
				in cmd : LightInstruction;
			}
			port powerPort {
				in pwr : PowerSignal;
			}
			port signalPort {
				out sig : LightControlSignal;
			}
		}

		part def LEDLightHead {
			port signalPort {
				in sig : LightControlSignal;
			}
		}

		part def WarningSystem {
			port operatorPort {
				in cmd : OperatorCommand;
			}
			port vehiclePowerPort {
				in vPwr : PowerSignal;
			}
			port diagnosticPort {
				out diag : DiagnosticFeedback;
			}

			part controlProcessor : ControlProcessor;
			part powerSupply : PowerSupplyUnit;
			part sirenDriver : SirenDriver;
			part lightController : LightController;
			part speakerArrays : SpeakerArray[4];
			part ledLightHeads : LEDLightHead[6];

			connect operatorPort to controlProcessor.commandPort;
			connect vehiclePowerPort to powerSupply.vehiclePowerPort;
			connect powerSupply.systemPowerPort to controlProcessor.powerPort;
			connect powerSupply.systemPowerPort to sirenDriver.powerPort;
			connect powerSupply.systemPowerPort to lightController.powerPort;
			connect controlProcessor.sirenCmdPort to sirenDriver.cmdPort;
			connect controlProcessor.lightCmdPort to lightController.cmdPort;
			connect controlProcessor.diagPort to diagnosticPort;
			connect sirenDriver.signalPort to speakerArrays.signalPort;
			connect lightController.signalPort to ledLightHeads.signalPort;

			flow cmdFlow of OperatorCommand
				from operatorPort.cmd to controlProcessor.commandPort.cmd;
			flow powerFlow of PowerSignal
				from vehiclePowerPort.vPwr to powerSupply.vehiclePowerPort.vPwr;
			flow systemPowerFlow of PowerSignal
				from powerSupply.systemPowerPort.sPwr to controlProcessor.powerPort.pwr;
			flow sirenCmdFlow of SirenInstruction
				from controlProcessor.sirenCmdPort.sirenCmd to sirenDriver.cmdPort.cmd;
			flow lightCmdFlow of LightInstruction
				from controlProcessor.lightCmdPort.lightCmd to lightController.cmdPort.cmd;
			flow sirenSignalFlow of SirenSignal
				from sirenDriver.signalPort.sig to speakerArrays.signalPort.sig;
			flow lightSignalFlow of LightControlSignal
				from lightController.signalPort.sig to ledLightHeads.signalPort.sig;
			flow diagFlow of DiagnosticFeedback
				from controlProcessor.diagPort.diag to diagnosticPort.diag;
		}
	}

	package Usages {
		private import Definitions::*;

		part operator : Operator;
		part warningSystem : WarningSystem;

		connect operator.commandPort to warningSystem.operatorPort;
	}

	package Requirements {
		private import Definitions::*;

		requirement def 'Reliability Requirement' {
			doc /* The system shall maintain operation during primary power failure using battery backup with capacity exceeding 1000 joules. */
			subject warningSystem : WarningSystem;
			require warningSystem.powerSupply.backupBatteryCapacity > 1000 [J];
		}

		requirement def 'Audibility Requirement' {
			doc /* The system shall produce audible warnings at frequencies above 500 hertz. */
			subject warningSystem : WarningSystem;
			require warningSystem.sirenDriver.signalPort.sig.frequency > 500 [Hz];
		}
	}
}
