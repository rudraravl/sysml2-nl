package MedicalIndustrySmartInfusionTherapySystem {

    import ScalarValues::*;

    unit def milliliter {
        attribute symbol : String = "mL";
        attribute dimension : String = "volume";
        attribute siConversionFactor : Real = 0.000001;
        attribute siUnit : String = "m^3";
    }

    unit def hour {
        attribute symbol : String = "h";
        attribute dimension : String = "time";
        attribute siConversionFactor : Real = 3600.0;
        attribute siUnit : String = "s";
    }

    unit def minute {
        attribute symbol : String = "min";
        attribute dimension : String = "time";
        attribute siConversionFactor : Real = 60.0;
        attribute siUnit : String = "s";
    }

    unit def milligram {
        attribute symbol : String = "mg";
        attribute dimension : String = "mass";
        attribute siConversionFactor : Real = 0.000001;
        attribute siUnit : String = "kg";
    }

    unit def kilopascal {
        attribute symbol : String = "kPa";
        attribute dimension : String = "pressure";
        attribute siConversionFactor : Real = 1000.0;
        attribute siUnit : String = "Pa";
    }

    unit def percent {
        attribute symbol : String = "%";
        attribute dimension : String = "ratio";
        attribute siConversionFactor : Real = 0.01;
        attribute siUnit : String = "1";
    }

    unit def wattHour {
        attribute symbol : String = "Wh";
        attribute dimension : String = "energy";
        attribute siConversionFactor : Real = 3600.0;
        attribute siUnit : String = "J";
    }

    unit def volt {
        attribute symbol : String = "V";
        attribute dimension : String = "electric potential";
        attribute siConversionFactor : Real = 1.0;
        attribute siUnit : String = "V";
    }

    unit def beatsPerMinute {
        attribute symbol : String = "bpm";
        attribute dimension : String = "frequency";
        attribute siConversionFactor : Real = 0.0166667;
        attribute siUnit : String = "Hz";
    }

    unit def millimeterMercury {
        attribute symbol : String = "mmHg";
        attribute dimension : String = "pressure";
        attribute siConversionFactor : Real = 133.322;
        attribute siUnit : String = "Pa";
    }

    attribute def Volume_mL :> Real {
        attribute unit : String = "mL";
        attribute minimum : Real = 0.0;
    }

    attribute def FlowRate_mL_per_h :> Real {
        attribute unit : String = "mL/h";
        attribute minimum : Real = 0.0;
    }

    attribute def Dose_mg :> Real {
        attribute unit : String = "mg";
        attribute minimum : Real = 0.0;
    }

    attribute def DoseRate_mg_per_h :> Real {
        attribute unit : String = "mg/h";
        attribute minimum : Real = 0.0;
    }

    attribute def Pressure_kPa :> Real {
        attribute unit : String = "kPa";
    }

    attribute def BatteryEnergy_Wh :> Real {
        attribute unit : String = "Wh";
        attribute minimum : Real = 0.0;
    }

    attribute def Voltage_V :> Real {
        attribute unit : String = "V";
        attribute minimum : Real = 0.0;
    }

    attribute def Duration_min :> Real {
        attribute unit : String = "min";
        attribute minimum : Real = 0.0;
    }

    attribute def Percentage :> Real {
        attribute unit : String = "%";
        attribute minimum : Real = 0.0;
        attribute maximum : Real = 100.0;
    }

    attribute def HeartRate_bpm :> Real {
        attribute unit : String = "bpm";
        attribute minimum : Real = 0.0;
    }

    attribute def BloodPressure_mmHg :> Real {
        attribute unit : String = "mmHg";
        attribute minimum : Real = 0.0;
    }

    attribute def OxygenSaturation_percent :> Real {
        attribute unit : String = "%";
        attribute minimum : Real = 0.0;
        attribute maximum : Real = 100.0;
    }

    enum def TherapyMode {
        enum continuous;
        enum intermittent;
        enum patientControlledAnalgesia;
        enum keepVeinOpen;
        enum loadingDose;
    }

    enum def AlarmSeverity {
        enum advisory;
        enum caution;
        enum critical;
    }

    enum def FluidPathIntegrity {
        enum intact;
        enum airDetected;
        enum upstreamOcclusion;
        enum downstreamOcclusion;
        enum doorOpen;
        enum lineDisconnected;
    }

    enum def UserRole {
        enum nurse;
        enum physician;
        enum pharmacist;
        enum biomedicalEngineer;
        enum patient;
    }

    enum def NetworkSecurityState {
        enum disconnected;
        enum authenticated;
        enum encrypted;
        enum compromised;
    }

    item def PatientIdentifier {
        attribute medicalRecordNumber : String;
        attribute encounterIdentifier : String;
        attribute dateOfBirthISO8601 : String;
    }

    item def MedicationFluid {
        attribute medicationName : String;
        attribute concentration_mg_per_mL : Real;
        attribute diluent : String;
        attribute totalVolume : Volume_mL;
        attribute remainingVolume : Volume_mL;
        attribute lotNumber : String;
        attribute expirationISO8601 : String;
        attribute isHighAlertMedication : Boolean;
    }

    item def InfusionPrescription {
        attribute orderIdentifier : String;
        attribute patient : PatientIdentifier;
        attribute medicationName : String;
        attribute therapyMode : TherapyMode;
        attribute prescribedDose : Dose_mg;
        attribute prescribedDoseRate : DoseRate_mg_per_h;
        attribute prescribedFlowRate : FlowRate_mL_per_h;
        attribute volumeToBeInfused : Volume_mL;
        attribute lockoutInterval : Duration_min;
        attribute maximumDosePerHour : Dose_mg;
        attribute prescribingClinician : String;
        attribute verifiedByPharmacist : Boolean;
    }

    item def PumpCommand {
        attribute commandIdentifier : String;
        attribute requestedMode : TherapyMode;
        attribute targetRate : FlowRate_mL_per_h;
        attribute targetVolume : Volume_mL;
        attribute commandTimeISO8601 : String;
        attribute commandedBy : UserRole;
    }

    item def PumpStatus {
        attribute currentRate : FlowRate_mL_per_h;
        attribute infusedVolume : Volume_mL;
        attribute remainingVolume : Volume_mL;
        attribute linePressure : Pressure_kPa;
        attribute batteryStateOfCharge : Percentage;
        attribute fluidPathIntegrity : FluidPathIntegrity;
        attribute activeAlarmCount : Integer;
        attribute isInfusing : Boolean;
    }

    item def SensorMeasurement {
        attribute measurementIdentifier : String;
        attribute measuredPressure : Pressure_kPa;
        attribute detectedAirVolume : Volume_mL;
        attribute doorClosed : Boolean;
        attribute upstreamFlowPresent : Boolean;
        attribute downstreamFlowPresent : Boolean;
        attribute measurementTimeISO8601 : String;
    }

    item def PatientPhysiologyData {
        attribute patient : PatientIdentifier;
        attribute heartRate : HeartRate_bpm;
        attribute systolicBloodPressure : BloodPressure_mmHg;
        attribute diastolicBloodPressure : BloodPressure_mmHg;
        attribute oxygenSaturation : OxygenSaturation_percent;
        attribute painScore0To10 : Integer;
        attribute observationTimeISO8601 : String;
    }

    item def AlarmNotification {
        attribute alarmIdentifier : String;
        attribute severity : AlarmSeverity;
        attribute alarmCode : String;
        attribute message : String;
        attribute audibleRequired : Boolean;
        attribute visualRequired : Boolean;
        attribute stopInfusionRequired : Boolean;
        attribute alarmTimeISO8601 : String;
    }

    item def TherapyRecord {
        attribute recordIdentifier : String;
        attribute patient : PatientIdentifier;
        attribute medicationName : String;
        attribute programmedRate : FlowRate_mL_per_h;
        attribute programmedVolume : Volume_mL;
        attribute deliveredVolume : Volume_mL;
        attribute deliveredDose : Dose_mg;
        attribute startTimeISO8601 : String;
        attribute stopTimeISO8601 : String;
        attribute completionStatus : String;
        attribute alarmSummary : String;
    }

    item def AuditEvent {
        attribute eventIdentifier : String;
        attribute eventTimeISO8601 : String;
        attribute actorRole : UserRole;
        attribute actorIdentifier : String;
        attribute eventType : String;
        attribute eventDetails : String;
        attribute integrityHash : String;
    }

    item def NetworkMessage {
        attribute messageIdentifier : String;
        attribute sourceSystem : String;
        attribute destinationSystem : String;
        attribute payloadType : String;
        attribute encrypted : Boolean;
        attribute authenticated : Boolean;
        attribute payloadDigest : String;
    }

    port def MedicationFluidInPort {
        in item fluid : MedicationFluid;
        attribute inletPressure : Pressure_kPa;
    }

    port def MedicationFluidOutPort {
        out item fluid : MedicationFluid;
        attribute outletPressure : Pressure_kPa;
    }

    port def PatientIVAccessPort {
        in item infusedFluid : MedicationFluid;
        out item physiology : PatientPhysiologyData;
        attribute venousBackPressure : Pressure_kPa;
    }

    port def PrescriptionInputPort {
        in item prescription : InfusionPrescription;
    }

    port def CommandInputPort {
        in item command : PumpCommand;
    }

    port def CommandOutputPort {
        out item command : PumpCommand;
    }

    port def StatusInputPort {
        in item status : PumpStatus;
    }

    port def StatusOutputPort {
        out item status : PumpStatus;
    }

    port def SensorInputPort {
        in item measurement : SensorMeasurement;
    }

    port def SensorOutputPort {
        out item measurement : SensorMeasurement;
    }

    port def AlarmInputPort {
        in item alarm : AlarmNotification;
    }

    port def AlarmOutputPort {
        out item alarm : AlarmNotification;
    }

    port def TherapyRecordOutputPort {
        out item record : TherapyRecord;
    }

    port def AuditEventOutputPort {
        out item event : AuditEvent;
    }

    port def NetworkPort {
        in item inboundMessage : NetworkMessage;
        out item outboundMessage : NetworkMessage;
        attribute securityState : NetworkSecurityState;
    }

    port def PowerInputPort {
        in attribute supplyVoltage : Voltage_V;
        in attribute availableEnergy : BatteryEnergy_Wh;
    }

    port def PowerOutputPort {
        out attribute supplyVoltage : Voltage_V;
        out attribute availableEnergy : BatteryEnergy_Wh;
    }

    port def UserInteractionPort {
        in item prescription : InfusionPrescription;
        in item userCommand : PumpCommand;
        out item status : PumpStatus;
        out item alarm : AlarmNotification;
        attribute authenticatedUserRole : UserRole;
    }

    interface def MedicationFlowInterface {
        end source : MedicationFluidOutPort;
        end destination : MedicationFluidInPort;
    }

    interface def IVDeliveryInterface {
        end source : MedicationFluidOutPort;
        end patientAccess : PatientIVAccessPort;
    }

    interface def CommandInterface {
        end controller : CommandOutputPort;
        end actuator : CommandInputPort;
    }

    interface def StatusInterface {
        end producer : StatusOutputPort;
        end consumer : StatusInputPort;
    }

    interface def SensorInterface {
        end sensor : SensorOutputPort;
        end controller : SensorInputPort;
    }

    interface def AlarmInterface {
        end producer : AlarmOutputPort;
        end annunciator : AlarmInputPort;
    }

    constraint def DoseAccuracyConstraint {
        in prescribedVolume : Volume_mL;
        in deliveredVolume : Volume_mL;
        in maximumErrorPercent : Percentage;
        attribute absoluteError : Real;
        assert constraint {
            deliveredVolume >= prescribedVolume * (1.0 - maximumErrorPercent / 100.0) and
            deliveredVolume <= prescribedVolume * (1.0 + maximumErrorPercent / 100.0)
        }
    }

    constraint def OcclusionPressureConstraint {
        in measuredPressure : Pressure_kPa;
        in occlusionThreshold : Pressure_kPa;
        assert constraint {
            measuredPressure < occlusionThreshold
        }
    }

    constraint def AirInLineConstraint {
        in detectedAirVolume : Volume_mL;
        in maximumAllowedAirVolume : Volume_mL;
        assert constraint {
            detectedAirVolume <= maximumAllowedAirVolume
        }
    }

    constraint def BatteryReserveConstraint {
        in stateOfCharge : Percentage;
        in minimumReserve : Percentage;
        assert constraint {
            stateOfCharge >= minimumReserve
        }
    }

    action def ValidatePrescription {
        in prescription : InfusionPrescription;
        out accepted : Boolean;
        out validationMessage : String;

        action verifyPatientMatch;
        action verifyMedicationConcentration;
        action verifyDoseLimits;
        action verifyPharmacyReview;
        action verifyTherapyMode;
        action computeSafeFlowRate;

        first verifyPatientMatch then verifyMedicationConcentration;
        then verifyDoseLimits;
        then verifyPharmacyReview;
        then verifyTherapyMode;
        then computeSafeFlowRate;
    }

    action def PrimeFluidPath {
        in reservoirFluid : MedicationFluid;
        out primed : Boolean;
        out primingVolume : Volume_mL;

        action openCassettePath;
        action moveAirTowardOutlet;
        action senseAirClearance;
        action stopBeforePatientConnection;

        first openCassettePath then moveAirTowardOutlet;
        then senseAirClearance;
        then stopBeforePatientConnection;
    }

    action def DeliverMedicationTherapy {
        in prescription : InfusionPrescription;
        in currentStatus : PumpStatus;
        out record : TherapyRecord;
        out alarm : AlarmNotification;

        action authenticateClinician;
        action loadMedicationContainer;
        action validatePrescription;
        action primeFluidPath;
        action startControlledPumping;
        action monitorPressureAndAir;
        action regulateFlowRate;
        action updateTherapyRecord;
        action completeOrStopTherapy;

        first authenticateClinician then loadMedicationContainer;
        then validatePrescription;
        then primeFluidPath;
        then startControlledPumping;
        then monitorPressureAndAir;
        then regulateFlowRate;
        then updateTherapyRecord;
        then completeOrStopTherapy;
    }

    action def MonitorSafety {
        in measurement : SensorMeasurement;
        in status : PumpStatus;
        out alarm : AlarmNotification;
        out safeToContinue : Boolean;

        action checkDoorClosed;
        action checkAirInLine;
        action checkOcclusion;
        action checkBatteryReserve;
        action checkUnintendedFlow;
        action commandSafeStopIfNeeded;

        first checkDoorClosed then checkAirInLine;
        then checkOcclusion;
        then checkBatteryReserve;
        then checkUnintendedFlow;
        then commandSafeStopIfNeeded;
    }

    action def CommunicateWithClinicalSystems {
        in record : TherapyRecord;
        out auditEvent : AuditEvent;
        out outboundMessage : NetworkMessage;

        action encryptPayload;
        action authenticateEndpoint;
        action transmitTherapyRecordToEHR;
        action receiveMedicationOrderUpdate;
        action logCommunicationEvent;

        first encryptPayload then authenticateEndpoint;
        then transmitTherapyRecordToEHR;
        then receiveMedicationOrderUpdate;
        then logCommunicationEvent;
    }

    state def InfusionControllerLifecycle {
        state off;
        state powerOnSelfTest;
        state ready;
        state programming;
        state prescriptionValidated;
        state priming;
        state infusing;
        state paused;
        state alarmed;
        state therapyComplete;
        state safeShutdown;

        transition initial then off;
        transition powerApplied first off then powerOnSelfTest;
        transition selfTestPassed first powerOnSelfTest then ready;
        transition clinicianStartsProgramming first ready then programming;
        transition prescriptionAccepted first programming then prescriptionValidated;
        transition primeRequested first prescriptionValidated then priming;
        transition primeComplete first priming then ready;
        transition startInfusion first ready then infusing;
        transition pauseRequested first infusing then paused;
        transition resumeRequested first paused then infusing;
        transition alarmDetected first infusing then alarmed;
        transition alarmAcknowledgedAndResolved first alarmed then ready;
        transition volumeDelivered first infusing then therapyComplete;
        transition shutdownRequested first ready then safeShutdown;
        transition emergencyStop first programming then alarmed;
        transition emergencyStopWhileInfusing first infusing then alarmed;
    }

    part def MedicationReservoir {
        attribute maximumVolume : Volume_mL = 500.0;
        attribute currentVolume : Volume_mL = 250.0;
        attribute minimumUsableVolume : Volume_mL = 5.0;
        attribute medicationLabelReadable : Boolean = true;

        port fillPort : MedicationFluidInPort;
        port outlet : MedicationFluidOutPort;
        port statusOut : StatusOutputPort;
    }

    part def PeristalticPumpMechanism {
        attribute minimumRate : FlowRate_mL_per_h = 0.1;
        attribute maximumRate : FlowRate_mL_per_h = 1200.0;
        attribute commandedRate : FlowRate_mL_per_h = 0.0;
        attribute deliveredVolume : Volume_mL = 0.0;
        attribute motorVoltage : Voltage_V = 12.0;

        port inlet : MedicationFluidInPort;
        port outlet : MedicationFluidOutPort;
        port commandIn : CommandInputPort;
        port statusOut : StatusOutputPort;
        port powerIn : PowerInputPort;

        perform action regulateFlow : DeliverMedicationTherapy;
    }

    part def FluidPathSensorSet {
        attribute airBubbleDetectionLimit : Volume_mL = 0.05;
        attribute downstreamOcclusionPressureThreshold : Pressure_kPa = 120.0;
        attribute upstreamOcclusionPressureThreshold : Pressure_kPa = -20.0;
        attribute nominalLinePressure : Pressure_kPa = 35.0;

        port fluidIn : MedicationFluidInPort;
        port fluidOut : MedicationFluidOutPort;
        port measurementOut : SensorOutputPort;
        port powerIn : PowerInputPort;

        perform action monitorSafety : MonitorSafety;
    }

    part def InfusionController {
        attribute firmwareVersion : String = "7.4.2";
        attribute maximumDoseErrorAllowed : Percentage = 5.0;
        attribute maxSingleAirBubbleVolume : Volume_mL = 0.10;
        attribute occlusionPressureLimit : Pressure_kPa = 120.0;
        attribute minimumBatteryReserve : Percentage = 15.0;
        attribute prescriptionAccepted : Boolean = false;

        port prescriptionIn : PrescriptionInputPort;
        port sensorIn : SensorInputPort;
        port pumpStatusIn : StatusInputPort;
        port patientDataIn : SensorInputPort;
        port commandOut : CommandOutputPort;
        port alarmOut : AlarmOutputPort;
        port recordOut : TherapyRecordOutputPort;
        port auditOut : AuditEventOutputPort;
        port network : NetworkPort;
        port powerIn : PowerInputPort;

        exhibit state lifecycle : InfusionControllerLifecycle;

        perform action validateOrder : ValidatePrescription;
        perform action administerTherapy : DeliverMedicationTherapy;
        perform action monitorSafety : MonitorSafety;
        perform action communicate : CommunicateWithClinicalSystems;
    }

    part def ClinicianUserInterface {
        attribute displaySizeInches : Real = 7.0;
        attribute supportsBarcodeMedicationAdministration : Boolean = true;
        attribute supportsTwoFactorAuthentication : Boolean = true;
        attribute audibleAlarmSoundLevel_dBA : Real = 75.0;

        port clinicianInteraction : UserInteractionPort;
        port prescriptionOut : PrescriptionInputPort;
        port commandOut : CommandOutputPort;
        port statusIn : StatusInputPort;
        port alarmIn : AlarmInputPort;
        port powerIn : PowerInputPort;
    }

    part def AlarmAnnunciator {
        attribute maximumSoundLevel_dBA : Real = 85.0;
        attribute visualAlarmColorCritical : String = "red";
        attribute visualAlarmColorCaution : String = "amber";
        attribute alarmSilenceDuration : Duration_min = 2.0;

        port alarmIn : AlarmInputPort;
        port powerIn : PowerInputPort;
    }

    part def BatteryPowerSubsystem {
        attribute nominalVoltage : Voltage_V = 14.4;
        attribute fullChargeEnergy : BatteryEnergy_Wh = 96.0;
        attribute currentEnergy : BatteryEnergy_Wh = 82.0;
        attribute stateOfCharge : Percentage = 85.0;
        attribute minimumOperatingVoltage : Voltage_V = 11.0;

        port powerOutController : PowerOutputPort;
        port powerOutPump : PowerOutputPort;
        port powerOutSensors : PowerOutputPort;
        port powerOutUI : PowerOutputPort;
        port powerOutAlarm : PowerOutputPort;
    }

    part def ClinicalNetworkGateway {
        attribute deviceIdentifier : String = "INF-PUMP-ICU-042";
        attribute supportsHL7FHIR : Boolean = true;
        attribute supportsTLS13 : Boolean = true;
        attribute securityState : NetworkSecurityState = NetworkSecurityState::encrypted;

        port controllerNetwork : NetworkPort;
        port hospitalNetwork : NetworkPort;
        port auditOut : AuditEventOutputPort;
    }

    part def Patient {
        attribute assignedCareArea : String = "Intensive Care Unit";
        attribute venousAccessType : String = "peripheral IV catheter";
        attribute baselineHeartRate : HeartRate_bpm = 82.0;
        attribute baselineSystolicPressure : BloodPressure_mmHg = 118.0;
        attribute baselineDiastolicPressure : BloodPressure_mmHg = 72.0;
        attribute baselineOxygenSaturation : OxygenSaturation_percent = 98.0;

        port ivAccess : PatientIVAccessPort;
        port physiologyOut : SensorOutputPort;
    }

    part def ElectronicHealthRecordSystem {
        attribute systemName : String = "Hospital EHR";
        attribute supportsMedicationAdministrationRecord : Boolean = true;
        attribute requiresAuthenticatedDevice : Boolean = true;

        port clinicalNetwork : NetworkPort;
    }

    part def SmartInfusionTherapySystem {
        doc /* 
        Primary high-level function: safely deliver a prescribed medication fluid to a patient through an intravenous line at a controlled rate and volume, while continuously monitoring therapy conditions, detecting hazards, alarming caregivers, and recording therapy data for clinical documentation.
        */

        attribute systemName : String = "Smart Infusion Therapy System";
        attribute intendedMedicalIndustryDomain : String = "acute-care medication infusion";
        attribute primaryFunction : String = "controlled intravenous medication delivery with continuous safety monitoring";
        attribute supportsPrimaryFunction : Boolean = true;
        attribute maximumSupportedReservoirVolume : Volume_mL = 500.0;
        attribute minimumProgrammableRate : FlowRate_mL_per_h = 0.1;
        attribute maximumProgrammableRate : FlowRate_mL_per_h = 1200.0;
        attribute targetDoseAccuracy : Percentage = 5.0;
        attribute targetAirBubbleLimit : Volume_mL = 0.10;
        attribute targetOcclusionDetectionPressure : Pressure_kPa = 120.0;
        attribute commandedVolume : Volume_mL = 100.0;
        attribute deliveredVolume : Volume_mL = 100.0;

        part reservoir : MedicationReservoir;
        part pumpMechanism : PeristalticPumpMechanism;
        part sensorSet : FluidPathSensorSet;
        part controller : InfusionController;
        part userInterface : ClinicianUserInterface;
        part alarmAnnunciator : AlarmAnnunciator;
        part powerSubsystem : BatteryPowerSubsystem;
        part gateway : ClinicalNetworkGateway;
        part patient : Patient;
        part ehr : ElectronicHealthRecordSystem;

        port medicationFill : MedicationFluidInPort;
        port clinicianPort : UserInteractionPort;
        port hospitalNetworkPort : NetworkPort;
        port patientIVPort : PatientIVAccessPort;

        connect medicationFill to reservoir.fillPort;
        connect reservoir.outlet to pumpMechanism.inlet;
        connect pumpMechanism.outlet to sensorSet.fluidIn;
        connect sensorSet.fluidOut to patient.ivAccess;

        connect controller.commandOut to pumpMechanism.commandIn;
        connect pumpMechanism.statusOut to controller.pumpStatusIn;
        connect sensorSet.measurementOut to controller.sensorIn;
        connect patient.physiologyOut to controller.patientDataIn;

        connect userInterface.prescriptionOut to controller.prescriptionIn;
        connect userInterface.commandOut to pumpMechanism.commandIn;
        connect pumpMechanism.statusOut to userInterface.statusIn;
        connect controller.alarmOut to userInterface.alarmIn;
        connect controller.alarmOut to alarmAnnunciator.alarmIn;

        connect controller.network to gateway.controllerNetwork;
        connect gateway.hospitalNetwork to ehr.clinicalNetwork;
        connect hospitalNetworkPort to gateway.hospitalNetwork;

        connect powerSubsystem.powerOutController to controller.powerIn;
        connect powerSubsystem.powerOutPump to pumpMechanism.powerIn;
        connect powerSubsystem.powerOutSensors to sensorSet.powerIn;
        connect powerSubsystem.powerOutUI to userInterface.powerIn;
        connect powerSubsystem.powerOutAlarm to alarmAnnunciator.powerIn;

        connect clinicianPort to userInterface.clinicianInteraction;
        connect patientIVPort to patient.ivAccess;

        perform action highLevelTherapyFunction : DeliverMedicationTherapy;
        perform action continuousSafetyMonitoring : MonitorSafety;
        perform action clinicalDocumentationExchange : CommunicateWithClinicalSystems;

        assert constraint doseAccuracy : DoseAccuracyConstraint {
            in prescribedVolume = commandedVolume;
            in deliveredVolume = deliveredVolume;
            in maximumErrorPercent = targetDoseAccuracy;
        }

        assert constraint airSafety : AirInLineConstraint {
            in detectedAirVolume = 0.02;
            in maximumAllowedAirVolume = targetAirBubbleLimit;
        }

        assert constraint occlusionSafety : OcclusionPressureConstraint {
            in measuredPressure = 35.0;
            in occlusionThreshold = targetOcclusionDetectionPressure;
        }

        assert constraint batteryReserve : BatteryReserveConstraint {
            in stateOfCharge = powerSubsystem.stateOfCharge;
            in minimumReserve = 15.0;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide controlled intravenous delivery of prescribed medication fluid to a patient at the programmed rate and volume while supporting clinical supervision. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.supportsPrimaryFunction == true and
            system.minimumProgrammableRate <= 0.1 and
            system.maximumProgrammableRate >= 1200.0
        }
    }

    requirement def DoseAccuracyRequirement {
        doc /* During normal operating conditions, the delivered volume shall remain within plus or minus five percent of the prescribed volume. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.deliveredVolume >= system.commandedVolume * 0.95 and
            system.deliveredVolume <= system.commandedVolume * 1.05
        }
    }

    requirement def AirInLineSafetyRequirement {
        doc /* The system shall detect air in the infusion line and prevent infusion when detected air exceeds the configured safety limit. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.targetAirBubbleLimit <= 0.10
        }
    }

    requirement def OcclusionDetectionRequirement {
        doc /* The system shall detect downstream occlusion using line pressure monitoring and generate a critical alarm when the pressure limit is exceeded. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.targetOcclusionDetectionPressure <= 120.0
        }
    }

    requirement def AlarmRequirement {
        doc /* The system shall provide audible and visual alarms for critical infusion hazards including occlusion, air in line, door open, depleted reservoir, low battery, and unauthorized programming. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.alarmAnnunciator.maximumSoundLevel_dBA >= 75.0
        }
    }

    requirement def BatteryOperationRequirement {
        doc /* The system shall maintain sufficient battery reserve to support controlled therapy interruption and safe shutdown when external power is unavailable. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.powerSubsystem.stateOfCharge >= system.controller.minimumBatteryReserve
        }
    }

    requirement def ClinicalDocumentationRequirement {
        doc /* The system shall record medication delivery history, alarms, clinician interactions, and therapy completion status for transfer to the electronic health record. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.gateway.supportsHL7FHIR == true and
            system.ehr.supportsMedicationAdministrationRecord == true
        }
    }

    requirement def CybersecurityRequirement {
        doc /* The system shall authenticate clinical network endpoints and encrypt medication order and therapy record messages. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.gateway.supportsTLS13 == true and
            system.gateway.securityState == NetworkSecurityState::encrypted
        }
    }

    requirement def UsabilityRequirement {
        doc /* The system shall support authenticated clinician programming and barcode-assisted medication verification to reduce medication administration errors. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.userInterface.supportsBarcodeMedicationAdministration == true and
            system.userInterface.supportsTwoFactorAuthentication == true
        }
    }

    requirement def PatientSafetyMonitoringRequirement {
        doc /* The system shall continuously monitor fluid path integrity and patient physiology data interfaces during active infusion. */
        subject system : SmartInfusionTherapySystem;
        require constraint {
            system.sensorSet.airBubbleDetectionLimit <= system.targetAirBubbleLimit and
            system.sensorSet.downstreamOcclusionPressureThreshold <= system.targetOcclusionDetectionPressure
        }
    }

    part smartInfusionTherapySystem : SmartInfusionTherapySystem;

    satisfy PrimaryFunctionRequirement by smartInfusionTherapySystem;
    satisfy DoseAccuracyRequirement by smartInfusionTherapySystem;
    satisfy AirInLineSafetyRequirement by smartInfusionTherapySystem;
    satisfy OcclusionDetectionRequirement by smartInfusionTherapySystem;
    satisfy AlarmRequirement by smartInfusionTherapySystem;
    satisfy BatteryOperationRequirement by smartInfusionTherapySystem;
    satisfy ClinicalDocumentationRequirement by smartInfusionTherapySystem;
    satisfy CybersecurityRequirement by smartInfusionTherapySystem;
    satisfy UsabilityRequirement by smartInfusionTherapySystem;
    satisfy PatientSafetyMonitoringRequirement by smartInfusionTherapySystem;
}
