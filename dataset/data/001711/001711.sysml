package 'IFTTT Automation Platform' {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def RuleID;
    attribute def ServiceID;
    attribute def EventType;
    attribute def ConditionExpression;
    attribute def ActionType;

    value def Timestamp :> Real;
    value def Temperature :> Real;
    value def Brightness :> Real;
    value def LocationCoordinate :> Real;

    item def TriggerEvent {
        attribute eventID : String;
        attribute eventType : EventType;
        attribute sourceService : ServiceID;
        attribute timestamp : Timestamp;
        attribute eventData : String;
    }

    item def ActionCommand {
        attribute commandID : String;
        attribute actionType : ActionType;
        attribute targetService : ServiceID;
        attribute timestamp : Timestamp;
        attribute parameters : String;
    }

    item def RuleDefinition {
        attribute ruleID : RuleID;
        attribute triggerCondition : ConditionExpression;
        attribute actionSpec : ActionType;
        attribute isEnabled : Boolean;
    }

    item def ExecutionResult {
        attribute success : Boolean;
        attribute timestamp : Timestamp;
        attribute errorMessage : String;
    }

    port def TriggerInputPort {
        in item triggerEvent : TriggerEvent;
    }

    port def ActionOutputPort {
        out item actionCommand : ActionCommand;
    }

    port def RuleConfigPort {
        in item ruleDefinition : RuleDefinition;
    }

    port def StatusPort {
        out item executionResult : ExecutionResult;
    }

    part def WeatherService {
        port eventOutput : TriggerInputPort;
        attribute serviceID : ServiceID;
        attribute currentTemp : Temperature;

        action monitorWeather {
            out weatherEvent : TriggerEvent;
            loop {
                action checkConditions {
                    out tempReading : Temperature;
                }
                then decide;
                    if checkConditions.tempReading < 15.0 then generateEvent;
                    if checkConditions.tempReading >= 15.0 then continueMonitoring;
                action generateEvent {
                    then assign weatherEvent.eventType := "temperature_low";
                    then assign weatherEvent.sourceService := serviceID;
                }
                then continueMonitoring;
                merge continueMonitoring;
            }
        }
    }

    part def SmartHomeDevice {
        port commandInput : ActionOutputPort;
        attribute deviceID : ServiceID;
        attribute deviceState : String;

        action executeCommand {
            in cmd : ActionCommand;
            out result : ExecutionResult;
            
            action validateCommand {
                in command : ActionCommand;
                out valid : Boolean;
            }
            then decide;
                if validateCommand.valid then applyCommand;
                if !validateCommand.valid then reportError;
            action applyCommand {
                then assign deviceState := "active";
                then assign result.success := true;
            }
            action reportError {
                then assign result.success := false;
                then assign result.errorMessage := "Invalid command";
            }
            then done;
        }
    }

    part def LocationService {
        port eventOutput : TriggerInputPort;
        attribute serviceID : ServiceID;
        attribute currentLocation : LocationCoordinate;

        action trackLocation {
            out locationEvent : TriggerEvent;
            loop {
                action detectLocationChange {
                    out locationChanged : Boolean;
                }
                then decide;
                    if detectLocationChange.locationChanged then emitEvent;
                merge continueTracking;
                action emitEvent {
                    then assign locationEvent.eventType := "location_changed";
                    then assign locationEvent.sourceService := serviceID;
                }
                then continueTracking;
            }
        }
    }

    action def EvaluateCondition {
        in triggerEvent : TriggerEvent;
        in ruleCondition : ConditionExpression;
        out conditionMet : Boolean;
    }

    action def GenerateAction {
        in triggerEvent : TriggerEvent;
        in actionSpec : ActionType;
        out actionCommand : ActionCommand;
    }

    action def LogExecution {
        in triggerEvent : TriggerEvent;
        in actionCommand : ActionCommand;
        in executionResult : ExecutionResult;
    }

    part def RuleEngine {
        port triggerInput : TriggerInputPort;
        port actionOutput : ActionOutputPort;
        port ruleConfig : RuleConfigPort;
        port statusOutput : StatusPort;

        attribute activeRules : RuleDefinition[*];
        attribute executionCount : Real;

        action processAutomationRule {
            in triggerEvent : TriggerEvent;
            out actionCommand : ActionCommand;
            out executionResult : ExecutionResult;

            first start;
            then receiveEvent;

            action receiveEvent {
                in evt : TriggerEvent = triggerEvent;
            }
            then matchRules;

            action matchRules {
                in evt : TriggerEvent = triggerEvent;
                out matchedRule : RuleDefinition;
                out matched : Boolean;

                for rule in activeRules {
                    action checkRule : EvaluateCondition {
                        in triggerEvent = evt;
                        in ruleCondition = rule.triggerCondition;
                        out conditionMet;
                    }
                    then decide;
                        if checkRule.conditionMet then selectRule;
                    action selectRule {
                        then assign matchedRule := rule;
                        then assign matched := true;
                    }
                    then continueCheck;
                    merge continueCheck;
                }
            }
            then decide;
                if matchRules.matched then createAction;
                if !matchRules.matched then skipAction;

            action createAction {
                action buildCommand : GenerateAction {
                    in triggerEvent = triggerEvent;
                    in actionSpec = matchRules.matchedRule.actionSpec;
                    out actionCommand;
                }
                then assign actionCommand := buildCommand.actionCommand;
                flow buildCommand.actionCommand to dispatchAction.cmd;
                action dispatchAction {
                    in cmd : ActionCommand;
                }
                then assign executionResult.success := true;
            }

            action skipAction {
                then assign executionResult.success := false;
            }
            then done;
        }
    }

    part def IFTTTPlatform {
        doc /* 
            An IFTTT (If This Then That) automation platform that connects various 
            services and devices. The system monitors trigger events from multiple 
            sources and automatically executes corresponding actions based on 
            user-defined rules. When a trigger condition is satisfied, the platform 
            evaluates the rule, generates the appropriate action command, and 
            dispatches it to the target service or device, enabling seamless 
            automation across different services and smart devices.
        */

        part weatherSvc : WeatherService {
            attribute serviceID = "WEATHER_001";
            perform monitorWeather;
        }

        part locationSvc : LocationService {
            attribute serviceID = "LOCATION_001";
            perform trackLocation;
        }

        part smartLight : SmartHomeDevice {
            attribute deviceID = "LIGHT_001";
            attribute deviceState = "off";
            perform executeCommand;
        }

        part smartThermostat : SmartHomeDevice {
            attribute deviceID = "THERMOSTAT_001";
            attribute deviceState = "idle";
            perform executeCommand;
        }

        part engine : RuleEngine {
            attribute executionCount = 0.0;
            perform processAutomationRule;
        }

        connection weatherToEngine
            connect weatherSvc.eventOutput to engine.triggerInput;

        connection locationToEngine
            connect locationSvc.eventOutput to engine.triggerInput;

        connection engineToLight
            connect engine.actionOutput to smartLight.commandInput;

        connection engineToThermostat
            connect engine.actionOutput to smartThermostat.commandInput;

        perform action automateServices {
            doc /* 
                Main automation workflow that continuously monitors triggers 
                from connected services and executes actions based on active rules.
            */

            first start;
            then merge automationLoop;

            action automationLoop {
                action collectEvents {
                    out events : TriggerEvent[*];
                }
                then processEvents;

                action processEvents {
                    in triggerEvents : TriggerEvent[*] = collectEvents.events;
                    out commands : ActionCommand[*];

                    for evt in triggerEvents {
                        perform action handleEvent {
                            in currentEvent : TriggerEvent = evt;
                            out cmd : ActionCommand;
                            out res : ExecutionResult;

                            action evaluateEvent : EvaluateCondition {
                                in triggerEvent = currentEvent;
                                in ruleCondition;
                                out conditionMet;
                            }
                            then decide;
                                if evaluateEvent.conditionMet then generateCmd;
                            action generateCmd : GenerateAction {
                                in triggerEvent = currentEvent;
                                in actionSpec;
                                out actionCommand;
                            }
                            then assign cmd := generateCmd.actionCommand;
                            then nextEvent;
                            merge nextEvent;
                        }
                    }
                }
                then executeCommands;

                action executeCommands {
                    in actionCommands : ActionCommand[*] = processEvents.commands;
                    out results : ExecutionResult[*];

                    for cmd in actionCommands {
                        action dispatchCommand {
                            in command : ActionCommand = cmd;
                            out result : ExecutionResult;
                        }
                        then recordResult : LogExecution {
                            in triggerEvent;
                            in actionCommand = cmd;
                            in executionResult = dispatchCommand.result;
                        }
                        then nextCommand;
                        merge nextCommand;
                    }
                }
                then automationLoop;
            }
        }
    }

    requirement def PlatformRequirement {
        doc /* Base requirement for IFTTT platform capabilities. */
        subject platform : IFTTTPlatform;
    }

    requirement platformRequirements : PlatformRequirement[*] {

        requirement <'REQ-001'> eventDetection : PlatformRequirement {
            doc /* 
                The platform shall detect and process trigger events from 
                connected services within 500 milliseconds of occurrence.
            */
        }

        requirement <'REQ-002'> ruleEvaluation : PlatformRequirement {
            doc /* 
                The platform shall evaluate all active rules against each 
                trigger event and determine matching conditions accurately.
            */
        }

        requirement <'REQ-003'> actionExecution : PlatformRequirement {
            doc /* 
                The platform shall execute actions on target services within 
                1 second of rule condition satisfaction.
            */
        }

        requirement <'REQ-004'> scalability : PlatformRequirement {
            doc /* 
                The platform shall support at least 100 concurrent automation 
                rules and 20 connected services without performance degradation.
            */
        }

        requirement <'REQ-005'> reliability : PlatformRequirement {
            doc /* 
                The platform shall achieve 99.9% uptime and successfully 
                execute 99.5% of triggered actions under normal conditions.
            */
        }
    }

    requirement systemMission {
        doc /* 
            The IFTTT platform shall enable users to create automated workflows 
            by connecting trigger events from various services to corresponding 
            actions on target devices and services, providing seamless integration 
            and automation across heterogeneous systems.
        */

        assume constraint servicesConnected {
            doc /* All services and devices are properly authenticated and connected. */
        }

        assume constraint rulesConfigured {
            doc /* Users have defined valid automation rules with proper triggers and actions. */
        }

        require platformRequirements;
    }
}
