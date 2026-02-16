package 'MHD Sensing Unit' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	private import Quantities::*;
	private import MeasurementReferences::*;
	
	attribute def MagneticFluxDensityUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[3] ordered;
	}
	
	attribute def MagneticFluxDensityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : MagneticFluxDensityUnit;
	}
	
	attribute magneticFluxDensity : MagneticFluxDensityValue :> scalarQuantities;
	
	attribute def ElectricConductivityUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[4] ordered;
	}
	
	attribute def ElectricConductivityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : ElectricConductivityUnit;
	}
	
	attribute electricConductivity : ElectricConductivityValue :> scalarQuantities;
	
	attribute def VolumeFlowUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
	}
	
	attribute def VolumeFlowValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeFlowUnit;
	}
	
	attribute volumeFlow : VolumeFlowValue :> scalarQuantities;
	
	attribute def VelocityUnit :> MeasurementUnit {
		attribute :>> unitPowerFactor : UnitPowerFactor[2] ordered;
	}
	
	attribute def VelocityValue :> ScalarQuantityValue {
		attribute :>> num : Real;
		attribute :>> mRef : VelocityUnit;
	}
	
	item def ConductiveFluid {
		attribute velocity : VelocityValue;
		attribute conductivity : ElectricConductivityValue;
		attribute temperature : TemperatureValue;
		attribute pressure : PressureValue;
	}
	
	item def InducedVoltageSignal {
		attribute voltage : Real;
		attribute timestamp : Real;
	}
	
	item def MagneticFieldSource {
		attribute fluxDensity : MagneticFluxDensityValue;
		attribute fieldDirection : String;
	}
	
	port def FluidInletPort {
		in item fluidIn : ConductiveFluid;
	}
	
	port def FluidOutletPort {
		out item fluidOut : ConductiveFluid;
	}
	
	port def VoltageOutputPort {
		out attribute voltage : Real;
	}
	
	port def PowerSupplyPort {
		in attribute voltage : Real;
		in attribute current : Real;
	}
	
	port def DataOutputPort {
		out attribute flowRate : VolumeFlowValue;
		out attribute velocity : VelocityValue;
	}
	
	action def GenerateMagneticField {
		in supplyPower : Real;
		in coilCurrent : Real;
		out magneticField : MagneticFieldSource;
	}
	
	action def SenseInducedVoltage {
		in fluidVelocity : VelocityValue;
		in magneticFlux : MagneticFluxDensityValue;
		in fluidConductivity : ElectricConductivityValue;
		in electrodeSpacing : LengthValue;
		out inducedVoltage : Real;
	}
	
	action def AmplifySignal {
		in rawVoltage : Real;
		in amplificationGain : Real;
		out amplifiedVoltage : Real;
	}
	
	action def FilterSignal {
		in inputSignal : Real;
		in cutoffFrequency : Real;
		out filteredSignal : Real;
	}
	
	action def CalculateFlowRate {
		in measuredVoltage : Real;
		in calibrationConstant : Real;
		in pipeArea : AreaValue;
		in magneticFlux : MagneticFluxDensityValue;
		out flowRate : VolumeFlowValue;
		out velocity : VelocityValue;
	}
	
	message PowerOnSignal;
	message InitializationComplete;
	message StartMeasurement;
	message DiagnosticRequest;
	message DiagnosticsComplete;
	message StopMeasurement;
	message PowerOffSignal;
	
	state def MHDSensorOperationalState {
		entry; then powerOff;
		
		state powerOff;
		transition powerOff_to_initialization
			first powerOff
			accept PowerOnSignal
			then initialization;
		
		state initialization {
			entry; then checkMagneticField;
			state checkMagneticField;
			then verifyElectrodes;
			state verifyElectrodes;
			then loadCalibration;
			state loadCalibration;
			then done;
		}
		transition initialization_to_ready
			first initialization
			accept InitializationComplete
			then ready;
		
		state ready;
		transition ready_to_measuring
			first ready
			accept StartMeasurement
			then measuring;
		
		state measuring {
			entry; then activateField;
			state activateField;
			then acquireSignal;
			state acquireSignal;
			then processData;
			state processData;
			then outputResults;
			state outputResults;
			then acquireSignal;
		}
		
		transition measuring_to_diagnostics
			first measuring
			accept DiagnosticRequest
			then diagnostics;
		
		state diagnostics {
			entry; then testElectrodes;
			state testElectrodes;
			then testMagneticField;
			state testMagneticField;
			then done;
		}
		transition diagnostics_to_ready
			first diagnostics
			accept DiagnosticsComplete
			then ready;
		
		transition measuring_to_ready
			first measuring
			accept StopMeasurement
			then ready;
		
		transition ready_to_powerOff
			first ready
			accept PowerOffSignal
			then powerOff;
	}
	
	connection def FluidFlowConnection {
		end source : FluidInletPort;
		end target : FluidOutletPort;
	}
	
	connection def SignalConnection {
		end source : VoltageOutputPort;
		end target;
	}
	
	part def Electromagnet {
		attribute numberOfTurns : Integer;
		attribute coreMaterial : String;
		attribute operatingCurrent : Real;
		attribute generatedFluxDensity : MagneticFluxDensityValue;
		
		port powerInput : PowerSupplyPort;
		
		perform action generateField : GenerateMagneticField {
			in supplyPower = powerInput.voltage * powerInput.current;
			in coilCurrent = operatingCurrent;
			out magneticField;
		}
	}
	
	part def MeasurementElectrode {
		attribute electrodeMaterial : String;
		attribute contactArea : AreaValue;
		attribute position : String;
		
		port signalOutput : VoltageOutputPort;
	}
	
	part def SignalConditioningModule {
		attribute amplifierGain : Real default = 100.0;
		attribute filterCutoff : Real default = 50.0;
		attribute noiseLevel : Real;
		
		port rawInput : VoltageOutputPort;
		port conditionedOutput : VoltageOutputPort;
		
		perform action amplifyAction : AmplifySignal {
			in rawVoltage = rawInput.voltage;
			in amplificationGain = amplifierGain;
			out amplifiedVoltage;
		}
		then perform action filterAction : FilterSignal {
			in inputSignal = amplifyAction.amplifiedVoltage;
			in cutoffFrequency = filterCutoff;
			out filteredSignal;
		}
		
		bind filterAction.filteredSignal = conditionedOutput.voltage;
	}
	
	part def MeasurementTube {
		attribute innerDiameter : LengthValue;
		attribute tubeLength : LengthValue;
		attribute tubeMaterial : String;
		attribute linerMaterial : String;
		
		port inlet : FluidInletPort;
		port outlet : FluidOutletPort;
		
		connection flowPath : FluidFlowConnection
			connect source references inlet
			to target references outlet;
	}
	
	part def MHDSensor {
		attribute sensorSerialNumber : String;
		attribute lastCalibrationDate : String;
		attribute calibrationConstant : Real default = 1.0;
		attribute electrodeSpacing : LengthValue;
		
		port fluidInput : FluidInletPort;
		port fluidOutput : FluidOutletPort;
		port powerPort : PowerSupplyPort;
		port outputPort : VoltageOutputPort;
		
		part measurementTube : MeasurementTube[1] {
			attribute :>> innerDiameter = 100.0;
			attribute :>> tubeLength = 200.0;
			attribute :>> tubeMaterial = "Stainless Steel 316L";
			attribute :>> linerMaterial = "PTFE";
		}
		
		part fieldCoils : Electromagnet[2] {
			attribute :>> numberOfTurns = 1500;
			attribute :>> coreMaterial = "Laminated Silicon Steel";
			attribute :>> operatingCurrent = 2.5;
		}
		
		part electrodes : MeasurementElectrode[2] {
			attribute :>> electrodeMaterial = "Hastelloy C";
		}
		
		part signalProcessor : SignalConditioningModule[1] {
			attribute :>> amplifierGain = 120.0;
			attribute :>> filterCutoff = 100.0;
			attribute :>> noiseLevel = 0.001;
		}
		
		connect fluidInput to measurementTube.inlet;
		connect measurementTube.outlet to fluidOutput;
		
		connect electrodes[1].signalOutput to signalProcessor.rawInput;
		connect signalProcessor.conditionedOutput to outputPort;
		
		perform action performMeasurement {
			in item fluid : ConductiveFluid = fluidInput.fluidIn;
			out flowRate : VolumeFlowValue;
			out velocity : VelocityValue;
			
			action activateMagneticField : GenerateMagneticField {
				in supplyPower = powerPort.voltage * powerPort.current;
				in coilCurrent = fieldCoils[1].operatingCurrent;
				out magneticField;
			}
			then fork;
			
			then action detectVoltage : SenseInducedVoltage {
				in fluidVelocity = fluid.velocity;
				in magneticFlux = activateMagneticField.magneticField.fluxDensity;
				in fluidConductivity = fluid.conductivity;
				in electrodeSpacing = MHDSensor::electrodeSpacing;
				out inducedVoltage;
			}
			then joinNode;
			
			join joinNode;
			then action calculateFlow : CalculateFlowRate {
				in measuredVoltage = detectVoltage.inducedVoltage;
				in calibrationConstant = MHDSensor::calibrationConstant;
				in pipeArea;
				in magneticFlux = activateMagneticField.magneticField.fluxDensity;
				out flowRate;
				out velocity;
			}
			
			bind calculateFlow.flowRate = performMeasurement.flowRate;
			bind calculateFlow.velocity = performMeasurement.velocity;
		}
		
		exhibit state operationalBehavior : MHDSensorOperationalState;
	}
	
	part def SensingUnit {
		attribute unitIdentifier : String;
		attribute installationDate : String;
		attribute operatingTemperatureMin : TemperatureValue;
		attribute operatingTemperatureMax : TemperatureValue;
		attribute maximumPressure : PressureValue;
		attribute minimumConductivity : ElectricConductivityValue;
		
		port processInlet : FluidInletPort;
		port processOutlet : FluidOutletPort;
		port powerSupply : PowerSupplyPort;
		port measurementData : DataOutputPort;
		
		part sensor : MHDSensor[1] {
			attribute :>> sensorSerialNumber = "MHD-2025-SN-00123";
			attribute :>> lastCalibrationDate = "2025-01-10";
			attribute :>> calibrationConstant = 1.02;
		}
		
		connect processInlet to sensor.fluidInput;
		connect sensor.fluidOutput to processOutlet;
		connect powerSupply to sensor.powerPort;
		
		flow from sensor.performMeasurement.flowRate to measurementData.flowRate;
		flow from sensor.performMeasurement.velocity to measurementData.velocity;
	}
	
	requirement def MHDSensingRequirement {
		doc /* The MHD sensing unit shall accurately measure flow rate of electrically conductive fluids. */
		
		require measurementAccuracy {
			doc /* The sensing unit shall provide flow measurement accuracy within ±0.5% of full scale. */
		}
		
		require responseTime {
			doc /* The sensing unit shall have a response time of less than 50 milliseconds. */
		}
		
		require minimumConductivity {
			doc /* The sensing unit shall operate with fluids having minimum conductivity of 10 microsiemens per centimeter. */
		}
		
		require temperatureRange {
			doc /* The sensing unit shall operate with fluid temperatures from -20°C to 200°C. */
		}
		
		require pressureRating {
			doc /* The sensing unit shall withstand fluid pressures up to 50 bar. */
		}
		
		require linearityError {
			doc /* The sensing unit shall maintain linearity error less than ±0.25% over the measurement range. */
		}
	}
	
	requirement sensingUnitRequirement : MHDSensingRequirement {
		subject unit : SensingUnit;
		
		assume conductiveFluid {
			doc /* The process fluid has sufficient electrical conductivity for MHD measurement. */
		}
		
		assume uniformMagneticField {
			doc /* The magnetic field is uniform and perpendicular to fluid flow direction. */
		}
		
		assume fullyDevelopedFlow {
			doc /* The fluid flow profile is fully developed in the measurement section. */
		}
	}
	
	part sensingUnitInstance : SensingUnit {
		attribute :>> unitIdentifier = "MHD-SU-001";
		attribute :>> installationDate = "2025-01-15";
		
		satisfy sensingUnitRequirement;
	}
}
