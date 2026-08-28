package OccupancySensingUnitModel {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----

    value type Distance :> Real {
        unit m;
    }

    value type ResponseTime :> Real {
        unit s;
    }

    value type ScanFrequency :> Real {
        unit Hz;
    }

    value type AreaValue :> Real {
        unit m2;
    }

    value type Percentage :> Real {
        unit '%';
    }

    value type ConfidenceScore :> Real {
        unit 'ratio';
    }

    value type Voltage :> Real {
        unit V;
    }

    value type RecordCount :> Integer {
        unit 'record';
    }

    value type Accuracy :> Real {
        unit '%';
    }

    // ---- Item definitions ----

    item def Timestamp {
        attribute value : DateTime;
    }

    item def RawOccupancyData {
        attribute timestamp : Timestamp;
        attribute occupantCount : Integer;
        attribute occupancyLevel : Percentage;
        attribute confidence : ConfidenceScore;
    }

    item def ProcessedOccupancyData {
        attribute timestamp : Timestamp;
        attribute occupantCount : Integer;
        attribute occupancyLevel : Percentage;
        attribute confidence : ConfidenceScore;
        attribute filtered : Boolean;
    }

    item def OccupancyRecord {
        attribute timestamp : Timestamp;
        attribute occupantCount : Integer;
        attribute occupancyLevel : Percentage;
        attribute confidence : ConfidenceScore;
        attribute storedAt : DateTime;
    }

    // ---- Port definitions ----

    port def RawDataOut {
        out raw : RawOccupancyData;
    }

    port def RawDataIn {
        in raw : RawOccupancyData;
    }

    port def ProcessedDataOut {
        out processed : ProcessedOccupancyData;
    }

    port def ProcessedDataIn {
        in processed : ProcessedOccupancyData;
    }

    port def RecordOut {
        out record : OccupancyRecord;
    }

    port def PowerIn {
        in voltage : Voltage;
    }

    // ---- Component part definitions ----

    part def OccupancySensor {
        attribute detectionRange : Distance = 8 [m];
        attribute responseTime : ResponseTime = 1.5 [s];
        attribute scanFrequency : ScanFrequency = 2 [Hz];
        attribute roomArea : AreaValue = 50 [m2];
        attribute roomCapacity : Integer = 20;

        port powerPort : PowerIn;
        port rawOut : RawDataOut;

        attribute lastReading : RawOccupancyData;

        action def performScan {
            in roomArea : AreaValue;
            in roomCapacity : Integer;
            out reading : RawOccupancyData;
        }

        action scan : performScan {
            in roomArea = roomArea;
            in roomCapacity = roomCapacity;
            out reading = lastReading;
        }

        state sensorBehavior {
            entry; then scanning;
            state scanning {
                entry do { scan; }
                do send lastReading via rawOut.raw;
                then done;
            }
        }
    }

    part def SignalProcessor {
        attribute filterWindow : Integer = 5;
        attribute noiseThreshold : ConfidenceScore = 0.3 [ratio];

        port powerPort : PowerIn;
        port rawIn : RawDataIn;
        port processedOut : ProcessedDataOut;

        action def filterReading {
            in raw : RawOccupancyData;
            in threshold : ConfidenceScore;
            out processed : ProcessedOccupancyData;
        }

        action filter : filterReading {
            in raw = rawIn.raw;
            in threshold = noiseThreshold;
            out processed to processedOut.processed;
        }

        state processorBehavior {
            entry; then waiting;
            state waiting {
                accept raw : RawOccupancyData via rawIn.raw
                    then filtering;
            }
            state filtering {
                entry do { filter; }
                then waiting;
            }
        }
    }

    part def DataStorage {
        attribute capacity : RecordCount = 10000 [record];
        attribute saveInterval : ResponseTime = 1 [s];
        attribute records : OccupancyRecord[0..*];

        port powerPort : PowerIn;
        port recordIn : ProcessedDataIn;
        port recordOut : RecordOut;

        action def storeRecord {
            in data : ProcessedOccupancyData;
            out record : OccupancyRecord;
        }

        action store : storeRecord {
            in data = recordIn.processed;
            out record to recordOut.record;
        }

        state storageBehavior {
            entry; then idle;
            state idle {
                accept data : ProcessedOccupancyData via recordIn.processed
                    then logging;
            }
            state logging {
                entry do { store; }
                then idle;
            }
        }
    }

    // ---- Top-level Occupancy Sensing Unit ----

    part def OccupancySensingUnit {
        attribute supplyVoltage : Voltage = 5 [V];
        attribute roomArea : AreaValue = 50 [m2];
        attribute roomCapacity : Integer = 20;

        port powerInput : PowerIn;
        port dataOutput : RecordOut;

        part sensor : OccupancySensor {
            attribute redefinition detectionRange = 8 [m];
            attribute redefinition responseTime = 1.5 [s];
            attribute redefinition scanFrequency = 2 [Hz];
            attribute redefinition roomArea = 50 [m2];
            attribute redefinition roomCapacity = 20;
        }

        part processor : SignalProcessor {
            attribute redefinition filterWindow = 5;
            attribute redefinition noiseThreshold = 0.3 [ratio];
        }

        part storage : DataStorage {
            attribute redefinition capacity = 10000 [record];
            attribute redefinition saveInterval = 1 [s];
        }

        // Internal connections
        connection rawLink connect sensor.rawOut to processor.rawIn {
            :>> raw;
        }

        connection processedLink connect processor.processedOut to storage.recordIn {
            :>> processed;
        }

        connection storageOutput connect storage.recordOut to dataOutput {
            :>> record;
        }

        connection powerToSensor connect powerInput to sensor.powerPort {
            :>> voltage;
        }

        connection powerToProcessor connect powerInput to processor.powerPort {
            :>> voltage;
        }

        connection powerToStorage connect powerInput to storage.powerPort {
            :>> voltage;
        }

        // Operational state machine
        state unitStateMachine {
            entry; then initializing;
            state initializing {
                entry do { /* power up subsystems */ }
                then active;
            }
            state active {
                entry do { sensor.scan; }
                then processing;
            }
            state processing {
                entry do { processor.filter; }
                then reporting;
            }
            state reporting {
                entry do { storage.store; }
                then idle;
            }
            state idle {
                // conserve power; cycle back to active after interval
                do wait(0.5 [s]);
                then active;
            }
        }

        // Composite behavior binding
        state behavior :>> unitStateMachine;
    }

    // ---- Requirements ----

    requirement def AccuracyRequirement {
        attribute minAccuracy : Accuracy = 95 [%];
        subject : OccupancySensingUnit;
        objective {
            assert subject.measuredAccuracy >= minAccuracy
        }
    }

    requirement def ResponseTimeRequirement {
        attribute maxResponseTime : ResponseTime = 2 [s];
        subject : OccupancySensingUnit;
        objective {
            assert subject.measuredResponseTime < maxResponseTime
        }
    }

    requirement def PowerSupplyRequirement {
        attribute nominalVoltage : Voltage = 5 [V];
        subject : OccupancySensingUnit;
        objective {
            assert subject.supplyVoltage == nominalVoltage
        }
    }

    requirement def DetectionRangeRequirement {
        attribute requiredRange : Distance = 8 [m];
        subject : OccupancySensor;
        objective {
            assert subject.detectionRange >= requiredRange
        }
    }

    requirement def ScanFrequencyRequirement {
        attribute requiredFrequency : ScanFrequency = 2 [Hz];
        subject : OccupancySensor;
        objective {
            assert subject.scanFrequency >= requiredFrequency
        }
    }

    requirement def StorageCapacityRequirement {
        attribute minRecords : RecordCount = 1000 [record];
        subject : DataStorage;
        objective {
            assert subject.capacity >= minRecords
        }
    }

    requirement accuracyReq : AccuracyRequirement {
        :>> subject : OccupancySensingUnit;
    }

    requirement responseTimeReq : ResponseTimeRequirement {
        :>> subject : OccupancySensingUnit;
    }

    requirement powerReq : PowerSupplyRequirement {
        :>> subject : OccupancySensingUnit;
    }

    requirement detectionRangeReq : DetectionRangeRequirement {
        :>> subject : OccupancySensor;
    }

    requirement scanFreqReq : ScanFrequencyRequirement {
        :>> subject : OccupancySensor;
    }

    requirement storageCapReq : StorageCapacityRequirement {
        :>> subject : DataStorage;
    }

    // ---- Verification actions ----

    action def verifyAccuracy {
        in unit : OccupancySensingUnit;
        in referenceCount : Integer;
        out pass : Boolean;
    }

    action def verifyResponseTime {
        in unit : OccupancySensingUnit;
        out measured : ResponseTime;
        out pass : Boolean;
    }

    action def verifyPowerSupply {
        in unit : OccupancySensingUnit;
        out pass : Boolean;
    }

}
