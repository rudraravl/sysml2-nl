package MunicipalWaterSupplyNetwork {
	private import ScalarValues::*;
	private import SI::*;

	package Definitions {
		item def Water;
		item def RawWater :> Water;
		item def PotableWater :> Water;
		item def Chemical;
		item def Coagulant :> Chemical;
		item def Chlorine :> Chemical;

		port def WaterInPort {
			in item water : Water;
		}
		port def WaterOutPort {
			out item water : Water;
		}
		port def BidirectionalWaterPort {
			inout item water : Water;
		}

		action def PumpWater {
			in inflow : Water;
			out outflow : Water;
		}

		action def MonitorWater {
			in sample : Water;
			out passed : Boolean;
		}

		part def Reservoir {
			attribute capacity : Real = 5000000 [SI::m**3];
			attribute currentLevel : Real = 3000000 [SI::m**3];
			port waterOut : WaterOutPort;
			item storedWater : RawWater;
		}

		part def Pump {
			attribute flowCapacity : Real = 0.5 [SI::m**3 / SI::s];
			attribute isOperational : Boolean = true;
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			perform action pumpWater : PumpWater {
				in inflow = waterIn.water;
				out outflow = waterOut.water;
			}
		}

		part def IntakePumpStation {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			part primaryPump : Pump {
				:>> flowCapacity = 0.5 [SI::m**3 / SI::s];
			}
			part standbyPump : Pump {
				:>> flowCapacity = 0.5 [SI::m**3 / SI::s];
				:>> isOperational = false;
			}
			flow of water : Water from waterIn.water to primaryPump.waterIn.water;
			flow of water : Water from primaryPump.waterOut.water to waterOut.water;
			flow of water : Water from waterIn.water to standbyPump.waterIn.water;
			flow of water : Water from standbyPump.waterOut.water to waterOut.water;
			state machine pumpStationOperation {
				state NormalOperation;
				state StandbyOperation;
				transition from NormalOperation to StandbyOperation
					when primaryPump.isOperational == false;
				transition from StandbyOperation to NormalOperation
					when primaryPump.isOperational == true;
			}
		}

		part def CoagulationUnit {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute coagulantDose : Real = 0.03 [SI::kg / SI::m**3];
			perform action addCoagulant {
				in inflow = waterIn.water;
				out outflow = waterOut.water;
			}
		}

		part def SedimentationBasin {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute retentionTime : Real = 14400 [SI::s];
			perform action settle {
				in inflow = waterIn.water;
				out outflow = waterOut.water;
			}
		}

		part def FiltrationSystem {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute filterMedia : String = "sand_anthracite";
			perform action filterWater {
				in inflow = waterIn.water;
				out outflow = waterOut.water;
			}
		}

		part def DisinfectionUnit {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute chlorineDose : Real = 0.002 [SI::kg / SI::m**3];
			attribute contactTime : Real = 1800 [SI::s];
			perform action disinfect {
				in inflow = waterIn.water;
				out outflow = waterOut.water;
			}
		}

		part def WaterQualityMonitor {
			port sampleIn : WaterInPort;
			attribute turbidity : Real;
			attribute chlorineResidual : Real;
			attribute qualityPassed : Boolean = true;
			attribute turbidityThreshold : Real = 0.3;
			attribute chlorineResidualMin : Real = 0.2;
			attribute chlorineResidualMax : Real = 4.0;
			perform action monitorWater : MonitorWater {
				in sample = sampleIn.water;
				out passed = qualityPassed;
			}
		}

		part def TreatmentPlant {
			port rawWaterIn : WaterInPort;
			port treatedWaterOut : WaterOutPort;
			port recycleOut : WaterOutPort;
			part coagulation : CoagulationUnit;
			part sedimentation : SedimentationBasin;
			part filtration : FiltrationSystem;
			part disinfection : DisinfectionUnit;
			part qualityMonitor : WaterQualityMonitor;
			flow of water : Water from rawWaterIn.water to coagulation.waterIn.water;
			flow of water : Water from coagulation.waterOut.water to sedimentation.waterIn.water;
			flow of water : Water from sedimentation.waterOut.water to filtration.waterIn.water;
			flow of water : Water from filtration.waterOut.water to disinfection.waterIn.water;
			flow of water : Water from disinfection.waterOut.water to treatedWaterOut.water;
			flow of water : Water from disinfection.waterOut.water to qualityMonitor.sampleIn.water;
			flow of water : Water from disinfection.waterOut.water to recycleOut.water;
			state machine treatmentOperation {
				state Treating;
				state Recycling;
				transition from Treating to Recycling
					when qualityMonitor.qualityPassed == false;
				transition from Recycling to Treating
					when qualityMonitor.qualityPassed == true;
			}
		}

		part def ClearWell {
			attribute capacity : Real = 2000 [SI::m**3];
			attribute emergencyReserve : Real = 500 [SI::m**3];
			attribute currentLevel : Real = 1500 [SI::m**3];
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			item storedWater : PotableWater;
		}

		part def HighServicePumpStation {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute currentDemand : Real = 0.4 [SI::m**3 / SI::s];
			attribute lowDemandThreshold : Real = 0.3 [SI::m**3 / SI::s];
			attribute moderateDemandThreshold : Real = 0.8 [SI::m**3 / SI::s];
			part pumps : Pump[1..4];
			flow of water : Water from waterIn.water to pumps.waterIn.water;
			flow of water : Water from pumps.waterOut.water to waterOut.water;
			state machine demandResponse {
				state LowDemand;
				state ModerateDemand;
				state PeakDemand;
				transition from LowDemand to ModerateDemand
					when currentDemand > lowDemandThreshold;
				transition from ModerateDemand to PeakDemand
					when currentDemand > moderateDemandThreshold;
				transition from PeakDemand to ModerateDemand
					when currentDemand < moderateDemandThreshold;
				transition from ModerateDemand to LowDemand
					when currentDemand < lowDemandThreshold;
			}
		}

		part def TransmissionPipeline {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute diameter : Real = 1.2 [SI::m];
			attribute length : Real = 15000 [SI::m];
		}

		part def ElevatedStorageTank {
			attribute capacity : Real = 1000 [SI::m**3];
			attribute currentLevel : Real = 700 [SI::m**3];
			attribute elevation : Real = 40 [SI::m];
			port waterConnection : BidirectionalWaterPort;
			item storedWater : PotableWater;
		}

		part def DistributionPipeline {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute diameter : Real = 0.3 [SI::m];
			attribute length : Real = 5000 [SI::m];
		}

		part def PressureReducingValve {
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			attribute outletPressure : Real = 300000 [SI::Pa];
			attribute maxInletPressure : Real = 600000 [SI::Pa];
		}

		part def DistributionNode {
			port waterIn : WaterInPort;
			port waterOut1 : WaterOutPort;
			port waterOut2 : WaterOutPort;
			port waterOut3 : WaterOutPort;
		}

		part def Meter {
			attribute totalConsumption : Real = 0 [SI::m**3];
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			perform action measure {
				in inflow = waterIn.water;
				out outflow = waterOut.water;
			}
		}

		part def ConsumerServiceConnection {
			attribute consumerType : String;
			port waterIn : WaterInPort;
			port waterOut : WaterOutPort;
			part meter : Meter;
			flow of water : Water from waterIn.water to meter.waterIn.water;
			flow of water : Water from meter.waterOut.water to waterOut.water;
		}

		part def Consumer {
			port waterIn : WaterInPort;
			attribute consumptionRate : Real = 0.001 [SI::m**3 / SI::s];
		}

		part def PressureSensor {
			port monitorIn : WaterInPort;
			attribute reading : Real;
			attribute threshold : Real = 700000 [SI::Pa];
			perform action sensePressure {
				in sample = monitorIn.water;
				out pressure : Real;
			}
		}

		part def FlowMeter {
			port monitorIn : WaterInPort;
			attribute reading : Real;
			perform action senseFlow {
				in sample = monitorIn.water;
				out flowRate : Real;
			}
		}

		requirement def ContinuousSupplyRequirement {
			doc /* The system shall provide continuous water supply to all consumers 24 hours per day. */
			attribute minUptimePercent : Real = 99.5;
		}

		requirement def WaterQualityRequirement {
			doc /* Treated water shall meet potable water standards at all times. */
			attribute maxTurbidity : Real = 0.3;
			attribute minChlorineResidual : Real = 0.2;
			attribute maxChlorineResidual : Real = 4.0;
		}

		requirement def PressureRequirement {
			doc /* System pressure shall remain within safe range at all distribution points. */
			attribute minPressure : Real = 140000 [SI::Pa];
			attribute maxPressure : Real = 700000 [SI::Pa];
		}

		requirement def RedundancyRequirement {
			doc /* Critical pump stations shall have standby pump capacity. */
			attribute minBackupPumps : Integer = 1;
		}

		requirement def StorageCapacityRequirement {
			doc /* System shall maintain emergency storage reserves. */
			attribute minEmergencyReserve : Real = 500 [SI::m**3];
		}
	}

	package Usages {
		private import Definitions::*;

		part waterNetwork {
			part reservoir : Reservoir;
			part intakeStation : IntakePumpStation;
			part treatmentPlant : TreatmentPlant;
			part clearWell : ClearWell;
			part highServiceStation : HighServicePumpStation;
			part transmissionMain : TransmissionPipeline;
			part waterTower : ElevatedStorageTank;
			part distributionNetwork {
				part mainDistributionLine : DistributionPipeline;
				part prvZone1 : PressureReducingValve;
				part prvZone2 : PressureReducingValve;
				part node1 : DistributionNode;
				part node2 : DistributionNode;
				part branchLine1 : DistributionPipeline;
				part branchLine2 : DistributionPipeline;
				part branchLine3 : DistributionPipeline;
			}
			part residentialConnections : ConsumerServiceConnection[0..*] {
				:>> consumerType = "residential";
			}
			part commercialConnections : ConsumerServiceConnection[0..*] {
				:>> consumerType = "commercial";
			}
			part industrialConnections : ConsumerServiceConnection[0..*] {
				:>> consumerType = "industrial";
			}
			part residentialConsumers : Consumer[0..*];
			part commercialConsumers : Consumer[0..*];
			part industrialConsumers : Consumer[0..*];
			part monitoringSystem {
				part pressureSensors : PressureSensor[0..*];
				part flowMeters : FlowMeter[0..*];
				part qualityMonitors : WaterQualityMonitor[0..*];
			}

			flow of water : Water
				from reservoir.waterOut.water to intakeStation.waterIn.water;
			flow of water : Water
				from intakeStation.waterOut.water to treatmentPlant.rawWaterIn.water;
			flow of water : Water
				from treatmentPlant.treatedWaterOut.water to clearWell.waterIn.water;
			flow of water : Water
				from clearWell.waterOut.water to highServiceStation.waterIn.water;
			flow of water : Water
				from highServiceStation.waterOut.water to transmissionMain.waterIn.water;
			flow of water : Water
				from transmissionMain.waterOut.water to waterTower.waterConnection.water;
			flow of water : Water
				from transmissionMain.waterOut.water to distributionNetwork.mainDistributionLine.waterIn.water;
			flow of water : Water
				from distributionNetwork.mainDistributionLine.waterOut.water to distributionNetwork.prvZone1.waterIn.water;
			flow of water : Water
				from distributionNetwork.prvZone1.waterOut.water to distributionNetwork.node1.waterIn.water;
			flow of water : Water
				from distributionNetwork.node1.waterOut1.water to distributionNetwork.branchLine1.waterIn.water;
			flow of water : Water
				from distributionNetwork.node1.waterOut2.water to distributionNetwork.branchLine2.waterIn.water;
			flow of water : Water
				from distributionNetwork.node1.waterOut3.water to distributionNetwork.prvZone2.waterIn.water;
			flow of water : Water
				from distributionNetwork.prvZone2.waterOut.water to distributionNetwork.node2.waterIn.water;
			flow of water : Water
				from distributionNetwork.node2.waterOut1.water to distributionNetwork.branchLine3.waterIn.water;
			flow of water : Water
				from distributionNetwork.branchLine1.waterOut.water to residentialConnections.waterIn.water;
			flow of water : Water
				from distributionNetwork.branchLine2.waterOut.water to commercialConnections.waterIn.water;
			flow of water : Water
				from distributionNetwork.branchLine3.waterOut.water to industrialConnections.waterIn.water;
			flow of water : Water
				from residentialConnections.waterOut.water to residentialConsumers.waterIn.water;
			flow of water : Water
				from commercialConnections.waterOut.water to commercialConsumers.waterIn.water;
			flow of water : Water
				from industrialConnections.waterOut.water to industrialConsumers.waterIn.water;
			flow of water : Water
				from transmissionMain.waterOut.water to monitoringSystem.pressureSensors.monitorIn.water;
			flow of water : Water
				from distributionNetwork.branchLine1.waterOut.water to monitoringSystem.flowMeters.monitorIn.water;
			flow of water : Water
				from clearWell.waterOut.water to monitoringSystem.qualityMonitors.sampleIn.water;

			requirement continuousSupply : ContinuousSupplyRequirement;
			requirement potableWaterQuality : WaterQualityRequirement;
			requirement safePressureRange : PressureRequirement;
			requirement pumpStationRedundancy : RedundancyRequirement;
			requirement emergencyStorage : StorageCapacityRequirement;

			satisfy continuousSupply by intakeStation, highServiceStation;
			satisfy potableWaterQuality by treatmentPlant;
			satisfy safePressureRange by distributionNetwork.prvZone1, distributionNetwork.prvZone2;
			satisfy pumpStationRedundancy by intakeStation;
			satisfy emergencyStorage by clearWell, waterTower;
		}
	}
}
