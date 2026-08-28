package GPLComplianceSystem {
    import ScalarValues::*;
    import ISQ::DateTime;

    // ---- Units and Value Types ----
    unit count;
    unit bytes;

    value type ChangeCount > Real { unit count; }
    value type PackageSize > Real { unit bytes; }

    // ---- Item Definitions ----
    item def SourceCode {
        attribute version : String;
        attribute hash : String;
        attribute isComplete : Boolean;
        attribute size : PackageSize;
    }

    item def LicenseNotice {
        attribute licenseName : String = "GNU GPL v3.0";
        attribute licenseText : String;
        attribute included : Boolean;
    }

    item def ChangeRecord {
        attribute changeId : String;
        attribute author : String;
        attribute timestamp : DateTime;
        attribute description : String;
        attribute affectedFiles : String[*];
    }

    item def DerivativeWork {
        attribute name : String;
        attribute basedOnVersion : String;
        attribute licensedUnderGPL : Boolean;
        attribute derivativeHash : String;
    }

    item def DistributionPackage {
        attribute packageId : String;
        attribute code : SourceCode;
        attribute notice : LicenseNotice;
        attribute changeHistory : ChangeRecord[*];
        attribute derivativeWorks : DerivativeWork[*];
    }

    item def ComplianceReport {
        attribute reportId : String;
        attribute isValid : Boolean;
        attribute issues : String[*];
        attribute derivativesChecked : DerivativeWork[*];
        attribute validatedAt : DateTime;
    }

    // ---- Port Definitions ----
    port def SourceAccessPort {
        out item code : SourceCode;
        out item notice : LicenseNotice;
    }

    port def ChangeFeedPort {
        out item change : ChangeRecord;
    }

    port def HistoryPort {
        out item history : ChangeRecord[*];
    }

    port def ValidationRequestPort {
        in item code : SourceCode;
        in item history : ChangeRecord[*];
        in item derivatives : DerivativeWork[*];
        out item report : ComplianceReport;
    }

    port def EnforcementPort {
        in item report : ComplianceReport;
        out item corrected : ComplianceReport;
    }

    port def DistributionRequestPort {
        in attribute requestId : String;
        out item package : DistributionPackage;
    }

    // ---- Part Definitions ----
    part def SourceCodeRepository {
        attribute repositoryId : String;
        attribute publicAccessible : Boolean = true;
        item storedCode : SourceCode;
        item notice : LicenseNotice;

        port sourceAccess : SourceAccessPort;

        action def PublishCode {
            out code : SourceCode;
            out notice : LicenseNotice;
            code = storedCode;
            notice = self.notice;
            sourceAccess.code.send(code);
            sourceAccess.notice.send(notice);
        }

        action def UpdateStoredCode {
            in newCode : SourceCode;
            then storedCode = newCode;
        }
    }

    part def ModificationTracker {
        attribute trackerId : String;
        item changeHistory : ChangeRecord[*] := {};

        port changeFeed : ChangeFeedPort;
        port historyOut : HistoryPort;

        action def RecordChange {
            in change : ChangeRecord;
            then changeHistory = changeHistory.append(change);
            then changeFeed.change.send(change);
        }

        action def EmitHistory {
            then historyOut.history.send(changeHistory);
        }
    }

    part def ComplianceValidator {
        attribute validatorId : String;
        item lastReport : ComplianceReport;

        port validationRequest : ValidationRequestPort;
        port enforcementOut : EnforcementPort;

        action def CheckModificationsDocumented {
            in history : ChangeRecord[*];
            out documented : Boolean;
            documented = history->notEmpty();
        }

        action def CheckLicenseNoticeIncluded {
            in notice : LicenseNotice;
            out included : Boolean;
            included = notice.included;
        }

        action def CheckDerivativeCopyleft {
            in derivatives : DerivativeWork[*];
            out compliant : Boolean;
            compliant = derivatives->forAll(d | d.licensedUnderGPL);
        }

        action def ValidateCompliance {
            in code : SourceCode;
            in history : ChangeRecord[*];
            in derivatives : DerivativeWork[*];
            in notice : LicenseNotice;
            out report : ComplianceReport;

            var issues : String[*] := {};
            var modsOk : Boolean;
            var noticeOk : Boolean;
            var copyleftOk : Boolean;

            CheckModificationsDocumented(history, modsOk);
            CheckLicenseNoticeIncluded(notice, noticeOk);
            CheckDerivativeCopyleft(derivatives, copyleftOk);

            if !modsOk {
                issues = issues.append("Modification history missing");
            }
            if !noticeOk {
                issues = issues.append("License notice not included");
            }
            if !copyleftOk {
                issues = issues.append("Derivative work not licensed under GPL");
            }

            report = ComplianceReport{
                reportId = "RPT-" + code.version,
                isValid = modsOk and noticeOk and copyleftOk,
                issues = issues,
                derivativesChecked = derivatives,
                validatedAt = now
            };
        }
    }

    part def EnforcementHandler {
        attribute handlerId : String;
        port enforcementIn : EnforcementPort;

        action def CorrectDerivativeLicensing {
            in derivative : DerivativeWork;
            out corrected : DerivativeWork;
            corrected = DerivativeWork{
                name = derivative.name,
                basedOnVersion = derivative.basedOnVersion,
                licensedUnderGPL = true,
                derivativeHash = derivative.derivativeHash
            };
        }

        action def EnforceCompliance {
            in report : ComplianceReport;
            out corrected : ComplianceReport;

            var fixedDerivatives : DerivativeWork[*] := {};
            for d in report.derivativesChecked {
                if !d.licensedUnderGPL {
                    var fixed : DerivativeWork;
                    CorrectDerivativeLicensing(d, fixed);
                    fixedDerivatives = fixedDerivatives.append(fixed);
                } else {
                    fixedDerivatives = fixedDerivatives.append(d);
                }
            }

            corrected = ComplianceReport{
                reportId = report.reportId + "-corrected",
                isValid = true,
                issues = {},
                derivativesChecked = fixedDerivatives,
                validatedAt = now
            };
        }
    }

    part def DistributionManager {
        attribute managerId : String;
        attribute packagesDistributed : ChangeCount := 0;

        port distributionRequest : DistributionRequestPort;
        port validationRequest : ValidationRequestPort;
        port enforcementRequest : EnforcementPort;
        port sourceIn : SourceAccessPort;

        action def PackageDistribution {
            in code : SourceCode;
            in notice : LicenseNotice;
            in history : ChangeRecord[*];
            in derivatives : DerivativeWork[*];
            out pkg : DistributionPackage;

            pkg = DistributionPackage{
                packageId = "DIST-" + code.version,
                code = code,
                notice = notice,
                changeHistory = history,
                derivativeWorks = derivatives
            };
            packagesDistributed = packagesDistributed + 1;
        }

        action def HandleDistributionRequest {
            in requestId : String;
            out pkg : DistributionPackage;

            var code : SourceCode;
            var notice : LicenseNotice;
            var history : ChangeRecord[*];
            var derivatives : DerivativeWork[*] := {};
            var report : ComplianceReport;

            sourceIn.code.recv(code);
            sourceIn.notice.recv(notice);

            validationRequest.code.send(code);
            validationRequest.history.send(history);
            validationRequest.derivatives.send(derivatives);
            validationRequest.report.recv(report);

            if report.isValid {
                PackageDistribution(code, notice, history, derivatives, pkg);
            } else {
                var corrected : ComplianceReport;
                enforcementRequest.report.send(report);
                enforcementRequest.corrected.recv(corrected);
                if corrected.isValid {
                    PackageDistribution(code, notice, history, corrected.derivativesChecked, pkg);
                }
            }

            distributionRequest.package.send(pkg);
        }
    }

    // ---- System Assembly ----
    part def GPLComplianceSystem {
        attribute systemId : String = "GPL-CS-001";

        part repository : SourceCodeRepository {
            storedCode = SourceCode{version = "1.0", hash = "abc123", isComplete = true, size = 10240};
            notice = LicenseNotice{licenseName = "GNU GPL v3.0", licenseText = "Full GPL v3 text...", included = true};
        }
        part tracker : ModificationTracker;
        part validator : ComplianceValidator;
        part enforcer : EnforcementHandler;
        part distributor : DistributionManager;

        connect repository.sourceAccess to distributor.sourceIn;
        connect tracker.historyOut to distributor.validationRequest;
        connect tracker.changeFeed to validator.validationRequest;
        connect distributor.validationRequest to validator.validationRequest;
        connect validator.enforcementOut to enforcer.enforcementIn;
        connect enforcer.enforcementIn to distributor.enforcementRequest;

        // ---- Operational State Machine ----
        state def OperationalStates {
            state Idle;
            state Validating;
            state Distributing;
            state Enforcing;

            transition initial to Idle;

            transition Idle to Validating
                when distributor.distributionRequest.requestId->notEmpty();

            transition Validating to Distributing
                when validator.validationRequest.report.isValid == true;

            transition Validating to Enforcing
                when validator.validationRequest.report.isValid == false;

            transition Enforcing to Validating
                when enforcer.enforcementIn.corrected.isValid == true;

            transition Distributing to Idle
                when distributor.distributionRequest.package->notEmpty();
        }

        part behavior : OperationalStates;

        requirement complianceSubject : GPLComplianceRequirement {
            subject system : GPLComplianceSystem;
        }
    }

    // ---- Requirements ----
    requirement def GPLComplianceRequirement {
        doc "The system shall ensure all distributed software adheres strictly to GNU GPL v3.0."
        subject system : GPLComplianceSystem;
        constraint { system.distributor.packagesDistributed >= 0 }
    }

    requirement def SourceAvailabilityRequirement {
        doc "The Source Code Repository shall make source code publicly accessible at all times."
        subject repository : SourceCodeRepository;
        constraint { repository.publicAccessible == true }
    }

    requirement def LicenseNoticeRequirement {
        doc "Every distribution package shall include the official GPL v3.0 license notice."
        subject distributor : DistributionManager;
        constraint { distributor.distributionRequest.package.notice.included == true }
    }

    requirement def ModificationTrackingRequirement {
        doc "All modifications shall be recorded with author, timestamp, description, and affected files."
        subject tracker : ModificationTracker;
        constraint { tracker.changeHistory->forAll(c | c.author->notEmpty() and c.timestamp->notEmpty()) }
    }

    requirement def CopyleftRequirement {
        doc "All derivative works shall be licensed under the same GPL v3.0 terms as the original."
        subject validator : ComplianceValidator;
        constraint { validator.validationRequest.report.derivativesChecked->forAll(d | d.licensedUnderGPL == true) }
    }

    requirement def EnforcementRequirement {
        doc "Non-compliant works shall trigger enforcement and correction before distribution proceeds."
        subject enforcer : EnforcementHandler;
        constraint { enforcer.enforcementIn.corrected.isValid == true }
    }

    requirement def DistributionWorkflowRequirement {
        doc "Distribution shall only proceed after successful compliance validation."
        subject distributor : DistributionManager;
        constraint { distributor.distributionRequest.package->notEmpty() implies validator.validationRequest.report.isValid == true }
    }

    // ---- Requirement Satisfaction ----
    satisfaction SourceAvailabilityRequirement {
        subject repository : SourceCodeRepository;
    }
    satisfaction LicenseNoticeRequirement {
        subject distributor : DistributionManager;
    }
    satisfaction ModificationTrackingRequirement {
        subject tracker : ModificationTracker;
    }
    satisfaction CopyleftRequirement {
        subject validator : ComplianceValidator;
    }
    satisfaction EnforcementRequirement {
        subject enforcer : EnforcementHandler;
    }
    satisfaction DistributionWorkflowRequirement {
        subject distributor : DistributionManager;
    }
}
