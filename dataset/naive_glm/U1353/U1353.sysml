package OpenHABHomeAutomation {
    import ScalarValues::*;

    package Units {
        value def TemperatureValue :> Real;
        unit def Celsius of TemperatureValue;

        value def BrightnessValue :> Real;
        unit def Lux of BrightnessValue;

        value def PercentageValue :> Real;
        unit def Percent of PercentageValue;

        value def TimeValue :> Real;
        unit def Second of TimeValue;
    }

    package Items {
        import Units::*;

        enum def HVACMode {
            OFF;
            HEAT;
            COOL;
            AUTO;
        }

        item def StateUpdate {
            attribute itemName : String;
            attribute value : String;
            attribute timestamp : TimeValue;
        }

        item def DeviceCommand {
            attribute targetItem : String;
            attribute command : String;
        }

        item def TemperatureReading {
            attribute value : TemperatureValue;
            attribute unit : String = "Celsius";
        }

        item def MotionReading {
            attribute triggered : Boolean;
        }

        item def BrightnessReading {
            attribute value : BrightnessValue;
            attribute unit : String = "Lux";
        }

        item def DimmerCommand {
            attribute level : PercentageValue;
        }

        item def ThermostatCommand {
            attribute targetTemperature : TemperatureValue;
            attribute mode : HVACMode;
        }
    }

    package Ports {
        import Items::*;

        port def BusPort {
            in item update : StateUpdate;
            out item broadcast : StateUpdate;
            out item command : DeviceCommand;
        }

        port def DevicePort {
            in item command : DeviceCommand;
            out item update : StateUpdate;
        }
    }

    package Devices {
        import Ports::*;
        import Items::*;
        import Units::*;

        part def Sensor {
            port devicePort : DevicePort;
            attribute name : String;
            attribute location : String;
        }

        part def Actuator {
            port devicePort : DevicePort;
            attribute name : String;
            attribute location : String;
        }

        part def TemperatureSensor :> Sensor {
            item currentReading : TemperatureReading;
            attribute currentValue : TemperatureValue;

            action def TakeReading {
                in currentTemp : TemperatureValue;
                out reading : TemperatureReading;
            }

            perform takeReading : TakeReading;
        }

        part def MotionSensor :> Sensor {
            item currentReading : MotionReading;
            attribute motionDetected : Boolean = false;

            state motionState {
                entry; then Idle;
                state Idle;
                transition from Idle to Triggered when motionDetected;
                state Triggered;
                transition from Triggered to Idle when not motionDetected;
            }
        }

        part def LightSensor :> Sensor {
            item currentReading : BrightnessReading;
            attribute currentValue : BrightnessValue;
            attribute darkThreshold : BrightnessValue = 50;
            attribute isDark : Boolean;

            action def MeasureBrightness {
                in rawValue : BrightnessValue;
                out reading : BrightnessReading;
            }

            perform measureBrightness : MeasureBrightness;
        }

        part def DimmableLight :> Actuator {
            attribute brightness : PercentageValue = 0;
            attribute isOn : Boolean = false;

            state lightState {
                entry; then Off;
                state Off;
                transition from Off to On when isOn;
                state On;
                transition from On to Off when not isOn;
            }

            action def SetBrightness {
                in level : PercentageValue;
                out newBrightness : PercentageValue;
            }

            action def TurnOn;
            action def TurnOff;

            perform setBrightness : SetBrightness;
        }

        part def SmartThermostat :> Actuator {
            attribute currentTemperature : TemperatureValue;
            attribute targetTemperature : TemperatureValue = 22.0;
            attribute mode : HVACMode = HVACMode::OFF;
            attribute deadband : TemperatureValue = 1.0;

            state thermostatState {
                entry; then Idle;
                state Idle;
                transition from Idle to Heating when currentTemperature < targetTemperature - deadband;
                state Heating;
                transition from Heating to Idle when currentTemperature >= targetTemperature;
                transition from Idle to Cooling when currentTemperature > targetTemperature + deadband;
                state Cooling;
                transition from Cooling to Idle when currentTemperature <= targetTemperature;
            }

            action def UpdateTarget {
                in newTarget : TemperatureValue;
                out updatedTarget : TemperatureValue;
            }

            action def ActivateHVAC {
                in hvacMode : HVACMode;
            }

            perform updateTarget : UpdateTarget;
        }
    }

    package Bindings {
        import Ports::*;
        import Items::*;

        part def Binding {
            port busPort : BusPort;
            port devicePort : DevicePort;
            attribute protocol : String;

            action def TranslateToDevice {
                in command : DeviceCommand;
                out translated : DeviceCommand;
            }

            action def TranslateFromDevice {
                in update : StateUpdate;
                out translated : StateUpdate;
            }

            perform translateToDevice : TranslateToDevice;
            perform translateFromDevice : TranslateFromDevice;
        }

        part def ZigbeeBinding :> Binding {
            attribute protocol : String = "Zigbee";
        }

        part def ZWaveBinding :> Binding {
            attribute protocol : String = "Z-Wave";
        }

        part def MQTTBinding :> Binding {
            attribute protocol : String = "MQTT";
        }
    }

    package Core {
        import Ports::*;
        import Items::*;
        import Bindings::*;
        import Units::*;

        part def EventBus {
            port busPort : BusPort;
            attribute subscriberCount : Integer = 0;

            action def Broadcast {
                in update : StateUpdate;
                out broadcasts : StateUpdate[*];
            }

            action def ReceiveUpdate {
                in update : StateUpdate;
                out received : StateUpdate;
            }

            perform broadcast : Broadcast;
            perform receiveUpdate : ReceiveUpdate;
        }

        part def RulesEngine {
            port busPort : BusPort;
            attribute ruleCount : Integer = 0;

            action def EvaluateRule {
                in update : StateUpdate;
                out command : DeviceCommand;
            }

            action def ExecuteAutomation {
                in trigger : StateUpdate;
                in context : StateUpdate[*];
                out commands : DeviceCommand[*];
            }

            action def MotionLightRule {
                in motionEvent : StateUpdate;
                in brightnessEvent : StateUpdate;
                out lightCommand : DeviceCommand;
            }

            action def ThermostatRule {
                in tempEvent : StateUpdate;
                in targetTemp : TemperatureValue;
                out thermostatCommand : DeviceCommand;
            }

            perform evaluateRule : EvaluateRule;
            perform executeAutomation : ExecuteAutomation;
            perform motionLightRule : MotionLightRule;
            perform thermostatRule : ThermostatRule;
        }

        part def PersistenceService {
            port busPort : BusPort;
            attribute storagePath : String;
            attribute recordCount : Integer = 0;

            action def StoreState {
                in update : StateUpdate;
            }

            action def RestoreState {
                in itemName : String;
                out restored : StateUpdate;
            }

            action def QueryHistory {
                in itemName : String;
                in startTime : TimeValue;
                in endTime : TimeValue;
                out history : StateUpdate[*];
            }

            perform storeState : StoreState;
            perform restoreState : RestoreState;
            perform queryHistory : QueryHistory;
        }

        part def UserInterface {
            port busPort : BusPort;

            action def DisplayDashboard {
                in updates : StateUpdate[*];
            }

            action def SendCommand {
                out command : DeviceCommand;
            }

            action def AdjustBrightness {
                in itemName : String;
                in level : PercentageValue;
                out command : DeviceCommand;
            }

            action def SetThermostat {
                in targetTemp : TemperatureValue;
                out command : DeviceCommand;
            }

            perform displayDashboard : DisplayDashboard;
            perform sendCommand : SendCommand;
            perform adjustBrightness : AdjustBrightness;
            perform setThermostat : SetThermostat;
        }

        part def CentralController {
            port busPort : BusPort;

            part eventBus : EventBus;
            part rulesEngine : RulesEngine;
            part persistence : PersistenceService;
            part ui : UserInterface;
            part zigbeeBinding : ZigbeeBinding;
            part zWaveBinding : ZWaveBinding;
            part mqttBinding : MQTTBinding;

            connection busToRules connect eventBus.busPort to rulesEngine.busPort;
            connection busToPersistence connect eventBus.busPort to persistence.busPort;
            connection busToUI connect eventBus.busPort to ui.busPort;
            connection busToZigbee connect eventBus.busPort to zigbeeBinding.busPort;
            connection busToZWave connect eventBus.busPort to zWaveBinding.busPort;
            connection busToMQTT connect eventBus.busPort to mqttBinding.busPort;
        }
    }

    package Home {
        import Devices::*;
        import Core::*;
        import Ports::*;

        part livingRoomTempSensor : TemperatureSensor {
            attribute name = "LivingRoomTemperature";
            attribute location = "LivingRoom";
        }

        part livingRoomMotionSensor : MotionSensor {
            attribute name = "LivingRoomMotion";
            attribute location = "LivingRoom";
        }

        part outdoorLightSensor : LightSensor {
            attribute name = "OutdoorBrightness";
            attribute location = "Outdoor";
        }

        part livingRoomLight : DimmableLight {
            attribute name = "LivingRoomLight";
            attribute location = "LivingRoom";
        }

        part bedroomLight : DimmableLight {
            attribute name = "BedroomLight";
            attribute location = "Bedroom";
        }

        part thermostat : SmartThermostat {
            attribute name = "CentralThermostat";
            attribute location = "Hallway";
            attribute targetTemperature = 22.0;
        }

        part controller : CentralController;

        connection tempSensorToZigbee connect livingRoomTempSensor.devicePort to controller.zigbeeBinding.devicePort;
        connection motionSensorToZigbee connect livingRoomMotionSensor.devicePort to controller.zigbeeBinding.devicePort;
        connection lightSensorToMQTT connect outdoorLightSensor.devicePort to controller.mqttBinding.devicePort;
        connection livingLightToZWave connect livingRoomLight.devicePort to controller.zWaveBinding.devicePort;
        connection bedroomLightToZWave connect bedroomLight.devicePort to controller.zWaveBinding.devicePort;
        connection thermostatToMQTT connect thermostat.devicePort to controller.mqttBinding.devicePort;
    }

    package Requirements {
        requirement def IntegrationRequirement {
            attribute id : String;
            attribute text : String;
        }

        requirement centralControllerReq : IntegrationRequirement {
            attribute id = "REQ-001";
            attribute text = "The system shall include a central controller that orchestrates all communication and logic.";
        }

        requirement eventBusReq : IntegrationRequirement {
            attribute id = "REQ-002";
            attribute text = "The system shall use an event bus to broadcast device status changes to interested components.";
        }

        requirement bindingReq : IntegrationRequirement {
            attribute id = "REQ-003";
            attribute text = "The system shall support Zigbee, Z-Wave, and MQTT bindings to communicate with devices using different protocols.";
        }

        requirement sensorReq : IntegrationRequirement {
            attribute id = "REQ-004";
            attribute text = "The system shall include a living room temperature sensor, a living room motion sensor, and an outdoor light sensor.";
        }

        requirement actuatorReq : IntegrationRequirement {
            attribute id = "REQ-005";
            attribute text = "The system shall include dimmable lights in the living room and bedroom, and a central smart thermostat.";
        }

        requirement rulesEngineReq : IntegrationRequirement {
            attribute id = "REQ-006";
            attribute text = "The system shall include a rules engine that listens to sensor events and executes user-defined automation logic.";
        }

        requirement autoLightRuleReq : IntegrationRequirement {
            attribute id = "REQ-007";
            attribute text = "A rule shall turn on the living room lights when motion is detected and outdoor brightness is below threshold.";
        }

        requirement thermostatAutoReq : IntegrationRequirement {
            attribute id = "REQ-008";
            attribute text = "The thermostat shall autonomously compare actual temperature to target and activate HVAC accordingly.";
        }

        requirement persistenceReq : IntegrationRequirement {
            attribute id = "REQ-009";
            attribute text = "The system shall include a persistence service that logs device state history and restores last known states after power outage.";
        }

        requirement uiReq : IntegrationRequirement {
            attribute id = "REQ-010";
            attribute text = "The system shall provide a user interface dashboard for monitoring devices and manual control.";
        }
    }

    satisfy Requirements::centralControllerReq by Home::controller;
    satisfy Requirements::eventBusReq by Home::controller.eventBus;
    satisfy Requirements::bindingReq by Home::controller.zigbeeBinding;
    satisfy Requirements::bindingReq by Home::controller.zWaveBinding;
    satisfy Requirements::bindingReq by Home::controller.mqttBinding;
    satisfy Requirements::sensorReq by Home::livingRoomTempSensor;
    satisfy Requirements::sensorReq by Home::livingRoomMotionSensor;
    satisfy Requirements::sensorReq by Home::outdoorLightSensor;
    satisfy Requirements::actuatorReq by Home::livingRoomLight;
    satisfy Requirements::actuatorReq by Home::bedroomLight;
    satisfy Requirements::actuatorReq by Home::thermostat;
    satisfy Requirements::rulesEngineReq by Home::controller.rulesEngine;
    satisfy Requirements::autoLightRuleReq by Home::controller.rulesEngine;
    satisfy Requirements::thermostatAutoReq by Home::thermostat;
    satisfy Requirements::persistenceReq by Home::controller.persistence;
    satisfy Requirements::uiReq by Home::controller.ui;
}
