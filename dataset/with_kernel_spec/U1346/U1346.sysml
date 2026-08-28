package SmartHomeAutomation {
    private import ScalarValues::*;
    private import SI::*;

    package ValueTypes {
        attribute def Temperature :> Real;
        attribute def Humidity :> Real;
        attribute def Power :> Real;
        attribute def Latency :> Real;
        attribute def Distance :> Real;
        attribute def TimeDuration :> Real;
    }

    package Definitions {
        private import ValueTypes::*;

        item def SensorData {
            attribute temp : Temperature;
            attribute hum : Humidity;
        }
        item def MotionEvent {
            attribute detected : Boolean;
            attribute distance : Distance;
        }
        item def LightCommand {
            attribute isOn : Boolean;
            attribute brightness : Integer;
        }
        item def RegistrationRequest {
            attribute deviceId : String;
            attribute deviceType : String;
        }
        item def RegistrationResponse {
            attribute success : Boolean;
            attribute assignedId : String;
        }

        port def CoAPPort {
            in item sensorData : SensorData;
            in item motionEvent : MotionEvent;
            out item lightCmd : LightCommand;
            in item regReq : RegistrationRequest;
            out item regResp : RegistrationResponse;
        }

        occurrence def PowerOn;
        occurrence def InitComplete;
        occurrence def NetworkFound;
        occurrence def RegistrationAck;
        occurrence def PowerOff;

        state def DeviceLifecycle {
            initial state PoweredOff;
            state Initializing;
            state Discovering;
            state Registering;
            state Operational;

            transition from PoweredOff to Initializing accept PowerOn;
            transition from Initializing to Discovering accept InitComplete;
            transition from Discovering to Registering accept NetworkFound;
            transition from Registering to Operational accept RegistrationAck;
            transition from Operational to PoweredOff accept PowerOff;
        }

        part def SmartHomeServer {
            attribute maxDevices : Integer = 100;
            port coapIF : CoAPPort;
            action monitoringControlLoop : MonitoringControlLoop;
        }

        action def MonitoringControlLoop {
            in data : SensorData;
            out cmd : LightCommand;
            first start;
            then decide;
            if data.temp > 25.0 then turnOnLight;
            else monitor;

            action turnOnLight {
                out lightCmd : LightCommand;
            }
            action monitor;
        }

        part def NetworkGateway {
            port serverIF : ~CoAPPort;
            port deviceIF : CoAPPort;
        }

        part def ConnectedDevice {
            port coapIF : ~CoAPPort;
            attribute deviceId : String;
            state deviceLifecycle : DeviceLifecycle;
        }

        part def TempHumiditySensor :> ConnectedDevice {
            attribute sampleInterval : TimeDuration = 10.0;
            action sampleAndReport : SampleAndReport;
        }

        action def SampleAndReport {
            out data : SensorData;
        }

        part def MotionSensor :> ConnectedDevice {
            attribute detectionRange : Distance = 5.0;
            action detectMotion : DetectMotion;
        }

        action def DetectMotion {
            out event : MotionEvent;
        }

        part def SmartLightActuator :> ConnectedDevice {
            attribute isOn : Boolean = false;
            attribute brightness : Integer = 0;
            action executeCommand : ExecuteCommand;
        }

        action def ExecuteCommand {
            in cmd : LightCommand;
        }
    }

    package Usages {
        private import Definitions::*;

        part smartHomeSystem {
            part server : SmartHomeServer;
            part gateway : NetworkGateway;
            connect server.coapIF to gateway.serverIF;

            part livingRoomSensor : TempHumiditySensor;
            connect livingRoomSensor.coapIF to gateway.deviceIF;

            part bedroomSensor : TempHumiditySensor;
            connect bedroomSensor.coapIF to gateway.deviceIF;

            part entranceMotionSensor : MotionSensor;
            connect entranceMotionSensor.coapIF to gateway.deviceIF;

            part livingRoomLight : SmartLightActuator;
            connect livingRoomLight.coapIF to gateway.deviceIF;
        }
    }

    package Requirements {
        private import ValueTypes::*;

        requirement def MaxDeviceCapacityReq {
            doc /* The central server shall manage up to 100 connected devices. */
            attribute maxDevices : Integer = 100;
            attribute currentDevices : Integer;
            require constraint { currentDevices <= maxDevices }
        }

        requirement def NetworkLatencyReq {
            doc /* Network communication delays shall be kept under 200 milliseconds. */
            attribute commDelay : Latency;
            attribute maxDelay : Latency = 200.0;
            require constraint { commDelay <= maxDelay }
        }

        requirement def PowerEfficiencyReq {
            doc /* Total operational power consumption shall be less than 50 watts. */
            attribute totalPower : Power;
            attribute maxPower : Power = 50.0;
            require constraint { totalPower <= maxPower }
        }

        requirement def MotionDetectionRangeReq {
            doc /* Motion sensors shall detect movement within a five-meter range. */
            attribute sensorRange : Distance;
            attribute requiredRange : Distance = 5.0;
            require constraint { sensorRange >= requiredRange }
        }
    }
}
