package 'TEOM Instrument' {
	private import ISQ::MassValue;
	private import ISQ::FrequencyValue;
	private import ISQ::TemperatureValue;
	private import ISQ::VolumeFlowRateValue;
	private import ISQ::MassConcentrationValue;
	private import SI::Cel;
	private import ScalarValues::Real;

	item def Air;
	attribute def DriveSignal;
	attribute def InitComplete;
	attribute def BaselineEstablished;
	attribute def SamplingComplete;
	attribute def ComputationComplete;

	part def TaperedElement {
		attribute naturalFrequency : FrequencyValue;
		attribute currentFrequency : FrequencyValue;
		attribute elementMass : MassValue;
		port drivePort { in drive : DriveSignal; }
		port vibrationPort { out frequency : FrequencyValue; }
		port tempPort { in temperature : TemperatureValue; }
	}

	part def PiezoelectricDriver {
		port driveOutPort { out drive : DriveSignal; }
	}

	part def VacuumPump {
		attribute flowRate : VolumeFlowRateValue;
		port airInPort { in air : Air; }
		port flowRatePort { out flowRateValue : VolumeFlowRateValue; }
	}

	part def ParticulateFilter {
		attribute collectedMass : MassValue;
		port airInPort { in air : Air; }
		port airOutPort { out filteredAir : Air; }
	}

	part def FrequencyDetector {
		port vibrationInPort { in frequency : FrequencyValue; }
		port frequencyOutPort { out detectedFrequency : FrequencyValue; }
	}

	part def TemperatureController {
		attribute setpoint : TemperatureValue;
		port tempOutPort { out temperature : TemperatureValue; }
	}

	part def DataProcessor {
		attribute baselineFrequency : FrequencyValue;
		attribute currentFrequency : FrequencyValue;
		attribute flowRate : VolumeFlowRateValue;
		attribute collectedMass : MassValue;
		attribute concentration : MassConcentrationValue;
		port freqInPort { in detectedFrequency : FrequencyValue; }
		port flowInPort { in flowRateValue : VolumeFlowRateValue; }
		port concOutPort { out concentration : MassConcentrationValue; }
	}

	part def TEOM {
		port airIntakePort { in air : Air; }
		port dataOutPort { out concentration : MassConcentrationValue; }

		part taperedElement : TaperedElement;
		part piezoelectricDriver : PiezoelectricDriver;
		part vacuumPump : VacuumPump;
		part particulateFilter : ParticulateFilter;
		part frequencyDetector : FrequencyDetector;
		part temperatureController : TemperatureController;
		part dataProcessor : DataProcessor;

		flow airToFilter of Air
			from airIntakePort.air to particulateFilter.airInPort.air;
		flow filterToPump of Air
			from particulateFilter.airOutPort.filteredAir to vacuumPump.airInPort.air;
		flow driveFlow of DriveSignal
			from piezoelectricDriver.driveOutPort.drive to taperedElement.drivePort.drive;
		flow tempFlow of TemperatureValue
			from temperatureController.tempOutPort.temperature to taperedElement.tempPort.temperature;
		flow vibrationFlow of FrequencyValue
			from taperedElement.vibrationPort.frequency to frequencyDetector.vibrationInPort.frequency;
		flow detectedFreqFlow of FrequencyValue
			from frequencyDetector.frequencyOutPort.detectedFrequency to dataProcessor.freqInPort.detectedFrequency;
		flow flowRateFlow of VolumeFlowRateValue
			from vacuumPump.flowRatePort.flowRateValue to dataProcessor.flowInPort.flowRateValue;
		flow concOutFlow of MassConcentrationValue
			from dataProcessor.concOutPort.concentration to dataOutPort.concentration;
	}

	action def InitializeSystem;
	action def MeasureBaseline { out baselineFreq : FrequencyValue; }
	action def SampleAir {
		out currentFreq : FrequencyValue;
		out collectedMass : MassValue;
	}
	action def ComputeConcentration {
		in baselineFreq : FrequencyValue;
		in currentFreq : FrequencyValue;
		in flowRate : VolumeFlowRateValue;
		out concentration : MassConcentrationValue;
	}

	action def TEOMOperation {
		in airFlowRate : VolumeFlowRateValue;
		out concentration : MassConcentrationValue;

		action initialize : InitializeSystem;
		then action measureBaseline : MeasureBaseline {
			out baselineFreq;
		}
		then loop {
			action sample : SampleAir {
				out currentFreq;
				out collectedMass;
			}
			then action compute : ComputeConcentration {
				in baselineFreq = measureBaseline.baselineFreq;
				in currentFreq = sample.currentFreq;
				in flowRate = TEOMOperation::airFlowRate;
				out concentration;
			}
		}
	}

	state teomStates {
		entry; then initializing;
		state initializing;
		accept InitComplete then measuringBaseline;
		state measuringBaseline;
		accept BaselineEstablished then sampling;
		state sampling;
		accept SamplingComplete then computing;
		state computing;
		accept ComputationComplete then sampling;
	}

	requirement req_ContinuousMeasurement {
		doc /* The TEOM shall continuously measure airborne particulate matter concentration in real-time. */
	}
	requirement req_TemperatureControl {
		doc /* The temperature controller shall maintain the tapered element at a stable elevated temperature of 50 degrees Celsius to prevent moisture condensation on the filter. */
		attribute setpoint : TemperatureValue;
		constraint { setpoint == 50 [Cel] }
	}
	requirement req_BaselineFrequency {
		doc /* The data processor shall establish a baseline frequency with a clean filter before sampling begins. */
	}
	requirement req_FrequencyMassProportionality {
		doc /* The change in resonant frequency of the tapered element shall be directly proportional to the mass of particles collected on the filter. */
		attribute frequencyShift : FrequencyValue;
		attribute massChange : MassValue;
		attribute proportionalityConstant : Real;
		constraint { frequencyShift == proportionalityConstant * massChange }
	}
}
