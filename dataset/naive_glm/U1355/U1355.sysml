package SmartBuildingAutomationSystem {
    import ScalarValues::*;
    
    package Definitions {
        attribute def Temperature {
            value : Real;
            unit "Celsius";
        }
        attribute def OccupancyCount {
            value : Integer;
        }
        attribute def Brightness {
            value : Real;
            unit "Percent";
        }
        attribute def ColorTemperature {
            value : Real;
            unit "Kelvin";
        }
        
        item def SensorData {
            attribute temp : Temperature;
            attribute occupancy : OccupancyCount;
            attribute zoneId : String;
        }
        
        item def LightControlCommand {
            attribute powerState : String;
            attribute brightness : Brightness;
            attribute colorTemp : ColorTemperature;
        }
        
        item def ThermostatControlCommand {
            attribute targetTemp : Temperature;
            attribute mode : String;
        }
        
        item def CloudSyncData {
            attribute timestamp : String;
            attribute data : String;
        }
    }
    
    package Requirements {
        requirement def OptimizeEnergyEfficiency {
            doc "The system shall optimize energy efficiency by automating lighting and climate control."
        }
        requirement def MaintainOccupantComfort {
            doc "The system shall maintain occupant comfort by adjusting environmental conditions based on occupancy."
        }
        requirement def DeviceInteroperability {
            doc "The system shall ensure devices from different manufacturers work together seamlessly."
        }
    }
    
    package Components {
        port def IoTDevicePort {
            out sensorData : Definitions::SensorData;
            in lightCommand : Definitions::LightControlCommand;
            in thermostatCommand : Definitions::ThermostatControlCommand;
        }
        
        port def CloudPort {
            out syncData : Definitions::CloudSyncData;
            in remoteCommand : String;
        }
        
        part def TemperatureOccupancySensor {
            port ioPort : IoTDevicePort;
            attribute zoneId : String;
            
            action def MeasureEnvironment {
                out data : Definitions::SensorData;
            }
            perform measure : MeasureEnvironment;
        }
        
        part def SmartLight {
            port ioPort : IoTDevicePort;
            attribute currentBrightness : Definitions::Brightness;
            attribute currentColorTemp : Definitions::ColorTemperature;
            
            action def AdjustLight {
                in cmd : Definitions::LightControlCommand;
            }
            perform adjust : AdjustLight;
        }
        
        part def SmartThermostat {
            port ioPort : IoTDevicePort;
            attribute currentTargetTemp : Definitions::Temperature;
            attribute currentMode : String;
            
            action def AdjustClimate {
                in cmd : Definitions::ThermostatControlCommand;
            }
            perform adjust : AdjustClimate;
        }
        
        part def CloudBridge {
            port cloudPort : ~CloudPort;
            
            action def SyncData {
                in data : Definitions::CloudSyncData;
            }
            perform sync : SyncData;
        }
    }
    
    package System {
        part def AutomationEngine {
            attribute rules : String;
            
            action def ProcessSensorData {
                in data : Definitions::SensorData;
                out lightCmd : Definitions::LightControlCommand;
                out thermoCmd : Definitions::ThermostatControlCommand;
            }
            perform process : ProcessSensorData;
        }
        
        part def BuildingGateway {
            port devicePorts : ~Components::IoTDevicePort[*];
            port cloudPort : Components::CloudPort;
            
            part engine : AutomationEngine;
            
            state def GatewayStates {
                entry; 
                state Provisioning;
                state Operational {
                    state CollectingData;
                    state ProcessingData;
                    state ExecutingCommands;
                    state SyncingData;
                    transition collect_to_process 
                        from CollectingData to ProcessingData 
                        when (true);
                    transition process_to_exec 
                        from ProcessingData to ExecutingCommands 
                        when (true);
                    transition exec_to_sync 
                        from ExecutingCommands to SyncingData 
                        when (true);
                    transition sync_to_collect 
                        from SyncingData to CollectingData 
                        when (true);
                }
                transition provisioning_to_operational 
                    from Provisioning to Operational 
                    when (true);
            }
            
            perform states : GatewayStates;
        }
    }
    
    package Building {
        part buildingSystem {
            part gateway : System::BuildingGateway;
            part sensors : Components::TemperatureOccupancySensor[*];
            part lights : Components::SmartLight[*];
            part thermostats : Components::SmartThermostat[*];
            part cloudBridge : Components::CloudBridge;
            
            satisfy Requirements::OptimizeEnergyEfficiency;
            satisfy Requirements::MaintainOccupantComfort;
            satisfy Requirements::DeviceInteroperability;
            
            connection def SensorToGateway {
                end source : Components::IoTDevicePort;
                end target : ~Components::IoTDevicePort;
            }
            
            connection def GatewayToActuator {
                end source : ~Components::IoTDevicePort;
                end target : Components::IoTDevicePort;
            }
            
            connection def GatewayToCloud {
                end source : Components::CloudPort;
                end target : ~Components::CloudPort;
            }
            
            connection sensorConnections : SensorToGateway 
                connect sensors.ioPort to gateway.devicePorts;
                
            connection lightConnections : GatewayToActuator 
                connect gateway.devicePorts to lights.ioPort;
                
            connection thermoConnections : GatewayToActuator 
                connect gateway.devicePorts to thermostats.ioPort;
                
            connection cloudConnections : GatewayToCloud 
                connect gateway.cloudPort to cloudBridge.cloudPort;
        }
    }
}
