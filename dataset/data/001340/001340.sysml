package 'AmorphousMetalTransformerSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def AtomicStructure;
	attribute def CrystallineOrder;
	
	item def MagneticFlux {
		attribute fluxDensity : ISQ::MagneticFluxDensityValue;
		attribute frequency : ISQ::FrequencyValue;
	}
	
	item def ElectricalPower {
		attribute voltage : ISQ::ElectricPotentialValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute power : ISQ::PowerValue;
	}
	
	item def ThermalEnergy {
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute heatFlow : ISQ::PowerValue;
	}
	
	port def ElectricalPort {
		in item powerIn : ElectricalPower;
		out item powerOut : ElectricalPower;
	}
	
	port def MagneticPort {
		in item fluxIn : MagneticFlux;
		out item fluxOut : MagneticFlux;
	}
	
	port def ThermalPort {
		out item heatOut : ThermalEnergy;
	}
	
	part def AmorphousMetalCore {
		doc /* 
		Amorphous metal core with non-crystalline atomic structure providing
		superior magnetic properties and reduced energy losses
		*/
		
		attribute atomicStructure : AtomicStructure {
			doc /* Random atomic arrangement without long-range crystalline order */
		}
		attribute magneticPermeability : Real;
		attribute saturationFluxDensity : ISQ::MagneticFluxDensityValue;
		attribute coreLossFactor : Real;
		attribute mass : ISQ::MassValue;
		attribute curieTempValue : ISQ::ThermodynamicTemperatureValue;
		
		port magneticInput : MagneticPort;
		port magneticOutput : MagneticPort;
		port thermal : ThermalPort;
	}
	
	part def PrimaryWinding {
		attribute numberOfTurns : Integer;
		attribute wireResistance : Real;
		attribute ratedCurrent : ISQ::ElectricCurrentValue;
		
		port electrical : ElectricalPort;
		port magnetic : MagneticPort;
	}
	
	part def SecondaryWinding {
		attribute numberOfTurns : Integer;
		attribute wireResistance : Real;
		attribute ratedCurrent : ISQ::ElectricCurrentValue;
		
		port electrical : ElectricalPort;
		port magnetic : MagneticPort;
	}
	
	part def CoolingSystem {
		attribute coolingCapacity : ISQ::PowerValue;
		attribute ambientTemperature : ISQ::ThermodynamicTemperatureValue;
		
		port thermalInput : ThermalPort;
	}
	
	part def ProtectionCircuit {
		attribute overloadThreshold : ISQ::ElectricCurrentValue;
		attribute overvoltageThreshold : ISQ::ElectricPotentialValue;
		
		port monitor : ElectricalPort;
	}
	
	action def CalculateCoreLoss {
		in fluxDensity : ISQ::MagneticFluxDensityValue;
		in frequency : ISQ::FrequencyValue;
		in coreMass : ISQ::MassValue;
		in lossFactor : Real;
		out coreLoss : ISQ::PowerValue;
	}
	
	action def TransformVoltage {
		in inputVoltage : ISQ::ElectricPotentialValue;
		in inputCurrent : ISQ::ElectricCurrentValue;
		in turnsRatio : Real;
		out outputVoltage : ISQ::ElectricPotentialValue;
		out outputCurrent : ISQ::ElectricCurrentValue;
	}
	
	action def MonitorTemperature {
		in coreTemp : ISQ::ThermodynamicTemperatureValue;
		in curieTemp : ISQ::ThermodynamicTemperatureValue;
		out temperatureStatus : Boolean;
		out safetyMargin : Real;
	}
	
	action def TransformerOperation {
		first start;
		then merge operationLoop;
		
		then action calculateLoss : CalculateCoreLoss {
			in fluxDensity;
			in frequency;
			in coreMass;
			in lossFactor;
			out coreLoss;
		}
		
		then action transform : TransformVoltage {
			in inputVoltage;
			in inputCurrent;
			in turnsRatio;
			out outputVoltage;
			out outputCurrent;
		}
		
		then action checkTemp : MonitorTemperature {
			in coreTemp;
			in curieTemp;
			out temperatureStatus;
			out safetyMargin;
		}
		
		then decide;
			if checkTemp.temperatureStatus == true then continueOperation;
			if checkTemp.temperatureStatus == false then shutdown;
		
		action continueOperation;
		then operationLoop;
		
		action shutdown {
			doc /* Emergency shutdown to prevent core damage */
		}
		then done;
	}
	
	attribute def PowerApplied;
	attribute def FaultCleared;
	attribute def PowerRemoved;
	
	state def TransformerStates {
		in attribute fluxStabilized : Boolean;
		in attribute loadCurrent : ISQ::ElectricCurrentValue;
		in attribute ratedCurrent : ISQ::ElectricCurrentValue;
		in attribute coreTemperature : ISQ::ThermodynamicTemperatureValue;
		in attribute maxTemperature : ISQ::ThermodynamicTemperatureValue;
		
		entry; then offline;
		
		state offline {
			doc /* Transformer de-energized, no power flow */
		}
		
		transition offline_to_startup
			first offline
			accept at PowerApplied
			then startup;
		
		state startup {
			doc /* Initial energization, flux building in core */
			entry action initializeFlux;
		}
		
		transition startup_to_normal
			first startup
			if fluxStabilized == true
			then normalOperation;
		
		state normalOperation {
			doc /* Steady-state power transformation with low core losses */
			do action transformPower;
			do action dissipateHeat;
		}
		
		transition normal_to_overload
			first normalOperation
			if loadCurrent > ratedCurrent
			then overload;
		
		state overload {
			doc /* Excessive load causing increased losses and heating */
			entry action reduceLoad;
		}
		
		transition overload_to_normal
			first overload
			if loadCurrent <= ratedCurrent
			then normalOperation;
		
		transition overload_to_fault
			first overload
			if coreTemperature > maxTemperature
			then fault;
		
		state fault {
			doc /* Protection activated due to thermal or electrical fault */
			entry action tripProtection;
		}
		
		transition fault_to_offline
			first fault
			accept at FaultCleared
			then offline;
		
		transition normal_to_offline
			first normalOperation
			accept at PowerRemoved
			then offline;
	}
	
	requirement def LowCoreLossRequirement {
		doc /* 
		The amorphous metal core shall minimize energy losses during 
		magnetic flux cycling to achieve high efficiency
		*/
		
		subject core : AmorphousMetalCore;
		
		require constraint lossConstraint {
			core.coreLossFactor <= 0.25
		}
	}
	
	requirement def HighPermeabilityRequirement {
		doc /* 
		The amorphous metal core shall provide high magnetic permeability
		to enable efficient magnetic coupling
		*/
		
		subject core : AmorphousMetalCore;
		
		require constraint permeabilityConstraint {
			core.magneticPermeability >= 10000.0
		}
	}
	
	requirement def ThermalStabilityRequirement {
		doc /* 
		The core temperature shall remain below the Curie temperature
		to maintain magnetic properties during operation
		*/
		
		subject core : AmorphousMetalCore;
		
		require constraint temperatureConstraint {
			core.thermal.heatOut.temperature < core.curieTempValue
		}
	}
	
	requirement def EfficientPowerTransformationRequirement {
		doc /* 
		The system shall transform electrical power between voltage levels
		with minimal energy loss using amorphous metal core technology
		*/
		
		assume constraint inputPowerAvailable;
		require constraint lowCoreLoss : LowCoreLossRequirement;
		require constraint highPermeability : HighPermeabilityRequirement;
		require constraint thermalStability : ThermalStabilityRequirement;
	}
	
	part amorphousMetalTransformer {
		doc /* 
		Primary Function: Efficiently transform electrical power between different 
		voltage levels using an amorphous metal core. The non-crystalline atomic 
		structure of the amorphous metal provides superior magnetic properties 
		compared to conventional crystalline transformer cores, resulting in 
		significantly reduced core losses (typically 70-80% lower), higher 
		magnetic permeability, and improved energy efficiency. This makes the 
		system ideal for power distribution applications where minimizing energy 
		waste and operational costs is critical.
		*/
		
		attribute ratedPower : ISQ::PowerValue;
		attribute primaryVoltage : ISQ::ElectricPotentialValue;
		attribute secondaryVoltage : ISQ::ElectricPotentialValue;
		attribute efficiency : Real;
		attribute turnsRatio : Real;
		
		part core : AmorphousMetalCore {
			attribute :>> atomicStructure;
			attribute :>> magneticPermeability = 12000.0;
			attribute :>> saturationFluxDensity = 1.56 [SI::T];
			attribute :>> coreLossFactor = 0.22;
			attribute :>> mass = 45.0 [SI::kg];
			attribute :>> curieTempValue = 688.0 [SI::K];
		}
		
		part primary : PrimaryWinding {
			attribute :>> numberOfTurns = 1200;
			attribute :>> wireResistance = 0.85;
			attribute :>> ratedCurrent = 25.0 [SI::A];
		}
		
		part secondary : SecondaryWinding {
			attribute :>> numberOfTurns = 120;
			attribute :>> wireResistance = 0.012;
			attribute :>> ratedCurrent = 250.0 [SI::A];
		}
		
		part cooling : CoolingSystem {
			attribute :>> coolingCapacity = 500.0 [SI::W];
			attribute :>> ambientTemperature = 298.0 [SI::K];
		}
		
		part protection : ProtectionCircuit {
			attribute :>> overloadThreshold = 275.0 [SI::A];
			attribute :>> overvoltageThreshold = 260.0 [SI::V];
		}
		
		connect primary.magnetic to core.magneticInput;
		connect core.magneticOutput to secondary.magnetic;
		connect core.thermal to cooling.thermalInput;
		connect secondary.electrical to protection.monitor;
		
		perform action operation : TransformerOperation {
			in fluxDensity = core.magneticInput.fluxIn.fluxDensity;
			in frequency = core.magneticInput.fluxIn.frequency;
			in coreMass = core.mass;
			in lossFactor = core.coreLossFactor;
			in inputVoltage = primary.electrical.powerIn.voltage;
			in inputCurrent = primary.electrical.powerIn.current;
			in turnsRatio = primary.numberOfTurns / secondary.numberOfTurns;
			in coreTemp = core.thermal.heatOut.temperature;
			in curieTemp = core.curieTempValue;
		}
		
		exhibit state operatingStates : TransformerStates {
			in fluxStabilized = true;
			in loadCurrent = secondary.electrical.powerOut.current;
			in ratedCurrent = secondary.ratedCurrent;
			in coreTemperature = core.thermal.heatOut.temperature;
			in maxTemperature = core.curieTempValue;
		}
		
		satisfy requirement powerTransformationReq : EfficientPowerTransformationRequirement 
			by amorphousMetalTransformer;
	}
}
