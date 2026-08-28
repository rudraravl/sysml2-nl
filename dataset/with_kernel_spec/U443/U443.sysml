package 'Veress Needle Insufflation System' {
	private import ISQ::*;
	private import SI::*;
	private import ScalarValues::*;

	item def CO2Gas;

	port def GasOutPort {
		out item gas : CO2Gas;
	}

	port def GasInPort {
		in item gas : CO2Gas;
	}

	port def PressureOutPort {
		out attribute pressure : ISQ::Pressure;
	}

	port def PressureInPort {
		in attribute pressure : ISQ::Pressure;
	}

	part def SharpCannula {
		attribute diameter : ISQ::Length = 2.1 [mm];
		attribute length : ISQ::Length = 120 [mm];
	}

	part def SpringLoadedObturator {
		attribute isExtended : Boolean = false;
		action extend;
		action retract;
	}

	part def Stopcock {
		attribute isOpen : Boolean = false;
		action open;
		action close;
	}

	part def PressureSensor {
		attribute measuredPressure : ISQ::Pressure;
	}

	part def HighPressureCO2Cylinder {
		port gasOutlet : GasOutPort;
	}

	part def CO2Insufflator {
		part cylinder : HighPressureCO2Cylinder[1];
		attribute targetPressure : ISQ::Pressure = 1.8 [kPa];
		attribute flowRate : ISQ::VolumeFlowRate;
		port gasOutlet : GasOutPort;
		port pressureInlet : PressureInPort;
		action regulateFlow;
	}

	state def SafetyMechanism {
		state Retracted;
		state Extended;
		transition from Retracted to Extended when sensor.measuredPressure < 1.0 [kPa];
		transition from Extended to Retracted when sensor.measuredPressure > 1.0 [kPa];
	}

	part def VeressNeedle {
		part cannula : SharpCannula[1];
		part obturator : SpringLoadedObturator[1];
		part valve : Stopcock[1];
		part sensor : PressureSensor[1];
		port gasInlet : GasInPort;
		port pressureOutlet : PressureOutPort;

		perform SafetyMechanism;
	}

	connection def GasFlowConnection {
		end : GasOutPort[1];
		end : GasInPort[1];
	}

	connection def PressureFeedbackConnection {
		end : PressureOutPort[1];
		end : PressureInPort[1];
	}

	state def OperationalProcedure {
		state Idle;
		state Insertion;
		state CavityEntry;
		state PlacementVerification;
		state Insufflation;
		state TargetPressureReached;

		transition from Idle to Insertion;
		transition from Insertion to CavityEntry when needle.sensor.measuredPressure < 1.0 [kPa];
		transition from CavityEntry to PlacementVerification;
		transition from PlacementVerification to Insufflation;
		transition from Insufflation to TargetPressureReached when needle.sensor.measuredPressure >= insufflator.targetPressure;
	}

	part def VeressNeedleInsufflationSystem {
		part needle : VeressNeedle[1];
		part insufflator : CO2Insufflator[1];

		connection : GasFlowConnection connect insufflator.gasOutlet to needle.gasInlet;
		connection : PressureFeedbackConnection connect needle.pressureOutlet to insufflator.pressureInlet;

		perform OperationalProcedure;
	}

	requirement def SafetyRequirement {
		text "The system shall prevent accidental puncture of internal organs via the spring-loaded obturator.";
	}

	requirement def PressureRequirement {
		text "The insufflator shall regulate abdominal pressure within the safe range of 1.6 to 2.0 kPa.";
		attribute minPressure : ISQ::Pressure = 1.6 [kPa];
		attribute maxPressure : ISQ::Pressure = 2.0 [kPa];
	}

	requirement def DimensionRequirement {
		text "Sharp cannula diameter shall be 2.1 mm and length shall be 120 mm.";
	}

	satisfy SafetyRequirement by VeressNeedle;
	satisfy PressureRequirement by CO2Insufflator;
	satisfy DimensionRequirement by SharpCannula;
}
