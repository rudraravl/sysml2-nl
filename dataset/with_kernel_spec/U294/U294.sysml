package IntelligentEmergencyMedicalBag {
	private import ScalarValues::*;

	attribute def Temperature :> Real {
		doc
		/*
		 * Temperature value in degrees Celsius.
		 */
	}
	attribute def HeartRate :> Integer {
		doc
		/*
		 * Heart rate in beats per minute.
		 */
	}
	attribute def BloodPressure :> Integer {
		doc
		/*
		 * Blood pressure in mmHg.
		 */
	}
	attribute def Quantity :> Integer {
		doc
		/*
		 * Count of items.
		 */
	}
	attribute def Weight :> Real {
		doc
		/*
		 * Weight in grams.
		 */
	}

	enum def SterilityStatus {
		sterile;
		nonSterile;
		unknown;
	}

	enum def UrgencyLevel {
		critical;
		urgent;
		moderate;
		minor;
	}

	enum def SupplyCategory {
		medication;
		instrument;
		woundCare;
	}

	item def MedicalSupply {
		attribute name : String;
		attribute category : SupplyCategory;
		attribute quantity : Quantity;
		attribute expirationDate : String;
		attribute sterility : SterilityStatus = SterilityStatus::sterile;
		attribute minStorageTemp : Temperature;
		attribute maxStorageTemp : Temperature;
	}

	item def Medication :> MedicalSupply {
		attribute dosage : String;
		attribute activeIngredient : String;
	}

	item def SterileInstrument :> MedicalSupply {
		attribute instrumentType : String;
		attribute sterilizationMethod : String;
	}

	item def WoundCareItem :> MedicalSupply {
		attribute woundCareType : String;
	}

	item def TreatmentRecord {
		attribute patientId : String;
		attribute timestamp : String;
		attribute assessedUrgency : UrgencyLevel;
		attribute suppliesUsed : String [0..*];
		attribute notes : String [0..1];
	}

	port def CompartmentDataPort {
		attribute temperature : Temperature;
		attribute itemCount : Quantity;
		attribute category : SupplyCategory;
	}

	port def AlertPort {
		attribute alertMessage : String;
		attribute isCritical : Boolean;
	}

	port def VitalSignsPort {
		attribute heartRate : HeartRate;
		attribute systolicBP : BloodPressure;
		attribute diastolicBP : BloodPressure;
		attribute bodyTemp : Temperature;
	}

	port def SupplyRequestPort {
		attribute requestedCategory : SupplyCategory;
		attribute requestedQuantity : Quantity;
	}

	action def OpenBag {
		doc
		/*
		 * Opens the sealed bag for emergency use.
		 */
	}

	action def AssessPatient {
		doc
		/*
		 * Assess patient severity from vital signs.
		 */
		in heartRate : HeartRate;
		in systolicBP : BloodPressure;
		in diastolicBP : BloodPressure;
		in bodyTemp : Temperature;
		out urgency : UrgencyLevel;
	}

	action def RetrieveSupplies {
		doc
		/*
		 * Retrieve correct supplies based on assessed urgency.
		 */
		in urgency : UrgencyLevel;
		out request : SupplyRequestPort;
	}

	action def AdministerTreatment {
		doc
		/*
		 * Administer treatment using retrieved supplies.
		 */
		in supplies : SupplyRequestPort;
		in urgency : UrgencyLevel;
	}

	action def LogEvent {
		doc
		/*
		 * Log the treatment event in a treatment record.
		 */
		in record : TreatmentRecord;
	}

	part def Compartment {
		doc
		/*
		 * Base definition for a temperature-controlled storage compartment.
		 */
		port dataOut : CompartmentDataPort;
		attribute currentTemp : Temperature;
		attribute targetMinTemp : Temperature;
		attribute targetMaxTemp : Temperature;
		attribute compartmentType : SupplyCategory;
		item supplies : MedicalSupply [0..*];

		action maintainTemperature {
			doc
			/*
			 * Continuously monitor and maintain temperature within the target range.
			 */
		}
	}

	part def MedicationCompartment :> Compartment {
		doc
		/*
		 * Compartment for medications, maintained at 2 to 8 degrees Celsius.
		 */
		item medications : Medication [0..*];
	}

	part def InstrumentCompartment :> Compartment {
		doc
		/*
		 * Compartment for sterile instruments, maintained at 15 to 25 degrees Celsius.
		 */
		item instruments : SterileInstrument [0..*];
	}

	part def WoundCareCompartment :> Compartment {
		doc
		/*
		 * Compartment for general wound care items, maintained at 15 to 25 degrees Celsius.
		 */
		item woundCareItems : WoundCareItem [0..*];
	}

	part def InventoryManager {
		doc
		/*
		 * Electronic component that actively tracks every item in the bag.
		 */
		port dataIn : CompartmentDataPort [0..*];
		port alertOut : AlertPort;
		item trackedSupplies : MedicalSupply [0..*];
		attribute lastCheckTimestamp : String;

		action trackInventory {
			doc
			/*
			 * Track all items including quantity, expiration date, and sterility status.
			 */
		}

		action checkExpirations {
			doc
			/*
			 * Check for expired items and generate alerts.
			 */
		}

		action checkSterility {
			doc
			/*
			 * Check for non-sterile items and generate alerts.
			 */
		}

		action generateAlert {
			doc
			/*
			 * Generate an alert for expired or non-sterile items.
			 */
		}
	}

	part def DiagnosticModule {
		doc
		/*
		 * Decision-support tool that assesses patient condition and recommends supplies.
		 */
		port vitalSignsIn : VitalSignsPort;
		port recommendationOut : SupplyRequestPort;
		attribute assessedUrgency : UrgencyLevel;

		action assessPatient {
			doc
			/*
			 * Assess patient condition severity from input vital signs.
			 */
		}

		action recommendSupplies {
			doc
			/*
			 * Recommend appropriate supplies based on the assessed urgency level.
			 */
		}
	}

	state def EmergencyCareProcess {
		doc
		/*
		 * Core operational workflow for providing emergency care.
		 */
		state Sealed;
		state Assessing;
		state RetrievingSupplies;
		state Administering;
		state Logging;
		state Completed;

		transition from Sealed to Assessing;
		transition from Assessing to RetrievingSupplies;
		transition from RetrievingSupplies to Administering;
		transition from Administering to Logging;
		transition from Logging to Completed;
	}

	part def EmergencyMedicalBag {
		doc
		/*
		 * Intelligent emergency medical bag system for first responders and medical personnel.
		 */
		attribute bagWeight : Weight;
		attribute isSealed : Boolean = true;

		port vitalSignsInput : VitalSignsPort;
		port alertOutput : AlertPort;
		port supplyRequestOutput : SupplyRequestPort;

		part medicationCompartment : MedicationCompartment {
			compartmentType = SupplyCategory::medication;
			targetMinTemp = 2.0;
			targetMaxTemp = 8.0;
		}

		part instrumentCompartment : InstrumentCompartment {
			compartmentType = SupplyCategory::instrument;
			targetMinTemp = 15.0;
			targetMaxTemp = 25.0;
		}

		part woundCareCompartment : WoundCareCompartment {
			compartmentType = SupplyCategory::woundCare;
			targetMinTemp = 15.0;
			targetMaxTemp = 25.0;
		}

		part inventoryManager : InventoryManager;
		part diagnosticModule : DiagnosticModule;

		connect medicationCompartment.dataOut to inventoryManager.dataIn;
		connect instrumentCompartment.dataOut to inventoryManager.dataIn;
		connect woundCareCompartment.dataOut to inventoryManager.dataIn;
		connect inventoryManager.alertOut to alertOutput;
		connect vitalSignsInput to diagnosticModule.vitalSignsIn;
		connect diagnosticModule.recommendationOut to supplyRequestOutput;

		exhibit process : EmergencyCareProcess;
	}

	part fieldMedicalBag : EmergencyMedicalBag {
		bagWeight = 3500.0;

		part medicationCompartment {
			item epinephrine : Medication {
				name = "Epinephrine";
				category = SupplyCategory::medication;
				quantity = 5;
				expirationDate = "2025-12-31";
				sterility = SterilityStatus::sterile;
				minStorageTemp = 2.0;
				maxStorageTemp = 8.0;
				dosage = "1 mg/mL";
				activeIngredient = "Epinephrine";
			}
			item morphine : Medication {
				name = "Morphine";
				category = SupplyCategory::medication;
				quantity = 3;
				expirationDate = "2025-06-30";
				sterility = SterilityStatus::sterile;
				minStorageTemp = 2.0;
				maxStorageTemp = 8.0;
				dosage = "10 mg/mL";
				activeIngredient = "Morphine sulfate";
			}
		}

		part instrumentCompartment {
			item scalpel : SterileInstrument {
				name = "Scalpel";
				category = SupplyCategory::instrument;
				quantity = 2;
				expirationDate = "2027-01-01";
				sterility = SterilityStatus::sterile;
				minStorageTemp = 15.0;
				maxStorageTemp = 25.0;
				instrumentType = "Surgical scalpel";
				sterilizationMethod = "Autoclave";
			}
			item forceps : SterileInstrument {
				name = "Hemostatic Forceps";
				category = SupplyCategory::instrument;
				quantity = 4;
				expirationDate = "2027-01-01";
				sterility = SterilityStatus::sterile;
				minStorageTemp = 15.0;
				maxStorageTemp = 25.0;
				instrumentType = "Hemostatic forceps";
				sterilizationMethod = "Autoclave";
			}
		}

		part woundCareCompartment {
			item gauze : WoundCareItem {
				name = "Sterile Gauze Pads";
				category = SupplyCategory::woundCare;
				quantity = 20;
				expirationDate = "2026-03-31";
				sterility = SterilityStatus::sterile;
				minStorageTemp = 15.0;
				maxStorageTemp = 25.0;
				woundCareType = "Gauze pad";
			}
			item antiseptic : WoundCareItem {
				name = "Antiseptic Wipes";
				category = SupplyCategory::woundCare;
				quantity = 15;
				expirationDate = "2025-09-30";
				sterility = SterilityStatus::sterile;
				minStorageTemp = 15.0;
				maxStorageTemp = 25.0;
				woundCareType = "Antiseptic wipe";
			}
			item bandage : WoundCareItem {
				name = "Elastic Bandage";
				category = SupplyCategory::woundCare;
				quantity = 8;
				expirationDate = "2026-12-31";
				sterility = SterilityStatus::nonSterile;
				minStorageTemp = 15.0;
				maxStorageTemp = 25.0;
				woundCareType = "Elastic bandage roll";
			}
		}
	}

	requirement def PortabilityRequirement {
		doc
		/*
		 * The bag must be lightweight and portable for field use by first responders.
		 */
		subject bag : EmergencyMedicalBag;
		attribute maxWeight : Weight = 5000.0;
	}

	requirement def TemperatureControlRequirement {
		doc
		/*
		 * Each compartment must maintain supplies within the specified temperature range
		 * to ensure integrity and effectiveness.
		 */
		subject compartment : Compartment;
	}

	requirement def InventoryTrackingRequirement {
		doc
		/*
		 * The inventory manager must track all items with quantity, expiration date,
		 * and sterility status, and provide alerts for expired or non-sterile items.
		 */
		subject manager : InventoryManager;
	}

	requirement def DiagnosticSupportRequirement {
		doc
		/*
		 * The diagnostic module must assess patient severity from vital signs
		 * including heart rate, blood pressure, and temperature, and recommend
		 * appropriate supplies for treatment.
		 */
		subject module : DiagnosticModule;
	}

	requirement def RapidAccessRequirement {
		doc
		/*
		 * All supplies must be accessible within seconds of opening the bag.
		 */
		subject bag : EmergencyMedicalBag;
	}

	requirement def SterilityAssuranceRequirement {
		doc
		/*
		 * All supplies in the bag must remain sterile, effective, and ready for use.
		 */
		subject compartment : Compartment;
	}

	requirement portabilityCheck : PortabilityRequirement {
		subject bag = fieldMedicalBag;
	}

	requirement tempControlMed : TemperatureControlRequirement {
		subject compartment = fieldMedicalBag.medicationCompartment;
	}

	requirement tempControlInst : TemperatureControlRequirement {
		subject compartment = fieldMedicalBag.instrumentCompartment;
	}

	requirement tempControlWound : TemperatureControlRequirement {
		subject compartment = fieldMedicalBag.woundCareCompartment;
	}

	requirement inventoryCheck : InventoryTrackingRequirement {
		subject manager = fieldMedicalBag.inventoryManager;
	}

	requirement diagnosticCheck : DiagnosticSupportRequirement {
		subject module = fieldMedicalBag.diagnosticModule;
	}

	requirement rapidAccessCheck : RapidAccessRequirement {
		subject bag = fieldMedicalBag;
	}

	requirement sterilityMed : SterilityAssuranceRequirement {
		subject compartment = fieldMedicalBag.medicationCompartment;
	}

	requirement sterilityInst : SterilityAssuranceRequirement {
		subject compartment = fieldMedicalBag.instrumentCompartment;
	}

	requirement sterilityWound : SterilityAssuranceRequirement {
		subject compartment = fieldMedicalBag.woundCareCompartment;
	}
}
