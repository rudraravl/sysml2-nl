package TimerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TimerDuration :> ISQ::DurationValue;
    attribute def ElapsedTime :> ISQ::DurationValue;
    attribute def RemainingTime :> ISQ::DurationValue;
    
    enum def TimerStatus {
        idle;
        running;
        paused;
        expired;
    }
    
    attribute def StartCommand {
        attribute setDuration : TimerDuration;
    }
    attribute def StopCommand;
    attribute def PauseCommand;
    attribute def ResumeCommand;
    attribute def ResetCommand;
    
    attribute def TimerExpiredSignal;
    attribute def TimerTickSignal {
        attribute elapsed : ElapsedTime;
        attribute remaining : RemainingTime;
    }
    
    port def TimerControlPort {
        in startCmd : StartCommand[0..*];
        in stopCmd : StopCommand[0..*];
        in pauseCmd : PauseCommand[0..*];
        in resumeCmd : ResumeCommand[0..*];
        in resetCmd : ResetCommand[0..*];
        out expiredSignal : TimerExpiredSignal[0..*];
        out tickSignal : TimerTickSignal[0..*];
        out currentStatus : TimerStatus;
    }
    
    port def ClockSourcePort {
        out clockTick : ISQ::DurationValue;
    }
    
    action def GenerateClockTick {
        in tickInterval : ISQ::DurationValue;
        out tickValue : ISQ::DurationValue;
    }
    
    part def ClockSource {
        attribute tickInterval : ISQ::DurationValue;
        port clockOut : ClockSourcePort;
        
        action generateClockTicks : GenerateClockTick {
            in tickInterval = ClockSource::tickInterval;
            out tickValue;
        }
    }
    
    part def TimerCore {
        port controlInterface : TimerControlPort;
        port clockInput : ~ClockSourcePort;
        
        private attribute targetDuration : TimerDuration := 0.0[s];
        private attribute currentElapsed : ElapsedTime := 0.0[s];
        private attribute status : TimerStatus := TimerStatus::idle;
        
        perform action manageTimerOperation {
            first start;
            then merge awaitCommand;
            
            action awaitCommand;
            
            then decide;
                if true then processStart;
                if true then processStop;
                if true then processPause;
                if true then processResume;
                if true then processReset;
            
            action processStart {
                assign targetDuration := 60.0[s];
                then assign currentElapsed := 0.0[s];
                then assign status := TimerStatus::running;
            }
            then executeCountdown;
            
            action processStop {
                assign status := TimerStatus::idle;
                then assign currentElapsed := 0.0[s];
            }
            then awaitCommand;
            
            action processPause {
                assign status := TimerStatus::paused;
            }
            then awaitCommand;
            
            action processResume {
                assign status := TimerStatus::running;
            }
            then executeCountdown;
            
            action processReset {
                assign currentElapsed := 0.0[s];
            }
            then awaitCommand;
            
            action executeCountdown {
                first start;
                then merge checkStatus;
                
                action checkStatus;
                
                then decide;
                    if status == TimerStatus::running then incrementTimer;
                    if status != TimerStatus::running then exitCountdown;
                
                action incrementTimer {
                    assign currentElapsed := currentElapsed + 0.1[s];
                    then decide;
                        if currentElapsed >= targetDuration then handleExpiration;
                        if currentElapsed < targetDuration then emitProgress;
                    
                    action emitProgress;
                    then checkStatus;
                    
                    action handleExpiration {
                        assign status := TimerStatus::expired;
                    }
                    then exitCountdown;
                }
                
                action exitCountdown;
            }
            then awaitCommand;
        }
    }
    
    part def UserInterface {
        port userControl : ~TimerControlPort;
        
        attribute requestedDuration : TimerDuration;
        
        perform action handleUserInteraction {
            first start;
            then action initiateTimer;
            then merge monitorTimer;
            
            action monitorTimer;
            
            then decide;
                if true then notifyCompletion;
                if true then updateDisplay;
            
            action notifyCompletion {
                doc /* Notify user that timer has expired. */
            }
            then done;
            
            action updateDisplay {
                doc /* Update display with current elapsed and remaining time. */
            }
            then monitorTimer;
        }
    }
    
    part def TimerSystem {
        doc /* A system that measures and tracks time intervals with user control. */
        
        attribute systemClockRate : ISQ::DurationValue := 0.1[s];
        
        part clock : ClockSource {
            :>> tickInterval = systemClockRate;
        }
        
        part timerCore : TimerCore;
        
        part ui : UserInterface {
            :>> requestedDuration = 60.0[s];
        }
        
        connect clock.clockOut to timerCore.clockInput;
        connect ui.userControl to timerCore.controlInterface;
        
        perform action operateSystem {
            first start;
            then action initializeSystem {
                doc /* Initialize all subsystems. */
            }
            then merge operationalLoop;
            
            action operationalLoop;
            
            then decide;
                if true then runTimer;
                if true then handleCompletion;
            
            action runTimer {
                doc /* Timer is actively counting down. */
            }
            then operationalLoop;
            
            action handleCompletion {
                doc /* Timer has completed its countdown. */
            }
            then operationalLoop;
        }
    }
    
    requirement def TimerFunctionalRequirement;
    
    requirement primaryTimerFunction : TimerFunctionalRequirement {
        doc /* The primary function of the timer system is to accurately measure 
               a user-specified time interval, provide continuous feedback on 
               elapsed and remaining time, and signal when the interval has expired. */
        
        subject system : TimerSystem;
        
        requirement shallAcceptDuration {
            doc /* The system shall accept a duration setting from the user. */
        }
        
        requirement shallMeasureTime {
            doc /* The system shall measure elapsed time from the start command. */
        }
        
        requirement shallProvideProgress {
            doc /* The system shall provide periodic updates on elapsed and remaining time. */
        }
        
        requirement shallSignalExpiration {
            doc /* The system shall emit a signal when the specified duration has elapsed. */
        }
        
        requirement shallSupportControl {
            doc /* The system shall support start, stop, pause, resume, and reset commands. */
        }
    }
    
    requirement timerAccuracy : TimerFunctionalRequirement {
        doc /* The timer shall maintain accuracy within acceptable tolerance. */
        
        subject core : TimerCore;
        
        require constraint accuracyConstraint {
            attribute measuredDuration : TimerDuration;
            attribute targetDuration : TimerDuration;
            attribute maxError : Real := 0.02;
            
            (measuredDuration - targetDuration).abs() <= targetDuration * maxError
        }
    }
    
    part timerSystemInstance : TimerSystem {
        :>> systemClockRate = 0.05[s];
        :>> ui.requestedDuration = 120.0[s];
    }
    
    satisfy primaryTimerFunction by timerSystemInstance;
}
