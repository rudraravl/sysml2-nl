package OpenWebNetHomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def OpenWebNetAddress {
        who : Integer;
        what : Integer;
        where : Integer;
        dimension : Integer;
        value : String;
    }

    attribute def MessageFrame {
        startDelimiter : String;
        address : OpenWebNetAddress;
        endDelimiter : String;
    }

    item def BusSignal {
        attribute voltage : ISQ::VoltageValue;
        attribute current : ISQ::ElectricalCurrentValue;
        attribute frequency : ISQ::FrequencyValue;
    }

    item def CommandMessage {
        attribute messageFrame : MessageFrame;
        attribute timestamp : String;
        attribute priority : Integer;
    }

    item def StatusMessage {
        attribute messageFrame : MessageFrame;
        attribute deviceState : String;
        attribute timestamp : String;
    }

    port def BusPort {
        in item powerSupply : BusSignal;
        inout attribute commandMsg : CommandMessage;
        inout attribute statusMsg : StatusMessage;
    }

    port def NetworkPort {
        in attribute externalCommand : CommandMessage;
        out attribute deviceStatus : StatusMessage;
    }

    part def BusGateway {
        attribute ipAddress : String;
        attribute tcpPort : Integer;
        
        port networkInterface : NetworkPort;
        port busInterface : BusPort;

        perform action routeMessages {
            first start;
            then merge waitForMessage;
            
            action waitForMessage {
                accept incomingCommand : CommandMessage;
            }
            then action validateCommand {
                in cmd : CommandMessage = waitForMessage.incomingCommand;
                out validCmd : CommandMessage;
                out isValid : Boolean;
            }
            then decide;
                if validateCommand.isValid then forwardToBus;
                if not validateCommand.isValid then rejectCommand;
            
            action forwardToBus {
                in cmd : CommandMessage = validateCommand.validCmd;
            }
            flow forwardToBus.cmd to busInterface.commandMsg;
            action waitForResponse {
                accept responseMsg : StatusMessage;
            }
            then action sendResponse {
                in status : StatusMessage = waitForResponse.responseMsg;
            }
            flow sendResponse.status to networkInterface.deviceStatus;
            then waitForMessage;
            
            action rejectCommand;
            then waitForMessage;
        }
    }

    part def LightingActuator {
        attribute deviceAddress : OpenWebNetAddress;
        attribute currentIntensity : ScalarValues::Real;
        attribute isOn : ScalarValues::Boolean;
        
        port busConnection : BusPort;

        state def LightingStateMachine {
            entry; then off;
            
            state off {
                entry assign isOn := false;
                entry assign currentIntensity := 0.0;
            }
            
            accept event cmdOff : CommandMessage;
            transition off_to_on
                first off
                accept cmdOn : CommandMessage
                if cmdOn.messageFrame.address.what == 1
                then on;
            
            state on {
                entry assign isOn := true;
                entry assign currentIntensity := 100.0;
            }
            
            transition on_to_off
                first on
                accept cmdOffTransition : CommandMessage
                if cmdOffTransition.messageFrame.address.what == 0
                then off;
            
            transition on_to_dimming
                first on
                accept cmdDim : CommandMessage
                if cmdDim.messageFrame.address.what >= 2 and cmdDim.messageFrame.address.what <= 10
                then dimming;
            
            state dimming {
                entry action adjustIntensity {
                    in level : Integer;
                    then assign currentIntensity := level * 10.0;
                }
            }
            
            transition dimming_to_on
                first dimming
                if currentIntensity == 100.0
                then on;
            
            transition dimming_to_off
                first dimming
                if currentIntensity == 0.0
                then off;
        }

        exhibit state lightControl : LightingStateMachine;
    }

    part def TemperatureControl {
        attribute deviceAddress : OpenWebNetAddress;
        attribute currentTemp : ISQ::TemperatureValue;
        attribute targetTemp : ISQ::TemperatureValue;
        attribute mode : String;
        
        port busConnection : BusPort;

        perform action regulateTemperature {
            first start;
            then merge monitorLoop;
            
            action monitorLoop {
                action measureTemperature {
                    out temp : ISQ::TemperatureValue;
                }
                then assign currentTemp := measureTemperature.temp;
                then action compareSetpoint {
                    in current : ISQ::TemperatureValue = currentTemp;
                    in target : ISQ::TemperatureValue = targetTemp;
                    out delta : ISQ::TemperatureValue;
                }
                then decide;
                    if compareSetpoint.delta > 2.0 [Celsius] then activateHeating;
                    if compareSetpoint.delta < -2.0 [Celsius] then activateCooling;
                    if compareSetpoint.delta >= -2.0 [Celsius] and compareSetpoint.delta <= 2.0 [Celsius] then maintainIdle;
                
                action activateHeating {
                    then assign mode := "heating";
                    then action sendHeatingCommand {
                        out cmd : CommandMessage;
                    }
                }
                flow activateHeating.sendHeatingCommand.cmd to busConnection.commandMsg;
                then monitorLoop;
                
                action activateCooling {
                    then assign mode := "cooling";
                    then action sendCoolingCommand {
                        out cmd : CommandMessage;
                    }
                }
                flow activateCooling.sendCoolingCommand.cmd to busConnection.commandMsg;
                then monitorLoop;
                
                action maintainIdle {
                    then assign mode := "idle";
                }
                then monitorLoop;
            }
        }
    }

    part def AutomationScenario {
        attribute scenarioId : Integer;
        attribute scenarioName : String;
        attribute isActive : ScalarValues::Boolean;
        
        port busConnection : BusPort;

        perform action executeScenario {
            first start;
            then action activateScenario {
                accept trigger : CommandMessage;
            }
            then assign isActive := true;
            then action sendScenarioCommands {
                out commands : CommandMessage[*];
            }
            then action broadcastCommands {
                in cmdList : CommandMessage[*] = sendScenarioCommands.commands;
            }
            flow broadcastCommands.cmdList to busConnection.commandMsg;
            then action waitForCompletion {
                accept confirmations : StatusMessage[*];
            }
            then assign isActive := false;
            then done;
        }
    }

    part def PowerSupplyUnit {
        attribute inputVoltage : ISQ::VoltageValue;
        attribute outputVoltage : ISQ::VoltageValue;
        attribute maxCurrent : ISQ::ElectricalCurrentValue;
        attribute efficiency : ScalarValues::Real;

        perform action providePower {
            in inputPower : BusSignal;
            out outputPower : BusSignal {
                :>> voltage = outputVoltage;
                :>> current = maxCurrent;
                :>> frequency = 50.0 [Hz];
            }
        }
    }

    part openWebNetSystem {
        doc /* 
            OpenWebNet Home Automation System
            
            This system implements the OpenWebNet protocol for comprehensive building automation.
            The primary function is to provide centralized, intelligent control and monitoring of
            distributed home automation devices including lighting, climate control, and scenario
            management through a standardized bus communication architecture.
            
            The system enables remote access, automated responses to environmental conditions,
            and coordinated multi-device scenarios while maintaining real-time status monitoring
            and feedback from all connected devices.
        */

        part gateway : BusGateway {
            attribute :>> ipAddress = "192.168.1.35";
            attribute :>> tcpPort = 20000;
        }

        part powerSupply : PowerSupplyUnit {
            attribute :>> inputVoltage = 230.0 [V];
            attribute :>> outputVoltage = 27.0 [V];
            attribute :>> maxCurrent = 2.0 [A];
            attribute :>> efficiency = 0.85;
        }

        part livingRoomLight : LightingActuator {
            attribute :>> deviceAddress {
                :>> who = 1;
                :>> what = 0;
                :>> where = 11;
                :>> dimension = 0;
                :>> value = "";
            }
            attribute :>> currentIntensity = 0.0;
            attribute :>> isOn = false;
        }

        part kitchenLight : LightingActuator {
            attribute :>> deviceAddress {
                :>> who = 1;
                :>> what = 0;
                :>> where = 12;
                :>> dimension = 0;
                :>> value = "";
            }
            attribute :>> currentIntensity = 0.0;
            attribute :>> isOn = false;
        }

        part bedroomLight : LightingActuator {
            attribute :>> deviceAddress {
                :>> who = 1;
                :>> what = 0;
                :>> where = 21;
                :>> dimension = 0;
                :>> value = "";
            }
            attribute :>> currentIntensity = 0.0;
            attribute :>> isOn = false;
        }

        part climateControl : TemperatureControl {
            attribute :>> deviceAddress {
                :>> who = 4;
                :>> what = 0;
                :>> where = 1;
                :>> dimension = 0;
                :>> value = "";
            }
            attribute :>> currentTemp = 20.0 [Celsius];
            attribute :>> targetTemp = 22.0 [Celsius];
            attribute :>> mode = "idle";
        }

        part eveningScenario : AutomationScenario {
            attribute :>> scenarioId = 1;
            attribute :>> scenarioName = "Evening Mode";
            attribute :>> isActive = false;
        }

        part morningScenario : AutomationScenario {
            attribute :>> scenarioId = 2;
            attribute :>> scenarioName = "Morning Mode";
            attribute :>> isActive = false;
        }

        connection powerBus1 connect powerSupply.providePower.outputPower to gateway.busInterface.powerSupply;
        connection powerBus2 connect powerSupply.providePower.outputPower to livingRoomLight.busConnection.powerSupply;
        connection powerBus3 connect powerSupply.providePower.outputPower to kitchenLight.busConnection.powerSupply;
        connection powerBus4 connect powerSupply.providePower.outputPower to bedroomLight.busConnection.powerSupply;
        connection powerBus5 connect powerSupply.providePower.outputPower to climateControl.busConnection.powerSupply;
        connection powerBus6 connect powerSupply.providePower.outputPower to eveningScenario.busConnection.powerSupply;
        connection powerBus7 connect powerSupply.providePower.outputPower to morningScenario.busConnection.powerSupply;

        connection dataBus1 connect gateway.busInterface to livingRoomLight.busConnection;
        connection dataBus2 connect gateway.busInterface to kitchenLight.busConnection;
        connection dataBus3 connect gateway.busInterface to bedroomLight.busConnection;
        connection dataBus4 connect gateway.busInterface to climateControl.busConnection;
        connection dataBus5 connect gateway.busInterface to eveningScenario.busConnection;
        connection dataBus6 connect gateway.busInterface to morningScenario.busConnection;

        perform action coordinateAutomation {
            doc /* 
                Primary system behavior coordinating all automation functions through
                the OpenWebNet protocol, managing device communication, scenario execution,
                and environmental monitoring.
            */
            
            first start;
            then action initializeSystem {
                action powerUpDevices {
                    perform powerSupply.providePower;
                }
                then action startGateway {
                    perform gateway.routeMessages;
                }
                then action registerDevices {
                    out deviceRegistry : OpenWebNetAddress[*];
                }
            }
            then merge operationalCycle;
            
            action operationalCycle {
                action processCommands {
                    perform gateway.routeMessages;
                }
                action controlLighting {
                    perform livingRoomLight.lightControl;
                    perform kitchenLight.lightControl;
                    perform bedroomLight.lightControl;
                }
                action manageClimate {
                    perform climateControl.regulateTemperature;
                }
                action handleScenarios {
                    perform eveningScenario.executeScenario;
                    perform morningScenario.executeScenario;
                }
            }
            then operationalCycle;
        }
    }

    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def ReliabilityRequirement;

    requirement <'OWN-REQ-001'> protocolCompliance : FunctionalRequirement {
        doc /* 
            The system shall implement the OpenWebNet protocol specification for all
            device communication, supporting WHO, WHAT, WHERE addressing and standard
            message frame formats.
        */
        
        subject system : BusGateway;
    }

    requirement <'OWN-REQ-002'> commandResponseTime : PerformanceRequirement {
        doc /* 
            The system shall process and execute device commands with end-to-end latency
            not exceeding 150 milliseconds from network reception to device actuation.
        */
        
        subject gateway : BusGateway;
    }

    requirement <'OWN-REQ-003'> busReliability : ReliabilityRequirement {
        doc /* 
            The system shall maintain bus communication reliability with message delivery
            success rate of at least 99.9% under normal operating conditions.
        */
        
        subject system : BusGateway;
    }

    requirement <'OWN-REQ-004'> powerRegulation : PerformanceRequirement {
        doc /* 
            The power supply shall maintain output voltage at 27V ±10% across all load
            conditions up to maximum rated current.
        */
        
        subject supply : PowerSupplyUnit;
        
        require constraint {
            supply.outputVoltage >= 24.3 [V] and
            supply.outputVoltage <= 29.7 [V]
        }
    }

    requirement <'OWN-REQ-005'> deviceAddressing : FunctionalRequirement {
        doc /* 
            Each device shall maintain a unique OpenWebNet address within the system
            supporting hierarchical zone and device identification.
        */
        
        require constraint {
            openWebNetSystem.livingRoomLight.deviceAddress.where != 
            openWebNetSystem.kitchenLight.deviceAddress.where and
            openWebNetSystem.kitchenLight.deviceAddress.where != 
            openWebNetSystem.bedroomLight.deviceAddress.where
        }
    }

    requirement <'OWN-REQ-006'> scenarioExecution : FunctionalRequirement {
        doc /* 
            The system shall support coordinated multi-device scenario execution with
            synchronized command distribution to all participating devices.
        */
        
        subject scenario : AutomationScenario;
    }

    requirement <'OWN-REQ-007'> temperatureControl : PerformanceRequirement {
        doc /* 
            The climate control subsystem shall maintain temperature within ±2°C of
            setpoint during normal operation.
        */
        
        subject climate : TemperatureControl;
        
        require constraint {
            climate.currentTemp >= climate.targetTemp - 2.0 [Celsius] and
            climate.currentTemp <= climate.targetTemp + 2.0 [Celsius]
        }
    }

    requirement systemMission {
        doc /* 
            The OpenWebNet Home Automation System shall provide integrated, intelligent
            control of building automation devices through standardized protocol communication,
            enabling centralized management, automated responses, and coordinated scenarios
            while maintaining real-time monitoring and reliable operation.
        */
        
        assume constraint validPowerInput {
            openWebNetSystem.powerSupply.inputVoltage == 230.0 [V]
        }
        
        require protocolCompliance;
        require commandResponseTime;
        require busReliability;
        require powerRegulation;
        require deviceAddressing;
        require scenarioExecution;
        require temperatureControl;
    }
}
