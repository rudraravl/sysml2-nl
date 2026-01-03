package 'Smart House System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> TemperatureValue;
    attribute def HumidityLevel :> Real;
    attribute def LightIntensity :> Real;
    attribute def OccupancyState { occupied : Boolean; }
    attribute def SecurityMode { armed : Boolean; intrusionDetected : Boolean; }
    
    item def SensorReading;
    item def ControlSignal;
    item def PowerSupply :> PowerValue;
    
    port def TemperatureSensorPort { out reading : TemperatureValue; }
    port def HumiditySensorPort { out reading : Real; }
    port def OccupancySensorPort { out occupied : Boolean; }
    port def LightSensorPort { out level : Real; }
    port def MotionSensorPort { out detected : Boolean; }
    port def DoorSensorPort { out isOpen : Boolean; }
    
    port def ClimateControlPort {
        in targetTemp : TemperatureSetpoint;
        in targetHumidity : Real;
        out currentTemp : TemperatureValue;
        out powerDraw : PowerValue;
    }
    
    port def LightingControlPort {
        in enabled : Boolean;
        in intensity : Real;
        out status : Boolean;
        out powerDraw : PowerValue;
    }
    
    port def SecurityControlPort {
        in armSystem : Boolean;
        out alarmActive : Boolean;
        out systemStatus : SecurityMode;
    }
    
    port def EnergyMonitorPort {
        out totalConsumption : PowerValue;
        out peakDemand : PowerValue;
    }
    
    part def TemperatureSensor {
        port output : TemperatureSensorPort;
        attribute currentValue :> ISQ::temperature;
    }
    
    part def HumiditySensor {
        port output : HumiditySensorPort;
        attribute currentValue : Real;
    }
    
    part def OccupancySensor {
        port output : OccupancySensorPort;
        attribute isOccupied : Boolean;
    }
    
    part def LightSensor {
        port output : LightSensorPort;
        attribute ambientLevel : Real;
    }
    
    part def MotionSensor {
        port output : MotionSensorPort;
        attribute motionActive : Boolean;
    }
    
    part def DoorSensor {
        port output : DoorSensorPort;
        attribute doorOpen : Boolean;
    }
    
    part def ClimateControlSystem {
        port control : ClimateControlPort;
        attribute operatingTemp : TemperatureSetpoint;
        attribute operatingHumidity : Real;
        attribute powerUsage :> ISQ::power;
        
        action regulateClimate {
            in desiredTemp : TemperatureSetpoint;
            in currentTemp : TemperatureValue;
            in desiredHumidity : Real;
            out heatingActive : Boolean;
            out coolingActive : Boolean;
            out humidifierActive : Boolean;
        }
    }
    
    part def LightingSystem {
        port control : LightingControlPort;
        attribute lightsActive : Boolean;
        attribute currentIntensity : Real;
        attribute powerUsage :> ISQ::power;
        
        action manageLighting {
            in targetIntensity : Real;
            in occupancyDetected : Boolean;
            in ambientLight : Real;
            out lightLevel : Real;
            out lightsOn : Boolean;
        }
    }
    
    part def SecuritySystem {
        port control : SecurityControlPort;
        attribute systemArmed : Boolean;
        attribute alarmTriggered : Boolean;
        
        state def SecurityStates {
            entry; then disarmed;
            
            state disarmed;
            state armed;
            state alarming;
            
            transition disarmedToArmed
                first disarmed
                then armed;
            
            transition armedToDisarmed
                first armed
                then disarmed;
            
            transition armedToAlarming
                first armed
                then alarming;
            
            transition alarmingToDisarmed
                first alarming
                then disarmed;
        }
    }
    
    part def EnergyManagementSystem {
        port monitor : EnergyMonitorPort;
        attribute totalPower :> ISQ::power;
        attribute peakPower :> ISQ::power;
        attribute energyConsumed :> ISQ::energy;
        
        action trackEnergy {
            in climatePower : PowerValue;
            in lightingPower : PowerValue;
            in appliancePower : PowerValue;
            out totalConsumption : PowerValue;
            out currentPeak : PowerValue;
        }
    }
    
    part def AutomationController {
        attribute comfortTemp : TemperatureSetpoint;
        attribute comfortHumidity : Real;
        attribute energySavingMode : Boolean;
        attribute awayMode : Boolean;
        
        action def AnalyzeSensors {
            in tempReading : TemperatureValue;
            in humidityReading : Real;
            in occupancy : Boolean;
            in ambientLight : Real;
            in motion : Boolean;
            out climateCommand : TemperatureSetpoint;
            out lightingCommand : Boolean;
            out lightIntensity : Real;
        }
        
        action def OptimizeComfort {
            in currentTemp : TemperatureValue;
            in currentHumidity : Real;
            in isOccupied : Boolean;
            in timeOfDay : Real;
            out optimalTemp : TemperatureSetpoint;
            out optimalHumidity : Real;
            out optimalLighting : Real;
        }
        
        action def ManageSecurity {
            in doorStatus : Boolean;
            in motionStatus : Boolean;
            in occupancyStatus : Boolean;
            in armedStatus : Boolean;
            out securityAlert : Boolean;
            out armCommand : Boolean;
        }
        
        action def OptimizeEnergy {
            in totalPower : PowerValue;
            in occupancy : Boolean;
            in timeOfDay : Real;
            out energyMode : Boolean;
            out loadShedding : Boolean;
        }
    }
    
    action def MonitorEnvironment {
        out temperature : TemperatureValue;
        out humidity : Real;
        out occupancy : Boolean;
        out ambientLight : Real;
        out motion : Boolean;
        out doorOpen : Boolean;
    }
    
    action def RegulateClimate {
        in targetTemp : TemperatureSetpoint;
        in targetHumidity : Real;
        in currentTemp : TemperatureValue;
        in currentHumidity : Real;
        out climateAction : Boolean;
    }
    
    action def ManageLighting {
        in occupancy : Boolean;
        in ambientLight : Real;
        in timeOfDay : Real;
        out lightingAction : Boolean;
        out intensity : Real;
    }
    
    action def MonitorSecurity {
        in doorOpen : Boolean;
        in motionDetected : Boolean;
        in occupancy : Boolean;
        in armed : Boolean;
        out alertStatus : Boolean;
    }
    
    action def TrackEnergy {
        in climatePower : PowerValue;
        in lightingPower : PowerValue;
        in occupancy : Boolean;
        out totalPower : PowerValue;
        out optimizationNeeded : Boolean;
    }
    
    part def SmartHouse {
        doc /* 
            A smart house system that autonomously manages climate control, lighting, 
            security, and energy consumption to optimize occupant comfort, safety, and 
            energy efficiency through continuous environmental monitoring and intelligent 
            automation.
        */
        
        part sensorNetwork {
            part tempSensors : TemperatureSensor[5];
            part humiditySensors : HumiditySensor[3];
            part occupancySensors : OccupancySensor[8];
            part lightSensors : LightSensor[6];
            part motionSensors : MotionSensor[10];
            part doorSensors : DoorSensor[6];
        }
        
        part controlSystems {
            part climate : ClimateControlSystem;
            part lighting : LightingSystem;
            part security : SecuritySystem;
            part energy : EnergyManagementSystem;
        }
        
        part controller : AutomationController {
            perform action orchestrateHome;
        }
        
        connection tempConnection connect 
            sensorNetwork::tempSensors[1].output to controller;
        connection humidityConnection connect 
            sensorNetwork::humiditySensors[1].output to controller;
        connection occupancyConnection connect 
            sensorNetwork::occupancySensors[1].output to controller;
        connection lightConnection connect 
            sensorNetwork::lightSensors[1].output to controller;
        connection motionConnection connect 
            sensorNetwork::motionSensors[1].output to controller;
        connection doorConnection connect 
            sensorNetwork::doorSensors[1].output to controller;
            
        connection climateControlConnection connect 
            controller to controlSystems::climate.control;
        connection lightingControlConnection connect 
            controller to controlSystems::lighting.control;
        connection securityControlConnection connect 
            controller to controlSystems::security.control;
        connection energyMonitorConnection connect 
            controlSystems::energy.monitor to controller;
        
        action orchestrateHome {
            first start;
            then merge operationLoop;
            
            action monitorEnvironment : MonitorEnvironment {
                out temperature;
                out humidity;
                out occupancy;
                out ambientLight;
                out motion;
                out doorOpen;
            }
            
            then decide operatingMode;
            
            if monitorEnvironment.occupancy then occupiedMode;
            if !monitorEnvironment.occupancy then unoccupiedMode;
            
            action occupiedMode {
                action regulateClimate : RegulateClimate {
                    in targetTemp = controller.comfortTemp;
                    in targetHumidity = controller.comfortHumidity;
                    in currentTemp = monitorEnvironment.temperature;
                    in currentHumidity = monitorEnvironment.humidity;
                    out climateAction;
                }
                
                flow regulateClimate.climateAction to manageLighting;
                
                action manageLighting : ManageLighting {
                    in occupancy = monitorEnvironment.occupancy;
                    in ambientLight = monitorEnvironment.ambientLight;
                    in timeOfDay = 12.0;
                    out lightingAction;
                    out intensity;
                }
                
                flow manageLighting.lightingAction to monitorSecurity;
                
                action monitorSecurity : MonitorSecurity {
                    in doorOpen = monitorEnvironment.doorOpen;
                    in motionDetected = monitorEnvironment.motion;
                    in occupancy = monitorEnvironment.occupancy;
                    in armed = false;
                    out alertStatus;
                }
                
                flow monitorSecurity.alertStatus to trackEnergy;
                
                action trackEnergy : TrackEnergy {
                    in climatePower = controlSystems::climate.powerUsage;
                    in lightingPower = controlSystems::lighting.powerUsage;
                    in occupancy = monitorEnvironment.occupancy;
                    out totalPower;
                    out optimizationNeeded;
                }
            }
            
            action unoccupiedMode {
                action optimizeEnergy : AutomationController::OptimizeEnergy {
                    in totalPower = controlSystems::energy.totalPower;
                    in occupancy = monitorEnvironment.occupancy;
                    in timeOfDay = 12.0;
                    out energyMode;
                    out loadShedding;
                }
                
                then assign controller.energySavingMode := optimizeEnergy.energyMode;
            }
            
            then operationLoop;
            then done;
        }
    }
    
    requirement def ComfortRequirement {
        doc /* The system shall maintain indoor temperature and humidity within comfort ranges. */
        subject house : SmartHouse;
    }
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall reduce energy consumption by at least 35% compared to non-automated operation. */
        subject house : SmartHouse;
    }
    
    requirement def SecurityRequirement {
        doc /* The system shall detect and respond to security events within 3 seconds. */
        subject house : SmartHouse;
        attribute responseTime : Real;
    }
    
    requirement def AutomationRequirement {
        doc /* The system shall automatically adjust all subsystems based on occupancy, environmental conditions, and time of day. */
        subject house : SmartHouse;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The primary function of the Smart House System is to autonomously manage 
            climate control, lighting, security, and energy consumption to optimize 
            occupant comfort, safety, and energy efficiency through continuous 
            environmental monitoring and intelligent automation.
        */
        subject house : SmartHouse;
        require comfortReq : ComfortRequirement;
        require energyReq : EnergyEfficiencyRequirement;
        require securityReq : SecurityRequirement;
        require automationReq : AutomationRequirement;
    }
    
    part smartHouse : SmartHouse;
}
