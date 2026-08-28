package ProjectBrillo {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import ISQ::TemperatureValue;
    private import ISQ::PressureValue;

    package Definitions {
        attribute def HumidityValue :> Real;
        attribute def BatteryLevelValue :> Real;

        item def SensorData {
            attribute deviceId : String;
            attribute timestamp : String;
            attribute temperature : TemperatureValue;
            attribute humidity : HumidityValue;
            attribute pressure : PressureValue;
        }

        item def Command {
            attribute deviceId : String;
            attribute commandType : String;
            attribute payload : String;
        }

        item def Alert {
            attribute alertType : String;
            attribute alertMessage : String;
            attribute deviceId : String;
            attribute severity : String;
        }

        item def StatusReport {
            attribute deviceId : String;
            attribute batteryLevel : BatteryLevelValue;
            attribute signalStrength : Real;
            attribute status : String;
        }

        item def Insight {
            attribute deviceId : String;
            attribute prediction : String;
            attribute confidence : Real;
        }

        port def DeviceCloudPort {
            out data : SensorData;
            out status : StatusReport;
            in cmd : Command;
        }

        port def GatewayDevicePort {
            in data : SensorData;
            in status : StatusReport;
            out cmd : Command;
        }

        port def GatewayPlatformPort {
            out data : SensorData;
            out status : StatusReport;
            in cmd : Command;
        }

        port def PlatformGatewayPort {
            in data : SensorData;
            in status : StatusReport;
            out cmd : Command;
        }

        port def PlatformUserPort {
            out data : SensorData;
            out alert : Alert;
            out insight : Insight;
            in cmd : Command;
        }

        port def UserPlatformPort {
            in data : SensorData;
            in alert : Alert;
            in insight : Insight;
            out cmd : Command;
        }

        action def CollectSensorData { out data : SensorData; }
        action def EncryptData { in raw : SensorData; out encrypted : SensorData; }
        action def AuthenticateDevice { in credentials : String; out token : String; out success : Boolean; }
        action def TransmitData { in data : SensorData; }
        action def CheckCommands { out cmd : Command[0..1]; }
        action def ExecuteCommand { in cmd : Command; }
        action def ReportStatus { out status : StatusReport; }
        action def BufferData { in data : SensorData; }
        action def ForwardToPlatform { in data : SensorData; }
        action def TranslateProtocol { in raw : SensorData; out translated : SensorData; }
        action def LoadBalance { in connectionId : String; }
        action def ProcessData { in data : SensorData; }
        action def DetectAnomalies { in data : SensorData; out alert : Alert[0..1]; }
        action def PredictFailure { in data : SensorData; out insight : Insight[0..1]; }
        action def DispatchCommand { in cmd : Command; }
        action def ValidateCredentials { in credentials : String; out valid : Boolean; }
        action def StoreData { in data : SensorData; }
        action def RegisterDevice { in deviceId : String; }
        action def DisplayData { in data : SensorData; }
        action def IssueCommand { out cmd : Command; }
        action def NotifyAlert { in alert : Alert; }
        action def DisplayInsight { in insight : Insight; }
        action def InitializeHardware;
        action def SelfTest;
        action def GracefulShutdown;
        action def LogError;
        action def AttemptRecovery;
        action def SleepAction { in duration : Real; }

        attribute def BootComplete;
        attribute def ConnectionEstablished;
        attribute def AuthenticationFailed;
        attribute def DataReady;
        attribute def TransmissionComplete;
        attribute def CommandReceived;
        attribute def CommandExecuted;
        attribute def StatusSent;
        attribute def Shutdown;
        attribute def ShutdownComplete;

        part def Microcontroller;
        part def PowerSystem { attribute batteryLevel : BatteryLevelValue; }
        part def SensorArray;
        part def CommsModule;
        part def SecurityModule {
            perform action encrypt : EncryptData;
            perform action authenticate : AuthenticateDevice;
        }

        part def EdgeDevice {
            part mcu : Microcontroller;
            part power : PowerSystem;
            part sensors : SensorArray;
            part comms : CommsModule;
            part security : SecurityModule;
            port cloud : DeviceCloudPort;

            perform action collectData : CollectSensorData;
            perform action transmitData : TransmitData;
            perform action checkCommands : CheckCommands;
            perform action executeCmd : ExecuteCommand;
            perform action reportStatus : ReportStatus;
            perform action initializeHardware : InitializeHardware;
            perform action selfTest : SelfTest;
            perform action encryptData : EncryptData;
            perform action authenticate : AuthenticateDevice;
            perform action sleepAction : SleepAction;
            perform action gracefulShutdown : GracefulShutdown;
            perform action logError : LogError;
            perform action attemptRecovery : AttemptRecovery;

            exhibit state lifecycle : EdgeDeviceLifecycle;
        }

        part def LoadBalancer;
        part def MessageQueue;
        part def ProtocolTranslator;

        part def CloudGateway {
            part lb : LoadBalancer;
            part mq : MessageQueue;
            part pt : ProtocolTranslator;
            port deviceSide : GatewayDevicePort[0..*];
            port platformSide : GatewayPlatformPort;

            perform action buffer : BufferData;
            perform action forward : ForwardToPlatform;
            perform action translate : TranslateProtocol;
            perform action balance : LoadBalance;
        }

        part def DataStore;
        part def DeviceRegistry;
        part def AnalyticsEngine {
            perform action analyze : ProcessData;
            perform action detect : DetectAnomalies;
            perform action predict : PredictFailure;
        }
        part def CommandDispatcher { perform action dispatch : DispatchCommand; }
        part def SecurityService { perform action validate : ValidateCredentials; }

        part def CloudPlatform {
            part store : DataStore;
            part registry : DeviceRegistry;
            part analytics : AnalyticsEngine;
            part dispatcher : CommandDispatcher;
            part secSvc : SecurityService;
            port gatewaySide : PlatformGatewayPort;
            port userSide : PlatformUserPort;
        }

        part def Dashboard { perform action display : DisplayData; }
        part def ControlInterface { perform action issue : IssueCommand; }
        part def AlertingSystem { perform action notify : NotifyAlert; }

        part def UserApplication {
            part dash : Dashboard;
            part ctrl : ControlInterface;
            part alerts : AlertingSystem;
            port platformSide : UserPlatformPort;
        }

        part def BrilloPlatform {
            part edge : EdgeDevice[1..*];
            part gateway : CloudGateway;
            part platform : CloudPlatform;
            part app : UserApplication;

            connect edge.cloud to gateway.deviceSide;
            connect gateway.platformSide to platform.gatewaySide;
            connect platform.userSide to app.platformSide;
        }

        state def EdgeDeviceLifecycle {
            entry; then boot;
            state boot {
                entry;
                do initializeHardware;
                do selfTest;
            }
            accept BootComplete then connect;

            state connect {
                entry;
                do authenticate;
            }
            accept ConnectionEstablished then operational;
            accept AuthenticationFailed then error;

            state operational {
                entry; then collecting;

                state collecting {
                    entry;
                    do collectData;
                    do encryptData;
                }
                accept DataReady then transmitting;

                state transmitting {
                    entry;
                    do transmitData;
                }
                accept TransmissionComplete then checking;

                state checking {
                    entry;
                    do checkCommands;
                }
                accept CommandReceived then executing;
                accept after 5[SI::s] then reporting;

                state executing {
                    entry;
                    do executeCmd;
                }
                accept CommandExecuted then reporting;

                state reporting {
                    entry;
                    do reportStatus;
                }
                accept StatusSent then sleeping;

                state sleeping {
                    entry;
                    do sleepAction;
                }
                accept after 10[SI::s] then collecting;
                accept Shutdown then shuttingDown;
            }

            state shuttingDown {
                entry;
                do gracefulShutdown;
            }
            accept ShutdownComplete then off;

            state off;

            state error {
                entry;
                do logError;
                do attemptRecovery;
            }
            accept ConnectionEstablished then operational;
            accept after 60[SI::s] then off;
        }

        requirement def ReliabilityRequirement {
            doc /* The system shall recover from connection errors automatically within 60 seconds. */
            subject brilloSystem : BrilloPlatform;
            attribute maxRecoveryTime : Real = 60;
        }

        requirement def SecurityRequirement {
            doc /* All data transmissions shall be encrypted and all connections authenticated. */
            subject brilloSystem : BrilloPlatform;
            attribute encryptionStandard : String = "AES-256";
            attribute authenticationMethod : String = "X.509";
        }

        requirement def PerformanceRequirement {
            doc /* The Cloud Gateway shall handle at least 10,000 simultaneous device connections. */
            subject gateway : CloudGateway;
            attribute minConnections : Integer = 10000;
        }

        requirement def ScalabilityRequirement {
            doc /* The platform shall support up to 100,000 edge devices. */
            subject brilloSystem : BrilloPlatform;
            attribute maxDevices : Integer = 100000;
        }

        requirement def RealTimeAnalyticsRequirement {
            doc /* The Analytics Engine shall process sensor data and generate alerts within 500 milliseconds. */
            subject analytics : AnalyticsEngine;
            attribute maxLatency : Real = 500;
        }
    }

    package Usages {
        private import Definitions::*;

        part brilloSystem : BrilloPlatform {
            part :>> edge : EdgeDevice[2];
            part :>> gateway : CloudGateway;
            part :>> platform : CloudPlatform;
            part :>> app : UserApplication;
        }

        requirement reliability : ReliabilityRequirement {
            subject :>> brilloSystem;
        }

        requirement security : SecurityRequirement {
            subject :>> brilloSystem;
        }

        requirement performance : PerformanceRequirement {
            subject :>> brilloSystem.gateway;
        }

        requirement scalability : ScalabilityRequirement {
            subject :>> brilloSystem;
        }

        requirement realTime : RealTimeAnalyticsRequirement {
            subject :>> brilloSystem.platform.analytics;
        }

        satisfy reliability by brilloSystem;
        satisfy security by brilloSystem.edge, brilloSystem.gateway, brilloSystem.platform;
        satisfy performance by brilloSystem.gateway;
        satisfy scalability by brilloSystem.gateway, brilloSystem.platform;
        satisfy realTime by brilloSystem.platform.analytics;
    }
}
