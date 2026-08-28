package DigitalTimer {
    import ScalarValues::*;
    import ISQ::*;
    import ISQTime::*;
    import Time::*;

    // ===== Value Types =====
    value type DurationValue :> TimeValue {}
    value type ElapsedTimeValue :> TimeValue {}
    value type RemainingTimeValue :> TimeValue {}
    value type TickPeriodValue :> TimeValue {}
    value type ToleranceValue :> TimeValue {}

    // ===== Package-Level Attributes =====
    attribute tickPeriodDefault : TickPeriodValue = 1.0 [s];
    attribute accuracyTolerance : ToleranceValue = 0.05 [s];

    // ===== Items =====
    item def Tick;
    item def StartCommand;
    item def PauseCommand;
    item def ResumeCommand;
    item def StopCommand;
    item def ResetCommand;

    item def SetDurationCommand {
        attr duration : DurationValue;
    }

    item def ProgressUpdate {
        attr elapsed : ElapsedTimeValue;
        attr remaining : RemainingTimeValue;
    }

    item def ExpiredSignal;
    item def AlertSignal;

    item def StartButtonPress;
    item def PauseButtonPress;
    item def ResumeButtonPress;
    item def StopButtonPress;
    item def ResetButtonPress;

    item def SetDurationButtonPress {
        attr duration : DurationValue;
    }

    // ===== Ports =====
    port def ClockTickPort {
        out tick : Tick;
    }

    port def CommandPort {
        in start : StartCommand;
        in pause : PauseCommand;
        in resume : ResumeCommand;
        in stop : StopCommand;
        in reset : ResetCommand;
        in setDuration : SetDurationCommand;
    }

    port def ProgressPort {
        out progress : ProgressUpdate;
        out expired : ExpiredSignal;
    }

    port def AlertPort {
        out alert : AlertSignal;
    }

    port def ButtonPressPort {
        in startPress : StartButtonPress;
        in pausePress : PauseButtonPress;
        in resumePress : ResumeButtonPress;
        in stopPress : StopButtonPress;
        in resetPress : ResetButtonPress;
        in setDurationPress : SetDurationButtonPress;
    }

    // ===== Clock Source =====
    part def ClockSource {
        attribute period : TickPeriodValue = tickPeriodDefault;
        port tickOut : ClockTickPort;

        state def ClockBehavior {
            entry; then ticking;

            state ticking {
                entry { send Tick {} through tickOut; }
                transition then ticking;
            }
        }

        exhibit ClockBehavior;
    }

    // ===== Timer Core =====
    part def TimerCore {
        attribute tickPeriod : TickPeriodValue = tickPeriodDefault;
        attribute targetDuration : DurationValue := 0 [s];
        attribute elapsedAccumulator : ElapsedTimeValue := 0 [s];
        attribute remaining : RemainingTimeValue := 0 [s];

        port cmdIn : CommandPort;
        port tickIn : ~ClockTickPort;
        port progressOut : ProgressPort;

        state def TimerBehavior {
            entry; then idle;

            state idle {
                entry {
                    elapsedAccumulator := 0 [s];
                    remaining := targetDuration;
                }
                transition on cmdIn.setDuration do {
                    targetDuration := cmdIn.setDuration.duration;
                    remaining := targetDuration;
                } -> idle;
                transition on cmdIn.start if targetDuration > 0 [s] -> running;
                transition on cmdIn.reset -> idle;
            }

            state running {
                entry {
                    remaining := targetDuration - elapsedAccumulator;
                }
                transition on cmdIn.pause -> paused;
                transition on cmdIn.stop -> idle;
                transition on cmdIn.reset -> idle;
                transition on tickIn.tick if elapsedAccumulator + tickPeriod >= targetDuration do {
                    elapsedAccumulator := elapsedAccumulator + tickPeriod;
                    remaining := 0 [s];
                } -> expired;
                transition on tickIn.tick do {
                    elapsedAccumulator := elapsedAccumulator + tickPeriod;
                    remaining := targetDuration - elapsedAccumulator;
                    send ProgressUpdate { elapsed = elapsedAccumulator; remaining = remaining; } through progressOut;
                } -> running;
            }

            state paused {
                transition on cmdIn.resume -> running;
                transition on cmdIn.stop -> idle;
                transition on cmdIn.reset -> idle;
            }

            state expired {
                entry {
                    send ExpiredSignal {} through progressOut;
                }
                transition on cmdIn.reset -> idle;
            }
        }

        exhibit TimerBehavior;
    }

    // ===== Display =====
    part def Display {
        port progressIn : ~ProgressPort;
        port alertOut : AlertPort;

        action def ShowProgress {
            in progress : ProgressUpdate;
        }

        action def SoundAlert {
            out alert : AlertSignal;
        }

        state def DisplayBehavior {
            entry; then active;

            state active {
                transition on progressIn.progress -> showing;
                transition on progressIn.expired -> alerting;
            }

            state showing {
                entry { /* Render elapsed and remaining time on screen */ }
                transition then active;
            }

            state alerting {
                entry {
                    send AlertSignal {} through alertOut;
                }
                transition then active;
            }
        }

        exhibit DisplayBehavior;
    }

    // ===== Keypad =====
    part def Keypad {
        port buttonIn : ButtonPressPort;
        port cmdOut : ~CommandPort;

        state def KeypadBehavior {
            entry; then idle;

            state idle {
                transition on buttonIn.startPress do {
                    send StartCommand {} through cmdOut;
                } -> idle;
                transition on buttonIn.pausePress do {
                    send PauseCommand {} through cmdOut;
                } -> idle;
                transition on buttonIn.resumePress do {
                    send ResumeCommand {} through cmdOut;
                } -> idle;
                transition on buttonIn.stopPress do {
                    send StopCommand {} through cmdOut;
                } -> idle;
                transition on buttonIn.resetPress do {
                    send ResetCommand {} through cmdOut;
                } -> idle;
                transition on buttonIn.setDurationPress do {
                    send SetDurationCommand { duration = buttonIn.setDurationPress.duration; } through cmdOut;
                } -> idle;
            }
        }

        exhibit KeypadBehavior;
    }

    // ===== User Interface =====
    part def UserInterface {
        port cmdOut : ~CommandPort;
        port progressIn : ~ProgressPort;
        port alertOut : AlertPort;
        port buttonIn : ButtonPressPort;

        part display : Display;
        part keypad : Keypad;

        connect buttonIn to keypad.buttonIn;
        connect keypad.cmdOut to cmdOut;
        connect progressIn to display.progressIn;
        connect display.alertOut to alertOut;
    }

    // ===== Top-Level System =====
    part def DigitalTimerSystem {
        part clockSource : ClockSource;
        part timerCore : TimerCore;
        part userInterface : UserInterface;

        connect clockSource.tickOut to timerCore.tickIn;
        connect userInterface.cmdOut to timerCore.cmdIn;
        connect timerCore.progressOut to userInterface.progressIn;
    }

    // ===== Requirements =====
    requirement def TimerAccuracyRequirement {
        doc /* The measured elapsed time shall not exceed the target duration by more than the defined tolerance. */;
        subject timer : TimerCore;
        assert { timer.elapsedAccumulator <= timer.targetDuration + accuracyTolerance }
    }

    requirement def CountdownRequirement {
        doc /* The timer shall count down from a user-set duration to zero. */;
        subject timer : TimerCore;
        assert { timer.targetDuration > 0 [s] }
    }

    requirement def StateTransitionRequirement {
        doc /* The timer shall support idle, running, paused, and expired states with appropriate transitions. */;
        subject timer : TimerCore;
    }

    requirement def PauseResumeRequirement {
        doc /* The timer shall support pausing and resuming the countdown without loss of elapsed time. */;
        subject timer : TimerCore;
    }

    requirement def ResetRequirement {
        doc /* The timer shall support resetting to its initial idle state from any other state. */;
        subject timer : TimerCore;
    }

    requirement def ExpirationSignalRequirement {
        doc /* The timer core shall send an expired signal when elapsed time reaches the target duration. */;
        subject timer : TimerCore;
    }

    requirement def ProgressFeedbackRequirement {
        doc /* The timer core shall continuously send progress updates including elapsed and remaining time. */;
        subject timer : TimerCore;
    }

    requirement def UserInteractionRequirement {
        doc /* The user interface shall allow start, stop, pause, resume, reset, and set-duration commands. */;
        subject ui : UserInterface;
    }

    requirement def DisplayRequirement {
        doc /* The display shall show progress updates and alert the user upon expiration. */;
        subject display : Display;
    }

    requirement def ClockSourceRequirement {
        doc /* The clock source shall generate a steady periodic time pulse with a positive period. */;
        subject clock : ClockSource;
        assert { clock.period > 0 [s] }
    }

    // ===== System Instance =====
    part digitalTimer : DigitalTimerSystem {
        satisfy TimerAccuracyRequirement by timerCore;
        satisfy CountdownRequirement by timerCore;
        satisfy StateTransitionRequirement by timerCore;
        satisfy PauseResumeRequirement by timerCore;
        satisfy ResetRequirement by timerCore;
        satisfy ExpirationSignalRequirement by timerCore;
        satisfy ProgressFeedbackRequirement by timerCore;
        satisfy UserInteractionRequirement by userInterface;
        satisfy DisplayRequirement by userInterface.display;
        satisfy ClockSourceRequirement by clockSource;
    }
}
