package ConductivePolymerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ElectricalConductivityValue :> Real;
	attribute def DopingConcentrationValue :> Real;
	attribute def ChargeCarrierDensityValue :> Real;
	
	item def ElectricalSignal {
		attribute voltage : ISQ::ElectricPotentialDifferenceValue;
		attribute current : ISQ::ElectricCurrentValue;
		attribute resistance : Real;
	}
	
	item def DopantMaterial {
		attribute concentration : DopingConcentrationValue;
		attribute ionizationEfficiency : Real;
	}
	
	item def ChargeCarrier {
		attribute density : ChargeCarrierDensityValue;
		attribute mobility : Real;
	}
	
	port def ElectricalPort {
		attribute voltage : ISQ::ElectricPotentialDifferenceValue;
		attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def ThermalPort {
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
		attribute heatFlux : ISQ::PowerValue;
	}
	
	part def PolymerChain {
		attribute chainLength : ISQ::LengthValue;
		attribute conjugationDegree : Real;
		attribute structuralOrder : Real;
	}
	
	part def DopingAgent {
		attribute dopantType : ScalarValues::String;
		attribute dopingLevel : DopingConcentrationValue;
		ref item dopant : DopantMaterial;
		
		action def IntroduceDopant {
			in targetConcentration : DopingConcentrationValue;
			out actualConcentration : DopingConcentrationValue;
		}
	}
	
	part def ConductionMechanism {
		attribute carrierDensity : ChargeCarrierDensityValue;
		attribute conductivity : ElectricalConductivityValue;
		ref item carriers : ChargeCarrier;
		
		action def TransportCharge {
			in appliedField : ISQ::ElectricFieldStrengthValue;
			out currentDensity : Real;
		}
	}
	
	part def EnvironmentalControl {
		attribute ambientTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute humidity : Real;
		port thermalInterface : ThermalPort;
		
		action def RegulateConditions {
			in targetTemperature : ISQ::ThermodynamicTemperatureValue;
			out stabilizedTemperature : ISQ::ThermodynamicTemperatureValue;
		}
	}
	
	state def ConductivePolymerState {
		entry action initializeState;
		
		state undoped {
			doc /* Polymer in insulating state with minimal conductivity */
			entry action setInsulating;
		}
		
		state lightlyDoped {
			doc /* Polymer with low doping showing semiconducting behavior */
			entry action setSemiconducting;
		}
		
		state heavilyDoped {
			doc /* Polymer with high doping showing metallic conductivity */
			entry action setMetallic;
		}
		
		state degraded {
			doc /* Polymer structure compromised, conductivity lost */
			entry action setDegraded;
		}
		
		transition undopedToLightlyDoped
			first undoped
			then lightlyDoped;
		
		transition lightlyDopedToHeavilyDoped
			first lightlyDoped
			then heavilyDoped;
		
		transition heavilyDopedToLightlyDoped
			first heavilyDoped
			then lightlyDoped;
		
		transition lightlyDopedToUndoped
			first lightlyDoped
			then undoped;
		
		transition undopedToDegraded
			first undoped
			then degraded;
		
		transition lightlyDopedToDegraded
			first lightlyDoped
			then degraded;
		
		transition heavilyDopedToDegraded
			first heavilyDoped
			then degraded;
	}
	
	action def InitializePolymer {
		in polymerType : ScalarValues::String;
		in chainLength : ISQ::LengthValue;
		out initializedChain : PolymerChain;
	}
	
	action def ApplyDoping {
		in polymer : PolymerChain;
		in dopant : DopantMaterial;
		in targetLevel : DopingConcentrationValue;
		out dopedPolymer : PolymerChain;
		out achievedDoping : DopingConcentrationValue;
	}
	
	action def MeasureConductivity {
		in polymer : PolymerChain;
		in appliedVoltage : ISQ::ElectricPotentialDifferenceValue;
		in temperature : ISQ::ThermodynamicTemperatureValue;
		out conductivity : ElectricalConductivityValue;
		out current : ISQ::ElectricCurrentValue;
	}
	
	action def StabilizeEnvironment {
		in currentTemperature : ISQ::ThermodynamicTemperatureValue;
		in targetTemperature : ISQ::ThermodynamicTemperatureValue;
		in currentHumidity : Real;
		out stabilizedTemperature : ISQ::ThermodynamicTemperatureValue;
		out stabilizedHumidity : Real;
	}
	
	action def ConductElectricity {
		doc /* Primary operational behavior of the conductive polymer system */
		
		in polymerType : ScalarValues::String;
		in chainLength : ISQ::LengthValue;
		in dopant : DopantMaterial;
		in targetLevel : DopingConcentrationValue;
		in currentTemperature : ISQ::ThermodynamicTemperatureValue;
		in targetTemperature : ISQ::ThermodynamicTemperatureValue;
		in currentHumidity : Real;
		in appliedVoltage : ISQ::ElectricPotentialDifferenceValue;
		in requiredConductivity : ElectricalConductivityValue;
		
		first start;
		
		then action initialize : InitializePolymer {
			in polymerType = ConductElectricity::polymerType;
			in chainLength = ConductElectricity::chainLength;
			out initializedChain;
		}
		
		then action dope : ApplyDoping {
			in polymer = initialize.initializedChain;
			in dopant = ConductElectricity::dopant;
			in targetLevel = ConductElectricity::targetLevel;
			out dopedPolymer;
			out achievedDoping;
		}
		
		then action stabilize : StabilizeEnvironment {
			in currentTemperature = ConductElectricity::currentTemperature;
			in targetTemperature = ConductElectricity::targetTemperature;
			in currentHumidity = ConductElectricity::currentHumidity;
			out stabilizedTemperature;
			out stabilizedHumidity;
		}
		
		then merge operationLoop;
		
		then action measure : MeasureConductivity {
			in polymer = dope.dopedPolymer;
			in appliedVoltage = ConductElectricity::appliedVoltage;
			in temperature = stabilize.stabilizedTemperature;
			out conductivity;
			out current;
		}
		
		then decide;
			if measure.conductivity >= ConductElectricity::requiredConductivity then maintainOperation;
			if measure.conductivity < ConductElectricity::requiredConductivity then operationLoop;
		
		action maintainOperation;
		then done;
	}
	
	part def ConductivePolymerSystem {
		doc /* 
		 * A conductive polymer system that enables electrical conductivity in organic 
		 * polymer materials through controlled chemical doping. The system's primary 
		 * function is to facilitate charge transport along polymer chains by introducing 
		 * charge carriers through oxidation or reduction, creating a material that 
		 * combines the mechanical properties of polymers with electrical conductivity 
		 * for applications in flexible electronics, sensors, actuators, and energy storage.
		 */
		
		attribute requiredConductivity : ElectricalConductivityValue;
		attribute operatingVoltage : ISQ::ElectricPotentialDifferenceValue;
		attribute systemEfficiency : Real;
		
		ref item polymerMaterial : PolymerChain {
			attribute chainLength = 1000.0;
			attribute conjugationDegree = 0.85;
			attribute structuralOrder = 0.75;
		}
		
		ref item dopantMaterial : DopantMaterial {
			attribute concentration = 0.05;
			attribute ionizationEfficiency = 0.92;
		}
		
		ref item chargeCarriers : ChargeCarrier {
			attribute density = 1.0e21;
			attribute mobility = 0.1;
		}
		
		part dopingSystem : DopingAgent {
			attribute dopantType = "p-type";
			attribute dopingLevel = 0.05;
			ref item :>> dopant = conductivePolymerSystem.dopantMaterial;
		}
		
		part conductionPath : ConductionMechanism {
			attribute carrierDensity = 1.0e21;
			attribute conductivity = 100.0;
			ref item :>> carriers = conductivePolymerSystem.chargeCarriers;
		}
		
		part environmentalController : EnvironmentalControl {
			attribute ambientTemperature = 298.15;
			attribute humidity = 0.40;
		}
		
		port positiveElectrode : ElectricalPort {
			attribute voltage = 5.0;
		}
		
		port negativeElectrode : ElectricalPort {
			attribute voltage = 0.0;
		}
		
		port thermalInterface : ThermalPort {
			attribute temperature = 298.15;
		}
		
		connection thermalCoupling 
			connect environmentalController.thermalInterface to thermalInterface;
		
		perform action operateConductivePolymer : ConductElectricity {
			in polymerType = "polyaniline";
			in chainLength = conductivePolymerSystem.polymerMaterial.chainLength;
			in dopant = conductivePolymerSystem.dopantMaterial;
			in targetLevel = conductivePolymerSystem.dopingSystem.dopingLevel;
			in currentTemperature = conductivePolymerSystem.environmentalController.ambientTemperature;
			in targetTemperature = 298.15;
			in currentHumidity = conductivePolymerSystem.environmentalController.humidity;
			in appliedVoltage = conductivePolymerSystem.operatingVoltage;
			in requiredConductivity = conductivePolymerSystem.requiredConductivity;
		}
		
		exhibit state polymerState : ConductivePolymerState;
	}
	
	requirement def MinimumConductivityRequirement {
		doc /* The conductive polymer system shall achieve minimum electrical conductivity of 10 S/m */
		subject polymer : ConductivePolymerSystem;
		require constraint {
			polymer.conductionPath.conductivity >= 10.0
		}
	}
	
	requirement def DopingStabilityRequirement {
		doc /* The doping level shall remain stable within ±5% over operational lifetime */
		subject dopingSystem : DopingAgent;
		require constraint {
			dopingSystem.dopingLevel >= 0.0475 and dopingSystem.dopingLevel <= 0.0525
		}
	}
	
	requirement def TemperatureRangeRequirement {
		doc /* The system shall operate within temperature range of 273K to 373K */
		subject envControl : EnvironmentalControl;
		require constraint {
			envControl.ambientTemperature >= 273.15 and 
			envControl.ambientTemperature <= 373.15
		}
	}
	
	requirement def ChargeTransportRequirement {
		doc /* The system shall maintain charge carrier mobility above 0.01 cm²/V·s */
		subject conduction : ConductionMechanism;
		require constraint {
			conduction.carriers.mobility >= 0.01
		}
	}
	
	requirement systemRequirements {
		doc /* Overall requirements for conductive polymer system operation */
		subject system : ConductivePolymerSystem;
		require conductivityReq : MinimumConductivityRequirement {
			subject polymer = system;
		}
		require dopingReq : DopingStabilityRequirement {
			subject dopingSystem = system.dopingSystem;
		}
		require temperatureReq : TemperatureRangeRequirement {
			subject envControl = system.environmentalController;
		}
		require transportReq : ChargeTransportRequirement {
			subject conduction = system.conductionPath;
		}
	}
	
	part conductivePolymerSystem : ConductivePolymerSystem {
		attribute requiredConductivity = 100.0;
		attribute operatingVoltage = 5.0;
		attribute systemEfficiency = 0.88;
		
		satisfy systemRequirements by conductivePolymerSystem;
	}
}
