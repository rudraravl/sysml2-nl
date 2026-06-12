package AccessControlSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Millisecond :> Real;
  attribute def Second :> Real;
  attribute def Volt :> Real;
  attribute def Ampere :> Real;
  attribute def Meter :> Real;
  attribute def Percent :> Real;

  enum def CredentialKind {
    enum card;
    enum pin;
    enum biometric;
    enum mobileToken;
    enum administratorOverride;
  }

  enum def AccessDecisionKind {
    enum granted;
    enum deniedUnknownCredential;
    enum deniedExpiredCredential;
    enum deniedWrongZone;
    enum deniedSchedule;
    enum deniedLockdown;
    enum deniedSystemFault;
  }

  enum def DoorPositionKind {
    enum open;
    enum closed;
    enum forcedOpen;
    enum heldOpen;
    enum unknown;
  }

  enum def LockCommandKind {
    enum lock;
    enum unlock;
    enum holdUnlocked;
    enum releaseHold;
  }

  enum def AlarmSeverityKind {
    enum informational;
    enum warning;
    enum critical;
  }

  item def Credential {
    attribute credentialId : String;
    attribute holderId : String;
    attribute kind : CredentialKind;
    attribute issuedAtEpochSeconds : Integer;
    attribute expiresAtEpochSeconds : Integer;
    attribute cryptographicSignature : String;
  }

  item def AccessRequest {
    attribute requestId : String;
    attribute doorId : String;
    attribute readerId : String;
    attribute presentedAtEpochMilliseconds : Integer;
    attribute requestedZone : String;
    attribute credential : Credential;
  }

  item def AccessDecision {
    attribute requestId : String;
    attribute decision : AccessDecisionKind;
    attribute reasonText : String;
    attribute validUntilEpochMilliseconds : Integer;
    attribute unlockDuration : Second;
  }

  item def DoorStatus {
    attribute doorId : String;
    attribute position : DoorPositionKind;
    attribute lockEngaged : Boolean;
    attribute lastChangedEpochMilliseconds : Integer;
  }

  item def LockCommand {
    attribute doorId : String;
    attribute command : LockCommandKind;
    attribute duration : Second;
    attribute issuedAtEpochMilliseconds : Integer;
  }

  item def AuditEvent {
    attribute eventId : String;
    attribute eventTimeEpochMilliseconds : Integer;
    attribute doorId : String;
    attribute actorId : String;
    attribute decision : AccessDecisionKind;
    attribute message : String;
  }

  item def AlarmNotification {
    attribute alarmId : String;
    attribute doorId : String;
    attribute severity : AlarmSeverityKind;
    attribute message : String;
    attribute raisedAtEpochMilliseconds : Integer;
  }

  item def PowerFeed {
    attribute voltage : Volt;
    attribute currentLimit : Ampere;
    attribute batteryCharge : Percent;
    attribute mainsAvailable : Boolean;
  }

  port def CredentialInputPort {
    in item presentedCredential : Credential;
  }

  port def AccessRequestPort {
    out item request : AccessRequest;
  }

  port def DecisionPort {
    in item decision : AccessDecision;
  }

  port def LockControlPort {
    in item command : LockCommand;
  }

  port def DoorStatusPort {
    out item status : DoorStatus;
  }

  port def AuditPort {
    in item event : AuditEvent;
  }

  port def AlarmPort {
    out item alarm : AlarmNotification;
  }

  port def PowerPort {
    in item feed : PowerFeed;
  }

  port def ManagementPort {
    in item policyUpdate : AccessPolicy;
    out item healthReport : SystemHealthReport;
  }

  item def AccessPolicy {
    attribute policyId : String;
    attribute zoneId : String;
    attribute permittedCredentialKinds : CredentialKind[1..*];
    attribute validFromEpochSeconds : Integer;
    attribute validToEpochSeconds : Integer;
    attribute requiresSecondFactor : Boolean;
    attribute lockdownActive : Boolean;
  }

  item def SystemHealthReport {
    attribute controllerOnline : Boolean;
    attribute readerOnline : Boolean;
    attribute lockOnline : Boolean;
    attribute doorSensorOnline : Boolean;
    attribute auditStoreAvailable : Boolean;
    attribute backupPowerAvailable : Boolean;
    attribute averageDecisionLatency : Millisecond;
  }

  part def CredentialReader {
    attribute readerId : String;
    attribute readRange : Meter;
    attribute maxReadLatency : Millisecond;
    attribute tamperDetected : Boolean;

    port credentialIn : CredentialInputPort;
    port accessRequestOut : AccessRequestPort;

    action buildAccessRequest {
      in item credential : Credential;
      out item request : AccessRequest;
    }
  }

  part def AccessController {
    attribute controllerId : String;
    attribute decisionTimeout : Millisecond;
    attribute unlockDurationDefault : Second;
    attribute lockdownMode : Boolean;
    attribute clockSynchronized : Boolean;

    port requestIn : AccessRequestPort;
    port decisionOut : DecisionPort;
    port lockCommandOut : LockControlPort;
    port doorStatusIn : DoorStatusPort;
    port auditOut : AuditPort;
    port alarmOut : AlarmPort;
    port management : ManagementPort;
    port power : PowerPort;

    part policyStore : PolicyStore;
    part credentialStore : CredentialStore;
    part decisionEngine : AuthorizationEngine;
    part eventBuilder : AuditEventBuilder;

    action evaluateAccess {
      in item request : AccessRequest;
      in item currentPolicy : AccessPolicy;
      out item decision : AccessDecision;
    }

    action commandDoorUnlock {
      in item decision : AccessDecision;
      out item command : LockCommand;
    }

    action detectDoorException {
      in item status : DoorStatus;
      out item alarm : AlarmNotification;
    }

    state accessControlLifecycle {
      state initializing;
      state secureIdle;
      state evaluatingCredential;
      state unlockingDoor;
      state monitoringEntry;
      state alarmed;
      state degradedOperation;
      state lockedDown;

      initial then initializing;

      transition initializing_to_secureIdle
        first initializing
        then secureIdle;

      transition secureIdle_to_evaluatingCredential
        first secureIdle
        then evaluatingCredential;

      transition evaluatingCredential_to_unlockingDoor
        first evaluatingCredential
        then unlockingDoor;

      transition evaluatingCredential_to_secureIdle
        first evaluatingCredential
        then secureIdle;

      transition unlockingDoor_to_monitoringEntry
        first unlockingDoor
        then monitoringEntry;

      transition monitoringEntry_to_secureIdle
        first monitoringEntry
        then secureIdle;

      transition monitoringEntry_to_alarmed
        first monitoringEntry
        then alarmed;

      transition secureIdle_to_lockedDown
        first secureIdle
        then lockedDown;

      transition lockedDown_to_secureIdle
        first lockedDown
        then secureIdle;

      transition secureIdle_to_degradedOperation
        first secureIdle
        then degradedOperation;

      transition degradedOperation_to_secureIdle
        first degradedOperation
        then secureIdle;
    }
  }

  part def AuthorizationEngine {
    attribute maximumDecisionLatency : Millisecond;
    attribute supportsOfflineCache : Boolean;

    action authorize {
      in item request : AccessRequest;
      in item policy : AccessPolicy;
      out item decision : AccessDecision;
    }
  }

  part def PolicyStore {
    attribute retainedPolicyCount : Integer;
    attribute lastPolicySyncEpochSeconds : Integer;
    attribute offlineRetentionDuration : Second;

    action retrievePolicy {
      in attribute zoneId : String;
      out item policy : AccessPolicy;
    }
  }

  part def CredentialStore {
    attribute retainedCredentialCount : Integer;
    attribute revocationListVersion : String;
    attribute maximumLookupLatency : Millisecond;

    action validateCredential {
      in item credential : Credential;
      out attribute credentialKnown : Boolean;
      out attribute credentialExpired : Boolean;
      out attribute credentialRevoked : Boolean;
    }
  }

  part def AuditEventBuilder {
    action createAuditEvent {
      in item request : AccessRequest;
      in item decision : AccessDecision;
      out item event : AuditEvent;
    }
  }

  part def ElectricStrikeLock {
    attribute lockId : String;
    attribute failSecure : Boolean;
    attribute actuationVoltage : Volt;
    attribute actuationCurrent : Ampere;
    attribute unlockHoldTime : Second;
    attribute engaged : Boolean;

    port control : LockControlPort;
    port power : PowerPort;

    state lockState {
      state locked;
      state unlocked;
      state heldUnlocked;
      state faulted;

      initial then locked;

      transition locked_to_unlocked
        first locked
        then unlocked;

      transition unlocked_to_locked
        first unlocked
        then locked;

      transition unlocked_to_heldUnlocked
        first unlocked
        then heldUnlocked;

      transition heldUnlocked_to_locked
        first heldUnlocked
        then locked;

      transition locked_to_faulted
        first locked
        then faulted;
    }
  }

  part def DoorPositionSensor {
    attribute sensorId : String;
    attribute debounceTime : Millisecond;
    attribute heldOpenThreshold : Second;
    attribute tamperDetected : Boolean;

    port statusOut : DoorStatusPort;
    port power : PowerPort;
  }

  part def AlarmAnnunciator {
    attribute annunciatorId : String;
    attribute audibleLevelPercent : Percent;
    attribute visualIndicatorEnabled : Boolean;

    port alarmIn : AlarmPort;

    action presentAlarm {
      in item alarm : AlarmNotification;
    }
  }

  part def AuditLogger {
    attribute loggerId : String;
    attribute localRetentionDays : Integer;
    attribute remoteReplicationEnabled : Boolean;
    attribute writeLatencyLimit : Millisecond;

    port auditIn : AuditPort;

    action persistEvent {
      in item event : AuditEvent;
    }
  }

  part def ManagementWorkstation {
    attribute workstationId : String;
    attribute operatorAuthenticated : Boolean;

    port management : ManagementPort;

    action updatePolicy {
      in item policy : AccessPolicy;
    }

    action viewHealth {
      in item report : SystemHealthReport;
    }
  }

  part def BackupPowerSupply {
    attribute nominalVoltage : Volt;
    attribute maximumCurrent : Ampere;
    attribute batteryCharge : Percent;
    attribute minimumRuntime : Second;
    attribute mainsAvailable : Boolean;

    port powerOut : PowerPort;
  }

  part def ControlledDoorAssembly {
    attribute doorId : String;
    attribute protectedZone : String;
    attribute normallyLocked : Boolean;
    attribute maximumHeldOpenTime : Second;

    part reader : CredentialReader {
      attribute readerId = "reader-main-entry";
      attribute readRange = 0.08;
      attribute maxReadLatency = 250.0;
    }

    part lock : ElectricStrikeLock {
      attribute lockId = "strike-main-entry";
      attribute failSecure = true;
      attribute actuationVoltage = 12.0;
      attribute actuationCurrent = 0.7;
      attribute unlockHoldTime = 5.0;
    }

    part sensor : DoorPositionSensor {
      attribute sensorId = "door-contact-main-entry";
      attribute debounceTime = 50.0;
      attribute heldOpenThreshold = 30.0;
    }
  }

  part def AccessControlSystem {
    attribute systemId : String;
    attribute primaryFunction : String = "Authenticate presented credentials, authorize entry according to policy, unlock protected doors for approved users, deny unauthorized access, and record auditable security events.";
    attribute maximumCredentialDecisionTime : Millisecond;
    attribute defaultUnlockDuration : Second;
    attribute requiredAvailabilityPercent : Percent;

    part mainEntrance : ControlledDoorAssembly {
      attribute doorId = "door-main-entry";
      attribute protectedZone = "lobby";
      attribute normallyLocked = true;
      attribute maximumHeldOpenTime = 30.0;
    }

    part controller : AccessController {
      attribute controllerId = "controller-01";
      attribute decisionTimeout = 500.0;
      attribute unlockDurationDefault = 5.0;
      attribute lockdownMode = false;
    }

    part auditLogger : AuditLogger {
      attribute loggerId = "audit-store-01";
      attribute localRetentionDays = 365;
      attribute remoteReplicationEnabled = true;
      attribute writeLatencyLimit = 1000.0;
    }

    part alarmAnnunciator : AlarmAnnunciator {
      attribute annunciatorId = "alarm-panel-01";
      attribute audibleLevelPercent = 80.0;
      attribute visualIndicatorEnabled = true;
    }

    part managementStation : ManagementWorkstation {
      attribute workstationId = "security-desk-01";
    }

    part powerSupply : BackupPowerSupply {
      attribute nominalVoltage = 12.0;
      attribute maximumCurrent = 3.0;
      attribute batteryCharge = 100.0;
      attribute minimumRuntime = 14400.0;
      attribute mainsAvailable = true;
    }

    connect mainEntrance.reader.accessRequestOut to controller.requestIn;
    connect controller.lockCommandOut to mainEntrance.lock.control;
    connect mainEntrance.sensor.statusOut to controller.doorStatusIn;
    connect controller.auditOut to auditLogger.auditIn;
    connect controller.alarmOut to alarmAnnunciator.alarmIn;
    connect managementStation.management to controller.management;
    connect powerSupply.powerOut to controller.power;
    connect powerSupply.powerOut to mainEntrance.lock.power;
    connect powerSupply.powerOut to mainEntrance.sensor.power;
  }

  action def HighLevelAccessControlFunction {
    in item presentedCredential : Credential;
    in item currentDoorStatus : DoorStatus;
    out item accessDecision : AccessDecision;
    out item lockCommand : LockCommand;
    out item auditEvent : AuditEvent;

    first receiveCredential;
    then validateCredential;
    then evaluatePolicy;
    then issueDecision;
    then actuateLock;
    then recordAuditEvent;

    action receiveCredential;
    action validateCredential;
    action evaluatePolicy;
    action issueDecision;
    action actuateLock;
    action recordAuditEvent;
  }

  requirement def AuthenticateCredentialRequirement {
    subject system : AccessControlSystem;

    require constraint {
      system.maximumCredentialDecisionTime <= 500.0
    }
  }

  requirement def FailSecureRequirement {
    subject lock : ElectricStrikeLock;

    require constraint {
      lock.failSecure == true
    }
  }

  requirement def UnlockDurationRequirement {
    subject system : AccessControlSystem;

    require constraint {
      system.defaultUnlockDuration >= 3.0 and system.defaultUnlockDuration <= 10.0
    }
  }

  requirement def AuditEveryDecisionRequirement {
    subject logger : AuditLogger;

    require constraint {
      logger.localRetentionDays >= 365 and logger.writeLatencyLimit <= 1000.0
    }
  }

  requirement def BackupPowerRequirement {
    subject supply : BackupPowerSupply;

    require constraint {
      supply.minimumRuntime >= 14400.0 and supply.nominalVoltage == 12.0
    }
  }

  requirement def HeldOpenAlarmRequirement {
    subject door : ControlledDoorAssembly;

    require constraint {
      door.maximumHeldOpenTime <= 30.0
    }
  }

  requirement def AvailabilityRequirement {
    subject system : AccessControlSystem;

    require constraint {
      system.requiredAvailabilityPercent >= 99.5
    }
  }

  part accessControlSystem : AccessControlSystem {
    attribute systemId = "ACS-building-entry";
    attribute maximumCredentialDecisionTime = 500.0;
    attribute defaultUnlockDuration = 5.0;
    attribute requiredAvailabilityPercent = 99.5;
  }

  satisfy AuthenticateCredentialRequirement by accessControlSystem;
  satisfy UnlockDurationRequirement by accessControlSystem;
  satisfy AvailabilityRequirement by accessControlSystem;
  satisfy BackupPowerRequirement by accessControlSystem.powerSupply;
  satisfy FailSecureRequirement by accessControlSystem.mainEntrance.lock;
  satisfy HeldOpenAlarmRequirement by accessControlSystem.mainEntrance;
  satisfy AuditEveryDecisionRequirement by accessControlSystem.auditLogger;
}