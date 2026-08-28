package ElephantClock {

    package Definitions {

        value type MassValue > Real { unit 'kg'; }
        value type VolumeValue > Real { unit 'L'; }
        value type TimeValue > Real { unit 'min'; }
        value type FlowRateValue > Real { unit 'L/min'; }
        value type AngleValue > Real { unit 'deg'; }
        value type LengthValue > Real { unit 'm'; }
        value type CountValue > Integer;

        item def Water;
        item def MetalBall;
        item def Sound;

        attribute def DripRate :> FlowRateValue;
        attribute def FillDuration :> TimeValue;
    }

    package Parts {

        part def Reservoir {
            attribute capacity : VolumeValue = 50.0;
            attribute currentVolume : VolumeValue = 50.0;
            out port waterOut : Water;
        }

        part def FlowRegulator {
            in port waterIn : Water;
            out port waterOut : Water;
            attribute dripRate : DripRate = 0.05;
            action def regulateFlow() {
                // Maintain constant drip rate regardless of upstream pressure
            }
        }

        part def FloatingBowl {
            in port waterIn : Water;
            in port tipCommand;
            out port sinkSignal;
            out port floatSignal;
            attribute mass : MassValue = 0.2;
            attribute sinkThreshold : MassValue = 1.7;
            attribute fillDuration : FillDuration = 30.0;
            attribute isSubmerged : Boolean = false;

            action def accumulateWater() {
                // Water accumulates until mass exceeds sinkThreshold
            }
            action def tipOver() {
                // Bowl tips, empties water, resets mass
            }
            action def refloat() {
                // Bowl returns to surface after emptying
            }
        }

        part def TriggerLever {
            in port pullSignal;
            out port releaseBallSignal;
            out port advanceDialSignal;
            out port moveScribeSignal;
            out port tipBowlSignal;
            attribute isTripped : Boolean = false;

            action def trip() {
                // Coordinated release of all downstream signals
            }
            action def reset() {
                // Lever returns to armed position
            }
        }

        part def BallReservoir {
            in port releaseSignal;
            out port ballOut : MetalBall;
            attribute ballCount : CountValue = 12;

            action def releaseBall() {
                // Release a single metal ball
            }
        }

        part def DragonAutomaton {
            in port ballIn : MetalBall;
            out port ballOut : MetalBall;
            attribute angle : AngleValue = 0.0;
            attribute hasBall : Boolean = false;

            action def swallowBall() {
                // Dragon swivels to receive ball
            }
            action def swivelDown() {
                // Dragon swivels downward to release ball
            }
            action def returnToRest() {
                // Dragon returns to upright position
            }
        }

        part def CymbalFigure {
            in port ballIn : MetalBall;
            out port soundOut : Sound;
            attribute struck : Boolean = false;

            action def strikeCymbal() {
                // Ball strikes cymbal producing sound
            }
        }

        part def TimeDial {
            in port advanceSignal;
            attribute currentTime : TimeValue = 0.0;
            attribute increment : TimeValue = 30.0;

            action def advance() {
                // Advance dial by half-hour increment
            }
        }

        part def ScribeFigure {
            in port moveSignal;
            attribute pointerAngle : AngleValue = 0.0;
            attribute increment : AngleValue = 15.0;

            action def movePointer() {
                // Move scribe pointer to indicate current time
            }
        }

        part def ElephantClock {
            attribute cycleDuration : TimeValue = 30.0;
            attribute operational : Boolean = true;

            part reservoir : Reservoir {
                attribute capacity = 50.0;
            }
            part regulator : FlowRegulator {
                attribute dripRate = 0.05;
            }
            part bowl : FloatingBowl {
                attribute fillDuration = 30.0;
                attribute sinkThreshold = 1.7;
            }
            part lever : TriggerLever;
            part ballReservoir : BallReservoir {
                attribute ballCount = 12;
            }
            part dragon : DragonAutomaton;
            part cymbalFigure : CymbalFigure;
            part timeDial : TimeDial;
            part scribe : ScribeFigure;

            flow from reservoir.waterOut to regulator.waterIn;
            flow from regulator.waterOut to bowl.waterIn;

            connection from bowl.sinkSignal to lever.pullSignal;
            connection from lever.releaseBallSignal to ballReservoir.releaseSignal;
            connection from lever.advanceDialSignal to timeDial.advanceSignal;
            connection from lever.moveScribeSignal to scribe.moveSignal;
            connection from lever.tipBowlSignal to bowl.tipCommand;

            flow from ballReservoir.ballOut to dragon.ballIn;
            flow from dragon.ballOut to cymbalFigure.ballIn;
            flow from cymbalFigure.soundOut to out;

            port out soundOut : Sound;

            exhibit state machine ClockCycle {
                entry action { send bowl.fillDuration to bowl; }

                state Filling {
                    entry action { bowl.accumulateWater(); }
                    transition Filling to Sinking
                        when bowl.mass >= bowl.sinkThreshold;
                }

                state Sinking {
                    entry action {
                        lever.trip();
                        ballReservoir.releaseBall();
                        dragon.swallowBall();
                        dragon.swivelDown();
                        cymbalFigure.strikeCymbal();
                        timeDial.advance();
                        scribe.movePointer();
                        bowl.tipOver();
                    }
                    transition Sinking to Refloating
                        when bowl.mass <= 0.3;
                }

                state Refloating {
                    entry action {
                        bowl.refloat();
                        dragon.returnToRest();
                        lever.reset();
                    }
                    transition Refloating to Filling
                        when bowl.isSubmerged == false;
                }
            }
        }
    }

    package Behaviors {

        action def RegulateFlow {
            in waterIn : Water;
            out waterOut : Water;
            attribute dripRate : DripRate = 0.05;
        }

        action def AccumulateWater {
            in waterIn : Water;
            out sinkTrigger;
            attribute mass : MassValue;
            attribute threshold : MassValue = 1.7;
        }

        action def TriggerSequence {
            in pullSignal;
            out ballRelease;
            out dialAdvance;
            out scribeMove;
            out bowlTip;
        }

        action def HalfHourStrike {
            in ball : MetalBall;
            out sound : Sound;
        }
    }

    package Requirements {

        requirement def TimekeepingAccuracy {
            attribute requiredCycleDuration : TimeValue = 30.0;
            attribute tolerance : TimeValue = 0.5;
            doc { The clock shall mark each half-hour cycle within a tolerance of 0.5 minutes. }
        }

        requirement def ConstantDripRate {
            attribute requiredDripRate : DripRate = 0.05;
            attribute maxVariation : DripRate = 0.001;
            doc { The flow regulator shall maintain a constant drip rate regardless of reservoir water level. }
        }

        requirement def AutonomousOperation {
            attribute continuous : Boolean = true;
            doc { The clock shall operate autonomously and self-reset after each half-hour cycle. }
        }

        requirement def AudibleSignal {
            doc { Each half-hour shall be marked by an audible strike of the cymbal. }
        }

        requirement def VisualDisplay {
            doc { The scribe pointer shall advance to indicate the current time after each cycle. }
        }

        requirement def BallRelease {
            attribute ballsPerCycle : CountValue = 1;
            doc { Exactly one metal ball shall be released per half-hour cycle. }
        }

        requirement def BowlReset {
            doc { The floating bowl shall tip, empty, and refloat to begin a new cycle after each strike. }
        }

        part def ClockRequirements {
            requirement r1 : TimekeepingAccuracy;
            requirement r2 : ConstantDripRate;
            requirement r3 : AutonomousOperation;
            requirement r4 : AudibleSignal;
            requirement r5 : VisualDisplay;
            requirement r6 : BallRelease;
            requirement r7 : BowlReset;
        }
    }
}
