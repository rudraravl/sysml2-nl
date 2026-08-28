package 'Al-Jazari Elephant Clock' {
	private import ScalarValues::*;
	private import ISQ::*;

	item def Water;
	item def MetalBall;

	attribute def SinkSignal;
	attribute def TriggerSignal;
	attribute def TipBowlSignal;

	port def WaterPort {
		out item water : Water;
	}
	port def BallPort {
		out item ball : MetalBall;
	}
	port def SinkOutPort {
		out sink : SinkSignal;
	}
	port def SinkInPort {
		in sink : SinkSignal;
	}
	port def TriggerOutPort {
		out trigger : TriggerSignal;
	}
	port def TriggerInPort {
		in trigger : TriggerSignal;
	}
	port def TipOutPort {
		out tip : TipBowlSignal;
	}
	port def TipInPort {
		in tip : TipBowlSignal;
	}

	part def UpperReservoir {
		port waterOutPort : WaterPort;
		attribute capacity : Real = 0.05;
		item storedWater : Water;
	}

	part def FlowRegulator {
		port waterInPort : ~WaterPort;
		port waterOutPort : WaterPort;
		attribute dripRate : Real = 2.78e-7;
	}

	part def FloatingBowl {
		port waterInPort : ~WaterPort;
		port waterOutPort : WaterPort;
		port sinkOutPort : SinkOutPort;
		port tipInPort : TipInPort;
		item collectedWater : Water;
		attribute waterVolume : Real = 0.0;
		attribute sinkThreshold : Real = 5.0e-4;
		attribute isSunk : Boolean = waterVolume >= sinkThreshold;
		attribute fillTime : Real = 30.0;
	}

	part def RopesAndPulleys {
		port sinkInPort : SinkInPort;
		port triggerOutPort : TriggerOutPort;
	}

	part def TriggerLeverMechanism {
		port triggerInPort : TriggerInPort;
		port ballReleaseOutPort : TriggerOutPort;
		port dialAdvanceOutPort : TriggerOutPort;
		port scribeMoveOutPort : TriggerOutPort;
		port bowlTipOutPort : TipOutPort;
	}

	part def BallReservoir {
		port releaseInPort : TriggerInPort;
		port ballOutPort : BallPort;
		attribute ballCount : Integer = 12;
	}

	part def DragonAutomaton {
		port ballInPort : ~BallPort;
		port ballOutPort : BallPort;
		attribute jawAngle : Real = 0.0;
	}

	part def CymbalFigure {
		port ballInPort : ~BallPort;
		attribute soundEmitted : Boolean = false;
	}

	part def TimeDial {
		port advanceInPort : TriggerInPort;
		attribute currentTime : Real = 0.0;
		attribute increment : Real = 30.0;
	}

	part def ScribeFigure {
		port moveInPort : TriggerInPort;
		attribute pointerPosition : Real = 0.0;
	}

	action def ReleaseBallAction {
		out ball : MetalBall;
	}

	action def SwivelDragonAction {
		in ballIn : MetalBall;
		out ballOut : MetalBall;
	}

	action def StrikeCymbalAction {
		in ball : MetalBall;
	}

	action def AdvanceTimeAction {
		in current : Real;
		in increment : Real;
		out updated : Real;
	}

	action def TipBowlAction {
		out water : Water;
	}

	part def ElephantClock {
		attribute cycleDuration : Real = 30.0;

		part upperReservoir : UpperReservoir;
		part flowRegulator : FlowRegulator;
		part floatingBowl : FloatingBowl;
		part ropesAndPulleys : RopesAndPulleys;
		part triggerLever : TriggerLeverMechanism;
		part ballReservoir : BallReservoir;
		part dragon : DragonAutomaton;
		part cymbalFigure : CymbalFigure;
		part timeDial : TimeDial;
		part scribeFigure : ScribeFigure;

		flow waterFlow1 of Water
			from upperReservoir.waterOutPort.water to flowRegulator.waterInPort.water;
		flow waterFlow2 of Water
			from flowRegulator.waterOutPort.water to floatingBowl.waterInPort.water;

		bind floatingBowl.sinkOutPort.sink = ropesAndPulleys.sinkInPort.sink;
		bind ropesAndPulleys.triggerOutPort.trigger = triggerLever.triggerInPort.trigger;
		bind triggerLever.ballReleaseOutPort.trigger = ballReservoir.releaseInPort.trigger;
		bind triggerLever.dialAdvanceOutPort.trigger = timeDial.advanceInPort.trigger;
		bind triggerLever.scribeMoveOutPort.trigger = scribeFigure.moveInPort.trigger;
		bind triggerLever.bowlTipOutPort.tip = floatingBowl.tipInPort.tip;

		flow ballFlow1 of MetalBall
			from ballReservoir.ballOutPort.ball to dragon.ballInPort.ball;
		flow ballFlow2 of MetalBall
			from dragon.ballOutPort.ball to cymbalFigure.ballInPort.ball;

		state clockCycle {
			entry; then filling;

			state filling;
			accept SinkSignal then sinking;

			state sinking;
			then triggering;

			state triggering {
				entry action triggerAll {
					action releaseBall : ReleaseBallAction {
						out ball = ballReservoir.ballOutPort.ball;
					}
					action swivelDragon : SwivelDragonAction {
						in ballIn = dragon.ballInPort.ball;
						out ballOut = dragon.ballOutPort.ball;
					}
					action strikeCymbal : StrikeCymbalAction {
						in ball = cymbalFigure.ballInPort.ball;
					}
					action advanceTime : AdvanceTimeAction {
						in current = timeDial.currentTime;
						in increment = timeDial.increment;
					}
					action tipBowl : TipBowlAction {
						out water = floatingBowl.waterOutPort.water;
					}
				}
			}
			then emptying;

			state emptying;
			then filling;
		}
	}

	requirement def ConstantDripRateRequirement {
		subject regulator : FlowRegulator;
		doc /* The flow regulator must maintain a constant drip rate regardless of the water level in the upper reservoir. */
		constraint { regulator.dripRate == 2.78e-7 }
	}

	requirement def HalfHourCycleRequirement {
		subject clock : ElephantClock;
		doc /* The floating bowl must sink after exactly 30 minutes of continuous filling. */
		constraint { clock.cycleDuration == 30.0 }
	}

	requirement def AutonomousResetRequirement {
		subject clock : ElephantClock;
		doc /* The clock must automatically tip the bowl, empty its water, and return to filling without external intervention. */
	}

	requirement def HalfHourMarkRequirement {
		subject clock : ElephantClock;
		doc /* Each sinking event must trigger a single ball drop, a cymbal strike, and a 30-minute advancement of the time dial and scribe pointer. */
		constraint { clock.timeDial.increment == 30.0 }
	}
}
