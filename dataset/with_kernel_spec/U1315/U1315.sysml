package SmartEnvironmentControlSystem {
    private import ScalarValues::*;
    
    enum def SystemMode { Comfort; Eco; Away; Sleep; Manual; }
    enum def LightingLevel { Off; Low; Medium; High; Full; }
    enum def HVACMode { Heating; Cooling; Off; }
    
    attribute def TemperatureValue :> Real { doc /* degrees Celsius */ }
    attribute def HumidityValue :> Real { doc /* percentage relative humidity */ }
    attribute def IlluminanceValue :> Real { doc /* lux */ }
    attribute def PowerValue :> Real { doc /* watt */ }
    attribute def EnergyValue :> Real { doc /* kilowatt-hour */ }
    
    attribute def HVACCommand {
        mode : HVACMode;
        targetTemp : TemperatureValue;
    }
    attribute def LightingCommand {
        level : LightingLevel;
    }
    attribute def SetModeCommand {
        mode : SystemMode;
    }
    
    port def TempOutPort { out temp : TemperatureValue; }
    port def HumidOutPort { out humid : HumidityValue; }
    port def LightOutPort { out light : IlluminanceValue; }
    port def MotionOutPort { out occupied : Boolean; }
    
    port def ControllerInPort {
        in temp : TemperatureValue;
        in humid : HumidityValue;
        in light : IlluminanceValue;
        in occupied : Boolean;
        in setMode : SetModeCommand;
    }
    port def ControllerOutPort {
        out hvacCmd : HVACCommand;
        out lightCmd : LightingCommand;
    }
    port def HVACInPort { in cmd : HVACCommand; }
    port def LightingInPort { in cmd : LightingCommand; }
    
    action def SenseTemperature { out temp : TemperatureValue; }
    action def SenseHumidity { out humid : HumidityValue; }
    action def SenseLight { out light : IlluminanceValue; }
    action def SenseMotion { out occupied : Boolean; }
    action def RegulateTemperature { in cmd : HVACCommand; }
    action def SetBrightness { in cmd : LightingCommand; }
    
    part def TemperatureSensor {
        port tempOut : TempOutPort;
        perform action sense : SenseTemperature;
    }
    part def HumiditySensor {
        port humidOut : HumidOutPort;
        perform action sense : SenseHumidity;
    }
    part def LightSensor {
        port lightOut : LightOutPort;
        perform action sense : SenseLight;
    }
    part def MotionSensor {
        port motionOut : MotionOutPort;
        perform action sense : SenseMotion;
    }
    part def HVACUnit {
        port cmdIn : HVACInPort;
        perform action regulate : RegulateTemperature;
    }
    part def LightingUnit {
        port cmdIn : LightingInPort;
        perform action adjust : SetBrightness;
    }
    
    part def Controller {
        port sensorIn : ControllerInPort;
        port cmdOut : ControllerOutPort;
        
        exhibit state controllerStates {
            entry; then Comfort;
            
            state Comfort;
            accept SetModeCommand via sensorIn.setMode then Eco;
            accept when sensorIn.occupied == false then Away;
            
            state Eco;
            accept SetModeCommand via sensorIn.setMode then Sleep;
            accept when sensorIn.occupied == false then Away;
            
            state Away;
            accept when sensorIn.occupied == true then Comfort;
            accept SetModeCommand via sensorIn.setMode then Comfort;
            
            state Sleep;
            accept SetModeCommand via sensorIn.setMode then Manual;
            accept when sensorIn.occupied == false then Away;
            
            state Manual;
            accept SetModeCommand via sensorIn.setMode then Comfort;
        }
    }
    
    part def SmartEnvironmentSystem {
        part controller : Controller;
        part tempSensor : TemperatureSensor;
        part humidSensor : HumiditySensor;
        part lightSensor : LightSensor;
        part motionSensor : MotionSensor;
        part hvac : HVACUnit;
        part lighting : LightingUnit;
        
        connect tempSensor.tempOut.temp to controller.sensorIn.temp;
        connect humidSensor.humidOut.humid to controller.sensorIn.humid;
        connect lightSensor.lightOut.light to controller.sensorIn.light;
        connect motionSensor.motionOut.occupied to controller.sensorIn.occupied;
        connect controller.cmdOut.hvacCmd to hvac.cmdIn.cmd;
        connect controller.cmdOut.lightCmd to lighting.cmdIn.cmd;
    }
    
    requirement def ComfortReqDef {
        doc /* The system shall maintain a comfortable temperature around 22 degC in Comfort mode. */
        attribute setTemp : TemperatureValue;
        attribute actualTemp : TemperatureValue;
        require constraint { actualTemp >= setTemp - 1.0 and actualTemp <= setTemp + 1.0 }
    }
    requirement def EcoRangeReqDef {
        doc /* In Eco mode the system shall allow a wider temperature range to conserve energy. */
        attribute minTemp : TemperatureValue;
        attribute maxTemp : TemperatureValue;
        attribute actualTemp : TemperatureValue;
        require constraint { actualTemp >= minTemp and actualTemp <= maxTemp }
    }
    requirement def AwayModeReqDef {
        doc /* Away mode shall set the system to a minimal energy state when the space is vacant. */
        attribute isOccupied : Boolean;
        attribute currentMode : SystemMode;
        require constraint { isOccupied == true or currentMode == SystemMode::Away }
    }
    requirement def NaturalLightUtilizationReqDef {
        doc /* The system shall consider natural light before turning on artificial lights. */
        attribute ambientLight : IlluminanceValue;
        attribute artificialLightLevel : LightingLevel;
        attribute threshold : IlluminanceValue;
        require constraint { ambientLight < threshold or artificialLightLevel == LightingLevel::Off }
    }
    requirement def EnergyBudgetReqDef {
        doc /* The system shall operate within a set energy budget over time. */
        attribute consumedEnergy : EnergyValue;
        attribute maxEnergy : EnergyValue;
        require constraint { consumedEnergy <= maxEnergy }
    }
    requirement def OccupancyAdaptationReqDef {
        doc /* The system shall detect occupancy and adjust lighting accordingly. */
        attribute motionDetected : Boolean;
        attribute lightLevel : LightingLevel;
        require constraint { motionDetected == false or lightLevel != LightingLevel::Off }
    }
    requirement def ModeSelectionReqDef {
        doc /* The system shall allow the user to select among Comfort, Eco, Away, Sleep, and Manual modes. */
        attribute userMode : SystemMode;
        attribute currentMode : SystemMode;
        require constraint { currentMode == userMode }
    }
}
