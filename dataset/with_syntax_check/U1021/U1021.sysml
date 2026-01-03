package CritiqueWorkSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    enum def WorkType {
        document;
        design;
        code;
        proposal;
        report;
    }
    
    enum def CritiqueSeverity {
        minor;
        moderate;
        major;
        critical;
    }
    
    enum def WorkflowState {
        submitted;
        queued;
        underReview;
        critiqued;
        revised;
        approved;
        rejected;
    }
    
    item def WorkItem {
        attribute workId : String;
        attribute title : String;
        attribute workType : WorkType;
        attribute content : String;
        attribute submissionTimestamp : TimeInstantValue;
        attribute currentState : WorkflowState;
        attribute revisionNumber : Integer;
    }
    
    item def CritiqueItem {
        attribute critiqueId : String;
        attribute workId : String;
        attribute reviewerName : String;
        attribute findings : String[0..*];
        attribute severity : CritiqueSeverity;
        attribute score : Real;
        attribute recommendations : String[0..*];
        attribute timestamp : TimeInstantValue;
    }
    
    item def RevisionRecord {
        attribute revisionId : String;
        attribute originalWorkId : String;
        attribute changes : String;
        attribute revisionTimestamp : TimeInstantValue;
        attribute critiqueAddressed : String[0..*];
    }
    
    port def WorkSubmissionPort {
        in item workIn : WorkItem;
        out item acknowledgment : String;
    }
    
    port def CritiquePort {
        in item workForReview : WorkItem;
        out item critiqueOut : CritiqueItem;
    }
    
    port def RevisionPort {
        in item revisedWork : WorkItem;
        out item revisionStatus : String;
    }
    
    port def ApprovalPort {
        in item workForApproval : WorkItem;
        in item associatedCritique : CritiqueItem;
        out item approvalDecision : Boolean;
    }
    
    part def WorkQueue {
        attribute queuedWorks : WorkItem[0..*];
        attribute maxQueueSize : Integer;
        
        port workInPort : WorkSubmissionPort;
        port workOutPort : WorkSubmissionPort;
        
        action enqueueWork {
            in work : WorkItem;
            out position : Integer;
        }
        
        action dequeueWork {
            out nextWork : WorkItem;
        }
        
        action checkQueueStatus {
            out queueLength : Integer;
            out isQueueFull : Boolean;
        }
    }
    
    part def ReviewEngine {
        attribute activeReviews : CritiqueItem[0..*];
        attribute qualityThreshold : Real;
        attribute averageReviewTime : DurationValue;
        
        port reviewInPort : CritiquePort;
        port reviewOutPort : CritiquePort;
        
        action analyzeWork {
            in work : WorkItem;
            out analysisResult : String;
        }
        
        action identifyIssues {
            in work : WorkItem;
            out issues : String[0..*];
        }
        
        action generateCritique {
            in work : WorkItem;
            in issues : String[0..*];
            out critique : CritiqueItem;
        }
        
        action calculateScore {
            in work : WorkItem;
            in critique : CritiqueItem;
            out score : Real;
        }
    }
    
    part def RevisionTracker {
        attribute revisionHistory : RevisionRecord[0..*];
        attribute maxRevisionsAllowed : Integer;
        
        port revisionInPort : RevisionPort;
        port revisionOutPort : RevisionPort;
        
        action recordRevision {
            in originalWork : WorkItem;
            in revisedWork : WorkItem;
            out record : RevisionRecord;
        }
        
        action compareVersions {
            in original : WorkItem;
            in revised : WorkItem;
            out differences : String;
        }
        
        action validateRevision {
            in revision : RevisionRecord;
            in critique : CritiqueItem;
            out isComplete : Boolean;
        }
    }
    
    part def ApprovalAuthority {
        attribute approvalCriteria : Real;
        attribute approvedWorks : WorkItem[0..*];
        attribute rejectedWorks : WorkItem[0..*];
        
        port approvalInPort : ApprovalPort;
        port approvalOutPort : ApprovalPort;
        
        action evaluateForApproval {
            in work : WorkItem;
            in critique : CritiqueItem;
            out meetsStandards : Boolean;
        }
        
        action issueApproval {
            in work : WorkItem;
            out approvalCertificate : String;
        }
        
        action issueRejection {
            in work : WorkItem;
            in reason : String;
            out rejectionNotice : String;
        }
    }
    
    part def NotificationService {
        attribute pendingNotifications : String[0..*];
        
        action notifySubmitter {
            in workId : String;
            in message : String;
        }
        
        action notifyReviewer {
            in workId : String;
            in assignmentDetails : String;
        }
        
        action broadcastStatus {
            in workId : String;
            in status : WorkflowState;
        }
    }
    
    action def SubmitWorkAction {
        in work : WorkItem;
        out submissionConfirmation : String;
    }
    
    action def ReviewWorkAction {
        in work : WorkItem;
        out critique : CritiqueItem;
    }
    
    action def ReviseWorkAction {
        in originalWork : WorkItem;
        in critique : CritiqueItem;
        out revisedWork : WorkItem;
    }
    
    action def ApproveWorkAction {
        in work : WorkItem;
        in critique : CritiqueItem;
        out isApproved : Boolean;
    }
    
    action def CritiqueWorkflow {
        doc /* 
            Primary workflow orchestrating the complete critique process from submission 
            through review, revision cycles, and final approval or rejection.
        */
        
        first start;
        then merge workEntry;
        
        action receiveSubmission : SubmitWorkAction {
            in work : WorkItem;
            out submissionConfirmation : String;
        }
        then workEntry;
        
        then action queueWork {
            in work : WorkItem;
            out queuePosition : Integer;
        }
        then assignToReviewer;
        
        action assignToReviewer {
            in work : WorkItem;
            out assignedReviewer : String;
        }
        then conductReview;
        
        action conductReview : ReviewWorkAction {
            in work : WorkItem;
            out critique : CritiqueItem;
        }
        then evaluateCritique;
        
        action evaluateCritique {
            in critique : CritiqueItem;
            out needsRevision : Boolean;
            out canApprove : Boolean;
        }
        then decide critiqueDecision;
            if evaluateCritique.needsRevision then requestRevision;
            if evaluateCritique.canApprove then proceedToApproval;
        
        action requestRevision {
            in critique : CritiqueItem;
            out revisionRequest : String;
        }
        then awaitRevision;
        
        action awaitRevision {
            out revisedWork : WorkItem;
        }
        then action processRevision : ReviseWorkAction {
            in originalWork : WorkItem;
            in critique : CritiqueItem;
            out revisedWork : WorkItem;
        }
        then checkRevisionCount;
        
        action checkRevisionCount {
            in work : WorkItem;
            out exceedsLimit : Boolean;
        }
        then decide revisionDecision;
            if checkRevisionCount.exceedsLimit then rejectWork;
            if !checkRevisionCount.exceedsLimit then workEntry;
        
        action proceedToApproval : ApproveWorkAction {
            in work : WorkItem;
            in critique : CritiqueItem;
            out isApproved : Boolean;
        }
        then decide approvalDecision;
            if proceedToApproval.isApproved then finalizeApproval;
            if !proceedToApproval.isApproved then rejectWork;
        
        action finalizeApproval {
            in work : WorkItem;
            out approvalRecord : String;
        }
        then notifyCompletion;
        
        action rejectWork {
            in work : WorkItem;
            out rejectionRecord : String;
        }
        then notifyCompletion;
        
        action notifyCompletion {
            in workId : String;
            in finalStatus : WorkflowState;
        }
        then done;
    }
    
    state def WorkLifecycleStateMachine {
        entry; then submitted;
        
        state submitted {
            entry; do action logSubmission;
        }
        
        transition submitted_to_queued
            first submitted
            then queued;
        
        state queued {
            entry; do action updateQueuePosition;
        }
        
        transition queued_to_underReview
            first queued
            then underReview;
        
        state underReview {
            entry; do action startReviewTimer;
        }
        
        transition review_to_critiqued
            first underReview
            then critiqued;
        
        state critiqued {
            entry; do action deliverCritique;
        }
        
        transition critiqued_to_revised
            first critiqued
            then revised;
        
        transition critiqued_to_approved
            first critiqued
            then approved;
        
        transition critiqued_to_rejected
            first critiqued
            then rejected;
        
        state revised {
            entry; do action recordRevision;
        }
        
        transition revised_to_queued
            first revised
            then queued;
        
        state approved {
            entry; do action issueApprovalCertificate;
        }
        
        state rejected {
            entry; do action issueRejectionNotice;
        }
    }
    
    constraint def ReviewTimeConstraint {
        in reviewDuration : DurationValue;
        in maxDuration : DurationValue;
        reviewDuration <= maxDuration
    }
    
    constraint def QualityScoreConstraint {
        in score : Real;
        in minimumScore : Real;
        score >= minimumScore
    }
    
    constraint def RevisionLimitConstraint {
        in revisionCount : Integer;
        in maxRevisions : Integer;
        revisionCount <= maxRevisions
    }
    
    requirement def CritiqueSystemRequirements {
        doc /* 
            Top-level requirements for the critique work system ensuring quality,
            timeliness, and completeness of the review process.
        */
        
        requirement <'REQ-001'> acceptWorkSubmissions {
            doc /* The system shall accept work submissions of multiple types and formats. */
        }
        
        requirement <'REQ-002'> conductThoroughReview {
            doc /* The system shall conduct comprehensive critique identifying all significant issues. */
        }
        
        requirement <'REQ-003'> provideActionableFeedback {
            doc /* All critiques shall include specific, actionable recommendations for improvement. */
        }
        
        requirement <'REQ-004'> trackRevisions {
            doc /* The system shall maintain complete revision history for all work items. */
        }
        
        requirement <'REQ-005'> enforceQualityStandards {
            doc /* The system shall enforce minimum quality standards before approval. */
        }
        
        requirement <'REQ-006'> timelyProcessing {
            doc /* The system shall complete initial review within 48 hours of submission. */
        }
    }
    
    part def CritiqueWorkSystem {
        part queue : WorkQueue;
        part reviewEngine : ReviewEngine;
        part revisionTracker : RevisionTracker;
        part approvalAuthority : ApprovalAuthority;
        part notificationService : NotificationService;
    }
    
    part critiqueWorkSystem : CritiqueWorkSystem {
        doc /* 
            A comprehensive system for critiquing submitted work through systematic review,
            feedback generation, and iterative improvement cycles.
            
            Primary Function: The system receives work submissions, queues them for review,
            conducts thorough critique by qualified reviewers, manages revision cycles based
            on feedback, and ultimately approves or rejects work based on quality standards.
            
            The system ensures consistent quality through structured evaluation, maintains
            complete audit trails of all reviews and revisions, and facilitates continuous
            improvement through actionable feedback loops.
        */
        
        part :>> queue {
            attribute :>> maxQueueSize = 100;
        }
        
        part :>> reviewEngine {
            attribute :>> qualityThreshold = 7.0;
            attribute :>> averageReviewTime = 24 [h];
        }
        
        part :>> revisionTracker {
            attribute :>> maxRevisionsAllowed = 3;
        }
        
        part :>> approvalAuthority {
            attribute :>> approvalCriteria = 8.0;
        }
        
        part :>> notificationService;
        
        connection queueToReview : WorkSubmissionPort
            connect queue.workOutPort to reviewEngine.reviewInPort;
        
        connection reviewToRevision : CritiquePort
            connect reviewEngine.reviewOutPort to revisionTracker.revisionInPort;
        
        connection revisionToApproval : RevisionPort
            connect revisionTracker.revisionOutPort to approvalAuthority.approvalInPort;
        
        assert constraint reviewTimeLimit : ReviewTimeConstraint {
            in reviewDuration = reviewEngine.averageReviewTime;
            in maxDuration = 48 [h];
        }
        
        assert constraint qualityMinimum : QualityScoreConstraint {
            in score = approvalAuthority.approvalCriteria;
            in minimumScore = 7.5;
        }
        
        assert constraint revisionLimit : RevisionLimitConstraint {
            in revisionCount = revisionTracker.maxRevisionsAllowed;
            in maxRevisions = 5;
        }
        
        perform action primaryWorkflow : CritiqueWorkflow;
        
        exhibit state workLifecycle : WorkLifecycleStateMachine;
        
        satisfy CritiqueSystemRequirements::acceptWorkSubmissions by queue;
        satisfy CritiqueSystemRequirements::conductThoroughReview by reviewEngine;
        satisfy CritiqueSystemRequirements::provideActionableFeedback by reviewEngine;
        satisfy CritiqueSystemRequirements::trackRevisions by revisionTracker;
        satisfy CritiqueSystemRequirements::enforceQualityStandards by approvalAuthority;
        satisfy CritiqueSystemRequirements::timelyProcessing by reviewEngine;
    }
}
