package LinuxMCEHomeAutomationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def IPAddress {
        attribute octet1 : Integer;
        attribute octet2 : Integer;
        attribute octet3 : Integer;
        attribute octet4 : Integer;
    }

    attribute def MACAddress {
        attribute address : String;
    }

    attribute def BandwidthValue :> Real;
    attribute def StorageValue :> Real;
    attribute def PowerValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def TimeValue :> Real;

    enum def DeviceState {
        offline;
        initializing;
        ready;
        active;
        error;
    }

    enum def MediaType {
        audio;
        video;
        photo;
        stream;
    }

    enum def RoomType {
        livingRoom;
        bedroom;
        kitchen;
        office;
        homeTheater;
    }

    enum def AutomationProtocol {
        zwave;
        zigbee;
        x10;
        insteon;
    }

    enum def SecurityMode {
        disarmed;
        armedHome;
        armedAway;
        triggered;
    }

    item def MediaContent {
        attribute fileName : String;
        attribute mediaType : MediaType;
        attribute fileSizeGB : Real;
        attribute durationSeconds : Real;
        attribute codec : String;
        attribute resolution : String;
    }

    item def AutomationCommand {
        attribute commandId : String;
        attribute targetDevice : String;
        attribute action : String;
        attribute parameters : String[0..*];
        attribute timestamp : TimeValue;
    }

    item def SensorReading {
        attribute sensorId : String;
        attribute readingType : String;
        attribute value : Real;
        attribute unit : String;
        attribute timestamp : TimeValue;
    }

    item def BootComplete;
    item def InitializationComplete;
    item def StreamRequest;
    item def StreamComplete;
    item def AutomationTrigger;
    item def AutomationComplete;
    item def SystemError;
    item def RecoveryInitiated;
    item def RecoveryComplete;
    item def RecoveryFailed;

    port def NetworkPort {
        attribute ipAddress : IPAddress;
        attribute macAddress : MACAddress;
        attribute bandwidth : BandwidthValue;
        attribute isActive : Boolean;
    }

    port def MediaStreamPort {
        attribute streamType : MediaType;
        attribute bitrate : BandwidthValue;
        attribute isStreaming : Boolean;
        out stream : MediaContent;
    }

    port def ControlPort {
        in commands : AutomationCommand[0..*];
        out responses : String[0..*];
    }

    port def SensorPort {
        out readings : SensorReading[0..*];
    }

    part def CoreServer {
        doc /* Central orchestration server managing all LinuxMCE functions including
             * media distribution, automation control, and system coordination.
             */

        attribute serverName : String;
        attribute cpuCores : Integer;
        attribute ramGB : Integer;
        attribute powerConsumption : PowerValue;
        attribute currentState : DeviceState;

        port networkInterface : NetworkPort;
        port mediaOutput : MediaStreamPort[0..*];
        port automationControl : ControlPort[0..*];

        part mediaDatabase {
            attribute dbEngine : String = "MySQL";
            attribute storageCapacity : StorageValue;
            attribute indexedFiles : Integer;
            attribute mediaLibrary : MediaContent[0..*];
        }

        part deviceRegistry {
            attribute registeredDevices : Integer;
            attribute supportedProtocols : AutomationProtocol[0..*];
        }

        part routingEngine {
            attribute maxConcurrentStreams : Integer;
            attribute activeStreams : Integer;
            attribute transcodingEnabled : Boolean;
        }

        part schedulingEngine {
            attribute activeScenarios : Integer;
            attribute scheduledEvents : Integer;
        }
    }

    part def MediaDirector {
        doc /* Client device providing user interface and media playback capabilities
             * in specific rooms throughout the home.
             */

        attribute directorId : String;
        attribute assignedRoom : RoomType;
        attribute displayResolution : String;
        attribute currentState : DeviceState;

        port networkInterface : NetworkPort;
        port mediaInput : MediaStreamPort;
        port controlInterface : ControlPort;

        part displaySubsystem {
            attribute screenSizeInches : Real;
            attribute refreshRateHz : Real;
            attribute hdmiOutputs : Integer;
            attribute currentInput : String;
        }

        part audioSubsystem {
            attribute channels : Integer;
            attribute maxVolumeDB : Real;
            attribute currentVolumeDB : Real;
            attribute audioOutputs : Integer;
        }

        part userInterface {
            attribute interfaceType : String = "Orbiter";
            attribute touchEnabled : Boolean;
            attribute remoteEnabled : Boolean;
            attribute skinTheme : String;
        }

        part localCache {
            attribute cacheSize : StorageValue;
            attribute cachedContent : Integer;
        }
    }

    part def LightingController {
        doc /* Manages lighting control throughout the home using various automation protocols. */

        attribute controllerId : String;
        attribute protocol : AutomationProtocol;
        attribute maxDevices : Integer;
        attribute connectedDevices : Integer;

        port controlInterface : ControlPort;
        port networkInterface : NetworkPort;

        part lightingZones {
            attribute zoneCount : Integer;
            attribute dimmingSupported : Boolean;
            attribute colorSupported : Boolean;
            attribute sceneCount : Integer;
        }
    }

    part def ClimateController {
        doc /* Controls HVAC systems and monitors environmental conditions. */

        attribute controllerId : String;
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute hvacMode : String;
        attribute fanSpeed : String;

        port controlInterface : ControlPort;
        port networkInterface : NetworkPort;
        port sensorInput : SensorPort;

        part thermostat {
            attribute minTemp : TemperatureValue;
            attribute maxTemp : TemperatureValue;
            attribute hysteresis : TemperatureValue;
            attribute scheduleEnabled : Boolean;
        }

        part environmentalSensors {
            attribute temperatureSensors : Integer;
            attribute humiditySensors : Integer;
            attribute airQualitySensors : Integer;
        }
    }

    part def SecuritySystem {
        doc /* Provides comprehensive security monitoring and control including
             * cameras, sensors, and alarm management.
             */

        attribute systemId : String;
        attribute securityMode : SecurityMode;
        attribute alarmActive : Boolean;
        attribute sirenEnabled : Boolean;

        port controlInterface : ControlPort;
        port networkInterface : NetworkPort;
        port sensorInput : SensorPort;

        part surveillanceSubsystem {
            attribute cameraCount : Integer;
            attribute recordingEnabled : Boolean;
            attribute storageCapacity : StorageValue;
            attribute motionDetectionEnabled : Boolean;
            attribute nightVisionEnabled : Boolean;
        }

        part sensorSubsystem {
            attribute motionSensors : Integer;
            attribute doorSensors : Integer;
            attribute windowSensors : Integer;
            attribute glassSensors : Integer;
            attribute smokeSensors : Integer;
        }

        part alarmSubsystem {
            attribute sirenCount : Integer;
            attribute strobeCount : Integer;
            attribute notificationEnabled : Boolean;
        }
    }

    part def TelephonySystem {
        doc /* Manages VoIP telephony and intercom functionality. */

        attribute systemId : String;
        attribute voipProvider : String;
        attribute activeLines : Integer;
        attribute maxLines : Integer;

        port controlInterface : ControlPort;
        port networkInterface : NetworkPort;

        part intercom {
            attribute stations : Integer;
            attribute videoEnabled : Boolean;
        }

        part callRouting {
            attribute autoAttendantEnabled : Boolean;
            attribute voicemailEnabled : Boolean;
        }
    }

    action def InitializeLinuxMCESystem {
        doc /* Initialize the complete LinuxMCE system bringing all subsystems online
             * in proper sequence with dependency management.
             */

        first start;
        then action bootCoreServer {
            doc /* Boot core server and initialize database services */
            out serverReady : Boolean;
        }
        then action initializeNetwork {
            doc /* Configure network infrastructure and DHCP services */
            out networkReady : Boolean;
        }
        then action detectDevices {
            doc /* Auto-detect all connected devices on the network */
            out detectedCount : Integer;
        }
        then action configureDevices {
            doc /* Configure detected devices and assign to rooms */
            in deviceCount = detectDevices.detectedCount;
            out configuredCount : Integer;
        }
        then action indexMediaLibrary {
            doc /* Scan and index all media files in the library */
            out indexedFiles : Integer;
        }
        then fork;
            then action activateMediaDirectors {
                doc /* Bring all media directors online */
            }
            then action activateAutomation {
                doc /* Initialize automation controllers */
            }
            then action activateSecurity {
                doc /* Initialize security system */
            }
        then join;
        then action loadScenarios {
            doc /* Load automation scenarios and schedules */
        }
        then done;
    }

    action def StreamMediaContent {
        doc /* Stream media content from core server to a media director with
             * transcoding and quality adaptation as needed.
             */

        in mediaFile : MediaContent;
        in targetDirectorId : String;
        in requestedQuality : String;

        first start;
        then action validateRequest {
            doc /* Validate media file exists and director is available */
            in file = mediaFile;
            in director = targetDirectorId;
            out isValid : Boolean;
        }
        then decide;
            if validateRequest.isValid then retrieveMedia;
            if not validateRequest.isValid then abortStream;
        action retrieveMedia {
            doc /* Retrieve media file from library */
            in file = mediaFile;
            out mediaStream;
        }
        then action analyzeFormat {
            doc /* Analyze media format and director capabilities */
            in stream = retrieveMedia.mediaStream;
            in quality = requestedQuality;
            out needsTranscoding : Boolean;
        }
        then decide;
            if analyzeFormat.needsTranscoding then transcodeMedia;
            if not analyzeFormat.needsTranscoding then routeStream;
        action transcodeMedia {
            doc /* Transcode media to compatible format */
            in stream = retrieveMedia.mediaStream;
            out transcodedStream;
        }
        then routeStream;
        action routeStream {
            doc /* Route media stream to target director */
            in director = targetDirectorId;
        }
        then merge monitorLoop;
        then action monitorStream {
            doc /* Monitor stream health and buffer status */
            out streamActive : Boolean;
            out bufferLevel : Real;
        }
        then decide;
            if monitorStream.streamActive and monitorStream.bufferLevel > 0.2 then monitorLoop;
            if not monitorStream.streamActive or monitorStream.bufferLevel <= 0.2 then stopStream;
        action stopStream {
            doc /* Stop streaming and release resources */
        }
        then done;
        action abortStream {
            doc /* Abort stream request due to validation failure */
        }
        then done;
    }

    action def ExecuteAutomationScenario {
        doc /* Execute home automation scenario coordinating multiple subsystems
             * based on triggers, schedules, or user commands.
             */

        in scenarioName : String;
        in triggerSource : String;
        in parameters : String[0..*];

        first start;
        then action loadScenario {
            doc /* Load scenario definition and rules */
            in scenario = scenarioName;
            out scenarioSteps : String[0..*];
        }
        then action evaluateConditions {
            doc /* Evaluate scenario conditions and prerequisites */
            in steps = loadScenario.scenarioSteps;
            out conditionsMet : Boolean;
        }
        then decide;
            if evaluateConditions.conditionsMet then executeSteps;
            if not evaluateConditions.conditionsMet then done;
        action executeSteps {
            doc /* Execute scenario steps in sequence */
        }
        then fork;
            then action controlLighting {
                doc /* Adjust lighting according to scenario */
                in params = parameters;
            }
            then action controlClimate {
                doc /* Adjust climate settings according to scenario */
                in params = parameters;
            }
            then action controlMedia {
                doc /* Control media playback according to scenario */
                in params = parameters;
            }
            then action controlSecurity {
                doc /* Adjust security settings according to scenario */
                in params = parameters;
            }
        then join;
        then action logExecution {
            doc /* Log scenario execution for history and analytics */
            in scenario = scenarioName;
            in trigger = triggerSource;
        }
        then action notifyUsers {
            doc /* Send notifications to user interfaces */
        }
        then done;
    }

    state def CoreServerStates {
        entry; then booting;

        state booting {
            doc /* Server is booting and initializing core services */
        }

        transition booting_to_initializing
            first booting
            accept at BootComplete
            then initializing;

        state initializing {
            doc /* Server is initializing subsystems and detecting devices */
            entry action init : InitializeLinuxMCESystem;
        }

        transition initializing_to_ready
            first initializing
            accept at InitializationComplete
            then ready;

        state ready {
            doc /* Server is ready and waiting for requests */
        }

        transition ready_to_streaming
            first ready
            accept at StreamRequest
            then streaming;

        state streaming {
            doc /* Server is actively streaming media content */
            entry action stream : StreamMediaContent;
        }

        transition streaming_to_ready
            first streaming
            accept at StreamComplete
            then ready;

        transition ready_to_automating
            first ready
            accept at AutomationTrigger
            then automating;

        state automating {
            doc /* Server is executing automation scenarios */
            entry action automate : ExecuteAutomationScenario;
        }

        transition automating_to_ready
            first automating
            accept at AutomationComplete
            then ready;

        transition any_to_error
            accept at SystemError
            then error;

        state error {
            doc /* Server has encountered an error condition */
        }

        transition error_to_recovery
            first error
            accept at RecoveryInitiated
            then recovery;

        state recovery {
            doc /* Server is attempting to recover from error */
        }

        transition recovery_to_ready
            first recovery
            accept at RecoveryComplete
            then ready;

        transition recovery_to_error
            first recovery
            accept at RecoveryFailed
            then error;
    }

    connection def NetworkConnection {
        end source : NetworkPort;
        end target : NetworkPort;
    }

    connection def MediaStreamConnection {
        end source : MediaStreamPort;
        end target : MediaStreamPort;
    }

    connection def ControlConnection {
        end source : ControlPort;
        end target : ControlPort;
    }

    connection def SensorConnection {
        end source : SensorPort;
        end target : SensorPort;
    }

    part linuxMCESystem {
        doc /* Complete LinuxMCE home automation and media center system providing
             * unified control of entertainment, lighting, climate, security, and
             * telephony through an integrated intelligent platform.
             */

        attribute systemName : String = "LinuxMCE-Home";
        attribute totalPowerConsumption : PowerValue;

        part core : CoreServer {
            attribute :>> serverName = "LinuxMCE-Core-01";
            attribute :>> cpuCores = 8;
            attribute :>> ramGB = 32;
            attribute :>> powerConsumption = 150.0;
            attribute :>> currentState = DeviceState::ready;

            part :>> mediaDatabase {
                attribute :>> storageCapacity = 4000.0;
                attribute :>> indexedFiles = 5000;
            }

            part :>> deviceRegistry {
                attribute :>> registeredDevices = 45;
                attribute :>> supportedProtocols = (
                    AutomationProtocol::zwave,
                    AutomationProtocol::zigbee,
                    AutomationProtocol::insteon
                );
            }

            part :>> routingEngine {
                attribute :>> maxConcurrentStreams = 10;
                attribute :>> activeStreams = 0;
                attribute :>> transcodingEnabled = true;
            }

            part :>> schedulingEngine {
                attribute :>> activeScenarios = 15;
                attribute :>> scheduledEvents = 42;
            }
        }

        part livingRoomDirector : MediaDirector {
            attribute :>> directorId = "MD-LivingRoom-01";
            attribute :>> assignedRoom = RoomType::livingRoom;
            attribute :>> displayResolution = "3840x2160";
            attribute :>> currentState = DeviceState::ready;

            part :>> displaySubsystem {
                attribute :>> screenSizeInches = 65.0;
                attribute :>> refreshRateHz = 120.0;
                attribute :>> hdmiOutputs = 3;
                attribute :>> currentInput = "HDMI1";
            }

            part :>> audioSubsystem {
                attribute :>> channels = 8;
                attribute :>> maxVolumeDB = 100.0;
                attribute :>> currentVolumeDB = 45.0;
                attribute :>> audioOutputs = 2;
            }

            part :>> userInterface {
                attribute :>> touchEnabled = true;
                attribute :>> remoteEnabled = true;
                attribute :>> skinTheme = "Modern";
            }

            part :>> localCache {
                attribute :>> cacheSize = 100.0;
                attribute :>> cachedContent = 25;
            }
        }

        part bedroomDirector : MediaDirector {
            attribute :>> directorId = "MD-Bedroom-01";
            attribute :>> assignedRoom = RoomType::bedroom;
            attribute :>> displayResolution = "1920x1080";
            attribute :>> currentState = DeviceState::ready;

            part :>> displaySubsystem {
                attribute :>> screenSizeInches = 42.0;
                attribute :>> refreshRateHz = 60.0;
                attribute :>> hdmiOutputs = 2;
            }

            part :>> audioSubsystem {
                attribute :>> channels = 2;
                attribute :>> maxVolumeDB = 80.0;
                attribute :>> currentVolumeDB = 30.0;
            }
        }

        part theaterDirector : MediaDirector {
            attribute :>> directorId = "MD-Theater-01";
            attribute :>> assignedRoom = RoomType::homeTheater;
            attribute :>> displayResolution = "3840x2160";
            attribute :>> currentState = DeviceState::ready;

            part :>> displaySubsystem {
                attribute :>> screenSizeInches = 120.0;
                attribute :>> refreshRateHz = 120.0;
                attribute :>> hdmiOutputs = 4;
            }

            part :>> audioSubsystem {
                attribute :>> channels = 12;
                attribute :>> maxVolumeDB = 120.0;
                attribute :>> currentVolumeDB = 60.0;
            }
        }

        part lighting : LightingController {
            attribute :>> controllerId = "LC-Main-01";
            attribute :>> protocol = AutomationProtocol::zwave;
            attribute :>> maxDevices = 64;
            attribute :>> connectedDevices = 32;

            part :>> lightingZones {
                attribute :>> zoneCount = 15;
                attribute :>> dimmingSupported = true;
                attribute :>> colorSupported = true;
                attribute :>> sceneCount = 8;
            }
        }

        part climate : ClimateController {
            attribute :>> controllerId = "CC-Main-01";
            attribute :>> targetTemperature = 22.0;
            attribute :>> currentTemperature = 21.5;
            attribute :>> hvacMode = "auto";
            attribute :>> fanSpeed = "medium";

            part :>> thermostat {
                attribute :>> minTemp = 15.0;
                attribute :>> maxTemp = 30.0;
                attribute :>> hysteresis = 0.5;
                attribute :>> scheduleEnabled = true;
            }

            part :>> environmentalSensors {
                attribute :>> temperatureSensors = 6;
                attribute :>> humiditySensors = 4;
                attribute :>> airQualitySensors = 2;
            }
        }

        part security : SecuritySystem {
            attribute :>> systemId = "SEC-Main-01";
            attribute :>> securityMode = SecurityMode::disarmed;
            attribute :>> alarmActive = false;
            attribute :>> sirenEnabled = true;

            part :>> surveillanceSubsystem {
                attribute :>> cameraCount = 8;
                attribute :>> recordingEnabled = true;
                attribute :>> storageCapacity = 2000.0;
                attribute :>> motionDetectionEnabled = true;
                attribute :>> nightVisionEnabled = true;
            }

            part :>> sensorSubsystem {
                attribute :>> motionSensors = 12;
                attribute :>> doorSensors = 8;
                attribute :>> windowSensors = 16;
                attribute :>> glassSensors = 4;
                attribute :>> smokeSensors = 6;
            }

            part :>> alarmSubsystem {
                attribute :>> sirenCount = 2;
                attribute :>> strobeCount = 2;
                attribute :>> notificationEnabled = true;
            }
        }

        part telephony : TelephonySystem {
            attribute :>> systemId = "TEL-Main-01";
            attribute :>> voipProvider = "Asterisk";
            attribute :>> activeLines = 0;
            attribute :>> maxLines = 4;

            part :>> intercom {
                attribute :>> stations = 6;
                attribute :>> videoEnabled = true;
            }

            part :>> callRouting {
                attribute :>> autoAttendantEnabled = true;
                attribute :>> voicemailEnabled = true;
            }
        }

        connection coreToLivingRoom : NetworkConnection connect
            core.networkInterface to livingRoomDirector.networkInterface;

        connection coreToBedroom : NetworkConnection connect
            core.networkInterface to bedroomDirector.networkInterface;

        connection coreToTheater : NetworkConnection connect
            core.networkInterface to theaterDirector.networkInterface;

        connection coreToLighting : NetworkConnection connect
            core.networkInterface to lighting.networkInterface;

        connection coreToClimate : NetworkConnection connect
            core.networkInterface to climate.networkInterface;

        connection coreToSecurity : NetworkConnection connect
            core.networkInterface to security.networkInterface;

        connection coreToTelephony : NetworkConnection connect
            core.networkInterface to telephony.networkInterface;

        connection mediaToLivingRoom : MediaStreamConnection connect
            core.mediaOutput to livingRoomDirector.mediaInput;

        connection mediaToBedroom : MediaStreamConnection connect
            core.mediaOutput to bedroomDirector.mediaInput;

        connection mediaToTheater : MediaStreamConnection connect
            core.mediaOutput to theaterDirector.mediaInput;

        connection controlLighting : ControlConnection connect
            core.automationControl to lighting.controlInterface;

        connection controlClimate : ControlConnection connect
            core.automationControl to climate.controlInterface;

        connection controlSecurity : ControlConnection connect
            core.automationControl to security.controlInterface;

        connection controlTelephony : ControlConnection connect
            core.automationControl to telephony.controlInterface;

        perform action systemInit : InitializeLinuxMCESystem;

        state coreState : CoreServerStates;
    }

    requirement <'REQ-LMCE-001'> unifiedHomeControl {
        doc /* The LinuxMCE system shall provide unified control of all home automation,
             * entertainment, security, and communication functions through a single
             * integrated platform accessible from any media director.
             */
        subject system :>> linuxMCESystem;
    }

    requirement <'REQ-LMCE-002'> mediaDistribution {
        doc /* The system shall distribute media content from a central library to
             * multiple media directors throughout the home with support for at least
             * 10 concurrent streams.
             */
        subject core :>> linuxMCESystem.core;
        require constraint {
            core.routingEngine.maxConcurrentStreams >= 10
        }
    }

    requirement <'REQ-LMCE-003'> automaticDeviceDetection {
        doc /* The system shall automatically detect and integrate compatible home
             * automation devices on the network using plug-and-play technology.
             */
        subject system :>> linuxMCESystem;
    }

    requirement <'REQ-LMCE-004'> scenarioAutomation {
        doc /* The system shall execute automation scenarios coordinating actions across
             * multiple subsystems based on events, schedules, and user-defined rules.
             */
        subject system :>> linuxMCESystem;
    }

    requirement <'REQ-LMCE-005'> comprehensiveSecurity {
        doc /* The system shall integrate comprehensive security monitoring and control
             * including at least 8 cameras, 12 motion sensors, and alarm management.
             */
        subject security :>> linuxMCESystem.security;
        require constraint {
            security.surveillanceSubsystem.cameraCount >= 8 and
            security.sensorSubsystem.motionSensors >= 12
        }
    }

    requirement <'REQ-LMCE-006'> multiRoomAudio {
        doc /* The system shall support synchronized multi-room audio distribution
             * with independent volume control in each zone.
             */
        subject system :>> linuxMCESystem;
    }

    requirement <'REQ-LMCE-007'> climateControl {
        doc /* The system shall provide intelligent climate control with environmental
             * monitoring in at least 6 zones and schedule-based automation.
             */
        subject climate :>> linuxMCESystem.climate;
        require constraint {
            climate.environmentalSensors.temperatureSensors >= 6 and
            climate.thermostat.scheduleEnabled == true
        }
    }

    requirement <'REQ-LMCE-008'> voipIntegration {
        doc /* The system shall integrate VoIP telephony with video intercom capability
             * supporting at least 4 concurrent lines.
             */
        subject telephony :>> linuxMCESystem.telephony;
        require constraint {
            telephony.maxLines >= 4 and
            telephony.intercom.videoEnabled == true
        }
    }

    satisfy unifiedHomeControl by linuxMCESystem;
    satisfy mediaDistribution by linuxMCESystem.core;
    satisfy automaticDeviceDetection by linuxMCESystem;
    satisfy scenarioAutomation by linuxMCESystem;
    satisfy comprehensiveSecurity by linuxMCESystem.security;
    satisfy multiRoomAudio by linuxMCESystem;
    satisfy climateControl by linuxMCESystem.climate;
    satisfy voipIntegration by linuxMCESystem.telephony;
}
