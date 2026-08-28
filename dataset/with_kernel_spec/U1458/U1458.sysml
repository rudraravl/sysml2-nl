package OffshoreOilProductionPlatform {
	private import ScalarValues::*;
	private import ISQ::*;

	package Definitions {
		item def RawFluid;
		item def CrudeOil;
		item def NaturalGas;
		item def ProducedWater;
		item def ElectricalPower;

		attribute def HazardSignal {
			attribute severity : Real;
		}
		attribute def ClearSignal;
		attribute def ResetSignal;

		port def FluidOutPort {
			out item fluid : RawFluid;
		}
		port def OilOutPort {
			out item oil : CrudeOil;
		}
		port def GasOutPort {
			out item gas : NaturalGas;
		}
		port def WaterOutPort {
			out item water : ProducedWater;
		}
		port def PowerOutPort {
			out item power : ElectricalPower;
		}

		action def ExtractFluid {
			out fluidOut : RawFluid;
		}
		action def SeparateFluid {
			in fluidIn : RawFluid;
			out oilOut : CrudeOil;
			out gasOut : NaturalGas;
			out waterOut : ProducedWater;
		}
		action def TreatOil {
			in oilIn : CrudeOil;
			out oilOut : CrudeOil;
		}
		action def CompressGas {
			in gasIn : NaturalGas;
			out gasOut : NaturalGas;
		}
		action def TreatWater {
			in waterIn : ProducedWater;
			out waterOut : ProducedWater;
		}
		action def GeneratePower {
			in gasIn : NaturalGas;
			out powerOut : ElectricalPower;
		}
		action def StoreOil {
			in oilIn : CrudeOil;
		}
		action def ExportOil {
			in oilIn : CrudeOil;
		}
		action def AutomateProduction;
		action def MonitorHazards;
		action def EmergencyShutdown;

		part def SubseaWell {
			port fluidOutPort : FluidOutPort;
			attribute flowRate :> ISQ::volumeFlowRate;
			perform action extractFluid : ExtractFluid {
				out fluidOut = fluidOutPort.fluid;
			}
		}
		part def SubseaManifold {
			port fluidInPort [6] : ~FluidOutPort;
			port fluidOutPort : FluidOutPort;
		}
		part def Riser {
			port fluidInPort : ~FluidOutPort;
			port fluidOutPort : FluidOutPort;
			attribute length :> ISQ::length;
		}
		part def SeparationSystem {
			port fluidInPort : ~FluidOutPort;
			port oilOutPort : OilOutPort;
			port gasOutPort : GasOutPort;
			port waterOutPort : WaterOutPort;
			perform action separateFluid : SeparateFluid {
				in fluidIn = fluidInPort.fluid;
				out oilOut = oilOutPort.oil;
				out gasOut = gasOutPort.gas;
				out waterOut = waterOutPort.water;
			}
		}
		part def OilTreatmentSystem {
			port oilInPort : ~OilOutPort;
			port oilOutPort : OilOutPort;
			perform action treatOil : TreatOil {
				in oilIn = oilInPort.oil;
				out oilOut = oilOutPort.oil;
			}
		}
		part def GasCompressionSystem {
			port gasInPort : ~GasOutPort;
			port gasOutPort : GasOutPort;
			attribute dischargePressure :> ISQ::pressure;
			perform action compressGas : CompressGas {
				in gasIn = gasInPort.gas;
				out gasOut = gasOutPort.gas;
			}
		}
		part def WaterTreatmentSystem {
			port waterInPort : ~WaterOutPort;
			port waterOutPort : WaterOutPort;
			perform action treatWater : TreatWater {
				in waterIn = waterInPort.water;
				out waterOut = waterOutPort.water;
			}
		}
		part def PowerGenerationSystem {
			port gasInPort : ~GasOutPort;
			port powerOutPort : PowerOutPort;
			attribute ratedPower :> ISQ::power;
			perform action generatePower : GeneratePower {
				in gasIn = gasInPort.gas;
				out powerOut = powerOutPort.power;
			}
		}
		part def StorageTank {
			port oilInPort : ~OilOutPort;
			port oilOutPort : OilOutPort;
			attribute capacity :> ISQ::volume;
			attribute currentVolume :> ISQ::volume;
			item storedOil : CrudeOil;
			perform action storeOil : StoreOil {
				in oilIn = oilInPort.oil;
			}
			constraint { currentVolume <= capacity }
		}
		part def ExportSystem {
			port oilInPort : ~OilOutPort;
			port oilOutPort : OilOutPort;
			perform action exportOil : ExportOil {
				in oilIn = oilInPort.oil;
			}
		}
		part def ExportDestination {
			port oilInPort : ~OilOutPort;
		}
		part def DisposalPoint {
			port waterInPort : ~WaterOutPort;
		}
		part def CentralControlSystem {
			port powerInPort : ~PowerOutPort;
			perform action automateProduction : AutomateProduction;
		}
		part def SafetySystem {
			perform action monitorHazards : MonitorHazards;
			perform action emergencyShutdown : EmergencyShutdown;
			exhibit state safetyStates {
				entry; then normal;
				state normal {
					do monitorHazards;
				}
				state warning;
				state emergency {
					entry emergencyShutdown;
				}
				transition normal_to_warning
					first normal
					accept hazard : HazardSignal
					if hazard.severity > 0.5
					then warning;
				transition warning_to_emergency
					first warning
					accept hazard : HazardSignal
					if hazard.severity > 0.9
					then emergency;
				transition warning_to_normal
					first warning
					accept ClearSignal
					then normal;
				transition emergency_to_normal
					first emergency
					accept ResetSignal
					then normal;
			}
		}
		part def OffshorePlatform;

		requirement def ProductionCapacity {
			doc /* The platform shall process a minimum of 50,000 barrels of oil equivalent per day. */
			attribute targetRate :> ISQ::volumeFlowRate;
		}
		requirement def SafetyResponseTime {
			doc /* The safety system shall initiate emergency shutdown within 2 seconds of detecting a critical hazard. */
			attribute maxResponseTime :> ISQ::time;
		}
		requirement def PowerSelfSufficiency {
			doc /* The power generation system shall supply 100% of the platform's electrical demand using processed natural gas. */
		}
		requirement def EnvironmentalCompliance {
			doc /* Produced water discharge shall meet regulatory oil-in-water concentration limits. */
			attribute maxOilConcentration : Real;
		}
	}

	package Usages {
		private import Definitions::*;

		part platform : OffshorePlatform {
			part wells [6] : SubseaWell;
			part manifold : SubseaManifold;
			part riser : Riser;
			part separationSystem : SeparationSystem;
			part oilTreatment : OilTreatmentSystem;
			part gasCompression : GasCompressionSystem;
			part waterTreatment : WaterTreatmentSystem;
			part powerGen : PowerGenerationSystem;
			part storageTank : StorageTank;
			part exportSystem : ExportSystem;
			part exportDest : ExportDestination;
			part disposal : DisposalPoint;
			part controlSystem : CentralControlSystem;
			part safetySystem : SafetySystem;

			flow of rawFluid : RawFluid
				from wells.fluidOutPort.fluid to manifold.fluidInPort.fluid;
			flow of rawFluid : RawFluid
				from manifold.fluidOutPort.fluid to riser.fluidInPort.fluid;
			flow of rawFluid : RawFluid
				from riser.fluidOutPort.fluid to separationSystem.fluidInPort.fluid;

			flow of oil : CrudeOil
				from separationSystem.oilOutPort.oil to oilTreatment.oilInPort.oil;
			flow of gas : NaturalGas
				from separationSystem.gasOutPort.gas to gasCompression.gasInPort.gas;
			flow of water : ProducedWater
				from separationSystem.waterOutPort.water to waterTreatment.waterInPort.water;

			flow of oil : CrudeOil
				from oilTreatment.oilOutPort.oil to storageTank.oilInPort.oil;
			flow of gas : NaturalGas
				from gasCompression.gasOutPort.gas to powerGen.gasInPort.gas;
			flow of water : ProducedWater
				from waterTreatment.waterOutPort.water to disposal.waterInPort.water;

			flow of oil : CrudeOil
				from storageTank.oilOutPort.oil to exportSystem.oilInPort.oil;
			flow of oil : CrudeOil
				from exportSystem.oilOutPort.oil to exportDest.oilInPort.oil;

			flow of power : ElectricalPower
				from powerGen.powerOutPort.power to controlSystem.powerInPort.power;

			requirement productionCapacity : ProductionCapacity;
			requirement safetyResponse : SafetyResponseTime;
			requirement powerSelfSufficiency : PowerSelfSufficiency;
			requirement environmentalCompliance : EnvironmentalCompliance;

			satisfy productionCapacity by separationSystem;
			satisfy productionCapacity by oilTreatment;
			satisfy productionCapacity by exportSystem;
			satisfy safetyResponse by safetySystem;
			satisfy powerSelfSufficiency by powerGen;
			satisfy environmentalCompliance by waterTreatment;
		}
	}
}
