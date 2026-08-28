package OpenHABHomeAutomation {
    private import ScalarValues::*;

    attribute def TemperatureValue :> Real {
        doc /* Temperature in degrees Celsius */
    }
    attribute def IlluminanceValue :> Real {
        doc /* Illuminance in lux */
    }
    attribute def BrightnessValue :> Real {
        doc /* Brightness percentage 0-100 */
    }

    attribute def DeviceEvent {
        attribute source : String;
        attribute payload : String;
    }
    attribute def HVACCommand {
        attribute mode : String;
    }

    port def EventBusPort {
        in eventIn : DeviceEvent;
        out eventOut : DeviceEvent;
    }
    port def DevicePort {
        out eventOut : DeviceEvent;
        in eventIn : DeviceEvent;
    }
    port def HVACOutPort {
        out hvacCmd : HVACCommand;
    }
    port def HVACInPort {
        in hvacCmd : HVACCommand;
    }

    part def Binding {
        port bindingPort : EventBusPort;
        port devicePort : DevicePort;

        state BindingOperation {
            entry; then idle;
            state idle;
                accept evt : DeviceEvent via devicePort
                do action {
                    send evt via bindingPort;
                }
                then idle;
                accept cmd : DeviceEvent via bindingPort
                do action {
                    send cmd via devicePort;
                }
                then idle;
        }
    }

    part def Sensor {
        port devicePort : DevicePort;
    }

    part def Actuator {
        port devicePort : DevicePort;
    }

    part def TemperatureSensor :> Sensor {
        attribute currentTemp : TemperatureValue = 22;
        state Sensing {
            entry; then idle;
            state idle;
                entry send new DeviceEvent("TempSensor", "22") via devicePort;
        }
    }

    part def MotionSensor :> Sensor {
        attribute motionDetected : Boolean = false;
        state Detection {
            entry; then noMotion;
            state noMotion;
                when motionDetected then motion;
            state motion;
                entry send new DeviceEvent("MotionSensor", "true") via devicePort;
        }
    }

    part def LightSensor :> Sensor {
        attribute ambientLight : IlluminanceValue = 500;
        state Sensing {
            entry; then idle;
            state idle;
                entry send new DeviceEvent("LightSensor", "500") via devicePort;
        }
    }

    part def DimmableLight :> Actuator {
        attribute brightness : BrightnessValue = 0;
        state Control {
            entry; then off;
            state off;
                accept evt : DeviceEvent via devicePort
                then on;
            state on;
                accept evt : DeviceEvent via devicePort
                then on;
        }
    }

    part def SmartThermostat :> Actuator {
        port hvacOut : HVACOutPort;
        attribute targetTemp : TemperatureValue = 22;
        state Regulation {
            entry; then idle;
            state idle;
                accept evt : DeviceEvent via devicePort
                then regulating;
            state regulating;
                entry send new HVACCommand("heatOn") via hvacOut;
        }
    }

    part def HVACSystem {
        port hvacIn : HVACInPort;
    }

    part def OpenHABController {
        port controllerBusPort : EventBusPort;

        part eventBus {
            port busPort : EventBusPort;
            state BusOperation {
                entry; then idle;
                state idle;
                    accept evt : DeviceEvent via busPort
                    do action {
                        send evt via busPort;
                    }
                    then idle;
            }
        }

        part rulesEngine {
            port enginePort : EventBusPort;
            state RuleEvaluation {
                entry; then listening;
                state listening;
                    accept evt : DeviceEvent via enginePort
                    do action {
                        // evaluate rules and emit commands
                    }
                    then listening;
            }
        }

        part persistenceService {
            port persistPort : EventBusPort;
            attribute history : DeviceEvent[*];
            state Logging {
                entry; then listening;
                state listening;
                    accept evt : DeviceEvent via persistPort
                    do action {
                        // store event in history
                    }
                    then listening;
            }
        }

        part userInterface {
            port uiPort : EventBusPort;
            state Dashboard {
                entry; then listening;
                state listening;
                    accept evt : DeviceEvent via uiPort
                    do action {
                        // display event on dashboard
                    }
                    then listening;
            }
        }

        part zigbeeBinding : Binding {}
        part zwaveBinding : Binding {}
        part mqttBinding : Binding {}

        connect eventBus.busPort to rulesEngine.enginePort;
        connect eventBus.busPort to persistenceService.persistPort;
        connect eventBus.busPort to userInterface.uiPort;
        connect eventBus.busPort to zigbeeBinding.bindingPort;
        connect eventBus.busPort to zwaveBinding.bindingPort;
        connect eventBus.busPort to mqttBinding.bindingPort;
    }

    part def HomeSystem {
        part controller : OpenHABController;
        part livingRoomTempSensor : TemperatureSensor;
        part livingRoomMotionSensor : MotionSensor;
        part outdoorLightSensor : LightSensor;
        part livingRoomLight : DimmableLight;
        part bedroomLight : DimmableLight;
        part thermostat : SmartThermostat;
        part hvac : HVACSystem;

        connect livingRoomTempSensor.devicePort to controller.zigbeeBinding.devicePort;
        connect livingRoomMotionSensor.devicePort to controller.zigbeeBinding.devicePort;
        connect outdoorLightSensor.devicePort to controller.zwaveBinding.devicePort;
        connect livingRoomLight.devicePort to controller.zigbeeBinding.devicePort;
        connect bedroomLight.devicePort to controller.zigbeeBinding.devicePort;
        connect thermostat.devicePort to controller.mqttBinding.devicePort;
        connect thermostat.hvacOut to hvac.hvacIn;
    }

    requirement def IntegrationRequirement {
        doc /* The system shall integrate devices using Zigbee, Z-Wave, and MQTT bindings. */
    }
    requirement def EventBusRequirement {
        doc /* The system shall have an event bus that broadcasts state changes to all interested components. */
    }
    requirement def RuleEngineRequirement {
        doc /* The system shall execute automation rules based on sensor events. */
    }
    requirement def PersistenceRequirement {
        doc /* The system shall log device state history and restore states after power outage. */
    }
    requirement def UIRequirement {
        doc /* The system shall provide a user interface for monitoring and manual control. */
    }

    requirement integrationReq : IntegrationRequirement;
    requirement eventBusReq : EventBusRequirement;
    requirement ruleEngineReq : RuleEngineRequirement;
    requirement persistenceReq : PersistenceRequirement;
    requirement uiReq : UIRequirement;

    part homeSystem : HomeSystem;

    satisfy integrationReq by homeSystem;
    satisfy eventBusReq by homeSystem.controller.eventBus;
    satisfy ruleEngineReq by homeSystem.controller.rulesEngine;
    satisfy persistenceReq by homeSystem.controller.persistenceService;
    satisfy uiReq by homeSystem.controller.userInterface;
}
