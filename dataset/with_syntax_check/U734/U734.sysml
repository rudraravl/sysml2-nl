package IonSelectiveElectrodeSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def IonConcentration :> Real {
		doc /* Concentration of target ions in solution, measured in mol/L */
	}
	
	attribute def ElectricPotential :> Real {
		doc /* Electric potential difference in millivolts */
	}
	
	attribute def Temperature :> Real {
		doc /* Temperature in Kelvin affecting electrode response */
	}
	
	attribute def SelectivityCoefficient :> Real {
		doc /* Ratio describing electrode preference for target ion over interfering ions */
	}
	
	item def SolutionSample {
		attribute targetIonConcentration : IonConcentration;
		attribute temperature : Temperature;
		attribute pH : Real;
		attribute interferingIonConcentration : IonConcentration;
	}
	
	item def PotentialMeasurement {
		attribute voltage : ElectricPotential;
		attribute timestamp : Real;
		attribute stability : Real;
	}
	
	item def ConcentrationResult {
		attribute measuredConcentration : IonConcentration;
		attribute uncertainty : Real;
		attribute valid : Boolean;
	}
	
	item def CalibrationParameters {
		attribute slope : Real;
		attribute intercept : Real;
		attribute standardConcentration : IonConcentration;
		attribute calibrationTemperature : Temperature;
	}
	
	port def SolutionPort {
		in item sample : SolutionSample;
	}
	
	port def PotentialPort {
		out item measurement : PotentialMeasurement;
	}
	
	port def DataPort {
		out item result : ConcentrationResult;
	}
	
	port def CalibrationPort {
		in item parameters : CalibrationParameters;
	}
	
	part def SelectiveMembrane {
		doc /* Ion-selective membrane that generates potential based on ion activity */
		
		attribute membraneType : String;
		attribute selectivity : SelectivityCoefficient;
		attribute resistance : Real;
		
		port solutionInterface : SolutionPort;
		port potentialOutput : PotentialPort;
		
		action def GenerateMembranePotential {
			in sampleConcentration : IonConcentration;
			in sampleTemperature : Temperature;
			in membraneSelectivity : SelectivityCoefficient;
			out membranePotential : ElectricPotential;
		}
		
		perform action generatePotential : GenerateMembranePotential;
	}
	
	part def InternalReference {
		doc /* Internal filling solution with known ion concentration */
		
		attribute fillingSolutionConcentration : IonConcentration;
		attribute composition : String;
	}
	
	part def ReferenceElectrode {
		doc /* Provides stable reference potential for measurement */
		
		attribute referencePotential : ElectricPotential;
		attribute electrodeType : String;
		
		port solutionInterface : SolutionPort;
		
		action def ProvideStableReference {
			out stablePotential : ElectricPotential;
		}
		
		perform action provideReference : ProvideStableReference;
	}
	
	part def PotentialMeter {
		doc /* High-impedance voltmeter measuring potential difference */
		
		attribute inputImpedance : Real;
		attribute resolution : Real;
		
		action def MeasurePotentialDifference {
			in membranePotential : ElectricPotential;
			in referencePotential : ElectricPotential;
			out potentialDifference : ElectricPotential;
		}
		
		perform action measureDifference : MeasurePotentialDifference;
	}
	
	part def SignalProcessor {
		doc /* Processes and conditions the measured potential signal */
		
		attribute filterCutoff : Real;
		attribute samplingRate : Real;
		
		action def FilterAndAmplify {
			in rawPotential : ElectricPotential;
			out processedPotential : ElectricPotential;
		}
		
		perform action processSignal : FilterAndAmplify;
	}
	
	part def ConcentrationCalculator {
		doc /* Converts measured potential to ion concentration using Nernst equation */
		
		attribute nernstSlope : Real;
		attribute calibrationIntercept : Real;
		
		action def ApplyNernstEquation {
			in measuredPotential : ElectricPotential;
			in temperature : Temperature;
			in slope : Real;
			in intercept : Real;
			out concentration : IonConcentration;
		}
		
		perform action calculateConcentration : ApplyNernstEquation;
	}
	
	state def ElectrodeSystemStates {
		entry; then initialization;
		
		state initialization {
			doc /* System initializing and performing self-check */
		}
		
		transition initialization_to_calibration
			first initialization
			accept CalibrationRequestEvent
			then calibration;
		
		state calibration {
			doc /* System being calibrated with standard solutions */
			entry action performCalibration;
		}
		
		transition calibration_to_ready
			first calibration
			accept CalibrationCompleteEvent
			then ready;
		
		state ready {
			doc /* System calibrated and ready for measurement */
		}
		
		transition ready_to_measuring
			first ready
			accept MeasurementStartEvent
			then measuring;
		
		state measuring {
			doc /* Actively measuring ion concentration in sample */
			entry action startMeasurement;
			do action continuousMeasurement;
		}
		
		transition measuring_to_stabilizing
			first measuring
			accept StabilizationNeededEvent
			then stabilizing;
		
		state stabilizing {
			doc /* Waiting for potential to stabilize */
			do action monitorStability;
		}
		
		transition stabilizing_to_measuring
			first stabilizing
			accept StabilizedEvent
			then measuring;
		
		transition measuring_to_ready
			first measuring
			accept MeasurementCompleteEvent
			then ready;
		
		transition measuring_to_maintenance
			first measuring
			accept DriftDetectedEvent
			then maintenance;
		
		transition ready_to_maintenance
			first ready
			accept MaintenanceRequestEvent
			then maintenance;
		
		state maintenance {
			doc /* System requires recalibration or cleaning */
		}
		
		transition maintenance_to_initialization
			first maintenance
			accept MaintenanceCompleteEvent
			then initialization;
	}
	
	action def CalibrationRequestEvent;
	action def CalibrationCompleteEvent;
	action def MeasurementStartEvent;
	action def MeasurementCompleteEvent;
	action def StabilizationNeededEvent;
	action def StabilizedEvent;
	action def DriftDetectedEvent;
	action def MaintenanceRequestEvent;
	action def MaintenanceCompleteEvent;
	
	part def IonSelectiveElectrodeAssembly {
		doc /* 
		Complete ion-selective electrode assembly combining sensing membrane,
		internal reference, and reference electrode for potentiometric measurement
		*/
		
		port sampleInput : SolutionPort;
		port measurementOutput : DataPort;
		port calibrationInput : CalibrationPort;
		
		part sensingMembrane : SelectiveMembrane {
			port :>> solutionInterface;
		}
		
		part internalFilling : InternalReference;
		
		part referenceCell : ReferenceElectrode {
			port :>> solutionInterface;
		}
		
		part voltmeter : PotentialMeter;
		
		part signalConditioner : SignalProcessor;
		
		part calculator : ConcentrationCalculator;
		
		state systemState : ElectrodeSystemStates;
		
		connect sampleInput to sensingMembrane.solutionInterface;
		connect sampleInput to referenceCell.solutionInterface;
		
		perform action measureIonConcentration : MeasureIonConcentration;
	}
	
	action def MeasureIonConcentration {
		doc /* 
		Primary function: Measure the concentration of specific ions in solution
		by generating a potential difference proportional to the logarithm of
		ion activity, then converting this potential to concentration using
		the Nernst equation and calibration parameters.
		*/
		
		first start;
		
		then action immerseSample {
			doc /* Immerse electrode assembly in sample solution */
			in sample : SolutionSample;
		}
		
		then action equilibrateMembrane {
			doc /* Allow membrane to equilibrate with sample ions */
			in ionConcentration : IonConcentration;
			in temperature : Temperature;
		}
		
		then action developPotential {
			doc /* Selective membrane develops potential based on ion activity */
			in ionActivity : IonConcentration;
			in membraneSelectivity : SelectivityCoefficient;
			in temperature : Temperature;
			out membranePotential : ElectricPotential;
		}
		
		then action measureAgainstReference {
			doc /* Measure potential difference between sensing and reference electrodes */
			in sensePotential : ElectricPotential;
			in referencePotential : ElectricPotential;
			out potentialDifference : ElectricPotential;
		}
		
		then action processSignal {
			doc /* Filter and condition the measured potential signal */
			in rawPotential : ElectricPotential;
			out conditionedPotential : ElectricPotential;
		}
		
		then action checkStability {
			doc /* Verify potential has stabilized before conversion */
			in potential : ElectricPotential;
			out isStable : Boolean;
		}
		
		then decide;
			if checkStability.isStable then convertToConcentration;
			if not checkStability.isStable then equilibrateMembrane;
		
		action convertToConcentration {
			doc /* Apply Nernst equation to convert potential to concentration */
			in measuredPotential : ElectricPotential;
			in calibrationSlope : Real;
			in calibrationIntercept : Real;
			in sampleTemperature : Temperature;
			out ionConcentration : IonConcentration;
		}
		
		then action validateResult {
			doc /* Validate measurement is within acceptable range */
			in concentration : IonConcentration;
			out validatedResult : ConcentrationResult;
		}
		
		then action outputConcentration {
			doc /* Output the measured ion concentration */
			in result : ConcentrationResult;
		}
		
		then done;
	}
	
	requirement def AccuracyRequirement {
		doc /* Electrode shall measure ion concentration with specified accuracy */
		
		subject electrode : IonSelectiveElectrodeAssembly;
		
		require constraint accuracyLimit {
			doc /* Measurement error shall be within ±2% of true concentration over operating range */
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* Electrode shall respond to concentration changes within specified time */
		
		subject electrode : IonSelectiveElectrodeAssembly;
		
		require constraint responseTimeLimit {
			doc /* Electrode shall reach 95% of final reading within 60 seconds */
		}
	}
	
	requirement def SelectivityRequirement {
		doc /* Electrode shall be selective to target ion over interfering species */
		
		subject membrane : SelectiveMembrane;
		
		require constraint selectivityCoefficient {
			doc /* Selectivity coefficient for major interfering ions shall be less than 0.01 */
		}
	}
	
	requirement def StabilityRequirement {
		doc /* Electrode potential shall remain stable during measurement */
		
		subject electrode : IonSelectiveElectrodeAssembly;
		
		require constraint potentialDrift {
			doc /* Potential drift shall be less than 0.5 mV per hour after equilibration */
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* Electrode shall operate over specified concentration range */
		
		subject electrode : IonSelectiveElectrodeAssembly;
		
		require constraint concentrationRange {
			doc /* Linear response shall be maintained from 1E-6 to 1E-1 mol/L */
		}
	}
	
	requirement ionElectrodeSystemRequirements {
		doc /* Top-level requirements for ion-selective electrode measurement system */
		
		require accuracyReq : AccuracyRequirement;
		require responseTimeReq : ResponseTimeRequirement;
		require selectivityReq : SelectivityRequirement;
		require stabilityReq : StabilityRequirement;
		require operatingRangeReq : OperatingRangeRequirement;
	}
	
	part ionSelectiveElectrodeSystem : IonSelectiveElectrodeAssembly {
		doc /* 
		Ion-selective electrode system for potentiometric determination of specific
		ion concentrations in aqueous solutions. The system generates an electric
		potential proportional to the logarithm of ion activity through a selective
		membrane, measures this potential against a stable reference, and converts
		the measurement to ion concentration using the Nernst equation.
		*/
		
		satisfy ionElectrodeSystemRequirements;
	}
}
