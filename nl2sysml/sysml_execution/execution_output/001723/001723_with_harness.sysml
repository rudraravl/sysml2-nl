package 'Philips Hue Smart Lighting System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def HueAngle :> Real {
		doc /* Color hue represented as angle in degrees (0-360). */
	}
	
	attribute def SaturationPercent :> Real {
		doc /* Color saturation as percentage (0-100). */
	}
	
	attribute def BrightnessPercent :> Real {
		doc /* Light brightness as percentage (0-100). */
	}
	
	attribute def ColorTemperatureKelvin :> ThermodynamicTemperatureValue {
		doc /* Color temperature in Kelvin (2000-6500K for warm to cool white). */
	}
	
	attribute def DeviceIdentifier :> String;
	attribute def SceneIdentifier :> String;
	attribute def GroupIdentifier :> String;
	
	item def LightCommand {
		attribute targetDevice : DeviceIdentifier;
		attribute powerOn : Boolean;
		attribute brightness : BrightnessPercent;
		attribute hue : HueAngle;
		attribute saturation : SaturationPercent;
		attribute colorTemp : ColorTemperatureKelvin;
	}
	
	item def StatusReport {
		attribute sourceDevice : DeviceIdentifier;
		attribute isOnline : Boolean;
		attribute currentPower : Boolean;
		attribute currentBrightness : BrightnessPercent;
		attribute currentHue : HueAngle;
		attribute currentSaturation : SaturationPercent;
	}
	
	item def NetworkMessage {
		attribute payload : String;
		attribute timestamp : TimeValue;
	}
	
	item def ElectricalPower;
	item def LightEmission;
	
	port def ACPowerPort {
		in item power : ElectricalPower;
	}
	
	port def ZigbeePort {
		in item inboundMessage : NetworkMessage;
		out item outboundMessage : NetworkMessage;
	}
	
	port def EthernetPort {
		in item inboundData : NetworkMessage;
		out item outboundData : NetworkMessage;
	}
	
	port def LightOutputPort {
		out item illumination : LightEmission;
	}
	
	port def UserInterfacePort {
		in item userCommand : LightCommand;
		out item systemStatus : StatusReport;
	}
	
	part def HueBulb {
		attribute bulbId : DeviceIdentifier;
		attribute maxLumens : LuminousFluxValue;
		attribute powerConsumption : PowerValue;
		
		private attribute isOn : Boolean = false;
		private attribute brightness : BrightnessPercent = 100.0;
		private attribute hue : HueAngle = 0.0;
		private attribute saturation : SaturationPercent = 0.0;
		private attribute colorTemp : ColorTemperatureKelvin;
		
		port acPower : ACPowerPort;
		port zigbeeComm : ZigbeePort;
		port lightOutput : LightOutputPort;
		
		part ledDriver {
			attribute outputVoltage : ISQ::VoltageValue;
			attribute outputCurrent : ISQ::ElectricCurrentValue;
		}
		
		part rgbwLedArray {
			attribute redIntensity : LuminousFluxValue;
			attribute greenIntensity : LuminousFluxValue;
			attribute blueIntensity : LuminousFluxValue;
			attribute whiteIntensity : LuminousFluxValue;
		}
		
		part zigbeeRadio {
			attribute transmitPower : PowerValue;
			attribute receiveSignalStrength : PowerValue;
		}
		
		state bulbStateMachine {
			entry; then off;
			
			state off {
				entry assign isOn := false;
			}
			accept powerOnCmd : LightCommand via zigbeeComm 
				if powerOnCmd.targetDevice == bulbId and powerOnCmd.powerOn 
				then on;
			
			state on {
				entry assign isOn := true;
				
				state steady;
				
				accept adjustCmd : LightCommand via zigbeeComm 
					if adjustCmd.targetDevice == bulbId and adjustCmd.powerOn 
					do action applySettings {
						assign brightness := adjustCmd.brightness;
						assign hue := adjustCmd.hue;
						assign saturation := adjustCmd.saturation;
						assign colorTemp := adjustCmd.colorTemp;
					}
					then steady;
			}
			accept powerOffCmd : LightCommand via zigbeeComm 
				if powerOffCmd.targetDevice == bulbId and not powerOffCmd.powerOn 
				then off;
		}
		
		action def ReportStatus {
			out status : StatusReport;
			
			assign status.sourceDevice := bulbId;
			assign status.isOnline := true;
			assign status.currentPower := isOn;
			assign status.currentBrightness := brightness;
			assign status.currentHue := hue;
			assign status.currentSaturation := saturation;
		}
	}
	
	part def HueBridge {
		attribute bridgeId : DeviceIdentifier;
		attribute maxConnectedDevices : Integer = 50;
		attribute firmwareVersion : String;
		
		port acPower : ACPowerPort;
		port ethernetUplink : EthernetPort;
		port zigbeeNetwork : ZigbeePort[1..*];
		
		part processor {
			attribute clockSpeed : FrequencyValue;
			attribute memorySize : ISQ::DigitalInformationValue;
		}
		
		part zigbeeCoordinator {
			attribute networkChannel : Integer;
			attribute panId : Integer;
		}
		
		part ethernetInterface {
			attribute macAddress : String;
			attribute ipAddress : String;
		}
		
		action def RouteCommand {
			in command : LightCommand;
			out routed : Boolean;
			
			first start;
			then action validateCommand {
				in cmd : LightCommand = command;
				out valid : Boolean;
			}
			then decide;
				if validateCommand.valid then broadcastToDevices;
				if not validateCommand.valid then rejectCommand;
			
			action broadcastToDevices {
				in cmd : LightCommand = command;
			}
			then assign routed := true;
			then done;
			
			action rejectCommand;
			then assign routed := false;
			then done;
		}
		
		action def AggregateStatus {
			out aggregatedStatus : StatusReport[*];
			
			loop {
				accept statusMsg : StatusReport via zigbeeNetwork;
				then assign aggregatedStatus := aggregatedStatus->including(statusMsg);
			}
		}
	}
	
	part def MobileApplication {
		attribute appVersion : String;
		attribute userId : DeviceIdentifier;
		
		port cloudInterface : EthernetPort;
		port userInterface : UserInterfacePort;
		
		action def SendLightingCommand {
			in targetId : DeviceIdentifier;
			in powerState : Boolean;
			in brightnessLevel : BrightnessPercent;
			in colorHue : HueAngle;
			in colorSat : SaturationPercent;
			out commandIssued : Boolean;
			
			first start;
			then action createCommand {
				out cmd : LightCommand;
				
				assign cmd.targetDevice := targetId;
				assign cmd.powerOn := powerState;
				assign cmd.brightness := brightnessLevel;
				assign cmd.hue := colorHue;
				assign cmd.saturation := colorSat;
			}
			then action transmitCommand {
				in command : LightCommand = createCommand.cmd;
			}
			then assign commandIssued := true;
			then done;
		}
		
		action def ActivateScene {
			in sceneId : SceneIdentifier;
			out sceneActivated : Boolean;
			
			first start;
			then action retrieveSceneSettings {
				in scene : SceneIdentifier = sceneId;
				out commands : LightCommand[*];
			}
			then action applySceneCommands {
				in commandList : LightCommand[*] = retrieveSceneSettings.commands;
			}
			then assign sceneActivated := true;
			then done;
		}
	}
	
	part def CloudService {
		attribute serviceEndpoint : String;
		attribute apiVersion : String;
		
		port clientConnections : EthernetPort[*];
		port bridgeConnections : EthernetPort[*];
		
		action def RelayCommands {
			loop {
				accept clientCmd : LightCommand via clientConnections;
				then action forwardToBridge {
					in command : LightCommand = clientCmd;
				}
			}
		}
		
		action def SynchronizeState {
			loop {
				accept bridgeStatus : StatusReport via bridgeConnections;
				then action updateClients {
					in status : StatusReport = bridgeStatus;
				}
			}
		}
	}
	
	action def ManageSmartLighting {
		doc /* 
			Primary system function: Enable users to wirelessly control 
			lighting color, brightness, and power state across multiple 
			bulbs through centralized bridge and cloud connectivity.
		*/
		
		in userRequest : LightCommand;
		out lightingResponse : StatusReport;
		
		first start;
		then merge awaitUserInput;
		
		then action receiveUserCommand {
			in request : LightCommand = userRequest;
			out processedCommand : LightCommand;
		}
		
		then action routeViaBridge {
			in command : LightCommand = receiveUserCommand.processedCommand;
			out bridgeConfirm : Boolean;
		}
		
		then action executeBulbControl {
			in bulbCommand : LightCommand = receiveUserCommand.processedCommand;
			out bulbResponse : StatusReport;
		}
		
		then action collectFeedback {
			in response : StatusReport = executeBulbControl.bulbResponse;
			assign lightingResponse := response;
		}
		
		then awaitUserInput;
	}
	
	part hueSystem {
		doc /* 
			The Philips Hue smart lighting system provides wireless control 
			of LED light bulbs through a central bridge connected to a home 
			network. Users control individual bulbs or groups via mobile apps, 
			adjusting color (16 million colors), brightness, and power state. 
			The system supports automated scenes, schedules, and integration 
			with voice assistants for enhanced ambiance and energy efficiency.
		*/
		
		part bridge : HueBridge {
			perform action routeCommands : RouteCommand;
			perform action aggregateStatus : AggregateStatus;
		}
		
		part livingRoomBulb1 : HueBulb {
			attribute :>> bulbId = "LR-Bulb-01";
			attribute :>> maxLumens = 800.0;
		}
		
		part livingRoomBulb2 : HueBulb {
			attribute :>> bulbId = "LR-Bulb-02";
			attribute :>> maxLumens = 800.0;
		}
		
		part bedroomBulb : HueBulb {
			attribute :>> bulbId = "BR-Bulb-01";
			attribute :>> maxLumens = 600.0;
		}
		
		part kitchenBulb : HueBulb {
			attribute :>> bulbId = "KT-Bulb-01";
			attribute :>> maxLumens = 1000.0;
		}
		
		part mobileApp : MobileApplication {
			perform action sendCommand : SendLightingCommand {
				in targetId = "LR-Bulb-01";
				in powerState = true;
				in brightnessLevel = 75.0;
				in colorHue = 120.0;
				in colorSat = 80.0;
			}
			perform action activateScene : ActivateScene;
		}
		
		part cloudService : CloudService {
			perform action relayCommands : RelayCommands;
			perform action synchronizeState : SynchronizeState;
		}
		
		part powerSupply {
			port acOutput : ACPowerPort;
		}
		
		connection powerToBridge connect powerSupply.acOutput to bridge.acPower;
		connection powerToBulb1 connect powerSupply.acOutput to livingRoomBulb1.acPower;
		connection powerToBulb2 connect powerSupply.acOutput to livingRoomBulb2.acPower;
		connection powerToBulb3 connect powerSupply.acOutput to bedroomBulb.acPower;
		connection powerToBulb4 connect powerSupply.acOutput to kitchenBulb.acPower;
		
		connection bridgeToBulb1 connect bridge.zigbeeNetwork to livingRoomBulb1.zigbeeComm;
		connection bridgeToBulb2 connect bridge.zigbeeNetwork to livingRoomBulb2.zigbeeComm;
		connection bridgeToBulb3 connect bridge.zigbeeNetwork to bedroomBulb.zigbeeComm;
		connection bridgeToBulb4 connect bridge.zigbeeNetwork to kitchenBulb.zigbeeComm;
		
		connection appToCloud connect mobileApp.cloudInterface to cloudService.clientConnections;
		connection cloudToBridge connect cloudService.bridgeConnections to bridge.ethernetUplink;
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for the Philips Hue smart lighting system. */
		
		requirement wirelessControl {
			doc /* The system shall enable wireless control of connected bulbs using Zigbee protocol. */
		}
		
		requirement colorCapability {
			doc /* Each bulb shall support 16 million colors with adjustable hue, saturation, and brightness. */
			
			require constraint hueRange {
				0.0 <= hueSystem.livingRoomBulb1.hue and 
				hueSystem.livingRoomBulb1.hue <= 360.0
			}
			
			require constraint saturationRange {
				0.0 <= hueSystem.livingRoomBulb1.saturation and 
				hueSystem.livingRoomBulb1.saturation <= 100.0
			}
			
			require constraint brightnessRange {
				0.0 <= hueSystem.livingRoomBulb1.brightness and 
				hueSystem.livingRoomBulb1.brightness <= 100.0
			}
		}
		
		requirement responseTime {
			doc /* The system shall respond to user commands within 400 milliseconds. */
		}
		
		requirement scalability {
			doc /* The bridge shall support simultaneous connection of up to 50 bulbs. */
			
			require constraint maxDevices {
				hueSystem.bridge.maxConnectedDevices == 50
			}
		}
		
		requirement remoteAccess {
			doc /* The system shall enable remote control through cloud service when internet-connected. */
		}
		
		requirement energyEfficiency {
			doc /* Each bulb shall consume no more than 10 watts at maximum brightness. */
		}
		
		requirement sceneManagement {
			doc /* The system shall support creation and activation of custom lighting scenes. */
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Philips Hue Smart Lighting System'::*;
}
