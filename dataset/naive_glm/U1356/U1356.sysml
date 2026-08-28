package HueLightingSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    def PowerLevel :> Real { unit "percent"; }
    def ColorTemperature :> Integer { unit "K"; }
    def HueValue :> Integer { doc { "Hue angle in degrees, 0-359." } unit "deg"; }
    def SaturationValue :> Real { unit "percent"; }
    def BulbId :> Integer;
    def SceneId :> String;
    def CommandId :> Integer;

    // ===== Item Definitions =====
    item def LightCommand {
        attribute commandId : CommandId;
        attribute bulbId : BulbId;
        attribute powerOn : Boolean;
        attribute brightness : PowerLevel;
        attribute hue : HueValue;
        attribute saturation : SaturationValue;
        attribute colorTemp : ColorTemperature;
    }

    item def SceneCommand {
        attribute sceneId : SceneId;
        attribute bulbCommands : LightCommand[0..50];
    }

    item def BulbStatus {
        attribute bulbId : BulbId;
        attribute isOn : Boolean;
        attribute currentBrightness : PowerLevel;
        attribute currentHue : HueValue;
        attribute currentSaturation : SaturationValue;
        attribute currentColorTemp : ColorTemperature;
    }

    item def EthernetFrame {
        attribute payload : String;
    }

    item def ZigbeePacket {
        attribute bulbId : BulbId;
        attribute payload : LightCommand;
    }

    // ===== Port Definitions =====
    port def EthernetPort {
        out attribute frames : EthernetFrame;
        in attribute incomingFrames : EthernetFrame;
    }

    port def ZigbeePort {
        out attribute packets : ZigbeePacket;
        in attribute incomingPackets : ZigbeePacket;
    }

    port def CloudAppPort {
        out attribute commands : LightCommand;
        in attribute statuses : BulbStatus;
    }

    port def AppUserPort {
        in attribute userCommands : LightCommand;
        out attribute uiStatus : BulbStatus;
    }

    // ===== RGBW LED Subsystem =====
    part def RGBWLedArray {
        attribute redIntensity : PowerLevel = 0;
        attribute greenIntensity : PowerLevel = 0;
        attribute blueIntensity : PowerLevel = 0;
        attribute whiteIntensity : PowerLevel = 0;

        action def SetColor {
            in hue : HueValue;
            in saturation : SaturationValue;
            in brightness : PowerLevel;
            in colorTemp : ColorTemperature;
        }

        perform action setOutput : SetColor;
    }

    // ===== LED Driver =====
    part def LedDriver {
        port def CommandInput {
            in attribute command : LightCommand;
        }
        port commandIn : CommandInput;

        action def TranslateCommand {
            in command : LightCommand;
            out red : PowerLevel;
            out green : PowerLevel;
            out blue : PowerLevel;
            out white : PowerLevel;
        }

        perform action translate : TranslateCommand;
    }

    // ===== Zigbee Radio =====
    part def ZigbeeRadio {
        port zigbee : ZigbeePort;

        state def RadioState {
            entry; exit;
            state Idle;
            state Receiving;
            state Transmitting;
            transition Idle -> Receiving when zigbee.incomingPackets->notEmpty();
            transition Receiving -> Idle;
            transition Idle -> Transmitting when zigbee.packets->notEmpty();
            transition Transmitting -> Idle;
        }

        exhibit state radioBehavior : RadioState;
    }

    // ===== Hue Smart Bulb =====
    part def HueSmartBulb {
        attribute bulbId : BulbId;
        attribute isOn : Boolean = false;
        attribute brightness : PowerLevel = 100;
        attribute hue : HueValue = 0;
        attribute saturation : SaturationValue = 0;
        attribute colorTemp : ColorTemperature = 2700;

        port zigbee : ZigbeePort;

        part ledArray : RGBWLedArray;
        part driver : LedDriver {
            connect driver.commandIn to ledArray.setOutput;
        }
        part radio : ZigbeeRadio {
            connect radio.zigbee to zigbee;
        }

        state def BulbState {
            entry; exit;
            state Off {
                entry { isOn = false; }
            }
            state On {
                entry { isOn = true; }
            }
            transition Off -> On when zigbee.incomingPackets->notEmpty() and zigbee.incomingPackets->any().payload.powerOn == true;
            transition On -> Off when zigbee.incomingPackets->notEmpty() and zigbee.incomingPackets->any().payload.powerOn == false;
            transition On -> On when zigbee.incomingPackets->notEmpty() {
                action updateSettings {
                    brightness = zigbee.incomingPackets->any().payload.brightness;
                    hue = zigbee.incomingPackets->any().payload.hue;
                    saturation = zigbee.incomingPackets->any().payload.saturation;
                    colorTemp = zigbee.incomingPackets->any().payload.colorTemp;
                }
            }
        }

        exhibit state bulbBehavior : BulbState;

        action def ProcessCommand {
            in cmd : LightCommand;
        }

        perform action process : ProcessCommand {
            in cmd = zigbee.incomingPackets->any().payload;
        }
    }

    // ===== Hue Bridge =====
    part def HueBridge {
        attribute maxBulbs : Integer = 50;
        attribute connectedBulbCount : Integer = 0;

        port ethernet : EthernetPort;
        port zigbee : ZigbeePort;

        part bulbRegistry {
            attribute registeredBulbs : BulbId[0..50];
        }

        action def RouteCommand {
            in cmd : LightCommand;
            out packet : ZigbeePacket;
        }

        action def CollectStatus {
            in packet : ZigbeePacket;
            out status : BulbStatus;
        }

        perform action route : RouteCommand;
        perform action collect : CollectStatus;

        state def BridgeState {
            entry; exit;
            state Listening;
            state Processing;
            state Forwarding;
            transition Listening -> Processing when ethernet.incomingFrames->notEmpty();
            transition Processing -> Forwarding;
            transition Forwarding -> Listening;
        }

        exhibit state bridgeBehavior : BridgeState;
    }

    // ===== Mobile Application =====
    part def MobileApplication {
        attribute userId : String;
        attribute savedScenes : SceneId[0..*];

        port userInterface : AppUserPort;
        port cloudLink : CloudAppPort;

        action def IssueCommand {
            in bulbId : BulbId;
            in powerOn : Boolean;
            in brightness : PowerLevel;
            in hue : HueValue;
            in saturation : SaturationValue;
            in colorTemp : ColorTemperature;
            out cmd : LightCommand;
        }

        action def ActivateScene {
            in sceneId : SceneId;
            out sceneCmd : SceneCommand;
        }

        action def DisplayStatus {
            in status : BulbStatus;
        }

        perform action issue : IssueCommand;
        perform action activate : ActivateScene;
        perform action display : DisplayStatus;
    }

    // ===== Cloud Service =====
    part def CloudService {
        attribute bridgeId : String;
        attribute authenticatedUsers : String[0..*];

        port appInterface : CloudAppPort {
            inverse of MobileApplication::cloudLink;
        }
        port bridgeInterface : EthernetPort;

        action def RelayCommand {
            in cmd : LightCommand;
            out frame : EthernetFrame;
        }

        action def SyncStatus {
            in frame : EthernetFrame;
            out status : BulbStatus;
        }

        perform action relay : RelayCommand;
        perform action sync : SyncStatus;

        state def CloudState {
            entry; exit;
            state Idle;
            state Relaying;
            state Syncing;
            transition Idle -> Relaying when appInterface.commands->notEmpty();
            transition Relaying -> Idle;
            transition Idle -> Syncing when bridgeInterface.incomingFrames->notEmpty();
            transition Syncing -> Idle;
        }

        exhibit state cloudBehavior : CloudState;
    }

    // ===== System Assembly =====
    part HueSystem {
        part mobileApp : MobileApplication;
        part cloud : CloudService;
        part bridge : HueBridge;
        part bulbs : HueSmartBulb[1..50];

        connect mobileApp.cloudLink to cloud.appInterface;
        connect cloud.bridgeInterface to bridge.ethernet;

        for bulb in bulbs {
            connect bridge.zigbee to bulb.zigbee;
        }
    }

    // ===== Requirements =====
    requirement def WirelessControlReq {
        doc { "The system shall allow users to wirelessly control power state, brightness, color, and color temperature of individual bulbs or groups." }
        attribute subject : HueSystem;
        attribute objective : Boolean = true;
    }

    requirement def BulbColorRangeReq {
        doc { "Each Hue Smart Bulb shall produce over 16 million colors using RGBW LED mixing." }
        attribute subject : HueSmartBulb;
        attribute minColors : Integer = 16777216;
        attribute objective : Boolean = true;
    }

    requirement def BridgeCapacityReq {
        doc { "The Hue Bridge shall coordinate a network of up to 50 connected bulbs." }
        attribute subject : HueBridge;
        attribute maxBulbs : Integer = 50;
        attribute objective : Boolean = true;
    }

    requirement def RemoteAccessReq {
        doc { "The Cloud Service shall relay commands from the mobile app to the Hue Bridge, enabling remote control from anywhere with internet." }
        attribute subject : CloudService;
        attribute objective : Boolean = true;
    }

    requirement def SceneSupportReq {
        doc { "The Mobile Application shall allow users to create and activate pre-saved lighting scenes for multiple bulbs." }
        attribute subject : MobileApplication;
        attribute objective : Boolean = true;
    }

    requirement def CommandLatencyReq {
        doc { "A bulb shall adjust its light output within 1 second of receiving a command." }
        attribute subject : HueSmartBulb;
        attribute maxLatency : Real = 1.0;
        attribute objective : Boolean = true;
    }

    requirement def StatusSyncReq {
        doc { "The Cloud Service shall synchronize bulb status so the mobile app reflects current light states." }
        attribute subject : CloudService;
        attribute objective : Boolean = true;
    }

    requirement systemRequirements {
        satisfy WirelessControlReq by HueSystem;
        satisfy BulbColorRangeReq by HueSystem.bulbs;
        satisfy BridgeCapacityReq by HueSystem.bridge;
        satisfy RemoteAccessReq by HueSystem.cloud;
        satisfy SceneSupportReq by HueSystem.mobileApp;
        satisfy CommandLatencyReq by HueSystem.bulbs;
        satisfy StatusSyncReq by HueSystem.cloud;
    }
}
