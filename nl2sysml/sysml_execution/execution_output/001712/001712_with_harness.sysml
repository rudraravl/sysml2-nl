package 'IKEA Furniture Retail and Assembly System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ProductCode;
    attribute def AssemblyInstructionSet;
    attribute def StockLevel :> Integer;
    
    attribute def PriceValue :> Real;
    
    attribute def CustomerSatisfactionScore :> Real;
    
    item def FurniturePart {
        attribute partID : ProductCode;
        attribute mass : MassValue;
        attribute dimensions : LengthValue[3];
        attribute material : String;
    }
    
    item def FlatPackage {
        attribute packageID : ProductCode;
        attribute totalMass : MassValue;
        attribute volume : VolumeValue;
        attribute parts : FurniturePart[1..*];
        attribute assemblyInstructions : AssemblyInstructionSet;
        attribute price : PriceValue;
    }
    
    item def AssembledProduct {
        attribute productID : ProductCode;
        attribute assemblyDuration : TimeValue;
        attribute qualityScore : Real;
    }
    
    item def CustomerOrder {
        attribute orderID : ProductCode;
        attribute selectedProducts : ProductCode[1..*];
        attribute totalCost : PriceValue;
    }
    
    port def WarehouseInventoryPort {
        out item availableStock : FlatPackage[*];
        in item replenishmentRequest : ProductCode[*];
    }
    
    port def ShowroomDisplayPort {
        out item displayedProducts : AssembledProduct[*];
        in item customerInquiry : ProductCode[*];
    }
    
    port def CheckoutTransactionPort {
        in item customerPurchase : CustomerOrder;
        out item processedOrder : FlatPackage[*];
    }
    
    port def CustomerServicePort {
        in item serviceRequest : ProductCode;
        out item supportResponse : AssemblyInstructionSet;
    }
    
    action def DesignProduct {
        in customerNeeds : CustomerSatisfactionScore;
        in costTarget : PriceValue;
        out productDesign : FurniturePart[*];
        out assemblyGuide : AssemblyInstructionSet;
    }
    
    action def ManufactureParts {
        in design : FurniturePart[*];
        out manufacturedParts : FurniturePart[*];
    }
    
    action def CreateFlatPackage {
        in parts : FurniturePart[*];
        in instructions : AssemblyInstructionSet;
        in targetPrice : PriceValue;
        out package : FlatPackage;
    }
    
    action def StockInventory {
        in package : FlatPackage;
        out stockUpdate : StockLevel;
    }
    
    action def DisplayProduct {
        in sampleProduct : AssembledProduct;
        out customerEngagement : Boolean;
    }
    
    action def ProcessPurchase {
        in order : CustomerOrder;
        out retrievedPackages : FlatPackage[*];
        
        first start;
        then action validateOrder {
            in customerOrder = order;
            out validationResult : Boolean;
        }
        then decide;
            if validateOrder.validationResult then retrieveFromWarehouse;
            if not validateOrder.validationResult then rejectOrder;
        action retrieveFromWarehouse {
            in orderDetails = order;
            out packages : FlatPackage[*];
        }
        then assign retrievedPackages := retrieveFromWarehouse.packages;
        then completeTransaction;
        action rejectOrder {
            out errorMessage : String;
        }
        then completeTransaction;
        action completeTransaction;
        then done;
    }
    
    action def AssembleAtHome {
        in flatPackage : FlatPackage;
        out assembledFurniture : AssembledProduct;
        
        first start;
        then merge assemblyLoop;
        then action unpackParts {
            in package = flatPackage;
            out components : FurniturePart[*];
        }
        then action followInstructions {
            in instructions = flatPackage.assemblyInstructions;
            in components = unpackParts.components;
            out assemblyProgress : Real;
        }
        then decide;
            if followInstructions.assemblyProgress < 100.0 then continueAssembly;
            if followInstructions.assemblyProgress >= 100.0 then finalizeAssembly;
        action continueAssembly {
            in currentProgress : Real;
            out updatedProgress : Real;
        }
        then assemblyLoop;
        action finalizeAssembly {
            out completedProduct : AssembledProduct;
        }
        then assign assembledFurniture := finalizeAssembly.completedProduct;
        then done;
    }
    
    state def ProductLifecycleStates {
        entry; then conceptDesign;
        
        state conceptDesign {
            entry assign designPhaseActive : Boolean = true;
        }
        then manufactured;
        
        state manufactured {
            entry assign partsProduced : Boolean = true;
        }
        then flatPacked;
        
        state flatPacked {
            entry assign packageReady : Boolean = true;
        }
        then inWarehouse;
        
        state inWarehouse {
            entry assign inventoryStocked : Boolean = true;
        }
        then onDisplay;
        
        state onDisplay;
        accept at customerSelects;
        then sold;
        
        state sold;
        then transported;
        
        state transported;
        then customerAssembly;
        
        state customerAssembly;
        then inCustomerHome;
        
        state inCustomerHome;
    }
    
    part def DesignStudio {
        perform action designActivity : DesignProduct[*];
    }
    
    part def ProductionFacility {
        perform action manufacturing : ManufactureParts[*];
        perform action packaging : CreateFlatPackage[*];
    }
    
    part def DistributionWarehouse {
        port warehousePort : WarehouseInventoryPort;
        attribute currentInventory : FlatPackage[*];
        perform action inventoryManagement : StockInventory[*];
    }
    
    part def RetailShowroom {
        port showroomPort : ShowroomDisplayPort;
        attribute displayItems : AssembledProduct[*];
        perform action productDisplay : DisplayProduct[*];
    }
    
    part def CheckoutCounter {
        port checkoutPort : CheckoutTransactionPort;
        perform action salesProcessing : ProcessPurchase[*];
    }
    
    part def CustomerServiceDesk {
        port servicePort : CustomerServicePort;
    }
    
    part def HomeCustomer {
        perform action homeAssembly : AssembleAtHome[*];
        attribute satisfactionLevel : CustomerSatisfactionScore;
    }
    
    part def IKEARetailSystem {
        part designTeam : DesignStudio {
            perform ikeaOperationalFlow.productDesignPhase;
        }
        
        part factory : ProductionFacility {
            perform ikeaOperationalFlow.manufacturingPhase;
            perform ikeaOperationalFlow.packagingPhase;
        }
        
        part warehouse : DistributionWarehouse {
            perform ikeaOperationalFlow.inventoryControl;
        }
        
        part showroom : RetailShowroom {
            perform ikeaOperationalFlow.customerEngagement;
        }
        
        part checkout : CheckoutCounter {
            perform ikeaOperationalFlow.salesCompletion;
        }
        
        part customerService : CustomerServiceDesk;
        
        connection warehouseToShowroom connect 
            warehouse.warehousePort to showroom.showroomPort;
        
        connection showroomToCheckout connect 
            showroom.showroomPort to checkout.checkoutPort;
        
        connection checkoutToWarehouse connect 
            checkout.checkoutPort to warehouse.warehousePort;
        
        connection serviceToShowroom connect 
            customerService.servicePort to showroom.showroomPort;
        
        perform action ikeaOperationalFlow {
            first start;
            
            then action productDesignPhase : DesignProduct {
                in customerNeeds : CustomerSatisfactionScore;
                in costTarget : PriceValue;
                out productDesign : FurniturePart[*];
                out assemblyGuide : AssemblyInstructionSet;
            }
            
            then action manufacturingPhase : ManufactureParts {
                in design = productDesignPhase.productDesign;
                out manufacturedParts : FurniturePart[*];
            }
            
            then action packagingPhase : CreateFlatPackage {
                in parts = manufacturingPhase.manufacturedParts;
                in instructions = productDesignPhase.assemblyGuide;
                in targetPrice : PriceValue;
                out package : FlatPackage;
            }
            
            then action inventoryControl : StockInventory {
                in package = packagingPhase.package;
                out stockUpdate : StockLevel;
            }
            
            then action customerEngagement : DisplayProduct {
                in sampleProduct : AssembledProduct;
                out customerEngagement : Boolean;
            }
            
            then decide;
                if customerEngagement.customerEngagement then salesCompletion;
                if not customerEngagement.customerEngagement then customerEngagement;
            
            action salesCompletion : ProcessPurchase {
                in order : CustomerOrder;
                out retrievedPackages : FlatPackage[*];
            }
            
            then done;
        }
    }
    
    requirement def AffordabilityRequirement {
        doc /* Products shall be priced affordably to enable mass market accessibility. */
        
        require constraint affordablePricePoint {
            attribute maximumPrice : PriceValue;
            attribute marketSegmentTarget : String;
        }
    }
    
    requirement def FlatPackEfficiencyRequirement {
        doc /* Furniture shall be packaged efficiently in flat-pack format to reduce transportation and storage costs. */
        
        require constraint volumeOptimization {
            attribute volumeReductionPercent : Real;
            volumeReductionPercent >= 65.0
        }
        
        require constraint transportability {
            attribute maximumPackageMass : MassValue;
            maximumPackageMass <= 35.0[SI::kg]
        }
    }
    
    requirement def CustomerAssemblyRequirement {
        doc /* Customers shall be capable of assembling furniture independently using provided instructions. */
        
        require constraint instructionClarity {
            attribute clarityRating : Real;
            clarityRating >= 90.0
        }
        
        require constraint assemblyTimeLimit {
            attribute maximumAssemblyTime : TimeValue;
            maximumAssemblyTime <= 90.0[SI::min]
        }
        
        require constraint toolRequirements {
            attribute requiresSpecialTools : Boolean;
            requiresSpecialTools = false
        }
    }
    
    requirement def EnvironmentalSustainabilityRequirement {
        doc /* Products and operations shall minimize environmental impact through sustainable practices. */
        
        require constraint sustainableMaterials {
            attribute renewableContentMinimum : Real;
            renewableContentMinimum >= 60.0
        }
        
        require constraint recyclability {
            attribute recyclableContentPercent : Real;
            recyclableContentPercent >= 80.0
        }
    }
    
    requirement def DesignQualityRequirement {
        doc /* Products shall exhibit good design that balances aesthetics, functionality, and cost. */
        
        require constraint functionalDesign {
            attribute usabilityScore : Real;
            usabilityScore >= 85.0
        }
        
        require constraint aestheticAppeal {
            attribute designRating : Real;
            designRating >= 80.0
        }
    }
    
    requirement <'IKEA-SYS-001'> primarySystemRequirement {
        doc /* The IKEA retail system shall provide affordable, well-designed furniture in efficient flat-pack format that enables customer self-assembly and sustainable consumption. */
        
        subject ikeaRetailSystem : IKEARetailSystem;
        
        require affordability : AffordabilityRequirement;
        require flatPackEfficiency : FlatPackEfficiencyRequirement;
        require customerAssembly : CustomerAssemblyRequirement;
        require sustainability : EnvironmentalSustainabilityRequirement;
        require designQuality : DesignQualityRequirement;
        
        assume constraint customerCapabilities {
            doc /* Customers possess basic assembly skills and access to common household tools. */
        }
        
        assume constraint supplyChainReliability {
            doc /* Manufacturing and distribution infrastructure operates reliably to maintain inventory levels. */
        }
    }
    
    part ikeaStoreInstance : IKEARetailSystem;
    
    part customerInstance : HomeCustomer {
        perform action assemblyAtHome : AssembleAtHome {
            in flatPackage : FlatPackage;
            out assembledFurniture : AssembledProduct;
        }
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'IKEA Furniture Retail and Assembly System'::*;

    part testSubject : IKEARetailSystem {
    // TODO(human): unsupported input type for order: CustomerOrder (unsupported structured payload members: selectedProducts)
    }

    part testSubject : DesignStudio {
        exhibit state sm : ProductLifecycleStates;
    }
}
