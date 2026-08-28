package 'Oil Refinery System' {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def Fluid;
		item def CrudeOil :> Fluid;
		item def AtmosphericResidue :> Fluid;
		item def VacuumGasOil :> Fluid;
		item def HighOctaneGasoline :> Fluid;
		item def Naphtha :> Fluid;
		item def PurifiedNaphtha :> Fluid;
		item def Diesel :> Fluid;
		item def PurifiedDiesel :> Fluid;
		item def Kerosene :> Fluid;
		item def Hydrogen :> Fluid;
		item def Sulfur;

		attribute def TemperatureValue :> Real;
		attribute def PressureValue :> Real;
		attribute def FlowRateValue :> Real;

		port def FluidInPort { in item fluid: Fluid; }
		port def FluidOutPort { out item fluid: Fluid; }
		port def HydrogenInPort { in item hydrogen: Hydrogen; }
		port def HydrogenOutPort { out item hydrogen: Hydrogen; }
		port def SulfurOutPort { out item sulfur: Sulfur; }
		port def SulfurInPort { in item sulfur: Sulfur; }

		attribute def 'Alarm Condition';
		attribute def 'Reset Signal';
		attribute def 'Emergency Shutdown';
		attribute def 'Dispense Signal';

		part def AtmosphericDistillationColumn {
			port crudeIn : FluidInPort;
			port naphthaOut : FluidOutPort;
			port keroseneOut : FluidOutPort;
			port dieselOut : FluidOutPort;
			port residueOut : FluidOutPort;
			perform action 'distill crude': 'Distill Crude';
		}

		part def VacuumDistillationColumn {
			port residueIn : FluidInPort;
			port vacGasOilOut : FluidOutPort;
			perform action 'distill residue': 'Distill Residue';
		}

		part def FCCUnit {
			port vacGasOilIn : FluidInPort;
			port gasolineOut : FluidOutPort;
			perform action 'crack vgo': 'Crack VGO';
		}

		part def Hydrotreater {
			port feedIn : FluidInPort;
			port hydrogenIn : HydrogenInPort;
			port purifiedOut : FluidOutPort;
			port sulfurOut : SulfurOutPort;
			perform action 'hydrotreat': 'Hydrotreat';
		}

		part def StorageTank {
			port fillPort : FluidInPort;
			port dispensePort : FluidOutPort;
			attribute tankLevel : Real;
			attribute maxCapacity : Real;
			attribute minCapacity : Real;
			exhibit state 'tank states' {
				entry; then filling;
				state filling;
				accept when tankLevel >= maxCapacity then full;
				state full;
				accept 'Dispense Signal' then operational;
				state operational;
				accept when tankLevel <= minCapacity then filling;
			}
		}

		part def HydrogenSource {
			port hydrogenOut : HydrogenOutPort;
		}

		part def SulfurCollector {
			port sulfurIn : SulfurInPort;
		}

		part def DistributedControlSystem {
			attribute processTemp : TemperatureValue;
			attribute processPressure : PressureValue;
			attribute processFlow : FlowRateValue;
			exhibit state 'dcs states' {
				entry; then normal;
				state normal;
				accept 'Alarm Condition' then alarm;
				state alarm;
				accept 'Reset Signal' then normal;
				accept 'Emergency Shutdown' then shutdown;
				state shutdown;
			}
		}

		part def SafetyInterlockSystem {
			ref dcs : DistributedControlSystem;
			attribute tripPoint : PressureValue;
			attribute processPressure : PressureValue;
			exhibit state 'sis states' {
				entry; then monitoring;
				state monitoring;
				accept when processPressure > tripPoint then 'emergency shutdown';
				state 'emergency shutdown' {
					do send new 'Emergency Shutdown'() to dcs;
				}
			}
		}

		part def OilRefinery {
			part crudeStorage : StorageTank;
			part atmColumn : AtmosphericDistillationColumn;
			part vacColumn : VacuumDistillationColumn;
			part fcc : FCCUnit;
			part naphthaHydrotreater : Hydrotreater;
			part dieselHydrotreater : Hydrotreater;
			part gasolineStorage : StorageTank;
			part dieselStorage : StorageTank;
			part keroseneStorage : StorageTank;
			part hydrogenSource : HydrogenSource;
			part sulfurCollector : SulfurCollector;
			part dcs : DistributedControlSystem;
			part sis : SafetyInterlockSystem;

			bind sis.dcs = dcs;

			connect crudeStorage.dispensePort to atmColumn.crudeIn;
			connect atmColumn.residueOut to vacColumn.residueIn;
			connect vacColumn.vacGasOilOut to fcc.vacGasOilIn;
			connect fcc.gasolineOut to gasolineStorage.fillPort;
			connect atmColumn.naphthaOut to naphthaHydrotreater.feedIn;
			connect naphthaHydrotreater.purifiedOut to gasolineStorage.fillPort;
			connect atmColumn.dieselOut to dieselHydrotreater.feedIn;
			connect dieselHydrotreater.purifiedOut to dieselStorage.fillPort;
			connect atmColumn.keroseneOut to keroseneStorage.fillPort;
			connect hydrogenSource.hydrogenOut to naphthaHydrotreater.hydrogenIn;
			connect hydrogenSource.hydrogenOut to dieselHydrotreater.hydrogenIn;
			connect naphthaHydrotreater.sulfurOut to sulfurCollector.sulfurIn;
			connect dieselHydrotreater.sulfurOut to sulfurCollector.sulfurIn;
		}

		action def 'Distill Crude';
		action def 'Distill Residue';
		action def 'Crack VGO';
		action def 'Hydrotreat';

		requirement def 'Refinery Safety Requirement' {
			subject refinery : OilRefinery;
			doc /* Ensure safe operation under all conditions */
		}

		requirement def 'Refine Crude Oil' {
			doc /* The refinery shall process raw crude oil and convert it into finished transportation fuels including gasoline, diesel, and kerosene. */
		}
	}

	package Usages {
		private import Definitions::*;

		part oilRefinery : OilRefinery;

		satisfy 'Refine Crude Oil' by oilRefinery;
		satisfy 'Refinery Safety Requirement' by oilRefinery;
	}
}
