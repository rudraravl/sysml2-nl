package DOIResolutionSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types ----
    def DOIString :> String;
    def URLString :> String;
    def Metadata;
    def DigitalObject;

    attribute def Title :> String;
    attribute def Creator :> String;
    attribute def PublicationYear :> Integer;

    item def Metadata {
        attribute title : Title;
        attribute creators : Creator[1..*] ordered;
        attribute publicationYear : PublicationYear;
        attribute targetURL : URLString;
    }

    item def DigitalObject {
        attribute doi : DOIString;
        attribute content : String;
        attribute sizeMB : Real;
    }

    item def DOILookupRequest {
        attribute doi : DOIString;
        attribute requestTimestamp : DateTime;
    }

    item def DOILookupResponse {
        attribute doi : DOIString;
        attribute success : Boolean;
        attribute object : DigitalObject[0..1];
        attribute errorMessage : String[0..1];
    }

    item def RegistryQuery {
        attribute doi : DOIString;
    }

    item def RegistryResponse {
        attribute doi : DOIString;
        attribute found : Boolean;
        attribute metadata : Metadata[0..1];
    }

    item def ContentRequest {
        attribute targetURL : URLString;
        attribute doi : DOIString;
    }

    item def ContentResponse {
        attribute targetURL : URLString;
        attribute available : Boolean;
        attribute object : DigitalObject[0..1];
    }

    item def CacheEntry {
        attribute doi : DOIString;
        attribute metadata : Metadata;
        attribute lastAccessed : DateTime;
        attribute hitCount : Integer;
    }

    // ---- Port definitions ----
    port def UserRequestPort {
        in item request : DOILookupRequest;
        out item response : DOILookupResponse;
    }

    port def RegistryQueryPort {
        out item query : RegistryQuery;
        in item response : RegistryResponse;
    }

    port def ContentFetchPort {
        out item contentRequest : ContentRequest;
        in item contentResponse : ContentResponse;
    }

    port def CachePort {
        out item lookupDOI : DOIString;
        in item cacheResult : CacheEntry[0..1];
        out item storeEntry : CacheEntry;
        out item clearCache : Boolean;
    }

    // ---- Requirements ----
    requirement def ResolutionRequirement {
        attribute id : String = "REQ-001";
        attribute text : String = "The system shall resolve a valid DOI to its associated digital object or a direct link.";
    }

    requirement def FormatValidationRequirement {
        attribute id : String = "REQ-002";
        attribute text : String = "The system shall validate the format of a submitted DOI before processing.";
    }

    requirement def CacheRequirement {
        attribute id : String = "REQ-003";
        attribute text : String = "The system shall maintain a local cache of recently accessed metadata to accelerate resolution.";
    }

    requirement def RegistryQueryRequirement {
        attribute id : String = "REQ-004";
        attribute text : String = "The system shall query the DOI Registry for metadata when cache misses occur.";
    }

    requirement def ContentRetrievalRequirement {
        attribute id : String = "REQ-005";
        attribute text : String = "The system shall retrieve the digital object from the appropriate Content Provider using the resolved URL.";
    }

    requirement def ErrorHandlingRequirement {
        attribute id : String = "REQ-006";
        attribute text : String = "The system shall handle invalid DOIs, unregistered DOIs, and unavailable content gracefully.";
    }

    requirement def HighAvailabilityRequirement {
        attribute id : String = "REQ-007";
        attribute text : String = "The system shall be highly available and persistent, ensuring DOI links remain reliable for many years.";
    }

    requirement def MaintenanceRequirement {
        attribute id : String = "REQ-008";
        attribute text : String = "The system shall support a maintenance state for cache clearing and data synchronization.";
    }

    // ---- Parts ----

    part def DOIResolverEngine {
        port userPort : UserRequestPort;
        port registryPort : RegistryQueryPort;
        port contentPort : ContentFetchPort;

        attribute cache : CacheEntry[0..*];
        attribute maxCacheSize : Integer = 10000;

        requirement resolutionReq : ResolutionRequirement;
        requirement validationReq : FormatValidationRequirement;
        requirement cacheReq : CacheRequirement;
        requirement errorReq : ErrorHandlingRequirement;

        state def ResolverStateMachine {
            entry; then Idle;

            state Idle {
                entry;
                accept request : DOILookupRequest
                    then Validating;
            }

            state Validating {
                entry action validateDOI {
                    /* Validate DOI format */
                }
                transition validTransition
                    first Validating
                    accept ValidDOI
                    then CacheChecking;
                transition invalidTransition
                    first Validating
                    accept InvalidDOI
                    then HandlingError;
            }

            state CacheChecking {
                entry action checkCache {
                    /* Check local cache for DOI */
                }
                transition cacheHit
                    first CacheChecking
                    accept CacheHit
                    then FetchingContent;
                transition cacheMiss
                    first CacheChecking
                    accept CacheMiss
                    then QueryingRegistry;
            }

            state QueryingRegistry {
                entry action queryRegistry {
                    /* Send query to DOI Registry */
                }
                transition registryFound
                    first QueryingRegistry
                    accept RegistryResponse
                    guard found == true
                    then FetchingContent;
                transition registryNotFound
                    first QueryingRegistry
                    accept RegistryResponse
                    guard found == false
                    then HandlingError;
            }

            state FetchingContent {
                entry action fetchContent {
                    /* Request content from Content Provider */
                }
                transition contentAvailable
                    first FetchingContent
                    accept ContentResponse
                    guard available == true
                    then UpdatingCache;
                transition contentUnavailable
                    first FetchingContent
                    accept ContentResponse
                    guard available == false
                    then HandlingError;
            }

            state UpdatingCache {
                entry action updateCache {
                    /* Store retrieved metadata in cache */
                }
                transition cacheUpdated
                    first UpdatingCache
                    accept CacheUpdated
                    then DeliveringResponse;
            }

            state DeliveringResponse {
                entry action deliverResponse {
                    /* Deliver digital object to user */
                }
                transition responseDelivered
                    first DeliveringResponse
                    accept ResponseDelivered
                    then Idle;
            }

            state HandlingError {
                entry action handleError {
                    /* Generate error response */
                }
                transition errorHandled
                    first HandlingError
                    accept ErrorHandled
                    then Idle;
            }

            state Maintenance {
                entry action clearCaches {
                    /* Clear cache and synchronize data */
                }
                transition maintenanceComplete
                    first Maintenance
                    accept MaintenanceComplete
                    then Idle;
            }

            transition enterMaintenance
                first Idle
                accept MaintenanceTrigger
                then Maintenance;
        }

        exhibit state behavior : ResolverStateMachine;

        action def ValidateDOIAction {
            in doi : DOIString;
            out isValid : Boolean;
        }

        action def CheckCacheAction {
            in doi : DOIString;
            in cache : CacheEntry[0..*];
            out entry : CacheEntry[0..1];
        }

        action def QueryRegistryAction {
            in doi : DOIString;
            out metadata : Metadata[0..1];
            out found : Boolean;
        }

        action def FetchContentAction {
            in targetURL : URLString;
            in doi : DOIString;
            out object : DigitalObject[0..1];
            out available : Boolean;
        }

        action def UpdateCacheAction {
            in doi : DOIString;
            in metadata : Metadata;
            inout cache : CacheEntry[0..*];
        }

        action def DeliverResponseAction {
            in doi : DOIString;
            in object : DigitalObject[0..1];
            out response : DOILookupResponse;
        }

        action def HandleErrorAction {
            in doi : DOIString;
            in errorType : String;
            out response : DOILookupResponse;
        }

        action resolveDOI {
            in request : DOILookupRequest;
            out response : DOILookupResponse;

            // Validate DOI format
            action validate : ValidateDOIAction {
                in doi = request.doi;
                out isValid;
            }

            // Decision: valid or invalid
            decide isValid;
            if false then {
                action handleError : HandleErrorAction {
                    in doi = request.doi;
                    in errorType = "Invalid DOI format";
                    out response;
                }
            } else {
                // Check cache
                action checkCacheAction : CheckCacheAction {
                    in doi = request.doi;
                    in cache = cache;
                    out entry;
                }

                decide entry.isEmpty;
                if false then {
                    // Cache hit - fetch content directly
                    action fetchFromCache : FetchContentAction {
                        in targetURL = entry.metadata.targetURL;
                        in doi = request.doi;
                        out object;
                        out available;
                    }
                } else {
                    // Cache miss - query registry
                    action queryReg : QueryRegistryAction {
                        in doi = request.doi;
                        out metadata;
                        out found;
                    }

                    decide found;
                    if false then {
                        action handleNotFound : HandleErrorAction {
                            in doi = request.doi;
                            in errorType = "DOI not registered";
                            out response;
                        }
                    } else {
                        action fetchFromRegistry : FetchContentAction {
                            in targetURL = metadata.targetURL;
                            in doi = request.doi;
                            out object;
                            out available;
                        }

                        decide available;
                        if false then {
                            action handleUnavailable : HandleErrorAction {
                                in doi = request.doi;
                                in errorType = "Content unavailable";
                                out response;
                            }
                        } else {
                            // Update cache
                            action updateCacheAction : UpdateCacheAction {
                                in doi = request.doi;
                                in metadata = metadata;
                                inout cache = cache;
                            }

                            action deliver : DeliverResponseAction {
                                in doi = request.doi;
                                in object = object;
                                out response;
                            }
                        }
                    }
                }
            }
        }
    }

    part def DOIRegistry {
        port registryPort : RegistryQueryPort;

        attribute records : Metadata[0..*];
        attribute totalRecords : Integer;

        requirement registryReq : RegistryQueryRequirement;

        action def LookupDOIAction {
            in doi : DOIString;
            in records : Metadata[0..*];
            out metadata : Metadata[0..1];
            out found : Boolean;
        }

        action def RegisterDOIAction {
            in doi : DOIString;
            in metadata : Metadata;
            inout records : Metadata[0..*];
        }

        action handleQuery {
            in query : RegistryQuery;
            out response : RegistryResponse;

            action lookup : LookupDOIAction {
                in doi = query.doi;
                in records = records;
                out metadata;
                out found;
            }

            then assign response {
                response.doi = query.doi;
                response.found = found;
                response.metadata = metadata;
            }
        }

        exhibit action behavior : handleQuery;
    }

    part def ContentProvider {
        port contentPort : ContentFetchPort;

        attribute providerName : String;
        attribute baseURL : URLString;
        attribute hostedObjects : DigitalObject[0..*];

        requirement contentReq : ContentRetrievalRequirement;

        action def RetrieveObjectAction {
            in targetURL : URLString;
            in doi : DOIString;
            in hostedObjects : DigitalObject[0..*];
            out object : DigitalObject[0..1];
            out available : Boolean;
        }

        action handleContentRequest {
            in contentRequest : ContentRequest;
            out contentResponse : ContentResponse;

            action retrieve : RetrieveObjectAction {
                in targetURL = contentRequest.targetURL;
                in doi = contentRequest.doi;
                in hostedObjects = hostedObjects;
                out object;
                out available;
            }

            then assign contentResponse {
                contentResponse.targetURL = contentRequest.targetURL;
                contentResponse.available = available;
                contentResponse.object = object;
            }
        }

        exhibit action behavior : handleContentRequest;
    }

    part def DOIResolutionSystem {
        port userPort : UserRequestPort;

        part resolverEngine : DOIResolverEngine {
            port userPort;
            port registryPort;
            port contentPort;
        }

        part registry : DOIRegistry {
            port registryPort;
        }

        part contentProvider : ContentProvider {
            port contentPort;
        }

        requirement systemResolutionReq : ResolutionRequirement;
        requirement systemHighAvailReq : HighAvailabilityRequirement;
        requirement systemMaintenanceReq : MaintenanceRequirement;

        connection userConnection connect userPort to resolverEngine.userPort;
        connection registryConnection connect resolverEngine.registryPort to registry.registryPort;
        connection contentConnection connect resolverEngine.contentPort to contentProvider.contentPort;
    }
}
