package SerbianBarrelModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    alias liter for SI::liter;
    alias millimeter for SI::millimetre;
    alias kilogram for SI::kilogram;
    alias degreeCelsius for SI::degreeCelsius;
    alias day for SI::day;
    alias percent for SI::percent;

    item def Rakija {
        attribute alcoholByVolume : Real;
        attribute sugarMassFraction : Real;
        attribute temperature : Real;
    }

    item def Air {
        attribute relativeHumidity : Real;
        attribute temperature : Real;
    }

    item def OakExtract {
        attribute tanninConcentration : Real;
        attribute vanillinConcentration : Real;
        attribute colorIntensity : Real;
    }

    item def Sediment {
        attribute mass : Real;
    }

    port def LiquidPort {
        inout liquid : Rakija;
    }

    port def AirExchangePort {
        inout air : Air;
    }

    port def ExtractPort {
        out extract : OakExtract;
    }

    part def OakStave {
        attribute length : Real = 650.0 [millimeter];
        attribute thickness : Real = 28.0 [millimeter];
        attribute internalCharDepth : Real = 1.5 [millimeter];
        attribute moistureContent : Real = 12.0 [percent];

        port innerSurface : ExtractPort;

        action extractOakCompounds {
            in storedLiquid : Rakija;
            out extractedCompounds : OakExtract;

            first start;
            then calculateTanninRelease;
            then calculateVanillinRelease;
            then deliverExtract;
        }
    }

    part def SteelHoop {
        attribute diameter : Real;
        attribute bandWidth : Real = 35.0 [millimeter];
        attribute tensionForce : Real;
    }

    part def Bung {
        attribute diameter : Real = 42.0 [millimeter];
        attribute sealingCompression : Real = 18.0 [percent];

        port vaporLeakPath : AirExchangePort;
    }

    part def BrassTap {
        attribute boreDiameter : Real = 12.0 [millimeter];
        attribute openFraction : Real = 0.0;

        port inlet : LiquidPort;
        port outlet : LiquidPort;

        action dispense {
            in requestedVolume : Real;
            out deliveredLiquid : Rakija;

            first closed;
            then openValve;
            then transferLiquid;
            then closeValve;
        }
    }

    part def BarrelStand {
        attribute loadCapacity : Real = 85.0 [kilogram];
        attribute cradleAngle : Real = 12.0;
    }

    part def SerbianBarrelSystem {
        attribute nominalCapacity : Real = 50.0 [liter];
        attribute currentFillVolume : Real = 0.0 [liter];
        attribute storageTemperature : Real = 15.0 [degreeCelsius];
        attribute agingDuration : Real = 0.0 [day];
        attribute primaryFunction : String = "Store, mature, and dispense rakija or wine in a traditional Serbian oak barrel while allowing controlled wood extraction and sealing.";

        part staves[24] : OakStave;
        part frontHead : OakStave {
            attribute length = 430.0 [millimeter];
        }
        part rearHead : OakStave {
            attribute length = 430.0 [millimeter];
        }
        part hoops[6] : SteelHoop;
        part bung : Bung;
        part tap : BrassTap;
        part stand : BarrelStand;

        port fillDrainPort : LiquidPort;
        port tastingPort : LiquidPort;
        port breathingPort : AirExchangePort;
        port maturationPort : ExtractPort;

        item storedBatch : Rakija;
        item settledSolids : Sediment;

        connect tap.inlet to fillDrainPort;
        connect tap.outlet to tastingPort;
        connect bung.vaporLeakPath to breathingPort;
        connect staves.innerSurface to maturationPort;

        action fillBarrel {
            in incomingLiquid : Rakija;
            in fillVolume : Real;

            first verifyCleanAndSealed;
            then removeBung;
            then transferIncomingLiquid;
            then setCurrentFillVolume;
            then installBung;
        }

        action matureLiquid {
            in duration : Real;
            out maturedLiquid : Rakija;

            first holdAtCellarTemperature;
            then diffuseOakExtract;
            then allowMicroOxygenation;
            then settleSediment;
            then updateAgingDuration;
        }

        action dispenseServing {
            in servingVolume : Real;
            out serving : Rakija;

            first verifyAvailableVolume;
            then openTap;
            then drainByGravity;
            then closeTap;
            then reduceCurrentFillVolume;
        }

        state def BarrelOperatingState {
            entry action reportPrimaryFunction;

            state Empty;
            state Filling;
            state SealedAging;
            state ReadyToServe;
            state Dispensing;
            state Cleaning;
            state Maintenance;

            initial then Empty;

            transition Empty_to_Filling
                first Empty
                accept FillCommand
                then Filling;

            transition Filling_to_SealedAging
                first Filling
                accept BungInstalled
                then SealedAging;

            transition SealedAging_to_ReadyToServe
                first SealedAging
                accept MinimumAgingComplete
                then ReadyToServe;

            transition ReadyToServe_to_Dispensing
                first ReadyToServe
                accept TapOpened
                then Dispensing;

            transition Dispensing_to_ReadyToServe
                first Dispensing
                accept TapClosed
                then ReadyToServe;

            transition ReadyToServe_to_Cleaning
                first ReadyToServe
                accept EmptyForCleaning
                then Cleaning;

            transition Cleaning_to_Empty
                first Cleaning
                accept DryAndSanitized
                then Empty;

            transition SealedAging_to_Maintenance
                first SealedAging
                accept LeakDetected
                then Maintenance;

            transition Maintenance_to_SealedAging
                first Maintenance
                accept LeakRepaired
                then SealedAging;
        }

        exhibit stateMachine : BarrelOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        subject barrel : SerbianBarrelSystem;

        doc /* The Serbian barrel shall provide a high-level function of storing, maturing, and dispensing traditional fruit brandy or wine using an oak vessel held by hoops, sealed by a bung, and emptied through a tap. */

        require constraint {
            barrel.nominalCapacity >= 10.0 [liter] and
            barrel.currentFillVolume <= barrel.nominalCapacity
        }
    }

    requirement def SealingRequirement {
        subject barrel : SerbianBarrelSystem;

        require constraint {
            barrel.bung.sealingCompression >= 10.0 [percent] and
            barrel.bung.sealingCompression <= 30.0 [percent]
        }
    }

    requirement def MaturationRequirement {
        subject barrel : SerbianBarrelSystem;

        require constraint {
            barrel.storageTemperature >= 8.0 [degreeCelsius] and
            barrel.storageTemperature <= 20.0 [degreeCelsius]
        }
    }

    requirement def DispensingRequirement {
        subject barrel : SerbianBarrelSystem;

        require constraint {
            barrel.tap.boreDiameter >= 8.0 [millimeter] and
            barrel.tap.boreDiameter <= 16.0 [millimeter]
        }
    }

    part serbianOakBarrel : SerbianBarrelSystem {
        attribute nominalCapacity = 50.0 [liter];
        attribute storageTemperature = 14.0 [degreeCelsius];

        satisfy PrimaryFunctionRequirement;
        satisfy SealingRequirement;
        satisfy MaturationRequirement;
        satisfy DispensingRequirement;
    }
}