package EPLBasedSystemModel {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Text;
    attribute def Identifier;
    attribute def Boolean;
    attribute def Count :> ScalarValues::Integer;
    attribute def Percent :> ScalarValues::Real;
    attribute def Second :> SI::second;
    attribute def Byte :> SI::byte;
    attribute def FileCount :> Count;
    attribute def RiskScore :> Percent;
    attribute def ReviewLatency :> Second;
    attribute def RepositorySize :> Byte;

    item def SourceArtifact {
        attribute path : Text;
        attribute contentHash : Identifier;
        attribute size : RepositorySize;
        attribute detectedLicense : Text;
        attribute isModified : Boolean;
    }

    item def LicenseNotice {
        attribute licenseName : Text = "Eclipse Public License 2.0";
        attribute licenseIdentifier : Text = "EPL-2.0";
        attribute copyrightText : Text;
        attribute sourceAvailabilityStatement : Text;
    }

    item def ComplianceFinding {
        attribute artifactPath : Text;
        attribute severity : RiskScore;
        attribute findingText : Text;
        attribute remediationRequired : Boolean;
    }

    item def ComplianceReport {
        attribute reportId : Identifier;
        attribute scannedFiles : FileCount;
        attribute openFindings : Count;
        attribute complianceScore : Percent;
        attribute summary : Text;
    }

    item def ReleaseDecision {
        attribute approved : Boolean;
        attribute decisionReason : Text;
        attribute approver : Text;
    }

    port def ArtifactInputPort {
        in item artifact : SourceArtifact;
    }

    port def NoticeOutputPort {
        out item notice : LicenseNotice;
    }

    port def FindingOutputPort {
        out item finding : ComplianceFinding;
    }

    port def ReportOutputPort {
        out item report : ComplianceReport;
    }

    port def DecisionInputPort {
        in item decision : ReleaseDecision;
    }

    interface def ArtifactFlow {
        end source : ArtifactInputPort;
        end sink : ArtifactInputPort;
    }

    interface def FindingFlow {
        end source : FindingOutputPort;
        end sink : FindingOutputPort;
    }

    interface def ReportFlow {
        end source : ReportOutputPort;
        end sink : ReportOutputPort;
    }

    part def RepositoryCollector {
        port repositoryInput : ArtifactInputPort;
        port artifactOutput : ArtifactInputPort;

        attribute repositoryUri : Text;
        attribute collectedArtifactCount : FileCount;
        attribute totalRepositorySize : RepositorySize;

        action collectArtifacts {
            in item repositoryRoot : Text;
            out item artifacts : SourceArtifact;
        }
    }

    part def LicenseScanner {
        port artifactInput : ArtifactInputPort;
        port findingOutput : FindingOutputPort;

        attribute supportedLicenseId : Text = "EPL-2.0";
        attribute scanLatencyLimit : ReviewLatency = 300 [SI::s];
        attribute scannedArtifactCount : FileCount;

        action inspectArtifact {
            in item artifact : SourceArtifact;
            out item finding : ComplianceFinding;
        }
    }

    part def NoticeManager {
        port artifactInput : ArtifactInputPort;
        port noticeOutput : NoticeOutputPort;

        attribute canonicalLicenseName : Text = "Eclipse Public License 2.0";
        attribute canonicalSpdxIdentifier : Text = "EPL-2.0";

        action generateNotice {
            in item artifact : SourceArtifact;
            out item notice : LicenseNotice;
        }
    }

    part def ModificationTracker {
        port artifactInput : ArtifactInputPort;
        port findingOutput : FindingOutputPort;

        attribute modifiedFileCount : FileCount;
        attribute modificationDisclosureRequired : Boolean;

        action evaluateModification {
            in item artifact : SourceArtifact;
            out item finding : ComplianceFinding;
        }
    }

    part def ComplianceReporter {
        port findingInput : FindingOutputPort;
        port reportOutput : ReportOutputPort;

        attribute minimumComplianceScore : Percent = 95.0;
        attribute generatedReportCount : Count;

        action compileReport {
            in item finding : ComplianceFinding;
            out item report : ComplianceReport;
        }
    }

    part def ReleaseGate {
        port reportInput : ReportOutputPort;
        port decisionInput : DecisionInputPort;

        attribute releaseApproved : Boolean;
        attribute blockingFindingThreshold : Count = 0;

        action decideRelease {
            in item report : ComplianceReport;
            out item decision : ReleaseDecision;
        }
    }

    part def EPLBasedComplianceSystem {
        port sourcePort : ArtifactInputPort;
        port reportPort : ReportOutputPort;
        port decisionPort : DecisionInputPort;

        attribute primaryFunction : Text =
            "Identify Eclipse Public License 2.0 governed source artifacts, preserve required notices, track modifications, and produce a release compliance decision before distribution.";

        part collector : RepositoryCollector;
        part scanner : LicenseScanner;
        part noticeManager : NoticeManager;
        part modificationTracker : ModificationTracker;
        part reporter : ComplianceReporter;
        part gate : ReleaseGate;

        connect sourcePort to collector.repositoryInput;
        connect collector.artifactOutput to scanner.artifactInput;
        connect collector.artifactOutput to noticeManager.artifactInput;
        connect collector.artifactOutput to modificationTracker.artifactInput;
        connect scanner.findingOutput to reporter.findingInput;
        connect modificationTracker.findingOutput to reporter.findingInput;
        connect reporter.reportOutput to reportPort;
        connect reporter.reportOutput to gate.reportInput;
        connect gate.decisionInput to decisionPort;

        state def ComplianceLifecycle {
            entry action initializeReview;
            state Idle;
            state CollectingArtifacts;
            state ScanningLicenses;
            state GeneratingNotices;
            state CheckingModifications;
            state CompilingReport;
            state AwaitingReleaseDecision;
            state ApprovedForDistribution;
            state BlockedForRemediation;

            transition first Idle;
            transition Idle to CollectingArtifacts
                accept StartComplianceReview;

            transition CollectingArtifacts to ScanningLicenses
                accept ArtifactsCollected;

            transition ScanningLicenses to GeneratingNotices
                accept LicenseScanComplete;

            transition GeneratingNotices to CheckingModifications
                accept NoticesGenerated;

            transition CheckingModifications to CompilingReport
                accept ModificationReviewComplete;

            transition CompilingReport to AwaitingReleaseDecision
                accept ReportGenerated;

            transition AwaitingReleaseDecision to ApprovedForDistribution
                accept ReleaseApproved;

            transition AwaitingReleaseDecision to BlockedForRemediation
                accept ReleaseRejected;

            transition BlockedForRemediation to CollectingArtifacts
                accept RemediationComplete;
        }

        action performComplianceReview {
            in item repositoryRoot : Text;
            out item report : ComplianceReport;
            out item decision : ReleaseDecision;

            first start;
            then collect via collector.collectArtifacts;
            then scan via scanner.inspectArtifact;
            then notice via noticeManager.generateNotice;
            then modificationCheck via modificationTracker.evaluateModification;
            then reportBuild via reporter.compileReport;
            then releaseDecision via gate.decideRelease;
            then done;
        }
    }

    requirement def EPLLicenseBasisRequirement {
        subject system : EPLBasedComplianceSystem;

        attribute requiredLicenseIdentifier : Text = "EPL-2.0";

        require constraint {
            system.scanner.supportedLicenseId == requiredLicenseIdentifier
        }

        doc
            /* The system shall be based on the Eclipse Public License 2.0 and shall treat EPL-2.0 obligations as the governing compliance baseline. */
    }

    requirement def PrimaryFunctionRequirement {
        subject system : EPLBasedComplianceSystem;

        require constraint {
            system.primaryFunction != ""
        }

        doc
            /* The system shall describe its primary function as high-level license compliance support for EPL-governed source distribution. */
    }

    requirement def NoticePreservationRequirement {
        subject system : EPLBasedComplianceSystem;

        require constraint {
            system.noticeManager.canonicalSpdxIdentifier == "EPL-2.0"
        }

        doc
            /* The system shall generate and preserve license notices for artifacts governed by the Eclipse Public License 2.0. */
    }

    requirement def ModificationDisclosureRequirement {
        subject system : EPLBasedComplianceSystem;

        require constraint {
            system.modificationTracker.modificationDisclosureRequired == true
        }

        doc
            /* The system shall identify modified EPL-governed source artifacts so distribution packages can disclose modifications when required. */
    }

    requirement def ReleaseBlockingRequirement {
        subject system : EPLBasedComplianceSystem;

        require constraint {
            system.gate.blockingFindingThreshold == 0
        }

        doc
            /* The system shall block release when unresolved compliance findings remain. */
    }

    requirement def ScanPerformanceRequirement {
        subject system : EPLBasedComplianceSystem;

        require constraint {
            system.scanner.scanLatencyLimit <= 300 [SI::s]
        }

        doc
            /* The system shall complete license scanning within five minutes for a normal release review batch. */
    }

    part eplComplianceSystem : EPLBasedComplianceSystem {
        attribute primaryFunction =
            "Provide high-level automated governance for software distributed under the Eclipse Public License by scanning source artifacts, preserving notices, evaluating modifications, reporting compliance status, and controlling release approval.";
    }

    satisfy EPLLicenseBasisRequirement by eplComplianceSystem;
    satisfy PrimaryFunctionRequirement by eplComplianceSystem;
    satisfy NoticePreservationRequirement by eplComplianceSystem;
    satisfy ModificationDisclosureRequirement by eplComplianceSystem;
    satisfy ReleaseBlockingRequirement by eplComplianceSystem;
    satisfy ScanPerformanceRequirement by eplComplianceSystem;
}