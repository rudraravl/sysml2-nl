package 'IoT Environmental Monitor' {
    private import ScalarValues::*;
    private import ISQ::*;

    package Definitions {
        attribute def TemperatureValue;
        attribute def HumidityValue;
        attribute def PressureValue;
        attribute def VoltageValue;
        attribute def PowerValue;

        attribute def PowerUp;
        attribute def InitComplete;
        attribute def ConnectionSuccess;
        attribute def ConnectionFailure;
        attribute def Retry;
        attribute def DataReady;
        attribute def PackageReady;
        attribute def TransmissionComplete;

        item def SensorReading {
            attribute temp : TemperatureValue;
            attribute humidity : HumidityValue;
            attribute pressure : PressureValue;
        }

        item def HTTPRequest {
            attribute method : String;
            attribute payload : SensorReading;
        }

        item def CloudMessage {
            attribute payload : HTTPRequest;
            attribute timestamp : String;
        }

        port def PowerPort {
            out voltage : VoltageValue;
        }

        port def SensorDataPort {
            out reading : SensorReading;
        }

        port def HTTPPort {
            out request : HTTPRequest;
        }

        port def CloudPort {
            out message : CloudMessage;
        }

        action def Initialize;
        action def ConnectWiFi;
        action def GatherSensorData { out reading : SensorReading; }
        action def PackageData { in reading : SensorReading; out request : HTTPRequest; }
        action def TransmitData { in request : HTTPRequest; }
        action def MonitorEnergy { out consumption : PowerValue; }

        state def DeviceStates;

        part def EnvironmentalSensor {
            port powerIn : ~PowerPort;
            port dataOut : SensorDataPort;
            perform action 'gather sensor data' : GatherSensorData;
        }

        part def PIC32Microcontroller {
            port powerIn : ~PowerPort;
            port dataIn : ~SensorDataPort;
            port httpOut : HTTPPort;
            perform action 'package data' : PackageData;
        }

        part def WiFiTransceiver {
            port powerIn : ~PowerPort;
            port httpIn : ~HTTPPort;
            port cloudOut : CloudPort;
            perform action 'connect wifi' : ConnectWiFi;
            perform action 'transmit data' : TransmitData;
        }

        part def PowerManagementUnit {
            port powerIn : ~PowerPort;
            port powerOut : PowerPort;
            perform action 'monitor energy' : MonitorEnergy;
        }

        part def FlyportModule {
            part sensor : EnvironmentalSensor;
            part mcu : PIC32Microcontroller;
            part wifi : WiFiTransceiver;
            connect sensor.dataOut to mcu.dataIn;
            connect mcu.httpOut to wifi.httpIn;
        }

        part def IoTDevice {
            part pmu : PowerManagementUnit;
            part flyport : FlyportModule;
            port powerIn : ~PowerPort;
            port cloudOut : CloudPort;
            perform action 'initialize' : Initialize;
            perform action 'connect wifi' : ConnectWiFi;
            perform action 'gather sensor data' : GatherSensorData;
            perform action 'package data' : PackageData;
            perform action 'transmit data' : TransmitData;
            perform action 'monitor energy' : MonitorEnergy;
            connect powerIn to pmu.powerIn;
            connect pmu.powerOut to flyport.sensor.powerIn;
            connect pmu.powerOut to flyport.mcu.powerIn;
            connect pmu.powerOut to flyport.wifi.powerIn;
            connect flyport.wifi.cloudOut to cloudOut;
            exhibit state 'device states' : DeviceStates;
        }

        part def CloudServer {
            port cloudIn : ~CloudPort;
        }

        requirement def EnvironmentalSensingRequirement {
            attribute text : String;
        }

        requirement def WiFiConnectivityRequirement {
            attribute text : String;
        }

        requirement def CloudTransmissionRequirement {
            attribute text : String;
        }

        requirement def PowerManagementRequirement {
            attribute text : String;
        }

        requirement def AutonomousOperationRequirement {
            attribute text : String;
        }
    }

    package Usages {
        private import Definitions::*;

        part device : IoTDevice {
            state 'device states' : DeviceStates parallel {
                state 'operational states' {
                    entry; then off;
                    state off;
                    accept PowerUp then initializing;
                    state initializing {
                        do 'initialize';
                    }
                    accept InitComplete then connecting;
                    state connecting {
                        do 'connect wifi';
                    }
                    accept ConnectionSuccess then active;
                    accept ConnectionFailure then error;
                    state error;
                    accept Retry then connecting;
                    state active {
                        entry; then gathering;
                        state gathering {
                            do 'gather sensor data';
                        }
                        accept DataReady then packaging;
                        state packaging {
                            do 'package data';
                        }
                        accept PackageReady then transmitting;
                        state transmitting {
                            do 'transmit data';
                        }
                        accept TransmissionComplete then gathering;
                    }
                }
                state 'power monitoring' {
                    do 'monitor energy';
                }
            }
        }

        part cloud : CloudServer;

        connect device.cloudOut to cloud.cloudIn;

        requirement sensingReq : EnvironmentalSensingRequirement {
            text = "The device shall measure temperature, humidity, and atmospheric pressure using an integrated sensor.";
        }

        requirement wifiReq : WiFiConnectivityRequirement {
            text = "The device shall connect to a configured WiFi network and retry on connection failure.";
        }

        requirement cloudReq : CloudTransmissionRequirement {
            text = "The device shall transmit sensor data to a cloud server using HTTP requests.";
        }

        requirement powerReq : PowerManagementRequirement {
            text = "The power management unit shall regulate input voltage and monitor energy consumption.";
        }

        requirement autoReq : AutonomousOperationRequirement {
            text = "The device shall autonomously cycle through sensing, packaging, and transmission without manual intervention.";
        }

        satisfy sensingReq by device;
        satisfy wifiReq by device;
        satisfy cloudReq by device;
        satisfy powerReq by device.pmu;
        satisfy autoReq by device;
    }
}
