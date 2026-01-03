package OstomySystemModel {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def StomaType;
	attribute def EffluentConsistency;
	attribute def SkinCondition;
	
	item def BodilyEffluent {
		attribute volume : VolumeValue;
		attribute consistency : EffluentConsistency;
	}
	
	item def Flatus {
		attribute pressure : PressureValue;
	}
	
	port def StomaOutputPort {
		out item effluent : BodilyEffluent;
		out item gas : Flatus;
	}
	
	port def BarrierInputPort {
		in item effluent : BodilyEffluent;
		in item gas : Flatus;
	}
	
	port def BarrierOutputPort {
		out item effluent : BodilyEffluent;
		out item gas : Flatus;
	}
	
	port def PouchInputPort {
		in item effluent : BodilyEffluent;
		in item gas : Flatus;
	}
	
	port def SkinContactPort {
		attribute contactArea : AreaValue;
		attribute adhesionStrength : ForceValue;
		attribute skinCondition : SkinCondition;
	}
	
	part def Stoma {
		port output : StomaOutputPort;
		attribute stomaType : StomaType;
		attribute diameter : LengthValue;
		
		perform action produceEffluent {
			out item effluentOutput : BodilyEffluent;
			out item gasOutput : Flatus;
		}
	}
	
	part def SkinBarrier {
		port skinSide : SkinContactPort;
		port stomaInput : BarrierInputPort;
		port pouchOutput : BarrierOutputPort;
		
		attribute adhesiveType : String;
		attribute wearTime : DurationValue;
		attribute isWaterResistant : Boolean;
		attribute currentAdhesion : ForceValue;
		
		perform action maintainSeal {
			in adhesion : ForceValue;
			in duration : DurationValue;
			out sealIntegrity : Boolean;
		}
		
		perform action protectSkin {
			in effluentContact : Boolean;
			out skinProtected : Boolean;
		}
	}
	
	part def OdorFilter {
		attribute filterMaterial : String;
		attribute filterEfficiency : Real;
		
		perform action filterOdor {
			in item gasInput : Flatus;
			out item gasOutput : Flatus;
		}
	}
	
	part def CollectionPouch {
		port inlet : PouchInputPort;
		
		attribute capacity : VolumeValue;
		attribute currentVolume : VolumeValue;
		attribute material : String;
		attribute isOpaque : Boolean;
		attribute isDrainable : Boolean;
		
		part odorFilter : OdorFilter {
			attribute filterMaterial = "activated carbon";
			attribute filterEfficiency = 0.95;
		}
		
		perform action collectEffluent {
			in item effluentInput : BodilyEffluent;
			inout volume : VolumeValue;
			out fillLevel : Real;
		}
		
		perform action ventGas {
			in item gasInput : Flatus;
		}
	}
	
	action def MonitorFillLevel {
		in currentVolume : VolumeValue;
		in capacity : VolumeValue;
		out fillPercentage : Real;
		out requiresEmptying : Boolean;
	}
	
	action def CheckSealIntegrity {
		in adhesionStrength : ForceValue;
		in wearDuration : DurationValue;
		out sealIntact : Boolean;
		out replacementNeeded : Boolean;
	}
	
	action def EmptyPouch {
		in currentVolume : VolumeValue;
		out volumeRemaining : VolumeValue;
	}
	
	action def ReplaceAppliance {
		in wearTime : DurationValue;
		in sealCondition : Boolean;
		out replacementComplete : Boolean;
	}
	
	state def ApplianceLifecycleState {
		entry; then initial;
		
		state initial;
		transition initial_to_applied
			first initial
			then applied;
		
		state applied;
		transition applied_to_collecting
			first applied
			then collecting;
		
		state collecting;
		transition collecting_to_nearFull
			first collecting
			then nearFull;
		
		state nearFull;
		transition nearFull_to_emptying
			first nearFull
			then emptying;
		
		state emptying;
		transition emptying_to_collecting
			first emptying
			then collecting;
		
		transition collecting_to_sealDegraded
			first collecting
			then sealDegraded;
		
		state sealDegraded;
		transition sealDegraded_to_replacing
			first sealDegraded
			then replacing;
		
		state replacing;
		transition replacing_to_initial
			first replacing
			then initial;
	}
	
	requirement def <'REQ-OST-001'> PrimaryFunctionRequirement {
		doc /* 
		The ostomy system shall safely collect and contain bodily waste 
		discharged through a surgically created stoma opening.
		*/
		
		subject ostomySystem : OstomyAppliance;
		
		require constraint {
			doc /* The system shall prevent leakage during normal wear conditions. */
			ostomySystem.barrier.currentAdhesion >= 5.0 [SI::N]
		}
		
		require constraint {
			doc /* The collection pouch shall have minimum capacity for typical wear duration. */
			ostomySystem.pouch.capacity >= 400.0 [SI::mL]
		}
	}
	
	requirement def <'REQ-OST-002'> SkinProtectionRequirement {
		doc /* 
		The ostomy system shall protect peristomal skin from contact 
		with effluent to prevent skin breakdown and irritation.
		*/
		
		require constraint {
			doc /* The skin barrier shall maintain complete seal around stoma perimeter. */
		}
		
		require constraint {
			doc /* The barrier adhesive shall be hypoallergenic and skin-safe. */
		}
	}
	
	requirement def <'REQ-OST-003'> OdorControlRequirement {
		doc /* 
		The ostomy system shall minimize odor emission to maintain 
		user dignity and quality of life.
		*/
		
		require constraint {
			doc /* The integrated filter shall reduce odor by minimum 90 percent. */
		}
	}
	
	requirement def <'REQ-OST-004'> WearTimeRequirement {
		doc /* 
		The ostomy system shall maintain secure adhesion and seal 
		integrity for minimum wear duration.
		*/
		
		require constraint {
			doc /* The barrier shall remain securely adhered for at least 24 hours. */
		}
	}
	
	part def OstomyAppliance {
		doc /* 
		An ostomy appliance is a medical device system designed to collect 
		bodily waste discharged through a surgically created opening (stoma) 
		in the abdominal wall.
		
		The system's primary function is to safely and hygienically contain 
		effluent from the digestive or urinary system, protect the surrounding 
		peristomal skin from contact with waste, control odor emissions, and 
		provide the user with security, comfort, and dignity in daily activities.
		
		The appliance operates continuously and passively. As waste is expelled 
		through the stoma, it flows into a skin barrier that adheres securely 
		to the peristomal skin, then into a collection pouch that stores the 
		effluent. An integrated odor filter allows gas to escape while 
		neutralizing odors. Users periodically empty or replace the pouch 
		based on fill level, and replace the entire appliance when the skin 
		barrier adhesion degrades or at regular intervals to maintain skin health.
		*/
		
		part patientStoma : Stoma {
			port output;
			attribute diameter = 25.0 [SI::mm];
		}
		
		part barrier : SkinBarrier {
			port skinSide;
			port stomaInput;
			port pouchOutput;
			
			attribute adhesiveType = "hydrocolloid";
			attribute wearTime = 48.0 [SI::h];
			attribute isWaterResistant = true;
			attribute currentAdhesion = 8.0 [SI::N];
		}
		
		part pouch : CollectionPouch {
			port inlet;
			
			attribute capacity = 500.0 [SI::mL];
			attribute currentVolume = 0.0 [SI::mL];
			attribute material = "odor-barrier film";
			attribute isOpaque = true;
			attribute isDrainable = true;
			
			part odorFilter : OdorFilter;
		}
		
		connection stomaToBarrier connect 
			patientStoma.output to barrier.stomaInput;
		
		connection barrierToPouch connect 
			barrier.pouchOutput to pouch.inlet;
		
		perform action manageOstomySystem {
			first start;
			then merge continuousOperation;
			
			action monitorFill : MonitorFillLevel {
				in currentVolume = pouch.currentVolume;
				in capacity = pouch.capacity;
				out fillPercentage;
				out requiresEmptying;
			}
			
			then decide;
				if monitorFill.requiresEmptying then emptyAction;
				if not monitorFill.requiresEmptying then checkIntegrity;
			
			action emptyAction : EmptyPouch {
				in currentVolume = pouch.currentVolume;
				out volumeRemaining;
			}
			then continuousOperation;
			
			action checkIntegrity : CheckSealIntegrity {
				in adhesionStrength = barrier.currentAdhesion;
				in wearDuration = barrier.wearTime;
				out sealIntact;
				out replacementNeeded;
			}
			
			then decide;
				if checkIntegrity.replacementNeeded then replaceAction;
				if not checkIntegrity.replacementNeeded then continuousOperation;
			
			action replaceAction : ReplaceAppliance {
				in wearTime = barrier.wearTime;
				in sealCondition = checkIntegrity.sealIntact;
				out replacementComplete;
			}
			then done;
		}
	}
	
	part ostomySystem : OstomyAppliance {
		satisfy <'REQ-OST-001'> by ostomySystem;
		satisfy <'REQ-OST-002'> by barrier;
		satisfy <'REQ-OST-003'> by pouch.odorFilter;
		satisfy <'REQ-OST-004'> by barrier;
	}
}
