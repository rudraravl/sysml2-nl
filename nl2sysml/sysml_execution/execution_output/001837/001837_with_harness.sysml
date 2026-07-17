package 'Pharmaceutical Manufacturing Process' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def BatchTemperature :> TemperatureValue {
		attribute :>> num : Real;
		attribute :>> mRef : TemperatureUnit;
	}
	
	attribute def BatchPressure :> PressureValue {
		attribute :>> num : Real;
		attribute :>> mRef : PressureUnit;
	}
	
	attribute def MassFlowRate :> MassFlowRateValue {
		attribute :>> num : Real;
		attribute :>> mRef : MassFlowRateUnit;
	}
	
	attribute def BatchVolume :> VolumeValue {
		attribute :>> num : Real;
		attribute :>> mRef : VolumeUnit;
	}
	
	attribute def ConcentrationLevel {
		attribute value : Real;
		attribute unit : String;
	}
	
	attribute def pHLevel {
		attribute value : Real;
	}
	
	item def ActiveIngredient {
		attribute concentration : ConcentrationLevel;
		attribute purity : Real;
		attribute massFlow : MassFlowRate;
	}
	
	item def Excipient {
		attribute type : String;
		attribute massFlow : MassFlowRate;
	}
	
	item def Solvent {
		attribute volume : BatchVolume;
		attribute temperature : BatchTemperature;
	}
	
	item def MixedSolution {
		attribute activeConcentration : ConcentrationLevel;
		attribute pH : pHLevel;
		attribute temperature : BatchTemperature;
		attribute volume : BatchVolume;
	}
	
	item def CrystallizedProduct {
		attribute crystalSize : Real;
		attribute purity : Real;
		attribute mass : MassValue;
	}
	
	item def FilteredProduct {
		attribute moisture : Real;
		attribute purity : Real;
		attribute mass : MassValue;
	}
	
	item def DriedProduct {
		attribute moisture : Real;
		attribute particleSize : Real;
		attribute mass : MassValue;
	}
	
	item def MilledProduct {
		attribute particleSize : Real;
		attribute uniformity : Real;
		attribute mass : MassValue;
	}
	
	item def TabletProduct {
		attribute weight : MassValue;
		attribute hardness : Real;
		attribute dissolution : Real;
		attribute potency : Real;
	}
	
	item def WasteSolvent {
		attribute volume : BatchVolume;
		attribute contamination : Real;
	}
	
	attribute def MixingCommand {
		attribute speed : Real;
		attribute duration : TimeValue;
	}
	
	attribute def CrystallizationCommand {
		attribute targetTemperature : BatchTemperature;
		attribute coolingRate : Real;
	}
	
	attribute def DryingCommand {
		attribute targetMoisture : Real;
		attribute dryingTemperature : BatchTemperature;
	}
	
	attribute def CompressionCommand {
		attribute compressionForce : ForceValue;
		attribute tabletWeight : MassValue;
	}
	
	attribute def BatchStart;
	attribute def BatchComplete;
	attribute def QualityCheck;
	
	port def IngredientInputPort {
		in item activeIngredient : ActiveIngredient;
		in item excipient : Excipient;
		in item solvent : Solvent;
	}
	
	port def SolutionPort {
		out item solution : MixedSolution;
	}
	
	port def CrystalPort {
		out item crystals : CrystallizedProduct;
	}
	
	port def FilterPort {
		in item crystals : CrystallizedProduct;
		out item filteredProduct : FilteredProduct;
		out item waste : WasteSolvent;
	}
	
	port def DriedProductPort {
		out item driedProduct : DriedProduct;
	}
	
	port def MilledProductPort {
		out item milledProduct : MilledProduct;
	}
	
	port def TabletOutputPort {
		out item tablets : TabletProduct;
	}
	
	port def ProcessControlPort {
		in attribute setpoint : Real;
		out attribute measurement : Real;
		out attribute status : String;
	}
	
	part def MixingVessel {
		port ingredientInput : IngredientInputPort;
		port solutionOutput : SolutionPort;
		port controlInterface : ProcessControlPort;
		
		attribute mixingSpeed : Real;
		attribute vesselTemperature : BatchTemperature;
		attribute vesselVolume : BatchVolume;
		attribute mixerStatus : String;
	}
	
	part def Crystallizer {
		port solutionInput : SolutionPort;
		port crystalOutput : CrystalPort;
		port controlInterface : ProcessControlPort;
		
		attribute crystallizationTemp : BatchTemperature;
		attribute coolingRate : Real;
		attribute supersaturation : Real;
		attribute crystallizerStatus : String;
	}
	
	part def FilterPress {
		port crystalInput : CrystalPort;
		port filteredOutput : FilterPort;
		port controlInterface : ProcessControlPort;
		
		attribute filterPressure : BatchPressure;
		attribute filtrationRate : Real;
		attribute cakeThickness : Real;
		attribute filterStatus : String;
	}
	
	part def FluidBedDryer {
		port wetProductInput : FilterPort;
		port driedProductOutput : DriedProductPort;
		port controlInterface : ProcessControlPort;
		
		attribute dryingTemperature : BatchTemperature;
		attribute airFlowRate : Real;
		attribute residualMoisture : Real;
		attribute dryerStatus : String;
	}
	
	part def Mill {
		port driedProductInput : DriedProductPort;
		port milledProductOutput : MilledProductPort;
		port controlInterface : ProcessControlPort;
		
		attribute millSpeed : Real;
		attribute screenSize : Real;
		attribute throughput : MassFlowRate;
		attribute millStatus : String;
	}
	
	part def TabletPress {
		port milledProductInput : MilledProductPort;
		port tabletOutput : TabletOutputPort;
		port controlInterface : ProcessControlPort;
		
		attribute compressionForce : ForceValue;
		attribute productionRate : Real;
		attribute tabletWeight : MassValue;
		attribute pressStatus : String;
	}
	
	part def QualityControlLab {
		port sampleInput : TabletOutputPort;
		port controlInterface : ProcessControlPort;
		
		attribute testResults : String;
		attribute batchApproval : Boolean;
	}
	
	part def ProcessAutomationSystem {
		port mixerControl : ProcessControlPort;
		port crystallizerControl : ProcessControlPort;
		port filterControl : ProcessControlPort;
		port dryerControl : ProcessControlPort;
		port millControl : ProcessControlPort;
		port pressControl : ProcessControlPort;
		port qcControl : ProcessControlPort;
		
		attribute batchNumber : String;
		attribute processPhase : String;
		attribute overallYield : Real;
	}
	
	action def MixIngredients {
		in activeIngredientInput : ActiveIngredient;
		in excipientInput : Excipient;
		in solventInput : Solvent;
		in mixingCmd : MixingCommand;
		out mixedSolutionOutput : MixedSolution;
	}
	
	action def CrystallizeProduct {
		in solutionInput : MixedSolution;
		in crystallizationCmd : CrystallizationCommand;
		out crystalOutput : CrystallizedProduct;
	}
	
	action def FilterCrystals {
		in crystalInput : CrystallizedProduct;
		out filteredOutput : FilteredProduct;
		out wasteOutput : WasteSolvent;
	}
	
	action def DryProduct {
		in wetProductInput : FilteredProduct;
		in dryingCmd : DryingCommand;
		out driedOutput : DriedProduct;
	}
	
	action def MillProduct {
		in driedInput : DriedProduct;
		out milledOutput : MilledProduct;
	}
	
	action def CompressTablets {
		in milledInput : MilledProduct;
		in compressionCmd : CompressionCommand;
		out tabletOutput : TabletProduct;
	}
	
	action def InspectQuality {
		in tabletInput : TabletProduct;
		out qualityApproved : Boolean;
		out qualityMetrics : Real;
	}
	
	action def AdjustProcessParameters {
		in currentYield : Real;
		in targetYield : Real;
		in qualityMetrics : Real;
		out mixingAdjustment : MixingCommand;
		out crystallizationAdjustment : CrystallizationCommand;
	}
	
	action def ManufacturingProcess {
		in activeIngredient : ActiveIngredient;
		in excipient : Excipient;
		in solvent : Solvent;
		out finalTablets : TabletProduct;
		out processWaste : WasteSolvent;
		
		first start;
		
		accept batchStart : BatchStart;
		
		then action mixAction : MixIngredients {
			in activeIngredientInput = activeIngredient;
			in excipientInput = excipient;
			in solventInput = solvent;
			in mixingCmd : MixingCommand {
				attribute :>> speed = 300.0;
				attribute :>> duration : TimeValue {
					attribute :>> num = 3600.0;
					attribute :>> mRef = s;
				}
			}
			out mixedSolutionOutput : MixedSolution;
		}
		
		flow mixAction.mixedSolutionOutput to crystallizeAction.solutionInput;
		
		then action crystallizeAction : CrystallizeProduct {
			in solutionInput : MixedSolution;
			in crystallizationCmd : CrystallizationCommand {
				attribute :>> targetTemperature : BatchTemperature {
					attribute :>> num = 278.15;
					attribute :>> mRef = K;
				}
				attribute :>> coolingRate = 0.5;
			}
			out crystalOutput : CrystallizedProduct;
		}
		
		flow crystallizeAction.crystalOutput to filterAction.crystalInput;
		
		then action filterAction : FilterCrystals {
			in crystalInput : CrystallizedProduct;
			out filteredOutput : FilteredProduct;
			out wasteOutput : WasteSolvent;
		}
		
		flow filterAction.filteredOutput to dryAction.wetProductInput;
		flow filterAction.wasteOutput to processWaste;
		
		then action dryAction : DryProduct {
			in wetProductInput : FilteredProduct;
			in dryingCmd : DryingCommand {
				attribute :>> targetMoisture = 0.02;
				attribute :>> dryingTemperature : BatchTemperature {
					attribute :>> num = 333.15;
					attribute :>> mRef = K;
				}
			}
			out driedOutput : DriedProduct;
		}
		
		flow dryAction.driedOutput to millAction.driedInput;
		
		then action millAction : MillProduct {
			in driedInput : DriedProduct;
			out milledOutput : MilledProduct;
		}
		
		flow millAction.milledOutput to compressAction.milledInput;
		
		then action compressAction : CompressTablets {
			in milledInput : MilledProduct;
			in compressionCmd : CompressionCommand {
				attribute :>> compressionForce : ForceValue {
					attribute :>> num = 15000.0;
					attribute :>> mRef = N;
				}
				attribute :>> tabletWeight : MassValue {
					attribute :>> num = 0.0005;
					attribute :>> mRef = kg;
				}
			}
			out tabletOutput : TabletProduct;
		}
		
		flow compressAction.tabletOutput to inspectAction.tabletInput;
		
		then merge qualityLoop;
		
		then action inspectAction : InspectQuality {
			in tabletInput : TabletProduct;
			out qualityApproved : Boolean;
			out qualityMetrics : Real;
		}
		
		then decide;
			if inspectAction.qualityApproved then batchApproved;
			if not inspectAction.qualityApproved then adjustParameters;
		
		action adjustParameters : AdjustProcessParameters {
			in currentYield = 0.85;
			in targetYield = 0.95;
			in qualityMetrics = inspectAction.qualityMetrics;
			out mixingAdjustment : MixingCommand;
			out crystallizationAdjustment : CrystallizationCommand;
		}
		then qualityLoop;
		
		merge batchApproved;
		flow compressAction.tabletOutput to finalTablets;
		
		accept batchComplete : BatchComplete;
		then done;
	}
	
	part def PharmaceuticalManufacturingPlant {
		doc /*
		 * This system represents a continuous pharmaceutical tablet manufacturing facility
		 * that transforms raw active pharmaceutical ingredients and excipients into finished
		 * dosage forms through a series of precisely controlled unit operations.
		 * 
		 * Primary Function:
		 * The system's primary function is to produce high-quality pharmaceutical tablets by
		 * processing active ingredients through sequential stages of mixing, crystallization,
		 * filtration, drying, milling, and compression. The process begins with the dissolution
		 * and mixing of active pharmaceutical ingredients with excipients in a controlled solvent
		 * environment. The resulting solution undergoes controlled crystallization to form pure
		 * crystals of the desired particle size and morphology.
		 * 
		 * These crystals are then separated from the mother liquor through filtration, dried to
		 * remove residual moisture, milled to achieve uniform particle size distribution, and
		 * finally compressed into tablets of consistent weight, hardness, and dissolution
		 * characteristics. Throughout the process, an integrated automation system continuously
		 * monitors critical quality attributes and adjusts process parameters to maintain product
		 * specifications, ensuring batch-to-batch consistency and regulatory compliance while
		 * maximizing yield and minimizing waste generation.
		 */
		
		part mixingVessel : MixingVessel;
		part crystallizer : Crystallizer;
		part filterPress : FilterPress;
		part fluidBedDryer : FluidBedDryer;
		part mill : Mill;
		part tabletPress : TabletPress;
		part qcLab : QualityControlLab;
		part automationSystem : ProcessAutomationSystem;
	}
	
	part pharmaceuticalPlant : PharmaceuticalManufacturingPlant {
		
		connect mixingVessel.solutionOutput to crystallizer.solutionInput;
		connect crystallizer.crystalOutput to filterPress.crystalInput;
		connect filterPress.filteredOutput to fluidBedDryer.wetProductInput;
		connect fluidBedDryer.driedProductOutput to mill.driedProductInput;
		connect mill.milledProductOutput to tabletPress.milledProductInput;
		connect tabletPress.tabletOutput to qcLab.sampleInput;
		
		connect automationSystem.mixerControl to mixingVessel.controlInterface;
		connect automationSystem.crystallizerControl to crystallizer.controlInterface;
		connect automationSystem.filterControl to filterPress.controlInterface;
		connect automationSystem.dryerControl to fluidBedDryer.controlInterface;
		connect automationSystem.millControl to mill.controlInterface;
		connect automationSystem.pressControl to tabletPress.controlInterface;
		connect automationSystem.qcControl to qcLab.controlInterface;
		
		perform action manufacturingProcess : ManufacturingProcess[*] ordered;
	}
	
	requirement def ProductQualityRequirement {
		doc /* Tablets shall meet USP specifications for potency, dissolution, and uniformity */
		
		subject tablet : TabletProduct;
		
		require constraint {
			tablet.potency >= 0.95 and tablet.potency <= 1.05 and
			tablet.dissolution >= 0.80 and
			tablet.weight.num >= 0.00048 and tablet.weight.num <= 0.00052
		}
	}
	
	requirement def ProcessYieldRequirement {
		doc /* Manufacturing process shall achieve minimum 90% overall yield */
		
		subject plant : PharmaceuticalManufacturingPlant;
		
		require constraint {
			plant.automationSystem.overallYield >= 0.90
		}
	}
	
	requirement def EnvironmentalRequirement {
		doc /* Process shall minimize solvent waste and enable recovery */
		
		subject waste : WasteSolvent;
		
		require constraint {
			waste.contamination <= 0.05
		}
	}
	
	requirement def ProcessControlRequirement {
		doc /* Critical process parameters shall be maintained within specified ranges */
		
		subject plant : PharmaceuticalManufacturingPlant;
		
		require constraint {
			plant.crystallizer.crystallizationTemp.num >= 273.15 and
			plant.crystallizer.crystallizationTemp.num <= 283.15 and
			plant.fluidBedDryer.residualMoisture <= 0.03
		}
	}
	
	requirement manufacturingSystemRequirements {
		doc /* Top-level requirements for pharmaceutical manufacturing system */
		
		requirement productQuality : ProductQualityRequirement;
		requirement processYield : ProcessYieldRequirement;
		requirement environmental : EnvironmentalRequirement;
		requirement processControl : ProcessControlRequirement;
	}
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Pharmaceutical Manufacturing Process'::*;

    action orchestrator {
        action adjustParametersProbe : AdjustProcessParameters {
            in currentYield = 0.0;
            in targetYield = 0.0;
            in qualityMetrics = 0.0;
        }
        first adjustParametersProbe;
    }
}
