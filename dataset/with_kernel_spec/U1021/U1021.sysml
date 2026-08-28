package CritiqueApprovalWorkflow {
	private import ScalarValues::*;
	private import ScalarFunctions::*;
	private import SI::*;
	private import ISQ::*;

	public import Definitions::*;
	public import Usages::*;

	package Definitions {
		private import ScalarValues::*;
		private import ScalarFunctions::*;
		private import SI::*;
		private import ISQ::*;

		occurrence def Submit;
		occurrence def CritiqueComplete;
		occurrence def RevisionNeeded;
		occurrence def Resubmit;
		occurrence def MeetsCriteria;
		occurrence def FailsCriteria;

		item def Work {
			attribute title : String;
			attribute workType : WorkKind;
			attribute content : String;
		}
		enum def WorkKind {
			document;
			design;
			code;
			proposal;
		}
		enum def SeverityLevel {
			minor;
			moderate;
			major;
			critical;
		}
		item def Issue {
			attribute description : String;
			attribute severity : SeverityLevel;
			attribute recommendation : String;
		}
		item def Critique {
			attribute qualityScore : Real;
			item issues : Issue[0..*];
			attribute summary : String;
		}
		item def Revision {
			attribute changeLog : String;
			attribute revisionNumber : Natural;
		}
		enum def DecisionKind {
			approved;
			rejected;
			revise;
		}
		item def Decision {
			attribute decision : DecisionKind;
			attribute rationale : String;
			attribute finalScore : Real;
		}
		enum def NotificationKind {
			submissionAcknowledged;
			reviewAssigned;
			critiqueReady;
			revisionRequested;
			approvedNotification;
			rejectedNotification;
		}
		item def Notification {
			attribute kind : NotificationKind;
			attribute text : String;
			attribute recipient : String;
		}
		part def Stakeholder {
			attribute name : String;
			attribute role : String;
		}
		port def WorkPort {
			in work : Work;
			out workOut : Work;
		}
		port def CritiquePort {
			in critique : Critique;
			out critiqueOut : Critique;
		}
		port def DecisionPort {
			in decision : Decision;
			out decisionOut : Decision;
		}
		port def NotificationPort {
			in notification : Notification;
			out notificationOut : Notification;
		}
		port def RevisionPort {
			in revision : Revision;
			out revisionOut : Revision;
		}
		interface def WorkFlow {
			end a : WorkPort;
			end b : ~WorkPort;
		}
		interface def CritiqueFlow {
			end a : CritiquePort;
			end b : ~CritiquePort;
		}
		interface def DecisionFlow {
			end a : DecisionPort;
			end b : ~DecisionPort;
		}
		interface def NotificationFlow {
			end a : NotificationPort;
			end b : ~NotificationPort;
		}
		interface def RevisionFlow {
			end a : RevisionPort;
			end b : ~RevisionPort;
		}
		requirement def MaxReviewTimeRequirement {
			doc /* The review engine must complete a review within a maximum time. */
			subject reviewDuration : Real;
			attribute maxDuration : Real = 48;
			require constraint { reviewDuration <= maxDuration }
		}
		requirement def MinQualityScoreRequirement {
			doc /* The quality score must meet or exceed a minimum threshold for approval. */
			subject score : Real;
			attribute minScore : Real = 0.8;
			require constraint { score >= minScore }
		}
		requirement def MaxRevisionCyclesRequirement {
			doc /* The number of revision cycles must not exceed a maximum. */
			subject cycles : Natural;
			attribute maxCycles : Natural = 3;
			require constraint { cycles <= maxCycles }
		}
		calc def EvaluateQuality {
			in issues : Issue[0..*];
			return score : Real;
		}
	}

	package Usages {
		private import ScalarValues::*;
		private import ScalarFunctions::*;
		private import SI::*;
		private import ISQ::*;
		private import Definitions::*;

		part def WorkQueue {
			doc /* Manages incoming work submissions in an orderly fashion. */
			attribute queueDepth : Natural = 0;
			port enqueuePort : WorkPort;
			port dequeuePort : WorkPort;
			state queueState {
				entry; then empty;
				state empty;
				state nonEmpty;
				transition empty_to_nonEmpty
					first empty
					accept enqueuePort.work
					then nonEmpty;
				transition nonEmpty_to_empty
					first nonEmpty
					accept dequeuePort.workOut
					then empty;
				transition nonEmpty_to_nonEmpty
					first nonEmpty
					accept enqueuePort.work
					then nonEmpty;
			}
		}

		part def ReviewEngine {
			doc /* Core analytical component that evaluates work and produces a critique. */
			attribute reviewTime : Real;
			port reviewInPort : WorkPort;
			port revisedWorkInPort : WorkPort;
			port critiqueOutPort : CritiquePort;
			perform action conductReview {
				in work : Work;
				out critique : Critique;
				action identifyIssues {
					in workIn : Work;
					out issues : Issue[0..*];
				}
				action assignSeverity {
					in issuesIn : Issue[0..*];
					out issuesOut : Issue[0..*];
				}
				action provideRecommendations {
					in issuesIn : Issue[0..*];
					out issuesOut : Issue[0..*];
				}
				action calculateScore : EvaluateQuality {
					in issues : Issue[0..*] = provideRecommendations.issuesOut;
				}
				action generateCritique {
					in issues : Issue[0..*] = provideRecommendations.issuesOut;
					in score : Real = calculateScore.score;
					out critiqueOut : Critique;
				}
				flow identifyIssues.issues to assignSeverity.issuesIn;
				flow assignSeverity.issuesOut to provideRecommendations.issuesIn;
				flow generateCritique.critiqueOut to critique;
			}
			state reviewState {
				entry; then idle;
				state idle;
				state reviewing {
					do action reviewWork {
						in work : Work;
						out critique : Critique;
					}
				}
				state completed;
				transition idle_to_reviewing
					first idle
					accept reviewInPort.work
					then reviewing;
				transition reviewing_to_completed
					first reviewing
					accept critiqueOutPort.critiqueOut
					then completed;
				transition completed_to_idle
					first completed
					accept revisedWorkInPort.work
					then idle;
			}
		}

		part def RevisionTracker {
			doc /* Logs changes and ensures revisions address critique feedback. */
			attribute revisionCount : Natural = 0;
			attribute maxRevisions : Natural = 3;
			port workInPort : WorkPort;
			port critiqueInPort : CritiquePort;
			port revisionOutPort : WorkPort;
			port revisionLogPort : RevisionPort;
			perform action trackRevision {
				in work : Work;
				in critique : Critique;
				out revisedWork : Work;
				out revision : Revision;
				action logChanges {
					in workIn : Work;
					in critiqueIn : Critique;
					out revisionOut : Revision;
				}
				action applyRevisions {
					in workIn : Work;
					in revisionIn : Revision;
					out workOut : Work;
				}
				flow logChanges.revisionOut to applyRevisions.revisionIn;
				flow applyRevisions.workOut to revisedWork;
				flow logChanges.revisionOut to revision;
			}
			state revisionState {
				entry; then waiting;
				state waiting;
				state revising;
				transition waiting_to_revising
					first waiting
					accept critiqueInPort.critique
					then revising;
				transition revising_to_waiting
					first revising
					accept revisionOutPort.workOut
					then waiting;
			}
		}

		part def ApprovalAuthority {
			doc /* Makes the final approval or rejection decision. */
			attribute approvalThreshold : Real = 0.8;
			attribute revisionCount : Natural = 0;
			attribute maxRevisions : Natural = 3;
			port workInPort : WorkPort;
			port critiqueInPort : CritiquePort;
			port decisionOutPort : DecisionPort;
			port reviseOutPort : WorkPort;
			perform action makeDecision {
				in work : Work;
				in critique : Critique;
				out decision : Decision;
				action compareScore {
					in score : Real;
					in threshold : Real;
					out passes : Boolean;
				}
				action issueDecision {
					in workIn : Work;
					in critiqueIn : Critique;
					in passes : Boolean;
					out decisionOut : Decision;
				}
				flow compareScore.passes to issueDecision.passes;
				flow issueDecision.decisionOut to decision;
			}
			state approvalState {
				entry; then pending;
				state pending;
				state approved;
				state rejected;
				state needsRevision;
				transition pending_to_approved
					first pending
					accept critiqueInPort.critique
					then approved;
				transition pending_to_rejected
					first pending
					accept critiqueInPort.critique
					then rejected;
				transition pending_to_needsRevision
					first pending
					accept critiqueInPort.critique
					then needsRevision;
			}
		}

		part def NotificationService {
			doc /* Sends alerts to stakeholders throughout the workflow. */
			port notifyInPort : NotificationPort;
			port notifyOutPort : NotificationPort;
			perform action sendNotification {
				in notification : Notification;
				out notificationOut : Notification;
				action formatMessage {
					in notificationIn : Notification;
					out notificationOut : Notification;
				}
				action dispatch {
					in notificationIn : Notification;
					out notificationOut : Notification;
				}
				flow formatMessage.notificationOut to dispatch.notificationIn;
				flow dispatch.notificationOut to notificationOut;
			}
			state notificationState {
				entry; then ready;
				state ready;
				state sending;
				transition ready_to_sending
					first ready
					accept notifyInPort.notification
					then sending;
				transition sending_to_ready
					first sending
					accept notifyOutPort.notificationOut
					then ready;
			}
		}

		part def WorkflowSystem {
			port workInput : WorkPort;
			port decisionOutput : DecisionPort;
			port notificationOutput : NotificationPort;

			part workQueue : WorkQueue;
			part reviewEngine : ReviewEngine;
			part revisionTracker : RevisionTracker;
			part approvalAuthority : ApprovalAuthority;
			part notificationService : NotificationService;

			connection submitToQueue connect workInput to workQueue.enqueuePort;
			connection queueToReview connect workQueue.dequeuePort to reviewEngine.reviewInPort;
			connection reviewToRevision connect reviewEngine.critiqueOutPort to revisionTracker.critiqueInPort;
			connection workToRevision connect reviewEngine.reviewInPort to revisionTracker.workInPort;
			connection revisionToReview connect revisionTracker.revisionOutPort to reviewEngine.revisedWorkInPort;
			connection reviewToApproval connect reviewEngine.critiqueOutPort to approvalAuthority.critiqueInPort;
			connection workToApproval connect reviewEngine.reviewInPort to approvalAuthority.workInPort;
			connection approvalToRevision connect approvalAuthority.reviseOutPort to revisionTracker.workInPort;
			connection approvalDecision connect approvalAuthority.decisionOutPort to decisionOutput;
			connection notifyFlow connect notificationService.notifyOutPort to notificationOutput;

			requirement maxReviewTime : MaxReviewTimeRequirement;
			requirement minQualityScore : MinQualityScoreRequirement;
			requirement maxRevisionCycles : MaxRevisionCyclesRequirement;
		}

		part WorkItemLifecycle {
			doc /* Represents the lifecycle of a work item through the workflow. */
			attribute currentState : String;
			state lifecycle {
				entry; then submitted;
				state submitted;
				state underReview;
				state critiqued;
				state revised;
				state approved;
				state rejected;
				transition submit_to_review
					first submitted
					accept Submit
					then underReview;
				transition review_to_critiqued
					first underReview
					accept CritiqueComplete
					then critiqued;
				transition critiqued_to_revised
					first critiqued
					accept RevisionNeeded
					then revised;
				transition revised_to_review
					first revised
					accept Resubmit
					then underReview;
				transition critiqued_to_approved
					first critiqued
					accept MeetsCriteria
					then approved;
				transition critiqued_to_rejected
					first critiqued
					accept FailsCriteria
					then rejected;
			}
		}
	}
}
