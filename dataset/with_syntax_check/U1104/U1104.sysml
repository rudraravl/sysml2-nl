package 'Insteon Home Automation System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def InsteonAddress {
		attribute highByte : String;
		attribute middleByte : String;
		attribute lowByte : String;
	}
	
	enum def MessageType {
		enum standard;
		enum extended;
		enum broadcast;
		enum allLink;
	}
	
	enum def CommandCode {
		enum on;
		enum off;
		enum brighten;
		enum dim;
		enum statusRequest;
		enum statusResponse;
		enum setLevel;
	}
	
	enum def DeviceCategory {
		enum lighting;
		enum climate;
		enum sensors;
		enum appliances;
		enum access;
	}
	
	attribute def InsteonMessage {
		attribute messageType : MessageType;
		attribute fromAddress : InsteonAddress;
		attribute toAddress : InsteonAddress;
		attribute command : CommandCode;
		attribute parameter1 : Integer;
		attribute parameter2 : Integer;
	}
	
	attribute def SignalStrength :> Real;
	attribute def BrightnessLevel :> Real;
	attribute def PowerLineFrequency :> ISQ::frequency;
	attribute def RFFrequency :> ISQ::frequency;
	
	port def PowerLinePort {
		attribute carrierFrequency : PowerLineFrequency;
		out item txMessage : InsteonMessage;
		in item rxMessage : InsteonMessage;
		out signalStrength : SignalStrength;
	}
	
	port def RFPort {
		attribute frequency : RFFrequency;
		out item txMessage : InsteonMessage;
		in item rxMessage : InsteonMessage;
		out signalStrength : SignalStrength;
	}
	
	port def ControlPort {
		in attribute commandInput : CommandCode;
		in attribute levelInput : BrightnessLevel;
		out attribute statusOutput : String;
	}
	
	part def InsteonController {
		attribute deviceAddress : InsteonAddress;
		port powerLine : PowerLinePort;
		port rf : RFPort;
		port userInterface : ControlPort;
		
		action def TransmitCommand {
			in command : CommandCode;
			in targetAddress : InsteonAddress;
			in level : BrightnessLevel;
			out message : InsteonMessage;
			out success : Boolean;
		}
		
		action def ReceiveStatus {
			in message : InsteonMessage;
			out deviceStatus : String;
		}
		
		action def ManageNetwork {
			in userCommand : CommandCode;
			in targetDevice : InsteonAddress;
			out networkStatus : String;
			
			first start;
			then action createMessage {
				in cmd = userCommand;
				in target = targetDevice;
				out msg : InsteonMessage;
			}
			then action transmitPowerLine {
				in message = createMessage.msg;
				out plSignal : SignalStrength;
			}
			then action transmitRF {
				in plStrength = transmitPowerLine.plSignal;
				in message = createMessage.msg;
				out rfSignal : SignalStrength;
			}
			then action waitAcknowledge {
				in signal = transmitRF.rfSignal;
				out ackReceived : Boolean;
			}
			then decide;
				if waitAcknowledge.ackReceived then reportSuccess;
				else retransmit;
			action reportSuccess {
				out status : String;
			}
			then assign networkStatus := reportSuccess.status;
			then done;
			action retransmit {
				out status : String;
			}
			then assign networkStatus := retransmit.status;
			then createMessage;
		}
	}
	
	part def DimmableSwitch {
		attribute deviceAddress : InsteonAddress;
		attribute currentLevel : BrightnessLevel;
		attribute category : DeviceCategory;
		port powerLine : PowerLinePort;
		port rf : RFPort;
		port loadControl : ControlPort;
		
		state def SwitchBehavior {
			entry; then off;
			
			state off;
			state dimmed;
			state on;
			
			transition turnOn
				first off
				accept cmdOn : InsteonMessage
				if cmdOn.command == CommandCode::on
				then on;
			
			transition turnOff
				first on
				accept cmdOff : InsteonMessage
				if cmdOff.command == CommandCode::off
				then off;
			
			transition dimFromOn
				first on
				accept cmdDim : InsteonMessage
				if cmdDim.command == CommandCode::dim
				then dimmed;
			
			transition brightenFromDim
				first dimmed
				accept cmdBright : InsteonMessage
				if cmdBright.command == CommandCode::brighten
				then on;
			
			transition setSpecificLevel
				first off
				accept cmdSet : InsteonMessage
				if cmdSet.command == CommandCode::setLevel
				then dimmed;
		}
		
		action def ProcessMessage {
			in receivedMessage : InsteonMessage;
			out responseMessage : InsteonMessage;
			out newLevel : BrightnessLevel;
			
			first start;
			then decide;
				if receivedMessage.command == CommandCode::on then setOn;
				if receivedMessage.command == CommandCode::off then setOff;
				if receivedMessage.command == CommandCode::setLevel then setCustom;
			action setOn {
				out level : BrightnessLevel;
			}
			then assign newLevel := setOn.level;
			then done;
			action setOff {
				out level : BrightnessLevel;
			}
			then assign newLevel := setOff.level;
			then done;
			action setCustom {
				in param = receivedMessage.parameter1;
				out level : BrightnessLevel;
			}
			then assign newLevel := setCustom.level;
			then done;
		}
		
		action def SendStatusResponse {
			in currentState : BrightnessLevel;
			out statusMessage : InsteonMessage;
		}
	}
	
	part def MotionSensor {
		attribute deviceAddress : InsteonAddress;
		attribute motionDetected : Boolean;
		attribute ambientLightLevel : Real;
		attribute category : DeviceCategory;
		port powerLine : PowerLinePort;
		port rf : RFPort;
		
		action def DetectMotion {
			out motionEvent : Boolean;
			out lightLevel : Real;
			
			first start;
			then action sampleSensor {
				out rawMotion : Boolean;
				out rawLight : Real;
			}
			then action evaluateMotion {
				in motion = sampleSensor.rawMotion;
				in light = sampleSensor.rawLight;
				out shouldTrigger : Boolean;
			}
			then decide;
				if evaluateMotion.shouldTrigger then triggerEvent;
				else done;
			action triggerEvent {
				out event : Boolean;
			}
			then assign motionEvent := triggerEvent.event;
			then done;
		}
		
		action def BroadcastMotionAlert {
			in motionDetected : Boolean;
			out alertMessage : InsteonMessage;
		}
	}
	
	part def Thermostat {
		attribute deviceAddress : InsteonAddress;
		attribute currentTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute setpointTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute operatingMode : String;
		attribute category : DeviceCategory;
		port powerLine : PowerLinePort;
		port rf : RFPort;
		
		action def MeasureTemperature {
			out temperature : ISQ::ThermodynamicTemperatureValue;
		}
		
		action def AdjustSetpoint {
			in command : InsteonMessage;
			in currentSetpoint : ISQ::ThermodynamicTemperatureValue;
			out newSetpoint : ISQ::ThermodynamicTemperatureValue;
		}
		
		action def ControlHVAC {
			in currentTemp : ISQ::ThermodynamicTemperatureValue;
			in setpoint : ISQ::ThermodynamicTemperatureValue;
			out hvacCommand : String;
			
			first start;
			then decide;
				if currentTemp < setpoint then heat;
				if currentTemp > setpoint then cool;
				else maintain;
			action heat {
				out cmd : String;
			}
			then assign hvacCommand := heat.cmd;
			then done;
			action cool {
				out cmd : String;
			}
			then assign hvacCommand := cool.cmd;
			then done;
			action maintain {
				out cmd : String;
			}
			then assign hvacCommand := maintain.cmd;
			then done;
		}
	}
	
	part def SmartOutlet {
		attribute deviceAddress : InsteonAddress;
		attribute powerState : Boolean;
		attribute energyUsage : ISQ::PowerValue;
		attribute category : DeviceCategory;
		port powerLine : PowerLinePort;
		port rf : RFPort;
		port loadOutput : ControlPort;
		
		action def MonitorEnergy {
			out currentPower : ISQ::PowerValue;
			out totalEnergy : ISQ::EnergyValue;
		}
		
		action def SwitchLoad {
			in command : InsteonMessage;
			in currentState : Boolean;
			out newState : Boolean;
			
			first start;
			then decide;
				if command.command == CommandCode::on then turnLoadOn;
				if command.command == CommandCode::off then turnLoadOff;
			action turnLoadOn {
				out state : Boolean;
			}
			then assign newState := turnLoadOn.state;
			then done;
			action turnLoadOff {
				out state : Boolean;
			}
			then assign newState := turnLoadOff.state;
			then done;
		}
	}
	
	part def InsteonHub {
		attribute deviceAddress : InsteonAddress;
		attribute registeredDevices : InsteonAddress[*];
		port powerLine : PowerLinePort;
		port rf : RFPort;
		port internet : ControlPort;
		
		action def RouteMessage {
			in incomingMessage : InsteonMessage;
			out outgoingMessage : InsteonMessage;
			out routingPath : String;
			
			first start;
			then action determineRoute {
				in msg = incomingMessage;
				out path : String;
			}
			then action selectInterface {
				in route = determineRoute.path;
				out usePowerLine : Boolean;
				out useRF : Boolean;
			}
			then decide;
				if selectInterface.usePowerLine then sendPowerLine;
				if selectInterface.useRF then sendRF;
			action sendPowerLine {
				in msg = incomingMessage;
				out outMsg : InsteonMessage;
			}
			then assign outgoingMessage := sendPowerLine.outMsg;
			then done;
			action sendRF {
				in msg = incomingMessage;
				out outMsg : InsteonMessage;
			}
			then assign outgoingMessage := sendRF.outMsg;
			then done;
		}
		
		action def ManageDeviceRegistry {
			in deviceList : InsteonAddress[*];
			out networkMap : String;
		}
		
		action def BridgeCommunication {
			in powerLineMessage : InsteonMessage;
			out rfMessage : InsteonMessage;
		}
	}
	
	action def DualBandCommunication {
		in sourceDevice : InsteonAddress;
		in targetDevice : InsteonAddress;
		in command : CommandCode;
		in level : BrightnessLevel;
		out deliveryStatus : String;
		
		first start;
		then action encodeMessage {
			in src = sourceDevice;
			in dest = targetDevice;
			in cmd = command;
			in param = level;
			out message : InsteonMessage;
		}
		then action transmitPowerLine {
			in message = encodeMessage.message;
			out plSignal : SignalStrength;
		}
		then action transmitRF {
			in plStrength = transmitPowerLine.plSignal;
			in message = encodeMessage.message;
			out rfSignal : SignalStrength;
		}
		then action receiveAtDestination {
			in signal = transmitRF.rfSignal;
			out receivedMessage : InsteonMessage;
		}
		then action executeCommand {
			in message = receiveAtDestination.receivedMessage;
			out executionResult : String;
		}
		then action sendAcknowledgment {
			in result = executeCommand.executionResult;
			out ackMessage : InsteonMessage;
		}
		then assign deliveryStatus := "Message delivered and acknowledged";
		then done;
	}
	
	part homeAutomationSystem {
		part controller : InsteonController {
			attribute :>> deviceAddress {
				attribute :>> highByte = "1A";
				attribute :>> middleByte = "2B";
				attribute :>> lowByte = "3C";
			}
		}
		
		part hub : InsteonHub {
			attribute :>> deviceAddress {
				attribute :>> highByte = "2A";
				attribute :>> middleByte = "3B";
				attribute :>> lowByte = "4C";
			}
		}
		
		part livingRoomLight : DimmableSwitch {
			attribute :>> deviceAddress {
				attribute :>> highByte = "3A";
				attribute :>> middleByte = "4B";
				attribute :>> lowByte = "5C";
			}
		}
		
		part kitchenLight : DimmableSwitch {
			attribute :>> deviceAddress {
				attribute :>> highByte = "4A";
				attribute :>> middleByte = "5B";
				attribute :>> lowByte = "6C";
			}
		}
		
		part hallwayMotion : MotionSensor {
			attribute :>> deviceAddress {
				attribute :>> highByte = "5A";
				attribute :>> middleByte = "6B";
				attribute :>> lowByte = "7C";
			}
			attribute :>> motionDetected = false;
		}
		
		part mainThermostat : Thermostat {
			attribute :>> deviceAddress {
				attribute :>> highByte = "6A";
				attribute :>> middleByte = "7B";
				attribute :>> lowByte = "8C";
			}
		}
		
		part applianceOutlet : SmartOutlet {
			attribute :>> deviceAddress {
				attribute :>> highByte = "7A";
				attribute :>> middleByte = "8B";
				attribute :>> lowByte = "9C";
			}
			attribute :>> powerState = false;
		}
		
		connect controller.powerLine to hub.powerLine;
		connect controller.rf to hub.rf;
		connect hub.powerLine to livingRoomLight.powerLine;
		connect hub.powerLine to kitchenLight.powerLine;
		connect hub.powerLine to hallwayMotion.powerLine;
		connect hub.powerLine to mainThermostat.powerLine;
		connect hub.powerLine to applianceOutlet.powerLine;
		connect hub.rf to hallwayMotion.rf;
		
		perform action automateHome : AutomateHome;
	}
	
	action def AutomateHome {
		first start;
		then merge monitorLoop;
		
		action monitorLoop {
			action detectMotion : MotionSensor::DetectMotion {
				out motionEvent;
				out lightLevel;
			}
			
			then action evaluateCondition {
				in motion = detectMotion.motionEvent;
				in light = detectMotion.lightLevel;
				out shouldActivate : Boolean;
			}
			
			then decide;
				if evaluateCondition.shouldActivate then activateLights;
				else monitorLoop;
			
			action activateLights {
				action sendCommand : DualBandCommunication;
				
				then action adjustLight : DimmableSwitch::ProcessMessage;
			}
			
			then monitorLoop;
		}
	}
	
	requirement def <'REQ-001'> DualBandMeshNetworking {
		doc /* The Insteon system shall provide reliable dual-band mesh networking 
		       using both powerline and RF communication to ensure message delivery 
		       even if one path is blocked or degraded. */
		
		require constraint {
			doc /* Each device shall simultaneously transmit messages over both 
			       powerline (131.65 kHz) and RF (915 MHz) frequencies. */
		}
		
		require constraint {
			doc /* All devices shall act as repeaters to extend network range and 
			       improve reliability through mesh topology. */
		}
	}
	
	requirement def <'REQ-002'> InstantaneousResponse {
		doc /* The system shall provide near-instantaneous response to user commands 
		       and automated triggers without requiring polling or cloud connectivity. */
		
		require constraint {
			doc /* Command execution latency shall not exceed 500 milliseconds from 
			       user input to device action under normal conditions. */
		}
	}
	
	requirement def <'REQ-003'> DeviceInteroperability {
		doc /* All Insteon-certified devices shall communicate using the standard 
		       Insteon protocol regardless of manufacturer, enabling seamless 
		       integration and control. */
		
		require constraint {
			doc /* Devices shall support the standard Insteon command set including 
			       ON, OFF, DIM, BRIGHTEN, STATUS_REQUEST, and STATUS_RESPONSE. */
		}
	}
	
	requirement def <'REQ-004'> SceneControl {
		doc /* The system shall support scene-based control allowing multiple devices 
		       to be controlled simultaneously with a single command. */
		
		require constraint {
			doc /* Scene activation shall trigger all linked devices within 1 second. */
		}
	}
	
	requirement def <'REQ-005'> EnergyMonitoring {
		doc /* Smart outlets shall provide real-time energy consumption monitoring 
		       to enable energy management and cost tracking. */
		
		require constraint {
			doc /* Energy measurement accuracy shall be within 5% of actual consumption. */
		}
	}
	
	requirement systemRequirements {
		subject homeAutomationSystem;
		
		doc /* The Insteon home automation system provides reliable, peer-to-peer 
		       control of lighting, climate, appliances, and sensors using dual-band 
		       mesh networking technology. Its primary function is to enable automated 
		       and manual control of home devices with instantaneous response, high 
		       reliability, and seamless interoperability across manufacturers. */
		
		require dualBand : DualBandMeshNetworking;
		require instantResponse : InstantaneousResponse;
		require interop : DeviceInteroperability;
		require scenes : SceneControl;
		require energy : EnergyMonitoring;
	}
}
