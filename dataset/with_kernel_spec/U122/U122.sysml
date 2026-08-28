package 'Surgibox Sterile Field System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		attribute def PressureValue :> Real;
		attribute def BatteryLevelValue :> Real;
		attribute def FanSpeedValue :> Real;
		attribute def TemperatureValue :> Real;

		item def Air;
		item def AmbientAir :> Air;
		item def FilteredAir :> Air;
		item def ElectricalPower;
		item def FanSpeedCommand {
			attribute speed : FanSpeedValue;
		}

		attribute def PowerOnSignal;
		attribute def PressureReachedSignal;
		attribute def StartProcedureSignal;
		attribute def EndProcedureSignal;
		attribute def LowBatterySignal;
		attribute def ShutdownCompleteSignal;
		attribute def ExternalPowerConnectedSignal;

		part def SterileWorkspace {
			port cleanAirInPort {
				in item cleanAir : FilteredAir;
			}
			port pressureSensePort {
				out pressure : PressureValue;
			}
			port exhaustLeakPort {
				out item exhaust : FilteredAir;
			}
			attribute internalPressure : PressureValue;
		}

		part def FanAssembly {
			port ambientAirInPort {
				in item ambientAir : AmbientAir;
			}
			port unfilteredAirOutPort {
				out item unfilteredAir : Air;
			}
			port fanSpeedCmdInPort {
				in item fanSpeedCmd : FanSpeedCommand;
			}
			port powerInPort {
				in item power : ElectricalPower;
			}
			attribute currentSpeed : FanSpeedValue;
		}

		part def HEPAFilterUnit {
			port unfilteredAirInPort {
				in item unfilteredAir : Air;
			}
			port cleanAirOutPort {
				out item cleanAir : FilteredAir;
			}
			attribute filtrationEfficiency : Real;
		}

		part def PressureRegulationSystem {
			port cleanAirInPort {
				in item cleanAir : FilteredAir;
			}
			port regulatedAirOutPort {
				out item regulatedAir : FilteredAir;
			}
			port pressureCmdInPort {
				in targetPressure : PressureValue;
			}
			port powerInPort {
				in item power : ElectricalPower;
			}
		}

		part def EnvironmentMonitor {
			port pressureInPort {
				in pressure : PressureValue;
			}
			port pressureDataOutPort {
				out pressureData : PressureValue;
			}
			port temperatureOutPort {
				out temperature : TemperatureValue;
			}
			port powerInPort {
				in item power : ElectricalPower;
			}
		}

		part def SystemController {
			port pressureDataInPort {
				in pressureData : PressureValue;
			}
			port batteryStatusInPort {
				in batteryStatus : BatteryLevelValue;
			}
			port fanSpeedCmdOutPort {
				out item fanSpeedCmd : FanSpeedCommand;
			}
			port pressureCmdOutPort {
				out targetPressure : PressureValue;
			}
			port alertOutPort {
				out lowBatteryAlert : LowBatterySignal;
			}
			port powerInPort {
				in item power : ElectricalPower;
			}
			exhibit state 'controller states' : ControllerStates;
		}

		part def BatteryPack {
			port powerOutPort {
				out item power : ElectricalPower;
			}
			port batteryStatusOutPort {
				out batteryStatus : BatteryLevelValue;
			}
			attribute chargeLevel : BatteryLevelValue;
			attribute capacity : Real;
		}

		part def Surgibox {
			port ambientIntakePort {
				in item ambientAir : AmbientAir;
			}
			port exhaustPort {
				out item exhaust : FilteredAir;
			}
			part sterileWorkspace : SterileWorkspace;
			part fanAssembly : FanAssembly;
			part hepaFilter : HEPAFilterUnit;
			part pressureRegulation : PressureRegulationSystem;
			part environmentMonitor : EnvironmentMonitor;
			part systemController : SystemController;
			part batteryPack : BatteryPack;
			exhibit state 'surgibox states' : SurgiboxStates;
		}

		state def SurgiboxStates;
		state def ControllerStates;

		action def InitializeSystem;
		action def PressurizeWorkspace {
			in targetPressure : PressureValue;
			out achievedPressure : PressureValue;
		}
		action def MaintainPositivePressure {
			in currentPressure : PressureValue;
			in targetPressure : PressureValue;
			out fanSpeedCmd : FanSpeedCommand;
		}
		action def MonitorEnvironment {
			out pressure : PressureValue;
			out temperature : TemperatureValue;
		}
		action def ApplyLowBatteryAlert;
		action def ShutdownSystem;

		requirement def PositivePressureRequirement {
			doc /* The Surgibox shall maintain a positive pressure differential between the sterile workspace and ambient of at least 2.5 Pa during sterileReady and active states. */
			subject surgibox : Surgibox;
			attribute minPositivePressure : PressureValue = 2.5;
		}

		requirement def HEPAFiltrationRequirement {
			doc /* The HEPA filter unit shall remove at least 99.97% of airborne particles 0.3 micrometers in diameter from incoming ambient air. */
			subject hepaFilter : HEPAFilterUnit;
			attribute minEfficiency : Real = 0.9997;
		}

		requirement def BatteryLifeRequirement {
			doc /* The battery pack shall provide sufficient power for at least four hours of continuous operation in active mode. */
			subject batteryPack : BatteryPack;
			attribute minOperatingHours : Real = 4.0;
		}

		requirement def SterilityRequirement {
			doc /* The sterile workspace shall maintain a sterile environment through HEPA filtration and positive pressure, preventing ingress of contaminated air. */
			subject surgibox : Surgibox;
		}

		requirement def SafetyRequirement {
			doc /* The Surgibox shall enter a low battery safety state and initiate shutdown when battery level falls below 10%. */
			subject surgibox : Surgibox;
			attribute criticalBatteryThreshold : BatteryLevelValue = 10.0;
		}
	}

	package Usages {
		private import Definitions::*;

		part surgiboxSystem : Surgibox {
			part :>> sterileWorkspace;
			part :>> fanAssembly;
			part :>> hepaFilter;
			part :>> pressureRegulation;
			part :>> environmentMonitor;
			part :>> systemController;
			part :>> batteryPack;

			bind ambientIntakePort = fanAssembly.ambientAirInPort;
			bind sterileWorkspace.exhaustLeakPort = exhaustPort;

			flow unfilteredAirFlow of Air
				from fanAssembly.unfilteredAirOutPort.unfilteredAir
				to hepaFilter.unfilteredAirInPort.unfilteredAir;

			flow filteredAirFlow of FilteredAir
				from hepaFilter.cleanAirOutPort.cleanAir
				to pressureRegulation.cleanAirInPort.cleanAir;

			flow regulatedAirFlow of FilteredAir
				from pressureRegulation.regulatedAirOutPort.regulatedAir
				to sterileWorkspace.cleanAirInPort.cleanAir;

			flow pressureSenseFlow of PressureValue
				from sterileWorkspace.pressureSensePort.pressure
				to environmentMonitor.pressureInPort.pressure;

			flow pressureDataFlow of PressureValue
				from environmentMonitor.pressureDataOutPort.pressureData
				to systemController.pressureDataInPort.pressureData;

			flow fanSpeedCmdFlow of FanSpeedCommand
				from systemController.fanSpeedCmdOutPort.fanSpeedCmd
				to fanAssembly.fanSpeedCmdInPort.fanSpeedCmd;

			flow pressureCmdFlow of PressureValue
				from systemController.pressureCmdOutPort.targetPressure
				to pressureRegulation.pressureCmdInPort.targetPressure;

			flow batteryStatusFlow of BatteryLevelValue
				from batteryPack.batteryStatusOutPort.batteryStatus
				to systemController.batteryStatusInPort.batteryStatus;

			flow powerToFanFlow of ElectricalPower
				from batteryPack.powerOutPort.power
				to fanAssembly.powerInPort.power;

			flow powerToRegulatorFlow of ElectricalPower
				from batteryPack.powerOutPort.power
				to pressureRegulation.powerInPort.power;

			flow powerToMonitorFlow of ElectricalPower
				from batteryPack.powerOutPort.power
				to environmentMonitor.powerInPort.power;

			flow powerToControllerFlow of ElectricalPower
				from batteryPack.powerOutPort.power
				to systemController.powerInPort.power;

			exhibit state 'surgibox states' : SurgiboxStates {
				entry action initial { }
				transition initial then initializing;

				state initializing {
					entry action 'initialize system' : InitializeSystem;
					do send new PowerOnSignal() to systemController;
				}
				transition 'initializing-pressurizing'
					first initializing
					accept PowerOnSignal
					then pressurizing;

				state pressurizing {
					entry action 'pressurize workspace' : PressurizeWorkspace;
					do action 'monitor environment' : MonitorEnvironment;
				}
				transition 'pressurizing-sterileReady'
					first pressurizing
					accept PressureReachedSignal
					then sterileReady;
				transition 'pressurizing-lowBattery'
					first pressurizing
					accept LowBatterySignal
					then lowBattery;

				state sterileReady {
					doc /* The workspace has reached target positive pressure and is ready for surgical use. */
					do action 'maintain pressure' : MaintainPositivePressure;
				}
				transition 'sterileReady-active'
					first sterileReady
					accept StartProcedureSignal
					then active;
				transition 'sterileReady-lowBattery'
					first sterileReady
					accept LowBatterySignal
					then lowBattery;
				transition 'sterileReady-shutdown'
					first sterileReady
					accept EndProcedureSignal
					then shuttingDown;

				state active {
					doc /* Surgery is in progress; the system continuously maintains positive pressure. */
					do action 'maintain pressure' : MaintainPositivePressure;
					do action 'monitor environment' : MonitorEnvironment;
				}
				transition 'active-sterileReady'
					first active
					accept EndProcedureSignal
					then sterileReady;
				transition 'active-lowBattery'
					first active
					accept LowBatterySignal
					then lowBattery;
				transition 'active-shuttingDown'
					first active
					accept ShutdownCompleteSignal
					then shuttingDown;

				state lowBattery {
					doc /* Battery is critically low; system prepares for safe shutdown. */
					entry action 'apply low battery alert' : ApplyLowBatteryAlert;
					do send new LowBatterySignal() to systemController;
				}
				transition 'lowBattery-shutdown'
					first lowBattery
					accept ShutdownCompleteSignal
					then shuttingDown;
				transition 'lowBattery-sterileReady'
					first lowBattery
					accept ExternalPowerConnectedSignal
					then sterileReady;

				state shuttingDown {
					entry action 'shutdown system' : ShutdownSystem;
				}
			}
		}

		satisfy PositivePressureRequirement by surgiboxSystem;
		satisfy HEPAFiltrationRequirement by surgiboxSystem.hepaFilter;
		satisfy BatteryLifeRequirement by surgiboxSystem.batteryPack;
		satisfy SterilityRequirement by surgiboxSystem;
		satisfy SafetyRequirement by surgiboxSystem;
	}
}
