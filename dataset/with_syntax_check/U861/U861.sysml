package 'SSIES_System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	attribute def VoltageValue :> ISQ::ElectricPotentialValue;
	attribute def CurrentValue :> ISQ::ElectricCurrentValue;
	attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
	attribute def DensityValue :> ISQ::DensityValue;
	attribute def EnergyValue :> ISQ::EnergyValue;

	item def IonData {
		attribute density : DensityValue;
		attribute temperature : TemperatureValue;
		attribute driftVelocity : ISQ::SpeedValue;
		attribute composition : String;
	}

	item def ElectronData {
		attribute density : DensityValue;
		attribute temperature : TemperatureValue;
		attribute energy : EnergyValue;
	}

	item def ScintillationData {
		attribute amplitude : Real;
		attribute frequency : ISQ::FrequencyValue;
		attribute phaseVariation : Real;
	}

	item def TelemetryPacket {
		attribute timestamp : ISQ::TimeValue;
		attribute ionosphericData : IonData;
		attribute electronData : ElectronData;
		attribute scintillationData : ScintillationData;
		attribute instrumentStatus : String;
	}

	item def CommandPacket {
		attribute commandID : Integer;
		attribute operatingMode : String;
		attribute calibrationFlag : Boolean;
	}

	item def PowerSupply {
		attribute voltage : VoltageValue;
		attribute current : CurrentValue;
		attribute power : ISQ::PowerValue;
	}

	port def PowerPort {
		in item powerIn : PowerSupply;
	}

	port def DataPort {
		out item telemetryOut : TelemetryPacket;
		in item commandIn : CommandPacket;
	}

	port def SensorPort {
		out item ionMeasurement : IonData;
		out item electronMeasurement : ElectronData;
	}

	action def MeasureIons {
		out ionData : IonData;
	}

	action def MeasureElectrons {
		out electronData : ElectronData;
	}

	action def DetectScintillation {
		in ionData : IonData;
		in electronData : ElectronData;
		out scintillationData : ScintillationData;
	}

	action def ProcessMeasurements {
		in ionData : IonData;
		in electronData : ElectronData;
		in scintillationData : ScintillationData;
		out telemetry : TelemetryPacket;
	}

	action def TransmitTelemetry {
		in telemetry : TelemetryPacket;
		out transmittedPacket : TelemetryPacket;
	}

	action def SSIESOperationalCycle {
		doc /* 
			Primary operational cycle for SSIES instrument:
			1. Measure ionospheric ions and electrons
			2. Detect scintillation effects
			3. Process all measurements into telemetry
			4. Transmit telemetry to spacecraft bus
		*/

		first start;
		then merge continuousMeasurement;

		then action measureIons : MeasureIons {
			out ionData : IonData;
		}

		then action measureElectrons : MeasureElectrons {
			out electronData : ElectronData;
		}

		then action detectScintillation : DetectScintillation {
			in ionData = measureIons.ionData;
			in electronData = measureElectrons.ionData;
			out scintillationData : ScintillationData;
		}

		then action processMeasurements : ProcessMeasurements {
			in ionData = measureIons.ionData;
			in electronData = measureElectrons.electronData;
			in scintillationData = detectScintillation.scintillationData;
			out telemetry : TelemetryPacket;
		}

		then action transmitTelemetry : TransmitTelemetry {
			in telemetry = processMeasurements.telemetry;
			out transmittedPacket : TelemetryPacket;
		}

		then continuousMeasurement;
	}

	part def IonDriftMeter {
		port powerInput : PowerPort;
		port sensorOutput : SensorPort;

		attribute sweepVoltage : VoltageValue;
		attribute collectorArea : ISQ::AreaValue;

		perform action ionMeasurement : MeasureIons;
	}

	part def RetardingPotentialAnalyzer {
		port powerInput : PowerPort;
		port sensorOutput : SensorPort;

		attribute retardingVoltage : VoltageValue;
		attribute gridSpacing : ISQ::LengthValue;

		perform action electronMeasurement : MeasureElectrons;
	}

	part def ScintillationMonitor {
		port powerInput : PowerPort;

		attribute samplingRate : ISQ::FrequencyValue;
		attribute bandwidth : ISQ::FrequencyValue;

		perform action scintillationDetection : DetectScintillation;
	}

	part def DataProcessingUnit {
		port powerInput : PowerPort;
		port dataInterface : DataPort;

		attribute processingSpeed : ISQ::FrequencyValue;
		attribute memoryCapacity : Real;

		perform action dataProcessing : ProcessMeasurements;
		perform action telemetryTransmission : TransmitTelemetry;

		state operatingModes {
			entry; then initialization;
			
			state initialization;
			state standby;
			state measurement;
			state calibration;
			state safeMode;

			transition initialization_to_standby
				first initialization
				accept powerStable
				then standby;

			transition standby_to_measurement
				first standby
				accept startCommand
				then measurement;

			transition measurement_to_calibration
				first measurement
				accept calibrationRequest
				then calibration;

			transition calibration_to_measurement
				first calibration
				accept calibrationComplete
				then measurement;

			transition any_to_safe
				accept anomalyDetected
				then safeMode;

			transition safe_to_standby
				first safeMode
				accept resetCommand
				then standby;

			state measurement {
				entry action startMeasurements;
				do action continuousSampling;
				exit action stopMeasurements;
			}
		}
	}

	part def PowerRegulator {
		port primaryPower : PowerPort;
		port regulatedPower : PowerPort;

		attribute inputVoltage : VoltageValue;
		attribute outputVoltage : VoltageValue;
		attribute efficiency : Real;
	}

	part def SSIES_Instrument {
		doc /* 
			Special Sensor - Ionospheric and Electron Scintillation (SSIES)
			
			Primary Function: Measure in-situ ionospheric plasma parameters including
			ion density, composition, drift velocity, electron density and temperature,
			and detect ionospheric scintillation effects that impact radio wave propagation.
			
			The instrument operates continuously in low Earth orbit, providing critical
			data for space weather monitoring and ionospheric research.
		*/

		port spacecraftPower : PowerPort;
		port spacecraftData : DataPort;

		part ionDriftMeter : IonDriftMeter;
		part rpa : RetardingPotentialAnalyzer;
		part scintillationMonitor : ScintillationMonitor;
		part dpu : DataProcessingUnit;
		part powerRegulator : PowerRegulator;

		connect spacecraftPower to powerRegulator.primaryPower;
		connect powerRegulator.regulatedPower to ionDriftMeter.powerInput;
		connect powerRegulator.regulatedPower to rpa.powerInput;
		connect powerRegulator.regulatedPower to scintillationMonitor.powerInput;
		connect powerRegulator.regulatedPower to dpu.powerInput;
		connect dpu.dataInterface to spacecraftData;

		perform action operationalCycle[*] ordered references SSIESOperationalCycle;
	}

	part def SpacecraftBus {
		port powerBus : PowerPort;
		port dataBus : DataPort;

		part powerSystem;
		part commandControl;
		part telemetrySystem;
	}

	part ssiesSystem : SpacecraftBus {
		part ssies : SSIES_Instrument {
			connect spacecraftPower to powerBus;
			connect spacecraftData to dataBus;
		}
	}

	requirement def MeasurementAccuracyRequirement {
		doc /* 
			The SSIES shall measure ionospheric parameters with specified accuracy
			to support space weather prediction and ionospheric research.
		*/

		subject instrument : SSIES_Instrument;

		require constraint ionDensityAccuracy {
			doc /* Ion density measurements accurate to within 10% */
		}

		require constraint electronTemperatureAccuracy {
			doc /* Electron temperature measurements accurate to within 15% */
		}

		require constraint scintillationSensitivity {
			doc /* Scintillation detection sensitivity of 0.1 dB minimum */
		}
	}

	requirement def OperationalRequirement {
		doc /* 
			The SSIES shall operate continuously in low Earth orbit environment
			and provide telemetry at specified intervals.
		*/

		subject instrument : SSIES_Instrument;

		require constraint continuousOperation {
			doc /* Instrument shall operate continuously for mission duration */
		}

		require constraint telemetryRate {
			doc /* Telemetry packets transmitted at minimum 1 Hz rate */
		}

		require constraint powerConsumption {
			instrument.powerRegulator.inputVoltage <= 32.0[V] and
			instrument.powerRegulator.efficiency >= 0.85
		}
	}

	requirement def EnvironmentalRequirement {
		doc /* 
			The SSIES shall withstand space environment including thermal cycling,
			radiation, and vacuum conditions.
		*/

		subject instrument : SSIES_Instrument;

		require constraint thermalRange {
			doc /* Operate within -40°C to +60°C temperature range */
		}

		require constraint radiationTolerance {
			doc /* Survive total ionizing dose of 30 krad minimum */
		}
	}

	requirement <'SSIES-SYS-001'> ssiesMissionRequirements {
		doc /* 
			The SSIES instrument shall measure in-situ ionospheric plasma parameters
			and scintillation effects to support space weather monitoring and research.
		*/

		assume constraint orbitalEnvironment {
			doc /* Instrument operates in LEO at 400-850 km altitude */
		}

		require MeasurementAccuracyRequirement;
		require OperationalRequirement;
		require EnvironmentalRequirement;
	}

	part ssiesInstance : SSIES_Instrument {
		satisfy ssiesMissionRequirements;
	}
}
