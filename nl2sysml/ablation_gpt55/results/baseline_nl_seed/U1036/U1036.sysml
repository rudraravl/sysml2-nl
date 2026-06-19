package DOIResolutionSystemModel {
  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  attribute def TimeValue :> ISQ::time;
  attribute def DataSizeValue :> ISQ::information;
  attribute def DataRateValue :> ISQ::dataRate;
  attribute def AvailabilityPercent :> ScalarValues::Real;
  attribute def CountValue :> ScalarValues::Integer;
  attribute def IdentifierText :> ScalarValues::String;
  attribute def URIText :> ScalarValues::String;
  attribute def StatusText :> ScalarValues::String;

  enum def ResolutionStatus {
    enum valid;
    enum invalidSyntax;
    enum notFound;
    enum registryUnavailable;
    enum redirectPrepared;
    enum completed;
  }

  enum def CacheDisposition {
    enum hit;
    enum miss;
    enum stale;
    enum refreshed;
  }

  item def DOI {
    attribute prefix: IdentifierText;
    attribute suffix: IdentifierText;
    attribute canonicalText: IdentifierText;
  }

  item def TargetURL {
    attribute uri: URIText;
    attribute scheme: StatusText;
    attribute host: StatusText;
  }

  item def MetadataRecord {
    attribute doi: IdentifierText;
    attribute title: StatusText;
    attribute publisher: StatusText;
    attribute target: URIText;
    attribute lastUpdated: TimeValue;
    attribute recordSize: DataSizeValue;
  }

  item def DOIResolutionRequest {
    attribute requestedDOI: IdentifierText;
    attribute requestorAddress: StatusText;
    attribute acceptHeader: StatusText;
    attribute requestTime: TimeValue;
  }

  item def DOIResolutionResponse {
    attribute status: ResolutionStatus;
    attribute resolvedDOI: IdentifierText;
    attribute targetLocation: URIText;
    attribute responseTime: TimeValue;
    attribute cacheDisposition: CacheDisposition;
  }

  item def ResolutionError {
    attribute status: ResolutionStatus;
    attribute message: StatusText;
    attribute failedDOI: IdentifierText;
  }

  item def RegistryQuery {
    attribute doi: IdentifierText;
    attribute queryTime: TimeValue;
  }

  item def RegistryReply {
    attribute status: ResolutionStatus;
    attribute record: MetadataRecord;
    attribute replyTime: TimeValue;
  }

  item def HealthMetric {
    attribute observedLatency: TimeValue;
    attribute successfulResolutions: CountValue;
    attribute failedResolutions: CountValue;
    attribute availability: AvailabilityPercent;
  }

  port def DOIResolutionServicePort {
    in item request: DOIResolutionRequest;
    out item response: DOIResolutionResponse;
    out item error: ResolutionError;
  }

  port def ValidationPort {
    in item request: DOIResolutionRequest;
    out item validDOI: DOI;
    out item error: ResolutionError;
  }

  port def CacheLookupPort {
    in item doi: DOI;
    out item cachedRecord: MetadataRecord;
    out item disposition: CacheDisposition;
  }

  port def RegistryQueryPort {
    out item query: RegistryQuery;
    in item reply: RegistryReply;
  }

  port def CompositionPort {
    in item doi: DOI;
    in item metadata: MetadataRecord;
    out item response: DOIResolutionResponse;
  }

  port def AuditPort {
    in item request: DOIResolutionRequest;
    in item response: DOIResolutionResponse;
    in item error: ResolutionError;
  }

  port def MonitoringPort {
    out item metric: HealthMetric;
  }

  port def PublisherAdminPort {
    in item recordUpdate: MetadataRecord;
    out item updateResult: ResolutionStatus;
  }

  action def ReceiveDoiRequest {
    in item request: DOIResolutionRequest;
    out item acceptedRequest: DOIResolutionRequest;
  }

  action def ValidateDoiSyntax {
    in item request: DOIResolutionRequest;
    out item doi: DOI;
    out item validationError: ResolutionError;
  }

  action def CheckResolutionCache {
    in item doi: DOI;
    out item record: MetadataRecord;
    out item disposition: CacheDisposition;
  }

  action def QueryAuthoritativeRegistry {
    in item doi: DOI;
    out item reply: RegistryReply;
  }

  action def ComposeRedirectResponse {
    in item doi: DOI;
    in item record: MetadataRecord;
    in item disposition: CacheDisposition;
    out item response: DOIResolutionResponse;
  }

  action def RecordResolutionAudit {
    in item request: DOIResolutionRequest;
    in item response: DOIResolutionResponse;
  }

  action def ResolveDoiHighLevel {
    in item clientRequest: DOIResolutionRequest;
    out item clientResponse: DOIResolutionResponse;
    out item clientError: ResolutionError;

    action receive: ReceiveDoiRequest;
    action validate: ValidateDoiSyntax;
    action cacheLookup: CheckResolutionCache;
    action registryLookup: QueryAuthoritativeRegistry;
    action compose: ComposeRedirectResponse;
    action audit: RecordResolutionAudit;

    flow clientRequest to receive.request;
    flow receive.acceptedRequest to validate.request;
    flow validate.doi to cacheLookup.doi;
    flow validate.doi to registryLookup.doi;
    flow validate.doi to compose.doi;
    flow cacheLookup.record to compose.record;
    flow cacheLookup.disposition to compose.disposition;
    flow compose.response to audit.response;
    flow receive.acceptedRequest to audit.request;
    flow compose.response to clientResponse;
    flow validate.validationError to clientError;
  }

  state def DOIResolverOperationalStates {
    state initializing;
    state available;
    state degraded;
    state maintenance;
    state unavailable;

    transition initialStartup first initializing then available;
    transition registrySlow first available then degraded;
    transition registryRecovered first degraded then available;
    transition plannedMaintenance first available then maintenance;
    transition maintenanceComplete first maintenance then available;
    transition criticalFailure first available then unavailable;
    transition restart first unavailable then initializing;
  }

  part def APIGateway {
    attribute maximumIngressRate: DataRateValue = 10000 [1/s];
    attribute maximumRequestSize: DataSizeValue = 8 [kB];

    port clientFacing: DOIResolutionServicePort;
    port validationOut: ValidationPort;
    port auditOut: AuditPort;
  }

  part def DOISyntaxValidator {
    attribute minimumPrefixDigits: CountValue = 4;
    attribute maximumIdentifierLength: CountValue = 2048;
    attribute validationLatencyBudget: TimeValue = 20 [ms];

    port requestIn: ValidationPort;
  }

  part def ResolutionCache {
    attribute capacity: CountValue = 10000000;
    attribute nominalLookupTime: TimeValue = 5 [ms];
    attribute timeToLive: TimeValue = 86400 [s];

    port lookup: CacheLookupPort;
    port admin: PublisherAdminPort;
  }

  part def RegistryAdapter {
    attribute registryTimeout: TimeValue = 1500 [ms];
    attribute retryLimit: CountValue = 2;
    attribute outboundRateLimit: DataRateValue = 2500 [1/s];

    port lookup: RegistryQueryPort;
    port cacheUpdate: PublisherAdminPort;
  }

  part def ResponseComposer {
    attribute redirectStatusCode: CountValue = 302;
    attribute nominalCompositionTime: TimeValue = 10 [ms];

    port compose: CompositionPort;
  }

  part def AuditLog {
    attribute retentionPeriod: TimeValue = 31536000 [s];
    attribute writeLatencyBudget: TimeValue = 25 [ms];
    attribute storedEventCapacity: CountValue = 500000000;

    port auditIn: AuditPort;
  }

  part def HealthMonitor {
    attribute samplePeriod: TimeValue = 60 [s];
    attribute alertLatencyThreshold: TimeValue = 2000 [ms];
    attribute targetAvailability: AvailabilityPercent = 99.95 [%];

    port monitoring: MonitoringPort;
  }

  part def DOIResolutionSystem {
    doc /* The system is based on a Digital Object Identifier and provides the high-level primary function of accepting a DOI, validating its syntax, locating authoritative metadata, and returning a resolvable target URL for the identified digital object. */

    attribute resolvesDigitalObjectIdentifiers: Boolean = true;
    attribute maximumNominalResolutionTime: TimeValue = 500 [ms];
    attribute maximumDegradedResolutionTime: TimeValue = 2000 [ms];
    attribute availabilityObjective: AvailabilityPercent = 99.95 [%];
    attribute minimumSupportedThroughput: DataRateValue = 5000 [1/s];

    port clientApi: DOIResolutionServicePort;
    port authoritativeRegistry: RegistryQueryPort;
    port publisherAdministration: PublisherAdminPort;
    port operationsMonitoring: MonitoringPort;

    part apiGateway: APIGateway;
    part syntaxValidator: DOISyntaxValidator;
    part cache: ResolutionCache;
    part registryAdapter: RegistryAdapter;
    part responseComposer: ResponseComposer;
    part auditLog: AuditLog;
    part healthMonitor: HealthMonitor;

    connect clientApi to apiGateway.clientFacing;
    connect apiGateway.validationOut to syntaxValidator.requestIn;
    connect syntaxValidator.requestIn to cache.lookup;
    connect cache.lookup to responseComposer.compose;
    connect registryAdapter.lookup to authoritativeRegistry;
    connect registryAdapter.cacheUpdate to cache.admin;
    connect publisherAdministration to cache.admin;
    connect responseComposer.compose to apiGateway.clientFacing;
    connect apiGateway.auditOut to auditLog.auditIn;
    connect healthMonitor.monitoring to operationsMonitoring;

    perform action resolutionBehavior: ResolveDoiHighLevel;
    exhibit state operationalState: DOIResolverOperationalStates;
  }

  requirement def PrimaryFunctionRequirement {
    doc /* The system shall provide DOI resolution as its primary high-level function by transforming a valid DOI request into a response containing the target URL of the identified digital object. */

    subject system: DOIResolutionSystem;

    require constraint {
      system.resolvesDigitalObjectIdentifiers == true
    }
  }

  requirement def NominalLatencyRequirement {
    doc /* The system shall complete nominal DOI resolution within the specified latency objective when the DOI is valid and either cached or available from the authoritative registry. */

    subject system: DOIResolutionSystem;

    require constraint {
      system.maximumNominalResolutionTime <= 500 [ms]
    }
  }

  requirement def DegradedLatencyRequirement {
    doc /* The system shall return a resolved response or an explicit registry-unavailable error within the degraded-mode latency objective. */

    subject system: DOIResolutionSystem;

    require constraint {
      system.maximumDegradedResolutionTime <= 2000 [ms]
    }
  }

  requirement def AvailabilityRequirement {
    doc /* The DOI resolution service shall meet its availability objective for client-facing resolution requests. */

    subject system: DOIResolutionSystem;

    require constraint {
      system.availabilityObjective >= 99.95 [%]
    }
  }

  requirement def ThroughputRequirement {
    doc /* The DOI resolution service shall sustain the minimum client request throughput while maintaining nominal latency. */

    subject system: DOIResolutionSystem;

    require constraint {
      system.minimumSupportedThroughput >= 5000 [1/s]
    }
  }

  part doiResolutionSystem: DOIResolutionSystem;

  requirement primaryFunction: PrimaryFunctionRequirement {
    subject system = doiResolutionSystem;
  }

  requirement nominalLatency: NominalLatencyRequirement {
    subject system = doiResolutionSystem;
  }

  requirement degradedLatency: DegradedLatencyRequirement {
    subject system = doiResolutionSystem;
  }

  requirement availability: AvailabilityRequirement {
    subject system = doiResolutionSystem;
  }

  requirement throughput: ThroughputRequirement {
    subject system = doiResolutionSystem;
  }
}
