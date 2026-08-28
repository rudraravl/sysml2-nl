package DOIResolutionSystem {
    private import ScalarValues::String;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;
    private import ScalarValues::Real;

    package Types {
        value type DOI :> String;
        value type URL :> String;
        value type ResourceTitle :> String;
        value type CreatorName :> String;
        value type ErrorMessage :> String;
        value type StatusCode :> String;

        item def Metadata {
            attribute doi : DOI[1];
            attribute title : ResourceTitle[1];
            attribute creators : CreatorName[1..*];
            attribute publicationYear : Integer[1];
            attribute targetURL : URL[1];
        }

        item def DigitalObject {
            attribute identifier : DOI[1];
            attribute content : String[1];
            attribute sizeBytes : Integer[1];
        }

        item def LookupRequest {
            attribute requestedDOI : DOI[1];
        }

        item def LookupResponse {
            attribute status : StatusCode[1];
            attribute resolvedURL : URL[0..1];
            attribute object : DigitalObject[0..1];
            attribute error : ErrorMessage[0..1];
        }

        item def RegistryQuery {
            attribute doi : DOI[1];
        }

        item def RegistryResult {
            attribute found : Boolean[1];
            attribute resourceMetadata : Metadata[0..1];
        }

        item def ContentRequest {
            attribute url : URL[1];
            attribute doi : DOI[1];
        }

        item def ContentResult {
            attribute success : Boolean[1];
            attribute object : DigitalObject[0..1];
            attribute error : ErrorMessage[0..1];
        }

        item def CacheEntry {
            attribute doi : DOI[1];
            attribute resourceMetadata : Metadata[1];
            attribute accessCount : Integer[1];
        }

        item def CacheQuery {
            attribute doi : DOI[1];
        }

        item def CacheResult {
            attribute found : Boolean[1];
            attribute url : URL[0..1];
            attribute resourceMetadata : Metadata[0..1];
        }

        item def CacheUpdate {
            attribute doi : DOI[1];
            attribute resourceMetadata : Metadata[1];
        }

        item def MaintenanceTrigger;
        item def MaintenanceComplete;
    }

    package Ports {
        private import Types::*;

        port def UserRequestPort {
            in ref request : LookupRequest;
            out ref response : LookupResponse;
        }

        port def RegistryPort {
            in ref query : RegistryQuery;
            out ref result : RegistryResult;
        }

        port def ContentPort {
            in ref fetch : ContentRequest;
            out ref result : ContentResult;
        }

        port def CachePort {
            in ref query : CacheQuery;
            in ref update : CacheUpdate;
            out ref result : CacheResult;
        }

        interface def UserInterface {
            end user : ~UserRequestPort;
            end resolver : UserRequestPort;
        }

        interface def RegistryInterface {
            end resolver : ~RegistryPort;
            end registry : RegistryPort;
        }

        interface def ContentInterface {
            end resolver : ~ContentPort;
            end provider : ContentPort;
        }

        interface def CacheInterface {
            end resolver : ~CachePort;
            end cache : CachePort;
        }
    }

    package Components {
        private import Types::*;
        private import Ports::*;

        part def DOICache {
            attribute maxEntries : Integer = 1000;
            attribute entries : CacheEntry[0..*];

            port cachePort : CachePort {
                in ref :>> query;
                in ref :>> update;
                out ref :>> result;
            }

            exhibit state cacheBehavior {
                entry; then Ready;
                state Ready;

                transition handleQuery
                    first Ready
                    accept q : CacheQuery via cachePort
                    do send new CacheResult(false, null, null) via cachePort
                    then Ready;

                transition handleUpdate
                    first Ready
                    accept u : CacheUpdate via cachePort
                    then Ready;
            }
        }

        part def DOIResolverEngine {
            port userPort : UserRequestPort {
                in ref :>> request;
                out ref :>> response;
            }
            port registryPort : ~RegistryPort {
                out ref :>> query;
                in ref :>> result;
            }
            port contentPort : ~ContentPort {
                out ref :>> fetch;
                in ref :>> result;
            }
            port cachePort : ~CachePort {
                out ref :>> query;
                out ref :>> update;
                in ref :>> result;
            }

            part cache : DOICache;
            interface cache_interface : CacheInterface connect cachePort to cache.cachePort;

            exhibit state resolverBehavior {
                entry; then Idle;
                state Idle;

                transition receiveRequest
                    first Idle
                    accept req : LookupRequest via userPort
                    then Validating;

                state Validating;

                transition formatValid
                    first Validating
                    if receiveRequest.req.requestedDOI != ""
                    then CheckingCache;

                transition formatInvalid
                    first Validating
                    if receiveRequest.req.requestedDOI == ""
                    do send new LookupResponse("error", null, null, "Invalid DOI format") via userPort
                    then Idle;

                state CheckingCache;

                transition queryCache
                    first CheckingCache
                    do send new CacheQuery(receiveRequest.req.requestedDOI) via cachePort
                    then AwaitingCacheResponse;

                state AwaitingCacheResponse;

                transition cacheHit
                    first AwaitingCacheResponse
                    accept cacheRes : CacheResult via cachePort
                    if cacheRes.found
                    do send new ContentRequest(cacheRes.url, receiveRequest.req.requestedDOI) via contentPort
                    then AwaitingCachedContent;

                transition cacheMiss
                    first AwaitingCacheResponse
                    accept cacheRes : CacheResult via cachePort
                    if not cacheRes.found
                    do send new RegistryQuery(receiveRequest.req.requestedDOI) via registryPort
                    then AwaitingRegistry;

                state AwaitingRegistry;

                transition registryFound
                    first AwaitingRegistry
                    accept res : RegistryResult via registryPort
                    if res.found
                    do send new ContentRequest(res.resourceMetadata.targetURL, receiveRequest.req.requestedDOI) via contentPort
                    then AwaitingRegistryContent;

                transition registryNotFound
                    first AwaitingRegistry
                    accept res : RegistryResult via registryPort
                    if not res.found
                    do send new LookupResponse("error", null, null, "DOI not registered") via userPort
                    then Idle;

                state AwaitingCachedContent;

                transition cachedContentSuccess
                    first AwaitingCachedContent
                    accept cres : ContentResult via contentPort
                    if cres.success
                    then DeliveringCached;

                transition cachedContentFailure
                    first AwaitingCachedContent
                    accept cres : ContentResult via contentPort
                    if not cres.success
                    do send new LookupResponse("error", null, null, cres.error) via userPort
                    then Idle;

                state AwaitingRegistryContent;

                transition registryContentSuccess
                    first AwaitingRegistryContent
                    accept cres : ContentResult via contentPort
                    if cres.success
                    do send new CacheUpdate(receiveRequest.req.requestedDOI, registryFound.res.resourceMetadata) via cachePort
                    then DeliveringRegistry;

                transition registryContentFailure
                    first AwaitingRegistryContent
                    accept cres : ContentResult via contentPort
                    if not cres.success
                    do send new LookupResponse("error", null, null, cres.error) via userPort
                    then Idle;

                state DeliveringCached;

                transition deliverCachedResponse
                    first DeliveringCached
                    do send new LookupResponse("success", null, cachedContentSuccess.cres.object, null) via userPort
                    then Idle;

                state DeliveringRegistry;

                transition deliverRegistryResponse
                    first DeliveringRegistry
                    do send new LookupResponse("success", null, registryContentSuccess.cres.object, null) via userPort
                    then Idle;

                transition enterMaintenance
                    first Idle
                    accept MaintenanceTrigger
                    then Maintenance;

                state Maintenance;

                transition exitMaintenance
                    first Maintenance
                    accept MaintenanceComplete
                    then Idle;
            }
        }

        part def DOIRegistry {
            attribute recordCount : Integer = 0;
            attribute registryName : String;

            port registryPort : RegistryPort {
                in ref :>> query;
                out ref :>> result;
            }

            exhibit state registryBehavior {
                entry; then Waiting;
                state Waiting;

                transition handleQuery
                    first Waiting
                    accept q : RegistryQuery via registryPort
                    do send new RegistryResult(false, null) via registryPort
                    then Waiting;
            }
        }

        part def ContentProvider {
            attribute providerName : String;
            attribute baseURL : URL;
            attribute isAvailable : Boolean = true;

            port contentPort : ContentPort {
                in ref :>> fetch;
                out ref :>> result;
            }

            exhibit state providerBehavior {
                entry; then Ready;
                state Ready;

                transition serveRequest
                    first Ready
                    accept freq : ContentRequest via contentPort
                    if isAvailable
                    do send new ContentResult(true, null, null) via contentPort
                    then Ready;

                transition serveUnavailable
                    first Ready
                    accept freq : ContentRequest via contentPort
                    if not isAvailable
                    do send new ContentResult(false, null, "Content provider unavailable") via contentPort
                    then Ready;
            }
        }
    }

    package System {
        private import Types::*;
        private import Ports::*;
        private import Components::*;

        part def DOIResolutionSystem {
            part resolver : DOIResolverEngine;
            part registry : DOIRegistry;
            part provider : ContentProvider;

            interface registry_interface : RegistryInterface connect resolver.registryPort to registry.registryPort;
            interface content_interface : ContentInterface connect resolver.contentPort to provider.contentPort;
        }
    }

    package Requirements {
        private import Components::*;
        private import System::*;

        requirement def DOIFormatValidation {
            doc /* The resolver shall validate the format of a submitted DOI before processing. */
            subject resolver : DOIResolverEngine;
        }

        requirement def CacheFirstLookup {
            doc /* The resolver shall check its local cache before querying the registry to speed up requests. */
            subject resolver : DOIResolverEngine;
        }

        requirement def RegistryFallback {
            doc /* If the DOI is not found in the cache, the resolver shall query the authoritative DOI Registry. */
            subject resolver : DOIResolverEngine;
        }

        requirement def ContentRetrievalReq {
            doc /* The resolver shall retrieve the digital object from the appropriate Content Provider using the resolved URL. */
            subject resolver : DOIResolverEngine;
        }

        requirement def CacheUpdateReq {
            doc /* After successfully fetching an object via the registry path, the resolver shall update its cache for future requests. */
            subject resolver : DOIResolverEngine;
        }

        requirement def ErrorHandlingReq {
            doc /* The system shall handle invalid DOIs, unregistered DOIs, and unavailable content with appropriate error responses. */
            subject resolver : DOIResolverEngine;
        }

        requirement def HighAvailabilityReq {
            doc /* The system shall be highly available and persistent, ensuring DOIs remain reliable identifiers. */
            subject system : DOIResolutionSystem;
            attribute availabilityTarget : Real = 0.9999;
        }

        requirement def PerformanceReq {
            doc /* The system shall resolve cached DOIs within 100 milliseconds for 95 percent of requests. */
            subject resolver : DOIResolverEngine;
            attribute maxLatency : Real = 100.0;
        }

        requirement def MaintenanceModeReq {
            doc /* The system shall support a maintenance mode for clearing caches and synchronizing data with the registry. */
            subject resolver : DOIResolverEngine;
        }

        requirement doiFormatValidation : DOIFormatValidation;
        requirement cacheFirstLookup : CacheFirstLookup;
        requirement registryFallback : RegistryFallback;
        requirement contentRetrieval : ContentRetrievalReq;
        requirement cacheUpdate : CacheUpdateReq;
        requirement errorHandling : ErrorHandlingReq;
        requirement highAvailability : HighAvailabilityReq;
        requirement performance : PerformanceReq;
        requirement maintenanceMode : MaintenanceModeReq;
    }
}
