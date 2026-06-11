package SugarPackSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MassValue :> ISQ::mass {
        unit = SI::kilogram;
    }

    attribute def VolumeValue :> ISQ::volume {
        unit = SI::cubicMetre;
    }

    attribute def LengthValue :> ISQ::length {
        unit = SI::metre;
    }

    attribute def TemperatureValue :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def HumidityRatioValue {
        attribute value : Real;
        attribute unit : String = "%RH";
    }

    attribute def SealIntegrityValue {
        attribute value : Real;
        attribute unit : String = "%";
    }

    attribute def ShelfLifeValue {
        attribute value : Real;
        attribute unit : String = "day";
    }

    attribute def DispenseRateValue {
        attribute value : Real;
        attribute unit : String = "g/s";
    }

    enum def PackStateKind {
        enum sealed;
        enum opened;
        enum dispensing;
        enum closed;
        enum depleted;
        enum compromised;
    }

    enum def SugarGranuleSizeKind {
        enum fine;
        enum standard;
        enum coarse;
    }

    item def GranulatedSugar {
        attribute netMass : MassValue;
        attribute granuleSize : SugarGranuleSizeKind;
        attribute moistureContent : Real;
        attribute foodGrade : Boolean;
    }

    item def SugarPortion {
        attribute portionMass : MassValue;
        attribute flowRate : DispenseRateValue;
    }

    item def AmbientAir {
        attribute relativeHumidity : HumidityRatioValue;
        attribute temperature : TemperatureValue;
    }

    item def UserHandlingForce {
        attribute magnitude : Real;
        attribute unit : String = "N";
    }

    port def SugarOutletPort {
        out item dispensedSugar : SugarPortion;
    }

    port def FillAccessPort {
        in item bulkSugar : GranulatedSugar;
    }

    port def EnvironmentExposurePort {
        in item ambientAir : AmbientAir;
    }

    port def HandlingPort {
        in item handlingForce : UserHandlingForce;
    }

    part def SugarPack {
        attribute packState : PackStateKind = PackStateKind::sealed;
        attribute nominalCapacity : MassValue = 1.0 [SI::kilogram];
        attribute currentSugarMass : MassValue = 1.0 [SI::kilogram];
        attribute packageLength : LengthValue = 0.18 [SI::metre];
        attribute packageWidth : LengthValue = 0.09 [SI::metre];
        attribute packageHeight : LengthValue = 0.055 [SI::metre];
        attribute headspaceVolume : VolumeValue = 0.00008 [SI::cubicMetre];
        attribute maximumStorageTemperature : TemperatureValue = 303.15 [SI::kelvin];
        attribute maximumRelativeHumidity : HumidityRatioValue {
            value = 65.0;
        }
        attribute minimumSealIntegrity : SealIntegrityValue {
            value = 98.0;
        }
        attribute ratedShelfLife : ShelfLifeValue {
            value = 730.0;
        }

        port fillAccess : FillAccessPort;
        port outlet : SugarOutletPort;
        port environmentInterface : EnvironmentExposurePort;
        port handlingInterface : HandlingPort;

        part sugarInventory {
            attribute containedSugar : GranulatedSugar {
                netMass = currentSugarMass;
                granuleSize = SugarGranuleSizeKind::standard;
                moistureContent = 0.03;
                foodGrade = true;
            }
        }

        part laminateBody {
            attribute barrierLayerThickness : LengthValue = 0.00008 [SI::metre];
            attribute tearResistance : Real = 35.0;
            attribute oxygenTransmissionRate : Real = 2.0;
            attribute waterVaporTransmissionRate : Real = 1.5;
        }

        part resealableClosure {
            attribute sealIntegrity : SealIntegrityValue {
                value = 99.5;
            }
            attribute closureCyclesRemaining : Integer = 50;
            attribute tamperEvidenceIntact : Boolean = true;
        }

        part pourSpout {
            attribute apertureDiameter : LengthValue = 0.018 [SI::metre];
            attribute nominalDispenseRate : DispenseRateValue {
                value = 18.0;
            }
            port sugarExit : SugarOutletPort;
        }

        connection dispensePath connect pourSpout.sugarExit to outlet;

        action def OpenPack {
            inout pack : SugarPack;
            first start;
            then verifyTamperEvidence;
            then breakPrimarySeal;
            then exposePourSpout;
            then done;

            action verifyTamperEvidence {
                assert constraint { pack.resealableClosure.tamperEvidenceIntact == true }
            }

            action breakPrimarySeal {
                pack.resealableClosure.tamperEvidenceIntact := false;
                pack.packState := PackStateKind::opened;
            }

            action exposePourSpout {
                pack.resealableClosure.closureCyclesRemaining := pack.resealableClosure.closureCyclesRemaining - 1;
            }
        }

        action def DispenseSugar {
            inout pack : SugarPack;
            in requestedMass : MassValue;
            out deliveredPortion : SugarPortion;

            first start;
            then checkAvailability;
            then meterFlow;
            then updateInventory;
            then done;

            action checkAvailability {
                assert constraint { pack.currentSugarMass >= requestedMass }
                assert constraint { pack.packState == PackStateKind::opened or pack.packState == PackStateKind::closed }
            }

            action meterFlow {
                pack.packState := PackStateKind::dispensing;
                deliveredPortion.portionMass := requestedMass;
                deliveredPortion.flowRate := pack.pourSpout.nominalDispenseRate;
            }

            action updateInventory {
                pack.currentSugarMass := pack.currentSugarMass - requestedMass;
                if pack.currentSugarMass <= 0.0 [SI::kilogram] {
                    pack.packState := PackStateKind::depleted;
                } else {
                    pack.packState := PackStateKind::opened;
                }
            }
        }

        action def ClosePack {
            inout pack : SugarPack;

            first start;
            then engageClosure;
            then verifyClosure;
            then done;

            action engageClosure {
                pack.resealableClosure.closureCyclesRemaining := pack.resealableClosure.closureCyclesRemaining - 1;
                pack.packState := PackStateKind::closed;
            }

            action verifyClosure {
                assert constraint { pack.resealableClosure.sealIntegrity.value >= pack.minimumSealIntegrity.value }
            }
        }

        action def StorePack {
            inout pack : SugarPack;
            in ambient : AmbientAir;

            first start;
            then evaluateEnvironment;
            then preserveContents;
            then done;

            action evaluateEnvironment {
                if ambient.relativeHumidity.value > pack.maximumRelativeHumidity.value {
                    pack.packState := PackStateKind::compromised;
                }
                if ambient.temperature > pack.maximumStorageTemperature {
                    pack.packState := PackStateKind::compromised;
                }
            }

            action preserveContents {
                assert constraint { pack.laminateBody.waterVaporTransmissionRate <= 2.0 }
                assert constraint { pack.sugarInventory.containedSugar.foodGrade == true }
            }
        }

        state def SugarPackLifecycle {
            entry;
            state Sealed;
            state Opened;
            state Dispensing;
            state Closed;
            state Depleted;
            state Compromised;
            exit;

            transition initial then Sealed;

            transition open
                first Sealed
                accept OpenCommand
                do OpenPack
                then Opened;

            transition dispenseFromOpened
                first Opened
                accept DispenseCommand
                do DispenseSugar
                then Dispensing;

            transition finishDispense
                first Dispensing
                if currentSugarMass > 0.0 [SI::kilogram]
                then Opened;

            transition finishDepleted
                first Dispensing
                if currentSugarMass <= 0.0 [SI::kilogram]
                then Depleted;

            transition close
                first Opened
                accept CloseCommand
                do ClosePack
                then Closed;

            transition reopen
                first Closed
                accept OpenCommand
                do OpenPack
                then Opened;

            transition humidityFailure
                first Sealed
                accept ExcessHumidityEvent
                then Compromised;

            transition thermalFailure
                first Closed
                accept ExcessTemperatureEvent
                then Compromised;
        }
    }

    part def SugarPackUseContext {
        part consumer {
            port handInterface : HandlingPort;
        }

        part storageEnvironment {
            attribute typicalHumidity : HumidityRatioValue {
                value = 45.0;
            }
            attribute typicalTemperature : TemperatureValue = 294.15 [SI::kelvin];
            port airInterface : EnvironmentExposurePort;
        }

        part system : SugarPack;

        connection userHandling connect consumer.handInterface to system.handlingInterface;
        connection ambientExposure connect storageEnvironment.airInterface to system.environmentInterface;
    }

    requirement def PrimaryFunctionRequirement {
        doc
        /*
         * The SugarPack shall contain, protect, and dispense granulated sugar for consumer use.
         */
        subject sugarPack : SugarPack;
        require constraint {
            sugarPack.nominalCapacity >= 1.0 [SI::kilogram] and
            sugarPack.minimumSealIntegrity.value >= 98.0 and
            sugarPack.ratedShelfLife.value >= 730.0
        }
    }

    requirement def FoodProtectionRequirement {
        doc
        /*
         * The SugarPack shall preserve food-grade sugar by limiting moisture ingress during storage.
         */
        subject sugarPack : SugarPack;
        require constraint {
            sugarPack.laminateBody.waterVaporTransmissionRate <= 2.0 and
            sugarPack.maximumRelativeHumidity.value <= 65.0 and
            sugarPack.sugarInventory.containedSugar.foodGrade == true
        }
    }

    requirement def DispensingRequirement {
        doc
        /*
         * The SugarPack shall provide controlled dispensing of sugar through an integrated pour spout.
         */
        subject sugarPack : SugarPack;
        require constraint {
            sugarPack.pourSpout.apertureDiameter >= 0.012 [SI::metre] and
            sugarPack.pourSpout.apertureDiameter <= 0.025 [SI::metre] and
            sugarPack.pourSpout.nominalDispenseRate.value >= 10.0 and
            sugarPack.pourSpout.nominalDispenseRate.value <= 25.0
        }
    }

    requirement def ResealRequirement {
        doc
        /*
         * The SugarPack shall be resealable after opening to reduce contamination and moisture exposure.
         */
        subject sugarPack : SugarPack;
        require constraint {
            sugarPack.resealableClosure.closureCyclesRemaining >= 50 and
            sugarPack.resealableClosure.sealIntegrity.value >= sugarPack.minimumSealIntegrity.value
        }
    }

    requirement def TamperEvidenceRequirement {
        doc
        /*
         * The SugarPack shall indicate whether its primary seal has been opened before first use.
         */
        subject sugarPack : SugarPack;
        require constraint {
            sugarPack.resealableClosure.tamperEvidenceIntact == true
        }
    }

    satisfy PrimaryFunctionRequirement by SugarPack;
    satisfy FoodProtectionRequirement by SugarPack::laminateBody;
    satisfy DispensingRequirement by SugarPack::pourSpout;
    satisfy ResealRequirement by SugarPack::resealableClosure;
    satisfy TamperEvidenceRequirement by SugarPack::resealableClosure;

    use case def PrimarySugarPackFunction {
        subject pack : SugarPack;
        objective
        /*
         * Provide a consumer package that stores granulated sugar, protects it from normal environmental exposure,
         * allows the consumer to open the pack, dispense a desired portion, and reseal the pack for later use.
         */

        include use case StoreSugar;
        include use case OpenForUse;
        include use case DispensePortion;
        include use case ResealAfterUse;
    }

    use case def StoreSugar {
        subject pack : SugarPack;
        actor environment : AmbientAir;
    }

    use case def OpenForUse {
        subject pack : SugarPack;
        actor consumerForce : UserHandlingForce;
    }

    use case def DispensePortion {
        subject pack : SugarPack;
        actor consumerForce : UserHandlingForce;
    }

    use case def ResealAfterUse {
        subject pack : SugarPack;
        actor consumerForce : UserHandlingForce;
    }

    part sugarPackSystem : SugarPackUseContext {
        system.currentSugarMass = 1.0 [SI::kilogram];
        system.packState = PackStateKind::sealed;
    }
}