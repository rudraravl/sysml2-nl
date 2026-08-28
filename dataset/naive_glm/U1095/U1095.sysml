package SerialPublicationsManagementSystem {
    import ScalarValues::*;
    
    // Value Types
    value type ISSN {
        attribute code : String;
    }
    
    value type Date {
        attribute value : String;
    }
    
    // Item Definitions
    item def PublicationApplication {
        attribute title : String;
        attribute publisher : String;
        attribute type : String; 
    }
    
    item def Publication {
        attribute issn : ISSN;
        attribute title : String;
        attribute publisher : String;
        attribute type : String;
    }
    
    item def Article {
        attribute title : String;
        attribute authors : String;
        attribute content : String;
    }
    
    item def Issue {
        attribute issn : ISSN;
        attribute volume : Integer;
        attribute issueNumber : Integer;
        attribute publicationDate : Date;
        attribute articles : Article[0..*];
        attribute status : String;
    }
    
    item def Subscriber {
        attribute id : String;
        attribute name : String;
        attribute type : String; 
        attribute status : String; 
    }
    
    // Interfaces
    interface def RegistrationRequestInterface {
        end application : PublicationApplication;
    }
    
    interface def RegistrationResponseInterface {
        end publication : Publication;
    }
    
    interface def IssueInterface {
        end issue : Issue;
    }
    
    interface def DistributionInterface {
        end issue : Issue;
        end subscriber : Subscriber;
    }
    
    // Parts
    part def ISSNRegistrationAuthority {
        port requestIn : RegistrationRequestInterface;
        port responseOut : RegistrationResponseInterface;
        
        attribute registeredPublications : Publication[0..*];
        
        action def RegisterPublication {
            in application : PublicationApplication;
            out publication : Publication;
        }
        
        state RegistrationState {
            state Validating;
            state AssigningISSN;
            state Registered;
            transition from Validating to AssigningISSN;
            transition from AssigningISSN to Registered;
        }
    }
    
    part def EditorialManagementSystem {
        port requestOut : RegistrationRequestInterface;
        port responseIn : RegistrationResponseInterface;
        port publishedIssueOut : IssueInterface;
        
        attribute issues : Issue[0..*];
        
        action def CreateIssue {
            in issn : ISSN;
            out issue : Issue;
        }
        
        action def ApproveIssue {
            in out issue : Issue;
        }
        
        state IssueLifecycle {
            state Draft;
            state Review;
            state Approved;
            state Published;
            transition from Draft to Review;
            transition from Review to Approved;
            transition from Approved to Published;
        }
    }
    
    part def SubscriptionManagementSystem {
        port publishedIssueIn : IssueInterface;
        port distributionOut : DistributionInterface;
        
        attribute subscribers : Subscriber[0..*];
        
        action def DistributeIssue {
            in issue : Issue;
            out distributedTo : Subscriber[0..*];
        }
        
        state SubscriptionState {
            state Active;
            state Expired;
            state Suspended;
        }
    }
    
    part def CatalogSystem {
        port publishedIssueIn : IssueInterface;
        
        attribute catalogEntries : Issue[0..*];
        
        action def IndexIssue {
            in issue : Issue;
        }
        
        action def SearchPublication {
            in query : String;
            out results : Publication[0..*];
        }
    }
    
    part def ArchiveSystem {
        port publishedIssueIn : IssueInterface;
        
        attribute archivedIssues : Issue[0..*];
        
        action def ArchiveIssue {
            in issue : Issue;
        }
        
        state ArchiveState {
            state Receiving;
            state Storing;
            state Preserved;
            transition from Receiving to Storing;
            transition from Storing to Preserved;
        }
    }
    
    // Top-level System
    part def SerialPublicationsSystem {
        part issnAuthority : ISSNRegistrationAuthority;
        part editorialSystem : EditorialManagementSystem;
        part subscriptionSystem : SubscriptionManagementSystem;
        part catalogSystem : CatalogSystem;
        part archiveSystem : ArchiveSystem;
        
        connection editorialToIssn : RegistrationRequestInterface connect editorialSystem.requestOut to issnAuthority.requestIn;
        connection issnToEditorial : RegistrationResponseInterface connect issnAuthority.responseOut to editorialSystem.responseIn;
        
        connection editorialToSubscription : IssueInterface connect editorialSystem.publishedIssueOut to subscriptionSystem.publishedIssueIn;
        connection editorialToCatalog : IssueInterface connect editorialSystem.publishedIssueOut to catalogSystem.publishedIssueIn;
        connection editorialToArchive : IssueInterface connect editorialSystem.publishedIssueOut to archiveSystem.publishedIssueIn;
    }
    
    // Requirements
    requirement def RegistrationRequirement {
        subject : PublicationApplication;
        require {
            constraint { subject.title != "" }
            constraint { subject.publisher != "" }
        }
    }
    
    requirement def IssueApprovalRequirement {
        subject : Issue;
        require {
            constraint { subject.status == "Approved" }
        }
    }
    
    requirement def DistributionRequirement {
        subject : Issue;
        require {
            constraint { subject.status == "Published" }
        }
    }
    
    requirement def ArchiveRequirement {
        subject : Issue;
        require {
            constraint { subject.status == "Published" }
        }
    }
}
