package MedicalIncubator {

    import ScalarValues::*;

    // ================================================================
    // VALUE TYPES
    // ================================================================

    value def TemperatureC :> Real {
        unit : "°C";
    }
    value def HumidityPct :> Real {
        unit : "%RH";
    }
    value def CO2Pct :> Real {
        unit : "%";
    }
    value def PowerW :> Real {
        unit : "W";
    }
    value def FlowRateL :> Real {
        unit : "L/min";
    }
    value def PressurePa :> Real {
        unit : "Pa";
    }
    value def VolumeL :> Real {
        unit : "L";
    }
    value def VolumeM3 :> Real {
        unit : "m^3";
    }
    value def DurationS :> Real {
        unit : "s";
    }
    value def SoundLevelDb :> Real {
        unit : "dB";
    }

    // ================================================================
    // ITEMS
    // ================================================================

    item def Air;
    item def WaterVapor;
    item def CO2Gas;
    item def AirMixture;

    item def SensorReading {
        attribute temperature : TemperatureC;
        attribute humidity : HumidityPct;
        attribute co2 : CO2Pct;
        attribute doorOpen : Boolean;
        attribute timestamp : DurationS;
    }

    item def TargetSettings {
        attribute targetTemperature : TemperatureC = 37 [°C];
        attribute targetHumidity : HumidityPct = 95 [%RH];
        attribute targetCO2 : CO2Pct = 5 [%];
    }

    item def ActuatorCommand {
        attribute heaterEnable : Boolean = false;
        attribute humidifierEnable : Boolean = false;
        attribute co2InjectorEnable : Boolean = false;
    }

    item def AlarmNotification {
        attribute active : Boolean = false;
        attribute message : String;
        attribute severity : Integer = 0;
    }

    item def DoorStateSignal {
        attribute isOpen : Boolean = false;
    }

    // ================================================================
    // PORTS
    // ================================================================

    port def SensorOut {
        out reading : SensorReading;
    }
    port def SensorIn {
        in reading : SensorReading;
    }
    port def CommandOut {
        out command : ActuatorCommand;
    }
    port def ActuatorIn {
        in command : ActuatorCommand;
    }
    port def SettingsOut {
        out settings : TargetSettings;
    }
    port def SettingsIn {
        in settings : TargetSettings;
    }
    port def AlarmOut {
        out alarm : AlarmNotification;
    }
    port def AlarmIn {
        in alarm : AlarmNotification;
    }
    port def DoorOut {
        out doorState : DoorStateSignal;
    }
    port def DoorIn {
        in doorState : DoorStateSignal;
    }

    // ================================================================
    // SENSORS
    // ================================================================

    part def TemperatureSensor {
        attribute accuracy : TemperatureC = 0.1 [°C];
        attribute sampleRate : DurationS = 1 [s];
        attribute measuredValue : TemperatureC;
        port sensorPort : SensorOut;
        action measureTemperature {
            out reading : SensorReading;
        }
    }

    part def HumiditySensor {
        attribute accuracy : HumidityPct = 2 [%RH];
        attribute sampleRate : DurationS = 1 [s];
        attribute measuredValue : HumidityPct;
        port sensorPort : SensorOut;
        action measureHumidity {
            out reading : SensorReading;
        }
    }

    part def CO2Sensor {
        attribute accuracy : CO2Pct = 0.1 [%];
        attribute sampleRate : DurationS = 5 [s];
        attribute measuredValue : CO2Pct;
        port sensorPort : SensorOut;
        action measureCO2 {
            out reading : SensorReading;
        }
    }

    part def DoorSensor {
        attribute isOpen : Boolean = false;
        attribute lastEventTime : DurationS;
        port doorPort : DoorOut;
        action detectDoor {
            out doorState : DoorStateSignal;
        }
    }

    // ================================================================
    // ACTUATORS
    // ================================================================

    part def HeatingElement {
        attribute maxPower : PowerW = 800 [W];
        attribute currentPower : PowerW = 0 [W];
        attribute responseTime : DurationS = 2 [s];
        attribute enabled : Boolean = false;
        port actuatorPort : ActuatorIn;
        action heat {
            in command : ActuatorCommand;
        }
    }

    part def HumidificationSystem {
        attribute maxFlow : FlowRateL = 0.5 [L/min];
        attribute waterLevel : VolumeL = 5 [L];
        attribute reservoirCapacity : VolumeL = 10 [L];
        attribute responseTime : DurationS = 3 [s];
        attribute enabled : Boolean = false;
        port actuatorPort : ActuatorIn;
        action humidify {
            in command : ActuatorCommand;
        }
    }

    part def CO2InjectionSystem {
        attribute maxFlow : FlowRateL = 1 [L/min];
        attribute tankPressure : PressurePa;
        attribute responseTime : DurationS = 1 [s];
        attribute enabled : Boolean = false;
        port actuatorPort : ActuatorIn;
        action injectCO2 {
            in command : ActuatorCommand;
        }
    }

    // ================================================================
    // USER INTERFACE
    // ================================================================

    part def UserInterface {
        attribute currentSettings : TargetSettings;
        port settingsPort : SettingsOut;
        action setTargets {
            in temp : TemperatureC;
            in humidity : HumidityPct;
            in co2 : CO2Pct;
            out settings : TargetSettings;
        }
        action displayReadings {
            in reading : SensorReading;
        }
        action displayAlarm {
            in alarm : AlarmNotification;
        }
        action acknowledgeAlarm;
    }

    // ================================================================
    // ALARM SYSTEM
    // ================================================================

    part def AlarmSystem {
        attribute audibleLevel : SoundLevelDb = 80 [dB];
        attribute visualActive : Boolean = false;
        attribute muted : Boolean = false;
        port alarmPort : AlarmIn;
        action triggerAlarm {
            in alarm : AlarmNotification;
        }
        action muteAlarm;
        action clearAlarm;
    }

    // ================================================================
    // CHAMBER
    // ================================================================

    part def Chamber {
        attribute internalVolume : VolumeM3 = 0.2 [m^3];
        attribute doorSealed : Boolean = true;
        attribute currentTemperature : TemperatureC;
        attribute currentHumidity : HumidityPct;
        attribute currentCO2 : CO2Pct;
        attribute insulationRating : Real = 0.05;
    }

    // ================================================================
    // CONTROL UNIT (with embedded state machine)
    // ================================================================

    part def ControlUnit {
        attribute setpoints : TargetSettings;
        attribute lastReading : SensorReading;
        attribute alarmThresholdTemp : TemperatureC = 1 [°C];
        attribute alarmThresholdHumidity : HumidityPct = 5 [%RH];
        attribute alarmThresholdCO2 : CO2Pct = 0.5 [%];
        attribute doorOpen : Boolean = false;
        attribute conditionsStable : Boolean = false;
        attribute deviation : Boolean = false;
        attribute startupTimer : DurationS = 0 [s];
        attribute maxStartupTime : DurationS = 600 [s];

        port tempIn : SensorIn;
        port humIn : SensorIn;
        port co2In : SensorIn;
        port doorIn : DoorIn;
        port heaterOut : CommandOut;
        port humidifierOut : CommandOut;
        port co2InjectorOut : CommandOut;
        port alarmOut : AlarmOut;
        port settingsIn : SettingsIn;

        action processReadings {
            in readings : SensorReading;
            out command : ActuatorCommand;
        }
        action evaluateAlarm {
            in readings : SensorReading;
            out alarm : AlarmNotification;
        }
        action generateActuatorCommand {
            in readings : SensorReading;
            in setpoints : TargetSettings;
            in doorIsOpen : Boolean;
            out command : ActuatorCommand;
        }
        action checkStability {
            in readings : SensorReading;
            in setpoints : TargetSettings;
            out stable : Boolean;
        }
        action checkDeviation {
            in readings : SensorReading;
            in setpoints : TargetSettings;
            in thresholdTemp : TemperatureC;
            in thresholdHum : HumidityPct;
            in thresholdCO2 : CO2Pct;
            out deviated : Boolean;
        }

        state operationalState {
            entry { /* Initialize control unit */ }

            state Startup {
                entry { /* Activate actuators to reach target conditions */ }
                do { /* Monitor approach to setpoints */ }
                exit { /* Transition to maintaining once stable */ }
            }

            state Maintaining {
                entry { /* Begin stable closed-loop control */ }
                do { /* Continuous monitoring and fine adjustment */ }
                exit { /* Exit when door opened or deviation detected */ }
            }

            state DoorOpen {
                entry { /* Disable heating, humidification, CO2 injection */ }
                do { /* Hold in safe state until door closes */ }
                exit { /* Resume operation when door closed */ }
            }

            state Alarm {
                entry { /* Activate alarm system, cease actuators */ }
                do { /* Wait for operator acknowledgment and condition normalization */ }
                exit { /* Return to maintaining when conditions clear */ }
            }

            transition first initial to Startup;
            transition tStartupToMaintaining Startup to Maintaining when conditionsStable;
            transition tMaintainingToDoorOpen Maintaining to DoorOpen when doorOpen;
            transition tDoorOpenToMaintaining DoorOpen to Maintaining when !doorOpen and conditionsStable;
            transition tMaintainingToAlarm Maintaining to Alarm when deviation;
            transition tAlarmToMaintaining Alarm to Maintaining when !deviation and !doorOpen;
            transition tDoorOpenToAlarm DoorOpen to Alarm when deviation;
        }
    }

    // ================================================================
    // INCUBATOR ASSEMBLY
    // ================================================================

    part def Incubator {
        attribute systemID : String;
        attribute firmwareVersion : String = "1.0";
        attribute chamberVolume : VolumeM3 = 0.2 [m^3];
        attribute manufacturer : String;
        attribute modelNumber : String;

        part chamber : Chamber;
        part heater : HeatingElement;
        part humidifier : HumidificationSystem;
        part co2Injector : CO2InjectionSystem;
        part controlUnit : ControlUnit;
        part tempSensor : TemperatureSensor;
        part humiditySensor : HumiditySensor;
        part co2Sensor : CO2Sensor;
        part doorSensor : DoorSensor;
        part ui : UserInterface;
        part alarms : AlarmSystem;

        connection tempConn connect tempSensor.sensorPort to controlUnit.tempIn;
        connection humConn connect humiditySensor.sensorPort to controlUnit.humIn;
        connection co2Conn connect co2Sensor.sensorPort to controlUnit.co2In;
        connection doorConn connect doorSensor.doorPort to controlUnit.doorIn;
        connection heaterConn connect controlUnit.heaterOut to heater.actuatorPort;
        connection humidifierConn connect controlUnit.humidifierOut to humidifier.actuatorPort;
        connection co2ActConn connect controlUnit.co2InjectorOut to co2Injector.actuatorPort;
        connection alarmConn connect controlUnit.alarmOut to alarms.alarmPort;
        connection settingsConn connect ui.settingsPort to controlUnit.settingsIn;
    }

    // ================================================================
    // REQUIREMENTS
    // ================================================================

    requirement def MaintainTemperature {
        doc /* The incubator shall maintain chamber temperature within tolerance of the setpoint. */
        attribute setpoint : TemperatureC = 37 [°C];
        attribute tolerance : TemperatureC = 0.5 [°C];
        constraint { setpoint >= 20 [°C] and setpoint <= 60 [°C]; }
    }

    requirement def MaintainHumidity {
        doc /* The incubator shall maintain relative humidity within tolerance of the setpoint. */
        attribute setpoint : HumidityPct = 95 [%RH];
        attribute tolerance : HumidityPct = 5 [%RH];
        constraint { setpoint >= 50 [%RH] and setpoint <= 99 [%RH]; }
    }

    requirement def MaintainCO2 {
        doc /* The incubator shall maintain CO2 concentration within tolerance of the setpoint. */
        attribute setpoint : CO2Pct = 5 [%];
        attribute tolerance : CO2Pct = 0.5 [%];
        constraint { setpoint >= 0 [%] and setpoint <= 20 [%]; }
    }

    requirement def DoorSafety {
        doc /* When the chamber door is open, the heating, humidification, and CO2 injection systems shall be disabled. */
    }

    requirement def AlarmOnDeviation {
        doc /* The alarm system shall activate when any environmental parameter deviates beyond its tolerance for more than the max latency. */
        attribute maxLatency : DurationS = 5 [s];
    }

    requirement def OperationalStates {
        doc /* The incubator shall operate through Startup, Maintaining, DoorOpen, and Alarm states with defined transitions. */
    }

    requirement def StartupBehavior {
        doc /* On power-on, the incubator shall enter Startup mode and reach target conditions within the max startup time. */
        attribute maxStartupTime : DurationS = 600 [s];
    }

    requirement def ChamberSealing {
        doc /* The chamber shall be sealed to maintain the controlled environment when the door is closed. */
    }

    requirement def UserConfigurableTargets {
        doc /* The user shall be able to set target temperature, humidity, and CO2 concentration through the user interface. */
    }

    requirement def SensorAccuracy {
        doc /* All sensors shall provide readings within their specified accuracy at the defined sample rate. */
    }

    requirement def AlarmAudibility {
        doc /* The alarm shall be audible at a minimum of 80 dB and visible via indicator. */
        attribute minAudibleLevel : SoundLevelDb = 80 [dB];
    }

    // Requirement usages
    requirement tempReq : MaintainTemperature;
    requirement humReq : MaintainHumidity;
    requirement co2Req : MaintainCO2;
    requirement doorReq : DoorSafety;
    requirement alarmReq : AlarmOnDeviation;
    requirement statesReq : OperationalStates;
    requirement startupReq : StartupBehavior;
    requirement chamberSealReq : ChamberSealing;
    requirement uiReq : UserConfigurableTargets;
    requirement sensorAccReq : SensorAccuracy;
    requirement alarmAudReq : AlarmAudibility;

    // Satisfactions
    satisfaction tempSatisfy satisfy tempReq by Incubator.heater;
    satisfaction humSatisfy satisfy humReq by Incubator.humidifier;
    satisfaction co2Satisfy satisfy co2Req by Incubator.co2Injector;
    satisfaction doorSatisfy satisfy doorReq by Incubator.doorSensor;
    satisfaction alarmSatisfy satisfy alarmReq by Incubator.alarms;
    satisfaction statesSatisfy satisfy statesReq by Incubator.controlUnit;
    satisfaction startupSatisfy satisfy startupReq by Incubator.controlUnit;
    satisfaction chamberSealSatisfy satisfy chamberSealReq by Incubator.chamber;
    satisfaction uiSatisfy satisfy uiReq by Incubator.ui;
    satisfaction sensorAccSatisfy satisfy sensorAccReq by Incubator.tempSensor;
    satisfaction sensorAccSatisfy2 satisfy sensorAccReq by Incubator.humiditySensor;
    satisfaction sensorAccSatisfy3 satisfy sensorAccReq by Incubator.co2Sensor;
    satisfaction alarmAudSatisfy satisfy alarmAudReq by Incubator.alarms;
}
