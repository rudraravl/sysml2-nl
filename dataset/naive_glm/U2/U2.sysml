package AgriBotSystem {
    private import ScalarValues::*;
    
    attribute def DistanceCm :> Real { / unit: "cm"; }
    attribute def VolumeL :> Real { / unit: "L"; }
    attribute def Percentage :> Real { / unit: "%"; }
    attribute def PowerW :> Real { / unit: "W"; }
    attribute def VelocityMps :> Real { / unit: "m/s"; }
    
    item def Position {
        attribute x : Real;
        attribute y : Real;
    }
    
    item def GPSData {
        attribute position : Position;
        attribute accuracy : DistanceCm;
    }
    
    item def ImageData {
        attribute width : Integer;
        attribute height : Integer;
    }
    
    item def SoilData {
        attribute moisture : Percentage;
        attribute depth : DistanceCm;
    }
    
    item def NavigationCommand {
        attribute target : Position;
        attribute speed : VelocityMps;
    }
    
    item def TaskCommand {
        attribute action : String;
        attribute parameter : Real;
    }
    
    item def PowerFlow {
        attribute voltage : Real;
        attribute current : Real;
    }
    
    port def GPSPort {
        out data : GPSData;
    }
    
    port def CameraPort {
        out data : ImageData;
    }
    
    port def SoilSensorPort {
        out data : SoilData;
    }
    
    port def DrivePort {
        in command : NavigationCommand;
    }
    
    port def ToolPort {
        in command : TaskCommand;
    }
    
    port def PowerPort {
        out flow : PowerFlow;
    }
    
    requirement def AgriBotRequirements {
        requirement GPSAccuracy {
            doc "The GPS module must provide precise location tracking within 2cm.";
            constraint { sensors.gps.accuracy <= 2 }
        }
        requirement WaterTankCapacity {
            doc "The watering system must have a 100-liter water tank.";
            constraint { tools.waterer.tankCapacity == 100 }
        }
        requirement StorageBinCapacity {
            doc "The harvesting mechanism must have a 200-liter storage bin.";
            constraint { tools.harvester.storageBinCapacity == 200 }
        }
        requirement AutonomousMoistureResponse {
            doc "If soil sensor reports low moisture, navigate to dry area and activate watering system.";
        }
    }
    
    part def BatteryPack {
        attribute chargeLevel : Percentage = 100;
        attribute capacity : PowerW = 5000;
        port powerIn : ~PowerPort;
        port powerOut : PowerPort;
    }
    
    part def ChargingStation {
        attribute outputPower : PowerW = 1500;
        port powerOut : PowerPort;
    }
    
    part def GPSModule {
        attribute accuracy : DistanceCm = 2;
        port dataOut : GPSPort;
    }
    
    part def VisionSensor {
        port dataOut : CameraPort;
    }
    
    part def SoilSensor {
        attribute depth : DistanceCm = 30;
        port dataOut : SoilSensorPort;
    }
    
    part def SensorSuite {
        part gps : GPSModule;
        part camera : VisionSensor;
        part soil : SoilSensor;
        
        port gpsOut : ~GPSPort;
        port camOut : ~CameraPort;
        port soilOut : ~SoilSensorPort;
        
        connect gps.dataOut to gpsOut;
        connect camera.dataOut to camOut;
        connect soil.dataOut to soilOut;
    }
    
    part def PlantingMechanism {
        attribute seedHopperCapacity : VolumeL = 50;
        port controlIn : ~ToolPort;
    }
    
    part def WateringSystem {
        attribute tankCapacity : VolumeL = 100;
        attribute currentVolume : VolumeL = 100;
        port controlIn : ~ToolPort;
    }
    
    part def HarvestingMechanism {
        attribute storageBinCapacity : VolumeL = 200;
        attribute currentVolume : VolumeL = 0;
        port controlIn : ~ToolPort;
    }
    
    part def ToolSuite {
        part planter : PlantingMechanism;
        part waterer : WateringSystem;
        part harvester : HarvestingMechanism;
        
        port controlIn : ToolPort;
        
        connect controlIn to planter.controlIn;
        connect controlIn to waterer.controlIn;
        connect controlIn to harvester.controlIn;
    }
    
    part def MobilityPlatform {
        attribute vehicleType : String = "Wheeled";
        port navIn : ~DrivePort;
    }
    
    part def CentralControlUnit {
        port gpsIn : ~GPSPort;
        port camIn : ~CameraPort;
        port soilIn : ~SoilSensorPort;
        
        port navOut : DrivePort;
        port toolOut : ToolPort;
        port powerIn : ~PowerPort;
        
        attribute currentMoisture : Percentage;
        attribute currentBattery : Percentage;
    }
    
    part def AgriculturalRobot :> AgriBotRequirements {
        part ccu : CentralControlUnit;
        part sensors : SensorSuite;
        part tools : ToolSuite;
        part mobility : MobilityPlatform;
        part battery : BatteryPack;
        
        attribute targetMoisture : Percentage = 40;
        attribute minBattery : Percentage = 20;
        attribute fieldReady : Boolean = false;
        attribute cropReady : Boolean = false;
        
        port chargePort : ~PowerPort;
        
        connect sensors.gpsOut to ccu.gpsIn;
        connect sensors.camOut to ccu.camIn;
        connect sensors.soilOut to ccu.soilIn;
        connect ccu.navOut to mobility.navIn;
        connect ccu.toolOut to tools.controlIn;
        connect battery.powerOut to ccu.powerIn;
        connect chargePort to battery.powerIn;
        
        state agriBotStateMachine {
            state Off;
            state Surveying;
            state Planting;
            state Watering;
            state Harvesting;
            state Recharging;
            
            transition off_to_surveying first Off -> Surveying;
            
            transition surveying_to_planting Surveying -> Planting when fieldReady;
            transition planting_to_surveying Planting -> Surveying when !fieldReady;
            
            transition surveying_to_watering Surveying -> Watering when (ccu.currentMoisture < targetMoisture);
            transition watering_to_surveying Watering -> Surveying when (ccu.currentMoisture >= targetMoisture);
            
            transition surveying_to_harvesting Surveying -> Harvesting when cropReady;
            transition harvesting_to_surveying Harvesting -> Surveying when !cropReady;
            
            transition any_to_recharging Surveying, Planting, Watering, Harvesting -> Recharging when (battery.chargeLevel < minBattery);
            transition recharging_to_surveying Recharging -> Surveying when (battery.chargeLevel >= 100);
        }
    }
    
    part def AgriBotSystem {
        part robot : AgriculturalRobot;
        part station : ChargingStation;
        
        connect station.powerOut to robot.chargePort;
    }
}
