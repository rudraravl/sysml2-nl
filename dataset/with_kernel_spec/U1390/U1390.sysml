package 'Capillary Irrigation System' {
	private import ScalarValues::*;

	package Definitions {
		item def Water;
		item def Soil;
		item def Plant;

		port def WaterPort {
			out item water : Water;
		}

		part def Reservoir {
			attribute capacity : Real;
			attribute currentVolume : Real;
			port waterOutPort : WaterPort;
			item storedWater : Water;
		}

		part def CapillaryWick {
			port waterInPort : ~WaterPort;
			port waterOutPort : WaterPort;
			attribute length : Real;
			attribute porosity : Real;
			attribute saturation : Real;
		}

		part def PlantingBed {
			port waterInPort : ~WaterPort;
			attribute soilMoisture : Real;
			attribute targetMoisture : Real;
			item soil : Soil;
			item plants : Plant;
			item absorbedWater : Water;
		}

		action def PrimeWick {
			in w : CapillaryWick;
			in r : Reservoir;
			assign w.saturation := 1.0;
			assign r.currentVolume := r.currentVolume - 0.5;
		}

		action def WickWater {
			in w : CapillaryWick;
			in r : Reservoir;
			in b : PlantingBed;
			assign b.soilMoisture := b.soilMoisture + 0.01;
			assign r.currentVolume := r.currentVolume - 0.01;
			assign w.saturation := w.saturation - 0.01;
		}

		action def MaintainEquilibrium {
			in b : PlantingBed;
			in r : Reservoir;
			assign b.soilMoisture := b.soilMoisture - 0.001;
			assign r.currentVolume := r.currentVolume - 0.001;
		}

		action def NotifyRefill;

		attribute def RefillSignal;

		requirement def SelfWateringReq {
			doc /* The system shall automatically provide water to the planting bed without pumps, electronics, or external power. */
		}
		requirement def CapillaryActionReq {
			doc /* The wick shall transport water from the reservoir to the soil via capillary action. */
		}
		requirement def MoistureEquilibriumReq {
			doc /* The system shall maintain soil moisture at a stable level ideal for plant growth. */
		}
		requirement def DepletedStateReq {
			doc /* The system shall enter a depleted state and cease operation when the reservoir is empty, until manually refilled. */
		}
	}

	package Usages {
		private import Definitions::*;

		part system {
			part reservoir : Reservoir {
				attribute capacity := 10.0;
				attribute currentVolume := 10.0;
			}

			part wick : CapillaryWick {
				attribute length := 1.0;
				attribute porosity := 0.8;
				attribute saturation := 0.0;
			}

			part bed : PlantingBed {
				attribute soilMoisture := 0.1;
				attribute targetMoisture := 0.5;
			}

			flow of water : Water
				from reservoir.waterOutPort.water to wick.waterInPort.water;

			flow of water : Water
				from wick.waterOutPort.water to bed.waterInPort.water;

			action primeWick : PrimeWick {
				in w = wick;
				in r = reservoir;
			}
			action wickWater : WickWater {
				in w = wick;
				in r = reservoir;
				in b = bed;
			}
			action maintain : MaintainEquilibrium {
				in b = bed;
				in r = reservoir;
			}
			action alert : NotifyRefill;

			exhibit state irrigationStates {
				entry; then priming;

				state priming {
					do primeWick;
				}
				then wicking;

				state wicking {
					do wickWater;
				}
				accept when bed.soilMoisture >= bed.targetMoisture
					then equilibrium;
				accept when reservoir.currentVolume <= 0.0
					then depleted;

				state equilibrium {
					do maintain;
				}
				accept when bed.soilMoisture < bed.targetMoisture
					then wicking;
				accept when reservoir.currentVolume <= 0.0
					then depleted;

				state depleted {
					do alert;
				}
				accept RefillSignal
					then priming;
			}
		}

		requirement selfWateringReq : SelfWateringReq;
		requirement capillaryActionReq : CapillaryActionReq;
		requirement moistureEquilibriumReq : MoistureEquilibriumReq;
		requirement depletedStateReq : DepletedStateReq;

		satisfy selfWateringReq by system;
		satisfy capillaryActionReq by system.wick;
		satisfy moistureEquilibriumReq by system;
		satisfy depletedStateReq by system;
	}

	public import Usages::system;
}
