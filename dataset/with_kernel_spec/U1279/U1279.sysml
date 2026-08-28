package DaintreeLightingControl {
    private import ScalarValues::*;
    
    attribute def LightLevel {
        attribute value : Real;
        attribute unit : String = "lux";
    }
    
    attribute def DimmingLevel {
        attribute value : Real;
        attribute unit : String = "percent";
    }
    
    attribute def PowerConsumption {
        attribute value : Real;
        attribute unit : String = "watt";
    }
    
    item def OccupancyStatus {
        attribute isOccupied : Boolean;
    }
    
    item def DaylightReport {
        attribute level : LightLevel;
    }
    
    item def DimmingCommand {
        attribute level : DimmingLevel;
    }
    
    item def PowerReport {
        attribute consumption : PowerConsumption;
    }
    
    port def OccupancyStatusPort {
        out occupancyStatus : OccupancyStatus;
    }
    
    port def DaylightLevelPort {
        out daylightReport : DaylightReport;
    }
    
    port def DimmingCommandPort {
        in dimmingCommand : DimmingCommand;
    }
    
    port def PowerReportPort {
        out powerReport : PowerReport;
    }
    
    port def MeshNetworkPort {
        inout meshData : String;
    }
    
    part def ControllableBallast {
        port controlPort : DimmingCommandPort;
        port powerPort : PowerReportPort;
        
        action ballastBehavior {
            action receiveDimming accept DimmingCommand via controlPort;
            then action adjustLight {
            }
            then action reportPower send new PowerReport() to powerPort;
        }
    }
    
    part def LightingFixture {
        port meshPort : MeshNetworkPort;
        port dimmingPort : DimmingCommandPort;
        port powerPort : PowerReportPort;
        
        part ballast : ControllableBallast {
            port :>> controlPort = dimmingPort;
            port :>> powerPort = powerPort;
        }
        
        action fixtureBehavior {
            action receiveDimmingCommand accept DimmingCommand via dimmingPort;
            then action adjustBallast {
            }
            then action reportPower send new PowerReport() to powerPort;
        }
    }
    
    part def OccupancySensor {
        port meshPort : MeshNetworkPort;
        port statusPort : OccupancyStatusPort;
        
        action sensorBehavior {
            action detectMotion {
            }
            then action broadcastStatus send new OccupancyStatus() to statusPort;
        }
    }
    
    part def DaylightSensor {
        port meshPort : MeshNetworkPort;
        port lightLevelPort : DaylightLevelPort;
        
        action sensorBehavior {
            action measureLight {
            }
            then action reportLightLevel send new DaylightReport() to lightLevelPort;
        }
    }
    
    action def ControllerControlLogic {
        in occupancy : OccupancyStatus;
        in daylight : DaylightReport;
        out command : DimmingCommand;
        
        action receiveOccupancy accept OccupancyStatus;
        action receiveDaylight accept DaylightReport;
        then action decideDimming {
        }
        then action sendDimmingCommand send new DimmingCommand() to command;
    }
    
    state def ControllerStates {
        entry; then vacant;
        state vacant;
        accept OccupancyStatus then occupied;
        state occupied {
            accept OccupancyStatus then vacant;
        }
    }
    
    part def WirelessAreaController {
        port meshPort : MeshNetworkPort;
        port occupancyIn : OccupancyStatusPort;
        port daylightIn : DaylightLevelPort;
        port dimmingOut : DimmingCommandPort;
        
        attribute isOccupied : Boolean;
        attribute ambientLight : LightLevel;
        
        action controlLogic {
            action receiveOccupancy accept OccupancyStatus via occupancyIn;
            action receiveDaylight accept DaylightReport via daylightIn;
            then action decideDimming {
            }
            then action sendDimmingCommand send new DimmingCommand() to dimmingOut;
        }
        
        state controllerStates : ControllerStates;
    }
    
    part def NetworkGateway {
        port meshPort : MeshNetworkPort;
        port bmsPort : MeshNetworkPort;
        
        action gatewayBehavior {
            action coordinateTraffic {
            }
            then action bridgeData {
            }
        }
    }
    
    part def DaintreeSystem {
        port gatewayPort : MeshNetworkPort;
        
        part gateway : NetworkGateway {
            port :>> meshPort;
        }
        
        part areaController : WirelessAreaController {
            port :>> meshPort;
        }
        
        part fixtures[*] : LightingFixture {
            port :>> meshPort;
        }
        
        part occupancySensors[*] : OccupancySensor {
            port :>> meshPort;
        }
        
        part daylightSensors[*] : DaylightSensor {
            port :>> meshPort;
        }
        
        connect gateway.meshPort to areaController.meshPort;
        connect areaController.meshPort to fixtures.meshPort;
        connect occupancySensors.meshPort to areaController.meshPort;
        connect daylightSensors.meshPort to areaController.meshPort;
        
        flow occupancyFlow of OccupancyStatus 
            from occupancySensors.statusPort.occupancyStatus to areaController.occupancyIn.occupancyStatus;
        flow daylightFlow of DaylightReport 
            from daylightSensors.lightLevelPort.daylightReport to areaController.daylightIn.daylightReport;
        flow dimmingFlow of DimmingCommand 
            from areaController.dimmingOut.dimmingCommand to fixtures.dimmingPort.dimmingCommand;
        flow powerFlow of PowerReport 
            from fixtures.powerPort.powerReport to gateway.meshPort;
    }
    
    requirement def EnergyEfficiencyRequirement {
        subject system : DaintreeSystem;
        objective {
            doc "The system shall reduce energy consumption by adjusting lighting based on occupancy and daylight."
        }
    }
    
    requirement def WirelessMeshRequirement {
        subject system : DaintreeSystem;
        objective {
            doc "The system shall operate on a self-organizing wireless mesh network without dedicated control wiring."
        }
    }
    
    requirement def IndividualAddressabilityRequirement {
        subject system : DaintreeSystem;
        objective {
            doc "Each lighting fixture shall be individually addressable on the network."
        }
    }
    
    requirement def EnergyMonitoringRequirement {
        subject system : DaintreeSystem;
        objective {
            doc "Each lighting fixture shall report its energy consumption to the network."
        }
    }
}
