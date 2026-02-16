package MobileInternetDeviceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SignalStrength {
		attribute value : Real;
		attribute unit : String = "dBm";
	}
	
	attribute def DataRate {
		attribute value : Real;
		attribute unit : String = "Mbps";
	}
	
	attribute def BatteryLevel {
		attribute percentage : Real;
		attribute voltage : Real;
	}
	
	item def NetworkPacket {
		attribute size : Real;
		attribute timestamp : Real;
		attribute destination : String;
		attribute payload : String;
	}
	
	item def UserRequest {
		attribute requestType : String;
		attribute url : String;
		attribute priority : Integer;
	}
	
	item def ContentData {
		attribute dataSize : Real;
		attribute contentType : String;
		attribute payload : String;
	}
	
	port def NetworkPort {
		in item receivedPackets : NetworkPacket[*];
		out item transmittedPackets : NetworkPacket[*];
	}
	
	port def UserInterfacePort {
		in item userInputs : UserRequest[*];
		out item displayContent : ContentData[*];
	}
	
	port def PowerPort {
		in attribute powerSupply : PowerValue;
		out attribute powerDemand : PowerValue;
	}
	
	part def WirelessModem {
		attribute signalStrength : SignalStrength;
		attribute currentDataRate : DataRate;
		attribute connectionStatus : Boolean;
		
		port networkInterface : NetworkPort;
		port powerIn : PowerPort;
		
		action def EstablishConnection {
			out connectionEstablished : Boolean;
			out negotiatedDataRate : DataRate;
		}
		
		action def TransmitData {
			in packet : NetworkPacket;
			out transmissionSuccess : Boolean;
		}
		
		action def ReceiveData {
			out packet : NetworkPacket;
		}
		
		state modemBehavior {
			entry; then disconnected;
			
			state disconnected;
			accept powerUp then connecting;
			
			state connecting;
			accept linkEstablished then connected;
			accept linkFailed then disconnected;
			
			state connected;
			accept startTransmit then transmitting;
			accept startReceive then receiving;
			accept connectionLost then disconnected;
			
			state transmitting;
			accept transmitComplete then connected;
			
			state receiving;
			accept receiveComplete then connected;
		}
	}
	
	part def ApplicationProcessor {
		attribute processingSpeed : FrequencyValue;
		attribute memoryUsage : Real;
		attribute coreCount : Integer;
		
		port powerIn : PowerPort;
		
		action def ProcessRequest {
			in request : UserRequest;
			out networkPacket : NetworkPacket;
		}
		
		action def ProcessResponse {
			in packet : NetworkPacket;
			out content : ContentData;
		}
		
		action def ManageResources {
			in currentLoad : Real;
			out optimizedAllocation : Real;
		}
		
		action def ExecuteApplication {
			in appRequest : UserRequest;
			out appResponse : ContentData;
		}
	}
	
	part def DisplayController {
		attribute resolution : String;
		attribute refreshRate : FrequencyValue;
		attribute brightness : Real;
		
		port displayPort : UserInterfacePort;
		port powerIn : PowerPort;
		
		action def RenderContent {
			in content : ContentData;
			out displayReady : Boolean;
		}
		
		action def UpdateDisplay {
			in content : ContentData;
		}
		
		action def AdjustBrightness {
			in level : Real;
		}
	}
	
	part def TouchInputController {
		attribute sensitivity : Real;
		attribute multiTouchEnabled : Boolean;
		
		port inputPort : UserInterfacePort;
		port powerIn : PowerPort;
		
		action def CaptureInput {
			out userRequest : UserRequest;
		}
		
		action def ProcessTouch {
			in touchCoordinates : Real[2];
			out interpretedAction : String;
		}
		
		action def DetectGesture {
			in touchSequence : Real[*];
			out gestureType : String;
		}
	}
	
	part def BatteryManagementSystem {
		attribute batteryLevel : BatteryLevel;
		attribute chargingStatus : Boolean;
		attribute estimatedRuntime : TimeValue;
		
		port powerOutput : PowerPort;
		
		action def MonitorBattery {
			out currentLevel : Real;
			out healthStatus : String;
		}
		
		action def DistributePower {
			in powerRequests : PowerValue[*];
			out allocatedPower : PowerValue;
		}
		
		action def OptimizePowerConsumption {
			in systemLoad : Real;
			out powerSavingMode : Boolean;
		}
		
		state batteryBehavior {
			entry; then normal;
			
			state fullCharge;
			accept discharge then normal;
			
			state normal;
			accept toLowPower then lowPower;
			accept toCharging then charging;
			
			state lowPower;
			accept toCritical then critical;
			accept toChargingFromLow then charging;
			
			state critical;
			accept emergencyCharging then charging;
			
			state charging;
			accept toFull then fullCharge;
		}
	}
	
	part def MobileInternetDevice {
		attribute deviceId : String;
		attribute operatingMode : String;
		attribute deviceName : String;
		
		part modem : WirelessModem;
		part processor : ApplicationProcessor;
		part display : DisplayController;
		part touchInput : TouchInputController;
		part battery : BatteryManagementSystem;
		
		connection powerToModem connect battery.powerOutput to modem.powerIn;
		connection powerToProcessor connect battery.powerOutput to processor.powerIn;
		connection powerToDisplay connect battery.powerOutput to display.powerIn;
		connection powerToTouch connect battery.powerOutput to touchInput.powerIn;
		
		perform action operateDevice[*] ordered references deviceOperation;
	}
	
	action def DeviceOperation {
		first start;
		then action initializeSystem {
			action powerOn;
			then action establishNetworkConnection;
			then action loadUserInterface;
		}
		then merge mainLoop;
		
		action mainLoop {
			first action captureUserInput {
				out userRequest : UserRequest;
			}
			then action processUserRequest {
				in request : UserRequest = captureUserInput.userRequest;
				out requestPacket : NetworkPacket;
			}
			then action transmitRequest {
				in packet : NetworkPacket = processUserRequest.requestPacket;
				out transmitSuccess : Boolean;
			}
			then decide;
				if transmitRequest.transmitSuccess then waitForResponse;
				if not transmitRequest.transmitSuccess then retryTransmission;
			
			action waitForResponse {
				action receiveNetworkData {
					out responsePacket : NetworkPacket;
				}
				then action processResponse {
					in packet : NetworkPacket = receiveNetworkData.responsePacket;
					out contentData : ContentData;
				}
				then action renderToDisplay {
					in content : ContentData = processResponse.contentData;
				}
			}
			then mainLoop;
			
			action retryTransmission {
				action delayRetry;
				then action reattemptConnection;
			}
			then mainLoop;
		}
		
		action monitorBatteryStatus {
			action checkBatteryLevel {
				out level : Real;
			}
			then decide;
				if checkBatteryLevel.level < 10.0 then enterLowPowerMode;
				if checkBatteryLevel.level >= 10.0 then continueNormalOperation;
			
			action enterLowPowerMode {
				action reduceBrightness;
				then action limitBackgroundProcesses;
			}
			action continueNormalOperation;
		}
		
		then done;
	}
	
	part mobileDevice : MobileInternetDevice {
		perform action operateDevice : DeviceOperation {
			first start;
			then fork parallelOperations;
			
			parallel action primaryFunction {
				perform operateDevice.initializeSystem;
				then perform operateDevice.mainLoop;
			}
			
			parallel action backgroundMonitoring {
				perform operateDevice.monitorBatteryStatus;
			}
			
			join parallelOperations;
			then done;
		}
		
		part :>> modem {
			perform operateDevice.mainLoop.transmitRequest;
			perform operateDevice.mainLoop.waitForResponse.receiveNetworkData;
		}
		
		part :>> processor {
			perform operateDevice.mainLoop.processUserRequest;
			perform operateDevice.mainLoop.waitForResponse.processResponse;
		}
		
		part :>> display {
			perform operateDevice.mainLoop.waitForResponse.renderToDisplay;
		}
		
		part :>> touchInput {
			perform operateDevice.mainLoop.captureUserInput;
		}
		
		part :>> battery {
			perform operateDevice.monitorBatteryStatus.checkBatteryLevel;
		}
	}
	
	requirement def ConnectivityRequirement {
		doc /* The device shall maintain network connectivity with minimum signal strength. */
		
		subject device : MobileInternetDevice;
		
		attribute minimumSignalStrength : Real = -90.0;
		
		require constraint {
			device.modem.signalStrength.value >= minimumSignalStrength
		}
	}
	
	requirement def BatteryLifeRequirement {
		doc /* The device shall operate for minimum duration on full battery charge. */
		
		subject device : MobileInternetDevice;
		
		attribute minimumOperatingTime : TimeValue;
		
		require constraint {
			device.battery.batteryLevel.percentage > 0.0
		}
	}
	
	requirement def DataThroughputRequirement {
		doc /* The device shall support minimum data transmission rate. */
		
		subject device : MobileInternetDevice;
		
		attribute minimumDataRate : Real = 1.0;
		
		require constraint {
			device.modem.currentDataRate.value >= minimumDataRate
		}
	}
	
	requirement def UserResponsivenessRequirement {
		doc /* The device shall respond to user input within acceptable time. */
		
		subject device : MobileInternetDevice;
		
		attribute maxResponseTime : TimeValue;
		
		require constraint {
			device.processor.processingSpeed > 1.0e9
		}
	}
	
	requirement <'MID-001'> deviceFunctionalRequirement {
		doc /* The mobile internet device shall provide continuous internet connectivity 
		       and user interaction capabilities for accessing online content. The primary
		       function is to enable users to browse the internet, access web applications,
		       and consume digital content through a wireless network connection. */
		
		subject mobileDevice;
		
		assume constraint networkAvailable {
			doc /* Network infrastructure is available and accessible. */
		}
		
		assume constraint powerAvailable {
			doc /* Battery has sufficient charge to operate. */
		}
		
		require connectivityReq : ConnectivityRequirement {
			subject device = mobileDevice;
		}
		
		require batteryReq : BatteryLifeRequirement {
			subject device = mobileDevice;
		}
		
		require throughputReq : DataThroughputRequirement {
			subject device = mobileDevice;
		}
		
		require responsivenessReq : UserResponsivenessRequirement {
			subject device = mobileDevice;
		}
	}
	
	occurrence def InternetBrowsingScenario {
		ref part user;
		ref part device : MobileInternetDevice;
		
		message userTouchInput of UserRequest
			from user to device.touchInput.inputPort;
		
		then message processedRequest of NetworkPacket
			from device.processor to device.modem.networkInterface;
		
		then message networkResponse of NetworkPacket
			from device.modem.networkInterface to device.processor;
		
		then message displayUpdate of ContentData
			from device.processor to device.display.displayPort;
	}
}
