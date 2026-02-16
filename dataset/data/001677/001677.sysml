package OpenpicusIoTSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SSID;
    attribute def IPAddress;
    attribute def MACAddress;
    
    item def WiFiCredentials {
        attribute networkSSID : SSID;
        attribute password : String;
        attribute securityType : String;
    }
    
    item def SensorReading {
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute pressure : PressureValue;
    }
    
    item def HTTPRequest {
        attribute method : String;
        attribute endpoint : String;
        attribute headers : String[*];
        attribute payload : String;
    }
    
    item def HTTPResponse {
        attribute statusCode : Integer;
        attribute body : String;
        attribute timestamp : TimeValue;
    }
    
    item def ControlMessage {
        attribute deviceID : String;
        attribute command : String;
        attribute parameters : String[*];
    }
    
    port def WiFiPort {
        in item credentials : WiFiCredentials;
        out item connectionStatus : String;
        in item txData : HTTPRequest;
        out item rxData : HTTPResponse;
    }
    
    port def SensorDataPort {
        out item reading : SensorReading;
        in item samplingConfig : FrequencyValue;
    }
    
    port def ControlInterfacePort {
        in item controlMsg : ControlMessage;
        out item statusResponse : String;
    }
    
    port def PowerPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    part def WiFiTransceiver {
        attribute macAddr : MACAddress;
        attribute ipAddr : IPAddress;
        attribute signalStrength : Real;
        attribute isConnected : Boolean;
        
        port wifiInterface : WiFiPort;
        
        action def EstablishConnection {
            in credentials : WiFiCredentials;
            out connected : Boolean;
            out assignedIP : IPAddress;
        }
        
        action def TransmitHTTP {
            in request : HTTPRequest;
            out response : HTTPResponse;
            out success : Boolean;
        }
        
        action def ReceiveData {
            out incomingData : HTTPResponse;
        }
    }
    
    part def PIC32Microcontroller {
        attribute clockSpeed : FrequencyValue;
        attribute ramSize : Integer;
        attribute flashSize : Integer;
        
        port controlInterface : ControlInterfacePort;
        
        action def ProcessSensorData {
            in rawData : SensorReading;
            out processedData : SensorReading;
        }
        
        action def ExecuteCommand {
            in command : ControlMessage;
            out result : String;
        }
        
        action def FormatHTTPPayload {
            in sensorData : SensorReading;
            out request : HTTPRequest;
        }
    }
    
    part def EnvironmentalSensor {
        attribute sensorType : String;
        attribute measurementRange_min : Real;
        attribute measurementRange_max : Real;
        attribute accuracy : Real;
        
        port dataOutput : SensorDataPort;
        
        action def AcquireReading {
            out temperature : TemperatureValue;
            out humidity : Real;
            out pressure : PressureValue;
        }
        
        action def Calibrate {
            in referenceValue : Real;
            out calibrationFactor : Real;
        }
    }
    
    part def PowerManagementUnit {
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute efficiency : Real;
        
        port powerSupply : PowerPort;
        
        action def RegulateVoltage {
            in inputV : ElectricPotentialValue;
            out outputV : ElectricPotentialValue;
        }
        
        action def MonitorPowerConsumption {
            out currentDraw : ElectricCurrentValue;
            out powerUsage : PowerValue;
        }
    }
    
    part def OpenpicusFlyportModule {
        doc /* 
            Openpicus Flyport WiFi-enabled microcontroller module integrating
            PIC32 processor with IEEE 802.11 wireless connectivity for IoT applications.
        */
        
        attribute moduleModel : String;
        attribute firmwareVersion : String;
        attribute operatingVoltage : ElectricPotentialValue;
        
        part processor : PIC32Microcontroller {
            attribute :>> clockSpeed = 80.0 [SI::Hz];
            attribute :>> ramSize = 32768;
            attribute :>> flashSize = 262144;
        }
        
        part wifiModule : WiFiTransceiver {
            attribute :>> signalStrength = 0.8;
            attribute :>> isConnected = false;
        }
        
        part envSensor : EnvironmentalSensor {
            attribute :>> sensorType = "DHT22";
            attribute :>> measurementRange_min = -40.0;
            attribute :>> measurementRange_max = 80.0;
            attribute :>> accuracy = 0.5;
        }
        
        part powerMgmt : PowerManagementUnit {
            attribute :>> inputVoltage = 5.0 [SI::V];
            attribute :>> outputVoltage = 3.3 [SI::V];
            attribute :>> efficiency = 0.85;
        }
        
        connect envSensor.dataOutput to processor.controlInterface;
        connect processor.controlInterface to wifiModule.wifiInterface;
        connect powerMgmt.powerSupply to processor.controlInterface;
    }
    
    action def MonitorEnvironmentalConditions {
        in pollingInterval : DurationValue;
        out dataHistory : SensorReading[*];
        
        private attribute currentReading : SensorReading;
        private attribute readingLog : SensorReading[*] := ();
        
        first start;
        then merge continuousMonitoring;
        
        action acquireSensorData {
            out temp : TemperatureValue;
            out hum : Real;
            out press : PressureValue;
        }
        
        then action packageReading {
            in temperature : TemperatureValue = acquireSensorData.temp;
            in humidity : Real = acquireSensorData.hum;
            in pressure : PressureValue = acquireSensorData.press;
            out reading : SensorReading;
        }
        
        then assign currentReading := packageReading.reading;
        then assign readingLog := readingLog;
        
        action waitForNextSample {
            in interval : DurationValue = pollingInterval;
        }
        
        then continuousMonitoring;
    }
    
    action def TransmitDataToCloud {
        in sensorData : SensorReading;
        in serverEndpoint : String;
        out transmissionSuccess : Boolean;
        
        first start;
        
        action formatPayload {
            in data : SensorReading = sensorData;
            out httpRequest : HTTPRequest;
        }
        
        then action sendRequest {
            in request : HTTPRequest = formatPayload.httpRequest;
            out response : HTTPResponse;
        }
        
        then decide;
            if sendRequest.response.statusCode == 200 then success;
            if sendRequest.response.statusCode != 200 then retry;
        
        action success {
            out result : Boolean = true;
        }
        then assign transmissionSuccess := success.result;
        then done;
        
        action retry {
            in request : HTTPRequest = formatPayload.httpRequest;
        }
        then sendRequest;
    }
    
    action def IoTOperationalCycle {
        in networkConfig : WiFiCredentials;
        in cloudEndpoint : String;
        in samplingPeriod : DurationValue;
        out systemStatus : String;
        
        first start;
        
        action connectToNetwork {
            in credentials : WiFiCredentials = networkConfig;
            out connectionEstablished : Boolean;
        }
        
        then decide;
            if connectToNetwork.connectionEstablished then beginOperations;
            if not connectToNetwork.connectionEstablished then retryConnection;
        
        action retryConnection {
            in credentials : WiFiCredentials = networkConfig;
        }
        then connectToNetwork;
        
        merge beginOperations;
        
        action monitoringLoop : MonitorEnvironmentalConditions {
            in pollingInterval = samplingPeriod;
            out dataHistory;
        }
        
        action transmissionLoop : TransmitDataToCloud {
            in sensorData = monitoringLoop.currentReading;
            in serverEndpoint = cloudEndpoint;
            out transmissionSuccess;
        }
        
        then assign systemStatus := "IoT system operational";
        then done;
    }
    
    state def OpenpicusSystemState {
        attribute systemStatus : String;
        
        entry; then powerOn;
        
        state powerOn {
            entry assign systemStatus := "System initializing";
        }
        
        state connecting {
            entry assign systemStatus := "Establishing WiFi connection";
        }
        
        state active {
            entry assign systemStatus := "Active - monitoring and transmitting";
        }
        
        state errorState {
            entry assign systemStatus := "Error - attempting recovery";
        }
        
        transition powerOn_to_connecting
            first powerOn
            then connecting;
        
        transition connecting_to_active
            first connecting
            then active;
        
        transition connecting_to_error
            first connecting
            then errorState;
        
        transition error_to_connecting
            first errorState
            then connecting;
        
        transition active_to_powerOn
            first active
            then powerOn;
    }
    
    part openpicusIoTDevice : OpenpicusFlyportModule {
        attribute :>> moduleModel = "Flyport WiFi";
        attribute :>> firmwareVersion = "3.1.2";
        attribute :>> operatingVoltage = 3.3 [SI::V];
        
        perform action mainOperation : IoTOperationalCycle {
            in networkConfig {
                attribute networkSSID = "IoT_Network";
                attribute password = "securepass123";
                attribute securityType = "WPA2";
            }
            in cloudEndpoint = "https://api.iotcloud.com/data";
            in samplingPeriod = 10.0 [SI::s];
            out systemStatus;
        }
        
        exhibit state deviceBehavior : OpenpicusSystemState;
    }
    
    requirement def <'REQ-FUN-001'> WiFiConnectivityRequirement {
        doc /* 
            The Openpicus system shall establish and maintain WiFi connectivity
            to the configured network within 30 seconds of power-on.
        */
        
        subject device : OpenpicusFlyportModule;
        
        require constraint {
            device.wifiModule.isConnected == true
        }
    }
    
    requirement def <'REQ-FUN-002'> DataAcquisitionRequirement {
        doc /* 
            The system shall acquire environmental sensor data at configurable
            intervals between 1 and 60 seconds with timestamp accuracy of ±1 second.
        */
        
        subject sensor : EnvironmentalSensor;
        
        require constraint {
            sensor.accuracy <= 1.0
        }
    }
    
    requirement def <'REQ-FUN-003'> CloudTransmissionRequirement {
        doc /* 
            The system shall transmit sensor readings to the cloud endpoint
            via HTTP POST with JSON payload format and receive acknowledgment.
        */
        
        subject device : OpenpicusFlyportModule;
    }
    
    requirement def <'REQ-PERF-001'> PowerConsumptionRequirement {
        doc /* 
            The Openpicus module shall operate with average power consumption
            not exceeding 500 mW during normal operation.
        */
        
        subject pmu : PowerManagementUnit;
        
        require constraint {
            pmu.efficiency >= 0.80
        }
    }
    
    requirement def <'REQ-PERF-002'> SensorAccuracyRequirement {
        doc /* 
            Temperature measurements shall maintain accuracy within ±0.5°C
            and humidity within ±2% RH across the operating range.
        */
        
        subject sensor : EnvironmentalSensor;
        
        require constraint {
            sensor.accuracy <= 0.5
        }
    }
    
    requirement <'SYS-REQ-001'> openpicusSystemRequirement {
        doc /* 
            The Openpicus-based IoT system shall provide WiFi-enabled environmental
            monitoring with autonomous data acquisition, processing, and cloud
            transmission capabilities for remote sensing applications.
        */
        
        subject openpicusIoTDevice;
        
        require WiFiConnectivityRequirement;
        require DataAcquisitionRequirement;
        require CloudTransmissionRequirement;
        require PowerConsumptionRequirement;
        require SensorAccuracyRequirement;
    }
}
