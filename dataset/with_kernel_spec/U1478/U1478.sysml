package 'Automated Fluid Transfer System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Liquid;

		attribute def PumpCommand {
			attribute powerLevel : Real [0..1];
		}
		attribute def ValveCommand {
			attribute position : Real [0..1];
		}
		attribute def StartSignal;
		attribute def StopSignal;
		attribute def ShutdownAlert {
			attribute reason : String;
		}

		port def LiquidPort {
			out item liquid : Liquid;
		}
		port def PumpCmdPort {
			in cmd : PumpCommand;
		}
		port def ValveCmdPort {
			in cmd : ValveCommand;
		}
		port def FlowReadingPort {
			out flowRate : VolumeFlowRateValue;
		}
		port def PressureReadingPort {
			out pressure : PressureValue;
		}
		port def LevelReadingPort {
			out level : Real [0..1];
		}
		port def AlertPort {
			out alert : ShutdownAlert;
		}

		part def SourceTank {
			port liquidOutPort : LiquidPort;
			port levelSensorPort : LevelReadingPort;
			attribute capacity : VolumeValue = 1000 [L];
			attribute lowLevelThreshold : Real = 0.10;
			item liquid : Liquid {
				attribute volume : VolumeValue;
			}
		}

		part def DestinationTank {
			port liquidInPort : ~LiquidPort;
			port levelSensorPort : LevelReadingPort;
			attribute capacity : VolumeValue = 1000 [L];
			attribute highLevelThreshold : Real = 0.90;
			item liquid : Liquid {
				attribute volume : VolumeValue;
			}
		}

		part def InletValve {
			port liquidInPort : ~LiquidPort;
			port liquidOutPort : LiquidPort;
			port cmdPort : ValveCmdPort;
			attribute position : Real [0..1] = 1.0;
		}

		part def DischargeValve {
			port liquidInPort : ~LiquidPort;
			port liquidOutPort : LiquidPort;
			port cmdPort : ValveCmdPort;
			attribute position : Real [0..1] = 1.0;
		}

		part def CheckValve {
			port liquidInPort : ~LiquidPort;
			port liquidOutPort : LiquidPort;
		}

		part def ElectricMotor {
			attribute ratedPower : PowerValue = 7.5 [kW];
			attribute currentPower : PowerValue;
		}

		part def Impeller {
			attribute rotationalSpeed : AngularVelocityValue;
		}

		part def Pump {
			port liquidInPort : ~LiquidPort;
			port liquidOutPort : LiquidPort;
			port cmdPort : PumpCmdPort;
			part motor : ElectricMotor;
			part impeller : Impeller;
			attribute targetFlowRate : VolumeFlowRateValue;
			attribute targetPressure : PressureValue;
		}

		part def FlowMeter {
			port liquidInPort : ~LiquidPort;
			port liquidOutPort : LiquidPort;
			port readingPort : FlowReadingPort;
		}

		part def PressureSensor {
			port liquidInPort : ~LiquidPort;
			port liquidOutPort : LiquidPort;
			port readingPort : PressureReadingPort;
		}

		part def Controller {
			port pumpCmdPort : ~PumpCmdPort;
			port dischargeValveCmdPort : ~ValveCmdPort;
			port inletValveCmdPort : ~ValveCmdPort;
			port flowReadingPort : ~FlowReadingPort;
			port pressureReadingPort : ~PressureReadingPort;
			port sourceLevelPort : ~LevelReadingPort;
			port destLevelPort : ~LevelReadingPort;
			port alertPort : AlertPort;

			attribute targetFlowRate : VolumeFlowRateValue = 50 [L/min];
			attribute targetPressure : PressureValue = 200 [kPa];
			attribute sourceLowThreshold : Real = 0.10;
			attribute destHighThreshold : Real = 0.90;
		}

		state def ControllerStates;

		action def InitializeSystem {
			out pumpCmd : PumpCommand;
			out valveCmd : ValveCommand;
		}

		action def ControlPump {
			in flowRate : VolumeFlowRateValue;
			in pressure : PressureValue;
			in targetFlow : VolumeFlowRateValue;
			in targetPressure : PressureValue;
			out pumpCmd : PumpCommand;
			out valveCmd : ValveCommand;
		}

		action def ShutdownPump {
			out pumpCmd : PumpCommand;
			out valveCmd : ValveCommand;
			out alert : ShutdownAlert;
		}

		requirement def PreventDryRun {
			doc /* The system shall automatically shut down the pump if the source tank level falls below 10%. */
		}

		requirement def PreventOverflow {
			doc /* The system shall automatically shut down the pump if the destination tank level exceeds 90%. */
		}

		requirement def MaintainFlowRate {
			doc /* The controller shall maintain the target flow rate by adjusting pump speed and discharge valve position. */
		}

		requirement def MaintainPressure {
			doc /* The controller shall maintain the target pressure by adjusting the discharge valve. */
		}

		requirement def MotorPowerSpec {
			doc /* The pump motor shall have a rated power of 7.5 kW. */
		}
	}

	package Usages {
		private import Definitions::*;

		part system {
			part sourceTank : SourceTank;
			part inletValve : InletValve;
			part pump : Pump;
			part dischargeValve : DischargeValve;
			part checkValve : CheckValve;
			part flowMeter : FlowMeter;
			part pressureSensor : PressureSensor;
			part destinationTank : DestinationTank;
			part controller : Controller;

			flow of liquid : Liquid
				from sourceTank.liquidOutPort.liquid to inletValve.liquidInPort.liquid;
			flow of liquid : Liquid
				from inletValve.liquidOutPort.liquid to pump.liquidInPort.liquid;
			flow of liquid : Liquid
				from pump.liquidOutPort.liquid to dischargeValve.liquidInPort.liquid;
			flow of liquid : Liquid
				from dischargeValve.liquidOutPort.liquid to checkValve.liquidInPort.liquid;
			flow of liquid : Liquid
				from checkValve.liquidOutPort.liquid to flowMeter.liquidInPort.liquid;
			flow of liquid : Liquid
				from flowMeter.liquidOutPort.liquid to pressureSensor.liquidInPort.liquid;
			flow of liquid : Liquid
				from pressureSensor.liquidOutPort.liquid to destinationTank.liquidInPort.liquid;

			flow of flowRate : VolumeFlowRateValue
				from flowMeter.readingPort.flowRate to controller.flowReadingPort.flowRate;
			flow of pressure : PressureValue
				from pressureSensor.readingPort.pressure to controller.pressureReadingPort.pressure;
			flow of level : Real
				from sourceTank.levelSensorPort.level to controller.sourceLevelPort.level;
			flow of level : Real
				from destinationTank.levelSensorPort.level to controller.destLevelPort.level;

			flow of pumpCmd : PumpCommand
				from controller.pumpCmdPort.cmd to pump.cmdPort.cmd;
			flow of valveCmd : ValveCommand
				from controller.dischargeValveCmdPort.cmd to dischargeValve.cmdPort.cmd;
			flow of valveCmd : ValveCommand
				from controller.inletValveCmdPort.cmd to inletValve.cmdPort.cmd;

			state controllerStates : ControllerStates {
				entry; then idle;

				state idle;
				accept StartSignal
					then starting;

				state starting {
					entry action initialize : InitializeSystem {
						out pumpCmd = controller.pumpCmdPort.cmd;
						out valveCmd = controller.dischargeValveCmdPort.cmd;
					}
				}
				then running;

				state running {
					do action controlLoop : ControlPump {
						in flowRate = controller.flowReadingPort.flowRate;
						in pressure = controller.pressureReadingPort.pressure;
						in targetFlow = controller.targetFlowRate;
						in targetPressure = controller.targetPressure;
						out pumpCmd = controller.pumpCmdPort.cmd;
						out valveCmd = controller.dischargeValveCmdPort.cmd;
					}
				}

				accept when controller.sourceLevelPort.level < controller.sourceLowThreshold
					do action shutdownDry : ShutdownPump {
						out pumpCmd = controller.pumpCmdPort.cmd;
						out valveCmd = controller.dischargeValveCmdPort.cmd;
						out alert = controller.alertPort.alert;
					}
					then shutdown;

				accept when controller.destLevelPort.level > controller.destHighThreshold
					do action shutdownOverflow : ShutdownPump {
						out pumpCmd = controller.pumpCmdPort.cmd;
						out valveCmd = controller.dischargeValveCmdPort.cmd;
						out alert = controller.alertPort.alert;
					}
					then shutdown;

				accept StopSignal
					then shutdown;

				state shutdown {
					entry action stopPump : ShutdownPump {
						out pumpCmd = controller.pumpCmdPort.cmd;
						out valveCmd = controller.dischargeValveCmdPort.cmd;
						out alert = controller.alertPort.alert;
					}
				}
				accept StartSignal
					then idle;
			}

			requirement r1 : PreventDryRun;
			requirement r2 : PreventOverflow;
			requirement r3 : MaintainFlowRate;
			requirement r4 : MaintainPressure;
			requirement r5 : MotorPowerSpec;

			satisfy r1 by controller;
			satisfy r2 by controller;
			satisfy r3 by controller;
			satisfy r4 by controller;
			satisfy r5 by pump.motor;
		}
	}
}
