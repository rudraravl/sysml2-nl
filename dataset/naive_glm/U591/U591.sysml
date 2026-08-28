package AirPollutionSensingUnitModel {
    import ScalarValues::*;
    import ISQ::*;
    
    // Value Types
    value type Concentration :> Real { unit "ug/m3"; }
    value type Temperature :> Real { unit "degC"; }
    value type Humidity :> Real { unit "%"; }
    value type Pressure :> Real { unit "hPa"; }
    value type AQIValue :> Integer;
    value type Voltage :> Real { unit "V"; }
    
    // Item Types
    item def AirSample;
    item def RawSensorData;
    item def ProcessedData;
    item def CalibratedData;
    
    item def ValidatedMeasurement {
        attribute timestamp : String;
        attribute aqi : AQIValue;
        attribute pm25 : Concentration;
        attribute pm10 : Concentration;
        attribute co : Concentration;
        attribute no2 : Concentration;
        attribute o3 : Concentration;
        attribute so2 : Concentration;
        attribute temp : Temperature;
        attribute humidity : Humidity;
        attribute pressure : Pressure;
    }
    
    // Requirements
    requirement def MeasureAirQuality {
        doc /* The system shall measure key air quality indicators. */
    }
    
    requirement def TransmitData {
        doc /* The system shall transmit validated measurement packages via LoRaWAN. */
    }
    
    requirement def ManagePower {
        doc /* The system shall regulate incoming voltage for all internal components. */
    }
    
    // Parts
    part def Enclosure {
        attribute material : String = "UV-resistant plastic";
        attribute weatherproof : Boolean = true;
        part bracket {
            attribute material : String = "Stainless Steel";
        }
    }
    
    part def HEPAFilter {
        attribute replaceable : Boolean = true;
        port out airOut : AirSample;
    }
    
    part def PM25Sensor {
        port in airIn : AirSample;
        port in powerIn : Voltage;
        port out dataOut : RawSensorData;
        attribute sensorType : String = "Laser-based";
    }
    
    part def PM10Sensor {
        port in airIn : AirSample;
        port in powerIn : Voltage;
        port out dataOut : RawSensorData;
        attribute sensorType : String = "Laser-based";
    }
    
    part def ElectrochemicalSensor {
        port in airIn : AirSample;
        port in powerIn : Voltage;
        port out dataOut : RawSensorData;
        attribute sensorType : String = "Electrochemical";
    }
    
    part def MOSSensor {
        port in airIn : AirSample;
        port in powerIn : Voltage;
        port out dataOut : RawSensorData;
        attribute sensorType : String = "Metal-oxide";
    }
    
    part def EnvironmentalSensor {
        port in airIn : AirSample;
        port in powerIn : Voltage;
        port out dataOut : RawSensorData;
    }
    
    part def SignalProcessor {
        port in rawDataIn : RawSensorData;
        port in powerIn : Voltage;
        port out validatedDataOut : ValidatedMeasurement;
        
        action def ProcessData {
            in data : RawSensorData;
            out result : ValidatedMeasurement;
            // Filter noise, apply calibration, calculate AQI, validate
        }
    }
    
    part def LoRaWANModule {
        port in dataIn : ValidatedMeasurement;
        port in powerIn : Voltage;
        attribute protocol : String = "LoRaWAN";
    }
    
    part def PowerManagementUnit {
        port out regulatedVoltage : Voltage;
    }
    
    part def AirPollutionSensingUnit {
        satisfy MeasureAirQuality by self;
        satisfy TransmitData by self;
        satisfy ManagePower by self;
        
        part enclosure : Enclosure;
        part hepaFilter : HEPAFilter;
        part sensorArray {
            part pm25Sensor : PM25Sensor;
            part pm10Sensor : PM10Sensor;
            part coSensor : ElectrochemicalSensor;
            part no2Sensor : ElectrochemicalSensor;
            part o3Sensor : ElectrochemicalSensor;
            part so2Sensor : MOSSensor;
            part tempSensor : EnvironmentalSensor;
            part humiditySensor : EnvironmentalSensor;
            part pressureSensor : EnvironmentalSensor;
        }
        part signalProcessor : SignalProcessor;
        part loraWanModule : LoRaWANModule;
        part powerManagementUnit : PowerManagementUnit;
        
        // Connections
        connection filterToSensors : AirSample connect hepaFilter.airOut to sensorArray.pm25Sensor.airIn, sensorArray.pm10Sensor.airIn, sensorArray.coSensor.airIn, sensorArray.no2Sensor.airIn, sensorArray.o3Sensor.airIn, sensorArray.so2Sensor.airIn, sensorArray.tempSensor.airIn, sensorArray.humiditySensor.airIn, sensorArray.pressureSensor.airIn;
        
        connection sensorsToProcessor : RawSensorData connect sensorArray.pm25Sensor.dataOut, sensorArray.pm10Sensor.dataOut, sensorArray.coSensor.dataOut, sensorArray.no2Sensor.dataOut, sensorArray.o3Sensor.dataOut, sensorArray.so2Sensor.dataOut, sensorArray.tempSensor.dataOut, sensorArray.humiditySensor.dataOut, sensorArray.pressureSensor.dataOut to signalProcessor.rawDataIn;
        
        connection processorToRadio : ValidatedMeasurement connect signalProcessor.validatedDataOut to loraWanModule.dataIn;
        
        connection powerToProcessor : Voltage connect powerManagementUnit.regulatedVoltage to signalProcessor.powerIn;
        connection powerToRadio : Voltage connect powerManagementUnit.regulatedVoltage to loraWanModule.powerIn;
        connection powerToSensors : Voltage connect powerManagementUnit.regulatedVoltage to sensorArray.pm25Sensor.powerIn, sensorArray.pm10Sensor.powerIn, sensorArray.coSensor.powerIn, sensorArray.no2Sensor.powerIn, sensorArray.o3Sensor.powerIn, sensorArray.so2Sensor.powerIn, sensorArray.tempSensor.powerIn, sensorArray.humiditySensor.powerIn, sensorArray.pressureSensor.powerIn;
        
        // State Machine
        state def OperationalStates {
            entry; 
            state idle;
            state warmingUp;
            state measuring;
            state handlingErrors;
            
            transition from idle to warmingUp when trigger;
            transition from warmingUp to measuring when warmupComplete;
            transition from measuring to idle when measurementComplete;
            transition from idle to handlingErrors when errorDetected;
            transition from measuring to handlingErrors when errorDetected;
            transition from handlingErrors to idle when errorResolved;
        }
    }
}
