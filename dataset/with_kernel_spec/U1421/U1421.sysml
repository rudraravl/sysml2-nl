package 'Gasoline Engine System' {
	public import ISQ::*;
	public import ScalarValues::*;

	package Definitions {
		alias Torque for ISQ::TorqueValue;
		alias Pressure for ISQ::PressureValue;
		alias Voltage for ISQ::ElectricPotentialValue;

		item def Gasoline;
		item def Air;
		item def ExhaustGas;
		item def Spark;
		item def FuelAirMixture;

		attribute def ThrottlePosition :> Real;
		attribute def CompressionRatio :> Real;
		attribute def EngineStart;
		attribute def EngineStop;

		port def FuelInPort { in fuel : Gasoline; }
		port def FuelOutPort { out fuel : Gasoline; }
		port def AirInPort { in air : Air; }
		port def AirOutPort { out air : Air; }
		port def SparkInPort { in spark : Spark; }
		port def SparkOutPort { out spark : Spark; }
		port def ExhaustInPort { in exhaust : ExhaustGas; }
		port def ExhaustOutPort { out exhaust : ExhaustGas; }
		port def TorqueOutPort { out torque : Torque; }

		action def Intake {
			in fuel : Gasoline;
			in air : Air;
			out mixture : FuelAirMixture;
		}
		action def Compression {
			in mixture : FuelAirMixture;
			out compressedMixture : FuelAirMixture;
		}
		action def Power {
			in compressedMixture : FuelAirMixture;
			in spark : Spark;
			out torque : Torque;
			out exhaust : ExhaustGas;
		}
		action def Exhaust {
			in exhaust : ExhaustGas;
			out expelledExhaust : ExhaustGas;
		}

		action def FourStrokeCycle {
			in fuel : Gasoline;
			in air : Air;
			in spark : Spark;
			out torque : Torque;
			out exhaust : ExhaustGas;

			action intake: Intake {
				in fuel = FourStrokeCycle::fuel;
				in air = FourStrokeCycle::air;
			}
			flow intake.mixture to compression.mixture;
			action compression: Compression;
			flow compression.compressedMixture to power.compressedMixture;
			action power: Power {
				in spark = FourStrokeCycle::spark;
				out torque = FourStrokeCycle::torque;
			}
			flow power.exhaust to exhaust.exhaust;
			action exhaust: Exhaust {
				out expelledExhaust = FourStrokeCycle::exhaust;
			}
		}

		action def EngineControl {
			in fuel : Gasoline;
			in air : Air;
			in spark : Spark;
			out torque : Torque;
			out exhaust : ExhaustGas;

			first start;
			then merge continue;
			then action engineStarted accept engineStart : EngineStart;
			then action engineStopped accept engineStop : EngineStop;
			then continue;

			first engineStarted then 'four stroke cycle';
			first 'four stroke cycle' then engineStopped;

			action 'four stroke cycle' : FourStrokeCycle {
				in fuel = EngineControl::fuel;
				in air = EngineControl::air;
				in spark = EngineControl::spark;
				out torque = EngineControl::torque;
				out exhaust = EngineControl::exhaust;
			}
		}

		part def FuelTank {
			port fuelOutPort : FuelOutPort;
		}
		part def FuelPump {
			port fuelInPort : FuelInPort;
			port fuelOutPort : FuelOutPort;
			attribute fuelPressure : Pressure;
		}
		part def FuelInjector {
			port fuelInPort : FuelInPort;
			port fuelOutPort : FuelOutPort;
		}
		part def AirFilter {
			port airInPort : AirInPort;
			port airOutPort : AirOutPort;
		}
		part def Throttle {
			port airInPort : AirInPort;
			port airOutPort : AirOutPort;
			attribute throttlePosition : ThrottlePosition;
		}
		part def IgnitionSystem {
			port sparkOutPort : SparkOutPort;
		}
		part def Cylinder {
			port fuelInPort : FuelInPort;
			port airInPort : AirInPort;
			port sparkInPort : SparkInPort;
			port exhaustOutPort : ExhaustOutPort;
			port torqueOutPort : TorqueOutPort;
			attribute compressionRatio : CompressionRatio;

			perform cycle : FourStrokeCycle {
				in fuel = fuelInPort.fuel;
				in air = airInPort.air;
				in spark = sparkInPort.spark;
				out torque = torqueOutPort.torque;
				out exhaust = exhaustOutPort.exhaust;
			}
		}
		part def ExhaustManifold {
			port exhaustInPort : ExhaustInPort;
			port exhaustOutPort : ExhaustOutPort;
		}
		part def CatalyticConverter {
			port exhaustInPort : ExhaustInPort;
			port exhaustOutPort : ExhaustOutPort;
		}

		part def Engine {
			part fuelSystem {
				part tank : FuelTank;
				part pump : FuelPump {
					attribute :>> fuelPressure = 350000;
				}
				part injector1 : FuelInjector;
				part injector2 : FuelInjector;
				part injector3 : FuelInjector;
				part injector4 : FuelInjector;
			}
			part airIntakeSystem {
				part airFilter : AirFilter;
				part throttle : Throttle;
			}
			part ignitionSystem : IgnitionSystem;
			part cylinder1 : Cylinder { attribute :>> compressionRatio = 10.0; }
			part cylinder2 : Cylinder { attribute :>> compressionRatio = 10.0; }
			part cylinder3 : Cylinder { attribute :>> compressionRatio = 10.0; }
			part cylinder4 : Cylinder { attribute :>> compressionRatio = 10.0; }
			part exhaustSystem {
				part manifold : ExhaustManifold;
				part converter : CatalyticConverter;
			}

			flow fuelSystem.tank.fuelOutPort.fuel to fuelSystem.pump.fuelInPort.fuel;
			flow fuelSystem.pump.fuelOutPort.fuel to fuelSystem.injector1.fuelInPort.fuel;
			flow fuelSystem.pump.fuelOutPort.fuel to fuelSystem.injector2.fuelInPort.fuel;
			flow fuelSystem.pump.fuelOutPort.fuel to fuelSystem.injector3.fuelInPort.fuel;
			flow fuelSystem.pump.fuelOutPort.fuel to fuelSystem.injector4.fuelInPort.fuel;

			flow airIntakeSystem.airFilter.airOutPort.air to airIntakeSystem.throttle.airInPort.air;
			flow airIntakeSystem.throttle.airOutPort.air to cylinder1.airInPort.air;
			flow airIntakeSystem.throttle.airOutPort.air to cylinder2.airInPort.air;
			flow airIntakeSystem.throttle.airOutPort.air to cylinder3.airInPort.air;
			flow airIntakeSystem.throttle.airOutPort.air to cylinder4.airInPort.air;

			flow fuelSystem.injector1.fuelOutPort.fuel to cylinder1.fuelInPort.fuel;
			flow fuelSystem.injector2.fuelOutPort.fuel to cylinder2.fuelInPort.fuel;
			flow fuelSystem.injector3.fuelOutPort.fuel to cylinder3.fuelInPort.fuel;
			flow fuelSystem.injector4.fuelOutPort.fuel to cylinder4.fuelInPort.fuel;

			flow ignitionSystem.sparkOutPort.spark to cylinder1.sparkInPort.spark;
			flow ignitionSystem.sparkOutPort.spark to cylinder2.sparkInPort.spark;
			flow ignitionSystem.sparkOutPort.spark to cylinder3.sparkInPort.spark;
			flow ignitionSystem.sparkOutPort.spark to cylinder4.sparkInPort.spark;

			flow cylinder1.exhaustOutPort.exhaust to exhaustSystem.manifold.exhaustInPort.exhaust;
			flow cylinder2.exhaustOutPort.exhaust to exhaustSystem.manifold.exhaustInPort.exhaust;
			flow cylinder3.exhaustOutPort.exhaust to exhaustSystem.manifold.exhaustInPort.exhaust;
			flow cylinder4.exhaustOutPort.exhaust to exhaustSystem.manifold.exhaustInPort.exhaust;

			flow exhaustSystem.manifold.exhaustOutPort.exhaust to exhaustSystem.converter.exhaustInPort.exhaust;
		}

		requirement def CompressionRatioRequirement {
			doc /* The compression ratio of each cylinder shall be between 9:1 and 11:1. */
			attribute compressionRatio : CompressionRatio;
			constraint { compressionRatio >= 9.0 and compressionRatio <= 11.0 }
		}
		requirement def FuelPressureRequirement {
			doc /* The fuel pump shall deliver fuel at a pressure of 3 bar to 5 bar. */
			attribute fuelPressure : Pressure;
			constraint { fuelPressure >= 300000 and fuelPressure <= 500000 }
		}
		requirement def EmissionsControlRequirement {
			doc /* The catalytic converter shall reduce CO and NOx emissions to below legal limits. */
		}
	}

	package Usages {
		private import Definitions::*;

		part engine : Engine;

		requirement compRatioReq : CompressionRatioRequirement {
			attribute compressionRatio = engine.cylinder1.compressionRatio;
		}
		requirement fuelPressReq : FuelPressureRequirement {
			attribute fuelPressure = engine.fuelSystem.pump.fuelPressure;
		}
		requirement emissionsReq : EmissionsControlRequirement;
	}
}
