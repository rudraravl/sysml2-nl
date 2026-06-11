package EnergyManufacturingCoSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    item def RawMaterialBatch {
        attribute batchId : String;
        attribute materialKind : MaterialKind;
        attribute mass : MassValue;
        attribute moistureFraction : Real;
        attribute receivedAt : DateTime;
    }

    enum def MaterialKind {
        enum copper;
        enum electricalSteel;
        enum aluminum;
        enum insulationResin;
        enum bearingSteel;
        enum packaging;
    }

    item def FinishedEnergyProduct {
        attribute serialNumber : String;
        attribute productKind : ProductKind;
        attribute ratedPower : PowerValue;
        attribute ratedVoltage : ElectricPotentialValue;
        attribute efficiency : Real;
        attribute manufacturingDate : DateTime;
        attribute complianceStatus : ComplianceStatus;
    }

    enum def ProductKind {
        enum industrialMotor;
        enum pumpDriveAssembly;
        enum powerConversionCabinet;
        enum generatorSubassembly;
    }

    enum def ComplianceStatus {
        enum pending;
        enum passed;
        enum failed;
        enum quarantined;
    }

    item def ManufacturingOrder {
        attribute orderId : String;
        attribute requestedProduct : ProductKind;
        attribute quantity : Integer;
        attribute dueDate : DateTime;
        attribute priority : Integer;
    }

    item def QualityRecord {
        attribute recordId : String;
        attribute measuredEfficiency : Real;
        attribute measuredInsulationResistance : ResistanceValue;
        attribute vibrationLevel : AccelerationValue;
        attribute disposition : ComplianceStatus;
    }

    item def EnergyFlow {
        attribute activePower : PowerValue;
        attribute voltage : ElectricPotentialValue;
        attribute current : ElectricCurrentValue;
        attribute frequency : FrequencyValue;
    }

    item def ProductionStatus {
        attribute producedCount : Integer;
        attribute rejectedCount : Integer;
        attribute lineAvailability : Real;
        attribute workInProcessCount : Integer;
    }

    value type MassValue specializes Mass {
        unit = kg;
    }

    value type PowerValue specializes Power {
        unit = W;
    }

    value type ElectricPotentialValue specializes ElectricPotential {
        unit = V;
    }

    value type ElectricCurrentValue specializes ElectricCurrent {
        unit = A;
    }

    value type FrequencyValue specializes Frequency {
        unit = Hz;
    }

    value type ResistanceValue specializes Resistance {
        unit = Ohm;
    }

    value type AccelerationValue specializes Acceleration {
        unit = "m/s^2";
    }

    value type DurationValue specializes Time {
        unit = s;
    }

    port def MaterialInputPort {
        in item material : RawMaterialBatch;
    }

    port def ProductOutputPort {
        out item product : FinishedEnergyProduct;
    }

    port def OrderInputPort {
        in item order : ManufacturingOrder;
    }

    port def QualityRecordPort {
        out item record : QualityRecord;
    }

    port def ElectricalPowerPort {
        in item power : EnergyFlow;
    }

    port def StatusPort {
        out item status : ProductionStatus;
    }

    port def ControlCommandPort {
        in item command : String;
    }

    part def EnterpriseResourcePlanningSystem {
        port orderIn : OrderInputPort;
        port productionStatusOut : StatusPort;
        attribute scheduledOrders : Integer;
        attribute planningHorizon : DurationValue;
    }

    part def MaterialReceivingCell {
        port rawMaterialIn : MaterialInputPort;
        port acceptedMaterialOut : MaterialInputPort;
        port statusOut : StatusPort;
        attribute storageCapacity : MassValue;
        attribute inspectionThroughput : MassValue;
    }

    part def FabricationLine {
        port materialIn : MaterialInputPort;
        port powerIn : ElectricalPowerPort;
        port commandIn : ControlCommandPort;
        port fabricatedAssemblyOut : ProductOutputPort;
        port statusOut : StatusPort;
        attribute nominalThroughput : Integer;
        attribute averageCycleTime : DurationValue;
        attribute installedPower : PowerValue;

        part cutter {
            attribute positioningAccuracy : LengthValue;
            attribute maxSheetThickness : LengthValue;
        }

        part windingStation {
            attribute windingSpeed : FrequencyValue;
            attribute wireTensionSetpoint : ForceValue;
        }

        part machiningCenter {
            attribute spindlePower : PowerValue;
            attribute toolChangeTime : DurationValue;
        }
    }

    part def AssemblyLine {
        port assemblyIn : ProductOutputPort;
        port commandIn : ControlCommandPort;
        port assembledProductOut : ProductOutputPort;
        port statusOut : StatusPort;
        attribute stations : Integer;
        attribute taktTime : DurationValue;

        part rotorInsertionStation;
        part bearingPressStation;
        part enclosureStation;
        part labelingStation;
    }

    part def TestAndQualityCell {
        port productIn : ProductOutputPort;
        port powerIn : ElectricalPowerPort;
        port testedProductOut : ProductOutputPort;
        port qualityRecordOut : QualityRecordPort;
        port statusOut : StatusPort;
        attribute maxTestVoltage : ElectricPotentialValue;
        attribute minimumInsulationResistance : ResistanceValue;
        attribute efficiencyAcceptanceThreshold : Real;
    }

    part def PackagingAndShippingCell {
        port productIn : ProductOutputPort;
        port shippedProductOut : ProductOutputPort;
        port statusOut : StatusPort;
        attribute packingRate : Integer;
        attribute finishedGoodsCapacity : Integer;
    }

    part def UtilityPowerSystem {
        port facilityPowerOut : ElectricalPowerPort;
        attribute serviceVoltage : ElectricPotentialValue;
        attribute availableCapacity : PowerValue;
        attribute nominalFrequency : FrequencyValue;
    }

    part def ManufacturingExecutionSystem {
        port orderIn : OrderInputPort;
        port commandOut : ControlCommandPort;
        port statusIn : StatusPort;
        attribute activeOrders : Integer;
        attribute traceabilityRetention : DurationValue;
    }

    part def EnergyManufacturingCompany {
        doc /* Energy Manufacturing Co. Inc is modeled as an industrial energy-equipment manufacturing enterprise whose primary high-level function is to transform approved raw materials and customer production orders into tested, compliant, packaged energy products such as industrial motors, pump drive assemblies, generator subassemblies, and power conversion cabinets. */

        port customerOrderIn : OrderInputPort;
        port rawMaterialIn : MaterialInputPort;
        port gridPowerIn : ElectricalPowerPort;
        port finishedProductOut : ProductOutputPort;
        port qualityRecordOut : QualityRecordPort;
        port enterpriseStatusOut : StatusPort;

        attribute dailyProductionTarget : Integer = 120;
        attribute nominalPlantCapacity : PowerValue = 2500000 [W];
        attribute targetFirstPassYield : Real = 0.985;
        attribute targetLineAvailability : Real = 0.92;

        part erp : EnterpriseResourcePlanningSystem {
            attribute scheduledOrders = 40;
            attribute planningHorizon = 2592000 [s];
        }

        part mes : ManufacturingExecutionSystem {
            attribute activeOrders = 12;
            attribute traceabilityRetention = 315360000 [s];
        }

        part receiving : MaterialReceivingCell {
            attribute storageCapacity = 250000 [kg];
            attribute inspectionThroughput = 10000 [kg];
        }

        part fabrication : FabricationLine {
            attribute nominalThroughput = 160;
            attribute averageCycleTime = 300 [s];
            attribute installedPower = 900000 [W];
        }

        part assembly : AssemblyLine {
            attribute stations = 8;
            attribute taktTime = 420 [s];
        }

        part quality : TestAndQualityCell {
            attribute maxTestVoltage = 15000 [V];
            attribute minimumInsulationResistance = 100000000 [Ohm];
            attribute efficiencyAcceptanceThreshold = 0.94;
        }

        part packaging : PackagingAndShippingCell {
            attribute packingRate = 140;
            attribute finishedGoodsCapacity = 500;
        }

        part utilities : UtilityPowerSystem {
            attribute serviceVoltage = 13800 [V];
            attribute availableCapacity = 2500000 [W];
            attribute nominalFrequency = 60 [Hz];
        }

        connect customerOrderIn to erp.orderIn;
        connect customerOrderIn to mes.orderIn;
        connect rawMaterialIn to receiving.rawMaterialIn;
        connect gridPowerIn to utilities.facilityPowerOut;
        connect utilities.facilityPowerOut to fabrication.powerIn;
        connect utilities.facilityPowerOut to quality.powerIn;
        connect receiving.acceptedMaterialOut to fabrication.materialIn;
        connect mes.commandOut to fabrication.commandIn;
        connect mes.commandOut to assembly.commandIn;
        connect fabrication.fabricatedAssemblyOut to assembly.assemblyIn;
        connect assembly.assembledProductOut to quality.productIn;
        connect quality.testedProductOut to packaging.productIn;
        connect quality.qualityRecordOut to qualityRecordOut;
        connect packaging.shippedProductOut to finishedProductOut;
        connect packaging.statusOut to enterpriseStatusOut;
    }

    action def ReceiveInspectAndReleaseMaterial {
        in item incoming : RawMaterialBatch;
        out item accepted : RawMaterialBatch;
        out item rejected : RawMaterialBatch;

        first start;
        then inspectIdentity;
        then measureMassAndCondition;
        then decideMaterialDisposition;

        if incoming.moistureFraction <= 0.03 then releaseAcceptedMaterial;
        else quarantineRejectedMaterial;

        then done;

        action inspectIdentity;
        action measureMassAndCondition;
        action decideMaterialDisposition;
        action releaseAcceptedMaterial;
        action quarantineRejectedMaterial;
    }

    action def ManufactureEnergyProduct {
        in item order : ManufacturingOrder;
        in item material : RawMaterialBatch;
        out item product : FinishedEnergyProduct;

        first start;
        then scheduleWorkOrder;
        then fabricateComponents;
        then assembleProduct;
        then performFunctionalTest;
        then packageProduct;
        then releaseProduct;

        action scheduleWorkOrder;
        action fabricateComponents;
        action assembleProduct;
        action performFunctionalTest;
        action packageProduct;
        action releaseProduct;
    }

    action def ExecuteQualityTest {
        in item candidate : FinishedEnergyProduct;
        out item tested : FinishedEnergyProduct;
        out item record : QualityRecord;

        first start;
        then verifyNameplateData;
        then insulationResistanceTest;
        then noLoadRunTest;
        then loadEfficiencyTest;
        then vibrationScreening;
        then assignDisposition;

        action verifyNameplateData;
        action insulationResistanceTest;
        action noLoadRunTest;
        action loadEfficiencyTest;
        action vibrationScreening;
        action assignDisposition;
    }

    state def ManufacturingLineStateMachine {
        entry action initializeLine;
        exit action secureLine;

        state idle;
        state scheduled;
        state receivingMaterial;
        state fabricating;
        state assembling;
        state testing;
        state packaging;
        state shipping;
        state maintenance;
        state faulted;

        initial then idle;

        transition idle_to_scheduled
            first idle
            accept ManufacturingOrder
            then scheduled;

        transition scheduled_to_receiving
            first scheduled
            then receivingMaterial;

        transition receiving_to_fabricating
            first receivingMaterial
            if materialApproved
            then fabricating;

        transition fabricating_to_assembling
            first fabricating
            if fabricatedAssemblyComplete
            then assembling;

        transition assembling_to_testing
            first assembling
            if assemblyComplete
            then testing;

        transition testing_to_packaging
            first testing
            if productPassed
            then packaging;

        transition testing_to_faulted
            first testing
            if criticalTestFailure
            then faulted;

        transition packaging_to_shipping
            first packaging
            if packageComplete
            then shipping;

        transition shipping_to_idle
            first shipping
            then idle;

        transition any_to_maintenance
            first idle
            accept "maintenanceRequested"
            then maintenance;

        transition maintenance_to_idle
            first maintenance
            if maintenanceComplete
            then idle;

        transition any_to_faulted
            first scheduled
            if emergencyStop
            then faulted;

        transition faulted_to_idle
            first faulted
            if faultCleared
            then idle;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* Energy Manufacturing Co. Inc shall convert customer manufacturing orders and approved raw materials into compliant finished energy products through receiving, fabrication, assembly, test, packaging, and shipment. */
        subject company : EnergyManufacturingCompany;

        require constraint {
            company.dailyProductionTarget >= 100
        }
    }

    requirement def ProductComplianceRequirement {
        doc /* Each released finished product shall have passed quality testing and shall be marked compliant before shipment. */
        subject product : FinishedEnergyProduct;

        require constraint {
            product.complianceStatus == ComplianceStatus::passed
        }
    }

    requirement def EfficiencyRequirement {
        doc /* Each released energy product shall meet or exceed the minimum efficiency threshold established by the quality cell. */
        subject product : FinishedEnergyProduct;
        subject qualityCell : TestAndQualityCell;

        require constraint {
            product.efficiency >= qualityCell.efficiencyAcceptanceThreshold
        }
    }

    requirement def TraceabilityRequirement {
        doc /* The manufacturing execution system shall retain order, material, process, and quality traceability data for at least ten years. */
        subject mes : ManufacturingExecutionSystem;

        require constraint {
            mes.traceabilityRetention >= 315360000 [s]
        }
    }

    requirement def AvailabilityRequirement {
        doc /* The manufacturing system shall maintain sufficient line availability to support planned production. */
        subject company : EnergyManufacturingCompany;

        require constraint {
            company.targetLineAvailability >= 0.90
        }
    }

    requirement def PowerCapacityRequirement {
        doc /* The facility utility power system shall provide sufficient capacity for fabrication and quality test operations. */
        subject utilities : UtilityPowerSystem;
        subject fabrication : FabricationLine;

        require constraint {
            utilities.availableCapacity >= fabrication.installedPower
        }
    }

    requirement def MaterialAcceptanceRequirement {
        doc /* Incoming raw material shall be inspected and accepted only when its measured moisture fraction is within the permitted manufacturing limit. */
        subject batch : RawMaterialBatch;

        require constraint {
            batch.moistureFraction <= 0.03
        }
    }

    satisfy PrimaryFunctionRequirement by EnergyManufacturingCompany;
    satisfy AvailabilityRequirement by EnergyManufacturingCompany;
    satisfy PowerCapacityRequirement by UtilityPowerSystem;
    satisfy TraceabilityRequirement by ManufacturingExecutionSystem;
    satisfy ProductComplianceRequirement by FinishedEnergyProduct;
    satisfy EfficiencyRequirement by FinishedEnergyProduct;
    satisfy MaterialAcceptanceRequirement by RawMaterialBatch;

    allocation def ManufacturingFlowAllocation {
        end orderProcessing : ManufacturingExecutionSystem;
        end materialPreparation : MaterialReceivingCell;
        end componentProduction : FabricationLine;
        end productBuild : AssemblyLine;
        end productVerification : TestAndQualityCell;
        end productRelease : PackagingAndShippingCell;
    }

    view def HighLevelOperationalView {
        expose EnergyManufacturingCompany;
        expose ManufacturingOrder;
        expose RawMaterialBatch;
        expose FinishedEnergyProduct;
        expose ManufacturingLineStateMachine;
        expose ManufactureEnergyProduct;
        expose PrimaryFunctionRequirement;
    }
}