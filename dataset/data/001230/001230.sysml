package 'SNOTEL System Model' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SnowWaterEquivalent :> ISQ::LengthValue {
        doc /* Depth of water that would result from melting the snowpack */
    }
    
    attribute def SnowDepth :> ISQ::LengthValue {
        doc /* Physical depth of snowpack measured from ground surface */
    }
    
    attribute def AirTemperature :> ISQ::ThermodynamicTemperatureValue;
    
    attribute def Precipitation :> ISQ::LengthValue {
        doc /* Accumulated precipitation depth */
    }
    
    attribute def SoilMoisture :> Real {
        doc /* Volumetric soil moisture content as percentage */
    }
    
    attribute def SoilTemperature :> ISQ::ThermodynamicTemperatureValue;
    
    attribute def BatteryVoltage :> ISQ::ElectricPotentialValue;
    
    item def SensorReading {
        attribute timestamp : String;
        attribute value : Real;
        attribute qualityFlag : String;
    }
    
    item def DataPacket {
        attribute stationId : String;
        attribute transmitTime : String;
        attribute readings : SensorReading[*];
        attribute batteryStatus : BatteryVoltage;
    }
    
    port def SensorPort {
        out reading : SensorReading;
    }
    
    port def DataPort {
        out packet : DataPacket;
        in command : String;
    }
    
    port def PowerPort {
        in voltage : ISQ::ElectricPotentialValue;
        out current : ISQ::ElectricCurrentValue;
    }
    
    part def SnowPillow {
        doc /* Pressure-sensing device measuring snowpack weight to determine SWE */
        port sensorOut : SensorPort;
        attribute pressureReading : ISQ::PressureValue;
        attribute calibrationFactor : Real;
    }
    
    part def UltrasonicDepthSensor {
        doc /* Measures snow depth using ultrasonic distance measurement */
        port sensorOut : SensorPort;
        attribute distanceToSnow : ISQ::LengthValue;
        attribute measurementRange : ISQ::LengthValue;
    }
    
    part def TemperatureSensor {
        doc /* Measures air or soil temperature using thermistor or RTD */
        port sensorOut : SensorPort;
        attribute temperature : ISQ::ThermodynamicTemperatureValue;
        attribute sensorLocation : String;
    }
    
    part def PrecipitationGauge {
        doc /* Measures accumulated precipitation using storage gauge */
        port sensorOut : SensorPort;
        attribute accumulatedDepth : ISQ::LengthValue;
        attribute gaugeType : String;
    }
    
    part def SoilMoistureSensor {
        doc /* Measures volumetric soil moisture content */
        port sensorOut : SensorPort;
        attribute moisturePercent : Real;
        attribute installationDepth : ISQ::LengthValue;
    }
    
    part def DataLogger {
        doc /* Collects, stores, and processes sensor data */
        port sensorInputs : ~SensorPort[*];
        port commPort : DataPort;
        port powerIn : ~PowerPort;
        
        attribute storedData : DataPacket[*];
        attribute samplingInterval : ISQ::TimeValue;
        attribute memoryCapacity : Real;
    }
    
    part def SatelliteTransmitter {
        doc /* Transmits data via GOES satellite system */
        port commPort : ~DataPort;
        port powerIn : ~PowerPort;
        
        attribute transmitFrequency : ISQ::FrequencyValue;
        attribute transmitPower : ISQ::PowerValue;
        attribute antennaGain : Real;
    }
    
    part def SolarPanel {
        doc /* Provides primary power from solar energy */
        port powerOut : PowerPort;
        attribute outputVoltage : ISQ::ElectricPotentialValue;
        attribute maxPower : ISQ::PowerValue;
        attribute efficiency : Real;
    }
    
    part def Battery {
        doc /* Stores energy for continuous operation during low light */
        port powerOut : PowerPort;
        attribute capacity : Real;
        attribute chargeLevel : Real;
        attribute voltage : ISQ::ElectricPotentialValue;
    }
    
    part def PowerController {
        doc /* Manages power distribution and battery charging */
        port solarIn : ~PowerPort;
        port batteryPort : ~PowerPort;
        port systemOut : PowerPort[*];
        
        attribute chargingCurrent : ISQ::ElectricCurrentValue;
        attribute loadCurrent : ISQ::ElectricCurrentValue;
    }
    
    action def MeasureSnowpack {
        in pillowPressure : ISQ::PressureValue;
        in snowDepth : ISQ::LengthValue;
        out swe : SnowWaterEquivalent;
        out depth : SnowDepth;
    }
    
    action def MeasureWeather {
        in airTemp : ISQ::ThermodynamicTemperatureValue;
        in precip : ISQ::LengthValue;
        out temperature : AirTemperature;
        out precipitation : Precipitation;
    }
    
    action def MeasureSoil {
        in soilTemp : ISQ::ThermodynamicTemperatureValue;
        in moisture : Real;
        out temperature : SoilTemperature;
        out moistureContent : SoilMoisture;
    }
    
    action def AggregateData {
        in sensorReadings : SensorReading[*];
        out dataPacket : DataPacket;
    }
    
    action def TransmitData {
        in dataPacket : DataPacket;
        out transmissionStatus : String;
    }
    
    action def ManagePower {
        in solarVoltage : ISQ::ElectricPotentialValue;
        in batteryCharge : Real;
        out powerStatus : String;
    }
    
    action def SNOTELMonitoringCycle {
        doc /* Continuous monitoring cycle for SNOTEL station */
        
        first start;
        then merge continuousMonitoring;
        
        action measureSnowpack : MeasureSnowpack {
            in pillowPressure;
            in snowDepth;
            out swe;
            out depth;
        }
        
        action measureWeather : MeasureWeather {
            in airTemp;
            in precip;
            out temperature;
            out precipitation;
        }
        
        action measureSoil : MeasureSoil {
            in soilTemp;
            in moisture;
            out temperature;
            out moistureContent;
        }
        
        then action aggregateData : AggregateData {
            in sensorReadings : SensorReading[*];
            out dataPacket;
        }
        
        then action transmitData : TransmitData {
            in dataPacket = aggregateData.dataPacket;
            out transmissionStatus;
        }
        
        then decide;
            if transmitData.transmissionStatus == "success" then continuousMonitoring;
            if transmitData.transmissionStatus == "failure" then retryTransmission;
        
        action retryTransmission : TransmitData {
            in dataPacket = aggregateData.dataPacket;
            out transmissionStatus;
        }
        
        then continuousMonitoring;
    }
    
    part def SNOTELStation {
        doc /* 
            SNOTEL (SNOwpack TELemetry) automated station for monitoring 
            mountain snowpack and related climate variables in remote locations
        */
    }
    
    part snotelStation : SNOTELStation {
        doc /* 
            Operational SNOTEL station instance monitoring snowpack water content,
            snow depth, precipitation, air temperature, soil moisture, and soil temperature
            for water supply forecasting and flood prediction
        */
        
        perform action monitoringCycle : SNOTELMonitoringCycle;
        
        part snowPillow : SnowPillow {
            :>> calibrationFactor = 1.02;
            perform monitoringCycle.measureSnowpack;
        }
        
        part depthSensor : UltrasonicDepthSensor {
            :>> measurementRange = 10.0[SI::m];
            perform monitoringCycle.measureSnowpack;
        }
        
        part airTempSensor : TemperatureSensor {
            :>> sensorLocation = "air";
            perform monitoringCycle.measureWeather;
        }
        
        part precipGauge : PrecipitationGauge {
            :>> gaugeType = "storage";
            perform monitoringCycle.measureWeather;
        }
        
        part soilTempSensor : TemperatureSensor {
            :>> sensorLocation = "soil";
            perform monitoringCycle.measureSoil;
        }
        
        part soilMoistureSensor : SoilMoistureSensor {
            :>> installationDepth = 0.5[SI::m];
            perform monitoringCycle.measureSoil;
        }
        
        part dataLogger : DataLogger {
            :>> samplingInterval = 3600.0[SI::s];
            :>> memoryCapacity = 30.0;
            perform monitoringCycle.aggregateData;
        }
        
        part transmitter : SatelliteTransmitter {
            :>> transmitFrequency = 401.65e6[SI::Hz];
            :>> transmitPower = 5.0[SI::W];
            :>> antennaGain = 3.0;
            perform monitoringCycle.transmitData;
        }
        
        part solarPanel : SolarPanel {
            :>> outputVoltage = 12.0[SI::V];
            :>> maxPower = 50.0[SI::W];
            :>> efficiency = 0.18;
        }
        
        part battery : Battery {
            :>> capacity = 100.0;
            :>> chargeLevel = 85.0;
            :>> voltage = 12.0[SI::V];
        }
        
        part powerController : PowerController;
        
        connect snowPillow.sensorOut to dataLogger.sensorInputs;
        connect depthSensor.sensorOut to dataLogger.sensorInputs;
        connect airTempSensor.sensorOut to dataLogger.sensorInputs;
        connect precipGauge.sensorOut to dataLogger.sensorInputs;
        connect soilTempSensor.sensorOut to dataLogger.sensorInputs;
        connect soilMoistureSensor.sensorOut to dataLogger.sensorInputs;
        
        connect dataLogger.commPort to transmitter.commPort;
        
        connect solarPanel.powerOut to powerController.solarIn;
        connect battery.powerOut to powerController.batteryPort;
        connect powerController.systemOut to dataLogger.powerIn;
        connect powerController.systemOut to transmitter.powerIn;
    }
    
    requirement def DataAccuracyRequirement {
        doc /* Sensor measurements shall meet specified accuracy standards */
        subject station : SNOTELStation;
        require constraint {
            doc /* Snow water equivalent accuracy within ±2.5 cm */
        }
    }
    
    requirement def TransmissionReliabilityRequirement {
        doc /* Data transmission shall be reliable under all weather conditions */
        subject station : SNOTELStation;
        require constraint {
            doc /* Successful transmission rate ≥ 95% over annual period */
        }
    }
    
    requirement def PowerAutonomyRequirement {
        doc /* System shall operate autonomously on solar power and battery */
        subject station : SNOTELStation;
        require constraint {
            doc /* Minimum 7 days continuous operation without solar charging */
        }
    }
    
    requirement def OperationalTemperatureRequirement {
        doc /* System shall operate across full mountain climate temperature range */
        subject station : SNOTELStation;
        require constraint {
            doc /* Operational temperature range: -50°C to +50°C */
        }
    }
    
    requirement <'SNOTEL-001'> primaryMissionRequirement {
        doc /* 
            The SNOTEL system shall continuously monitor and transmit 
            snowpack water content, snow depth, precipitation, air temperature,
            soil moisture, and soil temperature data from remote mountain locations
            to support water supply forecasting, flood prediction, and climate research.
        */
        
        subject snotelStation;
        
        require constraint dataAccuracyConstraint : DataAccuracyRequirement;
        require constraint transmissionReliabilityConstraint : TransmissionReliabilityRequirement;
        require constraint powerAutonomyConstraint : PowerAutonomyRequirement;
        require constraint operationalTempConstraint : OperationalTemperatureRequirement;
    }
}
