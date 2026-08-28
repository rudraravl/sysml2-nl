package GPLComplianceSystem {
	private import ScalarValues::String;
	private import ScalarValues::Boolean;
	private import ScalarValues::Integer;

	attribute def SourceCode {
		attribute hasGPLNotice : Boolean;
		attribute isDerivative : Boolean;
		attribute derivativeHasGPL : Boolean;
	}
	attribute def SoftwarePackage {
		attribute content : SourceCode;
		attribute licenseNotice : String;
	}
	attribute def DistributionRequest;
	attribute def ChangeRequest {
		attribute author : String;
		attribute timestamp : Integer;
		attribute description : String;
	}
	attribute def ModificationRecord {
		attribute author : String;
		attribute timestamp : Integer;
		attribute description : String;
	}
	attribute def ValidationResult {
		attribute isCompliant : Boolean;
		attribute issue : String;
	}
	attribute def EnforcementAction {
		attribute issue : String;
	}
	attribute def EnforcementComplete;
	attribute def SourceRequest;

	port def RepoPort {
		in request : SourceRequest;
		out code : SourceCode;
	}
	port def UpdatePort {
		in newCode : SourceCode;
	}
	port def ChangeRequestPort {
		in change : ChangeRequest;
	}
	port def ModRecordPort {
		in record : ModificationRecord;
	}
	port def ValPort {
		in code : SourceCode;
		out result : ValidationResult;
	}
	port def DistPort {
		in request : DistributionRequest;
		out pkg : SoftwarePackage;
	}
	port def EnforcePort {
		in action : EnforcementAction;
		out complete : EnforcementComplete;
	}

	part def SourceRepository {
		port repoPort : RepoPort;
		port updatePort : UpdatePort;
		port changePort : ~ChangeRequestPort;
		attribute storedCode : SourceCode = new SourceCode(false, true, false);
		exhibit state repoStates {
			entry send new ChangeRequest("Init", 0, "Initial commit") via changePort;
			then waiting;
			state waiting;
			accept req : SourceRequest via repoPort
				do send storedCode via repoPort
				then waiting;
			accept upd : SourceCode via updatePort
				do action {
					storedCode = upd;
					send new ChangeRequest("System", 0, "Code updated") via changePort;
				}
				then waiting;
		}
	}

	part def ModificationTracker {
		port changePort : ChangeRequestPort;
		port recordPort : ~ModRecordPort;
		exhibit state trackerStates {
			entry; then monitoring;
			state monitoring;
			accept req : ChangeRequest via changePort
				do send new ModificationRecord(req.author, req.timestamp, req.description) via recordPort
				then monitoring;
		}
	}

	part def ComplianceValidator {
		port valPort : ValPort;
		port recordPort : ModRecordPort;
		attribute currentCode : SourceCode;
		attribute recordCount : Integer = 0;
		exhibit state validatorStates {
			entry; then waitingForCode;
			state waitingForCode;
			accept rc : SourceCode via valPort
				do action { currentCode = rc; }
				then evaluating;
			accept rec : ModificationRecord via recordPort
				do action { recordCount = recordCount + 1; }
				then waitingForCode;
			state evaluating;
			transition successTransition
				first evaluating
				if currentCode.hasGPLNotice and ((not currentCode.isDerivative) or currentCode.derivativeHasGPL) and (recordCount > 0)
				do send new ValidationResult(true, "") via valPort
				then waitingForCode;
			transition failureTransition
				first evaluating
				if not (currentCode.hasGPLNotice and ((not currentCode.isDerivative) or currentCode.derivativeHasGPL) and (recordCount > 0))
				do send new ValidationResult(false, "Compliance violation or undocumented changes") via valPort
				then waitingForCode;
		}
	}

	part def DistributionManager {
		port distPort : DistPort;
		port repoPort : ~RepoPort;
		port valPort : ~ValPort;
		port enforcePort : ~EnforcePort;
		attribute licenseNotice : String = "GPL v3.0 License Notice";
		attribute currentCode : SourceCode;

		exhibit state operationalStates {
			entry; then idle;
			state idle;
			accept req : DistributionRequest via distPort
				do send new SourceRequest() via repoPort
				then waitingForCode;
			state waitingForCode;
			accept rc : SourceCode via repoPort
				do action { currentCode = rc; }
				then validating;
			state validating {
				entry send currentCode via valPort;
			}
			transition validTransition
				first validating
				accept res : ValidationResult via valPort
				if res.isCompliant
				then distributing;
			transition invalidTransition
				first validating
				accept res2 : ValidationResult via valPort
				if not res2.isCompliant
				do send new EnforcementAction(res2.issue) via enforcePort
				then enforcing;
			state distributing {
				entry send new SoftwarePackage(currentCode, licenseNotice) via distPort;
			}
			transition distributeComplete
				first distributing
				then idle;
			state enforcing;
			accept comp : EnforcementComplete via enforcePort
				do send new SourceRequest() via repoPort
				then waitingForCode;
		}
	}

	part def Enforcer {
		port enforcePort : EnforcePort;
		port updatePort : ~UpdatePort;
		exhibit state enforcerStates {
			entry; then idle;
			state idle;
			accept act : EnforcementAction via enforcePort
				do send new SourceCode(true, false, false) via updatePort
				then fixing;
			state fixing;
			transition sendComplete
				first fixing
				do send new EnforcementComplete() via enforcePort
				then idle;
		}
	}

	part def User {
		port distPort : ~DistPort;
		exhibit state userStates {
			entry; then requesting;
			state requesting {
				entry send new DistributionRequest() via distPort;
			}
			accept pkg : SoftwarePackage via distPort
				then idle;
			state idle;
		}
	}

	requirement def GPLCompliance {
		doc /* Enforce GPL v3.0: source accessible, modifications tracked, copyleft applied, license notice included. */
	}
	requirement def SourceAccessible :> GPLCompliance {
		doc /* Source code must be publicly accessible. */
	}
	requirement def ModificationDocumentation :> GPLCompliance {
		doc /* All modifications must be documented (who, when, what). */
	}
	requirement def LicenseInclusion :> GPLCompliance {
		doc /* Every distribution must include the GPL license notice. */
	}
	requirement def CopyleftApplied :> GPLCompliance {
		doc /* Derivative works must be licensed under GPL v3.0. */
	}

	part gplSystem {
		part repository : SourceRepository;
		part tracker : ModificationTracker;
		part validator : ComplianceValidator;
		part manager : DistributionManager;
		part enforcer : Enforcer;
		part user : User;

		interface repoToManager connect repository.repoPort to manager.repoPort {
			flow codeFlow of SourceCode from repository.repoPort.code to manager.repoPort.code;
			flow requestFlow of SourceRequest from manager.repoPort.request to repository.repoPort.request;
		}
		interface managerToVal connect manager.valPort to validator.valPort {
			flow valCodeFlow of SourceCode from manager.valPort.code to validator.valPort.code;
			flow resultFlow of ValidationResult from validator.valPort.result to manager.valPort.result;
		}
		interface enforcerToRepo connect enforcer.updatePort to repository.updatePort {
			flow updateFlow of SourceCode from enforcer.updatePort.newCode to repository.updatePort.newCode;
		}
		interface managerToEnforcer connect manager.enforcePort to enforcer.enforcePort {
			flow actionFlow of EnforcementAction from manager.enforcePort.action to enforcer.enforcePort.action;
			flow completeFlow of EnforcementComplete from enforcer.enforcePort.complete to manager.enforcePort.complete;
		}
		interface repoToTracker connect repository.changePort to tracker.changePort {
			flow changeFlow of ChangeRequest from repository.changePort.change to tracker.changePort.change;
		}
		interface trackerToVal connect tracker.recordPort to validator.recordPort {
			flow recordFlow of ModificationRecord from tracker.recordPort.record to validator.recordPort.record;
		}
		interface userToManager connect user.distPort to manager.distPort {
			flow userRequestFlow of DistributionRequest from user.distPort.request to manager.distPort.request;
			flow packageFlow of SoftwarePackage from manager.distPort.pkg to user.distPort.pkg;
		}

		satisfy SourceAccessible by repository;
		satisfy ModificationDocumentation by tracker;
		satisfy LicenseInclusion by manager;
		satisfy CopyleftApplied by validator;
	}
}
