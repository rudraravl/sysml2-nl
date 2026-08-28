package TGuardSystem {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def TempReading {
			attribute value : ISQ::TemperatureValue;
		}
		item def PressureReading {
			attribute value : ISQ::PressureValue;
		}
		item def ValveCommand {
			attribute position : Real;
		}

		attribute def 'Reset';

		port def TempOutputPort {
			out temp : TempReading;
		}
		port def PressureOutputPort {
			out pressure : PressureReading;
		}
		port def ControllerTempInputPort {
			in temp : TempReading;
		}
		port def ControllerPressureInputPort {
			in pressure : PressureReading;
		}
		port def ControllerValveOutputPort {
			out cmd : ValveCommand;
		}
		port def ValveInputPort {
			in cmd : ValveCommand;
		}

		action def SenseTemp {
			out temp : TempReading;
		}
		action def SensePressure {
			out pressure : PressureReading;
		}
		action def AdjustFlow {
			in cmd : ValveCommand;
		}

		state def ControllerStates;

		part def TemperatureSensor {
			port tempPort : TempOutputPort;
			perform action senseTemp : SenseTemp;
		}

		part def PressureSensor {
			port pressurePort : PressureOutputPort;
			perform action sensePressure : SensePressure;
		}

		part def ControlValve {
			port cmdPort : ValveInputPort;
			perform action adjustFlow : AdjustFlow;
		}

		part def ProtectionController {
			port tempPort : ControllerTempInputPort;
			port pressurePort : ControllerPressureInputPort;
			port valveCmdPort : ControllerValveOutputPort;

			attribute maxTemp : ISQ::TemperatureValue = 350 [K];
			attribute criticalTemp : ISQ::TemperatureValue = 400 [K];
			attribute emergencyTemp : ISQ::TemperatureValue = 450 [K];
			attribute maxPressure : ISQ::PressureValue = 0.5 [MPa];
			attribute criticalPressure : ISQ::PressureValue = 0.6 [MPa];
			attribute emergencyPressure : ISQ::PressureValue = 0.7 [MPa];

			exhibit state controllerStates : ControllerStates;
		}

		requirement def MaxTemperatureRequirement {
			doc /* The fluid temperature shall remain below the defined maximum safety limit. */
			attribute limit : ISQ::TemperatureValue;
		}
		requirement def MaxPressureRequirement {
			doc /* The fluid pressure shall remain below the defined maximum safety limit. */
			attribute limit : ISQ::PressureValue;
		}
		requirement def AutonomousShutdownRequirement {
			doc /* The TGuard system shall autonomously close the control valve when an emergency condition is detected. */
		}
		requirement def ContinuousMonitoringRequirement {
			doc /* The TGuard system shall continuously monitor temperature and pressure in real-time. */
		}
	}

	import Definitions::*;

	package Usages {
		private import Definitions::*;

		part tguardSystem {
			part tempSensor : TemperatureSensor;
			part pressureSensor : PressureSensor;
			part controlValve : ControlValve;
			part controller : ProtectionController {
				state controllerStates : ControllerStates {
					entry; then normal;

					state normal {
						entry do send new ValveCommand(position = 1.0) to valveCmdPort;
					}
					accept when tempPort.temp.value > maxTemp * 0.8
						or pressurePort.pressure.value > maxPressure * 0.8
						then elevated;

					state elevated {
						entry do send new ValveCommand(position = 0.5) to valveCmdPort;
					}
					accept when tempPort.temp.value > criticalTemp
						or pressurePort.pressure.value > criticalPressure
						then critical;
					accept when tempPort.temp.value <= maxTemp * 0.8
						and pressurePort.pressure.value <= maxPressure * 0.8
						then normal;

					state critical {
						entry do send new ValveCommand(position = 0.25) to valveCmdPort;
					}
					accept when tempPort.temp.value > emergencyTemp
						or pressurePort.pressure.value > emergencyPressure
						then emergency;
					accept when tempPort.temp.value <= criticalTemp
						and pressurePort.pressure.value <= criticalPressure
						then elevated;

					state emergency {
						entry do send new ValveCommand(position = 0.0) to valveCmdPort;
					}
					accept 'Reset'
						then normal;
				}
			}

			flow tempFlow of TempReading
				from tempSensor.tempPort.temp
				to controller.tempPort.temp;
			flow pressureFlow of PressureReading
				from pressureSensor.pressurePort.pressure
				to controller.pressurePort.pressure;
			flow cmdFlow of ValveCommand
				from controller.valveCmdPort.cmd
				to controlValve.cmdPort.cmd;
		}

		action senseTemp : SenseTemp;
		action sensePressure : SensePressure;
		action adjustFlow : AdjustFlow;

		requirement maxTempReq : MaxTemperatureRequirement {
			attribute limit = 350 [K];
		}
		requirement maxPressureReq : MaxPressureRequirement {
			attribute limit = 0.5 [MPa];
		}
		requirement autoShutdownReq : AutonomousShutdownRequirement;
		requirement continuousMonitoringReq : ContinuousMonitoringRequirement;
	}
}
