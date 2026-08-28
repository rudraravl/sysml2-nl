package OperatorSwitchboardSystem {
    import ScalarValues::*;
    
    // --- Value Types & Items ---
    value type Duration :> Real {
        unit "s";
    }
    
    attribute def CallRecord {
        attribute callerNumber : String;
        attribute receiverNumber : String;
        attribute startTime : Integer;
        attribute duration : Duration;
    }
    
    enum def LineStatus {
        enum idle;
        enum ringing;
        enum busy;
    }
    
    enum def SignalType {
        enum dialTone;
        enum ringingTone;
        enum busyTone;
        enum none;
    }
    
    enum def CallState {
        enum waiting;
        enum connecting;
        enum active;
        enum completed;
        enum failed;
    }
    
    item def AudioSignal;
    
    item def ControlMessage {
        attribute sourceId : Integer;
        attribute destId : Integer;
        attribute signalRequest : SignalType;
        attribute statusUpdate : LineStatus;
        attribute callData : CallRecord;
    }
    
    // --- Port Definitions ---
    port def AudioBidirectionalPort {
        in audioIn : AudioSignal;
        out audioOut : AudioSignal;
    }
    
    port def ControlBidirectionalPort {
        in ctrlIn : ControlMessage;
        out ctrlOut : ControlMessage;
    }
    
    // --- Part Definitions ---
    part def SubscriberLineInterface {
        attribute lineNumber : String;
        attribute lineId : Integer;
        attribute currentStatus : LineStatus = LineStatus::idle;
        
        port audioLink : AudioBidirectionalPort;
        port ctrlLink : ControlBidirectionalPort;
        
        state def LineBehavior {
            state Idle;
            state OffHook;
            state Ringing;
            state InCall;
            
            transition idle_to_offhook 
                from Idle 
                to OffHook 
                when (ctrlLink.ctrlIn.statusUpdate == LineStatus::busy) 
                do { ctrlLink.ctrlOut = ControlMessage{sourceId = lineId, statusUpdate = LineStatus::busy}; };
                
            transition offhook_to_incall 
                from OffHook 
                to InCall 
                when (ctrlLink.ctrlIn.statusUpdate == LineStatus::busy && ctrlLink.ctrlIn.destId != 0);
                
            transition any_to_idle 
                from InCall 
                to Idle 
                when (ctrlLink.ctrlIn.statusUpdate == LineStatus::idle);
        }
    }
    
    part def TrunkLineInterface {
        attribute trunkId : Integer;
        attribute status : LineStatus = LineStatus::idle;
        
        port audioLink : AudioBidirectionalPort;
        port ctrlLink : ControlBidirectionalPort;
    }
    
    part def OperatorConsole {
        attribute consoleId : Integer;
        attribute operatorName : String;
        
        port audioLink : AudioBidirectionalPort;
        port ctrlLink : ControlBidirectionalPort;
    }
    
    part def SignalGenerator {
        in signalCmdIn : ControlMessage;
        out signalAudioOut : AudioSignal;
        
        state def GeneratorStates {
            state Idle;
            state DialTone;
            state RingTone;
            state BusyTone;
            
            transition idle_to_dial 
                from Idle 
                to DialTone 
                when (signalCmdIn.signalRequest == SignalType::dialTone);
                
            transition idle_to_ring 
                from Idle 
                to RingTone 
                when (signalCmdIn.signalRequest == SignalType::ringingTone);
                
            transition idle_to_busy 
                from Idle 
                to BusyTone 
                when (signalCmdIn.signalRequest == SignalType::busyTone);
                
            transition any_to_idle 
                from DialTone, RingTone, BusyTone 
                to Idle 
                when (signalCmdIn.signalRequest == SignalType::none);
        }
    }
    
    part def CallRecordingSystem {
        in callLogIn : CallRecord;
        attribute recordCount : Integer = 0;
        
        part def DataStorage {
            attribute records[*] : CallRecord;
        }
        
        part storage : DataStorage;
        
        action def LogCall {
            in callData : CallRecord;
            then storeRecord;
            action storeRecord {
                storage.records = storage.records->including(callData);
            }
        }
    }
    
    part def SwitchingMatrix {
        // External Ports
        port subAudio[100] : AudioBidirectionalPort;
        port subCtrl[100] : ControlBidirectionalPort;
        
        port trunkAudio[10] : AudioBidirectionalPort;
        port trunkCtrl[10] : ControlBidirectionalPort;
        
        port opAudio[5] : AudioBidirectionalPort;
        port opCtrl[5] : ControlBidirectionalPort;
        
        out signalCmdOut : ControlMessage;
        in signalAudioIn : AudioSignal;
        
        out callLogOut : CallRecord;
        
        // Internal State
        attribute activeCallState : CallState = CallState::waiting;
        attribute callerId : Integer;
        attribute receiverId : Integer;
        attribute callStartTime : Integer;
        
        // Behavior
        state def MatrixCallHandling {
            state Idle;
            state AlertingOperator;
            state AwaitingDestination;
            state AttemptingConnection;
            state RingingDestination;
            state BusySignal;
            state CallActive;
            state Releasing;
            
            transition idle_to_alerting 
                from Idle 
                to AlertingOperator 
                when (subCtrl[callerId].ctrlIn.statusUpdate == LineStatus::busy) 
                do { 
                    signalCmdOut = ControlMessage{signalRequest = SignalType::dialTone}; 
                    opCtrl[1].ctrlOut = ControlMessage{sourceId = callerId};
                };
                
            transition alerting_to_awaiting 
                from AlertingOperator 
                to AwaitingDestination 
                when (opCtrl[1].ctrlIn.destId != 0) 
                do { 
                    receiverId = opCtrl[1].ctrlIn.destId; 
                    signalCmdOut = ControlMessage{signalRequest = SignalType::none}; 
                };
                
            transition awaiting_to_attempting 
                from AwaitingDestination 
                to AttemptingConnection;
                
            transition attempting_to_ringing 
                from AttemptingConnection 
                to RingingDestination 
                when (subCtrl[receiverId].ctrlIn.statusUpdate == LineStatus::idle) 
                do { 
                    subCtrl[receiverId].ctrlOut = ControlMessage{statusUpdate = LineStatus::ringing}; 
                    signalCmdOut = ControlMessage{signalRequest = SignalType::ringingTone}; 
                };
                
            transition attempting_to_busy 
                from AttemptingConnection 
                to BusySignal 
                when (subCtrl[receiverId].ctrlIn.statusUpdate == LineStatus::busy) 
                do { 
                    signalCmdOut = ControlMessage{signalRequest = SignalType::busyTone}; 
                };
                
            transition ringing_to_active 
                from RingingDestination 
                to CallActive 
                when (subCtrl[receiverId].ctrlIn.statusUpdate == LineStatus::busy) 
                do { 
                    signalCmdOut = ControlMessage{signalRequest = SignalType::none}; 
                    callStartTime = 1000; 
                    activeCallState = CallState::active;
                };
                
            transition busy_to_idle 
                from BusySignal 
                to Idle 
                when (subCtrl[callerId].ctrlIn.statusUpdate == LineStatus::idle);
                
            transition active_to_releasing 
                from CallActive 
                to Releasing 
                when (subCtrl[callerId].ctrlIn.statusUpdate == LineStatus::idle || subCtrl[receiverId].ctrlIn.statusUpdate == LineStatus::idle) 
                do { 
                    callLogOut = CallRecord{callerNumber = "123", receiverNumber = "456", startTime = callStartTime, duration = 60}; 
                };
                
            transition releasing_to_idle 
                from Releasing 
                to Idle 
                do { 
                    subCtrl[callerId].ctrlOut = ControlMessage{statusUpdate = LineStatus::idle}; 
                    subCtrl[receiverId].ctrlOut = ControlMessage{statusUpdate = LineStatus::idle}; 
                    activeCallState = CallState::waiting;
                };
        }
    }
    
    // --- Requirements ---
    requirement def SwitchboardSystemRequirements {
        requirement SubscriberCapacity {
            attribute maxSubscribers : Integer = 100;
            doc { The system shall support up to 100 individual subscriber lines. }
        }
        
        requirement OperatorConcurrency {
            attribute maxOperators : Integer = 5;
            doc { The system shall include 5 operator consoles to handle calls simultaneously. }
        }
        
        requirement TrunkCapacity {
            attribute maxTrunks : Integer = 10;
            doc { The system shall feature 10 external trunk lines for external networks. }
        }
        
        requirement SignalGeneration {
            doc { A dedicated Signal Generator shall provide dial tone, ringing signal, and busy signal. }
        }
        
        requirement CallRouting {
            doc { The Switching Matrix shall create temporary electrical connections between any two lines. }
        }
        
        requirement CallTermination {
            doc { The system shall terminate the connection when a user hangs up, freeing the lines. }
        }
        
        requirement CallLogging {
            doc { A Call Recording System shall automatically log caller, receiver, start time, and duration. }
        }
    }
    
    // --- Top-Level System ---
    part def SwitchboardSystem {
        requirement req : SwitchboardSystemRequirements;
        
        part matrix : SwitchingMatrix {
            satisfy req.CallRouting by matrix;
            satisfy req.CallTermination by matrix;
        }
        
        part signalGen : SignalGenerator {
            satisfy req.SignalGeneration by signalGen;
        }
        
        part recorder : CallRecordingSystem {
            satisfy req.CallLogging by recorder;
        }
        
        part operators[5] : OperatorConsole;
        part subscribers[100] : SubscriberLineInterface;
        part trunks[10] : TrunkLineInterface;
        
        // Connections
        connect matrix.signalCmdOut to signalGen.signalCmdIn;
        connect signalGen.signalAudioOut to matrix.signalAudioIn;
        
        connect matrix.callLogOut to recorder.callLogIn;
        
        connect subscribers.audioLink to matrix.subAudio;
        connect subscribers.ctrlLink to matrix.subCtrl;
        
        connect trunks.audioLink to matrix.trunkAudio;
        connect trunks.ctrlLink to matrix.trunkCtrl;
        
        connect operators.audioLink to matrix.opAudio;
        connect operators.ctrlLink to matrix.opCtrl;
    }
}
