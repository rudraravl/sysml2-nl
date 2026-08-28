package 'GI Tract System' {
	private import ScalarValues::Real;
	public import Definitions::*;

	package Definitions {
		item def Food;
		item def Saliva;
		item def Bolus;
		item def GastricJuice;
		item def Chyme;
		item def DigestiveFluid;
		item def Bile :> DigestiveFluid;
		item def PancreaticJuice :> DigestiveFluid;
		item def Nutrient;
		item def Waste :> Chyme;
		item def FecalMatter;
		item def Blood;

		port def FoodPort {
			out item food : Food;
		}
		port def BolusPort {
			out item bolus : Bolus;
		}
		port def ChymePort {
			out item chyme : Chyme;
		}
		port def WastePort {
			out item waste : Waste;
		}
		port def FecesPort {
			out item feces : FecalMatter;
		}
		port def NutrientPort {
			out item nutrient : Nutrient;
		}
		port def FluidPort {
			out item fluid : DigestiveFluid;
		}

		part def OralCavity {
			port foodInPort : ~FoodPort;
			port bolusOutPort : BolusPort;
		}
		part def Esophagus {
			port bolusInPort : ~BolusPort;
			port bolusOutPort : BolusPort;
		}
		part def Stomach {
			port bolusInPort : ~BolusPort;
			port chymeOutPort : ChymePort;
		}
		part def Duodenum {
			port chymeInPort : ~ChymePort;
			port bileInPort : ~FluidPort;
			port juiceInPort : ~FluidPort;
			port chymeOutPort : ChymePort;
		}
		part def Jejunum {
			port chymeInPort : ~ChymePort;
			port nutrientOutPort : NutrientPort;
			port chymeOutPort : ChymePort;
		}
		part def Ileum {
			port chymeInPort : ~ChymePort;
			port nutrientOutPort : NutrientPort;
			port wasteOutPort : WastePort;
		}
		part def SmallIntestine {
			port chymeInPort : ~ChymePort;
			port bileInPort : ~FluidPort;
			port juiceInPort : ~FluidPort;
			port nutrientOutPort : NutrientPort;
			port wasteOutPort : WastePort;
		}
		part def LargeIntestine {
			port wasteInPort : ~WastePort;
			port fecesOutPort : FecesPort;
		}
		part def Pancreas {
			port juiceOutPort : FluidPort;
		}
		part def Liver {
			port bileOutPort : FluidPort;
			port nutrientInPort : ~NutrientPort;
			port bloodOutPort : NutrientPort;
		}
		part def Gallbladder {
			port bileInPort : ~FluidPort;
			port bileOutPort : FluidPort;
		}
		part def Bloodstream {
			port nutrientInPort : ~NutrientPort;
		}

		action def Masticate {
			in item food : Food;
			in item saliva : Saliva;
			out item bolus : Bolus;
		}
		action def Peristalsis {
			in item bolus : Bolus;
			out item bolusMoved : Bolus;
		}
		action def GastricDigestion {
			in item bolus : Bolus;
			in item gastricJuice : GastricJuice;
			out item chyme : Chyme;
		}
		action def IntestinalDigestion {
			in item chyme : Chyme;
			in item bile : Bile;
			in item pancreaticJuice : PancreaticJuice;
			out item processedChyme : Chyme;
		}
		action def AbsorbNutrients {
			in item chyme : Chyme;
			out item nutrients : Nutrient;
			out item residue : Chyme;
		}
		action def AbsorbWater {
			in item waste : Waste;
			out item concentratedWaste : Waste;
		}
		action def FormFeces {
			in item waste : Waste;
			out item feces : FecalMatter;
		}

		state def StomachStates {
			entry; then Filling;
			state Filling;
			transition from Filling to Digesting;
			state Digesting;
			transition from Digesting to Emptying;
			state Emptying;
			transition from Emptying to Filling;
		}

		requirement def DigestionRequirement {
			doc /* The system must break down food into absorbable nutrients. */
		}
		requirement def AbsorptionRequirement {
			doc /* The system must absorb nutrients into the bloodstream. */
		}
		requirement def EliminationRequirement {
			doc /* The system must expel solid waste. */
		}
		requirement def PathogenDefenseRequirement {
			doc /* The stomach must kill harmful pathogens using acidic gastric juice. */
		}
	}

	package Usages {
		part context {
			part oralCavity : OralCavity {
				perform action masticate : Masticate {
					in food = foodInPort.food;
					out bolus = bolusOutPort.bolus;
				}
			}
			flow of bolus : Bolus
				from oralCavity.bolusOutPort.bolus to esophagus.bolusInPort.bolus;

			part esophagus : Esophagus {
				perform action peristalsis : Peristalsis {
					in bolus = bolusInPort.bolus;
					out bolusMoved = bolusOutPort.bolus;
				}
			}
			flow of bolus : Bolus
				from esophagus.bolusOutPort.bolus to stomach.bolusInPort.bolus;

			part stomach : Stomach {
				exhibit stomachStates : StomachStates;
				perform action gastricDigestion : GastricDigestion {
					in bolus = bolusInPort.bolus;
					out chyme = chymeOutPort.chyme;
				}
			}
			flow of chyme : Chyme
				from stomach.chymeOutPort.chyme to smallIntestine.chymeInPort.chyme;

			part smallIntestine : SmallIntestine {
				flow of chyme : Chyme from chymeInPort.chyme to duodenum.chymeInPort.chyme;
				flow of bile : Bile from bileInPort.fluid to duodenum.bileInPort.fluid;
				flow of pancreaticJuice : PancreaticJuice from juiceInPort.fluid to duodenum.juiceInPort.fluid;
				flow of chyme : Chyme from duodenum.chymeOutPort.chyme to jejunum.chymeInPort.chyme;
				flow of chyme : Chyme from jejunum.chymeOutPort.chyme to ileum.chymeInPort.chyme;
				flow of nutrients : Nutrient from jejunum.nutrientOutPort.nutrient to nutrientOutPort.nutrient;
				flow of nutrients : Nutrient from ileum.nutrientOutPort.nutrient to nutrientOutPort.nutrient;
				flow of waste : Waste from ileum.wasteOutPort.waste to wasteOutPort.waste;

				part duodenum : Duodenum {
					perform action intestinalDigestion : IntestinalDigestion {
						in chyme = chymeInPort.chyme;
						in bile = bileInPort.fluid;
						in pancreaticJuice = juiceInPort.fluid;
						out processedChyme = chymeOutPort.chyme;
					}
				}
				part jejunum : Jejunum {
					perform action absorbNutrients : AbsorbNutrients {
						in chyme = chymeInPort.chyme;
						out nutrients = nutrientOutPort.nutrient;
						out residue = chymeOutPort.chyme;
					}
				}
				part ileum : Ileum {
					perform action absorbNutrients : AbsorbNutrients {
						in chyme = chymeInPort.chyme;
						out nutrients = nutrientOutPort.nutrient;
						out residue = wasteOutPort.waste;
					}
				}
			}

			part pancreas : Pancreas;
			flow of pancreaticJuice : PancreaticJuice
				from pancreas.juiceOutPort.fluid to smallIntestine.juiceInPort.fluid;

			part liver : Liver;
			part gallbladder : Gallbladder;
			flow of bile : Bile
				from liver.bileOutPort.fluid to gallbladder.bileInPort.fluid;
			flow of bile : Bile
				from gallbladder.bileOutPort.fluid to smallIntestine.bileInPort.fluid;

			flow of nutrients : Nutrient
				from smallIntestine.nutrientOutPort.nutrient to liver.nutrientInPort.nutrient;
			flow of nutrients : Nutrient
				from liver.bloodOutPort.nutrient to bloodstream.nutrientInPort.nutrient;

			part bloodstream : Bloodstream;

			flow of waste : Waste
				from smallIntestine.wasteOutPort.waste to largeIntestine.wasteInPort.waste;

			part largeIntestine : LargeIntestine {
				item internalWaste : Waste;
				perform action absorbWater : AbsorbWater {
					in waste = wasteInPort.waste;
					out concentratedWaste = internalWaste;
				}
				perform action formFeces : FormFeces {
					in waste = internalWaste;
					out feces = fecesOutPort.feces;
				}
			}

			requirement digestionReq : DigestionRequirement;
			requirement absorptionReq : AbsorptionRequirement;
			requirement eliminationReq : EliminationRequirement;
			requirement pathogenReq : PathogenDefenseRequirement;

			satisfy digestionReq by stomach.gastricDigestion;
			satisfy absorptionReq by smallIntestine.ileum.absorbNutrients;
			satisfy eliminationReq by largeIntestine.formFeces;
			satisfy pathogenReq by stomach.gastricDigestion;
		}
	}
}
