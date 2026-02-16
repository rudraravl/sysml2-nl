package NodeMCUWeatherMonitoringSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def WiFiSSID;
    attribute def WiFiPassword;
    attribute def ServerURL;
    attribute def MACAddress;
    
    attribute def TemperatureValue :> ISQ::TemperatureValue;
    attribute def HumidityValue :> Real;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def CurrentValue :> ISQ::CurrentValue;
    attribute def FrequencyValue :> ISQ::FrequencyValue;
    attribute def TimeValue :> ISQ::DurationValue;
    
    item def SensorReading {
        attribute timestamp : TimeValue;
        attribute temperature : TemperatureValue;
        attribute humidity : HumidityValue;
    }
    
    port def PowerPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def WiFiPort {
        in ssid : WiFiSSID;
        in password : WiFiPassword;
        out macAddress : MACAddress;
        in dataToTransmit : SensorReading;
        out transmissionStatus : Boolean;
    }
    
    port def I2CPort {
        attribute sclPin : Integer;
        attribute sdaPin : Integer;
    }
    
    port def GPIOPort {
        attribute pinNumber : Integer;
        in digitalInput : Boolean;
        out digitalOutput : Boolean;
    }
    
    part def ESP8266Controller {
        attribute clockFrequency : FrequencyValue;
        attribute flashMemorySize : Real;
        attribute ramSize : Real;
        
        port wifi : WiFiPort;
        port i2c : I2CPort;
        port gpio : GPIOPort[16];
        port powerInput : PowerPort;
    }
    
    part def DHT22Sensor {
        attribute temperatureAccuracy : TemperatureValue;
        attribute humidityAccuracy : HumidityValue;
        attribute measurementRangeMin : TemperatureValue;
        attribute measurementRangeMax : TemperatureValue;
        
        port dataPin : GPIOPort;
        port power : PowerPort;
    }
    
    part def VoltageRegulator {
        attribute inputVoltageMin : VoltageValue;
        attribute inputVoltageMax : VoltageValue;
        attribute outputVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
        
        port input : PowerPort;
        port output : PowerPort;
    }
    
    part def USBPowerSupply {
        attribute nominalVoltage : VoltageValue;
        attribute maxCurrent : CurrentValue;
        
        port output : PowerPort;
    }
    
    part def StatusLED {
        attribute color : String;
        
        port control : GPIOPort;
        port power : PowerPort;
    }
    
    action def InitializeWiFi {
        in ssid : WiFiSSID;
        in password : WiFiPassword;
        out connected : Boolean;
        out assignedIP : ServerURL;
    }
    
    action def ReadEnvironmentalData {
        out temperature : TemperatureValue;
        out humidity : HumidityValue;
        out readSuccess : Boolean;
    }
    
    action def PackageData {
        in temperature : TemperatureValue;
        in humidity : HumidityValue;
        in currentTime : TimeValue;
        out dataPacket : SensorReading;
    }
    
    action def TransmitToServer {
        in dataPacket : SensorReading;
        in serverURL : ServerURL;
        out transmitSuccess : Boolean;
    }
    
    action def UpdateStatusIndicator {
        in systemState : Boolean;
    }
    
    action def MonitorAndReport {
        in wifiSSID : WiFiSSID;
        in wifiPassword : WiFiPassword;
        in serverAddress : ServerURL;
        in samplingInterval : TimeValue;
        out operationStatus : Boolean;
        
        first start;
        then action initialize : InitializeWiFi {
            in ssid = wifiSSID;
            in password = wifiPassword;
            out connected;
            out assignedIP;
        }
        
        then decide;
            if initialize.connected then monitoringCycle;
            if !initialize.connected then failureEnd;
        
        action monitoringCycle {
            first merge cycleStart;
            then action readSensors : ReadEnvironmentalData {
                out temperature;
                out humidity;
                out readSuccess;
            }
            
            then decide;
                if readSensors.readSuccess then processData;
                if !readSensors.readSuccess then cycleStart;
            
            action processData : PackageData {
                in temperature = readSensors.temperature;
                in humidity = readSensors.humidity;
                in currentTime = samplingInterval;
                out dataPacket;
            }
            
            then action transmit : TransmitToServer {
                in dataPacket = processData.dataPacket;
                in serverURL = serverAddress;
                out transmitSuccess;
            }
            
            then action updateLED : UpdateStatusIndicator {
                in systemState = transmit.transmitSuccess;
            }
            
            then cycleStart;
        }
        
        action failureEnd;
        then done;
    }
    
    state def SystemOperationalState {
        entry; then initializing;
        
        state initializing {
            entry action initWiFi : InitializeWiFi;
        }
        
        state idle;
        
        state measuring {
            do action measure : ReadEnvironmentalData;
        }
        
        state processing {
            do action package : PackageData;
        }
        
        state transmitting {
            do action transmit : TransmitToServer;
        }
        
        state error;
        
        transition init_to_idle
            first initializing
            accept wifiConnected
            then idle;
        
        transition init_to_error
            first initializing
            accept wifiFailed
            then error;
        
        transition idle_to_measuring
            first idle
            accept startMeasurement
            then measuring;
        
        transition measuring_to_processing
            first measuring
            accept measurementComplete
            then processing;
        
        transition measuring_to_error
            first measuring
            accept measurementFailed
            then error;
        
        transition processing_to_transmitting
            first processing
            accept dataReady
            then transmitting;
        
        transition transmitting_to_idle
            first transmitting
            accept transmitComplete
            then idle;
        
        transition transmitting_to_error
            first transmitting
            accept transmitFailed
            then error;
        
        transition error_to_initializing
            first error
            accept resetSystem
            then initializing;
    }
    
    part def NodeMCUWeatherStation {
        part controller : ESP8266Controller {
            :>> clockFrequency = 80.0 [SI::MHz];
            :>> flashMemorySize = 4.0;
            :>> ramSize = 80.0;
        }
        
        part sensor : DHT22Sensor {
            :>> temperatureAccuracy = 273.65 [SI::K];
            :>> humidityAccuracy = 2.0;
            :>> measurementRangeMin = 233.15 [SI::K];
            :>> measurementRangeMax = 353.15 [SI::K];
        }
        
        part regulator : VoltageRegulator {
            :>> inputVoltageMin = 4.5 [SI::V];
            :>> inputVoltageMax = 10.0 [SI::V];
            :>> outputVoltage = 3.3 [SI::V];
            :>> maxCurrent = 0.8 [SI::A];
        }
        
        part powerSupply : USBPowerSupply {
            :>> nominalVoltage = 5.0 [SI::V];
            :>> maxCurrent = 1.0 [SI::A];
        }
        
        part indicator : StatusLED {
            :>> color = "blue";
        }
        
        connection powerInput connect powerSupply.output to regulator.input;
        connection regulatedPower connect regulator.output to controller.powerInput;
        connection sensorPower connect regulator.output to sensor.power;
        connection ledPower connect regulator.output to indicator.power;
        connection sensorData connect sensor.dataPin to controller.gpio[2];
        connection ledControl connect controller.gpio[1] to indicator.control;
        
        perform action systemBehavior : MonitorAndReport;
        
        part operationalController {
            exhibit state operationalState : SystemOperationalState;
        }
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* 
            The NodeMCU Weather Monitoring System shall continuously measure ambient 
            temperature and humidity using an integrated DHT22 sensor and transmit 
            the collected environmental data to a remote server via WiFi connectivity 
            at regular intervals for real-time monitoring and analysis.
        */
        
        subject weatherStation : NodeMCUWeatherStation;
    }
    
    requirement def MeasurementAccuracyRequirement {
        doc /* 
            Temperature measurements shall maintain accuracy within ±0.5 Kelvin 
            and humidity measurements within ±2% relative humidity across the 
            operational range.
        */
        
        subject weatherStation : NodeMCUWeatherStation;
    }
    
    requirement def DataTransmissionRequirement {
        doc /* 
            The system shall transmit sensor readings to the configured server 
            at intervals not exceeding 60 seconds with a success rate of at least 95%.
        */
        
        subject weatherStation : NodeMCUWeatherStation;
    }
    
    requirement def PowerConsumptionRequirement {
        doc /* 
            The system shall operate within USB power specifications, consuming 
            no more than 5V at 500mA during normal operation.
        */
        
        subject weatherStation : NodeMCUWeatherStation;
    }
    
    requirement def ConnectivityRequirement {
        doc /* 
            The system shall establish WiFi connectivity within 30 seconds of 
            power-on and maintain connection stability with automatic reconnection 
            capability in case of network interruption.
        */
        
        subject weatherStation : NodeMCUWeatherStation;
    }
    
    requirement systemMissionRequirement {
        doc /* 
            The NodeMCU Weather Monitoring System shall provide autonomous, 
            continuous environmental monitoring with wireless data transmission 
            capabilities for remote weather observation applications.
        */
        
        require PrimaryFunctionRequirement;
        require MeasurementAccuracyRequirement;
        require DataTransmissionRequirement;
        require PowerConsumptionRequirement;
        require ConnectivityRequirement;
    }
    
    part weatherMonitoringStation : NodeMCUWeatherStation {
        doc /* 
            Instantiation of the NodeMCU-based weather monitoring system configured 
            for continuous environmental data collection and wireless transmission.
        */
        
        satisfy systemMissionRequirement;
    }
}
