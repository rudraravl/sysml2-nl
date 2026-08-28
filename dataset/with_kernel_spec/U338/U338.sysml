package OrageneDNACollectionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	package Definitions {
		item def Fluid {
			attribute volume : VolumeValue;
		}
		item def Saliva :> Fluid;
		item def DNAStabilizationReagent :> Fluid {
			attribute isVirucidal : Boolean = true;
			attribute isBacteriostatic : Boolean = true;
		}
		item def StabilizedDNASample :> Fluid {
			attribute preservationYears : Real;
			attribute storageTemp : TemperatureValue;
		}
		
		port def FluidPort {
			inout item fluid : Fluid[0..*];
		}
		
		part def CollectionTube {
			attribute capacity : VolumeValue;
			attribute graduationMarks : VolumeValue[0..*];
			port openEnd : FluidPort;
			port capInterface : FluidPort;
			item rawSaliva : Saliva[0..1];
			item stabilizedSample : StabilizedDNASample[0..1];
		}
		
		part def CollectionFunnel {
			attribute isAttached : Boolean = false;
			port tubeInterface : FluidPort;
			port mouthpiece : FluidPort;
		}
		
		part def ReagentReservoir {
			attribute isSealed : Boolean = true;
			item reagent : DNAStabilizationReagent[1];
			port outlet : FluidPort;
		}
		
		part def SealingCap {
			attribute isSealed : Boolean = true;
			attribute isAttached : Boolean = false;
			port tubeInterface : FluidPort;
			part reservoir : ReagentReservoir {
				attribute isPierced : Boolean = false;
			}
		}
		
		part def OrageneKit {
			part collectionTube : CollectionTube;
			part collectionFunnel : CollectionFunnel;
			part sealingCap : SealingCap;
		}
		
		action def ProvideSalivaSample {
			in person : String;
			out saliva : Saliva;
		}
		
		action def AttachFunnel {
			inout tube : CollectionTube;
			inout funnel : CollectionFunnel;
		}
		
		action def RemoveFunnel {
			inout tube : CollectionTube;
			inout funnel : CollectionFunnel;
		}
		
		action def SecureCap {
			inout tube : CollectionTube;
			inout cap : SealingCap;
		}
		
		action def ReleaseReagent {
			inout cap : SealingCap;
			out reagent : DNAStabilizationReagent;
		}
		
		action def MixContents {
			in saliva : Saliva;
			in reagent : DNAStabilizationReagent;
			out stabilizedSample : StabilizedDNASample;
		}
		
		action def CollectionWorkflow {
			in person : String;
			inout tube : CollectionTube;
			inout funnel : CollectionFunnel;
			inout cap : SealingCap;
			out finalSample : StabilizedDNASample;
			
			action provideSample : ProvideSalivaSample {
				in person = person;
				out saliva;
			}
			action attachFunnel : AttachFunnel {
				inout tube = tube;
				inout funnel = funnel;
			}
			action removeFunnel : RemoveFunnel {
				inout tube = tube;
				inout funnel = funnel;
			}
			action secureCap : SecureCap {
				inout tube = tube;
				inout cap = cap;
			}
			action releaseReagent : ReleaseReagent {
				inout cap = cap;
				out reagent;
			}
			action mixContents : MixContents {
				in saliva = provideSample.saliva;
				in reagent = releaseReagent.reagent;
				out stabilizedSample = finalSample;
			}
			
			succeed provideSample then attachFunnel;
			succeed attachFunnel then removeFunnel;
			succeed removeFunnel then secureCap;
			succeed secureCap then releaseReagent;
			succeed releaseReagent then mixContents;
		}
		
		state def KitState {
			state Unassembled;
			state ReadyForCollection;
			state SampleCollected;
			state CapSecured {
				state ReagentReleased;
				state Mixed;
				transition first ReagentReleased then Mixed;
			}
			state SealedForStorage;
			
			transition first Unassembled then ReadyForCollection;
			transition first ReadyForCollection then SampleCollected;
			transition first SampleCollected then CapSecured;
			transition first CapSecured then SealedForStorage;
		}
		
		requirement def PreservationRequirement {
			doc /* The system must preserve DNA at room temperature for years. */
			attribute minPreservationYears : Real = 5;
			attribute maxStorageTemp : TemperatureValue = 25 [degC];
			subject sample : StabilizedDNASample;
			requirement {
				doc /* Sample preservation duration must meet minimum. */
			}
			requirement {
				doc /* Sample must be storable at ambient temperature. */
			}
		}
		
		requirement def NonInvasiveCollectionRequirement {
			doc /* Collection must be non-invasive and self-administered. */
			subject kit : OrageneKit;
			requirement {
				doc /* The kit must support self-collection of saliva. */
			}
		}
		
		requirement def ReagentReleaseRequirement {
			doc /* Closing the cap must automatically release the reagent. */
			subject cap : SealingCap;
			requirement {
				doc /* Cap reservoir must be pierced upon sealing. */
			}
		}
	}
	
	package Usages {
		private import Definitions::*;
		
		part orageneKit : OrageneKit {
			part collectionTube : CollectionTube {
				attribute capacity = 4 [mL];
				attribute graduationMarks = (2 [mL], 4 [mL]);
			}
			part collectionFunnel : CollectionFunnel;
			part sealingCap : SealingCap {
				part reservoir : ReagentReservoir {
					item reagent : DNAStabilizationReagent {
						attribute volume = 1 [mL];
					}
				}
			}
			
			connection funnelToTube : FluidPort connect collectionFunnel.tubeInterface to collectionTube.openEnd;
			connection capToTube : FluidPort connect sealingCap.tubeInterface to collectionTube.capInterface;
			connection reagentToTube : FluidPort connect sealingCap.reservoir.outlet to collectionTube.capInterface;
			
			perform action workflow : CollectionWorkflow {
				in person = "Self-Collector";
				inout tube = collectionTube;
				inout funnel = collectionFunnel;
				inout cap = sealingCap;
				out finalSample;
			}
			
			exhibit state kitState : KitState;
		}
		
		requirement preservationReq : PreservationRequirement {
			subject sample = orageneKit.collectionTube.stabilizedSample;
		}
		requirement nonInvasiveReq : NonInvasiveCollectionRequirement {
			subject kit = orageneKit;
		}
		requirement reagentReleaseReq : ReagentReleaseRequirement {
			subject cap = orageneKit.sealingCap;
		}
	}
}
