package 'Matibabu Diagnostic System' {
	import ScalarValues::*;

	attribute def PowerOnSignal;
	attribute def StartTestSignal;
	attribute def FingerPositionedSignal;
	attribute def ScanCompleteSignal;
	attribute def AnalysisCompleteSignal;

	enum def MalariaType {
		falciparum;
		vivax;
		none;
		unknown;
	}

	enum def TestResult {
		positive;
		negative;
		inconclusive;
	}

	part def Finger;

	item def Light {
		attribute wavelength : Real;
	}

	item def OpticalData;
	item def MagneticData;

	part def DiagnosticReport {
		attribute result : TestResult;
		attribute parasiteType : MalariaType;
		attribute timestamp : String;
	}

	part def LEDEmitter {
		out port lightOut : Light;
	}

	part def PhotodetectorArray {
		in port lightIn : Light;
		out port opticalDataOut : OpticalData;
	}

	part def MagnetometerSensor {
		out port magneticDataOut : MagneticData;
	}

	part def SensingProbe {
		in port fingerIn : Finger;
		out port opticalDataOut : OpticalData;
		out port magneticDataOut : MagneticData;

		part led : LEDEmitter;
		part photodetector : PhotodetectorArray;
		part magnetometer : MagnetometerSensor;

		flow from led.lightOut to photodetector.lightIn;
		flow from photodetector.opticalDataOut to opticalDataOut;
		flow from magnetometer.magneticDataOut to magneticDataOut;
	}

	part def SignalProcessor {
		in port opticalIn : OpticalData;
		in port magneticIn : MagneticData;
		out port reportOut : DiagnosticReport;

		action def AnalyzeData {
			in optical : OpticalData;
			in magnetic : MagneticData;
			out report : DiagnosticReport;
		}
	}

	part def DisplayModule {
		in port reportIn : DiagnosticReport;
	}

	part def Battery {
		attribute capacity : Real;
	}

	action def RunDiagnosis {
		in item finger;
		out item report;
	}

	part def MatibabuDevice {
		part battery : Battery;
		part probe : SensingProbe;
		part processor : SignalProcessor;
		part display : DisplayModule;

		flow from probe.opticalDataOut to processor.opticalIn;
		flow from probe.magneticDataOut to processor.magneticIn;
		flow from processor.reportOut to display.reportIn;

		state def DeviceStates {
			entry; then off;
			state off;
			accept PowerOnSignal then ready;
			state ready;
			accept StartTestSignal then positioning;
			state positioning;
			accept FingerPositionedSignal then scanning;
			state scanning;
			accept ScanCompleteSignal then analyzing;
			state analyzing;
			accept AnalysisCompleteSignal then displaying;
			state displaying;
			accept PowerOnSignal then off;
		}

		action runDiagnosis : RunDiagnosis {
			in item finger;
			out item report;

			action positionFinger {
				in item finger;
				out item positionedFinger;
			}
			action scan {
				in item positionedFinger;
				out item opticalData;
				out item magneticData;
			}
			action analyze {
				in item opticalData;
				in item magneticData;
				out item report;
			}
			action displayResult {
				in item report;
			}

			flow from positionFinger.positionedFinger to scan.positionedFinger;
			flow from scan.opticalData to analyze.opticalData;
			flow from scan.magneticData to analyze.magneticData;
			flow from analyze.report to displayResult.report;
			flow from analyze.report to runDiagnosis::report;
		}
	}

	requirement def DiagnosisTimeRequirement {
		doc /* The device shall complete a full diagnosis in under two minutes. */
		attribute duration : Real;
		constraint { duration <= 120 }
	}

	requirement def NonInvasiveRequirement {
		doc /* The device shall perform diagnosis without drawing blood. */
	}

	requirement matibabuDiagnosisTime : DiagnosisTimeRequirement;
	requirement matibabuNonInvasive : NonInvasiveRequirement;
}
