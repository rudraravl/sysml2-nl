package 'Heat Flux Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	comment about HeatFluxSensingUnit
	/* This model describes a heat flux sensing unit that measures thermal energy 
	 * transfer rate per unit area. The system comprises a thermopile sensor element, 
	 * signal conditioning circuitry, analog-to-digital conversion, and a processing 
	 * module that outputs calibrated heat flux measurements. */
	
	attribute def HeatFluxUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[3] ordered = (
			UnitPowerFactor(unit = MassUnit(), exponent = 1),
			UnitPowerFactor(unit = TimeUnit(), exponent = -3),
			UnitPowerFactor(unit = LengthUnit(), exponent = 0)
		);
	}
	
	attribute def HeatFluxValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : HeatFluxUnit;
	}
	
	attribute heatFlux : HeatFluxValue :> scalarQuantities;
	
	attribute def VoltageValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VoltageUnit;
	}
	
	attribute def VoltageUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[4] ordered = (
			UnitPowerFactor(unit = MassUnit(), exponent = 1),
			UnitPowerFactor(unit = LengthUnit(), exponent = 2),
			UnitPowerFactor(unit = TimeUnit(), exponent = -3),
			UnitPowerFactor(unit = ElectricCurrentUnit(), exponent = -1)
		);
	}
	
	item def HeatFluxMeasurement {
		attribute fluxValue : HeatFluxValue;
		attribute timestamp : TimeValue;
		attribute sensorTemperature : TemperatureValue;
		attribute qualityIndicator : Real;
	}
	
	item def CalibrationData {
		attribute sensitivity : Real;
		attribute offsetVoltage : VoltageValue;
		attribute temperatureCoefficient : Real;
		attribute calibrationDate : String;
	}
	
	port def SensorOutputPort {
		out attribute rawVoltage : VoltageValue;
		out attribute temperature : TemperatureValue;
	}
	
	port def DataPort {
		out item measurement : HeatFluxMeasurement;
	}
	
	port def PowerPort {
		in attribute supplyVoltage : VoltageValue;
	}
	
	connection def SignalConnection {
		end source : SensorOutputPort;
		end target : ~SensorOutputPort;
	}
	
	part def ThermopileSensor {
		attribute junctionCount : Integer;
		attribute thermalResistance : Real;
		attribute responseTime : TimeValue;
		attribute operatingTemperature : TemperatureValue;
		
		port sensorOutput : SensorOutputPort;
		
		action generateVoltage {
			in incidentFlux : HeatFluxValue;
			out outputVoltage : VoltageValue;
		}
	}
	
	part def SignalConditioner {
		attribute amplificationGain : Real;
		attribute filterCutoffFrequency : Real;
		
		port analogInput : ~SensorOutputPort;
		port conditionedOutput : SensorOutputPort;
		
		action amplifySignal {
			in inputVoltage : VoltageValue;
			out amplifiedVoltage : VoltageValue;
		}
		
		action filterSignal {
			in noisySignal : VoltageValue;
			out cleanSignal : VoltageValue;
		}
	}
	
	part def ADConverter {
		attribute resolution : Integer;
		attribute samplingRate : Real;
		attribute referenceVoltage : VoltageValue;
		
		port analogInput : ~SensorOutputPort;
		
		action convertToDigital {
			in analogVoltage : VoltageValue;
			out digitalValue : Integer;
		}
	}
	
	part def ProcessingUnit {
		attribute calibration : CalibrationData;
		
		port dataOutput : DataPort;
		
		action computeHeatFlux {
			in digitalSignal : Integer;
			in sensorTemp : TemperatureValue;
			in calibrationData : CalibrationData;
			out measurement : HeatFluxMeasurement;
			
			action applyCalibration {
				in rawValue : Integer;
				in sensitivity : Real;
				in offset : VoltageValue;
				out calibratedVoltage : VoltageValue;
			}
			then compensateTemperature;
			
			action compensateTemperature {
				in voltage : VoltageValue;
				in temperature : TemperatureValue;
				in tempCoeff : Real;
				out compensatedVoltage : VoltageValue;
			}
			then convertToFlux;
			
			action convertToFlux {
				in voltage : VoltageValue;
				out flux : HeatFluxValue;
			}
			then validateMeasurement;
			
			action validateMeasurement {
				in flux : HeatFluxValue;
				out quality : Real;
			}
			then assembleMeasurement;
			
			action assembleMeasurement {
				in flux : HeatFluxValue;
				in temp : TemperatureValue;
				in quality : Real;
				out finalMeasurement : HeatFluxMeasurement;
			}
		}
	}
	
	part def DataStorage {
		attribute storageCapacity : Integer;
		attribute storedMeasurements : HeatFluxMeasurement[0..*];
		
		action storeMeasurement {
			in measurement : HeatFluxMeasurement;
		}
		
		action retrieveMeasurement {
			in index : Integer;
			out measurement : HeatFluxMeasurement;
		}
	}
	
	item def PowerOnSignal;
	item def InitCompleteSignal;
	item def WarmupCompleteSignal;
	item def StartMeasurementSignal;
	item def CalibrateCommandSignal;
	item def StopMeasurementSignal;
	item def FaultDetectedSignal;
	item def CalibrationCompleteSignal;
	item def RecoverySuccessSignal;
	item def ShutdownSignal;
	
	state def SensorOperationStates {
		entry; then powerOff;
		
		state powerOff;
		transition powerOff_to_initializing
			first powerOff
			accept PowerOnSignal
			then initializing;
		
		state initializing {
			entry action initializeHardware;
		}
		transition initializing_to_warmup
			first initializing
			accept InitCompleteSignal
			then warmup;
		
		state warmup {
			entry action stabilizeSensor;
		}
		transition warmup_to_ready
			first warmup
			accept WarmupCompleteSignal
			then ready;
		
		state ready {
			entry action enableMeasurement;
		}
		transition ready_to_measuring
			first ready
			accept StartMeasurementSignal
			then measuring;
		
		transition ready_to_calibration
			first ready
			accept CalibrateCommandSignal
			then calibrating;
		
		state measuring {
			entry action beginSampling;
			do action acquireData;
			exit action stopSampling;
		}
		transition measuring_to_ready
			first measuring
			accept StopMeasurementSignal
			then ready;
		
		transition measuring_to_fault
			first measuring
			accept FaultDetectedSignal
			then fault;
		
		state calibrating {
			entry action loadCalibration;
			do action performCalibration;
			exit action saveCalibration;
		}
		transition calibrating_to_ready
			first calibrating
			accept CalibrationCompleteSignal
			then ready;
		
		state fault {
			entry action logFault;
			do action attemptRecovery;
		}
		transition fault_to_ready
			first fault
			accept RecoverySuccessSignal
			then ready;
		
		transition fault_to_powerOff
			first fault
			accept ShutdownSignal
			then powerOff;
	}
	
	part def HeatFluxSensingUnit {
		part thermopile : ThermopileSensor[1] {
			attribute :>> junctionCount = 120;
			attribute :>> thermalResistance = 0.0015;
			attribute :>> responseTime = 0.5[s];
		}
		
		part conditioner : SignalConditioner[1] {
			attribute :>> amplificationGain = 100.0;
			attribute :>> filterCutoffFrequency = 10.0;
		}
		
		part adc : ADConverter[1] {
			attribute :>> resolution = 24;
			attribute :>> samplingRate = 100.0;
			attribute :>> referenceVoltage = 5.0[V];
		}
		
		part processor : ProcessingUnit[1] {
			attribute :>> calibration : CalibrationData {
				attribute :>> sensitivity = 8.5e-6;
				attribute :>> offsetVoltage = 0.0[V];
				attribute :>> temperatureCoefficient = 0.02;
				attribute :>> calibrationDate = "2025-01-15";
			}
		}
		
		part storage : DataStorage[1] {
			attribute :>> storageCapacity = 10000;
		}
		
		port powerInput : PowerPort;
		port dataOutput : DataPort;
		
		connection sensorToConditioner : SignalConnection
			connect thermopile.sensorOutput to conditioner.analogInput;
		
		connection conditionerToADC : SignalConnection
			connect conditioner.conditionedOutput to adc.analogInput;
		
		connect processor.dataOutput to dataOutput;
		
		state operationState : SensorOperationStates;
	}
	
	action def MeasurementCycle {
		in item targetSurface : Surface;
		out item measurements : HeatFluxMeasurement[1..*];
		
		action initializeSensor {
			out sensorReady : Boolean;
		}
		then acquireSample;
		
		action acquireSample {
			in surface : Surface;
			out rawVoltage : VoltageValue;
			out temperature : TemperatureValue;
		}
		then processSignal;
		
		action processSignal {
			in voltage : VoltageValue;
			in temp : TemperatureValue;
			out fluxValue : HeatFluxValue;
		}
		then validateData;
		
		action validateData {
			in flux : HeatFluxValue;
			out isValid : Boolean;
			out measurement : HeatFluxMeasurement;
		}
		then fork;
			then storeMeasurement;
			then outputMeasurement;
		
		action storeMeasurement {
			in measurement : HeatFluxMeasurement;
		}
		then joinNode;
		
		action outputMeasurement {
			in measurement : HeatFluxMeasurement;
			out transmittedData : HeatFluxMeasurement;
		}
		then joinNode;
		
		join joinNode;
		then checkContinue;
		
		action checkContinue {
			out continueAcquisition : Boolean;
		}
	}
	
	item def Surface {
		attribute surfaceArea : Real;
		attribute material : String;
		attribute emissivity : Real;
	}
	
	requirement def MeasurementAccuracyRequirement {
		doc /* The heat flux sensor shall measure heat flux with an accuracy of ±3% 
		     * of the reading over the range of 0 to 2000 W/m². */
		
		subject sensingSystem : HeatFluxSensingUnit;
		
		attribute maxError : Real = 0.03;
		attribute measurementRange : Real[2] = (0.0, 2000.0);
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The sensor system shall achieve 95% of final reading within 1 second 
		     * of a step change in heat flux. */
		
		subject sensingSystem : HeatFluxSensingUnit;
		
		attribute settlingPercentage : Real = 0.95;
		attribute maxResponseTime : TimeValue = 1.0[s];
	}
	
	requirement def OperatingTemperatureRequirement {
		doc /* The sensor shall operate continuously over an ambient temperature 
		     * range of -40°C to +85°C. */
		
		subject sensingSystem : HeatFluxSensingUnit;
		
		attribute minTemp : Real = -40.0;
		attribute maxTemp : Real = 85.0;
	}
	
	requirement def DataOutputRequirement {
		doc /* The system shall output calibrated heat flux measurements at a 
		     * minimum rate of 10 Hz with timestamp and quality indicators. */
		
		subject sensingSystem : HeatFluxSensingUnit;
		
		attribute minOutputRate : Real = 10.0;
	}
	
	requirement systemRequirements {
		subject heatFluxSensingUnit : HeatFluxSensingUnit;
		
		requirement accuracyReq : MeasurementAccuracyRequirement;
		requirement responseReq : ResponseTimeRequirement;
		requirement tempReq : OperatingTemperatureRequirement;
		requirement outputReq : DataOutputRequirement;
	}
	
	part sensingUnitInstance : HeatFluxSensingUnit;
	
	satisfy systemRequirements by sensingUnitInstance;
}
