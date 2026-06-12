package PhilipsHueLightingSystem {

    import ScalarValues::*;
    import SI::*;

    attribute def Percent : Real {
        unit = "%";
    }

    attribute def Kelvin : Real {
        unit = "K";
    }

    attribute def Lumen : Real {
        unit = "lm";
    }

    attribute def Watt : Real {
        unit = "W";
    }

    attribute def Volt : Real {
        unit = "V";
    }

    attribute def Millisecond : Real {
        unit = "ms";
    }

    attribute def Meter : Real {
        unit = "m";
    }

    enum def LampPowerMode {
        enum off;
        enum standby;
        enum illuminated;
        enum updating;
        enum faulted;
    }

    enum def BridgeConnectivityState {
        enum disconnected;
        enum lanConnected;
        enum cloudConnected;
        enum pairing;
        enum faulted;
    }

    enum def CommandKind {
        enum turnOn;
        enum turnOff;
        enum setBrightness;
        enum setColorTemperature;
        enum setColor;
        enum recallScene;
        enum identifyLamp;
        enum firmwareUpdate;
    }

    enum def AlertKind {
        enum unavailableLamp;
        enum excessiveLatency;
        enum firmwareFailure;
        enum networkLost;
        enum overTemperature;
        enum unauthorizedCommand;
    }

    item def HueCommand {
        attribute commandId : String;
        attribute kind : CommandKind;
        attribute targetLampId : String;
        attribute requestedBrightness : Percent;
        attribute requestedColorTemperature : Kelvin;
        attribute requestedHue : Real;
        attribute requestedSaturation : Percent;
        attribute requestedTransitionTime : Millisecond;
    }

    item def HueStatus {
        attribute sourceId : String;
        attribute isReachable : Boolean;
        attribute powerMode : LampPowerMode;
        attribute currentBrightness : Percent;
        attribute currentColorTemperature : Kelvin;
        attribute currentHue : Real;
        attribute currentSaturation : Percent;
        attribute measuredPower : Watt;
        attribute lastCommandLatency : Millisecond;
    }

    item def SceneProfile {
        attribute sceneId : String;
        attribute displayName : String;
        attribute brightness : Percent;
        attribute colorTemperature : Kelvin;
        attribute hue : Real;
        attribute saturation : Percent;
        attribute transitionTime : Millisecond;
    }

    item def MobileAppRequest {
        attribute userId : String;
        attribute command : HueCommand;
        attribute authenticationToken : String;
    }

    item def CloudMessage {
        attribute bridgeId : String;
        attribute payload : MobileAppRequest;
        attribute encrypted : Boolean;
    }

    item def ZigbeeFrame {
        attribute sourceAddress : String;
        attribute destinationAddress : String;
        attribute payload : HueCommand;
        attribute linkQuality : Percent;
        attribute retryCount : Integer;
    }

    item def PowerInput {
        attribute voltage : Volt;
        attribute availablePower : Watt;
    }

    item def AlertNotification {
        attribute alertId : String;
        attribute kind : AlertKind;
        attribute sourceId : String;
        attribute message : String;
        attribute severity : Integer;
    }

    port def UserCommandPort {
        in request : MobileAppRequest;
        out status : HueStatus;
        out alert : AlertNotification;
    }

    port def CloudPort {
        in inboundMessage : CloudMessage;
        out outboundStatus : CloudMessage;
    }

    port def EthernetPort {
        in request : MobileAppRequest;
        out status : HueStatus;
    }

    port def ZigbeeCoordinatorPort {
        out frameOut : ZigbeeFrame;
        in frameIn : ZigbeeFrame;
        in lampStatus : HueStatus;
    }

    port def ZigbeeLampPort {
        in frameIn : ZigbeeFrame;
        out frameOut : ZigbeeFrame;
        out status : HueStatus;
    }

    port def PowerPort {
        in power : PowerInput;
    }

    port def LightEmissionPort {
        out brightness : Percent;
        out colorTemperature : Kelvin;
        out luminousFlux : Lumen;
        out hue : Real;
        out saturation : Percent;
    }

    action def AuthenticateUser {
        in request : MobileAppRequest;
        out authorized : Boolean;
    }

    action def TranslateRequestToBridgeCommand {
        in request : MobileAppRequest;
        out command : HueCommand;
    }

    action def RouteCommandToLamp {
        in command : HueCommand;
        in lampAddress : String;
        out frame : ZigbeeFrame;
    }

    action def ApplyLampCommand {
        in command : HueCommand;
        in currentBrightness : Percent;
        in currentColorTemperature : Kelvin;
        out newBrightness : Percent;
        out newColorTemperature : Kelvin;
        out newPowerMode : LampPowerMode;
    }

    action def ReportLampStatus {
        in lampId : String;
        in brightness : Percent;
        in colorTemperature : Kelvin;
        in powerMode : LampPowerMode;
        out status : HueStatus;
    }

    action def RecallScene {
        in profile : SceneProfile;
        out command : HueCommand;
    }

    state def BridgeStateMachine {
        entry; then disconnected;

        state disconnected;
        state lanConnected;
        state cloudConnected;
        state pairing;
        state faulted;

        transition first disconnected
            then lanConnected
            accept event PowerInput;

        transition lanConnected
            then cloudConnected
            accept event CloudMessage;

        transition cloudConnected
            then pairing
            accept event HueCommand
            if command.kind == CommandKind::identifyLamp;

        transition pairing
            then cloudConnected
            accept event HueStatus
            if status.isReachable == true;

        transition cloudConnected
            then faulted
            accept event AlertNotification
            if alert.kind == AlertKind::networkLost;

        transition faulted
            then lanConnected
            accept event PowerInput;
    }

    state def LampStateMachine {
        entry; then standby;

        state off;
        state standby;
        state illuminated;
        state updating;
        state faulted;

        transition standby
            then illuminated
            accept event HueCommand
            if command.kind == CommandKind::turnOn;

        transition illuminated
            then standby
            accept event HueCommand
            if command.kind == CommandKind::turnOff;

        transition illuminated
            then illuminated
            accept event HueCommand
            if command.kind == CommandKind::setBrightness or command.kind == CommandKind::setColorTemperature or command.kind == CommandKind::setColor;

        transition standby
            then updating
            accept event HueCommand
            if command.kind == CommandKind::firmwareUpdate;

        transition illuminated
            then updating
            accept event HueCommand
            if command.kind == CommandKind::firmwareUpdate;

        transition updating
            then standby
            accept event HueStatus
            if status.powerMode == LampPowerMode::standby;

        transition standby
            then faulted
            accept event AlertNotification
            if alert.kind == AlertKind::overTemperature;

        transition illuminated
            then faulted
            accept event AlertNotification
            if alert.kind == AlertKind::overTemperature;

        transition faulted
            then standby
            accept event PowerInput;
    }

    part def HueMobileApplication {
        attribute installedVersion : String;
        attribute authenticatedUserId : String;
        attribute commandLatencyBudget : Millisecond = 500.0 [ms];

        port userCommandPort : UserCommandPort;
        port cloudPort : CloudPort;

        perform action AuthenticateUser;
        perform action TranslateRequestToBridgeCommand;
    }

    part def HueCloudService {
        attribute serviceRegion : String;
        attribute encryptionRequired : Boolean = true;
        attribute maximumCloudRelayLatency : Millisecond = 300.0 [ms];

        port mobileCloudPort : CloudPort;
        port bridgeCloudPort : CloudPort;
    }

    part def HueBridge {
        attribute bridgeId : String;
        attribute maxPairedLamps : Integer = 50;
        attribute lanLatencyBudget : Millisecond = 100.0 [ms];
        attribute zigbeeLatencyBudget : Millisecond = 200.0 [ms];
        attribute connectivityState : BridgeConnectivityState;

        port ethernetPort : EthernetPort;
        port cloudPort : CloudPort;
        port zigbeePort : ZigbeeCoordinatorPort;
        port powerPort : PowerPort;

        state machine bridgeBehavior : BridgeStateMachine;

        perform action TranslateRequestToBridgeCommand;
        perform action RouteCommandToLamp;
    }

    part def HueSmartLamp {
        attribute lampId : String;
        attribute zigbeeAddress : String;
        attribute ratedPower : Watt = 9.5 [W];
        attribute standbyPower : Watt = 0.5 [W];
        attribute maximumLuminousFlux : Lumen = 806.0 [lm];
        attribute minimumColorTemperature : Kelvin = 2000.0 [K];
        attribute maximumColorTemperature : Kelvin = 6500.0 [K];
        attribute brightness : Percent;
        attribute colorTemperature : Kelvin;
        attribute hue : Real;
        attribute saturation : Percent;
        attribute powerMode : LampPowerMode;
        attribute installationDistanceFromBridge : Meter;

        port zigbeePort : ZigbeeLampPort;
        port powerPort : PowerPort;
        port lightPort : LightEmissionPort;

        state machine lampBehavior : LampStateMachine;

        perform action ApplyLampCommand;
        perform action ReportLampStatus;
    }

    part def Room {
        attribute roomId : String;
        attribute displayName : String;
        attribute desiredDefaultBrightness : Percent = 70.0 [%];
        attribute desiredDefaultColorTemperature : Kelvin = 2700.0 [K];

        part ceilingLamp : HueSmartLamp {
            attribute lampId = "lamp-ceiling-01";
            attribute zigbeeAddress = "0xA101";
            attribute installationDistanceFromBridge = 4.5 [m];
        }

        part deskLamp : HueSmartLamp {
            attribute lampId = "lamp-desk-01";
            attribute zigbeeAddress = "0xA102";
            attribute installationDistanceFromBridge = 6.0 [m];
        }
    }

    part def PhilipsHueBasedLightingSystem {
        attribute systemName : String = "Philips Hue Based Connected Lighting System";
        attribute primaryFunction : String = "Provide user-controlled, network-connected indoor lighting by translating authenticated app, cloud, or local commands into coordinated brightness and color output at smart lamps.";
        attribute maximumEndToEndCommandLatency : Millisecond = 800.0 [ms];
        attribute nominalMainsVoltage : Volt = 120.0 [V];

        part mobileApplication : HueMobileApplication {
            attribute installedVersion = "6.0";
        }

        part cloudService : HueCloudService {
            attribute serviceRegion = "North America";
        }

        part bridge : HueBridge {
            attribute bridgeId = "bridge-home-001";
        }

        part livingRoom : Room {
            attribute roomId = "room-living";
            attribute displayName = "Living Room";
        }

        part bedroom : Room {
            attribute roomId = "room-bedroom";
            attribute displayName = "Bedroom";
        }

        port userInterface : UserCommandPort;
        port mainsPower : PowerPort;

        connection userToApp
            connect userInterface to mobileApplication.userCommandPort;

        connection appToCloud
            connect mobileApplication.cloudPort to cloudService.mobileCloudPort;

        connection cloudToBridge
            connect cloudService.bridgeCloudPort to bridge.cloudPort;

        connection appToBridgeLocal
            connect mobileApplication.userCommandPort to bridge.ethernetPort;

        connection bridgeToLivingRoomCeiling
            connect bridge.zigbeePort to livingRoom.ceilingLamp.zigbeePort;

        connection bridgeToLivingRoomDesk
            connect bridge.zigbeePort to livingRoom.deskLamp.zigbeePort;

        connection bridgeToBedroomCeiling
            connect bridge.zigbeePort to bedroom.ceilingLamp.zigbeePort;

        connection bridgeToBedroomDesk
            connect bridge.zigbeePort to bedroom.deskLamp.zigbeePort;

        connection powerToBridge
            connect mainsPower to bridge.powerPort;

        connection powerToLivingRoomCeiling
            connect mainsPower to livingRoom.ceilingLamp.powerPort;

        connection powerToLivingRoomDesk
            connect mainsPower to livingRoom.deskLamp.powerPort;

        connection powerToBedroomCeiling
            connect mainsPower to bedroom.ceilingLamp.powerPort;

        connection powerToBedroomDesk
            connect mainsPower to bedroom.deskLamp.powerPort;

        item sceneRelax : SceneProfile {
            attribute sceneId = "scene-relax";
            attribute displayName = "Relax";
            attribute brightness = 45.0 [%];
            attribute colorTemperature = 2200.0 [K];
            attribute hue = 35.0;
            attribute saturation = 25.0 [%];
            attribute transitionTime = 750.0 [ms];
        }

        item sceneConcentrate : SceneProfile {
            attribute sceneId = "scene-concentrate";
            attribute displayName = "Concentrate";
            attribute brightness = 100.0 [%];
            attribute colorTemperature = 4300.0 [K];
            attribute hue = 0.0;
            attribute saturation = 0.0 [%];
            attribute transitionTime = 500.0 [ms];
        }

        item sceneNightlight : SceneProfile {
            attribute sceneId = "scene-nightlight";
            attribute displayName = "Nightlight";
            attribute brightness = 5.0 [%];
            attribute colorTemperature = 2000.0 [K];
            attribute hue = 25.0;
            attribute saturation = 40.0 [%];
            attribute transitionTime = 1000.0 [ms];
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : PhilipsHueBasedLightingSystem;

        doc /* The system shall provide connected indoor lighting as its primary function by accepting authenticated user commands and producing commanded light output from smart lamps. */

        require constraint {
            system.primaryFunction != ""
        }
    }

    requirement def CommandExecutionLatencyRequirement {
        subject system : PhilipsHueBasedLightingSystem;

        doc /* The system shall complete an accepted user lighting command within the maximum end-to-end latency budget during normal network operation. */

        require constraint {
            system.maximumEndToEndCommandLatency <= 800.0 [ms]
        }
    }

    requirement def BrightnessRangeRequirement {
        subject lamp : HueSmartLamp;

        doc /* Each smart lamp shall support dimming across the commanded brightness range from off-equivalent output to full rated output. */

        require constraint {
            lamp.brightness >= 0.0 [%] and lamp.brightness <= 100.0 [%]
        }
    }

    requirement def ColorTemperatureRequirement {
        subject lamp : HueSmartLamp;

        doc /* Each tunable white smart lamp shall constrain commanded color temperature to its supported operating range. */

        require constraint {
            lamp.colorTemperature >= lamp.minimumColorTemperature and lamp.colorTemperature <= lamp.maximumColorTemperature
        }
    }

    requirement def PowerRequirement {
        subject lamp : HueSmartLamp;

        doc /* Each smart lamp shall consume no more than rated power while illuminated and no more than standby power while not emitting commanded light. */

        require constraint {
            lamp.ratedPower <= 9.5 [W] and lamp.standbyPower <= 0.5 [W]
        }
    }

    requirement def PairingCapacityRequirement {
        subject bridge : HueBridge;

        doc /* The bridge shall maintain pairing information for up to fifty smart lamps. */

        require constraint {
            bridge.maxPairedLamps >= 50
        }
    }

    requirement def SecureRemoteAccessRequirement {
        subject cloud : HueCloudService;

        doc /* Remote access messages exchanged through the cloud service shall be encrypted before being relayed to the home bridge. */

        require constraint {
            cloud.encryptionRequired == true
        }
    }

    requirement def LampReachabilityRequirement {
        subject system : PhilipsHueBasedLightingSystem;

        doc /* The bridge shall report an alert when a target lamp cannot be reached over the lighting mesh network. */

        require constraint {
            system.bridge.connectivityState != BridgeConnectivityState::faulted
        }
    }

    satisfy PrimaryFunctionRequirement by PhilipsHueBasedLightingSystem;
    satisfy CommandExecutionLatencyRequirement by PhilipsHueBasedLightingSystem;
    satisfy BrightnessRangeRequirement by HueSmartLamp;
    satisfy ColorTemperatureRequirement by HueSmartLamp;
    satisfy PowerRequirement by HueSmartLamp;
    satisfy PairingCapacityRequirement by HueBridge;
    satisfy SecureRemoteAccessRequirement by HueCloudService;
    satisfy LampReachabilityRequirement by PhilipsHueBasedLightingSystem;
}