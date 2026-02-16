package BuildingAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> TemperatureValue;
    attribute def HumidityLevel :> Real;
    attribute def IlluminanceLevel :> IlluminanceValue;
    attribute def CO2Level :> Real;
    attribute def OccupancyCount :> Integer;
    attribute def EnergyConsumption :> PowerValue;
    
    enum def HVACMode {
        enum heating;
        enum cooling;
        enum ventilation;
        enum off;
    }
    
    enum def LightingMode {
        enum automatic;
        enum manual;
        enum off;
    }
    
    enum def OccupancyState {
        enum occupied;
        enum unoccupied;
        enum partiallyOccupied;
    }
    
    enum def TimeOfDay {
        enum morning;
        enum daytime;
        enum evening;
        enum night;
    }
    
    item def SensorData {
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityLevel;
        attribute illuminance : IlluminanceLevel;
        attribute co2 : CO2Level;
        attribute occupancy : OccupancyCount;
    }
    
    item def HVACCommand {
        attribute mode : HVACMode;
        attribute targetTemperature : TemperatureSetpoint;
        attribute fanSpeed : Real;
    }
    
    item def LightingCommand {
        attribute mode : LightingMode;
        attribute brightness : Real;
        attribute zoneActive : Boolean;
    }
    
    item def SecurityCommand {
        attribute armed : Boolean;
        attribute alertActive : Boolean;
    }
    
    port def SensorPort {
        out sensorData : SensorData;
    }
    
    port def HVACControlPort {
        in hvacCommand : HVACCommand;
    }
    
    port def LightingControlPort {
        in lightingCommand : LightingCommand;
    }
    
    port def SecurityControlPort {
        in securityCommand : SecurityCommand;
        out alarmStatus : Boolean;
    }
    
    part def TemperatureSensor {
        port output : SensorPort;
        attribute currentReading : TemperatureValue;
    }
    
    part def HumiditySensor {
        port output : SensorPort;
        attribute currentReading : HumidityLevel;
    }
    
    part def OccupancySensor {
        port output : SensorPort;
        attribute currentCount : OccupancyCount;
        attribute motionDetected : Boolean;
    }
    
    part def LightSensor {
        port output : SensorPort;
        attribute currentIlluminance : IlluminanceLevel;
    }
    
    part def AirQualitySensor {
        port output : SensorPort;
        attribute currentCO2 : CO2Level;
    }
    
    part def HVACUnit {
        port controlInput : HVACControlPort;
        attribute operatingMode : HVACMode;
        attribute currentTemperature : TemperatureValue;
        attribute powerConsumption : PowerValue;
    }
    
    part def LightingFixture {
        port controlInput : LightingControlPort;
        attribute currentBrightness : Real;
        attribute powerConsumption : PowerValue;
    }
    
    part def SecuritySystem {
        port controlInterface : SecurityControlPort;
        attribute systemArmed : Boolean;
        attribute intrusionDetected : Boolean;
    }
    
    part def EnergyMeter {
        attribute totalConsumption : EnergyConsumption;
        attribute instantaneousPower : PowerValue;
        attribute peakDemand : PowerValue;
    }
    
    action def ReadSensors {
        out temperature : TemperatureValue;
        out humidity : HumidityLevel;
        out illuminance : IlluminanceLevel;
        out co2 : CO2Level;
        out occupancy : OccupancyCount;
    }
    
    action def DetermineOccupancyState {
        in occupancyCount : OccupancyCount;
        in timeOfDay : TimeOfDay;
        out occupancyState : OccupancyState;
    }
    
    action def CalculateHVACSetpoint {
        in currentTemp : TemperatureValue;
        in occupancyState : OccupancyState;
        in timeOfDay : TimeOfDay;
        out targetTemp : TemperatureSetpoint;
        out mode : HVACMode;
        out fanSpeed : Real;
    }
    
    action def CalculateLightingLevel {
        in currentIlluminance : IlluminanceLevel;
        in occupancyState : OccupancyState;
        in timeOfDay : TimeOfDay;
        out targetBrightness : Real;
        out lightingMode : LightingMode;
    }
    
    action def MonitorAirQuality {
        in co2Level : CO2Level;
        out ventilationRequired : Boolean;
    }
    
    action def OptimizeEnergy {
        in currentConsumption : EnergyConsumption;
        in occupancyState : OccupancyState;
        in timeOfDay : TimeOfDay;
        out hvacAdjustment : Real;
        out lightingAdjustment : Real;
    }
    
    action def ManageSecurity {
        in occupancyState : OccupancyState;
        in timeOfDay : TimeOfDay;
        in intrusionDetected : Boolean;
        out armSystem : Boolean;
        out triggerAlarm : Boolean;
    }
    
    action def AutomateBuildingOperations {
        first start;
        then merge controlLoop;
        
        action readSensors : ReadSensors {
            out temperature : TemperatureValue;
            out humidity : HumidityLevel;
            out illuminance : IlluminanceLevel;
            out co2 : CO2Level;
            out occupancy : OccupancyCount;
        }
        
        then action determineOccupancy : DetermineOccupancyState {
            in occupancyCount = readSensors.occupancy;
            in timeOfDay : TimeOfDay;
            out occupancyState : OccupancyState;
        }
        
        then action calculateHVAC : CalculateHVACSetpoint {
            in currentTemp = readSensors.temperature;
            in occupancyState = determineOccupancy.occupancyState;
            in timeOfDay = determineOccupancy.timeOfDay;
            out targetTemp : TemperatureSetpoint;
            out mode : HVACMode;
            out fanSpeed : Real;
        }
        
        then action calculateLighting : CalculateLightingLevel {
            in currentIlluminance = readSensors.illuminance;
            in occupancyState = determineOccupancy.occupancyState;
            in timeOfDay = determineOccupancy.timeOfDay;
            out targetBrightness : Real;
            out lightingMode : LightingMode;
        }
        
        then action monitorAir : MonitorAirQuality {
            in co2Level = readSensors.co2;
            out ventilationRequired : Boolean;
        }
        
        then decide;
            if monitorAir.ventilationRequired then increaseVentilation;
        
        action increaseVentilation {
            then assign calculateHVAC.mode := HVACMode::ventilation;
        }
        
        then action optimizeEnergy : OptimizeEnergy {
            in currentConsumption : EnergyConsumption;
            in occupancyState = determineOccupancy.occupancyState;
            in timeOfDay = determineOccupancy.timeOfDay;
            out hvacAdjustment : Real;
            out lightingAdjustment : Real;
        }
        
        then action manageSecurity : ManageSecurity {
            in occupancyState = determineOccupancy.occupancyState;
            in timeOfDay = determineOccupancy.timeOfDay;
            in intrusionDetected : Boolean;
            out armSystem : Boolean;
            out triggerAlarm : Boolean;
        }
        
        then controlLoop;
    }
    
    state def BuildingOperationalState {
        entry; then normalOperation;
        
        state normalOperation {
            entry; then occupiedMode;
            
            state occupiedMode;
            state unoccupiedMode;
            
            transition occupiedMode to unoccupiedMode
                accept OccupancyChange;
            
            transition unoccupiedMode to occupiedMode
                accept OccupancyChange;
        }
        
        state emergencyMode;
        
        transition normalOperation to emergencyMode
            accept EmergencyTrigger;
        
        transition emergencyMode to normalOperation
            accept EmergencyReset;
    }
    
    part def BuildingAutomationController;
    
    part buildingAutomationController : BuildingAutomationController {
        attribute buildingName : String;
        attribute totalZones : Integer;
        attribute operatingSchedule : String;
        
        part temperatureSensors : TemperatureSensor[8];
        part humiditySensors : HumiditySensor[8];
        part occupancySensors : OccupancySensor[12];
        part lightSensors : LightSensor[8];
        part airQualitySensors : AirQualitySensor[4];
        
        part hvacUnits : HVACUnit[4];
        part lightingFixtures : LightingFixture[24];
        part securitySystem : SecuritySystem;
        part energyMeter : EnergyMeter;
        
        perform action automationControl[*] ordered references AutomateBuildingOperations;
        
        exhibit state operationalState : BuildingOperationalState;
        
        connection tempToHVAC connect temperatureSensors[1].output to hvacUnits[1].controlInput;
        connection occToLighting connect occupancySensors[1].output to lightingFixtures[1].controlInput;
        connection airQualityToHVAC connect airQualitySensors[1].output to hvacUnits[1].controlInput;
    }
    
    requirement def ComfortRequirement {
        doc /* The building automation system shall maintain indoor environmental 
                conditions within comfortable ranges for occupants. */
        
        require constraint temperatureComfort {
            20.0 <= buildingAutomationController.hvacUnits[1].currentTemperature and
            buildingAutomationController.hvacUnits[1].currentTemperature <= 24.0
        }
        
        require constraint humidityComfort {
            30.0 <= buildingAutomationController.humiditySensors[1].currentReading and
            buildingAutomationController.humiditySensors[1].currentReading <= 60.0
        }
    }
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The building automation system shall optimize energy consumption 
                while maintaining occupant comfort. */
        
        require constraint energyReduction {
            buildingAutomationController.energyMeter.totalConsumption <= 
            0.70 * baselineEnergyConsumption
        }
        
        attribute baselineEnergyConsumption : EnergyConsumption;
    }
    
    requirement def SecurityRequirement {
        doc /* The building automation system shall provide automated security 
                monitoring and response capabilities. */
        
        require constraint intrusionResponse {
            buildingAutomationController.securitySystem.intrusionDetected == true
            implies buildingAutomationController.securitySystem.systemArmed == true
        }
    }
    
    requirement def AirQualityRequirement {
        doc /* The building automation system shall maintain acceptable indoor 
                air quality levels. */
        
        require constraint co2Limit {
            buildingAutomationController.airQualitySensors[1].currentCO2 <= 1000.0
        }
    }
    
    requirement def OccupancyAdaptationRequirement {
        doc /* The building automation system shall automatically adapt operations 
                based on real-time occupancy detection. */
        
        assume constraint occupancyDetection {
            buildingAutomationController.occupancySensors[1].currentCount > 0
            implies buildingAutomationController.hvacUnits[1].operatingMode != HVACMode::off
        }
    }
    
    requirement <'BAS-MAIN-001'> buildingAutomationMission {
        doc /* The building automation system shall autonomously monitor and control 
                HVAC, lighting, security, and energy systems to optimize occupant comfort, 
                safety, and operational efficiency while minimizing energy consumption 
                and environmental impact. */
        
        require comfortReq : ComfortRequirement;
        require energyReq : EnergyEfficiencyRequirement;
        require securityReq : SecurityRequirement;
        require airQualityReq : AirQualityRequirement;
        require occupancyReq : OccupancyAdaptationRequirement;
    }
}
