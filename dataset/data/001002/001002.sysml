package 'Capacitive Sensing System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def CapacitanceValue :> ISQ::CapacitanceValue;
	attribute def VoltageValue :> ISQ::ElectricPotentialValue;
	attribute def FrequencyValue :> ISQ::FrequencyValue;
	attribute def DistanceValue :> ISQ::LengthValue;
	attribute def TimeValue :> ISQ::TimeValue;
	attribute def SensitivityValue :> Real;
	attribute def ThresholdValue :> Real;
	
	attribute def TouchDetected;
	attribute def ProximityDetected;
	attribute def CalibrationCommand;
	attribute def MeasurementReady;
	
	item def ElectricalSignal {
		attribute voltage : VoltageValue;
		attribute frequency : FrequencyValue;
	}
	
	item def CapacitanceMeasurement {
		attribute value : CapacitanceValue;
		attribute timestamp : TimeValue;
		attribute valid : Boolean;
	}
	
	item def ProximityData {
		attribute distance : DistanceValue;
		attribute confidence : Real;
	}
	
	port def ExcitationPort {
		out signal : ElectricalSignal;
	}
	
	port def SensingPort {
		in responseSignal : ElectricalSignal;
		out rawCapacitance : CapacitanceValue;
	}
	
	port def DataPort {
		out measurement : CapacitanceMeasurement;
	}
	
	port def ControlPort {
		in calibrationCmd : CalibrationCommand;
		out status : MeasurementReady;
	}
	
	port def OutputPort {
		out touchEvent : TouchDetected;
		out proximityData : ProximityData;
	}
	
	part def SensingElectrode {
		attribute nominalCapacitance : CapacitanceValue;
		attribute electrodeArea : ISQ::AreaValue;
		port sensingInterface : SensingPort;
	}
	
	part def ExcitationGenerator {
		attribute outputVoltage : VoltageValue;
		attribute operatingFrequency : FrequencyValue;
		port excitationOutput : ExcitationPort;
		
		action def GenerateExcitation {
			in voltage : VoltageValue;
			in frequency : FrequencyValue;
			out excitationSignal : ElectricalSignal;
		}
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterCutoffFrequency : FrequencyValue;
		port signalInput : SensingPort;
		port conditionedOutput : DataPort;
		
		action def ConditionSignal {
			in rawSignal : ElectricalSignal;
			in gain : Real;
			out conditionedSignal : ElectricalSignal;
		}
	}
	
	part def CapacitanceConverter {
		attribute conversionFactor : Real;
		attribute resolution : CapacitanceValue;
		port analogInput : DataPort;
		port digitalOutput : DataPort;
		
		action def ConvertToCapacitance {
			in conditionedSignal : ElectricalSignal;
			in conversionFactor : Real;
			out capacitance : CapacitanceValue;
		}
	}
	
	part def ProcessingUnit {
		attribute baselineCapacitance : CapacitanceValue;
		attribute touchThreshold : ThresholdValue;
		attribute proximityThreshold : ThresholdValue;
		attribute calibrationData : CapacitanceValue[*];
		port measurementInput : DataPort;
		port controlInterface : ControlPort;
		port eventOutput : OutputPort;
		
		action def ProcessMeasurement {
			in measurement : CapacitanceMeasurement;
			in baseline : CapacitanceValue;
			in touchThreshold : ThresholdValue;
			in proximityThreshold : ThresholdValue;
			out deltaCapacitance : CapacitanceValue;
			out isTouched : Boolean;
			out proximityDistance : DistanceValue;
		}
		
		action def PerformCalibration {
			in samples : CapacitanceMeasurement[*];
			out newBaseline : CapacitanceValue;
			out calibrationSuccess : Boolean;
		}
	}
	
	part def PowerManagement {
		attribute supplyVoltage : VoltageValue;
		attribute currentConsumption : ISQ::ElectricCurrentValue;
		
		action def ManagePower {
			in operatingMode : String;
			out voltage : VoltageValue;
		}
	}
	
	action def MeasureCapacitance {
		in excitationVoltage : VoltageValue;
		in excitationFrequency : FrequencyValue;
		in nominalCapacitance : CapacitanceValue;
		out measuredCapacitance : CapacitanceValue;
		
		action generateExcitation : ExcitationGenerator::GenerateExcitation {
			in voltage = excitationVoltage;
			in frequency = excitationFrequency;
			out excitationSignal : ElectricalSignal;
		}
		
		action conditionSignal : SignalConditioner::ConditionSignal {
			in rawSignal : ElectricalSignal;
			in gain = 100.0;
			out conditionedSignal : ElectricalSignal;
		}
		
		action convertSignal : CapacitanceConverter::ConvertToCapacitance {
			in conditionedSignal : ElectricalSignal;
			in conversionFactor = 1.0e-12;
			out capacitance : CapacitanceValue;
		}
		
		flow generateExcitation.excitationSignal to conditionSignal.rawSignal;
		flow conditionSignal.conditionedSignal to convertSignal.conditionedSignal;
		flow convertSignal.capacitance to measuredCapacitance;
	}
	
	action def DetectTouchAndProximity {
		in currentCapacitance : CapacitanceValue;
		in baselineCapacitance : CapacitanceValue;
		in touchThreshold : ThresholdValue;
		in proximityThreshold : ThresholdValue;
		out touchDetected : Boolean;
		out proximityDistance : DistanceValue;
		
		first start;
		
		then action calculateDelta {
			attribute deltaC : CapacitanceValue;
		}
		
		then assign calculateDelta.deltaC := currentCapacitance - baselineCapacitance;
		
		then decide;
			if calculateDelta.deltaC >= touchThreshold then reportTouch;
			if calculateDelta.deltaC >= proximityThreshold and calculateDelta.deltaC < touchThreshold then reportProximity;
			if calculateDelta.deltaC < proximityThreshold then noDetection;
		
		action reportTouch {
			then assign touchDetected := true;
			then assign proximityDistance := 0.0[SI::mm];
		}
		
		action reportProximity {
			then assign touchDetected := false;
			action estimateDistance {
				in delta : CapacitanceValue;
				out distance : DistanceValue;
			}
			then assign proximityDistance := estimateDistance.distance;
		}
		
		action noDetection {
			then assign touchDetected := false;
			then assign proximityDistance := 100.0[SI::mm];
		}
		
		then done;
	}
	
	action def CapacitiveSensingOperation {
		in operatingVoltage : VoltageValue;
		in sensingFrequency : FrequencyValue;
		in nominalCap : CapacitanceValue;
		in touchThresh : ThresholdValue;
		in proximityThresh : ThresholdValue;
		out touchEvent : Boolean;
		out proximityInfo : ProximityData;
		
		first start;
		
		then action calibrate : ProcessingUnit::PerformCalibration {
			in samples : CapacitanceMeasurement[10];
			out newBaseline : CapacitanceValue;
			out calibrationSuccess : Boolean;
		}
		
		then merge continuousSensing;
		
		then action measure : MeasureCapacitance {
			in excitationVoltage = operatingVoltage;
			in excitationFrequency = sensingFrequency;
			in nominalCapacitance = nominalCap;
			out measuredCapacitance : CapacitanceValue;
		}
		
		flow measure.measuredCapacitance to detect.currentCapacitance;
		
		then action detect : DetectTouchAndProximity {
			in currentCapacitance : CapacitanceValue;
			in baselineCapacitance = calibrate.newBaseline;
			in touchThreshold = touchThresh;
			in proximityThreshold = proximityThresh;
			out touchDetected : Boolean;
			out proximityDistance : DistanceValue;
		}
		
		then assign touchEvent := detect.touchDetected;
		then assign proximityInfo.distance := detect.proximityDistance;
		then assign proximityInfo.confidence := 0.95;
		
		then continuousSensing;
	}
	
	state def SensingStateMachine {
		entry; then idle;
		
		state idle {
			doc /* System is powered but not actively sensing */
		}
		
		transition idle_to_calibrating
			first idle
			accept CalibrationCommand
			then calibrating;
		
		state calibrating {
			doc /* System is establishing baseline capacitance */
			entry action performCalibration : ProcessingUnit::PerformCalibration;
		}
		
		transition calibrating_to_monitoring
			first calibrating
			then monitoring;
		
		state monitoring {
			doc /* Continuous capacitance measurement and evaluation */
			entry action continuousMeasurement : MeasureCapacitance;
		}
		
		state touchActive {
			doc /* Touch event detected and being tracked */
			entry action trackTouch;
		}
		
		state proximityActive {
			doc /* Object in proximity range */
			entry action trackProximity;
		}
		
		transition monitoring_to_touchActive
			first monitoring
			accept TouchDetected
			then touchActive;
		
		transition monitoring_to_proximityActive
			first monitoring
			accept ProximityDetected
			then proximityActive;
		
		transition touchActive_to_monitoring
			first touchActive
			then monitoring;
		
		transition proximityActive_to_monitoring
			first proximityActive
			then monitoring;
		
		transition any_to_calibrating
			first monitoring or touchActive or proximityActive
			accept CalibrationCommand
			then calibrating;
	}
	
	part def CapacitiveSensingSystem {
		doc /*
		 * A capacitive sensing system that detects the presence, proximity, and touch
		 * of conductive objects by measuring variations in electrical capacitance.
		 * 
		 * The system operates by generating an electrical excitation signal applied to
		 * a sensing electrode. When a conductive object (such as a human finger) approaches
		 * or touches the electrode, it alters the electric field distribution, causing a
		 * measurable change in capacitance. The system continuously monitors these capacitance
		 * variations, processes the signals through conditioning and conversion stages, and
		 * determines both touch events and proximity distance based on calibrated thresholds.
		 * 
		 * Primary function: Detect and report touch and proximity events by measuring
		 * capacitance changes at a sensing electrode, enabling touchless user interfaces,
		 * presence detection, and interactive control surfaces for consumer electronics,
		 * automotive systems, and industrial applications.
		 */
		
		attribute operatingVoltage : VoltageValue = 3.3[SI::V];
		attribute sensingFrequency : FrequencyValue = 100000.0[SI::Hz];
		attribute touchThreshold : ThresholdValue = 5.0e-12;
		attribute proximityThreshold : ThresholdValue = 1.0e-12;
		
		part electrode : SensingElectrode {
			attribute :>> nominalCapacitance = 10.0e-12[SI::F];
			attribute :>> electrodeArea = 100.0[SI::mm2];
		}
		
		part excitationGen : ExcitationGenerator {
			attribute :>> outputVoltage = 3.3[SI::V];
			attribute :>> operatingFrequency = 100000.0[SI::Hz];
		}
		
		part signalConditioner : SignalConditioner {
			attribute :>> amplificationGain = 100.0;
			attribute :>> filterCutoffFrequency = 10000.0[SI::Hz];
		}
		
		part capConverter : CapacitanceConverter {
			attribute :>> conversionFactor = 1.0e-12;
			attribute :>> resolution = 0.01e-12[SI::F];
		}
		
		part processor : ProcessingUnit {
			attribute :>> baselineCapacitance = 10.0e-12[SI::F];
			attribute :>> touchThreshold = 5.0e-12;
			attribute :>> proximityThreshold = 1.0e-12;
		}
		
		part powerMgmt : PowerManagement {
			attribute :>> supplyVoltage = 3.3[SI::V];
			attribute :>> currentConsumption = 5.0e-3[SI::A];
		}
		
		connection excitationToElectrode connect 
			excitationGen.excitationOutput to electrode.sensingInterface;
		
		connection electrodeToConditioner connect 
			electrode.sensingInterface to signalConditioner.signalInput;
		
		connection conditionerToConverter connect 
			signalConditioner.conditionedOutput to capConverter.analogInput;
		
		connection converterToProcessor connect 
			capConverter.digitalOutput to processor.measurementInput;
		
		connection powerToExcitation connect 
			powerMgmt to excitationGen;
		
		connection powerToConditioner connect 
			powerMgmt to signalConditioner;
		
		connection powerToConverter connect 
			powerMgmt to capConverter;
		
		connection powerToProcessor connect 
			powerMgmt to processor;
		
		perform action sensingOperation : CapacitiveSensingOperation {
			in operatingVoltage = operatingVoltage;
			in sensingFrequency = sensingFrequency;
			in nominalCap = electrode.nominalCapacitance;
			in touchThresh = touchThreshold;
			in proximityThresh = proximityThreshold;
			out touchEvent : Boolean;
			out proximityInfo : ProximityData;
		}
		
		exhibit state sensingState : SensingStateMachine;
	}
	
	requirement <'CS-REQ-001'> primaryFunctionRequirement {
		doc /*
		 * The capacitive sensing system shall detect the presence and proximity of
		 * conductive objects by measuring variations in electrical capacitance at
		 * the sensing electrode and shall generate digital events indicating touch
		 * and proximity status with distance estimation.
		 */
		subject system : CapacitiveSensingSystem;
	}
	
	requirement <'CS-REQ-002'> sensingResolutionRequirement {
		doc /*
		 * The system shall measure capacitance changes with a resolution of at least
		 * 0.01 femtofarads to enable reliable detection of proximity and touch events.
		 */
		subject system : CapacitiveSensingSystem;
		require constraint {
			system.capConverter.resolution <= 0.01e-12[SI::F]
		}
	}
	
	requirement <'CS-REQ-003'> responseTimeRequirement {
		doc /*
		 * The system shall process and report touch events within 10 milliseconds
		 * of capacitance change detection to provide responsive user interaction.
		 */
		subject system : CapacitiveSensingSystem;
	}
	
	requirement <'CS-REQ-004'> calibrationRequirement {
		doc /*
		 * The system shall perform automatic baseline calibration to compensate for
		 * environmental variations in temperature, humidity, and electromagnetic interference.
		 */
		subject system : CapacitiveSensingSystem;
		require constraint {
			system.processor.calibrationData->size() >= 10
		}
	}
	
	requirement <'CS-REQ-005'> proximityRangeRequirement {
		doc /*
		 * The system shall detect object proximity within a range of 0 to 50 millimeters
		 * from the sensing electrode surface with distance estimation accuracy of ±5mm.
		 */
		subject system : CapacitiveSensingSystem;
	}
	
	requirement systemRequirement {
		doc /*
		 * The capacitive sensing system shall provide reliable touch and proximity
		 * detection for user interface applications through continuous capacitance
		 * monitoring, signal processing, and event generation.
		 */
		
		assume constraint operatingEnvironment {
			doc /* System operates within temperature range -20°C to +85°C and relative humidity 0-95% non-condensing. */
		}
		
		require primaryFunctionRequirement;
		require sensingResolutionRequirement;
		require responseTimeRequirement;
		require calibrationRequirement;
		require proximityRangeRequirement;
	}
	
	part capacitiveSensingSystemInstance : CapacitiveSensingSystem {
		satisfy systemRequirement;
	}
}
