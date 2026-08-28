package IntelligentOstomyCareSystem {

    import SI::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type VolumeValue :> Real {
        doc /* Volume measured in milliliters */
        unit :> 'mL';
    }

    value type PressureValue :> Real {
        doc /* Pressure measured in Pascals */
        unit :> 'Pa';
    }

    value type AreaValue :> Real {
        doc /* Area measured in square centimeters */
        unit :> 'cm^2';
    }

    value type LengthValue :> Real {
        doc /* Length measured in millimeters */
        unit :> 'mm';
    }

    value type TimeDurationHours :> Real {
        doc /* Time duration measured in hours */
        unit :> 'h';
    }

    value type TemperatureValue :> Real {
        doc /* Temperature in degrees Celsius */
        unit :> 'degC';
    }

    value type AdhesionStrength :> Real {
        doc /* Adhesion force per unit area in newtons per square centimeter */
        unit :> 'N/cm^2';
    }

    value type MoistureLevel :> Real {
        doc /* Moisture detection level from 0.0 (dry) to 1.0 (saturated) */
    }

    value type SaturationPercentage :> Real {
        doc /* Saturation level from 0.0 to 100.0 percent */
    }

    value type FillPercentage :> Real {
        doc /* Fill level from 0.0 to 100.0 percent */
    }

    value type BatteryLevel :> Real {
        doc /* Battery charge from 0.0 to 100.0 percent */
    }

    // ===== Enumerations =====

    enum def SystemStateKind {
        unattached;
        attached;
        collecting;
        nearCapacity;
        compromised;
    }

    enum def AlertKind {
        none;
        leakDetected;
        pouchNearCapacity;
        filterSaturated;
        wearTimeExpired;
        lowBattery;
    }

    enum def AlertMode {
        silent;
        visual;
        auditory;
        visualAndAuditory;
    }

    enum def FilterStatus {
        active;
        saturated;
    }

    // ===== Item Definitions =====

    item def Effluent {
        attribute pH : Real;
        attribute viscosity : Real;
    }

    item def LiquidEffluent :> Effluent {
        attribute volume : VolumeValue;
    }

    item def SolidEffluent :> Effluent {
        attribute mass : Real;
    }

    item def Gas {
        attribute pressure : PressureValue;
        attribute odorConcentration : Real;
    }

    item def OdorousGas :> Gas {
        attribute odorConcentration : Real;
    }

    item def FilteredGas :> Gas {
        attribute odorConcentration : Real := 0.0;
    }

    item def SensorSignal {
        attribute alertKind : AlertKind;
        attribute severity : Real;
        attribute timestamp : TimeDurationHours;
    }

    // ===== Port Definitions =====

    port def StomaInterfacePort {
        out item effluentFlow : Effluent;
        out item gasFlow : Gas;
        attribute skinContactArea : AreaValue;
        attribute skinTemperature : TemperatureValue;
    }

    port def BarrierPouchInterfacePort {
        in item effluentPassage : Effluent;
        in item gasPassage : Gas;
        attribute sealIntegrity : Boolean;
    }

    port def GasExhaustPort {
        in item incomingGas : OdorousGas;
        out item filteredGas : FilteredGas;
    }

    port def SensorOutputPort {
        out item sensorSignal : SensorSignal;
    }

    port def AlertInputPort {
        in item alertSignal : SensorSignal;
    }

    port def AlertOutputPort {
        attribute alertKind : AlertKind;
        attribute alertMode : AlertMode;
        attribute active : Boolean;
    }

    // ===== Interface Definitions =====

    interface def StomaToBarrierInterface {
        end stomaSide : StomaInterfacePort;
        end barrierSide : ~StomaInterfacePort;
    }

    interface def BarrierToPouchInterface {
        end barrierSide : BarrierPouchInterfacePort;
        end pouchSide : ~BarrierPouchInterfacePort;
    }

    interface def PouchToFilterInterface {
        end pouchSide : GasExhaustPort;
        end filterSide : ~GasExhaustPort;
    }

    interface def SensorToAlertInterface {
        end sensorSide : SensorOutputPort;
        end alertSide : AlertInputPort;
    }

    // ===== Action Definitions =====

    action def ApplyBarrierAction {
        in barrier : SkinBarrier;
        in stomaContactArea : AreaValue;
        out adhesionAchieved : Boolean;
    }

    action def AttachPouchAction {
        in barrier : SkinBarrier;
        in pouch : CollectionPouch;
        out attachmentComplete : Boolean;
    }

    action def CollectEffluentAction {
        in effluent : Effluent;
        in pouch : CollectionPouch;
        out fillUpdated : FillPercentage;
    }

    action def FilterGasAction {
        in odorousGas : OdorousGas;
        in filter : CharcoalFilter;
        out filteredGas : FilteredGas;
    }

    action def DetectLeakageAction {
        in moistureReading : MoistureLevel;
        in adhesionReading : AdhesionStrength;
        out leakDetected : Boolean;
        out signal : SensorSignal;
    }

    action def TriggerAlertAction {
        in alertKind : AlertKind;
        in alertModule : AlertModule;
        out alertActivated : Boolean;
    }

    action def EmptyPouchAction {
        in pouch : CollectionPouch;
        out emptyComplete : Boolean;
    }

    // ===== Part Definitions =====

    part def SkinBarrier {
        doc /* Adhesive plate that adheres to the peristomal skin creating a secure seal */
        attribute adhesionStrength : AdhesionStrength := 12.0;
        attribute barrierDiameter : LengthValue := 45.0;
        attribute skinContactArea : AreaValue := 15.9;
        attribute maxWearTime : TimeDurationHours := 72.0;
        attribute currentWearTime : TimeDurationHours := 0.0;
        attribute sealIntact : Boolean := true;
        attribute adhesiveIntegrityThreshold : AdhesionStrength := 5.0;
        attribute barrierMaterial : String := "hydrocolloid";

        port stomaPort : StomaInterfacePort;
        port pouchPort : BarrierPouchInterfacePort;

        action applyBarrier : ApplyBarrierAction {
            in barrier = Self;
            out adhesionAchieved = Self.sealIntact;
        }

        action removeBarrier {
            attribute sealIntact := false;
        }

        action updateWearTime {
            attribute currentWearTime := currentWearTime + 1.0;
        }

        state def barrierState {
            entry;
            state unattached {
                entry;
            }
            state attached {
                entry;
                transition to compromised when sealIntact == false;
            }
            state compromised {
                entry;
            }
            transition from unattached to attached when sealIntact == true;
            transition from attached to unattached when sealIntact == false and currentWearTime == 0.0;
        }
    }

    part def CollectionPouch {
        doc /* Receptacle that attaches to the skin barrier to collect effluent */
        attribute maxVolume : VolumeValue := 500.0;
        attribute currentVolume : VolumeValue := 0.0;
        attribute fillPercentage : FillPercentage := 0.0;
        attribute nearCapacityThreshold : FillPercentage := 75.0;
        attribute fullThreshold : FillPercentage := 100.0;
        attribute pouchMaterial : String := "odor-barrier film";

        port barrierPort : ~BarrierPouchInterfacePort;
        port filterPort : GasExhaustPort;

        action collectEffluent : CollectEffluentAction {
            in effluent : Effluent;
            in pouch = Self;
            out fillUpdated = fillPercentage;
        }

        action emptyPouch : EmptyPouchAction {
            in pouch = Self;
            attribute currentVolume := 0.0;
            attribute fillPercentage := 0.0;
        }

        action updateFillLevel {
            attribute fillPercentage := (currentVolume / maxVolume) * 100.0;
        }

        state def pouchFillState {
            entry;
            state empty;
            state filling;
            state nearCapacity;
            state full;
            transition from empty to filling when currentVolume > 0.0;
            transition from filling to nearCapacity when fillPercentage >= nearCapacityThreshold;
            transition from nearCapacity to full when fillPercentage >= fullThreshold;
            transition from full to empty when currentVolume == 0.0;
            transition from nearCapacity to empty when currentVolume == 0.0;
        }
    }

    part def CharcoalFilter {
        doc /* Integrated charcoal filter that releases gas while neutralizing odor */
        attribute saturationThreshold : SaturationPercentage := 100.0;
        attribute currentSaturation : SaturationPercentage := 0.0;
        attribute filterCapacity : VolumeValue := 200.0;
        attribute gasProcessed : VolumeValue := 0.0;
        attribute filterStatus : FilterStatus := FilterStatus::active;
        attribute charcoalLayerCount : Integer := 3;

        port gasInPort : ~GasExhaustPort;
        port gasOutPort : GasExhaustPort;

        action filterGas : FilterGasAction {
            in odorousGas : OdorousGas;
            in filter = Self;
            attribute gasProcessed := gasProcessed + 1.0;
            attribute currentSaturation := (gasProcessed / filterCapacity) * 100.0;
            attribute filterStatus := if currentSaturation >= saturationThreshold then FilterStatus::saturated else FilterStatus::active endif;
            out filteredGas : FilteredGas;
        }

        state def filterState {
            entry;
            state active;
            state saturated;
            transition from active to saturated when currentSaturation >= saturationThreshold;
        }
    }

    part def ComfortLayer {
        doc /* Soft breathable covering that rests against skin or clothing for patient comfort */
        attribute material : String := "breathable non-woven fabric";
        attribute thickness : LengthValue := 2.5;
        attribute breathabilityRating : Real := 0.85;
        attribute softnessRating : Real := 0.90;
        attribute moistureWicking : Boolean := true;
        attribute thermalRegulation : Boolean := true;
    }

    part def LeakageDetectionSensor {
        doc /* Electronic sensor that monitors seal integrity and detects moisture indicating leakage */
        attribute sensitivity : Real := 0.92;
        attribute moistureThreshold : MoistureLevel := 0.15;
        attribute currentMoistureLevel : MoistureLevel := 0.0;
        attribute adhesionThreshold : AdhesionStrength := 5.0;
        attribute currentAdhesionReading : AdhesionStrength := 12.0;
        attribute isLeakDetected : Boolean := false;
        attribute batteryLevel : BatteryLevel := 100.0;
        attribute samplingInterval : TimeDurationHours := 0.083;
        attribute sensorActive : Boolean := false;

        port sensorPort : SensorOutputPort;

        action detectLeakage : DetectLeakageAction {
            in moistureReading : MoistureLevel := currentMoistureLevel;
            in adhesionReading : AdhesionStrength := currentAdhesionReading;
            attribute isLeakDetected := if (currentMoistureLevel >= moistureThreshold) or (currentAdhesionReading < adhesionThreshold) then true else false endif;
            out leakDetected = isLeakDetected;
            out signal : SensorSignal {
                attribute alertKind := if isLeakDetected then AlertKind::leakDetected else AlertKind::none endif;
                attribute severity := if currentMoistureLevel >= moistureThreshold then 0.9 else 0.0 endif;
            }
        }

        action monitorSeal {
            attribute sensorActive := true;
            perform detectLeakage;
        }

        action updateBattery {
            attribute batteryLevel := batteryLevel - 0.5;
        }

        state def sensorState {
            entry;
            state dormant;
            state monitoring;
            state alarmTriggered;
            transition from dormant to monitoring when sensorActive == true;
            transition from monitoring to alarmTriggered when isLeakDetected == true;
            transition from alarmTriggered to monitoring when isLeakDetected == false;
            transition from monitoring to dormant when sensorActive == false;
        }
    }

    part def AlertModule {
        doc /* Electronic module that receives sensor signals and notifies the user through visual or auditory signals */
        attribute volumeLevel : Real := 0.7;
        attribute vibrationEnabled : Boolean := true;
        attribute visualIndicatorColor : String := "green";
        attribute currentAlertKind : AlertKind := AlertKind::none;
        attribute currentAlertMode : AlertMode := AlertMode::silent;
        attribute alertActive : Boolean := false;
        attribute batteryLevel : BatteryLevel := 100.0;
        attribute lowBatteryThreshold : BatteryLevel := 15.0;

        port inputPort : AlertInputPort;
        port outputPort : AlertOutputPort;

        action triggerAlert : TriggerAlertAction {
            in alertKind : AlertKind;
            in alertModule = Self;
            attribute currentAlertKind := alertKind;
            attribute alertActive := true;
            attribute currentAlertMode := if alertKind == AlertKind::leakDetected then AlertMode::visualAndAuditory else AlertMode::visual endif;
            attribute visualIndicatorColor := if alertKind == AlertKind::leakDetected then "red" else if alertKind == AlertKind::pouchNearCapacity then "yellow" else if alertKind == AlertKind::filterSaturated then "orange" else if alertKind == AlertKind::wearTimeExpired then "blue" else "green" endif endif endif endif;
            out alertActivated = alertActive;
        }

        action clearAlert {
            attribute currentAlertKind := AlertKind::none;
            attribute currentAlertMode := AlertMode::silent;
            attribute alertActive := false;
            attribute visualIndicatorColor := "green";
        }

        action updateBattery {
            attribute batteryLevel := batteryLevel - 0.3;
        }

        state def alertState {
            entry;
            state idle;
            state alerting;
            transition from idle to alerting when alertActive == true;
            transition from alerting to idle when alertActive == false;
        }
    }

    part def WearTimeMonitor {
        doc /* Monitors elapsed wear time and triggers alert when recommended wear time expires */
        attribute maxWearTime : TimeDurationHours := 72.0;
        attribute elapsedWearTime : TimeDurationHours := 0.0;
        attribute isExpired : Boolean := false;
        attribute wearTimeWarningThreshold : TimeDurationHours := 60.0;
        attribute warningIssued : Boolean := false;

        port wearTimeOutputPort : SensorOutputPort;

        action updateWearTime {
            attribute elapsedWearTime := elapsedWearTime + 1.0;
            attribute isExpired := if elapsedWearTime >= maxWearTime then true else false endif;
            attribute warningIssued := if elapsedWearTime >= wearTimeWarningThreshold then true else false endif;
        }

        action resetWearTime {
            attribute elapsedWearTime := 0.0;
            attribute isExpired := false;
            attribute warningIssued := false;
        }

        state def wearTimeState {
            entry;
            state tracking;
            state warning;
            state expired;
            transition from tracking to warning when elapsedWearTime >= wearTimeWarningThreshold;
            transition from warning to expired when elapsedWearTime >= maxWearTime;
            transition from expired to tracking when elapsedWearTime == 0.0;
        }
    }

    // ===== Main System Part =====

    part def IntelligentOstomyCareSystem {
        doc /* Advanced intelligent ostomy care system that collects waste, protects skin, controls odor, and provides proactive alerts */
        attribute systemId : String;
        attribute currentState : SystemStateKind := SystemStateKind::unattached;
        attribute systemActive : Boolean := false;

        part skinBarrier : SkinBarrier {
            attribute maxWearTime := 72.0;
        }

        part collectionPouch : CollectionPouch {
            attribute maxVolume := 500.0;
        }

        part charcoalFilter : CharcoalFilter {
            attribute saturationThreshold := 100.0;
        }

        part comfortLayer : ComfortLayer {
            attribute material := "breathable non-woven fabric";
        }

        part leakageSensor : LeakageDetectionSensor {
            attribute sensorActive := true;
            attribute batteryLevel := 100.0;
        }

        part alertModule : AlertModule {
            attribute volumeLevel := 0.7;
            attribute batteryLevel := 100.0;
        }

        part wearTimeMonitor : WearTimeMonitor {
            attribute maxWearTime := 72.0;
        }

        // Connections between components
        connection stomaToBarrier : StomaToBarrierInterface connect skinBarrier.stomaPort to collectionPouch.barrierPort;

        connection barrierToPouch : BarrierToPouchInterface connect skinBarrier.pouchPort to collectionPouch.barrierPort;

        connection pouchToFilter : PouchToFilterInterface connect collectionPouch.filterPort to charcoalFilter.gasInPort;

        connection sensorToAlert : SensorToAlertInterface connect leakageSensor.sensorPort to alertModule.inputPort;

        connection wearTimeToAlert : SensorToAlertInterface connect wearTimeMonitor.wearTimeOutputPort to alertModule.inputPort;

        // System-level state machine
        state def systemLifecycleStateMachine {
            entry;

            state unattached {
                doc /* System is not attached to the patient */
                entry;
                transition to attached when skinBarrier.sealIntact == true;
            }

            state attached {
                doc /* System is attached to the patient and sealed */
                entry;
                perform skinBarrier.applyBarrier;
                perform wearTimeMonitor.updateWearTime;
                transition to collecting when collectionPouch.currentVolume > 0.0;
                transition to compromised when leakageSensor.isLeakDetected == true;
            }

            state collecting {
                doc /* System is actively collecting effluent */
                entry;
                perform collectionPouch.collectEffluent;
                perform charcoalFilter.filterGas;
                perform leakageSensor.monitorSeal;
                perform wearTimeMonitor.updateWearTime;
                transition to nearCapacity when collectionPouch.fillPercentage >= collectionPouch.nearCapacityThreshold;
                transition to compromised when leakageSensor.isLeakDetected == true;
                transition to compromised when wearTimeMonitor.isExpired == true;
            }

            state nearCapacity {
                doc /* Pouch is nearing capacity; user should empty or change soon */
                entry;
                perform alertModule.triggerAlert with alertKind = AlertKind::pouchNearCapacity;
                transition to compromised when leakageSensor.isLeakDetected == true;
                transition to collecting when collectionPouch.currentVolume == 0.0;
            }

            state compromised {
                doc /* System integrity is compromised; immediate attention required */
                entry;
                perform alertModule.triggerAlert with alertKind = AlertKind::leakDetected;
                transition to unattached when skinBarrier.sealIntact == false and skinBarrier.currentWearTime == 0.0;
            }
        }

        // Top-level behavior binding
        exhibit state systemLifecycleStateMachine;

        // System initialization action
        action initializeSystem {
            attribute currentState := SystemStateKind::unattached;
            attribute systemActive := false;
            perform skinBarrier.barrierState.unattached.entry;
            perform collectionPouch.pouchFillState.empty.entry;
            perform charcoalFilter.filterState.active.entry;
            perform leakageSensor.sensorState.dormant.entry;
            perform alertModule.alertState.idle.entry;
            perform wearTimeMonitor.wearTimeState.tracking.entry;
        }

        // System activation action
        action activateSystem {
            attribute systemActive := true;
            perform leakageSensor.sensorState.monitoring.entry;
            perform alertModule.alertState.idle.entry;
        }
    }

    // ===== Requirements =====

    requirement def LeakPreventionRequirement {
        doc /* The system shall maintain a secure seal between the skin barrier and peristomal skin to prevent leaks */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Skin barrier adhesion strength must remain above minimum threshold */
            assert system.skinBarrier.adhesionStrength >= system.skinBarrier.adhesiveIntegrityThreshold;
        }
    }

    requirement def SkinProtectionRequirement {
        doc /* The system shall protect the surrounding skin from irritation caused by effluent contact */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Skin barrier seal integrity must be maintained */
            assert system.skinBarrier.sealIntact == true;
        }
    }

    requirement def OdorControlRequirement {
        doc /* The system shall neutralize odors through the integrated charcoal filter */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Charcoal filter must remain below saturation threshold during normal operation */
            assert system.charcoalFilter.currentSaturation < system.charcoalFilter.saturationThreshold;
        }
    }

    requirement def GasReleaseRequirement {
        doc /* The system shall allow gas release from the pouch to prevent ballooning */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Filter must process gas from pouch to atmosphere */
            assert system.charcoalFilter.filterStatus == FilterStatus::active;
        }
    }

    requirement def LeakageDetectionRequirement {
        doc /* The system shall detect seal compromise through moisture and adhesion monitoring */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Leakage sensor must be active and capable of detection */
            assert system.leakageSensor.sensorActive == true;
            assert system.leakageSensor.sensitivity >= 0.85;
        }
    }

    requirement def LeakageAlertRequirement {
        doc /* The system shall alert the user when a leak is detected */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Leak detection must trigger visual and auditory alert */
            assert if system.leakageSensor.isLeakDetected == true then system.alertModule.alertActive == true and system.alertModule.currentAlertKind == AlertKind::leakDetected endif;
        }
    }

    requirement def CapacityAlertRequirement {
        doc /* The system shall alert the user when the pouch is nearing capacity */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Fill percentage at or above 75 percent must trigger alert */
            assert if system.collectionPouch.fillPercentage >= system.collectionPouch.nearCapacityThreshold then system.alertModule.currentAlertKind == AlertKind::pouchNearCapacity endif;
        }
    }

    requirement def FilterSaturationAlertRequirement {
        doc /* The system shall alert the user when the charcoal filter is saturated */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Filter saturation at or above 100 percent must trigger alert */
            assert if system.charcoalFilter.currentSaturation >= system.charcoalFilter.saturationThreshold then system.alertModule.currentAlertKind == AlertKind::filterSaturated endif;
        }
    }

    requirement def WearTimeAlertRequirement {
        doc /* The system shall alert the user when recommended wear time has expired */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Wear time expiration must trigger alert */
            assert if system.wearTimeMonitor.isExpired == true then system.alertModule.currentAlertKind == AlertKind::wearTimeExpired endif;
        }
    }

    requirement def LowBatteryAlertRequirement {
        doc /* The system shall alert the user when the electronic monitoring battery is low */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Battery level below threshold must trigger low battery alert */
            assert if system.leakageSensor.batteryLevel <= system.leakageSensor.batteryLevel or system.alertModule.batteryLevel <= system.alertModule.lowBatteryThreshold then system.alertModule.currentAlertKind == AlertKind::lowBattery endif;
        }
    }

    requirement def ComfortRequirement {
        doc /* The system shall provide patient comfort through a soft, breathable comfort layer */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Comfort layer must be breathable and soft */
            assert system.comfortLayer.breathabilityRating >= 0.75;
            assert system.comfortLayer.softnessRating >= 0.75;
        }
    }

    requirement def DiscretionRequirement {
        doc /* The system shall operate discreetly for user confidence */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* System must be compact and odor-containing */
            assert system.collectionPouch.maxVolume <= 600.0;
            assert system.charcoalFilter.filterStatus == FilterStatus::active;
        }
    }

    requirement def StateTransitionRequirement {
        doc /* The system shall transition through defined lifecycle states: unattached, attached, collecting, nearCapacity, and compromised */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* System state must follow valid state transitions */
            assert system.currentState == SystemStateKind::unattached or system.currentState == SystemStateKind::attached or system.currentState == SystemStateKind::collecting or system.currentState == SystemStateKind::nearCapacity or system.currentState == SystemStateKind::compromised;
        }
    }

    requirement def CompromisedStateRequirement {
        doc /* The system shall enter a compromised state when a leak is detected requiring immediate attention */
        subject system : IntelligentOstomyCareSystem;
        objective {
            doc /* Leak detection must force state to compromised */
            assert if system.leakageSensor.isLeakDetected == true then system.currentState == SystemStateKind::compromised endif;
        }
    }

    // ===== Requirement Package =====

    package OstomyCareRequirements {
        requirement leakPrevention : LeakPreventionRequirement;
        requirement skinProtection : SkinProtectionRequirement;
        requirement odorControl : OdorControlRequirement;
        requirement gasRelease : GasReleaseRequirement;
        requirement leakageDetection : LeakageDetectionRequirement;
        requirement leakageAlert : LeakageAlertRequirement;
        requirement capacityAlert : CapacityAlertRequirement;
        requirement filterSaturationAlert : FilterSaturationAlertRequirement;
        requirement wearTimeAlert : WearTimeAlertRequirement;
        requirement lowBatteryAlert : LowBatteryAlertRequirement;
        requirement patientComfort : ComfortRequirement;
        requirement discretion : DiscretionRequirement;
        requirement stateTransitions : StateTransitionRequirement;
        requirement compromisedState : CompromisedStateRequirement;
    }

    // ===== Satisfaction Bindings =====

    satisfaction leakPrevention satisfy by IntelligentOstomyCareSystem.skinBarrier;
    satisfaction skinProtection satisfy by IntelligentOstomyCareSystem.skinBarrier;
    satisfaction odorControl satisfy by IntelligentOstomyCareSystem.charcoalFilter;
    satisfaction gasRelease satisfy by IntelligentOstomyCareSystem.charcoalFilter;
    satisfaction leakageDetection satisfy by IntelligentOstomyCareSystem.leakageSensor;
    satisfaction leakageAlert satisfy by IntelligentOstomyCareSystem.alertModule;
    satisfaction capacityAlert satisfy by IntelligentOstomyCareSystem.alertModule;
    satisfaction filterSaturationAlert satisfy by IntelligentOstomyCareSystem.alertModule;
    satisfaction wearTimeAlert satisfy by IntelligentOstomyCareSystem.wearTimeMonitor;
    satisfaction lowBatteryAlert satisfy by IntelligentOstomyCareSystem.alertModule;
    satisfaction patientComfort satisfy by IntelligentOstomyCareSystem.comfortLayer;
    satisfaction discretion satisfy by IntelligentOstomyCareSystem;
    satisfaction stateTransitions satisfy by IntelligentOstomyCareSystem;
    satisfaction compromisedState satisfy by IntelligentOstomyCareSystem;

}
