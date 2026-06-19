package SmartDevicePrimaryFunctionModel {
	import ScalarValues::*;

	attribute def Temperature_C :> Real;
	attribute def RelativeHumidity_percent :> Real;
	attribute def Illuminance_lux :> Real;
	attribute def Power_W :> Real;
	attribute def Voltage_V :> Real;
	attribute def Current_A :> Real;
	attribute def Energy_Wh :> Real;
	attribute def Duration_s :> Real;
	attribute def Frequency_MHz :> Real;
	attribute def DataRate_Mbps :> Real;
	attribute def Percentage :> Real;
	attribute def Count :> Integer;
	attribute def Identifier :> String;

	enum def DeviceMode {
		enum off;
		enum starting;
		enum standby;
		enum monitoring;
		enum deciding;
		enum acting;
		enum connected;
		enum degraded;
		enum fault;
	}

	enum def CommandKind {
		enum powerOn;
		enum powerOff;
		enum setPreference;
		enum requestStatus;
		enum enableAutomation;
		enum disableAutomation;
	}

	enum def ServiceKind {
		enum notifyUser;
		enum adjustLocalService;
		enum logObservation;
		enum synchronizeCloud;
		enum enterLowPower;
	}

	enum def ConnectivityKind {
		enum disconnected;
		enum localOnly;
		enum cloudConnected;
		enum maintenance;
	}

	item def ElectricalPower {
		attribute voltage : Voltage_V;
		attribute current : Current_A;
		attribute power : Power_W;
	}

	item def EnvironmentCondition {
		attribute temperature : Temperature_C;
		attribute relativeHumidity : RelativeHumidity_percent;
		attribute illuminance : Illuminance_lux;
		attribute occupancyDetected : Boolean;
	}

	item def SensorSample {
		attribute sampleId : Identifier;
		attribute temperature : Temperature_C;
		attribute relativeHumidity : RelativeHumidity_percent;
		attribute illuminance : Illuminance_lux;
		attribute occupancyDetected : Boolean;
		attribute confidence : Percentage;
	}

	item def UserCommand {
		attribute commandId : Identifier;
		attribute kind : CommandKind;
		attribute requestedTemperature : Temperature_C;
		attribute automationEnabled : Boolean;
	}

	item def NetworkMessage {
		attribute messageId : Identifier;
		attribute payloadSize_kB : Real;
		attribute encrypted : Boolean;
		attribute commandKind : CommandKind;
	}

	item def DeviceStatus {
		attribute mode : DeviceMode;
		attribute connectivity : ConnectivityKind;
		attribute batteryLevel : Percentage;
		attribute serviceAvailability : Percentage;
		attribute lastResponseTime : Duration_s;
	}

	item def ServiceRequest {
		attribute requestId : Identifier;
		attribute serviceKind : ServiceKind;
		attribute targetTemperature : Temperature_C;
		attribute notifyUser : Boolean;
		attribute synchronizeCloud : Boolean;
	}

	item def ServiceEffect {
		attribute effectId : Identifier;
		attribute serviceKind : ServiceKind;
		attribute completed : Boolean;
		attribute completionTime : Duration_s;
	}

	item def UserNotification {
		attribute notificationId : Identifier;
		attribute status : DeviceStatus;
		attribute messageText : String;
	}

	port def PowerSourcePort {
		out item power : ElectricalPower;
	}

	port def EnvironmentSourcePort {
		out item condition : EnvironmentCondition;
	}

	port def UserCommandPort {
		out item command : UserCommand;
	}

	port def SensorSamplePort {
		out item sample : SensorSample;
	}

	port def NetworkPort {
		in item inboundMessage : NetworkMessage;
		out item outboundMessage : NetworkMessage;
	}

	port def StatusPort {
		out item status : DeviceStatus;
	}

	port def ServiceRequestPort {
		out item request : ServiceRequest;
	}

	port def ServiceEffectPort {
		out item effect : ServiceEffect;
	}

	port def UserNotificationPort {
		out item notification : UserNotification;
	}

	action def AcquireContext {
		in item condition : EnvironmentCondition;
		out item sample : SensorSample;
	}

	action def InterpretIntent {
		in item command : UserCommand;
		in item remoteMessage : NetworkMessage;
		out item normalizedCommand : UserCommand;
	}

	action def SelectSmartResponse {
		in item sample : SensorSample;
		in item command : UserCommand;
		out item request : ServiceRequest;
	}

	action def IssueServiceRequest {
		in item request : ServiceRequest;
		out item effect : ServiceEffect;
	}

	action def PublishStatus {
		in item effect : ServiceEffect;
		out item status : DeviceStatus;
		out item notification : UserNotification;
		out item message : NetworkMessage;
	}

	action def ProvidePrimarySmartService {
		in item sensedCondition : EnvironmentCondition;
		in item userCommand : UserCommand;
		in item cloudMessage : NetworkMessage;
		out item controlledEffect : ServiceEffect;
		out item userNotice : UserNotification;
		out item cloudStatus : NetworkMessage;

		action acquireContext : AcquireContext;
		action interpretIntent : InterpretIntent;
		action selectResponse : SelectSmartResponse;
		action issueRequest : IssueServiceRequest;
		action publishStatus : PublishStatus;

		flow sensedCondition to acquireContext.condition;
		flow userCommand to interpretIntent.command;
		flow cloudMessage to interpretIntent.remoteMessage;
		flow acquireContext.sample to selectResponse.sample;
		flow interpretIntent.normalizedCommand to selectResponse.command;
		flow selectResponse.request to issueRequest.request;
		flow issueRequest.effect to publishStatus.effect;
		flow issueRequest.effect to controlledEffect;
		flow publishStatus.notification to userNotice;
		flow publishStatus.message to cloudStatus;
	}

	state def SmartDeviceLifecycle {
		state off;
		state starting;
		state standby;
		state monitoring;
		state deciding;
		state acting;
		state connected;
		state degraded;
		state fault;

		transition initialStartup first off then starting;
		transition bootComplete first starting then standby;
		transition beginMonitoring first standby then monitoring;
		transition contextAcquired first monitoring then deciding;
		transition responseSelected first deciding then acting;
		transition actionCompleted first acting then monitoring;
		transition cloudAttached first monitoring then connected;
		transition cloudLost first connected then degraded;
		transition localRecovery first degraded then monitoring;
		transition unrecoverableError first degraded then fault;
		transition shutdown first standby then off;
	}

	part def PowerSubsystem {
		attribute nominalInputVoltage : Voltage_V = 5.0;
		attribute regulatedVoltage : Voltage_V = 3.3;
		attribute maximumOutputPower : Power_W = 12.0;
		attribute batteryCapacity : Energy_Wh = 18.0;
		attribute batteryLevel : Percentage = 85.0;

		port externalPower : ~PowerSourcePort;
		port regulatedPowerOut : PowerSourcePort;
	}

	part def SensorSubsystem {
		attribute samplingPeriod : Duration_s = 1.0;
		attribute temperatureAccuracy : Temperature_C = 0.3;
		attribute humidityAccuracy : RelativeHumidity_percent = 2.0;

		port powerIn : ~PowerSourcePort;
		port environmentIn : ~EnvironmentSourcePort;
		port sampleOut : SensorSamplePort;

		perform action acquire : AcquireContext;
	}

	part def EdgeProcessor {
		attribute clockFrequency : Frequency_MHz = 240.0;
		attribute responseBudget : Duration_s = 2.0;
		attribute localAutomationEnabled : Boolean = true;

		port powerIn : ~PowerSourcePort;
		port sampleIn : ~SensorSamplePort;
		port userCommandIn : ~UserCommandPort;
		port remoteCommandIn : ~UserCommandPort;
		port serviceRequestOut : ServiceRequestPort;
		port statusOut : StatusPort;

		perform action decide : SelectSmartResponse;
	}

	part def WirelessCommunicationModule {
		attribute radioFrequency : Frequency_MHz = 2400.0;
		attribute maximumDataRate : DataRate_Mbps = 150.0;
		attribute encryptedLinkRequired : Boolean = true;
		attribute connectivity : ConnectivityKind = ConnectivityKind::cloudConnected;

		port powerIn : ~PowerSourcePort;
		port network : NetworkPort;
		port remoteCommandOut : UserCommandPort;
		port statusIn : ~StatusPort;
	}

	part def UserInterface {
		attribute displayBrightness : Percentage = 70.0;
		attribute audibleAlertEnabled : Boolean = true;

		port powerIn : ~PowerSourcePort;
		port commandIn : ~UserCommandPort;
		port commandOut : UserCommandPort;
		port statusIn : ~StatusPort;
		port notificationOut : UserNotificationPort;
	}

	part def ServiceActuator {
		attribute nominalActuationTime : Duration_s = 0.5;
		attribute maximumActuationPower : Power_W = 6.0;

		port powerIn : ~PowerSourcePort;
		port requestIn : ~ServiceRequestPort;
		port effectOut : ServiceEffectPort;

		perform action issue : IssueServiceRequest;
	}

	part def SmartDevice {
		attribute deviceId : Identifier = "smart-device-001";
		attribute operatingMode : DeviceMode = DeviceMode::monitoring;
		attribute connectivity : ConnectivityKind = ConnectivityKind::cloudConnected;
		attribute serviceAvailability : Percentage = 99.5;
		attribute serviceResponseTime : Duration_s = 1.2;
		attribute maximumStandbyPower : Power_W = 1.5;
		attribute maximumActivePower : Power_W = 10.0;

		port powerIn : ~PowerSourcePort;
		port environmentIn : ~EnvironmentSourcePort;
		port userCommandIn : ~UserCommandPort;
		port network : NetworkPort;
		port controlledServiceOut : ServiceEffectPort;
		port userNotificationOut : UserNotificationPort;

		part powerSubsystem : PowerSubsystem;
		part sensorSubsystem : SensorSubsystem;
		part processor : EdgeProcessor;
		part wireless : WirelessCommunicationModule;
		part userInterface : UserInterface;
		part actuator : ServiceActuator;

		connect powerIn to powerSubsystem.externalPower;
		connect powerSubsystem.regulatedPowerOut to sensorSubsystem.powerIn;
		connect powerSubsystem.regulatedPowerOut to processor.powerIn;
		connect powerSubsystem.regulatedPowerOut to wireless.powerIn;
		connect powerSubsystem.regulatedPowerOut to userInterface.powerIn;
		connect powerSubsystem.regulatedPowerOut to actuator.powerIn;

		connect environmentIn to sensorSubsystem.environmentIn;
		connect sensorSubsystem.sampleOut to processor.sampleIn;

		connect userCommandIn to userInterface.commandIn;
		connect userInterface.commandOut to processor.userCommandIn;

		connect network to wireless.network;
		connect wireless.remoteCommandOut to processor.remoteCommandIn;
		connect processor.statusOut to wireless.statusIn;
		connect processor.statusOut to userInterface.statusIn;

		connect processor.serviceRequestOut to actuator.requestIn;
		connect actuator.effectOut to controlledServiceOut;
		connect userInterface.notificationOut to userNotificationOut;

		perform action providePrimarySmartService : ProvidePrimarySmartService;
		exhibit state lifecycle : SmartDeviceLifecycle;
	}

	part def User {
		port commandOut : UserCommandPort;
		port notificationIn : ~UserNotificationPort;
	}

	part def HomeEnvironment {
		attribute nominalTemperature : Temperature_C = 22.0;
		attribute nominalHumidity : RelativeHumidity_percent = 45.0;
		attribute nominalIlluminance : Illuminance_lux = 300.0;

		port environmentOut : EnvironmentSourcePort;
	}

	part def CloudService {
		attribute requiredEncryptedMessages : Boolean = true;
		attribute expectedAvailability : Percentage = 99.9;

		port network : NetworkPort;
	}

	part def PowerAdapter {
		attribute outputVoltage : Voltage_V = 5.0;
		attribute outputCurrentLimit : Current_A = 3.0;
		attribute outputPowerLimit : Power_W = 15.0;

		port powerOut : PowerSourcePort;
	}

	part def SmartServiceLoad {
		attribute acceptedMaximumEffectTime : Duration_s = 1.0;

		port serviceIn : ~ServiceEffectPort;
	}

	part def SmartDeviceSystem {
		part device : SmartDevice;
		part user : User;
		part homeEnvironment : HomeEnvironment;
		part cloudService : CloudService;
		part powerAdapter : PowerAdapter;
		part serviceLoad : SmartServiceLoad;

		connect powerAdapter.powerOut to device.powerIn;
		connect homeEnvironment.environmentOut to device.environmentIn;
		connect user.commandOut to device.userCommandIn;
		connect device.userNotificationOut to user.notificationIn;
		connect cloudService.network to device.network;
		connect device.controlledServiceOut to serviceLoad.serviceIn;
	}

	requirement def SmartDevicePrimaryFunctionRequirement {
		subject device : SmartDevice;

		require constraint {
			device.serviceResponseTime <= 2.0
		}

		require constraint {
			device.serviceAvailability >= 99.0
		}

		require constraint {
			device.maximumActivePower <= 10.0
		}
	}

	requirement def SmartDeviceConnectivityRequirement {
		subject device : SmartDevice;

		require constraint {
			device.connectivity == ConnectivityKind::cloudConnected
		}
	}

	requirement def SmartDevicePowerRequirement {
		subject device : SmartDevice;

		require constraint {
			device.maximumStandbyPower <= 1.5
		}
	}

	part smartDeviceSystem : SmartDeviceSystem;

	requirement primaryFunctionRequirement : SmartDevicePrimaryFunctionRequirement {
		subject device = smartDeviceSystem.device;
	}

	requirement connectivityRequirement : SmartDeviceConnectivityRequirement {
		subject device = smartDeviceSystem.device;
	}

	requirement powerRequirement : SmartDevicePowerRequirement {
		subject device = smartDeviceSystem.device;
	}

	satisfy primaryFunctionRequirement by smartDeviceSystem.device;
	satisfy connectivityRequirement by smartDeviceSystem.device.wireless;
	satisfy powerRequirement by smartDeviceSystem.device.powerSubsystem;
}
