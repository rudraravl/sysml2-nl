package DOI_Resolution_System_Model {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def DOI;
    attribute def URL;
    attribute def MetadataRecord;
    attribute def ResolutionStatus;
    attribute def TimeStamp;
    attribute def IdentifierString;
    attribute def ErrorMessage;

    item def DOIRequest {
        attribute doi : IdentifierString;
        attribute requesterAddress : URL;
        attribute submittedAt : TimeStamp;
    }

    item def DOIResponse {
        attribute doi : IdentifierString;
        attribute targetURL : URL;
        attribute metadata : MetadataRecord;
        attribute status : ResolutionStatus;
        attribute resolvedAt : TimeStamp;
    }

    item def ErrorResponse {
        attribute doi : IdentifierString;
        attribute status : ResolutionStatus;
        attribute message : ErrorMessage;
        attribute generatedAt : TimeStamp;
    }

    value def Latency {
        unit = ms;
        quantity = ISQ::time;
    }

    value def Availability {
        unit = one;
        quantity = ISQ::dimensionless;
    }

    value def RequestRate {
        unit = one / s;
        quantity = ISQ::frequency;
    }

    port def DOIRequestPort {
        in item request : DOIRequest;
    }

    port def DOIResponsePort {
        out item response : DOIResponse;
        out item error : ErrorResponse;
    }

    port def RegistryQueryPort {
        out item registryRequest : DOIRequest;
        in item registryResponse : DOIResponse;
        in item registryError : ErrorResponse;
    }

    part def DOIResolutionSystem {
        attribute primaryFunction : String =
            "Resolve a submitted Digital Object Identifier into an actionable target URL and associated metadata.";

        attribute maximumResolutionLatency : Latency = 500 [ms];
        attribute minimumAvailability : Availability = 0.999;
        attribute sustainedRequestRate : RequestRate = 1000 [one / s];

        port clientInput : DOIRequestPort;
        port clientOutput : DOIResponsePort;

        part apiGateway : APIGateway;
        part syntaxValidator : DOISyntaxValidator;
        part cache : ResolutionCache;
        part registryAdapter : DOIRegistryAdapter;
        part resolverEngine : ResolverEngine;
        part auditLogger : AuditLogger;
        part healthMonitor : HealthMonitor;

        connect clientInput to apiGateway.externalRequest;
        connect apiGateway.validationRequest to syntaxValidator.validationInput;
        connect syntaxValidator.validatedRequest to resolverEngine.resolutionInput;
        connect resolverEngine.cacheLookup to cache.lookupPort;
        connect resolverEngine.registryQuery to registryAdapter.registryPort;
        connect resolverEngine.resolutionOutput to apiGateway.internalResponse;
        connect apiGateway.externalResponse to clientOutput;
        connect resolverEngine.auditEvent to auditLogger.eventInput;
        connect healthMonitor.observedComponents to apiGateway.healthPort;
        connect healthMonitor.observedComponents to cache.healthPort;
        connect healthMonitor.observedComponents to registryAdapter.healthPort;
    }

    part def APIGateway {
        port externalRequest : DOIRequestPort;
        port externalResponse : DOIResponsePort;
        port validationRequest : DOIRequestPort;
        port internalResponse : DOIResponsePort;
        port healthPort : HealthObservationPort;

        attribute acceptedRequests : Integer;
        attribute rejectedRequests : Integer;
    }

    part def DOISyntaxValidator {
        port validationInput : DOIRequestPort;
        port validatedRequest : DOIRequestPort;
        port validationError : DOIResponsePort;

        attribute requiredPrefixPattern : String = "10.";
        attribute permitsSlashSeparator : Boolean = true;

        action validateDOI {
            in item candidate : DOIRequest;
            out item accepted : DOIRequest;
            out item rejected : ErrorResponse;
        }
    }

    part def ResolutionCache {
        port lookupPort : CacheLookupPort;
        port healthPort : HealthObservationPort;

        attribute maximumEntries : Integer = 10000000;
        attribute entryTimeToLive : Latency = 86400000 [ms];
        attribute hitRatio : Real;

        action lookupCachedResolution {
            in item request : DOIRequest;
            out item cachedResponse : DOIResponse;
            out item cacheMiss : DOIRequest;
        }

        action storeResolution {
            in item response : DOIResponse;
        }
    }

    port def CacheLookupPort {
        in item lookupRequest : DOIRequest;
        out item cachedResponse : DOIResponse;
        out item cacheMiss : DOIRequest;
    }

    part def DOIRegistryAdapter {
        port registryPort : RegistryQueryPort;
        port healthPort : HealthObservationPort;

        attribute registryEndpoint : URL;
        attribute retryLimit : Integer = 3;
        attribute timeout : Latency = 200 [ms];

        action queryAuthoritativeRegistry {
            in item request : DOIRequest;
            out item response : DOIResponse;
            out item error : ErrorResponse;
        }
    }

    part def ResolverEngine {
        port resolutionInput : DOIRequestPort;
        port resolutionOutput : DOIResponsePort;
        port cacheLookup : CacheLookupPort;
        port registryQuery : RegistryQueryPort;
        port auditEvent : AuditEventPort;

        attribute activeResolutions : Integer;
        attribute averageLatency : Latency;

        action resolveDOI {
            in item request : DOIRequest;
            out item response : DOIResponse;
            out item error : ErrorResponse;

            first start;
            then checkCache;
            then queryRegistry if cacheMiss;
            then buildResponse;
            then publishResult;
        }

        state def ResolutionStateMachine {
            state idle;
            state validating;
            state checkingCache;
            state queryingRegistry;
            state resolved;
            state failed;

            transition idle_to_validating
                first idle
                accept DOIRequest
                then validating;

            transition validating_to_cache
                first validating
                if isValidDOI
                then checkingCache;

            transition validating_to_failed
                first validating
                if not isValidDOI
                then failed;

            transition cache_to_resolved
                first checkingCache
                if cacheHit
                then resolved;

            transition cache_to_registry
                first checkingCache
                if not cacheHit
                then queryingRegistry;

            transition registry_to_resolved
                first queryingRegistry
                if registryResponseReceived
                then resolved;

            transition registry_to_failed
                first queryingRegistry
                if registryUnavailable or doiNotFound
                then failed;

            transition resolved_to_idle
                first resolved
                then idle;

            transition failed_to_idle
                first failed
                then idle;
        }
    }

    item def AuditEvent {
        attribute doi : IdentifierString;
        attribute status : ResolutionStatus;
        attribute latency : Latency;
        attribute recordedAt : TimeStamp;
    }

    port def AuditEventPort {
        in item event : AuditEvent;
    }

    part def AuditLogger {
        port eventInput : AuditEventPort;

        attribute retainedDays : Integer = 365;
        attribute encryptedAtRest : Boolean = true;

        action recordResolutionEvent {
            in item event : AuditEvent;
        }
    }

    item def HealthObservation {
        attribute componentName : String;
        attribute available : Boolean;
        attribute responseLatency : Latency;
        attribute observedAt : TimeStamp;
    }

    port def HealthObservationPort {
        out item observation : HealthObservation;
    }

    part def HealthMonitor {
        port observedComponents : HealthObservationPort;

        attribute monitoringInterval : Latency = 5000 [ms];

        action collectHealth {
            out item observations : HealthObservation;
        }
    }

    requirement def PrimaryFunctionRequirement {
        subject system : DOIResolutionSystem;

        require constraint {
            system.primaryFunction ==
            "Resolve a submitted Digital Object Identifier into an actionable target URL and associated metadata."
        }
    }

    requirement def ValidDOIRequirement {
        subject validator : DOISyntaxValidator;

        require constraint {
            validator.requiredPrefixPattern == "10." and
            validator.permitsSlashSeparator == true
        }
    }

    requirement def LatencyRequirement {
        subject system : DOIResolutionSystem;

        require constraint {
            system.maximumResolutionLatency <= 500 [ms]
        }
    }

    requirement def AvailabilityRequirement {
        subject system : DOIResolutionSystem;

        require constraint {
            system.minimumAvailability >= 0.999
        }
    }

    requirement def CacheCapacityRequirement {
        subject cache : ResolutionCache;

        require constraint {
            cache.maximumEntries >= 10000000
        }
    }

    requirement def AuditRequirement {
        subject logger : AuditLogger;

        require constraint {
            logger.retainedDays >= 365 and
            logger.encryptedAtRest == true
        }
    }

    satisfy PrimaryFunctionRequirement by DOIResolutionSystem;
    satisfy ValidDOIRequirement by DOISyntaxValidator;
    satisfy LatencyRequirement by DOIResolutionSystem;
    satisfy AvailabilityRequirement by DOIResolutionSystem;
    satisfy CacheCapacityRequirement by ResolutionCache;
    satisfy AuditRequirement by AuditLogger;
}