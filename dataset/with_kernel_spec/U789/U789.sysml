package OccupancySensingSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    package Definitions {
        attribute def VoltageValue :> Real;
        
        item def RawMeasurement {
            attribute timestamp : TimeInstantValue;
            attribute occupantCount : Integer;
            attribute occupancyLevel : Real;
            attribute confidence : Real;
        }
        
        item def ProcessedMeasurement {
            attribute timestamp : TimeInstantValue;
            attribute occupantCount : Integer;
            attribute occupancyLevel : Real;
            attribute confidence : Real;
        }
        
        port def RawDataOut {
            out item raw : RawMeasurement;
        }
        
        port def ProcessedDataOut {
            out item processed : ProcessedMeasurement;
        }
        
        part def Room {
            attribute area : AreaValue = 50 [m2];
            attribute capacity : Integer = 20;
        }
        
        part def OccupancySensor {
            attribute detectionRange : LengthValue = 8 [m];
            attribute responseTime : DurationValue = 1.5 [s];
            attribute scanFrequency : FrequencyValue = 2 [Hz];
            port rawOut : RawDataOut;
        }
        
        part def SignalProcessor {
            port rawIn : ~RawDataOut;
            port processedOut : ProcessedDataOut;
        }
        
        part def DataStorage {
            attribute maxRecords : Integer = 10000;
            attribute saveInterval : DurationValue = 1 [s];
            port dataIn : ~ProcessedDataOut;
        }
        
        action def MeasureAction {
            in room : Room;
            out raw : RawMeasurement;
        }
        
        action def ProcessAction {
            in raw : RawMeasurement;
            out processed : ProcessedMeasurement;
        }
        
        action def StoreAction {
            in processed : ProcessedMeasurement;
        }
        
        action def ConservePowerAction;
        
        attribute def InitializeComplete;
        attribute def MeasurementComplete;
        attribute def ProcessingComplete;
        attribute def ReportingComplete;
        
        state def OperatingStates;
        
        requirement def AccuracyRequirement {
            /* The system shall achieve at least 95% accuracy in occupancy counting. */
            attribute minAccuracy : Real = 0.95;
        }
        
        requirement def ResponseTimeRequirement {
            /* The system shall respond within 2 seconds from measurement to report. */
            attribute maxResponseTime : DurationValue = 2 [s];
        }
        
        requirement def PowerSupplyRequirement {
            /* The system shall operate on a standard low-voltage power supply. */
            attribute maxVoltage : VoltageValue = 5 [V];
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part occupancySensingUnit {
            attribute supplyVoltage : VoltageValue = 5 [V];
            
            part room : Room;
            part sensor : OccupancySensor;
            part processor : SignalProcessor;
            part storage : DataStorage;
            
            flow of raw : RawMeasurement
                from sensor.rawOut.raw to processor.rawIn.raw;
            
            flow of processed : ProcessedMeasurement
                from processor.processedOut.processed to storage.dataIn.processed;
            
            action measure : MeasureAction {
                in room = room;
                out raw = sensor.rawOut.raw;
            }
            action process : ProcessAction {
                in raw = processor.rawIn.raw;
                out processed = processor.processedOut.processed;
            }
            action store : StoreAction {
                in processed = storage.dataIn.processed;
            }
            action conservePower : ConservePowerAction;
            
            exhibit state operatingStates : OperatingStates {
                entry; then initializing;
                
                state initializing;
                accept InitializeComplete then active;
                
                state active {
                    entry measure;
                }
                accept MeasurementComplete then processing;
                
                state processing {
                    entry process;
                }
                accept ProcessingComplete then reporting;
                
                state reporting {
                    entry store;
                }
                accept ReportingComplete then idle;
                
                state idle {
                    entry conservePower;
                }
                accept after 1 [s] then active;
            }
            
            satisfy accuracyReq : AccuracyRequirement;
            satisfy responseTimeReq : ResponseTimeRequirement;
            satisfy powerReq : PowerSupplyRequirement;
        }
    }
}
