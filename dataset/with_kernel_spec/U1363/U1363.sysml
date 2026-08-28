package SmartHomeEcosystem {
    private import ScalarValues::*;
    private import SI::*;
    private import ISQ::*;

    item def Command {
        attribute deviceId : String;
        attribute actionType : String;
        attribute value : String;
    }
    item def Telemetry {
        attribute deviceId : String;
        attribute status : String;
        attribute timestamp : String;
    }
    item def Notification {
        attribute notifMessage : String;
    }
    item def RegistrationRequest {
        attribute deviceId : String;
        attribute authToken : String;
    }
    item def RegistrationResponse {
        attribute success : Boolean;
    }
    item def Disconnect;
    item def Reconnect;

    attribute def BrightnessValue :> ScalarValues::Real;
    attribute def ColorTemperatureValue :> ScalarValues::Real;
    attribute def EnergyValue :> ScalarValues::Real;
    attribute def TemperatureValue :> ScalarValues::Real;
    attribute def PowerLoadValue :> ScalarValues::Real;

    port def DevicePort {
        in item cmd : Command;
        in item regReq : RegistrationRequest;
        out item regResp : RegistrationResponse;
        out item tel : Telemetry;
    }
    port def GatewayDevicePort {
        out item cmd : Command;
        in item tel : Telemetry;
        in item regReq : RegistrationRequest;
        out item regResp : RegistrationResponse;
    }
    port def GatewayCloudPort {
        in item cmd : Command;
        out item tel : Telemetry;
        out item notif : Notification;
    }
    port def CloudGatewayPort {
        out item cmd : Command;
        in item tel : Telemetry;
        out item notif : Notification;
    }
    port def CloudAppPort {
        in item cmd : Command;
        out item tel : Telemetry;
        out item notif : Notification;
    }
    port def AppPort {
        out item cmd : Command;
        in item tel : Telemetry;
        in item notif : Notification;
    }

    part def Microcontroller {
        attribute processorSpeed : ScalarValues::Real;
        attribute firmwareVersion : String;
    }
    part def WirelessModule {
        attribute protocol : String;
        attribute signalStrength : ScalarValues::Real;
    }

    abstract part def SmartDevice {
        attribute deviceId : String;
        part mcu : Microcontroller;
        part wireless : WirelessModule;
        port devicePort : DevicePort;

        state DeviceLifecycle {
            state unregistered;
            state registered;
            state operational {
                state standby;
                state executing;
                state reporting;
                transition first standby accept cmd then executing;
                transition first executing then reporting;
                transition first reporting then standby;
            }
            state disconnected;
            
            transition first unregistered accept regReq then registered;
            transition first registered then operational;
            transition first operational accept Disconnect then disconnected;
            transition first disconnected accept Reconnect then operational;
        }
    }

    part def SmartLight :> SmartDevice {
        attribute isOn : Boolean = false;
        attribute brightness : BrightnessValue = 0;
        attribute colorTemp : ColorTemperatureValue = 2700;
        attribute energyConsumption : EnergyValue = 0;
    }
    part def SmartThermostat :> SmartDevice {
        attribute currentTemp : TemperatureValue;
        attribute setpoint : TemperatureValue;
        attribute hvacMode : String;
        action controlHVAC;
    }
    part def SmartSocket :> SmartDevice {
        attribute powerOn : Boolean = false;
        attribute powerLoad : PowerLoadValue;
        attribute cumulativeEnergy : EnergyValue;
        attribute overloadProtection : Boolean = true;
    }

    part def NetworkGateway {
        attribute gatewayId : String;
        attribute localProtocol : String;
        attribute cloudSecure : Boolean = true;
        port cloudPort : GatewayCloudPort;
        port devicePort : GatewayDevicePort[0..*];
        action bridgeTraffic;
        action discoverDevices;
        action secureConnection;
    }

    part def CloudInfrastructure {
        attribute region : String;
        attribute databaseUrl : String;
        attribute analyticsEnabled : Boolean = true;
        port appPort : CloudAppPort;
        port gatewayPort : CloudGatewayPort[0..*];

        part deviceManagement {
            action registerDevice;
            action authenticateDevice;
        }
        part dataRouting {
            action routeCommand;
            action processTelemetry;
        }
        part dataStorage;
        part analytics;
    }

    part def MobileApplication {
        attribute appVersion : String;
        attribute userToken : String;
        port cloudPort : AppPort;
        action viewStatus;
        action sendCommand { out item cmd : Command; }
        action receiveNotification { in item notif : Notification; }
    }

    connection def DeviceGatewayLink {
        end device : SmartDevice;
        end gateway : NetworkGateway;
    }
    connection def GatewayCloudLink {
        end gateway : NetworkGateway;
        end cloud : CloudInfrastructure;
    }
    connection def CloudAppLink {
        end cloud : CloudInfrastructure;
        end app : MobileApplication;
    }

    part def SmartHomeSystem {
        part light1 : SmartLight;
        part thermostat1 : SmartThermostat;
        part socket1 : SmartSocket;
        part gateway1 : NetworkGateway;
        part cloud1 : CloudInfrastructure;
        part app1 : MobileApplication;

        connection lightLink : DeviceGatewayLink connect light1 to gateway1;
        connection thermostatLink : DeviceGatewayLink connect thermostat1 to gateway1;
        connection socketLink : DeviceGatewayLink connect socket1 to gateway1;
        connection gwCloud : GatewayCloudLink connect gateway1 to cloud1;
        connection cloudApp : CloudAppLink connect cloud1 to app1;

        action CommandExecutionSequence {
            first start;
            action userTap { out item cmd : Command; }
            then action cloudAuth { in item cmd : Command; out item authCmd : Command; }
            then action cloudRoute { in item cmd : Command; out item gwCmd : Command; }
            then action gwTransmit { in item cmd : Command; out item devCmd : Command; }
            then action deviceExec { in item cmd : Command; out item tel : Telemetry; }
            then action gwRelay { in item tel : Telemetry; out item cloudTel : Telemetry; }
            then action cloudForward { in item tel : Telemetry; out item appTel : Telemetry; }
            then done;
        }

        requirement secureComm : SecureCommunication {
            subject :>> smartHomeSystem;
        }
        requirement remoteCtrl : RemoteControl {
            subject :>> smartHomeSystem;
        }
        requirement deviceLife : DeviceLifecycle {
            subject :>> light1;
        }
        requirement cloudMgmt : CloudManagement {
            subject :>> cloud1;
        }
    }

    requirement def SecureCommunication {
        subject smartHomeSystem : SmartHomeSystem;
        doc /* All communications between devices, gateway, cloud, and mobile app shall be encrypted and authenticated. */
    }
    requirement def RemoteControl {
        subject smartHomeSystem : SmartHomeSystem;
        doc /* Users shall be able to remotely control any smart device through the mobile application. */
    }
    requirement def DeviceLifecycle {
        subject device : SmartDevice;
        doc /* Devices shall transition from unregistered to operational through a secure authentication process and reconnect automatically on connection loss. */
    }
    requirement def CloudManagement {
        subject cloud : CloudInfrastructure;
        doc /* The cloud shall provide centralized device registration, command routing, telemetry storage, and usage analytics. */
    }
}
