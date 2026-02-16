package 'Clipsal C-Bus Building Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NetworkAddress :> Integer;
	attribute def GroupAddress :> Integer;
	attribute def ApplicationID :> Integer;
	attribute def BrightnessLevel :> Real;
	
	item def CBusCommand {
		attribute sourceAddress : NetworkAddress;
		attribute targetGroup : GroupAddress;
		attribute application : ApplicationID;
		attribute commandType : String;
		attribute level : Real;
		attribute priority : Integer;
	}
	
	item def StatusReport {
		attribute unitAddress : NetworkAddress;
		attribute currentState : String;
		attribute measuredValue : Real;
	}
	
	port def CBusPort {
		in item commandIn : CBusCommand[*];
		out item commandOut : CBusCommand[*];
		out item statusOut : StatusReport[*];
	}
	
	port def PowerPort {
		attribute voltage : ElectricPotentialValue;
		attribute current : ElectricCurrentValue;
	}
	
	port def LoadPort {
		attribute outputLevel : Real;
		attribute maxPower : PowerValue;
	}
	
	part def CBusPowerSupply {
		doc /* Provides regulated DC power to the C-Bus network and connected units. */
		attribute ratedVoltage : ElectricPotentialValue;
		attribute maxCurrent : ElectricCurrentValue;
		attribute maxUnitsSupported : Integer;
		port acInput : PowerPort;
		port dcOutput : PowerPort;
		port busConnection : CBusPort;
	}
	
	part def InputUnit {
		doc /* Wall switch or sensor that generates control commands on the C-Bus network. */
		attribute unitAddress : NetworkAddress;
		attribute assignedGroups : GroupAddress[*];
		attribute numberOfButtons : Integer;
		port busPort : CBusPort;
		
		action generateCommand {
			in buttonPressed : Integer;
			in targetGroup : GroupAddress;
			out command : CBusCommand;
		}
	}
	
	part def OutputUnit {
		doc /* Dimmer or relay that receives commands and controls electrical loads. */
		attribute unitAddress : NetworkAddress;
		attribute listenGroups : GroupAddress[*];
		attribute currentLevel : BrightnessLevel;
		port busPort : CBusPort;
		port loadConnection : LoadPort;
		
		action processCommand {
			in command : CBusCommand;
			out newLevel : Real;
		}
		
		state machine def ControlStateMachine {
			in ref outputUnit : OutputUnit;
			
			state off {
				entry action setOff {
					assign outputUnit.currentLevel := 0.0;
				}
			}
			
			state ramping {
				entry action rampToLevel {
					in targetLevel : Real;
					in rampRate : Real;
				}
			}
			
			state on {
				entry action setOn {
					assign outputUnit.currentLevel := 100.0;
				}
			}
			
			initial state init;
			transition init to off;
			transition off to ramping accept cmd : CBusCommand
				if cmd.commandType == "ramp" and cmd.level > 0.0;
			transition off to on accept cmd : CBusCommand
				if cmd.commandType == "on";
			transition on to ramping accept cmd : CBusCommand
				if cmd.commandType == "ramp";
			transition on to off accept cmd : CBusCommand
				if cmd.commandType == "off";
			transition ramping to on accept cmd : CBusCommand
				if cmd.level >= 100.0;
			transition ramping to off accept cmd : CBusCommand
				if cmd.commandType == "off" or cmd.level <= 0.0;
		}
		
		exhibit state controlBehavior : ControlStateMachine {
			in ref outputUnit = self;
		}
	}
	
	part def NetworkInterface {
		doc /* PC interface enabling computer control and monitoring of the C-Bus network. */
		attribute interfaceAddress : NetworkAddress;
		port busPort : CBusPort;
		port computerPort;
		
		action transmitToNetwork {
			in externalCommand : CBusCommand;
			out busCommand : CBusCommand;
		}
		
		action monitorNetwork {
			in busTraffic : CBusCommand[*];
			out loggedData : CBusCommand[*];
		}
	}
	
	part def MotionSensor {
		doc /* Infrared sensor that triggers lighting commands based on occupancy detection. */
		attribute sensorAddress : NetworkAddress;
		attribute detectionZone : LengthValue;
		attribute timeoutPeriod : TimeValue;
		attribute controlGroup : GroupAddress;
		port busPort : CBusPort;
		
		state machine def DetectionStateMachine {
			state idle;
			state occupied;
			state timeout;
			
			initial state start;
			transition start to idle;
			transition idle to occupied accept motionDetected;
			transition occupied to timeout after timeoutPeriod;
			transition timeout to idle accept noMotion;
			transition timeout to occupied accept motionDetected;
		}
		
		exhibit state detectionBehavior : DetectionStateMachine;
		
		action sendOccupancyCommand {
			in detected : Boolean;
			out command : CBusCommand;
		}
	}
	
	part def ScheduleController {
		doc /* Time-based controller that executes programmed lighting scenes. */
		attribute controllerAddress : NetworkAddress;
		attribute scheduledEvents : Integer;
		port busPort : CBusPort;
		
		action executeSchedule {
			in currentTime : TimeValue;
			out commands : CBusCommand[*];
		}
	}
	
	action def CBusNetworkOperation {
		doc /* Coordinates message routing and device interaction across the C-Bus network. */
		first start;
		then merge awaitActivity;
		
		action awaitActivity;
		then accept inputEvent : CBusCommand;
		then decide;
			if inputEvent.commandType == "lighting" then processLighting;
			if inputEvent.commandType == "sensor" then processSensor;
			if inputEvent.commandType == "schedule" then processSchedule;
		
		action processLighting {
			action routeToOutputs {
				in command : CBusCommand;
				out distributed : Boolean;
			}
			then updateLoads;
		}
		
		action processSensor {
			action evaluateSensorData {
				in sensorInput : StatusReport;
				out triggerCommand : CBusCommand;
			}
			then routeToOutputs;
		}
		
		action processSchedule {
			action executeTimedEvent {
				in scheduledCommand : CBusCommand;
				out executed : Boolean;
			}
			then routeToOutputs;
		}
		
		action updateLoads {
			action applyLevelChange[*] {
				in targetLevel : Real;
				out applied : Boolean;
			}
		}
		then awaitActivity;
		
		action routeToOutputs {
			in command : CBusCommand;
			out distributed : Boolean;
		}
	}
	
	part cBusSystem {
		doc /* 
		The Clipsal C-Bus system is a microprocessor-based distributed control and 
		management system for buildings and homes. Its primary function is to provide 
		intelligent, flexible control of lighting, HVAC, security, and other electrical 
		loads through a two-wire communication network. Input devices such as wall 
		switches and sensors transmit digital commands over the shared bus, which are 
		received and executed by output units controlling the actual loads. This 
		architecture enables sophisticated automation, remote control, energy management, 
		and integration with building management systems while maintaining reliability 
		through distributed intelligence rather than centralized control.
		*/
		
		part powerSupply : CBusPowerSupply {
			attribute :>> ratedVoltage = 36[V];
			attribute :>> maxCurrent = 1.0[A];
			attribute :>> maxUnitsSupported = 100;
		}
		
		part pcInterface : NetworkInterface {
			attribute :>> interfaceAddress = 254;
			perform cBusSystem.networkBehavior.processSchedule.executeTimedEvent;
		}
		
		part wallSwitch1 : InputUnit {
			attribute :>> unitAddress = 10;
			attribute :>> assignedGroups = (1, 2);
			attribute :>> numberOfButtons = 4;
			perform cBusSystem.networkBehavior.processLighting.routeToOutputs;
		}
		
		part wallSwitch2 : InputUnit {
			attribute :>> unitAddress = 11;
			attribute :>> assignedGroups = (3, 4);
			attribute :>> numberOfButtons = 2;
		}
		
		part dimmer1 : OutputUnit {
			attribute :>> unitAddress = 20;
			attribute :>> listenGroups = (1, 5);
			attribute :>> currentLevel = 0.0;
			perform cBusSystem.networkBehavior.updateLoads.applyLevelChange;
		}
		
		part dimmer2 : OutputUnit {
			attribute :>> unitAddress = 21;
			attribute :>> listenGroups = (2, 5);
			attribute :>> currentLevel = 0.0;
			perform cBusSystem.networkBehavior.updateLoads.applyLevelChange;
		}
		
		part relay1 : OutputUnit {
			attribute :>> unitAddress = 22;
			attribute :>> listenGroups = (3);
			attribute :>> currentLevel = 0.0;
		}
		
		part relay2 : OutputUnit {
			attribute :>> unitAddress = 23;
			attribute :>> listenGroups = (4);
			attribute :>> currentLevel = 0.0;
		}
		
		part motionSensor1 : MotionSensor {
			attribute :>> sensorAddress = 30;
			attribute :>> detectionZone = 8[m];
			attribute :>> timeoutPeriod = 300[s];
			attribute :>> controlGroup = 5;
			perform cBusSystem.networkBehavior.processSensor.evaluateSensorData;
		}
		
		part scheduler : ScheduleController {
			attribute :>> controllerAddress = 40;
			attribute :>> scheduledEvents = 24;
			perform cBusSystem.networkBehavior.processSchedule.executeTimedEvent;
		}
		
		connection bus1 connect powerSupply.busConnection to pcInterface.busPort;
		connection bus2 connect pcInterface.busPort to wallSwitch1.busPort;
		connection bus3 connect wallSwitch1.busPort to wallSwitch2.busPort;
		connection bus4 connect wallSwitch2.busPort to dimmer1.busPort;
		connection bus5 connect dimmer1.busPort to dimmer2.busPort;
		connection bus6 connect dimmer2.busPort to relay1.busPort;
		connection bus7 connect relay1.busPort to relay2.busPort;
		connection bus8 connect relay2.busPort to motionSensor1.busPort;
		connection bus9 connect motionSensor1.busPort to scheduler.busPort;
		
		perform action networkBehavior : CBusNetworkOperation;
	}
	
	requirement <'CBUS-REQ-001'> distributedControl {
		doc /* The system shall provide distributed intelligence where input units 
		directly command output units without requiring a central controller. */
		
		subject cBusSystem;
		
		require constraint {
			cBusSystem.wallSwitch1.assignedGroups->exists(g | 
				cBusSystem.dimmer1.listenGroups->includes(g))
		}
	}
	
	requirement <'CBUS-REQ-002'> networkReliability {
		doc /* The C-Bus network shall maintain operation with message error rate 
		below 0.01% under normal conditions. */
		
		subject cBusSystem;
	}
	
	requirement <'CBUS-REQ-003'> responseLatency {
		doc /* Output units shall respond to valid commands within 200 milliseconds 
		of command transmission. */
		
		subject cBusSystem.dimmer1;
	}
	
	requirement <'CBUS-REQ-004'> scalability {
		doc /* A single network segment shall support up to 100 addressable units 
		with unique network addresses. */
		
		subject cBusSystem.powerSupply;
		
		require constraint {
			cBusSystem.powerSupply.maxUnitsSupported == 100
		}
	}
	
	requirement <'CBUS-REQ-005'> powerSupplyStability {
		doc /* The C-Bus power supply shall provide regulated 36V DC output with 
		voltage regulation better than ±5%. */
		
		subject cBusSystem.powerSupply;
		
		require constraint {
			cBusSystem.powerSupply.ratedVoltage == 36[V]
		}
	}
	
	requirement <'CBUS-REQ-006'> occupancyDetection {
		doc /* Motion sensors shall trigger lighting commands within 1 second of 
		detecting occupancy and maintain on-state during continued occupancy. */
		
		subject cBusSystem.motionSensor1;
		
		require constraint {
			cBusSystem.motionSensor1.timeoutPeriod >= 60[s]
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the Clipsal C-Bus building automation system. */
		
		require distributedControl;
		require networkReliability;
		require responseLatency;
		require scalability;
		require powerSupplyStability;
		require occupancyDetection;
	}
}
