package 'Pressure Regulation System' {
	private import ISQ::VolumeValue;
	private import ISQ::PressureValue;
	private import ISQ::DurationValue;
	private import ScalarValues::*;
	private import SI::kPa;
	private import SI::L;
	private import SI::s;

	attribute def PressureReading {
		value : PressureValue;
	}

	attribute def ValveCommand {
		position : Real;
	}

	action def ShutdownSystem;

	part def PressureVessel {
		attribute volume : VolumeValue = 500 [L];
		attribute maxPressure : PressureValue = 1000 [kPa];
		attribute targetPressure : PressureValue = 500 [kPa];
		attribute tolerance : PressureValue = 5 [kPa];
		attribute criticalPressure : PressureValue = 950 [kPa];
		attribute currentPressure : PressureValue;
		port pressurePort {
			out pressure : PressureValue;
		}
	}

	part def PressureSensor {
		port pressureInPort {
			in pressure : PressureValue;
		}
		port pressureOutPort {
			out pressureReading : PressureReading;
		}
	}

	part def PressureController {
		port pressureInPort {
			in pressureReading : PressureReading;
		}
		port valveCommandPort {
			out valveCommand : ValveCommand;
		}
		action shutdownSystem : ShutdownSystem;
		exhibit state controllerStates {
			in vessel : PressureVessel;
			entry; then Setup;
			state Setup;
			accept after 10 [s]
				then PassiveMonitoring;
			state PassiveMonitoring;
			accept when pressureInPort.pressureReading.value < vessel.targetPressure - vessel.tolerance
				then ActiveRegulating;
			accept when pressureInPort.pressureReading.value > vessel.targetPressure + vessel.tolerance
				then ActiveRegulating;
			accept when pressureInPort.pressureReading.value >= vessel.criticalPressure
				then Emergency;
			state ActiveRegulating;
			accept when pressureInPort.pressureReading.value >= vessel.targetPressure - vessel.tolerance
				and pressureInPort.pressureReading.value <= vessel.targetPressure + vessel.tolerance
				then PassiveMonitoring;
			accept when pressureInPort.pressureReading.value >= vessel.criticalPressure
				then Emergency;
			state Emergency {
				entry send new ValveCommand(0.0) to valveCommandPort;
				do shutdownSystem;
			}
		}
	}

	part def InletValve {
		port valveCommandPort {
			in valveCommand : ValveCommand;
		}
	}

	part def ReliefValve {
		in vessel : PressureVessel;
		attribute threshold : PressureValue = 950 [kPa];
		exhibit state reliefStates {
			entry; then Closed;
			state Closed;
			accept when vessel.currentPressure >= threshold
				then Open;
			state Open;
			accept when vessel.currentPressure < threshold
				then Closed;
		}
	}

	part def PressureRegulationSystem {
		part vessel : PressureVessel;
		part sensor : PressureSensor;
		part controller : PressureController;
		part inletValve : InletValve;
		part reliefValve : ReliefValve;

		bind controller.controllerStates.vessel = vessel;
		bind reliefValve.vessel = vessel;

		flow pressureToSensor of PressureValue
			from vessel.pressurePort.pressure to sensor.pressureInPort.pressure;
		flow pressureFlow of PressureReading
			from sensor.pressureOutPort.pressureReading to controller.pressureInPort.pressureReading;
		flow commandFlow of ValveCommand
			from controller.valveCommandPort.valveCommand to inletValve.valveCommandPort.valveCommand;
	}

	requirement def MaintainTargetPressure {
		subject vessel : PressureVessel;
		constraint lowerBound { vessel.currentPressure >= vessel.targetPressure - vessel.tolerance }
		constraint upperBound { vessel.currentPressure <= vessel.targetPressure + vessel.tolerance }
	}

	requirement def SafetyRelief {
		subject vessel : PressureVessel;
		constraint maxPressureLimit { vessel.currentPressure < vessel.maxPressure }
	}
}
