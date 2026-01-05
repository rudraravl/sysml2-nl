package 'Ozone Monitor System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def OzoneConcentration :> Real {
        doc /* Ozone concentration measured in parts per billion (ppb) */
    }
    
    attribute def AirQualityIndex :> Integer {
        doc /* Air Quality Index value calculated from ozone concentration */
    }
    
    enum def AlertLevel {
        good;
        moderate;
        unhealthy;
        hazardous;
    }
    
    attribute def CalibrationCoefficient :> Real;
    
    item def AirSample {
        attribute ozoneLevel : OzoneConcentration;
        attribute temperature : TemperatureValue;
        attribute humidity : Real;
        attribute timestamp : TimeValue;
    }
    
    item def PowerSupply {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    port def SensorDataPort {
        out item sample : AirSample;
    }
    
    port def ProcessedDataPort {
        in attribute concentration : OzoneConcentration;
        out attribute aqi : AirQualityIndex;
        out attribute alert : AlertLevel;
    }
    
    port def DisplayPort {
        in attribute concentration : OzoneConcentration;
        in attribute aqi : AirQualityIndex;
        in attribute alert : AlertLevel;
    }
    
    port def PowerPort {
        in item power : PowerSupply;
    }
    
    part def OzoneSensor {
        doc /* Electrochemical sensor detecting ozone molecules in ambient air */
        
        attribute calibrationFactor : CalibrationCoefficient;
        attribute sensitivity : Real;
        
        port dataOut : SensorDataPort;
        port powerIn : ~PowerPort;
        
        action def SampleAir {
            in samplingDuration : TimeValue;
            out airSample : AirSample;
        }
    }
    
    part def DataProcessor {
        doc /* Processes raw sensor data and calculates air quality metrics */
        
        attribute ozoneThresholdGood : OzoneConcentration = 50.0;
        attribute ozoneThresholdModerate : OzoneConcentration = 100.0;
        attribute ozoneThresholdUnhealthy : OzoneConcentration = 150.0;
        
        port sensorIn : ~SensorDataPort;
        port dataOut : ProcessedDataPort;
        port powerIn : ~PowerPort;
        
        action def ProcessSample {
            in rawSample : AirSample;
            out concentration : OzoneConcentration;
        }
        
        action def CalculateAQI {
            in concentration : OzoneConcentration;
            out aqi : AirQualityIndex;
        }
        
        action def DetermineAlert {
            in concentration : OzoneConcentration;
            in thresholdGood : OzoneConcentration;
            in thresholdModerate : OzoneConcentration;
            in thresholdUnhealthy : OzoneConcentration;
            out alert : AlertLevel;
        }
    }
    
    part def DisplayUnit {
        doc /* Visual display showing real-time ozone levels and air quality status */
        
        port displayIn : ~DisplayPort;
        port powerIn : ~PowerPort;
        
        action def UpdateDisplay {
            in concentration : OzoneConcentration;
            in aqi : AirQualityIndex;
            in alert : AlertLevel;
        }
    }
    
    part def AlarmUnit {
        doc /* Audible and visual alarm activated when hazardous levels detected */
        
        port powerIn : ~PowerPort;
        
        action def ActivateAlarm {
            in alert : AlertLevel;
        }
    }
    
    part def DataLogger {
        doc /* Stores historical measurement data for trend analysis */
        
        attribute storageCapacity : Integer = 10000;
        attribute recordedSamples : AirSample[*] ordered;
        
        port powerIn : ~PowerPort;
        
        action def LogMeasurement {
            in sample : AirSample;
            out updatedLog : AirSample[*];
        }
    }
    
    part def PowerModule {
        doc /* Provides regulated power to all system components */
        
        attribute inputVoltage : ElectricPotentialValue = 12.0[V];
        attribute outputVoltage : ElectricPotentialValue = 5.0[V];
        
        port powerOut[5] : PowerPort;
    }
    
    action def MonitorOzoneLevel {
        in samplingInterval : TimeValue;
        out concentration : OzoneConcentration;
        out aqi : AirQualityIndex;
        out alert : AlertLevel;
        
        first start;
        then merge continueMeasurement;
        
        action sampleAir : OzoneSensor::SampleAir {
            in samplingDuration = samplingInterval;
            out airSample : AirSample;
        }
        
        then action processSample : DataProcessor::ProcessSample {
            in rawSample = sampleAir.airSample;
            out concentration : OzoneConcentration;
        }
        
        then action calculateAQI : DataProcessor::CalculateAQI {
            in concentration = processSample.concentration;
            out aqi : AirQualityIndex;
        }
        
        then action determineAlert : DataProcessor::DetermineAlert {
            in concentration = processSample.concentration;
            in thresholdGood = 50.0;
            in thresholdModerate = 100.0;
            in thresholdUnhealthy = 150.0;
            out alert : AlertLevel;
        }
        
        then decide;
            if determineAlert.alert == AlertLevel::hazardous then activateAlarm;
            else continueMeasurement;
        
        action activateAlarm : AlarmUnit::ActivateAlarm {
            in alert = determineAlert.alert;
        }
        then continueMeasurement;
    }
    
    state def OperatingState {
        entry action initializeSystem;
        
        state idle;
        state measuring;
        state processing;
        state displaying;
        state alarming;
        
        transition idle_to_measuring
            first idle
            then measuring;
        
        transition measuring_to_processing
            first measuring
            then processing;
        
        transition processing_to_displaying
            first processing
            then displaying;
        
        transition displaying_to_alarming
            first displaying
            then alarming;
        
        transition displaying_to_idle
            first displaying
            then idle;
        
        transition alarming_to_idle
            first alarming
            then idle;
    }
    
    part def OzoneMonitorSystem {
        doc /* 
            Atmospheric ozone monitoring system that continuously measures ozone 
            concentration, calculates air quality index, displays real-time data, 
            logs measurements, and activates alarms when hazardous levels are detected.
        */
        
        attribute measurementInterval : TimeValue = 60.0[s];
        attribute currentConcentration : OzoneConcentration;
        attribute currentAQI : AirQualityIndex;
        attribute currentAlert : AlertLevel;
        attribute systemState : OperatingState;
        
        part sensor : OzoneSensor {
            perform monitoringBehavior.sampleAir;
        }
        
        part processor : DataProcessor {
            perform monitoringBehavior.processSample;
            perform monitoringBehavior.calculateAQI;
            perform monitoringBehavior.determineAlert;
        }
        
        part display : DisplayUnit {
            perform monitoringBehavior.updateDisplay;
        }
        
        part alarm : AlarmUnit {
            perform monitoringBehavior.activateAlarm;
        }
        
        part logger : DataLogger {
            perform monitoringBehavior.logData;
        }
        
        part power : PowerModule;
        
        connect sensor.dataOut to processor.sensorIn;
        connect processor.dataOut to display.displayIn;
        connection c1 connect power.powerOut[1] to sensor.powerIn;
        connection c2 connect power.powerOut[2] to processor.powerIn;
        connection c3 connect power.powerOut[3] to display.powerIn;
        connection c4 connect power.powerOut[4] to alarm.powerIn;
        connection c5 connect power.powerOut[5] to logger.powerIn;
        
        action monitoringBehavior {
            first start;
            then merge continueMeasurement;
            
            action sampleAir : OzoneSensor::SampleAir {
                in samplingDuration = measurementInterval;
                out airSample : AirSample;
            }
            
            then action processSample : DataProcessor::ProcessSample {
                in rawSample = sampleAir.airSample;
                out concentration : OzoneConcentration;
            }
            
            then action calculateAQI : DataProcessor::CalculateAQI {
                in concentration = processSample.concentration;
                out aqi : AirQualityIndex;
            }
            
            then action determineAlert : DataProcessor::DetermineAlert {
                in concentration = processSample.concentration;
                in thresholdGood = processor.ozoneThresholdGood;
                in thresholdModerate = processor.ozoneThresholdModerate;
                in thresholdUnhealthy = processor.ozoneThresholdUnhealthy;
                out alert : AlertLevel;
            }
            
            then action updateDisplay : DisplayUnit::UpdateDisplay {
                in concentration = processSample.concentration;
                in aqi = calculateAQI.aqi;
                in alert = determineAlert.alert;
            }
            
            then action logData : DataLogger::LogMeasurement {
                in sample = sampleAir.airSample;
                out updatedLog : AirSample[*];
            }
            
            then decide;
                if determineAlert.alert == AlertLevel::hazardous then activateAlarm;
                else continueMeasurement;
            
            action activateAlarm : AlarmUnit::ActivateAlarm {
                in alert = determineAlert.alert;
            }
            then continueMeasurement;
        }
    }
    
    part ozoneMonitor : OzoneMonitorSystem;
    
    requirement def MeasurementAccuracy {
        doc /* The ozone monitor shall measure concentrations with specified accuracy */
        
        subject monitor : OzoneMonitorSystem;
        
        require constraint {
            doc /* Measurement accuracy shall be within ±5 ppb or ±5%, whichever is greater */
        }
    }
    
    requirement def ResponseTime {
        doc /* The system shall respond to concentration changes within specified time */
        
        subject monitor : OzoneMonitorSystem;
        
        require constraint {
            doc /* 90% response time shall be less than 60 seconds */
        }
    }
    
    requirement def DataRetention {
        doc /* The system shall maintain historical measurement records */
        
        subject monitor : OzoneMonitorSystem;
        
        require constraint {
            doc /* System shall store minimum 30 days of measurement data */
        }
    }
    
    requirement def AlarmActivation {
        doc /* The system shall activate alarm when hazardous levels detected */
        
        subject monitor : OzoneMonitorSystem;
        
        require constraint {
            doc /* Alarm shall activate within 5 seconds when concentration exceeds 150 ppb */
        }
    }
    
    requirement <'OZM-001'> ozoneMonitoringMission {
        doc /* 
            The ozone monitor system shall continuously measure atmospheric ozone 
            concentration to protect public health by providing real-time air quality 
            information, logging historical data for trend analysis, and alerting users 
            to hazardous ozone levels that may pose health risks.
        */
        
        subject monitor : OzoneMonitorSystem;
        
        require r1 : MeasurementAccuracy;
        require r2 : ResponseTime;
        require r3 : DataRetention;
        require r4 : AlarmActivation;
    }
}
