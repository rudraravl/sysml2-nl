package DigitalTimerSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import ISQ::DurationValue;
    
    item def Tick;
    
    attribute def SetDurationCommand {
        attribute duration : DurationValue;
    }
    attribute def StartCommand;
    attribute def PauseCommand;
    attribute def ResumeCommand;
    attribute def ResetCommand;
    
    attribute def ProgressUpdate {
        attribute elapsed : DurationValue;
        attribute remaining : DurationValue;
    }
    attribute def ExpiredSignal;
    
    port def TickOutPort {
        out item tick : Tick;
    }
    port def TickInPort {
        in item tick : Tick;
    }
    
    port def CommandOutPort {
        out setDuration : SetDurationCommand;
        out start : StartCommand;
        out pause : PauseCommand;
        out resume : ResumeCommand;
        out reset : ResetCommand;
    }
    port def CommandInPort {
        in setDuration : SetDurationCommand;
        in start : StartCommand;
        in pause : PauseCommand;
        in resume : ResumeCommand;
        in reset : ResetCommand;
    }
    
    port def StatusOutPort {
        out progress : ProgressUpdate;
        out expired : ExpiredSignal;
    }
    port def StatusInPort {
        in progress : ProgressUpdate;
        in expired : ExpiredSignal;
    }
    
    part def ClockSource {
        port tickOut : TickOutPort;
    }
    
    part def TimerCore {
        attribute targetDuration : DurationValue;
        attribute elapsedTime : DurationValue = 0 [s];
        port cmdIn : CommandInPort;
        port tickIn : TickInPort;
        port statusOut : StatusOutPort;
        exhibit state timerStates {
            entry; then idle;
            
            state idle {
                entry assign elapsedTime = 0 [s];
                accept setDuration : SetDurationCommand
                    do assign targetDuration = setDuration.duration;
            }
            transition idle_to_running
                first idle
                accept StartCommand
                then running;
            
            state running;
            accept tick : Tick via tickIn
                do {
                    assign elapsedTime = elapsedTime + 1 [s];
                    send new ProgressUpdate(elapsed = elapsedTime, remaining = targetDuration - elapsedTime) via statusOut;
                }
                then running;
            transition running_to_paused
                first running
                accept PauseCommand
                then paused;
            transition running_to_expired
                first running
                accept when elapsedTime >= targetDuration
                do send new ExpiredSignal() via statusOut
                then expired;
            transition running_to_idle
                first running
                accept ResetCommand
                do assign elapsedTime = 0 [s]
                then idle;
            
            state paused;
            transition paused_to_running
                first paused
                accept ResumeCommand
                then running;
            transition paused_to_idle
                first paused
                accept ResetCommand
                do assign elapsedTime = 0 [s]
                then idle;
            
            state expired;
            transition expired_to_idle
                first expired
                accept ResetCommand
                do assign elapsedTime = 0 [s]
                then idle;
        }
    }
    
    part def UserInterface {
        port cmdOut : CommandOutPort;
        port statusIn : StatusInPort;
    }
    
    requirement def AccuracyRequirement {
        doc "The measured time shall remain within a defined tolerance of the actual elapsed time.";
        attribute tolerance : DurationValue = 0.1 [s];
    }
    
    part digitalTimerSystem {
        part clockSource : ClockSource;
        part timerCore : TimerCore;
        part userInterface : UserInterface;
        
        interface clockToCore connect clockSource.tickOut to timerCore.tickIn {
            flow of tick : Tick from clockSource.tickOut.tick to timerCore.tickIn.tick;
        }
        interface uiToCore connect userInterface.cmdOut to timerCore.cmdIn {
            flow of setDuration : SetDurationCommand from userInterface.cmdOut.setDuration to timerCore.cmdIn.setDuration;
            flow of start : StartCommand from userInterface.cmdOut.start to timerCore.cmdIn.start;
            flow of pause : PauseCommand from userInterface.cmdOut.pause to timerCore.cmdIn.pause;
            flow of resume : ResumeCommand from userInterface.cmdOut.resume to timerCore.cmdIn.resume;
            flow of reset : ResetCommand from userInterface.cmdOut.reset to timerCore.cmdIn.reset;
        }
        interface coreToUI connect timerCore.statusOut to userInterface.statusIn {
            flow of progress : ProgressUpdate from timerCore.statusOut.progress to userInterface.statusIn.progress;
            flow of expired : ExpiredSignal from timerCore.statusOut.expired to userInterface.statusIn.expired;
        }
        
        satisfy timerAccuracy : AccuracyRequirement by timerCore;
    }
}
