package IoTEnvironmentalMonitoringSystem {
    private import ScalarValues::*;
    
    package Types {
        item def SensorData {
            attribute timestamp : String;
            attribute deviceId : String;
            attribute zoneId : String;
            attribute temperature : Real;
            attribute humidity : Real;
            attribute airQuality : Real;
            attribute ambientLight : Real;
        }
        
        item def ControlCommand {
            attribute zoneId : String;
            attribute actuatorType : String;
            attribute hvacMode : String;
            attribute fanSpeed : Integer;
        }
        
        item def AlertNotification {
            attribute zoneId : String;
            attribute alertType : String;
            attribute alertMessage : String;
            attribute timestamp : String;
            attribute severity : String;
        }
        
        item def AppData {
            attribute currentConditions : SensorData[0..*];
            attribute activeAlerts : AlertNotification[0..*];
            attribute historicalReports : String[0..*];
        }
        
        attribute def CollectTrigger;
        attribute def TransmittedAck;
        attribute def ForwardedAck;
        attribute def HeatingOn;
        attribute def CoolingOn;
        attribute def VentilatingOn;
        attribute def HVACOff;
        attribute def FanStart;
        attribute def FanStop;
        attribute def ViewHistoryRequest;
        attribute def ReturnRequest;
        attribute def OverrideRequest;
    }
    
    package Ports {
        private import Types::*;
        
        port def DataOutPort {
            out data : SensorData;
        }
        
        port def DataInPort {
            in data : SensorData;
        }
        
        port def CommandOutPort {
            out command : ControlCommand;
        }
        
        port def CommandInPort {
            in command : ControlCommand;
        }
        
        port def AlertOutPort {
            out alert : AlertNotification;
        }
        
        port def AlertInPort {
            in alert : AlertNotification;
        }
        
        port def AppDataOutPort {
            out appData : AppData;
        }
        
        port def AppDataInPort {
            in appData : AppData;
        }
    }
    
    package Actions {
        private import Types::*;
        
        action def CollectData {
            out data : SensorData;
        }
        
        action def AggregateData {
            in rawData : SensorData[0..*];
            out consolidated : SensorData;
        }
        
        action def TransmitToCloud {
            in data : SensorData;
        }
        
        action def StoreData {
            in data : SensorData;
        }
        
        action def AnalyzeData {
            in data : SensorData;
            out anomalyDetected : Boolean;
            out alert : AlertNotification;
        }
        
        action def GenerateControl {
            in zoneId : String;
            in anomalyDetected : Boolean;
            out command : ControlCommand;
        }
        
        action def ExecuteHVACCommand {
            in command : ControlCommand;
        }
        
        action def ExecuteFanCommand {
            in command : ControlCommand;
        }
        
        action def DisplayDashboard {
            in appData : AppData;
        }
        
        action def DisplayHistoricalReports {
            in appData : AppData;
        }
        
        action def SendOverrideCommand {
            out command : ControlCommand;
        }
    }
    
    package StateMachines {
        private import Types::*;
        private import Actions::*;
        
        state def SensorStates {
            entry; then idle;
            state idle;
            accept CollectTrigger do CollectData then transmitting;
            state transmitting;
            accept TransmittedAck then idle;
        }
        
        state def GatewayStates {
            entry; then waiting;
            state waiting;
            accept CollectTrigger do AggregateData then uploading;
            state uploading;
            accept TransmittedAck do TransmitToCloud then waiting;
            accept ControlCommand then forwarding;
            state forwarding;
            accept ForwardedAck then waiting;
        }
        
        state def CloudStates {
            entry; then idle;
            state idle;
            accept CollectTrigger do StoreData then analyzing;
            state analyzing;
            succession analyzing to deciding do AnalyzeData;
            state deciding;
            succession deciding to idle do GenerateControl;
        }
        
        state def HVACStates {
            entry; then off;
            state off;
            accept HeatingOn then heating;
            accept CoolingOn then cooling;
            accept VentilatingOn then ventilating;
            state heating;
            accept HVACOff then off;
            state cooling;
            accept HVACOff then off;
            state ventilating;
            accept HVACOff then off;
        }
        
        state def FanStates {
            entry; then idle;
            state idle;
            accept FanStart then running;
            state running;
            accept FanStop then idle;
        }
        
        state def AppStates {
            entry; then dashboard;
            state dashboard;
            accept ViewHistoryRequest then history;
            accept OverrideRequest then override;
            state history;
            accept ReturnRequest then dashboard;
            state override;
            succession override to dashboard;
        }
    }
    
    package Requirements {
        requirement def DataCollectionReq {
            doc /* Each sensor suite shall continuously collect temperature, humidity, air quality, and ambient light data from its zone. */
            attribute samplePeriod : Real;
            attribute maxSamplePeriod : Real = 60;
            require constraint { samplePeriod <= maxSamplePeriod }
        }
        
        requirement def DataTransmissionReq {
            doc /* The gateway shall transmit consolidated sensor data to the cloud within 1 second of aggregation. */
            attribute transmissionTime : Real;
            attribute maxTransmissionTime : Real = 1;
            require constraint { transmissionTime <= maxTransmissionTime }
        }
        
        requirement def DataIntegrityReq {
            doc /* All sensor data shall include a timestamp and device ID for traceability. */
            attribute hasTimestamp : Boolean;
            attribute hasDeviceId : Boolean;
            require constraint { hasTimestamp == true && hasDeviceId == true }
        }
        
        requirement def CloudStorageReq {
            doc /* The cloud platform shall persistently store all incoming sensor data for historical analysis. */
            attribute storageSuccess : Boolean;
            require constraint { storageSuccess == true }
        }
        
        requirement def RealTimeAnalyticsReq {
            doc /* The cloud shall detect anomalous conditions and generate alerts within 5 seconds. */
            attribute detectionLatency : Real;
            attribute maxDetectionLatency : Real = 5;
            require constraint { detectionLatency <= maxDetectionLatency }
        }
        
        requirement def AutonomousControlReq {
            doc /* The system shall autonomously generate control commands to maintain each zone within target conditions. */
            attribute targetTemp : Real;
            attribute actualTemp : Real;
            attribute tempTolerance : Real = 1.5;
            require constraint { abs(actualTemp - targetTemp) <= tempTolerance }
        }
        
        requirement def ActuatorResponseReq {
            doc /* Actuators shall respond to control commands within 2 seconds. */
            attribute responseTime : Real;
            attribute maxResponseTime : Real = 2;
            require constraint { responseTime <= maxResponseTime }
        }
        
        requirement def ManualOverrideReq {
            doc /* The mobile app shall provide manual override of HVAC and ventilation systems for any zone. */
            attribute overrideEnabled : Boolean;
            require constraint { overrideEnabled == true }
        }
        
        requirement def DashboardRefreshReq {
            doc /* The mobile app dashboard shall refresh with current zone conditions at least every 5 seconds. */
            attribute refreshInterval : Real;
            attribute maxRefreshInterval : Real = 5;
            require constraint { refreshInterval <= maxRefreshInterval }
        }
        
        requirement def AlertNotificationReq {
            doc /* Alert notifications shall be delivered to the mobile app for any detected anomaly. */
            attribute alertDelivered : Boolean;
            require constraint { alertDelivered == true }
        }
    }
    
    package Definitions {
        private import Types::*;
        private import Ports::*;
        private import Actions::*;
        private import StateMachines::*;
        
        part def SensorSuite {
            attribute zoneId : String;
            attribute deviceId : String;
            port dataOut : DataOutPort;
            action collectData : CollectData;
            exhibit state sensorState : SensorStates;
        }
        
        part def HVACUnit {
            attribute zoneId : String;
            port commandIn : CommandInPort;
            action executeHVAC : ExecuteHVACCommand;
            exhibit state hvacState : HVACStates;
        }
        
        part def VentilationFan {
            attribute zoneId : String;
            port commandIn : CommandInPort;
            action executeFan : ExecuteFanCommand;
            exhibit state fanState : FanStates;
        }
        
        part def ActuatorSuite {
            part hvac : HVACUnit;
            part fan : VentilationFan;
        }
        
        part def Zone {
            attribute zoneId : String;
            part sensors : SensorSuite[1..*];
            part actuators : ActuatorSuite;
        }
        
        part def Gateway {
            port dataIn : DataInPort;
            port dataOut : DataOutPort;
            port commandIn : CommandInPort;
            port commandOut : CommandOutPort;
            action aggregateData : AggregateData;
            action transmitToCloud : TransmitToCloud;
            exhibit state gatewayState : GatewayStates;
        }
        
        part def CloudPlatform {
            port dataIn : DataInPort;
            port commandOut : CommandOutPort;
            port alertOut : AlertOutPort;
            port appDataOut : AppDataOutPort;
            action storeData : StoreData;
            action analyzeData : AnalyzeData;
            action generateControl : GenerateControl;
            exhibit state cloudState : CloudStates;
        }
        
        part def MobileApp {
            port alertIn : AlertInPort;
            port commandOut : CommandOutPort;
            port appDataIn : AppDataInPort;
            attribute manualOverrideEnabled : Boolean;
            action displayDashboard : DisplayDashboard;
            action displayHistory : DisplayHistoricalReports;
            action sendOverride : SendOverrideCommand;
            exhibit state appState : AppStates;
        }
    }
    
    package System {
        private import Definitions::*;
        private import Requirements::*;
        
        part def EnvironmentalMonitoringSystem {
            part zones : Zone[1..*];
            part gateway : Gateway;
            part cloud : CloudPlatform;
            part app : MobileApp;
            
            connect zones.sensors.dataOut to gateway.dataIn;
            connect gateway.dataOut to cloud.dataIn;
            connect cloud.commandOut to gateway.commandIn;
            connect gateway.commandOut to zones.actuators.hvac.commandIn;
            connect gateway.commandOut to zones.actuators.fan.commandIn;
            connect cloud.alertOut to app.alertIn;
            connect cloud.appDataOut to app.appDataIn;
            connect app.commandOut to gateway.commandIn;
            
            satisfy DataCollectionReq by zones.sensors;
            satisfy DataTransmissionReq by gateway;
            satisfy DataIntegrityReq by zones.sensors;
            satisfy CloudStorageReq by cloud;
            satisfy RealTimeAnalyticsReq by cloud;
            satisfy AutonomousControlReq by cloud;
            satisfy ActuatorResponseReq by zones.actuators;
            satisfy ManualOverrideReq by app;
            satisfy DashboardRefreshReq by app;
            satisfy AlertNotificationReq by cloud;
        }
        
        part envMonitoringSystem : EnvironmentalMonitoringSystem;
    }
}
