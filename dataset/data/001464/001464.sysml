package 'ISSN Publication Management System' {
    private import ScalarValues::*;
    private import ISQ::*;
    
    attribute def ISSNCode :> String;
    
    attribute def PublicationMetadata {
        attribute title : String;
        attribute publisher : String;
        attribute issn : ISSNCode;
        attribute publicationFrequency : String;
        attribute publicationLanguage : String;
        attribute subjectArea : String;
    }
    
    attribute def SubscriberRecord {
        attribute subscriberId : String;
        attribute subscriberName : String;
        attribute email : String;
        attribute subscriptionType : SubscriptionType;
        attribute expirationDate : String;
    }
    
    enum def SubscriptionType {
        enum individualSubscription;
        enum institutionalSubscription;
        enum trialSubscription;
    }
    
    enum def PublicationStatus {
        enum active;
        enum suspended;
        enum ceased;
        enum transferred;
    }
    
    enum def IssueStatus {
        enum draft;
        enum review;
        enum approved;
        enum published;
        enum archived;
    }
    
    item def SerialIssue {
        attribute volumeNumber : Integer;
        attribute issueNumber : Integer;
        attribute publicationDate : String;
        attribute pageCount : Integer;
        attribute issueStatus : IssueStatus;
        attribute doi : String;
    }
    
    item def Article {
        attribute articleTitle : String;
        attribute authors : String[1..*];
        attribute articleAbstract : String;
        attribute keywords : String[*];
        attribute pageRange : String;
    }
    
    item def RegistrationRequest {
        attribute requestMetadata : PublicationMetadata;
        attribute requestDate : String;
        attribute applicantName : String;
    }
    
    item def RegistrationResponse {
        attribute assignedISSN : ISSNCode;
        attribute registrationDate : String;
        attribute certificateNumber : String;
        attribute isApproved : Boolean;
    }
    
    port def RegistrationPort {
        in item request : RegistrationRequest;
        out item response : RegistrationResponse;
    }
    
    port def ContentPort {
        in item submission : SerialIssue;
        out item published : SerialIssue;
    }
    
    port def SubscriberPort {
        in item subscription : SubscriberRecord;
        out item delivery : SerialIssue;
    }
    
    port def CatalogPort {
        in item query : String;
        out item results : PublicationMetadata[*];
    }
    
    part def ISSNRegistrationAuthority {
        attribute registeredPublications : PublicationMetadata[*];
        attribute totalRegistrations : Integer;
        
        port registrationInterface : RegistrationPort;
        
        action def ValidateISSNFormat {
            in code : ISSNCode;
            out isValid : Boolean;
        }
        
        action def AssignISSN {
            in request : RegistrationRequest;
            out response : RegistrationResponse;
        }
        
        action def VerifyUniqueness {
            in proposedISSN : ISSNCode;
            out isUnique : Boolean;
        }
        
        action processRegistration {
            in applicationRequest : RegistrationRequest;
            out registrationResult : RegistrationResponse;
            
            first start;
            then action validateApplication {
                out valid : Boolean;
            }
            then decide;
                if validateApplication.valid then assignCode;
                else rejectApplication;
            
            action assignCode {
                action generateISSN {
                    out newISSN : ISSNCode;
                }
                then action checkUnique : VerifyUniqueness {
                    out isUnique : Boolean;
                }
                then decide;
                    if checkUnique.isUnique then approveRegistration;
                    else generateISSN;
                
                action approveRegistration;
                then done;
            }
            
            action rejectApplication;
            then done;
        }
    }
    
    part def EditorialManagementSystem {
        attribute pendingIssues : SerialIssue[*];
        attribute publishedIssues : SerialIssue[*];
        
        port contentInterface : ContentPort;
        
        action def ReviewContent {
            in issue : SerialIssue;
            out reviewPassed : Boolean;
        }
        
        action def ApproveForPublication {
            in issue : SerialIssue;
            out approvedIssue : SerialIssue;
        }
        
        action manageIssuePublication {
            in submittedIssue : SerialIssue;
            out finalIssue : SerialIssue;
            
            first start;
            then action receiveSubmission;
            then action reviewIssue : ReviewContent {
                out reviewPassed : Boolean;
            }
            then decide;
                if reviewIssue.reviewPassed then approveIssue;
                else requestRevision;
            
            action approveIssue : ApproveForPublication {
                out approvedIssue : SerialIssue;
            }
            then action publishIssue;
            then done;
            
            action requestRevision;
            then done;
        }
    }
    
    part def SubscriptionManagementSystem {
        attribute activeSubscribers : SubscriberRecord[*];
        attribute subscriptionCount : Integer;
        
        port subscriberInterface : SubscriberPort[*];
        
        action def ProcessSubscription {
            in subscriber : SubscriberRecord;
            out confirmed : Boolean;
        }
        
        action def ValidateSubscription {
            in subscriber : SubscriberRecord;
            out isActive : Boolean;
        }
        
        action def DeliverIssue {
            in issue : SerialIssue;
            in subscriber : SubscriberRecord;
            out delivered : Boolean;
        }
        
        action distributeToSubscribers {
            in publishedIssue : SerialIssue;
            in subscribers : SubscriberRecord[*];
            out distributionComplete : Boolean;
            
            first start;
            then action validateIssue {
                out ready : Boolean;
            }
            then decide;
                if validateIssue.ready then distributeLoop;
                else done;
            
            action distributeLoop {
                action checkSubscription : ValidateSubscription {
                    out isActive : Boolean;
                }
                then decide;
                    if checkSubscription.isActive then deliver;
                    else skipSubscriber;
                
                action deliver : DeliverIssue {
                    out delivered : Boolean;
                }
                then done;
                
                action skipSubscriber;
                then done;
            }
        }
    }
    
    part def CatalogSystem {
        attribute catalogEntries : PublicationMetadata[*];
        attribute totalEntries : Integer;
        
        port catalogInterface : CatalogPort;
        
        action def SearchByISSN {
            in issn : ISSNCode;
            out results : PublicationMetadata[*];
        }
        
        action def SearchByTitle {
            in title : String;
            out results : PublicationMetadata[*];
        }
        
        action def UpdateCatalog {
            in catalogMetadata : PublicationMetadata;
            out updated : Boolean;
        }
        
        action performSearch {
            in searchQuery : String;
            out searchResults : PublicationMetadata[*];
            
            first start;
            then action parseQuery {
                out queryType : String;
            }
            then decide;
                if parseQuery.queryType == "ISSN" then searchISSN;
                else searchTitle;
            
            action searchISSN : SearchByISSN {
                out results : PublicationMetadata[*];
            }
            then collectResults;
            
            action searchTitle : SearchByTitle {
                out results : PublicationMetadata[*];
            }
            then collectResults;
            
            action collectResults;
            then done;
        }
    }
    
    part def ArchiveSystem {
        attribute archivedIssues : SerialIssue[*];
        attribute storageCapacity : Real;
        
        action def ArchiveIssue {
            in issue : SerialIssue;
            out archived : Boolean;
        }
        
        action def RetrieveIssue {
            in issueId : String;
            out issue : SerialIssue;
        }
        
        action archivePublishedIssue {
            in publishedIssue : SerialIssue;
            out archiveComplete : Boolean;
            
            first start;
            then action prepareForArchive;
            then action storeIssue : ArchiveIssue {
                out archived : Boolean;
            }
            then action confirmArchive;
            then done;
        }
    }
    
    action def ManageSerialPublication {
        in registrationRequest : RegistrationRequest;
        in newIssue : SerialIssue;
        in subscriberList : SubscriberRecord[*];
        out issnAssigned : ISSNCode;
        out issuePublished : SerialIssue;
        out distributionStatus : Boolean;
        
        first start;
        then action registerPublication {
            out registration : RegistrationResponse;
        }
        then decide;
            if registerPublication.registration.isApproved then processIssue;
            else done;
        
        action processIssue {
            action editorialProcess {
                out published : SerialIssue;
            }
            then action distributeIssue {
                out distributed : Boolean;
            }
            then action archiveIssue {
                out archived : Boolean;
            }
            then action updateCatalog {
                out catalogUpdated : Boolean;
            }
            then finalizePublication;
        }
        
        action finalizePublication;
        then done;
    }
    
    part def ISSNPublicationSystem {
        part registry : ISSNRegistrationAuthority;
        part editorial : EditorialManagementSystem;
        part subscription : SubscriptionManagementSystem;
        part catalog : CatalogSystem;
        part archive : ArchiveSystem;
        
        connection registryToEditorial connect registry.registrationInterface to editorial.contentInterface;
        connection editorialToSubscription connect editorial.contentInterface to subscription.subscriberInterface;
        connection editorialToCatalog connect editorial.contentInterface to catalog.catalogInterface;
        
        perform action publicationWorkflow : ManageSerialPublication[*] ordered;
    }
    
    part issnPublicationSystem : ISSNPublicationSystem {
        doc /*
            The ISSN Publication Management System is a comprehensive platform for managing
            serial publications identified by International Standard Serial Numbers (ISSN).
            Its primary function is to coordinate the complete lifecycle of periodical
            publications including registration of new serials with unique ISSN identifiers,
            editorial management of individual issues, subscription management for
            distribution to subscribers, cataloging for discovery and retrieval, and
            long-term archival preservation. The system ensures each serial publication
            maintains a globally unique identifier while facilitating efficient content
            production, distribution, and access for journals, magazines, newspapers,
            and other continuing resources in both print and electronic formats.
        */
    }
    
    requirement def UniqueIdentifierRequirement;
    requirement def LifecycleManagementRequirement;
    requirement def DistributionRequirement;
    requirement def CatalogRequirement;
    
    requirement <'ISSN-REQ-001'> uniqueIdentifierAssignment : UniqueIdentifierRequirement {
        doc /*
            Each serial publication registered in the system shall be assigned a unique
            ISSN code that conforms to ISO 3297 standard format and is globally unique
            across all registered publications.
        */
        
        subject issnPublicationSystem.registry;
    }
    
    requirement <'ISSN-REQ-002'> publicationLifecycleManagement : LifecycleManagementRequirement {
        doc /*
            The system shall manage the complete lifecycle of serial publications from
            initial ISSN registration through editorial processing, distribution to
            subscribers, and archival preservation.
        */
        
        subject issnPublicationSystem;
    }
    
    requirement <'ISSN-REQ-003'> subscriberDistribution : DistributionRequirement {
        doc /*
            The system shall distribute published issues only to subscribers with active
            subscription status and valid subscription records.
        */
        
        subject issnPublicationSystem.subscription;
    }
    
    requirement <'ISSN-REQ-004'> catalogAccessibility : CatalogRequirement {
        doc /*
            The system shall maintain a searchable catalog of all registered publications
            enabling discovery by ISSN, title, publisher, and subject classification.
        */
        
        subject issnPublicationSystem.catalog;
    }
    
    requirement systemMissionRequirement {
        doc /*
            The ISSN Publication Management System shall provide comprehensive management
            of serial publications throughout their entire lifecycle while ensuring global
            uniqueness of identifiers and accessibility of content.
        */
        
        require uniqueIdentifierAssignment;
        require publicationLifecycleManagement;
        require subscriberDistribution;
        require catalogAccessibility;
    }
}
