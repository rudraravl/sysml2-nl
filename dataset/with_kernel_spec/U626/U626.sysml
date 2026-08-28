package 'Capacitive Sensing System' {
	private import ScalarValues::*;
	private import ISQ::*;

	attribute def CapacitanceValue :> Real;
	attribute def VoltageValue :> Real;
	attribute def FrequencyValue :> Real;
	attribute def DistanceValue :> Real;

	attribute def ExcitationSignal {
		frequency : FrequencyValue;
		voltage : VoltageValue;
	}
	attribute def AnalogResponse {
		voltage : VoltageValue;
	}
	attribute def ConditionedSignal {
		voltage : VoltageValue;
	}
	attribute def DigitalCapacitance {
		value : CapacitanceValue;
	}
	attribute def PowerSupply {
		voltage : VoltageValue;
	}
	attribute def StartCommand;
	attribute def CalibrateCommand;
	attribute def CalibrationComplete;
	attribute def ProximityEvent {
		distance : DistanceValue;
	}
	attribute def TouchEvent;

	action def Calibrate {
		in measured : CapacitanceValue;
		out baselineValue : CapacitanceValue;
	}
	action def ProcessMeasurement {
		in measured : CapacitanceValue;
		in baselineValue : CapacitanceValue;
		in proxThreshold : CapacitanceValue;
		in touchThresh : CapacitanceValue;
		out change : CapacitanceValue;
		out distance : DistanceValue;
	}
	action def ReportProximity;
	action def ReportTouch;

	part def PowerManagement {
		port powerOut {
			out power : PowerSupply;
		}
	}

	part def ExcitationGenerator {
		port powerIn {
			in power : PowerSupply;
		}
		port excitationOut {
			out excitation : ExcitationSignal;
		}
	}

	part def SensingElectrode {
		port powerIn {
			in power : PowerSupply;
		}
		port excitationIn {
			in excitation : ExcitationSignal;
		}
		port responseOut {
			out response : AnalogResponse;
		}
		attribute capacitance : CapacitanceValue;
	}

	part def SignalConditioner {
		port powerIn {
			in power : PowerSupply;
		}
		port responseIn {
			in response : AnalogResponse;
		}
		port conditionedOut {
			out conditioned : ConditionedSignal;
		}
	}

	part def CapacitanceConverter {
		port powerIn {
			in power : PowerSupply;
		}
		port conditionedIn {
			in conditioned : ConditionedSignal;
		}
		port digitalOut {
			out digitalValue : DigitalCapacitance;
		}
	}

	part def ProcessingUnit {
		port powerIn {
			in power : PowerSupply;
		}
		port digitalIn {
			in digitalValue : DigitalCapacitance;
		}
		port eventOut {
			out proximity : ProximityEvent;
			out touch : TouchEvent;
		}

		attribute baseline : CapacitanceValue;
		attribute proximityThreshold : CapacitanceValue;
		attribute touchThreshold : CapacitanceValue;
		attribute currentCapacitance : CapacitanceValue;
		attribute capacitanceChange : CapacitanceValue;
		attribute estimatedDistance : DistanceValue;

		action calibrate : Calibrate;
		action processMeasurement : ProcessMeasurement;
		action reportProximity : ReportProximity;
		action reportTouch : ReportTouch;

		exhibit state sensorStates {
			entry; then idle;
			state idle;
			accept StartCommand then calibration;
			state calibration {
				do calibrate {
					in measured = currentCapacitance;
					out baselineValue = baseline;
				}
			}
			accept CalibrationComplete then monitoring;
			state monitoring {
				do processMeasurement {
					in measured = currentCapacitance;
					in baselineValue = baseline;
					in proxThreshold = proximityThreshold;
					in touchThresh = touchThreshold;
					out change = capacitanceChange;
					out distance = estimatedDistance;
				}
			}
			accept when capacitanceChange > proximityThreshold
				then proximityActive;
			accept when capacitanceChange > touchThreshold
				then touchActive;
			state proximityActive {
				do reportProximity;
			}
			accept when capacitanceChange <= proximityThreshold
				then monitoring;
			accept when capacitanceChange > touchThreshold
				then touchActive;
			state touchActive {
				do reportTouch;
			}
			accept when capacitanceChange <= touchThreshold
				then monitoring;
		}
	}

	part def CapacitiveSensorSystem {
		part powerManagement : PowerManagement;
		part excitationGenerator : ExcitationGenerator;
		part sensingElectrode : SensingElectrode;
		part signalConditioner : SignalConditioner;
		part capacitanceConverter : CapacitanceConverter;
		part processingUnit : ProcessingUnit;

		flow powerFlow1 of PowerSupply
			from powerManagement.powerOut.power to excitationGenerator.powerIn.power;
		flow powerFlow2 of PowerSupply
			from powerManagement.powerOut.power to sensingElectrode.powerIn.power;
		flow powerFlow3 of PowerSupply
			from powerManagement.powerOut.power to signalConditioner.powerIn.power;
		flow powerFlow4 of PowerSupply
			from powerManagement.powerOut.power to capacitanceConverter.powerIn.power;
		flow powerFlow5 of PowerSupply
			from powerManagement.powerOut.power to processingUnit.powerIn.power;

		flow excitationFlow of ExcitationSignal
			from excitationGenerator.excitationOut.excitation to sensingElectrode.excitationIn.excitation;
		flow responseFlow of AnalogResponse
			from sensingElectrode.responseOut.response to signalConditioner.responseIn.response;
		flow conditionedFlow of ConditionedSignal
			from signalConditioner.conditionedOut.conditioned to capacitanceConverter.conditionedIn.conditioned;
		flow digitalFlow of DigitalCapacitance
			from capacitanceConverter.digitalOut.digitalValue to processingUnit.digitalIn.digitalValue;
	}

	requirement def CapacitiveSensingRequirements {
		requirement 'REQ-001' {
			doc /* The system shall detect capacitance changes without requiring physical pressure. */
		}
		requirement 'REQ-002' {
			doc /* The excitation generator shall produce a stable high-frequency electric field. */
		}
		requirement 'REQ-003' {
			doc /* The signal conditioner shall amplify the signal and filter environmental noise. */
		}
		requirement 'REQ-004' {
			doc /* The processing unit shall compare real-time capacitance to a calibrated baseline. */
		}
		requirement 'REQ-005' {
			doc /* The system shall report proximity when capacitance change exceeds the proximity threshold. */
		}
		requirement 'REQ-006' {
			doc /* The system shall register a touch event when capacitance change exceeds the touch threshold. */
		}
		requirement 'REQ-007' {
			doc /* The power management unit shall provide stable voltage to all components. */
		}
	}
}
