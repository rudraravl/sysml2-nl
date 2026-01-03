package MedicalBagSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ExpirationDate {
        attribute year : Integer;
        attribute month : Integer;
        attribute day : Integer;
    }
    
    attribute def SterilityStatus {
        attribute isSterile : Boolean;
        attribute certificationDate : ExpirationDate;
    }
    
    item def MedicalSupply {
        attribute itemName : String;
        attribute quantity : Integer;
        attribute expirationDate : ExpirationDate;
        attribute mass : MassValue;
    }
    
    item def Medication :> MedicalSupply {
        attribute dosageMg : Real;
        attribute activeIngredient : String;
        attribute administrationRoute : String;
    }
    
    item def SterileInstrument :> MedicalSupply {
        attribute instrumentType : String;
        attribute sterilityStatus : SterilityStatus;
    }
    
    item def Bandage :> MedicalSupply {
        attribute length : LengthValue;
        attribute width : LengthValue;
        attribute material : String;
    }
    
    item def Antiseptic :> MedicalSupply {
        attribute volumeMl : Real;
        attribute concentration : Real;
    }
    
    item def PatientVitals {
        attribute heartRate : Real;
        attribute bloodPressureSystolic : PressureValue;
        attribute bloodPressureDiastolic : PressureValue;
        attribute bodyTemperature : TemperatureValue;
        attribute respiratoryRate : Real;
    }
    
    item def TreatmentRecord {
        attribute patientID : String;
        attribute timestamp : String;
        attribute suppliesUsed : MedicalSupply[*];
        attribute vitals : PatientVitals;
    }
    
    port def SupplyAccessPort {
        out item supply : MedicalSupply;
    }
    
    port def VitalsMonitorPort {
        in item vitals : PatientVitals;
    }
    
    port def TreatmentPort {
        in item record : TreatmentRecord;
    }
    
    part def StorageCompartment {
        attribute compartmentID : String;
        attribute maxCapacity : Integer;
        attribute currentLoad : Integer;
        attribute temperatureMin : TemperatureValue;
        attribute temperatureMax : TemperatureValue;
        port accessPort : SupplyAccessPort;
    }
    
    part def MedicationCompartment :> StorageCompartment {
        item medications : Medication[0..*];
    }
    
    part def InstrumentCompartment :> StorageCompartment {
        item instruments : SterileInstrument[0..*];
    }
    
    part def WoundCareCompartment :> StorageCompartment {
        item bandages : Bandage[0..*];
        item antiseptics : Antiseptic[0..*];
    }
    
    part def InventoryManager {
        attribute totalItemCount : Integer;
        attribute lastInventoryCheck : String;
        
        action def UpdateInventory {
            in item addedSupply : MedicalSupply;
            in attribute currentCount : Integer;
            out attribute updatedCount : Integer;
        }
        
        action def CheckExpiration {
            in item supply : MedicalSupply;
            in attribute currentDate : ExpirationDate;
            out attribute isExpired : Boolean;
        }
        
        action def VerifySterility {
            in item instrument : SterileInstrument;
            out attribute isValid : Boolean;
        }
    }
    
    part def DiagnosticModule {
        port vitalsPort : VitalsMonitorPort;
        
        action def AssessPatient {
            in item vitals : PatientVitals;
            out attribute severity : String;
            out attribute recommendedSupplies : MedicalSupply[*];
        }
    }
    
    part def MedicalBag {
        attribute bagID : String;
        attribute totalMass : MassValue;
        attribute maxMass : MassValue;
        attribute isSealed : Boolean;
        
        part medicationStorage : MedicationCompartment {
            attribute :>> compartmentID = "MED-01";
            attribute :>> maxCapacity = 20;
            attribute :>> currentLoad = 0;
            attribute :>> temperatureMin = 288.15 [K];
            attribute :>> temperatureMax = 298.15 [K];
        }
        
        part instrumentStorage : InstrumentCompartment {
            attribute :>> compartmentID = "INST-01";
            attribute :>> maxCapacity = 15;
            attribute :>> currentLoad = 0;
            attribute :>> temperatureMin = 283.15 [K];
            attribute :>> temperatureMax = 303.15 [K];
        }
        
        part woundCareStorage : WoundCareCompartment {
            attribute :>> compartmentID = "WOUND-01";
            attribute :>> maxCapacity = 25;
            attribute :>> currentLoad = 0;
            attribute :>> temperatureMin = 278.15 [K];
            attribute :>> temperatureMax = 308.15 [K];
        }
        
        part inventory : InventoryManager {
            attribute :>> totalItemCount = 0;
        }
        
        part diagnostics : DiagnosticModule;
        
        port treatmentPort : TreatmentPort;
        
        connection medToInventory connect 
            medicationStorage.accessPort to inventory;
        
        connection instToInventory connect 
            instrumentStorage.accessPort to inventory;
        
        connection woundToInventory connect 
            woundCareStorage.accessPort to inventory;
        
        perform action provideEmergencyCare;
    }
    
    action def OpenBag {
        inout attribute sealed : Boolean;
        out attribute success : Boolean;
    }
    
    action def CloseBag {
        inout attribute sealed : Boolean;
        out attribute success : Boolean;
    }
    
    action def RetrieveSupply {
        in attribute supplyType : String;
        in attribute compartmentID : String;
        out item retrievedSupply : MedicalSupply;
        out attribute retrievalSuccess : Boolean;
    }
    
    action def AssessPatientCondition {
        in item vitals : PatientVitals;
        out attribute urgencyLevel : String;
        out attribute treatmentPlan : String;
    }
    
    action def AdministerTreatment {
        in item supplies : MedicalSupply[*];
        in attribute treatmentPlan : String;
        out item treatmentRecord : TreatmentRecord;
    }
    
    action def RestockSupply {
        in item newSupply : MedicalSupply;
        in attribute targetCompartment : String;
        out attribute restockSuccess : Boolean;
    }
    
    action def ProvideEmergencyCare {
        first start;
        
        then action openBag : OpenBag {
            inout attribute bagSealed : Boolean;
            out attribute opened : Boolean;
        }
        
        then action assessPatient : AssessPatientCondition {
            in item patientVitals : PatientVitals;
            out attribute urgency : String;
            out attribute plan : String;
        }
        
        then decide;
            if assessPatient.urgency == "critical" then retrieveCriticalSupplies;
            if assessPatient.urgency == "moderate" then retrieveStandardSupplies;
            if assessPatient.urgency == "minor" then retrieveBasicSupplies;
        
        action retrieveCriticalSupplies : RetrieveSupply {
            in attribute supplyType = "medication";
            in attribute compartmentID = "MED-01";
            out item supply : MedicalSupply;
            out attribute success : Boolean;
        }
        then merge treatmentJunction;
        
        action retrieveStandardSupplies : RetrieveSupply {
            in attribute supplyType = "instrument";
            in attribute compartmentID = "INST-01";
            out item supply : MedicalSupply;
            out attribute success : Boolean;
        }
        then treatmentJunction;
        
        action retrieveBasicSupplies : RetrieveSupply {
            in attribute supplyType = "bandage";
            in attribute compartmentID = "WOUND-01";
            out item supply : MedicalSupply;
            out attribute success : Boolean;
        }
        then treatmentJunction;
        
        then action administerTreatment : AdministerTreatment {
            in item treatmentSupplies : MedicalSupply[*];
            in attribute treatmentPlan = assessPatient.plan;
            out item record : TreatmentRecord;
        }
        
        then action closeBag : CloseBag {
            inout attribute bagSealed : Boolean;
            out attribute closed : Boolean;
        }
        
        then done;
    }
    
    requirement def MedicalBagSystemRequirements {
        doc /* Requirements for emergency medical bag system. */
        
        requirement <'REQ-001'> rapidAccess {
            doc /* All medical supplies shall be accessible within 15 seconds of bag opening. */
            subject bag : MedicalBag;
            require constraint {
                doc /* Access time constraint for emergency response */
            }
        }
        
        requirement <'REQ-002'> sterilityMaintenance {
            doc /* All sterile instruments shall maintain sterility throughout storage and retrieval. */
            subject compartment : InstrumentCompartment;
            require constraint {
                doc /* Sterility verification and maintenance required */
            }
        }
        
        requirement <'REQ-003'> temperatureControl {
            doc /* Storage compartments shall maintain specified temperature ranges for supply integrity. */
            subject compartment : StorageCompartment;
            require constraint {
                compartment.temperatureMin <= compartment.temperatureMax
            }
        }
        
        requirement <'REQ-004'> inventoryTracking {
            doc /* The system shall track all supplies including quantities and expiration dates. */
            subject manager : InventoryManager;
            require constraint {
                doc /* Real-time inventory monitoring required */
            }
        }
        
        requirement <'REQ-005'> massLimit {
            doc /* The total mass of the medical bag shall not exceed maximum portable mass. */
            subject bag : MedicalBag;
            require constraint {
                bag.totalMass <= bag.maxMass
            }
        }
        
        requirement <'REQ-006'> compartmentCapacity {
            doc /* No storage compartment shall exceed its maximum capacity. */
            subject compartment : StorageCompartment;
            require constraint {
                compartment.currentLoad <= compartment.maxCapacity
            }
        }
    }
    
    requirement primaryMissionRequirement {
        doc /* The medical bag system shall provide organized, rapid access to essential medical supplies 
                and equipment for emergency medical treatment in field conditions, enabling healthcare 
                providers to assess patient condition and administer appropriate care. */
        
        assume constraint fieldOperationalConditions {
            doc /* System operates in variable environmental conditions with limited infrastructure */
        }
        
        assume constraint trainedOperator {
            doc /* System is operated by trained medical personnel */
        }
        
        require MedicalBagSystemRequirements::rapidAccess;
        require MedicalBagSystemRequirements::sterilityMaintenance;
        require MedicalBagSystemRequirements::temperatureControl;
        require MedicalBagSystemRequirements::inventoryTracking;
        require MedicalBagSystemRequirements::massLimit;
        require MedicalBagSystemRequirements::compartmentCapacity;
    }
    
    part emergencyMedicalBag : MedicalBag {
        attribute :>> bagID = "EMB-2024-001";
        attribute :>> maxMass = 6.0 [kg];
        attribute :>> totalMass = 4.5 [kg];
        attribute :>> isSealed = true;
        
        perform action emergencyResponse : ProvideEmergencyCare;
    }
}
