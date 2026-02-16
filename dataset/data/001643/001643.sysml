package BticinoHomeAutomationSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DeviceAddress :> String;
	
	item def BusMessage {
		attribute sourceAddress : DeviceAddress;
		attribute destinationAddress : DeviceAddress;
		attribute commandType : String;
		attribute payload : Real[0..*];
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute frequency : ISQ::FrequencyValue;
	}
	
	attribute def BrightnessLevel :> Real;
	
	port def SCSBusPort {
		in item messageIn : BusMessage[*];
		out item messageOut : BusMessage[*];
	}
	
	port def PowerPort {
		in item powerSupply : ElectricalPower;
	}
	
	part def SCSBusCommunicator {
		port busInterface : SCSBusPort;
		
		action def TransmitMessage {
			in message : BusMessage;
			out transmitted : Boolean;
			
			first start;
			then action validateMessage {
				in msg : BusMessage = message;
				out valid : Boolean;
			}
			then decide;
				if validateMessage.valid then sendMessage;
				else rejectMessage;
			action sendMessage {
				assign transmitted := true;
			}
			action rejectMessage {
				assign transmitted := false;
			}
			then done;
		}
		
		action def ReceiveMessage {
			out message : BusMessage;
		}
	}
	
	part def LightActuator {
		attribute deviceId : DeviceAddress;
		attribute currentBrightness : BrightnessLevel;
		
		port busPort : SCSBusPort;
		port powerPort : PowerPort;
		
		state def LightControlStateMachine {
			entry; then off;
			
			state off {
				entry assign currentBrightness := 0.0;
			}
			
			state on {
				entry assign currentBrightness := 100.0;
			}
			
			state dimmed {
				attribute dimLevel : BrightnessLevel;
			}
			
			transition off_to_on
				first off
				accept cmd : BusMessage
				if cmd.commandType == "turnOn"
				then on;
			
			transition on_to_off
				first on
				accept cmd : BusMessage
				if cmd.commandType == "turnOff"
				then off;
			
			transition on_to_dimmed
				first on
				accept cmd : BusMessage
				if cmd.commandType == "dim"
				then dimmed;
			
			transition dimmed_to_on
				first dimmed
				accept cmd : BusMessage
				if cmd.commandType == "turnOn"
				then on;
			
			transition dimmed_to_off
				first dimmed
				accept cmd : BusMessage
				if cmd.commandType == "turnOff"
				then off;
		}
		
		action def ProcessCommand {
			in command : BusMessage;
			out newBrightness : BrightnessLevel;
			
			first start;
			then action parseCommand {
				in cmd : BusMessage = command;
				out brightness : BrightnessLevel;
			}
			then decide;
				if parseCommand.brightness >= 0.0 and parseCommand.brightness <= 100.0 
					then applyBrightness;
				else rejectCommand;
			action applyBrightness {
				assign newBrightness := parseCommand.brightness;
			}
			action rejectCommand;
			then done;
		}
	}
	
	part def TouchSensor {
		attribute deviceId : DeviceAddress;
		attribute buttonState : Boolean;
		
		port busPort : SCSBusPort;
		
		action def DetectPress {
			out pressDetected : Boolean;
			
			first start;
			then action sampleButton {
				out state : Boolean;
			}
			then assign pressDetected := sampleButton.state;
			then done;
		}
		
		action def GenerateCommand {
			in pressEvent : Boolean;
			out commandMessage : BusMessage;
			
			first start;
			then decide;
				if pressEvent then createOnCommand;
				else createOffCommand;
			action createOnCommand {
				assign commandMessage.commandType := "turnOn";
			}
			action createOffCommand {
				assign commandMessage.commandType := "turnOff";
			}
			then assign commandMessage.sourceAddress := deviceId;
			then done;
		}
	}
	
	part def ScenarioController {
		attribute activeScenario : String;
		
		port busPort : SCSBusPort;
		
		action def ActivateScenario {
			in scenarioName : String;
			out commands : BusMessage[*];
			
			first start;
			then decide;
				if scenarioName == "welcome" then welcomeScenario;
				if scenarioName == "goodnight" then goodnightScenario;
				if scenarioName == "away" then awayScenario;
				else defaultScenario;
			
			action welcomeScenario {
				action buildWelcomeCommands {
					out msgs : BusMessage[*];
				}
				then assign commands := buildWelcomeCommands.msgs;
			}
			
			action goodnightScenario {
				action buildGoodnightCommands {
					out msgs : BusMessage[*];
				}
				then assign commands := buildGoodnightCommands.msgs;
			}
			
			action awayScenario {
				action buildAwayCommands {
					out msgs : BusMessage[*];
				}
				then assign commands := buildAwayCommands.msgs;
			}
			
			action defaultScenario {
				assign commands := ( );
			}
			
			then done;
		}
	}
	
	part def PowerSupplyUnit {
		attribute inputVoltage : ISQ::VoltageValue;
		attribute outputVoltage : ISQ::VoltageValue;
		attribute maxCurrent : ISQ::ElectricCurrentValue;
		
		port powerIn : PowerPort;
		port powerOut : PowerPort;
		
		action def RegulateVoltage {
			in vIn : ISQ::VoltageValue;
			out vOut : ISQ::VoltageValue;
			
			first start;
			then action convertVoltage {
				in inputV : ISQ::VoltageValue = vIn;
				out outputV : ISQ::VoltageValue;
			}
			then assign vOut := convertVoltage.outputV;
			then done;
		}
	}
	
	part def BticinoHomeSystem {
		attribute systemId : DeviceAddress;
		
		part scsBus : SCSBusCommunicator;
		part powerSupply : PowerSupplyUnit {
			attribute :>> inputVoltage = 230.0 [SI::V];
			attribute :>> outputVoltage = 27.0 [SI::V];
			attribute :>> maxCurrent = 1.5 [SI::A];
		}
		part scenarioController : ScenarioController;
		
		part livingRoomLight : LightActuator {
			attribute :>> deviceId = "LR_LIGHT_01";
		}
		
		part bedroomLight : LightActuator {
			attribute :>> deviceId = "BR_LIGHT_01";
		}
		
		part kitchenLight : LightActuator {
			attribute :>> deviceId = "KT_LIGHT_01";
		}
		
		part hallwayLight : LightActuator {
			attribute :>> deviceId = "HL_LIGHT_01";
		}
		
		part entranceSwitch : TouchSensor {
			attribute :>> deviceId = "EN_SWITCH_01";
		}
		
		part livingRoomSwitch : TouchSensor {
			attribute :>> deviceId = "LR_SWITCH_01";
		}
		
		part bedroomSwitch : TouchSensor {
			attribute :>> deviceId = "BR_SWITCH_01";
		}
		
		connection busConnection1 connect scsBus.busInterface to livingRoomLight.busPort;
		connection busConnection2 connect scsBus.busInterface to bedroomLight.busPort;
		connection busConnection3 connect scsBus.busInterface to kitchenLight.busPort;
		connection busConnection4 connect scsBus.busInterface to hallwayLight.busPort;
		connection busConnection5 connect scsBus.busInterface to entranceSwitch.busPort;
		connection busConnection6 connect scsBus.busInterface to livingRoomSwitch.busPort;
		connection busConnection7 connect scsBus.busInterface to bedroomSwitch.busPort;
		connection busConnection8 connect scsBus.busInterface to scenarioController.busPort;
		
		connection powerConnection1 connect powerSupply.powerOut to livingRoomLight.powerPort;
		connection powerConnection2 connect powerSupply.powerOut to bedroomLight.powerPort;
		connection powerConnection3 connect powerSupply.powerOut to kitchenLight.powerPort;
		connection powerConnection4 connect powerSupply.powerOut to hallwayLight.powerPort;
		
		perform action coordinateHomeAutomation {
			first start;
			then merge monitorLoop;
			
			then action monitorSensors {
				out sensorEvents : BusMessage[*];
			}
			
			then decide;
				if monitorSensors.sensorEvents->size() > 0 then processEvents;
				else monitorLoop;
			
			action processEvents {
				in events : BusMessage[*] = monitorSensors.sensorEvents;
				
				action routeCommands {
					in messages : BusMessage[*] = events;
					out routedMessages : BusMessage[*];
				}
				
				then action updateActuators {
					in commands : BusMessage[*] = routeCommands.routedMessages;
				}
			}
			
			then monitorLoop;
		}
	}
	
	requirement def SystemRequirement;
	
	requirement <'BTI-REQ-001'> homeAutomationCapability : SystemRequirement {
		doc /* The Bticino home automation system shall provide centralized control 
		     of lighting and scenarios through the SCS bus communication protocol. */
		
		subject bticinoSystem : BticinoHomeSystem;
		
		require <'BTI-REQ-001.1'> busReliability {
			doc /* The SCS bus shall reliably transmit commands between all connected 
			     devices with latency less than 100 milliseconds. */
		}
		
		require <'BTI-REQ-001.2'> lightingControl {
			doc /* The system shall support on/off and dimming control for all 
			     connected light actuators with brightness range 0-100%. */
		}
		
		require <'BTI-REQ-001.3'> scenarioManagement {
			doc /* The system shall support programmable scenarios that coordinate 
			     multiple devices simultaneously. */
		}
		
		require <'BTI-REQ-001.4'> powerStability {
			doc /* The power supply shall maintain stable 27V DC output with 
			     ripple less than 5% under full load. */
		}
	}
	
	requirement <'BTI-REQ-002'> userInteraction : SystemRequirement {
		doc /* The system shall respond to user touch sensor inputs within 200 milliseconds 
		     and provide visual feedback through controlled devices. */
		
		assume constraint validSensorInput {
			doc /* Touch sensors generate valid bus messages conforming to SCS protocol specification. */
		}
	}
	
	requirement <'BTI-REQ-003'> systemScalability : SystemRequirement {
		doc /* The system shall support expansion up to 255 devices on a single SCS bus segment. */
	}
}
