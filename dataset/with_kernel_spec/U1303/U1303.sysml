package MobileInternetDeviceModel {
    private import ScalarValues::*;

    package Definitions {
        attribute def BatteryCharge :> Real;
        attribute def ScreenBrightness :> Real;
        attribute def DataRate :> Real;
        attribute def BatteryHealth :> Real;
        attribute def Temperature :> Real;
        attribute def Power :> Real;

        item def TouchEvent {
            attribute xCoord : Real;
            attribute yCoord : Real;
            attribute gesture : String;
            attribute timestamp : Real;
        }

        item def DisplayContent {
            attribute frameData : String;
            attribute resolution : String;
        }

        item def DataPacket {
            attribute payload : String;
            attribute sourceAddress : String;
            attribute destinationAddress : String;
            attribute size : Integer;
        }

        item def NetworkRequest :> DataPacket;
        item def NetworkResponse :> DataPacket;
        item def PowerSignal;

        attribute def ConnectRequest;
        attribute def ConnectionEstablished;
        attribute def DisconnectRequest;
        attribute def DataReceived;
        attribute def SendData;
        attribute def PluggedIn;
        attribute def Unplugged;
        attribute def TransmissionComplete;
        attribute def ReceiveComplete;

        port def TouchPort {
            out item touchEvent : TouchEvent;
        }

        port def DisplayPort {
            out item content : DisplayContent;
        }

        port def NetworkPort {
            out item request : NetworkRequest;
            in item response : NetworkResponse;
        }

        port def PowerPort {
            out item power : PowerSignal;
        }

        port def BatteryStatusPort {
            out item charge : BatteryCharge;
            out item temperature : Temperature;
            out item health : BatteryHealth;
        }

        port def ControlPort {
            out item command : String;
            in item status : String;
        }

        action def CaptureTouch {
            out item touchEvent : TouchEvent;
        }

        action def ProcessInput {
            in item touchEvent : TouchEvent;
            out item request : NetworkRequest;
        }

        action def SendRequest {
            in item request : NetworkRequest;
        }

        action def ReceiveResponse {
            out item response : NetworkResponse;
        }

        action def PrepareContent {
            in item response : NetworkResponse;
            out item content : DisplayContent;
        }

        action def RenderContent {
            in item content : DisplayContent;
        }

        action def HandleUserRequest {
            in item touchEvent : TouchEvent;
            out item content : DisplayContent;
            action captureTouch : CaptureTouch;
            then action processInput : ProcessInput;
            then action sendRequest : SendRequest;
            then action receiveResponse : ReceiveResponse;
            then action prepareContent : PrepareContent;
            then action renderContent : RenderContent;
        }

        action def MonitorBattery {
            in charge : BatteryCharge;
            in temperature : Temperature;
            out status : String;
        }

        action def ReduceBrightness {
            in targetBrightness : ScreenBrightness;
        }

        action def LimitBackgroundProcesses;
        action def DistributePower;

        state def ModemStates {
            transition initial then disconnected;
            state disconnected;
            state connecting;
            state connected {
                transition initial then idle;
                state idle;
                state transmitting;
                state receiving;
                transition idle -> transmitting accept SendData;
                transition transmitting -> idle accept TransmissionComplete;
                transition idle -> receiving accept DataReceived;
                transition receiving -> idle accept ReceiveComplete;
            }
            transition disconnected -> connecting accept ConnectRequest;
            transition connecting -> connected accept ConnectionEstablished;
            transition connected -> disconnected accept DisconnectRequest;
        }

        state def BatteryStates {
            attribute chargeLevel : Real;
            transition initial then normal;
            state normal;
            state lowPower {
                entry action reduceBrightness : ReduceBrightness {
                    in targetBrightness = 50;
                }
                entry action limitBackground : LimitBackgroundProcesses;
            }
            state critical {
                entry action reduceBrightnessCritical : ReduceBrightness {
                    in targetBrightness = 10;
                }
                entry action limitBackgroundCritical : LimitBackgroundProcesses;
            }
            state charging;
            transition normal -> lowPower if chargeLevel < 20;
            transition lowPower -> critical if chargeLevel < 5;
            transition lowPower -> normal if chargeLevel > 30;
            transition critical -> lowPower if chargeLevel > 15;
            transition normal -> charging accept PluggedIn;
            transition lowPower -> charging accept PluggedIn;
            transition critical -> charging accept PluggedIn;
            transition charging -> normal accept Unplugged if chargeLevel >= 80;
        }

        state def DeviceStates parallel {
            state modemOperation : ModemStates;
            state batteryOperation : BatteryStates;
        }

        part def ApplicationProcessor {
            port touchIn : ~TouchPort;
            port displayOut : DisplayPort;
            port netPort : NetworkPort;
            port powerIn : ~PowerPort;
            port controlIn : ~ControlPort;

            perform action processInput : ProcessInput;
            perform action prepareContent : PrepareContent;
            perform action handleUserRequest : HandleUserRequest;
        }

        part def TouchInputController {
            port touchOut : TouchPort;
            port powerIn : ~PowerPort;

            perform action captureTouch : CaptureTouch;
        }

        part def DisplayController {
            port displayIn : ~DisplayPort;
            port powerIn : ~PowerPort;
            port controlIn : ~ControlPort;
            attribute brightness : ScreenBrightness;

            perform action renderContent : RenderContent;
        }

        part def WirelessModem {
            port netExt : NetworkPort;
            port netInt : ~NetworkPort;
            port powerIn : ~PowerPort;

            exhibit state modemStates : ModemStates;
            perform action sendRequest : SendRequest;
            perform action receiveResponse : ReceiveResponse;
        }

        part def RechargeableBattery {
            port powerOut : PowerPort;
            port statusOut : BatteryStatusPort;
            attribute chargeLevel : BatteryCharge;
            attribute health : BatteryHealth;
            attribute temperature : Temperature;
            attribute capacity : BatteryCharge;
        }

        part def BatteryManagementSystem {
            port batteryIn : ~PowerPort;
            port statusIn : ~BatteryStatusPort;
            port powerOut1 : PowerPort;
            port powerOut2 : PowerPort;
            port powerOut3 : PowerPort;
            port powerOut4 : PowerPort;
            port controlOut : ControlPort;

            attribute chargeLevel : BatteryCharge;

            exhibit state batteryStates : BatteryStates;
            perform action monitorBattery : MonitorBattery;
            perform action distributePower : DistributePower;
        }

        part def Network {
            port networkPort : ~NetworkPort;
        }

        part def Charger {
            port powerOut : PowerPort;
        }

        part def MobileInternetDevice {
            part appProcessor : ApplicationProcessor;
            part touchController : TouchInputController;
            part displayController : DisplayController;
            part modem : WirelessModem;
            part battery : RechargeableBattery;
            part bms : BatteryManagementSystem;

            connect touchController.touchOut to appProcessor.touchIn;
            connect appProcessor.displayOut to displayController.displayIn;
            connect appProcessor.netPort to modem.netInt;
            connect battery.powerOut to bms.batteryIn;
            connect battery.statusOut to bms.statusIn;
            connect bms.powerOut1 to appProcessor.powerIn;
            connect bms.powerOut2 to modem.powerIn;
            connect bms.powerOut3 to touchController.powerIn;
            connect bms.powerOut4 to displayController.powerIn;
            connect bms.controlOut to appProcessor.controlIn;
            connect bms.controlOut to displayController.controlIn;

            exhibit state deviceStates : DeviceStates;
        }

        requirement def BatteryLifeRequirement {
            doc /* The device shall provide at least 10 hours of continuous web browsing on a full charge. */
            subject device : MobileInternetDevice;
            attribute minDuration : Real = 10;
        }

        requirement def LowPowerModeRequirement {
            doc /* When battery charge drops below 20%, the system shall reduce screen brightness and limit background processes. */
            subject device : MobileInternetDevice;
            attribute threshold : Real = 20;
        }

        requirement def ConnectivityRequirement {
            doc /* The modem shall establish a wireless connection within 5 seconds of receiving a connect request. */
            subject device : MobileInternetDevice;
            attribute maxConnectTime : Real = 5;
        }

        requirement def ResponseTimeRequirement {
            doc /* The device shall process user input and render content within 100 milliseconds. */
            subject device : MobileInternetDevice;
            attribute maxResponseTime : Real = 100;
        }
    }

    package Usages {
        private import Definitions::*;

        part myDevice : MobileInternetDevice;
        part theNetwork : Network;

        connect myDevice.modem.netExt to theNetwork.networkPort;
    }
}
