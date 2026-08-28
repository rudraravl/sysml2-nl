package FlatPackFurnitureSystem {

    private import ScalarValues::*;
    private import SI::kg;
    private import SI::m;

    item def FurnitureConcept {
        attribute conceptID : String;
        attribute name : String;
        attribute targetCost : Real;
        attribute renewableMaterialFraction : Real;
        attribute recyclableMaterialFraction : Real;
    }

    item def FurniturePart {
        attribute partID : String;
        attribute partName : String;
        attribute materialType : String;
        attribute partMass : Real;
        attribute partLength : Real;
        attribute isRenewable : Boolean;
        attribute isRecyclable : Boolean;
    }

    item def AssemblyInstructions {
        attribute instructionID : String;
        attribute stepCount : Integer;
        attribute instructionLanguage : String;
    }

    item def HardwareComponent {
        attribute hardwareID : String;
        attribute hardwareType : String;
        attribute quantity : Integer;
    }

    item def FlatPackBox {
        attribute boxID : String;
        attribute productSKU : String;
        attribute totalMass : Real;
        attribute boxDimensions : String;
        attribute partCount : Integer;
    }

    item def AssembledFurniture {
        attribute furnitureID : String;
        attribute productName : String;
        attribute fullyAssembled : Boolean;
    }

    item def CustomerFeedback {
        attribute feedbackID : String;
        attribute rating : Integer;
        attribute feedbackText : String;
    }

    item def PurchaseOrder {
        attribute orderID : String;
        attribute customerID : String;
        attribute productSKU : String;
        attribute quantity : Integer;
        attribute totalCost : Real;
        attribute orderDate : String;
    }

    item def ReplenishmentRequest {
        attribute requestID : String;
        attribute productSKU : String;
        attribute requestedQty : Integer;
        attribute priority : String;
    }

    item def ShippingManifest {
        attribute manifestID : String;
        attribute boxIDs : String;
        attribute destination : String;
        attribute shipDate : String;
    }

    item def SupportTicket {
        attribute ticketID : String;
        attribute customerID : String;
        attribute issueType : String;
        attribute resolved : Boolean;
    }

    port def ConceptPortDef {
        out item concept : FurnitureConcept;
    }
    port def PartPortDef {
        out item furniturePart : FurniturePart;
    }
    port def FlatPackPortDef {
        out item flatPack : FlatPackBox;
    }
    port def InstructionsPortDef {
        out item instructions : AssemblyInstructions;
    }
    port def HardwarePortDef {
        out item hardware : HardwareComponent;
    }
    port def FeedbackPortDef {
        out item feedback : CustomerFeedback;
    }
    port def OrderPortDef {
        out item order : PurchaseOrder;
    }
    port def ReplenishmentPortDef {
        out item request : ReplenishmentRequest;
    }
    port def ManifestPortDef {
        out item manifest : ShippingManifest;
    }
    port def SupportTicketPortDef {
        out item ticket : SupportTicket;
    }
    port def AssembledFurniturePortDef {
        out item displayFurniture : AssembledFurniture;
    }

    requirement AffordabilityRequirement {
        doc /* Products must be priced for mass-market appeal. */
        attribute targetCost : Real;
        constraint { targetCost <= 500.0 }
    }
    requirement EfficiencyRequirement {
        doc /* Flat-pack model must reduce shipping and storage costs. */
        attribute totalMass : Real;
        constraint { totalMass <= 30.0 }
    }
    requirement SelfAssemblyRequirement {
        doc /* Customers must be able to assemble the product using clear, simple instructions. */
        attribute stepCount : Integer;
        constraint { stepCount <= 20 }
    }
    requirement DesignQualityRequirement {
        doc /* Furniture must meet good design quality standards. */
        attribute rating : Integer;
        constraint { rating >= 70 }
    }
    requirement SustainabilityRequirement {
        doc /* Products must use renewable and recyclable materials. */
        attribute renewableMaterialFraction : Real;
        attribute recyclableMaterialFraction : Real;
        constraint { renewableMaterialFraction >= 0.6 }
        constraint { recyclableMaterialFraction >= 0.8 }
    }
    requirement CustomerSupportRequirement {
        doc /* Customer service must resolve support tickets efficiently. */
        attribute resolved : Boolean;
        constraint { resolved == true }
    }

    action def DesignNewConcept {
        in feedback : CustomerFeedback;
        out concept : FurnitureConcept;
    }
    action def ManufactureParts {
        in concept : FurnitureConcept;
        out parts : FurniturePart;
        out hardware : HardwareComponent;
    }
    action def PackageFlatPack {
        in parts : FurniturePart;
        in hardware : HardwareComponent;
        in concept : FurnitureConcept;
        out flatPack : FlatPackBox;
        out instructions : AssemblyInstructions;
    }
    action def ManageInventoryAction {
        in flatPack : FlatPackBox;
        in request : ReplenishmentRequest;
        out dispatchedPack : FlatPackBox;
        out manifest : ShippingManifest;
    }
    action def AssembleDisplayModel {
        in flatPack : FlatPackBox;
        out displayFurniture : AssembledFurniture;
    }
    action def ProcessOrder {
        in order : PurchaseOrder;
        in flatPack : FlatPackBox;
        out request : ReplenishmentRequest;
        out flatPackRequest : FlatPackBox;
        out confirmation : PurchaseOrder;
    }
    action def ProvideSupport {
        in ticket : SupportTicket;
        out resolvedTicket : SupportTicket;
    }
    action def AssembleFurnitureAction {
        in flatPack : FlatPackBox;
        in instructions : AssemblyInstructions;
        out assembledFurniture : AssembledFurniture;
    }
    action def ProvideFeedback {
        out feedback : CustomerFeedback;
    }

    state def DesignLifecycle {
        initial state Researching;
        transition from Researching to Drafting;
        state Drafting;
        transition from Drafting to Reviewing;
        state Reviewing;
        transition from Reviewing to Approved;
        state Approved;
    }
    state def InventoryState {
        initial state Stocked;
        transition from Stocked to LowStock;
        state LowStock;
        transition from LowStock to Replenishing;
        state Replenishing;
        transition from Replenishing to Stocked;
    }
    state def CheckoutState {
        initial state Idle;
        transition from Idle to Processing;
        state Processing;
        transition from Processing to Completed;
        state Completed;
        transition from Completed to Idle;
    }
    state def SupportState {
        initial state Available;
        transition from Available to Assisting;
        state Assisting;
        transition from Assisting to Available;
    }
    state def CustomerJourney {
        initial state Browsing;
        transition from Browsing to Purchased;
        state Purchased;
        transition from Purchased to Assembling;
        state Assembling;
        transition from Assembling to Assembled;
        state Assembled;
        transition from Assembled to ProvidingFeedback;
        state ProvidingFeedback;
    }

    part def DesignStudio {
        attribute studioID : String;
        attribute location : String;
        in port feedbackIn : ~FeedbackPortDef;
        out port conceptOut : ConceptPortDef;
        perform designNewConcept : DesignNewConcept;
        state designLifecycle : DesignLifecycle;
    }

    part def ManufacturingLine {
        attribute lineID : String;
        in port conceptIn : ~ConceptPortDef;
        out port partOut : PartPortDef;
        out port hardwareOut : HardwarePortDef;
        perform manufactureParts : ManufactureParts;
    }

    part def PackagingStation {
        attribute stationID : String;
        in port partIn : ~PartPortDef;
        in port hardwareIn : ~HardwarePortDef;
        in port conceptIn : ~ConceptPortDef;
        out port flatPackOut : FlatPackPortDef;
        out port instructionsOut : InstructionsPortDef;
        perform packageFlatPack : PackageFlatPack;
    }

    part def ProductionFacility {
        attribute facilityID : String;
        attribute location : String;
        in port conceptIn : ~ConceptPortDef;
        out port flatPackOut : FlatPackPortDef;
        out port instructionsOut : InstructionsPortDef;

        part manufacturingLine : ManufacturingLine;
        part packagingStation : PackagingStation;

        connect conceptIn to manufacturingLine.conceptIn;
        connect conceptIn to packagingStation.conceptIn;
        connect manufacturingLine.partOut to packagingStation.partIn;
        connect manufacturingLine.hardwareOut to packagingStation.hardwareIn;
        connect packagingStation.flatPackOut to flatPackOut;
        connect packagingStation.instructionsOut to instructionsOut;
    }

    part def DistributionWarehouse {
        attribute warehouseID : String;
        attribute location : String;
        attribute maxCapacity : Integer;
        attribute currentStock : Integer;
        in port flatPackIn : ~FlatPackPortDef;
        in port replenishmentIn : ~ReplenishmentPortDef;
        out port flatPackOut : FlatPackPortDef;
        out port manifestOut : ManifestPortDef;
        perform manageInventory : ManageInventoryAction;
        state inventoryState : InventoryState;
    }

    part def DisplayArea {
        attribute areaID : String;
        in port flatPackIn : ~FlatPackPortDef;
        out port displayFurnitureOut : AssembledFurniturePortDef;
        perform assembleDisplayModel : AssembleDisplayModel;
    }

    part def RetailShowroom {
        attribute showroomID : String;
        attribute location : String;
        in port flatPackIn : ~FlatPackPortDef;
        in port feedbackIn : ~FeedbackPortDef;
        out port displayFurnitureOut : AssembledFurniturePortDef;
        out port feedbackOut : FeedbackPortDef;

        part displayArea : DisplayArea;

        connect flatPackIn to displayArea.flatPackIn;
        connect displayArea.displayFurnitureOut to displayFurnitureOut;
    }

    part def CheckoutCounter {
        attribute counterID : String;
        in port orderIn : ~OrderPortDef;
        in port flatPackIn : ~FlatPackPortDef;
        out port replenishmentOut : ReplenishmentPortDef;
        out port flatPackOut : FlatPackPortDef;
        out port orderConfirmationOut : OrderPortDef;
        perform processOrder : ProcessOrder;
        state checkoutState : CheckoutState;
    }

    part def CustomerServiceDesk {
        attribute deskID : String;
        in port ticketIn : ~SupportTicketPortDef;
        out port resolvedTicketOut : SupportTicketPortDef;
        perform provideSupport : ProvideSupport;
        state supportState : SupportState;
    }

    part def Customer {
        attribute customerID : String;
        attribute name : String;
        in port flatPackIn : ~FlatPackPortDef;
        in port instructionsIn : ~InstructionsPortDef;
        in port resolvedTicketIn : ~SupportTicketPortDef;
        out port feedbackOut : FeedbackPortDef;
        out port ticketOut : SupportTicketPortDef;
        out port orderOut : OrderPortDef;
        perform assembleFurniture : AssembleFurnitureAction;
        perform provideFeedback : ProvideFeedback;
        state customerJourney : CustomerJourney;
    }

    part FlatPackRetailSystem {
        doc
        /*
         * Complete business and operational system of a flat-pack furniture retailer.
         * Covers the lifecycle from design through manufacturing, distribution,
         * retail, and final customer self-assembly.
         */

        part designStudio : DesignStudio;
        part productionFacility : ProductionFacility;
        part distributionWarehouse : DistributionWarehouse;
        part retailShowroom : RetailShowroom;
        part checkoutCounter : CheckoutCounter;
        part customerServiceDesk : CustomerServiceDesk;
        part customer : Customer;

        connect designStudio.conceptOut to productionFacility.conceptIn;
        connect productionFacility.flatPackOut to distributionWarehouse.flatPackIn;
        connect productionFacility.flatPackOut to retailShowroom.flatPackIn;
        connect distributionWarehouse.flatPackOut to checkoutCounter.flatPackIn;
        connect checkoutCounter.replenishmentOut to distributionWarehouse.replenishmentIn;
        connect checkoutCounter.flatPackOut to customer.flatPackIn;
        connect productionFacility.instructionsOut to customer.instructionsIn;
        connect customer.feedbackOut to designStudio.feedbackIn;
        connect customer.feedbackOut to retailShowroom.feedbackIn;
        connect customer.orderOut to checkoutCounter.orderIn;
        connect customer.ticketOut to customerServiceDesk.ticketIn;
        connect customerServiceDesk.resolvedTicketOut to customer.resolvedTicketIn;
        connect retailShowroom.feedbackOut to designStudio.feedbackIn;

        satisfy AffordabilityRequirement by designStudio;
        satisfy EfficiencyRequirement by productionFacility;
        satisfy SelfAssemblyRequirement by customer;
        satisfy DesignQualityRequirement by designStudio;
        satisfy SustainabilityRequirement by productionFacility;
        satisfy CustomerSupportRequirement by customerServiceDesk;
    }
}
