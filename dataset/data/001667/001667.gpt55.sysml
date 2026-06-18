package LinuxMCE_HighLevel_System_Model {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def AvailabilityRatio :> Real;
    attribute def Count :> Integer;
    attribute def MediaStreamCount :> Integer;
    attribute def Percent :> Real;
    attribute def Seconds :> ISQ::time { unit = SI::second; }
    attribute def Milliseconds :> ISQ::time { unit = SI::milli * SI::second; }
    attribute def Hertz :> ISQ::frequency { unit = SI::hertz; }
    attribute def DataRate :> ISQ::dataRate { unit = SI::bit / SI::second; }
    attribute def StorageCapacity :> ISQ::informationCapacity { unit = SI::byte; }
    attribute def ElectricPower :> ISQ::power { unit = SI::watt; }
    attribute def TemperatureCelsius :> ISQ::thermodynamicTemperature { unit = SI::degreeCelsius; }
    attribute def LuminousIntensityPercent :> Percent;
    attribute def AudioLevelPercent :> Percent;
    attribute def Voltage :> ISQ::electricPotential { unit = SI::volt; }

    enum def DeviceHealthStatus {
        enum nominal;
        enum degraded;
        enum offline;
        enum initializing;
        enum faulted;
    }

    enum def SecurityMode {
        enum disarmed;
        enum armedStay;
        enum armedAway;
        enum alarmActive;
    }

    enum def OccupancyState {
        enum occupied;
        enum unoccupied;
        enum unknown;
    }

    enum def MediaPlaybackState {
        enum stopped;
        enum playing;
        enum paused;
        enum buffering;
        enum unavailable;
    }

    enum def AutomationPriority {
        enum informational;
        enum normal;
        enum urgent;
        enum emergency;
    }

    item def EthernetFrame {
        attribute payloadBytes : StorageCapacity;
        attribute vlanId : Integer;
        attribute priorityCodePoint : Integer;
    }

    item def IpPacket {
        attribute payloadBytes : StorageCapacity;
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute protocol : String;
    }

    item def DceMessage {
        attribute sourceDeviceId : Integer;
        attribute targetDeviceId : Integer;
        attribute commandName : String;
        attribute commandGroup : String;
        attribute priority : AutomationPriority;
        attribute issuedAtEpochSeconds : Seconds;
    }

    item def MediaContentRequest {
        attribute contentId : String;
        attribute roomId : String;
        attribute requestedResolution : String;
        attribute requestedAudioChannels : Integer;
    }

    item def MediaStream {
        attribute streamId : String;
        attribute codec : String;
        attribute videoBitRate : DataRate;
        attribute audioBitRate : DataRate;
        attribute frameRate : Hertz;
        attribute latencyBudget : Milliseconds;
    }

    item def LightingCommand {
        attribute zoneId : String;
        attribute targetLevel : LuminousIntensityPercent;
        attribute transitionTime : Seconds;
    }

    item def ClimateCommand {
        attribute zoneId : String;
        attribute targetTemperature : TemperatureCelsius;
        attribute fanMode : String;
    }

    item def SecurityEvent {
        attribute sensorId : String;
        attribute eventType : String;
        attribute severity : AutomationPriority;
        attribute detectedAtEpochSeconds : Seconds;
    }

    item def TelephonyEvent {
        attribute callId : String;
        attribute callerId : String;
        attribute destinationExtension : String;
        attribute eventType : String;
    }

    item def OrbiterUserCommand {
        attribute userId : String;
        attribute roomId : String;
        attribute commandName : String;
        attribute commandPayload : String;
    }

    item def AutomationStatus {
        attribute systemMode : String;
        attribute securityMode : SecurityMode;
        attribute activeMediaStreams : MediaStreamCount;
        attribute deviceHealth : DeviceHealthStatus;
        attribute summaryText : String;
    }

    item def Notification {
        attribute recipient : String;
        attribute subject : String;
        attribute body : String;
        attribute priority : AutomationPriority;
    }

    port def EthernetPort {
        in item rxFrame : EthernetFrame;
        out item txFrame : EthernetFrame;
        attribute nominalSpeed : DataRate;
    }

    port def IpNetworkPort {
        in item inboundPacket : IpPacket;
        out item outboundPacket : IpPacket;
        attribute nominalThroughput : DataRate;
    }

    port def DcePort {
        in item inboundMessage : DceMessage;
        out item outboundMessage : DceMessage;
    }

    port def MediaRequestPort {
        in item request : MediaContentRequest;
        out item stream : MediaStream;
    }

    port def MediaRenderPort {
        in item streamIn : MediaStream;
        out item playbackState : MediaPlaybackState;
    }

    port def LightingControlPort {
        in item command : LightingCommand;
        out item status : AutomationStatus;
    }

    port def ClimateControlPort {
        in item command : ClimateCommand;
        out item status : AutomationStatus;
    }

    port def SecuritySensorPort {
        out item event : SecurityEvent;
        in item armDisarmCommand : DceMessage;
    }

    port def TelephonyPort {
        in item telephonyEventIn : TelephonyEvent;
        out item telephonyEventOut : TelephonyEvent;
    }

    port def UserInterfacePort {
        in item displayedStatus : AutomationStatus;
        out item userCommand : OrbiterUserCommand;
    }

    port def NotificationPort {
        out item notification : Notification;
    }

    part def LinuxMCEHomeControlSystem {
        attribute primaryFunction : String = "Provide a unified LinuxMCE-based home infrastructure that integrates media distribution, home automation, security monitoring, telephony, and user interfaces through a central Core using the DCE router.";
        attribute targetAvailability : AvailabilityRatio = 0.995;
        attribute maximumCommandLatency : Milliseconds = 500;
        attribute maximumMediaStartupTime : Seconds = 5;
        attribute supportedRooms : Count = 6;
        attribute supportedOrbiters : Count = 12;
        attribute supportedMediaStreams : MediaStreamCount = 8;
        attribute nominalPowerConsumption : ElectricPower = 450 [SI::watt];

        port wan : IpNetworkPort;
        port homeEthernet : EthernetPort;
        port notifications : NotificationPort;

        part core : LinuxMCECore {
            attribute deviceId = 1;
            attribute hostName = "dcerouter";
            attribute installedRole = "LinuxMCE Core";
        }

        part network : HomeNetwork {
            attribute lanThroughput = 1000000000 [SI::bit / SI::second];
            attribute wifiThroughput = 600000000 [SI::bit / SI::second];
        }

        part livingRoomMediaDirector : MediaDirector {
            attribute deviceId = 101;
            attribute roomId = "living-room";
            attribute displayResolution = "3840x2160";
        }

        part bedroomMediaDirector : MediaDirector {
            attribute deviceId = 102;
            attribute roomId = "bedroom";
            attribute displayResolution = "1920x1080";
        }

        part kitchenOrbiter : OrbiterInterface {
            attribute deviceId = 201;
            attribute roomId = "kitchen";
            attribute interfaceType = "wall-tablet";
        }

        part mobileOrbiter : OrbiterInterface {
            attribute deviceId = 202;
            attribute roomId = "mobile";
            attribute interfaceType = "smartphone";
        }

        part lightingSubsystem : LightingSubsystem {
            attribute zoneCount = 12;
            attribute defaultTransition = 2 [SI::second];
        }

        part climateSubsystem : ClimateSubsystem {
            attribute zoneCount = 4;
            attribute allowedMinimumSetpoint = 16 [SI::degreeCelsius];
            attribute allowedMaximumSetpoint = 30 [SI::degreeCelsius];
        }

        part securitySubsystem : SecuritySubsystem {
            attribute protectedSensorCount = 18;
            attribute sirenPower = 30 [SI::watt];
        }

        part telephonySubsystem : TelephonySubsystem {
            attribute extensionCount = 6;
            attribute voicemailRetention = 30;
        }

        part storage : MediaStorage {
            attribute totalCapacity = 16000000000000 [SI::byte];
            attribute reservedRecordingCapacity = 4000000000000 [SI::byte];
        }

        connect wan to network.internet;
        connect homeEthernet to network.backbone;
        connect network.coreLan to core.lan;
        connect network.mediaLan1 to livingRoomMediaDirector.lan;
        connect network.mediaLan2 to bedroomMediaDirector.lan;
        connect network.orbiterLan1 to kitchenOrbiter.network;
        connect network.orbiterLan2 to mobileOrbiter.network;
        connect core.storageNetwork to storage.network;
        connect core.dceBus to lightingSubsystem.dce;
        connect core.dceBus to climateSubsystem.dce;
        connect core.dceBus to securitySubsystem.dce;
        connect core.dceBus to telephonySubsystem.dce;
        connect core.mediaService to livingRoomMediaDirector.mediaRequest;
        connect core.mediaService to bedroomMediaDirector.mediaRequest;
        connect livingRoomMediaDirector.dce to core.dceBus;
        connect bedroomMediaDirector.dce to core.dceBus;
        connect kitchenOrbiter.ui to core.orbiterService;
        connect mobileOrbiter.ui to core.orbiterService;
        connect securitySubsystem.alerts to notifications;
        connect core.notifications to notifications;

        perform action orchestration : CoordinateIntegratedHomeServices {
            in item userCommand = kitchenOrbiter.ui.userCommand;
            out item status = kitchenOrbiter.ui.displayedStatus;
        }

        exhibit state systemStates : LinuxMCESystemOperationalStates;

        satisfy requirement primaryFunctionRequirement by this;
        satisfy requirement integratedControlRequirement by core;
        satisfy requirement mediaDistributionRequirement by livingRoomMediaDirector;
        satisfy requirement automationLatencyRequirement by core;
        satisfy requirement securityMonitoringRequirement by securitySubsystem;
        satisfy requirement userInterfaceRequirement by kitchenOrbiter;
    }

    part def LinuxMCECore {
        attribute deviceId : Integer;
        attribute hostName : String;
        attribute installedRole : String;
        attribute cpuClock : Hertz = 3200000000 [SI::hertz];
        attribute memoryCapacity : StorageCapacity = 32000000000 [SI::byte];
        attribute systemDiskCapacity : StorageCapacity = 1000000000000 [SI::byte];
        attribute dceRouterHealth : DeviceHealthStatus = DeviceHealthStatus::nominal;
        attribute databaseHealth : DeviceHealthStatus = DeviceHealthStatus::nominal;
        attribute activeSessions : Count;
        attribute activeMediaStreams : MediaStreamCount;

        port lan : IpNetworkPort {
            attribute nominalThroughput = 1000000000 [SI::bit / SI::second];
        }
        port storageNetwork : IpNetworkPort;
        port dceBus : DcePort;
        port mediaService : MediaRequestPort;
        port orbiterService : UserInterfacePort;
        port telephonyService : TelephonyPort;
        port notifications : NotificationPort;

        part dceRouter : DCERouter {
            attribute routingTableCapacity = 512;
            attribute maximumMessageLatency = 200 [SI::milli * SI::second];
        }

        part plutoDatabase : ConfigurationDatabase {
            attribute configuredDeviceCount = 64;
            attribute backupInterval = 86400 [SI::second];
        }

        part automationEngine : AutomationEngine {
            attribute ruleCount = 75;
            attribute sceneCount = 24;
        }

        part mediaCatalog : MediaCatalogService {
            attribute indexedMovieCount = 1200;
            attribute indexedAudioTrackCount = 45000;
        }

        connect dceBus to dceRouter.dce;
        connect mediaService to mediaCatalog.mediaRequest;
        connect orbiterService to automationEngine.userInterface;
        connect dceRouter.database to plutoDatabase.query;
        connect automationEngine.dce to dceRouter.dce;
        connect mediaCatalog.database to plutoDatabase.query;

        perform action bootCore : BootLinuxMCECore;
        perform action routeAutomationCommand : RouteDceAutomationCommand;
        exhibit state coreStates : CoreServiceStates;
    }

    part def DCERouter {
        attribute routingTableCapacity : Count;
        attribute maximumMessageLatency : Milliseconds;
        attribute health : DeviceHealthStatus = DeviceHealthStatus::nominal;

        port dce : DcePort;
        port database : IpNetworkPort;

        perform action routeMessage : RouteDceAutomationCommand;
    }

    part def ConfigurationDatabase {
        attribute configuredDeviceCount : Count;
        attribute backupInterval : Seconds;
        attribute health : DeviceHealthStatus = DeviceHealthStatus::nominal;

        port query : IpNetworkPort;
    }

    part def AutomationEngine {
        attribute ruleCount : Count;
        attribute sceneCount : Count;
        attribute occupancy : OccupancyState = OccupancyState::unknown;
        attribute securityMode : SecurityMode = SecurityMode::disarmed;

        port dce : DcePort;
        port userInterface : UserInterfacePort;

        perform action evaluateEventRules : EvaluateAutomationRules;
    }

    part def MediaCatalogService {
        attribute indexedMovieCount : Count;
        attribute indexedAudioTrackCount : Count;
        attribute transcodePowerLimit : ElectricPower = 180 [SI::watt];

        port mediaRequest : MediaRequestPort;
        port database : IpNetworkPort;

        perform action prepareMediaStream : PrepareMediaStream;
    }

    part def HomeNetwork {
        attribute lanThroughput : DataRate;
        attribute wifiThroughput : DataRate;
        attribute routerPower : ElectricPower = 25 [SI::watt];

        port internet : IpNetworkPort;
        port backbone : EthernetPort;
        port coreLan : IpNetworkPort;
        port mediaLan1 : IpNetworkPort;
        port mediaLan2 : IpNetworkPort;
        port orbiterLan1 : IpNetworkPort;
        port orbiterLan2 : IpNetworkPort;
    }

    part def MediaDirector {
        attribute deviceId : Integer;
        attribute roomId : String;
        attribute displayResolution : String;
        attribute playbackState : MediaPlaybackState = MediaPlaybackState::stopped;
        attribute maximumVideoBitRate : DataRate = 50000000 [SI::bit / SI::second];
        attribute maximumAudioLevel : AudioLevelPercent = 100;
        attribute nominalPower : ElectricPower = 65 [SI::watt];

        port lan : IpNetworkPort;
        port dce : DcePort;
        port mediaRequest : MediaRequestPort;
        port renderer : MediaRenderPort;

        part localPlayer : MediaRenderingEngine {
            attribute supportedCodec = "H.264,H.265,VP9,AAC,FLAC";
        }

        connect mediaRequest to localPlayer.streamControl;
        connect renderer to localPlayer.renderOutput;

        perform action playRequestedMedia : RenderMediaContent;
        exhibit state playbackStates : MediaDirectorPlaybackStates;
    }

    part def MediaRenderingEngine {
        attribute supportedCodec : String;
        attribute audioSyncTolerance : Milliseconds = 40 [SI::milli * SI::second];

        port streamControl : MediaRequestPort;
        port renderOutput : MediaRenderPort;
    }

    part def OrbiterInterface {
        attribute deviceId : Integer;
        attribute roomId : String;
        attribute interfaceType : String;
        attribute screenRefreshPeriod : Seconds = 1 [SI::second];
        attribute batteryVoltage : Voltage = 3.8 [SI::volt];

        port network : IpNetworkPort;
        port ui : UserInterfacePort;

        perform action submitUserCommand : SubmitOrbiterCommand;
    }

    part def LightingSubsystem {
        attribute zoneCount : Count;
        attribute defaultTransition : Seconds;
        attribute maximumZonesOn : Count = 12;
        attribute health : DeviceHealthStatus = DeviceHealthStatus::nominal;

        port dce : DcePort;
        port lighting : LightingControlPort;

        part livingRoomLights : LightingZone {
            attribute zoneId = "living-room";
            attribute maximumLoad = 600 [SI::watt];
        }

        part bedroomLights : LightingZone {
            attribute zoneId = "bedroom";
            attribute maximumLoad = 300 [SI::watt];
        }

        part kitchenLights : LightingZone {
            attribute zoneId = "kitchen";
            attribute maximumLoad = 500 [SI::watt];
        }

        connect lighting to livingRoomLights.control;
        connect lighting to bedroomLights.control;
        connect lighting to kitchenLights.control;

        perform action setLightingScene : ApplyLightingScene;
    }

    part def LightingZone {
        attribute zoneId : String;
        attribute currentLevel : LuminousIntensityPercent = 0;
        attribute maximumLoad : ElectricPower;

        port control : LightingControlPort;
    }

    part def ClimateSubsystem {
        attribute zoneCount : Count;
        attribute allowedMinimumSetpoint : TemperatureCelsius;
        attribute allowedMaximumSetpoint : TemperatureCelsius;
        attribute health : DeviceHealthStatus = DeviceHealthStatus::nominal;

        port dce : DcePort;
        port climate : ClimateControlPort;

        part livingRoomThermostat : ThermostatZone {
            attribute zoneId = "living-room";
            attribute currentTemperature = 21 [SI::degreeCelsius];
        }

        part bedroomThermostat : ThermostatZone {
            attribute zoneId = "bedroom";
            attribute currentTemperature = 20 [SI::degreeCelsius];
        }

        connect climate to livingRoomThermostat.control;
        connect climate to bedroomThermostat.control;

        perform action controlClimate : AdjustClimateZone;
    }

    part def ThermostatZone {
        attribute zoneId : String;
        attribute currentTemperature : TemperatureCelsius;
        attribute targetTemperature : TemperatureCelsius = 21 [SI::degreeCelsius];

        port control : ClimateControlPort;
    }

    part def SecuritySubsystem {
        attribute protectedSensorCount : Count;
        attribute sirenPower : ElectricPower;
        attribute currentMode : SecurityMode = SecurityMode::disarmed;
        attribute alarmNotificationDelay : Seconds = 3 [SI::second];

        port dce : DcePort;
        port sensorBus : SecuritySensorPort;
        port alerts : NotificationPort;

        part entryDoorSensor : SecuritySensor {
            attribute sensorId = "front-door";
            attribute sensorType = "door-contact";
            attribute batteryVoltage = 3.1 [SI::volt];
        }

        part motionSensorHallway : SecuritySensor {
            attribute sensorId = "hallway-motion";
            attribute sensorType = "pir-motion";
            attribute batteryVoltage = 3.0 [SI::volt];
        }

        part smokeDetectorKitchen : SecuritySensor {
            attribute sensorId = "kitchen-smoke";
            attribute sensorType = "smoke";
            attribute batteryVoltage = 3.2 [SI::volt];
        }

        connect sensorBus to entryDoorSensor.sense;
        connect sensorBus to motionSensorHallway.sense;
        connect sensorBus to smokeDetectorKitchen.sense;

        perform action processSecurityEvent : ProcessSecurityEvent;
        exhibit state securityStates : SecurityModeStates;
    }

    part def SecuritySensor {
        attribute sensorId : String;
        attribute sensorType : String;
        attribute health : DeviceHealthStatus = DeviceHealthStatus::nominal;
        attribute batteryVoltage : Voltage;

        port sense : SecuritySensorPort;
    }

    part def TelephonySubsystem {
        attribute extensionCount : Count;
        attribute voicemailRetention : Count;
        attribute sipRegistrationHealth : DeviceHealthStatus = DeviceHealthStatus::nominal;

        port dce : DcePort;
        port sipTrunk : TelephonyPort;
        port roomPhones : TelephonyPort;

        perform action handleIncomingCall : HandleTelephonyEvent;
    }

    part def MediaStorage {
        attribute totalCapacity : StorageCapacity;
        attribute reservedRecordingCapacity : StorageCapacity;
        attribute availableCapacity : StorageCapacity = 8000000000000 [SI::byte];
        attribute health : DeviceHealthStatus = DeviceHealthStatus::nominal;

        port network : IpNetworkPort;
    }

    action def CoordinateIntegratedHomeServices {
        in item userCommand : OrbiterUserCommand;
        out item status : AutomationStatus;

        first start;
        then authenticateUser;
        then classifyCommand;
        if commandIsMedia then prepareMedia;
        if commandIsLighting then sendLightingCommand;
        if commandIsClimate then sendClimateCommand;
        if commandIsSecurity then updateSecurityMode;
        then publishStatus;
        then done;

        action authenticateUser;
        action classifyCommand;
        action prepareMedia;
        action sendLightingCommand;
        action sendClimateCommand;
        action updateSecurityMode;
        action publishStatus;

        decision commandIsMedia;
        decision commandIsLighting;
        decision commandIsClimate;
        decision commandIsSecurity;
    }

    action def BootLinuxMCECore {
        out item status : AutomationStatus;

        first start;
        then initializeLinuxServices;
        then mountMediaStorage;
        then startDatabase;
        then startDceRouter;
        then discoverConfiguredDevices;
        then publishReadyStatus;
        then done;

        action initializeLinuxServices;
        action mountMediaStorage;
        action startDatabase;
        action startDceRouter;
        action discoverConfiguredDevices;
        action publishReadyStatus;
    }

    action def RouteDceAutomationCommand {
        in item command : DceMessage;
        out item routedCommand : DceMessage;

        first receiveCommand;
        then validateDeviceIds;
        then lookupDestination;
        then forwardToTarget;
        then logResult;
        then done;

        action receiveCommand;
        action validateDeviceIds;
        action lookupDestination;
        action forwardToTarget;
        action logResult;
    }

    action def EvaluateAutomationRules {
        in item eventMessage : DceMessage;
        out item resultingCommand : DceMessage;

        first acceptEvent;
        then evaluateRoomContext;
        then evaluateOccupancy;
        then evaluateTimeOfDay;
        then selectSceneOrDeviceCommand;
        then emitCommand;
        then done;

        action acceptEvent;
        action evaluateRoomContext;
        action evaluateOccupancy;
        action evaluateTimeOfDay;
        action selectSceneOrDeviceCommand;
        action emitCommand;
    }

    action def PrepareMediaStream {
        in item request : MediaContentRequest;
        out item stream : MediaStream;

        first receiveRequest;
        then verifyContentAvailability;
        then selectBestFormat;
        then reserveNetworkBandwidth;
        then startStreamer;
        then deliverStream;
        then done;

        action receiveRequest;
        action verifyContentAvailability;
        action selectBestFormat;
        action reserveNetworkBandwidth;
        action startStreamer;
        action deliverStream;
    }

    action def RenderMediaContent {
        in item stream : MediaStream;
        out item playbackState : MediaPlaybackState;

        first receiveStream;
        then bufferStream;
        then synchronizeAudioVideo;
        then renderToDisplay;
        then reportPlaybackState;
        then done;

        action receiveStream;
        action bufferStream;
        action synchronizeAudioVideo;
        action renderToDisplay;
        action reportPlaybackState;
    }

    action def SubmitOrbiterCommand {
        out item command : OrbiterUserCommand;
        in item status : AutomationStatus;

        first captureUserGesture;
        then buildCommandPayload;
        then transmitToCore;
        then receiveUpdatedStatus;
        then refreshDisplay;
        then done;

        action captureUserGesture;
        action buildCommandPayload;
        action transmitToCore;
        action receiveUpdatedStatus;
        action refreshDisplay;
    }

    action def ApplyLightingScene {
        in item command : LightingCommand;
        out item status : AutomationStatus;

        first receiveSceneCommand;
        then validateZone;
        then rampDimmer;
        then confirmLevel;
        then done;

        action receiveSceneCommand;
        action validateZone;
        action rampDimmer;
        action confirmLevel;
    }

    action def AdjustClimateZone {
        in item command : ClimateCommand;
        out item status : AutomationStatus;

        first receiveSetpoint;
        then validateTemperatureRange;
        then commandThermostat;
        then monitorTemperature;
        then reportClimateStatus;
        then done;

        action receiveSetpoint;
        action validateTemperatureRange;
        action commandThermostat;
        action monitorTemperature;
        action reportClimateStatus;
    }

    action def ProcessSecurityEvent {
        in item event : SecurityEvent;
        out item alert : Notification;

        first receiveSensorEvent;
        then correlateSecurityMode;
        if alarmCondition then activateAlarm;
        if informationalCondition then logEvent;
        then notifyOccupants;
        then done;

        action receiveSensorEvent;
        action correlateSecurityMode;
        action activateAlarm;
        action logEvent;
        action notifyOccupants;

        decision alarmCondition;
        decision informationalCondition;
    }

    action def HandleTelephonyEvent {
        in item telephonyEvent : TelephonyEvent;
        out item routedTelephonyEvent : TelephonyEvent;

        first receiveSipEvent;
        then matchCallerRules;
        then pauseActiveMediaIfNeeded;
        then routeToExtensionOrVoicemail;
        then publishCallStatus;
        then done;

        action receiveSipEvent;
        action matchCallerRules;
        action pauseActiveMediaIfNeeded;
        action routeToExtensionOrVoicemail;
        action publishCallStatus;
    }

    state def LinuxMCESystemOperationalStates {
        entry;
        state poweredOff;
        state booting;
        state discoveringDevices;
        state operational;
        state degraded;
        state emergencyAlarm;
        state maintenance;

        transition first poweredOff;
        transition powerApplied from poweredOff to booting;
        transition coreServicesStarted from booting to discoveringDevices;
        transition devicesDiscovered from discoveringDevices to operational;
        transition nonCriticalDeviceFailure from operational to degraded;
        transition serviceRestored from degraded to operational;
        transition securityEmergency from operational to emergencyAlarm;
        transition securityReset from emergencyAlarm to operational;
        transition maintenanceRequested from operational to maintenance;
        transition maintenanceCompleted from maintenance to operational;
    }

    state def CoreServiceStates {
        entry;
        state stopped;
        state linuxBooting;
        state databaseStarting;
        state dceRouterStarting;
        state running;
        state recovering;
        state failed;

        transition first stopped;
        transition start from stopped to linuxBooting;
        transition linuxReady from linuxBooting to databaseStarting;
        transition databaseReady from databaseStarting to dceRouterStarting;
        transition dceReady from dceRouterStarting to running;
        transition transientFault from running to recovering;
        transition recoveryComplete from recovering to running;
        transition unrecoverableFault from recovering to failed;
        transition restart from failed to linuxBooting;
    }

    state def MediaDirectorPlaybackStates {
        entry;
        state idle;
        state requestingContent;
        state buffering;
        state playing;
        state paused;
        state stopped;
        state unavailable;

        transition first idle;
        transition contentSelected from idle to requestingContent;
        transition streamAssigned from requestingContent to buffering;
        transition bufferReady from buffering to playing;
        transition pauseRequested from playing to paused;
        transition resumeRequested from paused to playing;
        transition stopRequested from playing to stopped;
        transition stopFromPaused from paused to stopped;
        transition networkFault from playing to unavailable;
        transition serviceRestored from unavailable to idle;
    }

    state def SecurityModeStates {
        entry;
        state disarmed;
        state armingDelay;
        state armedStay;
        state armedAway;
        state entryDelay;
        state alarmActive;

        transition first disarmed;
        transition armStayRequested from disarmed to armedStay;
        transition armAwayRequested from disarmed to armingDelay;
        transition exitDelayExpired from armingDelay to armedAway;
        transition perimeterBreachWhileArmed from armedStay to alarmActive;
        transition motionDetectedWhileAway from armedAway to alarmActive;
        transition entryDoorOpened from armedAway to entryDelay;
        transition validCodeEntered from entryDelay to disarmed;
        transition entryDelayExpired from entryDelay to alarmActive;
        transition disarmRequested from alarmActive to disarmed;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : LinuxMCEHomeControlSystem;
        doc /* The system shall provide a unified LinuxMCE-based home automation and media-control environment at a high level by coordinating media, lighting, climate, security, telephony, and user interfaces through the LinuxMCE Core. */
        require constraint { system.supportedRooms >= 6 }
        require constraint { system.supportedOrbiters >= 12 }
        require constraint { system.supportedMediaStreams >= 8 }
    }

    requirement def IntegratedControlRequirement {
        subject core : LinuxMCECore;
        doc /* The Core shall act as the central DCE router, configuration host, automation coordinator, and media catalog service for all connected rooms and subsystems. */
        require constraint { core.memoryCapacity >= 16000000000 [SI::byte] }
        require constraint { core.cpuClock >= 2000000000 [SI::hertz] }
    }

    requirement def AutomationLatencyRequirement {
        subject core : LinuxMCECore;
        doc /* User automation commands issued from Orbiters shall be routed by the Core to controlled devices within the specified command-latency budget. */
        require constraint { core.dceRouter.maximumMessageLatency <= 200 [SI::milli * SI::second] }
    }

    requirement def MediaDistributionRequirement {
        subject director : MediaDirector;
        doc /* Each Media Director shall request, receive, and render media streams from the LinuxMCE Core for its assigned room. */
        require constraint { director.maximumVideoBitRate >= 25000000 [SI::bit / SI::second] }
    }

    requirement def SecurityMonitoringRequirement {
        subject security : SecuritySubsystem;
        doc /* The security subsystem shall monitor configured sensors, change security modes, and notify occupants when emergency events are detected. */
        require constraint { security.protectedSensorCount >= 10 }
        require constraint { security.alarmNotificationDelay <= 5 [SI::second] }
    }

    requirement def UserInterfaceRequirement {
        subject orbiter : OrbiterInterface;
        doc /* Orbiter user interfaces shall allow occupants to command media, lighting, climate, security, and telephony functions and receive integrated system status. */
        require constraint { orbiter.screenRefreshPeriod <= 2 [SI::second] }
    }

    requirement primaryFunctionRequirement : PrimaryFunctionRequirement {
        subject system = linuxMCEHome;
    }

    requirement integratedControlRequirement : IntegratedControlRequirement {
        subject core = linuxMCEHome.core;
    }

    requirement automationLatencyRequirement : AutomationLatencyRequirement {
        subject core = linuxMCEHome.core;
    }

    requirement mediaDistributionRequirement : MediaDistributionRequirement {
        subject director = linuxMCEHome.livingRoomMediaDirector;
    }

    requirement securityMonitoringRequirement : SecurityMonitoringRequirement {
        subject security = linuxMCEHome.securitySubsystem;
    }

    requirement userInterfaceRequirement : UserInterfaceRequirement {
        subject orbiter = linuxMCEHome.kitchenOrbiter;
    }

    part linuxMCEHome : LinuxMCEHomeControlSystem {
        attribute primaryFunction = "Centralize control of a smart home using LinuxMCE so occupants can access one integrated environment for whole-home media, automation, security, climate, lighting, telephony, and status monitoring.";
    }

}
