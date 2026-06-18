package HomeMedicalEquipmentModel {
    import ScalarValues::*;
    import SI::*;

    unit L;
    unit min;
    unit L_per_min;
    unit kPa;
    unit pct;
    unit degC;
    unit V;
    unit W;
    unit dBA;
    unit h;
    unit s;

    attribute def VolumeFlow :> Real { unit = L_per_min; }
    attribute def Pressure :> Real { unit = kPa; }
    attribute def OxygenFraction :> Real { unit = pct; }
    attribute def RelativeHumidity :> Real { unit = pct; }
    attribute def Temperature :> Real { unit = degC; }
    attribute def Voltage :> Real { unit = V; }
    attribute def Power :> Real { unit = W; }
    attribute def SoundPressureLevel :> Real { unit = dBA; }
    attribute def Duration :> Real { unit = s; }
    attribute def OperatingHours :> Real { unit = h; }
    attribute def Percentage :> Real { unit = pct; }

    enum def TherapyMode {
        enum continuousFlow;
        enum pulseDose;
        enum standby;
    }

    enum def AlarmSeverity {
        enum advisory;
        enum caution;
        enum warning;
        enum critical;
    }

    enum def EquipmentAvailability {
        enum available;
        enum degraded;
        enum unavailable;
        enum serviceLocked;
    }

    enum def PowerSourceKind {
        enum mainsAC;
        enum internalBattery;
        enum externalDC;
    }

    item def GasMixture {
        attribute oxygenFraction : OxygenFraction;
        attribute nitrogenFraction : Percentage;
        attribute carbonDioxideFraction : Percentage;
        attribute waterVaporFraction : Percentage;
        attribute flow : VolumeFlow;
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute relativeHumidity : RelativeHumidity;
    }

    item def AmbientAir :> GasMixture {
        attribute :>> oxygenFraction = 20.9 [pct];
        attribute :>> nitrogenFraction = 78.1 [pct];
        attribute :>> carbonDioxideFraction = 0.04 [pct];
    }

    item def CompressedAir :> GasMixture {
        attribute compressorDischargePressure : Pressure;
    }

    item def OxygenEnrichedGas :> GasMixture {
        attribute :>> oxygenFraction = 93.0 [pct];
        attribute therapeuticFlow : VolumeFlow;
    }

    item def ExhaustGas :> GasMixture {
        attribute nitrogenEnrichedFraction : Percentage;
    }

    item def OxygenPrescription {
        attribute patientIdentifier : String;
        attribute prescribedMode : TherapyMode;
        attribute prescribedContinuousFlow : VolumeFlow;
        attribute minimumOxygenFraction : OxygenFraction;
        attribute maximumOutletPressure : Pressure;
        attribute dailyUseDuration : OperatingHours;
    }

    item def PatientVitalSigns {
        attribute pulseOximetry : Percentage;
        attribute respiratoryRatePerMinute : Real;
        attribute heartRatePerMinute : Real;
    }

    item def ElectricPower {
        attribute sourceKind : PowerSourceKind;
        attribute voltage : Voltage;
        attribute availablePower : Power;
    }

    item def UserCommand {
        attribute requestedMode : TherapyMode;
        attribute requestedFlow : VolumeFlow;
        attribute alarmSilenceRequested : Boolean;
        attribute powerOnRequested : Boolean;
        attribute powerOffRequested : Boolean;
    }

    item def TherapyLog {
        attribute accumulatedUse : OperatingHours;
        attribute deliveredFlowAverage : VolumeFlow;
        attribute deliveredOxygenFractionAverage : OxygenFraction;
        attribute alarmCount : Integer;
        attribute lastServiceHours : OperatingHours;
    }

    item def AlarmMessage {
        attribute severity : AlarmSeverity;
        attribute code : String;
        attribute messageText : String;
        attribute audibleLevel : SoundPressureLevel;
        attribute latched : Boolean;
    }

    port def AirIntakePort {
        in item air : AmbientAir;
    }

    port def CompressedAirPort {
        inout item compressedAir : CompressedAir;
    }

    port def ProductGasPort {
        out item oxygenGas : OxygenEnrichedGas;
    }

    port def ExhaustPort {
        out item exhaustGas : ExhaustGas;
    }

    port def PatientGasPort {
        in item oxygenGas : OxygenEnrichedGas;
        out item exhalationBackPressure : GasMixture;
    }

    port def ElectricalPowerInPort {
        in item power : ElectricPower;
    }

    port def UserInterfacePort {
        in item command : UserCommand;
        out item alarm : AlarmMessage;
        out item log : TherapyLog;
    }

    port def ClinicalDataPort {
        in item prescription : OxygenPrescription;
        out item therapyLog : TherapyLog;
        out item alarmMessage : AlarmMessage;
    }

    port def VitalSignsPort {
        in item vitalSigns : PatientVitalSigns;
    }

    constraint def FlowAccuracyConstraint {
        in commandedFlow : VolumeFlow;
        in measuredFlow : VolumeFlow;
        require constraint {
            measuredFlow >= commandedFlow - 0.25 [L_per_min] and
            measuredFlow <= commandedFlow + 0.25 [L_per_min]
        }
    }

    constraint def OxygenPurityConstraint {
        in measuredOxygenFraction : OxygenFraction;
        require constraint {
            measuredOxygenFraction >= 87.0 [pct] and measuredOxygenFraction <= 96.0 [pct]
        }
    }

    constraint def OutletPressureSafetyConstraint {
        in outletPressure : Pressure;
        require constraint {
            outletPressure <= 55.0 [kPa]
        }
    }

    constraint def AudibleAlarmConstraint {
        in alarmLevel : SoundPressureLevel;
        in severity : AlarmSeverity;
        require constraint {
            severity == AlarmSeverity::critical implies alarmLevel >= 65.0 [dBA]
        }
    }

    action def FilterAmbientAir {
        in item rawAir : AmbientAir;
        out item filteredAir : AmbientAir;
    }

    action def CompressAir {
        in item filteredAir : AmbientAir;
        out item compressedAir : CompressedAir;
        attribute targetDischargePressure : Pressure = 210.0 [kPa];
    }

    action def SeparateNitrogen {
        in item compressedAir : CompressedAir;
        out item productGas : OxygenEnrichedGas;
        out item exhaustGas : ExhaustGas;
        attribute sieveCycleDuration : Duration = 8.0 [s];
    }

    action def StoreProductGas {
        in item productGas : OxygenEnrichedGas;
        out item bufferedGas : OxygenEnrichedGas;
        attribute reservoirPressure : Pressure;
    }

    action def RegulateTherapyFlow {
        in item bufferedGas : OxygenEnrichedGas;
        in item prescription : OxygenPrescription;
        out item regulatedGas : OxygenEnrichedGas;
        attribute measuredFlow : VolumeFlow;
        constraint flowAccuracy : FlowAccuracyConstraint {
            in commandedFlow = prescription.prescribedContinuousFlow;
            in measuredFlow = measuredFlow;
        }
    }

    action def HumidifyGas {
        in item regulatedGas : OxygenEnrichedGas;
        out item humidifiedGas : OxygenEnrichedGas;
        attribute targetHumidity : RelativeHumidity = 40.0 [pct];
    }

    action def DeliverToPatient {
        in item humidifiedGas : OxygenEnrichedGas;
        out item deliveredGas : OxygenEnrichedGas;
        attribute patientEndPressure : Pressure;
    }

    action def MonitorTherapy {
        in item deliveredGas : OxygenEnrichedGas;
        in item vitalSigns : PatientVitalSigns;
        out item log : TherapyLog;
        out item alarm : AlarmMessage;
        constraint oxygenPurity : OxygenPurityConstraint {
            in measuredOxygenFraction = deliveredGas.oxygenFraction;
        }
        constraint pressureLimit : OutletPressureSafetyConstraint {
            in outletPressure = deliveredGas.pressure;
        }
    }

    action def DeliverOxygenTherapy {
        in item ambientAir : AmbientAir;
        in item prescription : OxygenPrescription;
        in item vitalSigns : PatientVitalSigns;
        out item deliveredGas : OxygenEnrichedGas;
        out item exhaustGas : ExhaustGas;
        out item therapyLog : TherapyLog;
        out item alarm : AlarmMessage;

        action filter : FilterAmbientAir;
        action compress : CompressAir;
        action separate : SeparateNitrogen;
        action store : StoreProductGas;
        action regulate : RegulateTherapyFlow;
        action humidify : HumidifyGas;
        action deliver : DeliverToPatient;
        action monitor : MonitorTherapy;

        flow ambientAir to filter.rawAir;
        flow filter.filteredAir to compress.filteredAir;
        flow compress.compressedAir to separate.compressedAir;
        flow separate.productGas to store.productGas;
        flow separate.exhaustGas to exhaustGas;
        flow store.bufferedGas to regulate.bufferedGas;
        flow prescription to regulate.prescription;
        flow regulate.regulatedGas to humidify.regulatedGas;
        flow humidify.humidifiedGas to deliver.humidifiedGas;
        flow deliver.deliveredGas to deliveredGas;
        flow deliver.deliveredGas to monitor.deliveredGas;
        flow vitalSigns to monitor.vitalSigns;
        flow monitor.log to therapyLog;
        flow monitor.alarm to alarm;

        first filter then compress;
        then separate;
        then store;
        then regulate;
        then humidify;
        then deliver;
        then monitor;
    }

    state def OxygenTherapyStateMachine {
        attribute commandedMode : TherapyMode;
        attribute availability : EquipmentAvailability;
        attribute activePowerSource : PowerSourceKind;

        state Off;
        state Standby;
        state SelfTest;
        state Ready;
        state TherapyActive;
        state BatteryBackup;
        state AlarmActive;
        state ServiceRequired;
        state Shutdown;

        transition initial then Off;

        transition powerOn
            first Off
            accept UserCommand
            if powerOnRequested
            then Standby;

        transition beginSelfTest
            first Standby
            then SelfTest;

        transition selfTestPassed
            first SelfTest
            if availability == EquipmentAvailability::available
            then Ready;

        transition selfTestFailed
            first SelfTest
            if availability == EquipmentAvailability::unavailable
            then ServiceRequired;

        transition startTherapy
            first Ready
            accept OxygenPrescription
            then TherapyActive;

        transition mainsLost
            first TherapyActive
            accept ElectricPower
            if activePowerSource == PowerSourceKind::internalBattery
            then BatteryBackup;

        transition mainsRestored
            first BatteryBackup
            accept ElectricPower
            if activePowerSource == PowerSourceKind::mainsAC
            then TherapyActive;

        transition alarmDetected
            first TherapyActive
            accept AlarmMessage
            then AlarmActive;

        transition alarmResolved
            first AlarmActive
            if availability != EquipmentAvailability::unavailable
            then TherapyActive;

        transition serviceFault
            first AlarmActive
            if availability == EquipmentAvailability::serviceLocked
            then ServiceRequired;

        transition stopTherapy
            first TherapyActive
            accept UserCommand
            if requestedMode == TherapyMode::standby
            then Ready;

        transition shutdownRequested
            first Ready
            accept UserCommand
            if powerOffRequested
            then Shutdown;

        transition shutdownComplete
            first Shutdown
            then Off;
    }

    part def IntakeFilter {
        port inlet : AirIntakePort;
        port outlet : AirIntakePort;
        attribute particleRemovalEfficiency : Percentage = 99.0 [pct];
        attribute replacementInterval : OperatingHours = 1000.0 [h];
    }

    part def Compressor {
        port inlet : AirIntakePort;
        port outlet : CompressedAirPort;
        attribute ratedPower : Power = 180.0 [W];
        attribute nominalDischargePressure : Pressure = 210.0 [kPa];
        perform action compression : CompressAir;
    }

    part def MolecularSieveAssembly {
        port inlet : CompressedAirPort;
        port productOutlet : ProductGasPort;
        port exhaustOutlet : ExhaustPort;
        attribute nominalOxygenFraction : OxygenFraction = 93.0 [pct];
        attribute minimumAcceptableOxygenFraction : OxygenFraction = 87.0 [pct];
        perform action separation : SeparateNitrogen;
    }

    part def ProductReservoir {
        port inlet : ProductGasPort;
        port outlet : ProductGasPort;
        attribute nominalReservoirPressure : Pressure = 140.0 [kPa];
        attribute usableCapacityLiters : Real = 1.2;
        perform action storage : StoreProductGas;
    }

    part def FlowControlValve {
        port inlet : ProductGasPort;
        port outlet : ProductGasPort;
        attribute commandedFlow : VolumeFlow = 2.0 [L_per_min];
        attribute measuredFlow : VolumeFlow;
        attribute minimumFlow : VolumeFlow = 0.5 [L_per_min];
        attribute maximumFlow : VolumeFlow = 5.0 [L_per_min];
        perform action regulation : RegulateTherapyFlow;
    }

    part def HumidifierBottle {
        port inlet : ProductGasPort;
        port outlet : ProductGasPort;
        attribute waterFillVolumeMilliliters : Real = 350.0;
        attribute targetRelativeHumidity : RelativeHumidity = 40.0 [pct];
        perform action humidification : HumidifyGas;
    }

    part def NasalCannula {
        port equipmentEnd : PatientGasPort;
        port patientEnd : PatientGasPort;
        attribute tubingLengthMeters : Real = 2.1;
        attribute maximumPressureDrop : Pressure = 7.0 [kPa];
    }

    part def OxygenSensor {
        port sampleIn : ProductGasPort;
        attribute measuredOxygenFraction : OxygenFraction;
        attribute calibrationInterval : OperatingHours = 4320.0 [h];
    }

    part def FlowSensor {
        port sampleIn : ProductGasPort;
        attribute measuredFlow : VolumeFlow;
        attribute accuracy : VolumeFlow = 0.1 [L_per_min];
    }

    part def PressureSensor {
        port sampleIn : ProductGasPort;
        attribute measuredPressure : Pressure;
        attribute maximumSafePressure : Pressure = 55.0 [kPa];
    }

    part def PowerSubsystem {
        port powerIn : ElectricalPowerInPort;
        port powerOut : ElectricalPowerInPort;
        attribute mainsVoltage : Voltage = 120.0 [V];
        attribute maximumPowerDraw : Power = 320.0 [W];
        attribute batteryRuntimeAt2Lpm : OperatingHours = 2.0 [h];
        attribute activeSource : PowerSourceKind = PowerSourceKind::mainsAC;
    }

    part def Controller {
        port clinicianData : ClinicalDataPort;
        port userInterface : UserInterfacePort;
        port vitals : VitalSignsPort;
        attribute selectedMode : TherapyMode = TherapyMode::continuousFlow;
        attribute availability : EquipmentAvailability = EquipmentAvailability::available;
        attribute softwareVersion : String = "3.2.4";
        perform action therapySupervisor : MonitorTherapy;
        exhibit state operatingState : OxygenTherapyStateMachine;
    }

    part def UserInterfacePanel {
        port ui : UserInterfacePort;
        attribute displayBrightnessPercent : Percentage = 70.0 [pct];
        attribute minimumAlarmSoundLevel : SoundPressureLevel = 65.0 [dBA];
    }

    part def RemoteClinicalGateway {
        port data : ClinicalDataPort;
        attribute encryptedCommunicationEnabled : Boolean = true;
        attribute logUploadInterval : OperatingHours = 24.0 [h];
    }

    part def HomePatient {
        port cannulaInterface : PatientGasPort;
        port vitalSignsOut : VitalSignsPort;
        attribute prescribedSpO2Minimum : Percentage = 90.0 [pct];
        attribute currentVitalSigns : PatientVitalSigns;
    }

    part def Caregiver {
        port userAccess : UserInterfacePort;
        attribute trainedForFilterReplacement : Boolean = true;
        attribute trainedForAlarmResponse : Boolean = true;
    }

    part def HomeElectricalOutlet {
        port acOutlet : ElectricalPowerInPort;
        attribute outletVoltage : Voltage = 120.0 [V];
        attribute breakerPowerLimit : Power = 1800.0 [W];
    }

    part def RoomAirSource {
        port airOut : AirIntakePort;
        attribute roomTemperature : Temperature = 22.0 [degC];
        attribute roomRelativeHumidity : RelativeHumidity = 45.0 [pct];
    }

    part def HomeMedicalOxygenEquipment {
        attribute primaryFunction : String =
            "Provide prescribed oxygen-enriched breathing gas to a home patient through a nasal cannula while controlling flow, monitoring oxygen concentration and pressure, recording therapy use, and alarming unsafe conditions.";

        port airIntake : AirIntakePort;
        port patientOutlet : PatientGasPort;
        port exhaustOutlet : ExhaustPort;
        port mainsPower : ElectricalPowerInPort;
        port userAccess : UserInterfacePort;
        port clinicianAccess : ClinicalDataPort;
        port patientVitals : VitalSignsPort;

        part filter : IntakeFilter;
        part compressor : Compressor;
        part sieveBeds : MolecularSieveAssembly;
        part reservoir : ProductReservoir;
        part flowValve : FlowControlValve;
        part humidifier : HumidifierBottle;
        part cannula : NasalCannula;
        part oxygenSensor : OxygenSensor;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part powerSubsystem : PowerSubsystem;
        part controller : Controller;
        part userInterfacePanel : UserInterfacePanel;
        part clinicalGateway : RemoteClinicalGateway;

        perform action deliverTherapy : DeliverOxygenTherapy;
        exhibit state lifecycle : OxygenTherapyStateMachine;

        connect airIntake to filter.inlet;
        connect filter.outlet to compressor.inlet;
        connect compressor.outlet to sieveBeds.inlet;
        connect sieveBeds.productOutlet to reservoir.inlet;
        connect sieveBeds.exhaustOutlet to exhaustOutlet;
        connect reservoir.outlet to flowValve.inlet;
        connect flowValve.outlet to humidifier.inlet;
        connect humidifier.outlet to cannula.equipmentEnd;
        connect cannula.patientEnd to patientOutlet;

        connect flowValve.outlet to flowSensor.sampleIn;
        connect flowValve.outlet to pressureSensor.sampleIn;
        connect reservoir.outlet to oxygenSensor.sampleIn;

        connect mainsPower to powerSubsystem.powerIn;
        connect powerSubsystem.powerOut to compressor.inlet;
        connect userAccess to userInterfacePanel.ui;
        connect userInterfacePanel.ui to controller.userInterface;
        connect clinicianAccess to clinicalGateway.data;
        connect clinicalGateway.data to controller.clinicianData;
        connect patientVitals to controller.vitals;
    }

    part def HomeCareOxygenTherapyContext {
        part equipment : HomeMedicalOxygenEquipment;
        part patient : HomePatient;
        part caregiver : Caregiver;
        part wallOutlet : HomeElectricalOutlet;
        part roomAir : RoomAirSource;

        connect roomAir.airOut to equipment.airIntake;
        connect wallOutlet.acOutlet to equipment.mainsPower;
        connect equipment.patientOutlet to patient.cannulaInterface;
        connect patient.vitalSignsOut to equipment.patientVitals;
        connect caregiver.userAccess to equipment.userAccess;
    }

    requirement def PrimaryFunctionRequirement {
        subject equipment : HomeMedicalOxygenEquipment;
        require constraint {
            equipment.flowValve.commandedFlow >= 0.5 [L_per_min] and
            equipment.flowValve.commandedFlow <= 5.0 [L_per_min] and
            equipment.sieveBeds.nominalOxygenFraction >= 90.0 [pct]
        }
    }

    requirement def FlowControlRequirement {
        subject valve : FlowControlValve;
        require constraint {
            valve.measuredFlow >= valve.commandedFlow - 0.25 [L_per_min] and
            valve.measuredFlow <= valve.commandedFlow + 0.25 [L_per_min]
        }
    }

    requirement def OxygenConcentrationRequirement {
        subject sensor : OxygenSensor;
        require constraint {
            sensor.measuredOxygenFraction >= 87.0 [pct]
        }
    }

    requirement def OutletPressureRequirement {
        subject sensor : PressureSensor;
        require constraint {
            sensor.measuredPressure <= sensor.maximumSafePressure
        }
    }

    requirement def HomePowerRequirement {
        subject power : PowerSubsystem;
        require constraint {
            power.maximumPowerDraw <= 320.0 [W] and
            power.batteryRuntimeAt2Lpm >= 2.0 [h]
        }
    }

    requirement def AlarmRequirement {
        subject ui : UserInterfacePanel;
        require constraint {
            ui.minimumAlarmSoundLevel >= 65.0 [dBA]
        }
    }

    requirement def MaintainabilityRequirement {
        subject filter : IntakeFilter;
        require constraint {
            filter.replacementInterval >= 1000.0 [h]
        }
    }

    requirement <HME-001> primaryTherapyFunction : PrimaryFunctionRequirement {
        doc /* The home medical oxygen equipment shall provide prescribed oxygen-enriched breathing gas to a home patient at a controlled therapeutic flow and shall continuously monitor delivery safety. */
    }

    requirement <HME-002> prescribedFlowAccuracy : FlowControlRequirement {
        doc /* The equipment shall regulate continuous oxygen flow within plus or minus 0.25 L/min of the prescribed setting over the range 0.5 L/min to 5.0 L/min. */
    }

    requirement <HME-003> oxygenPurity : OxygenConcentrationRequirement {
        doc /* The oxygen-enriched product gas delivered for therapy shall remain at or above 87 percent oxygen during normal operation. */
    }

    requirement <HME-004> outletPressureSafety : OutletPressureRequirement {
        doc /* Patient outlet pressure shall not exceed 55 kPa during any normal or single-fault operating condition. */
    }

    requirement <HME-005> homeElectricalOperation : HomePowerRequirement {
        doc /* The equipment shall operate from a common home electrical outlet and provide at least two hours of battery backup at 2 L/min. */
    }

    requirement <HME-006> audibleAndVisualAlarm : AlarmRequirement {
        doc /* Critical unsafe therapy conditions shall produce visible alarm indication and an audible alarm of at least 65 dBA. */
    }

    requirement <HME-007> userMaintainability : MaintainabilityRequirement {
        doc /* The caregiver-replaceable intake filter shall have a replacement interval of at least 1000 operating hours. */
    }

    satisfy primaryTherapyFunction by HomeMedicalOxygenEquipment::deliverTherapy;
    satisfy prescribedFlowAccuracy by FlowControlValve::regulation;
    satisfy oxygenPurity by MolecularSieveAssembly::separation;
    satisfy outletPressureSafety by PressureSensor;
    satisfy homeElectricalOperation by PowerSubsystem;
    satisfy audibleAndVisualAlarm by UserInterfacePanel;
    satisfy userMaintainability by IntakeFilter;

    part homeUseScenario : HomeCareOxygenTherapyContext {
        part :>> equipment {
            part :>> flowValve {
                attribute :>> commandedFlow = 2.0 [L_per_min];
            }
            part :>> sieveBeds {
                attribute :>> nominalOxygenFraction = 93.0 [pct];
            }
            part :>> powerSubsystem {
                attribute :>> activeSource = PowerSourceKind::mainsAC;
            }
        }
        part :>> patient {
            attribute :>> prescribedSpO2Minimum = 90.0 [pct];
        }
    }
}
