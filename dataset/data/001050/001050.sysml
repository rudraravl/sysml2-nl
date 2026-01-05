package FishCounterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FishCount :> Integer;
    attribute def DetectionEvent;
    attribute def SystemCommand;
    attribute def Timestamp :> String;
    
    item def Fish {
        attribute species : String;
        attribute estimatedLength : LengthValue;
        attribute direction : String;
    }
    
    port def SensorPort {
        out detectionSignal : DetectionEvent;
        out fishData : Fish;
    }
    
    port def ProcessingPort {
        in rawDetection : DetectionEvent;
        in fishData : Fish;
        out validatedDetection : Boolean;
    }
    
    port def CounterPort {
        in increment : Boolean;
        out currentCount : FishCount;
    }
    
    port def DisplayPort {
        in countData : FishCount;
    }
    
    port def PowerPort {
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
    }
    
    part def OpticalSensor {
        port sensorOut : SensorPort;
        port powerIn : ~PowerPort;
        
        attribute detectionThreshold : LengthValue;
        attribute samplingRate : FrequencyValue;
        
        action detectFish {
            out detection : DetectionEvent;
            out fishInfo : Fish;
        }
    }
    
    part def SignalProcessor {
        port processingIn : ~ProcessingPort;
        port processingOut : ProcessingPort;
        port powerIn : ~PowerPort;
        
        attribute filterThreshold : Real;
        
        action validateDetection {
            in rawSignal : DetectionEvent;
            in fishData : Fish;
            out isValid : Boolean;
        }
        
        action filterNoise {
            in signal : DetectionEvent;
            out cleanSignal : DetectionEvent;
        }
    }
    
    part def CountingModule {
        port counterIn : ~CounterPort;
        port counterOut : CounterPort;
        port powerIn : ~PowerPort;
        
        attribute upstreamCount : FishCount := 0;
        attribute downstreamCount : FishCount := 0;
        attribute netCount : FishCount := 0;
        
        action incrementCounter {
            in shouldIncrement : Boolean;
            in direction : String;
            inout upstream : FishCount;
            inout downstream : FishCount;
            inout net : FishCount;
        }
        
        action resetCounters {
            in resetCommand : SystemCommand;
            inout upstream : FishCount;
            inout downstream : FishCount;
            inout net : FishCount;
        }
    }
    
    part def DisplayController {
        port displayIn : ~DisplayPort;
        port powerIn : ~PowerPort;
        
        attribute displayedUpstream : FishCount;
        attribute displayedDownstream : FishCount;
        attribute displayedNet : FishCount;
        
        action updateDisplay {
            in count : FishCount;
        }
        
        action formatOutput {
            in count : FishCount;
            out formattedText : String;
        }
    }
    
    part def DataLogger {
        port powerIn : ~PowerPort;
        
        attribute logBuffer : FishCount[*];
        attribute timestamps : Timestamp[*];
        attribute storageCapacity : Integer;
        
        action logCount {
            in count : FishCount;
            in time : Timestamp;
            inout buffer : FishCount[*];
            inout times : Timestamp[*];
        }
        
        action exportData {
            in buffer : FishCount[*];
            in times : Timestamp[*];
            out dataFile : String;
        }
    }
    
    part def PowerSupply {
        port powerOut : PowerPort;
        
        attribute inputVoltage : ElectricPotentialValue;
        attribute outputVoltage : ElectricPotentialValue := 12.0 [SI::V];
        attribute maxCurrent : ElectricCurrentValue := 2.0 [SI::A];
    }
    
    action def MonitorAndDetect {
        out fishDetected : DetectionEvent;
        out fishInfo : Fish;
    }
    
    action def ProcessSignal {
        in detection : DetectionEvent;
        in fishData : Fish;
        out validated : Boolean;
    }
    
    action def UpdateCount {
        in valid : Boolean;
        in direction : String;
        inout upstreamTotal : FishCount;
        inout downstreamTotal : FishCount;
        inout netTotal : FishCount;
    }
    
    action def RecordAndDisplay {
        in count : FishCount;
        in time : Timestamp;
    }
    
    action def OperateFishCounter {
        first start;
        then merge continuousOperation;
        
        action monitor : MonitorAndDetect {
            out detected : DetectionEvent;
            out info : Fish;
        }
        
        then action process : ProcessSignal {
            in detection = monitor.detected;
            in fishData = monitor.info;
            out isValidated : Boolean;
        }
        
        then decide;
            if process.isValidated then updateAndRecord;
            if !process.isValidated then continuousOperation;
        
        action updateAndRecord {
            first action update : UpdateCount {
                in valid = process.isValidated;
                in direction = monitor.info.direction;
                inout upstreamTotal;
                inout downstreamTotal;
                inout netTotal;
            }
            
            then action record : RecordAndDisplay {
                in count = update.netTotal;
                in time;
            }
        }
        
        then continuousOperation;
    }
    
    part def FishCounterSystem {
        attribute systemName : String;
        attribute installationLocation : String;
        attribute operationalStatus : String;
        
        part sensor : OpticalSensor;
        part processor : SignalProcessor;
        part counter : CountingModule;
        part display : DisplayController;
        part logger : DataLogger;
        part power : PowerSupply;
        
        connection sensorToProcessor connect sensor.sensorOut to processor.processingIn;
        connection processorToCounter connect processor.processingOut to counter.counterIn;
        connection counterToDisplay connect counter.counterOut to display.displayIn;
        
        connection powerToSensor connect power.powerOut to sensor.powerIn;
        connection powerToProcessor connect power.powerOut to processor.powerIn;
        connection powerToCounter connect power.powerOut to counter.powerIn;
        connection powerToDisplay connect power.powerOut to display.powerIn;
        connection powerToLogger connect power.powerOut to logger.powerIn;
    }
    
    part fishCounter : FishCounterSystem {
        :>> systemName = "Automated Fish Counter";
        
        perform action operate[*] ordered references OperateFishCounter;
        
        part sensor {
            :>> detectionThreshold = 0.05 [SI::m];
            :>> samplingRate = 30.0 [SI::Hz];
            perform operate.monitor;
        }
        
        part processor {
            :>> filterThreshold = 0.85;
            perform operate.process;
        }
        
        part counter {
            perform operate.updateAndRecord.update;
        }
        
        part display {
            perform operate.updateAndRecord.record;
        }
        
        part logger {
            :>> storageCapacity = 1000000;
            perform operate.updateAndRecord.record;
        }
        
        part power {
            :>> inputVoltage = 120.0 [SI::V];
        }
    }
    
    requirement def FunctionalRequirement;
    requirement def PerformanceRequirement;
    requirement def EnvironmentalRequirement;
    
    requirement <'FC-REQ-001'> primaryFunction : FunctionalRequirement {
        doc /*
            The primary function of the Fish Counter System is to automatically and 
            continuously monitor a waterway passage, detect individual fish as they 
            pass through the monitored zone, accurately count them while distinguishing 
            upstream from downstream migration, maintain running totals, and provide 
            real-time display and data logging capabilities for fishery management and 
            ecological research purposes.
        */
        
        subject fishCounter;
        
        require constraint operationalContinuity {
            doc /* The system shall operate continuously during monitoring periods. */
        }
    }
    
    requirement <'FC-REQ-002'> detectionAccuracy : PerformanceRequirement {
        doc /* The system shall achieve minimum 95% detection accuracy for fish within size range. */
        
        subject fishCounter.sensor;
        
        require constraint accuracyThreshold {
            0.95 <= 1.0
        }
    }
    
    requirement <'FC-REQ-003'> countingCapacity : PerformanceRequirement {
        doc /* The system shall process up to 300 fish detections per minute. */
        
        subject fishCounter.counter;
        
        require constraint throughput {
            300 <= 500
        }
    }
    
    requirement <'FC-REQ-004'> environmentalRobustness : EnvironmentalRequirement {
        doc /* The system shall operate in outdoor waterway conditions with temperature range -10°C to 50°C. */
        
        subject fishCounter;
        
        require constraint temperatureRange {
            doc /* Operating temperature: -10°C to 50°C */
        }
        
        require constraint waterResistance {
            doc /* Sensor components shall be waterproof to IP68 standard. */
        }
    }
    
    requirement <'FC-REQ-005'> dataRetention : FunctionalRequirement {
        doc /* The system shall store count data with timestamps for minimum 365 days. */
        
        subject fishCounter.logger;
        
        require constraint storageCapacity {
            fishCounter.logger.storageCapacity >= 100000
        }
    }
    
    requirement <'FC-SYS-001'> systemRequirements {
        doc /* 
            The Fish Counter System shall provide automated fish passage monitoring 
            with high accuracy detection, bidirectional counting, real-time display, 
            and long-term data logging in challenging environmental conditions.
        */
        
        require primaryFunction;
        require detectionAccuracy;
        require countingCapacity;
        require environmentalRobustness;
        require dataRetention;
    }
}
