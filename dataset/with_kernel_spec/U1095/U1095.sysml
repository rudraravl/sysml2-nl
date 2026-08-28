package SerialPublicationsManagement {
    private import ScalarValues::*;

    attribute def ISSNCode :> String;

    item def PublicationApplication {
        attribute title : String;
        attribute publisher : String;
        attribute publicationType : String;
    }

    item def ISSNAssignment {
        attribute issn : ISSNCode;
        attribute title : String;
        attribute publisher : String;
        attribute isApproved : Boolean;
    }

    part def Article {
        attribute title : String;
        attribute authors : String[*];
        attribute doi : String;
    }

    part def Publication {
        attribute issn : ISSNCode;
        attribute title : String;
        attribute publisher : String;
        attribute publicationType : String;
        part issues : Issue[*];
    }

    part def Issue {
        ref publication : Publication;
        attribute volumeNumber : Integer;
        attribute issueNumber : Integer;
        attribute publicationDate : String;
        attribute status : String;
        part articles : Article[*];
    }

    part def Subscriber {
        attribute subscriberId : String;
        attribute name : String;
        attribute subscriptionType : String;
        attribute isActive : Boolean;
    }

    item def DistributionMessage {
        ref issue : Issue;
        ref subscriber : Subscriber;
    }

    item def CatalogEntry {
        attribute issn : ISSNCode;
        attribute title : String;
        attribute publisher : String;
        ref latestIssue : Issue;
    }

    item def ArchiveRecord {
        ref issue : Issue;
        attribute archiveDate : String;
        attribute storageLocation : String;
    }

    port def RegistrationRequestPort {
        in ref application : PublicationApplication;
        out ref assignment : ISSNAssignment;
    }

    port def IssuePublicationPort {
        in ref publishedIssue : Issue;
    }

    port def IssueDistributionPort {
        in ref issueToDistribute : Issue;
        out ref distributions : DistributionMessage[*];
    }

    port def IssueCatalogPort {
        in ref issueToIndex : Issue;
    }

    port def IssueArchivePort {
        in ref issueToArchive : Issue;
    }

    interface def RegistrationInterface {
        end applicant : ~RegistrationRequestPort;
        end authority : RegistrationRequestPort;
    }

    interface def PublicationDistributionInterface {
        end source : ~IssuePublicationPort;
        end target : IssueDistributionPort;
    }

    interface def PublicationCatalogInterface {
        end source : ~IssuePublicationPort;
        end target : IssueCatalogPort;
    }

    interface def PublicationArchiveInterface {
        end source : ~IssuePublicationPort;
        end target : IssueArchivePort;
    }

    state def IssueWorkflow {
        state Draft;
        state UnderReview;
        state Approved;
        state Published;
        transition from Draft to UnderReview;
        transition from UnderReview to Approved;
        transition from UnderReview to Draft;
        transition from Approved to Published;
    }

    part def ISSNRegistrationAuthority {
        port registrationPort : RegistrationRequestPort {
            in ref :>> application;
            out ref :>> assignment;
        }

        perform action registerPublication {
            action validateApplication {
                in ref app : PublicationApplication;
                out attribute isValid : Boolean;
            }
            then action verifyUniqueness {
                in ref app : PublicationApplication;
                out attribute isUnique : Boolean;
            }
            then action assignISSN {
                in ref app : PublicationApplication;
                in attribute isValid : Boolean = validateApplication.isValid;
                in attribute isUnique : Boolean = verifyUniqueness.isUnique;
                out ref assigned : ISSNAssignment;
            }
        }

        flow app1 from registrationPort.application to registerPublication.validateApplication.app;
        flow app2 from registrationPort.application to registerPublication.verifyUniqueness.app;
        flow app3 from registrationPort.application to registerPublication.assignISSN.app;
        flow assignmentOut from registerPublication.assignISSN.assigned to registrationPort.assignment;
    }

    part def EditorialManagementSystem {
        port registrationPort : ~RegistrationRequestPort {
            out ref :>> application;
            in ref :>> assignment;
        }
        port publicationPort : ~IssuePublicationPort {
            out ref :>> publishedIssue;
        }

        part registeredPublications : Publication[*];

        state issueWorkflow : IssueWorkflow;

        perform action manageIssue {
            action createApplication {
                out ref request : PublicationApplication;
            }
            then action receiveAssignment {
                in ref assignment : ISSNAssignment;
            }
            then action createDraftIssue {
                in ref assignment : ISSNAssignment;
                out ref draftIssue : Issue;
            }
            then action reviewIssue {
                in ref issue : Issue = createDraftIssue.draftIssue;
                out ref reviewedIssue : Issue;
            }
            then action approveIssue {
                in ref issue : Issue = reviewIssue.reviewedIssue;
                out ref approvedIssue : Issue;
            }
            then action publishIssue {
                in ref issue : Issue = approveIssue.approvedIssue;
                out ref published : Issue;
            }
        }

        flow appOut from manageIssue.createApplication.request to registrationPort.application;
        flow assignmentIn1 from registrationPort.assignment to manageIssue.receiveAssignment.assignment;
        flow assignmentIn2 from registrationPort.assignment to manageIssue.createDraftIssue.assignment;
        flow issueOut from manageIssue.publishIssue.published to publicationPort.publishedIssue;
    }

    part def SubscriptionManagementSystem {
        port distributionPort : IssueDistributionPort {
            in ref :>> issueToDistribute;
            out ref :>> distributions;
        }

        part subscribers : Subscriber[*];

        perform action distributeIssue {
            action getActiveSubscribers {
                in ref issue : Issue;
                out ref activeSubs : Subscriber[*];
            }
            then action sendToSubscribers {
                in ref issue : Issue;
                in ref subs : Subscriber[*] = getActiveSubscribers.activeSubs;
                out ref distributions : DistributionMessage[*];
            }
        }

        flow distIn1 from distributionPort.issueToDistribute to distributeIssue.getActiveSubscribers.issue;
        flow distIn2 from distributionPort.issueToDistribute to distributeIssue.sendToSubscribers.issue;
        flow distOut from distributeIssue.sendToSubscribers.distributions to distributionPort.distributions;
    }

    part def CatalogSystem {
        port catalogPort : IssueCatalogPort {
            in ref :>> issueToIndex;
        }

        item catalogEntries : CatalogEntry[*];

        perform action indexIssue {
            action extractMetadata {
                in ref issue : Issue;
                out attribute issn : ISSNCode;
                out attribute title : String;
            }
            then action updateCatalog {
                in ref issue : Issue;
                in attribute issn : ISSNCode = extractMetadata.issn;
                in attribute title : String = extractMetadata.title;
                out ref entry : CatalogEntry;
            }
        }

        perform action searchCatalog {
            in attribute searchTerm : String;
            out ref results : CatalogEntry[*];
        }

        flow indexIn1 from catalogPort.issueToIndex to indexIssue.extractMetadata.issue;
        flow indexIn2 from catalogPort.issueToIndex to indexIssue.updateCatalog.issue;
    }

    part def ArchiveSystem {
        port archivePort : IssueArchivePort {
            in ref :>> issueToArchive;
        }

        part archivedIssues : Issue[*];

        perform action archiveIssue {
            action prepareForStorage {
                in ref issue : Issue;
                out ref preparedIssue : Issue;
            }
            then action storeIssue {
                in ref issue : Issue = prepareForStorage.preparedIssue;
                out ref record : ArchiveRecord;
            }
        }

        flow archiveIn from archivePort.issueToArchive to archiveIssue.prepareForStorage.issue;
    }

    part def SerialPublicationsSystem {
        part registrationAuthority : ISSNRegistrationAuthority;
        part editorialSystem : EditorialManagementSystem;
        part subscriptionSystem : SubscriptionManagementSystem;
        part catalogSystem : CatalogSystem;
        part archiveSystem : ArchiveSystem;

        interface registrationInterface : RegistrationInterface
            connect editorialSystem.registrationPort to registrationAuthority.registrationPort {
                flow app from registrationInterface.applicant.application to registrationInterface.authority.application;
                flow assigned from registrationInterface.authority.assignment to registrationInterface.applicant.assignment;
            }

        interface distributionInterface : PublicationDistributionInterface
            connect editorialSystem.publicationPort to subscriptionSystem.distributionPort {
                flow issue from distributionInterface.source.publishedIssue to distributionInterface.target.issueToDistribute;
            }

        interface catalogInterface : PublicationCatalogInterface
            connect editorialSystem.publicationPort to catalogSystem.catalogPort {
                flow issue from catalogInterface.source.publishedIssue to catalogInterface.target.issueToIndex;
            }

        interface archiveInterface : PublicationArchiveInterface
            connect editorialSystem.publicationPort to archiveSystem.archivePort {
                flow issue from archiveInterface.source.publishedIssue to archiveInterface.target.issueToArchive;
            }
    }

    requirement def Req_ISSNUniqueness {
        text "Every serial publication must be assigned a globally unique ISSN code upon registration.";
    }

    requirement def Req_EditorialWorkflow {
        text "Issues must progress through draft, review, approval, and published states before distribution.";
    }

    requirement def Req_Distribution {
        text "Published issues must be automatically distributed to all active subscribers.";
    }

    requirement def Req_CatalogDiscoverability {
        text "All registered publications must be indexed in the public catalog for search by title, publisher, or ISSN.";
    }

    requirement def Req_ArchivePreservation {
        text "Published issues must be securely stored in the archive system for long-term preservation.";
    }
}
