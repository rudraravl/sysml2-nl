package MedTechEuropeConnectedCareModel {

    import ScalarValues::*;
    import SI::*;

    enum def ClinicalPriority {
        enum Informational;
        enum Low;
        enum Medium;
        enum High;
        enum Critical;
    }

    enum def DeviceMode {
        enum Commissioning;
        enum Standby;
        enum Monitoring;
        enum Alarm;
        enum Maintenance;
        enum SafeShutdown;
    }

    enum def ConnectivityState {
        enum Disconnected;
        enum LocalOnly;
        enum CloudConnected;
        enum EHRConnected;
    }

    enum def DataClassification {
        enum Operational;
        enum PersonalHealthData;
        enum SafetyCritical;
        enum Audit;
    }

    enum def RegulatoryRegion {
        enum EuropeanUnion;
        enum UnitedKingdom;
        enum Switzerland;
        enum Norway;
    }

    attribute def HeartRate_bpm :> Real {
        attribute unitSymbol: String = "beat/min";
        attribute minimum: Real = 20.0;
        attribute maximum: Real = 240.0;
    }

    attribute def OxygenSaturation_percent :> Real {
        attribute unitSymbol: String = "%";
        attribute minimum: Real = 0.0;
        attribute maximum: Real = 100.0;
    }

    attribute def Temperature_Celsius :> Real {
        attribute unitSymbol: String = "degC";
        attribute minimum: Real = 25.0;
        attribute maximum: Real = 45.0;
    }

    attribute def Pressure_mmHg :> Real {
        attribute unitSymbol: String = "mmHg";
        attribute minimum: Real = 0.0;
        attribute maximum: Real = 300.0;
    }

    attribute def RespirationRate_perMinute :> Real {
        attribute unitSymbol: String = "breath/min";
        attribute minimum: Real = 0.0;
        attribute maximum: Real = 80.0;
    }

    attribute def Duration_second :> Real {
        attribute unitSymbol: String = "s";
        attribute minimum: Real = 0.0;
    }

    attribute def Latency_millisecond :> Real {
        attribute unitSymbol: String = "ms";
        attribute minimum: Real = 0.0;
    }

    attribute def DataRate_kilobitPerSecond :> Real {
        attribute unitSymbol: String = "kbit/s";
        attribute minimum: Real = 0.0;
    }

    attribute def Energy_wattHour :> Real {
        attribute unitSymbol: String = "W.h";
        attribute minimum: Real = 0.0;
    }

    attribute def Dose_milligram :> Real {
        attribute unitSymbol: String = "mg";
        attribute minimum: Real = 0.0;
    }

    attribute def Percentage :> Real {
        attribute unitSymbol: String = "%";
        attribute minimum: Real = 0.0;
        attribute maximum: Real = 100.0;
    }

    item def Patient {
        attribute patientIdentifier: String;
        attribute consentGranted: Boolean;
        attribute age_year: Integer;
        attribute region: RegulatoryRegion;
    }

    item def Clinician {
        attribute clinicianIdentifier: String;
        attribute role: String;
        attribute authenticated: Boolean;
    }

    item def HeartRateSample {
        attribute value: HeartRate_bpm;
        attribute measuredAtUtc: String;
        attribute confidence: Percentage;
        attribute classification: DataClassification = DataClassification::PersonalHealthData;
    }

    item def SpO2Sample {
        attribute value: OxygenSaturation_percent;
        attribute measuredAtUtc: String;
        attribute confidence: Percentage;
        attribute classification: DataClassification = DataClassification::PersonalHealthData;
    }

    item def TemperatureSample {
        attribute value: Temperature_Celsius;
        attribute measuredAtUtc: String;
        attribute confidence: Percentage;
        attribute classification: DataClassification = DataClassification::PersonalHealthData;
    }

    item def BloodPressureSample {
        attribute systolic: Pressure_mmHg;
        attribute diastolic: Pressure_mmHg;
        attribute meanArterialPressure: Pressure_mmHg;
        attribute measuredAtUtc: String;
        attribute confidence: Percentage;
        attribute classification: DataClassification = DataClassification::PersonalHealthData;
    }

    item def RespirationSample {
        attribute value: RespirationRate_perMinute;
        attribute measuredAtUtc: String;
        attribute confidence: Percentage;
        attribute classification: DataClassification = DataClassification::PersonalHealthData;
    }

    item def VitalSignSet {
        item heartRate: HeartRateSample;
        item oxygenSaturation: SpO2Sample;
        item temperature: TemperatureSample;
        item bloodPressure: BloodPressureSample;
        item respirationRate: RespirationSample;
        attribute patientIdentifier: String;
        attribute acquiredAtUtc: String;
        attribute complete: Boolean;
    }

    item def DeviceStatus {
        attribute deviceIdentifier: String;
        attribute mode: DeviceMode;
        attribute batteryRemaining: Percentage;
        attribute connectivity: ConnectivityState;
        attribute lastSelfTestPassed: Boolean;
        attribute softwareVersion: String;
    }

    item def ClinicalAlert {
        attribute alertIdentifier: String;
        attribute patientIdentifier: String;
        attribute priority: ClinicalPriority;
        attribute reason: String;
        attribute generatedAtUtc: String;
        attribute acknowledged: Boolean;
        item evidence: VitalSignSet;
    }

    item def AuditRecord {
        attribute auditIdentifier: String;
        attribute actorIdentifier: String;
        attribute actionName: String;
        attribute occurredAtUtc: String;
        attribute classification: DataClassification = DataClassification::Audit;
        attribute integrityProtected: Boolean;
    }

    item def EncryptedTelemetryPacket {
        attribute packetIdentifier: String;
        attribute payloadClassification: DataClassification;
        attribute encrypted: Boolean;
        attribute signed: Boolean;
        attribute transmittedAtUtc: String;
        item vitalSigns: VitalSignSet;
        item status: DeviceStatus;
    }

    item def EHRObservationBundle {
        attribute bundleIdentifier: String;
        attribute patientIdentifier: String;
        attribute hl7FhirVersion: String = "R4";
        attribute pseudonymizedForAnalytics: Boolean;
        item observations: VitalSignSet;
    }

    item def CommandMessage {
        attribute commandIdentifier: String;
        attribute issuedBy: String;
        attribute commandName: String;
        attribute issuedAtUtc: String;
        attribute authenticated: Boolean;
    }

    item def Acknowledgement {
        attribute messageIdentifier: String;
        attribute accepted: Boolean;
        attribute reason: String;
        attribute acknowledgedAtUtc: String;
    }

    port def PatientContactPort {
        in item patient: Patient;
        out item heartRate: HeartRateSample;
        out item oxygenSaturation: SpO2Sample;
        out item temperature: TemperatureSample;
        out item bloodPressure: BloodPressureSample;
        out item respiration: RespirationSample;
    }

    port def SensorDataPort {
        out item vitalSigns: VitalSignSet;
        out item deviceStatus: DeviceStatus;
    }

    port def LocalTelemetryPort {
        in item command: CommandMessage;
        out item packet: EncryptedTelemetryPacket;
        in item acknowledgement: Acknowledgement;
    }

    port def CloudTelemetryPort {
        in item packet: EncryptedTelemetryPacket;
        out item acknowledgement: Acknowledgement;
        out item command: CommandMessage;
    }

    port def ClinicianUserPort {
        in item clinician: Clinician;
        out item alert: ClinicalAlert;
        out item observations: EHRObservationBundle;
        in item acknowledgement: Acknowledgement;
        in item command: CommandMessage;
    }

    port def EHRExchangePort {
        out item observationBundle: EHRObservationBundle;
        in item acknowledgement: Acknowledgement;
    }

    port def AuditPort {
        out item auditRecord: AuditRecord;
    }

    constraint def HeartRateValidity {
        in value: HeartRate_bpm;
        constraint validHeartRate {
            value >= 20.0 and value <= 240.0
        }
    }

    constraint def SpO2Validity {
        in value: OxygenSaturation_percent;
        constraint validSpO2 {
            value >= 0.0 and value <= 100.0
        }
    }

    constraint def BloodPressureValidity {
        in systolic: Pressure_mmHg;
        in diastolic: Pressure_mmHg;
        constraint validPressure {
            systolic >= 50.0 and systolic <= 260.0 and diastolic >= 30.0 and diastolic <= 160.0 and systolic > diastolic
        }
    }

    constraint def AlertThresholdPolicy {
        in heartRate: HeartRate_bpm;
        in spo2: OxygenSaturation_percent;
        in temperature: Temperature_Celsius;
        in respiration: RespirationRate_perMinute;
        out priority: ClinicalPriority;
        constraint criticalRule {
            if heartRate < 40.0 or heartRate > 150.0 or spo2 < 88.0 or temperature > 40.0 or respiration > 35.0 then priority == ClinicalPriority::Critical else priority != ClinicalPriority::Critical
        }
    }

    constraint def TelemetryLatencyLimit {
        in latency: Latency_millisecond;
        constraint withinLimit {
            latency <= 5000.0
        }
    }

    action def AcquireVitalSigns {
        in item patient: Patient;
        out item vitalSigns: VitalSignSet;
        out item status: DeviceStatus;
    }

    action def ValidateVitalSigns {
        in item rawVitalSigns: VitalSignSet;
        out item validatedVitalSigns: VitalSignSet;
        out item validationStatus: DeviceStatus;
    }

    action def EncryptAndSignTelemetry {
        in item vitalSigns: VitalSignSet;
        in item status: DeviceStatus;
        out item packet: EncryptedTelemetryPacket;
    }

    action def TransmitTelemetryToCloud {
        in item packet: EncryptedTelemetryPacket;
        out item acknowledgement: Acknowledgement;
        out latency: Latency_millisecond;
    }

    action def AnalyzePatientTrend {
        in item vitalSigns: VitalSignSet;
        out item alert: ClinicalAlert;
    }

    action def PublishObservationToEHR {
        in item vitalSigns: VitalSignSet;
        out item observationBundle: EHRObservationBundle;
        out item acknowledgement: Acknowledgement;
    }

    action def NotifyClinician {
        in item alert: ClinicalAlert;
        in item clinician: Clinician;
        out item acknowledgement: Acknowledgement;
    }

    action def RecordAuditEvidence {
        in actorIdentifier: String;
        in actionName: String;
        out item auditRecord: AuditRecord;
    }

    action def ContinuousRemoteMonitoringWorkflow {
        in item patient: Patient;
        in item clinician: Clinician;
        out item observationBundle: EHRObservationBundle;
        out item alert: ClinicalAlert;
        out item auditRecord: AuditRecord;

        action acquire: AcquireVitalSigns {
            in patient = patient;
        }

        action validate: ValidateVitalSigns {
            in rawVitalSigns = acquire.vitalSigns;
        }

        action protect: EncryptAndSignTelemetry {
            in vitalSigns = validate.validatedVitalSigns;
            in status = validate.validationStatus;
        }

        action transmit: TransmitTelemetryToCloud {
            in packet = protect.packet;
        }

        action analyze: AnalyzePatientTrend {
            in vitalSigns = validate.validatedVitalSigns;
        }

        action publish: PublishObservationToEHR {
            in vitalSigns = validate.validatedVitalSigns;
        }

        action notify: NotifyClinician {
            in alert = analyze.alert;
            in clinician = clinician;
        }

        action audit: RecordAuditEvidence {
            in actorIdentifier = clinician.clinicianIdentifier;
            in actionName = "continuous remote patient monitoring";
        }

        flow publish.observationBundle to observationBundle;
        flow analyze.alert to alert;
        flow audit.auditRecord to auditRecord;
    }

    state def ConnectedCareDeviceStates {
        attribute mode: DeviceMode;

        state unpowered;
        state commissioning;
        state standby;
        state selfTest;
        state monitoring;
        state alarm;
        state maintenance;
        state safeShutdown;

        transition first unpowered;
        transition unpowered to commissioning accept CommandMessage;
        transition commissioning to selfTest accept CommandMessage;
        transition selfTest to standby if mode == DeviceMode::Standby;
        transition standby to monitoring accept Patient;
        transition monitoring to alarm accept ClinicalAlert;
        transition alarm to monitoring accept Acknowledgement;
        transition monitoring to maintenance accept CommandMessage;
        transition maintenance to selfTest accept CommandMessage;
        transition monitoring to safeShutdown if mode == DeviceMode::SafeShutdown;
        transition standby to safeShutdown if mode == DeviceMode::SafeShutdown;
    }

    state def ConnectivityManagerStates {
        attribute connectivity: ConnectivityState;

        state disconnected;
        state localOnly;
        state cloudConnected;
        state ehrConnected;

        transition first disconnected;
        transition disconnected to localOnly accept EncryptedTelemetryPacket;
        transition localOnly to cloudConnected accept Acknowledgement;
        transition cloudConnected to ehrConnected accept EHRObservationBundle;
        transition ehrConnected to cloudConnected accept Acknowledgement;
        transition cloudConnected to localOnly if connectivity == ConnectivityState::LocalOnly;
        transition localOnly to disconnected if connectivity == ConnectivityState::Disconnected;
    }

    part def WearableVitalPatch {
        attribute deviceIdentifier: String;
        attribute batteryCapacity: Energy_wattHour = 3.2;
        attribute nominalSamplingPeriod: Duration_second = 5.0;
        attribute ingressProtectionRating: String = "IP22";
        attribute intendedUseLocation: String = "home, ward, rehabilitation clinic";

        port patientContact: PatientContactPort;
        port sensorData: SensorDataPort;

        exhibit state deviceState: ConnectedCareDeviceStates;

        perform action acquireVitalSigns: AcquireVitalSigns;
    }

    part def BloodPressureCuff {
        attribute deviceIdentifier: String;
        attribute measurementInterval: Duration_second = 900.0;
        attribute cuffPressureLimit: Pressure_mmHg = 260.0;

        port patientContact: PatientContactPort;
        port sensorData: SensorDataPort;

        perform action acquireBloodPressure: AcquireVitalSigns;
    }

    part def BedsideGateway {
        attribute deviceIdentifier: String;
        attribute supportedWirelessProtocols: String = "Bluetooth Low Energy, Wi-Fi, LTE-M";
        attribute minimumTelemetryDataRate: DataRate_kilobitPerSecond = 64.0;
        attribute maximumCloudLatency: Latency_millisecond = 5000.0;

        port sensorIn: SensorDataPort;
        port localTelemetry: LocalTelemetryPort;
        port audit: AuditPort;

        exhibit state connectivityState: ConnectivityManagerStates;

        perform action validateVitalSigns: ValidateVitalSigns;
        perform action protectTelemetry: EncryptAndSignTelemetry;
        perform action transmitTelemetry: TransmitTelemetryToCloud;
        perform action auditGatewayEvent: RecordAuditEvidence;
    }

    part def EuropeanHealthCloudPlatform {
        attribute platformIdentifier: String;
        attribute hostingRegion: RegulatoryRegion = RegulatoryRegion::EuropeanUnion;
        attribute availabilityTarget: Percentage = 99.9;
        attribute encryptionAtRest: Boolean = true;
        attribute encryptionInTransit: Boolean = true;
        attribute clinicalAlgorithmVersion: String = "EU-CC-ALERT-2.1";

        port telemetryIn: CloudTelemetryPort;
        port clinicianOut: ClinicianUserPort;
        port ehrExchange: EHRExchangePort;
        port audit: AuditPort;

        perform action analyzeTrend: AnalyzePatientTrend;
        perform action publishObservation: PublishObservationToEHR;
        perform action auditCloudEvent: RecordAuditEvidence;
    }

    part def ClinicianDashboard {
        attribute applicationIdentifier: String;
        attribute supportedLanguages: String = "English, French, German, Italian, Spanish, Dutch, Swedish";
        attribute maximumAlertDisplayLatency: Latency_millisecond = 3000.0;
        attribute requiresMultiFactorAuthentication: Boolean = true;

        port userInterface: ClinicianUserPort;
        port audit: AuditPort;

        perform action notifyClinician: NotifyClinician;
        perform action auditClinicianEvent: RecordAuditEvidence;
    }

    part def HospitalEHRConnector {
        attribute connectorIdentifier: String;
        attribute interoperabilityStandard: String = "HL7 FHIR R4";
        attribute consentCheckRequired: Boolean = true;
        attribute pseudonymizationForSecondaryUse: Boolean = true;

        port ehrPort: EHRExchangePort;
        port audit: AuditPort;

        perform action publishObservationToEHR: PublishObservationToEHR;
        perform action auditEhrEvent: RecordAuditEvidence;
    }

    part def CybersecurityAndPrivacyService {
        attribute serviceIdentifier: String;
        attribute cryptographicProfile: String = "TLS 1.3, AES-256-GCM, ECDSA P-256";
        attribute dataProtectionMode: String = "GDPR privacy by design and by default";
        attribute vulnerabilityDisclosureProcess: Boolean = true;
        attribute auditRetention_year: Integer = 10;

        port telemetrySecurity: LocalTelemetryPort;
        port audit: AuditPort;

        perform action encryptAndSign: EncryptAndSignTelemetry;
        perform action recordSecurityAudit: RecordAuditEvidence;
    }

    part def ConnectedCareRemotePatientMonitoringSystem {
        attribute systemIdentifier: String = "MTE-CC-RPM-001";
        attribute primaryFunction: String = "Continuously acquire patient vital signs, validate and protect the data, transmit it to European clinical services, alert clinicians to deterioration, and publish interoperable observations to the electronic health record.";
        attribute intendedMedicalPurpose: String = "Remote physiological monitoring supporting early clinical review without replacing clinician judgement.";
        attribute marketContext: String = "Designed for deployment by European healthcare providers in alignment with MedTech Europe principles for patient safety, innovation, interoperability, data protection, and responsible access to care.";
        attribute regulatoryRegion: RegulatoryRegion = RegulatoryRegion::EuropeanUnion;
        attribute medicalDeviceRiskClass: String = "EU MDR Class IIa";
        attribute gdprSpecialCategoryDataProcessed: Boolean = true;
        attribute supportedPrimaryFunction: Boolean = true;

        part wearablePatch: WearableVitalPatch;
        part bloodPressureCuff: BloodPressureCuff;
        part gateway: BedsideGateway;
        part cloudPlatform: EuropeanHealthCloudPlatform;
        part dashboard: ClinicianDashboard;
        part ehrConnector: HospitalEHRConnector;
        part securityService: CybersecurityAndPrivacyService;

        port patientInterface: PatientContactPort;
        port clinicianInterface: ClinicianUserPort;
        port ehrInterface: EHRExchangePort;
        port auditOutput: AuditPort;

        connect patientInterface to wearablePatch.patientContact;
        connect patientInterface to bloodPressureCuff.patientContact;
        connect wearablePatch.sensorData to gateway.sensorIn;
        connect bloodPressureCuff.sensorData to gateway.sensorIn;
        connect gateway.localTelemetry to securityService.telemetrySecurity;
        connect gateway.localTelemetry to cloudPlatform.telemetryIn;
        connect cloudPlatform.clinicianOut to dashboard.userInterface;
        connect dashboard.userInterface to clinicianInterface;
        connect cloudPlatform.ehrExchange to ehrConnector.ehrPort;
        connect ehrConnector.ehrPort to ehrInterface;
        connect gateway.audit to auditOutput;
        connect cloudPlatform.audit to auditOutput;
        connect dashboard.audit to auditOutput;
        connect ehrConnector.audit to auditOutput;
        connect securityService.audit to auditOutput;

        exhibit state deviceLifecycle: ConnectedCareDeviceStates;
        exhibit state connectivityLifecycle: ConnectivityManagerStates;

        perform action primaryMonitoringWorkflow: ContinuousRemoteMonitoringWorkflow;
    }

    requirement def PrimaryFunctionRequirement {
        subject system: ConnectedCareRemotePatientMonitoringSystem;

        require constraint primaryFunctionExists {
            system.supportedPrimaryFunction == true
        }

        doc /* The system shall provide a high-level primary function of continuous remote patient monitoring for European care settings by collecting vital signs, validating measurements, protecting personal health data, alerting clinicians, and sharing observations with an electronic health record. */
    }

    requirement def PatientSafetyRequirement {
        subject system: ConnectedCareRemotePatientMonitoringSystem;

        require constraint medicalPurposeDeclared {
            system.medicalDeviceRiskClass == "EU MDR Class IIa"
        }

        doc /* The system shall be designed for patient safety and shall support clinical review without autonomously making irreversible clinical treatment decisions. */
    }

    requirement def VitalSignCompletenessRequirement {
        subject vitalSigns: VitalSignSet;

        require constraint completeVitals {
            vitalSigns.complete == true
        }

        doc /* Each monitoring cycle shall include heart rate, oxygen saturation, temperature, blood pressure, and respiration rate or shall identify the set as incomplete. */
    }

    requirement def TelemetrySecurityRequirement {
        subject packet: EncryptedTelemetryPacket;

        require constraint protectedTelemetry {
            packet.encrypted == true and packet.signed == true
        }

        doc /* Personal health telemetry shall be encrypted and integrity protected before leaving the local gateway. */
    }

    requirement def EuropeanDataProtectionRequirement {
        subject system: ConnectedCareRemotePatientMonitoringSystem;

        require constraint gdprHealthData {
            system.gdprSpecialCategoryDataProcessed == true and system.regulatoryRegion == RegulatoryRegion::EuropeanUnion
        }

        doc /* The system shall process special-category personal health data according to European privacy-by-design expectations. */
    }

    requirement def InteroperabilityRequirement {
        subject connector: HospitalEHRConnector;

        require constraint fhirRequired {
            connector.interoperabilityStandard == "HL7 FHIR R4"
        }

        doc /* Observations shall be exchanged with hospital information systems using an interoperable HL7 FHIR R4 representation. */
    }

    requirement def ClinicalAlertRequirement {
        subject alert: ClinicalAlert;

        require constraint criticalAcknowledgementRequired {
            if alert.priority == ClinicalPriority::Critical then alert.acknowledged == true else true
        }

        doc /* Critical alerts shall require clinician acknowledgement. */
    }

    requirement def LatencyRequirement {
        subject gateway: BedsideGateway;

        require constraint cloudLatency {
            gateway.maximumCloudLatency <= 5000.0
        }

        doc /* Validated safety-relevant telemetry shall be made available to the cloud service within five seconds under nominal connectivity. */
    }

    requirement def AuditabilityRequirement {
        subject record: AuditRecord;

        require constraint auditIntegrity {
            record.integrityProtected == true
        }

        doc /* Safety-relevant access, transmission, alert, and EHR publication events shall produce integrity-protected audit records. */
    }

    requirement def UsabilityRequirement {
        subject dashboard: ClinicianDashboard;

        require constraint displayLatency {
            dashboard.maximumAlertDisplayLatency <= 3000.0 and dashboard.requiresMultiFactorAuthentication == true
        }

        doc /* The clinician dashboard shall display high-priority alerts promptly and require strong user authentication. */
    }

    part medTechEuropeConnectedCareSystem: ConnectedCareRemotePatientMonitoringSystem;

    requirement primaryFunction: PrimaryFunctionRequirement {
        subject system = medTechEuropeConnectedCareSystem;
    }

    requirement patientSafety: PatientSafetyRequirement {
        subject system = medTechEuropeConnectedCareSystem;
    }

    requirement telemetryLatency: LatencyRequirement {
        subject gateway = medTechEuropeConnectedCareSystem.gateway;
    }

    requirement interoperability: InteroperabilityRequirement {
        subject connector = medTechEuropeConnectedCareSystem.ehrConnector;
    }

    requirement usability: UsabilityRequirement {
        subject dashboard = medTechEuropeConnectedCareSystem.dashboard;
    }

}
