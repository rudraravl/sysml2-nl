package HueLightingSystem {
    private import ScalarValues::*;

    enum def PowerState {
        enum on;
        enum off;
    }

    attribute def Level :> Real;
    attribute def ColorTemp :> Real;

    item def RGBWColor {
        attribute red : Level = 0.0;
        attribute green : Level = 0.0;
        attribute blue : Level = 0.0;
        attribute white : Level = 0.0;
    }

    item def LightCommand {
        attribute powerState : PowerState;
        attribute brightness : Level = 0.0;
        attribute color : RGBWColor;
        attribute colorTemp : ColorTemp = 2700.0;
    }

    item def BulbStatus {
        attribute powerState : PowerState;
        attribute brightness : Level = 0.0;
        attribute color : RGBWColor;
        attribute colorTemp : ColorTemp = 2700.0;
    }

    item def Scene {
        attribute sceneName : String;
        attribute bulbCommands : LightCommand[*];
    }

    port def AppPort {
        out command : LightCommand;
        in status : BulbStatus;
    }

    port def CloudAppPort {
        in command : LightCommand;
        out status : BulbStatus;
    }

    port def CloudBridgePort {
        out command : LightCommand;
        in status : BulbStatus;
    }

    port def BridgeInternetPort {
        in command : LightCommand;
        out status : BulbStatus;
    }

    port def BridgeZigbeePort {
        out command : LightCommand;
        in status : BulbStatus;
    }

    port def BulbZigbeePort {
        in command : LightCommand;
        out status : BulbStatus;
    }

    interface def AppToCloudInterface {
        end app : AppPort;
        end cloud : CloudAppPort;
    }

    interface def CloudToBridgeInterface {
        end cloud : CloudBridgePort;
        end bridge : BridgeInternetPort;
    }

    interface def BridgeToBulbInterface {
        end bridge : BridgeZigbeePort;
        end bulb : BulbZigbeePort;
    }

    part def RGBWLEDArray {
        attribute redLevel : Level;
        attribute greenLevel : Level;
        attribute blueLevel : Level;
        attribute whiteLevel : Level;
    }

    part def ZigbeeRadio {
        attribute networkId : String;
        attribute channel : Integer;
    }

    part def BulbDriver {
        attribute outputCurrent : Level;
    }

    part def HueSmartBulb {
        attribute bulbId : String;
        attribute isOn : Boolean = false;
        attribute currentBrightness : Level = 0.0;
        attribute currentColor : RGBWColor;
        attribute currentColorTemp : ColorTemp = 2700.0;
        
        port zigbeePort : BulbZigbeePort;
        
        part ledArray : RGBWLEDArray;
        part radio : ZigbeeRadio;
        part driver : BulbDriver;

        state def BulbState {
            entry; then off;
            state off;
            state on;
            transition off_to_on first off accept command : LightCommand via zigbeePort if command.powerState == PowerState::on then on;
            transition on_to_off first on accept command : LightCommand via zigbeePort if command.powerState == PowerState::off then off;
            transition adjust_on first on accept command : LightCommand via zigbeePort then on;
        }

        exhibit state bulbState : BulbState;

        perform action updateLight {
            action trigger accept cmd : LightCommand via zigbeePort;
            then action updateStatus {
                out status : BulbStatus;
            }
            flow from updateStatus.status to zigbeePort.status;
        }
    }

    part def HueBridge {
        attribute bridgeId : String;
        attribute connectedBulbs : HueSmartBulb[0..50];
        
        port ethernetPort : BridgeInternetPort;
        port zigbeePort : BridgeZigbeePort;

        perform action relayCommand {
            action trigger accept cmd : LightCommand via ethernetPort;
            then send trigger.cmd via zigbeePort;
        }

        perform action collectStatus {
            action trigger accept stat : BulbStatus via zigbeePort;
            then send trigger.stat via ethernetPort;
        }
    }

    part def MobileApp {
        attribute appVersion : String;
        attribute savedScenes : Scene[*];
        
        port cloudPort : AppPort;

        perform action sendCommand {
            action generateCommand {
                out cmd : LightCommand;
            }
            flow from generateCommand.cmd to cloudPort.command;
        }

        perform action activateScene {
            action selectScene {
                out scene : Scene;
            }
            then action sendCommands {
                in scene = selectScene.scene;
                out commands : LightCommand[*] = scene.bulbCommands;
            }
        }

        perform action receiveStatus {
            action trigger accept stat : BulbStatus via cloudPort;
        }
    }

    part def CloudService {
        attribute serviceRegion : String;
        
        port appPort : CloudAppPort;
        port bridgePort : CloudBridgePort;

        perform action forwardCommand {
            action trigger accept cmd : LightCommand via appPort;
            then send trigger.cmd via bridgePort;
        }

        perform action syncStatus {
            action trigger accept stat : BulbStatus via bridgePort;
            then send trigger.stat via appPort;
        }
    }

    part def HueSystem {
        part mobileApp : MobileApp;
        part cloudService : CloudService;
        part hueBridge : HueBridge;
        part bulbs : HueSmartBulb[1..50];

        interface appToCloud : AppToCloudInterface connect mobileApp.cloudPort to cloudService.appPort {
            flow commandFlow of LightCommand from mobileApp.cloudPort.command to cloudService.appPort.command;
            flow statusFlow of BulbStatus from cloudService.appPort.status to mobileApp.cloudPort.status;
        }

        interface cloudToBridge : CloudToBridgeInterface connect cloudService.bridgePort to hueBridge.ethernetPort {
            flow commandFlow of LightCommand from cloudService.bridgePort.command to hueBridge.ethernetPort.command;
            flow statusFlow of BulbStatus from hueBridge.ethernetPort.status to cloudService.bridgePort.status;
        }

        interface bridgeToBulbs : BridgeToBulbInterface connect hueBridge.zigbeePort to bulbs.zigbeePort {
            flow commandFlow of LightCommand from hueBridge.zigbeePort.command to bulbs.zigbeePort.command;
            flow statusFlow of BulbStatus from bulbs.zigbeePort.status to hueBridge.zigbeePort.status;
        }
    }

    requirement def RemoteControlRequirement {
        doc /* The system shall allow a user to remotely control power state, brightness, color, and color temperature of Hue bulbs from a mobile application. */
        subject system : HueSystem;
    }

    requirement def SceneRequirement {
        doc /* The mobile application shall allow users to create, store, and activate pre-saved lighting scenes for multiple bulbs. */
        subject app : MobileApp;
    }

    requirement def BridgeCapacityRequirement {
        doc /* The Hue Bridge shall support routing commands and collecting status from a maximum of 50 smart bulbs simultaneously. */
        subject bridge : HueBridge;
    }

    requirement def EnergyEfficiencyRequirement {
        doc /* The system shall allow precise dimming and scheduling to reduce overall power consumption compared to traditional lighting. */
        subject system : HueSystem;
    }
}
