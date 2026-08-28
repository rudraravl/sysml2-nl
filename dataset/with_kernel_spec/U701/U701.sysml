package 'Doppler Ground Speed Radar System' {
	private import ScalarValues::*;
	private import ISQ::*;

	item def VehiclePower {
		attribute voltage : ElectricPotentialValue;
	}
	item def RegulatedPower {
		attribute voltage : ElectricPotentialValue;
	}
	item def RadarSignal {
		attribute frequency : FrequencyValue;
		attribute power : PowerValue;
	}
	item def DopplerMeasurement {
		attribute groundSpeed : SpeedValue;
		attribute dopplerShift : FrequencyValue;
	}
	item def FaultEvent;

	attribute def PowerOnCommand;
	attribute def StandbyCommand;
	attribute def OperateCommand;
	attribute def ResetCommand;
	attribute def SelfTestPassed;
	attribute def SelfTestFailed;
	attribute def FaultDetected;

	action def 'Convert Power';
	action def 'Generate RF Signal';
	action def 'Focus Radar Beam';
	action def 'Amplify and Filter Echo';
	action def 'Compute Doppler Speed';
	action def 'Initialize Radar';
	action def 'Perform Measurement Cycle';
	action def 'Enter Standby';
	action def 'Resume Operation';
	action def 'Handle Fault';

	state def 'Radar States';

	part def PowerSupplyUnit {
		perform action 'convert power' : 'Convert Power';
		port vehiclePowerIn {
			in vehiclePower : VehiclePower;
		}
		port regulatedPowerOut {
			out regulatedPower : RegulatedPower;
		}
	}

	part def RFTransmitter {
		perform action 'generate RF signal' : 'Generate RF Signal';
		port powerIn {
			in power : RegulatedPower;
		}
		port rfOut {
			out signal : RadarSignal;
		}
		port referenceOut {
			out reference : RadarSignal;
		}
		attribute transmitFrequency : FrequencyValue;
	}

	part def AntennaSystem {
		perform action 'focus radar beam' : 'Focus Radar Beam';
		port txIn {
			in signal : RadarSignal;
		}
		port echoOut {
			out echo : RadarSignal;
		}
		attribute beamAngle : PlaneAngleValue;
	}

	part def RFReceiver {
		perform action 'amplify and filter echo' : 'Amplify and Filter Echo';
		port echoIn {
			in echo : RadarSignal;
		}
		port receivedOut {
			out signal : RadarSignal;
		}
		port powerIn {
			in power : RegulatedPower;
		}
	}

	part def DopplerProcessor {
		perform action 'compute doppler speed' : 'Compute Doppler Speed';
		port receivedIn {
			in received : RadarSignal;
		}
		port referenceIn {
			in reference : RadarSignal;
		}
		port speedOut {
			out speed : DopplerMeasurement;
		}
		port powerIn {
			in power : RegulatedPower;
		}
		port faultOut {
			out faultEvt : FaultEvent;
		}
	}

	part def DopplerGroundSpeedRadarSystem {
		port vehiclePowerIn {
			in vehiclePower : VehiclePower;
		}
		port speedDataOut {
			out speedData : DopplerMeasurement;
		}
		port faultReportOut {
			out faultReport : FaultEvent;
		}
		exhibit state 'radar states' : 'Radar States';
	}

	part dopplerRadar : DopplerGroundSpeedRadarSystem {
		action 'initialize radar' : 'Initialize Radar';
		action 'perform measurement cycle' : 'Perform Measurement Cycle';
		action 'enter standby' : 'Enter Standby';
		action 'resume operation' : 'Resume Operation';
		action 'handle fault' : 'Handle Fault';

		part psu : PowerSupplyUnit;
		part tx : RFTransmitter;
		part antenna : AntennaSystem;
		part rx : RFReceiver;
		part processor : DopplerProcessor;

		flow vehiclePowerFlow of VehiclePower
			from vehiclePowerIn.vehiclePower to psu.vehiclePowerIn.vehiclePower;

		flow regPowerToTx of RegulatedPower
			from psu.regulatedPowerOut.regulatedPower to tx.powerIn.power;

		flow regPowerToRx of RegulatedPower
			from psu.regulatedPowerOut.regulatedPower to rx.powerIn.power;

		flow regPowerToProcessor of RegulatedPower
			from psu.regulatedPowerOut.regulatedPower to processor.powerIn.power;

		flow txToAntenna of RadarSignal
			from tx.rfOut.signal to antenna.txIn.signal;

		flow referenceToProcessor of RadarSignal
			from tx.referenceOut.reference to processor.referenceIn.reference;

		flow echoToReceiver of RadarSignal
			from antenna.echoOut.echo to rx.echoIn.echo;

		flow receivedToProcessor of RadarSignal
			from rx.receivedOut.signal to processor.receivedIn.received;

		flow speedOutputFlow of DopplerMeasurement
			from processor.speedOut.speed to speedDataOut.speedData;

		flow faultReportFlow of FaultEvent
			from processor.faultOut.faultEvt to faultReportOut.faultReport;

		state 'radar states' : 'Radar States' {
			entry; then off;

			state off;
			transition off_to_initializing
				first off
				accept PowerOnCommand
				then initializing;

			state initializing {
				entry 'initialize radar';
			}
			transition initializing_to_operational
				first initializing
				accept SelfTestPassed
				then operational;
			transition initializing_to_faulted
				first initializing
				accept SelfTestFailed
				then faulted;

			state operational {
				do 'perform measurement cycle';
			}
			transition operational_to_standby
				first operational
				accept StandbyCommand
				do 'enter standby'
				then standby;
			transition operational_to_faulted
				first operational
				accept FaultDetected
				then faulted;

			state standby;
			transition standby_to_operational
				first standby
				accept OperateCommand
				do 'resume operation'
				then operational;
			transition standby_to_faulted
				first standby
				accept FaultDetected
				then faulted;

			state faulted {
				entry 'handle fault';
			}
			transition faulted_to_initializing
				first faulted
				accept ResetCommand
				then initializing;
		}
	}

	requirement 'Ground Speed Accuracy' {
		doc /* The Doppler ground speed radar system shall provide true speed measurements relative to the surface with high accuracy, independent of wheel slip, wind speed, and GPS availability. */
		subject dopplerRadar;
	}

	requirement 'Operational Lifecycle' {
		doc /* The radar shall operate through initialization, operational, standby, and fault states with defined transitions and safety behaviors, including automatic transmitter shutdown on fault detection. */
		subject dopplerRadar;
	}

	requirement 'Doppler Processing' {
		doc /* The Doppler processor shall compare the received signal frequency to the transmitted reference frequency, measure the Doppler shift, and combine it with the known antenna beam angle to calculate true ground speed. */
		subject dopplerRadar;
	}
}
