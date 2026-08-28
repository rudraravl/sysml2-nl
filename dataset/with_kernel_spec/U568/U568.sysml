package 'Submersible Pumping System' {
	private import ScalarValues::*;

	package Definitions {
		item def Fluid;

		attribute def HighLevelSignal;
		attribute def LowLevelSignal;
		attribute def StartCommand;
		attribute def StopCommand;
		attribute def FaultSignal;
		attribute def ResetCommand;

		port def FluidOutPort {
			out item fluid : Fluid;
		}
		port def FluidInPort {
			in item fluid : Fluid;
		}
		port def SensorSignalOutPort {
			out highLevel : HighLevelSignal;
			out lowLevel : LowLevelSignal;
		}
		port def ControlSignalInPort {
			in highLevel : HighLevelSignal;
			in lowLevel : LowLevelSignal;
		}
		port def ControlSignalOutPort {
			out startCmd : StartCommand;
			out stopCmd : StopCommand;
		}
		port def PumpControlInPort {
			in startCmd : StartCommand;
			in stopCmd : StopCommand;
		}

		part def Sump {
			attribute capacity : Real;
			attribute minSafeLevel : Real;
			attribute maxSafeLevel : Real;
			port fluidOutPort : FluidOutPort;
		}

		part def SubmersiblePump {
			attribute ratedPower : Real;
			attribute ratedFlowRate : Real;
			attribute ratedHead : Real;
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			port controlInPort : PumpControlInPort;
		}

		part def LevelSensor {
			attribute highSetpoint : Real;
			attribute lowSetpoint : Real;
			port signalOutPort : SensorSignalOutPort;
		}

		part def ControlPanel {
			attribute operatingMode : String;
			port sensorInPort : ControlSignalInPort;
			port pumpOutPort : ControlSignalOutPort;
		}

		part def DischargePipe {
			attribute material : String;
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
		}

		part def DischargePoint {
			attribute elevation : Real;
			port fluidInPort : FluidInPort;
		}

		action def PumpFluid {
			in fluidIn : Fluid;
			out fluidOut : Fluid;
		}

		action def SenseLevel {
			out level : Real;
		}

		requirement def MinFlowRateReq {
			doc
			/* The system shall maintain a minimum flow rate of 0.01 cubic meters per second. */
			subject flowRate : Real;
			constraint { flowRate >= 0.01 }
		}

		requirement def DischargeHeightReq {
			doc
			/* The pump shall achieve a discharge head of at least 10 meters. */
			subject dischargeHead : Real;
			constraint { dischargeHead >= 10 }
		}

		requirement def EfficiencyReq {
			doc
			/* The pump shall operate with a hydraulic efficiency of at least 80 percent. */
			subject efficiency : Real;
			constraint { efficiency >= 0.80 }
		}
	}

	package Usages {
		private import Definitions::*;

		part pumpingSystem {
			attribute operatingMode : String = "Automatic";

			part sump : Sump {
				attribute capacity = 2.0;
				attribute minSafeLevel = 0.2;
				attribute maxSafeLevel = 1.5;
			}

			part pump : SubmersiblePump {
				attribute ratedPower = 1500;
				attribute ratedFlowRate = 0.05;
				attribute ratedHead = 12;

				perform action pumpFluid : PumpFluid {
					in fluidIn = fluidInPort.fluid;
					out fluidOut = fluidOutPort.fluid;
				}

				exhibit state pumpStates {
					entry; then off;
					state off;
					accept StartCommand
						then starting;
					state starting;
					transition starting_to_running
						first starting
						then running;
					state running {
						do pumpFluid;
					}
					accept StopCommand
						then stopping;
					accept FaultSignal
						then alarm;
					state stopping;
					transition stopping_to_off
						first stopping
						then off;
					state alarm;
					accept ResetCommand
						then off;
				}
			}

			part levelSensor : LevelSensor {
				attribute highSetpoint = 1.2;
				attribute lowSetpoint = 0.3;

				perform action senseLevel : SenseLevel;

				exhibit state sensorStates {
					entry; then belowHigh;
					do senseLevel { out level; }
					state belowHigh;
					accept when senseLevel.level >= highSetpoint
						do send new HighLevelSignal() to controlPanel
						then aboveHigh;
					state aboveHigh;
					accept when senseLevel.level <= lowSetpoint
						do send new LowLevelSignal() to controlPanel
						then belowHigh;
				}
			}

			part controlPanel : ControlPanel {
				attribute operatingMode = "Automatic";

				exhibit state controlStates {
					entry; then idle;
					state idle;
					accept HighLevelSignal
						do send new StartCommand() to pump
						then pumping;
					state pumping;
					accept LowLevelSignal
						do send new StopCommand() to pump
						then idle;
				}
			}

			part dischargePipe : DischargePipe {
				attribute material = "Stainless Steel";
			}

			part dischargePoint : DischargePoint {
				attribute elevation = 12.0;
			}

			flow of fluid : Fluid
				from sump.fluidOutPort.fluid to pump.fluidInPort.fluid;
			flow of fluid : Fluid
				from pump.fluidOutPort.fluid to dischargePipe.fluidInPort.fluid;
			flow of fluid : Fluid
				from dischargePipe.fluidOutPort.fluid to dischargePoint.fluidInPort.fluid;

			interface sensorToControlPanel
				connect levelSensor.signalOutPort to controlPanel.sensorInPort {
					flow highLevelFlow of HighLevelSignal
						from levelSensor.signalOutPort.highLevel
						to controlPanel.sensorInPort.highLevel;
					flow lowLevelFlow of LowLevelSignal
						from levelSensor.signalOutPort.lowLevel
						to controlPanel.sensorInPort.lowLevel;
				}

			interface controlPanelToPump
				connect controlPanel.pumpOutPort to pump.controlInPort {
					flow startCmdFlow of StartCommand
						from controlPanel.pumpOutPort.startCmd
						to pump.controlInPort.startCmd;
					flow stopCmdFlow of StopCommand
						from controlPanel.pumpOutPort.stopCmd
						to pump.controlInPort.stopCmd;
				}

			requirement minFlowRateReq : MinFlowRateReq;
			requirement dischargeHeightReq : DischargeHeightReq;
			requirement efficiencyReq : EfficiencyReq;

			satisfy minFlowRateReq by pump.ratedFlowRate;
			satisfy dischargeHeightReq by pump.ratedHead;
			satisfy efficiencyReq by pump;
		}
	}
}
