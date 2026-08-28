package IFTTT_Platform {

    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types ----

    value type TemperatureValue :> Real {
        unit '°C';
    }

    value type CoordinateValue :> Real {
        unit 'm';
    }

    value type HumidityValue :> Real {
        unit '%';
    }

    value type PowerState :> String;

    value type RuleId :> String;

    value type DeviceId :> String;

    value type ServiceId :> String;

    // ---- Item Definitions ----

    item def TriggerEvent {
        attribute sourceService : ServiceId;
        attribute eventType : String;
        attribute timestamp : String;
        attribute payload : String;
    }

    item def WeatherTriggerEvent :> TriggerEvent {
        attribute eventType : String = "temperatureLow";
        attribute temperature : TemperatureValue;
        attribute threshold : TemperatureValue;
    }

    item def LocationTriggerEvent :> TriggerEvent {
        attribute eventType : String = "locationChanged";
        attribute latitude : CoordinateValue;
        attribute longitude : CoordinateValue;
    }

    item def ActionCommand {
        attribute targetDevice : DeviceId;
        attribute commandType : String;
        attribute parameter : String;
        attribute ruleId : RuleId;
    }

    item def LightCommand :> ActionCommand {
        attribute commandType : String = "setPower";
        attribute powerState : PowerState;
        attribute brightness : Integer;
    }

    item def ThermostatCommand :> ActionCommand {
        attribute commandType : String = "setHeating";
        attribute powerState : PowerState;
        attribute targetTemperature : TemperatureValue;
    }

    item def CommandAck {
        attribute targetDevice : DeviceId;
        attribute status : String;
        attribute detail : String;
    }

    item def AutomationRule {
        attribute ruleId : RuleId;
        attribute description : String;
        attribute triggerService : ServiceId;
        attribute triggerType : String;
        attribute actionDevice : DeviceId;
        attribute actionType : String;
        attribute active : Boolean;
    }

    // ---- Port Definitions ----

    port def TriggerOut {
        out triggerEvent : TriggerEvent;
    }

    port def TriggerIn {
        in triggerEvent : TriggerEvent;
    }

    port def CommandOut {
        out actionCommand : ActionCommand;
    }

    port def CommandIn {
        in actionCommand : ActionCommand;
    }

    port def AckOut {
        out ack : CommandAck;
    }

    port def AckIn {
        in ack : CommandAck;
    }

    // ---- Interfaces ----

    interface def TriggerFlow {
        end source : TriggerOut;
        end target : TriggerIn;
    }

    interface def CommandFlow {
        end source : CommandOut;
        end target : CommandIn;
    }

    interface def AckFlow {
        end source : AckOut;
        end target : AckIn;
    }

    // ---- Trigger Services ----

    part def WeatherService {
        attribute serviceId : ServiceId = "weather-001";
        port triggerPort : TriggerOut;
        attribute currentTemperature : TemperatureValue;
        attribute lowThreshold : TemperatureValue = 15.0;

        state weatherBehavior {
            entry;
            state Monitoring {
                entry;
                do {
                    if (currentTemperature < lowThreshold) {
                        send WeatherTriggerEvent{
            sourceService = "weather-001",
            eventType = "temperatureLow",
            timestamp = "2025-01-01T08:00:00Z",
            payload = "cold-snap",
            temperature = currentTemperature,
            threshold = lowThreshold
        } to triggerPort;
                    }
                }
            }
            accept WeatherTriggerEvent;
        }
    }

    part def LocationService {
        attribute serviceId : ServiceId = "location-001";
        port triggerPort : TriggerOut;
        attribute currentLatitude : CoordinateValue;
        attribute currentLongitude : CoordinateValue;
        attribute homeLatitude : CoordinateValue = 37.7749;
        attribute homeLongitude : CoordinateValue = -122.4194;

        state locationBehavior {
            state Tracking {
                do {
                    send LocationTriggerEvent{
            sourceService = "location-001",
            eventType = "locationChanged",
            timestamp = "2025-01-01T08:05:00Z",
            payload = "user-arrived-home",
            latitude = currentLatitude,
            longitude = currentLongitude
        } to triggerPort;
                }
            }
        }
    }

    // ---- Action Devices ----

    part def SmartLight {
        attribute deviceId : DeviceId = "light-001";
        port commandPort : CommandIn;
        port ackPort : AckOut;
        attribute powerState : PowerState = "off";
        attribute brightness : Integer = 0;

        state lightBehavior {
            state Off {
                entry;
                accept LightCommand[powerState == "on"] then On;
            }
            state On {
                entry;
                accept LightCommand[powerState == "off"] then Off;
            }
        }

        action handleCommand {
            in cmd : LightCommand;
            if (cmd.targetDevice == deviceId) {
                powerState = cmd.powerState;
                brightness = cmd.brightness;
                send CommandAck{
            targetDevice = deviceId,
            status = "success",
            detail = "Light set to " + cmd.powerState
        } to ackPort;
            } else {
                send CommandAck{
            targetDevice = deviceId,
            status = "rejected",
            detail = "Invalid target device"
        } to ackPort;
            }
        }
    }

    part def SmartThermostat {
        attribute deviceId : DeviceId = "thermostat-001";
        port commandPort : CommandIn;
        port ackPort : AckOut;
        attribute powerState : PowerState = "off";
        attribute currentTemperature : TemperatureValue = 18.0;
        attribute targetTemperature : TemperatureValue = 21.0;

        state thermostatBehavior {
            state Idle {
                entry;
                accept ThermostatCommand[powerState == "on"] then Heating;
            }
            state Heating {
                entry;
                do {
                    if (currentTemperature >= targetTemperature) {
                        powerState = "off";
                    }
                }
                accept ThermostatCommand[powerState == "off"] then Idle;
            }
        }

        action handleCommand {
            in cmd : ThermostatCommand;
            if (cmd.targetDevice == deviceId) {
                powerState = cmd.powerState;
                targetTemperature = cmd.targetTemperature;
                send CommandAck{
            targetDevice = deviceId,
            status = "success",
            detail = "Thermostat heating to " + cmd.targetTemperature.toString() + " C"
        } to ackPort;
            } else {
                send CommandAck{
            targetDevice = deviceId,
            status = "rejected",
            detail = "Invalid target device"
        } to ackPort;
            }
        }
    }

    // ---- Rule Engine ----

    part def RuleEngine {
        attribute engineId : String = "rule-engine-001";
        port triggerInPort : TriggerIn;
        port commandOutPort : CommandOut;
        port ackInPort : AckIn;
        attribute ruleBook : AutomationRule[0..*];
        attribute processedCount : Integer = 0;

        action evaluateTrigger {
            in event : TriggerEvent;
            out command : ActionCommand;

            for rule in ruleBook {
                if (rule.active and rule.triggerService == event.sourceService and rule.triggerType == event.eventType) {
                    if (rule.actionDevice == "thermostat-001") {
                        command = ThermostatCommand{
            targetDevice = "thermostat-001",
            commandType = "setHeating",
            parameter = "heat-on",
            ruleId = rule.ruleId,
            powerState = "on",
            targetTemperature = 21.0
        };
                    } elif (rule.actionDevice == "light-001") {
                        command = LightCommand{
            targetDevice = "light-001",
            commandType = "setPower",
            parameter = "light-on",
            ruleId = rule.ruleId,
            powerState = "on",
            brightness = 80
        };
                    }
                }
            }
        }

        state engineBehavior {
            state Listening {
                entry;
                accept TriggerEvent then Evaluating;
            }
            state Evaluating {
                entry;
                do {
                    processedCount = processedCount + 1;
                }
                transition to Listening;
            }
        }
    }

    // ---- Top-level Platform Assembly ----

    part def IFTTTPlatform {
        part ruleEngine : RuleEngine {
            attribute ruleBook : AutomationRole[0..*] = {
                AutomationRule{
            ruleId = "rule-001",
            description = "If temperature low, activate thermostat",
            triggerService = "weather-001",
            triggerType = "temperatureLow",
            actionDevice = "thermostat-001",
            actionType = "setHeating",
            active = true
        },
                AutomationRule{
            ruleId = "rule-002",
            description = "If location changed to home, turn on light",
            triggerService = "location-001",
            triggerType = "locationChanged",
            actionDevice = "light-001",
            actionType = "setPower",
            active = true
        }
            };
        }

        part weatherService : WeatherService {
            attribute currentTemperature : TemperatureValue = 12.0;
        }

        part locationService : LocationService {
            attribute currentLatitude : CoordinateValue = 37.7749;
            attribute currentLongitude : CoordinateValue = -122.4194;
        }

        part smartLight : SmartLight;
        part smartThermostat : SmartThermostat;

        interface weatherToEngine : TriggerFlow connect weatherService.triggerPort to ruleEngine.triggerInPort;
        interface locationToEngine : TriggerFlow connect locationService.triggerPort to ruleEngine.triggerInPort;
        interface engineToLight : CommandFlow connect ruleEngine.commandOutPort to smartLight.commandPort;
        interface engineToThermostat : CommandFlow connect ruleEngine.commandOutPort to smartThermostat.commandPort;
        interface lightToEngine : AckFlow connect smartLight.ackPort to ruleEngine.ackInPort;
        interface thermostatToEngine : AckFlow connect smartThermostat.ackPort to ruleEngine.ackInPort;
    }

    // ---- Requirements ----

    requirement def PlatformRequirement {
        subject platform : IFTTTPlatform;
        objective {
            doc "The platform shall connect trigger services to action devices via user-defined automation rules."
        }
    }

    requirement def TriggerRequirement {
        subject service : TriggerService;
        objective {
            doc "A trigger service shall emit a TriggerEvent when its monitored condition is satisfied."
        }
    }

    requirement def RuleEvaluationRequirement {
        subject engine : RuleEngine;
        objective {
            doc "The Rule Engine shall evaluate every incoming TriggerEvent against all active rules and emit an ActionCommand for each matching rule."
        }
    }

    requirement def ActionExecutionRequirement {
        subject device : SmartLight | SmartThermostat;
        objective {
            doc "An action device shall validate received ActionCommands, execute the requested state change, and report a CommandAck."
        }
    }

    requirement def TemperatureLowRuleRequirement {
        subject rule : AutomationRule;
        objective {
            doc "When the Weather Service reports a temperature below 15 degrees Celsius, the Rule Engine shall command the Smart Thermostat to activate heating."
        }
    }

    requirement def LocationArrivalRuleRequirement {
        subject rule : AutomationRule;
        objective {
            doc "When the Location Service reports a location change, the Rule Engine shall command the Smart Light to turn on."
        }
    }

    requirement platformReq : PlatformRequirement {
        subject platform : IFTTTPlatform;
    }

    requirement triggerReq : TriggerRequirement {
        subject service : WeatherService | LocationService;
    }

    requirement ruleEvalReq : RuleEvaluationRequirement {
        subject engine : ruleEngine;
    }

    requirement actionExecReq : ActionExecutionRequirement {
        subject device : smartLight | smartThermostat;
    }

    requirement tempRuleReq : TemperatureLowRuleRequirement {
        subject rule : AutomationRule;
    }

    requirement locationRuleReq : LocationArrivalRuleRequirement {
        subject rule : AutomationRule;
    }

}
