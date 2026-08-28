package 'Syringe Filter System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	package Definitions {
		item def LiquidSample {
			attribute volume : VolumeValue;
		}
		item def Filtrate {
			attribute volume : VolumeValue;
			attribute sterilityAssured : Boolean;
		}
		item def Retentate;

		attribute def PrepareSignal;
		attribute def StartFiltrationSignal;
		attribute def StopFiltrationSignal;
		attribute def DisposeSignal;

		part def Plunger {
			port forcePort {
				out appliedForce : ForceValue;
			}
		}

		part def SyringeBarrel {
			attribute capacity : VolumeValue;
			attribute currentVolume : VolumeValue;
			port forcePort {
				in appliedForce : ForceValue;
			}
			port liquidPort {
				out unfilteredLiquid : LiquidSample;
			}
		}

		part def FilterHousing {
			attribute material : String = "Polypropylene";
		}

		part def FilterMembrane {
			attribute poreSize : LengthValue = 0.22e-6[SI::m];
			attribute maxPressure : PressureValue = 500000[SI::Pa];
			attribute currentPressure : PressureValue = 0[SI::Pa];
			port inletPort {
				in unfilteredLiquid : LiquidSample;
			}
			port filtratePort {
				out filtrate : Filtrate;
			}
			port retentatePort {
				out retentate : Retentate;
			}
		}

		part def FilterUnit {
			part housing : FilterHousing;
			part membrane : FilterMembrane;
			port inletPort {
				in unfilteredLiquid : LiquidSample;
			}
			port filtratePort {
				out filtrate : Filtrate;
			}
			port retentatePort {
				out retentate : Retentate;
			}
			bind inletPort = membrane.inletPort;
			bind filtratePort = membrane.filtratePort;
			bind retentatePort = membrane.retentatePort;
		}

		part def CollectionVessel {
			attribute capacity : VolumeValue;
			attribute collectedVolume : VolumeValue = 0[SI::m^3];
			port liquidPort {
				in filtrate : Filtrate;
			}
		}

		action def AttachFilter {
			in syringeBarrel : SyringeBarrel;
			in filterUnit : FilterUnit;
		}
		action def FilterLiquid {
			in membrane : FilterMembrane;
			in unfiltered : LiquidSample;
			out filtrate : Filtrate;
			out retentate : Retentate;
		}
		action def DisposeFilterUnit {
			in filterUnit : FilterUnit;
		}

		part def SyringeFilterSystem {
			attribute isDisposed : Boolean = false;

			part plunger : Plunger;
			part barrel : SyringeBarrel;
			part filterUnit : FilterUnit;
			part vessel : CollectionVessel;

			flow forceFlow of ForceValue
				from plunger.forcePort.appliedForce to barrel.forcePort.appliedForce;
			flow unfilteredFlow of LiquidSample
				from barrel.liquidPort.unfilteredLiquid to filterUnit.inletPort.unfilteredLiquid;
			flow filteredFlow of Filtrate
				from filterUnit.filtratePort.filtrate to vessel.liquidPort.filtrate;

			exhibit state systemStates : SystemStates;
		}

		state def SystemStates {
			in system : SyringeFilterSystem;
			entry; then packaged;
			state packaged;
			accept PrepareSignal then prepared;
			state prepared {
				entry AttachFilter {
					in syringeBarrel = system.barrel;
					in filterUnit = system.filterUnit;
				}
			}
			accept StartFiltrationSignal then filtering;
			state filtering {
				do FilterLiquid {
					in membrane = system.filterUnit.membrane;
					in unfiltered = system.barrel.liquidPort.unfilteredLiquid;
				}
				accept when system.filterUnit.membrane.currentPressure > system.filterUnit.membrane.maxPressure
					then aborted;
				accept StopFiltrationSignal then completed;
			}
			state completed {
				entry DisposeFilterUnit {
					in filterUnit = system.filterUnit;
				}
				then disposed;
			}
			state aborted {
				entry DisposeFilterUnit {
					in filterUnit = system.filterUnit;
				}
				then disposed;
			}
			state disposed;
		}

		requirement def SterileFiltrationRequirement {
			doc /* The filtrate collected in the collection vessel shall be sterile and free of particles larger than the membrane pore size. */
			subject system : SyringeFilterSystem;
		}
		requirement def PoreSizeRequirement {
			doc /* The filter membrane shall have a nominal pore size of 0.22 micrometers. */
			subject membrane : FilterMembrane;
			require membrane.poreSize == 0.22e-6[SI::m];
		}
		requirement def PressureSafetyRequirement {
			doc /* Filtration shall be aborted if the applied pressure exceeds the membrane maximum safety pressure. */
			subject system : SyringeFilterSystem;
			require system.filterUnit.membrane.currentPressure <= system.filterUnit.membrane.maxPressure;
		}
		requirement def SingleUseRequirement {
			doc /* The filter unit shall be disposed of after a single filtration cycle. */
			subject system : SyringeFilterSystem;
			require system.isDisposed == true;
		}
	}

	package Usages {
		private import Definitions::*;

		part system : SyringeFilterSystem {
			part :>> plunger;
			part :>> barrel {
				:>> capacity = 0.00001[SI::m^3];
				:>> currentVolume = 0.00001[SI::m^3];
			}
			part :>> filterUnit {
				part :>> housing;
				part :>> membrane {
					:>> poreSize = 0.22e-6[SI::m];
					:>> maxPressure = 500000[SI::Pa];
					:>> currentPressure = 0[SI::Pa];
				}
			}
			part :>> vessel {
				:>> capacity = 0.000015[SI::m^3];
				:>> collectedVolume = 0[SI::m^3];
			}

			state :>> systemStates {
				in :>> system = system;
			}
		}

		verification sterilizationTest : SterileFiltrationRequirement {
			subject testSystem :> system;
		}
		verification poreSizeTest : PoreSizeRequirement {
			subject testMembrane :> system.filterUnit.membrane;
		}
		verification pressureSafetyTest : PressureSafetyRequirement {
			subject testSystem :> system;
		}
		verification singleUseTest : SingleUseRequirement {
			subject testSystem :> system;
		}
	}
}
