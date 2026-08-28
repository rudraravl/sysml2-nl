package OstomyCareSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import Time::*;

    attribute def VolumeValue :> ISQ::volume;
    attribute def DurationValue :> Time::Duration;

    attribute def AttachSignal;
    attribute def DetachSignal;
    attribute def LeakSignal;
    attribute def CapacityAlertSignal;
    attribute def FilterSaturatedSignal;
    attribute def WearTimeExpiredSignal;
    attribute def ClearAlertSignal;

    item def Effluent {
        attribute volume : VolumeValue;
    }
    item def Gas {
        attribute volume : VolumeValue;
        attribute odorIntensity : Real;
    }
    item def FilteredGas {
        attribute volume : VolumeValue;
        attribute odorIntensity : Real;
    }
    item def Moisture {
        attribute level : Real;
    }

    port def EffluentFlowPort {
        in item effluent : Effluent;
    }
    port def GasFlowPort {
        in item gas : Gas;
        out item filteredGas : FilteredGas;
    }
    port def MoistureSignalPort {
        in item moisture : Moisture;
    }
    port def SignalPort;
    port def AlertPort {
        out visualSignal : Boolean;
        out auditorySignal : Boolean;
        out alertText : String;
    }

    action def CollectEffluent {
        in item effluent : Effluent;
        out currentVolume : VolumeValue;
    }
    action def ReleaseGas {
        in item gas : Gas;
        out item filteredGas : FilteredGas;
    }
    action def NeutralizeOdor {
        in item gasWithOdor : Gas;
        out item neutralizedGas : FilteredGas;
    }
    action def DetectLeakage {
        in moistureLevel : Real;
        in adhesionLevel : Real;
        out leakDetected : Boolean;
    }
    action def MonitorFillLevel {
        in currentVolume : VolumeValue;
        in maxVolume : VolumeValue;
        out nearCapacity : Boolean;
    }
    action def MonitorFilterStatus {
        in saturation : Real;
        in threshold : Real;
        out saturated : Boolean;
    }
    action def MonitorWearTime {
        in elapsed : DurationValue;
        in maxWear : DurationValue;
        out expired : Boolean;
    }
    action def IssueAlert {
        in alertType : String;
    }
    action def ClearAlerts;
    action def MaintainSeal;
    action def ProvideComfort;

    part def SkinBarrier {
        port effluentOut : EffluentFlowPort;
        port moistureOut : MoistureSignalPort;
        attribute adhesionLevel : Real;
        attribute adhesionThreshold : Real = 0.3;
        attribute moistureLevel : Real;
        attribute moistureThreshold : Real = 0.1;
        perform action maintainSeal : MaintainSeal;
    }

    part def CollectionPouch {
        port effluentIn : EffluentFlowPort;
        port gasOut : GasFlowPort;
        port capacityOut : SignalPort;
        attribute currentVolume : VolumeValue;
        attribute maxVolume : VolumeValue = 500.0 [mL];
        attribute nearCapacityThreshold : VolumeValue = 0.8 * maxVolume;
        perform action collectEffluent : CollectEffluent;
    }

    part def CharcoalFilter {
        port gasIn : GasFlowPort;
        port filteredGasOut : GasFlowPort;
        port filterStatusOut : SignalPort;
        attribute saturationLevel : Real;
        attribute saturationThreshold : Real = 0.85;
        perform action releaseGas : ReleaseGas;
        perform action neutralizeOdor : NeutralizeOdor;
    }

    part def ComfortLayer {
        attribute breathability : Real;
        perform action provideComfort : ProvideComfort;
    }

    part def LeakageDetectionSensor {
        port moistureIn : MoistureSignalPort;
        port leakOut : SignalPort;
        perform action detectLeakage : DetectLeakage;
    }

    part def AlertModule {
        port leakIn : SignalPort;
        port capacityIn : SignalPort;
        port filterStatusIn : SignalPort;
        port wearTimeIn : SignalPort;
        port alertOut : AlertPort;
        perform action issueAlert : IssueAlert;
        perform action clearAlerts : ClearAlerts;
    }

    part def User {
        port alertReceptionPort : AlertPort;
    }

    part def OstomySystem {
        part skinBarrier : SkinBarrier;
        part collectionPouch : CollectionPouch;
        part charcoalFilter : CharcoalFilter;
        part comfortLayer : ComfortLayer;
        part leakageSensor : LeakageDetectionSensor;
        part alertModule : AlertModule;
        part user : User;

        attribute wearTimeElapsed : DurationValue;
        attribute maxWearTime : DurationValue = 168.0 [h];

        action 'collect effluent' : CollectEffluent;
        action 'release gas' : ReleaseGas;
        action 'neutralize odor' : NeutralizeOdor;
        action 'detect leakage' : DetectLeakage;
        action 'monitor fill level' : MonitorFillLevel;
        action 'monitor filter status' : MonitorFilterStatus;
        action 'monitor wear time' : MonitorWearTime;
        action 'issue alert' : IssueAlert;

        exhibit state systemStates;

        connection effluentFlow connect skinBarrier.effluentOut to collectionPouch.effluentIn;
        connection gasFlow connect collectionPouch.gasOut to charcoalFilter.gasIn;
        connection filteredGasFlow connect charcoalFilter.filteredGasOut to charcoalFilter.gasIn;
        connection moistureFlow connect skinBarrier.moistureOut to leakageSensor.moistureIn;
        connection leakSignal connect leakageSensor.leakOut to alertModule.leakIn;
        connection capacitySignal connect collectionPouch.capacityOut to alertModule.capacityIn;
        connection filterSignal connect charcoalFilter.filterStatusOut to alertModule.filterStatusIn;
        connection alertDelivery connect alertModule.alertOut to user.alertReceptionPort;
    }

    state def SystemStates {
        entry; then unattached;
        state unattached;
        transition unattached_to_attached
            first unattached
            accept AttachSignal
            then attached;
        state attached {
            do MaintainSeal;
        }
        transition attached_to_collecting
            first attached
            then collecting;
        state collecting {
            do 'collect effluent';
            do 'release gas';
            do 'neutralize odor';
            do 'detect leakage';
            do 'monitor fill level';
            do 'monitor filter status';
            do 'monitor wear time';
        }
        transition collecting_to_nearCapacity
            first collecting
            accept when 'monitor fill level'.nearCapacity
            do send new CapacityAlertSignal() to alertModule
            then nearCapacity;
        transition collecting_to_compromised
            first collecting
            accept when 'detect leakage'.leakDetected
            do send new LeakSignal() to alertModule
            then compromised;
        transition collecting_to_compromised_filter
            first collecting
            accept when 'monitor filter status'.saturated
            do send new FilterSaturatedSignal() to alertModule
            then compromised;
        transition collecting_to_compromised_wear
            first collecting
            accept when 'monitor wear time'.expired
            do send new WearTimeExpiredSignal() to alertModule
            then compromised;
        state nearCapacity {
            do 'issue alert';
        }
        transition nearCapacity_to_collecting
            first nearCapacity
            accept ClearAlertSignal
            do ClearAlerts
            then collecting;
        transition nearCapacity_to_compromised
            first nearCapacity
            accept when 'detect leakage'.leakDetected
            do send new LeakSignal() to alertModule
            then compromised;
        state compromised {
            entry 'issue alert';
        }
        transition compromised_to_unattached
            first compromised
            accept DetachSignal
            then unattached;
    }

    requirement def SealIntegrityRequirement {
        doc /* The Skin Barrier shall maintain adhesion above threshold and moisture below threshold during wear. */
        subject skinBarrier : SkinBarrier;
        assert constraint {
            skinBarrier.adhesionLevel >= skinBarrier.adhesionThreshold and
            skinBarrier.moistureLevel <= skinBarrier.moistureThreshold
        }
    }

    requirement def OdorControlRequirement {
        doc /* The Charcoal Filter shall neutralize odor from released gas to prevent discomfort. */
        subject charcoalFilter : CharcoalFilter;
    }

    requirement def LeakageDetectionRequirement {
        doc /* The system shall detect moisture or loss of adhesion and alert the user promptly. */
        subject leakageSensor : LeakageDetectionSensor;
    }

    requirement def CapacityManagementRequirement {
        doc /* The system shall alert the user when pouch volume reaches 80% of maximum capacity. */
        subject collectionPouch : CollectionPouch;
        assert constraint {
            collectionPouch.nearCapacityThreshold >= 0.8 * collectionPouch.maxVolume
        }
    }

    requirement def WearTimeRequirement {
        doc /* The system shall alert the user when the recommended wear time has expired. */
        subject ostomySystem : OstomySystem;
        assert constraint {
            ostomySystem.maxWearTime <= 168.0 [h]
        }
    }

    part ostomySystem : OstomySystem;

    state systemStates : SystemStates {
        ref sys : OstomySystem = ostomySystem;
    }

    requirement sealIntegrity : SealIntegrityRequirement {
        subject skinBarrier = ostomySystem.skinBarrier;
    }
    requirement odorControl : OdorControlRequirement {
        subject charcoalFilter = ostomySystem.charcoalFilter;
    }
    requirement leakageDetection : LeakageDetectionRequirement {
        subject leakageSensor = ostomySystem.leakageSensor;
    }
    requirement capacityManagement : CapacityManagementRequirement {
        subject collectionPouch = ostomySystem.collectionPouch;
    }
    requirement wearTime : WearTimeRequirement {
        subject ostomySystem = ostomySystem;
    }
}
