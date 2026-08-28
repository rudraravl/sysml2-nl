package WeatherMonitoringSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    package Definitions {
        item def Power {
            attribute voltage :> ISQ::electricPotential;
            attribute current :> ISQ::electricCurrent;
        }
        item def WeatherData {
            attribute temperature :> ISQ::temperature;
            attribute humidity : Real;
            attribute timestamp : String;
        }
        item def NetworkData {
            attribute payload : WeatherData;
            attribute destination : String;
        }
        item def LEDCommand {
            attribute ledState : String;
        }

        port def PowerPort {
            in item power : Power;
        }
        port def SensorDataPort {
            out item data : WeatherData;
        }
        port def NetworkPort {
            in item rxData : NetworkData;
            out item txData : NetworkData;
        }
        port def LEDPort {
            out item command : LEDCommand;
        }

        attribute def PowerOnSignal;
        attribute def WiFiConnectedSignal;
        attribute def WiFiFailedSignal;
        attribute def SensorDataReadySignal;
        attribute def SensorReadFailSignal;
        attribute def DataProcessedSignal;
        attribute def TransmissionCompleteSignal;
        attribute def TransmissionFailSignal;
        attribute def ErrorEvent;
        attribute def ResetEvent;

        action def ConnectWiFi {
            in attribute ssid : String;
            in attribute password : String;
            out attribute success : Boolean;
        }
        action def ReadSensor {
            out item data : WeatherData;
        }
        action def ProcessData {
            in item rawData : WeatherData;
            in attribute serverAddress : String;
            out item networkData : NetworkData;
        }
        action def TransmitData {
            in item data : NetworkData;
            out attribute success : Boolean;
        }
        action def HandleError {
            in attribute errorType : String;
            out attribute recovered : Boolean;
        }
        action def BlinkLED {
            in attribute pattern : String;
        }
        action def ReceiveData {
            in item data : NetworkData;
        }

        part def USBPowerSupply {
            out port powerOut : PowerPort;
            attribute outputVoltage :> ISQ::electricPotential = 5.0[V];
            attribute outputCurrent :> ISQ::electricCurrent = 1.0[A];
        }

        part def VoltageRegulator {
            in port powerIn : PowerPort;
            out port powerOut : PowerPort;
            attribute regulatedVoltage :> ISQ::electricPotential = 3.3[V];
        }

        part def DHT22 {
            out port dataPort : SensorDataPort;
            attribute temperature :> ISQ::temperature;
            attribute humidity : Real;
            perform action readSensor : ReadSensor;
        }

        part def BlueLED {
            in port powerPort : PowerPort;
            in port controlPort : LEDPort;
            attribute color : String = "blue";
            attribute isOn : Boolean = false;
        }

        part def ESP8266 {
            in port powerPort : PowerPort;
            in port sensorPort : SensorDataPort;
            out port ledPort : LEDPort;
            port networkPort : NetworkPort;
            attribute wifiSSID : String;
            attribute wifiPassword : String;
            attribute serverAddress : String;
            attribute sampleInterval :> ISQ::time = 60[s];

            perform action connectWiFi : ConnectWiFi;
            perform action readSensor : ReadSensor;
            perform action processData : ProcessData;
            perform action transmitData : TransmitData;
            perform action handleError : HandleError;
            perform action blinkLED : BlinkLED;

            exhibit state controllerStates parallel {
                state operationalStates {
                    entry action initial;
                    state off;
                    state initializing {
                        do blinkLED;
                    }
                    state connectingWiFi {
                        do connectWiFi;
                    }
                    state connected;
                    state measuring {
                        do readSensor;
                    }
                    state processing {
                        do processData;
                    }
                    state transmitting {
                        do transmitData;
                    }
                    state errorState {
                        do handleError;
                        do blinkLED;
                    }

                    transition initial then off;
                    transition off_to_initializing
                        first off
                        accept PowerOnSignal
                        then initializing;
                    transition initializing_to_connecting
                        first initializing
                        then connectingWiFi;
                    transition connecting_to_connected
                        first connectingWiFi
                        accept WiFiConnectedSignal
                        then connected;
                    transition connecting_to_error
                        first connectingWiFi
                        accept WiFiFailedSignal
                        then errorState;
                    transition connected_to_measuring
                        first connected
                        accept SensorDataReadySignal
                        then measuring;
                    transition measuring_to_processing
                        first measuring
                        accept SensorDataReadySignal
                        then processing;
                    transition measuring_to_error
                        first measuring
                        accept SensorReadFailSignal
                        then errorState;
                    transition processing_to_transmitting
                        first processing
                        accept DataProcessedSignal
                        then transmitting;
                    transition transmitting_to_connected
                        first transmitting
                        accept TransmissionCompleteSignal
                        then connected;
                    transition transmitting_to_error
                        first transmitting
                        accept TransmissionFailSignal
                        then errorState;
                    transition error_to_connecting
                        first errorState
                        accept ResetEvent
                        then connectingWiFi;
                }
            }
        }

        part def NodeMCU {
            attribute deviceID : String;
            part powerSupply : USBPowerSupply;
            part regulator : VoltageRegulator;
            part esp8266 : ESP8266;
            part dht22 : DHT22;
            part statusLED : BlueLED;

            connection powerToRegulator connect powerSupply.powerOut to regulator.powerIn;
            connection regulatorToESP connect regulator.powerOut to esp8266.powerPort;
            connection regulatorToLED connect regulator.powerOut to statusLED.powerPort;
            connection sensorToESP connect dht22.dataPort to esp8266.sensorPort;
            connection espToLED connect esp8266.ledPort to statusLED.controlPort;
        }

        part def RemoteServer {
            port networkPort : NetworkPort;
            perform action receiveData : ReceiveData;
        }

        requirement def SystemRequirements {
            subject nodeMcu : NodeMCU;
            doc /* The system shall autonomously collect environmental data and transmit it wirelessly to a remote server. */
        }
        requirement def PowerRequirement {
            subject powerSupply : USBPowerSupply;
            subject regulator : VoltageRegulator;
            doc /* The system shall be powered by a standard USB power supply with voltage regulation to 3.3V. */
        }
        requirement def SensingRequirement {
            subject sensor : DHT22;
            doc /* The system shall measure ambient temperature and humidity using a DHT22 sensor. */
        }
        requirement def TransmissionRequirement {
            subject esp : ESP8266;
            subject server : RemoteServer;
            doc /* The system shall transmit sensor data to a remote server over WiFi. */
        }
        requirement def ErrorHandlingRequirement {
            subject esp : ESP8266;
            doc /* The system shall handle WiFi and sensor errors with recovery logic. */
        }
        requirement def StatusIndicatorRequirement {
            subject led : BlueLED;
            doc /* The system shall indicate operational status via a blue LED. */
        }
    }

    package Usages {
        private import Definitions::*;

        part weatherStation : NodeMCU {
            attribute deviceID = "weather-001";
            part esp8266 : ESP8266 {
                attribute wifiSSID = "MyWiFi";
                attribute wifiPassword = "secret";
                attribute serverAddress = "http://server.example.com/data";
            }
        }

        part remoteServer : RemoteServer;

        connection wifiLink connect weatherStation.esp8266.networkPort to remoteServer.networkPort;

        requirement systemReq : SystemRequirements {
            subject nodeMcu = weatherStation;
        }
        requirement powerReq : PowerRequirement {
            subject powerSupply = weatherStation.powerSupply;
            subject regulator = weatherStation.regulator;
        }
        requirement sensingReq : SensingRequirement {
            subject sensor = weatherStation.dht22;
        }
        requirement transmissionReq : TransmissionRequirement {
            subject esp = weatherStation.esp8266;
            subject server = remoteServer;
        }
        requirement errorReq : ErrorHandlingRequirement {
            subject esp = weatherStation.esp8266;
        }
        requirement statusReq : StatusIndicatorRequirement {
            subject led = weatherStation.statusLED;
        }
    }
}
