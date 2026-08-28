package SnowMonitoringSystem {
    import ScalarValues::*;
    import ISQ::*;
    
    // ---- Value Types with Units ----
    value type LengthValue :> Real { unit 'm'; }
    value type MassValue :> Real { unit 'kg'; }
    value type TemperatureValue :> Real { unit 'degC'; }
    value type DensityValue :> Real { unit 'kg/m3'; }
    value type VoltageValue :> Real { unit 'V'; }
    value type PowerValue :> Real { unit 'W'; }
    value type EnergyValue :> Real { unit 'J'; }
    value type DurationValue :> Real { unit 's'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type TimestampValue :> String;
    
    // ---- Item Types ----
    item def DistanceReading {
        attribute value : LengthValue;
        attribute timestamp : TimestampValue;
        attribute sensorId : String;
    }
    
    item def WeightReading {
        attribute value : MassValue;
        attribute timestamp : TimestampValue;
        attribute sensorId : String;
    }
    
    item def AmbientTempReading {
        attribute value : TemperatureValue;
        attribute timestamp : TimestampValue;
        attribute sensorId : String;
    }
    
    item def SnowMeasurementRecord {
        attribute snowDepth : LengthValue;
        attribute snowWaterEquivalent : MassValue;
        attribute snowDensity : DensityValue;
        attribute ambientTemperature : TemperatureValue;
        attribute timestamp : TimestampValue;
        attribute stationId : String;
    }
    
    item def PowerFlow {
        attribute voltage : VoltageValue;
        attribute current : Real;
        attribute direction : Boolean; // true = charging, false = discharging
    }
    
    item def SensorStatus {
        attribute sensorId : String;
        attribute operational : Boolean;
        attribute errorCode : Integer;
    }
    
    // ---- Port Definitions ----
    port def DistanceDataOut {
        out reading : DistanceReading;
        out status : SensorStatus;
    }
    
    port def DistanceDataIn {
        in reading : DistanceReading;
        in status : SensorStatus;
    }
    
    port def WeightDataOut {
        out reading : WeightReading;
        out status : SensorStatus;
    }
    
    port def WeightDataIn {
        in reading : WeightReading;
        in status : SensorStatus;
    }
    
    port def TempDataOut {
        out reading : AmbientTempReading;
        out status : SensorStatus;
    }
    
    port def TempDataIn {
        in reading : AmbientTempReading;
        in status : SensorStatus;
    }
    
    port def RecordDataOut {
        out record : SnowMeasurementRecord;
    }
    
    port def RecordDataIn {
        in record : SnowMeasurementRecord;
    }
    
    port def PowerOut {
        out power : PowerFlow;
    }
    
    port def PowerIn {
        in power : PowerFlow;
    }
    
    port def SolarPowerOut {
        out power : PowerFlow;
    }
    
    // ---- Sensor Parts ----
    part def UltrasonicDistanceSensor {
        attribute mountHeight : LengthValue = 2.0 [m];
        attribute maxRange : LengthValue = 5.0 [m];
        attribute accuracy : LengthValue = 0.01 [m];
        attribute sensorId : String = "ULTRASONIC_01";
        
        port dataOut : DistanceDataOut;
        port powerIn : PowerIn;
        
        attribute operational : Boolean = true;
        
        action def MeasureDistance {
            in mountHeight : LengthValue;
            out reading : DistanceReading;
        }
        
        perform action measure : MeasureDistance {
            in mountHeight = mountHeight;
            out reading = dataOut.reading;
        }
    }
    
    part def LoadCell {
        attribute plateArea : Real = 1.0; // m2
        attribute maxLoad : MassValue = 500.0 [kg];
        attribute accuracy : MassValue = 0.05 [kg];
        attribute sensorId : String = "LOADCELL_01";
        
        port dataOut : WeightDataOut;
        port powerIn : PowerIn;
        
        attribute operational : Boolean = true;
        
        action def MeasureWeight {
            out reading : WeightReading;
        }
        
        perform action measure : MeasureWeight {
            out reading = dataOut.reading;
        }
    }
    
    part def TemperatureProbe {
        attribute rangeMin : TemperatureValue = -40.0 [degC];
        attribute rangeMax : TemperatureValue = 60.0 [degC];
        attribute accuracy : TemperatureValue = 0.5 [degC];
        attribute sensorId : String = "TEMP_01";
        
        port dataOut : TempDataOut;
        port powerIn : PowerIn;
        
        attribute operational : Boolean = true;
        
        action def MeasureTemperature {
            out reading : AmbientTempReading;
        }
        
        perform action measure : MeasureTemperature {
            out reading = dataOut.reading;
        }
    }
    
    // ---- Data Storage ----
    part def DataStorageUnit {
        attribute capacity : Integer = 100000; // records
        attribute storedRecords : Integer = 0;
        
        port recordIn : RecordDataIn;
        
        action def StoreRecord {
            in record : SnowMeasurementRecord;
            out success : Boolean;
        }
        
        perform action store : StoreRecord {
            in record = recordIn.record;
        }
    }
    
    // ---- Power Subsystem ----
    part def SolarPanel {
        attribute ratedPower : PowerValue = 30.0 [W];
        attribute nominalVoltage : VoltageValue = 12.0 [V];
        
        port powerOut : SolarPowerOut;
        
        action def HarvestEnergy {
            out power : PowerFlow;
        }
        
        perform action harvest : HarvestEnergy {
            out power = powerOut.power;
        }
    }
    
    part def BatteryPack {
        attribute capacity : EnergyValue = 1296000.0 [J]; // 36 Wh
        attribute chargeLevel : EnergyValue = 1296000.0 [J];
        attribute nominalVoltage : VoltageValue = 12.0 [V];
        attribute minOperationalLevel : EnergyValue = 129600.0 [J];
        
        port chargeIn : PowerIn;
        port powerOut : PowerOut;
        
        state def BatteryState;
        state behavior batteryStateMachine : BatteryState {
            state Charging;
            state Discharging;
            state Depleted;
            
            transition Charging_to_Discharging first Charging if chargeLevel >= capacity then Discharging;
            transition Discharging_to_Charging first Discharging if chargeLevel <= minOperationalLevel then Charging;
            transition any_to_Depleted if chargeLevel <= 0.0 [J] then Depleted;
        }
    }
    
    part def PowerController {
        port solarIn : PowerIn;
        port batteryCharge : PowerOut;
        port loadPower : PowerOut;
        
        action def RegulatePower {
            in solarInput : PowerFlow;
            out batteryChargeFlow : PowerFlow;
            out loadPowerFlow : PowerFlow;
        }
    }
    
    // ---- Central Processing Unit ----
    part def CentralProcessingUnit {
        attribute stationId : String = "SNOW_STATION_001";
        attribute samplingInterval : DurationValue = 1800.0 [s]; // 30 minutes
        attribute mountHeight : LengthValue = 2.0 [m];
        attribute plateArea : Real = 1.0;
        
        port distanceIn : DistanceDataIn;
        port weightIn : WeightDataIn;
        port tempIn : TempDataIn;
        port recordOut : RecordDataOut;
        port powerIn : PowerIn;
        
        attribute lastRecord : SnowMeasurementRecord;
        attribute sensorFaultDetected : Boolean = false;
        
        action def AcquireSensorData {
            out distance : DistanceReading;
            out weight : WeightReading;
            out temperature : AmbientTempReading;
            out statuses : SensorStatus[3];
        }
        
        action def CalculateSnowDepth {
            in distanceReading : DistanceReading;
            in mountHeight : LengthValue;
            out snowDepth : LengthValue;
        }
        
        action def CalculateSnowWaterEquivalent {
            in weightReading : WeightReading;
            out swe : MassValue;
        }
        
        action def CalculateSnowDensity {
            in snowDepth : LengthValue;
            in swe : MassValue;
            in plateArea : Real;
            out density : DensityValue;
        }
        
        action def ComposeRecord {
            in snowDepth : LengthValue;
            in swe : MassValue;
            in density : DensityValue;
            in temperature : TemperatureValue;
            in timestamp : TimestampValue;
            out record : SnowMeasurementRecord;
        }
        
        action def CheckSensorHealth {
            in statuses : SensorStatus[3];
            out faultDetected : Boolean;
        }
        
        perform action acquire : AcquireSensorData {
            out distance = distanceIn.reading;
            out weight = weightIn.reading;
            out temperature = tempIn.reading;
        }
        
        perform action calcDepth : CalculateSnowDepth {
            in distanceReading = acquire.distance;
            in mountHeight = mountHeight;
        }
        
        perform action calcSWE : CalculateSnowWaterEquivalent {
            in weightReading = acquire.weight;
        }
        
        perform action calcDensity : CalculateSnowDensity {
            in snowDepth = calcDepth.snowDepth;
            in swe = calcSWE.swe;
            in plateArea = plateArea;
        }
        
        perform action compose : ComposeRecord {
            in snowDepth = calcDepth.snowDepth;
            in swe = calcSWE.swe;
            in density = calcDensity.density;
            in temperature = acquire.temperature.value;
        }
        
        perform action healthCheck : CheckSensorHealth {
            in statuses = acquire.statuses;
            out faultDetected = sensorFaultDetected;
        }
        
        // ---- State Machine ----
        state def OperatingState;
        state behavior stationStateMachine : OperatingState {
            entry action;
            
            state Standby {
                entry action { /* low-power mode */ }
            }
            state Wake {
                entry action { /* power up sensors */ }
            }
            state Acquire {
                entry action perform acquire;
            }
            state Process {
                entry action {
                    perform calcDepth;
                    perform calcSWE;
                    perform calcDensity;
                    perform compose;
                    perform healthCheck;
                }
            }
            state Store {
                entry action { /* send record to storage */ }
            }
            state Error {
                entry action { /* flag maintenance required */ }
            }
            
            transition initial_to_Standby initial then Standby;
            transition Standby_to_Wake Standby if samplingIntervalElapsed then Wake;
            transition Wake_to_Acquire Wake then Acquire;
            transition Acquire_to_Process Acquire then Process;
            transition Process_to_Store Process if !sensorFaultDetected then Store;
            transition Process_to_Error Process if sensorFaultDetected then Error;
            transition Store_to_Standby Store then Standby;
            transition Error_to_Standby Error if maintenanceReset then Standby;
        }
        
        attribute samplingIntervalElapsed : Boolean;
        attribute maintenanceReset : Boolean;
    }
    
    // ---- Top-level System ----
    part def SnowGaugeStation {
        attribute stationName : String = "Alpine Snow Monitoring Station";
        attribute location : String = "Remote Mountain Site";
        attribute deploymentDate : String;
        
        part ultrasonicSensor : UltrasonicDistanceSensor;
        part loadCell : LoadCell;
        part tempProbe : TemperatureProbe;
        part cpu : CentralProcessingUnit;
        part storage : DataStorageUnit;
        part solarPanel : SolarPanel;
        part battery : BatteryPack;
        part powerController : PowerController;
        
        // Data connections
        connection distanceLink connect ultrasonicSensor.dataOut to cpu.distanceIn;
        connection weightLink connect loadCell.dataOut to cpu.weightIn;
        connection tempLink connect tempProbe.dataOut to cpu.tempIn;
        connection recordLink connect cpu.recordOut to storage.recordIn;
        
        // Power connections
        connection solarToController connect solarPanel.powerOut to powerController.solarIn;
        connection controllerToBattery connect powerController.batteryCharge to battery.chargeIn;
        connection batteryToController connect battery.powerOut to powerController.loadPower;
        
        // Power distribution to components (via powerController.loadPower)
        connection powerToCPU connect powerController.loadPower to cpu.powerIn;
        connection powerToUltrasonic connect powerController.loadPower to ultrasonicSensor.powerIn;
        connection powerToLoadCell connect powerController.loadPower to loadCell.powerIn;
        connection powerToTempProbe connect powerController.loadPower to tempProbe.powerIn;
    }
    
    // ---- Requirements ----
    requirement def AutonomousOperation {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall operate autonomously for extended periods without human intervention."
        }
        require station.battery.chargeLevel > station.battery.minOperationalLevel
    }
    
    requirement def SolarPowered {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall be powered by a solar panel charging a rechargeable battery pack."
        }
        require station.solarPanel.ratedPower > 0.0 [W]
    }
    
    requirement def ContinuousDataCollection {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall continuously collect snowpack data at regular predefined intervals."
        }
        require station.cpu.samplingInterval <= 3600.0 [s]
    }
    
    requirement def SnowDepthMeasurement {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall measure snow depth using an upward-facing ultrasonic distance sensor mounted at a fixed height."
        }
        require station.ultrasonicSensor.mountHeight > 0.0 [m]
    }
    
    requirement def SnowWaterEquivalentMeasurement {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall determine snow water equivalent from load cell weight measurements."
        }
        require station.loadCell.maxLoad > 0.0 [kg]
    }
    
    requirement def AmbientTemperatureMeasurement {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall measure ambient air temperature for environmental context."
        }
        require station.tempProbe.rangeMin <= -40.0 [degC]
        require station.tempProbe.rangeMax >= 60.0 [degC]
    }
    
    requirement def DataStorage {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall save complete measurement records with timestamps to onboard storage."
        }
        require station.storage.capacity > 0
    }
    
    requirement def EnergyEfficientCycling {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall cycle between low-power standby and active measurement modes."
        }
        require station.cpu.samplingInterval > 60.0 [s]
    }
    
    requirement def FaultDetection {
        subject station : SnowGaugeStation;
        objective {
            doc "The station shall enter an error state upon sensor failure to indicate maintenance is required."
        }
        require station.cpu.sensorFaultDetected implies station.cpu.stationStateMachine.Error.isActive
    }
    
    requirement def SnowpackCharacteristicsCalculation {
        subject station : SnowGaugeStation;
        objective {
            doc "The CPU shall calculate snow depth, snow water equivalent, and snow density from sensor data."
        }
        require station.cpu.calcDepth.snowDepth >= 0.0 [m]
        require station.cpu.calcSWE.swe >= 0.0 [kg]
        require station.cpu.calcDensity.density >= 0.0 [kg/m3]
    }
    
    requirement package SnowStationRequirements {
        requirement autonomousOp : AutonomousOperation;
        requirement solarPower : SolarPowered;
        requirement continuousData : ContinuousDataCollection;
        requirement depthMeas : SnowDepthMeasurement;
        requirement sweMeas : SnowWaterEquivalentMeasurement;
        requirement tempMeas : AmbientTemperatureMeasurement;
        requirement dataStore : DataStorage;
        requirement energyCycle : EnergyEfficientCycling;
        requirement faultDetect : FaultDetection;
        requirement calcReq : SnowpackCharacteristicsCalculation;
    }
    
    // ---- System Requirement Satisfaction ----
    part stationInstance : SnowGaugeStation {
        satisfy autonomousOp;
        satisfy solarPower;
        satisfy continuousData;
        satisfy depthMeas;
        satisfy sweMeas;
        satisfy tempMeas;
        satisfy dataStore;
        satisfy energyCycle;
        satisfy faultDetect;
        satisfy calcReq;
    }
}
