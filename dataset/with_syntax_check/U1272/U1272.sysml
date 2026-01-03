package ArduinoEnvironmentalMonitor {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SensorData {
        temperature : TemperatureValue;
        humidity : Real;
        lightLevel : Real;
        timestamp : TimeValue;
    }
    
    attribute def AlertThreshold {
        maxTemp : TemperatureValue;
        minTemp : TemperatureValue;
        maxHumidity : Real;
    }
    
    attribute def SystemCommand;
    attribute def AlertSignal;
    
    enum def OperatingMode {
        enum normalMonitoring;
        enum alertActive;
        enum calibration;
        enum standby;
    }
    
    port def SensorPort {
        out data : SensorData;
    }
    
    port def DisplayPort {
        in displayData : SensorData;
    }
    
    port def AlertPort {
        out alert : AlertSignal;
    }
    
    port def PowerSupplyPort {
        in voltage : ElectricPotentialValue;
        in current : ElectricCurrentValue;
    }
    
    port def CommunicationPort {
        in rxData : SensorData[*];
        out txData : SensorData[*];
        attribute baudRate : Integer;
    }
    
    part def ArduinoMicrocontroller {
        attribute processorSpeed : FrequencyValue;
        attribute memorySize : Integer;
        attribute operatingVoltage : ElectricPotentialValue;
        
        port digitalIO : SensorPort[14];
        port analogInput : SensorPort[6];
        port serialComm : CommunicationPort;
        port powerIn : PowerSupplyPort;
    }
    
    part def TemperatureHumiditySensor {
        attribute sensorModel : String;
        attribute measurementRange : TemperatureValue[2];
        attribute accuracy : Real;
        
        port dataOutput : SensorPort;
        port power : PowerSupplyPort;
    }
    
    part def LightSensor {
        attribute sensitivity : Real;
        attribute spectralRange : String;
        
        port analogOutput : SensorPort;
        port power : PowerSupplyPort;
    }
    
    part def LCDDisplay {
        attribute displaySize : String;
        attribute resolution : Integer[2];
        
        port dataInput : DisplayPort;
        port power : PowerSupplyPort;
    }
    
    part def BuzzerAlarm {
        attribute frequency : FrequencyValue;
        attribute volume : Real;
        
        port controlInput : AlertPort;
        port power : PowerSupplyPort;
    }
    
    part def LEDIndicator {
        attribute color : String;
        attribute brightness : Real;
        
        port controlSignal : AlertPort;
        port power : PowerSupplyPort;
    }
    
    action def ReadEnvironmentalData {
        in sensorPort : SensorPort;
        out temperature : TemperatureValue;
        out humidity : Real;
        out light : Real;
    }
    
    action def ProcessSensorReadings {
        in rawTemperature : TemperatureValue;
        in rawHumidity : Real;
        in rawLight : Real;
        out processedData : SensorData;
    }
    
    action def EvaluateThresholds {
        in currentData : SensorData;
        in thresholds : AlertThreshold;
        out alertRequired : Boolean;
    }
    
    action def UpdateDisplay {
        in sensorData : SensorData;
        in displayPort : DisplayPort;
    }
    
    action def TriggerAlert {
        in alertType : String;
        out alertSignal : AlertSignal;
    }
    
    action def TransmitData {
        in dataToSend : SensorData;
        in commPort : CommunicationPort;
    }
    
    part def EnvironmentalMonitoringSystem {
        doc /* 
            Arduino-based environmental monitoring system that continuously measures
            temperature, humidity, and light levels. The system displays real-time
            readings on an LCD screen, triggers visual and audible alerts when
            environmental parameters exceed safe thresholds, and transmits data
            to external systems for logging and analysis.
        */
        
        part controller : ArduinoMicrocontroller {
            attribute :>> processorSpeed = 16000000.0 [SI::Hz];
            attribute :>> memorySize = 32768;
            attribute :>> operatingVoltage = 5.0 [SI::V];
        }
        
        part tempHumidSensor : TemperatureHumiditySensor {
            attribute :>> sensorModel = "DHT22";
            attribute :>> measurementRange = (233.15 [SI::K], 353.15 [SI::K]);
            attribute :>> accuracy = 0.5;
        }
        
        part lightSensor : LightSensor {
            attribute :>> sensitivity = 0.01;
            attribute :>> spectralRange = "400-700nm";
        }
        
        part display : LCDDisplay {
            attribute :>> displaySize = "16x2";
            attribute :>> resolution = (16, 2);
        }
        
        part buzzer : BuzzerAlarm {
            attribute :>> frequency = 2000.0 [SI::Hz];
            attribute :>> volume = 85.0;
        }
        
        part statusLED : LEDIndicator {
            attribute :>> color = "red";
            attribute :>> brightness = 0.8;
        }
        
        attribute thresholds : AlertThreshold {
            maxTemp = 303.15 [SI::K];
            minTemp = 288.15 [SI::K];
            maxHumidity = 80.0;
        }
        
        connect tempHumidSensor.dataOutput to controller.digitalIO#(2);
        connect lightSensor.analogOutput to controller.analogInput#(0);
        connect controller.digitalIO#(3) to display.dataInput;
        connect controller.digitalIO#(8) to buzzer.controlInput;
        connect controller.digitalIO#(13) to statusLED.controlSignal;
        
        perform action monitorEnvironment : ContinuousMonitoring;
    }
    
    action def ContinuousMonitoring {
        in thresholds : AlertThreshold;
        out currentStatus : OperatingMode;
        
        first start;
        then merge monitoringLoop;
        
        then action initializeSystem {
            doc /* Configure sensors, display, and communication interfaces */
        }
        
        then action readSensors : ReadEnvironmentalData {
            out temperature : TemperatureValue;
            out humidity : Real;
            out light : Real;
        }
        
        then action processSensorData : ProcessSensorReadings {
            in rawTemperature = readSensors.temperature;
            in rawHumidity = readSensors.humidity;
            in rawLight = readSensors.light;
            out processedData : SensorData;
        }
        
        then action evaluateConditions : EvaluateThresholds {
            in currentData = processSensorData.processedData;
            in thresholds = ContinuousMonitoring::thresholds;
            out alertRequired : Boolean;
        }
        
        then decide;
            if evaluateConditions.alertRequired then activateAlert;
            if not evaluateConditions.alertRequired then normalOperation;
        
        action activateAlert : TriggerAlert {
            in alertType = "Environmental threshold exceeded";
            out alertSignal : AlertSignal;
        }
        then updateDisplayWithAlert;
        
        action normalOperation {
            doc /* Continue normal monitoring without alert */
        }
        then updateDisplayNormal;
        
        action updateDisplayWithAlert : UpdateDisplay {
            in sensorData = processSensorData.processedData;
        }
        then transmitDataToServer;
        
        action updateDisplayNormal : UpdateDisplay {
            in sensorData = processSensorData.processedData;
        }
        then transmitDataToServer;
        
        action transmitDataToServer : TransmitData {
            in dataToSend = processSensorData.processedData;
        }
        
        then action waitInterval {
            doc /* Delay for sampling period of 2 seconds */
        }
        
        then monitoringLoop;
    }
    
    state def MonitoringStateMachine {
        entry; then initialization;
        
        state initialization {
            entry action configurePins;
            entry action calibrateSensors;
            do action testCommunication;
        }
        then activeMonitoring;
        
        state activeMonitoring {
            entry; then normalMode;
            
            state normalMode {
                entry action enableSensors;
                do action continuousSampling;
            }
            
            accept temperatureExceedsThreshold;
            then alertMode;
            
            state alertMode {
                entry action activateBuzzer;
                entry action illuminateLED;
                do action logAlertEvent;
            }
            
            accept conditionsNormalized;
            then normalMode;
            
            accept calibrationRequested;
            then calibrationMode;
        }
        
        state calibrationMode {
            entry action pauseMonitoring;
            do action recalibrateSensors;
        }
        then activeMonitoring;
    }
    
    requirement def SystemRequirements {
        doc /* Requirements for Arduino environmental monitoring system */
        
        requirement <'REQ-001'> primaryFunction {
            doc /* 
                The system shall continuously monitor environmental conditions
                including temperature, humidity, and light intensity, displaying
                real-time measurements and alerting users when parameters exceed
                safe operating thresholds.
            */
            subject system : EnvironmentalMonitoringSystem;
        }
        
        requirement <'REQ-002'> measurementAccuracy {
            doc /* Temperature measurements shall be accurate to ±0.5°C */
            subject sensor : TemperatureHumiditySensor;
        }
        
        requirement <'REQ-003'> samplingRate {
            doc /* System shall sample all sensors at minimum 0.5 Hz */
        }
        
        requirement <'REQ-004'> alertResponse {
            doc /* 
                System shall activate visual and audible alerts within 1 second
                of detecting threshold violation
            */
            subject alertSystem : BuzzerAlarm;
        }
        
        requirement <'REQ-005'> displayUpdate {
            doc /* Display shall refresh sensor readings every 2 seconds */
            subject display : LCDDisplay;
        }
        
        requirement <'REQ-006'> dataCommunication {
            doc /* 
                System shall transmit sensor data via serial communication
                at 9600 baud for external logging
            */
        }
        
        requirement <'REQ-007'> powerConsumption {
            doc /* Total system power consumption shall not exceed 500 mA at 5V */
        }
    }
    
    requirement systemMission {
        doc /* 
            The Arduino Environmental Monitoring System provides automated,
            real-time surveillance of indoor environmental conditions to ensure
            safe and comfortable operating parameters for sensitive equipment
            or living spaces.
        */
        
        assume constraint operatingConditions {
            doc /* System operates indoors with stable 5V DC power supply */
        }
        
        require SystemRequirements::primaryFunction;
        require SystemRequirements::measurementAccuracy;
        require SystemRequirements::samplingRate;
        require SystemRequirements::alertResponse;
    }
}
