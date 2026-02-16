package 'Domus Intelligent Home System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> ISQ::ThermodynamicTemperatureValue;
    attribute def HumidityLevel :> Real;
    attribute def LightIntensity :> Real;
    attribute def PowerLevel :> ISQ::PowerValue;
    attribute def EnergyAmount :> ISQ::EnergyValue;
    
    enum def OccupancyMode {
        unoccupied;
        occupied;
        sleeping;
        away;
    }
    
    enum def ClimateMode {
        heating;
        cooling;
        ventilating;
        idle;
    }
    
    enum def SecurityStatus {
        armed;
        disarmed;
        breached;
        monitoring;
    }
    
    enum def LightingMode {
        automatic;
        manual;
        off;
    }
    
    item def EnvironmentalData {
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute humidity : Real;
        attribute airQuality : Real;
    }
    
    item def OccupancyData {
        attribute mode : OccupancyMode;
        attribute count : Integer;
        attribute lastDetection : ISQ::TimeValue;
    }
    
    item def ClimateCommand {
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        attribute mode : ClimateMode;
    }
    
    item def LightingCommand {
        attribute intensity : Real;
        attribute mode : LightingMode;
    }
    
    item def SecurityCommand {
        attribute status : SecurityStatus;
        attribute zones : String[*];
    }
    
    item def EnergyStatus {
        attribute consumption : ISQ::PowerValue;
        attribute efficiency : Real;
    }
    
    port def EnvironmentalSensorPort {
        out envData : EnvironmentalData;
    }
    
    port def OccupancySensorPort {
        out occData : OccupancyData;
    }
    
    port def ClimateControlPort {
        in command : ClimateCommand;
        out status : EnvironmentalData;
    }
    
    port def LightingControlPort {
        in command : LightingCommand;
        out currentLevel : Real;
    }
    
    port def SecurityControlPort {
        in command : SecurityCommand;
        out alert : SecurityStatus;
    }
    
    port def EnergyMonitorPort {
        out energyStatus : EnergyStatus;
    }
    
    port def CentralControlPort {
        out climateCmd : ClimateCommand;
        in climateStatus : EnvironmentalData;
        out lightCmd : LightingCommand;
        in lightStatus : Real;
        out securityCmd : SecurityCommand;
        in securityAlert : SecurityStatus;
        in energyData : EnergyStatus;
    }
    
    part def EnvironmentalSensor {
        port output : EnvironmentalSensorPort;
        attribute sensorId : String;
    }
    
    part def OccupancySensor {
        port output : OccupancySensorPort;
        attribute detectionRange : ISQ::LengthValue;
    }
    
    part def ClimateControlSystem {
        port control : ClimateControlPort;
        attribute currentMode : ClimateMode;
        attribute powerConsumption : ISQ::PowerValue;
        
        part hvacUnit {
            attribute capacity : ISQ::PowerValue;
        }
        part airHandler {
            attribute flowRate : Real;
        }
    }
    
    part def LightingSystem {
        port control : LightingControlPort;
        attribute numberOfZones : Integer;
        attribute totalPower : ISQ::PowerValue;
        
        part dimmableFixtures[*] {
            attribute maxPower : ISQ::PowerValue;
        }
    }
    
    part def SecuritySystem {
        port control : SecurityControlPort;
        attribute currentStatus : SecurityStatus;
        
        part motionDetectors[*] {
            attribute coverage : ISQ::AreaValue;
        }
        part doorSensors[*];
        part cameras[*] {
            attribute resolution : String;
        }
    }
    
    part def EnergyManagementSystem {
        port monitor : EnergyMonitorPort;
        attribute totalConsumption : ISQ::EnergyValue;
        attribute peakDemand : ISQ::PowerValue;
    }
    
    part def CentralController {
        port systemControl : CentralControlPort;
        attribute operatingMode : OccupancyMode;
    }
    
    part def Room {
        attribute name : String;
        attribute area : ISQ::AreaValue;
        
        part envSensor : EnvironmentalSensor;
        part occSensor : OccupancySensor;
    }
    
    action def SenseEnvironment {
        in sensorData : EnvironmentalData;
        in occupancyData : OccupancyData;
        out aggregatedData : EnvironmentalData;
        out currentOccupancy : OccupancyMode;
    }
    
    action def DetermineClimateAction {
        in currentTemp : ISQ::ThermodynamicTemperatureValue;
        in targetTemp : ISQ::ThermodynamicTemperatureValue;
        in occupied : OccupancyMode;
        out climateCmd : ClimateCommand;
    }
    
    action def ManageLighting {
        in occupancy : OccupancyMode;
        in ambientLight : Real;
        in timeOfDay : ISQ::TimeValue;
        out lightCmd : LightingCommand;
    }
    
    action def MonitorSecurity {
        in occupancy : OccupancyMode;
        in currentStatus : SecurityStatus;
        out securityCmd : SecurityCommand;
    }
    
    action def OptimizeEnergy {
        in climateLoad : ISQ::PowerValue;
        in lightingLoad : ISQ::PowerValue;
        in occupancyPattern : OccupancyMode;
        out optimizationActions : String;
    }
    
    action def ManageDomusOperations {
        in targetTemperature : ISQ::ThermodynamicTemperatureValue;
        in securityMode : SecurityStatus;
        out systemStatus : String;
        
        first start;
        then merge operationLoop;
        
        action sense : SenseEnvironment {
            in sensorData;
            in occupancyData;
            out aggregatedData;
            out currentOccupancy;
        }
        
        then fork parallelOperations;
        
        action climateControl : DetermineClimateAction {
            in currentTemp = sense.aggregatedData.temperature;
            in targetTemp = targetTemperature;
            in occupied = sense.currentOccupancy;
            out climateCmd;
        }
        
        action lightingControl : ManageLighting {
            in occupancy = sense.currentOccupancy;
            in ambientLight;
            in timeOfDay;
            out lightCmd;
        }
        
        action securityControl : MonitorSecurity {
            in occupancy = sense.currentOccupancy;
            in currentStatus = securityMode;
            out securityCmd;
        }
        
        action energyOptimization : OptimizeEnergy {
            in climateLoad;
            in lightingLoad;
            in occupancyPattern = sense.currentOccupancy;
            out optimizationActions;
        }
        
        then join synchronize;
        then operationLoop;
    }
    
    state def DomusOperationalStates {
        entry; then standby;
        
        state standby;
        
        accept OccupantArrival;
        then active;
        
        state active {
            entry; then normalOperation;
            
            state normalOperation;
            
            accept NightTime;
            then nightMode;
            
            state nightMode;
            
            accept DayTime;
            then normalOperation;
        }
        
        accept OccupantDeparture;
        then away;
        
        state away;
        
        accept OccupantArrival;
        then active;
        
        accept EmergencyShutdown;
        then exit;
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def SafetyRequirement;
    
    requirement <'REQ-001'> primaryFunction : FunctionalRequirement {
        doc /* 
            The Domus system shall provide intelligent, automated management of 
            residential environmental comfort, security, lighting, and energy efficiency 
            by continuously monitoring occupancy and environmental conditions, and 
            autonomously adjusting climate control, lighting levels, and security systems 
            to optimize occupant comfort while minimizing energy consumption.
        */
    }
    
    requirement <'REQ-002'> comfortMaintenance : FunctionalRequirement {
        doc /* 
            The system shall maintain indoor temperature within ±1°C of the setpoint 
            when occupied and humidity between 30% and 60%.
        */
        
        require constraint temperatureTolerance {
            doc /* Temperature deviation shall not exceed 1°C from setpoint. */
        }
        
        require constraint humidityRange {
            doc /* Humidity shall remain between 30% and 60%. */
        }
    }
    
    requirement <'REQ-003'> responseTime : PerformanceRequirement {
        doc /* 
            The system shall detect occupancy changes and adjust environmental 
            controls within 30 seconds.
        */
    }
    
    requirement <'REQ-004'> energyEfficiency : PerformanceRequirement {
        doc /* 
            The system shall reduce energy consumption by at least 25% compared 
            to manual operation while maintaining comfort requirements.
        */
    }
    
    requirement <'REQ-005'> securityMonitoring : SafetyRequirement {
        doc /* 
            The system shall continuously monitor all entry points and alert 
            occupants of unauthorized access within 5 seconds.
        */
    }
    
    requirement domusSystemRequirements {
        doc /* Top-level requirements for the Domus intelligent home system. */
        
        require primaryFunction;
        require comfortMaintenance;
        require responseTime;
        require energyEfficiency;
        require securityMonitoring;
    }
    
    part def Domus {
        attribute totalFloorArea : ISQ::AreaValue;
        attribute designOccupancy : Integer;
        attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
        
        part controller : CentralController;
        part livingRoom : Room;
        part masterBedroom : Room;
        part kitchen : Room;
        part bathroom : Room;
        part climateSystem : ClimateControlSystem;
        part lightingSystem : LightingSystem;
        part securitySystem : SecuritySystem;
        part energyManager : EnergyManagementSystem;
    }
    
    part domus : Domus {
        doc /* 
            An intelligent residential dwelling system that autonomously manages 
            environmental comfort, security, lighting, and energy consumption.
            
            The Domus integrates environmental sensing, occupancy detection, climate 
            control, automated lighting, security monitoring, and energy management 
            subsystems to create a responsive, efficient living environment that 
            adapts to occupant presence and preferences while optimizing resource 
            utilization and maintaining safety.
        */
        
        attribute :>> totalFloorArea = 93.0 [SI::'m^2'];
        attribute :>> designOccupancy = 4;
        attribute :>> targetTemperature = 294.15 [SI::K];
        
        part :>> livingRoom {
            attribute :>> name = "Living Room";
            attribute :>> area = 40.0 [SI::'m^2'];
        }
        
        part :>> masterBedroom {
            attribute :>> name = "Master Bedroom";
            attribute :>> area = 25.0 [SI::'m^2'];
        }
        
        part :>> kitchen {
            attribute :>> name = "Kitchen";
            attribute :>> area = 18.0 [SI::'m^2'];
        }
        
        part :>> bathroom {
            attribute :>> name = "Bathroom";
            attribute :>> area = 10.0 [SI::'m^2'];
        }
        
        part :>> climateSystem {
            attribute :>> currentMode = ClimateMode::idle;
            attribute :>> powerConsumption = 3500.0 [SI::W];
        }
        
        part :>> lightingSystem {
            attribute :>> numberOfZones = 4;
            attribute :>> totalPower = 800.0 [SI::W];
        }
        
        part :>> securitySystem {
            attribute :>> currentStatus = SecurityStatus::disarmed;
        }
        
        part :>> energyManager {
            attribute :>> totalConsumption = 0.0 [SI::J];
            attribute :>> peakDemand = 5000.0 [SI::W];
        }
        
        connection envMonitoring connect 
            livingRoom.envSensor.output to controller.systemControl;
        
        connection climateControl connect 
            controller.systemControl to climateSystem.control;
        
        connection lightControl connect 
            controller.systemControl to lightingSystem.control;
        
        connection securityControl connect 
            controller.systemControl to securitySystem.control;
        
        connection energyMonitoring connect 
            energyManager.monitor to controller.systemControl;
        
        perform action operations : ManageDomusOperations {
            in targetTemperature = domus.targetTemperature;
            in securityMode = SecurityStatus::monitoring;
            out systemStatus;
        }
        
        exhibit state operationalState : DomusOperationalStates;
        
        satisfy domusSystemRequirements;
    }
}
