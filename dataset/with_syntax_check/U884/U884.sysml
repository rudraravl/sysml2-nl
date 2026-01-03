package SnowGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SnowDepthValue :> LengthValue {
        doc /* Vertical depth of accumulated snow measured from ground surface */
    }
    
    attribute def SnowWaterEquivalentValue :> LengthValue {
        doc /* Depth of water that would result from melting accumulated snow */
    }
    
    attribute def SnowDensityValue :> DensityValue {
        doc /* Mass per unit volume of accumulated snow */
    }
    
    attribute def AmbientTemperatureValue :> ThermodynamicTemperatureValue {
        doc /* Temperature of air surrounding the snow gauge */
    }
    
    item def SnowMeasurementRecord {
        attribute depth : SnowDepthValue;
        attribute waterEquivalent : SnowWaterEquivalentValue;
        attribute density : SnowDensityValue;
        attribute temperature : AmbientTemperatureValue;
        attribute timestamp : Real;
    }
    
    port def SensorDataPort {
        out rawDistance : LengthValue;
        out snowLoad : ISQ::ForceValue;
        out temperature : AmbientTemperatureValue;
    }
    
    port def DataOutputPort {
        out measurement : SnowMeasurementRecord;
    }
    
    port def PowerInputPort {
        in voltage : ISQ::ElectricPotentialValue;
        in current : ISQ::ElectricCurrentValue;
    }
    
    part def UltrasonicDistanceSensor {
        doc /* Measures distance to snow surface using ultrasonic pulses */
        port sensorOut : SensorDataPort;
        port power : PowerInputPort;
        
        attribute mountingHeight : LengthValue;
        attribute measurementAccuracy : LengthValue;
        attribute operatingRange : LengthValue;
    }
    
    part def LoadCell {
        doc /* Measures weight of accumulated snow on collection plate */
        out snowWeight : ISQ::ForceValue;
        port power : PowerInputPort;
        
        attribute maxCapacity : ISQ::ForceValue;
        attribute plateArea : ISQ::AreaValue;
    }
    
    part def TemperatureProbe {
        doc /* Measures ambient air temperature */
        out ambientTemperature : AmbientTemperatureValue;
        port power : PowerInputPort;
        
        attribute measurementRange : AmbientTemperatureValue[2];
        attribute accuracy : AmbientTemperatureValue;
    }
    
    part def ProcessingUnit {
        doc /* Processes sensor data and calculates snow parameters */
        in sensorData : SensorDataPort;
        out processedMeasurement : SnowMeasurementRecord;
        port power : PowerInputPort;
        
        attribute calibrationOffset : LengthValue;
    }
    
    part def DataStorage {
        doc /* Stores historical snow measurement records */
        in measurement : SnowMeasurementRecord;
        port dataOut : DataOutputPort;
        port power : PowerInputPort;
        
        attribute storageCapacity : Real;
        attribute recordingInterval : ISQ::TimeValue;
    }
    
    part def BatteryPack {
        doc /* Provides electrical power to all system components */
        port powerOut : PowerInputPort[*];
        
        attribute capacity : Real;
        attribute nominalVoltage : ISQ::ElectricPotentialValue;
    }
    
    part def SolarPanel {
        doc /* Charges battery using solar energy */
        out chargingPower : ISQ::PowerValue;
        
        attribute maxPower : ISQ::PowerValue;
        attribute efficiency : Real;
    }
    
    action def MeasureDistanceToSnow {
        in mountingHeight : LengthValue;
        in rawDistance : LengthValue;
        out snowDepth : SnowDepthValue;
    }
    
    action def CalculateWaterEquivalent {
        in snowWeight : ISQ::ForceValue;
        in collectionArea : ISQ::AreaValue;
        out waterEquivalent : SnowWaterEquivalentValue;
    }
    
    action def ComputeSnowDensity {
        in snowDepth : SnowDepthValue;
        in waterEquivalent : SnowWaterEquivalentValue;
        out density : SnowDensityValue;
    }
    
    action def StoreRecord {
        in record : SnowMeasurementRecord;
        out storageSuccess : Boolean;
    }
    
    action def PerformMeasurementCycle {
        doc /* Execute complete measurement and recording cycle */
        
        in mountingHeight : LengthValue;
        in collectionArea : ISQ::AreaValue;
        in currentTime : Real;
        out finalRecord : SnowMeasurementRecord;
        
        first start;
        
        then action measureDistance : MeasureDistanceToSnow {
            in mountingHeight = PerformMeasurementCycle::mountingHeight;
            in rawDistance;
            out snowDepth;
        }
        
        then action calculateWE : CalculateWaterEquivalent {
            in snowWeight;
            in collectionArea = PerformMeasurementCycle::collectionArea;
            out waterEquivalent;
        }
        
        then action computeDensity : ComputeSnowDensity {
            in snowDepth = measureDistance.snowDepth;
            in waterEquivalent = calculateWE.waterEquivalent;
            out density;
        }
        
        then action assembleRecord {
            out record : SnowMeasurementRecord;
        }
        
        then action storeRecord : StoreRecord {
            in record = assembleRecord.record;
            out storageSuccess;
        }
        
        then done;
    }
    
    attribute def MeasurementTrigger;
    attribute def SensorFailure;
    
    state def SnowGaugeOperationalStates {
        entry; then standby;
        
        state standby {
            doc /* Low power state awaiting measurement trigger */
        }
        
        transition standby_to_acquiring
            first standby
            accept at MeasurementTrigger
            then acquiring;
        
        state acquiring {
            doc /* Collecting data from all sensors */
            entry action activateSensors;
            do action readSensors;
        }
        
        transition acquiring_to_computing
            first acquiring
            then computing;
        
        state computing {
            doc /* Processing sensor data to derive snow parameters */
            do action calculateParameters;
        }
        
        transition computing_to_storing
            first computing
            then storing;
        
        state storing {
            doc /* Saving measurement record to storage */
            do action saveData;
        }
        
        transition storing_to_standby
            first storing
            then standby;
        
        state fault {
            doc /* Error condition requiring intervention */
        }
        
        transition standby_to_fault
            first standby
            accept at SensorFailure
            then fault;
            
        transition acquiring_to_fault
            first acquiring
            accept at SensorFailure
            then fault;
            
        transition computing_to_fault
            first computing
            accept at SensorFailure
            then fault;
            
        transition storing_to_fault
            first storing
            accept at SensorFailure
            then fault;
    }
    
    requirement def MeasurementPrecisionReq {
        doc /* Snow depth measurements shall meet specified accuracy requirements */
        
        subject gauge : SnowGauge;
        
        require constraint {
            gauge.distanceSensor.measurementAccuracy <= 5.0 [SI::mm]
        }
    }
    
    requirement def OperationalTemperatureReq {
        doc /* System shall function across expected environmental temperature range */
        
        subject gauge : SnowGauge;
        
        require constraint {
            gauge.temperatureProbe.measurementRange[1] >= 223.15 [SI::K] and
            gauge.temperatureProbe.measurementRange[2] <= 343.15 [SI::K]
        }
    }
    
    requirement def DataRecordingFrequencyReq {
        doc /* System shall record measurements at regular intervals */
        
        subject gauge : SnowGauge;
        
        require constraint {
            gauge.storage.recordingInterval <= 3600.0 [SI::s]
        }
    }
    
    requirement def PowerAutonomyReq {
        doc /* System shall operate autonomously with solar charging */
        
        subject gauge : SnowGauge;
        
        require constraint {
            gauge.solarPanel.maxPower >= 20.0 [SI::W]
        }
    }
    
    requirement snowGaugeSystemRequirements {
        doc /* Complete set of requirements for snow gauge system */
        
        require MeasurementPrecisionReq;
        require OperationalTemperatureReq;
        require DataRecordingFrequencyReq;
        require PowerAutonomyReq;
    }
    
    part def SnowGauge {
        doc /* Complete snow gauge system assembly */
        
        attribute installationHeight : LengthValue;
        attribute collectionPlateArea : ISQ::AreaValue;
        
        part distanceSensor : UltrasonicDistanceSensor;
        part loadCell : LoadCell;
        part temperatureProbe : TemperatureProbe;
        part processor : ProcessingUnit;
        part storage : DataStorage;
        part battery : BatteryPack;
        part solarPanel : SolarPanel;
    }
    
    action def ContinuousSnowMonitoring {
        doc /* 
            Primary function: Continuously monitor snow accumulation by measuring
            snow depth using ultrasonic distance sensing, determining snow water
            equivalent through weight measurement, calculating snow density, and
            recording time-series data for hydrological forecasting and water
            resource management.
        */
        
        in installationHeight : LengthValue;
        in collectionArea : ISQ::AreaValue;
        out snowRecords : SnowMeasurementRecord[*];
        
        first start;
        
        then action initialize {
            doc /* Power up sensors and verify system readiness */
        }
        
        then loop {
            action cycle : PerformMeasurementCycle {
                in mountingHeight = installationHeight;
                in collectionArea = collectionArea;
                in currentTime;
                out finalRecord;
            }
            
            then action waitForInterval {
                in interval : ISQ::TimeValue;
            }
        }
    }
    
    part snowGauge : SnowGauge {
        doc /* Automated snow monitoring system for hydrological applications */
        
        attribute :>> installationHeight = 3.5 [SI::m];
        attribute :>> collectionPlateArea = 0.25 [SI::'m^2'];
        
        perform action continuousMonitoring : ContinuousSnowMonitoring {
            in installationHeight = snowGauge.installationHeight;
            in collectionArea = snowGauge.collectionPlateArea;
            out snowRecords;
        }
        
        part distanceSensor : UltrasonicDistanceSensor {
            attribute :>> mountingHeight = snowGauge.installationHeight;
            attribute :>> measurementAccuracy = 3.0 [SI::mm];
            attribute :>> operatingRange = 5.0 [SI::m];
        }
        
        part loadCell : LoadCell {
            attribute :>> maxCapacity = 2000.0 [SI::N];
            attribute :>> plateArea = snowGauge.collectionPlateArea;
            
            out snowWeight;
        }
        
        part temperatureProbe : TemperatureProbe {
            attribute :>> measurementRange = (223.15 [SI::K], 343.15 [SI::K]);
            attribute :>> accuracy = 0.2 [SI::K];
            
            out ambientTemperature;
        }
        
        part processor : ProcessingUnit {
            attribute :>> calibrationOffset = 0.0 [SI::mm];
        }
        
        part storage : DataStorage {
            attribute :>> storageCapacity = 500000.0;
            attribute :>> recordingInterval = 1800.0 [SI::s];
        }
        
        part battery : BatteryPack {
            attribute :>> capacity = 200.0;
            attribute :>> nominalVoltage = 12.0 [SI::V];
        }
        
        part solarPanel : SolarPanel {
            attribute :>> maxPower = 25.0 [SI::W];
            attribute :>> efficiency = 0.18;
        }
        
        connection powerToSensor connect battery.powerOut to distanceSensor.power;
        connection powerToLoad connect battery.powerOut to loadCell.power;
        connection powerToTemp connect battery.powerOut to temperatureProbe.power;
        connection powerToProcessor connect battery.powerOut to processor.power;
        connection powerToStorage connect battery.powerOut to storage.power;
    }
}
