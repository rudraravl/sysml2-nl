package AccessControlSystem {
    private import ScalarValues::String;
    private import ScalarValues::Integer;
    private import ScalarValues::Boolean;
    private import ScalarValues::Real;

    item def Credential {
        attribute credentialId : String;
        attribute userName : String;
    }
    item def ScannedCredential :> Credential {
        attribute zoneId : String;
    }
    item def UnlockCommand {
        attribute zoneId : String;
    }
    item def LockCommand {
        attribute zoneId : String;
    }
    item def AuditEntry {
        attribute userName : String;
        attribute zoneId : String;
        attribute timestamp : String;
        attribute granted : Boolean;
    }
    enum def SecurityLevel {
        general;
        restricted;
        high;
    }
    item def AuthorizedUser {
        attribute userName : String;
        attribute credentialId : String;
        attribute allowedLevel : SecurityLevel;
    }
    item def ZoneSecurity {
        attribute zoneId : String;
        attribute level : SecurityLevel;
    }

    port def CredentialPort {
        out scannedCredential : ScannedCredential;
    }
    port def LockCommandPort {
        in unlock : UnlockCommand;
        in lock : LockCommand;
    }
    port def AuditOutputPort {
        out auditEntry : AuditEntry;
    }
    port def AuditInputPort {
        in auditEntry : AuditEntry;
    }
    port def ProcessorCredentialPort {
        in scannedCredential : ScannedCredential;
    }
    port def ProcessorLockPort {
        out unlock : UnlockCommand;
        out lock : LockCommand;
    }

    part def CredentialScanner {
        attribute zoneId : String;
        port credentialPort : CredentialPort;
        perform action scanBehavior {
            in request : Credential;
            out result : ScannedCredential;
        }
        flow resultFlow from scanBehavior.result to credentialPort.scannedCredential;
    }

    part def ElectronicDoorLock {
        attribute relockDelay : Integer = 5;
        port lockCommandPort : LockCommandPort;
        state lockStateMachine {
            entry; then locked;
            state locked;
            state unlocked;
            transition locked_to_unlocked
                first locked
                then accept lockCommandPort.unlock
                then unlocked;
            transition unlocked_to_locked
                first unlocked
                then after relockDelay
                then locked;
        }
    }

    part def AccessControlProcessor {
        port credentialPort : ProcessorCredentialPort;
        port lockPort : ProcessorLockPort;
        port auditPort : AuditOutputPort;
        attribute authorizedUsers : AuthorizedUser[0..*];
        attribute zoneSecurityLevels : ZoneSecurity[0..*];

        perform action processBehavior {
            in scanned : ScannedCredential;
            out unlockCmd : UnlockCommand;
            out lockCmd : LockCommand;
            out audit : AuditEntry;
        }

        flow credentialFlow from credentialPort.scannedCredential to processBehavior.scanned;
        flow unlockFlow from processBehavior.unlockCmd to lockPort.unlock;
        flow lockFlow from processBehavior.lockCmd to lockPort.lock;
        flow auditFlow from processBehavior.audit to auditPort.auditEntry;
    }

    part def AuditDatabase {
        port auditPort : AuditInputPort;
        attribute storedEntries : AuditEntry[0..*];
        perform action recordBehavior {
            in entry : AuditEntry;
        }
        flow auditFlow from auditPort.auditEntry to recordBehavior.entry;
    }

    part def Zone {
        attribute zoneId : String;
        attribute securityLevel : SecurityLevel;
        part credentialScanner : CredentialScanner;
        part doorLock : ElectronicDoorLock;
    }

    part accessControlSystem {
        part processor : AccessControlProcessor {
            attribute authorizedUsers : AuthorizedUser[0..*] = (
                AuthorizedUser { userName = "Alice"; credentialId = "ID001"; allowedLevel = SecurityLevel::general; },
                AuthorizedUser { userName = "Bob"; credentialId = "ID002"; allowedLevel = SecurityLevel::high; }
            );
            attribute zoneSecurityLevels : ZoneSecurity[0..*] = (
                ZoneSecurity { zoneId = "Z001"; level = SecurityLevel::general; },
                ZoneSecurity { zoneId = "Z002"; level = SecurityLevel::restricted; },
                ZoneSecurity { zoneId = "Z003"; level = SecurityLevel::high; }
            );
        }
        part auditDatabase : AuditDatabase;

        part generalZone : Zone {
            attribute :>> zoneId = "Z001";
            attribute :>> securityLevel = SecurityLevel::general;
            part :>> credentialScanner {
                attribute :>> zoneId = "Z001";
            }
        }
        part restrictedZone : Zone {
            attribute :>> zoneId = "Z002";
            attribute :>> securityLevel = SecurityLevel::restricted;
            part :>> credentialScanner {
                attribute :>> zoneId = "Z002";
            }
        }
        part highSecurityZone : Zone {
            attribute :>> zoneId = "Z003";
            attribute :>> securityLevel = SecurityLevel::high;
            part :>> credentialScanner {
                attribute :>> zoneId = "Z003";
            }
        }

        interface credentialInterfaceGeneral connect generalZone.credentialScanner.credentialPort to processor.credentialPort {
            flow credentialFlow of ScannedCredential
                from generalZone.credentialScanner.credentialPort.scannedCredential to processor.credentialPort.scannedCredential;
        }
        interface credentialInterfaceRestricted connect restrictedZone.credentialScanner.credentialPort to processor.credentialPort {
            flow credentialFlow of ScannedCredential
                from restrictedZone.credentialScanner.credentialPort.scannedCredential to processor.credentialPort.scannedCredential;
        }
        interface credentialInterfaceHigh connect highSecurityZone.credentialScanner.credentialPort to processor.credentialPort {
            flow credentialFlow of ScannedCredential
                from highSecurityZone.credentialScanner.credentialPort.scannedCredential to processor.credentialPort.scannedCredential;
        }

        interface lockInterfaceGeneral connect processor.lockPort to generalZone.doorLock.lockCommandPort {
            flow unlockFlow of UnlockCommand
                from processor.lockPort.unlock to generalZone.doorLock.lockCommandPort.unlock;
            flow lockFlow of LockCommand
                from processor.lockPort.lock to generalZone.doorLock.lockCommandPort.lock;
        }
        interface lockInterfaceRestricted connect processor.lockPort to restrictedZone.doorLock.lockCommandPort {
            flow unlockFlow of UnlockCommand
                from processor.lockPort.unlock to restrictedZone.doorLock.lockCommandPort.unlock;
            flow lockFlow of LockCommand
                from processor.lockPort.lock to restrictedZone.doorLock.lockCommandPort.lock;
        }
        interface lockInterfaceHigh connect processor.lockPort to highSecurityZone.doorLock.lockCommandPort {
            flow unlockFlow of UnlockCommand
                from processor.lockPort.unlock to highSecurityZone.doorLock.lockCommandPort.unlock;
            flow lockFlow of LockCommand
                from processor.lockPort.lock to highSecurityZone.doorLock.lockCommandPort.lock;
        }

        interface auditInterface connect processor.auditPort to auditDatabase.auditPort {
            flow auditFlow of AuditEntry
                from processor.auditPort.auditEntry to auditDatabase.auditPort.auditEntry;
        }
    }

    requirement def AccessControlRequirement {
        doc /* The system shall authenticate user credentials and grant or deny access based on zone security level. */
        subject accessControlSystem;
        objective {
            doc /* Ensure only authorized users access zones with appropriate security levels. */
        }
    }
    requirement def AuditLoggingRequirement {
        doc /* The system shall log every access attempt to the audit database. */
        subject accessControlSystem;
        objective {
            doc /* All access attempts, granted or denied, must be recorded with user, zone, time, and decision. */
        }
    }
    requirement def AutoRelockRequirement {
        doc /* Electronic door locks shall automatically re-lock after a configurable delay. */
        subject doorLock : ElectronicDoorLock;
        objective {
            doc /* Prevent doors from being left open after an unlock command. */
        }
    }
    requirement accessControlReq : AccessControlRequirement;
    requirement auditLoggingReq : AuditLoggingRequirement;
    requirement autoRelockReq : AutoRelockRequirement;
}
