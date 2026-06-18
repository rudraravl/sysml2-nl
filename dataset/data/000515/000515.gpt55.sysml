package TranscranialMagneticStimulationSystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Time_s :> ISQ::time {
        :>> unit = SI::second;
    }

    attribute def Frequency_Hz :> ISQ::frequency {
        :>> unit = SI::hertz;
    }

    attribute def Voltage_V :> ISQ::electricPotential {
        :>> unit = SI::volt;
    }

    attribute def Current_A :> ISQ::electricCurrent {
        :>> unit = SI::ampere;
    }

    attribute def Energy_J :> ISQ::energy {
        :>> unit = SI::joule;
    }

    attribute def Power_W :> ISQ::power {
        :>> unit = SI::watt;
    }

    attribute def Temperature_degC :> ISQ::thermodynamicTemperature {
        :>> unit = SI::degreeCelsius;
    }

    attribute def MagneticFluxDensity_T :> ISQ::magneticFluxDensity {
        :>> unit = SI::tesla;
    }

    attribute def ElectricFieldStrength_V_per_m :> ISQ::electricFieldStrength {
        :>> unit = SI::voltPerMeter;
    }

    attribute def Length_mm :> ISQ::length {
        :>> unit = SI::millimetre;
    }

    attribute def Angle_deg :> ISQ::planeAngle {
        :>> unit = SI::degree;
    }

    attribute def SoundPressureLevel_dBA :> ScalarValues::Real {
        attribute unitSymbol : String = "dBA";
    }

    attribute def Percentage_pct :> ScalarValues::Real {
        attribute unitSymbol : String = "%";
    }

    attribute def PulseCount :> ScalarValues::Integer;

    enum def TreatmentMode {
        enum singlePulse;
        enum pairedPulse;
        enum repetitiveTMS;
        enum thetaBurst;
        enum shamSimulation;
    }

    enum def CoilGeometry {
        enum figureEight;
        enum circular;
        enum doubleCone;
        enum hCoil;
    }

    enum def InterlockState {
        enum closedSafe;
        enum openUnsafe;
    }

    enum def SessionDisposition {
        enum completed;
        enum stoppedByOperator;
        enum stoppedByPatient;
        enum stoppedBySafetyInterlock;
        enum stoppedByFault;
    }

    item def ElectricalPower {
        attribute rmsVoltage : Voltage_V;
        attribute frequency : Frequency_Hz;
        attribute availablePower : Power_W;
        attribute protectiveEarthPresent : Boolean;
    }

    item def DCLinkEnergy {
        attribute voltage : Voltage_V;
        attribute storedEnergy : Energy_J;
        attribute polarityPositive : Boolean;
    }

    item def CapacitorChargeCommand {
        attribute requestedVoltage : Voltage_V;
        attribute maximumChargeTime : Time_s;
        attribute enableCharge : Boolean;
    }

    item def PulseTriggerCommand {
        attribute requestedPulseAmplitude : Percentage_pct;
        attribute pulseIndex : PulseCount;
        attribute intendedIntervalFromPreviousPulse : Time_s;
        attribute inhibitIfUnsafe : Boolean;
    }

    item def CoilDriveCurrent {
        attribute peakCurrent : Current_A;
        attribute pulseWidth : Time_s;
        attribute riseTime : Time_s;
        attribute waveformBiphasic : Boolean;
    }

    item def MagneticPulse {
        attribute peakMagneticFluxDensity : MagneticFluxDensity_T;
        attribute pulseWidth : Time_s;
        attribute riseTime : Time_s;
        attribute repetitionFrequency : Frequency_Hz;
        attribute pulseIndex : PulseCount;
        attribute acousticLevelAtPatientEar : SoundPressureLevel_dBA;
    }

    item def InducedCorticalField {
        attribute peakElectricFieldStrength : ElectricFieldStrength_V_per_m;
        attribute targetDepth : Length_mm;
        attribute focalityDiameter : Length_mm;
        attribute fieldOrientationToGyrus : Angle_deg;
        attribute effectiveNeuromodulationExpected : Boolean;
    }

    item def StimulationPrescription {
        attribute mode : TreatmentMode;
        attribute trainCount : PulseCount;
        attribute pulsesPerTrain : PulseCount;
        attribute interTrainInterval : Time_s;
        attribute pulseRepetitionFrequency : Frequency_Hz;
        attribute intensityRelativeToMotorThreshold : Percentage_pct;
        attribute targetName : String;
        attribute targetDepth : Length_mm;
        attribute targetCoordinateX : Length_mm;
        attribute targetCoordinateY : Length_mm;
        attribute targetCoordinateZ : Length_mm;
    }

    item def PatientHeadModel {
        attribute patientIdentifier : String;
        attribute scalpToCortexDistance : Length_mm;
        attribute restingMotorThreshold : Percentage_pct;
        attribute seizureRiskScreenPassed : Boolean;
        attribute implantedMetalScreenPassed : Boolean;
        attribute hearingProtectionConfirmed : Boolean;
    }

    item def CoilPose {
        attribute coordinateX : Length_mm;
        attribute coordinateY : Length_mm;
        attribute coordinateZ : Length_mm;
        attribute yaw : Angle_deg;
        attribute pitch : Angle_deg;
        attribute roll : Angle_deg;
        attribute distanceToScalp : Length_mm;
        attribute targetRegistrationError : Length_mm;
    }

    item def TemperatureReading {
        attribute measuredTemperature : Temperature_degC;
        attribute warningThreshold : Temperature_degC;
        attribute shutdownThreshold : Temperature_degC;
    }

    item def PhysiologicalStatus {
        attribute patientStopSwitchPressed : Boolean;
        attribute clinicianStopSwitchPressed : Boolean;
        attribute patientResponsive : Boolean;
        attribute adverseEventSuspected : Boolean;
    }

    item def DeviceStatus {
        attribute powered : Boolean;
        attribute initialized : Boolean;
        attribute armed : Boolean;
        attribute deliveringPulse : Boolean;
        attribute faultPresent : Boolean;
        attribute interlockState : InterlockState;
        attribute deliveredPulses : PulseCount;
        attribute coilTemperature : Temperature_degC;
        attribute dcLinkVoltage : Voltage_V;
    }

    item def TreatmentReport {
        attribute disposition : SessionDisposition;
        attribute totalDeliveredPulses : PulseCount;
        attribute maximumCoilTemperature : Temperature_degC;
        attribute maximumPeakMagneticFluxDensity : MagneticFluxDensity_T;
        attribute maximumInducedElectricField : ElectricFieldStrength_V_per_m;
        attribute safetyStopOccurred : Boolean;
        attribute operatorAcknowledgedCompletion : Boolean;
    }

    port def MainsPowerInputPort {
        in item power : ElectricalPower;
    }

    port def DCPowerOutputPort {
        out item energy : DCLinkEnergy;
    }

    port def DCPowerInputPort {
        in item energy : DCLinkEnergy;
    }

    port def ChargeControlPort {
        in item command : CapacitorChargeCommand;
        out item status : DeviceStatus;
    }

    port def PulseCommandPort {
        in item command : PulseTriggerCommand;
        out item status : DeviceStatus;
    }

    port def CoilCurrentOutputPort {
        out item current : CoilDriveCurrent;
    }

    port def CoilCurrentInputPort {
        in item current : CoilDriveCurrent;
    }

    port def MagneticPulseOutputPort {
        out item pulse : MagneticPulse;
    }

    port def MagneticPulseInputPort {
        in item pulse : MagneticPulse;
    }

    port def CorticalFieldOutputPort {
        out item field : InducedCorticalField;
    }

    port def CorticalFieldInputPort {
        in item field : InducedCorticalField;
    }

    port def PrescriptionInputPort {
        in item prescription : StimulationPrescription;
    }

    port def PatientModelInputPort {
        in item patient : PatientHeadModel;
    }

    port def CoilPoseOutputPort {
        out item pose : CoilPose;
    }

    port def CoilPoseInputPort {
        in item pose : CoilPose;
    }

    port def TemperatureOutputPort {
        out item temperature : TemperatureReading;
    }

    port def TemperatureInputPort {
        in item temperature : TemperatureReading;
    }

    port def PhysiologicalStatusOutputPort {
        out item status : PhysiologicalStatus;
    }

    port def PhysiologicalStatusInputPort {
        in item status : PhysiologicalStatus;
    }

    port def DeviceStatusOutputPort {
        out item status : DeviceStatus;
    }

    port def DeviceStatusInputPort {
        in item status : DeviceStatus;
    }

    port def ReportOutputPort {
        out item report : TreatmentReport;
    }

    part def OperatorConsole {
        attribute displayRefreshPeriod : Time_s = 0.1 [SI::second];
        attribute minimumOperatorConfirmationTime : Time_s = 1.0 [SI::second];

        port prescriptionIn : PrescriptionInputPort;
        port patientIn : PatientModelInputPort;
        port statusIn : DeviceStatusInputPort;
        port reportOut : ReportOutputPort;
        port pulseCommandOut : PulseCommandPort;
        port chargeCommandOut : ChargeControlPort;
    }

    part def MedicalGradePowerSupply {
        attribute nominalInputVoltage : Voltage_V = 230.0 [SI::volt];
        attribute nominalInputFrequency : Frequency_Hz = 50.0 [SI::hertz];
        attribute maximumOutputVoltage : Voltage_V = 3000.0 [SI::volt];
        attribute maximumOutputPower : Power_W = 2500.0 [SI::watt];
        attribute isolationLeakageCurrentLimit : Current_A = 0.0005 [SI::ampere];

        port mainsIn : MainsPowerInputPort;
        port dcOut : DCPowerOutputPort;
        port chargeControlIn : ChargeControlPort;
        port statusOut : DeviceStatusOutputPort;
    }

    part def CapacitorBank {
        attribute capacitanceEnergyAtFullCharge : Energy_J = 450.0 [SI::joule];
        attribute maximumSafeVoltage : Voltage_V = 2800.0 [SI::volt];
        attribute dischargeToSafeVoltageTime : Time_s = 30.0 [SI::second];
        attribute safeMaintenanceVoltage : Voltage_V = 50.0 [SI::volt];

        port dcIn : DCPowerInputPort;
        port energyOut : DCPowerOutputPort;
        port statusOut : DeviceStatusOutputPort;
    }

    part def PulseGenerator {
        attribute maximumPeakCoilCurrent : Current_A = 8000.0 [SI::ampere];
        attribute nominalPulseWidth : Time_s = 0.00028 [SI::second];
        attribute minimumInterPulseInterval : Time_s = 0.02 [SI::second];
        attribute supportsBiphasicWaveform : Boolean = true;
        attribute hardwareInhibitActive : Boolean = false;

        port energyIn : DCPowerInputPort;
        port triggerIn : PulseCommandPort;
        port coilCurrentOut : CoilCurrentOutputPort;
        port statusOut : DeviceStatusOutputPort;
    }

    part def TMSCoil {
        attribute geometry : CoilGeometry = CoilGeometry::figureEight;
        attribute windingInductance : ScalarValues::Real = 0.000015;
        attribute windingResistance : ScalarValues::Real = 0.018;
        attribute maximumSurfaceTemperature : Temperature_degC = 41.0 [SI::degreeCelsius];
        attribute nominalPeakMagneticFluxDensityAtScalp : MagneticFluxDensity_T = 1.8 [SI::tesla];
        attribute maximumPeakMagneticFluxDensityAtScalp : MagneticFluxDensity_T = 2.2 [SI::tesla];
        attribute focalityDiameterAtCortex : Length_mm = 12.0 [SI::millimetre];

        port driveIn : CoilCurrentInputPort;
        port magneticPulseOut : MagneticPulseOutputPort;
        port temperatureOut : TemperatureOutputPort;
        port poseIn : CoilPoseInputPort;
    }

    part def PatientCouplingVolume {
        attribute nonInvasiveAirGapAllowed : Boolean = true;
        attribute maximumCoilToScalpDistance : Length_mm = 5.0 [SI::millimetre];
        attribute nominalScalpToCortexDistance : Length_mm = 18.0 [SI::millimetre];

        port magneticPulseIn : MagneticPulseInputPort;
        port patientModelIn : PatientModelInputPort;
        port corticalFieldOut : CorticalFieldOutputPort;
    }

    part def NeuronavigationSubsystem {
        attribute targetRegistrationErrorLimit : Length_mm = 3.0 [SI::millimetre];
        attribute poseUpdatePeriod : Time_s = 0.02 [SI::second];
        attribute cameraTrackingAvailable : Boolean = true;

        port prescriptionIn : PrescriptionInputPort;
        port patientModelIn : PatientModelInputPort;
        port coilPoseOut : CoilPoseOutputPort;
        port statusOut : DeviceStatusOutputPort;
    }

    part def CoolingSubsystem {
        attribute coolantNominalFlowRate : ScalarValues::Real = 1.5;
        attribute coilWarningTemperature : Temperature_degC = 39.0 [SI::degreeCelsius];
        attribute coilShutdownTemperature : Temperature_degC = 41.0 [SI::degreeCelsius];
        attribute postTrainCoolingDuration : Time_s = 5.0 [SI::second];

        port coilTemperatureIn : TemperatureInputPort;
        port statusOut : DeviceStatusOutputPort;
    }

    part def PatientAndClinicianSafetySubsystem {
        attribute maximumAllowedRepetitionFrequency : Frequency_Hz = 20.0 [SI::hertz];
        attribute maximumAllowedTrainDuration : Time_s = 10.0 [SI::second];
        attribute maximumAllowedPulsesPerSession : PulseCount = 3000;
        attribute maximumAllowedAcousticLevelAtEar : SoundPressureLevel_dBA = 140.0;
        attribute emergencyStopReactionTime : Time_s = 0.01 [SI::second];

        port prescriptionIn : PrescriptionInputPort;
        port patientModelIn : PatientModelInputPort;
        port corticalFieldIn : CorticalFieldInputPort;
        port coilTemperatureIn : TemperatureInputPort;
        port physiologicalStatusIn : PhysiologicalStatusInputPort;
        port deviceStatusIn : DeviceStatusInputPort;
        port triggerCommandOut : PulseCommandPort;
        port statusOut : DeviceStatusOutputPort;
    }

    part def PatientInterface {
        attribute hearingProtectionRequired : Boolean = true;
        attribute patientStopSwitchRequired : Boolean = true;
        attribute minimumPatientResponsivenessCheckInterval : Time_s = 60.0 [SI::second];

        port physiologicalStatusOut : PhysiologicalStatusOutputPort;
        port patientModelIn : PatientModelInputPort;
    }

    part def TreatmentDataLogger {
        attribute samplePeriodDuringPulseTrain : Time_s = 0.001 [SI::second];
        attribute retainedRecordDuration : Time_s = 315360000.0 [SI::second];

        port prescriptionIn : PrescriptionInputPort;
        port patientModelIn : PatientModelInputPort;
        port statusIn : DeviceStatusInputPort;
        port corticalFieldIn : CorticalFieldInputPort;
        port temperatureIn : TemperatureInputPort;
        port reportOut : ReportOutputPort;
    }

    action def VerifyPrescriptionSafety {
        in item prescription : StimulationPrescription;
        in item patient : PatientHeadModel;
        out ok : Boolean;

        constraint prescriptionScreening {
            patient.seizureRiskScreenPassed == true and
            patient.implantedMetalScreenPassed == true and
            patient.hearingProtectionConfirmed == true and
            prescription.pulseRepetitionFrequency <= 20.0 [SI::hertz] and
            prescription.intensityRelativeToMotorThreshold <= 120.0 and
            prescription.trainCount * prescription.pulsesPerTrain <= 3000
        }
    }

    action def LocalizeCorticalTarget {
        in item prescription : StimulationPrescription;
        in item patient : PatientHeadModel;
        out item pose : CoilPose;

        constraint navigationAccuracy {
            pose.targetRegistrationError <= 3.0 [SI::millimetre] and
            pose.distanceToScalp <= 5.0 [SI::millimetre]
        }
    }

    action def ChargePulseEnergyStore {
        in item prescription : StimulationPrescription;
        out item storedEnergy : DCLinkEnergy;

        constraint chargeWithinHardwareLimit {
            storedEnergy.voltage <= 2800.0 [SI::volt] and
            storedEnergy.storedEnergy <= 450.0 [SI::joule]
        }
    }

    action def DeliverPulseTrain {
        in item prescription : StimulationPrescription;
        in item patient : PatientHeadModel;
        in item pose : CoilPose;
        out item deliveredPulse : MagneticPulse;
        out item inducedField : InducedCorticalField;

        constraint pulseTrainDose {
            deliveredPulse.repetitionFrequency == prescription.pulseRepetitionFrequency and
            deliveredPulse.peakMagneticFluxDensity <= 2.2 [SI::tesla] and
            deliveredPulse.pulseWidth <= 0.0004 [SI::second] and
            inducedField.peakElectricFieldStrength <= 200.0 [SI::voltPerMeter] and
            inducedField.targetDepth == prescription.targetDepth
        }
    }

    action def MonitorSafetyDuringTreatment {
        in item deviceStatus : DeviceStatus;
        in item physiologicalStatus : PhysiologicalStatus;
        in item coilTemperature : TemperatureReading;
        out continueTreatment : Boolean;

        constraint continueOnlyIfSafe {
            continueTreatment ==
            (
                deviceStatus.faultPresent == false and
                deviceStatus.interlockState == InterlockState::closedSafe and
                physiologicalStatus.patientStopSwitchPressed == false and
                physiologicalStatus.clinicianStopSwitchPressed == false and
                physiologicalStatus.adverseEventSuspected == false and
                coilTemperature.measuredTemperature < coilTemperature.shutdownThreshold
            )
        }
    }

    action def RunTMSTreatmentSession {
        in item prescription : StimulationPrescription;
        in item patient : PatientHeadModel;
        out item report : TreatmentReport;

        action verify : VerifyPrescriptionSafety;
        action localize : LocalizeCorticalTarget;
        action charge : ChargePulseEnergyStore;
        action deliver : DeliverPulseTrain;
        action monitor : MonitorSafetyDuringTreatment;

        flow prescription to verify.prescription;
        flow patient to verify.patient;
        flow prescription to localize.prescription;
        flow patient to localize.patient;
        flow prescription to charge.prescription;
        flow prescription to deliver.prescription;
        flow patient to deliver.patient;
        flow localize.pose to deliver.pose;

        first verify then localize;
        then charge;
        then deliver;
        then monitor;
    }

    state def TMSOperationalLifecycle {
        state poweredOff;
        state initializing;
        state standbyReady;
        state prescriptionLoaded;
        state targetLocalized;
        state armed;
        state deliveringPulses;
        state coolingBetweenTrains;
        state paused;
        state completed;
        state faultSafeShutdown;

        transition powerOn
            first poweredOff
            accept PowerOn
            then initializing;

        transition selfTestPassed
            first initializing
            accept SelfTestComplete
            if noFaultPresent
            then standbyReady;

        transition selfTestFailed
            first initializing
            accept FaultDetected
            then faultSafeShutdown;

        transition prescriptionAccepted
            first standbyReady
            accept PrescriptionValidated
            then prescriptionLoaded;

        transition localizationAccepted
            first prescriptionLoaded
            accept CoilPoseWithinTolerance
            then targetLocalized;

        transition armByOperator
            first targetLocalized
            accept OperatorArmCommand
            then armed;

        transition beginPulseTrain
            first armed
            accept TriggerEnable
            then deliveringPulses;

        transition trainCompleteCoolingRequired
            first deliveringPulses
            accept TrainComplete
            if coilTemperatureBelowShutdown
            then coolingBetweenTrains;

        transition nextTrainReady
            first coolingBetweenTrains
            accept CoolingIntervalElapsed
            then armed;

        transition pauseRequested
            first deliveringPulses
            accept OperatorPause
            then paused;

        transition resumeAfterPause
            first paused
            accept OperatorResume
            then armed;

        transition treatmentComplete
            first deliveringPulses
            accept AllPrescribedPulsesDelivered
            then completed;

        transition emergencyStopFromAnyActiveState
            first armed
            accept EmergencyStop
            then faultSafeShutdown;

        transition thermalFault
            first deliveringPulses
            accept CoilOverTemperature
            then faultSafeShutdown;

        transition interlockOpened
            first deliveringPulses
            accept SafetyInterlockOpened
            then faultSafeShutdown;
    }

    part def TranscranialMagneticStimulationSystem {
        attribute primaryHighLevelFunction : String =
            "Non-invasively deliver brief, controlled magnetic pulses through a scalp-positioned coil to induce a focal electric field in targeted cortical tissue for neuromodulation, while enforcing patient, clinician, thermal, electrical, acoustic, and dosing safety limits.";

        attribute supportsNonInvasiveNeuromodulation : Boolean = true;
        attribute commandedTreatmentMode : TreatmentMode = TreatmentMode::repetitiveTMS;
        attribute maximumPeakMagneticFluxDensityAtScalp : MagneticFluxDensity_T = 2.2 [SI::tesla];
        attribute maximumInducedCorticalElectricField : ElectricFieldStrength_V_per_m = 200.0 [SI::voltPerMeter];
        attribute maximumPulseRepetitionFrequency : Frequency_Hz = 20.0 [SI::hertz];
        attribute maximumPulseWidth : Time_s = 0.0004 [SI::second];
        attribute maximumSessionPulses : PulseCount = 3000;
        attribute safeIfInterlockOpened : Boolean = true;

        port mainsPower : MainsPowerInputPort;
        port prescriptionInput : PrescriptionInputPort;
        port patientModelInput : PatientModelInputPort;
        port sessionReportOutput : ReportOutputPort;

        part operatorConsole : OperatorConsole;
        part powerSupply : MedicalGradePowerSupply;
        part capacitorBank : CapacitorBank;
        part pulseGenerator : PulseGenerator;
        part stimulationCoil : TMSCoil;
        part patientCouplingVolume : PatientCouplingVolume;
        part neuronavigation : NeuronavigationSubsystem;
        part coolingSubsystem : CoolingSubsystem;
        part safetySubsystem : PatientAndClinicianSafetySubsystem;
        part patientInterface : PatientInterface;
        part dataLogger : TreatmentDataLogger;

        connect mainsPower to powerSupply.mainsIn;

        connect prescriptionInput to operatorConsole.prescriptionIn;
        connect prescriptionInput to neuronavigation.prescriptionIn;
        connect prescriptionInput to safetySubsystem.prescriptionIn;
        connect prescriptionInput to dataLogger.prescriptionIn;

        connect patientModelInput to operatorConsole.patientIn;
        connect patientModelInput to neuronavigation.patientModelIn;
        connect patientModelInput to patientCouplingVolume.patientModelIn;
        connect patientModelInput to patientInterface.patientModelIn;
        connect patientModelInput to safetySubsystem.patientModelIn;
        connect patientModelInput to dataLogger.patientModelIn;

        connect operatorConsole.chargeCommandOut to powerSupply.chargeControlIn;
        connect powerSupply.dcOut to capacitorBank.dcIn;
        connect capacitorBank.energyOut to pulseGenerator.energyIn;

        connect safetySubsystem.triggerCommandOut to pulseGenerator.triggerIn;
        connect pulseGenerator.coilCurrentOut to stimulationCoil.driveIn;

        connect neuronavigation.coilPoseOut to stimulationCoil.poseIn;
        connect stimulationCoil.magneticPulseOut to patientCouplingVolume.magneticPulseIn;
        connect patientCouplingVolume.corticalFieldOut to safetySubsystem.corticalFieldIn;
        connect patientCouplingVolume.corticalFieldOut to dataLogger.corticalFieldIn;

        connect stimulationCoil.temperatureOut to coolingSubsystem.coilTemperatureIn;
        connect stimulationCoil.temperatureOut to safetySubsystem.coilTemperatureIn;
        connect stimulationCoil.temperatureOut to dataLogger.temperatureIn;

        connect patientInterface.physiologicalStatusOut to safetySubsystem.physiologicalStatusIn;

        connect powerSupply.statusOut to safetySubsystem.deviceStatusIn;
        connect pulseGenerator.statusOut to operatorConsole.statusIn;
        connect pulseGenerator.statusOut to dataLogger.statusIn;
        connect coolingSubsystem.statusOut to safetySubsystem.deviceStatusIn;
        connect neuronavigation.statusOut to safetySubsystem.deviceStatusIn;

        connect dataLogger.reportOut to sessionReportOutput;
        connect operatorConsole.reportOut to sessionReportOutput;

        perform treatmentSession : RunTMSTreatmentSession;
        exhibit operationalLifecycle : TMSOperationalLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject tms : TranscranialMagneticStimulationSystem;

        doc /* The system shall provide transcranial magnetic stimulation by converting electrical energy into brief high-current pulses through a treatment coil, producing a time-varying magnetic field that penetrates the scalp and skull without direct electrical contact and induces a controlled electric field in a selected cortical target. */

        require constraint primaryFunctionCapability {
            tms.supportsNonInvasiveNeuromodulation == true and
            tms.maximumPeakMagneticFluxDensityAtScalp >= 1.0 [SI::tesla] and
            tms.maximumInducedCorticalElectricField >= 50.0 [SI::voltPerMeter]
        }
    }

    requirement def DoseControlRequirement {
        subject tms : TranscranialMagneticStimulationSystem;

        doc /* The system shall limit stimulation dose by enforcing configured pulse count, train duration, pulse width, repetition frequency, and intensity limits before and during treatment. */

        require constraint doseLimits {
            tms.maximumPulseRepetitionFrequency <= 20.0 [SI::hertz] and
            tms.maximumPulseWidth <= 0.0004 [SI::second] and
            tms.maximumSessionPulses <= 3000
        }
    }

    requirement def NonInvasiveCouplingRequirement {
        subject tms : TranscranialMagneticStimulationSystem;

        doc /* The system shall deliver therapeutic energy magnetically across the scalp without implanted electrodes, penetrating skin and skull by electromagnetic induction. */

        require constraint nonInvasiveCoupling {
            tms.patientCouplingVolume.nonInvasiveAirGapAllowed == true and
            tms.patientCouplingVolume.maximumCoilToScalpDistance <= 5.0 [SI::millimetre]
        }
    }

    requirement def TargetingRequirement {
        subject tms : TranscranialMagneticStimulationSystem;

        doc /* The system shall support repeatable positioning of the treatment coil over the prescribed cortical target using tracked pose feedback and shall inhibit delivery when registration error exceeds tolerance. */

        require constraint targetingAccuracy {
            tms.neuronavigation.targetRegistrationErrorLimit <= 3.0 [SI::millimetre]
        }
    }

    requirement def ThermalSafetyRequirement {
        subject tms : TranscranialMagneticStimulationSystem;

        doc /* The system shall monitor coil temperature and stop pulse delivery before the coil surface exceeds the patient-contact thermal limit. */

        require constraint thermalLimit {
            tms.stimulationCoil.maximumSurfaceTemperature <= 41.0 [SI::degreeCelsius] and
            tms.coolingSubsystem.coilShutdownTemperature <= 41.0 [SI::degreeCelsius]
        }
    }

    requirement def ElectricalSafetyRequirement {
        subject tms : TranscranialMagneticStimulationSystem;

        doc /* The system shall isolate mains power, discharge stored energy to a safe level after shutdown, and inhibit high-current pulses when a safety interlock is open. */

        require constraint electricalSafety {
            tms.powerSupply.isolationLeakageCurrentLimit <= 0.0005 [SI::ampere] and
            tms.capacitorBank.safeMaintenanceVoltage <= 50.0 [SI::volt] and
            tms.safeIfInterlockOpened == true
        }
    }

    requirement def EmergencyStopRequirement {
        subject tms : TranscranialMagneticStimulationSystem;

        doc /* The system shall transition to fault-safe shutdown and inhibit pulse generation within the specified reaction time after emergency stop activation by patient, clinician, interlock, or controller fault. */

        require constraint emergencyStopTiming {
            tms.safetySubsystem.emergencyStopReactionTime <= 0.01 [SI::second]
        }
    }

    part tmsClinicalSystem : TranscranialMagneticStimulationSystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject tms = tmsClinicalSystem;
    }

    requirement controlledDose : DoseControlRequirement {
        subject tms = tmsClinicalSystem;
    }

    requirement nonInvasiveEnergyTransfer : NonInvasiveCouplingRequirement {
        subject tms = tmsClinicalSystem;
    }

    requirement corticalTargeting : TargetingRequirement {
        subject tms = tmsClinicalSystem;
    }

    requirement coilThermalProtection : ThermalSafetyRequirement {
        subject tms = tmsClinicalSystem;
    }

    requirement electricalProtection : ElectricalSafetyRequirement {
        subject tms = tmsClinicalSystem;
    }

    requirement emergencyStopProtection : EmergencyStopRequirement {
        subject tms = tmsClinicalSystem;
    }

    satisfy primaryFunction by tmsClinicalSystem;
    satisfy controlledDose by tmsClinicalSystem.safetySubsystem;
    satisfy nonInvasiveEnergyTransfer by tmsClinicalSystem.patientCouplingVolume;
    satisfy corticalTargeting by tmsClinicalSystem.neuronavigation;
    satisfy coilThermalProtection by tmsClinicalSystem.coolingSubsystem;
    satisfy electricalProtection by tmsClinicalSystem.powerSupply;
    satisfy emergencyStopProtection by tmsClinicalSystem.safetySubsystem;
}
