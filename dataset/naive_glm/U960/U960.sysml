package AccessControlSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----

    value type SecurityLevel > Integer {
        doc /* Numeric security level: 1=general, 2=restricted, 3=high-security */
    }

    value type CredentialId > String {
        doc /* Unique identifier encoded on a credential (e.g., card serial number). */
    }

    value type UserName > String;

    value type ZoneId > String;

    value type DecisionEnumeration {
        enum { granted, denied };
    }

    value type UnlockDurationValue > TimeValue {
        doc /* Configurable auto re-lock delay. */
    }

    attribute generalLevel : SecurityLevel = 1;
    attribute restrictedLevel : SecurityLevel = 2;
    attribute highSecurityLevel : SecurityLevel = 3;

    // ---- Item Types ----

    item def Credential {
        attribute id : CredentialId;
        attribute bearerName : UserName;
        attribute assignedLevel : SecurityLevel;
    }

    item def ScanRequest {
        attribute credentialId : CredentialId;
        attribute zoneId : ZoneId;
        attribute timestamp : DateTime;
    }

    item def AccessDecision {
        attribute credentialId : CredentialId;
        attribute zoneId : ZoneId;
        attribute userName : UserName;
        attribute decision : DecisionEnumeration;
        attribute timestamp : DateTime;
        attribute reason : String;
    }

    item def LockCommand {
        attribute zoneId : ZoneId;
        attribute command : LockCommandKind;
    }

    item def LockCommandKind {
        enum { unlock, lock };
    }

    item def AuditEntry {
        attribute userName : UserName;
        attribute zoneId : ZoneId;
        attribute credentialId : CredentialId;
        attribute timestamp : DateTime;
        attribute decision : DecisionEnumeration;
        attribute reason : String;
    }

    item def UserRecord {
        attribute name : UserName;
        attribute credentialId : CredentialId;
        attribute assignedLevel : SecurityLevel;
    }

    // ---- Port Definitions ----

    port def ScanRequestPort {
        out scanRequest : ScanRequest;
    }

    port def LockCommandPort {
        in lockCommand : LockCommand;
    }

    port def DecisionPort {
        out accessDecision : AccessDecision;
    }

    port def AuditPort {
        in auditEntry : AuditEntry;
    }

    port def DoorStatusPort {
        out doorOpen : Boolean;
    }

    // ---- Credential Scanner ----

    part def CredentialScanner {
        port scanOut : ScanRequestPort;
        attribute zoneId : ZoneId;

        state machine Behavior {
            entry;
            state Idle;
            state Transmitting;

            transition idle_to_transmitting
                source Idle
                target Transmitting
                when scanOut.scanRequest'->notEmpty() {
                }
            transition transmitting_to_idle
                source Transmitting
                target Idle
                when true {
                }
        }
    }

    // ---- Electronic Door Lock ----

    part def ElectronicDoorLock {
        port lockCmd : LockCommandPort;
        port doorStatus : DoorStatusPort;
        attribute zoneId : ZoneId;
        attribute autoRelockDelay : UnlockDurationValue = 5 [s];
        attribute locked : Boolean = true;

        state machine Behavior {
            entry;
            state Locked;
            state Unlocked;

            transition locked_to_unlocked
                source Locked
                target Unlocked
                when lockCmd.lockCommand.command == LockCommandKind::unlock {
                do { locked = false; }
            }
            transition unlocked_to_locked_auto
                source Unlocked
                target Locked
                when elapsed(autoRelockDelay) {
                do { locked = true; }
            }
            transition unlocked_to_locked_cmd
                source Unlocked
                target Locked
                when lockCmd.lockCommand.command == LockCommandKind::lock {
                do { locked = true; }
            }
        }
    }

    // ---- Access Control Processor ----

    part def AccessControlProcessor {
        port scanIn : ScanRequestPort;
        port lockOut : LockCommandPort;
        port decisionOut : DecisionPort;
        port auditOut : AuditPort;

        attribute authorizedUsers : UserRecord[0..*];
        attribute zoneSecurityMap : ZoneId[0..*] = ("entrance", "restricted", "highsecurity");
        attribute zoneLevels : SecurityLevel[0..*] = (generalLevel, restrictedLevel, highSecurityLevel);

        action def AuthenticateCredential {
            in scan : ScanRequest;
            out user : UserRecord;
            out authenticated : Boolean;
        }

        action def CheckAuthorization {
            in user : UserRecord;
            in zoneId : ZoneId;
            out authorized : Boolean;
            out reason : String;
        }

        action def ProcessAccessRequest {
            in scan : ScanRequest;
            out decision : AccessDecision;
            out lockCmd : LockCommand;
            out audit : AuditEntry;

            perform authenticate : AuthenticateCredential {
                in scan = scan;
                out user = userRecord;
                out authenticated = authOk;
            }
            perform check : CheckAuthorization {
                in user = userRecord;
                in zoneId = scan.zoneId;
                out authorized = authzOk;
                out reason = authzReason;
            }

            decide decideOutcome;
                if authOk and authzOk then {
                    decision.decision = DecisionEnumeration::granted;
                    decision.reason = "Access granted";
                    lockCmd.command = LockCommandKind::unlock;
                } else if not authOk then {
                    decision.decision = DecisionEnumeration::denied;
                    decision.reason = "Credential not recognized";
                    lockCmd.command = LockCommandKind::lock;
                } else {
                    decision.decision = DecisionEnumeration::denied;
                    decision.reason = authzReason;
                    lockCmd.command = LockCommandKind::lock;
                }

            decision.credentialId = scan.credentialId;
            decision.zoneId = scan.zoneId;
            decision.timestamp = scan.timestamp;

            audit.userName = userRecord.name;
            audit.zoneId = scan.zoneId;
            audit.credentialId = scan.credentialId;
            audit.timestamp = scan.timestamp;
            audit.decision = decision.decision;
            audit.reason = decision.reason;
        }

        state machine Behavior {
            entry;
            state Listening;

            transition handle_scan
                source Listening
                target Listening
                when scanIn.scanRequest'->notEmpty() {
                do {
                    perform proc : ProcessAccessRequest {
                        in scan = scanIn.scanRequest;
                        out decision = decisionOut.accessDecision;
                        out lockCmd = lockOut.lockCommand;
                        out audit = auditOut.auditEntry;
                    }
                }
            }
        }
    }

    // ---- Audit Database ----

    part def AuditDatabase {
        port auditIn : AuditPort;
        attribute storedEntries : AuditEntry[0..*];

        state machine Behavior {
            entry;
            state Receiving;

            transition store_entry
                source Receiving
                target Receiving
                when auditIn.auditEntry'->notEmpty() {
                do { storedEntries = storedEntries->including(auditIn.auditEntry); }
            }
        }
    }

    // ---- Zone ----

    part def Zone {
        attribute zoneId : ZoneId;
        attribute securityLevel : SecurityLevel;
        part scanner : CredentialScanner {
            attribute zoneId = zoneId;
        }
        part doorLock : ElectronicDoorLock {
            attribute zoneId = zoneId;
        }
    }

    // ---- System ----

    part def AccessControlSystem {
        part processor : AccessControlProcessor;
        part auditDb : AuditDatabase;

        part generalEntrance : Zone {
            attribute zoneId = "entrance";
            attribute securityLevel = generalLevel;
        }
        part restrictedArea : Zone {
            attribute zoneId = "restricted";
            attribute securityLevel = restrictedLevel;
        }
        part highSecurityZone : Zone {
            attribute zoneId = "highsecurity";
            attribute securityLevel = highSecurityLevel;
        }

        connection def ScannerToProcessor {
            end source : ScanRequestPort;
            end target : ScanRequestPort;
        }

        connection def ProcessorToLock {
            end source : LockCommandPort;
            end target : LockCommandPort;
        }

        connection def ProcessorToAudit {
            end source : AuditPort;
            end target : AuditPort;
        }

        connection scannerToProc1 : ScannerToProcessor
            connect generalEntrance.scanner.scanOut to processor.scanIn;
        connection scannerToProc2 : ScannerToProcessor
            connect restrictedArea.scanner.scanOut to processor.scanIn;
        connection scannerToProc3 : ScannerToProcessor
            connect highSecurityZone.scanner.scanOut to processor.scanIn;

        connection procToLock1 : ProcessorToLock
            connect processor.lockOut to generalEntrance.doorLock.lockCmd;
        connection procToLock2 : ProcessorToLock
            connect processor.lockOut to restrictedArea.doorLock.lockCmd;
        connection procToLock3 : ProcessorToLock
            connect processor.lockOut to highSecurityZone.doorLock.lockCmd;

        connection procToAudit : ProcessorToAudit
            connect processor.auditOut to auditDb.auditIn;
    }

    // ---- Requirements ----

    requirement def AuthenticationRequirement {
        subject : AccessControlProcessor;
        doc /* The processor shall authenticate presented credentials against the authorized user list. */
        require { subject.authorizedUsers->size() > 0; }
    }

    requirement def AuthorizationRequirement {
        subject : AccessControlProcessor;
        doc /* The processor shall verify the user's assigned security level meets or exceeds the zone's security level. */
    }

    requirement def UnlockCommandRequirement {
        subject : AccessControlProcessor;
        doc /* If access is granted, the processor shall send an unlock command to the corresponding zone's electronic door lock. */
    }

    requirement def DenyAccessRequirement {
        subject : AccessControlProcessor;
        doc /* If access is denied, the processor shall not send an unlock command and the door shall remain locked. */
    }

    requirement def AutoRelockRequirement {
        subject : ElectronicDoorLock;
        doc /* The electronic door lock shall automatically re-lock after a configurable delay following an unlock command. */
        require { subject.autoRelockDelay > 0 [s]; }
    }

    requirement def AuditLoggingRequirement {
        subject : AccessControlProcessor;
        doc /* Every access attempt shall be recorded with user name, zone, timestamp, and decision, and sent to the audit database. */
    }

    requirement def ZoneConfigurationRequirement {
        subject : AccessControlSystem;
        doc /* The system shall support zones with configurable security levels including general, restricted, and high-security. */
        require { subject.generalEntrance.securityLevel == generalLevel; }
        require { subject.restrictedArea.securityLevel == restrictedLevel; }
        require { subject.highSecurityZone.securityLevel == highSecurityLevel; }
    }

    requirement def AuditStorageRequirement {
        subject : AuditDatabase;
        doc /* The audit database shall permanently store all received audit entries. */
    }

    requirement AccessControlSystemRequirements {
        subject : AccessControlSystem;
        satisfy AuthenticationRequirement;
        satisfy AuthorizationRequirement;
        satisfy UnlockCommandRequirement;
        satisfy DenyAccessRequirement;
        satisfy AutoRelockRequirement;
        satisfy AuditLoggingRequirement;
        satisfy ZoneConfigurationRequirement;
        satisfy AuditStorageRequirement;
    }

}
