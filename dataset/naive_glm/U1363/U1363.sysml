package SmartHomeEcosystem {
    import ScalarValues::*;
    import Collections::*;

    package Units {
        quantity temperature;
        unit degC of temperature;

        quantity power;
        unit W of power;

        quantity energy;
        unit kWh of energy;

        quantity dimensionless;
        unit percent of dimensionless;

        quantity colorTemperature;
        unit K of colorTemperature;

        quantity time;
        unit s of time;
    }

    package DataTypes {
        import Units::*;

        enum def DeviceType { light; thermostat; socket; }
        enum def ConnectionState { unregistered; authenticating; operational; reconnecting; }
        enum def OperationalState { standby; executing; reporting; }

        item def Command {
            attribute commandId : String;
            attribute deviceId : String;
            attribute action : String;
            attribute paramValue : Real;
            attribute timestamp : String;
            attribute encrypted : Boolean;
        }

        item def StatusUpdate {
            attribute deviceId : String;
            attribute state : String;
            attribute timestamp : String;
        }

        item def TelemetryData {
            attribute deviceId : String;
            attribute metricName : String;
            attribute value : Real;
            attribute unit : String;
            attribute timestamp : String;
        }

        item def Notification {
            attribute notificationId : String;
            attribute message : String;
            attribute severity : String;
            attribute timestamp : String;
        }

        item def RegistrationRequest {
            attribute deviceId : String;
            attribute deviceType : DeviceType;
            attribute macAddress : String;
            attribute firmwareVersion : String;
        }

        item def AuthToken {
            attribute token : String;
            attribute expires : String;
        }

        item def UserCredentials {
            attribute username : String;
            attribute passwordHash : String;
        }

        item def RegistrationRequestReceived;
        item def AuthenticationSuccessful;
        item def AuthenticationFailed;
        item def ConnectionLost;
        item def ConnectionRestored;
        item def ReconnectFailed;
        item def CommandReceived;
        item def CommandCompleted;
        item def ReportSent;
    }

    package Ports {
        import DataTypes::*;

        port def WirelessPort {
            in item command : Command;
            out item status : StatusUpdate;
            out item telemetry : TelemetryData;
            in item registration : RegistrationRequest;
        }

        port def InternetPort {
            in item command : Command;
            out item status : StatusUpdate;
            out item telemetry : TelemetryData;
            in item registration : RegistrationRequest;
            out item authToken : AuthToken;
        }

        port def CloudPort {
            out item command : Command;
            in item status : StatusUpdate;
            in item telemetry : TelemetryData;
            in item notification : Notification;
            out item credentials : UserCredentials;
        }

        port def AppPort {
            in item command : Command;
            out item status : StatusUpdate;
            out item notification : Notification;
        }
    }

    package Devices {
        import DataTypes::*;
        import Ports::*;
        import Units::*;

        part def Microcontroller {
            attribute firmwareVersion : String;
            attribute processingLoad : Real [percent];
            action def executeCommand(in cmd : Command) : Boolean;
            action def parseCommand(in cmd : Command) : String;
        }

        part def WirelessModule {
            attribute protocol : String;
            attribute signalStrength : Real [percent];
            attribute encrypted : Boolean;
            action def transmit(in data : String);
            action def receive() : String;
        }

        abstract part def SmartDevice {
            attribute deviceId : String;
            attribute deviceType : DeviceType;
            attribute connectionState : ConnectionState = ConnectionState::unregistered;
            attribute operationalState : OperationalState = OperationalState::standby;
            attribute lastSeen : String;

            part microcontroller : Microcontroller;
            part wireless : WirelessModule;

            port wirelessPort : WirelessPort;

            state deviceLifecycle {
                entry; then Unregistered;

                state Unregistered {
                    entry { connectionState = ConnectionState::unregistered; }
                }
                state Authenticating {
                    entry { connectionState = ConnectionState::authenticating; }
                }
                state Operational {
                    entry { connectionState = ConnectionState::operational; }
                    entry; then Standby;

                    state Standby {
                        entry { operationalState = OperationalState::standby; }
                    }
                    state Executing {
                        entry { operationalState = OperationalState::executing; }
                    }
                    state Reporting {
                        entry { operationalState = OperationalState::reporting; }
                    }

                    transition Standby -> Executing accept CommandReceived;
                    transition Executing -> Reporting accept CommandCompleted;
                    transition Reporting -> Standby accept ReportSent;
                }
                state Reconnecting {
                    entry { connectionState = ConnectionState::reconnecting; }
                }

                transition Unregistered -> Authenticating accept RegistrationRequestReceived;
                transition Authenticating -> Operational accept AuthenticationSuccessful;
                transition Authenticating -> Unregistered accept AuthenticationFailed;
                transition Operational -> Reconnecting accept ConnectionLost;
                transition Reconnecting -> Operational accept ConnectionRestored;
                transition Reconnecting -> Unregistered accept ReconnectFailed;
            }

            abstract action def executeCommand(in cmd : Command);
            abstract action def reportStatus() : StatusUpdate;
            abstract action def sendTelemetry() : TelemetryData;
        }

        part def SmartLight :> SmartDevice {
            attribute isOn : Boolean = false;
            attribute brightness : Real [percent] = 100;
            attribute colorTemperature : Real [K] = 3000;
            attribute energyConsumed : Real [kWh] = 0;
            attribute ratedPower : Real [W] = 9;

            action def executeCommand(in cmd : Command) {
                if cmd.action == "turnOn" { isOn = true; }
                if cmd.action == "turnOff" { isOn = false; }
                if cmd.action == "setBrightness" { brightness = cmd.paramValue; }
                if cmd.action == "setColorTemp" { colorTemperature = cmd.paramValue; }
            }

            action def reportStatus() : StatusUpdate {
                return StatusUpdate { deviceId = deviceId; state = if isOn then "on" else "off"; timestamp = lastSeen; };
            }

            action def sendTelemetry() : TelemetryData {
                return TelemetryData { deviceId = deviceId; metricName = "energy"; value = energyConsumed; unit = "kWh"; timestamp = lastSeen; };
            }
        }

        part def SmartThermostat :> SmartDevice {
            attribute currentTemperature : Real [degC] = 22;
            attribute setpoint : Real [degC] = 22;
            attribute hvacActive : Boolean = false;
            attribute humidity : Real [percent] = 50;

            action def executeCommand(in cmd : Command) {
                if cmd.action == "setSetpoint" { setpoint = cmd.paramValue; }
            }

            action def controlHVAC() {
                if currentTemperature < setpoint { hvacActive = true; }
                if currentTemperature >= setpoint { hvacActive = false; }
            }

            action def reportStatus() : StatusUpdate {
                return StatusUpdate { deviceId = deviceId; state = if hvacActive then "heating" else "idle"; timestamp = lastSeen; };
            }

            action def sendTelemetry() : TelemetryData {
                return TelemetryData { deviceId = deviceId; metricName = "temperature"; value = currentTemperature; unit = "degC"; timestamp = lastSeen; };
            }
        }

        part def SmartSocket :> SmartDevice {
            attribute powerOn : Boolean = false;
            attribute currentLoad : Real [W] = 0;
            attribute cumulativeEnergy : Real [kWh] = 0;
            attribute overloadThreshold : Real [W] = 2500;
            attribute overloadTripped : Boolean = false;

            action def executeCommand(in cmd : Command) {
                if cmd.action == "turnOn" { powerOn = true; }
                if cmd.action == "turnOff" { powerOn = false; }
                if cmd.action == "resetOverload" { overloadTripped = false; }
            }

            action def checkOverload() {
                if currentLoad > overloadThreshold {
                    powerOn = false;
                    overloadTripped = true;
                }
            }

            action def reportStatus() : StatusUpdate {
                return StatusUpdate { deviceId = deviceId; state = if powerOn then "on" else "off"; timestamp = lastSeen; };
            }

            action def sendTelemetry() : TelemetryData {
                return TelemetryData { deviceId = deviceId; metricName = "power"; value = currentLoad; unit = "W"; timestamp = lastSeen; };
            }
        }
    }

    package Infrastructure {
        import DataTypes::*;
        import Ports::*;
        import Devices::*;
        import Units::*;

        part def NetworkGateway {
            attribute gatewayId : String;
            attribute localProtocol : String;
            attribute cloudConnected : Boolean = false;
            attribute maxDevices : Integer = 128;
            attribute registeredDeviceCount : Integer = 0;

            port devicePort : WirelessPort[0..*];
            port cloudPort : InternetPort;

            action def discoverDevices() : RegistrationRequest[0..*];
            action def routeCommand(in cmd : Command) {
                // forward command to the target device over the local wireless network
            }
            action def relayStatus(in status : StatusUpdate) {
                // forward status update from device to cloud
            }
            action def relayTelemetry(in data : TelemetryData) {
                // forward telemetry from device to cloud
            }
            action def secureCloudConnection() {
                cloudConnected = true;
            }
            action def handleRegistration(in req : RegistrationRequest) {
                registeredDeviceCount = registeredDeviceCount + 1;
            }
        }

        part def CloudInfrastructure {
            attribute serverId : String;
            attribute region : String;
            attribute uptime : Real [percent] = 99.9;

            port gatewayPort : InternetPort[0..*];
            port appPort : CloudPort[0..*];

            part deviceManager {
                attribute registeredDevices : String[0..*];
                action def registerDevice(in req : RegistrationRequest) : AuthToken {
                    return AuthToken { token = "token-" + req.deviceId; expires = "24h"; };
                }
                action def authenticateDevice(in deviceId : String) : Boolean;
                action def manageLifecycle(in deviceId : String);
                action def revokeDevice(in deviceId : String);
            }

            part dataRouter {
                action def routeCommand(in cmd : Command) {
                    // route command from app to the correct home gateway
                }
                action def processTelemetry(in data : TelemetryData) {
                    // store telemetry and forward relevant updates to app
                }
                action def routeStatus(in status : StatusUpdate) {
                    // forward status update to the mobile application
                }
            }

            part dataStorage {
                attribute deviceHistory : String[0..*];
                attribute userPreferences : String[0..*];
                attribute eventLogs : String[0..*];
                action def store(in data : String);
                action def retrieve(in query : String) : String;
                action def logEvent(in event : String);
            }

            part analyticsEngine {
                attribute insights : String[0..*];
                action def analyzeUsage(in data : TelemetryData[0..*]) : String;
                action def detectAnomaly(in data : TelemetryData) : Boolean;
                action def generateReport(in deviceId : String) : String;
            }
        }

        part def MobileApplication {
            attribute appId : String;
            attribute userId : String;
            attribute authenticated : Boolean = false;
            attribute pushNotificationsEnabled : Boolean = true;

            port cloudPort : CloudPort;
            port userPort : AppPort;

            action def login(in creds : UserCredentials) : Boolean {
                authenticated = true;
                return true;
            }
            action def logout() {
                authenticated = false;
            }
            action def sendCommand(in cmd : Command) {
                // encrypt and send command to cloud
            }
            action def displayStatus(in status : StatusUpdate);
            action def receiveNotification(in notif : Notification);
            action def refreshDeviceList();
        }
    }

    package System {
        import Devices::*;
        import Infrastructure::*;
        import Ports::*;
        import DataTypes::*;

        part def SmartHomeSystem {
            attribute systemId : String;
            attribute homeName : String;

            part cloud : CloudInfrastructure;
            part gateway : NetworkGateway;
            part app : MobileApplication;
            part lights : SmartLight[0..*];
            part thermostats : SmartThermostat[0..*];
            part sockets : SmartSocket[0..*];

            connect app.cloudPort to cloud.appPort;
            connect cloud.gatewayPort to gateway.cloudPort;
            connect gateway.devicePort to lights.wirelessPort;
            connect gateway.devicePort to thermostats.wirelessPort;
            connect gateway.devicePort to sockets.wirelessPort;
        }
    }

    package Requirements {
        import ScalarValues::*;
        import Devices::*;
        import Infrastructure::*;
        import DataTypes::*;

        requirement def DeviceRegistration {
            doc { Each smart device shall transition from unregistered to operational through secure registration and authentication. }
            subject device : SmartDevice;
            objective {
                device.connectionState == ConnectionState::operational
            }
        }

        requirement def SecureCommunication {
            doc { All commands transmitted between the mobile application, cloud, gateway, and devices shall be encrypted. }
            subject cmd : Command;
            objective {
                cmd.encrypted == true
            }
        }

        requirement def RemoteControl {
            doc { The user shall be able to remotely control registered smart devices from the mobile application. }
            subject app : MobileApplication;
            subject device : SmartDevice;
            objective {
                device.connectionState == ConnectionState::operational
            }
        }

        requirement def OverloadProtection {
            doc { Smart sockets shall disconnect power when the measured load exceeds the overload threshold. }
            subject socket : SmartSocket;
            objective {
                socket.overloadTripped == true when socket.currentLoad > socket.overloadThreshold
            }
        }

        requirement def TelemetryTracking {
            doc { Each smart device shall report status updates and telemetry to the cloud through the gateway. }
            subject device : SmartDevice;
            objective {
                device.operationalState == OperationalState::reporting
            }
        }

        requirement def RealTimeStatusDisplay {
            doc { The mobile application shall display the real-time status of each device within a short latency of receiving a status update. }
            subject app : MobileApplication;
            subject status : StatusUpdate;
            objective {
                app.authenticated == true
            }
        }

        requirement def AutomaticReconnection {
            doc { Devices that lose connection shall automatically attempt to reconnect and return to operational state. }
            subject device : SmartDevice;
            objective {
                device.connectionState == ConnectionState::operational or device.connectionState == ConnectionState::reconnecting
            }
        }

        requirement def CloudDataStorage {
            doc { The cloud infrastructure shall store device activity history, user preferences, and system event logs. }
            subject cloud : CloudInfrastructure;
            objective {
                cloud.dataStorage.eventLogs.size > 0
            }
        }

        requirement def AnalyticsInsights {
            doc { The cloud analytics engine shall analyze usage patterns and detect unusual activity. }
            subject cloud : CloudInfrastructure;
            objective {
                cloud.analyticsEngine.insights.size >= 0
            }
        }
    }
}
