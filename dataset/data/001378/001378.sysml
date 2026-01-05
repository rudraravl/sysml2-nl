package 'CEBus Home Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CEBusAddress {
		attribute houseCode : String;
		attribute unitCode : Integer;
	}
	
	attribute def CEBusPacket {
		attribute sourceAddress : CEBusAddress;
		attribute destinationAddress : CEBusAddress;
		attribute commandType : CEBusCommandType;
		attribute payload : String[0..*];
		attribute timestamp : ISQ::DurationValue;
	}
	
	enum def CEBusCommandType {
		enum powerOn;
		enum powerOff;
		enum dimLevel;
		enum statusRequest;
		enum statusResponse;
		enum temperatureSet;
		enum alarmTrigger;
	}
	
	attribute def DeviceStatus {
		attribute isActive : Boolean;
		attribute operationalLevel : Real;
		attribute lastUpdate : ISQ::DurationValue;
	}
	
	port def CEBusPort {
		attribute carrierFrequency : ISQ::FrequencyValue;
		attribute signalVoltage : ISQ::VoltageValue;
		in attribute rxPackets : CEBusPacket[*];
		out attribute txPackets : CEBusPacket[*];
	}
	
	port def PowerLinePort {
		attribute voltage : ISQ::VoltageValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute powerQuality : Real;
	}
	
	part def CEBusController {
		doc /* 
			Central controller managing CEBus network communication,
			device registration, packet routing, and collision avoidance.
		*/
		
		port busInterface : CEBusPort {
			attribute :>> carrierFrequency = 100000.0[SI::Hz];
			attribute :>> signalVoltage = 5.0[SI::V];
		}
		
		port powerLine : PowerLinePort;
		
		attribute registeredDevices : CEBusAddress[*];
		attribute networkStatus : String;
		attribute packetQueue : CEBusPacket[*];
		
		perform action manageNetwork : ManageNetworkCommunication;
	}
	
	part def CEBusDevice {
		doc /* Base device connected to CEBus network for home automation. */
		
		port busConnection : CEBusPort;
		port powerConnection : PowerLinePort;
		
		attribute deviceAddress : CEBusAddress;
		attribute deviceStatus : DeviceStatus;
		attribute firmwareVersion : String;
		
		perform action handleCommands : ProcessIncomingCommands;
	}
	
	part def SmartLightingModule :> CEBusDevice {
		doc /* Intelligent lighting module with dimming and scheduling capabilities. */
		
		attribute brightnessLevel : Real;
		attribute powerConsumption : ISQ::PowerValue;
		attribute lightingMode : String;
		
		perform action manageLighting : ControlLightingBehavior;
	}
	
	part def ClimateControlModule :> CEBusDevice {
		doc /* HVAC control module for temperature and humidity regulation. */
		
		attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute targetTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute currentHumidity : Real;
		attribute hvacMode : String;
		
		perform action regulateClimate : ClimateControlBehavior;
	}
	
	part def SecuritySensorModule :> CEBusDevice {
		doc /* Security sensor for intrusion detection and alarm triggering. */
		
		attribute sensorTriggered : Boolean;
		attribute sensorType : String;
		attribute sensitivityLevel : Real;
		
		perform action monitorSecurity : SecurityMonitoringBehavior;
	}
	
	part def ApplianceControlModule :> CEBusDevice {
		doc /* Generic appliance control for various household devices. */
		
		attribute applianceType : String;
		attribute operatingState : String;
		attribute energyUsage : ISQ::PowerValue;
		
		perform action controlAppliance : ApplianceControlBehavior;
	}
	
	action def TransmitCEBusPacket {
		in packet : CEBusPacket;
		in targetPort : CEBusPort;
		out transmissionSuccess : Boolean;
	}
	
	action def ReceiveCEBusPacket {
		in sourcePort : CEBusPort;
		out receivedPacket : CEBusPacket;
	}
	
	action def RoutePacket {
		in incomingPacket : CEBusPacket;
		in routingTable : CEBusAddress[*];
		out destinationFound : Boolean;
		out routedPacket : CEBusPacket;
	}
	
	action def ManageNetworkCommunication {
		doc /* 
			Continuously monitor CEBus for incoming packets, validate addresses,
			route commands to appropriate devices, and manage network timing.
		*/
		
		in registeredAddresses : CEBusAddress[*];
		out networkActive : Boolean;
		
		first start;
		then assign networkActive := true;
		then merge communicationLoop;
		
		action communicationLoop : ReceiveCEBusPacket {
			out incomingPacket : CEBusPacket;
		}
		
		then decide;
			if communicationLoop.incomingPacket.destinationAddress == null then communicationLoop;
			if communicationLoop.incomingPacket.destinationAddress != null then validateAndRoute;
		
		action validateAndRoute : RoutePacket {
			in incomingPacket = communicationLoop.incomingPacket;
			in routingTable = registeredAddresses;
			out destinationFound;
			out routedPacket;
		}
		
		then decide;
			if validateAndRoute.destinationFound == true then forwardPacket;
			if validateAndRoute.destinationFound == false then logError;
		
		action forwardPacket : TransmitCEBusPacket {
			in packet = validateAndRoute.routedPacket;
			out transmissionSuccess;
		}
		then communicationLoop;
		
		action logError;
		then communicationLoop;
	}
	
	action def ProcessIncomingCommands {
		doc /* Process commands received from CEBus and update device state. */
		
		in deviceAddr : CEBusAddress;
		in currentStatus : DeviceStatus;
		out updatedStatus : DeviceStatus;
		
		first start;
		then merge commandLoop;
		
		action commandLoop : ReceiveCEBusPacket {
			out receivedCommand : CEBusPacket;
		}
		
		then decide;
			if receivedCommand.destinationAddress == deviceAddr then processCommand;
			if receivedCommand.destinationAddress != deviceAddr then commandLoop;
		
		action processCommand;
		then action updateDeviceStatus {
			then assign updatedStatus := DeviceStatus {
				isActive = true;
				operationalLevel = 100.0;
			}
		}
		then action sendStatusResponse : TransmitCEBusPacket {
			in packet = CEBusPacket {
				sourceAddress = deviceAddr;
				commandType = CEBusCommandType::statusResponse;
			}
		}
		then commandLoop;
	}
	
	action def ControlLightingBehavior {
		doc /* Control lighting based on CEBus commands and schedules. */
		
		in receivedCommand : CEBusCommandType;
		in currentBrightness : Real;
		out newBrightness : Real;
		out statusUpdate : DeviceStatus;
		
		first start;
		then decide;
			if receivedCommand == CEBusCommandType::powerOn then turnOn;
			if receivedCommand == CEBusCommandType::powerOff then turnOff;
			if receivedCommand == CEBusCommandType::dimLevel then adjustDimming;
			if receivedCommand == CEBusCommandType::statusRequest then reportStatus;
		
		action turnOn {
			then assign newBrightness := 100.0;
		}
		then updateStatus;
		
		action turnOff {
			then assign newBrightness := 0.0;
		}
		then updateStatus;
		
		action adjustDimming {
			then assign newBrightness := currentBrightness * 0.6;
		}
		then updateStatus;
		
		action reportStatus;
		then updateStatus;
		
		action updateStatus {
			then assign statusUpdate := DeviceStatus {
				isActive = newBrightness > 0.0;
				operationalLevel = newBrightness;
			}
		}
		then done;
	}
	
	action def ClimateControlBehavior {
		doc /* Regulate temperature and humidity based on CEBus commands. */
		
		in targetTemp : ISQ::ThermodynamicTemperatureValue;
		in currentTemp : ISQ::ThermodynamicTemperatureValue;
		out hvacCommand : String;
		
		first start;
		then decide;
			if currentTemp < targetTemp then activateHeating;
			if currentTemp > targetTemp then activateCooling;
			if currentTemp == targetTemp then maintainTemperature;
		
		action activateHeating {
			then assign hvacCommand := "HEAT_ON";
		}
		then done;
		
		action activateCooling {
			then assign hvacCommand := "COOL_ON";
		}
		then done;
		
		action maintainTemperature {
			then assign hvacCommand := "MAINTAIN";
		}
		then done;
	}
	
	action def SecurityMonitoringBehavior {
		doc /* Monitor security sensors and trigger alarms via CEBus. */
		
		in sensorState : Boolean;
		out alarmPacket : CEBusPacket;
		
		first start;
		then merge monitorLoop;
		
		action monitorLoop;
		then decide;
			if sensorState == true then triggerAlarm;
			if sensorState == false then monitorLoop;
		
		action triggerAlarm {
			then assign alarmPacket := CEBusPacket {
				commandType = CEBusCommandType::alarmTrigger;
			}
		}
		then action broadcastAlarm : TransmitCEBusPacket {
			in packet = alarmPacket;
		}
		then monitorLoop;
	}
	
	action def ApplianceControlBehavior {
		doc /* Control appliance operation based on CEBus commands. */
		
		in command : CEBusCommandType;
		out applianceState : String;
		
		first start;
		then decide;
			if command == CEBusCommandType::powerOn then startAppliance;
			if command == CEBusCommandType::powerOff then stopAppliance;
		
		action startAppliance {
			then assign applianceState := "RUNNING";
		}
		then done;
		
		action stopAppliance {
			then assign applianceState := "STOPPED";
		}
		then done;
	}
	
	connection def CEBusNetworkConnection {
		doc /* Power line carrier connection implementing CEBus protocol. */
		end controllerPort : CEBusPort;
		end devicePort : CEBusPort;
	}
	
	part ceBusHomeSystem : CEBusHomeAutomationSystem {
		doc /* 
			Complete CEBus-based home automation system integrating
			centralized control with distributed intelligent devices.
		*/
		
		part controller : CEBusController {
			attribute :>> registeredDevices = (
				CEBusAddress { houseCode = "A"; unitCode = 1; },
				CEBusAddress { houseCode = "A"; unitCode = 2; },
				CEBusAddress { houseCode = "A"; unitCode = 3; },
				CEBusAddress { houseCode = "A"; unitCode = 4; },
				CEBusAddress { houseCode = "A"; unitCode = 5; }
			);
		}
		
		part livingRoomLight : SmartLightingModule {
			attribute :>> deviceAddress {
				attribute :>> houseCode = "A";
				attribute :>> unitCode = 1;
			}
			attribute :>> lightingMode = "AUTOMATIC";
		}
		
		part kitchenLight : SmartLightingModule {
			attribute :>> deviceAddress {
				attribute :>> houseCode = "A";
				attribute :>> unitCode = 2;
			}
			attribute :>> lightingMode = "MANUAL";
		}
		
		part mainThermostat : ClimateControlModule {
			attribute :>> deviceAddress {
				attribute :>> houseCode = "A";
				attribute :>> unitCode = 3;
			}
			attribute :>> targetTemperature = 295.15[SI::K];
			attribute :>> hvacMode = "AUTO";
		}
		
		part frontDoorSensor : SecuritySensorModule {
			attribute :>> deviceAddress {
				attribute :>> houseCode = "A";
				attribute :>> unitCode = 4;
			}
			attribute :>> sensorType = "CONTACT";
			attribute :>> sensitivityLevel = 0.8;
		}
		
		part coffeemaker : ApplianceControlModule {
			attribute :>> deviceAddress {
				attribute :>> houseCode = "A";
				attribute :>> unitCode = 5;
			}
			attribute :>> applianceType = "COFFEE_MAKER";
		}
		
		connection busNet1 : CEBusNetworkConnection connect
			controller.busInterface to livingRoomLight.busConnection;
		
		connection busNet2 : CEBusNetworkConnection connect
			controller.busInterface to kitchenLight.busConnection;
		
		connection busNet3 : CEBusNetworkConnection connect
			controller.busInterface to mainThermostat.busConnection;
		
		connection busNet4 : CEBusNetworkConnection connect
			controller.busInterface to frontDoorSensor.busConnection;
		
		connection busNet5 : CEBusNetworkConnection connect
			controller.busInterface to coffeemaker.busConnection;
		
		perform action coordinateHomeAutomation {
			doc /* 
				Primary system function: Provide integrated home automation through
				CEBus power line carrier communication, enabling centralized monitoring
				and control of lighting, climate, security, and appliances while
				allowing devices to communicate status and respond to commands for
				enhanced comfort, energy efficiency, and security.
			*/
			
			first start;
			then action initializeNetwork {
				action registerAllDevices;
				then action establishPowerLineCarrier;
				then action synchronizeDeviceClocks;
			}
			then merge operationalCycle;
			
			action operationalCycle {
				action pollDeviceStatus;
				flow pollDeviceStatus to processUserCommands;
				action processUserCommands;
				flow processUserCommands to routeCommandPackets;
				action routeCommandPackets;
				flow routeCommandPackets to updateSystemState;
				action updateSystemState;
				flow updateSystemState to monitorNetworkHealth;
				action monitorNetworkHealth;
			}
			then operationalCycle;
		}
	}
	
	part def CEBusHomeAutomationSystem {
		doc /* 
			CEBus-based residential automation system providing standardized
			power line carrier communication for distributed control of lighting,
			HVAC, security, and appliances, enabling intelligent coordination
			and energy management throughout the home.
		*/
	}
	
	requirement def PrimarySystemFunction;
	requirement def CommunicationReliability;
	requirement def EnergyEfficiency;
	
	requirement <'SYS-001'> ceBusPrimaryFunction : PrimarySystemFunction {
		doc /* 
			The CEBus home automation system shall provide reliable power line
			carrier communication enabling centralized monitoring and distributed
			control of residential devices including lighting, climate control,
			security sensors, and appliances for enhanced comfort, convenience,
			and energy efficiency.
		*/
		subject ceBusHomeSystem;
	}
	
	requirement <'SYS-002'> communicationReliability : CommunicationReliability {
		doc /* 
			The system shall maintain packet delivery reliability of at least
			95% under normal residential power line conditions with automatic
			collision detection and retry mechanisms.
		*/
		subject ceBusHomeSystem.controller;
	}
	
	requirement <'SYS-003'> energyEfficiency : EnergyEfficiency {
		doc /* 
			The system shall reduce overall household energy consumption by
			at least 15% through intelligent scheduling, occupancy detection,
			and coordinated device control.
		*/
		subject ceBusHomeSystem;
	}
	
	satisfy ceBusPrimaryFunction by ceBusHomeSystem;
	satisfy communicationReliability by ceBusHomeSystem.controller.manageNetwork;
	satisfy energyEfficiency by ceBusHomeSystem.coordinateHomeAutomation;
}
