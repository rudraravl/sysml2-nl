package GastrointestinalTractSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def NutrientComposition {
		attribute carbohydrates : MassValue;
		attribute proteins : MassValue;
		attribute fats : MassValue;
		attribute fiber : MassValue;
		attribute water : VolumeValue;
		attribute vitamins : MassValue;
		attribute minerals : MassValue;
	}
	
	attribute def EnzymeConcentration {
		attribute amylase : Real;
		attribute pepsin : Real;
		attribute lipase : Real;
		attribute trypsin : Real;
	}
	
	item def IngestedFood {
		attribute totalMass : MassValue;
		attribute composition : NutrientComposition;
		attribute temperature : TemperatureValue;
	}
	
	item def Bolus {
		attribute mass : MassValue;
		attribute moistureContent : Real;
		attribute particleSize : LengthValue;
	}
	
	item def Chyme {
		attribute mass : MassValue;
		attribute pH : Real;
		attribute nutrients : NutrientComposition;
		attribute viscosity : Real;
	}
	
	item def AbsorbedNutrients {
		attribute glucose : MassValue;
		attribute aminoAcids : MassValue;
		attribute fattyAcids : MassValue;
		attribute electrolytes : MassValue;
		attribute waterAbsorbed : VolumeValue;
	}
	
	item def FecalMatter {
		attribute mass : MassValue;
		attribute waterContent : VolumeValue;
		attribute bacterialContent : Real;
	}
	
	item def DigestiveSecretion {
		attribute volume : VolumeValue;
		attribute enzymes : EnzymeConcentration;
		attribute pH : Real;
	}
	
	port def LumenPort {
		in item materialIn;
		out item materialOut;
	}
	
	port def SecretionPort {
		out item secretion : DigestiveSecretion;
	}
	
	port def AbsorptionPort {
		out item nutrients : AbsorbedNutrients;
	}
	
	part def OralCavity {
		attribute salivaryFlowRate : VolumeValue;
		attribute teethCount : Integer;
		
		port foodIntake : LumenPort;
		port bolusOutput : LumenPort;
		port salivaryGlands : SecretionPort;
		
		action mechanicalDigestion {
			in food : IngestedFood;
			out partiallyChewed : Bolus;
		}
		
		action salivaryDigestion {
			in bolus : Bolus;
			in saliva : DigestiveSecretion;
			out lubricatedBolus : Bolus;
		}
	}
	
	part def Esophagus {
		attribute length : LengthValue;
		attribute peristalticWaveSpeed : SpeedValue;
		
		port proximalEnd : LumenPort;
		port distalEnd : LumenPort;
		
		action peristalticTransport {
			in bolus : Bolus;
			out transportedBolus : Bolus;
		}
		
		state esophagealStates {
			entry; then resting;
			
			state resting;
			transition restingToContracting
				first resting
				accept bolusArrival : Bolus
				then contracting;
			
			state contracting {
				do action peristalticTransport;
			}
			transition contractingToRelaxing
				first contracting
				then relaxing;
			
			state relaxing;
			transition relaxingToResting
				first relaxing
				then resting;
		}
	}
	
	part def Stomach {
		attribute capacity : VolumeValue;
		attribute gastricAcidpH : Real;
		attribute emptyingRate : VolumeValue;
		
		port cardiacSphincter : LumenPort;
		port pyloricSphincter : LumenPort;
		port gastricGlands : SecretionPort;
		
		action mechanicalMixing {
			in bolus : Bolus;
			out mixedContent : Chyme;
		}
		
		action acidicDigestion {
			in content : Chyme;
			in gastricJuice : DigestiveSecretion;
			out acidifiedChyme : Chyme;
		}
		
		action proteinBreakdown {
			in chyme : Chyme;
			out partiallyDigested : Chyme;
		}
		
		state gastricStates {
			entry; then empty;
			
			state empty;
			transition emptyToFilling
				first empty
				accept foodEntry : Bolus
				then filling;
			
			state filling {
				do action mechanicalMixing;
			}
			transition fillingToDigesting
				first filling
				then digesting;
			
			state digesting {
				entry; then acidification;
				
				state acidification {
					do action acidicDigestion;
				}
				transition acidificationToEnzymatic
					first acidification
					then enzymaticBreakdown;
				
				state enzymaticBreakdown {
					do action proteinBreakdown;
				}
			}
			transition digestingToEmptying
				first digesting
				then emptying;
			
			state emptying;
			transition emptyingToEmpty
				first emptying
				then empty;
		}
	}
	
	part def SmallIntestine {
		attribute totalLength : LengthValue;
		attribute surfaceArea : AreaValue;
		attribute transitTime : DurationValue;
		
		port proximalJunction : LumenPort;
		port distalJunction : LumenPort;
		port pancreaticDuct : SecretionPort;
		port bileDuct : SecretionPort;
		port bloodVessels : AbsorptionPort;
		
		part duodenum {
			attribute length : LengthValue;
			
			action neutralizeAcid {
				in acidicChyme : Chyme;
				in pancreaticJuice : DigestiveSecretion;
				out neutralizedChyme : Chyme;
			}
			
			action emulsifyFats {
				in chyme : Chyme;
				in bile : DigestiveSecretion;
				out emulsifiedChyme : Chyme;
			}
		}
		
		part jejunum {
			attribute length : LengthValue;
			attribute villiDensity : Real;
			
			action nutrientAbsorption {
				in chyme : Chyme;
				out absorbedNutrients : AbsorbedNutrients;
				out remainingChyme : Chyme;
			}
			
			action enzymaticDigestion {
				in chyme : Chyme;
				out digestedChyme : Chyme;
			}
		}
		
		part ileum {
			attribute length : LengthValue;
			
			action finalAbsorption {
				in chyme : Chyme;
				out nutrients : AbsorbedNutrients;
				out residue : Chyme;
			}
			
			action vitaminB12Absorption {
				in chyme : Chyme;
				out absorbedB12 : MassValue;
			}
		}
	}
	
	part def LargeIntestine {
		attribute length : LengthValue;
		attribute waterAbsorptionCapacity : VolumeValue;
		attribute bacterialPopulation : Real;
		
		port ileocecalValve : LumenPort;
		port analCanal : LumenPort;
		
		action waterReabsorption {
			in liquidWaste : Chyme;
			out concentratedWaste : FecalMatter;
			out absorbedWater : VolumeValue;
		}
		
		action bacterialFermentation {
			in waste : FecalMatter;
			out fermentedWaste : FecalMatter;
		}
		
		action fecalStorage {
			in waste : FecalMatter;
			out storedWaste : FecalMatter;
		}
		
		state colonicStates {
			entry; then absorbing;
			
			state absorbing {
				do action waterReabsorption;
			}
			transition absorbingToFermenting
				first absorbing
				then fermenting;
			
			state fermenting {
				do action bacterialFermentation;
			}
			transition fermentingToStoring
				first fermenting
				then storing;
			
			state storing {
				do action fecalStorage;
			}
			transition storingToEliminating
				first storing
				accept defecationReflex
				then eliminating;
			
			state eliminating;
			transition eliminatingToAbsorbing
				first eliminating
				then absorbing;
		}
	}
	
	part def Pancreas {
		attribute enzymeProductionRate : MassValue;
		
		port exocrineDuct : SecretionPort;
		
		action secretePancreaticJuice {
			out juice : DigestiveSecretion;
		}
		
		action produceEnzymes {
			out enzymes : EnzymeConcentration;
		}
	}
	
	part def Liver {
		attribute bileProductionRate : VolumeValue;
		attribute metabolicCapacity : Real;
		
		port hepaticDuct : SecretionPort;
		port hepaticVein : AbsorptionPort;
		
		action produceBile {
			out bile : DigestiveSecretion;
		}
		
		action metabolizeNutrients {
			in nutrients : AbsorbedNutrients;
			out processedNutrients : AbsorbedNutrients;
		}
		
		action detoxification {
			in bloodSupply : AbsorbedNutrients;
			out detoxifiedBlood : AbsorbedNutrients;
		}
	}
	
	part def Gallbladder {
		attribute storageCapacity : VolumeValue;
		attribute concentrationFactor : Real;
		
		port cysticDuct : SecretionPort;
		
		action storeBile {
			in bile : DigestiveSecretion;
			out storedBile : DigestiveSecretion;
		}
		
		action concentrateBile {
			in diluteBile : DigestiveSecretion;
			out concentratedBile : DigestiveSecretion;
		}
		
		action releaseBile {
			in storedBile : DigestiveSecretion;
			out releasedBile : DigestiveSecretion;
		}
	}
	
	part gastrointestinalTract {
		part mouth : OralCavity;
		part esophagus : Esophagus;
		part stomach : Stomach;
		part smallBowel : SmallIntestine;
		part largeBowel : LargeIntestine;
		part pancreas : Pancreas;
		part liver : Liver;
		part gallbladder : Gallbladder;
		
		connect mouth.bolusOutput to esophagus.proximalEnd;
		connect esophagus.distalEnd to stomach.cardiacSphincter;
		connect stomach.pyloricSphincter to smallBowel.proximalJunction;
		connect pancreas.exocrineDuct to smallBowel.pancreaticDuct;
		connect liver.hepaticDuct to gallbladder.cysticDuct;
		connect gallbladder.cysticDuct to smallBowel.bileDuct;
		connect smallBowel.distalJunction to largeBowel.ileocecalValve;
		connect smallBowel.bloodVessels to liver.hepaticVein;
	}
	
	action def IngestFood {
		in food : IngestedFood;
		out bolus : Bolus;
	}
	
	action def TransportBolus {
		in bolus : Bolus;
		out deliveredBolus : Bolus;
	}
	
	action def GastricProcessing {
		in bolus : Bolus;
		in gastricSecretion : DigestiveSecretion;
		out chyme : Chyme;
	}
	
	action def IntestinalDigestion {
		in chyme : Chyme;
		in pancreaticEnzymes : DigestiveSecretion;
		in bile : DigestiveSecretion;
		out nutrients : AbsorbedNutrients;
		out residue : Chyme;
	}
	
	action def NutrientAbsorption {
		in digestedChyme : Chyme;
		out absorbedNutrients : AbsorbedNutrients;
		out unabsorbedResidue : Chyme;
	}
	
	action def WaterReclamation {
		in residue : Chyme;
		out feces : FecalMatter;
		out reclaimedWater : VolumeValue;
	}
	
	action def EliminateWaste {
		in feces : FecalMatter;
	}
	
	action completeDigestiveProcess {
		first start;
		
		then action ingest : IngestFood {
			in food;
			out bolus;
		}
		
		then action chew {
			in rawFood = ingest.food;
			out masticatedBolus : Bolus;
		}
		
		then action swallow : TransportBolus {
			in bolus = chew.masticatedBolus;
			out deliveredBolus;
		}
		
		then action stomachDigest : GastricProcessing {
			in bolus = swallow.deliveredBolus;
			in gastricSecretion;
			out chyme;
		}
		
		then action intestinalProcess : IntestinalDigestion {
			in chyme = stomachDigest.chyme;
			in pancreaticEnzymes;
			in bile;
			out nutrients;
			out residue;
		}
		
		then action absorb : NutrientAbsorption {
			in digestedChyme = intestinalProcess.nutrients;
			out absorbedNutrients;
			out unabsorbedResidue;
		}
		
		then action reclaimWater : WaterReclamation {
			in residue = absorb.unabsorbedResidue;
			out feces;
			out reclaimedWater;
		}
		
		then action eliminate : EliminateWaste {
			in feces = reclaimWater.feces;
		}
		
		then done;
	}
	
	requirement def PrimaryDigestiveFunction {
		doc /* The gastrointestinal tract shall mechanically and chemically break down ingested food, 
		       absorb nutrients and water into the bloodstream, and eliminate indigestible waste. */
		
		subject system : gastrointestinalTract;
	}
	
	requirement def NutrientAbsorptionEfficiency {
		doc /* The small intestine shall absorb at least 90% of digestible carbohydrates, 
		       95% of proteins, and 95% of fats from processed chyme. */
		
		subject absorptionSite : SmallIntestine;
		
		require constraint {
			absorptionSite.jejunum.villiDensity >= 10.0 and
			absorptionSite.surfaceArea >= 200.0
		}
	}
	
	requirement def GastricAcidityControl {
		doc /* The stomach shall maintain a pH between 1.5 and 3.5 during active digestion 
		       to facilitate protein denaturation and pathogen neutralization. */
		
		subject gastricChamber : Stomach;
		
		require constraint {
			gastricChamber.gastricAcidpH >= 1.5 and 
			gastricChamber.gastricAcidpH <= 3.5
		}
	}
	
	requirement def WaterConservation {
		doc /* The large intestine shall reabsorb at least 80% of water content from 
		       intestinal residue to maintain systemic hydration. */
		
		subject colon : LargeIntestine;
		
		require constraint {
			colon.waterAbsorptionCapacity >= 1.0
		}
	}
	
	requirement def TransitTimeRegulation {
		doc /* The complete digestive process from ingestion to elimination shall occur 
		       within 24 to 72 hours under normal physiological conditions. */
		
		attribute totalTransitTime : DurationValue;
		
		require constraint {
			totalTransitTime >= 24.0 and totalTransitTime <= 72.0
		}
	}
	
	requirement systemDigestiveRequirements {
		doc /* The gastrointestinal tract system shall fulfill all functional requirements 
		       for nutrient extraction and waste elimination. */
		
		assume constraint adequateFoodIntake {
			doc /* Food enters the system with measurable nutrient composition and mass. */
		}
		
		require primaryFunction : PrimaryDigestiveFunction;
		require absorptionEfficiency : NutrientAbsorptionEfficiency;
		require acidityControl : GastricAcidityControl;
		require waterConservation : WaterConservation;
		require transitRegulation : TransitTimeRegulation;
		
		satisfy primaryFunction by gastrointestinalTract.completeDigestiveProcess;
	}
}
