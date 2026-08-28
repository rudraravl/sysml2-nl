package 'Smart First Aid Kit System' {
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::Real;

    enum def InjuryType {
        cut;
        burn;
        sprain;
    }

    enum def Severity {
        mild;
        moderate;
        severe;
    }

    item def Supply {
        attribute name : String;
        attribute quantity : Integer;
        attribute minQuantity : Integer;
    }

    item def AdhesiveBandage :> Supply;
    item def GauzeBandage :> Supply;
    item def ElasticBandage :> Supply;
    item def AntisepticWipe :> Supply;
    item def AntisepticSpray :> Supply;
    item def PainMedication :> Supply;
    item def DisposableGloves :> Supply;
    item def Scissors :> Supply;
    item def Tweezers :> Supply;
    item def Thermometer :> Supply;

    item def InjuryReport {
        attribute injuryType : InjuryType;
        attribute severity : Severity;
    }

    item def TreatmentStep {
        attribute description : String;
    }

    item def TreatmentPlan {
        attribute steps : TreatmentStep[0..*] ordered;
        attribute requiredSupplies : Supply[0..*];
    }

    item def RestockAlert {
        attribute supplyName : String;
        attribute currentQuantity : Integer;
        attribute minQuantity : Integer;
    }

    part def DurableWaterproofContainer {
        attribute material : String = "Polycarbonate";
        attribute rating : String = "IP67";
    }

    part def UserInterface {
        port injuryInputPort;
        port guidanceOutputPort;
        port alertOutputPort;
    }

    part def StorageCompartment {
        port stockQueryPort;
        port dispensePort;
        attribute supplies : Supply[0..*];
    }

    part def InventoryTracker {
        port stockUpdatePort;
        port alertPort;
        attribute stockLevels : Supply[0..*];
    }

    action def AssessInjury {
        in report : InjuryReport;
        out plan : TreatmentPlan;
    }

    action def CheckStock {
        in plan : TreatmentPlan;
        out available : Boolean;
    }

    action def DispenseSupplies {
        in plan : TreatmentPlan;
        out dispensed : Supply[0..*];
    }

    action def ProvideGuidance {
        in plan : TreatmentPlan;
    }

    action def UpdateInventory {
        in dispensed : Supply[0..*];
        out isLowStock : Boolean;
        out lowStock : Supply;
    }

    action def TriggerAlert {
        in lowStock : Supply;
    }

    part def SmartFirstAidKit {
        part container : DurableWaterproofContainer;
        part userInterface : UserInterface;
        part storageCompartment : StorageCompartment;
        part inventoryTracker : InventoryTracker;

        port userPort;

        attribute currentReport : InjuryReport;
        attribute currentPlan : TreatmentPlan;
        attribute dispensedItems : Supply[0..*];
        attribute lowStockItem : Supply;
        attribute stockAvailable : Boolean;
        attribute isLowStock : Boolean;

        connect userPort to userInterface.injuryInputPort;
        connect userInterface.guidanceOutputPort to userPort;
        connect userInterface.alertOutputPort to userPort;
        connect storageCompartment.stockQueryPort to inventoryTracker.stockUpdatePort;
        connect inventoryTracker.alertPort to userInterface.alertOutputPort;

        state KitOperation {
            entry; then idle;

            state idle;
            accept report : InjuryReport via userPort {
                currentReport = report;
            } then assessing;

            state assessing {
                entry {
                    action assess : AssessInjury {
                        in report = currentReport;
                        out plan = currentPlan;
                    }
                }
            }
            then checking;

            state checking {
                entry {
                    action check : CheckStock {
                        in plan = currentPlan;
                        out available = stockAvailable;
                    }
                }
            }
            then if stockAvailable {
                then dispensing;
            } else {
                then idle;
            }

            state dispensing {
                entry {
                    action dispense : DispenseSupplies {
                        in plan = currentPlan;
                        out dispensed = dispensedItems;
                    }
                }
            }
            then guiding;

            state guiding {
                entry {
                    action guide : ProvideGuidance {
                        in plan = currentPlan;
                    }
                }
            }
            then updating;

            state updating {
                entry {
                    action update : UpdateInventory {
                        in dispensed = dispensedItems;
                        out isLowStock = isLowStock;
                        out lowStock = lowStockItem;
                    }
                    if isLowStock {
                        action alert : TriggerAlert {
                            in lowStock = lowStockItem;
                        }
                    }
                }
            }
            then idle;
        }
    }

    requirement def GuidedCareRequirement {
        subject kit : SmartFirstAidKit;
        text "The system shall provide step-by-step treatment guidance based on reported injury type and severity.";
    }

    requirement def InventoryManagementRequirement {
        subject kit : SmartFirstAidKit;
        text "The system shall monitor supply levels and trigger a restock alert when any supply drops below its minimum quantity.";
    }

    requirement def WaterproofContainerRequirement {
        subject kit : SmartFirstAidKit;
        text "The system shall be housed in a durable, waterproof container.";
    }

    requirement def SupplyDispensingRequirement {
        subject kit : SmartFirstAidKit;
        text "The system shall check internal stock availability before dispensing supplies from its storage compartment.";
    }
}
