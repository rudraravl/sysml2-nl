package WordCatheterSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def PressureValue :> Real;
    attribute def VolumeValue :> Real;
    attribute def FlowRateValue :> Real;

    item def SalineSolution;
    item def Exudate;
    item def PurulentFluid;

    enum def CatheterState {
        uninflated;
        inflating;
        inflated;
        draining;
        deflating;
        removed;
    }

    enum def DrainageStatus {
        patent;
        partial;
        obstructed;
    }

    port def FluidPort {
        out item saline : SalineSolution;
        in item drainage : Exudate;
    }

    port def InflationPort {
        in item saline : SalineSolution;
    }

    port def DrainagePort {
        out item exudate : Exudate;
    }

    part def InflatableBulb {
        attribute volume : VolumeValue;
        attribute pressure : PressureValue;
        attribute maxVolume : VolumeValue;
        port inflationPort : InflationPort;
    }

    part def DrainageLumen {
        attribute innerDiameter : LengthValue;
        attribute length : LengthValue;
        attribute flowRate : FlowRateValue;
        port inletPort : DrainagePort;
        port outletPort : DrainagePort;
    }

    part def CatheterTube {
        attribute outerDiameter : LengthValue;
        attribute length : LengthValue;
        attribute material : String;
        port proximalEnd;
        port distalEnd;
    }

    part def WordCatheter {
        attribute overallLength : LengthValue;
        attribute state : CatheterState;
        attribute drainageStatus : DrainageStatus;

        part tube : CatheterTube {
            attribute :>> outerDiameter = 3.5;
            attribute :>> length = 50.0;
            attribute :>> material = "Medical Grade Silicone";
        }

        part bulb : InflatableBulb {
            attribute :>> volume = 0.0;
            attribute :>> pressure = 0.0;
            attribute :>> maxVolume = 5.0;
        }

        part drainageLumen : DrainageLumen {
            attribute :>> innerDiameter = 2.5;
            attribute :>> length = tube.length;
            attribute :>> flowRate = 0.0;
        }

        port inflationAccess : InflationPort;
        port drainageAccess : DrainagePort;

        connection bulbInflation connect inflationAccess to bulb.inflationPort;
        connection drainageFlow connect drainageLumen.outletPort to drainageAccess;
    }

    part def AbscessCavity {
        attribute volume : VolumeValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        port drainagePoint : DrainagePort;
        item purulentContent : PurulentFluid;
    }

    part def InflationSyringe {
        attribute capacity : VolumeValue;
        attribute currentVolume : VolumeValue;
        port tip : FluidPort;
        item saline : SalineSolution;
    }

    part def CollectionReservoir {
        attribute capacity : VolumeValue;
        attribute collectedVolume : VolumeValue;
        port inlet : DrainagePort;
    }

    action def PrepareCatheter {
        in catheter : WordCatheter;
        out sterileCatheter : WordCatheter;
    }

    action def CreateIncision {
        in site : AbscessCavity;
        out incisedSite : AbscessCavity;
    }

    action def InsertCatheter {
        in catheter : WordCatheter;
        in site : AbscessCavity;
        out insertedCatheter : WordCatheter;
    }

    action def InflateBulb {
        in catheter : WordCatheter;
        in syringe : InflationSyringe;
        in targetVolume : VolumeValue;
        out securedCatheter : WordCatheter;
    }

    action def MonitorDrainage {
        in catheter : WordCatheter;
        in collector : CollectionReservoir;
        out drainageRate : FlowRateValue;
        out status : DrainageStatus;
    }

    action def AssessEpithelialization {
        in site : AbscessCavity;
        in treatmentDuration : TimeValue;
        out tractFormed : Boolean;
    }

    action def DeflateBulb {
        in catheter : WordCatheter;
        out deflatedCatheter : WordCatheter;
    }

    action def RemoveCatheter {
        in catheter : WordCatheter;
        out removedCatheter : WordCatheter;
    }

    action def PerformWordCatheterTreatment {
        first start;

        then action prepare : PrepareCatheter;

        then action incise : CreateIncision;

        then action insert : InsertCatheter {
            in catheter = prepare.sterileCatheter;
            in site = incise.incisedSite;
        }

        then action inflate : InflateBulb {
            in catheter = insert.insertedCatheter;
            in targetVolume = 3.0;
        }

        then merge continueTreatment;

        then action monitor : MonitorDrainage {
            in catheter = inflate.securedCatheter;
        }

        then action assess : AssessEpithelialization;

        then decide;
            if assess.tractFormed then deflate;
            if !assess.tractFormed then continueTreatment;

        action deflate : DeflateBulb;

        then action remove : RemoveCatheter {
            in catheter = deflate.deflatedCatheter;
        }

        then done;
    }

    state def WordCatheterLifecycle {
        entry; then prepared;

        state prepared;
        state inserted;
        state inflated;
        state draining;
        state evaluating;
        state obstructed;
        state deflated;
        state removed;

        transition prepared_to_inserted
            first prepared
            accept InsertionEvent
            then inserted;

        transition inserted_to_inflated
            first inserted
            accept InflationEvent
            then inflated;

        transition inflated_to_draining
            first inflated
            then draining;

        transition draining_to_evaluating
            first draining
            accept PatencyCheckEvent
            then evaluating;

        transition evaluating_to_draining
            first evaluating
            then draining;

        transition evaluating_to_obstructed
            first evaluating
            then obstructed;

        transition obstructed_to_draining
            first obstructed
            accept ClearanceEvent
            then draining;

        transition draining_to_deflated
            first draining
            accept DeflationEvent
            then deflated;

        transition deflated_to_removed
            first deflated
            accept RemovalEvent
            then removed;
    }

    requirement def StakeholderRequirement;
    requirement def SystemRequirement;

    requirement <'REQ-WC-001'> primaryFunction : StakeholderRequirement {
        doc /* The Word catheter system shall provide continuous drainage 
             * of a Bartholin gland cyst or abscess while maintaining an 
             * open tract to promote epithelialization and prevent recurrence.
            */
        subject system : WordCatheterTreatmentSystem;
    }

    requirement <'REQ-WC-002'> retentionCapability : StakeholderRequirement {
        doc /* The catheter shall remain securely anchored within the 
             * abscess cavity through an inflatable bulb mechanism for 
             * the duration of treatment.
            */
        subject catheter : WordCatheter;
    }

    requirement <'REQ-WC-003'> treatmentDuration : StakeholderRequirement {
        doc /* The catheter shall maintain patency and drainage for a 
             * minimum of 4 weeks to allow complete tract formation.
            */
        subject system : WordCatheterTreatmentSystem;
    }

    requirement <'REQ-WC-101'> bulbInflationVolume : SystemRequirement {
        subject bulb :>> WordCatheter::bulb;
        assert constraint {
            bulb.volume >= 2.0 and bulb.volume <= 5.0
        }
    }

    requirement <'REQ-WC-102'> bulbInflationPressure : SystemRequirement {
        subject bulb :>> WordCatheter::bulb;
        assert constraint {
            bulb.pressure >= 8.0 and bulb.pressure <= 20.0
        }
    }

    requirement <'REQ-WC-103'> catheterDiameter : SystemRequirement {
        subject tube :>> WordCatheter::tube;
        assert constraint {
            tube.outerDiameter >= 3.0 and tube.outerDiameter <= 4.0
        }
    }

    requirement <'REQ-WC-104'> drainagePatency : SystemRequirement {
        subject lumen :>> WordCatheter::drainageLumen;
        assert constraint {
            lumen.flowRate > 0.0
        }
    }

    requirement <'REQ-WC-105'> biocompatibility : SystemRequirement {
        subject tube :>> WordCatheter::tube;
        doc /* All catheter materials in contact with tissue shall be 
             * medical-grade silicone to ensure biocompatibility and 
             * minimize inflammatory response.
            */
    }

    part def WordCatheterTreatmentSystem {
        part catheter : WordCatheter;
        part abscessSite : AbscessCavity;
        part inflationDevice : InflationSyringe;
        part drainageCollector : CollectionReservoir;
    }

    part wordCatheterTreatmentSystem : WordCatheterTreatmentSystem {
        part :>> catheter {
            attribute :>> overallLength = 50.0;
            attribute :>> state = CatheterState::uninflated;
            attribute :>> drainageStatus = DrainageStatus::patent;
        }

        part :>> abscessSite {
            attribute :>> volume = 20.0;
            attribute :>> pressure = 5.0;
            attribute :>> temperature = 37.5;
        }

        part :>> inflationDevice {
            attribute :>> capacity = 10.0;
            attribute :>> currentVolume = 10.0;
        }

        part :>> drainageCollector {
            attribute :>> capacity = 100.0;
            attribute :>> collectedVolume = 0.0;
        }

        connection inflationConnection
            connect inflationDevice.tip to catheter.inflationAccess;

        connection abscessDrainage
            connect abscessSite.drainagePoint to catheter.drainageLumen.inletPort;

        connection collectionConnection
            connect catheter.drainageAccess to drainageCollector.inlet;

        perform action treatment : PerformWordCatheterTreatment;
    }

    satisfy primaryFunction by wordCatheterTreatmentSystem;
    satisfy retentionCapability by wordCatheterTreatmentSystem.catheter;
    satisfy treatmentDuration by wordCatheterTreatmentSystem;
    satisfy bulbInflationVolume by wordCatheterTreatmentSystem.catheter.bulb;
    satisfy bulbInflationPressure by wordCatheterTreatmentSystem.catheter.bulb;
    satisfy catheterDiameter by wordCatheterTreatmentSystem.catheter.tube;
    satisfy drainagePatency by wordCatheterTreatmentSystem.catheter.drainageLumen;
    satisfy biocompatibility by wordCatheterTreatmentSystem.catheter.tube;
}
