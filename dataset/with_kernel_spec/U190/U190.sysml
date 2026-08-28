package 'Personal Cooling Vest System' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;

	package Definitions {
		// ---- Value types with units ----
		attribute def CelsiusUnit;
		attribute def LiterPerMinuteUnit;
		attribute def WattUnit;
		attribute def JoulePerSecondUnit;
		attribute def LiterUnit;
		attribute def WattHourUnit;

		value type Temperature :> Real {
			attribute unit : CelsiusUnit;
		}
		value type FlowRate :> Real {
			attribute unit : LiterPerMinuteUnit;
		}
		value type Power :> Real {
			attribute unit : WattUnit;
		}
		value type HeatFlux :> Real {
			attribute unit : JoulePerSecondUnit;
		}
		value type Volume :> Real {
			attribute unit : LiterUnit;
		}
		value type BatteryCapacity :> Real {
			attribute unit : WattHourUnit;
		}

		// ---- Item types ----
		item def CoolingFluid {
			attribute temperature : Temperature;
			attribute flowRate : FlowRate;
		}

		item def TemperatureReading {
			attribute value : Temperature;
		}

		item def ControlCommand {
			attribute activateCooling : Boolean;
			attribute pumpSpeed : FlowRate;
		}

		item def PowerFlow {
			attribute power : Power;
		}

		item def ThermalEnergy {
			attribute heat : HeatFlux;
		}

		// ---- Port definitions ----
		port def FluidOutPort {
			out item fluid : CoolingFluid;
		}

		port def FluidInPort :> ~FluidOutPort;

		port def TemperatureSignalPort {
			out item reading : TemperatureReading;
		}

		port def TemperatureReceivePort :> ~TemperatureSignalPort;

		port def ControlSignalPort {
			out item command : ControlCommand;
		}

		port def ControlReceivePort :> ~ControlSignalPort;

		port def PowerOutPort {
			out item power : PowerFlow;
		}

		port def PowerInPort :> ~PowerOutPort;

		port def HeatOutPort {
			out item heat : ThermalEnergy;
		}

		port def HeatInPort :> ~HeatOutPort;

		// ---- Part definitions ----
		part def BatteryPack {
			port powerPort : PowerOutPort;
			attribute capacity : BatteryCapacity;
			attribute currentCharge : BatteryCapacity;
			attribute outputVoltage : Real;
		}

		part def TemperatureSensor {
			port readingPort : TemperatureSignalPort;
			attribute sensedTemperature : Temperature;
			attribute accuracy : Real;
		}

		part def ControlUnit {
			port sensorPort : TemperatureReceivePort;
			port coolerCommandPort : ControlSignalPort;
			port pumpCommandPort : ControlSignalPort;
			port powerInPort : PowerInPort;
			attribute targetTemperature : Temperature;
			attribute currentTemperature : Temperature;
			attribute hysteresis : Temperature;
			attribute coolingActive : Boolean;

			state def ControlBehavior {
				state Monitoring {
					entry;
					transition from Monitoring to ActiveCooling
						when currentTemperature > targetTemperature + hysteresis;
				}
				state ActiveCooling {
					entry;
					transition from ActiveCooling to Monitoring
						when currentTemperature <= targetTemperature - hysteresis;
				}
			}
		}

		part def ThermoelectricCooler {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			port commandPort : ControlReceivePort;
			port powerInPort : PowerInPort;
			port wasteHeatPort : HeatOutPort;
			attribute coolingPower : Power;
			attribute efficiency : Real;
		}

		part def FluidPump {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			port commandPort : ControlReceivePort;
			port powerInPort : PowerInPort;
			attribute maxFlowRate : FlowRate;
		}

		part def Reservoir {
			port fluidOutPort : FluidOutPort;
			port fluidReturnPort : FluidInPort;
			attribute capacity : Volume;
			attribute fluidLevel : Volume;
			item storedFluid : CoolingFluid;
		}

		part def ThermalDistributionNetwork {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			port heatAbsorbedPort : HeatInPort;
			attribute channelLength : Real;
			attribute heatExchangeEfficiency : Real;
		}

		part def CoolingVestGarment {
			port fluidInPort : FluidInPort;
			port fluidOutPort : FluidOutPort;
			part thermalNetwork : ThermalDistributionNetwork;
		}

		part def Wearer {
			attribute bodyTemperature : Temperature;
			port bodyHeatPort : HeatOutPort;
		}

		part def AmbientEnvironment {
			port heatSinkPort : HeatInPort;
			attribute airTemperature : Temperature;
		}

		part def CoolingVestSystem {
			part battery : BatteryPack;
			part sensor : TemperatureSensor;
			part controller : ControlUnit;
			part cooler : ThermoelectricCooler;
			part pump : FluidPump;
			part reservoir : Reservoir;
			part vest : CoolingVestGarment;
			ref part wearer : Wearer;
			ref part environment : AmbientEnvironment;
		}
	}

	package Usages {
		part coolingVestSystem : CoolingVestSystem {
			// Battery powers the controller
			flow of power : PowerFlow
				from battery.powerPort.power to controller.powerInPort.power;

			// Battery powers the thermoelectric cooler
			flow of power : PowerFlow
				from battery.powerPort.power to cooler.powerInPort.power;

			// Battery powers the pump
			flow of power : PowerFlow
				from battery.powerPort.power to pump.powerInPort.power;

			// Sensor sends temperature reading to controller
			flow of reading : TemperatureReading
				from sensor.readingPort.reading to controller.sensorPort.reading;

			// Controller sends command to cooler
			flow of command : ControlCommand
				from controller.coolerCommandPort.command to cooler.commandPort.command;

			// Controller sends command to pump
			flow of command : ControlCommand
				from controller.pumpCommandPort.command to pump.commandPort.command;

			// Pump draws fluid from reservoir
			flow of fluid : CoolingFluid
				from reservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;

			// Pump pushes fluid through cooler
			flow of fluid : CoolingFluid
				from pump.fluidOutPort.fluid to cooler.fluidInPort.fluid;

			// Cooler chills fluid and sends to vest
			flow of fluid : CoolingFluid
				from cooler.fluidOutPort.fluid to vest.fluidInPort.fluid;

			// Vest thermal network absorbs heat, warmed fluid returns
			flow of fluid : CoolingFluid
				from vest.fluidOutPort.fluid to reservoir.fluidReturnPort.fluid;

			// Wearer's body heat absorbed by thermal distribution network
			flow of heat : ThermalEnergy
				from wearer.bodyHeatPort.heat to vest.thermalNetwork.heatAbsorbedPort.heat;

			// Cooler waste heat dissipated to ambient environment
			flow of heat : ThermalEnergy
				from cooler.wasteHeatPort.heat to environment.heatSinkPort.heat;

			part :>> battery : BatteryPack {
				attribute :>> capacity : BatteryCapacity = 100.0;
				attribute :>> currentCharge : BatteryCapacity = 100.0;
				attribute :>> outputVoltage : Real = 12.0;
			}

			part :>> sensor : TemperatureSensor {
				attribute :>> sensedTemperature : Temperature = 37.0;
				attribute :>> accuracy : Real = 0.5;
			}

			part :>> controller : ControlUnit {
				attribute :>> targetTemperature : Temperature = 37.0;
				attribute :>> currentTemperature : Temperature = 37.5;
				attribute :>> hysteresis : Temperature = 0.5;
				attribute :>> coolingActive : Boolean = false;
			}

			part :>> cooler : ThermoelectricCooler {
				attribute :>> coolingPower : Power = 50.0;
				attribute :>> efficiency : Real = 60.0;
			}

			part :>> pump : FluidPump {
				attribute :>> maxFlowRate : FlowRate = 2.0;
			}

			part :>> reservoir : Reservoir {
				attribute :>> capacity : Volume = 0.5;
				attribute :>> fluidLevel : Volume = 0.4;
			}

			part :>> vest : CoolingVestGarment {
				part :>> thermalNetwork : ThermalDistributionNetwork {
					attribute :>> channelLength : Real = 2.5;
					attribute :>> heatExchangeEfficiency : Real = 85.0;
				}
			}

			part :>> wearer : Wearer {
				attribute :>> bodyTemperature : Temperature = 37.5;
			}

			part :>> environment : AmbientEnvironment {
				attribute :>> airTemperature : Temperature = 25.0;
			}
		}
	}

	package Requirements {
		requirement def ThermalComfortRequirement {
			doc :> "The cooling vest system shall maintain the wearer's body temperature within a comfortable range.";
			attribute targetTemp : Temperature = 37.0;
			attribute maxTemp : Temperature = 38.0;
			attribute minTemp : Temperature = 36.0;
			assert wearer.bodyTemperature <= maxTemp and wearer.bodyTemperature >= minTemp;
		}

		requirement def ContinuousOperationRequirement {
			doc :> "The battery pack shall power the system for at least 4 hours of continuous operation.";
			attribute minDurationHours : Real = 4.0;
			assert battery.capacity >= 50.0;
		}

		requirement def CoolingCapacityRequirement {
			doc :> "The thermoelectric cooler shall remove at least 50 watts of heat from the cooling fluid.";
			attribute minCoolingPower : Power = 50.0;
			assert cooler.coolingPower >= minCoolingPower;
		}

		requirement def FlowRateRequirement {
			doc :> "The fluid pump shall maintain a flow rate of at least 1.5 liters per minute when active.";
			attribute minFlowRate : FlowRate = 1.5;
			assert pump.maxFlowRate >= minFlowRate;
		}

		requirement def ReservoirCapacityRequirement {
			doc :> "The reservoir shall hold sufficient cooling fluid for the entire cooling loop.";
			attribute minCapacity : Volume = 0.3;
			assert reservoir.capacity >= minCapacity;
		}

		requirement thermalComfortReq : ThermalComfortRequirement;
		requirement continuousOperationReq : ContinuousOperationRequirement;
		requirement coolingCapacityReq : CoolingCapacityRequirement;
		requirement flowRateReq : FlowRateRequirement;
		requirement reservoirCapacityReq : ReservoirCapacityRequirement;
	}
}
