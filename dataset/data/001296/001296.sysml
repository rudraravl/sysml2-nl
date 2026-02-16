package TriangulationPositioningSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def AngleMeasurement :> Real;
    attribute def DistanceMeasurement :> LengthValue;
    
    item def Coordinates {
        attribute x : LengthValue;
        attribute y : LengthValue;
        attribute z : LengthValue;
    }
    
    item def BeaconSignal {
        attribute beaconId : String;
        attribute beaconPosition : Coordinates;
        attribute signalStrength : Real;
        attribute timestamp : TimeValue;
    }
    
    item def RangeData {
        attribute distance : DistanceMeasurement;
        attribute angle : AngleMeasurement;
        attribute sourceId : String;
    }
    
    item def PositionEstimate {
        attribute location : Coordinates;
        attribute accuracy : LengthValue;
        attribute confidence : Real;
        attribute calculationTime : TimeValue;
    }
    
    port def SignalPort {
        in item signal : BeaconSignal;
    }
    
    port def RangePort {
        out item range : RangeData;
    }
    
    port def PositionPort {
        out item position : PositionEstimate;
    }
    
    part def Beacon {
        attribute beaconIdentifier : String;
        attribute fixedPosition : Coordinates;
        attribute transmitPower : PowerValue;
        
        port signalOut : ~SignalPort;
        
        perform action transmitSignal {
            out signal : BeaconSignal;
        }
    }
    
    part def RangeFinder {
        attribute rangeFinderId : String;
        attribute measurementNoise : LengthValue;
        
        port signalIn : SignalPort;
        port rangeOut : RangePort;
        
        perform action calculateRange {
            in receivedSignal : BeaconSignal;
            out rangeData : RangeData;
        }
    }
    
    part def TriangulationProcessor {
        attribute processorId : String;
        attribute minimumBeacons : Integer = 3;
        
        port rangeIn1 : ~RangePort;
        port rangeIn2 : ~RangePort;
        port rangeIn3 : ~RangePort;
        port positionOut : PositionPort;
        
        perform action computePosition {
            in range1 : RangeData;
            in range2 : RangeData;
            in range3 : RangeData;
            out estimate : PositionEstimate;
        }
    }
    
    part def DataValidator {
        attribute validatorId : String;
        attribute maxAcceptableError : LengthValue;
        
        perform action validateMeasurements {
            in ranges : RangeData[*];
            out valid : Boolean;
            out errorMetric : Real;
        }
    }
    
    part def PositionDisplay {
        attribute displayId : String;
        
        port positionIn : ~PositionPort;
        
        perform action updateDisplay {
            in currentPosition : PositionEstimate;
        }
    }
    
    action def TriangulationCycle {
        first start;
        
        then action acquireSignals {
            out signal1 : BeaconSignal;
            out signal2 : BeaconSignal;
            out signal3 : BeaconSignal;
        }
        
        then action measureRanges {
            in s1 : BeaconSignal = acquireSignals.signal1;
            in s2 : BeaconSignal = acquireSignals.signal2;
            in s3 : BeaconSignal = acquireSignals.signal3;
            out r1 : RangeData;
            out r2 : RangeData;
            out r3 : RangeData;
        }
        
        then action validate {
            in ranges : RangeData[3] = (measureRanges.r1, measureRanges.r2, measureRanges.r3);
            out isValid : Boolean;
        }
        
        then decide;
            if validate.isValid then calculate;
            if not validate.isValid then retry;
        
        action calculate {
            in range1 : RangeData = measureRanges.r1;
            in range2 : RangeData = measureRanges.r2;
            in range3 : RangeData = measureRanges.r3;
            out finalPosition : PositionEstimate;
        }
        
        then action output {
            in pos : PositionEstimate = calculate.finalPosition;
        }
        then done;
        
        action retry;
        then start;
    }
    
    part def TriangulationSystem {
        doc /* A positioning system that determines the location of a receiver by measuring 
                distances to three or more fixed beacons with known positions and computing 
                the intersection point using geometric triangulation. */
        
        attribute systemStatus : String;
        attribute operationalMode : String;
        
        part beacon1 : Beacon;
        part beacon2 : Beacon;
        part beacon3 : Beacon;
        part rangeFinder1 : RangeFinder;
        part rangeFinder2 : RangeFinder;
        part rangeFinder3 : RangeFinder;
        part processor : TriangulationProcessor;
        part validator : DataValidator;
        part display : PositionDisplay;
        
        connection beacon1ToRF1 connect beacon1.signalOut to rangeFinder1.signalIn;
        connection beacon2ToRF2 connect beacon2.signalOut to rangeFinder2.signalIn;
        connection beacon3ToRF3 connect beacon3.signalOut to rangeFinder3.signalIn;
        
        connection rf1ToProc connect rangeFinder1.rangeOut to processor.rangeIn1;
        connection rf2ToProc connect rangeFinder2.rangeOut to processor.rangeIn2;
        connection rf3ToProc connect rangeFinder3.rangeOut to processor.rangeIn3;
        
        connection procToDisplay connect processor.positionOut to display.positionIn;
        
        perform action operationCycle : TriangulationCycle[*] ordered;
    }
    
    state def TriangulationSystemState {
        in attribute statusRef : String;
        
        entry; then idle;
        
        state idle {
            entry assign statusRef := "Ready";
        }
        
        state acquiring {
            entry assign statusRef := "Acquiring Signals";
        }
        
        state processing {
            entry assign statusRef := "Processing Data";
            
            state validating;
            state computing;
            state complete;
            
            transition validating_to_computing
                first validating
                then computing;
            
            transition computing_to_complete
                first computing
                then complete;
        }
        
        state error {
            entry assign statusRef := "Error - Invalid Data";
        }
        
        transition idle_to_acquiring
            first idle
            then acquiring;
        
        transition acquiring_to_processing
            first acquiring
            then processing;
        
        transition processing_to_idle
            first processing.complete
            then idle;
        
        transition processing_to_error
            first processing.validating
            then error;
        
        transition error_to_idle
            first error
            then idle;
    }
    
    part triangulationSystem : TriangulationSystem {
        attribute :>> systemStatus = "Initialized";
        attribute :>> operationalMode = "Standard";
        
        part :>> beacon1 {
            attribute :>> beaconIdentifier = "BEACON_A";
            attribute :>> fixedPosition {
                attribute :>> x = 0.0 [m];
                attribute :>> y = 0.0 [m];
                attribute :>> z = 0.0 [m];
            }
            attribute :>> transmitPower = 10.0 [W];
        }
        
        part :>> beacon2 {
            attribute :>> beaconIdentifier = "BEACON_B";
            attribute :>> fixedPosition {
                attribute :>> x = 100.0 [m];
                attribute :>> y = 0.0 [m];
                attribute :>> z = 0.0 [m];
            }
            attribute :>> transmitPower = 10.0 [W];
        }
        
        part :>> beacon3 {
            attribute :>> beaconIdentifier = "BEACON_C";
            attribute :>> fixedPosition {
                attribute :>> x = 50.0 [m];
                attribute :>> y = 86.6 [m];
                attribute :>> z = 0.0 [m];
            }
            attribute :>> transmitPower = 10.0 [W];
        }
        
        part :>> rangeFinder1 {
            attribute :>> rangeFinderId = "RF_1";
            attribute :>> measurementNoise = 0.1 [m];
        }
        
        part :>> rangeFinder2 {
            attribute :>> rangeFinderId = "RF_2";
            attribute :>> measurementNoise = 0.1 [m];
        }
        
        part :>> rangeFinder3 {
            attribute :>> rangeFinderId = "RF_3";
            attribute :>> measurementNoise = 0.1 [m];
        }
        
        part :>> processor {
            attribute :>> processorId = "PROC_MAIN";
            attribute :>> minimumBeacons = 3;
        }
        
        part :>> validator {
            attribute :>> validatorId = "VAL_1";
            attribute :>> maxAcceptableError = 2.0 [m];
        }
        
        part :>> display {
            attribute :>> displayId = "DISP_1";
        }
        
        exhibit state systemBehavior : TriangulationSystemState {
            in attribute :>> statusRef = systemStatus;
        }
    }
    
    requirement def PositionAccuracyRequirement {
        doc /* The triangulation system shall determine position with specified accuracy. */
        
        subject system : TriangulationSystem;
        
        attribute maxPositionError : LengthValue = 1.0 [m];
    }
    
    requirement def MinimumBeaconRequirement {
        doc /* The system shall use at least three beacons for triangulation. */
        
        subject system : TriangulationSystem;
    }
    
    requirement def ResponseTimeRequirement {
        doc /* The system shall complete position calculation within maximum time. */
        
        subject system : TriangulationSystem;
        
        attribute maxResponseTime : TimeValue = 1.0 [s];
    }
    
    requirement <'TRI-SYS-001'> primaryTriangulationRequirement {
        doc /* The triangulation system shall determine the precise location of a receiver 
                by measuring distances from at least three fixed beacons with known positions 
                and computing the intersection point through geometric triangulation, achieving 
                position accuracy within one meter under normal operating conditions. */
        
        subject system : TriangulationSystem;
        
        require accuracyReq : PositionAccuracyRequirement {
            subject sysRef : TriangulationSystem = system;
        }
        
        require beaconReq : MinimumBeaconRequirement {
            subject sysRef : TriangulationSystem = system;
        }
        
        require responseReq : ResponseTimeRequirement {
            subject sysRef : TriangulationSystem = system;
        }
    }
}
