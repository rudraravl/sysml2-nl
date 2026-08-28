package AirQualityEgg {
    private import ISQ::*;
    private import ScalarValues::*;
    
    unit ppb;
    unit ppm;
    unit ug_per_m3;
    unit pct;
    unit index;
    
    value type PollutantConcentration;
    value type NO2Concentration :> PollutantConcentration {
        unit ppb;
    }
    value type COConcentration :> PollutantConcentration {
        unit ppm;
    }
    value type O3Concentration :> PollutantConcentration {
        unit ppb;
    }
    value type PM25Concentration :> PollutantConcentration {
        unit ug_per_m3;
    }
    value type HumidityValue {
        unit pct;
    }
    value type AQIValue {
        unit index;
    }
    value type VoltageValue :> ElectricPotentialValue;
    
    attribute def SensorReading {
        attribute no2 : NO2Concentration;
        attribute co : COConcentration;
        attribute o3 : O3Concentration;
        attribute pm25 : PM25Concentration;
        attribute temp : TemperatureValue;
        attribute humidity : HumidityValue;
    }
    
    attribute def MeasurementReport {
        attribute reading : SensorReading;
        attribute aqi : AQIValue;
        attribute timestamp : String;
    }
    
    port def SensorDataPort {
        out reading : SensorReading;
    }
    
    port def CloudCommPort {
        out report : MeasurementReport;
    }
    
    port def PowerPort {
        in voltage : VoltageValue;
    }
    
    part def NO2Sensor {
        port dataOut : SensorDataPort;
        perform action senseNO2 {
            out no2 : NO2Concentration;
        }
    }
    
    part def COSensor {
        port dataOut : SensorDataPort;
        perform action senseCO {
            out co : COConcentration;
        }
    }
    
    part def O3Sensor {
        port dataOut : SensorDataPort;
        perform action senseO3 {
            out o3 : O3Concentration;
        }
    }
    
    part def PM25Sensor {
        port dataOut : SensorDataPort;
        perform action sensePM25 {
            out pm25 : PM25Concentration;
        }
    }
    
    part def EnvironmentalSensor {
        port dataOut : SensorDataPort;
        perform action senseEnv {
            out temp : TemperatureValue;
            out humidity : HumidityValue;
        }
    }
    
    action def CalibrateData {
        in rawReading : SensorReading;
        out calibratedReading : SensorReading;
    }
    
    action def ComputeAQI {
        in reading : SensorReading;
        out aqi : AQIValue;
    }
    
    action def ProcessData {
        in rawReading : SensorReading;
        out report : MeasurementReport;
        
        first start;
        then action calibrate : CalibrateData {
            in rawReading = rawReading;
            out calibratedReading;
        }
        then action computeAQI : ComputeAQI {
            in reading = calibrate.calibratedReading;
            out aqi;
        }
        then assign report.reading := calibrate.calibratedReading;
        then assign report.aqi := computeAQI.aqi;
        then done;
    }
    
    action def TransmitData {
        in report : MeasurementReport;
        first start;
        then done;
    }
    
    action def RegulatePower {
        in input : VoltageValue;
        out output : VoltageValue;
    }
    
    part def SensorSuite {
        part no2Sensor : NO2Sensor;
        part coSensor : COSensor;
        part o3Sensor : O3Sensor;
        part pm25Sensor : PM25Sensor;
        part envSensor : EnvironmentalSensor;
        port dataOut : SensorDataPort;
        port powerIn : PowerPort;
    }
    
    part def CentralProcessingUnit {
        port sensorIn : ~SensorDataPort;
        port cloudOut : CloudCommPort;
        port powerIn : PowerPort;
        
        attribute samplingInterval : TimeValue;
        
        perform action processData : ProcessData;
        
        state operationalState {
            entry; then idle;
            state idle;
            transition first idle after samplingInterval then sampling;
            state sampling {
                do action sampleData;
            }
            transition first sampling then processing;
            state processing {
                do action computeReport;
            }
            transition first processing then transmitting;
            state transmitting {
                do action sendData;
            }
            transition first transmitting then idle;
        }
    }
    
    part def WiFiTransceiver {
        port dataIn : ~CloudCommPort;
        port powerIn : PowerPort;
        port antennaOut : CloudCommPort;
        
        perform action transmitData : TransmitData;
    }
    
    part def PowerModule {
        port powerOut : ~PowerPort;
        attribute inputVoltage : VoltageValue;
        attribute regulatedVoltage : VoltageValue;
        
        perform action regulatePower : RegulatePower;
    }
    
    part def CloudServer {
        port dataIn : ~CloudCommPort;
    }
    
    part def AirQualityEggDevice {
        part sensorSuite : SensorSuite;
        part cpu : CentralProcessingUnit;
        part wifi : WiFiTransceiver;
        part power : PowerModule;
        
        connect power.powerOut to cpu.powerIn;
        connect power.powerOut to wifi.powerIn;
        connect power.powerOut to sensorSuite.powerIn;
        connect sensorSuite.dataOut to cpu.sensorIn;
        connect cpu.cloudOut to wifi.dataIn;
    }
    
    part device : AirQualityEggDevice;
    part cloudServer : CloudServer;
    connect device.wifi.antennaOut to cloudServer.dataIn;
    
    requirement def AirQualityMonitoringRequirement {
        subject egg : AirQualityEggDevice;
        requirement measurePollutants {
            subject egg;
            doc /* The device shall measure NO2, CO, O3, and PM2.5 concentrations. */
        }
        requirement measureEnvironment {
            subject egg;
            doc /* The device shall measure ambient temperature and humidity. */
        }
        requirement computeStandardAQI {
            subject egg;
            doc /* The device shall compute a standardized Air Quality Index from calibrated sensor readings. */
        }
        requirement transmitDataToCloud {
            subject egg;
            doc /* The device shall transmit measurement data and AQI to a central cloud server via WiFi. */
        }
        requirement continuousOperationCycle {
            subject egg;
            doc /* The device shall operate in a continuous cycle of sampling, processing, transmitting, and waiting at a configurable interval. */
        }
    }
    
    requirement airQualityEggRequirement : AirQualityMonitoringRequirement {
        subject egg :> device;
    }
}
