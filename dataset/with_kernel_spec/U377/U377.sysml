package 'Medical Scrubs Management System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    enum def ScrubCondition {
        clean;
        soiled;
        contaminated;
    }

    enum def InspectionResult {
        pass;
        fail;
    }

    item def Scrub {
        attribute size : String;
        attribute color : String;
        attribute condition : ScrubCondition;
        attribute isIntact : Boolean;
    }

    item def DetergentSolution {
        attribute concentration : Real;
        attribute volume : Real;
    }

    port def ScrubOutPort {
        out item scrub : Scrub[0..*];
    }

    port def ScrubInPort {
        in item scrub : Scrub[0..*];
    }

    port def DetergentInPort {
        in item detergent : DetergentSolution;
    }

    interface def ScrubFlow {
        end supplier : ScrubOutPort;
        end consumer : ScrubInPort;
        flow supplier.scrub to consumer.scrub;
    }

    part def DispensaryUnit {
        attribute location : String;
        attribute cleanInventoryCount : Integer;
        port issuePort : ScrubOutPort;
        port restockPort : ScrubInPort;

        action issueScrubs {
            out scrub : Scrub[0..*];
        }
        action acceptRestock {
            in scrub : Scrub[0..*];
        }
    }

    part def CollectionBin {
        attribute location : String;
        attribute capacity : ISQ::Mass;
        attribute currentLoad : ISQ::Mass;
        port collectPort : ScrubInPort;
        port dispatchPort : ScrubOutPort;

        action collectSoiled {
            in scrub : Scrub[0..*];
        }
        action dispatchFull {
            out scrub : Scrub[0..*];
        }
    }

    part def SortingStation {
        port inPort : ScrubInPort;
        port outPort : ScrubOutPort;

        action sortScrubs {
            in scrub : Scrub[0..*];
            out sortedScrub : Scrub[0..*];
        }
        perform sortScrubs;
    }

    part def IndustrialWasher {
        attribute minWashTemperature : ISQ::Temperature = 71.0 [SI::degreeCelsius];
        attribute cycleTime : ISQ::Time = 0.75 [SI::hour];
        port scrubInPort : ScrubInPort;
        port rewashInPort : ScrubInPort;
        port detergentInPort : DetergentInPort;
        port scrubOutPort : ScrubOutPort;

        action washCycle {
            in scrub : Scrub[0..*];
            in detergent : DetergentSolution;
            out washedScrub : Scrub[0..*];
        }
        perform washCycle;
    }

    part def IndustrialDryer {
        attribute cycleTime : ISQ::Time = 0.5 [SI::hour];
        port scrubInPort : ScrubInPort;
        port scrubOutPort : ScrubOutPort;

        action dryCycle {
            in scrub : Scrub[0..*];
            out driedScrub : Scrub[0..*];
        }
        perform dryCycle;
    }

    part def InspectionStation {
        port scrubInPort : ScrubInPort;
        port passedScrubOutPort : ScrubOutPort;
        port failedScrubOutPort : ScrubOutPort;

        action inspectScrubs {
            in scrub : Scrub[0..*];
            out passed : Scrub[0..*];
            out failed : Scrub[0..*];
        }
        perform inspectScrubs;
    }

    part def FoldingPackagingStation {
        port scrubInPort : ScrubInPort;
        port scrubOutPort : ScrubOutPort;

        action foldAndPackage {
            in scrub : Scrub[0..*];
            out packagedScrub : Scrub[0..*];
        }
        perform foldAndPackage;
    }

    part def CleanStorage {
        attribute temperature : ISQ::Temperature = 20.0 [SI::degreeCelsius];
        attribute humidity : Real = 50.0;
        port scrubInPort : ScrubInPort;
        port scrubOutPort : ScrubOutPort;

        action storeClean {
            in scrub : Scrub[0..*];
        }
        action releaseClean {
            out scrub : Scrub[0..*];
        }
    }

    part def HealthcareWorker;
    part def LaundryOperator;
    part def QualityInspector;

    requirement def ProcessingTimeRequirement {
        doc /* Process scrubs from collection to storage within four hours. */
        attribute maxProcessingTime : ISQ::Time = 4.0 [SI::hour];
    }

    requirement def HygieneStandardRequirement {
        doc /* Maintain minimum wash temperature to guarantee effective decontamination. */
        attribute minWashTemp : ISQ::Temperature = 71.0 [SI::degreeCelsius];
    }

    requirement def ContinuousSupplyRequirement {
        doc /* Ensure a continuous supply of clean scrubs to all dispensary units. */
        attribute minimumRequiredInventory : Integer = 50;
    }

    part def ScrubsManagementSystem {
        attribute totalProcessingTime : ISQ::Time;
        attribute cleanScrubsInventory : Integer;

        part dispensary : DispensaryUnit[1..*];
        part collectionBins : CollectionBin[1..*];
        part sortingStation : SortingStation;
        part washer : IndustrialWasher;
        part dryer : IndustrialDryer;
        part inspectionStation : InspectionStation;
        part foldingStation : FoldingPackagingStation;
        part cleanStorage : CleanStorage;

        interface : ScrubFlow connect
            supplier ::> collectionBins.dispatchPort to
            consumer ::> sortingStation.inPort;

        interface : ScrubFlow connect
            supplier ::> sortingStation.outPort to
            consumer ::> washer.scrubInPort;

        interface : ScrubFlow connect
            supplier ::> washer.scrubOutPort to
            consumer ::> dryer.scrubInPort;

        interface : ScrubFlow connect
            supplier ::> dryer.scrubOutPort to
            consumer ::> inspectionStation.scrubInPort;

        interface : ScrubFlow connect
            supplier ::> inspectionStation.failedScrubOutPort to
            consumer ::> washer.rewashInPort;

        interface : ScrubFlow connect
            supplier ::> inspectionStation.passedScrubOutPort to
            consumer ::> foldingStation.scrubInPort;

        interface : ScrubFlow connect
            supplier ::> foldingStation.scrubOutPort to
            consumer ::> cleanStorage.scrubInPort;

        interface : ScrubFlow connect
            supplier ::> cleanStorage.scrubOutPort to
            consumer ::> dispensary.restockPort;

        action manageScrubsLifecycle {
            action collectSoiledScrubs {
                in scrub : Scrub[0..*];
                out collected : Scrub[0..*];
            }
            then sortScrubs {
                in scrub : Scrub[0..*];
                out sorted : Scrub[0..*];
            }
            then washScrubs {
                in scrub : Scrub[0..*];
                in detergent : DetergentSolution;
                out washed : Scrub[0..*];
            }
            then dryScrubs {
                in scrub : Scrub[0..*];
                out dried : Scrub[0..*];
            }
            then inspectScrubs {
                in scrub : Scrub[0..*];
                out passed : Scrub[0..*];
                out failed : Scrub[0..*];
            }
            then foldAndPackage {
                in scrub : Scrub[0..*];
                out packaged : Scrub[0..*];
            }
            then storeCleanScrubs {
                in scrub : Scrub[0..*];
                out stored : Scrub[0..*];
            }
            then restockDispensary {
                in scrub : Scrub[0..*];
                out restocked : Scrub[0..*];
            }
            flow collectSoiledScrubs.collected to sortScrubs.scrub;
            flow sortScrubs.sorted to washScrubs.scrub;
            flow washScrubs.washed to dryScrubs.scrub;
            flow dryScrubs.dried to inspectScrubs.scrub;
            flow inspectScrubs.passed to foldAndPackage.scrub;
            flow foldAndPackage.packaged to storeCleanScrubs.scrub;
            flow storeCleanScrubs.stored to restockDispensary.scrub;
            flow inspectScrubs.failed to washScrubs.scrub;
        }

        perform manageScrubsLifecycle;

        satisfy processingTimeReq : ProcessingTimeRequirement {
            subject :> manageScrubsLifecycle;
        }
        satisfy hygieneReq : HygieneStandardRequirement {
            subject :> washer;
        }
        satisfy supplyReq : ContinuousSupplyRequirement {
            subject :> dispensary;
        }
    }

    use case 'Manage Scrubs Lifecycle' {
        subject system : ScrubsManagementSystem;
        actor staff : HealthcareWorker;
        actor laundryOperator : LaundryOperator;
        actor qualityInspector : QualityInspector;
        objective {
            doc /* Ensure continuous supply of clean, safe, decontaminated scrubs to all healthcare workers. */
        }
        first start;
        then include 'Dispense Clean Scrubs' {
            subject;
            actor :>> staff = 'Manage Scrubs Lifecycle'::staff;
        }
        then include 'Collect Soiled Scrubs' {
            subject;
            actor :>> staff = 'Manage Scrubs Lifecycle'::staff;
        }
        then include 'Process Scrubs' {
            subject;
            actor :>> laundryOperator = 'Manage Scrubs Lifecycle'::laundryOperator;
            actor :>> qualityInspector = 'Manage Scrubs Lifecycle'::qualityInspector;
        }
        then include 'Restock Dispensary' {
            subject;
            actor :>> laundryOperator = 'Manage Scrubs Lifecycle'::laundryOperator;
        }
        then done;
    }

    use case 'Dispense Clean Scrubs' {
        subject system : ScrubsManagementSystem;
        actor staff : HealthcareWorker;
    }

    use case 'Collect Soiled Scrubs' {
        subject system : ScrubsManagementSystem;
        actor staff : HealthcareWorker;
    }

    use case 'Process Scrubs' {
        subject system : ScrubsManagementSystem;
        actor laundryOperator : LaundryOperator;
        actor qualityInspector : QualityInspector;
    }

    use case 'Restock Dispensary' {
        subject system : ScrubsManagementSystem;
        actor laundryOperator : LaundryOperator;
    }

    part scrubsSystem : ScrubsManagementSystem;
}
