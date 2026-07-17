package 'Pendulum Clock System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ClockTime {
		attribute hours : Integer;
		attribute minutes : Integer;
		attribute seconds : Integer;
	}
	
	attribute def PendulumAngle :> ISQ::PlaneAngleValue;
	attribute def SwingDirection;
	attribute def EscapementTick;
	attribute def WindingCommand;
	attribute def StopCommand;
	
	port def MechanicalCouplingPort {
		out torque : ISQ::TorqueValue;
		in motion : PendulumAngle;
	}
	
	port def EnergyPort {
		out power : ISQ::PowerValue;
	}
	
	port def TimingPort {
		out tick : EscapementTick;
	}
	
	part def Pendulum {
		doc /* Oscillating mass that provides the time base through its regular periodic motion. */
		
		attribute length :> ISQ::length;
		attribute bobMass :> ISQ::mass;
		attribute period :> ISQ::time;
		attribute currentAngle : PendulumAngle;
		
		in port impulseInput : MechanicalCouplingPort;
		out port swingOutput : MechanicalCouplingPort;
	}
	
	part def EscapementMechanism {
		doc /* Converts continuous rotational motion into discrete steps synchronized with pendulum swings. */
		
		in port pendulumInput : MechanicalCouplingPort;
		in port driveInput : EnergyPort;
		out port tickOutput : TimingPort;
		out port impulseOutput : MechanicalCouplingPort;
	}
	
	part def GearTrain {
		doc /* Transmits and reduces power from the energy source to the escapement and display. */
		
		attribute reductionRatio : Real;
		
		in port energyInput : EnergyPort;
		in port regulationInput : TimingPort;
		out port escapementDrive : EnergyPort;
		out port displayDrive : EnergyPort;
	}
	
	part def PowerSource {
		doc /* Stores and releases energy to drive the clock mechanism, typically a weight or spring. */
		
		attribute storedEnergy :> ISQ::energy;
		attribute maxEnergy :> ISQ::energy;
		
		in port windingInput;
		out port powerOutput : EnergyPort;
	}
	
	part def TimeDisplay {
		doc /* Visual representation of time through rotating hands on a dial. */
		
		attribute hourAngle :> ISQ::planeAngle;
		attribute minuteAngle :> ISQ::planeAngle;
		attribute secondAngle :> ISQ::planeAngle;
		attribute displayedTime : ClockTime;
		
		in port driveInput : EnergyPort;
	}
	
	action def SwingPendulum {
		in impulse : ISQ::TorqueValue;
		in currentAngle : PendulumAngle;
		in length : ISQ::LengthValue;
		out nextAngle : PendulumAngle;
		out swingComplete;
	}
	
	action def AdvanceEscapement {
		in pendulumSwing : PendulumAngle;
		in drivePower : ISQ::PowerValue;
		out tick : EscapementTick;
		out impulse : ISQ::TorqueValue;
	}
	
	action def TransmitPower {
		in sourcePower : ISQ::PowerValue;
		in tick : EscapementTick;
		out escapementPower : ISQ::PowerValue;
		out displayPower : ISQ::PowerValue;
	}
	
	action def UpdateHands {
		in drivePower : ISQ::PowerValue;
		inout hourAngle : ISQ::PlaneAngleValue;
		inout minuteAngle : ISQ::PlaneAngleValue;
		inout secondAngle : ISQ::PlaneAngleValue;
		out currentTime : ClockTime;
	}
	
	action def ProvidePower {
		inout storedEnergy : ISQ::EnergyValue;
		out power : ISQ::PowerValue;
	}
	
	action def KeepTime {
		in windCommand : WindingCommand;
		in stopCommand : StopCommand;
		out displayedTime : ClockTime;
		
		first start;
		
		then merge continuousOperation;
		
		then action providePower : ProvidePower {
			inout storedEnergy;
			out power;
		}
		
		flow providePower.power to transmit.sourcePower;
		
		then action swing : SwingPendulum {
			in impulse;
			in currentAngle;
			in length;
			out nextAngle;
			out swingComplete;
		}
		
		flow swing.nextAngle to advance.pendulumSwing;
		
		then action advance : AdvanceEscapement {
			in pendulumSwing;
			in drivePower;
			out tick;
			out impulse;
		}
		
		flow advance.impulse to swing.impulse;
		flow advance.tick to transmit.tick;
		
		then action transmit : TransmitPower {
			in sourcePower;
			in tick;
			out escapementPower;
			out displayPower;
		}
		
		flow transmit.escapementPower to advance.drivePower;
		flow transmit.displayPower to update.drivePower;
		
		then action update : UpdateHands {
			in drivePower;
			inout hourAngle;
			inout minuteAngle;
			inout secondAngle;
			out currentTime;
		}
		
		then decide;
			if providePower.storedEnergy > 0.0 [SI::J] then continuousOperation;
			if providePower.storedEnergy <= 0.0 [SI::J] then done;
	}
	
	part def PendulumClock {
		doc /* A mechanical timekeeping device that uses a swinging pendulum as its time base to regulate the advancement of gears and display of time. */
		
		part powerSource : PowerSource {
			attribute :>> storedEnergy;
			attribute :>> maxEnergy = 1000.0 [SI::J];
		}
		
		part pendulum : Pendulum {
			attribute :>> length = 0.994 [SI::m];
			attribute :>> bobMass = 0.5 [SI::kg];
			attribute :>> period = 2.0 [SI::s];
		}
		
		part escapement : EscapementMechanism;
		
		part gearTrain : GearTrain {
			attribute :>> reductionRatio = 3600.0;
		}
		
		part display : TimeDisplay;
		
		connect powerSource.powerOutput to gearTrain.energyInput;
		connect gearTrain.escapementDrive to escapement.driveInput;
		connect gearTrain.displayDrive to display.driveInput;
		connect escapement.tickOutput to gearTrain.regulationInput;
		connect escapement.impulseOutput to pendulum.impulseInput;
		connect pendulum.swingOutput to escapement.pendulumInput;
		
		perform action keepTime : KeepTime {
			in windCommand;
			in stopCommand;
			out displayedTime;
		}
	}
	
	part pendulumClock : PendulumClock {
		part :>> powerSource {
			perform keepTime.providePower;
		}
		
		part :>> pendulum {
			perform keepTime.swing;
		}
		
		part :>> escapement {
			perform keepTime.advance;
		}
		
		part :>> gearTrain {
			perform keepTime.transmit;
		}
		
		part :>> display {
			perform keepTime.update;
		}
	}
	
	requirement def TimekeepingAccuracy {
		doc /* The pendulum clock shall maintain accurate time through regulated oscillation of the pendulum. */
		
		require constraint periodicOscillation {
			doc /* The pendulum shall oscillate with a consistent period determined by its length. */
		}
		
		require constraint regulatedAdvancement {
			doc /* The escapement shall advance the gear train in discrete steps synchronized with pendulum swings. */
		}
	}
	
	requirement def ContinuousOperation {
		doc /* The pendulum clock shall operate continuously while energy is available from the power source. */
		
		require constraint energyAvailability {
			doc /* The power source shall maintain sufficient stored energy to drive the mechanism. */
		}
		
		require constraint mechanicalCoupling {
			doc /* All mechanical components shall be properly coupled to transmit motion and energy. */
		}
	}
	
	requirement def TimeDisplay {
		doc /* The pendulum clock shall display the current time through rotating hands on a dial. */
		
		require constraint handMovement {
			doc /* The display hands shall rotate at rates corresponding to hours, minutes, and seconds. */
		}
		
		require constraint gearReduction {
			doc /* The gear train shall provide appropriate reduction ratios for each display hand. */
		}
	}
	
	requirement clockSystemRequirements {
		doc /* Top-level requirements for the pendulum clock system to fulfill its primary function of accurate timekeeping. */
		
		subject pendulumClock;
		
		require reqTimekeepingAccuracy : TimekeepingAccuracy;
		require reqContinuousOperation : ContinuousOperation;
		require reqTimeDisplay : TimeDisplay;
		
		assume constraint gravitationalField {
			doc /* The clock operates in a constant gravitational field affecting pendulum period. */
		}
		
		assume constraint minimalFriction {
			doc /* Mechanical friction is minimized to maintain consistent pendulum motion. */
		}
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Pendulum Clock System'::*;

    action orchestrator {
        attribute testImpulse : ISQ::TorqueValue;
        attribute testCurrentAngle : PendulumAngle;
        attribute testLength : ISQ::LengthValue;
        action actionProbe : SwingPendulum {
            in impulse = testImpulse;
            in currentAngle = testCurrentAngle;
            in length = testLength;
        }
        first actionProbe;
    }
}
