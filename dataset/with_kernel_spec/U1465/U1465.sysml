package 'Pendulum Clock' {
	private import ISQ::*;
	private import SI::*;

	package Definitions {
		alias Torque for ISQ::TorqueValue;
		alias Energy for ISQ::EnergyValue;
		alias Time for ISQ::TimeValue;
		attribute def AngleValue :> Real;
		alias Angle for AngleValue;
		alias Frequency for ISQ::FrequencyValue;
		alias Length for ISQ::LengthValue;
		alias Mass for ISQ::MassValue;
		alias Acceleration for ISQ::AccelerationValue;

		attribute def WindingCommand;
		attribute def StopCommand;

		port def DrivePort {
			out driveTorque: Torque;
		}
		port def GearInputPort {
			in inputTorque: Torque;
		}
		port def GearOutputPort {
			out outputTorque: Torque;
		}
		port def EscapementInputPort {
			in gearTorque: Torque;
		}
		port def EscapementOutputPort {
			out handDriveTorque: Torque;
		}
		port def PendulumInteractionPort {
			in push: Torque;
			out swingSignal: Frequency;
		}
		port def HandDrivePort {
			in handDriveTorque: Torque;
		}

		part def PowerSource {
			attribute storedEnergy: Energy;
			port drivePort : DrivePort;
		}
		part def GearTrain {
			attribute reductionRatio: Real;
			port inputPort : GearInputPort;
			port outputPort : GearOutputPort;
		}
		part def Pendulum {
			attribute length: Length;
			attribute bobMass: Mass;
			attribute naturalPeriod: Time;
			port pendulumPort : PendulumInteractionPort;
		}
		part def Escapement {
			port inputPort : EscapementInputPort;
			port outputPort : EscapementOutputPort;
			port pendulumPort : ~PendulumInteractionPort;
		}
		part def TimeDisplay {
			attribute hourAngle: Angle;
			attribute minuteAngle: Angle;
			attribute secondAngle: Angle;
			port inputPort : HandDrivePort;
		}
		part def PendulumClock {
			attribute timeDeviation: Time;
			part powerSource : PowerSource;
			part gearTrain : GearTrain;
			part escapement : Escapement;
			part pendulum : Pendulum;
			part timeDisplay : TimeDisplay;
		}

		action def ReleaseEnergy {
			out driveTorque: Torque;
		}
		action def TransmitPower {
			in driveTorque: Torque;
			out gearTorque: Torque;
		}
		action def RegulateMotion {
			in gearTorque: Torque;
			in swingSignal: Frequency;
			out pendulumPush: Torque;
			out handDriveTorque: Torque;
		}
		action def Oscillate {
			in push: Torque;
			out swingSignal: Frequency;
		}
		action def DisplayTime {
			in handDriveTorque: Torque;
			out hourAngle: Angle;
			out minuteAngle: Angle;
			out secondAngle: Angle;
		}

		requirement def TimekeepingAccuracy {
			doc /* The clock shall maintain time accurately within specified tolerance over a 24-hour period. */
			subject clock: PendulumClock;
			attribute maxDeviation: Time;
			require constraint { clock.timeDeviation <= maxDeviation }
		}
		requirement def PendulumPeriodRequirement {
			doc /* The pendulum period shall be determined by its length and local gravity per T = 2*pi*sqrt(L/g). */
			subject pendulum: Pendulum;
			attribute length: Length;
			attribute gravity: Acceleration;
			attribute period: Time;
			require constraint { period == 2.0 * 3.14159 * (length / gravity) ** 0.5 }
		}
		requirement def EnergyReserve {
			doc /* The power source shall provide sufficient energy to run the clock for at least 7 days. */
			subject powerSource: PowerSource;
			attribute storedEnergy: Energy;
			attribute dailyConsumption: Energy;
			require constraint { storedEnergy >= 7.0 * dailyConsumption }
		}
		requirement def ContinuousOperation {
			doc /* The clock shall run continuously as long as the power source has energy. */
			subject powerSource: PowerSource;
			require constraint { powerSource.storedEnergy > 0[J] }
		}
	}

	package Usages {
		private import Definitions::*;

		action 'operate clock' {
			loop {
				accept windingCommand : WindingCommand;
				then action {
					action 'release energy': ReleaseEnergy {
						out driveTorque: Torque;
					}
					flow 'release energy'.driveTorque to 'transmit power'.driveTorque;
					action 'transmit power': TransmitPower {
						in driveTorque: Torque;
						out gearTorque: Torque;
					}
					flow 'transmit power'.gearTorque to 'regulate motion'.gearTorque;
					action 'regulate motion': RegulateMotion {
						in gearTorque: Torque;
						in swingSignal: Frequency;
						out pendulumPush: Torque;
						out handDriveTorque: Torque;
					}
					flow 'regulate motion'.pendulumPush to 'oscillate'.push;
					action 'oscillate': Oscillate {
						in push: Torque;
						out swingSignal: Frequency;
					}
					flow 'oscillate'.swingSignal to 'regulate motion'.swingSignal;
					action 'display time': DisplayTime {
						in handDriveTorque: Torque;
						out hourAngle: Angle;
						out minuteAngle: Angle;
						out secondAngle: Angle;
					}
					flow 'regulate motion'.handDriveTorque to 'display time'.handDriveTorque;
				}
				then accept stopCommand : StopCommand;
			}
		}

		part clockSystem : PendulumClock {
			part :>> powerSource {
				perform ReleaseEnergy {
					out driveTorque = drivePort.driveTorque;
				}
			}
			part :>> gearTrain {
				perform TransmitPower {
					in driveTorque = inputPort.inputTorque;
					out gearTorque = outputPort.outputTorque;
				}
			}
			part :>> escapement {
				perform RegulateMotion {
					in gearTorque = inputPort.gearTorque;
					in swingSignal = pendulumPort.swingSignal;
					out pendulumPush = pendulumPort.push;
					out handDriveTorque = outputPort.handDriveTorque;
				}
			}
			part :>> pendulum {
				perform Oscillate {
					in push = pendulumPort.push;
					out swingSignal = pendulumPort.swingSignal;
				}
			}
			part :>> timeDisplay {
				perform DisplayTime {
					in handDriveTorque = inputPort.handDriveTorque;
				}
			}

			flow of Torque from powerSource.drivePort.driveTorque to gearTrain.inputPort.inputTorque;
			flow of Torque from gearTrain.outputPort.outputTorque to escapement.inputPort.gearTorque;
			flow of Torque from escapement.outputPort.handDriveTorque to timeDisplay.inputPort.handDriveTorque;
			flow of Torque from escapement.pendulumPort.push to pendulum.pendulumPort.push;
			flow of Frequency from pendulum.pendulumPort.swingSignal to escapement.pendulumPort.swingSignal;

			requirement timekeepingAccuracy : TimekeepingAccuracy {
				subject clock = clockSystem;
				attribute maxDeviation = 1.0[s];
			}
			requirement pendulumPeriodReq : PendulumPeriodRequirement {
				subject pendulum = pendulum;
				attribute length = pendulum.length;
				attribute gravity = 9.81[m/s^2];
				attribute period = pendulum.naturalPeriod;
			}
			requirement energyReserve : EnergyReserve {
				subject powerSource = powerSource;
				attribute storedEnergy = powerSource.storedEnergy;
				attribute dailyConsumption = 10.0[J];
			}
			requirement continuousOperation : ContinuousOperation {
				subject powerSource = powerSource;
			}
		}
	}
}
