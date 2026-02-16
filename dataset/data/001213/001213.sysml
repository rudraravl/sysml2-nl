package 'Quantum Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import UnitsAndScales::*;
	private import Quantities::*;
	
	attribute def MagneticFluxDensityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MagneticFluxDensityUnit;
	}
	
	attribute def MagneticFluxDensityUnit :> MeasurementUnit;
	
	attribute def FrequencyValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : FrequencyUnit;
	}
	
	attribute def FrequencyUnit :> MeasurementUnit;
	
	attribute def CoherenceTimeValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : TimeUnit;
	}
	
	attribute def TimeUnit :> MeasurementUnit;
	
	attribute def QuantumStateValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : QuantumStateUnit;
	}
	
	attribute def QuantumStateUnit :> MeasurementUnit;
	
	item def MeasurementData {
		attribute fieldStrength : MagneticFluxDensityValue;
		attribute timestamp : TimeValue;
		attribute confidence : Real;
	}
	
	item def ControlCommand {
		attribute laserPower : PowerValue;
		attribute microwaveFrequency : FrequencyValue;
		attribute measurementDuration : TimeValue;
	}
	
	port def MeasurementOutputPort {
		out item data : MeasurementData;
	}
	
	port def ControlInputPort {
		in item command : ControlCommand;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : Real;
		in attribute current : Real;
	}
	
	port def OpticalPort {
		out attribute lightIntensity : PowerValue;
	}
	
	port def MicrowavePort {
		out attribute rfPower : PowerValue;
		out attribute frequency : FrequencyValue;
	}
	
	requirement def SensingPerformanceRequirement {
		doc /* The quantum sensing unit shall measure magnetic fields with high sensitivity and accuracy. */
		
		attribute maxNoise : Real;
		attribute minFieldNum : Real;
		attribute maxFieldNum : Real;
		attribute minCoherenceNum : Real;
	}
	
	action def InitializeSensor {
		in controlParams : ControlCommand;
		out initialized : Boolean;
	}
	
	action def PrepareQuantumState {
		in laserPower : PowerValue;
		in preparationTime : TimeValue;
		out state : QuantumStateValue;
	}
	
	action def ApplyMicrowavePulse {
		in frequency : FrequencyValue;
		in duration : TimeValue;
		inout state : QuantumStateValue;
	}
	
	action def EvolveUnderField {
		in evolutionTime : TimeValue;
		in magneticField : MagneticFluxDensityValue;
		inout state : QuantumStateValue;
	}
	
	action def ReadoutState {
		in state : QuantumStateValue;
		out fluorescence : Real;
	}
	
	action def ProcessSignal {
		in fluorescence : Real;
		in calibration : Real;
		out fieldValue : MagneticFluxDensityValue;
	}
	
	action def PerformMeasurement {
		in item control : ControlCommand;
		out item measurement : MeasurementData;
		
		bind prepare.laserPower = control.laserPower;
		
		action prepare : PrepareQuantumState {
			in laserPower;
			in preparationTime;
			out state;
		}
		
		succession flow from prepare.state to pulse.state;
		
		action pulse : ApplyMicrowavePulse {
			in frequency;
			in duration;
			inout state;
		}
		
		succession flow from pulse.state to evolve.state;
		
		action evolve : EvolveUnderField {
			in evolutionTime;
			in magneticField;
			inout state;
		}
		
		succession flow from evolve.state to readout.state;
		
		action readout : ReadoutState {
			in state;
			out fluorescence;
		}
		
		succession flow from readout.fluorescence to process.fluorescence;
		
		action process : ProcessSignal {
			in fluorescence;
			in calibration;
			out fieldValue;
		}
		
		bind process.fieldValue = measurement.fieldStrength;
	}
	
	state def QuantumSensorStateMachine {
		entry; then initialization;
		
		state initialization;
		then ready;
		
		state ready;
		accept StartMeasurement
		then measuring;
		
		state measuring {
			state preparation;
			then interrogation;
			
			state interrogation;
			then readout;
			
			state readout;
		}
		then processing;
		
		state processing;
		then ready;
		
		accept Shutdown
		then shutdown;
		
		state shutdown;
		then done;
	}
	
	part def LaserSystem {
		attribute wavelength : LengthValue;
		attribute outputPower : PowerValue;
		attribute stability : Real;
		
		port laserOutput : OpticalPort;
	}
	
	part def MicrowaveGenerator {
		attribute operatingFrequency : FrequencyValue;
		attribute outputPower : PowerValue;
		attribute phaseNoise : Real;
		
		port microwaveOutput : MicrowavePort;
	}
	
	part def NVCenterDiamond {
		attribute crystalSize : LengthValue;
		attribute nvDensity : Real;
		attribute coherenceTime : CoherenceTimeValue;
		attribute currentState : QuantumStateValue;
		
		port opticalInput {
			in attribute excitation : PowerValue;
		}
		
		port microwaveInput {
			in attribute rfField : PowerValue;
		}
		
		port opticalOutput {
			out attribute emission : PowerValue;
		}
	}
	
	part def PhotonDetector {
		attribute quantumEfficiency : Real;
		attribute darkCountRate : FrequencyValue;
		attribute timeResolution : TimeValue;
		
		port detectorInput {
			in attribute photonFlux : PowerValue;
		}
		
		port detectorOutput {
			out attribute counts : Real;
		}
	}
	
	part def SignalProcessor {
		attribute samplingRate : FrequencyValue;
		attribute bitDepth : Integer;
		attribute processingLatency : TimeValue;
		
		port signalInput {
			in attribute rawData : Real;
		}
		
		port signalOutput {
			out attribute processedField : MagneticFluxDensityValue;
		}
	}
	
	part def TemperatureStabilizer {
		attribute setpoint : TemperatureValue;
		attribute precision : TemperatureValue;
		attribute bandwidth : FrequencyValue;
		
		port tempControl {
			in attribute target : TemperatureValue;
			out attribute actual : TemperatureValue;
		}
	}
	
	connection def OpticalLink {
		end source : OpticalPort;
		end target;
	}
	
	connection def MicrowaveLink {
		end source : MicrowavePort;
		end target;
	}
	
	connection def DataLink {
		end transmitter;
		end receiver;
	}
	
	part quantumSensingUnit {
		attribute operatingTemp : TemperatureValue;
		attribute measurementRate : FrequencyValue;
		attribute sensitivity : MagneticFluxDensityValue;
		
		satisfy performanceReq : SensingPerformanceRequirement;
		
		port measurementOutput : MeasurementOutputPort;
		port controlInput : ControlInputPort;
		port powerSupply : PowerSupplyPort;
		
		part laser : LaserSystem {
			attribute :>> wavelength;
			attribute :>> outputPower;
			attribute :>> stability = 0.999;
		}
		
		part microwaveSource : MicrowaveGenerator {
			attribute :>> operatingFrequency;
			attribute :>> outputPower;
			attribute :>> phaseNoise = 0.0001;
		}
		
		part quantumSensor : NVCenterDiamond {
			attribute :>> crystalSize;
			attribute :>> nvDensity = 1.0e17;
			attribute :>> coherenceTime;
		}
		
		part detector : PhotonDetector {
			attribute :>> quantumEfficiency = 0.85;
			attribute :>> darkCountRate;
			attribute :>> timeResolution;
		}
		
		part processor : SignalProcessor {
			attribute :>> samplingRate;
			attribute :>> bitDepth = 16;
			attribute :>> processingLatency;
		}
		
		part tempController : TemperatureStabilizer {
			attribute :>> setpoint;
			attribute :>> precision;
			attribute :>> bandwidth;
		}
		
		connection opticalExcitation : OpticalLink
			connect source references laser.laserOutput
			to target references quantumSensor.opticalInput;
		
		connection microwaveControl : MicrowaveLink
			connect source references microwaveSource.microwaveOutput
			to target references quantumSensor.microwaveInput;
		
		connection opticalDetection : OpticalLink
			connect source references quantumSensor.opticalOutput
			to target references detector.detectorInput;
		
		connection dataProcessing : DataLink
			connect transmitter references detector.detectorOutput
			to receiver references processor.signalInput;
		
		connection dataOutput : DataLink
			connect transmitter references processor.signalOutput
			to receiver references measurementOutput;
		
		perform action measurementCycle : PerformMeasurement {
			in item :>> control : ControlCommand;
			out item :>> measurement : MeasurementData;
		}
		
		state sensorControl : QuantumSensorStateMachine;
	}
	
	requirement performanceReq : SensingPerformanceRequirement {
		subject quantumSensingUnit;
		
		attribute :>> maxNoise = 1.0e-12;
		attribute :>> minFieldNum = 1.0e-9;
		attribute :>> maxFieldNum = 1.0e-3;
		attribute :>> minCoherenceNum = 1.0e-3;
	}
	
	verification def VerifyMeasurementAccuracy {
		subject testUnit : quantumSensingUnit;
		
		objective verifyAccuracy {
			doc /* Verify that the quantum sensing unit achieves specified measurement accuracy. */
		}
		
		return verdict : Boolean;
	}
	
	part testSetup {
		part testSensor :> quantumSensingUnit;
		
		verification verifyAccuracy : VerifyMeasurementAccuracy {
			subject :>> testUnit = testSensor;
		}
		
		perform verifyAccuracy {
			in :>> testUnit;
			out :>> verdict = true;
		}
	}
}
