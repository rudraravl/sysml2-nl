package 'Municipal Sewage Treatment Plant' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import ISQ::VolumeValue;
	private import ISQ::TimeValue;

	package Definitions {
		attribute def FlowRate :> Real;
		attribute def Concentration :> Real;
		attribute def Percentage :> Real;
		attribute def PathogenCount :> Real;
		attribute def TemperatureValue :> Real;

		item def RawSewage {
			attribute bod : Concentration;
			attribute tss : Concentration;
			attribute coliform : PathogenCount;
			attribute pH : Real;
			attribute flowRate : FlowRate;
		}
		item def ScreenedWastewater;
		item def DegrittedWastewater;
		item def PrimaryEffluent;
		item def MixedLiquor;
		item def SecondaryEffluent;
		item def TreatedEffluent {
			attribute bod : Concentration;
			attribute tss : Concentration;
			attribute coliform : PathogenCount;
			attribute pH : Real;
		}
		item def PrimarySludge {
			attribute solidsConcentration : Percentage;
			attribute organicContent : Percentage;
		}
		item def WasteActivatedSludge {
			attribute solidsConcentration : Percentage;
			attribute organicContent : Percentage;
		}
		item def ReturnActivatedSludge;
		item def DigestedSludge {
			attribute volatileSolidsReduction : Percentage;
			attribute solidsConcentration : Percentage;
		}
		item def Chlorine;
		item def Screenings;
		item def Grit;
		item def Air;

		port def WastewaterInPort {
			in item wastewater;
		}
		port def WastewaterOutPort {
			out item wastewater;
		}
		port def SludgeOutPort {
			out item sludge;
		}
		port def SludgeInPort {
			in item sludge;
		}
		port def AirInPort {
			in item air;
		}
		port def AirOutPort {
			out item air;
		}
		port def ChemicalInPort {
			in item chemical;
		}
		port def ChemicalOutPort {
			out item chemical;
		}
		port def RecyclePort {
			out item recycle;
		}
		port def RecycleInPort {
			in item recycle;
		}

		attribute def PlantStartSignal;
		attribute def PlantOperationalSignal;
		attribute def PlantShutdownSignal;
		attribute def MaintenanceSignal;
		attribute def ResumeOperationSignal;

		part def ScreeningUnit {
			port wastewaterIn : WastewaterInPort;
			port wastewaterOut : WastewaterOutPort;
			port screeningsOut : SludgeOutPort;
			attribute screeningEfficiency : Percentage;
		}
		part def GritChamber {
			port wastewaterIn : WastewaterInPort;
			port wastewaterOut : WastewaterOutPort;
			port gritOut : SludgeOutPort;
			attribute gritRemovalRate : Percentage;
		}
		part def PrimaryClarifier {
			port wastewaterIn : WastewaterInPort;
			port effluentOut : WastewaterOutPort;
			port sludgeOut : SludgeOutPort;
			attribute settlingArea : Real;
			attribute detentionTime : TimeValue;
		}
		part def AerationBasin {
			port wastewaterIn : WastewaterInPort;
			port mixedLiquorOut : WastewaterOutPort;
			port airIn : AirInPort;
			port recycleIn : RecycleInPort;
			attribute dissolvedOxygen : Concentration;
			attribute volume : VolumeValue;
			attribute mlssConcentration : Concentration;
		}
		part def SecondaryClarifier {
			port mixedLiquorIn : WastewaterInPort;
			port effluentOut : WastewaterOutPort;
			port wasteSludgeOut : SludgeOutPort;
			port recycleOut : RecyclePort;
			attribute surfaceArea : Real;
		}
		part def DisinfectionChamber {
			port wastewaterIn : WastewaterInPort;
			port effluentOut : WastewaterOutPort;
			port chemicalIn : ChemicalInPort;
			attribute contactTime : TimeValue;
			attribute chlorineDose : Concentration;
		}
		part def AnaerobicDigester {
			port sludgeIn1 : SludgeInPort;
			port sludgeIn2 : SludgeInPort;
			port digestedSludgeOut : SludgeOutPort;
			attribute temperature : TemperatureValue;
			attribute retentionTime : TimeValue;
		}
		part def Blower {
			port airIn : AirInPort;
			port airOut : AirOutPort;
			attribute airflowRate : FlowRate;
		}
		part def ChlorineDosingSystem {
			port chemicalIn : ChemicalInPort;
			port chemicalOut : ChemicalOutPort;
			attribute dosingRate : FlowRate;
		}

		action def ScreenWastewater {
			in item rawSewage : RawSewage;
			out item screenedWastewater : ScreenedWastewater;
			out item screenings : Screenings;
		}
		action def RemoveGrit {
			in item screenedWastewater : ScreenedWastewater;
			out item degrittedWastewater : DegrittedWastewater;
			out item grit : Grit;
		}
		action def PrimarySettling {
			in item degrittedWastewater : DegrittedWastewater;
			out item primaryEffluent : PrimaryEffluent;
			out item primarySludge : PrimarySludge;
		}
		action def AerateAndTreat {
			in item primaryEffluent : PrimaryEffluent;
			in item returnSludge : ReturnActivatedSludge;
			in item air : Air;
			out item mixedLiquor : MixedLiquor;
		}
		action def SecondarySettling {
			in item mixedLiquor : MixedLiquor;
			out item secondaryEffluent : SecondaryEffluent;
			out item wasteSludge : WasteActivatedSludge;
			out item returnSludge : ReturnActivatedSludge;
		}
		action def Disinfect {
			in item secondaryEffluent : SecondaryEffluent;
			in item chlorine : Chlorine;
			out item treatedEffluent : TreatedEffluent;
		}
		action def DigestSludge {
			in item primarySludge : PrimarySludge;
			in item wasteSludge : WasteActivatedSludge;
			out item digestedSludge : DigestedSludge;
		}
		action def InitializeSystems;
		action def RunTreatmentProcess;
		action def PerformMaintenance;
		action def FlushAndSecure;

		state def PlantStates;

		requirement def TreatedEffluentQuality {
			attribute maxBOD : Concentration = 30.0;
			attribute maxTSS : Concentration = 30.0;
			attribute maxColiform : PathogenCount = 200.0;
			attribute minpH : Real = 6.0;
			attribute maxpH : Real = 9.0;
			requirement {
				subject effluent : TreatedEffluent;
				require constraint { effluent.bod <= maxBOD }
				require constraint { effluent.tss <= maxTSS }
				require constraint { effluent.coliform <= maxColiform }
				require constraint { effluent.pH >= minpH and effluent.pH <= maxpH }
			}
		}
		requirement def SludgeStability {
			attribute minVSR : Percentage = 38.0;
			requirement {
				subject sludge : DigestedSludge;
				require constraint { sludge.volatileSolidsReduction >= minVSR }
			}
		}
	}

	package Usages {
		private import Definitions::*;

		part treatmentPlant {
			attribute plantCapacity : VolumeValue;
			attribute inflowRate : FlowRate;

			port rawSewageInlet : WastewaterInPort;
			port treatedEffluentOutlet : WastewaterOutPort;
			port screeningsOutlet : SludgeOutPort;
			port gritOutlet : SludgeOutPort;
			port digestedSludgeOutlet : SludgeOutPort;
			port airIntake : AirInPort;
			port chlorineIntake : ChemicalInPort;

			part screeningUnit : ScreeningUnit {
				perform action screenWastewater : ScreenWastewater {
					in item rawSewage = wastewaterIn.wastewater;
					out item screenedWastewater = wastewaterOut.wastewater;
					out item screenings = screeningsOut.sludge;
				}
			}
			part gritChamber : GritChamber {
				perform action removeGrit : RemoveGrit {
					in item screenedWastewater = wastewaterIn.wastewater;
					out item degrittedWastewater = wastewaterOut.wastewater;
					out item grit = gritOut.sludge;
				}
			}
			part primaryClarifier : PrimaryClarifier {
				perform action primarySettling : PrimarySettling {
					in item degrittedWastewater = wastewaterIn.wastewater;
					out item primaryEffluent = effluentOut.wastewater;
					out item primarySludge = sludgeOut.sludge;
				}
			}
			part aerationBasin : AerationBasin {
				perform action aerateAndTreat : AerateAndTreat {
					in item primaryEffluent = wastewaterIn.wastewater;
					in item returnSludge = recycleIn.recycle;
					in item air = airIn.air;
					out item mixedLiquor = mixedLiquorOut.wastewater;
				}
			}
			part secondaryClarifier : SecondaryClarifier {
				perform action secondarySettling : SecondarySettling {
					in item mixedLiquor = mixedLiquorIn.wastewater;
					out item secondaryEffluent = effluentOut.wastewater;
					out item wasteSludge = wasteSludgeOut.sludge;
					out item returnSludge = recycleOut.recycle;
				}
			}
			part disinfectionChamber : DisinfectionChamber {
				perform action disinfect : Disinfect {
					in item secondaryEffluent = wastewaterIn.wastewater;
					in item chlorine = chemicalIn.chemical;
					out item treatedEffluent = effluentOut.wastewater;
				}
			}
			part anaerobicDigester : AnaerobicDigester {
				perform action digestSludge : DigestSludge {
					in item primarySludge = sludgeIn1.sludge;
					in item wasteSludge = sludgeIn2.sludge;
					out item digestedSludge = digestedSludgeOut.sludge;
				}
			}
			part blower : Blower;
			part chlorineDosingSystem : ChlorineDosingSystem;

			flow of wastewater : RawSewage
				from rawSewageInlet.wastewater to screeningUnit.wastewaterIn.wastewater;
			flow of wastewater : ScreenedWastewater
				from screeningUnit.wastewaterOut.wastewater to gritChamber.wastewaterIn.wastewater;
			flow of wastewater : DegrittedWastewater
				from gritChamber.wastewaterOut.wastewater to primaryClarifier.wastewaterIn.wastewater;
			flow of wastewater : PrimaryEffluent
				from primaryClarifier.effluentOut.wastewater to aerationBasin.wastewaterIn.wastewater;
			flow of wastewater : MixedLiquor
				from aerationBasin.mixedLiquorOut.wastewater to secondaryClarifier.mixedLiquorIn.wastewater;
			flow of wastewater : SecondaryEffluent
				from secondaryClarifier.effluentOut.wastewater to disinfectionChamber.wastewaterIn.wastewater;
			flow of wastewater : TreatedEffluent
				from disinfectionChamber.effluentOut.wastewater to treatedEffluentOutlet.wastewater;
			flow of sludge : PrimarySludge
				from primaryClarifier.sludgeOut.sludge to anaerobicDigester.sludgeIn1.sludge;
			flow of sludge : WasteActivatedSludge
				from secondaryClarifier.wasteSludgeOut.sludge to anaerobicDigester.sludgeIn2.sludge;
			flow of recycle : ReturnActivatedSludge
				from secondaryClarifier.recycleOut.recycle to aerationBasin.recycleIn.recycle;
			flow of air : Air
				from airIntake.air to blower.airIn.air;
			flow of air : Air
				from blower.airOut.air to aerationBasin.airIn.air;
			flow of chemical : Chlorine
				from chlorineIntake.chemical to chlorineDosingSystem.chemicalIn.chemical;
			flow of chemical : Chlorine
				from chlorineDosingSystem.chemicalOut.chemical to disinfectionChamber.chemicalIn.chemical;
			flow of sludge : Screenings
				from screeningUnit.screeningsOut.sludge to screeningsOutlet.sludge;
			flow of sludge : Grit
				from gritChamber.gritOut.sludge to gritOutlet.sludge;
			flow of sludge : DigestedSludge
				from anaerobicDigester.digestedSludgeOut.sludge to digestedSludgeOutlet.sludge;

			exhibit state plantStates : PlantStates parallel {
				state operationalStates {
					entry; then offline;
					state offline;
					accept PlantStartSignal
						then startup;
					state startup {
						do action initializeSystems : InitializeSystems;
					}
					accept PlantOperationalSignal
						then operational;
					state operational {
						entry; then normalOperation;
						state normalOperation {
							do action runTreatmentProcess : RunTreatmentProcess;
						}
						accept MaintenanceSignal
							then maintenance;
						state maintenance {
							do action performMaintenance : PerformMaintenance;
						}
						accept ResumeOperationSignal
							then normalOperation;
					}
					accept PlantShutdownSignal
						then shutdown;
					state shutdown {
						do action flushAndSecure : FlushAndSecure;
					}
					accept PlantStartSignal
						then startup;
				}
				state healthStates {
					entry; then normal;
					state normal;
					accept when aerationBasin.dissolvedOxygen < 1.0
						then warning;
					state warning;
					accept ResumeOperationSignal
						then normal;
					accept when disinfectionChamber.chlorineDose <= 0.0
						then faulted;
					state faulted;
					accept ResumeOperationSignal
						then normal;
				}
			}

			requirement effluentQuality : TreatedEffluentQuality {
				subject effluent = disinfectionChamber.disinfect.treatedEffluent;
			}
			requirement sludgeStability : SludgeStability {
				subject sludge = anaerobicDigester.digestSludge.digestedSludge;
			}
		}
	}

	public import Definitions::*;
	public import Usages::*;
}
