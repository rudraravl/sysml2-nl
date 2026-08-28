package NestThermostatSystem {
    private import ScalarValues::*;
    
    attribute def Temperature :> Real;
    attribute def Humidity :> Real;
    attribute def Power :> Real;
    attribute def Duration :> Real;
    attribute def Percentage :> Real;
    
    enum def HVACMode {
        Off;
        Heating;
        Cooling;
        FanOnly;
        Auto;
    }
    
    item def WeatherForecast;
    item def ClimateSchedule;
    
    port def SensorDataPort {
        out temperature : Temperature;
        out humidity : Humidity;
        out motionDetected : Boolean;
    }
    
    port def HVACCommandPort {
        out heatOn : Boolean;
        out coolOn : Boolean;
        out fanOn : Boolean;
    }
    
    port def DisplayControlPort {
        out currentTemp : Temperature;
        out setpoint : Temperature;
        out mode : HVACMode;
        out status : String;
    }
    
    port def NetworkPort {
        in weatherData : WeatherForecast;
        in remoteCommand : String;
    }
    
    port def ManualAdjustmentPort {
        out timestamp : Duration;
        out setpointChange : Temperature;
    }
    
    port def SchedulePort {
        out schedule : ClimateSchedule;
    }
    
    part def TemperatureSensor {
        port dataOut : SensorDataPort;
    }
    
    part def HumiditySensor {
        port dataOut : SensorDataPort;
    }
    
    part def MotionSensor {
        port dataOut : SensorDataPort;
    }
    
    part def Display {
        port displayIF : DisplayControlPort;
        attribute screenType : String = "Round LCD";
    }
    
    part def WiFiRadio {
        port netPort : NetworkPort;
        attribute connectivity : String = "Cloud";
    }
    
    part def LearningEngine {
        port occupancyIn : SensorDataPort;
        port manualAdjustmentsIn : ManualAdjustmentPort;
        port weatherIn : NetworkPort;
        port scheduleOut : SchedulePort;
        attribute learningPeriod : Duration;
        attribute learnedSchedule : ClimateSchedule;
    }
    
    state def ThermostatControl {
        attribute currentTemp : Temperature;
        attribute setpoint : Temperature;
        attribute occupancy : Boolean;
        attribute powerOn : Boolean;
        attribute heatOn : Boolean;
        attribute coolOn : Boolean;
        attribute fanOn : Boolean;
        attribute mode : HVACMode;
        
        state Off;
        state Auto;
        state Heating;
        state Cooling;
        state FanOnly;
        
        transition Off to Auto when powerOn == true;
        transition Auto to Heating when currentTemp < setpoint - 0.5;
        transition Auto to Cooling when currentTemp > setpoint + 0.5;
        transition Auto to FanOnly when occupancy == true and currentTemp == setpoint;
        transition Heating to Auto when currentTemp >= setpoint;
        transition Cooling to Auto when currentTemp <= setpoint;
        transition FanOnly to Auto when occupancy == false;
    }
    
    part def ThermostatController {
        port tempData : SensorDataPort;
        port humidityData : SensorDataPort;
        port motionData : SensorDataPort;
        port displayControl : DisplayControlPort;
        port wifiInternal : NetworkPort;
        port manualAdjustmentsOut : ManualAdjustmentPort;
        port scheduleIn : SchedulePort;
        port hvacControl : HVACCommandPort;
        
        attribute currentTemp : Temperature;
        attribute targetTemp : Temperature;
        attribute currentHumidity : Humidity;
        attribute occupancy : Boolean;
        attribute systemStatus : String;
        
        state thermostatControl : ThermostatControl;
    }
    
    part def NestThermostat {
        port sensorIF : SensorDataPort;
        port uiIF : DisplayControlPort;
        port netIF : NetworkPort;
        port hvacCtrl : HVACCommandPort;
        
        attribute targetTemp : Temperature;
        
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part motionSensor : MotionSensor;
        part display : Display;
        part wifiRadio : WiFiRadio;
        part learningEngine : LearningEngine;
        part controller : ThermostatController;
        
        connect tempSensor.dataOut to controller.tempData;
        connect humiditySensor.dataOut to controller.humidityData;
        connect motionSensor.dataOut to controller.motionData;
        connect controller.displayControl to display.displayIF;
        connect controller.wifiInternal to wifiRadio.netPort;
        connect motionSensor.dataOut to learningEngine.occupancyIn;
        connect controller.manualAdjustmentsOut to learningEngine.manualAdjustmentsIn;
        connect wifiRadio.netPort to learningEngine.weatherIn;
        connect learningEngine.scheduleOut to controller.scheduleIn;
        connect controller.hvacControl to hvacCtrl;
    }
    
    part def Furnace {
        port controlIn : ~HVACCommandPort;
        attribute powerDraw : Power;
    }
    
    part def AirConditioner {
        port controlIn : ~HVACCommandPort;
        attribute powerDraw : Power;
    }
    
    part def AirHandler {
        port controlIn : ~HVACCommandPort;
        attribute powerDraw : Power;
    }
    
    part def HVACUnit {
        port thermostatIF : ~HVACCommandPort;
        part furnace : Furnace;
        part ac : AirConditioner;
        part airHandler : AirHandler;
        
        connect thermostatIF to furnace.controlIn;
        connect thermostatIF to ac.controlIn;
        connect thermostatIF to airHandler.controlIn;
    }
    
    part def CloudService {
        port wifiPort : NetworkPort;
    }
    
    part def SmartphoneApp {
        port cloudPort : NetworkPort;
    }
    
    interface def HVACControlInterface {
        end supplierPort : HVACCommandPort;
        end consumerPort : ~HVACCommandPort;
    }
    
    part def NestSystem;
    
    part system : NestSystem {
        part thermostat : NestThermostat;
        part hvac : HVACUnit;
        part cloud : CloudService;
        part app : SmartphoneApp;
        
        interface : HVACControlInterface connect
            supplierPort ::> thermostat.hvacCtrl to
            consumerPort ::> hvac.thermostatIF;
        
        connect thermostat.wifiRadio.netPort to cloud.wifiPort;
        connect app.cloudPort to cloud.wifiPort;
    }
    
    requirement def TemperatureControlReq {
        doc /* The thermostat shall maintain the indoor temperature within 0.5 degrees of the target setpoint. */
        attribute actualTemp : Temperature;
        attribute setpoint : Temperature;
        require constraint { actualTemp - setpoint <= 0.5 and setpoint - actualTemp <= 0.5 }
    }
    
    requirement def EnergyEfficiencyReq {
        doc /* The system shall reduce energy consumption by avoiding heating or cooling an unoccupied home. */
        attribute occupancy : Boolean;
        attribute hvacActive : Boolean;
        require constraint { not occupancy implies not hvacActive }
    }
    
    requirement def LearningPeriodReq {
        doc /* The learning engine shall learn the household schedule and preferences within 7 days. */
        attribute learningTime : Duration;
        attribute maxLearningTime : Duration = 604800;
        require constraint { learningTime <= maxLearningTime }
    }
    
    requirement def RemoteControlReq {
        doc /* The system shall allow remote control via a smartphone app with response time under 2 seconds. */
        attribute responseTime : Duration;
        attribute maxResponseTime : Duration = 2;
        require constraint { responseTime <= maxResponseTime }
    }
    
    requirement def WeatherIntegrationReq {
        doc /* The thermostat shall use local weather forecast data to optimize climate control decisions. */
        attribute weatherDataAvailable : Boolean;
        attribute scheduleAdjusted : Boolean;
        require constraint { weatherDataAvailable implies scheduleAdjusted }
    }
    
    requirement def OccupancyDetectionReq {
        doc /* The thermostat shall detect occupancy using the motion sensor to inform climate control. */
        attribute occupancyDetected : Boolean;
        require constraint { occupancyDetected == true }
    }
    
    requirement def DisplayInterfaceReq {
        doc /* The display shall show current temperature, target setpoint, and system status on a round LCD. */
        attribute displayActive : Boolean;
        attribute showsTemp : Boolean;
        attribute showsSetpoint : Boolean;
        attribute showsStatus : Boolean;
        require constraint { displayActive implies (showsTemp and showsSetpoint and showsStatus) }
    }
    
    requirement def HVACControlReq {
        doc /* The thermostat shall correctly activate heating, cooling, and fan based on the control mode. */
        attribute heatOn : Boolean;
        attribute coolOn : Boolean;
        attribute fanOn : Boolean;
        attribute mode : HVACMode;
        require constraint {
            (mode == HVACMode::Heating implies (heatOn and not coolOn)) and
            (mode == HVACMode::Cooling implies (coolOn and not heatOn)) and
            (mode == HVACMode::FanOnly implies fanOn)
        }
    }
}
