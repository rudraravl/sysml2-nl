package 'Tuya IoT Platform System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def DeviceIdentifier;
	attribute def UserIdentifier;
	attribute def SessionToken;
	attribute def EncryptionKey;

	attribute def ResponseLatency :> ISQ::DurationValue;
	attribute def DataThroughput :> Real;
	attribute def PowerDraw :> ISQ::PowerValue;
	attribute def EnergyUsage :> ISQ::EnergyValue;

	item def DeviceCommand {
		attribute deviceId : DeviceIdentifier;
		attribute commandType : String;
		attribute parameters : String;
		attribute timestamp : Real;
	}

	item def DeviceTelemetry {
		attribute deviceId : DeviceIdentifier;
		attribute isOnline : Boolean;
		attribute powerState : Boolean;
		attribute sensorReadings : Real[*];
		attribute timestamp : Real;
	}

	item def CloudPacket {
		attribute packetId : String;
		attribute sourceAddress : String;
		attribute destinationAddress : String;
		attribute encryptedData : String;
		attribute securityToken : SessionToken;
	}

	item def UserRequest {
		attribute userId : UserIdentifier;
		attribute requestType : String;
		attribute targetDeviceId : DeviceIdentifier;
		attribute payload : String;
	}

	port def WirelessCommunicationPort {
		attribute signalQuality : Real;
		attribute throughput : DataThroughput;
		in item commandIn : DeviceCommand[*];
		out item telemetryOut : DeviceTelemetry[*];
	}

	port def CloudServicePort {
		attribute securityProtocol : String;
		attribute connectionStatus : Boolean;
		in item packetIn : CloudPacket[*];
		out item packetOut : CloudPacket[*];
	}

	port def ApplicationInterfacePort {
		in item userRequestIn : UserRequest[*];
		out item deviceResponseOut : DeviceTelemetry[*];
	}

	part def IoTDevice {
		attribute deviceId : DeviceIdentifier;
		attribute firmwareVersion : String;
		attribute powerConsumption : PowerDraw;
		attribute operationalState : Boolean;
		port communicationPort : WirelessCommunicationPort;

		part microcontroller {
			perform action processIncomingCommands;
			perform action generateTelemetry;
		}

		part wirelessModule {
			perform action transmitData;
			perform action receiveData;
		}
	}

	part def SmartLightDevice :> IoTDevice {
		attribute brightnessLevel : Real;
		attribute colorTemperature : Real;
		attribute isLightOn : Boolean;
		attribute energyConsumed : EnergyUsage;
	}

	part def SmartThermostatDevice :> IoTDevice {
		attribute currentTemperature : TemperatureValue;
		attribute setpointTemperature : TemperatureValue;
		attribute operatingMode : String;
		attribute hvacState : Boolean;
	}

	part def SmartSocketDevice :> IoTDevice {
		attribute currentLoad : PowerDraw;
		attribute cumulativeEnergy : EnergyUsage;
		attribute socketState : Boolean;
		attribute overloadProtection : Boolean;
	}

	part def TuyaCloudInfrastructure {
		attribute platformId : String;
		attribute serverRegion : String;
		attribute maxConcurrentConnections : Real;
		port cloudInterface : CloudServicePort;

		part deviceManagementService {
			perform action registerDevice;
			perform action authenticateDevice;
			perform action manageDeviceLifecycle;
		}

		part dataRoutingService {
			perform action routeCommandsToDevices;
			perform action aggregateTelemetryData;
			perform action enforceSecurityPolicies;
		}

		part persistenceService {
			perform action storeDeviceHistory;
			perform action cacheUserPreferences;
			perform action logSystemEvents;
		}

		part analyticsService {
			perform action analyzeUsagePatterns;
			perform action generateInsights;
			perform action detectAnomalies;
		}
	}

	part def MobileApplicationClient {
		attribute appVersion : String;
		attribute userId : UserIdentifier;
		attribute devicePlatform : String;
		port userInterface : ApplicationInterfacePort;
		port cloudConnection : CloudServicePort;

		part presentationLayer {
			perform action renderDeviceStatus;
			perform action captureUserCommands;
			perform action displayNotifications;
		}

		part businessLogicLayer {
			perform action validateUserInput;
			perform action formatCommands;
			perform action processResponses;
		}
	}

	part def NetworkGateway {
		attribute gatewayId : DeviceIdentifier;
		attribute maxSupportedDevices : Real;
		attribute networkProtocol : String;
		port localDeviceNetwork : WirelessCommunicationPort[*];
		port internetUplink : CloudServicePort;

		part routingController {
			perform action manageLocalTraffic;
			perform action bridgeToCloud;
			perform action handleDeviceDiscovery;
		}

		part securityModule {
			perform action encryptTraffic;
			perform action authenticateConnections;
		}
	}

	action def AuthenticateDeviceSession {
		in deviceCredentials : DeviceIdentifier;
		in securityKey : EncryptionKey;
		out authenticationSuccess : Boolean;
		out sessionToken : SessionToken;

		first start;
		then action validateCredentials {
			in credentials = deviceCredentials;
			in key = securityKey;
			out isValid : Boolean;
		}
		then decide;
			if validateCredentials.isValid then generateToken;
			if not validateCredentials.isValid then rejectAuth;
		action generateToken {
			out token : SessionToken;
		}
		then assign authenticationSuccess := true;
		then assign sessionToken := generateToken.token;
		then done;
		action rejectAuth;
		then assign authenticationSuccess := false;
		then done;
	}

	action def TransmitUserCommand {
		in userRequest : UserRequest;
		in targetDevice : DeviceIdentifier;
		out commandDelivered : Boolean;
		out deliveryLatency : ResponseLatency;

		first start;
		then action encapsulateCommand {
			in request = userRequest;
			out deviceCommand : DeviceCommand;
		}
		then action routeThroughCloud {
			in command = encapsulateCommand.deviceCommand;
			out cloudPacket : CloudPacket;
		}
		then action deliverToGateway {
			in packet = routeThroughCloud.cloudPacket;
			out gatewayReceived : Boolean;
		}
		then action forwardToDevice {
			in target = targetDevice;
			out deviceReceived : Boolean;
		}
		then assign commandDelivered := forwardToDevice.deviceReceived;
		then done;
	}

	action def CollectDeviceTelemetry {
		in deviceId : DeviceIdentifier;
		in sensorData : Real[*];
		out telemetryPacket : DeviceTelemetry;

		first start;
		then action assembleTelemetry {
			in id = deviceId;
			in readings = sensorData;
			out telemetry : DeviceTelemetry;
		}
		then assign telemetryPacket := assembleTelemetry.telemetry;
		then done;
	}

	action def SynchronizeDeviceState {
		in localTelemetry : DeviceTelemetry;
		out cloudPacket : CloudPacket;

		first start;
		then action encryptTelemetry {
			in telemetry = localTelemetry;
			out encrypted : String;
		}
		then action packageForCloud {
			in data = encryptTelemetry.encrypted;
			out packet : CloudPacket;
		}
		then assign cloudPacket := packageForCloud.packet;
		then done;
	}

	action def UpdateDeviceConfiguration {
		in command : DeviceCommand;
		in currentTelemetry : DeviceTelemetry;
		out updatedTelemetry : DeviceTelemetry;

		first start;
		then action parseCommand {
			in cmd = command;
			out parsedParameters : String;
		}
		then action applyConfiguration {
			in parameters = parseCommand.parsedParameters;
			in currentState = currentTelemetry;
			out newState : DeviceTelemetry;
		}
		then assign updatedTelemetry := applyConfiguration.newState;
		then done;
	}

	action def TuyaPlatformOperation {
		in userId : UserIdentifier;
		in targetDeviceId : DeviceIdentifier;
		in desiredCommand : String;
		out finalTelemetry : DeviceTelemetry;

		first start;
		then action authenticateSession : AuthenticateDeviceSession {
			in deviceCredentials = targetDeviceId;
			in securityKey;
			out authenticationSuccess;
			out sessionToken;
		}
		then decide;
			if authenticateSession.authenticationSuccess then proceedWithOperation;
			if not authenticateSession.authenticationSuccess then abortOperation;
		
		merge proceedWithOperation;
		then action issueUserCommand : TransmitUserCommand {
			in userRequest;
			in targetDevice = targetDeviceId;
			out commandDelivered;
			out deliveryLatency;
		}
		then action collectCurrentState : CollectDeviceTelemetry {
			in deviceId = targetDeviceId;
			in sensorData;
			out telemetryPacket;
		}
		then action updateConfiguration : UpdateDeviceConfiguration {
			in command;
			in currentTelemetry = collectCurrentState.telemetryPacket;
			out updatedTelemetry;
		}
		then action syncToCloud : SynchronizeDeviceState {
			in localTelemetry = updateConfiguration.updatedTelemetry;
			out cloudPacket;
		}
		then assign finalTelemetry := updateConfiguration.updatedTelemetry;
		then done;

		action abortOperation;
		then done;
	}

	state def DeviceLifecycleState {
		entry action initializeDevice;

		state unregistered {
			entry action awaitRegistration;
		}

		state registering {
			do action performRegistration;
		}

		state authenticated {
			entry action establishSecureSession;

			state disconnected {
				entry action attemptReconnection;
			}

			state connecting {
				do action negotiateConnection;
			}

			state operational {
				entry action enableDeviceServices;

				state standby;

				state executing {
					do action executeDeviceCommand;
				}

				state reporting {
					do action transmitTelemetry;
				}

				transition standby_to_executing
					first standby
					accept event commandReceived
					then executing;

				transition executing_to_standby
					first executing
					if commandCompleted
					then standby;

				transition standby_to_reporting
					first standby
					accept event telemetryScheduled
					then reporting;

				transition reporting_to_standby
					first reporting
					if telemetryTransmitted
					then standby;
			}

			transition disconnected_to_connecting
				first disconnected
				accept event connectionInitiated
				then connecting;

			transition connecting_to_operational
				first connecting
				if connectionEstablished
				then operational;

			transition connecting_to_disconnected
				first connecting
				if connectionTimedOut
				then disconnected;

			transition operational_to_disconnected
				first operational
				accept event connectionLost
				then disconnected;
		}

		transition unregistered_to_registering
			first unregistered
			accept event registrationRequest
			then registering;

		transition registering_to_authenticated
			first registering
			if registrationSuccessful
			then authenticated;

		transition registering_to_unregistered
			first registering
			if registrationFailed
			then unregistered;

		transition authenticated_to_unregistered
			first authenticated
			accept event deregistrationRequest
			then unregistered;

		exit action releaseResources;
	}

	part tuyaIoTPlatformSystem {
		doc /*
			The Tuya IoT Platform System is a comprehensive cloud-based ecosystem 
			that enables seamless connectivity, remote control, and intelligent 
			automation of diverse smart home and industrial IoT devices. The platform 
			provides unified device management, real-time data processing, secure 
			communication channels, and user-friendly interfaces for controlling 
			connected devices from anywhere in the world through mobile applications 
			and voice assistants.
		*/

		part cloudInfrastructure : TuyaCloudInfrastructure {
			perform TuyaPlatformOperation.authenticateSession;
			perform TuyaPlatformOperation.syncToCloud;
		}

		part networkGateway : NetworkGateway {
			exhibit state gatewayLifecycle : DeviceLifecycleState;
		}

		part mobileApp : MobileApplicationClient {
			perform TuyaPlatformOperation.issueUserCommand;
		}

		part smartLight1 : SmartLightDevice {
			perform TuyaPlatformOperation.collectCurrentState;
			perform TuyaPlatformOperation.updateConfiguration;
			exhibit state deviceLifecycle : DeviceLifecycleState;
		}

		part smartLight2 : SmartLightDevice {
			exhibit state deviceLifecycle : DeviceLifecycleState;
		}

		part thermostat1 : SmartThermostatDevice {
			perform TuyaPlatformOperation.collectCurrentState;
			perform TuyaPlatformOperation.updateConfiguration;
			exhibit state deviceLifecycle : DeviceLifecycleState;
		}

		part smartSocket1 : SmartSocketDevice {
			perform TuyaPlatformOperation.collectCurrentState;
			exhibit state deviceLifecycle : DeviceLifecycleState;
		}

		part smartSocket2 : SmartSocketDevice {
			exhibit state deviceLifecycle : DeviceLifecycleState;
		}

		connection appCloudLink connect mobileApp.cloudConnection to cloudInfrastructure.cloudInterface;
		connection gatewayCloudLink connect networkGateway.internetUplink to cloudInfrastructure.cloudInterface;
		connection gatewayLight1Link connect networkGateway.localDeviceNetwork to smartLight1.communicationPort;
		connection gatewayLight2Link connect networkGateway.localDeviceNetwork to smartLight2.communicationPort;
		connection gatewayThermostatLink connect networkGateway.localDeviceNetwork to thermostat1.communicationPort;
		connection gatewaySocket1Link connect networkGateway.localDeviceNetwork to smartSocket1.communicationPort;
		connection gatewaySocket2Link connect networkGateway.localDeviceNetwork to smartSocket2.communicationPort;
	}

	requirement <'TUYA-SYS-001'> platformPrimaryFunction {
		doc /*
			The Tuya IoT Platform System shall provide a unified cloud-based 
			infrastructure for connecting, controlling, and monitoring heterogeneous 
			smart devices across residential and commercial environments. The system 
			shall enable users to remotely manage device operations, automate 
			workflows based on triggers and conditions, receive real-time status 
			updates, and analyze historical usage data through intuitive mobile and 
			web applications with end-to-end encrypted communication channels.
		*/

		subject tuyaIoTPlatformSystem;

		require deviceConnectivityReq : DeviceConnectivityRequirement;
		require cloudReliabilityReq : CloudReliabilityRequirement;
		require userExperienceReq : UserExperienceRequirement;
		require securityReq : SecurityRequirement;
		require scalabilityReq : ScalabilityRequirement;
	}

	requirement deviceConnectivityReq : DeviceConnectivityRequirement {
		doc /*
			All registered IoT devices shall establish and maintain stable wireless 
			connectivity with the network gateway and successfully authenticate with 
			the cloud platform within 45 seconds of power-on under normal network 
			conditions. Devices shall automatically attempt reconnection with 
			exponential backoff strategy upon connection loss.
		*/
	}

	requirement cloudReliabilityReq : CloudReliabilityRequirement {
		doc /*
			The cloud infrastructure shall maintain 99.95% uptime availability and 
			process device telemetry updates and user commands with median response 
			latency not exceeding 300 milliseconds under normal load conditions. 
			The platform shall support graceful degradation and failover mechanisms 
			to ensure continuous operation during partial system failures.
		*/
	}

	requirement userExperienceReq : UserExperienceRequirement {
		doc /*
			The mobile application shall display real-time device status with visual 
			feedback provided within 1.5 seconds of user interaction. Control commands 
			shall be acknowledged within 2 seconds and device state changes shall be 
			reflected in the user interface within 3 seconds of command execution.
		*/
	}

	requirement securityReq : SecurityRequirement {
		doc /*
			All communication between devices, gateways, cloud infrastructure, and 
			client applications shall be encrypted using industry-standard protocols 
			(TLS 1.3 or higher). Device authentication shall employ multi-factor 
			mechanisms including unique device identifiers, cryptographic keys, and 
			time-limited session tokens. User data and device telemetry shall be 
			encrypted at rest and in transit.
		*/
	}

	requirement scalabilityReq : ScalabilityRequirement {
		doc /*
			The platform shall support horizontal scaling to accommodate at least 
			10,000 concurrent device connections per gateway instance and 1,000,000 
			registered devices per cloud region. The system architecture shall enable 
			dynamic resource allocation based on real-time demand with automatic 
			load balancing across distributed server infrastructure.
		*/
	}

	occurrence def SmartHomeControlScenario {
		ref part user;
		ref part system :>> tuyaIoTPlatformSystem;

		message userInitiatesCommand of UserRequest
			from user to system.mobileApp.userInterface.userRequestIn;

		then message appToCloudRequest of CloudPacket
			from system.mobileApp.cloudConnection.packetOut
			to system.cloudInfrastructure.cloudInterface.packetIn;

		then message cloudToGatewayCommand of CloudPacket
			from system.cloudInfrastructure.cloudInterface.packetOut
			to system.networkGateway.internetUplink.packetIn;

		then message gatewayToDeviceCommand of DeviceCommand
			from system.networkGateway.localDeviceNetwork.commandIn
			to system.smartLight1.communicationPort.commandIn;

		then message deviceExecutesCommand;

		then message deviceToGatewayTelemetry of DeviceTelemetry
			from system.smartLight1.communicationPort.telemetryOut
			to system.networkGateway.localDeviceNetwork.telemetryOut;

		then message gatewayToCloudTelemetry of CloudPacket
			from system.networkGateway.internetUplink.packetOut
			to system.cloudInfrastructure.cloudInterface.packetIn;

		then message cloudToAppResponse of CloudPacket
			from system.cloudInfrastructure.cloudInterface.packetOut
			to system.mobileApp.cloudConnection.packetIn;

		then message appToUserFeedback of DeviceTelemetry
			from system.mobileApp.userInterface.deviceResponseOut
			to user;
	}
}
