package LysimeterSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SoilMoistureContent :> Real;
	attribute def WaterDepth :> Real;
	
	item def WaterSample {
		attribute volume :> ISQ::volume;
		attribute timestamp :> ISQ::time;
		attribute chemicalProperties : String;
	}
	
	item def SoilProfile {
		attribute depth :> ISQ::length;
		attribute moisture : SoilMoistureContent;
		attribute temperature :> ISQ::temperature;
		attribute texture : String;
	}
	
	item def WaterBalanceData {
		attribute precipitation :> ISQ::volume;
		attribute irrigation :> ISQ::volume;
		attribute drainage :> ISQ::volume;
		attribute evapotranspiration :> ISQ::volume;
		attribute storageChange :> ISQ::volume;
		attribute measurementPeriod :> ISQ::time;
	}
	
	attribute def VolumeFlowRate :> Real;
	
	port def WaterInputPort {
		in attribute waterInput :> ISQ::volume;
		in attribute inputRate : VolumeFlowRate;
	}
	
	port def WaterOutputPort {
		out attribute waterOutput :> ISQ::volume;
		out attribute outputRate : VolumeFlowRate;
	}
	
	port def SensorDataPort {
		out attribute moistureReading : SoilMoistureContent;
		out attribute massReading :> ISQ::mass;
		out attribute temperatureReading :> ISQ::temperature;
	}
	
	port def ControlPort {
		in attribute irrigationCommand :> ISQ::volume;
		out attribute systemStatus : String;
	}
	
	part def PrecisionWeighingSystem {
		attribute resolution :> ISQ::mass = 0.01 [SI::kg];
		attribute capacity :> ISQ::mass = 5000.0 [SI::kg];
		
		out port weightData : SensorDataPort {
			out attribute massReading :> ISQ::mass;
		}
		
		action def MeasureMass {
			out currentMass :> ISQ::mass;
			out massChange :> ISQ::mass;
		}
	}
	
	part def SoilMoistureSensorArray {
		attribute numberOfSensors : Integer = 8;
		attribute depthInterval :> ISQ::length = 0.2 [SI::m];
		
		out port moistureData : SensorDataPort {
			out attribute moistureReading : SoilMoistureContent;
		}
		
		action def MeasureMoisture {
			in depth :> ISQ::length;
			out moistureProfile : SoilProfile;
		}
	}
	
	part def DrainageCollectionSystem {
		attribute collectionCapacity :> ISQ::volume = 100.0 [SI::L];
		
		in port drainageInlet : WaterOutputPort {
			in attribute waterOutput :> ISQ::volume;
		}
		
		out port drainageOutlet : WaterOutputPort {
			out attribute waterOutput :> ISQ::volume;
			out attribute outputRate : VolumeFlowRate;
		}
		
		action def CollectDrainage {
			in inflowRate : VolumeFlowRate;
			in duration :> ISQ::time;
			out collectedSample : WaterSample;
			out totalVolume :> ISQ::volume;
		}
	}
	
	part def IrrigationSystem {
		attribute applicationRate : VolumeFlowRate;
		
		out port waterSupply : WaterInputPort {
			out attribute waterInput :> ISQ::volume;
			out attribute inputRate : VolumeFlowRate;
		}
		
		action def ApplyIrrigation {
			in targetVolume :> ISQ::volume;
			in applicationDuration :> ISQ::time;
			out appliedVolume :> ISQ::volume;
		}
	}
	
	part def RainGauge {
		attribute catchmentArea :> ISQ::area = 1.0 [SI::m^2];
		
		out port precipitationData : SensorDataPort {
			out attribute precipitationDepth :> ISQ::length;
		}
		
		action def MeasurePrecipitation {
			in measurementInterval :> ISQ::time;
			out precipitationVolume :> ISQ::volume;
		}
	}
	
	part def DataAcquisitionUnit {
		attribute samplingInterval :> ISQ::time = 900.0 [SI::s];
		attribute storageCapacity : Integer = 100000;
		
		in port sensorInputs : SensorDataPort {
			in attribute moistureReading : SoilMoistureContent;
			in attribute massReading :> ISQ::mass;
		}
		
		out port processedData {
			out attribute waterBalance : WaterBalanceData;
			out attribute evapotranspirationRate : VolumeFlowRate;
		}
		
		action def ProcessData {
			in moistureData : SoilMoistureContent;
			in massData :> ISQ::mass;
			in drainageData :> ISQ::volume;
			in precipitationData :> ISQ::volume;
			out balanceReport : WaterBalanceData;
		}
	}
	
	part def SoilContainer {
		attribute containerDepth :> ISQ::length = 2.0 [SI::m];
		attribute surfaceArea :> ISQ::area = 1.0 [SI::m^2];
		attribute soilType : String = "Loamy Sand";
		attribute vegetationCover : String = "Grass";
		
		in port atmosphericInterface : WaterInputPort {
			in attribute waterInput :> ISQ::volume;
		}
		
		out port drainageInterface : WaterOutputPort {
			out attribute waterOutput :> ISQ::volume;
		}
		
		port soilSensorInterface : SensorDataPort {
			out attribute moistureReading : SoilMoistureContent;
			out attribute temperatureReading :> ISQ::temperature;
		}
	}
	
	state def LysimeterOperationalStates {
		attribute operationalMode : String;
		attribute dataStatus : String;
		
		entry; then initialization;
		
		state initialization {
			entry assign operationalMode := "Initializing";
		}
		
		accept event SystemReady
		then initialization
		do send SystemReady() to monitoring;
		
		state monitoring {
			entry assign operationalMode := "Active";
			
			state continuousMeasurement {
				entry; then collectSensorData;
				
				state collectSensorData {
					entry assign dataStatus := "Collecting";
				}
				
				accept at collectSensorData
				then collectSensorData
				do send DataCollected() to processMeasurements;
				
				state processMeasurements {
					entry assign dataStatus := "Processing";
				}
				
				accept at processMeasurements
				then processMeasurements
				do send DataProcessed() to calculateBalance;
				
				state calculateBalance {
					entry assign dataStatus := "Calculating";
				}
				
				accept at calculateBalance
				then calculateBalance
				do send BalanceCalculated() to storeResults;
				
				state storeResults {
					entry assign dataStatus := "Storing";
				}
				
				accept at storeResults
				then storeResults
				do send ResultsStored() to collectSensorData;
			}
		}
		
		accept event MaintenanceScheduled
		then monitoring
		do send MaintenanceScheduled() to maintenance;
		
		state maintenance {
			entry assign operationalMode := "Maintenance";
			
			state calibration;
			state cleaning;
			state inspection;
		}
		
		accept event MaintenanceCompleted
		then maintenance
		do send MaintenanceCompleted() to monitoring;
		
		accept event SystemFault
		then monitoring
		do send SystemFault() to error;
		
		state error {
			entry assign operationalMode := "Error";
		}
		
		accept event SystemReset
		then error
		do send SystemReset() to initialization;
	}
	
	action def CalculateWaterBalance {
		in precipitationInput :> ISQ::volume;
		in irrigationInput :> ISQ::volume;
		in drainageOutput :> ISQ::volume;
		in previousMass :> ISQ::mass;
		in currentMass :> ISQ::mass;
		in surfaceArea :> ISQ::area;
		in waterDensity :> ISQ::density = 1000.0 [SI::kg/SI::m^3];
		out evapotranspiration :> ISQ::volume;
		out storageChange :> ISQ::volume;
		out balanceError :> ISQ::volume;
	}
	
	action def MonitorWaterMovement {
		in measurementInterval :> ISQ::time;
		in previousSystemMass :> ISQ::mass;
		out waterBalanceReport : WaterBalanceData;
		
		first start;
		then merge continuousMonitoring;
		
		then action measurePrecipitation : RainGauge::MeasurePrecipitation {
			in measurementInterval = measurementInterval;
			out precipitationVolume;
		}
		
		then action measureSystemMass : PrecisionWeighingSystem::MeasureMass {
			out currentMass;
			out massChange;
		}
		
		then action collectDrainageVolume : DrainageCollectionSystem::CollectDrainage {
			in inflowRate;
			in duration = measurementInterval;
			out collectedSample;
			out totalVolume;
		}
		
		then action measureSoilConditions : SoilMoistureSensorArray::MeasureMoisture {
			in depth;
			out moistureProfile;
		}
		
		then action computeWaterBalance : CalculateWaterBalance {
			in precipitationInput = measurePrecipitation.precipitationVolume;
			in irrigationInput = 0.0 [SI::m^3];
			in drainageOutput = collectDrainageVolume.totalVolume;
			in previousMass = previousSystemMass;
			in currentMass = measureSystemMass.currentMass;
			in surfaceArea = 1.0 [SI::m^2];
			out evapotranspiration;
			out storageChange;
			out balanceError;
		}
		
		then decide;
			if computeWaterBalance.balanceError < 0.05 [SI::m^3] then continuousMonitoring;
			if computeWaterBalance.balanceError >= 0.05 [SI::m^3] then recalibrate;
		
		action recalibrate {
			doc /* Recalibrate sensors and verify measurement accuracy */
		}
		then continuousMonitoring;
		
		then done;
	}
	
	part lysimeterInstrument : Lysimeter {
		perform action waterBalanceMonitoring[*] ordered references MonitorWaterMovement;
		
		part soilColumn : SoilContainer {
			attribute :>> containerDepth = 2.0 [SI::m];
			attribute :>> surfaceArea = 1.0 [SI::m^2];
			attribute :>> soilType = "Sandy Loam";
			attribute :>> vegetationCover = "Turfgrass";
			
			perform waterBalanceMonitoring.measureSoilConditions;
		}
		
		part weighingPlatform : PrecisionWeighingSystem {
			attribute :>> resolution = 0.01 [SI::kg];
			attribute :>> capacity = 5000.0 [SI::kg];
			
			perform waterBalanceMonitoring.measureSystemMass;
		}
		
		part moistureSensorNetwork : SoilMoistureSensorArray {
			attribute :>> numberOfSensors = 10;
			attribute :>> depthInterval = 0.2 [SI::m];
			
			perform waterBalanceMonitoring.measureSoilConditions;
		}
		
		part drainageCollection : DrainageCollectionSystem {
			attribute :>> collectionCapacity = 200.0 [SI::L];
			
			perform waterBalanceMonitoring.collectDrainageVolume;
		}
		
		part precipitationMonitor : RainGauge {
			attribute :>> catchmentArea = 1.0 [SI::m^2];
			
			perform waterBalanceMonitoring.measurePrecipitation;
		}
		
		part irrigationControl : IrrigationSystem {
			perform action applyWater : ApplyIrrigation {
				in targetVolume;
				in applicationDuration;
				out appliedVolume;
			}
		}
		
		part dataSystem : DataAcquisitionUnit {
			attribute :>> samplingInterval = 900.0 [SI::s];
			
			perform waterBalanceMonitoring.computeWaterBalance;
		}
		
		connection moistureDataFlow
			connect moistureSensorNetwork.moistureData to dataSystem.sensorInputs;
		
		connection massDataFlow
			connect weighingPlatform.weightData to dataSystem.sensorInputs;
		
		connection drainageFlow
			connect soilColumn.drainageInterface to drainageCollection.drainageInlet;
		
		connection irrigationFlow
			connect irrigationControl.waterSupply to soilColumn.atmosphericInterface;
		
		connection precipitationFlow
			connect precipitationMonitor.precipitationData to dataSystem.sensorInputs;
	}
	
	part def Lysimeter {
		doc /* 
			A lysimeter is a precision hydrological instrument designed to measure 
			water balance components in soil-plant systems by isolating a soil volume 
			and monitoring all water inputs and outputs to quantify evapotranspiration.
		*/
	}
	
	requirement def MeasurementPrecisionRequirement {
		doc /* The lysimeter shall achieve specified measurement precision for water balance components. */
		
		subject lysimeterSystem : Lysimeter;
		
		require constraint massPrecision {
			doc /* Mass measurements shall have precision of ±0.01 kg or better. */
		}
		
		require constraint volumePrecision {
			doc /* Drainage volume measurements shall have precision of ±0.1 L or better. */
		}
		
		require constraint moisturePrecision {
			doc /* Soil moisture measurements shall have precision of ±2% volumetric water content. */
		}
	}
	
	requirement def DataAcquisitionRequirement {
		doc /* The lysimeter shall continuously acquire and process environmental data. */
		
		subject lysimeterSystem : Lysimeter;
		
		require constraint samplingRate {
			doc /* All sensors shall be sampled at intervals not exceeding 15 minutes. */
		}
		
		require constraint dataIntegrity {
			doc /* All measurements shall be timestamped and quality-checked before storage. */
		}
		
		require constraint continuousOperation {
			doc /* System shall operate continuously with automated data collection. */
		}
	}
	
	requirement def WaterBalanceAccuracyRequirement {
		doc /* The lysimeter shall maintain water balance closure within acceptable limits. */
		
		subject lysimeterSystem : Lysimeter;
		
		require constraint balanceClosure {
			doc /* Water balance closure error shall not exceed ±3% of total inputs over 24-hour periods. */
		}
		
		require constraint evapotranspirationAccuracy {
			doc /* Evapotranspiration estimates shall have accuracy of ±5% compared to reference methods. */
		}
	}
	
	requirement <'LYS-SYS-001'> lysimeterSystemRequirement {
		doc /* 
			The lysimeter system shall accurately measure and quantify all components 
			of the soil water balance including precipitation, irrigation, drainage, 
			soil water storage changes, and evapotranspiration to support hydrological 
			research, agricultural water management, and environmental monitoring applications.
		*/
		
		subject measuredSystem : Lysimeter = lysimeterInstrument;
		
		assume constraint operatingEnvironment {
			doc /* System operates in controlled or field conditions with environmental monitoring. */
		}
		
		assume constraint soilHomogeneity {
			doc /* Soil column is representative of surrounding field conditions. */
		}
		
		require measurementPrecision : MeasurementPrecisionRequirement {
			subject lysimeterSystem = measuredSystem;
		}
		
		require dataAcquisition : DataAcquisitionRequirement {
			subject lysimeterSystem = measuredSystem;
		}
		
		require waterBalanceAccuracy : WaterBalanceAccuracyRequirement {
			subject lysimeterSystem = measuredSystem;
		}
		
		satisfy by lysimeterInstrument.waterBalanceMonitoring;
	}
}
