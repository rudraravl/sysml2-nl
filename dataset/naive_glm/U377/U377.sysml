package MedicalScrubsManagementSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---------- Value Types with Units ----------
    attribute def TemperatureValue :> Real {
        attribute unit : String = "degC";
    }
    attribute def DurationValue :> Real {
        attribute unit : String = "hour";
    }
    attribute def MassValue :> Real {
        attribute unit : String = "kg";
    }
    attribute def CountValue :> Integer;
    attribute def PercentageValue :> Real {
        attribute unit : String = "percent";
    }

    // ---------- Enumerations ----------
    enum def ScrubSize { small; medium; large; xlarge; xxlarge; }
    enum def ScrubColor { blue; green; teal; magenta; navy; }
    enum def ContaminationLevel { low; moderate; high; biohazard; }
    enum def InspectionResult { pass; fail_rewash; fail_retire; }
    enum def ScrubState { clean; issued; soiled; collected; sorted; washing; drying; inspected; folded; stored; }

    // ---------- Item Types ----------
    item def Scrub {
        attribute size : ScrubSize;
        attribute color : ScrubColor;
        attribute contaminationLevel : ContaminationLevel := ContaminationLevel::low;
        attribute state : ScrubState := ScrubState::clean;
        attribute rfidTagId : String;
        attribute washCycleCount : Integer := 0;
        attribute maxWashCycles : Integer := 100;
    }

    item def CleanScrub :> Scrub {
        redefines attribute state := ScrubState::clean;
    }

    item def SoiledScrub :> Scrub {
        redefines attribute state := ScrubState::soiled;
    }

    item def DetergentSolution {
        attribute concentration : PercentageValue;
        attribute volume : Real;
    }

    item def PackagedScrubSet {
        attribute contents : Scrub[1..*];
        attribute packageId : String;
    }

    // ---------- Port Definitions ----------
    port def CleanScrubOutPort {
        out cleanScrubs : CleanScrub[0..*];
    }
    port def SoiledScrubInPort {
        in soiledScrubs : SoiledScrub[0..*];
    }
    port def ScrubTransferPort {
        out scrubsOut : Scrub[0..*];
        in scrubsIn : Scrub[0..*];
    }
    port def DetergentInPort {
        in detergent : DetergentSolution[0..*];
    }
    port def PackagedScrubOutPort {
        out packagedSets : PackagedScrubSet[0..*];
    }
    port def PackagedScrubInPort {
        in packagedSets : PackagedScrubSet[0..*];
    }

    // ---------- Requirements ----------
    requirement def ProcessingTimeRequirement {
        doc /* The system shall process scrubs from collection to clean storage within 4 hours. */
        attribute maxProcessingTime : DurationValue = 4.0;
        subject scrubsProcessingTime : DurationValue;
        constraint { scrubsProcessingTime <= maxProcessingTime }
    }

    requirement def WashTemperatureRequirement {
        doc /* The washer shall maintain a minimum wash temperature of 71 degC for thermal decontamination. */
        attribute minWashTemp : TemperatureValue = 71.0;
        subject washTemp : TemperatureValue;
        constraint { washTemp >= minWashTemp }
    }

    requirement def HygieneStandardRequirement {
        doc /* All scrubs issued from dispensary shall be decontaminated and inspected. */
        subject issuedScrubs : CleanScrub[0..*];
        constraint { issuedScrubs->forAll(s | s.state == ScrubState::clean) }
    }

    requirement def InspectionRequirement {
        doc /* Every scrub shall pass quality inspection before packaging. */
        subject inspectedScrubs : Scrub[0..*];
        constraint { inspectedScrubs->forAll(s | s.state == ScrubState::inspected) }
    }

    requirement def InventoryAvailabilityRequirement {
        doc /* The dispensary shall maintain a minimum stock of 50 clean scrubs per size. */
        attribute minStockPerSize : CountValue = 50;
        subject dispensaryStock : CountValue;
        constraint { dispensaryStock >= minStockPerSize }
    }

    requirement def EnvironmentalControlRequirement {
        doc /* Clean storage shall maintain temperature between 18 and 24 degC and humidity below 50%. */
        attribute minTemp : TemperatureValue = 18.0;
        attribute maxTemp : TemperatureValue = 24.0;
        attribute maxHumidity : PercentageValue = 50.0;
        subject storageTemp : TemperatureValue;
        subject storageHumidity : PercentageValue;
        constraint { storageTemp >= minTemp and storageTemp <= maxTemp }
        constraint { storageHumidity <= maxHumidity }
    }

    // ---------- Part Definitions ----------

    part def DispensaryUnit {
        attribute dispensaryId : String;
        attribute capacity : CountValue;
        attribute currentStock : CountValue := 0;
        port cleanOut : CleanScrubOutPort;
        port restockIn : PackagedScrubInPort;

        attribute stockBySize : Map[ScrubSize, CountValue];

        action def issueScrub(in staffId : String, in requestedSize : ScrubSize, in requestedColor : ScrubColor) : CleanScrub {
            // Decrement stock and issue scrub
        }

        action def restock(in sets : PackagedScrubSet[0..*]) {
            // Add packaged sets to inventory
        }

        satisfy InventoryAvailabilityRequirement by restock;

        state def DispensaryBehavior {
            entry; then Operational;
            state Operational;
            transition from Operational to Operational on restockIn;
            transition from Operational to Operational when currentStock < 50;
        }
    }

    part def CollectionBin {
        attribute binId : String;
        attribute location : String;
        attribute capacity : CountValue;
        attribute fillLevel : CountValue := 0;
        port soiledOut : ScrubTransferPort;

        action def collectSoiledScrub(in scrub : SoiledScrub) {
            // Accept soiled scrub from staff
        }

        action def dispatchForSorting(out scrubs : SoiledScrub[0..*]) {
            // Send collected scrubs to sorting
        }

        state def CollectionBinBehavior {
            entry; then Empty;
            state Empty;
            state PartiallyFilled;
            state Full;
            transition from Empty to PartiallyFilled on collectSoiledScrub;
            transition from PartiallyFilled to PartiallyFilled on collectSoiledScrub;
            transition from PartiallyFilled to Full when fillLevel >= capacity;
            transition from Full to Empty on dispatchForSorting;
        }
    }

    part def SortingStation {
        attribute stationId : String;
        attribute throughputPerHour : CountValue;
        port soiledIn : SoiledScrubInPort;
        port sortedOut : ScrubTransferPort;

        action def sortScrubs(in scrubs : SoiledScrub[0..*]) : Scrub[0..*] {
            // Sort by color and contamination level
            // Assign sorted state
        }

        state def SortingBehavior {
            entry; then Idle;
            state Idle;
            state Sorting;
            transition from Idle to Sorting on soiledIn;
            transition from Sorting to Idle when true;
        }
    }

    part def IndustrialWasher {
        attribute washerId : String;
        attribute loadCapacity : MassValue;
        attribute currentTemperature : TemperatureValue;
        attribute cycleDurationMinutes : Integer;
        attribute minRequiredTemp : TemperatureValue = 71.0;
        port scrubIn : ScrubTransferPort;
        port detergentIn : DetergentInPort;
        port scrubOut : ScrubTransferPort;

        action def washCycle(in scrubs : Scrub[0..*], in detergent : DetergentSolution, in targetTemp : TemperatureValue) : Scrub[0..*] {
            // Execute high-temperature wash cycle
            // Increment washCycleCount for each scrub
        }

        satisfy WashTemperatureRequirement by washCycle;

        state def WasherBehavior {
            entry; then Idle;
            state Idle;
            state Loading;
            state Washing {
                entry action { currentTemperature := 71.0; }
                do action { /* maintain temperature and agitate */ }
            }
            state Unloading;
            transition from Idle to Loading on scrubIn;
            transition from Loading to Washing when true;
            transition from Washing to Unloading when currentTemperature >= 71.0;
            transition from Unloading to Idle when true;
        }
    }

    part def IndustrialDryer {
        attribute dryerId : String;
        attribute loadCapacity : MassValue;
        attribute dryingTemp : TemperatureValue;
        attribute cycleDurationMinutes : Integer;
        port scrubIn : ScrubTransferPort;
        port scrubOut : ScrubTransferPort;

        action def dryCycle(in scrubs : Scrub[0..*]) : Scrub[0..*] {
            // Tumble dry scrubs
        }

        state def DryerBehavior {
            entry; then Idle;
            state Idle;
            state Drying;
            transition from Idle to Drying on scrubIn;
            transition from Drying to Idle when true;
        }
    }

    part def InspectionStation {
        attribute stationId : String;
        port scrubIn : ScrubTransferPort;
        port passOut : ScrubTransferPort;
        port failOut : ScrubTransferPort;

        action def inspect(in scrub : Scrub) : InspectionResult {
            // Examine for cleanliness, wear, and tear
        }

        action def routeScrub(in scrub : Scrub) {
            // If fail_rewash -> send back to washer
            // If fail_retire -> dispose
            // If pass -> send to folding
        }

        satisfy InspectionRequirement by inspect;

        state def InspectionBehavior {
            entry; then Idle;
            state Idle;
            state Inspecting;
            transition from Idle to Inspecting on scrubIn;
            transition from Inspecting to Idle when true;
        }
    }

    part def FoldingPackagingStation {
        attribute stationId : String;
        port scrubIn : ScrubTransferPort;
        port packagedOut : PackagedScrubOutPort;

        action def foldAndPackage(in scrubs : Scrub[0..*]) : PackagedScrubSet {
            // Fold, package, and label scrubs
        }

        state def FoldingBehavior {
            entry; then Idle;
            state Idle;
            state Folding;
            state Packaging;
            transition from Idle to Folding on scrubIn;
            transition from Folding to Packaging when true;
            transition from Packaging to Idle when true;
        }
    }

    part def CleanStorageArea {
        attribute storageId : String;
        attribute capacity : CountValue;
        attribute currentTemp : TemperatureValue;
        attribute currentHumidity : PercentageValue;
        attribute inventoryCount : CountValue := 0;
        port packagedIn : PackagedScrubInPort;
        port restockOut : PackagedScrubOutPort;

        action def storePackagedSets(in sets : PackagedScrubSet[0..*]) {
            // Place in environmentally controlled storage
        }

        action def dispatchToDispensary(out sets : PackagedScrubSet[0..*]) {
            // Restock dispensary units
        }

        satisfy EnvironmentalControlRequirement by storePackagedSets;

        state def StorageBehavior {
            entry; then ClimateControlled;
            state ClimateControlled {
                entry action { currentTemp := 21.0; currentHumidity := 40.0; }
                do action { /* maintain climate */ }
            }
            transition from ClimateControlled to ClimateControlled on packagedIn;
            transition from ClimateControlled to ClimateControlled on restockOut;
        }
    }

    part def StaffMember {
        attribute staffId : String;
        attribute name : String;
        attribute role : String;
    }

    // ---------- Top-level System ----------
    part def MedicalScrubsManagementSystem {

        attribute systemId : String := "MSMS-001";
        attribute totalProcessingTime : DurationValue;

        satisfy ProcessingTimeRequirement by totalProcessingTime;
        satisfy HygieneStandardRequirement by dispensary.cleanOut.cleanScrubs;

        part dispensary : DispensaryUnit {
            attribute dispensaryId := "DISP-01";
            attribute capacity := 500;
        }

        part collectionBins : CollectionBin[4] {
            attribute capacity := 100;
        }

        part sortingStation : SortingStation {
            attribute stationId := "SORT-01";
            attribute throughputPerHour := 200;
        }

        part industrialWasher : IndustrialWasher {
            attribute washerId := "WASH-01";
            attribute loadCapacity := 50.0;
            attribute cycleDurationMinutes := 45;
        }

        part industrialDryer : IndustrialDryer {
            attribute dryerId := "DRY-01";
            attribute loadCapacity := 50.0;
            attribute dryingTemp := 60.0;
            attribute cycleDurationMinutes := 30;
        }

        part inspectionStation : InspectionStation {
            attribute stationId := "INSP-01";
        }

        part foldingPackaging : FoldingPackagingStation {
            attribute stationId := "FOLD-01";
        }

        part cleanStorage : CleanStorageArea {
            attribute storageId := "STOR-01";
            attribute capacity := 1000;
        }

        // ---------- Connections ----------
        connection def ScrubFlowConnection :> Connection {
            end source : ScrubTransferPort;
            end target : ScrubTransferPort;
        }

        connection def SoiledFlowConnection :> Connection {
            end source : SoiledScrubInPort;
            end target : ScrubTransferPort;
        }

        connection def PackagedFlowConnection :> Connection {
            end source : PackagedScrubOutPort;
            end target : PackagedScrubInPort;
        }

        // Collection bins to sorting station
        connection binToSort : ScrubFlowConnection connect collectionBins.soiledOut to sortingStation.scrubIn;

        // Sorting station to washer
        connection sortToWash : ScrubFlowConnection connect sortingStation.sortedOut to industrialWasher.scrubIn;

        // Washer to dryer
        connection washToDry : ScrubFlowConnection connect industrialWasher.scrubOut to industrialDryer.scrubIn;

        // Dryer to inspection
        connection dryToInspect : ScrubFlowConnection connect industrialDryer.scrubOut to inspectionStation.scrubIn;

        // Inspection pass to folding
        connection inspectToFold : ScrubFlowConnection connect inspectionStation.passOut to foldingPackaging.scrubIn;

        // Inspection fail back to washer (re-wash loop)
        connection inspectRewash : ScrubFlowConnection connect inspectionStation.failOut to industrialWasher.scrubIn;

        // Folding to clean storage
        connection foldToStorage : PackagedFlowConnection connect foldingPackaging.packagedOut to cleanStorage.packagedIn;

        // Clean storage to dispensary (restock)
        connection storageToDispensary : PackagedFlowConnection connect cleanStorage.restockOut to dispensary.restockIn;

        // ---------- System-level Behavior ----------
        action def ProcessScrubBatch(in soiledBatch : SoiledScrub[0..*]) : PackagedScrubSet[0..*] {
            action sort : SortingStation::sortScrubs in soiledBatch;
            action wash : IndustrialWasher::washCycle in sort.out;
            action dry : IndustrialDryer::dryCycle in wash.out;
            action inspect : InspectionStation::inspect in dry.out;
            action fold : FoldingPackagingStation::foldAndPackage in inspect.pass;
            return fold.out;
        }

        state def SystemOperation {
            entry; then Running;
            state Running {
                entry action { totalProcessingTime := 0.0; }
                do action { /* monitor cycle time, ensure < 4 hours */ }
            }
            state Maintenance;
            transition from Running to Maintenance when industrialWasher.currentTemperature < 71.0;
            transition from Maintenance to Running when industrialWasher.currentTemperature >= 71.0;
        }
    }

}
