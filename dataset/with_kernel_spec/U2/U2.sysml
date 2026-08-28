package AgriculturalRobotSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    // ---- Item/Attribute types ----
    attribute def GPSPosition {
        attribute latitude : Real;
        attribute longitude : Real;
        attribute altitude : LengthValue;
    }

    item def VisionData {
        attribute cropHealthIndex : Real;
        attribute maturityPercent : Real;
    }

    item def SoilMoistureData {
        attribute moisturePercent : Real;
        attribute probeDepth : LengthValue = 0.30 [m];
    }

    item def PlantingCommand {
        attribute activate : Boolean;
        attribute seedSpacing : LengthValue = 0.15 [m];
    }

    item def WateringCommand {
        attribute activate : Boolean;
        attribute flowRate : Real;
    }

    item def HarvestingCommand {
        attribute activate : Boolean;
    }

    item def NavigationTarget {
        attribute position : GPSPosition;
    }

    // ---- Signals ----
    attribute def SigPowerOn;
    attribute def SigPowerOff;
    attribute def SigStartMission;
    attribute def SigTaskComplete;
    attribute def SigBatteryLow;
    attribute def SigDocked;
    attribute def SigChargeComplete;
    attribute def SigLowMoisture;
    attribute def SigPlantingNeeded;
    attribute def SigHarvestingReady;

    // ---- State definition (top-level for harness visibility) ----
    state def RobotStates;

    // ---- Port definitions ----
    port def GPSDataPort {
        out attribute position : GPSPosition;
    }

    port def VisionDataPort {
        out item data : VisionData;
    }

    port def SoilDataPort {
        out item data : SoilMoistureData;
    }

    port def BatteryStatusPort {
        out attribute stateOfCharge : Real;
        out attribute voltage : Real;
    }

    port def PlantingCmdPort {
        in item command : PlantingCommand;
    }

    port def WateringCmdPort {
        in item command : WateringCommand;
    }

    port def HarvestingCmdPort {
        in item command : HarvestingCommand;
    }

    port def NavigationCmdPort {
        in item target : NavigationTarget;
    }

    port def PowerOutPort {
        out attribute power : PowerValue;
    }

    port def PowerInPort {
        in attribute power : PowerValue;
    }

    // ---- Part definitions ----
    part def GPSModule {
        attribute accuracy : LengthValue = 0.02 [m];
        port dataOut : GPSDataPort;
        port powerIn : PowerInPort;
        perform action acquirePosition {
            out attribute position : GPSPosition;
            first start;
            then action triangulate;
            then action applyCorrection;
            then done;
        }
    }

    part def Camera {
        port dataOut : VisionDataPort;
        port powerIn : PowerInPort;
        perform action captureImage {
            out item data : VisionData;
            first start;
            then action acquireFrame;
            then action analyzeCropHealth;
            then done;
        }
    }

    part def SoilSensor {
        attribute maxProbeDepth : LengthValue = 0.30 [m];
        port dataOut : SoilDataPort;
        port powerIn : PowerInPort;
        perform action measureMoisture {
            out item data : SoilMoistureData;
            first start;
            then action insertProbe;
            then action readMoisture;
            then action retractProbe;
            then done;
        }
    }

    part def CentralControlUnit {
        port gpsIn : ~GPSDataPort;
        port visionIn : ~VisionDataPort;
        port soilIn : ~SoilDataPort;
        port batteryIn : ~BatteryStatusPort;
        port plantingOut : PlantingCmdPort;
        port wateringOut : WateringCmdPort;
        port harvestingOut : HarvestingCmdPort;
        port navigationOut : NavigationCmdPort;
        port powerIn : PowerInPort;

        attribute soilMoistureThreshold : Real = 20.0;
        attribute batteryLowThreshold : Real = 20.0;
        attribute currentTask : String;
        attribute targetLocation : GPSPosition;

        perform action evaluateConditions {
            in item soilData : SoilMoistureData;
            in item visionData : VisionData;
            in attribute batteryLevel : Real;
            first start;
            then action checkSoilMoisture;
            then action checkCropHealth;
            then action checkBatteryLevel;
            then action decideTask;
            then done;
        }
    }

    part def PlantingMechanism {
        part seedHopper {
            attribute capacity : MassValue = 50 [kg];
            attribute currentLoad : MassValue;
        }
        port cmdIn : ~PlantingCmdPort;
        port powerIn : PowerInPort;
        perform action plantSeeds {
            in item command : PlantingCommand;
            first start;
            then action positionHopper;
            then action dispenseSeed;
            then action coverFurrow;
            then done;
        }
    }

    part def WateringSystem {
        part waterTank {
            attribute capacity : VolumeValue = 100 [L];
            attribute currentVolume : VolumeValue;
        }
        port cmdIn : ~WateringCmdPort;
        port powerIn : PowerInPort;
        perform action irrigate {
            in item command : WateringCommand;
            first start;
            then action activatePump;
            then action sprayWater;
            then action stopPump;
            then done;
        }
    }

    part def HarvestingMechanism {
        part storageBin {
            attribute capacity : VolumeValue = 200 [L];
            attribute currentLoad : VolumeValue;
        }
        port cmdIn : ~HarvestingCmdPort;
        port powerIn : PowerInPort;
        perform action harvest {
            in item command : HarvestingCommand;
            first start;
            then action engageCutter;
            then action gatherCrop;
            then action depositInBin;
            then done;
        }
    }

    part def Wheel {
        attribute diameter : LengthValue = 0.5 [m];
    }

    part def MobilitySystem {
        port navIn : ~NavigationCmdPort;
        port powerIn : PowerInPort;
        part wheels[4] : Wheel;
        perform action navigateTo {
            in item target : NavigationTarget;
            first start;
            then action computePath;
            then action driveWheels;
            then action verifyArrival;
            then done;
        }
    }

    part def BatteryPack {
        attribute capacity : EnergyValue = 5000 [Wh];
        attribute currentCharge : Real;
        attribute voltage : Real;
        port powerOut : PowerOutPort;
        port statusOut : BatteryStatusPort;
        port chargeIn : PowerInPort;
        part batteryManagementSystem {
            attribute cellCount : Integer = 12;
            perform action monitorCharge {
                out attribute stateOfCharge : Real;
                first start;
                then action readVoltage;
                then action computeSOC;
                then done;
            }
        }
    }

    part def ChargingStation {
        attribute location : GPSPosition;
        port powerOut : PowerOutPort;
        perform action supplyPower {
            first start;
            then action activateChargingCircuit;
            then action regulateCurrent;
            then done;
        }
    }

    // ---- Main robot part definition ----
    part def AgriculturalRobot {
        attribute mass : MassValue;
        attribute soilMoistureThreshold : Real = 20.0;

        part controlUnit : CentralControlUnit;
        part gpsModule : GPSModule;
        part camera : Camera;
        part soilSensor : SoilSensor;
        part plantingMechanism : PlantingMechanism;
        part wateringSystem : WateringSystem;
        part harvestingMechanism : HarvestingMechanism;
        part mobilitySystem : MobilitySystem;
        part batteryPack : BatteryPack;

        port chargingPort : PowerInPort;

        message notifyBatteryLow of SigBatteryLow from batteryPack.batteryManagementSystem to controlUnit;

        connect gpsModule.dataOut to controlUnit.gpsIn;
        connect camera.dataOut to controlUnit.visionIn;
        connect soilSensor.dataOut to controlUnit.soilIn;
        connect batteryPack.statusOut to controlUnit.batteryIn;
        connect controlUnit.plantingOut to plantingMechanism.cmdIn;
        connect controlUnit.wateringOut to wateringSystem.cmdIn;
        connect controlUnit.harvestingOut to harvestingMechanism.cmdIn;
        connect controlUnit.navigationOut to mobilitySystem.navIn;

        connect batteryPack.powerOut to controlUnit.powerIn;
        connect batteryPack.powerOut to gpsModule.powerIn;
        connect batteryPack.powerOut to camera.powerIn;
        connect batteryPack.powerOut to soilSensor.powerIn;
        connect batteryPack.powerOut to plantingMechanism.powerIn;
        connect batteryPack.powerOut to wateringSystem.powerIn;
        connect batteryPack.powerOut to harvestingMechanism.powerIn;
        connect batteryPack.powerOut to mobilitySystem.powerIn;

        state robotStates : RobotStates {
            entry; then off;
            state off;
            accept SigPowerOn then standby;

            state standby;
            accept SigStartMission then surveying;
            accept SigPowerOff then off;

            state surveying {
                do action evaluateField {
                    first start;
                    then action collectGPSData;
                    then action collectVisionData;
                    then action collectSoilData;
                    then done;
                }
            }
            accept SigLowMoisture then watering;
            accept SigPlantingNeeded then planting;
            accept SigHarvestingReady then harvesting;
            accept SigBatteryLow then returningToBase;

            state planting {
                do action executePlanting {
                    first start;
                    then action positionHopper;
                    then action dispenseSeed;
                    then done;
                }
            }
            accept SigTaskComplete then surveying;
            accept SigBatteryLow then returningToBase;

            state watering {
                do action executeWatering {
                    first start;
                    then action activatePump;
                    then action sprayWater;
                    then done;
                }
            }
            accept SigTaskComplete then surveying;
            accept SigBatteryLow then returningToBase;

            state harvesting {
                do action executeHarvesting {
                    first start;
                    then action engageCutter;
                    then action gatherCrop;
                    then done;
                }
            }
            accept SigTaskComplete then surveying;
            accept SigBatteryLow then returningToBase;

            state returningToBase {
                do action driveToCharger {
                    first start;
                    then action computePath;
                    then action driveWheels;
                    then done;
                }
            }
            accept SigDocked then charging;

            state charging {
                do action chargeBattery {
                    first start;
                    then action readVoltage;
                    then action computeSOC;
                    then done;
                }
            }
            accept SigChargeComplete then standby;
            accept SigPowerOff then off;
        }
    }

    // ---- System assembly ----
    part def AgriculturalRobotSystem {
        part robot : AgriculturalRobot;
        part chargingStation : ChargingStation;
        connect chargingStation.powerOut to robot.chargingPort;
    }

    // ---- Requirements ----
    requirement def AutonomousCropManagement {
        doc /* The robot shall autonomously survey, plant, water, and harvest crops based on real-time environmental data. */
    }

    requirement def GPSAccuracyRequirement {
        doc /* The GPS module shall provide location tracking with an accuracy of 2 centimeters or better. */
    }

    requirement def WaterTankCapacityRequirement {
        doc /* The watering system shall include a water tank with a capacity of at least 100 liters. */
    }

    requirement def HarvestBinCapacityRequirement {
        doc /* The harvesting mechanism shall include a storage bin with a capacity of at least 200 liters. */
    }

    requirement def AutoWateringOnLowMoisture {
        doc /* When the soil sensor reports moisture below 20%, the robot shall navigate to the affected area and activate the watering system. */
    }

    requirement def AutoRechargeRequirement {
        doc /* When the battery state of charge falls below 20%, the robot shall navigate to the charging station and recharge. */
    }

    part robotInstance : AgriculturalRobot;
    requirement autonomousCropManagement : AutonomousCropManagement;
    requirement gpsAccuracyRequirement : GPSAccuracyRequirement;
    requirement waterTankCapacityRequirement : WaterTankCapacityRequirement;
    requirement harvestBinCapacityRequirement : HarvestBinCapacityRequirement;
    requirement autoWateringOnLowMoisture : AutoWateringOnLowMoisture;
    requirement autoRechargeRequirement : AutoRechargeRequirement;

    satisfy autonomousCropManagement by robotInstance;
    satisfy gpsAccuracyRequirement by robotInstance.gpsModule;
    satisfy waterTankCapacityRequirement by robotInstance.wateringSystem;
    satisfy harvestBinCapacityRequirement by robotInstance.harvestingMechanism;
    satisfy autoWateringOnLowMoisture by robotInstance;
    satisfy autoRechargeRequirement by robotInstance;
}
