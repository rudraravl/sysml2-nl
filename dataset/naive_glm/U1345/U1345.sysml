package FlatPackFurnitureRetailer {

    package ValueTypes {
        unit kg;
        unit USD;
        unit m;
        unit m3;
        unit ea;
        unit h;
        unit percent;

        value type Mass :> Real { unit kg; }
        value type Currency :> Real { unit USD; }
        value type Length :> Real { unit m; }
        value type Volume :> Real { unit m3; }
        value type Quantity :> Integer { unit ea; }
        value type Duration :> Real { unit h; }
        value type Percentage :> Real { unit percent; }
    }

    package ItemDefinitions {
        item def Material {
            attribute materialId : String;
            attribute renewable : Boolean;
            attribute recyclable : Boolean;
            attribute unitCost : Currency;
        }
        item def RenewableMaterial :> Material {
            attribute renewable = true;
        }
        item def RecyclableMaterial :> Material {
            attribute recyclable = true;
        }
        item def FurniturePart {
            attribute partId : String;
            attribute mass : Mass;
            attribute length : Length;
            attribute material : Material;
        }
        item def HardwareComponent {
            attribute componentId : String;
            attribute quantity : Quantity;
            attribute material : Material;
        }
        item def AssemblyInstruction {
            attribute documentId : String;
            attribute stepCount : Integer;
            attribute language : String;
            attribute clarityScore : Percentage;
        }
        item def FlatPackBox {
            attribute sku : String;
            attribute productName : String;
            attribute retailPrice : Currency;
            attribute boxVolume : Volume;
            attribute boxMass : Mass;
            attribute partCount : Quantity;
            attribute instructionsIncluded : Boolean;
        }
        item def DesignConcept {
            attribute conceptId : String;
            attribute name : String;
            attribute targetCost : Currency;
            attribute targetRetailPrice : Currency;
            attribute sustainabilityRating : Percentage;
        }
        item def CustomerFeedback {
            attribute feedbackId : String;
            attribute rating : Integer;
            attribute comment : String;
            attribute source : String;
        }
        item def PurchaseOrder {
            attribute orderId : String;
            attribute customerId : String;
            attribute totalAmount : Currency;
            attribute boxCount : Quantity;
        }
        item def ReplenishmentRequest {
            attribute requestId : String;
            attribute sku : String;
            attribute quantity : Quantity;
            attribute priority : Integer;
        }
        item def SupportTicket {
            attribute ticketId : String;
            attribute customerId : String;
            attribute issueType : String;
            attribute description : String;
        }
        item def DisplaySample {
            attribute sampleId : String;
            attribute sku : String;
            attribute assembled : Boolean;
        }
    }

    package Ports {
        port def FeedbackInPort {
            in item : CustomerFeedback;
        }
        port def ConceptOutPort {
            out item : DesignConcept;
        }
        port def ConceptInPort {
            in item : DesignConcept;
        }
        port def PartsOutPort {
            out item : FurniturePart;
            out item : HardwareComponent;
        }
        port def PartsInPort {
            in item : FurniturePart;
            in item : HardwareComponent;
        }
        port def BoxOutPort {
            out item : FlatPackBox;
        }
        port def BoxInPort {
            in item : FlatPackBox;
        }
        port def ReplenishmentOutPort {
            out item : ReplenishmentRequest;
        }
        port def ReplenishmentInPort {
            in item : ReplenishmentRequest;
        }
        port def OrderInPort {
            in item : PurchaseOrder;
        }
        port def BoxDeliveryOutPort {
            out item : FlatPackBox;
        }
        port def BoxDeliveryInPort {
            in item : FlatPackBox;
        }
        port def SupportInPort {
            in item : SupportTicket;
        }
        port def InstructionOutPort {
            out item : AssemblyInstruction;
        }
        port def InstructionInPort {
            in item : AssemblyInstruction;
        }
        port def SampleOutPort {
            out item : DisplaySample;
        }
        port def SampleInPort {
            in item : DisplaySample;
        }
    }

    package Requirements {
        requirement def AffordabilityRequirement {
            doc /* The product shall be affordable for mass-market appeal. */
            attribute maxRetailPrice : Currency = 250;
            subject product : FlatPackBox;
            constraint { product.retailPrice <= maxRetailPrice; }
        }
        requirement def EfficiencyRequirement {
            doc /* The flat-pack model shall reduce shipping and storage costs. */
            attribute maxBoxVolume : Volume = 0.5;
            subject box : FlatPackBox;
            constraint { box.boxVolume <= maxBoxVolume; }
        }
        requirement def SelfAssemblyRequirement {
            doc /* The product shall rely on customer self-assembly using clear, simple instructions. */
            attribute minClarityScore : Percentage = 80;
            subject instruction : AssemblyInstruction;
            constraint { instruction.clarityScore >= minClarityScore; }
        }
        requirement def DesignQualityRequirement {
            doc /* The product shall exhibit good design quality. */
            attribute minDesignScore : Percentage = 75;
            subject concept : DesignConcept;
            constraint { concept.sustainabilityRating >= minDesignScore; }
        }
        requirement def SustainabilityRequirement {
            doc /* The product shall use renewable and recyclable materials. */
            subject material : Material;
            constraint { material.renewable == true and material.recyclable == true; }
        }
        requirement def InventoryTrackingRequirement {
            doc /* The warehouse shall track stock levels and handle replenishment requests. */
            subject warehouse : >> Object;
            constraint { warehouse.stockLevel >= 0; }
        }
        requirement def CustomerSupportRequirement {
            doc /* The customer service desk shall provide assembly support. */
            subject desk : >> Object;
            constraint { desk.responseTime <= 24; }
        }

        requirement affordabilityReq : AffordabilityRequirement;
        requirement efficiencyReq : EfficiencyRequirement;
        requirement selfAssemblyReq : SelfAssemblyRequirement;
        requirement designQualityReq : DesignQualityRequirement;
        requirement sustainabilityReq : SustainabilityRequirement;
        requirement inventoryTrackingReq : InventoryTrackingRequirement;
        requirement customerSupportReq : CustomerSupportRequirement;
    }

    package Parts {

        part def DesignStudio {
            port feedbackIn : FeedbackInPort;
            port conceptOut : ConceptOutPort;
            attribute designQualityScore : Percentage = 80;
            attribute costTarget : Currency = 100;
            attribute conceptReceived : Boolean = false;
            attribute conceptDrafted : Boolean = false;
            attribute reviewApproved : Boolean = false;
            attribute conceptSent : Boolean = false;

            action def analyzeFeedback {
                in feedback : CustomerFeedback;
                out insights : String;
            }
            action def draftConcept {
                in target : Currency;
                out concept : DesignConcept;
            }
            action def reviewConcept {
                in concept : DesignConcept;
                out approved : Boolean;
            }
            action def finalizeConcept {
                in concept : DesignConcept;
                out finalConcept : DesignConcept;
            }

            state def DesignLifecycle {
                entry; then Researching;
                state Researching {
                    entry { /* analyze customer feedback */ }
                }
                state Conceptualizing {
                    entry { /* draft design concept */ }
                }
                state Reviewing {
                    entry { /* evaluate cost and quality */ }
                }
                state Finalizing {
                    entry { /* finalize and emit concept */ }
                }
                transition from Researching to Conceptualizing when conceptReceived;
                transition from Conceptualizing to Reviewing when conceptDrafted;
                transition from Reviewing to Finalizing when reviewApproved;
                transition from Finalizing to Researching when conceptSent;
            }

            exhibit state DesignLifecycle;
        }

        part def ProductionFacility {
            port conceptIn : ConceptInPort;
            port partsOut : PartsOutPort;
            port boxOut : BoxOutPort;
            port sampleOut : SampleOutPort;
            attribute productionCapacity : Quantity = 1000;
            attribute currentStock : Quantity = 0;
            attribute conceptReceived : Boolean = false;
            attribute partsProduced : Boolean = false;
            attribute boxesPacked : Boolean = false;
            attribute boxesShipped : Boolean = false;

            action def manufactureParts {
                in concept : DesignConcept;
                out parts : FurniturePart;
                out hardware : HardwareComponent;
            }
            action def packageBox {
                in parts : FurniturePart;
                in hardware : HardwareComponent;
                out box : FlatPackBox;
                out instructions : AssemblyInstruction;
            }
            action def shipBoxes {
                in box : FlatPackBox;
            }

            state def ProductionLifecycle {
                entry; then Idle;
                state Idle;
                state Manufacturing {
                    entry { /* manufacture parts */ }
                }
                state Packaging {
                    entry { /* package flat-pack boxes */ }
                }
                state Shipping {
                    entry { /* ship to warehouse */ }
                }
                transition from Idle to Manufacturing when conceptReceived;
                transition from Manufacturing to Packaging when partsProduced;
                transition from Packaging to Shipping when boxesPacked;
                transition from Shipping to Idle when boxesShipped;
            }

            exhibit state ProductionLifecycle;
        }

        part def DistributionWarehouse {
            port boxIn : BoxInPort;
            port replenishmentIn : ReplenishmentInPort;
            port boxDeliveryOut : BoxDeliveryOutPort;
            port replenishmentOut : ReplenishmentOutPort;
            attribute maxCapacity : Quantity = 5000;
            attribute stockLevel : Quantity = 0;
            attribute reorderThreshold : Quantity = 200;
            attribute boxReceived : Boolean = false;
            attribute orderReceived : Boolean = false;
            attribute replenishmentNeeded : Boolean = false;
            attribute boxDelivered : Boolean = false;

            action def receiveBox {
                in box : FlatPackBox;
            }
            action def trackInventory {
                in current : Quantity;
                out level : Quantity;
            }
            action def requestReplenishment {
                out request : ReplenishmentRequest;
            }
            action def retrieveBox {
                in sku : String;
                out box : FlatPackBox;
            }

            state def WarehouseLifecycle {
                entry; then Monitoring;
                state Monitoring {
                    entry { /* track stock levels */ }
                }
                state Receiving;
                state Retrieving;
                state Reordering;
                transition from Monitoring to Receiving when boxReceived;
                transition from Receiving to Monitoring when boxReceived == false;
                transition from Monitoring to Retrieving when orderReceived;
                transition from Retrieving to Monitoring when boxDelivered;
                transition from Monitoring to Reordering when stockLevel <= reorderThreshold;
                transition from Reordering to Monitoring when replenishmentNeeded == false;
            }

            exhibit state WarehouseLifecycle;
        }

        part def RetailShowroom {
            port sampleIn : SampleInPort;
            port feedbackOut : FeedbackInPort;
            attribute displayCount : Quantity = 0;
            attribute sampleReceived : Boolean = false;
            attribute feedbackCollected : Boolean = false;

            action def displaySample {
                in sample : DisplaySample;
            }
            action def collectFeedback {
                out feedback : CustomerFeedback;
            }

            state def ShowroomLifecycle {
                entry; then Displaying;
                state Displaying {
                    entry { /* present assembled samples */ }
                }
                state Engaging;
                state CollectingFeedback;
                transition from Displaying to Engaging when sampleReceived;
                transition from Engaging to CollectingFeedback when feedbackCollected == false;
                transition from CollectingFeedback to Displaying when feedbackCollected;
            }

            exhibit state ShowroomLifecycle;
        }

        part def CheckoutCounter {
            port orderIn : OrderInPort;
            port boxDeliveryIn : BoxDeliveryInPort;
            port boxDeliveryOut : BoxDeliveryOutPort;
            attribute processedOrders : Quantity = 0;
            attribute orderReceived : Boolean = false;
            attribute boxRetrieved : Boolean = false;
            attribute orderComplete : Boolean = false;

            action def processOrder {
                in order : PurchaseOrder;
                out confirmation : String;
            }
            action def requestBox {
                in sku : String;
            }
            action def handOverBox {
                in box : FlatPackBox;
                out deliveredBox : FlatPackBox;
            }

            state def CheckoutLifecycle {
                entry; then Waiting;
                state Waiting;
                state Processing;
                state Retrieving;
                state HandingOver;
                transition from Waiting to Processing when orderReceived;
                transition from Processing to Retrieving when orderReceived;
                transition from Retrieving to HandingOver when boxRetrieved;
                transition from HandingOver to Waiting when orderComplete;
            }

            exhibit state CheckoutLifecycle;
        }

        part def CustomerServiceDesk {
            port supportIn : SupportInPort;
            port instructionOut : InstructionOutPort;
            attribute responseTime : Duration = 12;
            attribute ticketReceived : Boolean = false;
            attribute issueResolved : Boolean = false;

            action def receiveTicket {
                in ticket : SupportTicket;
            }
            action def provideAssistance {
                in ticket : SupportTicket;
                out instruction : AssemblyInstruction;
            }

            state def SupportLifecycle {
                entry; then Available;
                state Available;
                state Assisting;
                state Resolved;
                transition from Available to Assisting when ticketReceived;
                transition from Assisting to Resolved when issueResolved;
                transition from Resolved to Available when issueResolved == false;
            }

            exhibit state SupportLifecycle;
        }

        part def Customer {
            port boxDeliveryIn : BoxDeliveryInPort;
            port instructionIn : InstructionInPort;
            port orderOut : OrderInPort;
            port supportOut : SupportInPort;
            attribute customerId : String;
            attribute boxReceived : Boolean = false;
            attribute instructionReceived : Boolean = false;
            attribute assemblyStarted : Boolean = false;
            attribute assemblyComplete : Boolean = false;

            action def purchaseProduct {
                out order : PurchaseOrder;
            }
            action def transportBox {
                in box : FlatPackBox;
            }
            action def assembleFurniture {
                in box : FlatPackBox;
                in instruction : AssemblyInstruction;
                out assembledProduct : String;
            }

            state def CustomerLifecycle {
                entry; then Browsing;
                state Browsing;
                state Purchasing;
                state Transporting;
                state Assembling;
                state Enjoying;
                transition from Browsing to Purchasing when orderOut::item@sent;
                transition from Purchasing to Transporting when boxReceived;
                transition from Transporting to Assembling when instructionReceived;
                transition from Assembling to Enjoying when assemblyComplete;
                transition from Enjoying to Browsing when assemblyComplete == false;
            }

            exhibit state CustomerLifecycle;
        }
    }

    part def FlatPackRetailerSystem {
        part designStudio : DesignStudio;
        part productionFacility : ProductionFacility;
        part distributionWarehouse : DistributionWarehouse;
        part retailShowroom : RetailShowroom;
        part checkoutCounter : CheckoutCounter;
        part customerServiceDesk : CustomerServiceDesk;
        part customer : Customer;

        connect designStudio.conceptOut to productionFacility.conceptIn;
        connect productionFacility.boxOut to distributionWarehouse.boxIn;
        connect productionFacility.sampleOut to retailShowroom.sampleIn;
        connect retailShowroom.feedbackOut to designStudio.feedbackIn;
        connect customer.orderOut to checkoutCounter.orderIn;
        connect checkoutCounter.boxDeliveryOut to customer.boxDeliveryIn;
        connect distributionWarehouse.boxDeliveryOut to checkoutCounter.boxDeliveryIn;
        connect distributionWarehouse.replenishmentOut to productionFacility.conceptIn;
        connect customer.supportOut to customerServiceDesk.supportIn;
        connect customerServiceDesk.instructionOut to customer.instructionIn;

        satisfy affordabilityReq by productionFacility.boxOut::item;
        satisfy efficiencyReq by productionFacility.boxOut::item;
        satisfy selfAssemblyReq by customerServiceDesk.instructionOut::item;
        satisfy designQualityReq by designStudio.conceptOut::item;
        satisfy sustainabilityReq by productionFacility.partsOut::item::material;
        satisfy inventoryTrackingReq by distributionWarehouse;
        satisfy customerSupportReq by customerServiceDesk;
    }
}
