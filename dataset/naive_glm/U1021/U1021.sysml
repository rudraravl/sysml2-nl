package CritiqueApprovalWorkflow {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    
    value def QualityScoreValue :> Real {
        doc /* Quality score on a 0..100 scale. */
        attribute max : Real = 100;
        constraint { 0 <= self & self <= max }
    }
    
    value def ReviewTimeValue :> Real {
        doc /* Review time in hours. */
        unit hours;
    }
    
    value def RevisionCountValue :> Integer {
        doc /* Number of revision cycles completed. */
    }
    
    // ---- Enumerations ----
    
    enum def SeverityLevel {
        minor;
        moderate;
        major;
        critical;
    }
    
    enum def WorkType {
        document;
        design;
        code;
        proposal;
    }
    
    enum def DecisionKind {
        approve;
        reject;
        requestRevision;
    }
    
    enum def NotificationKind {
        submissionReceived;
        reviewAssigned;
        critiqueReady;
        revisionRequested;
        revisionReceived;
        approved;
        rejected;
    }
    
    // ---- Item definitions ----
    
    item def WorkItem {
        attribute id : String;
        attribute title : String;
        attribute type : WorkType;
        attribute submitterId : String;
        attribute contentRef : String;
        attribute submissionTimestamp : TimeInstantValue;
    }
    
    item def Issue {
        attribute id : String;
        attribute description : String;
        attribute severity : SeverityLevel;
        attribute recommendation : String;
    }
    
    item def CritiqueDocument {
        attribute id : String;
        attribute workItemId : String;
        attribute issues : Issue[0..*];
        attribute qualityScore : QualityScoreValue;
        attribute summary : String;
        attribute generatedTimestamp : TimeInstantValue;
    }
    
    item def RevisionLog {
        attribute id : String;
        attribute workItemId : String;
        attribute changeDescription : String;
        attribute addressedIssueIds : String[0..*];
        attribute revisionTimestamp : TimeInstantValue;
    }
    
    item def ApprovalCriteria {
        attribute minQualityScore : QualityScoreValue = 75;
        attribute maxRevisions : RevisionCountValue = 3;
        attribute maxReviewTime : ReviewTimeValue = 48 [hours];
    }
    
    item def Notification {
        attribute id : String;
        attribute recipientId : String;
        attribute kind : NotificationKind;
        attribute subject : String;
        attribute body : String;
        attribute timestamp : TimeInstantValue;
    }
    
    // ---- Ports ----
    
    port def WorkSubmissionPort {
        out item work : WorkItem;
    }
    
    port def WorkProcessingPort {
        in item work : WorkItem;
        out item work : WorkItem;
    }
    
    port def CritiqueOutputPort {
        out item critique : CritiqueDocument;
    }
    
    port def RevisionPort {
        in item work : WorkItem;
        in item critique : CritiqueDocument;
        out item revisedWork : WorkItem;
        out item revisionLog : RevisionLog;
    }
    
    port def DecisionPort {
        in item work : WorkItem;
        in item critique : CritiqueDocument;
        out attribute decision : DecisionKind;
    }
    
    port def NotificationPort {
        out item notification : Notification;
    }
    
    // ---- Parts ----
    
    part def WorkQueue {
        port workIn : WorkSubmissionPort;
        port workOut : WorkProcessingPort;
        
        attribute queuedItems : WorkItem[0..*] ordered;
        
        action def Enqueue {
            in item newWork : WorkItem;
            out item storedWork : WorkItem;
        }
        
        action def Dequeue {
            out item nextWork : WorkItem;
        }
        
        action enqueue : Enqueue {
            in item newWork = workIn.work;
            out item storedWork = queuedItems;
        }
        
        action dequeue : Dequeue {
            out item nextWork = workOut.work;
        }
        
        state def QueueBehavior {
            entry; then Idle;
            state Idle;
            transition Idle_to_Busy
                first Idle
                accept enqueue
                then Busy;
            state Busy;
            transition Busy_to_Idle
                first Busy
                accept dequeue
                then Idle;
        }
    }
    
    part def ReviewEngine {
        port workIn : WorkProcessingPort;
        port critiqueOut : CritiqueOutputPort;
        
        attribute currentWork : WorkItem[0..1];
        attribute currentCritique : CritiqueDocument[0..1];
        
        action def AnalyzeWork {
            in item work : WorkItem;
            out item critique : CritiqueDocument;
            
            private attribute identifiedIssues : Issue[0..*];
            private attribute computedScore : QualityScoreValue;
            
            action identifyIssues {
                in item work : WorkItem;
                out item issues : Issue[0..*];
            }
            
            action assignSeverity {
                in item issues : Issue[0..*];
                out item severityTaggedIssues : Issue[0..*];
            }
            
            action generateRecommendations {
                in item issues : Issue[0..*];
                out item enrichedIssues : Issue[0..*];
            }
            
            action calculateScore {
                in item issues : Issue[0..*];
                out attribute score : QualityScoreValue;
            }
            
            action composeCritique {
                in item issues : Issue[0..*];
                in attribute score : QualityScoreValue;
                out item critique : CritiqueDocument;
            }
            
            flow identifyIssues.issues -> assignSeverity.issues;
            flow assignSeverity.severityTaggedIssues -> generateRecommendations.issues;
            flow generateRecommendations.enrichedIssues -> calculateScore.issues;
            flow generateRecommendations.enrichedIssues -> composeCritique.issues;
            flow calculateScore.score -> composeCritique.score;
        }
        
        action analyze : AnalyzeWork {
            in item work : WorkItem = workIn.work;
            out item critique : CritiqueDocument = critiqueOut.critique;
        }
        
        state def ReviewBehavior {
            entry; then Waiting;
            state Waiting;
            transition Waiting_to_Reviewing
                first Waiting
                accept workIn.work
                then Reviewing;
            state Reviewing;
            transition Reviewing_to_Waiting
                first Reviewing
                accept analyze
                then Waiting;
        }
    }
    
    part def RevisionTracker {
        port revisionIn : RevisionPort;
        port workOut : WorkProcessingPort;
        
        attribute revisionCount : RevisionCountValue = 0;
        attribute maxRevisions : RevisionCountValue = 3;
        attribute revisionLogs : RevisionLog[0..*];
        
        action def TrackRevision {
            in item work : WorkItem;
            in item critique : CritiqueDocument;
            out item revisedWork : WorkItem;
            out item log : RevisionLog;
            
            action logChanges {
                in item work : WorkItem;
                in item critique : CritiqueDocument;
                out item log : RevisionLog;
            }
            
            action verifyAddressedFeedback {
                in item critique : CritiqueDocument;
                in item log : RevisionLog;
                out attribute verified : Boolean;
            }
            
            action produceRevisedWork {
                in item work : WorkItem;
                in item log : RevisionLog;
                out item revisedWork : WorkItem;
            }
            
            flow logChanges.log -> verifyAddressedFeedback.log;
            flow logChanges.log -> produceRevisedWork.log;
        }
        
        action track : TrackRevision {
            in item work : WorkItem = revisionIn.work;
            in item critique : CritiqueDocument = revisionIn.critique;
            out item revisedWork : WorkItem = workOut.work;
            out item log : RevisionLog = revisionIn.revisionLog;
        }
        
        state def RevisionBehavior {
            entry; then Idle;
            state Idle;
            transition Idle_to_Logging
                first Idle
                accept revisionIn
                then Logging;
            state Logging;
            transition Logging_to_Idle
                first Logging
                accept track
                then Idle;
        }
    }
    
    part def ApprovalAuthority {
        port decisionIn : DecisionPort;
        port notificationOut : NotificationPort;
        
        attribute criteria : ApprovalCriteria;
        attribute decision : DecisionKind;
        
        action def Evaluate {
            in item work : WorkItem;
            in item critique : CritiqueDocument;
            out attribute decision : DecisionKind;
            
            private attribute score : QualityScoreValue;
            private attribute revisionCount : RevisionCountValue;
            
            action compareScore {
                in attribute score : QualityScoreValue;
                in attribute minScore : QualityScoreValue;
                out attribute meetsScore : Boolean;
            }
            
            action checkRevisionLimit {
                in attribute revisionCount : RevisionCountValue;
                in attribute maxRevisions : RevisionCountValue;
                out attribute withinLimit : Boolean;
            }
            
            action decide {
                in attribute meetsScore : Boolean;
                in attribute withinLimit : Boolean;
                out attribute decision : DecisionKind;
            }
            
            flow compareScore.meetsScore -> decide.meetsScore;
            flow checkRevisionLimit.withinLimit -> decide.withinLimit;
        }
        
        action evaluate : Evaluate {
            in item work : WorkItem = decisionIn.work;
            in item critique : CritiqueDocument = decisionIn.critique;
            out attribute decision : DecisionKind = decisionIn.decision;
        }
        
        state def ApprovalBehavior {
            entry; then Pending;
            state Pending;
            transition Pending_to_Evaluating
                first Pending
                accept decisionIn
                then Evaluating;
            state Evaluating;
            transition Evaluating_to_Pending
                first Evaluating
                accept evaluate
                then Pending;
        }
    }
    
    part def NotificationService {
        port notificationOut : NotificationPort;
        
        attribute sentNotifications : Notification[0..*];
        
        action def SendNotification {
            in item notification : Notification;
            out attribute sent : Boolean;
        }
        
        action send : SendNotification {
            in item notification : Notification = notificationOut.notification;
            out attribute sent : Boolean;
        }
        
        state def NotificationBehavior {
            entry; then Idle;
            state Idle;
            transition Idle_to_Sending
                first Idle
                accept notificationOut.notification
                then Sending;
            state Sending;
            transition Sending_to_Idle
                first Sending
                accept send
                then Idle;
        }
    }
    
    // ---- Top-level system ----
    
    part def CritiqueApprovalSystem {
        port submissionPort : WorkSubmissionPort;
        port externalNotification : NotificationPort;
        
        part workQueue : WorkQueue {
            port workIn : WorkSubmissionPort;
            port workOut : WorkProcessingPort;
        }
        
        part reviewEngine : ReviewEngine {
            port workIn : WorkProcessingPort;
            port critiqueOut : CritiqueOutputPort;
        }
        
        part revisionTracker : RevisionTracker {
            port revisionIn : RevisionPort;
            port workOut : WorkProcessingPort;
        }
        
        part approvalAuthority : ApprovalAuthority {
            port decisionIn : DecisionPort;
            port notificationOut : NotificationPort;
        }
        
        part notificationService : NotificationService {
            port notificationOut : NotificationPort;
        }
        
        attribute criteria : ApprovalCriteria;
        
        // Internal connections
        connection workQueueToReview : WorkProcessingPort connect workQueue.workOut to reviewEngine.workIn;
        
        // The review engine produces a critique; a routing decision determines
        // whether the work goes to revision or to approval. This is modeled
        // through the shared flow of the critique and work item.
        connection reviewToRevision : RevisionPort connect reviewEngine.critiqueOut to revisionTracker.revisionIn;
        
        connection revisionToReview : WorkProcessingPort connect revisionTracker.workOut to reviewEngine.workIn;
        
        connection reviewToApproval : DecisionPort connect reviewEngine.critiqueOut to approvalAuthority.decisionIn;
        
        connection approvalNotification : NotificationPort connect approvalAuthority.notificationOut to notificationService.notificationOut;
        
        connection externalNotificationLink : NotificationPort connect notificationService.notificationOut to externalNotification;
        
        // System-level state machine governing the lifecycle of a work item
        state def WorkItemLifecycle {
            attribute revisionCount : RevisionCountValue = 0;
            attribute maxRevisions : RevisionCountValue = 3;
            attribute minQualityScore : QualityScoreValue = 75;
            attribute maxReviewTime : ReviewTimeValue = 48 [hours];
            
            entry; then Submitted;
            
            state Submitted;
            transition Submitted_to_UnderReview
                first Submitted
                accept workQueue.workOut.work
                then UnderReview;
            
            state UnderReview;
            transition UnderReview_to_Critiqued
                first UnderReview
                accept reviewEngine.critiqueOut.critique
                then Critiqued;
            
            state Critiqued;
            
            transition Critiqued_to_Revised
                first Critiqued
                accept revisionTracker.revisionIn
                then Revised;
            
            transition Critiqued_to_Approved
                first Critiqued
                if reviewEngine.critiqueOut.critique.qualityScore >= minQualityScore
                accept approvalAuthority.decisionIn
                then Approved;
            
            state Revised;
            transition Revised_to_UnderReview
                first Revised
                accept revisionTracker.workOut.work
                then UnderReview;
            
            state Approved;
            state Rejected;
            
            transition Critiqued_to_Rejected
                first Critiqued
                if revisionCount >= maxRevisions & reviewEngine.critiqueOut.critique.qualityScore < minQualityScore
                accept approvalAuthority.decisionIn
                then Rejected;
        }
        
        state lifecycle : WorkItemLifecycle;
    }
    
    // ---- Requirements ----
    
    requirement def ShallEnforceOrderlyQueueing {
        doc /* The system shall place all submitted work items into a Work Queue for orderly processing. */
        subject workQueue : WorkQueue;
        objective ensureOrderlyProcessing;
    }
    
    requirement def ShallProduceCritique {
        doc /* The Review Engine shall produce a formal critique document identifying issues, severity, recommendations, and a quality score. */
        subject reviewEngine : ReviewEngine;
        objective provideStructuredFeedback;
    }
    
    requirement def ShallTrackRevisions {
        doc /* The Revision Tracker shall log all changes and verify that revisions address critique feedback. */
        subject revisionTracker : RevisionTracker;
        attribute maxRevisions : RevisionCountValue = 3;
        objective ensureIterativeImprovement;
    }
    
    requirement def ShallMakeFinalDecision {
        doc /* The Approval Authority shall compare the quality score against approval criteria and approve or reject the work. */
        subject approvalAuthority : ApprovalAuthority;
        attribute minQualityScore : QualityScoreValue = 75;
        objective ensureQualityStandard;
    }
    
    requirement def ShallNotifyStakeholders {
        doc /* The NotificationService shall send alerts to submitters and reviewers about status changes and final decisions. */
        subject notificationService : NotificationService;
        objective keepStakeholdersInformed;
    }
    
    requirement def ShallEnforceLifecycle {
        doc /* Each work item shall move through distinct lifecycle states: submitted, under review, critiqued, revised, approved, or rejected. */
        subject system : CritiqueApprovalSystem;
        objective enforceProcessDiscipline;
    }
    
    requirement def ShallEnforceTimeAndQualityRules {
        doc /* The system shall enforce a maximum review time and a minimum quality score for approval. */
        subject system : CritiqueApprovalSystem;
        attribute maxReviewTime : ReviewTimeValue = 48 [hours];
        attribute minQualityScore : QualityScoreValue = 75;
        objective ensureTimelyAndHighQualityOutcomes;
    }
    
    requirement package SystemRequirements {
        requirement req1 : ShallEnforceOrderlyQueueing;
        requirement req2 : ShallProduceCritique;
        requirement req3 : ShallTrackRevisions;
        requirement req4 : ShallMakeFinalDecision;
        requirement req5 : ShallNotifyStakeholders;
        requirement req6 : ShallEnforceLifecycle;
        requirement req7 : ShallEnforceTimeAndQualityRules;
    }
    
    // ---- Satisfaction ----
    
    satisfaction satisfyQueueing : req1 subject workQueue;
    satisfaction satisfyCritique : req2 subject reviewEngine;
    satisfaction satisfyRevisions : req3 subject revisionTracker;
    satisfaction satisfyDecision : req4 subject approvalAuthority;
    satisfaction satisfyNotification : req5 subject notificationService;
    satisfaction satisfyLifecycle : req6 subject lifecycle;
    satisfaction satisfyRules : req7 subject lifecycle;
}
