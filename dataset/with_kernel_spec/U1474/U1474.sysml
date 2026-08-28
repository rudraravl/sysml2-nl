package 'Pharmaceutical Manufacturing Plant' {
	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ISQ::*;
		private import ScalarValues::*;

		item def ActivePharmaceuticalIngredient;
		item def Excipient;
		item def Solvent;
		item def Solution;
		item def CrystalMixture;
		item def WetProduct;
		item def WasteSolvent;
		item def DryMaterial;
		item def Powder;
		item def Tablet {
			attribute weight : ISQ::MassValue;
			attribute hardness : ISQ::ForceValue;
			attribute dissolution : Real;
		}
		item def QualityReport {
			attribute potency : Real;
			attribute weight : ISQ::MassValue;
			attribute dissolution : Real;
			attribute isConforming : Boolean;
		}

		attribute def Temperature :> Real;
		attribute def Pressure :> Real;
		attribute def FlowRate :> Real;
		attribute def CoolingRate :> Real;
		attribute def CompressionForce :> ISQ::ForceValue;
		attribute def ControlCommand;
		attribute def SensorData {
			attribute temp : Temperature;
			attribute pressure : Pressure;
			attribute flowRate : FlowRate;
		}

		port def MaterialInPort {
			in item material;
		}
		port def MaterialOutPort {
			out item material;
		}
		port def ControlPort {
			in attribute command : ControlCommand;
		}
		port def SensorPort {
			out attribute data : SensorData;
		}
		port def QualityPort {
			out item report : QualityReport;
		}

		part def MixingVessel {
			in port apiIn : MaterialInPort;
			in port excipientIn : MaterialInPort;
			in port solventIn : MaterialInPort;
			out port solutionOut : MaterialOutPort;
			in port control : ControlPort;
			out port sensor : SensorPort;
		}
		part def Crystallizer {
			in port solutionIn : MaterialInPort;
			out port crystalOut : MaterialOutPort;
			in port control : ControlPort;
			out port sensor : SensorPort;
		}
		part def FilterPress {
			in port crystalIn : MaterialInPort;
			out port wetProductOut : MaterialOutPort;
			out port wasteSolventOut : MaterialOutPort;
			in port control : ControlPort;
			out port sensor : SensorPort;
		}
		part def FluidBedDryer {
			in port wetProductIn : MaterialInPort;
			out port dryMaterialOut : MaterialOutPort;
			in port control : ControlPort;
			out port sensor : SensorPort;
		}
		part def Mill {
			in port dryMaterialIn : MaterialInPort;
			out port powderOut : MaterialOutPort;
			in port control : ControlPort;
			out port sensor : SensorPort;
		}
		part def TabletPress {
			in port powderIn : MaterialInPort;
			out port tabletOut : MaterialOutPort;
			in port control : ControlPort;
			out port sensor : SensorPort;
		}
		part def ProcessAutomationSystem {
			out port mixingControl : ControlPort;
			out port crystallizerControl : ControlPort;
			out port filterControl : ControlPort;
			out port dryerControl : ControlPort;
			out port millControl : ControlPort;
			out port pressControl : ControlPort;

			in port mixingSensor : SensorPort;
			in port crystallizerSensor : SensorPort;
			in port filterSensor : SensorPort;
			in port dryerSensor : SensorPort;
			in port millSensor : SensorPort;
			in port pressSensor : SensorPort;

			in port qualityIn : QualityPort;

			state def AutomationStates;
			state automationStates : AutomationStates {
				entry; then monitoring;
				state monitoring;
				accept report : QualityReport
					if not report.isConforming
					do send new ControlCommand() to mixingControl
					then adjusting;
				state adjusting;
				accept data : SensorData
					then monitoring;
			}
		}
		part def QualityControlLab {
			in port tabletIn : MaterialInPort;
			out port reportOut : QualityPort;
		}

		part def Plant {
			part mixingVessel : MixingVessel;
			part crystallizer : Crystallizer;
			part filterPress : FilterPress;
			part fluidBedDryer : FluidBedDryer;
			part mill : Mill;
			part tabletPress : TabletPress;
			part automationSystem : ProcessAutomationSystem;
			part qualityControlLab : QualityControlLab;
		}

		action def MixMaterials {
			in api : ActivePharmaceuticalIngredient;
			in excipient : Excipient;
			in solvent : Solvent;
			out solution : Solution;
		}
		action def CrystallizeSolution {
			in solution : Solution;
			out crystals : CrystalMixture;
		}
		action def FilterCrystals {
			in crystals : CrystalMixture;
			out wetProduct : WetProduct;
			out wasteSolvent : WasteSolvent;
		}
		action def DryProduct {
			in wetProduct : WetProduct;
			out dryMaterial : DryMaterial;
		}
		action def MillMaterial {
			in dryMaterial : DryMaterial;
			out powder : Powder;
		}
		action def PressTablets {
			in powder : Powder;
			out tablets : Tablet;
		}
		action def ManufactureTablets {
			in api : ActivePharmaceuticalIngredient;
			in excipient : Excipient;
			in solvent : Solvent;
			out tablets : Tablet;
		}

		requirement def PotencyRequirement {
			doc /* The tablet potency must be within 95-105% of the label claim. */
			attribute minPotency : Real = 0.95;
			attribute maxPotency : Real = 1.05;
		}
		requirement def WeightRequirement {
			doc /* The tablet weight must be within +/- 5% of the target weight. */
			attribute targetWeight : ISQ::MassValue;
			attribute tolerance : Real = 0.05;
		}
		requirement def DissolutionRequirement {
			doc /* At least 80% of the active ingredient must dissolve in 30 minutes. */
			attribute minDissolution : Real = 0.80;
			attribute timeLimit : Real = 30.0;
		}
	}

	package Usages {
		part plant : Plant {
			flow mixingVessel.solutionOut.material to crystallizer.solutionIn.material;
			flow crystallizer.crystalOut.material to filterPress.crystalIn.material;
			flow filterPress.wetProductOut.material to fluidBedDryer.wetProductIn.material;
			flow fluidBedDryer.dryMaterialOut.material to mill.dryMaterialIn.material;
			flow mill.powderOut.material to tabletPress.powderIn.material;
			flow tabletPress.tabletOut.material to qualityControlLab.tabletIn.material;

			flow automationSystem.mixingControl.command to mixingVessel.control.command;
			flow automationSystem.crystallizerControl.command to crystallizer.control.command;
			flow automationSystem.filterControl.command to filterPress.control.command;
			flow automationSystem.dryerControl.command to fluidBedDryer.control.command;
			flow automationSystem.millControl.command to mill.control.command;
			flow automationSystem.pressControl.command to tabletPress.control.command;

			flow mixingVessel.sensor.data to automationSystem.mixingSensor.data;
			flow crystallizer.sensor.data to automationSystem.crystallizerSensor.data;
			flow filterPress.sensor.data to automationSystem.filterSensor.data;
			flow fluidBedDryer.sensor.data to automationSystem.dryerSensor.data;
			flow mill.sensor.data to automationSystem.millSensor.data;
			flow tabletPress.sensor.data to automationSystem.pressSensor.data;

			flow qualityControlLab.reportOut.report to automationSystem.qualityIn.report;

			requirement potencyReq : PotencyRequirement;
			requirement weightReq : WeightRequirement;
			requirement dissolutionReq : DissolutionRequirement;
		}

		action manufactureTablets : ManufactureTablets {
			in api : ActivePharmaceuticalIngredient;
			in excipient : Excipient;
			in solvent : Solvent;
			out tablets : Tablet;

			action mixMaterials : MixMaterials {
				in api = manufactureTablets::api;
				in excipient = manufactureTablets::excipient;
				in solvent = manufactureTablets::solvent;
				out solution : Solution;
			}
			flow mixMaterials.solution to crystallizeSolution.solution;

			action crystallizeSolution : CrystallizeSolution {
				in solution : Solution;
				out crystals : CrystalMixture;
			}
			flow crystallizeSolution.crystals to filterCrystals.crystals;

			action filterCrystals : FilterCrystals {
				in crystals : CrystalMixture;
				out wetProduct : WetProduct;
				out wasteSolvent : WasteSolvent;
			}
			flow filterCrystals.wetProduct to dryProduct.wetProduct;

			action dryProduct : DryProduct {
				in wetProduct : WetProduct;
				out dryMaterial : DryMaterial;
			}
			flow dryProduct.dryMaterial to millMaterial.dryMaterial;

			action millMaterial : MillMaterial {
				in dryMaterial : DryMaterial;
				out powder : Powder;
			}
			flow millMaterial.powder to pressTablets.powder;

			action pressTablets : PressTablets {
				in powder : Powder;
				out tablets = manufactureTablets::tablets;
			}

			first start;
			then mixMaterials;
			then crystallizeSolution;
			then filterCrystals;
			then dryProduct;
			then millMaterial;
			then pressTablets;
			then done;
		}
	}
}
