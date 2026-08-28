package LinuxMCEHomeAutomation {
    private import ScalarValues::*;
    private import ISQ::*;

    package Types {
        private import ScalarValues::*;

        attribute def Temperature :> ScalarValues::Real;
        attribute def Humidity :> ScalarValues::Real;
        attribute def Luminance :> ScalarValues::Real;
        attribute def SoundLevel :> ScalarValues::Real;
        attribute def Power :> ScalarValues::Real;
        attribute def ScreenSize :> ScalarValues::Real;
        attribute def FlashRate :> ScalarValues::Real;
        attribute def Latency :> ScalarValues::Real;
        attribute def Uptime :> ScalarValues::Real;
        attribute def Time :> ScalarValues::Real;

        enum def MediaType {
            movie;
            music;
            photo;
        }
        enum def HVACMode {
            off;
            heat;
            cool;
            auto;
        }
        enum def SensorType {
            door;
            window;
            motion;
        }
        enum def ProtocolType {
            ZWave;
            WiFi;
            Ethernet;
        }

        item def MediaItem {
            attribute title : String;
            attribute type : MediaType;
            attribute filePath : String;
            attribute duration : Time;
        }
        item def Device {
            attribute id : String;
            attribute name : String;
            attribute type : String;
        }
        item def Light {
            attribute id : String;
            attribute zone : String;
            attribute status : Boolean;
            attribute level : Real;
        }
        item def LightSetting {
            attribute light : Light;
            attribute level : Real;
        }
        item def Scene {
            attribute name : String;
            attribute lightSettings : LightSetting[*];
        }
        item def VoicemailMessage {
            attribute caller : String;
            attribute timestamp : Time;
            attribute audioPath : String;
        }
        item def ControlCommand {
            attribute target : String;
            attribute actionName : String;
            attribute parameters : String;
        }
        item def SensorReading {
            attribute temperature : Temperature;
            attribute humidity : Humidity;
            attribute airQuality : Real;
        }
        item def MediaStreamData {
            attribute format : String;
            attribute bitrate : Real;
            attribute payload : String;
        }
        item def VoIPPacket {
            attribute codec : String;
            attribute payload : String;
        }
    }

    package Interfaces {
        private import Types::*;

        port def NetworkPort;
        port def ZWavePort {
            in item cmd : ControlCommand;
            out item status : ControlCommand;
        }
        port def MediaStreamPort {
            in item stream : MediaStreamData;
            out item stream : MediaStreamData;
        }
        port def ControlPort {
            in item cmd : ControlCommand;
            out item status : ControlCommand;
        }
        port def SensorPort {
            out item reading : SensorReading;
        }
        port def AlarmPort {
            out item alarm : Boolean;
        }
        port def VoIPPort {
            in item packet : VoIPPacket;
            out item packet : VoIPPacket;
        }
        port def VideoIntercomPort {
            in item video : String;
            out item video : String;
        }
    }

    package Components {
        private import Types::*;
        private import Interfaces::*;

        part def MediaLibrary {
            attribute mediaItems : MediaItem[*];
            action indexMedia {
                in item newMedia : MediaItem;
                out item indexedLibrary : MediaItem[*];
                first start;
                then action parseMetadata;
                then action generateThumbnails;
                then action updateDatabase;
                then done;
            }
        }

        part def DeviceRegistry {
            attribute devices : Device[*];
            action discoverDevices {
                out item discoveredDevices : Device[*];
                first start;
                then action scanNetwork;
                then action registerDevices;
                then done;
            }
        }

        part def AutomationOrchestrator {
            action executeScenario {
                in item scenarioName : String;
                out item commands : ControlCommand[*];
            }
        }

        part def MediaStreamer {
            port streamOut : MediaStreamPort;
            action streamMedia {
                in item media : MediaItem;
                out item stream : MediaStreamData;
            }
        }

        part def CoreServer {
            part mediaLibrary : MediaLibrary;
            part deviceRegistry : DeviceRegistry;
            part orchestrator : AutomationOrchestrator;
            part mediaStreamer : MediaStreamer;
            port network : NetworkPort;
            port mediaOut : MediaStreamPort;
            port controlOut : ControlPort;
            port sensorIn : SensorPort;
            port telephony : VoIPPort;

            connect mediaStreamer.streamOut to mediaOut;
        }

        part def Display {
            attribute size : ScreenSize;
            attribute resolution : String;
        }

        part def AudioSubsystem {
            attribute channels : Integer;
            attribute power : Power;
        }

        part def ControlInterface {
            port control : ControlPort;
        }

        part def MediaDirector {
            part display : Display;
            part audio : AudioSubsystem;
            part controlInterface : ControlInterface;
            port mediaIn : MediaStreamPort;
            port control : ControlPort;
            port network : NetworkPort;
            port intercom : VideoIntercomPort;
            attribute room : String;

            state def DirectorState {
                state off {
                    transition to standby on powerOn;
                }
                state standby {
                    transition to playing on playCommand;
                    transition to off on powerOff;
                }
                state playing {
                    transition to standby on stopCommand;
                }
            }
        }

        part def ZWaveInterface {
            port zwave : ZWavePort;
            attribute protocol : ProtocolType = ProtocolType::ZWave;
        }

        part def LightGroup {
            attribute lights : Light[*];
            attribute level : Real;
        }

        part def LightingController {
            part zwaveInterface : ZWaveInterface;
            part lightGroups : LightGroup[*];
            part scenes : Scene[*];
            port network : NetworkPort;
            port control : ControlPort;

            action setScene {
                in item scene : Scene;
            }
            action dimLights {
                in item zone : String;
                in item level : Real;
            }
        }

        part def ClimateSensor {
            port sensorData : SensorPort;
            attribute temp : Temperature;
            attribute humidity : Humidity;
            attribute airQuality : Real;
        }

        part def HVACUnit {
            attribute mode : HVACMode;
            attribute setpoint : Temperature;
            action heat;
            action cool;
        }

        part def ClimateController {
            part sensors : ClimateSensor[*];
            part hvac : HVACUnit;
            port network : NetworkPort;
            port control : ControlPort;
            port sensorIn : SensorPort;

            action runSchedule;
            action adjustSetpoint {
                in item temp : Temperature;
            }
        }

        part def Camera {
            attribute resolution : String;
            attribute nightVision : Boolean = true;
            attribute motionDetection : Boolean = true;
            port videoOut : MediaStreamPort;
            port network : NetworkPort;
        }

        part def SecuritySensor {
            attribute type : SensorType;
            attribute triggered : Boolean;
            port sensorOut : SensorPort;
        }

        part def Siren {
            attribute soundLevel : SoundLevel;
            port alarmIn : AlarmPort;
        }

        part def Strobe {
            attribute flashRate : FlashRate;
            port alarmIn : AlarmPort;
        }

        part def Alarm {
            part siren : Siren;
            part strobe : Strobe;
            action soundAlarm;
        }

        part def SecuritySystem {
            part cameras : Camera[*];
            part sensors : SecuritySensor[*];
            part alarm : Alarm;
            port network : NetworkPort;
            port control : ControlPort;
            port sensorIn : SensorPort;
            port alarmOut : AlarmPort;

            action arm;
            action disarm;
            action triggerAlarm;
        }

        part def VoIPService {
            attribute lines : Integer;
            action makeCall {
                in item number : String;
            }
        }

        part def AutoAttendant {
            action answerCall;
            action routeCall;
        }

        part def Voicemail {
            attribute messages : VoicemailMessage[*];
            action recordMessage;
        }

        part def VideoIntercom {
            part camera : Camera;
            part display : Display;
            action initiateCall {
                in item room : String;
            }
        }

        part def TelephonySystem {
            part voip : VoIPService;
            part autoAttendant : AutoAttendant;
            part voicemail : Voicemail;
            part videoIntercom : VideoIntercom;
            port network : NetworkPort;
            port control : ControlPort;
            port voipPort : VoIPPort;
            port intercomPort : VideoIntercomPort;
        }
    }

    package Behaviors {
        private import Types::*;
        private import Components::*;

        action def GoodMorningScenario {
            in item triggerTime : Time;
            action raiseLights {
                out item cmd : ControlCommand;
            }
            action adjustClimate {
                out item cmd : ControlCommand;
            }
            action playNews {
                out item stream : MediaStreamData;
            }
            first start;
            then raiseLights;
            then adjustClimate;
            then playNews;
            then done;
        }

        action def DeviceDiscoveryProcess {
            out item discoveredDevices : Device[*];
            first start;
            then action scanNetwork;
            then action registerDevices;
            then done;
        }

        action def MediaIndexingProcess {
            in item newMedia : MediaItem;
            out item indexedLibrary : MediaItem[*];
            first start;
            then action parseMetadata;
            then action generateThumbnails;
            then action updateDatabase;
            then done;
        }

        state def CoreServerState {
            state Idle {
                entry do nothing;
                transition to Discovering on discoveryTrigger;
            }
            state Discovering {
                entry do execute DeviceDiscoveryProcess;
                transition to Indexing on discoveryComplete;
            }
            state Indexing {
                entry do execute MediaIndexingProcess;
                transition to Orchestrating on indexingComplete;
            }
            state Orchestrating {
                entry do monitorSensors;
                transition to Idle on systemReset;
                transition to Error on faultDetected;
            }
            state Error {
                entry do logFault;
                transition to Idle on faultCleared;
            }
        }
    }

    package Requirements {
        private import Types::*;

        requirement def MediaStreamingReq {
            doc /* The system shall stream media from the core server to multiple media directors simultaneously. */
            attribute simultaneousStreams : Integer;
            require constraint { simultaneousStreams >= 3 }
        }
        requirement def AutomationResponseTimeReq {
            doc /* The system shall respond to automation triggers within 2 seconds. */
            attribute responseTime : Latency;
            attribute maxResponseTime : Latency = 2.0;
            require constraint { responseTime <= maxResponseTime }
        }
        requirement def TemperatureRegulationReq {
            doc /* The climate controller shall maintain temperature within 1 degree of setpoint. */
            attribute setpoint : Temperature;
            attribute actual : Temperature;
            attribute tolerance : Temperature = 1.0;
            require constraint { abs(actual - setpoint) <= tolerance }
        }
        requirement def SecurityNotificationReq {
            doc /* The security system shall notify homeowners within 10 seconds of an alarm trigger. */
            attribute notificationTime : Latency;
            attribute maxNotificationTime : Latency = 10.0;
            require constraint { notificationTime <= maxNotificationTime }
        }
        requirement def LightingSceneReq {
            doc /* The lighting controller shall support at least 10 pre-programmed scenes. */
            attribute sceneCount : Integer;
            attribute minSceneCount : Integer = 10;
            require constraint { sceneCount >= minSceneCount }
        }
        requirement def TelephonyVoicemailReq {
            doc /* The telephony system shall store at least 100 voicemail messages. */
            attribute voicemailCapacity : Integer;
            attribute minVoicemailCapacity : Integer = 100;
            require constraint { voicemailCapacity >= minVoicemailCapacity }
        }
        requirement def HomeTheaterSpecReq {
            doc /* The home theater director shall support a 120-inch display and 12-channel audio. */
            attribute minScreenSize : ScreenSize = 120.0;
            attribute minChannels : Integer = 12;
            require constraint { screenSize >= minScreenSize && audioChannels >= minChannels }
        }
        requirement def SystemUptimeReq {
            doc /* The system shall maintain 99.9 percent uptime annually. */
            attribute operationalTime : Uptime;
            attribute minUptime : Uptime = 31536000.0;
            require constraint { operationalTime >= minUptime }
        }
    }

    package SystemAssembly {
        private import Types::*;
        private import Interfaces::*;
        private import Components::*;
        private import Behaviors::*;
        private import Requirements::*;

        part def HomeNetwork {
            port coreIF : NetworkPort;
            port directorIF : NetworkPort;
            port lightingIF : NetworkPort;
            port climateIF : NetworkPort;
            port securityIF : NetworkPort;
            port telephonyIF : NetworkPort;
        }

        part smartHome {
            part core : CoreServer {
                state coreState : CoreServerState;
            }
            part homeNet : HomeNetwork;

            part livingRoomDirector : MediaDirector {
                attribute room = "Living Room";
                part display : Display {
                    attribute size = 55.0;
                    attribute resolution = "4K";
                }
                part audio : AudioSubsystem {
                    attribute channels = 5;
                    attribute power = 100.0;
                }
            }
            part bedroomDirector : MediaDirector {
                attribute room = "Bedroom";
                part display : Display {
                    attribute size = 42.0;
                    attribute resolution = "1080p";
                }
                part audio : AudioSubsystem {
                    attribute channels = 2;
                    attribute power = 20.0;
                }
            }
            part homeTheaterDirector : MediaDirector {
                attribute room = "Home Theater";
                part display : Display {
                    attribute size = 120.0;
                    attribute resolution = "4K";
                }
                part audio : AudioSubsystem {
                    attribute channels = 12;
                    attribute power = 500.0;
                }
            }

            part lightingCtrl : LightingController {
                part lightGroups : LightGroup[3];
                part scenes : Scene[10];
            }
            part climateCtrl : ClimateController {
                part sensors : ClimateSensor[5];
                part hvac : HVACUnit {
                    attribute mode = HVACMode::auto;
                    attribute setpoint = 22.0;
                }
            }
            part securitySys : SecuritySystem {
                part cameras : Camera[4] {
                    attribute resolution = "1080p";
                }
                part sensors : SecuritySensor[10];
                part alarm : Alarm {
                    part siren : Siren {
                        attribute soundLevel = 110.0;
                    }
                    part strobe : Strobe {
                        attribute flashRate = 2.0;
                    }
                }
            }
            part telephonySys : TelephonySystem {
                part voip : VoIPService {
                    attribute lines = 4;
                }
                part voicemail : Voicemail {
                    attribute messages : VoicemailMessage[100];
                }
                part videoIntercom : VideoIntercom {
                    part camera : Camera {
                        attribute resolution = "720p";
                    }
                    part display : Display {
                        attribute size = 7.0;
                    }
                }
            }

            connect core.network to homeNet.coreIF;
            connect livingRoomDirector.network to homeNet.directorIF;
            connect bedroomDirector.network to homeNet.directorIF;
            connect homeTheaterDirector.network to homeNet.directorIF;
            connect lightingCtrl.network to homeNet.lightingIF;
            connect climateCtrl.network to homeNet.climateIF;
            connect securitySys.network to homeNet.securityIF;
            connect telephonySys.network to homeNet.telephonyIF;

            flow core.mediaOut.stream to livingRoomDirector.mediaIn.stream;
            flow core.mediaOut.stream to bedroomDirector.mediaIn.stream;
            flow core.mediaOut.stream to homeTheaterDirector.mediaIn.stream;

            flow core.controlOut.cmd to lightingCtrl.control.cmd;
            flow core.controlOut.cmd to climateCtrl.control.cmd;
            flow core.controlOut.cmd to securitySys.control.cmd;
            flow core.controlOut.cmd to telephonySys.control.cmd;

            flow climateCtrl.sensorIn.reading to core.sensorIn.reading;
            flow securitySys.sensorIn.reading to core.sensorIn.reading;

            flow telephonySys.voipPort.packet to core.telephony.packet;
            flow core.telephony.packet to telephonySys.voipPort.packet;

            connect bedroomDirector.intercom to telephonySys.intercomPort;
            connect livingRoomDirector.intercom to telephonySys.intercomPort;

            satisfy MediaStreamingReq by core;
            satisfy AutomationResponseTimeReq by core;
            satisfy TemperatureRegulationReq by climateCtrl;
            satisfy SecurityNotificationReq by securitySys;
            satisfy LightingSceneReq by lightingCtrl;
            satisfy TelephonyVoicemailReq by telephonySys;
            satisfy HomeTheaterSpecReq by homeTheaterDirector;
            satisfy SystemUptimeReq by smartHome;

            action goodMorningExec : GoodMorningScenario {
                bind raiseLights.cmd.target = "bedroom_lights";
                bind raiseLights.cmd.actionName = "dim_up";
                bind adjustClimate.cmd.target = "bedroom_climate";
                bind adjustClimate.cmd.actionName = "set_temp";
                bind playNews.stream.format = "video";
                bind playNews.stream.bitrate = 128.0;
            }
        }
    }
}
