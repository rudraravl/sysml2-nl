package SelsynAngleTransmissionSystem {
	private import ISQ::AngleValue;
	private import ISQ::TorqueValue;
	private import ISQ::ElectricPotentialValue;
	private import ISQ::FrequencyValue;
	private import ScalarValues::*;
	
	item def ACPower {
		attribute voltage : ElectricPotentialValue;
		attribute frequency : FrequencyValue;
	}
	
	item def ThreePhaseSignals {
		attribute phaseA : ElectricPotentialValue;
		attribute phaseB : ElectricPotentialValue;
		attribute phaseC : ElectricPotentialValue;
	}
	
	attribute def AngleAlignedEvent;
	attribute def AngleMismatchEvent;
	
	part def InputShaft {
		port angleOut {
			out angle : AngleValue;
		}
	}
	
	part def OutputShaft {
		port angleIn {
			in angle : AngleValue;
		}
		port torqueIn {
			in torque : TorqueValue;
		}
	}
	
	part def ACPowerSource {
		port powerOut {
			out power : ACPower;
		}
	}
	
	part def SelsynTransmitterUnit {
		port angleIn {
			in angle : AngleValue;
		}
		port powerIn {
			in power : ACPower;
		}
		port signalsOut {
			out signals : ThreePhaseSignals;
		}
		
		action convertAngleToVoltage {
			in currentAngle : AngleValue;
			in excitation : ACPower;
			out outSignals : ThreePhaseSignals;
		}
	}
	
	part def SelsynReceiverUnit {
		port signalsIn {
			in signals : ThreePhaseSignals;
		}
		port powerIn {
			in power : ACPower;
		}
		port angleOut {
			out angle : AngleValue;
		}
		port torqueOut {
			out torque : TorqueValue;
		}
		
		attribute currentAngle : AngleValue;
		attribute correctiveTorque : TorqueValue;
		attribute isAligned : Boolean;
		
		state def SynchronizationStates;
		state synchronizationState : SynchronizationStates {
			entry; then misaligned;
			state misaligned {
				do action applyCorrectiveTorque { /* generate torque proportional to angle error and rotate shaft */ }
			}
			accept AngleAlignedEvent
				then aligned;
			state aligned {
				do action holdPosition { /* hold current position with zero corrective torque */ }
			}
			accept AngleMismatchEvent
				then misaligned;
		}
	}
	
	requirement def AngleTransmissionRequirement {
		doc /* The output shaft must replicate the input shaft angle. */
		attribute inputAngle : AngleValue;
		attribute outputAngle : AngleValue;
		constraint { outputAngle == inputAngle }
	}
	
	part def SelsynSystem {
		part inputShaft : InputShaft;
		part outputShaft : OutputShaft;
		part acPowerSource : ACPowerSource;
		part transmitter : SelsynTransmitterUnit;
		part receiver : SelsynReceiverUnit;
		
		interface connect inputShaft.angleOut to transmitter.angleIn {
			flow angleFlow of AngleValue from inputShaft.angleOut.angle to transmitter.angleIn.angle;
		}
		
		interface connect acPowerSource.powerOut to transmitter.powerIn {
			flow powerFlow1 of ACPower from acPowerSource.powerOut.power to transmitter.powerIn.power;
		}
		
		interface connect acPowerSource.powerOut to receiver.powerIn {
			flow powerFlow2 of ACPower from acPowerSource.powerOut.power to receiver.powerIn.power;
		}
		
		interface connect transmitter.signalsOut to receiver.signalsIn {
			flow signalsFlow of ThreePhaseSignals from transmitter.signalsOut.signals to receiver.signalsIn.signals;
		}
		
		interface connect receiver.angleOut to outputShaft.angleIn {
			flow angleFlow2 of AngleValue from receiver.angleOut.angle to outputShaft.angleIn.angle;
		}
		
		interface connect receiver.torqueOut to outputShaft.torqueIn {
			flow torqueFlow of TorqueValue from receiver.torqueOut.torque to outputShaft.torqueIn.torque;
		}
		
		requirement angleTransmission : AngleTransmissionRequirement {
			:>> inputAngle = inputShaft.angleOut.angle;
			:>> outputAngle = outputShaft.angleIn.angle;
		}
	}
}
