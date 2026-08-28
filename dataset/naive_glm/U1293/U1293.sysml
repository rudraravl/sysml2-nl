package HomeAutomationSystem {
import ScalarValues::*;

// ===== Units =====
unit degC;
unit pct;
unit W;
unit kWh;
unit lux;
unit ppm;
unit s;

// ===== Value Types =====
value def Temperature :> Real { unit degC; }
value def Humidity :> Real { unit pct; }
value def Power :> Real { unit W; }
value def Energy :> Real { unit kWh; }
value def Illuminance :> Real { unit lux; }
value def CO2Concentration :> Real { unit ppm; }
value def Brightness :> Real { unit pct; }
value def Duration :> Real { unit s; }

// ===== Enumerations =====
enum def SecurityMode { armedAway; armedStay; disarmed; }
enum def DoorStatus { closed; open; }
enum def LockStatus { locked; unlocked; }
enum def OccupancyState { occupied; empty; }
enum def AlarmState { idle; triggered; }
enum def HvacMode { heating; cooling; off; }
enum def RoomId { livingRoom; bedroom; kitchen; }

// ===== Item Definitions =====
item def TemperatureReading {
    attribute value : Temperature;
    attribute room : RoomId;
}
item def HumidityReading {
    attribute value : Humidity;
    attribute room : RoomId;
}
item def AirQualityReading {
    attribute co2 : CO2Concentration;
    attribute room : RoomId;
}
item def OccupancyReading {
    attribute state : OccupancyState;
    attribute room : RoomId;
}
item def MotionReading {
    attribute detected : Boolean;
    attribute room : RoomId;
}
item def LightReading {
    attribute level : Illuminance;
    attribute room : RoomId;
}
item def DoorWindowReading {
    attribute status : DoorStatus;
    attribute location : String;
}
item def LockReading {
    attribute status : LockStatus;
    attribute doorId : String;
}
item def PowerReading {
    attribute value : Power;
    attribute deviceId : String;
}
item def HvacCommand {
    attribute mode : HvacMode;
    attribute targetTemp : Temperature;
    attribute room : RoomId;
}
item def LightCommand {
    attribute brightness : Brightness;
    attribute room : RoomId;
}
item def LockCommand {
    attribute status : LockStatus;
    attribute doorId : String;
}
item def AlarmCommand {
    attribute state : AlarmState;
}
item def UserPreferences {
    attribute comfortTemp : Temperature = 22;
    attribute awayTemp : Temperature = 18;
    attribute securityMode : SecurityMode = SecurityMode::disarmed;
    attribute maxBrightness : Brightness = 80;
}

// ===== Port Definitions =====
port def TempOutPort { out item temp : TemperatureReading; }
port def HumOutPort { out item hum : HumidityReading; }
port def AqOutPort { out item aq : AirQualityReading; }
port def OccOutPort { out item occ : OccupancyReading; }
port def MotOutPort { out item mot : MotionReading; }
port def LightOutPort { out item light : LightReading; }
port def DwOutPort { out item dw : DoorWindowReading; }
port def LockOutPort { out item lock : LockReading; }
port def PowerOutPort { out item power : PowerReading; }
port def HvacCmdInPort { in item cmd : HvacCommand; }
port def LightCmdInPort { in item cmd : LightCommand; }
port def LockCmdInPort { in item cmd : LockCommand; }
port def AlarmCmdInPort { in item cmd : AlarmCommand; }

// ===== Sensor Part Definitions =====
part def TemperatureSensor {
    port out tempOut : TempOutPort;
    attribute room : RoomId;
    attribute sampleInterval : Duration = 5 [s];
    action def sense {
        out reading : TemperatureReading;
    }
}

part def HumiditySensor {
    port out humOut : HumOutPort;
    attribute room : RoomId;
}

part def AirQualitySensor {
    port out aqOut : AqOutPort;
    attribute room : RoomId;
}

part def OccupancySensor {
    port out occOut : OccOutPort;
    attribute room : RoomId;
}

part def MotionSensor {
    port out motOut : MotOutPort;
    attribute room : RoomId;
}

part def LightSensor {
    port out lightOut : LightOutPort;
    attribute room : RoomId;
}

part def DoorWindowSensor {
    port out dwOut : DwOutPort;
    attribute location : String;
}

part def SmartLock {
    port out lockOut : LockOutPort;
    port in lockCmdIn : LockCmdInPort;
    attribute doorId : String;
    attribute status : LockStatus = LockStatus::locked;
    state def LockStateMachine {
        entry; then Locked;
        state Locked {
            entry { status = LockStatus::locked; }
        }
        state Unlocked {
            entry { status = LockStatus::unlocked; }
        }
        transition t1 first Locked then Unlocked
            when lockCmdIn.cmd.status == LockStatus::unlocked;
        transition t2 first Unlocked then Locked
            when lockCmdIn.cmd.status == LockStatus::locked;
    }
}

part def PowerMeter {
    port out powerOut : PowerOutPort;
    attribute deviceId : String;
    attribute currentPower : Power = 0;
}

// ===== Device Part Definitions =====
part def HvacUnit {
    port in cmdIn : HvacCmdInPort;
    port out powerOut : PowerOutPort;
    attribute room : RoomId;
    attribute mode : HvacMode = HvacMode::off;
    attribute currentTemp : Temperature = 20;
    attribute maxPower : Power = 2000 [W];
    state def HvacStateMachine {
        entry; then Off;
        state Off {
            entry { mode = HvacMode::off; }
        }
        state Heating {
            entry { mode = HvacMode::heating; }
        }
        state Cooling {
            entry { mode = HvacMode::cooling; }
        }
        transition t1 first Off then Heating
            when cmdIn.cmd.mode == HvacMode::heating;
        transition t2 first Off then Cooling
            when cmdIn.cmd.mode == HvacMode::cooling;
        transition t3 first Heating then Off
            when cmdIn.cmd.mode == HvacMode::off;
        transition t4 first Cooling then Off
            when cmdIn.cmd.mode == HvacMode::off;
    }
}

part def SmartLight {
    port in cmdIn : LightCmdInPort;
    port out powerOut : PowerOutPort;
    attribute room : RoomId;
    attribute brightness : Brightness = 0;
    attribute maxPower : Power = 60 [W];
}

part def SecurityPanel {
    port in alarmCmdIn : AlarmCmdInPort;
    attribute mode : SecurityMode = SecurityMode::disarmed;
    attribute alarmState : AlarmState = AlarmState::idle;
    state def SecurityStateMachine {
        entry; then Disarmed;
        state Disarmed {
            entry { alarmState = AlarmState::idle; }
        }
        state ArmedAway {
            entry { mode = SecurityMode::armedAway; }
        }
        state ArmedStay {
            entry { mode = SecurityMode::armedStay; }
        }
        state AlarmTriggered {
            entry { alarmState = AlarmState::triggered; }
        }
        transition t1 first Disarmed then ArmedAway
            when mode == SecurityMode::armedAway;
        transition t2 first Disarmed then ArmedStay
            when mode == SecurityMode::armedStay;
        transition t3 first ArmedAway then Disarmed
            when mode == SecurityMode::disarmed;
        transition t4 first ArmedStay then Disarmed
            when mode == SecurityMode::disarmed;
        transition t5 first ArmedAway then AlarmTriggered
            when alarmCmdIn.cmd.state == AlarmState::triggered;
        transition t6 first ArmedStay then AlarmTriggered
            when alarmCmdIn.cmd.state == AlarmState::triggered;
        transition t7 first AlarmTriggered then Disarmed
            when mode == SecurityMode::disarmed;
    }
}

// ===== Central Controller =====
part def CentralController {
    port in tempIn : ~TempOutPort [*];
    port in humIn : ~HumOutPort [*];
    port in aqIn : ~AqOutPort [*];
    port in occIn : ~OccOutPort [*];
    port in motIn : ~MotOutPort [*];
    port in lightIn : ~LightOutPort [*];
    port in dwIn : ~DwOutPort [*];
    port in lockIn : ~LockOutPort [*];
    port in powerIn : ~PowerOutPort [*];
    port out hvacCmdOut : ~HvacCmdInPort [*];
    port out lightCmdOut : ~LightCmdInPort [*];
    port out lockCmdOut : ~LockCmdInPort [*];
    port out alarmCmdOut : ~AlarmCmdInPort;

    attribute preferences : UserPreferences;
    attribute totalPower : Power = 0;
    attribute totalEnergy : Energy = 0;
    attribute securityMode : SecurityMode = SecurityMode::disarmed;

    action def evaluateClimate {
        in occ : OccupancyReading;
        in temp : TemperatureReading;
        in prefs : UserPreferences;
        out cmd : HvacCommand;
    }
    action def evaluateLighting {
        in occ : OccupancyReading;
        in light : LightReading;
        in prefs : UserPreferences;
        out cmd : LightCommand;
    }
    action def evaluateSecurity {
        in mot : MotionReading;
        in dw : DoorWindowReading;
        in lock : LockReading;
        in mode : SecurityMode;
        out lockCmd : LockCommand;
        out alarmCmd : AlarmCommand;
    }
    action def evaluateEnergy {
        in power : PowerReading;
        out total : Power;
    }

    state def ControllerStateMachine {
        entry; then Monitoring;
        state Monitoring;
        state IntrusionResponse;
        transition t1 first Monitoring then IntrusionResponse
            when alarmCmdOut.cmd.state == AlarmState::triggered;
        transition t2 first IntrusionResponse then Monitoring
            when alarmCmdOut.cmd.state == AlarmState::idle;
    }
}

// ===== System =====
part def HomeAutomationSystem {
    part controller : CentralController;
    part securityPanel : SecurityPanel;

    part livingRoomTempSensor : TemperatureSensor { attribute room = RoomId::livingRoom; }
    part bedroomTempSensor : TemperatureSensor { attribute room = RoomId::bedroom; }
    part kitchenTempSensor : TemperatureSensor { attribute room = RoomId::kitchen; }

    part livingRoomHumSensor : HumiditySensor { attribute room = RoomId::livingRoom; }
    part bedroomHumSensor : HumiditySensor { attribute room = RoomId::bedroom; }
    part kitchenHumSensor : HumiditySensor { attribute room = RoomId::kitchen; }

    part livingRoomAqSensor : AirQualitySensor { attribute room = RoomId::livingRoom; }
    part bedroomAqSensor : AirQualitySensor { attribute room = RoomId::bedroom; }
    part kitchenAqSensor : AirQualitySensor { attribute room = RoomId::kitchen; }

    part livingRoomOccSensor : OccupancySensor { attribute room = RoomId::livingRoom; }
    part bedroomOccSensor : OccupancySensor { attribute room = RoomId::bedroom; }
    part kitchenOccSensor : OccupancySensor { attribute room = RoomId::kitchen; }

    part livingRoomMotSensor : MotionSensor { attribute room = RoomId::livingRoom; }
    part bedroomMotSensor : MotionSensor { attribute room = RoomId::bedroom; }
    part kitchenMotSensor : MotionSensor { attribute room = RoomId::kitchen; }

    part livingRoomLightSensor : LightSensor { attribute room = RoomId::livingRoom; }
    part bedroomLightSensor : LightSensor { attribute room = RoomId::bedroom; }
    part kitchenLightSensor : LightSensor { attribute room = RoomId::kitchen; }

    part frontDoorSensor : DoorWindowSensor { attribute location = "frontDoor"; }
    part backDoorSensor : DoorWindowSensor { attribute location = "backDoor"; }
    part livingRoomWindowSensor : DoorWindowSensor { attribute location = "livingRoomWindow"; }
    part bedroomWindowSensor : DoorWindowSensor { attribute location = "bedroomWindow"; }

    part frontDoorLock : SmartLock { attribute doorId = "frontDoor"; }
    part backDoorLock : SmartLock { attribute doorId = "backDoor"; }

    part mainHvac : HvacUnit { attribute room = RoomId::livingRoom; }
    part bedroomHvac : HvacUnit { attribute room = RoomId::bedroom; }

    part livingRoomLight : SmartLight { attribute room = RoomId::livingRoom; }
    part bedroomLight : SmartLight { attribute room = RoomId::bedroom; }
    part kitchenLight : SmartLight { attribute room = RoomId::kitchen; }

    part hvacPowerMeter : PowerMeter { attribute deviceId = "hvac"; }
    part lightingPowerMeter : PowerMeter { attribute deviceId = "lighting"; }

    // Connections - sensors to controller
    connect livingRoomTempSensor.tempOut to controller.tempIn;
    connect bedroomTempSensor.tempOut to controller.tempIn;
    connect kitchenTempSensor.tempOut to controller.tempIn;

    connect livingRoomHumSensor.humOut to controller.humIn;
    connect bedroomHumSensor.humOut to controller.humIn;
    connect kitchenHumSensor.humOut to controller.humIn;

    connect livingRoomAqSensor.aqOut to controller.aqIn;
    connect bedroomAqSensor.aqOut to controller.aqIn;
    connect kitchenAqSensor.aqOut to controller.aqIn;

    connect livingRoomOccSensor.occOut to controller.occIn;
    connect bedroomOccSensor.occOut to controller.occIn;
    connect kitchenOccSensor.occOut to controller.occIn;

    connect livingRoomMotSensor.motOut to controller.motIn;
    connect bedroomMotSensor.motOut to controller.motIn;
    connect kitchenMotSensor.motOut to controller.motIn;

    connect livingRoomLightSensor.lightOut to controller.lightIn;
    connect bedroomLightSensor.lightOut to controller.lightIn;
    connect kitchenLightSensor.lightOut to controller.lightIn;

    connect frontDoorSensor.dwOut to controller.dwIn;
    connect backDoorSensor.dwOut to controller.dwIn;
    connect livingRoomWindowSensor.dwOut to controller.dwIn;
    connect bedroomWindowSensor.dwOut to controller.dwIn;

    connect frontDoorLock.lockOut to controller.lockIn;
    connect backDoorLock.lockOut to controller.lockIn;

    connect hvacPowerMeter.powerOut to controller.powerIn;
    connect lightingPowerMeter.powerOut to controller.powerIn;

    // Connections - controller to devices
    connect controller.hvacCmdOut to mainHvac.cmdIn;
    connect controller.hvacCmdOut to bedroomHvac.cmdIn;

    connect controller.lightCmdOut to livingRoomLight.cmdIn;
    connect controller.lightCmdOut to bedroomLight.cmdIn;
    connect controller.lightCmdOut to kitchenLight.cmdIn;

    connect controller.lockCmdOut to frontDoorLock.lockCmdIn;
    connect controller.lockCmdOut to backDoorLock.lockCmdIn;

    connect controller.alarmCmdOut to securityPanel.alarmCmdIn;

    // Requirement satisfaction
    satisfy ClimateControlRequirement by controller;
    satisfy EnergyEfficiencyRequirement by controller;
    satisfy SecurityArmedAwayRequirement by controller;
    satisfy LightingControlRequirement by livingRoomLight;
    satisfy OccupancyBasedHvacRequirement by controller;
    satisfy IntrusionDetectionRequirement by securityPanel;
}

// ===== Requirements =====
requirement def ClimateControlRequirement {
    subject controller : CentralController;
    attribute requiredComfortTemp : Temperature = 22;
    require controller.preferences.comfortTemp == requiredComfortTemp;
}

requirement def EnergyEfficiencyRequirement {
    subject controller : CentralController;
    attribute maxStandbyPower : Power = 500 [W];
    require controller.totalPower <= maxStandbyPower;
}

requirement def SecurityArmedAwayRequirement {
    subject controller : CentralController;
    require controller.securityMode == SecurityMode::armedAway implies
        controller.lockCmdOut.cmd.status == LockStatus::locked;
}

requirement def LightingControlRequirement {
    subject light : SmartLight;
    require light.brightness >= 0 and light.brightness <= 100;
}

requirement def OccupancyBasedHvacRequirement {
    subject controller : CentralController;
    attribute roomEmpty : Boolean;
    require roomEmpty implies controller.hvacCmdOut.cmd.mode == HvacMode::off;
}

requirement def IntrusionDetectionRequirement {
    subject panel : SecurityPanel;
    attribute intrusionDetected : Boolean;
    attribute armedAway : Boolean;
    require (armedAway and intrusionDetected) implies
        panel.alarmState == AlarmState::triggered;
}
}
