package 'HEALS System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def EmissivityValue :> Real;
	attribute def LuminousFluxValue :> ISQ::LuminousFluxValue;
	attribute def SpectralRadianceValue :> Real;
	attribute def AluminumConcentrationValue :> Real;
	attribute def QuantumEfficiencyValue :> Real;
	
	attribute def SubstrateComposition {
		attribute aluminumContent : AluminumConcentrationValue;
		attribute phosphorDopant : Real;
		attribute matrixMaterial : String;
	}
	
	attribute def OpticalCharacteristics {
		attribute emissivity : EmissivityValue;
		attribute peakEmissionWavelength : ISQ::LengthValue;
		attribute quantumEfficiency : QuantumEfficiencyValue;
		attribute spectralBandwidth : ISQ::LengthValue;
	}
	
	attribute def ThermalCharacteristics {
		attribute operatingTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute thermalConductivity : Real;
		attribute maxSurfaceTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	item def ElectricalExcitation;
	item def OpticalRadiation;
	item def ThermalLoad;
	
	port def ExcitationPort {
		in item excitation : ElectricalExcitation;
		in attribute voltage : ISQ::ElectricPotentialDifferenceValue;
		in attribute current : ISQ::ElectricCurrentValue;
	}
	
	port def EmissionPort {
		out item radiation : OpticalRadiation;
		out attribute luminousFlux : LuminousFluxValue;
		out attribute spectralRadiance : SpectralRadianceValue;
	}
	
	port def ThermalInterfacePort {
		out item thermalEnergy : ThermalLoad;
		out attribute heatFlux : ISQ::PowerValue;
		out attribute surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	part def AluminumReflectorLayer {
		attribute thickness : ISQ::LengthValue;
		attribute reflectance : Real;
		attribute thermalConductivity : Real;
		
		port thermalPort : ThermalInterfacePort;
	}
	
	part def LuminescentPhosphorLayer {
		attribute composition : SubstrateComposition;
		attribute opticalProperties : OpticalCharacteristics;
		attribute layerThickness : ISQ::LengthValue;
		
		port excitationIn : ExcitationPort;
		port emissionOut : EmissionPort;
		port thermalOut : ThermalInterfacePort;
	}
	
	part def EncapsulationLayer {
		attribute material : String;
		attribute opticalTransmittance : Real;
		attribute thermalResistance : Real;
	}
	
	part def ThermalManagementSubsystem {
		attribute heatSinkArea : ISQ::AreaValue;
		attribute coolantFlowRate : Real;
		
		port thermalIn : ThermalInterfacePort;
	}
	
	part def PowerSupplyUnit {
		attribute outputVoltage : ISQ::ElectricPotentialDifferenceValue;
		attribute outputCurrent : ISQ::ElectricCurrentValue;
		attribute efficiency : Real;
		
		port powerOut : ExcitationPort;
	}
	
	part def HEALS_System {
		doc /* 
		 * A high-performance solid-state lighting system utilizing an aluminiferous
		 * luminescent substrate with enhanced thermal emissivity. The system converts
		 * electrical energy into high-intensity optical radiation while efficiently
		 * managing thermal loads through radiative heat dissipation. The aluminum-enhanced
		 * substrate provides superior thermal management and optical reflectivity,
		 * enabling sustained high-brightness operation.
		 */
		
		attribute systemEmissivity : EmissivityValue;
		attribute totalLuminousOutput : LuminousFluxValue;
		attribute operationalTemperature : ISQ::ThermodynamicTemperatureValue;
		attribute systemEfficiency : Real;
		
		port electricalInput : ExcitationPort;
		port opticalOutput : EmissionPort;
		
		part powerSupply : PowerSupplyUnit {
			attribute outputVoltage = 24.0 [SI::V];
			attribute outputCurrent = 2.5 [SI::A];
			attribute efficiency = 0.92;
		}
		
		part aluminumReflector : AluminumReflectorLayer {
			attribute thickness = 100.0e-6 [SI::m];
			attribute reflectance = 0.95;
			attribute thermalConductivity = 237.0;
		}
		
		part phosphorSubstrate : LuminescentPhosphorLayer {
			attribute composition : SubstrateComposition {
				attribute aluminumContent = 0.18;
				attribute phosphorDopant = 0.12;
				attribute matrixMaterial = "yttrium aluminum garnet";
			}
			attribute opticalProperties : OpticalCharacteristics {
				attribute emissivity = 0.96;
				attribute peakEmissionWavelength = 550.0e-9 [SI::m];
				attribute quantumEfficiency = 0.88;
				attribute spectralBandwidth = 80.0e-9 [SI::m];
			}
			attribute layerThickness = 200.0e-6 [SI::m];
		}
		
		part encapsulation : EncapsulationLayer {
			attribute material = "silicone composite";
			attribute opticalTransmittance = 0.94;
			attribute thermalResistance = 0.15;
		}
		
		part thermalManagement : ThermalManagementSubsystem {
			attribute heatSinkArea = 0.04 [SI::m^2];
			attribute coolantFlowRate = 0.5;
		}
		
		connect electricalInput to powerSupply.powerOut;
		connect powerSupply.powerOut to phosphorSubstrate.excitationIn;
		connect phosphorSubstrate.emissionOut to opticalOutput;
		connect phosphorSubstrate.thermalOut to aluminumReflector.thermalPort;
		connect aluminumReflector.thermalPort to thermalManagement.thermalIn;
		
		perform action operateHEALS;
	}
	
	action def AbsorbElectricalEnergy {
		in inputVoltage : ISQ::ElectricPotentialDifferenceValue;
		in inputCurrent : ISQ::ElectricCurrentValue;
		out electricalPower : ISQ::PowerValue;
	}
	
	action def ExcitePhosphor {
		in electricalPower : ISQ::PowerValue;
		in quantumEfficiency : QuantumEfficiencyValue;
		out opticalPower : ISQ::PowerValue;
		out thermalPower : ISQ::PowerValue;
	}
	
	action def EmitRadiation {
		in opticalPower : ISQ::PowerValue;
		in emissivity : EmissivityValue;
		in peakWavelength : ISQ::LengthValue;
		out luminousFlux : LuminousFluxValue;
		out spectralRadiance : SpectralRadianceValue;
	}
	
	action def ReflectOpticalEnergy {
		in incidentRadiation : LuminousFluxValue;
		in reflectance : Real;
		out enhancedOutput : LuminousFluxValue;
	}
	
	action def DissipateHeat {
		in thermalLoad : ISQ::PowerValue;
		in emissivity : EmissivityValue;
		in surfaceArea : ISQ::AreaValue;
		out surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
		out radiatedPower : ISQ::PowerValue;
	}
	
	action operateHEALS {
		doc /* 
		 * Primary operational sequence: absorb electrical energy, excite luminescent
		 * phosphor, emit high-intensity radiation, enhance output through aluminum
		 * reflection, and dissipate waste heat through high-emissivity radiative cooling.
		 */
		
		first start;
		
		then action absorbEnergy : AbsorbElectricalEnergy {
			in inputVoltage : ISQ::ElectricPotentialDifferenceValue;
			in inputCurrent : ISQ::ElectricCurrentValue;
			out electricalPower : ISQ::PowerValue;
		}
		
		then action exciteAction : ExcitePhosphor {
			in electricalPower = absorbEnergy.electricalPower;
			in quantumEfficiency = 0.88;
			out opticalPower : ISQ::PowerValue;
			out thermalPower : ISQ::PowerValue;
		}
		
		then action emit : EmitRadiation {
			in opticalPower = exciteAction.opticalPower;
			in emissivity = 0.96;
			in peakWavelength = 550.0e-9 [SI::m];
			out luminousFlux : LuminousFluxValue;
			out spectralRadiance : SpectralRadianceValue;
		}
		
		then action dissipate : DissipateHeat {
			in thermalLoad = exciteAction.thermalPower;
			in emissivity = 0.96;
			in surfaceArea = 0.04 [SI::m^2];
			out surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
			out radiatedPower : ISQ::PowerValue;
		}
		
		then action reflect : ReflectOpticalEnergy {
			in incidentRadiation = emit.luminousFlux;
			in reflectance = 0.95;
			out enhancedOutput : LuminousFluxValue;
		}
		
		then done;
	}
	
	state def HEALS_OperationalStates {
		entry; then standby;
		
		state standby {
			doc /* System powered but not emitting, substrate at ambient temperature */
		}
		
		transition standby_to_warmup
			first standby
			accept powerApplied : ElectricalExcitation
			then warmup;
		
		state warmup {
			doc /* Initial excitation phase, substrate temperature rising */
		}
		
		transition warmup_to_active
			first warmup
			if true
			then active;
		
		state active {
			doc /* Full operational state with stable emission and thermal equilibrium */
			
			state thermalRegulation {
				entry; then balancing;
				
				state balancing {
					doc /* Active thermal management to maintain optimal operating temperature */
				}
				
				transition balancing_to_equilibrium
					first balancing
					if true
					then equilibrium;
				
				state equilibrium {
					doc /* Thermal equilibrium achieved, maximum efficiency operation */
				}
				
				transition equilibrium_to_balancing
					first equilibrium
					if true
					then balancing;
			}
		}
		
		transition active_to_cooldown
			first active
			accept powerRemoved
			then cooldown;
		
		state cooldown {
			doc /* Power removed, substrate cooling via radiative heat dissipation */
		}
		
		transition cooldown_to_standby
			first cooldown
			if true
			then standby;
		
		state overtemperature {
			doc /* Thermal protection state, emission reduced or halted */
		}
		
		transition active_to_overtemperature
			first active
			if true
			then overtemperature;
		
		transition overtemperature_to_cooldown
			first overtemperature
			accept thermalShutdown
			then cooldown;
	}
	
	requirement def EmissivityRequirement {
		doc /* The substrate shall maintain emissivity above 0.92 across operational range */
		
		subject substrate : HEALS_System;
		
		require constraint {
			substrate.systemEmissivity >= 0.92
		}
	}
	
	requirement def OpticalEfficiencyRequirement {
		doc /* The system shall achieve minimum 80% quantum efficiency for energy conversion */
		
		subject substrate : HEALS_System;
		
		require constraint {
			substrate.phosphorSubstrate.opticalProperties.quantumEfficiency >= 0.80
		}
	}
	
	requirement def ThermalStabilityRequirement {
		doc /* The substrate shall operate continuously at temperatures up to 127°C (400K) */
		
		subject substrate : HEALS_System;
		
		require constraint {
			substrate.operationalTemperature <= 400.0 [SI::K]
		}
	}
	
	requirement def AluminumContentRequirement {
		doc /* The substrate shall contain 15-20% aluminum by composition for optimal thermal and optical performance */
		
		subject substrate : HEALS_System;
		
		require constraint {
			substrate.phosphorSubstrate.composition.aluminumContent >= 0.15 and
			substrate.phosphorSubstrate.composition.aluminumContent <= 0.20
		}
	}
	
	requirement def LuminousOutputRequirement {
		doc /* The system shall deliver minimum 5000 lumens luminous flux at rated power */
		
		subject substrate : HEALS_System;
		
		require constraint {
			substrate.totalLuminousOutput >= 5000.0 [SI::lm]
		}
	}
	
	requirement <'HEALS-SYS-REQ-001'> primaryFunctionRequirement {
		doc /* 
		 * The High Emissivity Aluminiferous Luminescent Substrate System shall
		 * efficiently convert electrical energy into high-intensity optical radiation
		 * while maintaining thermal stability through enhanced radiative heat dissipation.
		 * The aluminum-enhanced substrate provides superior thermal management and optical
		 * performance for sustained high-brightness operation in demanding applications.
		 */
		
		subject healsSystem : HEALS_System;
		
		require emissivitySpec : EmissivityRequirement;
		require opticalEfficiency : OpticalEfficiencyRequirement;
		require thermalStability : ThermalStabilityRequirement;
		require aluminumContent : AluminumContentRequirement;
		require luminousOutput : LuminousOutputRequirement;
		
		assume constraint operatingConditions {
			doc /* System operates within controlled environmental conditions */
			healsSystem.operationalTemperature >= 273.15 [SI::K] and
			healsSystem.operationalTemperature <= 400.0 [SI::K]
		}
		
		assume constraint powerQuality {
			doc /* Input electrical power meets quality specifications */
			healsSystem.powerSupply.outputVoltage >= 20.0 [SI::V] and
			healsSystem.powerSupply.outputVoltage <= 28.0 [SI::V]
		}
	}
}
