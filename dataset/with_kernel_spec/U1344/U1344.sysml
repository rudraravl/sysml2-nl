package IFTTT_Automation {

    private import ScalarValues::*;
    private import SI::*;

    item def TriggerEvent {
        attribute sourceId : String;
        attribute timestamp : String;
    }

    item def TemperatureLowEvent :> TriggerEvent {
        attribute temperature : Real;
    }

    item def LocationChangedEvent :> TriggerEvent {
        attribute latitude : Real;
        attribute longitude : Real;
    }

    item def ActionCommand {
        attribute targetDeviceId : String;
        attribute commandType : String;
    }

    item def TurnOnCommand :> ActionCommand;
    item def TurnOffCommand :> ActionCommand;

    item def StatusReport {
        attribute deviceId : String;
        attribute status : String;
        attribute success : Boolean;
    }

    port def TriggerEventPort {
        out item trigger : TriggerEvent;
    }

    port def ActionCommandPort {
        in item command : ActionCommand;
    }

    port def StatusReportPort {
        out item report : StatusReport;
    }

    part def Rule {
        attribute ruleId : String;
        attribute triggerType : String;
        attribute targetDeviceId : String;
        attribute commandType : String;
        attribute active : Boolean := true;
    }

    part def TriggerService {
        port triggerOut : TriggerEventPort;
        attribute serviceId : String;
    }

    part def WeatherService :> TriggerService {
        attribute currentTemperature : Real;
        attribute thresholdTemperature : Real := 15.0;

        exhibit state weatherMonitoring {
            entry; then monitoring;
            state monitoring;
            transition tempLow
                first monitoring
                when currentTemperature < thresholdTemperature
                do send new TemperatureLowEvent(serviceId, "now", currentTemperature) via triggerOut
                then monitoring;
        }
    }

    part def LocationService :> TriggerService {
        attribute currentLatitude : Real;
        attribute currentLongitude : Real;
        attribute previousLatitude : Real;
        attribute previousLongitude : Real;

        exhibit state locationTracking {
            entry; then tracking;
            state tracking;
            transition moved
                first tracking
                when currentLatitude != previousLatitude or currentLongitude != previousLongitude
                do send new LocationChangedEvent(serviceId, "now", currentLatitude, currentLongitude) via triggerOut
                then tracking;
        }
    }

    part def ActionDevice {
        port commandIn : ActionCommandPort;
        port statusOut : StatusReportPort;
        attribute deviceId : String;
        attribute isOn : Boolean := false;

        exhibit state deviceOperation {
            entry; then idle;
            state idle {
                entry assign isOn := false;
            }
            transition turnOn
                first idle
                accept cmd : TurnOnCommand via commandIn
                if cmd.targetDeviceId == deviceId
                do assign isOn := true
                do send new StatusReport(deviceId, "on", true) via statusOut
                then active;
            state active {
                entry assign isOn := true;
            }
            transition turnOffFromActive
                first active
                accept cmd : TurnOffCommand via commandIn
                if cmd.targetDeviceId == deviceId
                do assign isOn := false
                do send new StatusReport(deviceId, "off", true) via statusOut
                then idle;
            transition turnOffFromIdle
                first idle
                accept cmd : TurnOffCommand via commandIn
                if cmd.targetDeviceId == deviceId
                do send new StatusReport(deviceId, "off", true) via statusOut
                then idle;
        }
    }

    part def SmartLight :> ActionDevice {
        attribute brightness : Integer := 0;
    }

    part def SmartThermostat :> ActionDevice {
        attribute targetTemperature : Real := 20.0;
        attribute currentTemperature : Real := 20.0;
    }

    part def RuleEngine {
        port triggerIn : ~TriggerEventPort;
        port commandOut : ~ActionCommandPort;
        port statusIn : ~StatusReportPort;
        attribute rules : Rule[0..*];
        attribute engineId : String := "ruleEngine-001";

        exhibit state engineOperation {
            entry; then waitingForTrigger;
            state waitingForTrigger;
            transition handleTempLow
                first waitingForTrigger
                accept evt : TemperatureLowEvent via triggerIn
                do send new TurnOnCommand("thermostat-001", "turnOn") via commandOut
                then waitingForStatus;
            transition handleLocationChanged
                first waitingForTrigger
                accept evt : LocationChangedEvent via triggerIn
                do send new TurnOnCommand("light-001", "turnOn") via commandOut
                then waitingForStatus;
            state waitingForStatus;
            transition receiveStatus
                first waitingForStatus
                accept report : StatusReport via statusIn
                then waitingForTrigger;
        }
    }

    part def IFTTTPlatform {
        part weatherService : WeatherService {
            attribute :>> serviceId := "weather-001";
            attribute :>> thresholdTemperature := 15.0;
        }
        part locationService : LocationService {
            attribute :>> serviceId := "location-001";
        }
        part ruleEngine : RuleEngine;
        part smartLight : SmartLight {
            attribute :>> deviceId := "light-001";
        }
        part smartThermostat : SmartThermostat {
            attribute :>> deviceId := "thermostat-001";
        }

        interface weatherService.triggerOut to ruleEngine.triggerIn;
        interface locationService.triggerOut to ruleEngine.triggerIn;
        interface ruleEngine.commandOut to smartLight.commandIn;
        interface ruleEngine.commandOut to smartThermostat.commandIn;
        interface smartLight.statusOut to ruleEngine.statusIn;
        interface smartThermostat.statusOut to ruleEngine.statusIn;
    }

    requirement def AutomationRequirement {
        doc /* The platform shall connect trigger services to action devices via a rule engine. */
        subject platform : IFTTTPlatform;
        objective {
            doc /* Ensure automated workflow execution from triggers to actions. */
        }
    }

    requirement def TriggerEvaluationRequirement :> AutomationRequirement {
        doc /* The rule engine shall evaluate all incoming trigger events against active rules. */
        subject engine : RuleEngine;
        objective {
            doc /* Every trigger event must be checked against all active rules for a match. */
        }
    }

    requirement def ActionDispatchRequirement :> AutomationRequirement {
        doc /* The rule engine shall dispatch an action command to the target device when a rule matches. */
        subject engine : RuleEngine;
        objective {
            doc /* Matching rules result in action commands sent to appropriate devices. */
        }
    }

    requirement def DeviceResponseRequirement :> AutomationRequirement {
        doc /* Action devices shall validate commands and report status back to the system. */
        subject device : ActionDevice;
        objective {
            doc /* Devices confirm command execution via status reports. */
        }
    }

    requirement automationReq : AutomationRequirement {
        subject platform = IFTTTPlatform;
    }

    requirement triggerReq : TriggerEvaluationRequirement {
        subject engine = IFTTTPlatform.ruleEngine;
    }

    requirement actionReq : ActionDispatchRequirement {
        subject engine = IFTTTPlatform.ruleEngine;
    }

    requirement deviceReq : DeviceResponseRequirement {
        subject device = IFTTTPlatform.smartThermostat;
    }
}
