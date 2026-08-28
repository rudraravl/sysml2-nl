package WordCatheterTreatmentSystem {

    import ScalarValues::*;

    package Units {
        unit mL;
        unit mmHg;
        unit day;
        unit week;
        unit mm;
        unit cm;
        unit g;
        unit mL_per_day;
        unit count;
        unit percent;

        value type Volume :> Real { unit mL; }
        value type Pressure :> Real { unit mmHg; }
        value type DurationDays :> Real { unit day; }
        value type DurationWeeks :> Real { unit week; }
        value type Length :> Real { unit mm; }
        value type Mass :> Real { unit g; }
        value type FlowRate :> Real { unit mL_per_day; }
        value type Count :> Real { unit count; }
        value type Percent :> Real { unit percent; }
    }

    import Units::*;

    package Items {
        item def SalineSolution {
            attribute concentration : Percent = 0.9;
            attribute volume : Volume;
            attribute temperature : Real;
        }

        item def AbscessFluid {
            attribute hasPus : Boolean;
            attribute hasBlood : Boolean;
            attribute viscosity : Percent;
            attribute volume : Volume;
        }

        item def DrainageOutput :> AbscessFluid {
            attribute collectionTimestamp : String;
        }
    }

    import Items::*;

    package Ports {
        port def SalineInjectionPort {
            in salineFlow : SalineSolution;
            attribute injectionPressure : Pressure;
        }

        port def DrainageFlowPort {
            out drainageFlow : DrainageOutput;
            attribute flowRate : FlowRate;
        }

        port def SalineDispensePort {
            out salineFlow : SalineSolution;
            attribute dispensePressure : Pressure;
        }

        port def DrainageInletPort {
            in drainageFlow : DrainageOutput;
            attribute accumulatedVolume : Volume;
        }

        port def AbscessInterfacePort {
            out drainageFlow : DrainageOutput;
            attribute patencyIndicator : Boolean;
        }
    }

    import Ports::*;

    package Components {

        part def InflatableBulb {
            attribute maxVolume : Volume = 3.0;
            attribute currentVolume : Volume = 0.0;
            attribute inflationPressure : Pressure;
            attribute material : String = "MedicalGradeSilicone";
            attribute isDeflated : Boolean = true;
            attribute isInflated : Boolean = false;

            port salineInPort : SalineInjectionPort;

            action inflateBulb;
            action deflateBulb;

            state BulbLifecycle {
                entry;

                state deflated;
                state inflated;

                transition from entry to deflated;
                transition from deflated to inflated when inflateBulb;
                transition from inflated to deflated when deflateBulb;
            }
        }

        part def DrainageLumen {
            attribute innerDiameter : Length = 2.0;
            attribute lumenLength : Length = 50.0;
            attribute isPatent : Boolean = true;
            attribute patencyScore : Percent = 100.0;

            port inletPort : AbscessInterfacePort;
            port outletPort : DrainageFlowPort;

            action drainFluid;
            action checkPatency;
            action flushLumen;
        }

        part def WordCatheter {
            attribute overallLength : Length = 60.0;
            attribute outerDiameter : Length = 4.0;
            attribute material : String = "MedicalGradeSilicone";
            attribute isSterile : Boolean = true;
            attribute serialNumber : String;

            attribute isInserted : Boolean = false;
            attribute isBulbInflated : Boolean = false;
            attribute isDrainingConfirmed : Boolean = false;
            attribute isEpithelialized : Boolean = false;
            attribute isBulbDeflated : Boolean = false;
            attribute isRemoved : Boolean = false;

            part inflatableBulb : InflatableBulb {
                attribute maxVolume : Volume = 3.0;
            }

            part drainageLumen : DrainageLumen {
                attribute innerDiameter : Length = 2.0;
            }

            port salineInjectionPort : SalineInjectionPort;
            port drainageOutputPort : DrainageFlowPort;

            connection inflateChannel : salineInjectionPort <-> inflatableBulb.salineInPort;
            connection drainagePath : drainageLumen.outletPort -> drainageOutputPort;

            state CatheterLifecycle {
                entry;

                state SterilePackaged;
                state InsertedUninflated;
                state InflatedAnchored;

                state DrainingAndHealing {
                    entry;

                    state Patent;
                    state Obstructed;

                    transition from entry to Patent;
                    transition from Patent to Obstructed when !drainageLumen.isPatent;
                    transition from Obstructed to Patent when drainageLumen.isPatent;
                }

                state Deflated;
                state Removed;

                transition from entry to SterilePackaged;
                transition from SterilePackaged to InsertedUninflated when isInserted;
                transition from InsertedUninflated to InflatedAnchored when isBulbInflated;
                transition from InflatedAnchored to DrainingAndHealing when isDrainingConfirmed;
                transition from DrainingAndHealing to Deflated when isEpithelialized;
                transition from Deflated to Removed when isRemoved;
            }
        }

        part def InflationSyringe {
            attribute capacity : Volume = 10.0;
            attribute currentFill : Volume = 0.0;
            attribute plungerPosition : Percent = 0.0;

            port dispensingPort : SalineDispensePort;

            action fillSyringe;
            action injectSaline;
        }

        part def CollectionReservoir {
            attribute capacity : Volume = 250.0;
            attribute currentVolume : Volume = 0.0;
            attribute isSealed : Boolean = true;
            attribute materialType : String = "MedicalGradePlastic";
            attribute emptyingInterval : DurationDays = 1.0;

            port inletPort : DrainageInletPort;

            action collectDrainage;
            action emptyReservoir;
        }

        part def TreatmentSite {
            attribute location : String = "Vestibule";
            attribute incisionSize : Length = 5.0;
            attribute hasAbscess : Boolean = true;
            attribute healingProgress : Percent = 0.0;
            attribute tractDiameter : Length = 0.0;

            port abscessPort : AbscessInterfacePort;
        }

        actor def HealthcareProfessional {
            attribute role : String;
            attribute licenseNumber : String;

            action makeIncision;
            action insertCatheter;
            action inflateBulb;
            action monitorPatency;
            action flushIfObstructed;
            action deflateBulb;
            action removeCatheter;
            action assessHealing;
        }

        actor def Patient {
            attribute hasBartholinGlandCyst : Boolean = true;
            attribute cystType : String;
            attribute hasAbscess : Boolean = true;

            part BartholinGland {
                attribute leftLobeStatus : String;
                attribute rightLobeStatus : String;
            }

            action epithelialization;
        }
    }

    import Components::*;

    package SystemIntegration {
        part WordCatheterTreatmentSystem {
            attribute systemId : String;
            attribute manufacturer : String = "MedicalDeviceCorp";
            attribute lotNumber : String;
            attribute sterilizationDate : String;
            attribute expirationDate : String;

            part catheter : WordCatheter;
            part inflationSyringe : InflationSyringe;
            part collectionReservoir : CollectionReservoir;
            part treatmentSite : TreatmentSite;

            actor clinician : HealthcareProfessional;
            actor patient : Patient;

            connection catheterInflation : inflationSyringe.dispensingPort <-> catheter.salineInjectionPort;
            connection drainageCollection : catheter.drainageOutputPort -> collectionReservoir.inletPort;
            connection catheterAbscessInterface : catheter.drainageLumen.inletPort <-> treatmentSite.abscessPort;
        }
    }

    import SystemIntegration::*;

    package Behaviors {

        action def PrepareSystemAction {
            in clinician : HealthcareProfessional;
            in system : WordCatheterTreatmentSystem;
            out prepared : Boolean;
        }

        action def MakeIncisionAction {
            in clinician : HealthcareProfessional;
            in site : TreatmentSite;
            out incisionComplete : Boolean;
        }

        action def InsertCatheterAction {
            in clinician : HealthcareProfessional;
            in catheter : WordCatheter;
            in site : TreatmentSite;
            out inserted : Boolean;
        }

        action def InflateBulbAction {
            in clinician : HealthcareProfessional;
            in syringe : InflationSyringe;
            in catheter : WordCatheter;
            out inflated : Boolean;
        }

        action def DrainageAction {
            in catheter : WordCatheter;
            in reservoir : CollectionReservoir;
            out drainedVolume : Volume;
        }

        action def MonitorPatencyAction {
            in catheter : WordCatheter;
            out isPatent : Boolean;
            out needsFlush : Boolean;
        }

        action def FlushLumenAction {
            in catheter : WordCatheter;
            out patencyRestored : Boolean;
        }

        action def EpithelializationAction {
            in patient : Patient;
            out tractFormed : Boolean;
        }

        action def DeflateBulbAction {
            in clinician : HealthcareProfessional;
            in syringe : InflationSyringe;
            in catheter : WordCatheter;
            out deflated : Boolean;
        }

        action def RemoveCatheterAction {
            in clinician : HealthcareProfessional;
            in catheter : WordCatheter;
            out removed : Boolean;
        }

        action def TreatmentProcedure {
            in clinician : HealthcareProfessional;
            in patient : Patient;
            in system : WordCatheterTreatmentSystem;

            action prepare : PrepareSystemAction;
            action incise : MakeIncisionAction;
            action insert : InsertCatheterAction;
            action inflate : InflateBulbAction;
            action drain : DrainageAction;
            action monitor : MonitorPatencyAction;
            action heal : EpithelializationAction;
            action deflate : DeflateBulbAction;
            action remove : RemoveCatheterAction;

            first prepare
            then incise
            then insert
            then inflate
            then drain
            then monitor
            then heal
            then deflate
            then remove;
        }
    }

    import Behaviors::*;

    package Requirements {

        requirement def DrainAbscessRequirement {
            doc /* The system shall enable drainage of Bartholin gland cyst or abscess fluid from the body to a collection reservoir. */
            attribute requiredDrainageRate : FlowRate = 5.0;
            attribute targetFluidType : String = "PusAndExudate";
        }

        requirement def CreatePermanentTractRequirement {
            doc /* The system shall create a permanent drainage tract through prolonged catheter presence to allow epithelialization. */
            attribute minDuration : DurationWeeks = 4.0;
            attribute targetTractDiameter : Length = 2.0;
        }

        requirement def PreventRecurrenceRequirement {
            doc /* The system shall prevent recurrence of Bartholin gland cysts or abscesses by maintaining an epithelialized drainage tract. */
            attribute maxRecurrenceRate : Percent = 5.0;
        }

        requirement def SecureCatheterRequirement {
            doc /* The inflatable bulb shall securely anchor the catheter within the abscess cavity to prevent displacement during treatment. */
            attribute minRetentionPressure : Pressure = 50.0;
            attribute bulbVolume : Volume = 3.0;
        }

        requirement def ContinuousDrainageRequirement {
            doc /* The drainage lumen shall remain patent and allow continuous fluid drainage for the duration of treatment. */
            attribute lumenInnerDiameter : Length = 2.0;
            attribute minPatencyDuration : DurationDays = 28.0;
        }

        requirement def PatencyMonitoringRequirement {
            doc /* The system shall allow for monitoring of drainage lumen patency and enable flush procedures when obstruction is detected. */
            attribute monitoringFrequency : String = "Daily";
        }

        requirement def EasyRemovalRequirement {
            doc /* After epithelialization, the bulb shall be deflatable and the catheter shall be easily removable without significant trauma. */
            attribute maxRemovalForce : Pressure = 5.0;
        }

        requirement def BiocompatibilityRequirement {
            doc /* The catheter shall be constructed of biocompatible, medical-grade silicone suitable for prolonged tissue contact. */
            attribute material : String = "MedicalGradeSilicone";
            attribute maxContactDuration : DurationWeeks = 6.0;
        }

        requirement def SterilityRequirement {
            doc /* The complete system shall be provided sterile for single-patient use. */
            attribute sterilizationMethod : String = "EthyleneOxide";
            attribute isSingleUse : Boolean = true;
        }

        requirement def InflationControlRequirement {
            doc /* The inflation syringe shall deliver controlled volume of saline to inflate the bulb to its designed anchoring volume. */
            attribute syringeCapacity : Volume = 10.0;
            attribute targetBulbVolume : Volume = 3.0;
            attribute salineConcentration : Percent = 0.9;
        }

        requirement def CollectionCapacityRequirement {
            doc /* The collection reservoir shall accommodate expected drainage volume between emptying intervals. */
            attribute minCapacity : Volume = 100.0;
            attribute isSealed : Boolean = true;
        }

        requirement def TreatmentDurationRequirement {
            doc /* The catheter shall remain in place for the duration required for complete epithelialization of the drainage tract. */
            attribute minDuration : DurationWeeks = 4.0;
            attribute maxDuration : DurationWeeks = 6.0;
        }

        requirement def AbscessDrainageCompleteRequirement {
            doc /* The treatment shall be considered complete when the abscess is fully drained and a permanent epithelialized tract has formed. */
            attribute requiredHealingProgress : Percent = 100.0;
            attribute tractDiameter : Length = 2.0;
        }

        requirement drainAbscess : DrainAbscessRequirement;
        requirement createTract : CreatePermanentTractRequirement;
        requirement preventRecurrence : PreventRecurrenceRequirement;
        requirement secureCatheter : SecureCatheterRequirement;
        requirement continuousDrainage : ContinuousDrainageRequirement;
        requirement patencyMonitoring : PatencyMonitoringRequirement;
        requirement easyRemoval : EasyRemovalRequirement;
        requirement biocompatibility : BiocompatibilityRequirement;
        requirement sterility : SterilityRequirement;
        requirement inflationControl : InflationControlRequirement;
        requirement collectionCapacity : CollectionCapacityRequirement;
        requirement treatmentDuration : TreatmentDurationRequirement;
        requirement drainageComplete : AbscessDrainageCompleteRequirement;
    }

    import Requirements::*;

    package Verifications {

        verification def VerifyDrainage {
            subject : WordCatheterTreatmentSystem;
            requirement drainAbscess : DrainAbscessRequirement;
            objective {
                doc /* Verify drainage flow rate meets requirement. */
            }
        }

        verification def VerifyRetention {
            subject : WordCatheterTreatmentSystem;
            requirement secureCatheter : SecureCatheterRequirement;
            objective {
                doc /* Verify bulb retains catheter under expected forces. */
            }
        }

        verification def VerifySterility {
            subject : WordCatheterTreatmentSystem;
            requirement sterility : SterilityRequirement;
            objective {
                doc /* Verify sterility per ISO standards. */
            }
        }

        verification def VerifyBiocompatibility {
            subject : WordCatheterTreatmentSystem;
            requirement biocompatibility : BiocompatibilityRequirement;
            objective {
                doc /* Verify material biocompatibility per ISO 10993. */
            }
        }

        verification def VerifyTreatmentDuration {
            subject : WordCatheterTreatmentSystem;
            requirement treatmentDuration : TreatmentDurationRequirement;
            objective {
                doc /* Verify catheter remains in place for required duration. */
            }
        }

        verification def VerifyPatency {
            subject : WordCatheterTreatmentSystem;
            requirement continuousDrainage : ContinuousDrainageRequirement;
            objective {
                doc /* Verify lumen patency throughout treatment. */
            }
        }

        verification def VerifyTractFormation {
            subject : WordCatheterTreatmentSystem;
            requirement createTract : CreatePermanentTractRequirement;
            objective {
                doc /* Verify tract formation and epithelialization. */
            }
        }
    }
}
