package 'Test Light System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def VoltageLevel :> ISQ::voltage;
	attribute def CurrentLevel :> ISQ::electricCurrent;
	attribute def ResistanceLevel :> ISQ::resistance;
	
	enum def IndicatorState {
		enum off;
		enum dim;
		enum bright;
	}
	
	item def ElectricalSignal {
		attribute voltage : VoltageLevel;
		attribute current : CurrentLevel;
	}
	
	item def CircuitStatus {
		attribute hasContinuity : Boolean;
		attribute voltagePresent : Boolean;
		attribute measuredVoltage : VoltageLevel;
	}
	
	port def ProbePort {
		in item inputSignal : ElectricalSignal;
		out item outputSignal : ElectricalSignal;
	}
	
	port def IndicatorPort {
		out attribute displayState : IndicatorState;
		out attribute brightness : Real;
	}
	
	part def MetalProbe {
		attribute conductivity : Real;
		attribute tipResistance : ResistanceLevel;
		port connection : ProbePort;
	}
	
	part def IncandescentLamp {
		attribute filamentResistance : ResistanceLevel;
		attribute ratedVoltage : VoltageLevel;
		attribute ratedCurrent : CurrentLevel;
		attribute currentBrightness : Real;
		attribute currentState : IndicatorState;
	}
	
	part def CurrentLimitingResistor {
		attribute resistance : ResistanceLevel;
		attribute powerRating : ISQ::power;
	}
	
	part def InsulatedHandle {
		attribute length : ISQ::length;
		attribute material : String;
	}
	
	part def WireLeads {
		attribute gauge : Integer;
		attribute wireLength : ISQ::length;
		attribute resistance : ResistanceLevel;
	}
	
	part def TestLightAssembly {
		part positiveProbe : MetalProbe {
			attribute :>> tipResistance = 0.01[SI::Ω];
		}
		
		part negativeProbe : MetalProbe {
			attribute :>> tipResistance = 0.01[SI::Ω];
		}
		
		part indicator : IncandescentLamp {
			attribute :>> filamentResistance = 10.0[SI::Ω];
			attribute :>> ratedVoltage = 12.0[SI::V];
			attribute :>> ratedCurrent = 1.2[SI::A];
		}
		
		part protectionResistor : CurrentLimitingResistor {
			attribute :>> resistance = 5.0[SI::Ω];
			attribute :>> powerRating = 5.0[SI::W];
		}
		
		part handle : InsulatedHandle {
			attribute :>> length = 150.0[SI::mm];
			attribute :>> material = "rubber";
		}
		
		part wiring : WireLeads {
			attribute :>> gauge = 18;
			attribute :>> wireLength = 1.0[SI::m];
			attribute :>> resistance = 0.02[SI::Ω];
		}
		
		port positiveConnection : ProbePort;
		port negativeConnection : ProbePort;
		port indicatorDisplay : IndicatorPort;
		
		connect positiveProbe.connection to positiveConnection;
		connect negativeProbe.connection to negativeConnection;
		
		perform action testOperation[*] ordered;
	}
	
	action def MeasureVoltage {
		in probeASignal : ElectricalSignal;
		in probeBSignal : ElectricalSignal;
		out voltageDifference : VoltageLevel;
		out isVoltagePresent : Boolean;
	}
	
	action def EvaluateContinuity {
		in appliedVoltage : VoltageLevel;
		in measuredCurrent : CurrentLevel;
		out continuityDetected : Boolean;
		out circuitResistance : ResistanceLevel;
	}
	
	action def DetermineIndicatorLevel {
		in circuitVoltage : VoltageLevel;
		in circuitCurrent : CurrentLevel;
		out indicatorState : IndicatorState;
		out brightnessLevel : Real;
	}
	
	action def UpdateDisplay {
		in targetState : IndicatorState;
		in targetBrightness : Real;
	}
	
	action def ExecuteCircuitTest {
		first start;
		
		then action captureProbeSignals {
			out probeAData : ElectricalSignal;
			out probeBData : ElectricalSignal;
		}
		
		then action measureVoltage : MeasureVoltage {
			in probeASignal = captureProbeSignals.probeAData;
			in probeBSignal = captureProbeSignals.probeBData;
			out voltageDifference;
			out isVoltagePresent;
		}
		
		then decide;
			if measureVoltage.isVoltagePresent then evaluateCircuit;
			if not measureVoltage.isVoltagePresent then indicateNoVoltage;
		
		action evaluateCircuit : EvaluateContinuity {
			in appliedVoltage = measureVoltage.voltageDifference;
			in measuredCurrent;
			out continuityDetected;
			out circuitResistance;
		}
		then decideOnContinuity;
		
		decide decideOnContinuity;
			if evaluateCircuit.continuityDetected then calculateBrightness;
			if not evaluateCircuit.continuityDetected then indicateOpenCircuit;
		
		action calculateBrightness : DetermineIndicatorLevel {
			in circuitVoltage = measureVoltage.voltageDifference;
			in circuitCurrent = evaluateCircuit.measuredCurrent;
			out indicatorState;
			out brightnessLevel;
		}
		then displayResult;
		
		action displayResult : UpdateDisplay {
			in targetState = calculateBrightness.indicatorState;
			in targetBrightness = calculateBrightness.brightnessLevel;
		}
		then reportStatus;
		
		action indicateNoVoltage : UpdateDisplay {
			in targetState = IndicatorState::off;
			in targetBrightness = 0.0;
		}
		then reportStatus;
		
		action indicateOpenCircuit : UpdateDisplay {
			in targetState = IndicatorState::off;
			in targetBrightness = 0.0;
		}
		then reportStatus;
		
		action reportStatus {
			out status : CircuitStatus;
		}
		then done;
	}
	
	state def TestLightBehavior {
		entry; then inactive;
		
		state inactive {
			entry assign lampState = IndicatorState::off;
			entry assign lampBrightness = 0.0;
		}
		accept at inactive then probing
			when ProbesAppliedToCircuit;
		
		state probing {
			do action testExecution : ExecuteCircuitTest;
		}
		accept at probing then illuminating
			when testExecution.calculateBrightness.brightnessLevel > 0.0;
		accept at probing then inactive
			when testExecution.calculateBrightness.brightnessLevel == 0.0;
		
		state illuminating {
			entry assign lampState = IndicatorState::bright;
			entry assign lampBrightness = 1.0;
		}
		accept at illuminating then dimming
			when VoltageDropDetected;
		accept at illuminating then inactive
			when ProbesRemovedFromCircuit;
		
		state dimming {
			entry assign lampState = IndicatorState::dim;
			entry assign lampBrightness = 0.5;
		}
		accept at dimming then illuminating
			when VoltageRestored;
		accept at dimming then inactive
			when ProbesRemovedFromCircuit;
		
		attribute lampState : IndicatorState;
		attribute lampBrightness : Real;
	}
	
	part testLightSystem : TestLightAssembly {
		perform action testOperation : ExecuteCircuitTest;
		exhibit state operatingBehavior : TestLightBehavior;
	}
	
	requirement def VoltageRangeRequirement {
		doc /* The test light shall operate correctly within a specified voltage range. */
		subject device : TestLightAssembly;
		require constraint voltageWithinLimits {
			device.indicator.ratedVoltage >= 6.0[SI::V] and 
			device.indicator.ratedVoltage <= 24.0[SI::V]
		}
	}
	
	requirement def ContinuityDetectionRequirement {
		doc /* The test light shall detect circuit continuity by allowing current flow. */
		subject device : TestLightAssembly;
	}
	
	requirement def VisualIndicationRequirement {
		doc /* The test light shall provide clear visual indication of circuit status. */
		subject device : TestLightAssembly;
		require constraint indicatorVisible {
			device.indicator.currentBrightness > 0.0
		}
	}
	
	requirement def SafetyRequirement {
		doc /* The test light shall provide electrical isolation through insulated handle. */
		subject device : TestLightAssembly;
		require constraint handleInsulated {
			device.handle.material == "rubber"
		}
	}
	
	requirement <'TL-REQ-001'> voltageOperation : VoltageRangeRequirement {
		subject device = testLightSystem;
	}
	
	requirement <'TL-REQ-002'> continuityDetection : ContinuityDetectionRequirement {
		subject device = testLightSystem;
	}
	
	requirement <'TL-REQ-003'> visualFeedback : VisualIndicationRequirement {
		subject device = testLightSystem;
	}
	
	requirement <'TL-REQ-004'> userSafety : SafetyRequirement {
		subject device = testLightSystem;
	}
	
	requirement <'TL-PRIMARY'> primarySystemFunction {
		doc /* 
			The test light system shall detect and visually indicate the presence of 
			electrical voltage and circuit continuity in automotive and electrical circuits 
			by illuminating an indicator lamp when a complete circuit path exists between 
			its two probes and sufficient voltage is present.
		*/
		
		assume constraint probesInContact {
			doc /* Both probes are in physical contact with the circuit under test. */
		}
		
		assume constraint voltageSourceAvailable {
			doc /* A voltage source is present in the circuit being tested. */
		}
		
		require voltageOperation;
		require continuityDetection;
		require visualFeedback;
		require userSafety;
	}
}
