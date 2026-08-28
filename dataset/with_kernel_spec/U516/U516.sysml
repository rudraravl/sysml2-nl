package 'Humphrey Pump Subsystem' {
	private import ScalarValues::Real;
	private import ScalarValues::Boolean;
	private import Definitions::*;
	private import Requirements::*;

	package Definitions {
		value type Pressure {
			unit 'Pa';
		}
		value type Volume {
			unit 'm^3';
		}
		value type Elevation {
			unit 'm';
		}
		value type FlowRate {
			unit 'm^3/s';
		}
		value type Energy {
			unit 'J';
		}
		value type Duration {
			unit 'ms';
		}
		value type Temperature {
			unit 'K';
		}

		item def Water;
		item def FuelAirMixture;
		item def ExhaustGas;
		item def SparkSignal;

		port def WaterPort {
			out item water : Water;
			attribute pressure : Pressure;
		}
		port def FuelMixturePort {
			out item mixture : FuelAirMixture;
			attribute pressure : Pressure;
		}
		port def ExhaustPort {
			out item exhaust : ExhaustGas;
			attribute temperature : Temperature;
		}
		port def SparkPort {
			out item spark : SparkSignal;
		}

		part def SourceReservoir {
			port waterOutPort : WaterPort;
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute elevation : Elevation;
		}

		part def DischargeTank {
			port waterInPort : ~WaterPort;
			attribute capacity : Volume;
			attribute currentLevel : Volume;
			attribute elevation : Elevation;
		}

		part def FuelSupplySystem {
			port mixtureOutPort : FuelMixturePort;
			attribute mixturePressure : Pressure;
			attribute flowRate : FlowRate;
		}

		part def Environment {
			port exhaustInPort : ~ExhaustPort;
		}

		part def CheckValve {
			port inletPort : ~WaterPort;
			port outletPort : WaterPort;
			attribute isOpen : Boolean;
		}

		part def IgnitionSystem {
			port sparkOutPort : SparkPort;
			attribute sparkEnergy : Energy;
			attribute timingAdvance : Duration;
		}

		part def CombustionChamber {
			port waterInletPort : ~WaterPort;
			port waterOutletPort : WaterPort;
			port fuelInletPort : ~FuelMixturePort;
			port exhaustOutletPort : ExhaustPort;
			port sparkInletPort : ~SparkPort;
			attribute chamberVolume : Volume;
			attribute chamberPressure : Pressure;
			attribute chamberTemperature : Temperature;
			attribute waterColumnLevel : Elevation;
			item waterColumn : Water {
				attribute volume : Volume;
			}
			item charge : FuelAirMixture;
			item exhaustGas : ExhaustGas;
		}

		action def IntakeAction {
			in item waterIn : Water;
			in item mixtureIn : FuelAirMixture;
			out item charge : FuelAirMixture;
			out item waterDrawn : Water;
		}

		action def IgnitionAction {
			in item charge : FuelAirMixture;
			in item spark : SparkSignal;
			out item exhaust : ExhaustGas;
			out attribute peakPressure : Pressure;
		}

		action def DischargeAction {
			in item waterColumn : Water;
			in attribute pressure : Pressure;
			out item waterOut : Water;
		}

		action def ExhaustAction {
			in item exhaustIn : ExhaustGas;
			out item exhaustOut : ExhaustGas;
			out attribute residualPressure : Pressure;
		}

		action def HumphreyPumpCycle {
			in item fuelIn : FuelAirMixture;
			in item waterIn : Water;
			in item spark : SparkSignal;
			out item waterOut : Water;
			out item exhaustOut : ExhaustGas;

			action intake : IntakeAction {
				in waterIn = waterIn;
				in mixtureIn = fuelIn;
			}
			then action ignition : IgnitionAction {
				in charge = intake.charge;
				in spark = spark;
			}
			then action discharge : DischargeAction {
				in waterColumn = intake.waterDrawn;
				in pressure = ignition.peakPressure;
				out waterOut = waterOut;
			}
			then action exhaust : ExhaustAction {
				in exhaustIn = ignition.exhaust;
				out exhaustOut = exhaustOut;
			}
			then intake;
		}

		part def HumphreyPump {
			port waterInPort : ~WaterPort;
			port waterOutPort : WaterPort;
			port fuelInPort : ~FuelMixturePort;
			port exhaustOutPort : ExhaustPort;

			attribute atmosphericPressure : Pressure = 101325 [Pa];
			attribute dischargeThreshold : Pressure = 500000 [Pa];
			attribute lowLevel : Elevation = 0.2 [m];
			attribute highLevel : Elevation = 0.8 [m];

			part combustionChamber : CombustionChamber;
			part ignitionSystem : IgnitionSystem;
			part inletValve : CheckValve;
			part outletValve : CheckValve;

			flow of water : Water
				from waterInPort.water to inletValve.inletPort.water;
			flow of water : Water
				from inletValve.outletPort.water to combustionChamber.waterInletPort.water;
			flow of water : Water
				from combustionChamber.waterOutletPort.water to outletValve.inletPort.water;
			flow of water : Water
				from outletValve.outletPort.water to waterOutPort.water;
			flow of mixture : FuelAirMixture
				from fuelInPort.mixture to combustionChamber.fuelInletPort.mixture;
			flow of spark : SparkSignal
				from ignitionSystem.sparkOutPort.spark to combustionChamber.sparkInletPort.spark;
			flow of exhaust : ExhaustGas
				from combustionChamber.exhaustOutletPort.exhaust to exhaustOutPort.exhaust;

			state pumpCycle {
				state Intake {
					/* Open inlet valve, close outlet valve; draw water and fresh fuel-air mixture */
				}
				state Ignition {
					/* Close all valves; fire spark to ignite trapped mixture */
				}
				state Discharge {
					/* Open outlet valve; combustion pressure forces water column to discharge tank */
				}
				state Exhaust {
					/* Close valves; water column oscillates back, expelling spent exhaust gases */
				}
				transition from Intake to Ignition;
				transition from Ignition to Discharge;
				transition from Discharge to Exhaust;
				transition from Exhaust to Intake;
			}

			perform action cycle : HumphreyPumpCycle {
				in fuelIn = fuelInPort.mixture;
				in waterIn = waterInPort.water;
				in spark = ignitionSystem.sparkOutPort.spark;
				out waterOut = waterOutPort.water;
				out exhaustOut = exhaustOutPort.exhaust;
			}
		}
	}

	package Usages {
		part humphreyPumpSubsystem {
			part sourceReservoir : SourceReservoir {
				attribute capacity = 1000 [m^3];
				attribute currentLevel = 800 [m^3];
				attribute elevation = 0 [m];
			}
			part fuelSupply : FuelSupplySystem {
				attribute mixturePressure = 200000 [Pa];
				attribute flowRate = 0.5 [m^3/s];
			}
			part pump : HumphreyPump;
			part dischargeTank : DischargeTank {
				attribute capacity = 500 [m^3];
				attribute currentLevel = 0 [m^3];
				attribute elevation = 30 [m];
			}
			part environment : Environment;

			flow of water : Water
				from sourceReservoir.waterOutPort.water to pump.waterInPort.water;
			flow of mixture : FuelAirMixture
				from fuelSupply.mixtureOutPort.mixture to pump.fuelInPort.mixture;
			flow of water : Water
				from pump.waterOutPort.water to dischargeTank.waterInPort.water;
			flow of exhaust : ExhaustGas
				from pump.exhaustOutPort.exhaust to environment.exhaustInPort.exhaust;
		}
	}

	package Requirements {
		requirement def NoMovingPartsRequirement {
			doc /* The Humphrey pump shall operate without pistons, crankshafts, or other major moving mechanical parts. */
			subject pump : HumphreyPump;
		}

		requirement def DirectCombustionRequirement {
			doc /* The system shall use the explosive force of a combusted fuel-air mixture to directly act on a column of water. */
			subject pump : HumphreyPump;
		}

		requirement def CyclicOperationRequirement {
			doc /* The pump shall operate in a continuous cycle comprising Intake, Ignition, Discharge, and Exhaust phases. */
			subject pump : HumphreyPump;
		}

		requirement def WaterLiftingRequirement {
			doc /* The pump shall lift water from the source reservoir to the elevated discharge tank. */
			subject pump : HumphreyPump;
			attribute sourceElevation : Elevation;
			attribute dischargeElevation : Elevation;
			constraint { dischargeElevation > sourceElevation }
		}

		requirement def FlowRateRequirement {
			doc /* The pump shall deliver a minimum flow rate of 0.5 cubic meters per second to the discharge tank. */
			subject pump : HumphreyPump;
			attribute requiredFlowRate : FlowRate = 0.5 [m^3/s];
		}
	}
}
