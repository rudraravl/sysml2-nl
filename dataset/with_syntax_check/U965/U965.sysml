package 'Air Quality Egg System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ConcentrationPPM :> Real;
    attribute def ConcentrationPPB :> Real;
    attribute def ConcentrationUgM3 :> Real;
    attribute def HumidityPercent :> Real;
    attribute def AQIValue :> Integer;
    
    item def AirQualityMeasurement {
        attribute timestamp : String;
        attribute no2Level : ConcentrationPPB;
        attribute coLevel : ConcentrationPPM;
        attribute o3Level : ConcentrationPPB;
        attribute pm25Level : ConcentrationUgM3;
        attribute temperature : ThermodynamicTemperatureValue;
        attribute humidity : HumidityPercent;
        attribute airQualityIndex : AQIValue;
    }
    
    item def NetworkConfig {
        attribute ssid : String;
        attribute password : String;
        attribute serverURL : String;
        attribute apiKey : String;
    }
    
    port def SensorDataPort {
        out measurement : AirQualityMeasurement;
    }
    
    port def ProcessingPort {
        in rawData : AirQualityMeasurement;
        out processedData : AirQualityMeasurement;
    }
    
    port def NetworkPort {
        in dataToTransmit : AirQualityMeasurement;
        out transmissionStatus : Boolean;
    }
    
    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    part def NO2Sensor {
        port dataOut : SensorDataPort;
        attribute range : ConcentrationPPB;
        attribute accuracy : ConcentrationPPB;
    }
    
    part def COSensor {
        port dataOut : SensorDataPort;
        attribute range : ConcentrationPPM;
        attribute accuracy : ConcentrationPPM;
    }
    
    part def OzoneSensor {
        port dataOut : SensorDataPort;
        attribute range : ConcentrationPPB;
        attribute accuracy : ConcentrationPPB;
    }
    
    part def ParticulateMatterSensor {
        port dataOut : SensorDataPort;
        attribute particleSize : LengthValue;
        attribute range : ConcentrationUgM3;
    }
    
    part def EnvironmentalSensor {
        port tempOut : SensorDataPort;
        port humidityOut : SensorDataPort;
        attribute tempRange : ThermodynamicTemperatureValue;
        attribute humidityRange : HumidityPercent;
    }
    
    part def ProcessingUnit {
        port sensorInput : ProcessingPort;
        port networkOutput : NetworkPort;
        attribute processingFrequency : FrequencyValue;
        attribute memoryCapacity : Real;
    }
    
    part def WiFiTransceiver {
        port dataInput : NetworkPort;
        attribute operatingFrequency : FrequencyValue;
        attribute transmitPower : PowerValue;
        attribute range : LengthValue;
    }
    
    part def PowerModule {
        port powerOutput : PowerPort;
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
    }
    
    action def SampleSensor {
        in sensorID : String;
        out reading : AirQualityMeasurement;
    }
    
    action def CalibrateData {
        in rawMeasurement : AirQualityMeasurement;
        out calibratedMeasurement : AirQualityMeasurement;
    }
    
    action def ComputeAQI {
        in measurements : AirQualityMeasurement;
        out aqiValue : AQIValue;
    }
    
    action def TransmitToCloud {
        in data : AirQualityMeasurement;
        in config : NetworkConfig;
        out transmitSuccess : Boolean;
    }
    
    action def MonitorAndReportAirQuality {
        in samplingPeriod : TimeValue;
        in networkConfig : NetworkConfig;
        out reportedData : AirQualityMeasurement[*];
        
        first start;
        then merge collectCycle;
        
        action collectCycle {
            action sampleNO2 : SampleSensor {
                in sensorID = "NO2";
                out no2Reading : AirQualityMeasurement;
            }
            
            action sampleCO : SampleSensor {
                in sensorID = "CO";
                out coReading : AirQualityMeasurement;
            }
            
            action sampleO3 : SampleSensor {
                in sensorID = "O3";
                out o3Reading : AirQualityMeasurement;
            }
            
            action samplePM25 : SampleSensor {
                in sensorID = "PM2.5";
                out pm25Reading : AirQualityMeasurement;
            }
            
            action sampleEnvironment : SampleSensor {
                in sensorID = "Environment";
                out envReading : AirQualityMeasurement;
            }
        }
        
        then action calibrate : CalibrateData {
            in rawMeasurement : AirQualityMeasurement;
            out calibratedMeasurement : AirQualityMeasurement;
        }
        
        then action calculateAQI : ComputeAQI {
            in measurements = calibrate.calibratedMeasurement;
            out aqiValue : AQIValue;
        }
        
        then action transmit : TransmitToCloud {
            in data = calibrate.calibratedMeasurement;
            in config = networkConfig;
            out transmitSuccess : Boolean;
        }
        
        then action waitForNextCycle {
            in waitTime = samplingPeriod;
        }
        
        then collectCycle;
    }
    
    part def AirQualityEgg {
        doc /*
            The Air Quality Egg is a community-driven environmental monitoring device 
            designed to measure and report local air quality conditions in real-time. 
            Its primary function is to continuously sense atmospheric pollutants including 
            nitrogen dioxide, carbon monoxide, ozone, and particulate matter, along with 
            environmental parameters such as temperature and humidity. The system processes 
            these measurements, calculates an air quality index, and wirelessly transmits 
            the data to cloud-based services for public access and analysis. This enables 
            citizens to participate in building distributed networks of air quality sensors, 
            contributing to environmental awareness and data-driven decision making about 
            local air pollution levels.
        */
        
        attribute deviceID : String;
        attribute deploymentLocation : String;
        attribute samplingInterval : TimeValue;
        
        part no2Sensor : NO2Sensor {
            :>> range = 1000.0;
            :>> accuracy = 5.0;
        }
        
        part coSensor : COSensor {
            :>> range = 100.0;
            :>> accuracy = 1.0;
        }
        
        part o3Sensor : OzoneSensor {
            :>> range = 500.0;
            :>> accuracy = 5.0;
        }
        
        part pm25Sensor : ParticulateMatterSensor {
            :>> particleSize = 2.5;
            :>> range = 500.0;
        }
        
        part envSensor : EnvironmentalSensor {
            :>> tempRange = 50.0;
            :>> humidityRange = 100.0;
        }
        
        part processor : ProcessingUnit {
            :>> processingFrequency = 1.0e6;
            :>> memoryCapacity = 512.0;
        }
        
        part wifi : WiFiTransceiver {
            :>> operatingFrequency = 2.4e9;
            :>> transmitPower = 0.5;
            :>> range = 100.0;
        }
        
        part power : PowerModule {
            :>> inputVoltage = 5.0;
            :>> outputVoltage = 3.3;
            :>> maxCurrent = 2.0;
        }
        
        connect no2Sensor.dataOut to processor.sensorInput;
        connect coSensor.dataOut to processor.sensorInput;
        connect o3Sensor.dataOut to processor.sensorInput;
        connect pm25Sensor.dataOut to processor.sensorInput;
        connect envSensor.tempOut to processor.sensorInput;
        connect envSensor.humidityOut to processor.sensorInput;
        connect processor.networkOutput to wifi.dataInput;
        
        perform action monitoring : MonitorAndReportAirQuality {
            in samplingPeriod = samplingInterval;
            in networkConfig : NetworkConfig;
            out reportedData : AirQualityMeasurement[*];
        }
    }
    
    requirement def MeasurementRequirement {
        doc /* The system shall measure air quality pollutants and environmental conditions. */
        
        requirement pollutantSensing {
            doc /* The system shall sense NO2, CO, O3, and PM2.5 concentrations. */
        }
        
        requirement environmentalSensing {
            doc /* The system shall measure temperature and relative humidity. */
        }
        
        requirement measurementAccuracy {
            doc /* Measurements shall meet specified accuracy tolerances. */
            
            require constraint no2Tolerance {
                doc /* NO2 accuracy within ±5 ppb. */
            }
            
            require constraint coTolerance {
                doc /* CO accuracy within ±1 ppm. */
            }
            
            require constraint pm25Tolerance {
                doc /* PM2.5 accuracy within ±5 µg/m³. */
            }
        }
    }
    
    requirement def DataProcessingRequirement {
        doc /* The system shall process sensor data and compute air quality metrics. */
        
        requirement dataCalibration {
            doc /* Raw sensor data shall be calibrated using factory calibration coefficients. */
        }
        
        requirement aqiCalculation {
            doc /* The system shall calculate an air quality index from pollutant concentrations. */
        }
        
        requirement samplingRate {
            doc /* The system shall sample sensors at configurable intervals between 10 and 300 seconds. */
        }
    }
    
    requirement def CommunicationRequirement {
        doc /* The system shall transmit data to remote services. */
        
        requirement wirelessConnectivity {
            doc /* The system shall support WiFi 802.11 b/g/n connectivity. */
        }
        
        requirement dataTransmission {
            doc /* Processed measurements shall be transmitted to cloud services within 5 seconds of collection. */
        }
        
        requirement networkReliability {
            doc /* The system shall retry failed transmissions up to 3 times before logging an error. */
        }
    }
    
    requirement def PowerManagementRequirement {
        doc /* The system shall operate within specified power constraints. */
        
        require constraint operatingVoltageRange {
            doc /* System shall operate from 4.5V to 5.5V DC input. */
        }
        
        require constraint averagePowerConsumption {
            doc /* Average power consumption shall not exceed 2.5W during normal operation. */
        }
        
        require constraint sleepModePower {
            doc /* Power consumption in sleep mode shall not exceed 0.1W. */
        }
    }
    
    requirement systemRequirements {
        subject airQualityEggSystem;
        
        require measurement : MeasurementRequirement;
        require processing : DataProcessingRequirement;
        require communication : CommunicationRequirement;
        require powerManagement : PowerManagementRequirement;
    }
    
    part airQualityEggSystem : AirQualityEgg {
        :>> deviceID = "AQE-001";
        :>> deploymentLocation = "Urban Monitoring Site";
        :>> samplingInterval = 60.0;
    }
}
