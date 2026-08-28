package SeedCountingMachine {
    import ScalarValues::*;
    import ISQ::*;
    
    // ===== Value Types =====
    
    value type MassFlowRate > Real {
        unit g/min;
    }
    
    value type BeltSpeed > Real {
        unit mm/s;
    }
    
    value type Count > Integer {
        unit "count";
    }
    
    value type Voltage > Real {
        unit V;
    }
    
    value type Frequency > Real {
        unit Hz;
    }
    
    value type DurationValue > Real {
        unit s;
    }
    
    // ===== Item Types =====
    
    item def Seed {
        attribute averageMass : MassValue;
        attribute diameter : LengthValue;
    }
    
    item def SeedBatch {
        attribute targetCount : Count;
        attribute currentCount : Count;
        attribute seeds : Seed[0..*];
    }
    
    item def ElectricalPulse {
        attribute amplitude : Voltage;
        attribute duration : DurationValue;
    }
    
    // ===== Port Definitions =====
    
    port def SeedFlowPort {
        out seed : Seed[0..*];
    }
    
    port def SeedFlowInPort {
        in seed : Seed[0..*];
    }
    
    port def PulsePort {
        out pulse : ElectricalPulse;
    }
    
    port def PulseInPort {
        in pulse : ElectricalPulse;
    }
    
    port def CommandPort {
        in command : CommandSignal;
    }
    
    port def StatusPort {
        out status : StatusMessage;
    }
    
    port def ControlSignalPort {
        out signal : ControlSignal;
    }
    
    port def ControlSignalInPort {
        in signal : ControlSignal;
    }
    
    item def CommandSignal {
        attribute commandType : CommandType;
    }
    
    enum def CommandType {
        START;
        STOP;
        RESET;
        SET_TARGET;
    }
    
    item def StatusMessage {
        attribute state : String;
        attribute currentCount : Count;
        attribute targetCount : Count;
    }
    
    item def ControlSignal {
        attribute action : ControlAction;
        attribute value : Real;
    }
    
    enum def ControlAction {
        RUN_FEEDER;
        STOP_FEEDER;
        RUN_CONVEYOR;
        STOP_CONVEYOR;
        SET_BELT_SPEED;
        SET_FEED_RATE;
    }
    
    // ===== Requirements =====
    
    requirement def CountingAccuracyRequirement {
        doc <<The seed counting machine shall count seeds with an accuracy of at least 99.5%.>>
        attribute minAccuracy : Real = 0.995;
        subject : SeedCountingMachine;
        objective {
            subject.accuracy >= minAccuracy
        }
    }
    
    requirement def SingleFileTransportRequirement {
        doc <<The conveyor belt shall transport seeds in a single file line to prevent clumping.>>
        subject : ConveyorBelt;
        objective {
            subject.maxSeedsPerBeltWidth == 1
        }
    }
    
    requirement def TargetCountRequirement {
        doc <<The controller shall stop the feeder when the target count is reached and allow the conveyor to clear.>>
        subject : CountingController;
        objective {
            subject.batchComplete == true
        }
    }
    
    requirement def FaultDetectionRequirement {
        doc <<The system shall detect faults and enter an error state, alerting the operator.>>
        subject : SeedCountingMachine;
        objective {
            subject.canDetectFaults == true
        }
    }
    
    // ===== Component Part Definitions =====
    
    part def HopperFeeder {
        port seedOut : SeedFlowPort;
        port controlIn : ControlSignalInPort;
        
        attribute capacity : MassValue = 500 [g];
        attribute feedRate : MassFlowRate = 10 [g/min];
        attribute isDispensing : Boolean = false;
        
        action def DispenseSeeds {
            in seedStream : Seed[0..*];
            out dispensedSeed : Seed[0..*];
        }
        
        perform action dispense : DispenseSeeds;
        
        state def FeederBehavior {
            entry;
            
            state Off {
                entry;
            }
            
            state Dispensing {
                entry;
                do dispense;
            }
            
            transition off_to_dispensing
                from Off to Dispensing
                when controlIn.signal.action == ControlAction::RUN_FEEDER;
            
            transition dispensing_to_off
                from Dispensing to Off
                when controlIn.signal.action == ControlAction::STOP_FEEDER;
        }
        
        exhibit state behavior : FeederBehavior;
        
        satisfy CountingAccuracyRequirement;
    }
    
    part def ConveyorBelt {
        port seedIn : SeedFlowInPort;
        port seedOut : SeedFlowPort;
        port controlIn : ControlSignalInPort;
        
        attribute beltSpeed : BeltSpeed = 50 [mm/s];
        attribute beltLength : LengthValue = 600 [mm];
        attribute maxSeedsPerBeltWidth : Integer = 1;
        attribute isRunning : Boolean = false;
        
        action def TransportSeeds {
            in incomingSeed : Seed[0..*];
            out outgoingSeed : Seed[0..*];
        }
        
        perform action transport : TransportSeeds;
        
        state def ConveyorBehavior {
            entry;
            
            state Stopped {
                entry;
            }
            
            state Running {
                entry;
                do transport;
            }
            
            transition stopped_to_running
                from Stopped to Running
                when controlIn.signal.action == ControlAction::RUN_CONVEYOR;
            
            transition running_to_stopped
                from Running to Stopped
                when controlIn.signal.action == ControlAction::STOP_CONVEYOR;
        }
        
        exhibit state behavior : ConveyorBehavior;
        
        satisfy SingleFileTransportRequirement;
    }
    
    part def OpticalSensor {
        port seedIn : SeedFlowInPort;
        port seedOut : SeedFlowPort;
        port pulseOut : PulsePort;
        
        attribute beamActive : Boolean = true;
        attribute detectionFrequency : Frequency = 1000 [Hz];
        attribute pulseCount : Count = 0;
        
        action def DetectSeed {
            in incomingSeed : Seed;
            out detectedPulse : ElectricalPulse;
            out passedSeed : Seed;
        }
        
        perform action detect : DetectSeed;
        
        state def SensorBehavior {
            entry;
            
            state BeamUninterrupted {
                entry;
            }
            
            state BeamInterrupted {
                entry;
                do detect;
            }
            
            transition uninterrupted_to_interrupted
                from BeamUninterrupted to BeamInterrupted
                when seedIn.seed->size() > 0;
            
            transition interrupted_to_uninterrupted
                from BeamInterrupted to BeamUninterrupted
                when seedIn.seed->size() == 0;
        }
        
        exhibit state behavior : SensorBehavior;
    }
    
    part def CountingController {
        port pulseIn : PulseInPort;
        port commandIn : CommandPort;
        port feederControl : ControlSignalPort;
        port conveyorControl : ControlSignalPort;
        port statusOut : StatusPort;
        
        attribute targetCount : Count = 100;
        attribute currentCount : Count = 0;
        attribute batchComplete : Boolean = false;
        attribute canDetectFaults : Boolean = true;
        attribute accuracy : Real = 0.998;
        
        action def ProcessPulse {
            in pulse : ElectricalPulse;
            out newCount : Count;
        }
        
        action def CompareCount {
            in count : Count;
            in target : Count;
            out reached : Boolean;
        }
        
        action def IssueControl {
            in action : ControlAction;
            out signal : ControlSignal;
        }
        
        perform action processPulse : ProcessPulse;
        perform action compareCount : CompareCount;
        perform action issueControl : IssueControl;
        
        state def ControllerStateMachine {
            entry;
            
            state Idle {
                entry;
                do issueControl(ControlAction::STOP_FEEDER);
                do issueControl(ControlAction::STOP_CONVEYOR);
            }
            
            state Ready {
                entry;
                do issueControl(ControlAction::RUN_CONVEYOR);
            }
            
            state Feeding {
                entry;
                do issueControl(ControlAction::RUN_FEEDER);
            }
            
            state Counting {
                entry;
                do processPulse;
                do compareCount;
            }
            
            state Clearing {
                entry;
                do issueControl(ControlAction::STOP_FEEDER);
            }
            
            state Complete {
                entry;
                do issueControl(ControlAction::STOP_CONVEYOR);
            }
            
            state Error {
                entry;
            }
            
            transition idle_to_ready
                from Idle to Ready
                when commandIn.command.commandType == CommandType::START;
            
            transition ready_to_feeding
                from Ready to Feeding
                when pulseIn.pulse != null;
            
            transition feeding_to_counting
                from Feeding to Counting
                when pulseIn.pulse != null;
            
            transition counting_to_clearing
                from Counting to Clearing
                when currentCount >= targetCount;
            
            transition clearing_to_complete
                from Clearing to Complete
                when pulseIn.pulse == null;
            
            transition any_to_error
                from Idle to Error
                when canDetectFaults && faultDetected;
            
            transition feeding_to_error
                from Feeding to Error
                when canDetectFaults && faultDetected;
            
            transition counting_to_error
                from Counting to Error
                when canDetectFaults && faultDetected;
            
            transition complete_to_idle
                from Complete to Idle
                when commandIn.command.commandType == CommandType::RESET;
            
            transition error_to_idle
                from Error to Idle
                when commandIn.command.commandType == CommandType::RESET;
            
            attribute faultDetected : Boolean = false;
        }
        
        exhibit state behavior : ControllerStateMachine;
        
        satisfy TargetCountRequirement;
        satisfy FaultDetectionRequirement;
    }
    
    part def DisplayUnit {
        port statusIn : StatusPort;
        
        attribute displayText : String;
        attribute currentCount : Count = 0;
        attribute targetCount : Count = 100;
        attribute systemState : String = "Idle";
        
        action def UpdateDisplay {
            in status : StatusMessage;
        }
        
        perform action updateDisplay : UpdateDisplay;
        
        state def DisplayBehavior {
            entry;
            
            state ShowingIdle {
                entry;
                attribute displayText = "Idle";
            }
            
            state ShowingCounting {
                entry;
                attribute displayText = "Counting";
            }
            
            state ShowingComplete {
                entry;
                attribute displayText = "Complete";
            }
            
            state ShowingError {
                entry;
                attribute displayText = "Error";
            }
            
            transition to_idle
                from ShowingCounting to ShowingIdle
                when statusIn.status.state == "Idle";
            
            transition to_counting
                from ShowingIdle to ShowingCounting
                when statusIn.status.state == "Counting";
            
            transition to_complete
                from ShowingCounting to ShowingComplete
                when statusIn.status.state == "Complete";
            
            transition to_error
                from ShowingCounting to ShowingError
                when statusIn.status.state == "Error";
        }
        
        exhibit state behavior : DisplayBehavior;
    }
    
    part def CollectionBin {
        port seedIn : SeedFlowInPort;
        
        attribute capacity : Count = 500;
        attribute collectedCount : Count = 0;
        attribute isFull : Boolean = false;
        
        action def CollectSeeds {
            in incomingSeed : Seed[0..*];
        }
        
        perform action collect : CollectSeeds;
        
        state def BinBehavior {
            entry;
            
            state Empty {
                entry;
            }
            
            state Filling {
                entry;
                do collect;
            }
            
            state Full {
                entry;
                attribute isFull = true;
            }
            
            transition empty_to_filling
                from Empty to Filling
                when seedIn.seed->size() > 0;
            
            transition filling_to_full
                from Filling to Full
                when collectedCount >= capacity;
        }
        
        exhibit state behavior : BinBehavior;
    }
    
    // ===== Top-Level System =====
    
    part def SeedCountingMachine {
        port operatorCommand : CommandPort;
        port operatorDisplay : StatusPort;
        
        attribute accuracy : Real = 0.998;
        attribute canDetectFaults : Boolean = true;
        
        part hopperFeeder : HopperFeeder {
            attribute capacity : MassValue = 500 [g];
        }
        
        part conveyorBelt : ConveyorBelt {
            attribute beltSpeed : BeltSpeed = 50 [mm/s];
        }
        
        part opticalSensor : OpticalSensor {
            attribute detectionFrequency : Frequency = 1000 [Hz];
        }
        
        part countingController : CountingController {
            attribute targetCount : Count = 100;
        }
        
        part displayUnit : DisplayUnit;
        
        part collectionBin : CollectionBin {
            attribute capacity : Count = 500;
        }
        
        // Connections
        connection seedFlow1 : SeedFlow connect
            hopperFeeder.seedOut to conveyorBelt.seedIn;
        
        connection seedFlow2 : SeedFlow connect
            conveyorBelt.seedOut to opticalSensor.seedIn;
        
        connection seedFlow3 : SeedFlow connect
            opticalSensor.seedOut to collectionBin.seedIn;
        
        connection pulseConnection : PulseFlow connect
            opticalSensor.pulseOut to countingController.pulseIn;
        
        connection feederControlConnection : ControlSignalFlow connect
            countingController.feederControl to hopperFeeder.controlIn;
        
        connection conveyorControlConnection : ControlSignalFlow connect
            countingController.conveyorControl to conveyorBelt.controlIn;
        
        connection statusConnection : StatusFlow connect
            countingController.statusOut to displayUnit.statusIn;
        
        connection operatorCommandConnection : CommandFlow connect
            operatorCommand to countingController.commandIn;
        
        connection operatorDisplayConnection : StatusFlow connect
            countingController.statusOut to operatorDisplay;
        
        satisfy CountingAccuracyRequirement;
        satisfy FaultDetectionRequirement;
    }
    
    // ===== Connection Definitions =====
    
    connection def SeedFlow {
        end seedSource : SeedFlowPort;
        end seedSink : SeedFlowInPort;
        flow seed : Seed[0..*];
    }
    
    connection def PulseFlow {
        end pulseSource : PulsePort;
        end pulseSink : PulseInPort;
        flow pulse : ElectricalPulse;
    }
    
    connection def ControlSignalFlow {
        end controlSource : ControlSignalPort;
        end controlSink : ControlSignalInPort;
        flow signal : ControlSignal;
    }
    
    connection def StatusFlow {
        end statusSource : StatusPort;
        end statusSink : StatusPort;
        flow status : StatusMessage;
    }
    
    connection def CommandFlow {
        end commandSource : CommandPort;
        end commandSink : CommandPort;
        flow command : CommandSignal;
    }
}
