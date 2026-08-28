package LysimeterSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def WaterSample {
        attribute collectionTime : TimeValue;
        attribute volume : VolumeValue;
    }

    item def WaterBalanceReport {
        attribute totalRainfall : VolumeValue;
        attribute totalIrrigation : VolumeValue;
        attribute totalDrainage : VolumeValue;
        attribute deltaStorage : VolumeValue;
        attribute evapotranspiration : VolumeValue;
    }

    part def SoilMoistureSensor {
        attribute depth : LengthValue;
        out moisture : Real;
    }

    part def SensorNetwork {
        part sensors : SoilMoistureSensor[10];
        out moistureProfile : Real[10] = sensors.moisture;
    }

    part def SoilContainer {
        attribute depth : LengthValue = 2.0[m];
        attribute surfaceArea : AreaValue = 1.0[m^2];
        attribute soilType : String = "Sandy Loam";
        attribute vegetation : String = "Turfgrass";
        part sensorNetwork : SensorNetwork;
    }

    part def WeighingPlatform {
        attribute resolution : MassValue = 10.0[g];
        attribute maxCapacity : MassValue = 5000.0[kg];
        out weight : MassValue;
    }

    part def DrainageCollectionSystem {
        attribute collectedVolume : VolumeValue;
        out drainageVolume : VolumeValue;
        out waterSample : WaterSample;
    }

    part def IrrigationUnit {
        in controlSignal : Real;
        out appliedWater : VolumeValue;
    }

    part def RainGauge {
        out rainfall : VolumeValue;
    }

    action def CalculateWaterBalance {
        in currentWeight : MassValue;
        in previousWeight : MassValue;
        in rainfall : VolumeValue;
        in irrigation : VolumeValue;
        in drainage : VolumeValue;
        out report : WaterBalanceReport;
        out updatedPreviousWeight : MassValue;

        private attribute massChange : MassValue := currentWeight - previousWeight;
        private attribute deltaStorageVol : VolumeValue := massChange / 1000[kg/m^3];
        private attribute et : VolumeValue := rainfall + irrigation - drainage - deltaStorageVol;

        assign report := WaterBalanceReport {
            totalRainfall = rainfall;
            totalIrrigation = irrigation;
            totalDrainage = drainage;
            deltaStorage = deltaStorageVol;
            evapotranspiration = et;
        };
        assign updatedPreviousWeight := currentWeight;
    }

    part def DataAcquisitionUnit {
        attribute samplingInterval : TimeValue = 15.0[min];
        attribute previousWeight : MassValue = 0.0[kg];

        in weight : MassValue;
        in moistureProfile : Real[10];
        in rainfall : VolumeValue;
        in drainageVolume : VolumeValue;
        in appliedWater : VolumeValue;
        out waterBalanceReport : WaterBalanceReport;

        action calculateBalance : CalculateWaterBalance {
            in currentWeight = weight;
            in previousWeight = previousWeight;
            in rainfall = rainfall;
            in irrigation = appliedWater;
            in drainage = drainageVolume;
            out report = waterBalanceReport;
            out updatedPreviousWeight;
        }
        then assign previousWeight := calculateBalance.updatedPreviousWeight;
    }

    part def Lysimeter {
        part soilContainer : SoilContainer;
        part weighingPlatform : WeighingPlatform;
        part drainageCollection : DrainageCollectionSystem;
        part irrigationUnit : IrrigationUnit;
        part rainGauge : RainGauge;
        part dataAcquisition : DataAcquisitionUnit;

        connection weighPlatformToData connect weighingPlatform.weight to dataAcquisition.weight;
        connection sensorsToData connect soilContainer.sensorNetwork.moistureProfile to dataAcquisition.moistureProfile;
        connection rainToData connect rainGauge.rainfall to dataAcquisition.rainfall;
        connection drainToData connect drainageCollection.drainageVolume to dataAcquisition.drainageVolume;
        connection irrigToData connect irrigationUnit.appliedWater to dataAcquisition.appliedWater;

        exhibit state operationalStates {
            state continuousMonitoring;
            state maintenance;
            state errorState;
            transition continuousMonitoring to maintenance on maintenanceTrigger;
            transition maintenance to continuousMonitoring on resumeTrigger;
            transition continuousMonitoring to errorState on faultDetected;
            transition maintenance to errorState on faultDetected;
            transition errorState to maintenance on resetTrigger;
        }
    }

    requirement def SoilContainerRequirements {
        subject container : SoilContainer;
        requirement containerDepth : container.depth == 2.0[m];
        requirement containerArea : container.surfaceArea == 1.0[m^2];
    }

    requirement def WeighingPlatformRequirements {
        subject platform : WeighingPlatform;
        requirement weighingResolution : platform.resolution <= 10.0[g];
    }

    requirement def SensorNetworkRequirements {
        subject network : SensorNetwork;
        requirement sensorCount : network.sensors->size() == 10;
    }

    requirement def SamplingRequirements {
        subject daq : DataAcquisitionUnit;
        requirement samplingInterval : daq.samplingInterval == 15.0[min];
    }

    requirement def WaterBalanceRequirements {
        subject daq : DataAcquisitionUnit;
        requirement evapotranspirationCalculation :
            daq.waterBalanceReport.evapotranspiration == daq.waterBalanceReport.totalRainfall
            + daq.waterBalanceReport.totalIrrigation
            - daq.waterBalanceReport.totalDrainage
            - daq.waterBalanceReport.deltaStorage;
    }

    part lysimeterInstance : Lysimeter {
        satisfy SoilContainerRequirements by soilContainer;
        satisfy WeighingPlatformRequirements by weighingPlatform;
        satisfy SensorNetworkRequirements by soilContainer.sensorNetwork;
        satisfy SamplingRequirements by dataAcquisition;
        satisfy WaterBalanceRequirements by dataAcquisition;
    }
}
