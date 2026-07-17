package 'Nest Learning Thermostat System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureSetpoint :> ThermodynamicTemperatureValue;
    attribute def HumidityPercentage :> Real;
    attribute def TimeOfDay :> TimeValue;
    attribute def OccupancyState :> Boolean;
    attribute def EnergyConsumption :> EnergyValue;
    
    enum def HVACMode { heating; cooling; off; auto; }
    enum def FanMode { on; auto; circulate; }
    enum def SystemState { idle; heating; cooling; fanOnly; }
    
    item def TemperatureReading;
    item def HumidityReading;
    item def MotionEvent;
    item def HVACControlSignal;
    item def UserCommand;
    item def CloudData;
    item def WeatherForecast;
    item def ScheduleData;
    
    port def TemperatureSensorPort {
        out item temperatureData : TemperatureReading;
    }
    
    port def HumiditySensorPort {
        out item humidityData : HumidityReading;
    }
    
    port def MotionSensorPort {
        out item motionDetected : MotionEvent;
    }
    
    port def HVACControlPort {
        out item heatingSignal : HVACControlSignal;
        out item coolingSignal : HVACControlSignal;
        out item fanSignal : HVACControlSignal;
        in item systemFeedback : HVACControlSignal;
    }
    
    port def UserInterfacePort {
        in item setpointAdjustment : UserCommand;
        in item modeSelection : UserCommand;
        in item scheduleUpdate : UserCommand;
        out item displayData : TemperatureReading;
    }
    
    port def CloudConnectivityPort {
        out item telemetryData : CloudData;
        in item weatherData : WeatherForecast;
        in item remoteCommands : UserCommand;
        out item learningData : ScheduleData;
    }
    
    port def PowerPort {
        in item electricalPower : PowerValue;
    }
    
    part def PrecisionTemperatureSensor {
        port sensorOutput : TemperatureSensorPort;
        attribute currentTemperature : ThermodynamicTemperatureValue;
        attribute measurementAccuracy : ThermodynamicTemperatureValue;
        attribute samplingRate : FrequencyValue;
    }
    
    part def HumiditySensor {
        port sensorOutput : HumiditySensorPort;
        attribute currentHumidity : HumidityPercentage;
        attribute measurementRange : HumidityPercentage[2];
    }
    
    part def PassiveInfraredSensor {
        port motionOutput : MotionSensorPort;
        attribute detectionRadius : LengthValue;
        attribute sensitivity : Real;
        attribute lastMotionTime : TimeValue;
    }
    
    part def LCDTouchDisplay {
        port userInterface : UserInterfacePort;
        attribute screenDiameter : LengthValue;
        attribute resolution : Integer[2];
        attribute backlightIntensity : Real;
    }
    
    part def WiFiRadio {
        port cloudConnection : CloudConnectivityPort;
        attribute signalStrength : Real;
        attribute dataRate : Real;
        attribute isConnected : Boolean;
    }
    
    part def LearningEngine {
        attribute userSchedule : ScheduleData[*];
        attribute occupancyPatterns : OccupancyState[*];
        attribute temperaturePreferences : TemperatureSetpoint[*];
        attribute learningPeriod : TimeValue;
        attribute adaptationRate : Real;
    }
    
    part def ThermostatController {
        port tempSensorInput : ~TemperatureSensorPort;
        port humiditySensorInput : ~HumiditySensorPort;
        port motionSensorInput : ~MotionSensorPort;
        port hvacOutput : HVACControlPort;
        port userIO : UserInterfacePort;
        port cloudIO : ~CloudConnectivityPort;
        port powerInput : PowerPort;
        
        attribute targetTemperature : TemperatureSetpoint;
        attribute currentMode : HVACMode;
        attribute fanMode : FanMode;
        attribute temperatureTolerance : ThermodynamicTemperatureValue;
        attribute ecoModeEnabled : Boolean;
        attribute awayModeActive : Boolean;
        
        part aiEngine : LearningEngine;
        part temperatureSensor : PrecisionTemperatureSensor;
        part humiditySensor : HumiditySensor;
        part motionSensor : PassiveInfraredSensor;
        part displayModule : LCDTouchDisplay;
        part wifiModule : WiFiRadio;
    }
    
    part def ResidentialHVACSystem {
        port controlInterface : ~HVACControlPort;
        
        part furnace {
            attribute heatingCapacity : PowerValue;
            attribute efficiency : Real;
            attribute fuelType : String;
        }
        
        part airConditioner {
            attribute coolingCapacity : PowerValue;
            attribute seer : Real;
            attribute refrigerantType : String;
        }
        
        part airHandler {
            attribute airflowCapacity : VolumeFlowRateValue;
            attribute filterType : String;
            attribute motorPower : PowerValue;
        }
    }
    
    action def SenseEnvironment {
        out ambientTemperature : ThermodynamicTemperatureValue;
        out relativeHumidity : HumidityPercentage;
        out occupancyDetected : OccupancyState;
        out currentTime : TimeOfDay;
    }
    
    action def AnalyzeUserBehavior {
        in temperatureHistory : TemperatureSetpoint[*];
        in occupancyHistory : OccupancyState[*];
        in timeHistory : TimeOfDay[*];
        in weatherHistory : WeatherForecast[*];
        out predictedSchedule : ScheduleData[*];
        out optimalSetpoints : TemperatureSetpoint[*];
    }
    
    action def DetermineOptimalSetpoint {
        in currentTemperature : ThermodynamicTemperatureValue;
        in userPreference : TemperatureSetpoint;
        in occupancy : OccupancyState;
        in timeOfDay : TimeOfDay;
        in weatherForecast : WeatherForecast;
        in learnedSchedule : ScheduleData[*];
        in ecoMode : Boolean;
        out optimalSetpoint : TemperatureSetpoint;
        out energySavingsEstimate : EnergyValue;
    }
    
    action def RegulateClimate {
        in currentTemperature : ThermodynamicTemperatureValue;
        in targetSetpoint : TemperatureSetpoint;
        in tolerance : ThermodynamicTemperatureValue;
        in currentMode : HVACMode;
        out heatingRequired : Boolean;
        out coolingRequired : Boolean;
        out fanRequired : Boolean;
        out systemState : SystemState;
    }
    
    action def UpdateUserInterface {
        in displayTemperature : ThermodynamicTemperatureValue;
        in targetSetpoint : TemperatureSetpoint;
        in operatingMode : HVACMode;
        in systemStatus : SystemState;
        in energySavings : EnergyValue;
        out displayContent : String;
    }
    
    action def TransmitTelemetry {
        in temperatureLog : ThermodynamicTemperatureValue[*];
        in setpointLog : TemperatureSetpoint[*];
        in energyUsage : EnergyValue;
        in systemEvents : String[*];
        out cloudPayload : CloudData;
    }
    
    action def ManageHomeComfort {
        in powerSupply : PowerValue;
        in initialSetpoint : TemperatureSetpoint;
        out comfortMaintained : Boolean;
        out energyOptimized : Boolean;
        
        first start;
        then merge controlLoop;
        
        action controlLoop {
            action senseConditions : SenseEnvironment {
                out ambientTemperature;
                out relativeHumidity;
                out occupancyDetected;
                out currentTime;
            }
            
            then action intelligentControl : DetermineOptimalSetpoint {
                in currentTemperature = senseConditions.ambientTemperature;
                in occupancy = senseConditions.occupancyDetected;
                in timeOfDay = senseConditions.currentTime;
                in ecoMode = true;
                out optimalSetpoint;
                out energySavingsEstimate;
            }
            
            then decide;
                if intelligentControl.currentTemperature < intelligentControl.optimalSetpoint 
                    then initiateHeating;
                if intelligentControl.currentTemperature > intelligentControl.optimalSetpoint 
                    then initiateCooling;
            
            action initiateHeating : RegulateClimate {
                in currentTemperature = intelligentControl.currentTemperature;
                in targetSetpoint = intelligentControl.optimalSetpoint;
                in currentMode = HVACMode::heating;
                out heatingRequired;
                out systemState;
            }
            then controlLoop;
            
            action initiateCooling : RegulateClimate {
                in currentTemperature = intelligentControl.currentTemperature;
                in targetSetpoint = intelligentControl.optimalSetpoint;
                in currentMode = HVACMode::cooling;
                out coolingRequired;
                out systemState;
            }
            then controlLoop;
        }
    }
    
    part nestLearningThermostat : ThermostatController {
        :>> temperatureSensor :>> currentTemperature = 293.15 [K];
        :>> temperatureSensor :>> measurementAccuracy = 0.1 [K];
        :>> temperatureSensor :>> samplingRate = 0.1 [Hz];
        
        :>> humiditySensor :>> currentHumidity = 45.0;
        :>> humiditySensor :>> measurementRange = (0.0, 100.0);
        
        :>> motionSensor :>> detectionRadius = 6.0 [m];
        :>> motionSensor :>> sensitivity = 0.85;
        :>> motionSensor :>> lastMotionTime = 0.0 [s];
        
        :>> displayModule :>> screenDiameter = 0.084 [m];
        :>> displayModule :>> resolution = (480, 480);
        :>> displayModule :>> backlightIntensity = 0.7;
        
        :>> wifiModule :>> signalStrength = 0.82;
        :>> wifiModule :>> dataRate = 54.0;
        :>> wifiModule :>> isConnected = true;
        
        :>> targetTemperature = 294.65 [K];
        :>> currentMode = HVACMode::auto;
        :>> fanMode = FanMode::auto;
        :>> temperatureTolerance = 0.5 [K];
        :>> ecoModeEnabled = true;
        :>> awayModeActive = false;
        
        :>> aiEngine :>> learningPeriod = 604800.0 [s];
        :>> aiEngine :>> adaptationRate = 0.15;
        
        perform action climateControl : ManageHomeComfort;
    }
    
    part residentialHVAC : ResidentialHVACSystem {
        :>> furnace :>> heatingCapacity = 18000.0 [W];
        :>> furnace :>> efficiency = 0.96;
        :>> furnace :>> fuelType = "natural gas";
        :>> airConditioner :>> coolingCapacity = 10500.0 [W];
        :>> airConditioner :>> seer = 16.0;
        :>> airConditioner :>> refrigerantType = "R-410A";
        :>> airHandler :>> airflowCapacity = 0.00085 [m^3/s];
        :>> airHandler :>> filterType = "MERV 13";
        :>> airHandler :>> motorPower = 750.0 [W];
    }
    
    connection tempSensorLink : TemperatureSensorPort
        connect nestLearningThermostat.temperatureSensor.sensorOutput 
        to nestLearningThermostat.tempSensorInput;
    
    connection humiditySensorLink : HumiditySensorPort
        connect nestLearningThermostat.humiditySensor.sensorOutput 
        to nestLearningThermostat.humiditySensorInput;
    
    connection motionSensorLink : MotionSensorPort
        connect nestLearningThermostat.motionSensor.motionOutput 
        to nestLearningThermostat.motionSensorInput;
    
    connection hvacControlLink : HVACControlPort
        connect nestLearningThermostat.hvacOutput 
        to residentialHVAC.controlInterface;
    
    connection cloudLink : CloudConnectivityPort
        connect nestLearningThermostat.wifiModule.cloudConnection 
        to nestLearningThermostat.cloudIO;
    
    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall reduce residential heating and cooling energy consumption 
             by at least 20% compared to conventional programmable thermostats through 
             intelligent learning and automated scheduling. */
        
        subject controller : ThermostatController;
        
        require constraint energySavingsTarget {
            controller.ecoModeEnabled == true and
            controller.aiEngine.adaptationRate >= 0.1
        }
    }
    
    requirement def TemperaturePrecisionRequirement {
        doc /* The system shall maintain room temperature within 0.5K of the target 
             setpoint during occupied periods to ensure optimal comfort. */
        
        subject sensor : PrecisionTemperatureSensor;
        
        require constraint measurementPrecision {
            sensor.measurementAccuracy <= 0.2 [K]
        }
    }
    
    requirement def LearningCapabilityRequirement {
        doc /* The system shall automatically learn household occupancy patterns and 
             temperature preferences within 7 days of installation and continuously 
             adapt to changing user behavior. */
        
        subject learningSystem : LearningEngine;
        
        require constraint learningTimeframe {
            learningSystem.learningPeriod <= 604800.0 [s] and
            learningSystem.userSchedule->size() >= 14
        }
    }
    
    requirement def RemoteAccessRequirement {
        doc /* The system shall provide secure remote monitoring and control capabilities 
             via cloud connectivity with 99.5% uptime availability. */
        
        subject connectivity : WiFiRadio;
        
        require constraint cloudAvailability {
            connectivity.isConnected == true and
            connectivity.signalStrength >= 0.3
        }
    }
    
    requirement def UserExperienceRequirement {
        doc /* The system shall provide intuitive touch-screen interface with real-time 
             temperature display, energy savings information, and simple setpoint adjustment. */
        
        subject display : LCDTouchDisplay;
        
        require constraint interfaceQuality {
            display.resolution[0] >= 320 and
            display.backlightIntensity >= 0.5
        }
    }
    
    requirement <'NEST-SYS-001'> intelligentClimateControl {
        doc /* The Nest Learning Thermostat system shall automatically regulate residential 
             indoor climate by learning occupant behavior patterns, optimizing temperature 
             setpoints based on occupancy and time-of-day preferences, and minimizing energy 
             consumption while maintaining comfort through continuous adaptive control and 
             cloud-connected intelligence. */
        
        subject nestSystem : ThermostatController;
        
        assume constraint sensorAvailability {
            nestSystem.temperatureSensor.currentTemperature != null and
            nestSystem.motionSensor.lastMotionTime != null
        }
        
        assume constraint hvacFunctional {
            residentialHVAC.furnace.heatingCapacity > 0.0 [W] and
            residentialHVAC.airConditioner.coolingCapacity > 0.0 [W]
        }
        
        require energyEfficiency : EnergyEfficiencyRequirement {
            :>> controller = nestSystem;
        }
        
        require temperaturePrecision : TemperaturePrecisionRequirement {
            :>> sensor = nestSystem.temperatureSensor;
        }
        
        require learningCapability : LearningCapabilityRequirement {
            :>> learningSystem = nestSystem.aiEngine;
        }
        
        require remoteAccess : RemoteAccessRequirement {
            :>> connectivity = nestSystem.wifiModule;
        }
        
        require userExperience : UserExperienceRequirement {
            :>> display = nestSystem.displayModule;
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Nest Learning Thermostat System'::*;
}
