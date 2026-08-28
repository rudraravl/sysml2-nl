package 'Digital Sphygmomanometer' {
	private import ScalarValues::*;

	unit mmHg;
	unit bpm;
	unit s;

	attribute def Pressure :> Real;
	attribute def PulseRate :> Real;
	attribute def Duration :> Real;

	item def Air;

	item def CuffPressure {
		attribute pressure : Pressure;
	}

	item def OscillationSignal {
		attribute amplitude : Pressure;
	}

	item def MeasurementResult {
		attribute systolic : Pressure;
		attribute diastolic : Pressure;
		attribute meanArterialPressure : Pressure;
		attribute pulseRate : PulseRate;
	}

	item def StartSignal;

	item def InflateCommand {
		attribute targetPressure : Pressure;
	}

	item def DeflateCommand {
		attribute releaseRate : Pressure;
	}

	part def StartButton {
		port signalPort {
			out item startSignal : StartSignal;
		}
	}

	part def Pump {
		port controlPort {
			in item inflateCommand : InflateCommand;
		}
		port airOutPort {
			out item air : Air;
		}
	}

	part def ExhaustValve {
		port controlPort {
			in item deflateCommand : DeflateCommand;
		}
		port airInPort {
			in item air : Air;
		}
	}

	part def Cuff {
		port airInPort {
			in item air : Air;
		}
		port airOutPort {
			out item air : Air;
		}
		port pressurePort {
			out item cuffPressure : CuffPressure;
		}
	}

	part def PressureTransducer {
		port pressureInPort {
			in item cuffPressure : CuffPressure;
		}
		port dataOutPort {
			out item pressureData : CuffPressure;
		}
	}

	part def OscillationDetector {
		port pressureInPort {
			in item cuffPressure : CuffPressure;
		}
		port signalOutPort {
			out item oscillationData : OscillationSignal;
		}
	}

	part def Display {
		port resultInPort {
			in item result : MeasurementResult;
		}
	}

	part def Microprocessor {
		port startPort {
			in item startSignal : StartSignal;
		}
		port pumpControlPort {
			out item inflateCommand : InflateCommand;
		}
		port valveControlPort {
			out item deflateCommand : DeflateCommand;
		}
		port pressureDataPort {
			in item pressureData : CuffPressure;
		}
		port oscillationDataPort {
			in item oscillationData : OscillationSignal;
		}
		port displayPort {
			out item result : MeasurementResult;
		}

		attribute targetPressure : Pressure = 180 [mmHg];
		attribute minPressure : Pressure = 30 [mmHg];

		state machine MeasurementControl {
			state Idle;
			state Inflating;
			state Deflating;
			state Analyzing;
			state Displaying;

			transition initial to Idle;
			transition from Idle to Inflating on startPort.startSignal;
			transition from Inflating to Deflating;
			transition from Deflating to Analyzing;
			transition from Analyzing to Displaying;
			transition from Displaying to Idle;
		}
	}

	part def Sphygmomanometer {
		part startButton : StartButton;
		part pump : Pump;
		part valve : ExhaustValve;
		part cuff : Cuff;
		part transducer : PressureTransducer;
		part detector : OscillationDetector;
		part microprocessor : Microprocessor;
		part display : Display;

		flow startSignalFlow of StartSignal
			from startButton.signalPort.startSignal to microprocessor.startPort.startSignal;
		flow pumpControlFlow of InflateCommand
			from microprocessor.pumpControlPort.inflateCommand to pump.controlPort.inflateCommand;
		flow valveControlFlow of DeflateCommand
			from microprocessor.valveControlPort.deflateCommand to valve.controlPort.deflateCommand;
		flow pumpAirFlow of Air
			from pump.airOutPort.air to cuff.airInPort.air;
		flow cuffAirFlow of Air
			from cuff.airOutPort.air to valve.airInPort.air;
		flow cuffPressureFlow of CuffPressure
			from cuff.pressurePort.cuffPressure to transducer.pressureInPort.cuffPressure;
		flow cuffOscillationFlow of CuffPressure
			from cuff.pressurePort.cuffPressure to detector.pressureInPort.cuffPressure;
		flow pressureDataFlow of CuffPressure
			from transducer.dataOutPort.pressureData to microprocessor.pressureDataPort.pressureData;
		flow oscillationDataFlow of OscillationSignal
			from detector.signalOutPort.oscillationData to microprocessor.oscillationDataPort.oscillationData;
		flow displayResultFlow of MeasurementResult
			from microprocessor.displayPort.result to display.resultInPort.result;

		perform action measurementCycle : MeasurementCycle;

		requirement safePressureReq : SafePressureLimit {
			subject cuff;
		}
		requirement accuracyReq : MeasurementAccuracy {
			subject transducer;
		}
		requirement cycleTimeReq : CycleTimeLimit {
			subject microprocessor;
		}
	}

	action def InflateCuff {
		in item inflateCommand : InflateCommand;
		out item air : Air;
	}

	action def DeflateCuff {
		in item deflateCommand : DeflateCommand;
		out item air : Air;
	}

	action def MeasurePressure {
		in item cuffPressure : CuffPressure;
		out item pressureData : CuffPressure;
	}

	action def DetectOscillations {
		in item cuffPressure : CuffPressure;
		out item oscillationData : OscillationSignal;
	}

	action def AnalyzeData {
		in item pressureData : CuffPressure;
		in item oscillationData : OscillationSignal;
		out item result : MeasurementResult;
	}

	action def DisplayResult {
		in item result : MeasurementResult;
	}

	action def MeasurementCycle {
		first start;
		then action inflate : InflateCuff;
		then action deflate : DeflateCuff;
		then action measure : MeasurePressure;
		flow from measure.pressureData to analyze.pressureData;
		then action detect : DetectOscillations;
		flow from detect.oscillationData to analyze.oscillationData;
		then action analyze : AnalyzeData;
		flow from analyze.result to display.result;
		then action display : DisplayResult;
		then done;
	}

	requirement def SafePressureLimit {
		doc "The cuff pressure shall not exceed 300 mmHg to ensure patient safety.";
		attribute maxSafePressure : Pressure = 300 [mmHg];
	}

	requirement def MeasurementAccuracy {
		doc "Pressure readings shall be accurate within +/- 3 mmHg.";
		attribute maxError : Pressure = 3 [mmHg];
	}

	requirement def CycleTimeLimit {
		doc "The complete measurement cycle shall complete within 60 seconds.";
		attribute maxDuration : Duration = 60 [s];
	}
}
