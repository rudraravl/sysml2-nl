package 'Controlled Ember System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	public import Definitions::*;

	package Definitions {
		item def SolidFuel {
			attribute carbonContent : Real;
		}
		item def Oxygen;
		item def Exhaust;
		item def ThermalEnergy;

		attribute def IgniteSignal;
		attribute def ReviveSignal;

		port def FuelPort {
			out item fuel : SolidFuel;
		}
		port def AirPort {
			out item oxygen : Oxygen;
		}
		port def HeatPort {
			out item heat : ThermalEnergy;
		}
		port def ExhaustPort {
			out item exhaust : Exhaust;
		}

		part def FuelBed {
			port fuelOutPort : FuelPort;
			attribute fuelCapacity : MassValue;
			item fuel : SolidFuel {
				attribute mass : MassValue;
			}
		}
		part def CombustionCore {
			port fuelInPort : ~FuelPort;
			port airInPort : ~AirPort;
			port heatOutPort : HeatPort;
			port exhaustOutPort : ExhaustPort;
			attribute coreTemperature : TemperatureValue;
			attribute targetTemperature : TemperatureValue;
			attribute minFuelThreshold : MassValue;
			attribute fuelSpentThreshold : MassValue;
			attribute minOxygenFlow : Real;
		}
		part def AirSupplySystem {
			port airOutPort : AirPort;
			attribute airflowRate : Real;
			attribute maxAirflowRate : Real;
		}
		part def ThermalRadiator {
			port heatInPort : ~HeatPort;
			port exhaustInPort : ~ExhaustPort;
			attribute heatOutput : PowerValue;
			attribute radiatingEfficiency : Real;
		}

		action def Ignite;
		action def MonitorTemperature {
			out temp : TemperatureValue;
		}
		action def RegulateAirflow {
			in currentTemp : TemperatureValue;
			in targetTemp : TemperatureValue;
			out airflowCommand : Real;
		}
		action def TransferHeat {
			in heatInput : ThermalEnergy;
			out radiatedHeat : ThermalEnergy;
		}
		action def IncreaseAirSupply {
			out newAirflowRate : Real;
		}

		state def EmberStates;

		requirement def StableHeatOutput {
			doc /* The system shall provide stable radiant heat through flameless combustion of solid fuel. */
		}
		requirement def SelfRegulatingBurn {
			doc /* The system shall self-regulate airflow to maintain a stable glowing combustion state and attempt revival before extinguishing. */
		}
	}

	package Usages {
		private import Definitions::*;

		part 'ember system' {
			part fuelBed : FuelBed {
				attribute :>> fuelCapacity : MassValue = 5.0 [SI::kg];
				item :>> fuel {
					attribute :>> mass : MassValue = 2.0 [SI::kg];
				}
			}

			part combustionCore : CombustionCore {
				attribute :>> coreTemperature : TemperatureValue = 293.15 [SI::K];
				attribute :>> targetTemperature : TemperatureValue = 800.0 [SI::K];
				attribute :>> minFuelThreshold : MassValue = 0.2 [SI::kg];
				attribute :>> fuelSpentThreshold : MassValue = 0.001 [SI::kg];
				attribute :>> minOxygenFlow : Real = 0.002;
			}

			part airSupplySystem : AirSupplySystem {
				attribute :>> airflowRate : Real = 0.01;
				attribute :>> maxAirflowRate : Real = 0.05;
			}

			part thermalRadiator : ThermalRadiator {
				attribute :>> heatOutput : PowerValue = 500.0 [SI::W];
				attribute :>> radiatingEfficiency : Real = 0.85;
			}

			flow of fuel : SolidFuel
				from fuelBed.fuelOutPort.fuel to combustionCore.fuelInPort.fuel;

			flow of oxygen : Oxygen
				from airSupplySystem.airOutPort.oxygen to combustionCore.airInPort.oxygen;

			flow of heat : ThermalEnergy
				from combustionCore.heatOutPort.heat to thermalRadiator.heatInPort.heat;

			flow of exhaust : Exhaust
				from combustionCore.exhaustOutPort.exhaust to thermalRadiator.exhaustInPort.exhaust;

			perform action 'ignite' : Ignite;
			perform action 'monitor temperature' : MonitorTemperature {
				out temp = combustionCore.coreTemperature;
			}
			perform action 'regulate airflow' : RegulateAirflow {
				in currentTemp = combustionCore.coreTemperature;
				in targetTemp = combustionCore.targetTemperature;
				out airflowCommand = airSupplySystem.airflowRate;
			}
			perform action 'transfer heat' : TransferHeat {
				in heatInput = thermalRadiator.heatInPort.heat;
				out radiatedHeat;
			}
			perform action 'increase air supply' : IncreaseAirSupply {
				out newAirflowRate = airSupplySystem.airflowRate;
			}

			state 'ember states' : EmberStates {
				entry; then dormant;

				state dormant;
				accept IgniteSignal
					do 'ignite'
					then glowing;

				state glowing {
					entry 'monitor temperature';
					do 'regulate airflow';
				}
				accept when fuelBed.fuel.mass < combustionCore.minFuelThreshold
					then fading;
				accept when airSupplySystem.airflowRate < combustionCore.minOxygenFlow
					then fading;

				state fading;
				accept ReviveSignal
					do 'increase air supply'
					then glowing;
				accept when fuelBed.fuel.mass <= combustionCore.fuelSpentThreshold
					then extinguished;

				state extinguished;
			}
		}

		requirement 'stable heat output' : StableHeatOutput;
		requirement 'self regulating burn' : SelfRegulatingBurn;
	}
}
