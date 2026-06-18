package EPL2ObservabilityGatewayModel {

    enum def LicenseIdentifier {
        enum EPL_2_0;
        enum Apache_2_0;
        enum MIT;
        enum Proprietary;
    }

    enum def LicenseCompatibilityDecision {
        enum Accepted;
        enum Rejected;
        enum RequiresLegalReview;
    }

    enum def HealthState {
        enum Healthy;
        enum Degraded;
        enum Failed;
        enum Maintenance;
    }

    enum def CommandKind {
        enum Configure;
        enum Start;
        enum Stop;
        enum Restart;
        enum RotateKeys;
        enum ExportLicenseNotice;
        enum SelfTest;
    }

    enum def TelemetryKind {
        enum Metric;
        enum Log;
        enum Trace;
        enum Event;
    }

    attribute def DataRate {
        attribute value: Real;
        attribute unit: String = "Mbit/s";
    }

    attribute def DataSize {
        attribute value: Real;
        attribute unit: String = "MiB";
    }

    attribute def Duration {
        attribute value: Real;
        attribute unit: String = "s";
    }

    attribute def Frequency {
        attribute value: Real;
        attribute unit: String = "Hz";
    }

    attribute def Temperature {
        attribute value: Real;
        attribute unit: String = "degC";
    }

    attribute def Percentage {
        attribute value: Real;
        attribute unit: String = "%";
    }

    attribute def Count {
        attribute value: Integer;
        attribute unit: String = "count";
    }

    attribute def Timestamp {
        attribute value: String;
        attribute unit: String = "ISO-8601 UTC";
    }

    item def TelemetrySample {
        attribute sampleId: String;
        attribute sourceId: String;
        attribute kind: TelemetryKind;
        attribute timestamp: Timestamp;
        attribute payloadSize: DataSize;
        attribute payloadEncoding: String;
        attribute integrityHash: String;
    }

    item def ValidatedTelemetry {
        attribute sampleId: String;
        attribute sourceId: String;
        attribute kind: TelemetryKind;
        attribute timestamp: Timestamp;
        attribute canonicalPayloadSize: DataSize;
        attribute schemaVersion: String;
        attribute validationScore: Percentage;
    }

    item def NormalizedEvent {
        attribute eventId: String;
        attribute sourceId: String;
        attribute kind: TelemetryKind;
        attribute timestamp: Timestamp;
        attribute normalizedSize: DataSize;
        attribute routingTopic: String;
        attribute retentionClass: String;
    }

    item def Acknowledgement {
        attribute correlationId: String;
        attribute accepted: Boolean;
        attribute reason: String;
        attribute processingLatency: Duration;
    }

    item def ControlCommand {
        attribute commandId: String;
        attribute kind: CommandKind;
        attribute requestedBy: String;
        attribute issuedAt: Timestamp;
    }

    item def HealthReport {
        attribute state: HealthState;
        attribute uptime: Duration;
        attribute cpuLoad: Percentage;
        attribute memoryUsed: DataSize;
        attribute ingestRate: DataRate;
        attribute droppedSamples: Count;
        attribute lastError: String;
    }

    item def LicenseNotice {
        attribute licenseId: LicenseIdentifier;
        attribute licenseName: String;
        attribute licenseVersion: String;
        attribute noticeText: String;
        attribute copyrightStatement: String;
    }

    item def SourceCodeOffer {
        attribute offerId: String;
        attribute repositoryUrl: String;
        attribute sourceArchiveSize: DataSize;
        attribute correspondingSourceAvailable: Boolean;
        attribute validUntil: Timestamp;
    }

    item def ComponentManifest {
        attribute componentName: String;
        attribute componentVersion: String;
        attribute licenseId: LicenseIdentifier;
        attribute sourceAvailable: Boolean;
        attribute noticeIncluded: Boolean;
        attribute compatibilityDecision: LicenseCompatibilityDecision;
    }

    port def TelemetryIngressPort {
        in item sample: TelemetrySample;
        out item acknowledgement: Acknowledgement;
    }

    port def ValidatedTelemetryPort {
        in item validated: ValidatedTelemetry;
        out item acknowledgement: Acknowledgement;
    }

    port def EventPort {
        in item event: NormalizedEvent;
        out item acknowledgement: Acknowledgement;
    }

    port def ControlPort {
        in item command: ControlCommand;
        out item health: HealthReport;
    }

    port def LicenseDistributionPort {
        out item notice: LicenseNotice;
        out item sourceOffer: SourceCodeOffer;
        out item manifest: ComponentManifest;
    }

    port def InternalHealthPort {
        out item health: HealthReport;
    }

    action def ReceiveTelemetry {
        in item sample: TelemetrySample;
        out item acknowledgement: Acknowledgement;
        attribute maximumAcceptedPayload: DataSize = (value = 16.0, unit = "MiB");
        attribute maximumIngressLatency: Duration = (value = 0.050, unit = "s");
    }

    action def ValidateTelemetry {
        in item sample: TelemetrySample;
        out item validated: ValidatedTelemetry;
        out item acknowledgement: Acknowledgement;
        attribute requiredValidationScore: Percentage = (value = 99.0, unit = "%");
    }

    action def NormalizeTelemetry {
        in item validated: ValidatedTelemetry;
        out item event: NormalizedEvent;
        attribute targetSchemaVersion: String = "gateway.normalized.telemetry.v2";
        attribute maximumNormalizationLatency: Duration = (value = 0.100, unit = "s");
    }

    action def PersistEvent {
        in item event: NormalizedEvent;
        out item acknowledgement: Acknowledgement;
        attribute writeTimeout: Duration = (value = 0.250, unit = "s");
        attribute retentionPeriod: Duration = (value = 2592000.0, unit = "s");
    }

    action def PublishEvent {
        in item event: NormalizedEvent;
        out item acknowledgement: Acknowledgement;
        attribute publishTimeout: Duration = (value = 0.100, unit = "s");
    }

    action def GenerateLicenseArtifacts {
        in item manifest: ComponentManifest;
        out item notice: LicenseNotice;
        out item sourceOffer: SourceCodeOffer;
        attribute licenseId: LicenseIdentifier = LicenseIdentifier::EPL_2_0;
    }

    action def PerformSelfTest {
        out item health: HealthReport;
        attribute maximumSelfTestDuration: Duration = (value = 30.0, unit = "s");
    }

    action def IngestNormalizeStoreAndPublish {
        in item rawSample: TelemetrySample;
        out item finalAcknowledgement: Acknowledgement;
        out item normalizedEvent: NormalizedEvent;

        action receive: ReceiveTelemetry;
        action validate: ValidateTelemetry;
        action normalize: NormalizeTelemetry;
        action persist: PersistEvent;
        action publish: PublishEvent;

        flow rawSample to receive.sample;
        flow rawSample to validate.sample;
        flow validate.validated to normalize.validated;
        flow normalize.event to persist.event;
        flow normalize.event to publish.event;
        flow normalize.event to normalizedEvent;
        flow publish.acknowledgement to finalAcknowledgement;
    }

    state def GatewayLifecycle {
        state Unconfigured;
        state Configured;
        state Starting;
        state Operating;
        state Degraded;
        state Stopping;
        state Stopped;
        state Failed;
        state Maintenance;

        transition initial then Unconfigured;

        transition configure
            first Unconfigured
            accept ControlCommand
            if command.kind == CommandKind::Configure
            then Configured;

        transition start
            first Configured
            accept ControlCommand
            if command.kind == CommandKind::Start
            then Starting;

        transition becomeOperational
            first Starting
            then Operating;

        transition detectDegradation
            first Operating
            if health.state == HealthState::Degraded
            then Degraded;

        transition recoverFromDegradation
            first Degraded
            if health.state == HealthState::Healthy
            then Operating;

        transition stopFromOperating
            first Operating
            accept ControlCommand
            if command.kind == CommandKind::Stop
            then Stopping;

        transition stopFromDegraded
            first Degraded
            accept ControlCommand
            if command.kind == CommandKind::Stop
            then Stopping;

        transition stopped
            first Stopping
            then Stopped;

        transition restart
            first Stopped
            accept ControlCommand
            if command.kind == CommandKind::Restart
            then Starting;

        transition failFromStarting
            first Starting
            if health.state == HealthState::Failed
            then Failed;

        transition failFromOperating
            first Operating
            if health.state == HealthState::Failed
            then Failed;

        transition enterMaintenance
            first Failed
            accept ControlCommand
            if command.kind == CommandKind::SelfTest
            then Maintenance;

        transition maintenanceComplete
            first Maintenance
            if health.state == HealthState::Healthy
            then Configured;
    }

    part def TelemetryCollector {
        port telemetryIn: TelemetryIngressPort;
        port validatedOut: ValidatedTelemetryPort;
        port healthOut: InternalHealthPort;

        attribute maximumSustainedIngressRate: DataRate = (value = 250.0, unit = "Mbit/s");
        attribute maximumBurstIngressRate: DataRate = (value = 1000.0, unit = "Mbit/s");
        attribute maximumPayloadSize: DataSize = (value = 16.0, unit = "MiB");
        attribute pollingFrequency: Frequency = (value = 100.0, unit = "Hz");

        perform action receive: ReceiveTelemetry;
        perform action validate: ValidateTelemetry;
    }

    part def EventNormalizer {
        port validatedIn: ValidatedTelemetryPort;
        port eventOut: EventPort;
        port healthOut: InternalHealthPort;

        attribute normalizationLatencyBudget: Duration = (value = 0.100, unit = "s");
        attribute schemaCacheSize: DataSize = (value = 512.0, unit = "MiB");
        attribute targetSchemaVersion: String = "gateway.normalized.telemetry.v2";

        perform action normalize: NormalizeTelemetry;
    }

    part def EventRepository {
        port eventIn: EventPort;
        port healthOut: InternalHealthPort;

        attribute usableStorageCapacity: DataSize = (value = 204800.0, unit = "MiB");
        attribute writeThroughput: DataRate = (value = 500.0, unit = "Mbit/s");
        attribute retentionPeriod: Duration = (value = 2592000.0, unit = "s");
        attribute maximumWriteLatency: Duration = (value = 0.250, unit = "s");

        perform action persist: PersistEvent;
    }

    part def EventPublisher {
        port eventIn: EventPort;
        port healthOut: InternalHealthPort;

        attribute outboundThroughput: DataRate = (value = 500.0, unit = "Mbit/s");
        attribute publishLatencyBudget: Duration = (value = 0.100, unit = "s");
        attribute retryLimit: Count = (value = 3, unit = "count");

        perform action publish: PublishEvent;
    }

    part def LicenseManager {
        port licenseDistribution: LicenseDistributionPort;
        port control: ControlPort;
        port healthOut: InternalHealthPort;

        attribute governingLicense: LicenseIdentifier = LicenseIdentifier::EPL_2_0;
        attribute licenseName: String = "Eclipse Public License";
        attribute licenseVersion: String = "2.0";
        attribute noticesPreserved: Boolean = true;
        attribute sourceOfferEnabled: Boolean = true;
        attribute secondaryLicenseCompatibilityDisabled: Boolean = true;

        perform action generateArtifacts: GenerateLicenseArtifacts;
    }

    part def AdministrationInterface {
        port operatorControl: ControlPort;
        port licenseDistribution: LicenseDistributionPort;

        attribute maximumConcurrentOperators: Count = (value = 10, unit = "count");
        attribute commandTimeout: Duration = (value = 5.0, unit = "s");
    }

    part def HealthSupervisor {
        port collectorHealth: InternalHealthPort;
        port normalizerHealth: InternalHealthPort;
        port repositoryHealth: InternalHealthPort;
        port publisherHealth: InternalHealthPort;
        port licenseHealth: InternalHealthPort;
        port control: ControlPort;

        attribute healthEvaluationPeriod: Duration = (value = 1.0, unit = "s");
        attribute maximumAllowedCpuLoad: Percentage = (value = 85.0, unit = "%");
        attribute maximumAllowedTemperature: Temperature = (value = 75.0, unit = "degC");
        attribute maximumDroppedSamplesPerMinute: Count = (value = 100, unit = "count");

        perform action selfTest: PerformSelfTest;
    }

    part def EPL2ObservabilityGateway {
        port externalTelemetryIngress: TelemetryIngressPort;
        port externalControl: ControlPort;
        port externalLicenseDistribution: LicenseDistributionPort;

        part collector: TelemetryCollector;
        part normalizer: EventNormalizer;
        part repository: EventRepository;
        part publisher: EventPublisher;
        part licenseManager: LicenseManager;
        part administration: AdministrationInterface;
        part supervisor: HealthSupervisor;

        attribute systemName: String = "EPL 2.0 Observability Gateway";
        attribute primaryFunction: String = "Collect telemetry from distributed sources, validate and normalize it, persist it for auditability, and publish normalized events to downstream consumers while distributing all required Eclipse Public License 2.0 notices and corresponding source offers.";
        attribute governingLicense: LicenseIdentifier = LicenseIdentifier::EPL_2_0;
        attribute releaseVersion: String = "2.0.0";
        attribute maximumEndToEndLatency: Duration = (value = 0.500, unit = "s");
        attribute nominalThroughput: DataRate = (value = 250.0, unit = "Mbit/s");
        attribute memoryBudget: DataSize = (value = 4096.0, unit = "MiB");
        attribute minimumUptimeTarget: Percentage = (value = 99.9, unit = "%");

        connection externalTelemetryToCollector connect externalTelemetryIngress to collector.telemetryIn;
        connection collectorToNormalizer connect collector.validatedOut to normalizer.validatedIn;
        connection normalizerToRepository connect normalizer.eventOut to repository.eventIn;
        connection normalizerToPublisher connect normalizer.eventOut to publisher.eventIn;
        connection externalControlToAdministration connect externalControl to administration.operatorControl;
        connection administrationToLicenseManager connect administration.licenseDistribution to licenseManager.licenseDistribution;
        connection licenseManagerToExternalDistribution connect licenseManager.licenseDistribution to externalLicenseDistribution;
        connection collectorHealthToSupervisor connect collector.healthOut to supervisor.collectorHealth;
        connection normalizerHealthToSupervisor connect normalizer.healthOut to supervisor.normalizerHealth;
        connection repositoryHealthToSupervisor connect repository.healthOut to supervisor.repositoryHealth;
        connection publisherHealthToSupervisor connect publisher.healthOut to supervisor.publisherHealth;
        connection licenseHealthToSupervisor connect licenseManager.healthOut to supervisor.licenseHealth;
        connection supervisorToAdministration connect supervisor.control to administration.operatorControl;

        perform action primaryProcessing: IngestNormalizeStoreAndPublish;
        exhibit state lifecycle: GatewayLifecycle;
    }

    requirement def PrimaryFunctionRequirement {
        subject gateway: EPL2ObservabilityGateway;
        doc "The system shall provide a high-level observability gateway function by collecting telemetry, validating it, normalizing it into a common event representation, storing it for auditability, and publishing it to downstream consumers.";
        require constraint {
            gateway.nominalThroughput.value >= 250.0 and
            gateway.maximumEndToEndLatency.value <= 0.500
        }
    }

    requirement def EPL20BasisRequirement {
        subject gateway: EPL2ObservabilityGateway;
        doc "The system shall be based on the Eclipse Public License 2.0 as its governing open-source license.";
        require constraint {
            gateway.governingLicense == LicenseIdentifier::EPL_2_0
        }
    }

    requirement def EPL20NoticeRequirement {
        subject manager: LicenseManager;
        doc "The system shall preserve and distribute Eclipse Public License 2.0 notices with every binary or source distribution.";
        require constraint {
            manager.governingLicense == LicenseIdentifier::EPL_2_0 and
            manager.noticesPreserved == true
        }
    }

    requirement def EPL20SourceOfferRequirement {
        subject manager: LicenseManager;
        doc "The system shall provide a corresponding source-code offer and component manifest for EPL 2.0 covered material.";
        require constraint {
            manager.sourceOfferEnabled == true
        }
    }

    requirement def TelemetryThroughputRequirement {
        subject collector: TelemetryCollector;
        doc "The collector shall accept sustained telemetry ingress at no less than 250 Mbit/s and burst ingress at no less than 1000 Mbit/s.";
        require constraint {
            collector.maximumSustainedIngressRate.value >= 250.0 and
            collector.maximumBurstIngressRate.value >= 1000.0
        }
    }

    requirement def LatencyRequirement {
        subject gateway: EPL2ObservabilityGateway;
        doc "The gateway shall complete receive, validate, normalize, persist, and publish processing within 0.500 s for accepted telemetry samples under nominal load.";
        require constraint {
            gateway.maximumEndToEndLatency.value <= 0.500
        }
    }

    requirement def RepositoryRetentionRequirement {
        subject repository: EventRepository;
        doc "The event repository shall retain normalized events for at least 30 days.";
        require constraint {
            repository.retentionPeriod.value >= 2592000.0
        }
    }

    requirement def OperationalHealthRequirement {
        subject supervisor: HealthSupervisor;
        doc "The health supervisor shall evaluate subsystem health at least once per second and report Healthy, Degraded, Failed, or Maintenance state.";
        require constraint {
            supervisor.healthEvaluationPeriod.value <= 1.0
        }
    }

    requirement def PayloadLimitRequirement {
        subject collector: TelemetryCollector;
        doc "The collector shall reject telemetry samples with payloads larger than 16 MiB.";
        require constraint {
            collector.maximumPayloadSize.value <= 16.0
        }
    }

    part epl2Gateway: EPL2ObservabilityGateway;

    satisfy PrimaryFunctionRequirement by epl2Gateway;
    satisfy EPL20BasisRequirement by epl2Gateway;
    satisfy EPL20NoticeRequirement by epl2Gateway.licenseManager;
    satisfy EPL20SourceOfferRequirement by epl2Gateway.licenseManager;
    satisfy TelemetryThroughputRequirement by epl2Gateway.collector;
    satisfy LatencyRequirement by epl2Gateway;
    satisfy RepositoryRetentionRequirement by epl2Gateway.repository;
    satisfy OperationalHealthRequirement by epl2Gateway.supervisor;
    satisfy PayloadLimitRequirement by epl2Gateway.collector;
}
