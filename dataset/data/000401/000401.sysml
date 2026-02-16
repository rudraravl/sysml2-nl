package AndroidSystemModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def OSVersion {
		attribute major : Integer;
		attribute minor : Integer;
		attribute patch : Integer;
	}
	
	attribute def BatteryPercentage :> Real;
	attribute def SignalQuality :> Real;
	
	item def TouchEvent {
		attribute xPosition : Real;
		attribute yPosition : Real;
		attribute pressure : Real;
		attribute timestamp : TimeValue;
	}
	
	item def PixelFrame {
		attribute width : Integer;
		attribute height : Integer;
		attribute pixelData : Integer[*];
		attribute refreshRate : FrequencyValue;
	}
	
	item def NetworkPacket {
		attribute dataPayload : String;
		attribute packetSize : Integer;
		attribute timestamp : TimeValue;
	}
	
	item def AudioSample {
		attribute sampleRate : FrequencyValue;
		attribute bitDepth : Integer;
		attribute amplitude : Real;
	}
	
	item def SensorReading {
		attribute accelerationX : AccelerationValue;
		attribute accelerationY : AccelerationValue;
		attribute accelerationZ : AccelerationValue;
		attribute orientation : Real;
	}
	
	port def TouchInputPort {
		in item touch : TouchEvent;
	}
	
	port def DisplayPort {
		out item displayFrame : PixelFrame;
	}
	
	port def NetworkInterfacePort {
		in item rxPacket : NetworkPacket;
		out item txPacket : NetworkPacket;
	}
	
	port def AudioPort {
		in item audioIn : AudioSample;
		out item audioOut : AudioSample;
	}
	
	port def SensorInterfacePort {
		out item reading : SensorReading;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : ElectricPotentialValue;
		out attribute currentDraw : ElectricCurrentValue;
	}
	
	part def ApplicationProcessor {
		attribute cores : Integer;
		attribute clockFrequency : FrequencyValue;
		attribute temperature : ThermodynamicTemperatureValue;
		port processorPower : PowerSupplyPort;
		
		action def ExecuteInstruction {
			in instruction : String;
			out result : String;
		}
	}
	
	part def GraphicsProcessor {
		attribute shaderCores : Integer;
		attribute gpuFrequency : FrequencyValue;
		port gpuPower : PowerSupplyPort;
		
		action def RenderGraphics {
			in sceneData : String;
			out renderedFrame : PixelFrame;
		}
	}
	
	part def SystemMemory {
		attribute capacity : Real;
		attribute usedMemory : Real;
		attribute memorySpeed : FrequencyValue;
		port memoryPower : PowerSupplyPort;
	}
	
	part def DisplayPanel {
		attribute screenWidth : Integer;
		attribute screenHeight : Integer;
		attribute maxBrightness : Real;
		attribute currentBrightness : Real;
		port displayOutput : DisplayPort;
		port displayPower : PowerSupplyPort;
		
		action def UpdateScreen {
			in frameData : PixelFrame;
		}
	}
	
	part def TouchSensor {
		attribute touchSensitivity : Real;
		attribute multiTouchPoints : Integer;
		port touchInput : TouchInputPort;
		port touchPower : PowerSupplyPort;
		
		action def CaptureTouch {
			out touchData : TouchEvent;
		}
	}
	
	part def BatteryPack {
		attribute maxCapacity : EnergyValue;
		attribute currentCapacity : EnergyValue;
		attribute chargeLevel : BatteryPercentage;
		attribute outputVoltage : ElectricPotentialValue;
		port batteryOutput : PowerSupplyPort;
	}
	
	state def BatteryLifecycle {
		in attribute chargeLevel : BatteryPercentage;
		
		entry; then charging;
		
		state charging;
		transition charging_to_fullCharge
			first charging
			accept at when chargeLevel >= 80.0
			then fullCharge;
		
		state fullCharge;
		transition fullCharge_to_normalOperation
			first fullCharge
			accept at when chargeLevel < 80.0
			then normalOperation;
		
		state normalOperation;
		transition normalOperation_to_lowBattery
			first normalOperation
			accept at when chargeLevel <= 20.0
			then lowBattery;
		
		state lowBattery;
		transition lowBattery_to_criticalBattery
			first lowBattery
			accept at when chargeLevel <= 5.0
			then criticalBattery;
		
		state criticalBattery;
		transition criticalBattery_to_shutdown
			first criticalBattery
			accept at when chargeLevel <= 0.0
			then shutdown;
		
		state shutdown;
	}
	
	part def WirelessModem {
		attribute supportedBands : String[*];
		attribute signalStrength : SignalQuality;
		attribute dataRate : Real;
		port networkInterface : NetworkInterfacePort;
		port modemPower : PowerSupplyPort;
		
		action def TransmitPacket {
			in packet : NetworkPacket;
		}
		
		action def ReceivePacket {
			out packet : NetworkPacket;
		}
	}
	
	part def AudioCodec {
		attribute sampleRate : FrequencyValue;
		attribute channels : Integer;
		port audioInterface : AudioPort;
		port codecPower : PowerSupplyPort;
		
		action def ProcessAudio {
			in rawAudio : AudioSample;
			out processedAudio : AudioSample;
		}
	}
	
	part def SensorHub {
		attribute sensorCount : Integer;
		port sensorInterface : SensorInterfacePort;
		port sensorPower : PowerSupplyPort;
		
		action def AggregateReadings {
			out combinedData : SensorReading;
		}
	}
	
	part def AndroidOS {
		attribute version : OSVersion;
		attribute kernelVersion : String;
		attribute runningApps : Integer;
		attribute availableRAM : Real;
		
		action def ScheduleProcesses {
			in processQueue : String[*];
			out executionPlan : String[*];
		}
		
		action def ManageMemory {
			in memoryRequest : Real;
			out allocatedMemory : Real;
		}
		
		action def HandleInput {
			in userInput : TouchEvent;
			out systemResponse : String;
		}
	}
	
	part def ApplicationFramework {
		attribute installedApps : Integer;
		attribute activeServices : Integer;
		
		action def LaunchApp {
			in appIdentifier : String;
			out appInstance : String;
		}
		
		action def ProcessUIEvent {
			in touchInput : TouchEvent;
			out uiUpdate : PixelFrame;
		}
	}
	
	part def AndroidSmartphone;
	
	part androidSmartphone : AndroidSmartphone {
		attribute deviceName : String;
		attribute modelNumber : String;
		attribute imei : String;
		
		part cpu : ApplicationProcessor {
			:>> cores = 8;
			:>> clockFrequency = 3.0e9 [Hz];
			:>> temperature = 313.15 [K];
		}
		
		part gpu : GraphicsProcessor {
			:>> shaderCores = 512;
			:>> gpuFrequency = 900.0e6 [Hz];
		}
		
		part ram : SystemMemory {
			:>> capacity = 8192.0;
			:>> usedMemory = 4096.0;
			:>> memorySpeed = 3200.0e6 [Hz];
		}
		
		part screen : DisplayPanel {
			:>> screenWidth = 1440;
			:>> screenHeight = 3200;
			:>> maxBrightness = 1000.0;
			:>> currentBrightness = 500.0;
		}
		
		part touchPanel : TouchSensor {
			:>> touchSensitivity = 0.92;
			:>> multiTouchPoints = 10;
		}
		
		part battery : BatteryPack {
			:>> maxCapacity = 18000.0 [J];
			:>> currentCapacity = 14400.0 [J];
			:>> chargeLevel = 80.0;
			:>> outputVoltage = 3.8 [V];
		}
		
		part modem : WirelessModem {
			:>> supportedBands = ("LTE", "5G", "WiFi6");
			:>> signalStrength = 85.0;
			:>> dataRate = 1000.0;
		}
		
		part audio : AudioCodec {
			:>> sampleRate = 48000.0 [Hz];
			:>> channels = 2;
		}
		
		part sensors : SensorHub {
			:>> sensorCount = 6;
		}
		
		part operatingSystem : AndroidOS {
			:>> version.major = 14;
			:>> version.minor = 0;
			:>> version.patch = 5;
			:>> kernelVersion = "6.1.25";
			:>> runningApps = 12;
			:>> availableRAM = 4096.0;
		}
		
		part appFramework : ApplicationFramework {
			:>> installedApps = 85;
			:>> activeServices = 23;
		}
		
		connect battery.batteryOutput to cpu.processorPower;
		connect battery.batteryOutput to gpu.gpuPower;
		connect battery.batteryOutput to ram.memoryPower;
		connect battery.batteryOutput to screen.displayPower;
		connect battery.batteryOutput to touchPanel.touchPower;
		connect battery.batteryOutput to modem.modemPower;
		connect battery.batteryOutput to audio.codecPower;
		connect battery.batteryOutput to sensors.sensorPower;
		
		connect touchPanel.touchInput to screen.displayOutput;
		
		perform action executeSystemOperation : AndroidSystemOperation;
	}
	
	action def AndroidSystemOperation {
		first start;
		then action initializeSystem {
			doc /* Boot operating system and initialize hardware components */
		}
		then merge operationLoop;
		
		action operationLoop;
		then decide;
			if touchDetected then handleTouchInteraction;
			if networkActivity then processNetworkTraffic;
			if sensorUpdate then readSensorData;
			if displayUpdate then renderDisplay;
			if lowBattery then enterPowerSaveMode;
		
		action handleTouchInteraction {
			action captureTouchInput {
				doc /* Detect and capture touch event from touchscreen */
			}
			then action routeToOS {
				doc /* Route touch event to operating system */
			}
			then action processInFramework {
				doc /* Process event through application framework */
			}
			then action generateUIResponse {
				doc /* Generate user interface response */
			}
		}
		then operationLoop;
		
		action processNetworkTraffic {
			action receiveNetworkData {
				doc /* Receive data packets from wireless modem */
			}
			then action validatePackets {
				doc /* Validate and parse network packets */
			}
			then action deliverToApplication {
				doc /* Deliver data to target application */
			}
			then action prepareResponse {
				doc /* Prepare response packets if needed */
			}
			then action transmitResponse {
				doc /* Transmit response through modem */
			}
		}
		then operationLoop;
		
		action readSensorData {
			action pollSensors {
				doc /* Poll sensor hub for latest readings */
			}
			then action processSensorData {
				doc /* Process and filter sensor data */
			}
			then action updateApplications {
				doc /* Update applications with sensor information */
			}
		}
		then operationLoop;
		
		action renderDisplay {
			action prepareFrameBuffer {
				doc /* Prepare frame buffer with UI elements */
			}
			then action executeGPURender {
				doc /* Execute GPU rendering pipeline */
			}
			then action transferToDisplay {
				doc /* Transfer rendered frame to display panel */
			}
			then action updateDisplayPanel {
				doc /* Update physical display with new frame */
			}
		}
		then operationLoop;
		
		action enterPowerSaveMode {
			action reduceCPUFrequency {
				doc /* Lower CPU clock frequency */
			}
			then action dimDisplay {
				doc /* Reduce display brightness */
			}
			then action suspendBackgroundApps {
				doc /* Suspend non-critical background applications */
			}
		}
		then operationLoop;
	}
	
	requirement def SystemRequirement;
	requirement def PerformanceRequirement;
	requirement def PowerRequirement;
	
	requirement <'AND-SYS-001'> primarySystemFunction : SystemRequirement {
		doc /* 
		The Android smartphone shall provide a mobile computing platform that integrates 
		user interaction through touchscreen input, visual feedback through high-resolution 
		display, wireless connectivity for data communication, sensor-based context awareness, 
		and multimedia processing capabilities, all coordinated by the Android operating system 
		to enable execution of diverse applications while managing power consumption efficiently.
		*/
		
		subject androidSmartphone;
		
		require constraint {
			doc /* The system shall process touch input events within 10 milliseconds */
		}
		
		require constraint {
			doc /* The display shall maintain minimum refresh rate of 60 Hz */
		}
		
		require constraint {
			doc /* The system shall support concurrent execution of at least 10 applications */
		}
	}
	
	requirement <'AND-SYS-002'> responsiveUserExperience : PerformanceRequirement {
		doc /* 
		The Android smartphone shall deliver responsive user experience by maintaining 
		smooth touch interaction, fluid visual rendering, and immediate feedback to 
		user actions across all system operations.
		*/
		
		subject androidSmartphone;
		
		require constraint {
			doc /* Touch sensitivity shall exceed 90% accuracy */
		}
		
		require constraint {
			doc /* GPU shall render frames at minimum 60 frames per second */
		}
	}
	
	requirement <'AND-SYS-003'> efficientPowerManagement : PowerRequirement {
		doc /* 
		The Android smartphone shall manage battery power efficiently to maximize 
		operational duration while maintaining system performance and responsiveness.
		*/
		
		subject androidSmartphone.battery;
		
		require constraint {
			doc /* Battery charge level shall be continuously monitored */
		}
		
		require constraint {
			doc /* System shall activate power saving mode when battery drops below 20% */
		}
		
		require constraint {
			doc /* Critical shutdown shall occur only when battery reaches 0% */
		}
	}
	
	requirement <'AND-SYS-004'> wirelessConnectivity : SystemRequirement {
		doc /* 
		The Android smartphone shall maintain reliable wireless connectivity for 
		cellular and WiFi networks to enable continuous data communication.
		*/
		
		subject androidSmartphone.modem;
		
		require constraint {
			doc /* Modem shall support multiple wireless standards */
		}
		
		require constraint {
			doc /* Signal quality shall be monitored and reported */
		}
	}
	
	requirement <'AND-SYS-005'> integratedSystemOperation : SystemRequirement {
		doc /* 
		The Android smartphone shall integrate all hardware and software components 
		into a cohesive system that coordinates touch input, visual output, network 
		communication, sensor data, and application execution under unified operating 
		system control.
		*/
		
		assume constraint {
			doc /* Operating system version shall be Android 14 or higher */
		}
		
		require primarySystemFunction;
		require responsiveUserExperience;
		require efficientPowerManagement;
		require wirelessConnectivity;
	}
}
