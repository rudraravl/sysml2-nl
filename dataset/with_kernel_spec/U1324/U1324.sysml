package AllJoynEcosystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQThermodynamics::*;

    item def AllJoynMessage {
        attribute payload : String;
        attribute encrypted : Boolean;
        attribute authenticated : Boolean;
    }

    port def AllJoynNetworkPort {
        in item incomingMessage : AllJoynMessage;
        out item outgoingMessage : AllJoynMessage;
    }

    port def WifiPort :> AllJoynNetworkPort;
    port def BluetoothPort :> AllJoynNetworkPort;
    port def EthernetPort :> AllJoynNetworkPort;

    part def AllJoynDaemon {
        port wifiPort : WifiPort;
        port bluetoothPort : BluetoothPort;
        port ethernetPort : EthernetPort;

        action routeMessage {
            in message : AllJoynMessage;
            in sourcePort : AllJoynNetworkPort;
            out destPort : AllJoynNetworkPort;
        }
        action discoverDevices {
            out discoveredDevices : String;
        }
        action establishSecureSession {
            in device : String;
            out sessionKey : String;
        }
    }

    part def SmartDevice {
        attribute manufacturer : String;
        attribute deviceState : String;
        port allJoynPort : AllJoynNetworkPort;

        action handleMessage {
            in message : AllJoynMessage;
        }
        action announcePresence {
            out announcement : AllJoynMessage;
        }
    }

    part def SmartLightBulb :> SmartDevice {
        attribute brightness : Real;
        attribute colorTemperature : ThermodynamicTemperatureValue;

        action changeState {
            in newState : String;
            in newBrightness : Real;
            in newColorTemp : ThermodynamicTemperatureValue;
        }

        state LightBulbStateMachine {
            state off;
            accept AllJoynMessage then on;
            state on;
            accept AllJoynMessage then off;
        }
    }

    part def EnvironmentSensor :> SmartDevice {
        attribute temperature : ThermodynamicTemperatureValue;
        attribute humidity : Real;
        attribute airQuality : Real;

        action publishReadings {
            out readings : AllJoynMessage;
        }
    }

    part def SmartThermostat :> SmartDevice {
        attribute targetTemperature : ThermodynamicTemperatureValue;
        attribute operatingMode : String;

        action adjustState {
            in sensorData : AllJoynMessage;
            out newTargetTemp : ThermodynamicTemperatureValue;
            out newMode : String;
        }
    }

    part def MobileControlApp :> SmartDevice {
        action discoverDevices {
            out deviceList : String;
        }
        action sendCommand {
            in deviceId : String;
            in command : AllJoynMessage;
        }
    }

    connection def AllJoynConnection {
        end daemon : AllJoynDaemon;
        end device : SmartDevice;
    }

    part allJoynDaemon : AllJoynDaemon;
    part smartLightBulb : SmartLightBulb {
        :>> manufacturer = "Philips";
    }
    part environmentSensor : EnvironmentSensor {
        :>> manufacturer = "Nest";
    }
    part smartThermostat : SmartThermostat {
        :>> manufacturer = "Honeywell";
    }
    part mobileControlApp : MobileControlApp {
        :>> manufacturer = "Apple";
    }

    connection lightConnection : AllJoynConnection connect allJoynDaemon.wifiPort to smartLightBulb.allJoynPort;
    connection sensorConnection : AllJoynConnection connect allJoynDaemon.wifiPort to environmentSensor.allJoynPort;
    connection thermostatConnection : AllJoynConnection connect allJoynDaemon.wifiPort to smartThermostat.allJoynPort;
    connection appConnection : AllJoynConnection connect allJoynDaemon.wifiPort to mobileControlApp.allJoynPort;

    requirement SecureCommunication {
        doc /* All communication between devices and the AllJoyn Daemon must be encrypted and authenticated */;
    }
    requirement Interoperability {
        doc /* Devices from different manufacturers must be able to discover and communicate with each other */;
    }
    requirement OfflineFunctionality {
        doc /* The system must function correctly even without an internet connection */;
    }
}
