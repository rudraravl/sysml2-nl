package 'DigitalObjectIdentifierSystem' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def DoiIdentifier {
		attribute prefix : String;
		attribute suffix : String;
		attribute fullIdentifier : String;
	}
	
	attribute def ResourceMetadata {
		attribute title : String;
		attribute creators : String[1..*];
		attribute publicationYear : Integer;
		attribute publisher : String;
		attribute resourceType : String;
		attribute targetUrl : String;
	}
	
	attribute def QueryStatus {
		attribute resolved : Boolean;
		attribute responseTime : DurationValue;
		attribute httpStatusCode : Integer;
	}
	
	item def DigitalObject {
		attribute objectMetadata : ResourceMetadata;
		attribute location : String;
		attribute format : String;
	}
	
	port def DoiRequestPort {
		in attribute doiQuery : DoiIdentifier;
		out attribute objectResponse : DigitalObject;
		out attribute queryStatus : QueryStatus;
	}
	
	port def RegistryPort {
		in attribute lookupRequest : DoiIdentifier;
		out attribute metadataResponse : ResourceMetadata;
	}
	
	port def ContentPort {
		in attribute contentRequest : String;
		out attribute digitalContent : DigitalObject;
	}
	
	part def DoiResolverEngine {
		port requestInterface : DoiRequestPort;
		attribute cacheStore : ResourceMetadata[0..*];
		attribute performanceMetrics : QueryStatus;
	}
	
	part def DoiRegistry {
		port registryInterface : RegistryPort;
		attribute registeredIdentifiers : DoiIdentifier[1..*];
		attribute metadataStore : ResourceMetadata[1..*];
		attribute registryCapacity : Integer;
	}
	
	part def ContentProvider {
		port contentInterface : ContentPort;
		attribute availableObjects : DigitalObject[1..*];
		attribute storageCapacity : MassValue;
	}
	
	action def ValidateDoiFormat {
		in inputDoi : DoiIdentifier;
		out isValidFormat : Boolean;
		out normalizedDoi : DoiIdentifier;
	}
	
	action def CheckCache {
		in doi : DoiIdentifier;
		out cacheHit : Boolean;
		out cachedMetadata : ResourceMetadata;
	}
	
	action def QueryRegistry {
		in doi : DoiIdentifier;
		out registryMetadata : ResourceMetadata;
		out registryFound : Boolean;
	}
	
	action def FetchContent {
		in targetUrl : String;
		out content : DigitalObject;
		out fetchSuccess : Boolean;
	}
	
	action def UpdateCache {
		in doi : DoiIdentifier;
		in cacheMetadata : ResourceMetadata;
	}
	
	action def DeliverResponse {
		in content : DigitalObject;
		in responseMetadata : ResourceMetadata;
		out response : DigitalObject;
	}
	
	action def LogError {
		in errorCode : String;
		in errorDetails : String;
		out errorRecord : String;
	}
	
	action def PerformMaintenance {
		doc /* Perform system maintenance including cache cleanup and registry synchronization. */
	}
	
	action resolveDoiRequest {
		doc /* Core workflow for resolving a DOI to its associated digital object. 
		       The process validates the DOI format, checks cache for recent lookups, 
		       queries the central registry for metadata, fetches the actual content, 
		       updates the cache, and delivers the response to the requester. */
		
		in submittedDoi : DoiIdentifier;
		out resolvedObject : DigitalObject;
		
		first start;
		
		then action validate : ValidateDoiFormat {
			in inputDoi = submittedDoi;
			out isValidFormat : Boolean;
			out normalizedDoi : DoiIdentifier;
		}
		
		then decide;
			if validate.isValidFormat then checkCache;
			if not validate.isValidFormat then logValidationError;
		
		action checkCache : CheckCache {
			in doi = validate.normalizedDoi;
			out cacheHit : Boolean;
			out cachedMetadata : ResourceMetadata;
		}
		then decide;
			if checkCache.cacheHit then fetchFromCache;
			if not checkCache.cacheHit then queryRegistry;
		
		action fetchFromCache : FetchContent {
			in targetUrl = checkCache.cachedMetadata.targetUrl;
			out content : DigitalObject;
			out fetchSuccess : Boolean;
		}
		then decide;
			if fetchFromCache.fetchSuccess then deliverCachedResponse;
			if not fetchFromCache.fetchSuccess then queryRegistry;
		
		action deliverCachedResponse : DeliverResponse {
			in content = fetchFromCache.content;
			in responseMetadata = checkCache.cachedMetadata;
			out response : DigitalObject;
		}
		then done;
		
		action queryRegistry : QueryRegistry {
			in doi = validate.normalizedDoi;
			out registryMetadata : ResourceMetadata;
			out registryFound : Boolean;
		}
		then decide;
			if queryRegistry.registryFound then fetchContent;
			if not queryRegistry.registryFound then logRegistryError;
		
		action fetchContent : FetchContent {
			in targetUrl = queryRegistry.registryMetadata.targetUrl;
			out content : DigitalObject;
			out fetchSuccess : Boolean;
		}
		then decide;
			if fetchContent.fetchSuccess then updateCache;
			if not fetchContent.fetchSuccess then logFetchError;
		
		action updateCache : UpdateCache {
			in doi = validate.normalizedDoi;
			in cacheMetadata = queryRegistry.registryMetadata;
		}
		then deliverResponse;
		
		action deliverResponse : DeliverResponse {
			in content = fetchContent.content;
			in responseMetadata = queryRegistry.registryMetadata;
			out response : DigitalObject;
		}
		then done;
		
		action logValidationError : LogError {
			in errorCode = "DOI_INVALID_FORMAT";
			in errorDetails = "Submitted DOI does not conform to standard format";
			out errorRecord : String;
		}
		then done;
		
		action logRegistryError : LogError {
			in errorCode = "DOI_NOT_FOUND";
			in errorDetails = "DOI not registered in central registry";
			out errorRecord : String;
		}
		then done;
		
		action logFetchError : LogError {
			in errorCode = "CONTENT_UNAVAILABLE";
			in errorDetails = "Unable to retrieve digital object from target location";
			out errorRecord : String;
		}
		then done;
	}
	
	part def DoiResolutionSystem {
		doc /* A Digital Object Identifier (DOI) resolution system that provides persistent 
		       identification and location services for digital resources. The system accepts 
		       DOI queries, resolves them through a central registry, and returns access 
		       information to the requested digital objects. This enables reliable citation 
		       and retrieval of scholarly publications, datasets, and other digital content. */
		
		part resolver : DoiResolverEngine {
			perform action resolutionWorkflow[*] ordered references resolveDoiRequest;
		}
		
		part registry : DoiRegistry {
			perform resolutionWorkflow.queryRegistry;
		}
		
		part provider : ContentProvider {
			perform resolutionWorkflow.fetchContent;
		}
		
		connection resolverToRegistry connect 
			resolver.requestInterface to registry.registryInterface;
		
		connection registryToProvider connect 
			registry.registryInterface to provider.contentInterface;
	}
	
	requirement def ResolutionPerformanceRequirement {
		doc /* The DOI resolution system shall resolve valid DOI requests with acceptable performance. */
		
		require constraint {
			doc /* Average resolution time shall not exceed 1.5 seconds for 95% of requests. */
		}
	}
	
	requirement def PersistenceRequirement {
		doc /* The system shall maintain persistent and accurate mappings between DOIs and digital objects. */
		
		require constraint {
			doc /* DOI-to-resource mappings shall remain valid and accessible for minimum 10 years. */
		}
	}
	
	requirement def AvailabilityRequirement {
		doc /* The DOI resolution system shall provide high availability for resolution services. */
		
		require constraint {
			doc /* System uptime shall be 99.9% or higher measured annually. */
		}
	}
	
	requirement def UniquenessRequirement {
		doc /* Each DOI shall uniquely identify exactly one digital object. */
		
		require constraint {
			doc /* No two different digital objects shall be assigned the same DOI. */
		}
	}
	
	requirement <'DOI-SYS-REQ-001'> primarySystemRequirements {
		doc /* Top-level requirements for the Digital Object Identifier resolution system 
		       ensuring reliable, persistent, and performant identification services. */
		
		subject system : DoiResolutionSystem;
		
		require performanceReq : ResolutionPerformanceRequirement;
		require persistenceReq : PersistenceRequirement;
		require availabilityReq : AvailabilityRequirement;
		require uniquenessReq : UniquenessRequirement;
	}
	
	state def SystemOperationalState {
		entry; then operational;
		
		state operational {
			entry; then idle;
			
			state idle {
				accept doiRequest;
				then processing;
			}
			
			state processing {
				do action resolveDoiRequest;
				accept resolutionComplete;
				then idle;
			}
			
			accept maintenanceRequest;
			then maintenance;
		}
		
		state maintenance {
			do action PerformMaintenance;
			accept maintenanceComplete;
			then operational;
		}
	}
	
	part doiSystemInstance : DoiResolutionSystem {
		exhibit state operationalBehavior : SystemOperationalState;
	}
}
