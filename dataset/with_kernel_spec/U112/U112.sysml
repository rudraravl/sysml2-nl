package RightspotPHIndicator {

	private import ScalarValues::*;

	attribute def PH :> Real {
		doc
		/*
		 * pH value on the 0..14 scale.
		 */
	}
	attribute def Temperature :> Real {
		doc
		/*
		 * Fluid temperature in degrees Celsius.
		 */
	}
	attribute def Percent :> Real {
		doc
		/*
		 * Confidence score, 0..100.
		 */
	}

	enum def PlacementStatus {
		gastric;
		nonGastric;
		indeterminate;
	}

	item def AspirateSample {
		doc
		/*
		 * Fluid aspirate drawn from the feeding tube for pH verification.
		 */
	}

	item def RawSensorData {
		attribute rawPH : PH;
		attribute rawTemp : Temperature;
	}
	item def ProcessedData {
		attribute ph : PH;
		attribute temp : Temperature;
	}
	item def AnalysisResult {
		attribute ph : PH;
		attribute placement : PlacementStatus;
		attribute confidence : Percent;
	}

	attribute def SampleIntroduced {
		doc
		/*
		 * Trigger indicating a sample has been introduced into the device.
		 */
	}
	attribute def ResetSignal {
		doc
		/*
		 * Signal to reset the system to the idle state.
		 */
	}
	attribute def ErrorSignal {
		doc
		/*
		 * Signal indicating a malfunction during measurement or analysis.
		 */
	}
	attribute def PowerOff {
		doc
		/*
		 * Signal to shut down the device.
		 */
	}

	port def SamplePort {
		in item sample : AspirateSample;
	}
	port def RawDataOutPort {
		out item data : RawSensorData;
	}
	port def RawDataInPort {
		in item data : RawSensorData;
	}
	port def ProcessedOutPort {
		out item data : ProcessedData;
	}
	port def ProcessedInPort {
		in item data : ProcessedData;
	}
	port def ResultOutPort {
		out item result : AnalysisResult;
	}
	port def ResultInPort {
		in item result : AnalysisResult;
	}

	action def MeasurePH {
		in sample : AspirateSample;
		out rawData : RawSensorData;
	}
	action def ProcessSignal {
		in raw : RawSensorData;
		out processed : ProcessedData;
	}
	action def AnalyzePlacement {
		in data : ProcessedData;
		out result : AnalysisResult;
	}
	action def DisplayResult {
		in result : AnalysisResult;
	}

	part def PHSensorProbe {
		doc
		/*
		 * Electrochemical probe that directly interacts with the aspirate
		 * to measure raw pH and temperature.
		 */
		port sampleIn : SamplePort;
		port rawDataOut : RawDataOutPort;
		action measure : MeasurePH {
			in sample = sampleIn.sample;
			out rawData = rawDataOut.data;
		}
	}

	part def SignalProcessor {
		doc
		/*
		 * Receives raw sensor data and applies calibration formulas and
		 * temperature compensation to produce a corrected pH value.
		 */
		port rawDataIn : RawDataInPort;
		port processedOut : ProcessedOutPort;
		attribute calibrationOffset : PH = 0.0;
		attribute tempCoefficient : Real = -0.003;
		attribute referenceTemp : Temperature = 25.0;
		action process : ProcessSignal {
			in raw = rawDataIn.data;
			out processed = processedOut.data;
		}
	}

	part def PlacementAnalyzer {
		doc
		/*
		 * Interprets the corrected pH reading against a critical threshold
		 * (pH 5.5) to determine gastric, non-gastric, or indeterminate
		 * placement, and assigns a confidence level to the conclusion.
		 */
		port processedIn : ProcessedInPort;
		port resultOut : ResultOutPort;
		attribute gastricThreshold : PH = 5.5;
		action analyze : AnalyzePlacement {
			in data = processedIn.data;
			out result = resultOut.result;
		}
	}

	part def VisualDisplay {
		doc
		/*
		 * Presents the final results - pH value, placement status, and
		 * confidence score - to the healthcare professional.
		 */
		port resultIn : ResultInPort;
		action show : DisplayResult {
			in result = resultIn.result;
		}
	}

	part def ControlUnit {
		doc
		/*
		 * Central controller that manages the system's operational states,
		 * moving from idle to ready when a sample is introduced, through
		 * measuring and analysis phases, to displaying the result, and
		 * handling error conditions safely.
		 */
		port sampleIn : SamplePort;

		part probe : PHSensorProbe;
		part processor : SignalProcessor;
		part analyzer : PlacementAnalyzer;
		part display : VisualDisplay;

		connect sampleIn to probe.sampleIn;
		connect probe.rawDataOut to processor.rawDataIn;
		connect processor.processedOut to analyzer.processedIn;
		connect analyzer.resultOut to display.resultIn;

		state systemStates {
			entry; then idle;

			state idle;
			transition t_idle_ready
				first idle
				accept SampleIntroduced
				then ready;

			state ready;
			transition t_ready_measuring
				first ready
				then measuring;

			state measuring {
				do probe.measure;
			}
			transition t_measuring_processing
				first measuring
				then processing;

			state processing {
				do processor.process;
			}
			transition t_processing_analyzing
				first processing
				then analyzing;

			state analyzing {
				do analyzer.analyze;
			}
			transition t_analyzing_displaying
				first analyzing
				then displaying;

			state displaying {
				do display.show;
			}
			transition t_displaying_idle
				first displaying
				then idle;

			state error;
			transition t_measuring_error
				first measuring
				accept ErrorSignal
				then error;
			transition t_processing_error
				first processing
				accept ErrorSignal
				then error;
			transition t_analyzing_error
				first analyzing
				accept ErrorSignal
				then error;
			transition t_displaying_error
				first displaying
				accept ErrorSignal
				then error;
			transition t_error_idle
				first error
				accept ResetSignal
				then idle;

			transition t_power_off
				first idle
				accept PowerOff
				then done;
		}
	}

	requirement def VerifyTubePlacement {
		doc
		/*
		 * The system shall verify correct nasogastric feeding tube
		 * placement by measuring the pH of an aspirate sample.
		 */
	}

	requirement def PreventRespiratoryMisplacement {
		doc
		/*
		 * The system shall detect when the feeding tube is in the
		 * respiratory tract and report a non-gastric placement to
		 * prevent life-threatening complications.
		 */
	}

	requirement def MeasurePHRange {
		doc
		/*
		 * The pH sensor probe shall measure pH in the range 0 to 14.
		 */
	}

	requirement def GastricThresholdReq {
		doc
		/*
		 * A pH value of 5.5 or lower shall be classified as gastric
		 * (stomach) placement. Values above 5.5 shall be classified as
		 * non-gastric or indeterminate depending on the confidence score.
		 */
		attribute threshold : PH = 5.5;
	}

	requirement def DisplayResultsReq {
		doc
		/*
		 * The system shall display the precise pH value, the placement
		 * status, and the confidence score to the healthcare professional
		 * on a clear visual display.
		 */
	}

	requirement def HandleErrorsReq {
		doc
		/*
		 * The system shall enter an error state upon detecting a
		 * malfunction and shall allow reset to the idle state via a
		 * reset signal.
		 */
	}

	requirement def ResponseTimeReq {
		doc
		/*
		 * The system shall provide a placement result within 10 seconds
		 * of sample introduction.
		 */
		attribute maxSeconds : Real = 10;
	}

	requirement def ConfidenceThreshold {
		doc
		/*
		 * The placement analyzer shall assign a confidence score of at
		 * least 80 percent before reporting a definitive gastric or
		 * non-gastric result; otherwise the result shall be
		 * indeterminate.
		 */
		attribute minDefinitiveConfidence : Percent = 80;
	}

	requirement verifyTubePlacement : VerifyTubePlacement;
	requirement preventRespiratoryMisplacement : PreventRespiratoryMisplacement;
	requirement measurePHRange : MeasurePHRange;
	requirement gastricThresholdReq : GastricThresholdReq;
	requirement displayResultsReq : DisplayResultsReq;
	requirement handleErrorsReq : HandleErrorsReq;
	requirement responseTimeReq : ResponseTimeReq;
	requirement confidenceThreshold : ConfidenceThreshold;

	part def RightspotSystem :> ControlUnit {
		doc
		/*
		 * Rightspot pH Indicator system for verifying nasogastric
		 * feeding tube placement. A clinician introduces a fluid sample
		 * from the feeding tube, and within seconds the system provides
		 * a clear, data-backed confirmation of whether the tube is
		 * safely positioned in the stomach.
		 */
		satisfy verifyTubePlacement;
		satisfy preventRespiratoryMisplacement;
		satisfy measurePHRange;
		satisfy gastricThresholdReq;
		satisfy displayResultsReq;
		satisfy handleErrorsReq;
		satisfy responseTimeReq;
		satisfy confidenceThreshold;
	}

	part rightspotSystem : RightspotSystem;
}
