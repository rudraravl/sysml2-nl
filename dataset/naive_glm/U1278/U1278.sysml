package Control4HomeAutomation {
    import ScalarValues::*;

    // ===== Units =====
    unit percent;
    unit degreesCelsius;
    unit watts;

    // ===== Value Types =====
    value type BrightnessPercent > Real {
        unit percent;
    }

    value type TemperatureValue > Real {
        unit degreesCelsius;
    }

    value type VolumeLevel > Real {
        unit percent;
    }

    value type PowerConsumption > Real {
        unit watts;
    }

    // ===== Enumerations =====
    enumeration def LightingStateType {
        off;
        on;
        dimmed;
    }

    enumeration def HVACModeType {
        heating;
        cooling;
        automatic;
        off;
    }

    enumeration def SecurityModeType {
        disarmed;
        armedHome;
        armedAway;
    }

    enumeration def AlertLevelType {
        none;
        warning;
        critical;
    }

    enumeration def AudioPlaybackStateType {
        stopped;
        playing;
        paused;
    }

    enumeration def SceneType {
        goodMorning;
        movieTime;
        away;
        welcome;
        home;
    }

    enumeration def DeviceHealthStatusType {
        online;
        offline;
        degraded;
    }

    // ===== Item Definitions =====
    item def LightingCommand {
        attribute targetZone : Integer;
        attribute state : LightingStateType;
        attribute brightness : BrightnessPercent;
    }

    item def ClimateCommand {
        attribute targetThermostat : Integer;
        attribute mode : HVACModeType;
        attribute setpoint : TemperatureValue;
    }

    item def SecurityCommand {
        attribute mode : SecurityModeType;
    }

    item def AudioCommand {
        attribute targetZone : Integer;
        attribute playbackState : AudioPlaybackStateType;
        attribute volume : VolumeLevel;
        attribute track : String;
    }

    item def SceneActivation {
        attribute scene : SceneType;
    }

    item def SensorReading {
        attribute temperature : TemperatureValue;
        attribute motionDetected : Boolean;
        attribute doorOpen : Boolean;
        attribute zoneId : Integer;
    }

    item def SecurityBreachAlert {
        attribute alertLevel : AlertLevelType;
        attribute zoneId : Integer;
        attribute timestamp : String;
    }

    item def DeviceHealthReport {
        attribute deviceId : String;
        attribute status : DeviceHealthStatusType;
        attribute lastSeenTimestamp : String;
    }

    item def UserCommand {
        attribute commandType : String;
        attribute targetSubsystem : String;
        attribute payload : String;
    }

    // ===== Port Definitions =====
    port def NetworkPort {
        in userCommands : UserCommand;
        out deviceHealthReports : DeviceHealthReport;
    }

    port def LightingControlPort {
        in commands : LightingCommand;
        out status : LightingStateType;
    }

    port def ClimateControlPort {
        in commands : ClimateCommand;
        out readings : SensorReading;
    }

    port def SecurityPort {
        in commands : SecurityCommand;
        out alerts : SecurityBreachAlert;
    }

    port def AudioControlPort {
        in commands : AudioCommand;
        out status : AudioPlaybackStateType;
    }

    port def ScenePort {
        in activation : SceneActivation;
    }

    // ===== Interface Definitions =====
    interface def NetworkInterface {
        end source : NetworkPort;
        end target : NetworkPort;
    }

    interface def LightingInterface {
        end controller : LightingControlPort;
        end zone : LightingControlPort;
    }

    interface def ClimateInterface {
        end controller : ClimateControlPort;
        end thermostat : ClimateControlPort;
    }

    interface def SecurityInterface {
        end controller : SecurityPort;
        end panel : SecurityPort;
    }

    interface def AudioInterface {
        end controller : AudioControlPort;
        end zone : AudioControlPort;
    }

    interface def SceneInterface {
        end controller : ScenePort;
        end manager : ScenePort;
    }

    // ===== Part Definitions =====

    part def MainController {
        attribute systemId : String;
        attribute firmwareVersion : String;
        attribute operationalStatus : DeviceHealthStatusType;

        port networkPort : NetworkPort;
        port lightingBus : LightingControlPort;
        port climateBus : ClimateControlPort;
        port securityBus : SecurityPort;
        port audioBus : AudioControlPort;
        port scenePort : ScenePort;

        state controllerStateMachine {
            initial;
            state initializing;
            state operational;
            state degraded;
            state maintenance;

            transition init
                from initial
                to initializing;

            transition init_complete
                from initializing
                to operational
                when operationalStatus == DeviceHealthStatusType::online;

            transition device_failure
                from operational
                to degraded
                when operationalStatus == DeviceHealthStatusType::degraded;

            transition recovery
                from degraded
                to operational
                when operationalStatus == DeviceHealthStatusType::online;

            transition enter_maintenance
                from operational
                to maintenance
                accept command : UserCommand
                    [command.commandType == "enterMaintenance"];

            transition exit_maintenance
                from maintenance
                to operational
                accept command : UserCommand
                    [command.commandType == "exitMaintenance"];
        }

        action processUserCommand {
            in command : UserCommand;
        }

        action routeLightingCommand {
            in command : LightingCommand;
        }

        action routeClimateCommand {
            in command : ClimateCommand;
        }

        action routeSecurityCommand {
            in command : SecurityCommand;
        }

        action routeAudioCommand {
            in command : AudioCommand;
        }

        action monitorDeviceHealth {
            out reports : DeviceHealthReport;
        }

        action handleSceneActivation {
            in activation : SceneActivation;
        }
    }

    part def LightingZoneController {
        attribute zoneId : Integer;
        attribute zoneName : String;
        attribute currentState : LightingStateType;
        attribute currentBrightness : BrightnessPercent;

        port controlPort : LightingControlPort;

        state lightingStateMachine {
            initial;
            state off;
            state on;
            state dimmed;

            transition init
                from initial
                to off;

            transition off_to_on
                from off
                to on
                accept command : LightingCommand
                    [command.state == LightingStateType::on];

            transition on_to_off
                from on
                to off
                accept command : LightingCommand
                    [command.state == LightingStateType::off];

            transition off_to_dimmed
                from off
                to dimmed
                accept command : LightingCommand
                    [command.state == LightingStateType::dimmed];

            transition on_to_dimmed
                from on
                to dimmed
                accept command : LightingCommand
                    [command.state == LightingStateType::dimmed];

            transition dimmed_to_on
                from dimmed
                to on
                accept command : LightingCommand
                    [command.state == LightingStateType::on];

            transition dimmed_to_off
                from dimmed
                to off
                accept command : LightingCommand
                    [command.state == LightingStateType::off];
        }

        action setBrightness {
            in level : BrightnessPercent;
        }

        action togglePower {
        }

        action reportStatus {
            out status : LightingStateType;
        }
    }

    part def SmartThermostat {
        attribute thermostatId : Integer;
        attribute location : String;
        attribute currentMode : HVACModeType;
        attribute currentSetpoint : TemperatureValue;
        attribute currentTemperature : TemperatureValue;

        port controlPort : ClimateControlPort;

        state thermostatStateMachine {
            initial;
            state idle;
            state heating;
            state cooling;
            state automatic;

            transition init
                from initial
                to idle;

            transition idle_to_heating
                from idle
                to heating
                accept command : ClimateCommand
                    [command.mode == HVACModeType::heating];

            transition idle_to_cooling
                from idle
                to cooling
                accept command : ClimateCommand
                    [command.mode == HVACModeType::cooling];

            transition idle_to_automatic
                from idle
                to automatic
                accept command : ClimateCommand
                    [command.mode == HVACModeType::automatic];

            transition heating_to_idle
                from heating
                to idle
                accept command : ClimateCommand
                    [command.mode == HVACModeType::off];

            transition cooling_to_idle
                from cooling
                to idle
                accept command : ClimateCommand
                    [command.mode == HVACModeType::off];

            transition automatic_to_idle
                from automatic
                to idle
                accept command : ClimateCommand
                    [command.mode == HVACModeType::off];

            transition auto_to_heating
                from automatic
                to heating
                when currentTemperature < currentSetpoint;

            transition auto_to_cooling
                from automatic
                to cooling
                when currentTemperature > currentSetpoint;

            transition auto_heating_back
                from heating
                to automatic
                when currentTemperature >= currentSetpoint;

            transition auto_cooling_back
                from cooling
                to automatic
                when currentTemperature <= currentSetpoint;
        }

        action regulateTemperature {
            in setpoint : TemperatureValue;
        }

        action readSensors {
            out reading : SensorReading;
        }

        action setMode {
            in mode : HVACModeType;
        }
    }

    part def SecurityPanel {
        attribute panelId : String;
        attribute currentMode : SecurityModeType;
        attribute alarmActive : Boolean;
        attribute monitoringAllSensors : Boolean;

        port securityPort : SecurityPort;

        state securityStateMachine {
            initial;
            state disarmed;
            state armedHome;
            state armedAway;
            state alarmTriggered;
            state notifyingAuthorities;

            transition init
                from initial
                to disarmed;

            transition disarm_to_armedHome
                from disarmed
                to armedHome
                accept command : SecurityCommand
                    [command.mode == SecurityModeType::armedHome];

            transition disarm_to_armedAway
                from disarmed
                to armedAway
                accept command : SecurityCommand
                    [command.mode == SecurityModeType::armedAway];

            transition armedHome_to_disarm
                from armedHome
                to disarmed
                accept command : SecurityCommand
                    [command.mode == SecurityModeType::disarmed];

            transition armedAway_to_disarm
                from armedAway
                to disarmed
                accept command : SecurityCommand
                    [command.mode == SecurityModeType::disarmed];

            transition armedHome_breach
                from armedHome
                to alarmTriggered
                accept alert : SecurityBreachAlert
                    [alert.alertLevel == AlertLevelType::critical];

            transition armedAway_breach
                from armedAway
                to alarmTriggered
                accept alert : SecurityBreachAlert
                    [alert.alertLevel == AlertLevelType::critical];

            transition trigger_notification
                from alarmTriggered
                to notifyingAuthorities;

            transition notification_complete
                from notifyingAuthorities
                to alarmTriggered
                when alarmActive == true;

            transition alarm_disarm
                from alarmTriggered
                to disarmed
                accept command : SecurityCommand
                    [command.mode == SecurityModeType::disarmed];
        }

        action triggerAlarm {
            out alert : SecurityBreachAlert;
        }

        action notifyAuthorities {
            in alert : SecurityBreachAlert;
        }

        action monitorSensors {
            out alerts : SecurityBreachAlert;
        }

        action armSystem {
            in mode : SecurityModeType;
        }
    }

    part def AudioZoneController {
        attribute zoneId : Integer;
        attribute zoneName : String;
        attribute currentPlaybackState : AudioPlaybackStateType;
        attribute currentVolume : VolumeLevel;
        attribute currentTrack : String;

        port controlPort : AudioControlPort;

        state audioStateMachine {
            initial;
            state stopped;
            state playing;
            state paused;

            transition init
                from initial
                to stopped;

            transition stopped_to_playing
                from stopped
                to playing
                accept command : AudioCommand
                    [command.playbackState == AudioPlaybackStateType::playing];

            transition playing_to_paused
                from playing
                to paused
                accept command : AudioCommand
                    [command.playbackState == AudioPlaybackStateType::paused];

            transition playing_to_stopped
                from playing
                to stopped
                accept command : AudioCommand
                    [command.playbackState == AudioPlaybackStateType::stopped];

            transition paused_to_playing
                from paused
                to playing
                accept command : AudioCommand
                    [command.playbackState == AudioPlaybackStateType::playing];

            transition paused_to_stopped
                from paused
                to stopped
                accept command : AudioCommand
                    [command.playbackState == AudioPlaybackStateType::stopped];
        }

        action setVolume {
            in level : VolumeLevel;
        }

        action selectTrack {
            in track : String;
        }

        action controlPlayback {
            in state : AudioPlaybackStateType;
        }
    }

    part def Touchscreen {
        attribute touchscreenId : Integer;
        attribute location : String;
        attribute active : Boolean;

        port networkPort : NetworkPort;

        action displaySystemStatus {
            in healthReports : DeviceHealthReport;
        }

        action receiveUserInput {
            out command : UserCommand;
        }

        action activateScene {
            out activation : SceneActivation;
        }

        action displayLightingStatus {
            in zoneStatus : LightingStateType;
        }

        action displayClimateStatus {
            in temperature : TemperatureValue;
            in mode : HVACModeType;
        }

        action displaySecurityStatus {
            in mode : SecurityModeType;
            in alarmActive : Boolean;
        }

        action displayAudioStatus {
            in playbackState : AudioPlaybackStateType;
            in volume : VolumeLevel;
        }
    }

    part def SceneManager {
        attribute definedScenes : SceneType;

        port scenePort : ScenePort;

        action executeGoodMorning {
            doc /* Raise lights gradually to 60 percent, set thermostats to 21 degrees Celsius, play soft music at 30 percent volume, disarm security if armed home. */
        }

        action executeMovieTime {
            doc /* Dim lights to 10 percent, lower temperature to 19 degrees Celsius, stop audio in non-theater zones, set theater zone to playing. */
        }

        action executeAway {
            doc /* Turn off all lights, set thermostats to 16 degrees Celsius, arm security to armed away, stop all audio. */
        }

        action executeWelcome {
            doc /* Turn on entry lights to 80 percent, set temperature to 22 degrees Celsius, play welcome music at 25 percent volume. */
        }

        action executeHome {
            doc /* Turn on main lights to 70 percent, set temperature to 21 degrees Celsius, disarm security. */
        }

        action dispatchScene {
            in scene : SceneType;
        }
    }

    // ===== Subsystem Definitions =====

    part def LightingSubsystem {
        attribute subsystemName : String = "LightingControl";

        port bus : LightingControlPort;

        part zone1 : LightingZoneController {
            zoneId = 1;
            zoneName = "Living Room";
        }
        part zone2 : LightingZoneController {
            zoneId = 2;
            zoneName = "Kitchen";
        }
        part zone3 : LightingZoneController {
            zoneId = 3;
            zoneName = "Master Bedroom";
        }
        part zone4 : LightingZoneController {
            zoneId = 4;
            zoneName = "Guest Bedroom";
        }
        part zone5 : LightingZoneController {
            zoneId = 5;
            zoneName = "Dining Room";
        }
        part zone6 : LightingZoneController {
            zoneId = 6;
            zoneName = "Hallway";
        }
        part zone7 : LightingZoneController {
            zoneId = 7;
            zoneName = "Bathroom";
        }
        part zone8 : LightingZoneController {
            zoneId = 8;
            zoneName = "Garage";
        }
    }

    part def ClimateSubsystem {
        attribute subsystemName : String = "ClimateControl";

        port bus : ClimateControlPort;

        part thermostat1 : SmartThermostat {
            thermostatId = 1;
            location = "Main Floor";
        }
        part thermostat2 : SmartThermostat {
            thermostatId = 2;
            location = "Upper Floor";
        }
        part thermostat3 : SmartThermostat {
            thermostatId = 3;
            location = "Basement";
        }
    }

    part def SecuritySubsystem {
        attribute subsystemName : String = "SecuritySystem";

        port bus : SecurityPort;

        part panel : SecurityPanel {
            panelId = "SEC-001";
        }
    }

    part def AudioSubsystem {
        attribute subsystemName : String = "MultiZoneAudio";

        port bus : AudioControlPort;

        part audioZone1 : AudioZoneController {
            zoneId = 1;
            zoneName = "Living Room";
        }
        part audioZone2 : AudioZoneController {
            zoneId = 2;
            zoneName = "Kitchen";
        }
        part audioZone3 : AudioZoneController {
            zoneId = 3;
            zoneName = "Master Bedroom";
        }
        part audioZone4 : AudioZoneController {
            zoneId = 4;
            zoneName = "Dining Room";
        }
        part audioZone5 : AudioZoneController {
            zoneId = 5;
            zoneName = "Patio";
        }
        part audioZone6 : AudioZoneController {
            zoneId = 6;
            zoneName = "Garage";
        }
    }

    // ===== Requirements =====

    requirement def CentralizedControlRequirement {
        doc /* The system shall provide centralized control of lighting, climate, security, and audio subsystems through a main controller that acts as the central brain. */
        subject system : HomeAutomationSystem;
    }

    requirement def LightingZonesRequirement {
        doc /* The system shall support eight independent lighting zones, each managed by a dedicated controller capable of turning lights on, off, or dimming to a specified brightness level. */
        subject lighting : LightingSubsystem;
    }

    requirement def ClimateControlRequirement {
        doc /* The system shall include three smart thermostats that monitor and regulate temperature, operating the HVAC system in heating, cooling, or automatic modes to maintain a user-defined setpoint. */
        subject climate : ClimateSubsystem;
    }

    requirement def SecurityModesRequirement {
        doc /* The security system shall support disarmed, armed home, and armed away modes. Upon detecting a breach, the system shall automatically trigger an alarm and notify the authorities. */
        subject security : SecuritySubsystem;
    }

    requirement def MultiZoneAudioRequirement {
        doc /* The system shall provide independent audio control for six zones, supporting play, pause, stop, and volume adjustment in each zone separately. */
        subject audio : AudioSubsystem;
    }

    requirement def TouchscreenInterfaceRequirement {
        doc /* The system shall provide three dedicated touchscreens placed throughout the house for user interaction, supporting individual device control and scene activation. */
        subject touchscreens : Touchscreen;
    }

    requirement def SceneActivationRequirement {
        doc /* The system shall support pre-programmed scenes including GoodMorning, MovieTime, and Away that execute coordinated commands across multiple subsystems simultaneously. */
        subject sceneManager : SceneManager;
    }

    requirement def ContinuousOperationRequirement {
        doc /* The system shall operate continuously, monitoring the health of connected devices, automatically regulating climate, and responding to user commands. */
        subject system : HomeAutomationSystem;
    }

    requirement def NetworkCommunicationRequirement {
        doc /* The main controller shall communicate with all subsystems over a local network. */
        subject controller : MainController;
    }

    // ===== Top-Level System Definition =====

    part def HomeAutomationSystem {
        attribute systemName : String = "Control4HomeAutomation";
        attribute systemVersion : String = "4.0";

        part mainController : MainController {
            systemId = "HC-8000";
            firmwareVersion = "3.2.1";
            operationalStatus = DeviceHealthStatusType::online;
        }

        part lighting : LightingSubsystem;
        part climate : ClimateSubsystem;
        part security : SecuritySubsystem;
        part audio : AudioSubsystem;
        part sceneManager : SceneManager;

        part touchscreen1 : Touchscreen {
            touchscreenId = 1;
            location = "Main Hallway";
            active = true;
        }

        part touchscreen2 : Touchscreen {
            touchscreenId = 2;
            location = "Master Bedroom";
            active = true;
        }

        part touchscreen3 : Touchscreen {
            touchscreenId = 3;
            location = "Kitchen";
            active = true;
        }

        connection : NetworkInterface
            connect touchscreen1.networkPort to mainController.networkPort;
        connection : NetworkInterface
            connect touchscreen2.networkPort to mainController.networkPort;
        connection : NetworkInterface
            connect touchscreen3.networkPort to mainController.networkPort;

        connection : LightingInterface
            connect mainController.lightingBus to lighting.bus;
        connection : ClimateInterface
            connect mainController.climateBus to climate.bus;
        connection : SecurityInterface
            connect mainController.securityBus to security.bus;
        connection : AudioInterface
            connect mainController.audioBus to audio.bus;

        connection : SceneInterface
            connect mainController.scenePort to sceneManager.scenePort;

        satisfaction CentralizedControlRequirement by mainController;
        satisfaction LightingZonesRequirement by lighting;
        satisfaction ClimateControlRequirement by climate;
        satisfaction SecurityModesRequirement by security;
        satisfaction MultiZoneAudioRequirement by audio;
        satisfaction TouchscreenInterfaceRequirement by touchscreen1;
        satisfaction SceneActivationRequirement by sceneManager;
        satisfaction ContinuousOperationRequirement by mainController;
        satisfaction NetworkCommunicationRequirement by mainController;
    }

    // ===== Top-Level Usage =====
    part homeAutomationSystem : HomeAutomationSystem;
}
