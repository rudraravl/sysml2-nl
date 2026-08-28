package LysimeterSystem {
    import ISQ::*;
    import ISQUnits::*;
    import ScalarValues::*;

    // ---- Value types ----
    value def MassResolution :> Mass;
    value def SamplingInterval :> Time;
    value def MoistureFraction :> Real;
    value def Evapotranspiration :> Volume;

    // ---- Items ----
    item def Water;
    item def SoilSample;
    item def WeightReading {
        attribute value : Mass;
        attribute timestamp : DateTime;
    }
    item def MoistureReading {
        attribute value : MoistureFraction;
        attribute depth : Length;
        attribute sensorId : String;
        attribute timestamp : DateTime;
    }
    item def RainfallReading {
        attribute value : Volume;
        attribute timestamp : DateTime;
    }
    item def DrainageReading {
        attribute value : Volume;
        attribute timestamp : DateTime;
    }
    item def IrrigationCommand {
        attribute volume : Volume;
        attribute duration : Time;
    }
    item def WaterBalanceReport {
        attribute timestamp : DateTime;
        attribute totalWeight : Mass;
        attribute storageChange : Mass;
        attribute rainfall : Volume;
        attribute irrigation : Volume;
        attribute drainage : Volume;
        attribute evapotranspiration : Evapotranspiration;
        attribute moistureProfile : MoistureReading[10];
    }
    item def FaultAlert {
        attribute source : String;
        attribute description : String;
        attribute severity : Integer;
    }

    // ---- Enumerations ----
    enum def OperatingMode {
        literal Monitoring;
        literal Maintenance;
        literal Error;
    }

    // ---- Part definitions ----
    part def WeighingPlatform {
        attribute resolution : MassResolution = 10 [g];
        attribute maxCapacity : Mass = 5000 [kg];
        attribute tareMass : Mass;
        attribute lastReading : Mass;
        port out weightOut : WeightReading;

        action def weigh() : WeightReading {
            in soilMass : Mass;
            return reading : WeightReading;
        }

        perform action weighSoil : weigh {
            out weightOut;
        }
    }

    part def SoilMoistureSensor {
        attribute sensorId : String;
        attribute installationDepth : Length;
        attribute calibrated : Boolean = true;
        port out moistureOut : MoistureReading;

        action def sampleMoisture() : MoistureReading {
            return reading : MoistureReading;
        }

        perform action sample : sampleMoisture {
            out moistureOut;
        }
    }

    part def SoilMoistureSensorNetwork {
        attribute sensorCount : Integer = 10;
        attribute depthInterval : Length = 20 [cm];
        port out moistureOuts : MoistureReading[10];

        part sensors : SoilMoistureSensor[10] {
            redefinition sensorId = "SMS-" + (index + 1);
            redefinition installationDepth = (index + 1) * 20 [cm];
        }

        flow moistureOuts from sensors.moistureOut;
    }

    part def SoilContainer {
        attribute depth : Length = 2 [m];
        attribute surfaceArea : Area = 1 [m^2];
        attribute soilType : String = "Sandy Loam";
        attribute vegetation : String = "Turfgrass";
        attribute bulkDensity : MassDensity = 1300 [kg/m^3];

        port in irrigationIn : Water;
        port in rainfallIn : Water;
        port out drainageOut : Water;
        port out sampleOut : SoilSample;

        part sensorNetwork : SoilMoistureSensorNetwork;

        flow drainageOut from sensorNetwork.sensors to drainageOut;
    }

    part def DrainageCollectionSystem {
        attribute collectedVolume : Volume = 0 [L];
        attribute tankCapacity : Volume = 50 [L];
        attribute sampleVolume : Volume = 0.5 [L];

        port in drainageIn : Water;
        port out drainageReadingOut : DrainageReading;
        port out sampleOut : Water;
        port out overflowOut : Water;

        action def measureDrainage() : DrainageReading {
            in inflow : Water;
            return reading : DrainageReading;
        }

        perform action measure : measureDrainage {
            in drainageIn;
            out drainageReadingOut;
        }

        perform action collectSample {
            out sampleOut;
        }
    }

    part def IrrigationUnit {
        attribute appliedVolume : Volume = 0 [L];
        attribute maxFlowRate : VolumeFlowRate = 5 [L/min];
        attribute emitterCount : Integer = 16;

        port in commandIn : IrrigationCommand;
        port out irrigationOut : Water;

        action def applyIrrigation() {
            in command : IrrigationCommand;
            out water : Water;
        }

        perform action apply : applyIrrigation {
            in commandIn;
            out irrigationOut;
        }
    }

    part def RainGauge {
        attribute resolution : Volume = 0.1 [mm * m^2];
        attribute tippingBucketCapacity : Volume = 0.2 [mm * m^2];
        port out rainfallOut : RainfallReading;

        action def measureRainfall() : RainfallReading {
            return reading : RainfallReading;
        }

        perform action measure : measureRainfall {
            out rainfallOut;
        }
    }

    part def DataAcquisitionUnit {
        attribute samplingInterval : SamplingInterval = 15 [min];
        attribute currentMode : OperatingMode = OperatingMode::Monitoring;
        attribute lastReport : WaterBalanceReport;
        attribute previousWeight : Mass;
        attribute faultCount : Integer = 0;

        port in weightIn : WeightReading;
        port in moistureIn : MoistureReading[10];
        port in rainfallIn : RainfallReading;
        port in drainageIn : DrainageReading;
        port in faultIn : FaultAlert;

        port out reportOut : WaterBalanceReport;
        port out irrigationCommandOut : IrrigationCommand;
        port out modeOut : OperatingMode;

        action def calculateWaterBalance() : WaterBalanceReport {
            in weight : WeightReading;
            in moisture : MoistureReading[10];
            in rain : RainfallReading;
            in drainage : DrainageReading;
            in previousMass : Mass;
            in irrigationVolume : Volume;
            return report : WaterBalanceReport;
        }

        perform action sampleAll {
            in weightIn;
            in moistureIn;
            in rainfallIn;
            in drainageIn;
        }

        perform action computeBalance : calculateWaterBalance {
            in weightIn;
            in moistureIn;
            in rainfallIn;
            in drainageIn;
            in previousWeight;
            out reportOut;
        }

        state machine operatingStates {
            entry action { currentMode = OperatingMode::Monitoring; }

            state Monitoring {
                entry action { send samplingInterval; }
                do action sampleAll;
                transition to Maintenance when faultIn == null && maintenanceRequested;
                transition to Error when faultIn != null;
            }

            state Maintenance {
                entry action { currentMode = OperatingMode::Maintenance; }
                do action calibrateSensors;
                do action cleanDrainageSystem;
                transition to Monitoring when maintenanceComplete;
            }

            state Error {
                entry action { currentMode = OperatingMode::Error; faultCount = faultCount + 1; }
                do action logFault;
                transition to Maintenance when faultCleared;
            }
        }

        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;
        attribute faultCleared : Boolean = false;

        action def calibrateSensors;
        action def cleanDrainageSystem;
        action def logFault;
    }

    // ---- Top-level Lysimeter ----
    part def Lysimeter {
        attribute systemId : String = "LYS-001";
        attribute installationDate : DateTime;
        attribute location : String;

        part soilContainer : SoilContainer;
        part weighingPlatform : WeighingPlatform;
        part drainageSystem : DrainageCollectionSystem;
        part irrigationUnit : IrrigationUnit;
        part rainGauge : RainGauge;
        part dau : DataAcquisitionUnit;

        // Soil container physically rests on weighing platform
        connection soilOnPlatform connect soilContainer to weighingPlatform;

        // Drainage from soil container to drainage collection
        flow from soilContainer.drainageOut to drainageSystem.drainageIn;

        // Irrigation applied to soil surface
        flow from irrigationUnit.irrigationOut to soilContainer.irrigationIn;

        // Rainfall measured by rain gauge
        flow from rainGauge.rainfallOut to dau.rainfallIn;

        // Weight reading to DAU
        flow from weighingPlatform.weightOut to dau.weightIn;

        // Moisture readings to DAU
        flow from soilContainer.sensorNetwork.moistureOuts to dau.moistureIn;

        // Drainage reading to DAU
        flow from drainageSystem.drainageReadingOut to dau.drainageIn;

        // Irrigation command from DAU to irrigation unit
        flow from dau.irrigationCommandOut to irrigationUnit.commandIn;

        // Report output
        flow from dau.reportOut to externalReportSink;

        port out externalReportSink : WaterBalanceReport;
        port out externalSampleSink : Water;
        port out externalSoilSampleSink : SoilSample;

        flow from drainageSystem.sampleOut to externalSampleSink;
        flow from soilContainer.sampleOut to externalSoilSampleSink;
    }

    // ---- Requirements ----
    requirement def MeasurementPrecisionRequirement {
        attribute id : String = "REQ-001";
        attribute text : String = "The weighing platform shall detect mass changes as small as 10 grams.";
        subject weighingPlatform : WeighingPlatform;
        objective {
            assert weighingPlatform.resolution <= 10 [g]
        }
    }

    requirement def SoilColumnGeometryRequirement {
        attribute id : String = "REQ-002";
        attribute text : String = "The soil container shall be approximately 2 meters deep with a 1 square meter surface area.";
        subject soilContainer : SoilContainer;
        objective {
            assert soilContainer.depth == 2 [m] && soilContainer.surfaceArea == 1 [m^2]
        }
    }

    requirement def SensorNetworkRequirement {
        attribute id : String = "REQ-003";
        attribute text : String = "Ten soil moisture sensors shall be embedded at 20 cm intervals down the soil column.";
        subject sensorNetwork : SoilMoistureSensorNetwork;
        objective {
            assert sensorNetwork.sensorCount == 10 && sensorNetwork.depthInterval == 20 [cm]
        }
    }

    requirement def SamplingIntervalRequirement {
        attribute id : String = "REQ-004";
        attribute text : String = "The data acquisition unit shall sample all sensors every 15 minutes.";
        subject dau : DataAcquisitionUnit;
        objective {
            assert dau.samplingInterval == 15 [min]
        }
    }

    requirement def WaterBalanceRequirement {
        attribute id : String = "REQ-005";
        attribute text : String = "The system shall calculate evapotranspiration from inputs, outputs, and storage change.";
        subject dau : DataAcquisitionUnit;
        objective {
            assert dau.computeBalance.report.evapotranspiration == (dau.computeBalance.rain.value + dau.computeBalance.irrigationVolume - dau.computeBalance.drainage.value - (dau.computeBalance.weight.value - dau.computeBalance.previousMass) / (1000 [kg/m^3]))
        }
    }

    requirement def OperatingStatesRequirement {
        attribute id : String = "REQ-006";
        attribute text : String = "The system shall operate in Monitoring, Maintenance, and Error states.";
        subject dau : DataAcquisitionUnit;
        objective {
            assert dau.operatingStates.states == {OperatingMode::Monitoring, OperatingMode::Maintenance, OperatingMode::Error}
        }
    }

    requirement def DrainageAnalysisRequirement {
        attribute id : String = "REQ-007";
        attribute text : String = "The drainage collection system shall measure total volume and provide samples for chemical analysis.";
        subject drainageSystem : DrainageCollectionSystem;
        objective {
            assert drainageSystem.collectedVolume >= 0 [L] && drainageSystem.sampleOut != null
        }
    }

    // ---- Requirement satisfaction ----
    part lysimeterInstance : Lysimeter {
        satisfy MeasurementPrecisionRequirement by weighingPlatform;
        satisfy SoilColumnGeometryRequirement by soilContainer;
        satisfy SensorNetworkRequirement by soilContainer.sensorNetwork;
        satisfy SamplingIntervalRequirement by dau;
        satisfy WaterBalanceRequirement by dau;
        satisfy OperatingStatesRequirement by dau;
        satisfy DrainageAnalysisRequirement by drainageSystem;
    }
}
