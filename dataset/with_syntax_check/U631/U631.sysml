package 'Catalytic Bead Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	comment about CatalyticBeadSensor
	/* This model describes a catalytic bead sensor system for detecting combustible gases.
	 * The sensor operates by measuring resistance changes in a heated platinum bead
	 * caused by catalytic oxidation of target gases. A Wheatstone bridge circuit
	 * converts resistance changes to voltage signals for processing. */
	
	attribute def ConcentrationUnit :> MeasurementUnit {
		attribute :>> unitConversion = null;
	}
	
	attribute def GasConcentrationValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ConcentrationUnit;
	}
	
	attribute gasConcentration : GasConcentrationValue :> scalarQuantities;
	
	item def CombustibleGas {
		attribute concentration : GasConcentrationValue;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
		attribute gasType : String;
	}
	
	item def ElectricalSignal {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
	}
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> MeasurementUnit;
	
	attribute def CurrentValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : CurrentUnit;
	}
	
	attribute def CurrentUnit :> MeasurementUnit;
	
	attribute def ResistanceValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ResistanceUnit;
	}
	
	attribute def ResistanceUnit :> MeasurementUnit;
	
	item def MeasurementData {
		attribute concentrationReading : GasConcentrationValue;
		attribute timestamp : TimeValue;
		attribute sensorTemperature : TemperatureValue;
		attribute signalVoltage : VoltageValue;
	}
	
	port def GasInletPort {
		in item gasSample : CombustibleGas;
	}
	
	port def PowerSupplyPort {
		in item power : ElectricalSignal;
	}
	
	port def AnalogOutputPort {
		out item signal : ElectricalSignal;
	}
	
	port def DataOutputPort {
		out item measurement : MeasurementData;
	}
	
	part def CatalyticBead {
		attribute beadTemperature : TemperatureValue;
		attribute resistance : ResistanceValue;
		attribute catalystMaterial : String default = "Platinum";
		attribute beadDiameter : LengthValue;
		attribute surfaceArea : AreaValue;
		attribute thermalMass : Real;
	}
	
	attribute def AreaValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : AreaUnit;
	}
	
	attribute def AreaUnit :> MeasurementUnit;
	
	part def ActiveBead :> CatalyticBead {
		comment about ActiveBead
		/* The active bead is exposed to the gas sample and undergoes
		 * catalytic oxidation when combustible gases are present,
		 * causing temperature and resistance changes. */
		
		attribute exposedToGas : Boolean default = true;
	}
	
	part def ReferenceBead :> CatalyticBead {
		comment about ReferenceBead
		/* The reference bead is sealed or poisoned to prevent catalytic
		 * reaction, providing a stable baseline for differential measurement
		 * and compensating for ambient temperature variations. */
		
		attribute exposedToGas : Boolean default = false;
	}
	
	part def FixedResistor {
		attribute resistance : ResistanceValue;
		attribute tolerance : Real;
		attribute powerRating : PowerValue;
	}
	
	attribute def PowerValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : PowerUnit;
	}
	
	attribute def PowerUnit :> MeasurementUnit;
	
	part def WheatstoneCircuit {
		attribute supplyVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute balanceCondition : Boolean;
		
		part activeLeg : ActiveBead;
		part referenceLeg : ReferenceBead;
		part resistor1 : FixedResistor;
		part resistor2 : FixedResistor;
		
		attribute :>> outputVoltage.num = supplyVoltage.num * 
			((activeLeg.resistance.num / (activeLeg.resistance.num + resistor1.resistance.num)) -
			(referenceLeg.resistance.num / (referenceLeg.resistance.num + resistor2.resistance.num)));
	}
	
	part def SignalAmplifier {
		attribute gain : Real;
		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute bandwidth : FrequencyValue;
		attribute inputImpedance : ResistanceValue;
		
		attribute :>> outputVoltage.num = inputVoltage.num * gain;
	}
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def FrequencyUnit :> MeasurementUnit;
	
	part def AnalogToDigitalConverter {
		attribute resolution : Integer;
		attribute samplingRate : FrequencyValue;
		attribute referenceVoltage : VoltageValue;
		attribute conversionTime : TimeValue;
	}
	
	attribute def TimeValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TimeUnit;
	}
	
	attribute def TimeUnit :> MeasurementUnit;
	
	part def SignalProcessor {
		attribute calibrationCoefficients : Real[*];
		attribute filterCutoffFrequency : FrequencyValue;
		attribute processingRate : FrequencyValue;
	}
	
	part def HeatingController {
		attribute targetTemperature : TemperatureValue;
		attribute heatingPower : PowerValue;
		attribute controlMode : String;
	}
	
	action def HeatBeads {
		in item powerInput : ElectricalSignal;
		in targetTemp : TemperatureValue;
		out activeBeadTemp : TemperatureValue;
		out referenceBeadTemp : TemperatureValue;
	}
	
	action def CatalyticReaction {
		in item gas : CombustibleGas;
		in beadTemp : TemperatureValue;
		out temperatureRise : TemperatureValue;
		out heatOfReaction : PowerValue;
	}
	
	action def MeasureResistanceChange {
		in temperatureChange : TemperatureValue;
		in baselineResistance : ResistanceValue;
		out newResistance : ResistanceValue;
	}
	
	action def GenerateBridgeVoltage {
		in activeResistance : ResistanceValue;
		in referenceResistance : ResistanceValue;
		in supplyVoltage : VoltageValue;
		out differentialVoltage : VoltageValue;
	}
	
	action def AmplifySignal {
		in inputVoltage : VoltageValue;
		in amplifierGain : Real;
		out amplifiedVoltage : VoltageValue;
	}
	
	action def ConvertToDigital {
		in analogVoltage : VoltageValue;
		in adcResolution : Integer;
		out digitalValue : Real;
	}
	
	action def ProcessSignal {
		in digitalValue : Real;
		in calibrationData : Real[*];
		out filteredValue : Real;
	}
	
	action def CalculateConcentration {
		in processedValue : Real;
		in calibrationCurve : Real[*];
		out concentration : GasConcentrationValue;
	}
	
	action def MeasurementCycle {
		in item gasSample : CombustibleGas;
		in item powerSupply : ElectricalSignal;
		out item measurementResult : MeasurementData;
		
		action initializeHeating : HeatBeads {
			in powerInput;
			in targetTemp;
			out activeTemp;
			out refTemp;
		}
		
		bind initializeHeating.powerInput = powerSupply;
		
		first initializeHeating;
		then fork;
		
		action catalyzeReaction : CatalyticReaction {
			in gas;
			in beadTemp;
			out tempRise;
			out heatGen;
		}
		
		bind catalyzeReaction.gas = gasSample;
		flow from initializeHeating.activeTemp to catalyzeReaction.beadTemp;
		
		then measureActive : MeasureResistanceChange {
			in temperatureChange;
			in baselineResistance;
			out activeR;
		}
		
		flow from catalyzeReaction.tempRise to measureActive.temperatureChange;
		
		then joinNode;
		
		action measureReference : MeasureResistanceChange {
			in temperatureChange;
			in baselineResistance;
			out referenceR;
		}
		
		then joinNode;
		
		join joinNode;
		
		then generateVoltage : GenerateBridgeVoltage {
			in activeResistance;
			in referenceResistance;
			in supplyVoltage;
			out diffVoltage;
		}
		
		flow from measureActive.activeR to generateVoltage.activeResistance;
		flow from measureReference.referenceR to generateVoltage.referenceResistance;
		
		then amplify : AmplifySignal {
			in inputVoltage;
			in amplifierGain;
			out ampVoltage;
		}
		
		flow from generateVoltage.diffVoltage to amplify.inputVoltage;
		
		then digitize : ConvertToDigital {
			in analogVoltage;
			in adcResolution;
			out digValue;
		}
		
		flow from amplify.ampVoltage to digitize.analogVoltage;
		
		then process : ProcessSignal {
			in digitalValue;
			in calibrationData;
			out filtValue;
		}
		
		flow from digitize.digValue to process.digitalValue;
		
		then calculate : CalculateConcentration {
			in processedValue;
			in calibrationCurve;
			out conc;
		}
		
		flow from process.filtValue to calculate.processedValue;
		
		bind calculate.conc = measurementResult.concentrationReading;
		
		then done;
	}
	
	state def SensorOperationalStates {
		entry; then powerOff;
		
		state powerOff {
			entry assign systemStatus = "Power Off";
		}
		
		transition powerOn
			first powerOff
			accept PowerOnCommand
			then warmup;
		
		state warmup {
			entry assign systemStatus = "Warming Up";
			entry action heatBeadsToOperatingTemp : HeatBeads;
		}
		
		transition warmupComplete
			first warmup
			accept TemperatureStabilized
			then ready;
		
		state ready {
			entry assign systemStatus = "Ready";
		}
		
		transition startMeasurement
			first ready
			accept MeasureCommand
			then measuring;
		
		state measuring {
			entry assign systemStatus = "Measuring";
			entry action performMeasurement : MeasurementCycle;
		}
		
		transition measurementComplete
			first measuring
			accept MeasurementDone
			then ready;
		
		transition initiateCalibration
			first ready
			accept CalibrationCommand
			then calibrating;
		
		state calibrating {
			entry assign systemStatus = "Calibrating";
		}
		
		transition calibrationComplete
			first calibrating
			accept CalibrationDone
			then ready;
		
		transition detectFault
			first warmup, ready, measuring, calibrating
			accept FaultDetected
			then fault;
		
		state fault {
			entry assign systemStatus = "Fault";
		}
		
		transition resetFromFault
			first fault
			accept ResetCommand
			then powerOff;
		
		transition shutdown
			first ready, measuring, calibrating
			accept PowerOffCommand
			then powerOff;
	}
	
	part def CatalyticBeadSensor {
		attribute systemStatus : String;
		attribute operatingTemperature : TemperatureValue;
		attribute detectionRange : GasConcentrationValue[2];
		attribute responseTime : TimeValue;
		attribute accuracy : Real;
		attribute warmupTime : TimeValue;
		
		port gasInput : GasInletPort;
		port powerInput : PowerSupplyPort;
		port analogOutput : AnalogOutputPort;
		port dataOutput : DataOutputPort;
		
		part activeBead : ActiveBead {
			attribute :>> beadDiameter = 0.5[mm];
			attribute :>> beadTemperature = 500[degC];
			attribute :>> resistance = 2.5[Ohm];
		}
		
		part referenceBead : ReferenceBead {
			attribute :>> beadDiameter = 0.5[mm];
			attribute :>> beadTemperature = 500[degC];
			attribute :>> resistance = 2.5[Ohm];
		}
		
		part bridgeCircuit : WheatstoneCircuit {
			attribute :>> supplyVoltage = 5.0[V];
			
			part :>> activeLeg = activeBead;
			part :>> referenceLeg = referenceBead;
			
			part :>> resistor1 {
				attribute :>> resistance = 100[Ohm];
				attribute :>> tolerance = 0.01;
			}
			
			part :>> resistor2 {
				attribute :>> resistance = 100[Ohm];
				attribute :>> tolerance = 0.01;
			}
		}
		
		part amplifier : SignalAmplifier {
			attribute :>> gain = 100.0;
			attribute :>> bandwidth = 10000[Hz];
		}
		
		part adc : AnalogToDigitalConverter {
			attribute :>> resolution = 16;
			attribute :>> samplingRate = 1000[Hz];
			attribute :>> referenceVoltage = 5.0[V];
		}
		
		part processor : SignalProcessor {
			attribute :>> processingRate = 1000[Hz];
		}
		
		part heatingController : HeatingController {
			attribute :>> targetTemperature = 500[degC];
			attribute :>> controlMode = "PID";
		}
		
		connection beadToBridge1
			connect activeBead to bridgeCircuit.activeLeg;
		
		connection beadToBridge2
			connect referenceBead to bridgeCircuit.referenceLeg;
		
		connection bridgeToAmplifier
			connect bridgeCircuit to amplifier;
		
		connection amplifierToADC
			connect amplifier to adc;
		
		connection adcToProcessor
			connect adc to processor;
		
		perform action sensingOperation : MeasurementCycle;
		
		exhibit state operationalState : SensorOperationalStates;
	}
	
	part catalyticBeadSensingUnit : CatalyticBeadSensor {
		attribute :>> operatingTemperature = 500[degC];
		attribute :>> responseTime = 30[s];
		attribute :>> warmupTime = 60[s];
		attribute :>> accuracy = 0.05;
		attribute :>> detectionRange = (0[ppm], 10000[ppm]);
	}
	
	requirement def PerformanceRequirements {
		subject sensor : CatalyticBeadSensor;
		
		require detectionRangeReq {
			doc /* The sensor shall detect combustible gas concentrations
			     * from 0 to 10000 ppm (parts per million). */
		}
		
		require responseTimeReq {
			doc /* The sensor shall achieve 90% of final reading
			     * within 30 seconds of gas exposure (T90 response time). */
		}
		
		require accuracyReq {
			doc /* The sensor shall maintain measurement accuracy
			     * within ±5% of reading across the full detection range. */
		}
		
		require operatingTemperatureReq {
			doc /* The catalytic beads shall operate at 500°C ± 10°C
			     * for optimal catalytic activity and sensitivity. */
		}
		
		require warmupTimeReq {
			doc /* The sensor shall complete warmup and be ready
			     * for measurement within 60 seconds of power-on. */
		}
		
		require stabilityReq {
			doc /* The sensor shall maintain baseline stability
			     * with drift less than 2% per month under continuous operation. */
		}
		
		require selectivityReq {
			doc /* The sensor shall respond to common combustible gases
			     * including methane, propane, hydrogen, and volatile organic compounds. */
		}
	}
	
	requirement def SafetyRequirements {
		subject sensor : CatalyticBeadSensor;
		
		require explosionProofReq {
			doc /* The sensor housing shall be explosion-proof rated
			     * and suitable for Class I, Division 1 hazardous locations. */
		}
		
		require failSafeReq {
			doc /* The sensor shall enter a safe state and signal fault
			     * condition upon detection of bead failure, circuit malfunction,
			     * or out-of-range operating conditions. */
		}
		
		require poisonDetectionReq {
			doc /* The sensor shall detect catalyst poisoning conditions
			     * and alert the user when sensitivity degradation exceeds 20%. */
		}
	}
	
	requirement def EnvironmentalRequirements {
		subject sensor : CatalyticBeadSensor;
		
		require temperatureRangeReq {
			doc /* The sensor shall operate in ambient temperatures
			     * from -40°C to +70°C. */
		}
		
		require humidityRangeReq {
			doc /* The sensor shall operate in relative humidity
			     * from 0% to 95% non-condensing. */
		}
		
		require pressureRangeReq {
			doc /* The sensor shall operate at atmospheric pressures
			     * from 80 kPa to 120 kPa. */
		}
	}
	
	requirement performanceReqs : PerformanceRequirements {
		subject sensor = catalyticBeadSensingUnit;
	}
	
	requirement safetyReqs : SafetyRequirements {
		subject sensor = catalyticBeadSensingUnit;
	}
	
	requirement environmentalReqs : EnvironmentalRequirements {
		subject sensor = catalyticBeadSensingUnit;
	}
	
	dependency from catalyticBeadSensingUnit to performanceReqs;
	dependency from catalyticBeadSensingUnit to safetyReqs;
	dependency from catalyticBeadSensingUnit to environmentalReqs;
}
