package NestThermostatSystem {
    import ISQ::*;
    import ISQBase::*;
    import ISQSpaceTime::*;
    import ISQThermodynamics::*;
    import ISQTime::*;
    
    // ===== Value Types =====
    
    value def TemperatureValue :> RealValue {
        unit :> degC;
    }
    
    value def HumidityValue :> RealValue {
        unit :> percent;
        attr :>> num = 0;
    }
    
    value def OccupancyStateValue :> ScalarVectorValue {
        values :>> isOccupied : Boolean;
    }
    
    value def PowerStateValue :> ScalarVectorValue {
        values :>> isOn : Boolean;
    }
    
    value def ControlSignalValue :> ScalarVectorValue {
        values :>> active : Boolean;
    }
    
    value def SetpointValue :> TemperatureValue;
    
    value def ToleranceValue :> TemperatureValue;
    
    value def ScheduleEntryValue :> StructuredValue {
        values :>> timeOfDay : TimeValue;
        values :>> setpoint : TemperatureValue;
        values :>> mode : HVACMode;
    }
    
    enum def HVACMode {
        OFF;
        HEATING;
        COOLING;
        FAN_ONLY;
        AUTO;
    }
    
    enum def SystemStatus {
        IDLE;
        HEATING_ACTIVE;
        COOLING_ACTIVE;
        FAN_ACTIVE;
        AWAY;
    }
    
    item def TemperatureReading :> StructuredItem {
        attr value : TemperatureValue;
        attr timestamp : TimeValue;
    }
    
    item def HumidityReading :> StructuredItem {
        attr value : HumidityValue;
        attr timestamp : TimeValue;
    }
    
    item def OccupancyReading :> StructuredItem {
        attr detected : Boolean;
        attr timestamp : TimeValue;
    }
    
    item def WeatherForecast :> StructuredItem {
        attr outdoorTemp : TemperatureValue;
        attr humidity : HumidityValue;
        attr timestamp : TimeValue;
    }
    
    item def UserAdjustment :> StructuredItem {
        attr newSetpoint : TemperatureValue;
        attr timestamp : TimeValue;
    }
    
    item def RemoteCommand :> StructuredItem {
        attr setpoint : TemperatureValue;
        attr mode : HVACMode;
        attr source : String;
    }
    
    item def ScheduleEntry :> StructuredItem {
        attr entry : ScheduleEntryValue;
    }
    
    // ===== Port Definitions =====
    
    port def TempSensorOut {
        out reading : TemperatureReading;
    }
    
    port def HumiditySensorOut {
        out reading : HumidityReading;
    }
    
    port def MotionSensorOut {
        out reading : OccupancyReading;
    }
    
    port def ControlSignalPort {
        out signal : ControlSignalValue;
    }
    
    port def DisplayPort {
        in currentTemp : TemperatureValue;
        in setpoint : TemperatureValue;
        in status : SystemStatus;
    }
    
    port def TouchInputPort {
        out adjustment : UserAdjustment;
    }
    
    port def CloudPort {
        inout remoteCmd : RemoteCommand;
        in weather : WeatherForecast;
    }
    
    port def SchedulePort {
        out entry : ScheduleEntry;
    }
    
    // ===== Sensors =====
    
    part def TemperatureSensor {
        port tempOut : TempSensorOut;
        attr accuracy : TemperatureValue = 0.1 [degC];
        attr samplingInterval : TimeValue = 5 [s];
        
        action def senseTemperature {
            in environmentTemp : TemperatureValue;
            out reading : TemperatureReading;
        }
    }
    
    part def HumiditySensor {
        port humidOut : HumiditySensorOut;
        attr accuracy : HumidityValue = 2.0 [percent];
        attr samplingInterval : TimeValue = 30 [s];
        
        action def senseHumidity {
            in environmentHumidity : HumidityValue;
            out reading : HumidityReading;
        }
    }
    
    part def PIRMotionSensor {
        port motionOut : MotionSensorOut;
        attr detectionRange : LengthValue = 7.0 [m];
        attr fieldOfView : PlaneAngleValue = 90.0 [deg];
        attr samplingInterval : TimeValue = 2 [s];
        
        action def detectMotion {
            out reading : OccupancyReading;
        }
    }
    
    // ===== Learning Engine =====
    
    part def LearningEngine {
        port scheduleOut : SchedulePort;
        in currentTemp : TemperatureReading;
        in occupancy : OccupancyReading;
        in userAdjustments : UserAdjustment;
        in weather : WeatherForecast;
        
        attr learningPeriod : TimeValue = 7.0 [d];
        attr learnedSchedule : ScheduleEntryValue[0..*];
        attr occupancyPattern : ScheduleEntryValue[0..*];
        attr isLearningComplete : Boolean = false;
        
        state learningBehavior {
            entry;
            
            state CollectingData;
            state AnalyzingPatterns;
            state ScheduleGenerated;
            
            transition collect_to_analyze
                from CollectingData to AnalyzingPatterns
                when learningPeriod >= 7.0 [d];
            
            transition analyze_to_generated
                from AnalyzingPatterns to ScheduleGenerated
                when learnedSchedule->size() > 0;
            
            transition generated_to_collecting
                from ScheduleGenerated to CollectingData
                when userAdjustments->size() > 0;
        }
        
        action def observeBehavior {
            in adjustment : UserAdjustment;
            in occupancy : OccupancyReading;
            out learnedEntry : ScheduleEntry;
        }
        
        action def buildSchedule {
            in adjustments : UserAdjustment[0..*];
            in occupancyData : OccupancyReading[0..*];
            out schedule : ScheduleEntry[0..*];
        }
        
        action def optimizeForEnergy {
            in schedule : ScheduleEntry[0..*];
            in weather : WeatherForecast;
            in occupancy : OccupancyReading;
            out optimizedSchedule : ScheduleEntry[0..*];
        }
    }
    
    // ===== Display =====
    
    part def RoundLCDTouchDisplay {
        port displayIn : DisplayPort;
        port touchOut : TouchInputPort;
        attr diameter : LengthValue = 82.0 [mm];
        attr resolution : Integer = 320;
        
        action def renderDisplay {
            in temp : TemperatureValue;
            in setpoint : TemperatureValue;
            in status : SystemStatus;
        }
        
        action def captureTouch {
            out adjustment : UserAdjustment;
        }
    }
    
    // ===== WiFi Radio =====
    
    part def WiFiRadio {
        port cloud : CloudPort;
        attr protocol : String = "802.11 b/g/n";
        attr isConnected : Boolean = false;
        
        state connectionState {
            entry;
            
            state Disconnected;
            state Connected;
            
            transition disconnect_to_connect
                from Disconnected to Connected
                when cloud.weather->notEmpty();
            
            transition connect_to_disconnect
                from Connected to Disconnected
                when false;
        }
        
        action def receiveRemoteCommand {
            out cmd : RemoteCommand;
        }
        
        action def fetchWeather {
            out forecast : WeatherForecast;
        }
    }
    
    // ===== HVAC Controller (decision logic) =====
    
    part def HVACController {
        in currentTemp : TemperatureReading;
        in humidity : HumidityReading;
        in occupancy : OccupancyReading;
        in weather : WeatherForecast;
        in schedule : ScheduleEntry;
        in remoteCmd : RemoteCommand;
        in userAdjustment : UserAdjustment;
        
        out furnaceControl : ControlSignalValue;
        out acControl : ControlSignalValue;
        out fanControl : ControlSignalValue;
        
        attr currentMode : HVACMode = HVACMode::AUTO;
        attr currentSetpoint : TemperatureValue = 22.0 [degC];
        attr tolerance : TemperatureValue = 0.5 [degC];
        attr awaySetpoint : TemperatureValue = 15.0 [degC];
        attr awayMode : Boolean = false;
        
        state controlStateMachine {
            entry;
            
            state Idle;
            state Heating;
            state Cooling;
            state FanOnly;
            state Away;
            
            transition idle_to_heating
                from Idle to Heating
                when currentTemp.value < (currentSetpoint - tolerance) && !awayMode;
            
            transition idle_to_cooling
                from Idle to Cooling
                when currentTemp.value > (currentSetpoint + tolerance) && !awayMode;
            
            transition idle_to_away
                from Idle to Away
                when !occupancy.detected && awayMode == false;
            
            transition heating_to_idle
                from Heating to Idle
                when currentTemp.value >= currentSetpoint;
            
            transition cooling_to_idle
                from Cooling to Idle
                when currentTemp.value <= currentSetpoint;
            
            transition away_to_idle
                from Away to Idle
                when occupancy.detected;
            
            transition any_to_fanonly
                from Idle to FanOnly
                when currentMode == HVACMode::FAN_ONLY;
            
            transition fanonly_to_idle
                from FanOnly to Idle
                when currentMode != HVACMode::FAN_ONLY;
        }
        
        action def decideControl {
            in temp : TemperatureReading;
            in setpoint : TemperatureValue;
            in tol : TemperatureValue;
            in occ : OccupancyReading;
            in mode : HVACMode;
            out furnace : ControlSignalValue;
            out ac : ControlSignalValue;
            out fan : ControlSignalValue;
        }
        
        action def applySchedule {
            in entry : ScheduleEntry;
            out setpoint : TemperatureValue;
            out mode : HVACMode;
        }
    }
    
    // ===== HVAC Components =====
    
    part def Furnace {
        port controlIn : ControlSignalPort;
        attr heatingCapacity : PowerValue = 20000.0 [W];
        attr fuelType : String = "Natural Gas";
        attr isActive : Boolean = false;
        
        state furnaceState {
            entry;
            state Off;
            state On;
            transition off_to_on
                from Off to On
                when controlIn.signal.active;
            transition on_to_off
                from On to Off
                when !controlIn.signal.active;
        }
        
        action def generateHeat {
            in command : ControlSignalValue;
            out heatOutput : PowerValue;
        }
    }
    
    part def AirConditioner {
        port controlIn : ControlSignalPort;
        attr coolingCapacity : PowerValue = 18000.0 [W];
        attr refrigerant : String = "R-410A";
        attr isActive : Boolean = false;
        
        state acState {
            entry;
            state Off;
            state On;
            transition off_to_on
                from Off to On
                when controlIn.signal.active;
            transition on_to_off
                from On to Off
                when !controlIn.signal.active;
        }
        
        action def generateCool {
            in command : ControlSignalValue;
            out coolOutput : PowerValue;
        }
    }
    
    part def AirHandler {
        port controlIn : ControlSignalPort;
        attr fanSpeed : Integer = 3;
        attr airflow : VolumeFlowRateValue = 1200.0 [m3/min];
        attr isActive : Boolean = false;
        
        state fanState {
            entry;
            state Off;
            state LowSpeed;
            state HighSpeed;
            transition off_to_low
                from Off to LowSpeed
                when controlIn.signal.active;
            transition low_to_high
                from LowSpeed to HighSpeed
                when controlIn.signal.active;
            transition high_to_low
                from HighSpeed to LowSpeed
                when controlIn.signal.active;
            transition low_to_off
                from LowSpeed to Off
                when !controlIn.signal.active;
            transition high_to_off
                from HighSpeed to Off
                when !controlIn.signal.active;
        }
        
        action def circulateAir {
            in command : ControlSignalValue;
            out airflow : VolumeFlowRateValue;
        }
    }
    
    // ===== HVAC System =====
    
    part def HVACSystem {
        part furnace : Furnace;
        part airConditioner : AirConditioner;
        part airHandler : AirHandler;
        
        port furnaceControlPort : ControlSignalPort;
        port acControlPort : ControlSignalPort;
        port fanControlPort : ControlSignalPort;
        
        connection furnaceControlConn connect furnaceControlPort to furnace.controlIn;
        connection acControlConn connect acControlPort to airConditioner.controlIn;
        connection fanControlConn connect fanControlPort to airHandler.controlIn;
    }
    
    // ===== Nest Thermostat =====
    
    part def NestLearningThermostat {
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part motionSensor : PIRMotionSensor;
        part learningEngine : LearningEngine;
        part display : RoundLCDTouchDisplay;
        part wifiRadio : WiFiRadio;
        part controller : HVACController;
        
        port furnaceControlOut : ControlSignalPort;
        port acControlOut : ControlSignalPort;
        port fanControlOut : ControlSignalPort;
        
        attr model : String = "Nest Learning Thermostat 3rd Gen";
        attr firmwareVersion : String = "6.2";
        attr defaultSetpoint : TemperatureValue = 22.0 [degC];
        attr minSetpoint : TemperatureValue = 9.0 [degC];
        attr maxSetpoint : TemperatureValue = 32.0 [degC];
        
        connection tempToController connect tempSensor.tempOut.reading to controller.currentTemp;
        connection humidToController connect humiditySensor.humidOut.reading to controller.humidity;
        connection motionToController connect motionSensor.motionOut.reading to controller.occupancy;
        connection motionToLearning connect motionSensor.motionOut.reading to learningEngine.occupancy;
        connection tempToLearning connect tempSensor.tempOut.reading to learningEngine.currentTemp;
        connection touchToController connect display.touchOut.adjustment to controller.userAdjustment;
        connection touchToLearning connect display.touchOut.adjustment to learningEngine.userAdjustments;
        connection cloudToController connect wifiRadio.cloud.remoteCmd to controller.remoteCmd;
        connection cloudToLearning connect wifiRadio.cloud.weather to learningEngine.weather;
        connection cloudToControllerWeather connect wifiRadio.cloud.weather to controller.weather;
        connection scheduleToController connect learningEngine.scheduleOut.entry to controller.schedule;
        connection displayTemp connect tempSensor.tempOut.reading.value to display.displayIn.currentTemp;
        connection displaySetpoint connect controller.currentSetpoint to display.displayIn.setpoint;
        connection controllerFurnaceOut connect controller.furnaceControl to furnaceControlOut.signal;
        connection controllerACOut connect controller.acControl to acControlOut.signal;
        connection controllerFanOut connect controller.fanControl to fanControlOut.signal;
    }
    
    // ===== Top-level System =====
    
    part def NestThermostatSystem {
        part thermostat : NestLearningThermostat;
        part hvac : HVACSystem;
        
        connection thermostatFurnaceToHVAC connect thermostat.furnaceControlOut to hvac.furnaceControlPort;
        connection thermostatACToHVAC connect thermostat.acControlOut to hvac.acControlPort;
        connection thermostatFanToHVAC connect thermostat.fanControlOut to hvac.fanControlPort;
    }
    
    // ===== Requirements =====
    
    requirement def TemperatureControlRequirement {
        subject system : NestThermostatSystem;
        attribute targetSetpoint : TemperatureValue = 22.0 [degC];
        attribute tolerance : TemperatureValue = 0.5 [degC];
        doc /* The system shall maintain indoor temperature within the specified tolerance of the target setpoint. */
        require constraint {
            system.thermostat.controller.currentSetpoint == targetSetpoint
            and abs(system.thermostat.controller.currentTemp.value - targetSetpoint) <= tolerance
        }
    }
    
    requirement def OccupancyDetectionRequirement {
        subject thermostat : NestLearningThermostat;
        doc /* The thermostat shall detect occupancy using the PIR motion sensor and enter away mode when no occupancy is detected. */
        require constraint {
            thermostat.motionSensor.detectionRange >= 7.0 [m]
        }
    }
    
    requirement def LearningScheduleRequirement {
        subject engine : LearningEngine;
        attribute learningPeriod : TimeValue = 7.0 [d];
        doc /* The learning engine shall build an automated climate schedule within one week of observation. */
        require constraint {
            engine.learningPeriod <= 7.0 [d]
            and engine.learnedSchedule->size() > 0
        }
    }
    
    requirement def RemoteControlRequirement {
        subject thermostat : NestLearningThermostat;
        doc /* The thermostat shall support remote control via smartphone app through WiFi cloud connectivity. */
        require constraint {
            thermostat.wifiRadio.protocol == "802.11 b/g/n"
        }
    }
    
    requirement def WeatherIntegrationRequirement {
        subject thermostat : NestLearningThermostat;
        doc /* The thermostat shall fetch local weather forecasts to inform climate control decisions. */
        require constraint {
            thermostat.wifiRadio.cloud.weather->notEmpty()
        }
    }
    
    requirement def EnergyEfficiencyRequirement {
        subject system : NestThermostatSystem;
        doc /* The system shall avoid heating or cooling an unoccupied home to reduce energy consumption. */
        require constraint {
            system.thermostat.controller.awayMode == true
            implies system.hvac.furnace.isActive == false
            and system.hvac.airConditioner.isActive == false
        }
    }
    
    requirement def HVACModeRequirement {
        subject controller : HVACController;
        doc /* The controller shall support heating, cooling, fan-only, and auto modes and switch between them automatically. */
        require constraint {
            controller.currentMode in {HVACMode::HEATING, HVACMode::COOLING, HVACMode::FAN_ONLY, HVACMode::AUTO, HVACMode::OFF}
        }
    }
    
    requirement def DisplayRequirement {
        subject display : RoundLCDTouchDisplay;
        doc /* The display shall show current temperature, target setpoint, and system status. */
        require constraint {
            display.displayIn.currentTemp != null
            and display.displayIn.setpoint != null
            and display.displayIn.status != null
        }
    }
    
    requirement def SensorSuiteRequirement {
        subject thermostat : NestLearningThermostat;
        doc /* The thermostat shall include temperature, humidity, and PIR motion sensors. */
        require constraint {
            thermostat.tempSensor != null
            and thermostat.humiditySensor != null
            and thermostat.motionSensor != null
        }
    }
    
    requirement def HVACControlRequirement {
        subject system : NestThermostatSystem;
        doc /* The thermostat shall send control signals to the furnace, air conditioner, and air handler. */
        require constraint {
            system.hvac.furnace != null
            and system.hvac.airConditioner != null
            and system.hvac.airHandler != null
        }
    }
    
    // ===== Requirement Satisfaction =====
    
    satisfaction satisfyTempControl by NestThermostatSystem satisfies TemperatureControlRequirement;
    satisfaction satisfyOccupancy by NestLearningThermostat satisfies OccupancyDetectionRequirement;
    satisfaction satisfyLearning by LearningEngine satisfies LearningScheduleRequirement;
    satisfaction satisfyRemote by NestLearningThermostat satisfies RemoteControlRequirement;
    satisfaction satisfyWeather by NestLearningThermostat satisfies WeatherIntegrationRequirement;
    satisfaction satisfyEnergy by NestThermostatSystem satisfies EnergyEfficiencyRequirement;
    satisfaction satisfyHVACMode by HVACController satisfies HVACModeRequirement;
    satisfaction satisfyDisplay by RoundLCDTouchDisplay satisfies DisplayRequirement;
    satisfaction satisfySensors by NestLearningThermostat satisfies SensorSuiteRequirement;
    satisfaction satisfyHVACControl by NestThermostatSystem satisfies HVACControlRequirement;
}
