package 'AlJazariElephantClock' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def TimeInterval;
	attribute def BowlSunkSignal;
	attribute def ResetSignal;
	attribute def BallReleaseSignal;
	attribute def DialAdvanceSignal;
	
	item def Water {
		attribute volume : VolumeValue;
		attribute flowRate : VolumeFlowRateValue;
	}
	
	item def MetalBall {
		attribute mass : MassValue;
	}
	
	part def UpperReservoir {
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		port waterOutlet;
	}
	
	part def FloatingBowl {
		attribute bowlCapacity : VolumeValue;
		attribute currentWaterLevel : VolumeValue;
		attribute sinkThreshold : VolumeValue;
		port waterInlet;
		port sinkSignalOut;
	}
	
	part def FlowRegulator {
		attribute regulatedRate : VolumeFlowRateValue;
		port waterInlet;
		port waterOutlet;
	}
	
	part def PulleyAndRope {
		attribute ropeLength : LengthValue;
		port bowlConnection;
		port leverConnection;
	}
	
	part def TriggerLever {
		attribute leverAngle : Real;
		port pulleyInput;
		port ballReleaseOutput;
		port dialAdvanceOutput;
		port resetOutput;
	}
	
	part def BallReservoir {
		attribute ballCount : Integer;
		port releaseCommand;
		port ballOutput;
	}
	
	part def DragonAutomaton {
		attribute jawAngle : Real;
		port ballInput;
		port ballOutput;
	}
	
	part def CymbalPlayer {
		attribute cymbalStrikeCount : Integer;
		port activationInput;
	}
	
	part def TimeDial {
		attribute currentHourMarker : Integer;
		attribute totalHourMarkers : Integer;
		port advanceCommand;
	}
	
	part def ScribeFigure {
		attribute pointerAngle : Real;
		port dialPosition;
	}
	
	action def RegulateWaterFlow {
		in sourceVolume : VolumeValue;
		in targetRate : VolumeFlowRateValue;
		out regulatedFlow : VolumeFlowRateValue;
	}
	
	action def FillBowl {
		in incomingFlow : VolumeFlowRateValue;
		in currentLevel : VolumeValue;
		in fillDuration : TimeValue;
		out newLevel : VolumeValue;
	}
	
	action def DetectSinking {
		in waterLevel : VolumeValue;
		in threshold : VolumeValue;
		out sinkDetected : Boolean;
	}
	
	action def ActivateLever {
		in sinkSignal : BowlSunkSignal;
		out ballRelease : BallReleaseSignal;
		out dialAdvance : DialAdvanceSignal;
		out reset : ResetSignal;
	}
	
	action def ReleaseBall {
		in releaseSignal : BallReleaseSignal;
		in availableBalls : Integer;
		out ball : MetalBall;
	}
	
	action def DragonCatchAndRelease {
		in incomingBall : MetalBall;
		out releasedBall : MetalBall;
		out jawRotation : Real;
	}
	
	action def StrikeCymbals {
		in ballImpact : MetalBall;
		out soundGenerated : Boolean;
	}
	
	action def AdvanceDialMarker {
		in advanceSignal : DialAdvanceSignal;
		in currentMarker : Integer;
		in totalMarkers : Integer;
		out newMarker : Integer;
	}
	
	action def ResetBowl {
		in resetSignal : ResetSignal;
		out bowlEmptied : Boolean;
	}
	
	action def OperateElephantClock {
		in flowRate : VolumeFlowRateValue;
		in intervalDuration : TimeValue;
		in totalIntervals : Integer;
		out currentInterval : Integer;
		out timeDisplayed : Integer;
		
		first start;
		then merge continuousTimekeeping;
		
		then action regulateFlow : RegulateWaterFlow {
			in sourceVolume;
			in targetRate = flowRate;
			out regulatedFlow;
		}
		
		then action fillBowl : FillBowl {
			in incomingFlow = regulateFlow.regulatedFlow;
			in currentLevel;
			in fillDuration = intervalDuration;
			out newLevel;
		}
		
		then action detectSink : DetectSinking {
			in waterLevel = fillBowl.newLevel;
			in threshold;
			out sinkDetected;
		}
		
		then decide;
			if detectSink.sinkDetected then activateLever;
			if not detectSink.sinkDetected then continuousTimekeeping;
		
		action activateLever : ActivateLever {
			in sinkSignal;
			out ballRelease;
			out dialAdvance;
			out reset;
		}
		
		then action releaseBall : ReleaseBall {
			in releaseSignal = activateLever.ballRelease;
			in availableBalls;
			out ball;
		}
		
		then action dragonAction : DragonCatchAndRelease {
			in incomingBall = releaseBall.ball;
			out releasedBall;
			out jawRotation;
		}
		
		then action cymbalStrike : StrikeCymbals {
			in ballImpact = dragonAction.releasedBall;
			out soundGenerated;
		}
		
		then action advanceDial : AdvanceDialMarker {
			in advanceSignal = activateLever.dialAdvance;
			in currentMarker;
			in totalMarkers = totalIntervals;
			out newMarker;
		}
		
		then action resetBowl : ResetBowl {
			in resetSignal = activateLever.reset;
			out bowlEmptied;
		}
		
		then continuousTimekeeping;
	}
	
	part elephantClockSystem {
		doc /* 
			The Elephant Clock is an elaborate water-powered timekeeping automaton 
			designed by Al-Jazari in 1206 CE. Its primary function is to mark the 
			passage of time at regular intervals through a coordinated sequence of 
			mechanical actions and visual displays, powered entirely by the regulated 
			flow of water.
		*/
		
		attribute operatingFlowRate : VolumeFlowRateValue = 1.0 [SI::L/SI::h];
		attribute timeIntervalDuration : TimeValue = 30.0 [SI::min];
		attribute intervalsPerCycle : Integer = 24;
		
		part reservoir : UpperReservoir {
			attribute capacity = 50.0 [SI::L];
			attribute currentVolume = 50.0 [SI::L];
		}
		
		part regulator : FlowRegulator {
			attribute regulatedRate = elephantClockSystem::operatingFlowRate;
		}
		
		part bowl : FloatingBowl {
			attribute bowlCapacity = 0.5 [SI::L];
			attribute currentWaterLevel = 0.0 [SI::L];
			attribute sinkThreshold = 0.5 [SI::L];
		}
		
		part pulleySystem : PulleyAndRope {
			attribute ropeLength = 2.0 [SI::m];
		}
		
		part lever : TriggerLever {
			attribute leverAngle = 0.0;
		}
		
		part ballStore : BallReservoir {
			attribute ballCount = 24;
		}
		
		part dragon : DragonAutomaton {
			attribute jawAngle = 0.0;
		}
		
		part cymbals : CymbalPlayer {
			attribute cymbalStrikeCount = 0;
		}
		
		part dial : TimeDial {
			attribute currentHourMarker = 0;
			attribute totalHourMarkers = 24;
		}
		
		part scribe : ScribeFigure {
			attribute pointerAngle = 0.0;
		}
		
		connect reservoir.waterOutlet to regulator.waterInlet;
		connect regulator.waterOutlet to bowl.waterInlet;
		connect bowl.sinkSignalOut to lever.pulleyInput;
		connect lever.ballReleaseOutput to ballStore.releaseCommand;
		connect ballStore.ballOutput to dragon.ballInput;
		connect dragon.ballOutput to cymbals.activationInput;
		connect lever.dialAdvanceOutput to dial.advanceCommand;
		connect dial to scribe.dialPosition;
		
		perform action operateClock : OperateElephantClock {
			in flowRate = operatingFlowRate;
			in intervalDuration = timeIntervalDuration;
			in totalIntervals = intervalsPerCycle;
			out currentInterval;
			out timeDisplayed;
		}
	}
	
	requirement def TimekeepingAccuracy {
		doc /* 
			The clock shall maintain consistent time intervals throughout 
			its operating cycle with minimal drift.
		*/
		
		require constraint accuracyConstraint {
			doc /* Interval duration shall remain within 2% of nominal value. */
		}
	}
	
	requirement def FlowRegulation {
		doc /* 
			The water flow regulator shall maintain constant flow rate 
			independent of reservoir level variations.
		*/
		
		require constraint flowConstancy {
			doc /* Flow rate variation shall not exceed 3% over full reservoir range. */
		}
	}
	
	requirement def AutomataSequencing {
		doc /* 
			All automata actions shall execute in proper sequence following 
			each bowl sinking event.
		*/
		
		require constraint sequenceOrder {
			doc /* 
				Ball release, dragon rotation, cymbal strike, and dial advance 
				shall occur in specified order within 10 seconds.
			*/
		}
	}
	
	requirement def SystemReliability {
		doc /* 
			The clock shall operate continuously for at least 12 hours 
			without intervention.
		*/
		
		require constraint continuousOperation {
			doc /* System shall complete 24 intervals without failure. */
		}
	}
	
	requirement elephantClockRequirements {
		doc /* 
			The Elephant Clock system shall accurately measure and display 
			the passage of time through automated mechanical sequences, 
			demonstrating Al-Jazari's mastery of hydromechanical engineering.
		*/
		
		subject elephantClockSystem;
		
		require timekeepingAccuracy : TimekeepingAccuracy;
		require flowRegulation : FlowRegulation;
		require automataSequencing : AutomataSequencing;
		require systemReliability : SystemReliability;
	}
}
