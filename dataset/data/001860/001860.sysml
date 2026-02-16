package SiliconeRubberSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ElasticModulus :> ISQ::PressureValue;
	attribute def Elongation :> Real;
	attribute def HardnessShoreA :> Real;
	attribute def TearStrength :> ISQ::PressureValue;
	
	attribute def MaterialComposition {
		attribute polymerType : String;
		attribute fillerContent : Real;
		attribute crosslinkDensity : Real;
		attribute additivePackage : String;
	}
	
	attribute def TemperatureRange {
		attribute minOperatingTemp : ISQ::ThermodynamicTemperatureValue;
		attribute maxOperatingTemp : ISQ::ThermodynamicTemperatureValue;
	}
	
	attribute def MechanicalProperties {
		attribute tensileStrength : ISQ::PressureValue;
		attribute elongationAtBreak : Elongation;
		attribute hardness : HardnessShoreA;
		attribute tearStrength : TearStrength;
		attribute compressionSet : Real;
	}
	
	item def SiliconePolymerBase {
		attribute molecularWeight : Real;
		attribute viscosity : Real;
		attribute functionalGroups : String;
	}
	
	item def ReinforcingFiller {
		attribute particleSize : ISQ::LengthValue;
		attribute surfaceArea : Real;
		attribute loadingPercentage : Real;
	}
	
	item def CuringAgent {
		attribute catalystType : String;
		attribute concentration : Real;
		attribute activationTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def MechanicalLoadPort {
		in attribute appliedForce : ISQ::ForceValue;
		in attribute appliedStrain : Real;
		out attribute resultingStress : ISQ::PressureValue;
		out attribute deformation : ISQ::LengthValue;
	}
	
	port def ThermalPort {
		in attribute ambientTemperature : ISQ::ThermodynamicTemperatureValue;
		in attribute heatFlux : ISQ::HeatFlowRateValue;
		out attribute surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def ChemicalExposurePort {
		in attribute exposedSubstance : String;
		in attribute exposureDuration : ISQ::TimeValue;
		out attribute degradationLevel : Real;
	}
	
	part def SiliconeRubberMaterial {
		attribute composition : MaterialComposition {
			attribute :>> polymerType = "Polydimethylsiloxane";
			attribute :>> fillerContent = 0.25;
			attribute :>> crosslinkDensity = 0.15;
			attribute :>> additivePackage = "Heat Stabilizers and Pigments";
		}
		
		attribute operatingRange : TemperatureRange {
			attribute :>> minOperatingTemp = 213.15 [K];
			attribute :>> maxOperatingTemp = 523.15 [K];
		}
		
		attribute mechanicalProps : MechanicalProperties {
			attribute :>> tensileStrength = 8500000.0 [Pa];
			attribute :>> elongationAtBreak = 450.0;
			attribute :>> hardness = 55.0;
			attribute :>> tearStrength = 25000.0 [N/m];
			attribute :>> compressionSet = 18.0;
		}
		
		part polymerBase : SiliconePolymerBase {
			attribute :>> molecularWeight = 450000.0;
			attribute :>> viscosity = 50000.0;
			attribute :>> functionalGroups = "Vinyl-terminated";
		}
		
		part filler : ReinforcingFiller {
			attribute :>> particleSize = 12.0e-9 [m];
			attribute :>> surfaceArea = 200.0;
			attribute :>> loadingPercentage = 25.0;
		}
		
		part curingSystem : CuringAgent {
			attribute :>> catalystType = "Platinum-based";
			attribute :>> concentration = 0.015;
			attribute :>> activationTemperature = 393.15 [K];
		}
		
		port mechanicalInterface : MechanicalLoadPort;
		port thermalInterface : ThermalPort;
		port chemicalInterface : ChemicalExposurePort;
	}
	
	action def MixRawMaterials {
		in polymer : SiliconePolymerBase;
		in filler : ReinforcingFiller;
		in curingAgent : CuringAgent;
		out uncuredCompound : SiliconeRubberMaterial;
	}
	
	action def HeatCure {
		in compound : SiliconeRubberMaterial;
		in curingTemperature : ISQ::ThermodynamicTemperatureValue;
		in curingTime : ISQ::TimeValue;
		out curedMaterial : SiliconeRubberMaterial;
	}
	
	action def PostCure {
		in curedMaterial : SiliconeRubberMaterial;
		in postCureTemp : ISQ::ThermodynamicTemperatureValue;
		in postCureTime : ISQ::TimeValue;
		out finalMaterial : SiliconeRubberMaterial;
	}
	
	action def InspectProperties {
		in material : SiliconeRubberMaterial;
		out tensileTest : ISQ::PressureValue;
		out hardnessTest : HardnessShoreA;
		out elongationTest : Elongation;
	}
	
	action def ManufactureSiliconeRubber {
		in rawPolymer : SiliconePolymerBase;
		in rawFiller : ReinforcingFiller;
		in rawCuringAgent : CuringAgent;
		in primaryCureTemp : ISQ::ThermodynamicTemperatureValue;
		in primaryCureTime : ISQ::TimeValue;
		in secondaryCureTemp : ISQ::ThermodynamicTemperatureValue;
		in secondaryCureTime : ISQ::TimeValue;
		out finishedProduct : SiliconeRubberMaterial;
		
		first start;
		then action mix : MixRawMaterials {
			in polymer = rawPolymer;
			in filler = rawFiller;
			in curingAgent = rawCuringAgent;
			out uncuredCompound;
		}
		then action primaryCure : HeatCure {
			in compound = mix.uncuredCompound;
			in curingTemperature = primaryCureTemp;
			in curingTime = primaryCureTime;
			out curedMaterial;
		}
		then action secondaryCure : PostCure {
			in curedMaterial = primaryCure.curedMaterial;
			in postCureTemp = secondaryCureTemp;
			in postCureTime = secondaryCureTime;
			out finalMaterial;
		}
		then action inspect : InspectProperties {
			in material = secondaryCure.finalMaterial;
			out tensileTest;
			out hardnessTest;
			out elongationTest;
		}
		then assign finishedProduct := secondaryCure.finalMaterial;
		then done;
	}
	
	state def SiliconeRubberLifecycle {
		entry; then rawMaterial;
		
		state rawMaterial;
		
		transition rawMaterial_to_mixing
			first rawMaterial
			accept MixingStartEvent
			then mixing;
		
		state mixing;
		
		transition mixing_to_curing
			first mixing
			accept CuringStartEvent
			then curing;
		
		state curing;
		
		transition curing_to_postCuring
			first curing
			accept PostCuringStartEvent
			then postCuring;
		
		state postCuring;
		
		transition postCuring_to_ready
			first postCuring
			accept CuringCompleteEvent
			then ready;
		
		state ready;
		
		transition ready_to_inService
			first ready
			accept DeploymentEvent
			then inService;
		
		state inService;
		
		transition inService_to_aging
			first inService
			accept AgingEvent
			then aging;
		
		state aging;
		
		transition aging_to_endOfLife
			first aging
			accept FailureEvent
			then endOfLife;
		
		state endOfLife;
	}
	
	part def SiliconeRubberSeal {
		attribute sealGeometry : String;
		attribute crossSectionDiameter : ISQ::LengthValue;
		attribute innerDiameter : ISQ::LengthValue;
		attribute compressionRatio : Real;
		
		part material : SiliconeRubberMaterial;
		
		port mechanicalLoad : MechanicalLoadPort;
		port thermalConditions : ThermalPort;
		
		perform action provideSealing {
			in fluidPressure : ISQ::PressureValue;
			in operatingTemperature : ISQ::ThermodynamicTemperatureValue;
			in compressionForce : ISQ::ForceValue;
			out sealEffectiveness : Real;
			
			first start;
			then action checkOperatingConditions {
				in pressure = fluidPressure;
				in temperature = operatingTemperature;
				out conditionsValid : Boolean;
			}
			then decide;
				if checkOperatingConditions.conditionsValid then maintainSeal;
				if not checkOperatingConditions.conditionsValid then degradedSeal;
			action maintainSeal {
				assign sealEffectiveness := 0.99;
			}
			then done;
			action degradedSeal {
				assign sealEffectiveness := 0.70;
			}
			then done;
		}
	}
	
	part def SiliconeRubberGasket {
		attribute gasketThickness : ISQ::LengthValue;
		attribute gasketArea : ISQ::AreaValue;
		attribute boltTorque : ISQ::TorqueValue;
		
		part material : SiliconeRubberMaterial;
		
		port mechanicalLoad : MechanicalLoadPort;
		port thermalConditions : ThermalPort;
		
		perform action preventLeakage {
			in interfacePressure : ISQ::PressureValue;
			in surfaceTemperature : ISQ::ThermodynamicTemperatureValue;
			out leakageRate : Real;
			
			first start;
			then action evaluateInterface {
				in pressure = interfacePressure;
				in temperature = surfaceTemperature;
				out interfaceIntegrity : Boolean;
			}
			then decide;
				if evaluateInterface.interfaceIntegrity then noLeak;
				if not evaluateInterface.interfaceIntegrity then minorLeak;
			action noLeak {
				assign leakageRate := 0.0;
			}
			then done;
			action minorLeak {
				assign leakageRate := 0.02;
			}
			then done;
		}
	}
	
	part def SiliconeRubberHose {
		attribute hoseLength : ISQ::LengthValue;
		attribute innerDiameter : ISQ::LengthValue;
		attribute wallThickness : ISQ::LengthValue;
		attribute burstPressure : ISQ::PressureValue;
		
		part material : SiliconeRubberMaterial;
		
		port inletPort : MechanicalLoadPort;
		port outletPort : MechanicalLoadPort;
		port thermalConditions : ThermalPort;
		
		perform action conveyFluid {
			in flowRate : ISQ::VolumeFlowRateValue;
			in fluidTemperature : ISQ::ThermodynamicTemperatureValue;
			in internalPressure : ISQ::PressureValue;
			out flowEfficiency : Real;
			
			first start;
			then action checkPressureLimits {
				in pressure = internalPressure;
				out withinLimits : Boolean;
			}
			then decide;
				if checkPressureLimits.withinLimits then normalFlow;
				if not checkPressureLimits.withinLimits then restrictedFlow;
			action normalFlow {
				assign flowEfficiency := 0.95;
			}
			then done;
			action restrictedFlow {
				assign flowEfficiency := 0.60;
			}
			then done;
		}
	}
	
	part siliconeRubberSystem : SiliconeRubberMaterial {
		doc /* 
		This system represents a high-performance silicone rubber material engineered 
		for demanding sealing, gasketing, and fluid transfer applications. Its primary 
		function is to provide reliable, flexible, and durable elastomeric performance 
		across extreme temperature ranges while maintaining chemical resistance and 
		mechanical integrity.
		
		The system operates by leveraging the unique molecular structure of crosslinked 
		silicone polymers, which exhibit exceptional thermal stability, low-temperature 
		flexibility, and resistance to oxidation and ozone. When subjected to mechanical 
		loads, thermal cycling, and chemical exposure, the material maintains its elastic 
		properties through its stable Si-O backbone and controlled crosslink density.
		
		The manufacturing process involves precise mixing of polymer base, reinforcing 
		fillers, and curing agents, followed by controlled heat curing and post-curing 
		to achieve optimal mechanical properties and dimensional stability.
		*/
		
		part :>> polymerBase {
			attribute :>> molecularWeight = 500000.0;
			attribute :>> viscosity = 55000.0;
			attribute :>> functionalGroups = "Vinyl-terminated PDMS";
		}
		
		part :>> filler {
			attribute :>> particleSize = 10.0e-9 [m];
			attribute :>> surfaceArea = 220.0;
			attribute :>> loadingPercentage = 28.0;
		}
		
		part :>> curingSystem {
			attribute :>> catalystType = "Platinum-Karstedt";
			attribute :>> concentration = 0.018;
			attribute :>> activationTemperature = 388.15 [K];
		}
		
		part sealComponent : SiliconeRubberSeal {
			attribute :>> sealGeometry = "O-Ring";
			attribute :>> crossSectionDiameter = 0.0035 [m];
			attribute :>> innerDiameter = 0.025 [m];
			attribute :>> compressionRatio = 0.20;
		}
		
		part gasketComponent : SiliconeRubberGasket {
			attribute :>> gasketThickness = 0.002 [m];
			attribute :>> gasketArea = 0.005 [m^2];
			attribute :>> boltTorque = 15.0 [N*m];
		}
		
		part hoseComponent : SiliconeRubberHose {
			attribute :>> hoseLength = 0.5 [m];
			attribute :>> innerDiameter = 0.012 [m];
			attribute :>> wallThickness = 0.003 [m];
			attribute :>> burstPressure = 2500000.0 [Pa];
		}
		
		perform action operateAsElastomericSystem {
			in environmentalTemp : ISQ::ThermodynamicTemperatureValue;
			in mechanicalLoad : ISQ::ForceValue;
			in chemicalExposure : String;
			out systemPerformance : Real;
			
			first start;
			then action assessConditions {
				in temperature = environmentalTemp;
				in load = mechanicalLoad;
				in exposure = chemicalExposure;
				out conditionsAcceptable : Boolean;
			}
			then decide;
				if assessConditions.conditionsAcceptable then normalOperation;
				if not assessConditions.conditionsAcceptable then degradedOperation;
			action normalOperation {
				action sealOperation references sealComponent.provideSealing;
				action gasketOperation references gasketComponent.preventLeakage;
				action hoseOperation references hoseComponent.conveyFluid;
				assign systemPerformance := 0.96;
			}
			then done;
			action degradedOperation {
				assign systemPerformance := 0.75;
			}
			then done;
		}
	}
	
	requirement def TemperatureStabilityRequirement {
		doc /* The silicone rubber shall maintain mechanical properties across specified temperature range. */
		require constraint {
			siliconeRubberSystem.operatingRange.minOperatingTemp <= 218.15 [K] and
			siliconeRubberSystem.operatingRange.maxOperatingTemp >= 503.15 [K]
		}
	}
	
	requirement def MechanicalPerformanceRequirement {
		doc /* The silicone rubber shall provide adequate tensile strength and elongation for sealing applications. */
		require constraint {
			siliconeRubberSystem.mechanicalProps.tensileStrength >= 7000000.0 [Pa] and
			siliconeRubberSystem.mechanicalProps.elongationAtBreak >= 400.0 and
			siliconeRubberSystem.mechanicalProps.hardness >= 50.0 and
			siliconeRubberSystem.mechanicalProps.hardness <= 60.0
		}
	}
	
	requirement def ChemicalResistanceRequirement {
		doc /* The silicone rubber shall resist degradation from oils, water, and ozone exposure. */
		require constraint {
			siliconeRubberSystem.composition.polymerType == "Polydimethylsiloxane" and
			siliconeRubberSystem.composition.additivePackage == "Heat Stabilizers and Pigments"
		}
	}
	
	requirement def CompressionSetRequirement {
		doc /* The silicone rubber shall exhibit low compression set for long-term sealing reliability. */
		require constraint {
			siliconeRubberSystem.mechanicalProps.compressionSet <= 25.0
		}
	}
	
	requirement systemRequirements {
		doc /* Top-level requirements for silicone rubber elastomeric system. */
		require tempStability : TemperatureStabilityRequirement;
		require mechPerformance : MechanicalPerformanceRequirement;
		require chemResist : ChemicalResistanceRequirement;
		require compSet : CompressionSetRequirement;
	}
}
