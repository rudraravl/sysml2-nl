package HyalobarrierAdhesionPreventionSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def HyaluronicAcidGel {
		attribute concentration : Real;
		attribute viscosity : DynamicViscosityValue;
		attribute volume : VolumeValue;
		attribute biocompatibilityIndex : Real;
	}
	
	item def TissueContact {
		attribute contactArea : AreaValue;
		attribute adhesionRisk : Real;
	}
	
	item def ApplicationCommand;
	item def ResorptionStatus;
	
	attribute def DurationDays : TimeValue;
	
	port def TissueInterfacePort {
		out attribute separationMaintained : Boolean;
		in item tissueContact : TissueContact;
		out attribute barrierThickness : LengthValue;
	}
	
	port def ApplicationPort {
		in item command : ApplicationCommand;
		out attribute applicationComplete : Boolean;
	}
	
	part def SurgicalTissue {
		attribute surfaceArea : AreaValue;
		attribute healingRate : Real;
		port tissueInterface : ~TissueInterfacePort;
	}
	
	part def HyalobarrierGel {
		attribute appliedVolume : VolumeValue;
		attribute gelThickness : LengthValue;
		attribute effectiveDuration : DurationDays;
		attribute resorptionRate : Real;
		
		port tissueContactA : TissueInterfacePort;
		port tissueContactB : TissueInterfacePort;
		port applicationInterface : ApplicationPort;
		
		state machine GelLifecycle {
			initial state packaged {
				entry assign gelThickness := 0.0[SI::mm];
				entry assign effectiveDuration := 0.0[SI::d];
			}
			
			transition packaged_to_applied
				first packaged
				accept ApplicationCommand
				then applied;
			
			state applied {
				entry assign gelThickness := 2.0[SI::mm];
				do action spreadGel;
			}
			
			transition applied_to_barrier
				first applied
				if gelThickness >= 1.5[SI::mm]
				then activeBarrier;
			
			state activeBarrier {
				entry assign effectiveDuration := 7.0[SI::d];
				do action maintainSeparation {
					out separationActive : Boolean;
				}
			}
			
			transition barrier_to_resorbing
				first activeBarrier
				if effectiveDuration >= 7.0[SI::d]
				then resorbing;
			
			state resorbing {
				do action gradualResorption {
					in resorptionRate : Real;
					out remainingVolume : VolumeValue;
				}
			}
			
			transition resorbing_to_absorbed
				first resorbing
				if appliedVolume <= 0.1[SI::mL]
				then absorbed;
			
			state absorbed;
		}
	}
	
	part def Applicator {
		attribute reservoirCapacity : VolumeValue;
		attribute deliveryRate : VolumeFlowRateValue;
		port deliveryPort : ApplicationPort;
		
		perform action deliverGel {
			in targetVolume : VolumeValue;
			in targetSite : SurgicalTissue;
			out deliveredVolume : VolumeValue;
		}
	}
	
	action def PreventPostSurgicalAdhesions {
		in attribute surgicalSiteArea : AreaValue;
		in attribute requiredBarrierDuration : DurationDays;
		out attribute adhesionPreventionEffectiveness : Real;
		
		first start;
		then merge monitoringCycle;
		
		then action prepareSite {
			in siteArea : AreaValue;
			out sitePrepared : Boolean;
		}
		
		then action applyBarrier {
			in gelVolume : VolumeValue;
			in applicationSite : AreaValue;
			out barrierEstablished : Boolean;
		}
		
		then action monitorBarrierIntegrity {
			out barrierIntact : Boolean;
			out currentThickness : LengthValue;
			out elapsedTime : DurationDays;
		}
		
		then decide;
			if monitorBarrierIntegrity.elapsedTime < requiredBarrierDuration and 
			   monitorBarrierIntegrity.barrierIntact then monitoringCycle;
			if monitorBarrierIntegrity.elapsedTime >= requiredBarrierDuration then evaluateOutcome;
		
		action evaluateOutcome {
			in barrierDuration : DurationDays;
			out effectiveness : Real;
		}
		
		then assign adhesionPreventionEffectiveness := evaluateOutcome.effectiveness;
		then done;
	}
	
	part def HyalobarrierSystem {
		doc /* A medical device system that prevents post-surgical tissue adhesions 
		       by creating a temporary physical barrier between healing tissue surfaces 
		       using a bioresorbable hyaluronic acid-based gel. */
		
		attribute systemTemperature : ThermodynamicTemperatureValue;
		attribute operationalStatus : String;
		attribute targetAdhesionReduction : Real;
		
		part gel : HyalobarrierGel {
			attribute :>> appliedVolume = 10.0[SI::mL];
			attribute :>> gelThickness = 2.0[SI::mm];
			attribute :>> effectiveDuration = 7.0[SI::d];
			attribute :>> resorptionRate = 0.15;
		}
		
		part applicator : Applicator {
			attribute :>> reservoirCapacity = 20.0[SI::mL];
		}
		
		part surgicalSite {
			part tissue1 : SurgicalTissue {
				attribute :>> surfaceArea = 25.0[SI::cm^2];
			}
			part tissue2 : SurgicalTissue {
				attribute :>> surfaceArea = 25.0[SI::cm^2];
			}
		}
		
		connection applicatorToGel connect 
			applicator.deliveryPort to gel.applicationInterface;
		
		connection gelToTissue1 connect 
			gel.tissueContactA to surgicalSite.tissue1.tissueInterface;
		
		connection gelToTissue2 connect 
			gel.tissueContactB to surgicalSite.tissue2.tissueInterface;
		
		perform action primaryFunction : PreventPostSurgicalAdhesions {
			in surgicalSiteArea = 25.0[SI::cm^2];
			in requiredBarrierDuration = 7.0[SI::d];
			out adhesionPreventionEffectiveness;
		}
		
		exhibit state systemBehavior : gel.GelLifecycle;
	}
	
	requirement def <'REQ-001'> AdhesionPreventionCapability {
		doc /* The Hyalobarrier system shall prevent post-surgical adhesion formation 
		       by maintaining physical separation between adjacent tissue surfaces 
		       during the critical healing period. */
		
		subject system : HyalobarrierSystem;
		
		require constraint barrierDurationRequirement {
			system.gel.effectiveDuration >= 7.0[SI::d]
		}
		
		require constraint barrierThicknessRequirement {
			system.gel.gelThickness >= 1.5[SI::mm]
		}
	}
	
	requirement def <'REQ-002'> BioresorbabilityRequirement {
		doc /* The Hyalobarrier gel shall be fully bioresorbable within 30 days 
		       post-application without causing adverse tissue reactions. */
		
		subject gel : HyalobarrierGel;
		
		require constraint resorptionTimeConstraint {
			gel.effectiveDuration <= 30.0[SI::d]
		}
		
		require constraint biocompatibilityConstraint {
			gel.biocompatibilityIndex >= 0.95
		}
	}
	
	requirement def <'REQ-003'> ApplicationEffectiveness {
		doc /* The system shall deliver uniform gel coverage over the surgical site 
		       with consistent barrier thickness to ensure effective tissue separation. */
		
		subject system : HyalobarrierSystem;
		
		assume constraint surgicalSiteCondition {
			system.surgicalSite.tissue1.surfaceArea > 0.0[SI::cm^2] and
			system.surgicalSite.tissue2.surfaceArea > 0.0[SI::cm^2]
		}
		
		require constraint uniformCoverageConstraint {
			system.gel.gelThickness >= 1.5[SI::mm] and 
			system.gel.gelThickness <= 3.0[SI::mm]
		}
	}
	
	requirement <'SYS-001'> hyalobarrierMissionRequirement {
		doc /* The Hyalobarrier system provides temporary physical separation between 
		       healing tissue surfaces following surgical procedures to prevent 
		       post-operative adhesion formation, thereby reducing patient complications 
		       and improving surgical outcomes. */
		
		require AdhesionPreventionCapability;
		require BioresorbabilityRequirement;
		require ApplicationEffectiveness;
	}
}
