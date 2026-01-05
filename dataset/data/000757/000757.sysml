package 'Medical Scrubs Management System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def ScrubSize;
	attribute def ScrubColor;
	attribute def ContaminationLevel;
	attribute def CleanlinessStandard;
	
	item def MedicalScrub {
		attribute size : ScrubSize;
		attribute color : ScrubColor;
		attribute contaminationLevel : Real;
		attribute wearTime : TimeValue;
		attribute isClean : Boolean;
	}
	
	item def DetergentSolution {
		attribute concentration : Real;
		attribute volume : VolumeValue;
	}
	
	item def WashCycle {
		attribute temperature : TemperatureValue;
		attribute duration : TimeValue;
		attribute agitationSpeed : Real;
	}
	
	attribute def IssueRequest;
	attribute def ContaminationThresholdReached;
	attribute def CollectionEvent;
	attribute def CollectionComplete;
	attribute def SortingComplete;
	attribute def WashingStart;
	attribute def WashingComplete;
	attribute def DryingComplete;
	attribute def InspectionPass;
	attribute def InspectionFail;
	attribute def PackagingComplete;
	attribute def StorageComplete;
	
	part def HealthcareWorker {
		attribute staffId : String;
		attribute department : String;
	}
	
	part def DispensaryUnit {
		attribute capacity : Integer;
		attribute availableInventory : MedicalScrub[*];
	}
	
	part def CollectionBin {
		attribute maxCapacity : Integer;
		attribute currentLoad : Integer;
	}
	
	part def IndustrialWasher {
		attribute washTemperature : TemperatureValue;
		attribute cycleTime : TimeValue;
		attribute loadCapacity : Integer;
	}
	
	part def IndustrialDryer {
		attribute dryingTemperature : TemperatureValue;
		attribute dryingTime : TimeValue;
	}
	
	part def QualityInspectionStation {
		attribute inspectorId : String;
		attribute rejectionRate : Real;
	}
	
	part def CleanStorageArea {
		attribute storageCapacity : Integer;
		attribute environmentalControls : Boolean;
	}
	
	action def IssueScrubs {
		in worker : HealthcareWorker;
		in requestedSize : ScrubSize;
		in requestedColor : ScrubColor;
		out issuedScrub : MedicalScrub;
	}
	
	action def CollectUsedScrubs {
		in usedScrub : MedicalScrub;
		out collectedScrub : MedicalScrub;
	}
	
	action def SortScrubs {
		in scrubBatch : MedicalScrub[*];
		out sortedByColor : MedicalScrub[*];
		out sortedByContamination : MedicalScrub[*];
	}
	
	action def WashScrubs {
		in dirtyScrubs : MedicalScrub[*];
		in washCycle : WashCycle;
		in detergent : DetergentSolution;
		out washedScrubs : MedicalScrub[*];
	}
	
	action def DryScrubs {
		in wetScrubs : MedicalScrub[*];
		in dryingTemp : TemperatureValue;
		in dryingDuration : TimeValue;
		out driedScrubs : MedicalScrub[*];
	}
	
	action def InspectScrubs {
		in scrubsToInspect : MedicalScrub[*];
		out passedScrubs : MedicalScrub[*];
		out failedScrubs : MedicalScrub[*];
	}
	
	action def FoldAndPackage {
		in inspectedScrubs : MedicalScrub[*];
		out packagedScrubs : MedicalScrub[*];
	}
	
	action def StoreScrubs {
		in cleanScrubs : MedicalScrub[*];
	}
	
	action def ManageScrubsLifecycle {
		first start;
		then merge readyForDistribution;
		
		action issue : IssueScrubs {
			in worker;
			in requestedSize;
			in requestedColor;
			out issuedScrub;
		}
		
		then merge inUse;
		
		then action collect : CollectUsedScrubs {
			in usedScrub = issue.issuedScrub;
			out collectedScrub;
		}
		
		then action sort : SortScrubs {
			in scrubBatch = { collect.collectedScrub };
			out sortedByColor;
			out sortedByContamination;
		}
		
		then action wash : WashScrubs {
			in dirtyScrubs = sort.sortedByColor;
			in washCycle;
			in detergent;
			out washedScrubs;
		}
		
		then action dry : DryScrubs {
			in wetScrubs = wash.washedScrubs;
			in dryingTemp;
			in dryingDuration;
			out driedScrubs;
		}
		
		then action inspect : InspectScrubs {
			in scrubsToInspect = dry.driedScrubs;
			out passedScrubs;
			out failedScrubs;
		}
		
		then decide qualityCheck;
			if inspect.passedScrubs->notEmpty() then foldAndPack;
			if inspect.failedScrubs->notEmpty() then wash;
		
		action foldAndPack : FoldAndPackage {
			in inspectedScrubs = inspect.passedScrubs;
			out packagedScrubs;
		}
		
		then action store : StoreScrubs {
			in cleanScrubs = foldAndPack.packagedScrubs;
		}
		
		then readyForDistribution;
	}
	
	state def ScrubLifecycleState {
		entry; then cleanInventory;
		
		state cleanInventory;
		transition cleanInventory_to_issued
			first cleanInventory
			accept IssueRequest
			then issued;
		
		state issued {
			entry; then beingWorn;
			
			state beingWorn;
			transition beingWorn_to_contaminated
				first beingWorn
				accept ContaminationThresholdReached
				then contaminated;
			
			state contaminated;
			transition contaminated_to_exit
				first contaminated
				accept CollectionEvent
				then exit;
		}
		
		transition issued_to_collected
			first issued
			accept CollectionComplete
			then collected;
		
		state collected;
		transition collected_to_sorted
			first collected
			accept SortingComplete
			then sorted;
		
		state sorted;
		transition sorted_to_washing
			first sorted
			accept WashingStart
			then washing;
		
		state washing;
		transition washing_to_drying
			first washing
			accept WashingComplete
			then drying;
		
		state drying;
		transition drying_to_inspecting
			first drying
			accept DryingComplete
			then inspecting;
		
		state inspecting;
		transition inspecting_to_packaging
			first inspecting
			accept InspectionPass
			then packaging;
		transition inspecting_to_washing_retry
			first inspecting
			accept InspectionFail
			then washing;
		
		state packaging;
		transition packaging_to_storing
			first packaging
			accept PackagingComplete
			then storing;
		
		state storing;
		transition storing_to_cleanInventory
			first storing
			accept StorageComplete
			then cleanInventory;
	}
	
	part def ScrubsManagementSystem;
	
	part scrubsManagementSystem : ScrubsManagementSystem {
		part dispensary : DispensaryUnit {
			attribute capacity = 200;
		}
		
		part collectionBins : CollectionBin[5] {
			attribute maxCapacity = 50;
		}
		
		part washer : IndustrialWasher {
			attribute washTemperature : TemperatureValue = 75.0;
			attribute cycleTime : TimeValue = 45.0;
			attribute loadCapacity = 100;
		}
		
		part dryer : IndustrialDryer {
			attribute dryingTemperature : TemperatureValue = 65.0;
			attribute dryingTime : TimeValue = 30.0;
		}
		
		part inspectionStation : QualityInspectionStation;
		
		part cleanStorage : CleanStorageArea {
			attribute storageCapacity = 500;
			attribute environmentalControls = true;
		}
		
		part scrubInventory : MedicalScrub[500..1000] {
			exhibit state lifecycle : ScrubLifecycleState;
		}
		
		perform action manageCycle : ManageScrubsLifecycle {
			perform issue by dispensary;
			perform collect by collectionBins;
			perform wash by washer;
			perform dry by dryer;
			perform inspect by inspectionStation;
			perform store by cleanStorage;
		}
	}
	
	requirement def HygieneCompliance {
		doc /* All medical scrubs shall meet established cleanliness and decontamination standards to prevent cross-contamination and ensure patient and staff safety. */
		
		subject scrub : MedicalScrub;
		
		require constraint {
			scrub.contaminationLevel <= 0.05
		}
	}
	
	requirement def AvailabilityRequirement {
		doc /* The system shall maintain sufficient clean scrubs inventory to ensure continuous availability for all healthcare workers across all shifts. */
		
		subject system : ScrubsManagementSystem;
	}
	
	requirement def TurnaroundTimeRequirement {
		doc /* The system shall complete the full scrubs processing cycle from collection through cleaning to storage within 4 hours to maintain operational efficiency. */
		
		subject system : ScrubsManagementSystem;
	}
	
	requirement def TemperatureRequirement {
		doc /* Washing cycles shall maintain minimum temperature of 71 degrees Celsius for at least 25 minutes to ensure effective pathogen elimination. */
		
		subject washer : IndustrialWasher;
	}
	
	requirement <'SCRUBS-SYS-001'> primarySystemRequirement {
		doc /* The Medical Scrubs Management System shall provide a comprehensive, automated solution for issuing, collecting, 
		decontaminating, inspecting, and redistributing medical scrubs to healthcare workers, ensuring continuous availability 
		of clean, safe protective garments while maintaining strict hygiene standards and operational efficiency throughout 
		the healthcare facility. */
		
		subject scrubsManagementSystem : ScrubsManagementSystem;
		
		assume constraint adequateInfrastructure {
			doc /* The facility provides adequate utilities including water, steam, electricity, and drainage for industrial laundry operations. */
		}
		
		require hygieneReq : HygieneCompliance;
		
		require availabilityReq : AvailabilityRequirement;
		
		require turnaroundReq : TurnaroundTimeRequirement;
		
		require tempReq : TemperatureRequirement;
	}
}
