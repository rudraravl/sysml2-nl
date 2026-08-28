package 'Dew Warning System' {
	private import ScalarValues::*;

	attribute def TemperatureValue : Real;

	enum def RiskLevel {
		safe;
		caution;
		warning;
		critical;
	}

	item def AmbientData {
		attribute temp : TemperatureValue;
		attribute humidity : Real;
	}
	item def SurfaceData {
		attribute temp : TemperatureValue;
	}
	item def DewPointData {
		attribute dewPoint : TemperatureValue;
	}
	item def RiskAssessment {
		attribute level : RiskLevel;
		attribute alertText : String;
	}
	item def AlertMessage {
		attribute level : RiskLevel;
		attribute text : String;
	}

	port def AmbientDataPort {
		out item ambientData : AmbientData;
	}
	port def SurfaceDataPort {
		out item surfaceData : SurfaceData;
	}
	port def DewPointDataPort {
		out item dewPointData : DewPointData;
	}
	port def RiskAssessmentPort {
		out item riskAssessment : RiskAssessment;
	}
	port def AlertOutPort {
		out item alertMessage : AlertMessage;
	}
	port def AlertInPort {
		in item alertMessage : AlertMessage;
	}

	action def SenseAmbient {
		out ambientData : AmbientData;
	}
	action def SenseSurface {
		out surfaceData : SurfaceData;
	}
	action def CalculateDewPoint {
		in ambientData : AmbientData;
		out dewPointData : DewPointData;
	}
	action def GenerateAlert {
		in riskAssessment : RiskAssessment;
		out alertMessage : AlertMessage;
	}
	action def DisplayAlert {
		in alertMessage : AlertMessage;
	}

	part def AmbientSensor {
		port ambientOut : AmbientDataPort;
		perform action senseAmbient : SenseAmbient {
			out ambientData = ambientOut.ambientData;
		}
	}

	part def SurfaceSensor {
		port surfaceOut : SurfaceDataPort;
		perform action senseSurface : SenseSurface {
			out surfaceData = surfaceOut.surfaceData;
		}
	}

	part def DewPointProcessor {
		port ambientIn : ~AmbientDataPort;
		port dewPointOut : DewPointDataPort;
		perform action calculateDewPoint : CalculateDewPoint {
			in ambientData = ambientIn.ambientData;
			out dewPointData = dewPointOut.dewPointData;
		}
	}

	part def RiskAnalyzer {
		port surfaceIn : ~SurfaceDataPort;
		port dewPointIn : ~DewPointDataPort;
		port riskOut : RiskAssessmentPort;

		attribute surfaceTemp : TemperatureValue = surfaceIn.surfaceData.temp;
		attribute dewPointTemp : TemperatureValue = dewPointIn.dewPointData.dewPoint;
		attribute tempDiff : Real = surfaceTemp - dewPointTemp;

		attribute cautionThreshold : Real = 5.0;
		attribute warningThreshold : Real = 2.0;
		attribute criticalThreshold : Real = 0.0;

		state def RiskStates;
		exhibit state riskStates : RiskStates {
			entry; then safe;
			state safe {
				entry do send new RiskAssessment() to riskOut;
			}
			accept when tempDiff <= cautionThreshold then caution;
			state caution {
				entry do send new RiskAssessment() to riskOut;
			}
			accept when tempDiff <= warningThreshold then warning;
			accept when tempDiff > cautionThreshold then safe;
			state warning {
				entry do send new RiskAssessment() to riskOut;
			}
			accept when tempDiff <= criticalThreshold then critical;
			accept when tempDiff > warningThreshold then caution;
			state critical {
				entry do send new RiskAssessment() to riskOut;
			}
			accept when tempDiff > criticalThreshold then warning;
		}
	}

	part def AlertGenerator {
		port riskIn : ~RiskAssessmentPort;
		port alertOut : AlertOutPort;
		perform action generateAlert : GenerateAlert {
			in riskAssessment = riskIn.riskAssessment;
			out alertMessage = alertOut.alertMessage;
		}
	}

	part def VisualIndicator {
		port alertIn : AlertInPort;
		attribute displayMessage : String = alertIn.alertMessage.text;
		perform action displayAlert : DisplayAlert {
			in alertMessage = alertIn.alertMessage;
		}
	}

	part def DewWarningSystem {
		part ambientSensor : AmbientSensor;
		part surfaceSensor : SurfaceSensor;
		part dewPointProcessor : DewPointProcessor;
		part riskAnalyzer : RiskAnalyzer;
		part alertGenerator : AlertGenerator;
		part visualIndicator : VisualIndicator;

		interface ambientInterface connect ambientSensor.ambientOut to dewPointProcessor.ambientIn {
			flow ambientFlow of AmbientData
				from ambientSensor.ambientOut.ambientData to dewPointProcessor.ambientIn.ambientData;
		}
		interface surfaceInterface connect surfaceSensor.surfaceOut to riskAnalyzer.surfaceIn {
			flow surfaceFlow of SurfaceData
				from surfaceSensor.surfaceOut.surfaceData to riskAnalyzer.surfaceIn.surfaceData;
		}
		interface dewPointInterface connect dewPointProcessor.dewPointOut to riskAnalyzer.dewPointIn {
			flow dewPointFlow of DewPointData
				from dewPointProcessor.dewPointOut.dewPointData to riskAnalyzer.dewPointIn.dewPointData;
		}
		interface riskInterface connect riskAnalyzer.riskOut to alertGenerator.riskIn {
			flow riskFlow of RiskAssessment
				from riskAnalyzer.riskOut.riskAssessment to alertGenerator.riskIn.riskAssessment;
		}
		interface alertInterface connect alertGenerator.alertOut to visualIndicator.alertIn {
			flow alertFlow of AlertMessage
				from alertGenerator.alertOut.alertMessage to visualIndicator.alertIn.alertMessage;
		}
	}

	part dewWarningSystem : DewWarningSystem;

	requirement def 'Dew Warning Requirement' {
		doc /* The system shall continuously monitor ambient temperature, relative humidity, and surface temperature, calculate the dew point, assess condensation risk on a four-tier scale (safe, caution, warning, critical), and display alerts to operators to prevent moisture damage to sensitive equipment, materials, or infrastructure. */
		subject : sys : DewWarningSystem;
		require sys.visualIndicator.displayMessage != "";
	}

	requirement dewWarningRequirement : 'Dew Warning Requirement' {
		subject :>> sys = dewWarningSystem;
	}

	satisfy dewWarningRequirement by dewWarningSystem;
}
