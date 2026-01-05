package FirstAidKitSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	item def MedicalSupply {
		attribute expirationDate : String;
		attribute quantity : Integer;
	}
	
	item def Bandage :> MedicalSupply {
		attribute bandageSize : String;
		attribute sterile : Boolean;
	}
	
	item def AdhesiveBandage :> Bandage;
	item def GauzePad :> Bandage;
	item def ElasticBandage :> Bandage;
	
	item def Antiseptic :> MedicalSupply {
		attribute concentration : Real;
	}
	
	item def AntisepticWipe :> Antiseptic;
	item def AntisepticSpray :> Antiseptic;
	
	item def PainMedication :> MedicalSupply {
		attribute dosage : String;
	}
	
	item def Gloves :> MedicalSupply {
		attribute material : String;
	}
	
	item def Scissors :> MedicalSupply;
	item def Tweezers :> MedicalSupply;
	item def Thermometer :> MedicalSupply;
	
	item def Injury {
		attribute injuryType : InjuryType;
		attribute severity : SeverityLevel;
		attribute location : String;
	}
	
	item def TreatmentPlan {
		attribute steps : String;
		attribute requiredSupplies : MedicalSupply[*];
	}
	
	enum def InjuryType {
		enum cut;
		enum burn;
		enum scrape;
		enum bruise;
		enum sprain;
		enum bite;
	}
	
	enum def SeverityLevel {
		enum minor;
		enum moderate;
		enum severe;
	}
	
	value def Mass :> ISQ::mass;
	value def Volume :> ISQ::volume;
	value def SupplyCount :> Integer;
	
	port def SupplyAccessPort {
		in item injuryReport : Injury;
		out item selectedSupplies : MedicalSupply[*];
	}
	
	port def InventoryManagementPort {
		in item resupplyRequest : MedicalSupply[*];
		out attribute stockLevel : SupplyCount;
	}
	
	port def UserInterfacePort {
		in item userRequest : Injury;
		out item treatmentGuidance : TreatmentPlan;
	}
	
	part def StorageCompartment {
		attribute capacity : SupplyCount;
		attribute currentStock : SupplyCount;
		port storagePort : SupplyAccessPort;
	}
	
	part def InventoryTracker {
		attribute minimumThreshold : SupplyCount;
		attribute restockLevel : SupplyCount;
		port trackingPort : InventoryManagementPort;
	}
	
	part def InstructionManual {
		attribute manualLanguage : String;
		attribute version : String;
	}
	
	part def Container {
		attribute material : String;
		attribute weight : Mass;
		attribute waterproof : Boolean;
	}
	
	action def AssessInjury {
		in item reportedInjury : Injury;
		out attribute severityLevel : SeverityLevel;
		out item plan : TreatmentPlan;
	}
	
	action def SelectSupplies {
		in item treatmentPlan : TreatmentPlan;
		in attribute availableStock : SupplyCount;
		out item supplies : MedicalSupply[*];
		out attribute sufficientStock : Boolean;
	}
	
	action def DispenseSupplies {
		in item requestedSupplies : MedicalSupply[*];
		out item dispensedSupplies : MedicalSupply[*];
	}
	
	action def ProvideTreatmentGuidance {
		in item injury : Injury;
		in item supplies : MedicalSupply[*];
		out item instructions : TreatmentPlan;
	}
	
	action def UpdateInventory {
		in item usedSupplies : MedicalSupply[*];
		out attribute newStockLevel : SupplyCount;
		out attribute needsRestock : Boolean;
	}
	
	action def AlertLowStock {
		in attribute currentLevel : SupplyCount;
		in attribute threshold : SupplyCount;
	}
	
	action def RestockSupplies {
		in item newSupplies : MedicalSupply[*];
		out attribute updatedStock : SupplyCount;
	}
	
	state def KitOperationalStates {
		entry; then idle;
		
		state idle {
			doc /* Kit is ready and waiting for injury report */
		}
		
		transition idle_to_assessing
			first idle
			accept injuryReport : Injury
			then assessing;
		
		state assessing {
			entry; then assess;
			action assess : AssessInjury;
			then selecting;
		}
		
		state selecting {
			entry; then selectAction;
			action selectAction : SelectSupplies;
			then checkStock;
		}
		
		state checkStock;
		transition stock_sufficient
			first checkStock
			if selectAction.sufficientStock
			then dispensing;
		transition stock_insufficient
			first checkStock
			if not selectAction.sufficientStock
			then alerting;
		
		state dispensing {
			entry; then dispense;
			action dispense : DispenseSupplies;
			then guiding;
		}
		
		state guiding {
			entry; then guide;
			action guide : ProvideTreatmentGuidance;
			then updating;
		}
		
		state updating {
			entry; then updateAction;
			action updateAction : UpdateInventory;
			then checkRestock;
		}
		
		state checkRestock;
		transition needs_restock
			first checkRestock
			if updateAction.needsRestock
			then alerting;
		transition no_restock_needed
			first checkRestock
			if not updateAction.needsRestock
			then idle;
		
		state alerting {
			entry; then alert;
			action alert : AlertLowStock;
			then idle;
		}
	}
	
	action def ProvideEmergencyCare {
		first start;
		then action receiveInjury accept injury : Injury;
		then action assessInjury : AssessInjury {
			in item reportedInjury = receiveInjury.injury;
			out attribute severityLevel;
			out item plan;
		}
		flow from assessInjury.plan to selectSupplies.treatmentPlan;
		then action selectSupplies : SelectSupplies {
			in item treatmentPlan;
			in attribute availableStock;
			out item supplies;
			out attribute sufficientStock;
		}
		then decide;
			if selectSupplies.sufficientStock then dispenseSupplies;
			if not selectSupplies.sufficientStock then alertLowStock;
		action dispenseSupplies : DispenseSupplies {
			in item requestedSupplies = selectSupplies.supplies;
			out item dispensedSupplies;
		}
		flow from dispenseSupplies.dispensedSupplies to provideGuidance.supplies;
		then action provideGuidance : ProvideTreatmentGuidance {
			in item injury = receiveInjury.injury;
			in item supplies;
			out item instructions;
		}
		then action updateInventory : UpdateInventory {
			in item usedSupplies = dispenseSupplies.dispensedSupplies;
			out attribute newStockLevel;
			out attribute needsRestock;
		}
		then decide;
			if updateInventory.needsRestock then alertLowStock;
			if not updateInventory.needsRestock then done;
		action alertLowStock : AlertLowStock {
			in attribute currentLevel = updateInventory.newStockLevel;
			in attribute threshold;
		}
		then done;
	}
	
	part def FirstAidKit {
		doc /* A portable emergency medical supply container designed to provide 
		       immediate care for common injuries and medical emergencies. */
		
		attribute kitIdentifier : String;
		attribute totalWeight : Mass;
		attribute lastInspectionDate : String;
		
		port userPort : UserInterfacePort;
		port supplyPort : SupplyAccessPort;
		port inventoryPort : InventoryManagementPort;
		
		part container : Container {
			attribute :>> material = "impact-resistant plastic";
			attribute :>> waterproof = true;
		}
		
		part storage : StorageCompartment {
			attribute :>> capacity = 100;
		}
		
		part tracker : InventoryTracker {
			attribute :>> minimumThreshold = 20;
			attribute :>> restockLevel = 80;
		}
		
		part manual : InstructionManual {
			attribute :>> manualLanguage = "English";
			attribute :>> version = "2.1";
		}
		
		ref part adhesiveBandages : AdhesiveBandage[*];
		ref part gauzePads : GauzePad[*];
		ref part elasticBandages : ElasticBandage[*];
		ref part antisepticWipes : AntisepticWipe[*];
		ref part antisepticSpray : AntisepticSpray[*];
		ref part painMedications : PainMedication[*];
		ref part disposableGloves : Gloves[*];
		ref part scissors : Scissors[*];
		ref part tweezers : Tweezers[*];
		ref part thermometer : Thermometer[*];
	}
	
	part emergencyFirstAidKit : FirstAidKit {
		attribute :>> kitIdentifier = "FAK-001";
		attribute :>> totalWeight = 1.5[kg];
		attribute :>> lastInspectionDate = "2024-01-15";
		
		part :>> storage {
			attribute :>> currentStock = 75;
		}
		
		part adhesiveBandages[30] : AdhesiveBandage {
			attribute :>> bandageSize = "standard";
			attribute :>> sterile = true;
			attribute :>> quantity = 30;
		}
		
		part gauzePads[20] : GauzePad {
			attribute :>> bandageSize = "4x4 inches";
			attribute :>> sterile = true;
			attribute :>> quantity = 20;
		}
		
		part elasticBandages[5] : ElasticBandage {
			attribute :>> bandageSize = "3 inch";
			attribute :>> quantity = 5;
		}
		
		part antisepticWipes[25] : AntisepticWipe {
			attribute :>> concentration = 70.0;
			attribute :>> quantity = 25;
		}
		
		part antisepticSpray[2] : AntisepticSpray {
			attribute :>> concentration = 75.0;
			attribute :>> quantity = 2;
		}
		
		part painMedications[10] : PainMedication {
			attribute :>> dosage = "500mg";
			attribute :>> quantity = 10;
		}
		
		part disposableGloves[12] : Gloves {
			attribute :>> material = "nitrile";
			attribute :>> quantity = 12;
		}
		
		part scissors[1] : Scissors {
			attribute :>> quantity = 1;
		}
		
		part tweezers[1] : Tweezers {
			attribute :>> quantity = 1;
		}
		
		part thermometer[1] : Thermometer {
			attribute :>> quantity = 1;
		}
		
		perform action emergencyCare[*] ordered references provideCare;
		exhibit state operationalState : KitOperationalStates;
		
		connect storage.storagePort to supplyPort;
		connect tracker.trackingPort to inventoryPort;
	}
	
	action provideCare : ProvideEmergencyCare;
	
	requirement def EmergencyCareRequirement {
		doc /* The first aid kit shall provide immediate access to medical supplies 
		       and treatment guidance for common injuries. */
		
		subject kit : FirstAidKit;
		
		require constraint adequateSupplyLevels {
			kit.storage.currentStock >= kit.tracker.minimumThreshold
		}
		
		require constraint portableWeight {
			kit.totalWeight <= 2.5[kg]
		}
	}
	
	requirement def SupplyDiversityRequirement {
		doc /* The first aid kit shall contain a diverse range of medical supplies 
		       to address multiple injury types. */
		
		subject kit : FirstAidKit;
		
		require constraint minimumBandages {
			kit.adhesiveBandages->size() >= 20
		}
		
		require constraint minimumAntiseptics {
			kit.antisepticWipes->size() >= 15
		}
		
		require constraint minimumGloves {
			kit.disposableGloves->size() >= 6
		}
		
		require constraint essentialTools {
			kit.scissors->size() >= 1 and kit.tweezers->size() >= 1
		}
	}
	
	requirement def ResponseTimeRequirement {
		doc /* The first aid kit shall enable rapid assessment and supply 
		       dispensing for injury treatment. */
		
		subject kit : FirstAidKit;
	}
	
	requirement primaryMission : EmergencyCareRequirement {
		doc /* The first aid kit system shall provide immediate emergency medical 
		       care by assessing injuries, dispensing appropriate medical supplies, 
		       providing treatment guidance, and maintaining adequate inventory levels 
		       to ensure continuous readiness for emergency response. */
		
		subject kit = emergencyFirstAidKit;
		
		assume constraint injuryOccurrence {
			doc /* An injury requiring immediate medical attention has occurred 
			       and been reported to the system. */
		}
		
		require adequateSupplyLevels;
		require portableWeight;
	}
	
	requirement supplyManagement : SupplyDiversityRequirement {
		doc /* The kit shall maintain comprehensive medical supply inventory. */
		
		subject kit = emergencyFirstAidKit;
		
		require minimumBandages;
		require minimumAntiseptics;
		require minimumGloves;
		require essentialTools;
	}
	
	requirement rapidResponse : ResponseTimeRequirement {
		doc /* The kit shall support quick injury assessment and treatment. */
		
		subject kit = emergencyFirstAidKit;
	}
}
