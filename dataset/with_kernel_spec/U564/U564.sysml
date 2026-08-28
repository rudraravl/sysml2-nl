package 'Autonomous Solar-Powered Fluid Pumping System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Fluid;
		item def ElectricalPower;
		item def StartCommand;
		item def StopCommand;

		attribute def ChargeLevel;
		attribute def FluidLevel;

		port def FluidOutPort {
			out item fluid : Fluid;
		}
		port def FluidInPort {
			in item fluid : Fluid;
		}
		port def PowerOutPort {
			out item power : ElectricalPower;
		}
		port def PowerInPort {
			in item power : ElectricalPower;
		}
		port def ChargeLevelOutPort {
			out level : ChargeLevel;
		}
		port def ChargeLevelInPort {
			in level : ChargeLevel;
		}
		port def FluidLevelOutPort {
			out level : FluidLevel;
		}
		port def FluidLevelInPort {
			in level : FluidLevel;
		}
		port def CommandOutPort {
			out startCmd : StartCommand;
			out stopCmd : StopCommand;
		}
		port def CommandInPort {
			in startCmd : StartCommand;
			in stopCmd : StopCommand;
		}

		part def SolarPanelArray {
			port powerOut : PowerOutPort;
			attribute nominalPower : Real;
		}

		part def ChargeController {
			port solarIn : PowerInPort;
			port pumpPowerOut : PowerOutPort;
			port batteryPowerOut : PowerOutPort;
			port batteryChargeIn : ChargeLevelInPort;
		}

		part def BatteryBank {
			port chargeIn : PowerInPort;
			port supplyOut : PowerOutPort;
			port chargeLevelOut : ChargeLevelOutPort;
			attribute capacity : Real;
			attribute currentCharge : ChargeLevel;
		}

		part def PumpController {
			port batteryLevelIn : ChargeLevelInPort;
			port sourceLevelIn : FluidLevelInPort;
			port destLevelIn : FluidLevelInPort;
			port commandOut : CommandOutPort;
			attribute minBatteryLevel : ChargeLevel = 20.0;
			attribute minSourceLevel : FluidLevel = 10.0;
			attribute maxDestLevel : FluidLevel = 90.0;
		}

		part def CentrifugalPump {
			port powerIn : PowerInPort;
			port commandIn : CommandInPort;
			port fluidIn : FluidInPort;
			port fluidOut : FluidOutPort;
		}

		part def SourceReservoir {
			port fluidOut : FluidOutPort;
			port levelOut : FluidLevelOutPort;
			attribute capacity : Real;
			attribute currentLevel : FluidLevel;
		}

		part def DestinationTank {
			port fluidIn : FluidInPort;
			port levelOut : FluidLevelOutPort;
			attribute capacity : Real;
			attribute currentLevel : FluidLevel;
		}

		state def ChargeControllerStates;
		state def PumpControllerStates;
		state def PumpStates;

		action def TransferFluid {
			in inputFluid : Fluid;
			out outputFluid : Fluid;
		}

		action def SpinUp;
		action def SpinDown;

		action def MonitorLevels {
			in batteryLevel : ChargeLevel;
			in sourceLevel : FluidLevel;
			in destLevel : FluidLevel;
		}

		requirement def SolarAutonomy {
			doc /* The system shall be fully powered by solar energy without external grid connection. */
		}

		requirement def DryRunProtection {
			doc /* The pump shall not operate when the source reservoir level is below the minimum threshold. */
		}

		requirement def OverflowProtection {
			doc /* The pump shall not operate when the destination tank level exceeds the maximum safe level. */
		}

		requirement def BatteryProtection {
			doc /* The charge controller shall prevent battery overcharging by controlling charging current. */
		}

		requirement def LowBatteryCutoff {
			doc /* The pump controller shall prevent pump operation when battery charge is below minimum threshold. */
		}
	}

	package Usages {
		private import Definitions::*;

		part systemContext {
			satisfy SolarAutonomy;

			part solarArray : SolarPanelArray {
				attribute nominalPower = 5000.0;
			}

			flow of power : ElectricalPower
				from solarArray.powerOut.power to chargeController.solarIn.power;

			part chargeController : ChargeController {
				satisfy BatteryProtection;

				exhibit state controllerStates : ChargeControllerStates {
					entry; then direct;
					state direct;
					accept when batteryChargeIn.level < 100.0
						then charging;
					state charging;
					accept when batteryChargeIn.level >= 100.0
						then direct;
				}
			}

			flow of power : ElectricalPower
				from chargeController.batteryPowerOut.power to battery.chargeIn.power;
			flow of power : ElectricalPower
				from chargeController.pumpPowerOut.power to pump.powerIn.power;

			part battery : BatteryBank {
				attribute capacity = 10000.0;
				attribute currentCharge = 75.0;
				bind chargeLevelOut.level = currentCharge;
			}

			flow of level : ChargeLevel
				from battery.chargeLevelOut.level to chargeController.batteryChargeIn.level;
			flow of level : ChargeLevel
				from battery.chargeLevelOut.level to pumpController.batteryLevelIn.level;

			part pumpController : PumpController {
				satisfy DryRunProtection;
				satisfy OverflowProtection;
				satisfy LowBatteryCutoff;

				exhibit state controllerStates : PumpControllerStates {
					entry; then idle;
					state idle;
					accept when batteryLevelIn.level > minBatteryLevel
						and sourceLevelIn.level > minSourceLevel
						and destLevelIn.level < maxDestLevel
						do send new StartCommand() to commandOut
						then active;
					state active;
					accept when batteryLevelIn.level <= minBatteryLevel
						or sourceLevelIn.level <= minSourceLevel
						or destLevelIn.level >= maxDestLevel
						do send new StopCommand() to commandOut
						then idle;
				}
			}

			flow of level : FluidLevel
				from sourceReservoir.levelOut.level to pumpController.sourceLevelIn.level;
			flow of level : FluidLevel
				from destinationTank.levelOut.level to pumpController.destLevelIn.level;
			flow of startCmd : StartCommand
				from pumpController.commandOut.startCmd to pump.commandIn.startCmd;
			flow of stopCmd : StopCommand
				from pumpController.commandOut.stopCmd to pump.commandIn.stopCmd;

			part pump : CentrifugalPump {
				exhibit state pumpStates : PumpStates {
					entry; then off;
					state off;
					accept StartCommand
						then starting;
					state starting {
						entry action spinUp : SpinUp;
					}
					then running;
					state running {
						do action transferFluid : TransferFluid {
							in inputFluid = fluidIn.fluid;
							out outputFluid = fluidOut.fluid;
						}
					}
					accept StopCommand
						then stopping;
					state stopping {
						entry action spinDown : SpinDown;
					}
					then off;
				}
			}

			flow of fluid : Fluid
				from sourceReservoir.fluidOut.fluid to pump.fluidIn.fluid;
			flow of fluid : Fluid
				from pump.fluidOut.fluid to destinationTank.fluidIn.fluid;

			part sourceReservoir : SourceReservoir {
				attribute capacity = 1000.0;
				attribute currentLevel = 50.0;
				bind levelOut.level = currentLevel;
			}

			part destinationTank : DestinationTank {
				attribute capacity = 500.0;
				attribute currentLevel = 20.0;
				bind levelOut.level = currentLevel;
			}
		}
	}
}
