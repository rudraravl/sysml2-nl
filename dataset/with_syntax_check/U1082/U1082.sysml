package 'Home of the Future' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetting :> TemperatureValue;
    attribute def IlluminanceLevel :> IlluminanceValue;
    attribute def HumidityLevel :> Real;
    attribute def AirQualityIndex :> Real;
    attribute def OccupancyState :> Boolean;
    attribute def SecurityLevel :> Integer;
    
    enum def ClimateMode {
        heating;
        cooling;
        ventilation;
        auto;
        off;
    }
    
    enum def LightingScene {
        morning;
        day;
        evening;
        night;
        away;
        entertainment;
    }
    
    enum def SecurityState {
        disarmed;
        armedStay;
        armedAway;
        alarm;
    }
    
    item def EnvironmentalData {
        attribute temperature : TemperatureSetting;
        attribute humidity : HumidityLevel;
        attribute airQuality : AirQualityIndex;
        attribute illuminance : IlluminanceLevel;
        attribute timestamp : Real;
    }
    
    item def OccupancyData {
        attribute roomId : String;
        attribute occupied : OccupancyState;
        attribute personCount : Integer;
        attribute timestamp : Real;
    }
    
    item def ClimateCommand {
        attribute mode : ClimateMode;
        attribute targetTemperature : TemperatureSetting;
        attribute targetHumidity : HumidityLevel;
        attribute fanSpeed : Real;
    }
    
    item def LightingCommand {
        attribute scene : LightingScene;
        attribute brightness : Real;
        attribute colorTemperature : Real;
        attribute zoneId : String;
    }
    
    item def SecurityCommand {
        attribute state : SecurityState;
        attribute zoneId : String;
        attribute alertLevel : Integer;
    }
    
    item def EnergyCommand {
        attribute solarPriority : Boolean;
        attribute batteryChargeTarget : Real;
        attribute gridPowerLimit : PowerValue;
    }
    
    port def EnvironmentalSensorPort {
        out envData : EnvironmentalData;
    }
    
    port def OccupancySensorPort {
        out occData : OccupancyData;
    }
    
    port def ClimateControlPort {
        in climateCmd : ClimateCommand;
        out currentStatus : EnvironmentalData;
    }
    
    port def LightingControlPort {
        in lightCmd : LightingCommand;
        out currentLevel : IlluminanceLevel;
    }
    
    port def SecurityControlPort {
        in secCmd : SecurityCommand;
        out secStatus : SecurityState;
    }
    
    port def EnergyManagementPort {
        in energyCmd : EnergyCommand;
        out solarOutput : PowerValue;
        out batteryLevel : Real;
        out gridConsumption : PowerValue;
    }
    
    part def EnvironmentalSensor {
        port dataOut : EnvironmentalSensorPort;
        
        action def SenseEnvironment {
            out reading : EnvironmentalData;
        }
    }
    
    part def OccupancySensor {
        port dataOut : OccupancySensorPort;
        
        action def DetectOccupancy {
            out presence : OccupancyData;
        }
    }
    
    part def ClimateControlSystem {
        port controlPort : ClimateControlPort;
        port sensorPort : EnvironmentalSensorPort;
        
        attribute currentMode : ClimateMode;
        attribute setpoint : TemperatureSetting;
        attribute powerConsumption : PowerValue;
        
        action def RegulateClimate {
            in targetTemp : TemperatureSetting;
            in currentTemp : TemperatureSetting;
            in occupied : OccupancyState;
            out climateCmd : ClimateCommand;
            
            first start;
            then action evaluateConditions {
                in target = targetTemp;
                in current = currentTemp;
                out tempDelta : Real;
            }
            then decide;
                if evaluateConditions.tempDelta > 2.0 then activateHeating;
                if evaluateConditions.tempDelta < -2.0 then activateCooling;
                if evaluateConditions.tempDelta >= -2.0 and evaluateConditions.tempDelta <= 2.0 then maintainMode;
            
            action activateHeating {
                out heatingCmd : ClimateCommand;
            }
            
            action activateCooling {
                out coolingCmd : ClimateCommand;
            }
            
            action maintainMode {
                out autoCmd : ClimateCommand;
            }
            
            then done;
        }
    }
    
    part def IntelligentLightingSystem {
        port controlPort : LightingControlPort;
        port sensorPort : EnvironmentalSensorPort;
        port occupancyPort : OccupancySensorPort;
        
        attribute currentScene : LightingScene;
        attribute brightness : Real;
        attribute powerConsumption : PowerValue;
        
        action def AdjustLighting {
            in ambientLight : IlluminanceLevel;
            in occupied : OccupancyState;
            in timeOfDay : Real;
            out lightCmd : LightingCommand;
            
            first start;
            then action determineScene {
                in time = timeOfDay;
                in presence = occupied;
                out selectedScene : LightingScene;
            }
            then action calculateBrightness {
                in ambient = ambientLight;
                in scene = determineScene.selectedScene;
                out level : Real;
            }
            then done;
        }
    }
    
    part def SecuritySystem {
        port controlPort : SecurityControlPort;
        port occupancyPort : OccupancySensorPort;
        
        attribute currentState : SecurityState;
        attribute intrusionDetected : Boolean;
        
        action def MonitorSecurity {
            out alert : SecurityCommand;
        }
    }
    
    part def EnergyManagementSystem {
        port energyPort : EnergyManagementPort;
        
        attribute solarGeneration : PowerValue;
        attribute batteryCapacity : Real;
        attribute batteryCharge : Real;
        attribute gridPower : PowerValue;
        attribute totalConsumption : PowerValue;
        
        action def OptimizeEnergy {
            in solarAvailable : PowerValue;
            in batteryLevel : Real;
            in currentDemand : PowerValue;
            out energyCmd : EnergyCommand;
            
            first start;
            then action assessSources {
                in solar = solarAvailable;
                in battery = batteryLevel;
                out useSolar : Boolean;
                out useBattery : Boolean;
                out useGrid : Boolean;
            }
            then decide;
                if assessSources.useSolar then prioritizeSolar;
                if assessSources.useBattery then useBatteryPower;
                if assessSources.useGrid then useGridPower;
            
            action prioritizeSolar {
                out solarCmd : EnergyCommand;
            }
            
            action useBatteryPower {
                out batteryCmd : EnergyCommand;
            }
            
            action useGridPower {
                out gridCmd : EnergyCommand;
            }
            
            then done;
        }
    }
    
    part def CentralIntelligenceHub {
        attribute learningEnabled : Boolean;
        attribute operatingMode : String;
        attribute userPreferences : String[*];
        
        action def CoordinateHome {
            in envData : EnvironmentalData;
            in occData : OccupancyData;
            in energyData : PowerValue;
            out climateControl : ClimateCommand;
            out lightControl : LightingCommand;
            out securityControl : SecurityCommand;
            out energyControl : EnergyCommand;
            
            first start;
            then merge continuousMonitoring;
            
            action gatherData {
                in environment = envData;
                in occupancy = occData;
                in energy = energyData;
                out aggregatedData : String;
            }
            
            then action analyzePatterns {
                in data = gatherData.aggregatedData;
                out needsClimateAdjust : Boolean;
                out needsLightAdjust : Boolean;
                out needsSecurityUpdate : Boolean;
                out needsEnergyOptimization : Boolean;
            }
            
            then decide;
                if analyzePatterns.needsClimateAdjust then adjustClimate;
                if analyzePatterns.needsLightAdjust then adjustLighting;
                if analyzePatterns.needsSecurityUpdate then updateSecurity;
                if analyzePatterns.needsEnergyOptimization then optimizeEnergy;
            
            action adjustClimate {
                out cmd : ClimateCommand;
            }
            
            action adjustLighting {
                out cmd : LightingCommand;
            }
            
            action updateSecurity {
                out cmd : SecurityCommand;
            }
            
            action optimizeEnergy {
                out cmd : EnergyCommand;
            }
            
            merge afterAdjustments
                first adjustClimate
                first adjustLighting
                first updateSecurity
                first optimizeEnergy;
            
            then action learnFromInteractions {
                in userOverrides : String[*];
            }
            
            then continuousMonitoring;
            then done;
        }
    }
    
    part def SmartAppliance {
        port energyPort : EnergyManagementPort;
        
        attribute powerDraw : PowerValue;
        attribute operationalState : String;
        attribute scheduledOperation : Boolean;
        
        action def OperateAppliance {
            in energyAvailable : PowerValue;
            in scheduledTime : Real;
            out actualConsumption : PowerValue;
        }
    }
    
    requirement def FutureHomeRequirements {
        doc /* 
            The Home of the Future system shall provide an intelligent, adaptive living environment
            that optimizes comfort, security, and energy efficiency through seamless integration
            of climate control, lighting, security, and energy management subsystems.
        */
        
        requirement <'REQ-001'> primaryFunction {
            doc /* 
                The system shall autonomously manage all home subsystems to maintain optimal
                living conditions while minimizing energy consumption and maximizing security.
            */
        }
        
        requirement <'REQ-002'> comfortManagement {
            doc /* 
                The system shall maintain indoor temperature between 20°C and 24°C and
                relative humidity between 40% and 60% when occupied.
            */
        }
        
        requirement <'REQ-003'> energyEfficiency {
            doc /* 
                The system shall reduce total energy consumption by at least 40% compared
                to conventional homes through intelligent load management and renewable
                energy prioritization.
            */
        }
        
        requirement <'REQ-004'> securityResponse {
            doc /* 
                The system shall detect security breaches and initiate alarm protocols
                within 3 seconds of detection.
            */
        }
        
        requirement <'REQ-005'> adaptiveLearning {
            doc /* 
                The system shall learn occupant behavior patterns and preferences over
                a 30-day period and automatically adjust operations to match learned patterns.
            */
        }
        
        requirement <'REQ-006'> renewableIntegration {
            doc /* 
                The system shall prioritize solar energy when available and maintain
                battery storage at minimum 50% capacity for backup power.
            */
        }
    }
    
    part futureHome : FutureHome {
        doc /* 
            The Home of the Future is an intelligent residential ecosystem that seamlessly
            integrates environmental control, lighting, security, and energy management to
            create an adaptive living space. The system continuously monitors occupancy patterns,
            environmental conditions, and energy availability to automatically optimize comfort
            while minimizing resource consumption.
            
            The primary function is to provide a self-regulating home environment that learns
            from occupant behavior, anticipates needs, and proactively adjusts all subsystems
            to maintain ideal living conditions. Through coordinated control of climate, lighting,
            security, and energy systems, the home adapts to daily routines, seasonal changes,
            and unexpected events while maximizing efficiency and sustainability.
        */
        
        part hub : CentralIntelligenceHub {
            perform action orchestrate[*] ordered references CoordinateHome;
        }
        
        part climateSystem : ClimateControlSystem {
            perform orchestrate.adjustClimate;
        }
        
        part lightingSystem : IntelligentLightingSystem {
            perform orchestrate.adjustLighting;
        }
        
        part securitySystem : SecuritySystem {
            perform orchestrate.updateSecurity;
        }
        
        part energySystem : EnergyManagementSystem {
            perform orchestrate.optimizeEnergy;
        }
        
        part envSensors : EnvironmentalSensor[8];
        part occSensors : OccupancySensor[12];
        part appliances : SmartAppliance[15];
        
        connection envDataFlow connect envSensors.dataOut to climateSystem.sensorPort;
        connection envToLighting connect envSensors.dataOut to lightingSystem.sensorPort;
        connection occToLighting connect occSensors.dataOut to lightingSystem.occupancyPort;
        connection occToSecurity connect occSensors.dataOut to securitySystem.occupancyPort;
        connection climateControl connect hub to climateSystem.controlPort;
        connection lightControl connect hub to lightingSystem.controlPort;
        connection securityControl connect hub to securitySystem.controlPort;
        connection energyControl connect hub to energySystem.energyPort;
        connection applianceEnergy connect appliances.energyPort to energySystem.energyPort;
        
        satisfy futureHomeRequirements;
    }
    
    part def FutureHome;
    
    requirement futureHomeRequirements : FutureHomeRequirements;
}
