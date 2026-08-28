package EmergencyMedicalBagSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def TemperatureValue :> Real { unit "degC"; }
    value def HeartRateValue :> Real { unit "bpm"; }
    value def PressureValue :> Real { unit "mmHg"; }
    value def MassValue :> Real { unit "kg"; }
    value def DurationValue :> Real { unit "s"; }
    value def QuantityValue :> Integer;
    value def VolumeValue :> Real { unit "L"; }

    value def TempRange {
        attribute min : TemperatureValue;
        attribute max : TemperatureValue;
    }

    // ===== Item Types =====
    item def MedicalItem {
        attribute id : String;
        attribute name : String;
        attribute quantity : QuantityValue;
        attribute expirationDate : Date;
        attribute isSterile : Boolean;
        attribute category : String;
    }

    item def Medication :> MedicalItem {
        attribute dosage : String;
    }

    item def SterileInstrument :> MedicalItem {
        attribute instrumentType : String;
    }

    item def WoundCareItem :> MedicalItem {
        attribute woundCareType : String;
    }

    item def VitalSigns {
        attribute heartRate : HeartRateValue;
        attribute systolicBP : PressureValue;
        attribute diastolicBP : PressureValue;
        attribute bodyTemp : TemperatureValue;
    }

    item def TreatmentRecord {
        attribute recordId : String;
        attribute timestamp : DateTime;
        attribute patientId : String;
        attribute vitals : VitalSigns;
        attribute severityLevel : SeverityLevel;
        attribute itemsUsed : MedicalItem[0..*];
        attribute notes : String;
    }

    enum def SeverityLevel { mild; moderate; severe; critical; }

    enum def AlertType { expiredItem; nonSterileItem; lowStock; tempDeviation; }

    item def InventoryAlert {
        attribute alertType : AlertType;
        attribute itemId : String;
        attribute message : String;
        attribute timestamp : DateTime;
    }

    // ===== Port Definitions =====
    port def InventoryPort {
        out item alerts : InventoryAlert;
        in item itemUpdates : MedicalItem;
    }

    port def DiagnosticPort {
        in item vitals : VitalSigns;
        out item recommendedItems : MedicalItem[0..*];
        out attribute severity : SeverityLevel;
    }

    port def CompartmentPort {
        out item storedItems : MedicalItem[0..*];
        in attribute targetTemp : TemperatureValue;
        out attribute currentTemp : TemperatureValue;
    }

    port def PowerPort {
        out attribute voltage : Real;
        out attribute current : Real;
    }

    // ===== Interfaces =====
    interface def InventoryInterface {
        end supplier : InventoryPort;
        end consumer : InventoryPort;
    }

    interface def DiagnosticInterface {
        end supplier : DiagnosticPort;
        end consumer : DiagnosticPort;
    }

    interface def CompartmentInterface {
        end supplier : CompartmentPort;
        end consumer : CompartmentPort;
    }

    // ===== Part Definitions =====
    part def TemperatureController {
        attribute targetRange : TempRange;
        attribute currentTemp : TemperatureValue;
        port tempOut : CompartmentPort;
        attribute isHeating : Boolean;
        attribute isCooling : Boolean;

        action def RegulateTemp {
            in currentReading : TemperatureValue;
            in targetMin : TemperatureValue;
            in targetMax : TemperatureValue;
            out heatingCommand : Boolean;
            out coolingCommand : Boolean;
        }

        state defenum TempControlState {
            entry; heating; cooling; stable; alarm;
        }

        state machine TempStateMachine {
            state entry;
            state heating;
            state cooling;
            state stable;
            state alarm;

            transition entry to stable
                when { currentTemp >= targetRange.min and currentTemp <= targetRange.max }
                do { send tempOut.currentTemp(currentTemp); }

            transition stable to heating
                when { currentTemp < targetRange.min }
                do { isHeating = true; isCooling = false; }

            transition stable to cooling
                when { currentTemp > targetRange.max }
                do { isHeating = false; isCooling = true; }

            transition heating to stable
                when { currentTemp >= targetRange.min }
                do { isHeating = false; }

            transition cooling to stable
                when { currentTemp <= targetRange.max }
                do { isCooling = false; }

            transition stable to alarm
                when { currentTemp > targetRange.max + 5.0 or currentTemp < targetRange.min - 5.0 }
                do { send tempOut.currentTemp(currentTemp); }

            transition heating to alarm
                when { currentTemp > targetRange.max + 5.0 }
                do { isHeating = false; }

            transition cooling to alarm
                when { currentTemp < targetRange.min - 5.0 }
                do { isCooling = false; }

            transition alarm to stable
                when { currentTemp >= targetRange.min and currentTemp <= targetRange.max }
                do { send tempOut.currentTemp(currentTemp); }
        }
    }

    part def StorageCompartment {
        attribute compartmentId : String;
        attribute compartmentName : String;
        attribute targetTempRange : TempRange;
        attribute volume : VolumeValue;
        port compartmentPort : CompartmentPort;
        part tempController : TemperatureController {
            attribute targetRange : TempRange := targetTempRange;
        }
        item storedItems : MedicalItem[0..*];

        action def LoadItem {
            in item newItem : MedicalItem;
            out item updatedInventory : MedicalItem[0..*];
            do {
                storedItems := storedItems->including(newItem);
                updatedInventory := storedItems;
            }
        }

        action def RetrieveItem {
            in attribute itemId : String;
            out item retrievedItem : MedicalItem;
            do {
                // find and remove item
                retrievedItem := storedItems->selectOne(i | i.id == itemId);
                storedItems := storedItems->excluding(retrievedItem);
            }
        }
    }

    part def MedicationCompartment :> StorageCompartment {
        attribute compartmentName : String := "Medication Compartment";
        attribute targetTempRange : TempRange := TempRange{min = 2.0, max = 8.0};
        item medications : Medication[0..*];
    }

    part def InstrumentCompartment :> StorageCompartment {
        attribute compartmentName : String := "Sterile Instrument Compartment";
        attribute targetTempRange : TempRange := TempRange{min = 15.0, max = 25.0};
        item instruments : SterileInstrument[0..*];
    }

    part def WoundCareCompartment :> StorageCompartment {
        attribute compartmentName : String := "Wound Care Compartment";
        attribute targetTempRange : TempRange := TempRange{min = 15.0, max = 25.0};
        item woundCareItems : WoundCareItem[0..*];
    }

    part def InventoryManager {
        attribute managerId : String;
        port inventoryPort : InventoryPort;
        item trackedItems : MedicalItem[0..*];
        item activeAlerts : InventoryAlert[0..*];

        action def ScanInventory {
            out item alerts : InventoryAlert[0..*];
            do {
                // Check for expired items
                for item in trackedItems {
                    if item.expirationDate < now() {
                        activeAlerts := activeAlerts->including(
                            InventoryAlert{
                                alertType = AlertType::expiredItem,
                                itemId = item.id,
                                message = "Item " + item.name + " has expired.",
                                timestamp = now()
                            }
                        );
                    }
                    if not item.isSterile and item.category == "sterile" {
                        activeAlerts := activeAlerts->including(
                            InventoryAlert{
                                alertType = AlertType::nonSterileItem,
                                itemId = item.id,
                                message = "Item " + item.name + " is not sterile.",
                                timestamp = now()
                            }
                        );
                    }
                    if item.quantity < 3 {
                        activeAlerts := activeAlerts->including(
                            InventoryAlert{
                                alertType = AlertType::lowStock,
                                itemId = item.id,
                                message = "Item " + item.name + " is low in stock.",
                                timestamp = now()
                            }
                        );
                    }
                }
                alerts := activeAlerts;
                send inventoryPort.alerts(activeAlerts);
            }
        }

        action def UpdateItem {
            in item updatedItem : MedicalItem;
            do {
                trackedItems := trackedItems->excluding(trackedItems->selectOne(i | i.id == updatedItem.id));
                trackedItems := trackedItems->including(updatedItem);
            }
        }

        action def CheckExpiry {
            out item expiredItems : MedicalItem[0..*];
            do {
                expiredItems := trackedItems->select(i | i.expirationDate < now());
            }
        }

        action def CheckSterility {
            out item nonSterileItems : MedicalItem[0..*];
            do {
                nonSterileItems := trackedItems->select(i | not i.isSterile);
            }
        }

        state defenum InventoryState { idle; scanning; alerting; updating; }

        state machine InventoryStateMachine {
            state idle;
            state scanning;
            state alerting;
            state updating;

            transition idle to scanning
                when { true }
                do { perform ScanInventory(); }

            transition scanning to alerting
                when { activeAlerts->size() > 0 }
                do { send inventoryPort.alerts(activeAlerts); }

            transition scanning to idle
                when { activeAlerts->size() == 0 }

            transition alerting to idle
                when { true }

            transition idle to updating
                when { inventoryPort.itemUpdates->isReceived() }
                do { perform UpdateItem(inventoryPort.itemUpdates); }

            transition updating to idle
                when { true }
                do { perform ScanInventory(); }
        }
    }

    part def DiagnosticModule {
        attribute moduleId : String;
        port diagnosticPort : DiagnosticPort;
        attribute severityThresholds : > Real[4];

        action def AssessSeverity {
            in vitals : VitalSigns;
            out severity : SeverityLevel;
            do {
                if vitals.heartRate > 120 or vitals.systolicBP < 90 or vitals.bodyTemp > 39.0 {
                    severity := SeverityLevel::critical;
                } else if vitals.heartRate > 100 or vitals.systolicBP < 100 or vitals.bodyTemp > 38.0 {
                    severity := SeverityLevel::severe;
                } else if vitals.heartRate > 90 or vitals.systolicBP < 110 or vitals.bodyTemp > 37.5 {
                    severity := SeverityLevel::moderate;
                } else {
                    severity := SeverityLevel::mild;
                }
            }
        }

        action def RecommendSupplies {
            in severity : SeverityLevel;
            in vitals : VitalSigns;
            out recommendedItems : MedicalItem[0..*];
            do {
                if severity == SeverityLevel::critical {
                    recommendedItems := recommendedItems->including(
                        Medication{id = "MED001", name = "Epinephrine", quantity = 1, expirationDate = Date::today(), isSterile = true, category = "medication", dosage = "1mg/mL"}
                    );
                    recommendedItems := recommendedItems->including(
                        SterileInstrument{id = "INS001", name = "IV Catheter Kit", quantity = 1, expirationDate = Date::today(), isSterile = true, category = "sterile", instrumentType = "catheter"}
                    );
                } else if severity == SeverityLevel::severe {
                    recommendedItems := recommendedItems->including(
                        Medication{id = "MED002", name = "Saline Solution", quantity = 1, expirationDate = Date::today(), isSterile = true, category = "medication", dosage = "500mL"}
                    );
                    recommendedItems := recommendedItems->including(
                        WoundCareItem{id = "WND001", name = "Hemostatic Gauze", quantity = 2, expirationDate = Date::today(), isSterile = true, category = "woundcare", woundCareType = "gauze"}
                    );
                } else if severity == SeverityLevel::moderate {
                    recommendedItems := recommendedItems->including(
                        WoundCareItem{id = "WND002", name = "Adhesive Bandage", quantity = 3, expirationDate = Date::today(), isSterile = true, category = "woundcare", woundCareType = "bandage"}
                    );
                    recommendedItems := recommendedItems->including(
                        WoundCareItem{id = "WND003", name = "Antiseptic Wipes", quantity = 2, expirationDate = Date::today(), isSterile = true, category = "woundcare", woundCareType = "antiseptic"}
                    );
                } else {
                    recommendedItems := recommendedItems->including(
                        WoundCareItem{id = "WND004", name = "Standard Bandage", quantity = 1, expirationDate = Date::today(), isSterile = true, category = "woundcare", woundCareType = "bandage"}
                    );
                }
            }
        }

        action def ProcessVitals {
            in vitals : VitalSigns;
            out severity : SeverityLevel;
            out recommendedItems : MedicalItem[0..*];
            do {
                perform AssessSeverity(vitals) return severity;
                perform RecommendSupplies(severity, vitals) return recommendedItems;
                send diagnosticPort.severity(severity);
                send diagnosticPort.recommendedItems(recommendedItems);
            }
        }

        state defenum DiagnosticState { ready; processing; output; }

        state machine DiagnosticStateMachine {
            state ready;
            state processing;
            state output;

            transition ready to processing
                when { diagnosticPort.vitals->isReceived() }
                do { perform ProcessVitals(diagnosticPort.vitals); }

            transition processing to output
                when { true }

            transition output to ready
                when { true }
                do { send diagnosticPort.severity(diagnosticPort.severity); }
        }
    }

    part def PowerSupply {
        attribute capacity : MassValue;
        attribute chargeLevel : Real;
        port powerOut : PowerPort;
        attribute isPowered : Boolean;

        action def SupplyPower {
            do {
                isPowered := true;
                send powerOut.voltage(12.0);
                send powerOut.current(2.0);
            }
        }

        action def ConsumePower {
            in amount : Real;
            do {
                chargeLevel := chargeLevel - amount;
                if chargeLevel < 0.1 {
                    isPowered := false;
                }
            }
        }
    }

    part def BagShell {
        attribute bagId : String;
        attribute material : String := "Ballistic Nylon";
        attribute totalWeight : MassValue := 3.5;
        attribute isSealed : Boolean := true;
        attribute isWaterproof : Boolean := true;
        attribute maxPayload : MassValue := 8.0;

        action def OpenBag {
            out attribute isOpen : Boolean;
            do {
                isSealed := false;
                isOpen := true;
            }
        }

        action def CloseBag {
            do {
                isSealed := true;
            }
        }
    }

    part def EmergencyMedicalBag {
        attribute systemId : String := "EMB-001";
        attribute systemName : String := "Intelligent Emergency Medical Bag";
        attribute totalWeight : MassValue;
        attribute isPortable : Boolean := true;

        part bagShell : BagShell;
        part powerSupply : PowerSupply;

        part medicationCompartment : MedicationCompartment;
        part instrumentCompartment : InstrumentCompartment;
        part woundCareCompartment : WoundCareCompartment;

        part inventoryManager : InventoryManager;
        part diagnosticModule : DiagnosticModule;

        // Connections between compartments and inventory manager
        connection : CompartmentInterface connect medicationCompartment.compartmentPort to inventoryManager.inventoryPort;
        connection : CompartmentInterface connect instrumentCompartment.compartmentPort to inventoryManager.inventoryPort;
        connection : CompartmentInterface connect woundCareCompartment.compartmentPort to inventoryManager.inventoryPort;

        // Connection between diagnostic module and inventory manager
        connection : InventoryInterface connect diagnosticModule.diagnosticPort to inventoryManager.inventoryPort;

        // Power distribution
        connection powerConn1 connect powerSupply.powerOut to inventoryManager;
        connection powerConn2 connect powerSupply.powerOut to diagnosticModule;
        connection powerConn3 connect powerSupply.powerOut to medicationCompartment.tempController;
        connection powerConn4 connect powerSupply.powerOut to instrumentCompartment.tempController;
        connection powerConn5 connect powerSupply.powerOut to woundCareCompartment.tempController;

        // Operational workflow
        action def EmergencyCareWorkflow {
            in patientVitals : VitalSigns;
            out treatmentRecord : TreatmentRecord;

            action openBag : BagShell::OpenBag;
            action assessPatient : DiagnosticModule::ProcessVitals {
                in vitals := patientVitals;
            }
            action retrieveSupplies : StorageCompartment::RetrieveItem;
            action administerTreatment {
                in item supplies : MedicalItem[0..*];
                in severity : SeverityLevel;
                out item usedItems : MedicalItem[0..*];
                do {
                    usedItems := supplies;
                }
            }
            action logEvent {
                in item usedItems : MedicalItem[0..*];
                in vitals : VitalSigns;
                in severity : SeverityLevel;
                out record : TreatmentRecord;
                do {
                    record := TreatmentRecord{
                        recordId = "TR-" + UUID::random().toString(),
                        timestamp = now(),
                        patientId = "PT-UNKNOWN",
                        vitals = vitals,
                        severityLevel = severity,
                        itemsUsed = usedItems,
                        notes = "Emergency care administered in field."
                    };
                    treatmentRecord := record;
                }
            }

            flow from openBag.isOpen to assessPatient;
            flow from assessPatient.severity to retrieveSupplies;
            flow from assessPatient.recommendedItems to retrieveSupplies;
            flow from retrieveSupplies.retrievedItem to administerTreatment.supplies;
            flow from assessPatient.severity to administerTreatment.severity;
            flow from administerTreatment.usedItems to logEvent.usedItems;
            flow from assessPatient.vitals to logEvent.vitals;
            flow from assessPatient.severity to logEvent.severity;
            flow from logEvent.record to treatmentRecord;
        }

        state defenum SystemState { sealed; opened; assessing; retrieving; treating; logging; closed; }

        state machine SystemStateMachine {
            state sealed;
            state opened;
            state assessing;
            state retrieving;
            state treating;
            state logging;
            state closed;

            transition sealed to opened
                when { bagShell.isSealed == false }
                do { perform EmergencyCareWorkflow.openBag(); }

            transition opened to assessing
                when { diagnosticModule.diagnosticPort.vitals->isReceived() }
                do { perform EmergencyCareWorkflow.assessPatient(); }

            transition assessing to retrieving
                when { diagnosticModule.diagnosticPort.severity->isReceived() }
                do { perform EmergencyCareWorkflow.retrieveSupplies(); }

            transition retrieving to treating
                when { true }
                do { perform EmergencyCareWorkflow.administerTreatment(); }

            transition treating to logging
                when { true }
                do { perform EmergencyCareWorkflow.logEvent(); }

            transition logging to closed
                when { true }
                do { perform BagShell::CloseBag(); }

            transition closed to sealed
                when { bagShell.isSealed == true }
        }
    }

    // ===== Requirements =====
    requirement def PortabilityRequirement {
        attribute maxWeight : MassValue := 5.0;
        subject : EmergencyMedicalBag;
        require {
            subject.totalWeight <= maxWeight and subject.isPortable == true;
        }
    }

    requirement def AccessibilityRequirement {
        attribute maxAccessTime : DurationValue := 30.0;
        subject : EmergencyMedicalBag;
        require {
            // All supplies must be accessible within maxAccessTime seconds
            true;
        }
    }

    requirement def TemperatureControlRequirement {
        subject : StorageCompartment;
        attribute tolerance : TemperatureValue := 2.0;
        require {
            subject.tempController.currentTemp >= subject.targetTempRange.min - tolerance and
            subject.tempController.currentTemp <= subject.targetTempRange.max + tolerance;
        }
    }

    requirement def SterilityRequirement {
        subject : MedicalItem;
        require {
            subject.isSterile == true or subject.category != "sterile";
        }
    }

    requirement def InventoryTrackingRequirement {
        subject : InventoryManager;
        require {
            subject.trackedItems->size() > 0 and
            subject.activeAlerts->select(a | a.alertType == AlertType::expiredItem)->size() == 0;
        }
    }

    requirement def DiagnosticAccuracyRequirement {
        subject : DiagnosticModule;
        require {
            // Module must correctly classify severity based on vital signs
            true;
        }
    }

    requirement def WorkflowCompletenessRequirement {
        subject : EmergencyMedicalBag;
        require {
            // System must support complete emergency care workflow
            true;
        }
    }

    requirement def MedicationStorageRequirement :> TemperatureControlRequirement {
        subject : MedicationCompartment;
        attribute targetTempRange : TempRange := TempRange{min = 2.0, max = 8.0};
    }

    requirement def InstrumentStorageRequirement :> TemperatureControlRequirement {
        subject : InstrumentCompartment;
        attribute targetTempRange : TempRange := TempRange{min = 15.0, max = 25.0};
    }

    requirement def WoundCareStorageRequirement :> TemperatureControlRequirement {
        subject : WoundCareCompartment;
        attribute targetTempRange : TempRange := TempRange{min = 15.0, max = 25.0};
    }

    // ===== Verification =====
    verification def VerifyPortability {
        subject : EmergencyMedicalBag;
        objective {
            "Verify the bag meets portability requirements.";
        }
        method {
            "Weigh the fully loaded bag and confirm it does not exceed 5.0 kg.";
        }
    }

    verification def VerifyTemperatureControl {
        subject : StorageCompartment;
        objective {
            "Verify each compartment maintains its target temperature range.";
        }
        method {
            "Monitor compartment temperature over 24 hours and verify it remains within tolerance.";
        }
    }

    verification def VerifyInventoryTracking {
        subject : InventoryManager;
        objective {
            "Verify inventory manager tracks all items and generates appropriate alerts.";
        }
        method {
            "Insert expired and non-sterile items, verify alerts are generated.";
        }
    }

    verification def VerifyDiagnosticModule {
        subject : DiagnosticModule;
        objective {
            "Verify diagnostic module correctly assesses severity and recommends supplies.";
        }
        method {
            "Input known vital signs and verify severity classification and supply recommendations.";
        }
    }

    verification def VerifyWorkflow {
        subject : EmergencyMedicalBag;
        objective {
            "Verify complete emergency care workflow from bag opening to treatment logging.";
        }
        method {
            "Conduct simulated emergency scenario and verify all workflow steps complete successfully.";
        }
    }
}
