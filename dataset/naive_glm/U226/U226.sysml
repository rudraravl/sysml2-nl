package SmartFirstAidKitModel {
    import ScalarValues::*;
    
    // ============================================================
    // Dimensions and Units
    // ============================================================
    dimension Count;
    unit count : Count;
    
    dimension Mass;
    unit g : Mass;
    
    dimension Length;
    unit cm : Length;
    unit mm : Length;
    
    dimension Temperature;
    unit degC : Temperature;
    
    dimension Time;
    unit s : Time;
    unit min : Time;
    
    // ============================================================
    // Value Types
    // ============================================================
    value type MassValue :> Real {
        :>> unit = g;
    }
    
    value type QuantityValue :> Integer {
        :>> unit = count;
    }
    
    value type TemperatureValue :> Real {
        :>> unit = degC;
    }
    
    value type LengthValue :> Real {
        :>> unit = cm;
    }
    
    value type TimeValue :> Real {
        :>> unit = s;
    }
    
    // ============================================================
    // Enumerations
    // ============================================================
    enum def InjuryType {
        literal cut;
        literal burn;
        literal sprain;
        literal scrape;
        literal bruise;
        literal fracture;
    }
    
    enum def InjurySeverity {
        literal minor;
        literal moderate;
        literal severe;
        literal critical;
    }
    
    enum def SupplyCategory {
        literal bandage;
        literal antiseptic;
        literal medication;
        literal tool;
        literal protective;
        literal other;
    }
    
    enum def DispenseStatus {
        literal success;
        literal insufficientStock;
        literal error;
    }
    
    // ============================================================
    // Item Definitions - Medical Supplies
    // ============================================================
    item def MedicalSupply {
        attribute id : String;
        attribute name : String;
        attribute category : SupplyCategory;
        attribute minStock : QuantityValue;
        attribute currentStock : QuantityValue;
        attribute massPerUnit : MassValue;
    }
    
    item def AdhesiveBandage :> MedicalSupply {
        :>> name = "Adhesive Bandage";
        :>> category = bandage;
        attribute size : LengthValue;
    }
    
    item def GauzeBandage :> MedicalSupply {
        :>> name = "Gauze Bandage";
        :>> category = bandage;
        attribute width : LengthValue;
        attribute length : LengthValue;
    }
    
    item def ElasticBandage :> MedicalSupply {
        :>> name = "Elastic Bandage";
        :>> category = bandage;
        attribute width : LengthValue;
    }
    
    item def AntisepticWipe :> MedicalSupply {
        :>> name = "Antiseptic Wipe";
        :>> category = antiseptic;
    }
    
    item def AntisepticSpray :> MedicalSupply {
        :>> name = "Antiseptic Spray";
        :>> category = antiseptic;
        attribute volumeML : Integer;
    }
    
    item def PainMedication :> MedicalSupply {
        :>> name = "Pain Medication";
        :>> category = medication;
        attribute doseMG : Integer;
    }
    
    item def DisposableGloves :> MedicalSupply {
        :>> name = "Disposable Gloves";
        :>> category = protective;
        attribute gloveSize : String;
    }
    
    item def Scissors :> MedicalSupply {
        :>> name = "Scissors";
        :>> category = tool;
        attribute bladeLength : LengthValue;
    }
    
    item def Tweezers :> MedicalSupply {
        :>> name = "Tweezers";
        :>> category = tool;
        attribute totalLength : LengthValue;
    }
    
    item def Thermometer :> MedicalSupply {
        :>> name = "Digital Thermometer";
        :>> category = tool;
        attribute measurementRange : TemperatureValue;
    }
    
    // ============================================================
    // Data Item Definitions
    // ============================================================
    item def InjuryReport {
        attribute injuryType : InjuryType;
        attribute severity : InjurySeverity;
        attribute bodyLocation : String;
        attribute description : String;
    }
    
    item def TreatmentStep {
        attribute stepNumber : Integer;
        attribute instruction : String;
        attribute suppliesNeeded : String[0..*];
    }
    
    item def TreatmentPlan {
        attribute planId : String;
        attribute injuryType : InjuryType;
        attribute severity : InjurySeverity;
        attribute steps : TreatmentStep[0..*];
        attribute requiredSupplies : String[0..*];
        attribute estimatedDuration : TimeValue;
    }
    
    item def DispenseRequest {
        attribute requestId : String;
        attribute itemIds : String[0..*];
        attribute quantities : QuantityValue[0..*];
    }
    
    item def DispenseResult {
        attribute status : DispenseStatus;
        attribute dispensedItemIds : String[0..*];
        attribute dispensedQuantities : QuantityValue[0..*];
        attribute errorMessage : String;
    }
    
    item def RestockAlert {
        attribute supplyId : String;
        attribute supplyName : String;
        attribute currentStock : QuantityValue;
        attribute minStock : QuantityValue;
        attribute message : String;
    }
    
    // ============================================================
    // Port Definitions
    // ============================================================
    port def InjuryReportIn {
        in injuryReport : InjuryReport;
    }
    
    port def InjuryReportOut {
        out injuryReport : InjuryReport;
    }
    
    port def TreatmentPlanIn {
        in treatmentPlan : TreatmentPlan;
    }
    
    port def TreatmentPlanOut {
        out treatmentPlan : TreatmentPlan;
    }
    
    port def DispenseRequestIn {
        in dispenseRequest : DispenseRequest;
    }
    
    port def DispenseRequestOut {
        out dispenseRequest : DispenseRequest;
    }
    
    port def DispenseResultIn {
        in dispenseResult : DispenseResult;
    }
    
    port def DispenseResultOut {
        out dispenseResult : DispenseResult;
    }
    
    port def RestockAlertIn {
        in restockAlert : RestockAlert;
    }
    
    port def RestockAlertOut {
        out restockAlert : RestockAlert;
    }
    
    // ============================================================
    // Part Definitions - Subsystems
    // ============================================================
    part def WaterproofContainer {
        attribute material : String;
        attribute ipRating : String;
        attribute externalLength : LengthValue;
        attribute externalWidth : LengthValue;
        attribute externalHeight : LengthValue;
        attribute internalLength : LengthValue;
        attribute internalWidth : LengthValue;
        attribute internalHeight : LengthValue;
        attribute maxPayload : MassValue;
        attribute emptyMass : MassValue;
    }
    
    part def StorageCompartment {
        attribute compartmentId : String;
        attribute totalCapacity : QuantityValue;
        attribute usedCapacity : QuantityValue;
    }
    
    part def UserInterface {
        port reportIn : InjuryReportIn;
        port reportForwardOut : InjuryReportOut;
        port planReceiveIn : TreatmentPlanIn;
        port planDisplayOut : TreatmentPlanOut;
        port alertReceiveIn : RestockAlertIn;
        port alertDisplayOut : RestockAlertOut;
        
        attribute displayType : String;
        attribute inputMethod : String;
        attribute languageSupport : String[0..*];
        
        action def receiveInjuryReport {
            in report : InjuryReport;
        }
        
        action def displayTreatmentPlan {
            in plan : TreatmentPlan;
        }
        
        action def displayRestockAlert {
            in alert : RestockAlert;
        }
    }
    
    part def AssessmentEngine {
        port reportIn : InjuryReportIn;
        port planOut : TreatmentPlanOut;
        port stockQueryOut : DispenseRequestOut;
        port stockAvailIn : DispenseResultIn;
        port dispenseReqOut : DispenseRequestOut;
        port dispenseResultIn : DispenseResultIn;
        
        attribute knowledgeBaseVersion : String;
        attribute supportedInjuries : InjuryType[0..*];
        
        action def assessInjury {
            in report : InjuryReport;
            out plan : TreatmentPlan;
        }
        
        action def identifyRequiredSupplies {
            in plan : TreatmentPlan;
            out request : DispenseRequest;
        }
    }
    
    part def InventoryTracker {
        port stockQueryIn : DispenseRequestIn;
        port stockAvailOut : DispenseResultOut;
        port stockUpdateIn : DispenseResultIn;
        port alertOut : RestockAlertOut;
        
        attribute totalSKU : QuantityValue;
        attribute lastUpdateTimestamp : TimeValue;
        
        action def checkStock {
            in request : DispenseRequest;
            out availability : DispenseResult;
        }
        
        action def updateStockCounts {
            in result : DispenseResult;
        }
        
        action def checkRestockNeeded {
            out alerts : RestockAlert[0..*];
        }
    }
    
    part def Dispenser {
        port dispenseReqIn : DispenseRequestIn;
        port dispenseResultOut : DispenseResultOut;
        
        attribute mechanismType : String;
        attribute dispenseSpeed : QuantityValue;
        
        action def dispenseItems {
            in request : DispenseRequest;
            out result : DispenseResult;
        }
    }
    
    // ============================================================
    // State Machine Definition
    // ============================================================
    state def SmartFirstAidKitStates {
        attribute injuryReportReceived : Boolean = false;
        attribute treatmentPlanReady : Boolean = false;
        attribute dispenseComplete : Boolean = false;
        attribute treatmentComplete : Boolean = false;
        attribute inventoryUpdated : Boolean = false;
        
        state idle {
            doc /* System waits for an injury report from the user. */;
        }
        
        state assessing {
            doc /* System assesses the injury and generates a step-by-step treatment plan. */;
        }
        
        state dispensing {
            doc /* System checks stock, selects and dispenses required supplies. */;
        }
        
        state guiding {
            doc /* System provides step-by-step treatment guidance to the user. */;
        }
        
        state updatingInventory {
            doc /* System updates stock counts and checks for restock alerts. */;
        }
        
        transition from idle to assessing when injuryReportReceived;
        transition from assessing to dispensing when treatmentPlanReady;
        transition from dispensing to guiding when dispenseComplete;
        transition from guiding to updatingInventory when treatmentComplete;
        transition from updatingInventory to idle when inventoryUpdated;
    }
    
    // ============================================================
    // Main System Part
    // ============================================================
    part def SmartFirstAidKit {
        // External ports
        port extReportIn : InjuryReportIn;
        port extPlanOut : TreatmentPlanOut;
        port extAlertOut : RestockAlertOut;
        
        // State machine
        state machine operatingStates : SmartFirstAidKitStates;
        
        // Container
        part container : WaterproofContainer {
            :>> material = "ABS Polycarbonate";
            :>> ipRating = "IP67";
            :>> externalLength = 30.0;
            :>> externalWidth = 22.0;
            :>> externalHeight = 18.0;
            :>> internalLength = 28.0;
            :>> internalWidth = 20.0;
            :>> internalHeight = 16.0;
            :>> maxPayload = 5000;
            :>> emptyMass = 1500;
        }
        
        // Storage compartment
        part storage : StorageCompartment {
            :>> compartmentId = "MAIN";
            :>> totalCapacity = 50;
            :>> usedCapacity = 10;
        }
        
        // Medical supplies inventory
        part adhesiveBandage : AdhesiveBandage {
            :>> id = "AB001";
            :>> minStock = 10;
            :>> currentStock = 20;
            :>> massPerUnit = 2;
            :>> size = 7.5;
        }
        
        part gauzeBandage : GauzeBandage {
            :>> id = "GB001";
            :>> minStock = 5;
            :>> currentStock = 10;
            :>> massPerUnit = 15;
            :>> width = 7.5;
            :>> length = 450;
        }
        
        part elasticBandage : ElasticBandage {
            :>> id = "EB001";
            :>> minStock = 3;
            :>> currentStock = 5;
            :>> massPerUnit = 50;
            :>> width = 7.5;
        }
        
        part antisepticWipe : AntisepticWipe {
            :>> id = "AW001";
            :>> minStock = 15;
            :>> currentStock = 25;
            :>> massPerUnit = 5;
        }
        
        part antisepticSpray : AntisepticSpray {
            :>> id = "AS001";
            :>> minStock = 2;
            :>> currentStock = 3;
            :>> massPerUnit = 120;
            :>> volumeML = 60;
        }
        
        part painMedication : PainMedication {
            :>> id = "PM001";
            :>> minStock = 10;
            :>> currentStock = 20;
            :>> massPerUnit = 0.5;
            :>> doseMG = 500;
        }
        
        part disposableGloves : DisposableGloves {
            :>> id = "DG001";
            :>> minStock = 10;
            :>> currentStock = 15;
            :>> massPerUnit = 8;
            :>> gloveSize = "Medium";
        }
        
        part scissors : Scissors {
            :>> id = "SC001";
            :>> minStock = 1;
            :>> currentStock = 1;
            :>> massPerUnit = 80;
            :>> bladeLength = 8;
        }
        
        part tweezers : Tweezers {
            :>> id = "TW001";
            :>> minStock = 1;
            :>> currentStock = 1;
            :>> massPerUnit = 30;
            :>> totalLength = 12;
        }
        
        part thermometer : Thermometer {
            :>> id = "TH001";
            :>> minStock = 1;
            :>> currentStock = 1;
            :>> massPerUnit = 25;
            :>> measurementRange = 42.0;
        }
        
        // Subsystem parts
        part ui : UserInterface {
            :>> displayType = "Touch LCD";
            :>> inputMethod = "Touchscreen + Voice";
            :>> languageSupport = ["English", "Spanish", "French"];
        }
        
        part assessment : AssessmentEngine {
            :>> knowledgeBaseVersion = "v2.1";
            :>> supportedInjuries = [cut, burn, sprain, scrape, bruise, fracture];
        }
        
        part inventory : InventoryTracker {
            :>> totalSKU = 10;
            :>> lastUpdateTimestamp = 0;
        }
        
        part dispenser : Dispenser {
            :>> mechanismType = "Motorized Drawer";
            :>> dispenseSpeed = 5;
        }
        
        // Delegation connections: external ports to internal UI ports
        connect extReportIn to ui.reportIn;
        connect ui.planDisplayOut to extPlanOut;
        connect ui.alertDisplayOut to extAlertOut;
        
        // Flow connections: internal subsystem communication
        connect ui.reportForwardOut to assessment.reportIn;
        connect assessment.planOut to ui.planReceiveIn;
        connect assessment.stockQueryOut to inventory.stockQueryIn;
        connect inventory.stockAvailOut to assessment.stockAvailIn;
        connect assessment.dispenseReqOut to dispenser.dispenseReqIn;
        connect dispenser.dispenseResultOut to assessment.dispenseResultIn;
        connect dispenser.dispenseResultOut to inventory.stockUpdateIn;
        connect inventory.alertOut to ui.alertReceiveIn;
    }
    
    // ============================================================
    // Requirements
    // ============================================================
    requirement def GuidedCareReq {
        doc
            /* The smart first-aid kit shall provide guided emergency medical care
               by assessing injuries and generating treatment plans. */;
    }
    
    requirement def InjuryReportingReq {
        doc
            /* The system shall accept injury reports from a user specifying
               injury type and severity through the user interface. */;
    }
    
    requirement def TreatmentPlanReq {
        doc
            /* The system shall generate step-by-step treatment plans based on
               the reported injury type and severity. */;
    }
    
    requirement def StockCheckReq {
        doc
            /* The system shall check its internal stock to ensure required supplies
               are available before dispensing. */;
    }
    
    requirement def DispensingReq {
        doc
            /* The system shall dispense identified supplies from its storage
               compartment when stock is available. */;
    }
    
    requirement def InventoryTrackingReq {
        doc
            /* The system shall monitor the quantity of all supplies and update
               stock counts after items are used. */;
    }
    
    requirement def RestockAlertReq {
        doc
            /* The system shall alert the owner when any supply level drops below
               its predefined minimum stock threshold. */;
    }
    
    requirement def StateSequenceReq {
        doc
            /* The system shall cycle through idle, assessing, dispensing, guiding,
               and inventory updating states before returning to idle. */;
    }
    
    requirement def WaterproofReq {
        doc
            /* The container shall be waterproof and durable for portable field use. */;
    }
    
    requirement def DiverseSuppliesReq {
        doc
            /* The kit shall contain adhesive bandages, gauze bandages, elastic
               bandages, antiseptic wipes, antiseptic spray, pain medication,
               disposable gloves, scissors, tweezers, and a thermometer. */;
    }
    
    requirement def PortableReq {
        doc
            /* The system shall be portable and housed in a durable waterproof
               container suitable for emergency field use. */;
    }
    
    // ============================================================
    // Satisfaction
    // ============================================================
    satisfy GuidedCareReq by SmartFirstAidKit;
    satisfy InjuryReportingReq by UserInterface;
    satisfy TreatmentPlanReq by AssessmentEngine;
    satisfy StockCheckReq by InventoryTracker;
    satisfy DispensingReq by Dispenser;
    satisfy InventoryTrackingReq by InventoryTracker;
    satisfy RestockAlertReq by InventoryTracker;
    satisfy StateSequenceReq by SmartFirstAidKitStates;
    satisfy WaterproofReq by WaterproofContainer;
    satisfy DiverseSuppliesReq by StorageCompartment;
    satisfy PortableReq by WaterproofContainer;
}
