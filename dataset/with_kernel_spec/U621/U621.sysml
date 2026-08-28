package 'Portable Digital Breathalyzer' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def BloodAlcoholConcentration :> Real;
	attribute def BreathAlcoholConcentration :> Real;

	enum def AlarmStatus {
		safe;
		warning;
		violation;
	}

	item def BreathSample {
		attribute alcoholConcentration : BreathAlcoholConcentration;
	}

	item def BACResult {
		attribute bacValue : BloodAlcoholConcentration;
		attribute status : AlarmStatus;
	}

	attribute def TestStartSignal;
	attribute def BreathDetectedSignal;
	attribute def SampleCapturedSignal;
	attribute def AnalysisCompleteSignal;
	attribute def ResetSignal;

	action def CaptureSample {
		out sample : BreathSample;
	}
	action def AnalyzeSample {
		in sample : BreathSample;
		out result : BACResult;
	}
	action def ShowResult {
		in result : BACResult;
	}
	action def TestSequence {
		action captureSample : CaptureSample;
		action analyzeSample : AnalyzeSample;
		action showResult : ShowResult;
	}

	state def ControlStates {
		entry; then idle;
		state idle;
		transition 'idle-to-ready'
			first idle
			accept TestStartSignal
			then ready;
		state ready;
		transition 'ready-to-sampling'
			first ready
			accept BreathDetectedSignal
			then sampling;
		state sampling;
		transition 'sampling-to-analyzing'
			first sampling
			accept SampleCapturedSignal
			then analyzing;
		state analyzing;
		transition 'analyzing-to-complete'
			first analyzing
			accept AnalysisCompleteSignal
			then complete;
		state complete;
		transition 'complete-to-idle-timeout'
			first complete
			accept after 10 [s]
			then idle;
		transition 'complete-to-idle-reset'
			first complete
			accept ResetSignal
			then idle;
	}

	part def BreathSensor {
		attribute sensitivity : Real;
		attribute calibrationOffset : Real;
		out port sampleOutput : BreathSample;
	}

	part def AnalysisModule {
		attribute conversionFactor : Real;
		attribute legalLimit : BloodAlcoholConcentration;
		attribute warningThreshold : BloodAlcoholConcentration;
		in port sampleInput : BreathSample;
		out port resultOutput : BACResult;
	}

	part def DisplayUnit {
		in port resultInput : BACResult;
		attribute alarmEnabled : Boolean;
	}

	part def ControlUnit {
		exhibit state controlStates : ControlStates;
	}

	part def PowerSupply {
		attribute capacity : Real;
		attribute voltage : Real;
	}

	part def Breathalyzer {
		attribute legalLimit : BloodAlcoholConcentration;
		attribute warningThreshold : BloodAlcoholConcentration;
	}

	part breathalyzer : Breathalyzer {
		perform action runTest : TestSequence;
		part sensor : BreathSensor {
			perform runTest.captureSample;
		}
		part analyzer : AnalysisModule {
			perform runTest.analyzeSample;
		}
		part display : DisplayUnit {
			perform runTest.showResult;
		}
		part controller : ControlUnit;
		part power : PowerSupply;

		connect sensor.sampleOutput to analyzer.sampleInput;
		connect analyzer.resultOutput to display.resultInput;
	}

	requirement def MeasureBAC {
		doc /* The breathalyzer shall measure a person's Blood Alcohol Concentration by analyzing a breath sample. */
		subject breathalyzer : Breathalyzer;
	}

	requirement def DetermineLegalViolation {
		doc /* The system shall determine if an individual's alcohol level is above the legal limit by comparing the calculated BAC against a pre-set legal limit. */
		subject breathalyzer : Breathalyzer;
		attribute legalLimit : BloodAlcoholConcentration;
	}

	requirement def DisplayAlarmStatus {
		doc /* The display unit shall show the BAC level and provide a color-coded alarm status: 'safe', 'warning', or 'violation'. */
		subject displayUnit : DisplayUnit;
	}

	requirement def ManageOperationStates {
		doc /* The control unit shall manage device states: idle, ready, sampling, analyzing, and complete. */
		subject controlUnit : ControlUnit;
	}

	requirement def PowerByBattery {
		doc /* The device shall be powered by an internal power supply (battery). */
		subject powerSupply : PowerSupply;
	}

	requirement measureBACReq : MeasureBAC;
	requirement determineLegalViolationReq : DetermineLegalViolation;
	requirement displayAlarmStatusReq : DisplayAlarmStatus;
	requirement manageOperationStatesReq : ManageOperationStates;
	requirement powerByBatteryReq : PowerByBattery;

	satisfy measureBACReq by breathalyzer;
	satisfy determineLegalViolationReq by breathalyzer.analyzer;
	satisfy displayAlarmStatusReq by breathalyzer.display;
	satisfy manageOperationStatesReq by breathalyzer.controller;
	satisfy powerByBatteryReq by breathalyzer.power;
}
