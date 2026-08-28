package LinuxMCE {

    unit def Celsius { shortName = 'C'; }
    unit def Percent { shortName = '%'; }
    unit def Inches { shortName = 'in'; }
    unit def Channels { shortName = 'ch'; }
    unit def AQI { shortName = 'AQI'; }

    value def TemperatureValue :> Real { unit Celsius; }
    value def HumidityValue :> Real { unit Percent; }
    value def AirQualityValue :> Real { unit AQI; }
    value def ScreenSizeValue :> Real { unit Inches; }
    value def AudioChannelsValue :> Integer { unit Channels; }
    value def BrightnessValue :> Real { unit Percent; }
    value def VolumeValue :> Real { unit Percent; }

    item def MediaItem {
        attribute title : String;
        attribute mediaType : String;
        attribute filePath : String;
        attribute indexed : Boolean;
    }

    item def MediaStream {
        attribute streamId : String;
        attribute source : String;
        attribute target : String;
        attribute bitrate : Integer;
    }

    item def ControlCommand {
        attribute commandId : String;
        attribute targetDevice : String;
        attribute payload : String;
        attribute priority : Integer;
    }

    item def SensorReading {
        attribute sensorId : String;
        attribute value : Real;
        attribute timestamp : String;
    }

    item def AlertEvent {
        attribute severity : String;
        attribute description : String;
        attribute source : String;
    }

    item def PhoneCall {
        attribute callerId : String;
        attribute duration : Integer;
        attribute accepted : Boolean;
    }

    item def VoicemailMessage {
        attribute from : String;
        attribute length : Integer;
        attribute timestamp : String;
    }

    item def IntercomMessage {
        attribute fromRoom : String;
        attribute toRoom : String;
        attribute content : String;
    }

    item def DeviceDescriptor {
        attribute deviceId : String;
        attribute deviceType : String;
        attribute location : String;
        attribute protocol : String;
    }

    port def NetworkPort {
        in command : ControlCommand;
        out status : String;
    }

    port def MediaStreamPort {
        in streamRequest : String;
        out mediaStream : MediaStream;
    }

    port def ZWavePort {
        in zWaveCommand : String;
        out zWaveStatus : String;
    }

    port def SensorPort {
        out reading : SensorReading;
    }

    port def AudioPort {
        out audioSignal : String;
    }

    port def VideoPort {
        out videoSignal : String;
    }

    port def AlarmPort {
        out alert : AlertEvent;
    }

    port def TelephonyPort {
        in call : PhoneCall;
        out callStatus : String;
    }

    port def IntercomPort {
        in message : IntercomMessage;
        out messageStatus : String;
    }

    requirement def CentralControlRequirement {
        doc "The Core Server shall act as the central brain for the entire house, orchestrating all automation tasks.";
        subject coreServer : CoreServer;
        objective { coreServer.managesAllSubsystems == true }
    }

    requirement def MediaLibraryRequirement {
        doc "The Core Server shall manage a central media library storing all movies, music, and photos.";
        subject coreServer : CoreServer;
        objective { coreServer.mediaLibrary.size > 0 }
    }

    requirement def DeviceRegistryRequirement {
        doc "The Core Server shall keep a registry of every connected device.";
        subject coreServer : CoreServer;
        objective { coreServer.deviceRegistry.size > 0 }
    }

    requirement def MediaDirectorRequirement {
        doc "Media Directors shall allow residents to watch movies, listen to music, or access the control interface.";
        subject director : MediaDirector;
        objective { director.supportsVideo == true and director.supportsAudio == true and director.supportsControlUI == true }
    }

    requirement def HomeTheaterRequirement {
        doc "The home theater Media Director shall support a 120-inch screen and a 12-channel sound system.";
        subject director : MediaDirector;
        objective { director.screenSize == 120 and director.audioChannels == 12 }
    }

    requirement def LightingScenesRequirement {
        doc "The Lighting Controller shall execute pre-programmed scenes like Movie Night or Welcome Home.";
        subject lighting : LightingController;
        objective { lighting.scenes.includes("Movie Night") == true and lighting.scenes.includes("Welcome Home") == true }
    }

    requirement def ClimateControlRequirement {
        doc "The Climate Controller shall maintain a comfortable environment using sensors and automated schedules.";
        subject climate : ClimateController;
        objective { climate.maintainsComfort == true }
    }

    requirement def SecurityRequirement {
        doc "The Security System shall provide surveillance with cameras, sensors, and an alarm system.";
        subject security : SecuritySystem;
        objective { security.cameras.size > 0 and security.sensors.size > 0 and security.alarmSystem.active == true }
    }

    requirement def TelephonyRequirement {
        doc "The Telephony System shall integrate VoIP with auto-attendant, voicemail, and video intercom.";
        subject telephony : TelephonySystem;
        objective { telephony.voipEnabled == true and telephony.autoAttendant == true and telephony.voicemail == true and telephony.videoIntercom == true }
    }

    requirement def AutomationScenarioRequirement {
        doc "The system shall execute complex multi-system scenarios like Good Morning triggered by schedule.";
        subject system : LinuxMCESystem;
        objective { system.scenarios.includes("Good Morning") == true }
    }

    requirement def DeviceDiscoveryRequirement {
        doc "The system shall discover new devices and register them automatically.";
        subject coreServer : CoreServer;
        objective { coreServer.deviceDiscoveryEnabled == true }
    }

    requirement def MediaIndexingRequirement {
        doc "The system shall index new media and make it available in the media library.";
        subject coreServer : CoreServer;
        objective { coreServer.mediaIndexingEnabled == true }
    }

    action def LogMessage { in message : String; }
    action def IndexNewMedia { in newMedia : MediaItem; }
    action def DiscoverNewDevices { in deviceInfo : DeviceDescriptor; }
    action def ExecuteScenario { in scenarioName : String; }
    action def RouteMediaStreams { }
    action def ManageDeviceRegistry { }
    action def PerformMaintenance { }
    action def StreamMedia { }
    action def RenderAudioVideo { }
    action def DisplayControlUI { }
    action def ExecuteScene { in sceneName : String; }
    action def AdjustLights { in brightness : BrightnessValue; }
    action def ActivateHeating { }
    action def ActivateCooling { }
    action def RunSchedule { in scheduleName : String; }
    action def MonitorSensors { }
    action def TriggerAlarm { }
    action def NotifyHomeowners { }
    action def HandleIncomingCall { in call : PhoneCall; }
    action def RecordVoicemail { }
    action def EstablishIntercom { in message : IntercomMessage; }
    action def RouteTraffic { }
    action def ExecuteGoodMorning { }
    action def ExecuteMovieNight { }
    action def ExecuteWelcomeHome { }

    part def CoreServer {
        port networkPort : NetworkPort;
        port mediaStreamPort : MediaStreamPort;
        attribute mediaLibrary : MediaItem[0..*];
        attribute deviceRegistry : DeviceDescriptor[0..*];
        attribute scenarios : String[0..*];
        attribute managesAllSubsystems : Boolean;
        attribute deviceDiscoveryEnabled : Boolean;
        attribute mediaIndexingEnabled : Boolean;
        attribute currentScenario : String;

        state machine CoreServerBehavior {
            entry { LogMessage("Core Server initialized"); }
            state Operational {
                entry { ManageDeviceRegistry(); }
                do { RouteMediaStreams(); }
                state MediaIndexing {
                    entry { IndexNewMedia(); }
                    transition to DeviceDiscovery on newDeviceDetected;
                    transition to ScenarioExecution on scenarioTriggered;
                }
                state DeviceDiscovery {
                    entry { DiscoverNewDevices(); }
                    transition to MediaIndexing on newMediaDetected;
                    transition to ScenarioExecution on scenarioTriggered;
                }
                state ScenarioExecution {
                    entry { ExecuteScenario(currentScenario); }
                    transition to MediaIndexing on scenarioComplete;
                    transition to DeviceDiscovery on scenarioComplete;
                }
                transition to Maintenance on maintenanceScheduled;
            }
            state Maintenance {
                entry { PerformMaintenance(); }
                transition to Operational on maintenanceComplete;
            }
        }
    }

    part def MediaDirector {
        port networkPort : NetworkPort;
        port mediaStreamPort : MediaStreamPort;
        port audioOut : AudioPort;
        port videoOut : VideoPort;
        attribute roomName : String;
        attribute screenSize : ScreenSizeValue;
        attribute audioChannels : AudioChannelsValue;
        attribute resolution : String;
        attribute supportsVideo : Boolean;
        attribute supportsAudio : Boolean;
        attribute supportsControlUI : Boolean;
        attribute volume : VolumeValue;
        attribute currentMedia : String;

        state machine MediaDirectorBehavior {
            entry { LogMessage("Media Director initialized in " + roomName); }
            state Idle {
                transition to PlayingMedia on playCommand;
                transition to ControlInterface on uiCommand;
            }
            state PlayingMedia {
                entry { StreamMedia(); }
                do { RenderAudioVideo(); }
                transition to Idle on stopCommand;
                transition to Paused on pauseCommand;
            }
            state Paused {
                transition to PlayingMedia on resumeCommand;
                transition to Idle on stopCommand;
            }
            state ControlInterface {
                entry { DisplayControlUI(); }
                transition to Idle on exitCommand;
                transition to PlayingMedia on playCommand;
            }
        }
    }

    part def LightingController {
        port networkPort : NetworkPort;
        port zWavePort : ZWavePort;
        attribute lights : String[0..*];
        attribute zones : String[0..*];
        attribute scenes : String[0..*];
        attribute brightness : BrightnessValue;
        attribute currentScene : String;

        state machine LightingBehavior {
            entry { LogMessage("Lighting Controller initialized"); }
            state Idle {
                transition to ExecutingScene on sceneCommand;
                transition to AdjustingLights on lightCommand;
            }
            state ExecutingScene {
                entry { ExecuteScene(currentScene); }
                transition to Idle on sceneComplete;
            }
            state AdjustingLights {
                entry { AdjustLights(brightness); }
                transition to Idle on adjustmentComplete;
            }
        }
    }

    part def ClimateController {
        port networkPort : NetworkPort;
        port sensorPort : SensorPort;
        attribute targetTemperature : TemperatureValue;
        attribute currentTemperature : TemperatureValue;
        attribute currentHumidity : HumidityValue;
        attribute currentAirQuality : AirQualityValue;
        attribute schedules : String[0..*];
        attribute maintainsComfort : Boolean;
        attribute currentSchedule : String;

        state machine ClimateBehavior {
            entry { LogMessage("Climate Controller initialized"); }
            state Idle {
                transition to Heating on tempBelowTarget;
                transition to Cooling on tempAboveTarget;
                transition to ScheduledOperation on scheduleTrigger;
            }
            state Heating {
                entry { ActivateHeating(); }
                transition to Idle on targetReached;
            }
            state Cooling {
                entry { ActivateCooling(); }
                transition to Idle on targetReached;
            }
            state ScheduledOperation {
                entry { RunSchedule(currentSchedule); }
                transition to Idle on scheduleComplete;
            }
        }
    }

    part def Camera {
        attribute cameraId : String;
        attribute location : String;
        attribute motionDetection : Boolean;
        attribute nightVision : Boolean;
        attribute recording : Boolean;
    }

    part def SecuritySensor {
        attribute sensorId : String;
        attribute sensorType : String;
        attribute location : String;
        attribute triggered : Boolean;
    }

    part def AlarmSystem {
        attribute sirens : Boolean;
        attribute strobes : Boolean;
        attribute active : Boolean;
    }

    part def SecuritySystem {
        port networkPort : NetworkPort;
        port alarmPort : AlarmPort;
        part cameras : Camera[0..*];
        part sensors : SecuritySensor[0..*];
        part alarmSystem : AlarmSystem;
        attribute active : Boolean;

        state machine SecurityBehavior {
            entry { LogMessage("Security System initialized"); }
            state Disarmed {
                transition to Armed on armCommand;
            }
            state Armed {
                entry { MonitorSensors(); }
                transition to Alert on intrusionDetected;
                transition to Disarmed on disarmCommand;
            }
            state Alert {
                entry { TriggerAlarm(); }
                do { NotifyHomeowners(); }
                transition to Armed on resetCommand;
                transition to Disarmed on disarmCommand;
            }
        }
    }

    part def TelephonySystem {
        port networkPort : NetworkPort;
        port telephonyPort : TelephonyPort;
        port intercomPort : IntercomPort;
        attribute voipEnabled : Boolean;
        attribute autoAttendant : Boolean;
        attribute voicemail : Boolean;
        attribute videoIntercom : Boolean;
        attribute voicemailMessages : VoicemailMessage[0..*];
        attribute currentCall : PhoneCall;

        state machine TelephonyBehavior {
            entry { LogMessage("Telephony System initialized"); }
            state Idle {
                transition to IncomingCall on callReceived;
                transition to IntercomActive on intercomCommand;
            }
            state IncomingCall {
                entry { HandleIncomingCall(currentCall); }
                transition to Voicemail on noAnswer;
                transition to Idle on callEnded;
            }
            state Voicemail {
                entry { RecordVoicemail(); }
                transition to Idle on recordingComplete;
            }
            state IntercomActive {
                entry { EstablishIntercom(); }
                transition to Idle on intercomEnded;
            }
        }
    }

    part def HomeNetwork {
        port corePort : NetworkPort;
        port directorPorts : NetworkPort[0..*];
        port lightingPort : NetworkPort;
        port climatePort : NetworkPort;
        port securityPort : NetworkPort;
        port telephonyPort : NetworkPort;

        state machine NetworkBehavior {
            entry { LogMessage("Home Network initialized"); }
            state Active {
                do { RouteTraffic(); }
            }
        }
    }

    part def LinuxMCESystem {
        attribute scenarios : String[0..*] = ["Good Morning", "Movie Night", "Welcome Home"];

        part coreServer : CoreServer {
            attribute managesAllSubsystems = true;
            attribute deviceDiscoveryEnabled = true;
            attribute mediaIndexingEnabled = true;
            attribute currentScenario = "";
            attribute mediaLibrary = [
                MediaItem { title = "Inception"; mediaType = "Movie"; filePath = "/media/movies/inception.mkv"; indexed = true; },
                MediaItem { title = "The Dark Knight"; mediaType = "Movie"; filePath = "/media/movies/dark_knight.mkv"; indexed = true; },
                MediaItem { title = "Morning Jazz"; mediaType = "Music"; filePath = "/media/music/morning_jazz.mp3"; indexed = true; },
                MediaItem { title = "Family Vacation"; mediaType = "Photo"; filePath = "/media/photos/vacation.jpg"; indexed = true; }
            ];
            attribute deviceRegistry = [
                DeviceDescriptor { deviceId = "MD-LR-001"; deviceType = "MediaDirector"; location = "Living Room"; protocol = "Ethernet"; },
                DeviceDescriptor { deviceId = "MD-BR-002"; deviceType = "MediaDirector"; location = "Bedroom"; protocol = "Ethernet"; },
                DeviceDescriptor { deviceId = "MD-HT-003"; deviceType = "MediaDirector"; location = "Home Theater"; protocol = "Ethernet"; },
                DeviceDescriptor { deviceId = "LC-001"; deviceType = "LightingController"; location = "Utility Closet"; protocol = "Z-Wave"; },
                DeviceDescriptor { deviceId = "CC-001"; deviceType = "ClimateController"; location = "Utility Closet"; protocol = "Ethernet"; },
                DeviceDescriptor { deviceId = "SS-001"; deviceType = "SecuritySystem"; location = "Utility Closet"; protocol = "Ethernet"; },
                DeviceDescriptor { deviceId = "TS-001"; deviceType = "TelephonySystem"; location = "Utility Closet"; protocol = "Ethernet"; }
            ];
        }

        part livingRoomDirector : MediaDirector {
            attribute roomName = "Living Room";
            attribute screenSize = 55;
            attribute audioChannels = 2;
            attribute resolution = "4K";
            attribute supportsVideo = true;
            attribute supportsAudio = true;
            attribute supportsControlUI = true;
            attribute volume = 50;
            attribute currentMedia = "";
        }

        part bedroomDirector : MediaDirector {
            attribute roomName = "Bedroom";
            attribute screenSize = 32;
            attribute audioChannels = 2;
            attribute resolution = "1080p";
            attribute supportsVideo = true;
            attribute supportsAudio = true;
            attribute supportsControlUI = true;
            attribute volume = 30;
            attribute currentMedia = "";
        }

        part homeTheaterDirector : MediaDirector {
            attribute roomName = "Home Theater";
            attribute screenSize = 120;
            attribute audioChannels = 12;
            attribute resolution = "4K";
            attribute supportsVideo = true;
            attribute supportsAudio = true;
            attribute supportsControlUI = true;
            attribute volume = 75;
            attribute currentMedia = "";
        }

        part lightingController : LightingController {
            attribute lights = ["Living Room Main", "Living Room Accent", "Bedroom Main", "Bedroom Nightstand", "Home Theater Main", "Home Theater Sconce", "Kitchen Main", "Hallway"];
            attribute zones = ["Living Room", "Bedroom", "Home Theater", "Kitchen", "Hallway"];
            attribute scenes = ["Movie Night", "Welcome Home", "Good Morning", "All Off", "Dinner Time"];
            attribute brightness = 0;
            attribute currentScene = "";
        }

        part climateController : ClimateController {
            attribute targetTemperature = 22.0;
            attribute currentTemperature = 21.0;
            attribute currentHumidity = 45.0;
            attribute currentAirQuality = 50.0;
            attribute schedules = ["Morning Warmup", "Night Cooldown", "Away Mode"];
            attribute maintainsComfort = true;
            attribute currentSchedule = "";
        }

        part securitySystem : SecuritySystem {
            attribute active = true;
            part cameras : Camera[3] {
                part camera1 : Camera {
                    attribute cameraId = "CAM-001";
                    attribute location = "Front Door";
                    attribute motionDetection = true;
                    attribute nightVision = true;
                    attribute recording = false;
                }
                part camera2 : Camera {
                    attribute cameraId = "CAM-002";
                    attribute location = "Backyard";
                    attribute motionDetection = true;
                    attribute nightVision = true;
                    attribute recording = false;
                }
                part camera3 : Camera {
                    attribute cameraId = "CAM-003";
                    attribute location = "Garage";
                    attribute motionDetection = true;
                    attribute nightVision = false;
                    attribute recording = false;
                }
            }
            part sensors : SecuritySensor[4] {
                part frontDoorSensor : SecuritySensor {
                    attribute sensorId = "SEN-001";
                    attribute sensorType = "Door";
                    attribute location = "Front Door";
                    attribute triggered = false;
                }
                part backDoorSensor : SecuritySensor {
                    attribute sensorId = "SEN-002";
                    attribute sensorType = "Door";
                    attribute location = "Back Door";
                    attribute triggered = false;
                }
                part livingRoomWindowSensor : SecuritySensor {
                    attribute sensorId = "SEN-003";
                    attribute sensorType = "Window";
                    attribute location = "Living Room";
                    attribute triggered = false;
                }
                part hallwayMotionSensor : SecuritySensor {
                    attribute sensorId = "SEN-004";
                    attribute sensorType = "Motion";
                    attribute location = "Hallway";
                    attribute triggered = false;
                }
            }
            part alarmSystem : AlarmSystem {
                attribute sirens = true;
                attribute strobes = true;
                attribute active = false;
            }
        }

        part telephonySystem : TelephonySystem {
            attribute voipEnabled = true;
            attribute autoAttendant = true;
            attribute voicemail = true;
            attribute videoIntercom = true;
            attribute voicemailMessages = [];
            attribute currentCall = PhoneCall { callerId = ""; duration = 0; accepted = false; };
        }

        part homeNetwork : HomeNetwork;

        connection coreServer.networkPort to homeNetwork.corePort;
        connection livingRoomDirector.networkPort to homeNetwork.directorPorts[1];
        connection bedroomDirector.networkPort to homeNetwork.directorPorts[2];
        connection homeTheaterDirector.networkPort to homeNetwork.directorPorts[3];
        connection lightingController.networkPort to homeNetwork.lightingPort;
        connection climateController.networkPort to homeNetwork.climatePort;
        connection securitySystem.networkPort to homeNetwork.securityPort;
        connection telephonySystem.networkPort to homeNetwork.telephonyPort;

        connection coreServer.mediaStreamPort to livingRoomDirector.mediaStreamPort;
        connection coreServer.mediaStreamPort to bedroomDirector.mediaStreamPort;
        connection coreServer.mediaStreamPort to homeTheaterDirector.mediaStreamPort;

        connection climateController.sensorPort to coreServer.networkPort;
        connection securitySystem.alarmPort to coreServer.networkPort;
        connection telephonySystem.telephonyPort to coreServer.networkPort;
        connection telephonySystem.intercomPort to coreServer.networkPort;
        connection lightingController.zWavePort to coreServer.networkPort;

        connection livingRoomDirector.audioOut to bedroomDirector.networkPort;
        connection homeTheaterDirector.audioOut to livingRoomDirector.networkPort;

        action def ExecuteGoodMorning {
            doc "Slowly raise bedroom lights, adjust thermostat, start morning news stream on bedroom director.";
            first raiseBedroomLights;
            then adjustThermostat;
            then startNewsStream;
            action raiseBedroomLights {
                lightingController.currentScene = "Good Morning";
                lightingController.brightness = 30;
            }
            action adjustThermostat {
                climateController.targetTemperature = 22.0;
                climateController.currentSchedule = "Morning Warmup";
            }
            action startNewsStream {
                bedroomDirector.currentMedia = "Morning News Stream";
                bedroomDirector.volume = 25;
            }
        }

        action def ExecuteMovieNight {
            doc "Dim lights in home theater, lower projector screen, start movie stream.";
            first dimTheaterLights;
            then startMovieStream;
            action dimTheaterLights {
                lightingController.currentScene = "Movie Night";
                lightingController.brightness = 10;
            }
            action startMovieStream {
                homeTheaterDirector.currentMedia = "Selected Movie";
                homeTheaterDirector.volume = 75;
            }
        }

        action def ExecuteWelcomeHome {
            doc "Turn on entry lights, set comfortable temperature, play welcome music.";
            first turnOnEntryLights;
            then setComfortTemperature;
            then playWelcomeMusic;
            action turnOnEntryLights {
                lightingController.currentScene = "Welcome Home";
                lightingController.brightness = 80;
            }
            action setComfortTemperature {
                climateController.targetTemperature = 23.0;
            }
            action playWelcomeMusic {
                livingRoomDirector.currentMedia = "Welcome Playlist";
                livingRoomDirector.volume = 40;
            }
        }

        satisfy CentralControlRequirement by coreServer;
        satisfy MediaLibraryRequirement by coreServer;
        satisfy DeviceRegistryRequirement by coreServer;
        satisfy MediaDirectorRequirement by livingRoomDirector;
        satisfy MediaDirectorRequirement by bedroomDirector;
        satisfy MediaDirectorRequirement by homeTheaterDirector;
        satisfy HomeTheaterRequirement by homeTheaterDirector;
        satisfy LightingScenesRequirement by lightingController;
        satisfy ClimateControlRequirement by climateController;
        satisfy SecurityRequirement by securitySystem;
        satisfy TelephonyRequirement by telephonySystem;
        satisfy AutomationScenarioRequirement by LinuxMCESystem;
        satisfy DeviceDiscoveryRequirement by coreServer;
        satisfy MediaIndexingRequirement by coreServer;
    }
}
