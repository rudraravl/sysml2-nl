package 'PH Glass Electrode System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PHValue :> Real;
	attribute def CalibrationSlope :> Real;
	attribute def CalibrationIntercept :> Real;
	
	item def Solution {
		attribute hydrogenIonActivity : Real;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	item def CalibrationBuffer {
		attribute knownPH : PHValue;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	attribute def PrepareForCalibrationEvent;
	attribute def StartCalibrationEvent;
	attribute def CalibrationCompleteEvent;
	attribute def BeginMeasurementEvent;
	attribute def SignalStabilizedEvent;
	attribute def ReadingCompleteEvent;
	attribute def MaintenanceRequiredEvent;
	attribute def MaintenanceCompleteEvent;
	attribute def ElectrodeFaultEvent;
	
	port def SolutionPort {
		in item testSolution : Solution;
	}
	
	port def VoltagePort {
		out attribute voltage : ISQ::ElectricPotentialValue;
	}
	
	port def TemperaturePort {
		in attribute temp : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def DataPort {
		out attribute phReading : PHValue;
	}
	
	part def GlassMembrane {
		doc /* Ion-selective glass membrane that develops potential based on hydrogen ion activity */
		attribute membraneThickness : ISQ::LengthValue;
		attribute glassResistance : ISQ::ResistanceValue;
		port solutionInterface : SolutionPort;
		port potentialOutput : VoltagePort;
		
		action def GenerateMembranePotential {
			in externalActivity : Real;
			in internalActivity : Real;
			in temperature : ISQ::ThermodynamicTemperatureValue;
			out membranePotential : ISQ::ElectricPotentialValue;
		}
	}
	
	part def InternalReference {
		doc /* Internal buffer solution and reference element providing stable potential */
		attribute internalPH : PHValue;
		attribute internalActivity : Real;
		item bufferSolution : Solution;
		port internalContact : VoltagePort;
	}
	
	part def ReferenceElectrode {
		doc /* External reference electrode providing stable reference potential */
		attribute referencePotential : ISQ::ElectricPotentialValue;
		item electrolyteJunction;
		port solutionContact : SolutionPort;
		port referenceOutput : VoltagePort;
	}
	
	part def HighImpedanceAmplifier {
		doc /* High input impedance amplifier to measure glass electrode potential */
		attribute inputImpedance : ISQ::ResistanceValue;
		attribute gain : Real;
		port measuringInput : VoltagePort;
		port referenceInput : VoltagePort;
		port amplifiedOutput : VoltagePort;
		
		action def AmplifySignal {
			in measuringVoltage : ISQ::ElectricPotentialValue;
			in referenceVoltage : ISQ::ElectricPotentialValue;
			in amplifierGain : Real;
			out outputVoltage : ISQ::ElectricPotentialValue;
		}
	}
	
	part def TemperatureCompensator {
		doc /* Temperature sensor and compensation circuit for Nernstian response */
		attribute compensationFactor : Real;
		port tempSensor : TemperaturePort;
		port voltageInput : VoltagePort;
		port compensatedOutput : VoltagePort;
		
		action def CompensateTemperature {
			in rawVoltage : ISQ::ElectricPotentialValue;
			in temperature : ISQ::ThermodynamicTemperatureValue;
			in factor : Real;
			out compensatedVoltage : ISQ::ElectricPotentialValue;
		}
	}
	
	part def AnalogToDigitalConverter {
		doc /* ADC for digitizing compensated voltage signal */
		attribute resolution : Integer;
		attribute samplingRate : ISQ::FrequencyValue;
		port analogInput : VoltagePort;
		
		action def ConvertToDigital {
			in analogVoltage : ISQ::ElectricPotentialValue;
			in adcResolution : Integer;
			out digitalValue : Real;
		}
	}
	
	part def SignalProcessor {
		doc /* Microprocessor for calibration, calculation, and output */
		attribute calibrationSlope : CalibrationSlope;
		attribute calibrationIntercept : CalibrationIntercept;
		port dataInput;
		port phOutput : DataPort;
		
		action def CalculatePH {
			in digitalVoltage : Real;
			in slope : CalibrationSlope;
			in intercept : CalibrationIntercept;
			out phValue : PHValue;
		}
		
		action def StoreCalibration {
			in slope : CalibrationSlope;
			in intercept : CalibrationIntercept;
		}
	}
	
	part def PHGlassElectrodeSystem {
		doc /* Complete pH measurement system using glass electrode technology to determine hydrogen ion activity in solution */
		
		part glassSensor : GlassMembrane {
			:>> membraneThickness = 0.05[SI::mm];
			:>> glassResistance = 100.0e6[SI::Ω];
		}
		
		part internalRef : InternalReference {
			:>> internalPH = 7.0;
			:>> internalActivity = 1.0e-7;
		}
		
		part externalRef : ReferenceElectrode {
			:>> referencePotential = 0.0[SI::V];
		}
		
		part amplifier : HighImpedanceAmplifier {
			:>> inputImpedance = 1.0e12[SI::Ω];
			:>> gain = 1.0;
		}
		
		part tempComp : TemperatureCompensator {
			:>> compensationFactor = 0.0592;
		}
		
		part adc : AnalogToDigitalConverter {
			:>> resolution = 24;
			:>> samplingRate = 10.0[SI::Hz];
		}
		
		part processor : SignalProcessor {
			:>> calibrationSlope = -59.16;
			:>> calibrationIntercept = 7.0;
		}
		
		port sampleInput : SolutionPort;
		port temperatureInput : TemperaturePort;
		port measurementOutput : DataPort;
		
		connect glassSensor.solutionInterface to sampleInput;
		connect externalRef.solutionContact to sampleInput;
		connect glassSensor.potentialOutput to amplifier.measuringInput;
		connect externalRef.referenceOutput to amplifier.referenceInput;
		connect amplifier.amplifiedOutput to tempComp.voltageInput;
		connect temperatureInput to tempComp.tempSensor;
		connect tempComp.compensatedOutput to adc.analogInput;
		connect processor.phOutput to measurementOutput;
	}
	
	action def CalibrateSensor {
		in buffer1 : CalibrationBuffer;
		in buffer2 : CalibrationBuffer;
		out slope : CalibrationSlope;
		out intercept : CalibrationIntercept;
		
		first start;
		
		then action measureBuffer1 {
			in calibrationBuffer : CalibrationBuffer;
			out voltage1 : ISQ::ElectricPotentialValue;
			out ph1 : PHValue;
		}
		
		then action rinse1 {
			doc /* Rinse electrode with deionized water */
		}
		
		then action measureBuffer2 {
			in calibrationBuffer : CalibrationBuffer;
			out voltage2 : ISQ::ElectricPotentialValue;
			out ph2 : PHValue;
		}
		
		then action computeCalibration {
			in v1 : ISQ::ElectricPotentialValue;
			in v2 : ISQ::ElectricPotentialValue;
			in p1 : PHValue;
			in p2 : PHValue;
			out calculatedSlope : CalibrationSlope;
			out calculatedIntercept : CalibrationIntercept;
		}
		
		then assign slope := computeCalibration.calculatedSlope;
		then assign intercept := computeCalibration.calculatedIntercept;
		
		then done;
	}
	
	action def MeasurePHValue {
		in testSample : Solution;
		in sensorSlope : CalibrationSlope;
		in sensorIntercept : CalibrationIntercept;
		out phResult : PHValue;
		
		first start;
		
		then action immerseSensor {
			in sample : Solution;
		}
		
		then action waitForStabilization {
			in stabilizationTime : ISQ::TimeValue;
		}
		
		then action acquireVoltage {
			in solution : Solution;
			out rawVoltage : ISQ::ElectricPotentialValue;
		}
		
		then action amplifyVoltage {
			in inputVoltage : ISQ::ElectricPotentialValue;
			out amplifiedVoltage : ISQ::ElectricPotentialValue;
		}
		
		then action compensateForTemperature {
			in voltage : ISQ::ElectricPotentialValue;
			in temperature : ISQ::ThermodynamicTemperatureValue;
			out compensatedVoltage : ISQ::ElectricPotentialValue;
		}
		
		then action digitizeSignal {
			in analogSignal : ISQ::ElectricPotentialValue;
			out digitalSignal : Real;
		}
		
		then action convertToPH {
			in digitalVoltage : Real;
			in slope : CalibrationSlope;
			in intercept : CalibrationIntercept;
			out phValue : PHValue;
		}
		
		then assign phResult := convertToPH.phValue;
		
		then action rinseSensor {
			doc /* Rinse electrode with deionized water */
		}
		
		then done;
	}
	
	action def PerformPHMeasurement {
		in sample : Solution;
		out finalPH : PHValue;
		
		first start;
		
		then action calibrate : CalibrateSensor {
			in buffer1 : CalibrationBuffer {
				:>> knownPH = 4.01;
				:>> temperature = 298.15[SI::K];
			}
			in buffer2 : CalibrationBuffer {
				:>> knownPH = 7.00;
				:>> temperature = 298.15[SI::K];
			}
			out slope;
			out intercept;
		}
		
		then action measure : MeasurePHValue {
			in testSample = sample;
			in sensorSlope = calibrate.slope;
			in sensorIntercept = calibrate.intercept;
			out phResult;
		}
		
		then assign finalPH := measure.phResult;
		
		then done;
	}
	
	state def ElectrodeOperationalState {
		entry; then storage;
		
		state storage {
			doc /* Electrode stored in storage solution to maintain hydration */
		}
		
		transition storage_to_preparation
			first storage
			accept prepareEvent : PrepareForCalibrationEvent
			then preparation;
		
		state preparation {
			doc /* Electrode rinsed and prepared for calibration */
		}
		
		transition preparation_to_calibration
			first preparation
			accept startEvent : StartCalibrationEvent
			then calibration;
		
		state calibration {
			doc /* Electrode being calibrated with standard buffer solutions */
			entry; then twoPointCalibration;
			
			state twoPointCalibration;
			
			transition calibration_complete
				first twoPointCalibration
				accept completeEvent : CalibrationCompleteEvent
				then ready;
		}
		
		state ready {
			doc /* Electrode calibrated and ready for measurement */
		}
		
		transition ready_to_measuring
			first ready
			accept beginEvent : BeginMeasurementEvent
			then measuring;
		
		state measuring {
			doc /* Electrode actively measuring pH of sample solution */
			entry; then stabilizing;
			
			state stabilizing {
				doc /* Waiting for electrode response to stabilize */
			}
			
			transition stabilizing_to_reading
				first stabilizing
				accept stabilizedEvent : SignalStabilizedEvent
				then reading;
			
			state reading {
				doc /* Acquiring stable pH reading */
			}
			
			transition reading_complete
				first reading
				accept readingEvent : ReadingCompleteEvent
				then ready;
		}
		
		transition ready_to_maintenance
			first ready
			accept maintReqEvent : MaintenanceRequiredEvent
			then maintenance;
		
		state maintenance {
			doc /* Electrode cleaning or reconditioning required */
		}
		
		transition maintenance_to_storage
			first maintenance
			accept maintCompleteEvent : MaintenanceCompleteEvent
			then storage;
		
		transition storage_to_fault
			first storage
			accept faultEvent : ElectrodeFaultEvent
			then fault;
		
		transition preparation_to_fault
			first preparation
			accept faultEvent : ElectrodeFaultEvent
			then fault;
		
		transition calibration_to_fault
			first calibration
			accept faultEvent : ElectrodeFaultEvent
			then fault;
		
		transition ready_to_fault
			first ready
			accept faultEvent : ElectrodeFaultEvent
			then fault;
		
		transition measuring_to_fault
			first measuring
			accept faultEvent : ElectrodeFaultEvent
			then fault;
		
		transition maintenance_to_fault
			first maintenance
			accept faultEvent : ElectrodeFaultEvent
			then fault;
		
		state fault {
			doc /* Electrode malfunction detected */
		}
	}
	
	part phMeasurementSystem : PHGlassElectrodeSystem {
		perform action measurementOperation : PerformPHMeasurement {
			in sample : Solution {
				:>> temperature = 298.15[SI::K];
			}
			out finalPH;
		}
		
		exhibit state operationalState : ElectrodeOperationalState;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The pH measurement system shall achieve specified accuracy across operating range */
		
		attribute requiredAccuracy : PHValue;
		attribute measuredValue : PHValue;
		attribute trueValue : PHValue;
		
		require constraint accuracyConstraint {
			(measuredValue - trueValue) <= requiredAccuracy and
			(trueValue - measuredValue) <= requiredAccuracy
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The electrode shall reach 95% of final reading within specified time */
		
		attribute maxResponseTime : ISQ::TimeValue;
		attribute actualResponseTime : ISQ::TimeValue;
		
		require constraint responseConstraint {
			actualResponseTime <= maxResponseTime
		}
	}
	
	requirement def OperatingRangeRequirement {
		doc /* The system shall operate within specified pH and temperature ranges */
		
		attribute minPH : PHValue;
		attribute maxPH : PHValue;
		attribute minTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
		
		require constraint rangeConstraint {
			minPH >= 0.0 and maxPH <= 14.0 and
			minTemperature >= 273.15[SI::K] and maxTemperature <= 373.15[SI::K]
		}
	}
	
	requirement def CalibrationStabilityRequirement {
		doc /* The calibration shall remain stable for specified duration */
		
		attribute calibrationDrift : PHValue;
		attribute maxDrift : PHValue;
		attribute driftPeriod : ISQ::TimeValue;
		
		require constraint stabilityConstraint {
			calibrationDrift <= maxDrift
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for pH glass electrode measurement system */
		
		requirement accuracyReq : MeasurementAccuracyRequirement {
			:>> requiredAccuracy = 0.02;
		}
		
		requirement responseReq : ResponseTimeRequirement {
			:>> maxResponseTime = 30.0[SI::s];
		}
		
		requirement rangeReq : OperatingRangeRequirement {
			:>> minPH = 0.0;
			:>> maxPH = 14.0;
			:>> minTemperature = 273.15[SI::K];
			:>> maxTemperature = 353.15[SI::K];
		}
		
		requirement stabilityReq : CalibrationStabilityRequirement {
			:>> maxDrift = 0.05;
			:>> driftPeriod = 86400.0[SI::s];
		}
	}
}
