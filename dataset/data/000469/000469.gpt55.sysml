package MedicalDeviceConnectivity {

    import ScalarValues::*;

    enum def DeviceKind {
        enum electrocardiograph;
        enum vitalSignsMonitor;
        enum infusionPump;
        enum ventilator;
        enum pulseOximeter;
        enum bloodPressureMonitor;
    }

    enum def ConnectivityProtocol {
        enum ieee11073;
        enum hl7v2;
        enum fhirRest;
        enum mqttTls;
        enum proprietarySerial;
        enum bluetoothLeSecure;
        enum ethernetIp;
    }

    enum def AlarmPriority {
        enum advisory;
        enum warning;
        enum critical;
    }

    enum def AssociationState {
        enum unassociated;
        enum pendingConfirmation;
        enum associated;
        enum associationExpired;
    }

    enum def CyberSecurityPosture {
        enum trusted;
        enum suspicious;
        enum quarantined;
        enum lockedDown;
    }

    enum def MessageDisposition {
        enum accepted;
        enum rejected;
        enum buffered;
        enum retransmitted;
        enum delivered;
    }

    attribute def Millisecond :> Real {
        doc /* Unit: ms. */
    }

    attribute def Second :> Real {
        doc /* Unit: s. */
    }

    attribute def Percent :> Real {
        doc /* Unit: %. */
    }

    attribute def BeatPerMinute :> Real {
        doc /* Unit: beat/min. */
    }

    attribute def BreathPerMinute :> Real {
        doc /* Unit: breath/min. */
    }

    attribute def MillimeterMercury :> Real {
        doc /* Unit: mmHg. */
    }

    attribute def Celsius :> Real {
        doc /* Unit: degC. */
    }

    attribute def MilliliterPerHour :> Real {
        doc /* Unit: mL/h. */
    }

    attribute def Volt :> Real {
        doc /* Unit: V. */
    }

    attribute def ByteCount :> Integer {
        doc /* Unit: byte. */
    }

    attribute def MessageCount :> Integer {
        doc /* Unit: message. */
    }

    attribute def DeviceIdentifier :> String;

    attribute def PatientIdentifier :> String;

    attribute def EncounterIdentifier :> String;

    attribute def NetworkAddress :> String;

    attribute def UniversalObservationCode :> String;

    attribute def Iso8601Timestamp :> String;

    item def PatientContext {
        attribute patientId : PatientIdentifier;
        attribute encounterId : EncounterIdentifier;
        attribute bedId : String;
        attribute careUnit : String;
        attribute associationState : AssociationState;
        attribute associationTimestamp : Iso8601Timestamp;
    }

    item def DeviceIdentity {
        attribute deviceId : DeviceIdentifier;
        attribute manufacturer : String;
        attribute model : String;
        attribute serialNumber : String;
        attribute kind : DeviceKind;
        attribute firmwareVersion : String;
        attribute protocol : ConnectivityProtocol;
        attribute networkAddress : NetworkAddress;
    }

    item def DeviceStatus {
        attribute deviceId : DeviceIdentifier;
        attribute connected : Boolean;
        attribute batteryPercent : Percent;
        attribute lineVoltage : Volt;
        attribute clockSynchronized : Boolean;
        attribute selfTestPassed : Boolean;
        attribute lastSeen : Iso8601Timestamp;
        attribute securityPosture : CyberSecurityPosture;
    }

    item def RawObservation {
        attribute deviceId : DeviceIdentifier;
        attribute vendorMetricName : String;
        attribute vendorMetricCode : String;
        attribute rawValue : String;
        attribute rawUnit : String;
        attribute sampleTime : Iso8601Timestamp;
        attribute sequenceNumber : Integer;
        attribute payloadBytes : ByteCount;
    }

    item def NormalizedObservation {
        attribute patientId : PatientIdentifier;
        attribute encounterId : EncounterIdentifier;
        attribute deviceId : DeviceIdentifier;
        attribute universalCode : UniversalObservationCode;
        attribute displayName : String;
        attribute numericValue : Real;
        attribute canonicalUnit : String;
        attribute sampleTime : Iso8601Timestamp;
        attribute receivedTime : Iso8601Timestamp;
        attribute clinicallyValidated : Boolean;
    }

    item def HeartRateObservation :> NormalizedObservation {
        attribute :>> universalCode = "MDC_ECG_HEART_RATE";
        attribute heartRate : BeatPerMinute;
        attribute :>> canonicalUnit = "beat/min";
    }

    item def RespiratoryRateObservation :> NormalizedObservation {
        attribute :>> universalCode = "MDC_RESP_RATE";
        attribute respiratoryRate : BreathPerMinute;
        attribute :>> canonicalUnit = "breath/min";
    }

    item def BloodPressureObservation :> NormalizedObservation {
        attribute systolic : MillimeterMercury;
        attribute diastolic : MillimeterMercury;
        attribute meanArterialPressure : MillimeterMercury;
        attribute :>> canonicalUnit = "mmHg";
    }

    item def OxygenSaturationObservation :> NormalizedObservation {
        attribute spo2 : Percent;
        attribute :>> universalCode = "MDC_PULS_OXIM_SAT_O2";
        attribute :>> canonicalUnit = "%";
    }

    item def TemperatureObservation :> NormalizedObservation {
        attribute bodyTemperature : Celsius;
        attribute :>> universalCode = "MDC_TEMP_BODY";
        attribute :>> canonicalUnit = "degC";
    }

    item def InfusionRateObservation :> NormalizedObservation {
        attribute infusionRate : MilliliterPerHour;
        attribute :>> universalCode = "MDC_FLOW_FLUID_PUMP";
        attribute :>> canonicalUnit = "mL/h";
    }

    item def DeviceCommand {
        attribute targetDeviceId : DeviceIdentifier;
        attribute commandName : String;
        attribute commandPayload : String;
        attribute issuedBy : String;
        attribute issuedTime : Iso8601Timestamp;
        attribute requiresHumanConfirmation : Boolean;
    }

    item def AlarmNotification {
        attribute patientId : PatientIdentifier;
        attribute deviceId : DeviceIdentifier;
        attribute alarmCode : String;
        attribute alarmText : String;
        attribute priority : AlarmPriority;
        attribute onsetTime : Iso8601Timestamp;
        attribute acknowledged : Boolean;
    }

    item def AuditEvent {
        attribute eventId : String;
        attribute actor : String;
        attribute action : String;
        attribute deviceId : DeviceIdentifier;
        attribute patientId : PatientIdentifier;
        attribute eventTime : Iso8601Timestamp;
        attribute disposition : MessageDisposition;
        attribute securityRelevant : Boolean;
    }

    item def HealthRecordUpdate {
        attribute patientId : PatientIdentifier;
        attribute encounterId : EncounterIdentifier;
        attribute fhirResourceType : String;
        attribute resourceJson : String;
        attribute submissionTime : Iso8601Timestamp;
        attribute disposition : MessageDisposition;
    }

    item def NetworkPacket {
        attribute sourceAddress : NetworkAddress;
        attribute destinationAddress : NetworkAddress;
        attribute encrypted : Boolean;
        attribute payloadSize : ByteCount;
        attribute protocol : ConnectivityProtocol;
    }

    port def MedicalDevicePort {
        out item identity : DeviceIdentity;
        out item rawObservation : RawObservation;
        out item status : DeviceStatus;
        out item alarm : AlarmNotification;
        in item command : DeviceCommand;
    }

    port def GatewayDevicePort {
        in item identity : DeviceIdentity;
        in item rawObservation : RawObservation;
        in item status : DeviceStatus;
        in item alarm : AlarmNotification;
        out item command : DeviceCommand;
    }

    port def NormalizationInputPort {
        in item rawObservation : RawObservation;
        in item identity : DeviceIdentity;
        in item patientContext : PatientContext;
    }

    port def NormalizationOutputPort {
        out item normalizedObservation : NormalizedObservation;
        out item auditEvent : AuditEvent;
    }

    port def PatientContextPort {
        in item patientContext : PatientContext;
        out item patientContextRequest : String;
        out item auditEvent : AuditEvent;
    }

    port def ClinicalDataPort {
        in item normalizedObservation : NormalizedObservation;
        in item alarm : AlarmNotification;
        out item healthRecordUpdate : HealthRecordUpdate;
    }

    port def EhrPort {
        in item healthRecordUpdate : HealthRecordUpdate;
        out item patientContext : PatientContext;
    }

    port def AlarmPort {
        in item alarm : AlarmNotification;
        out item alarm : AlarmNotification;
        out item auditEvent : AuditEvent;
    }

    port def ClinicianUserPort {
        out item alarm : AlarmNotification;
        out item normalizedObservation : NormalizedObservation;
        in item command : DeviceCommand;
    }

    port def NetworkPort {
        in item packet : NetworkPacket;
        out item packet : NetworkPacket;
    }

    port def AuditPort {
        in item auditEvent : AuditEvent;
        out item auditEvent : AuditEvent;
    }

    interface def DeviceTelemetryInterface {
        end device : MedicalDevicePort;
        end gateway : GatewayDevicePort;
        flow device.identity to gateway.identity;
        flow device.rawObservation to gateway.rawObservation;
        flow device.status to gateway.status;
        flow device.alarm to gateway.alarm;
        flow gateway.command to device.command;
    }

    interface def RawDataToNormalizerInterface {
        end gateway : NormalizationInputPort;
        end normalizer : NormalizationInputPort;
        flow gateway.rawObservation to normalizer.rawObservation;
        flow gateway.identity to normalizer.identity;
        flow gateway.patientContext to normalizer.patientContext;
    }

    interface def NormalizedDataInterface {
        end normalizer : NormalizationOutputPort;
        end destination : ClinicalDataPort;
        flow normalizer.normalizedObservation to destination.normalizedObservation;
    }

    interface def AlarmDistributionInterface {
        end source : AlarmPort;
        end sink : AlarmPort;
        flow source.alarm to sink.alarm;
        flow source.auditEvent to sink.auditEvent;
    }

    interface def EhrUpdateInterface {
        end engine : ClinicalDataPort;
        end ehr : EhrPort;
        flow engine.healthRecordUpdate to ehr.healthRecordUpdate;
        flow ehr.patientContext to engine.normalizedObservation;
    }

    interface def AuditInterface {
        end producer : AuditPort;
        end recorder : AuditPort;
        flow producer.auditEvent to recorder.auditEvent;
    }

    part def BedsideMedicalDevice {
        attribute deviceKind : DeviceKind;
        attribute supportedProtocol : ConnectivityProtocol;
        attribute nominalSamplingPeriod : Second;
        attribute communicationTimeout : Second;
        attribute producesLifeCriticalData : Boolean;
        port connectivity : MedicalDevicePort;
        port network : NetworkPort;

        action generateMeasurements : GenerateDeviceMeasurements;
        action respondToCommand : RespondToDeviceCommand;

        state deviceConnectionState : DeviceConnectionState;
    }

    part def VitalSignsMonitor :> BedsideMedicalDevice {
        attribute :>> deviceKind = DeviceKind::vitalSignsMonitor;
        attribute :>> supportedProtocol = ConnectivityProtocol::ieee11073;
        attribute :>> nominalSamplingPeriod = 1.0;
        attribute :>> communicationTimeout = 5.0;
        attribute :>> producesLifeCriticalData = true;
    }

    part def InfusionPump :> BedsideMedicalDevice {
        attribute :>> deviceKind = DeviceKind::infusionPump;
        attribute :>> supportedProtocol = ConnectivityProtocol::proprietarySerial;
        attribute :>> nominalSamplingPeriod = 10.0;
        attribute :>> communicationTimeout = 15.0;
        attribute :>> producesLifeCriticalData = true;
    }

    part def Ventilator :> BedsideMedicalDevice {
        attribute :>> deviceKind = DeviceKind::ventilator;
        attribute :>> supportedProtocol = ConnectivityProtocol::ethernetIp;
        attribute :>> nominalSamplingPeriod = 1.0;
        attribute :>> communicationTimeout = 3.0;
        attribute :>> producesLifeCriticalData = true;
    }

    part def ConnectivityGateway {
        doc /* Receives heterogeneous bedside medical device data, maintains secure device sessions, buffers messages during network interruption, and forwards normalized clinical content to downstream hospital systems. */
        attribute gatewayId : String;
        attribute maximumConnectedDevices : Integer;
        attribute connectedDeviceCount : Integer;
        attribute inboundLatencyBudget : Millisecond;
        attribute outboundLatencyBudget : Millisecond;
        attribute storeAndForwardCapacity : MessageCount;
        attribute messageLossRate : Percent;
        attribute securityPosture : CyberSecurityPosture;

        port vitalSignsSide : GatewayDevicePort;
        port infusionPumpSide : GatewayDevicePort;
        port ventilatorSide : GatewayDevicePort;
        port normalizerInput : NormalizationInputPort;
        port alarmOutput : AlarmPort;
        port auditOutput : AuditPort;
        port network : NetworkPort;

        action discoverDevices : DiscoverDevices;
        action receiveDeviceTelemetry : ReceiveDeviceTelemetry;
        action bufferTelemetry : BufferTelemetry;
        action enforceSecureSession : EnforceSecureSession;
        action forwardRawTelemetry : ForwardRawTelemetry;

        state operationalState : GatewayOperationalState;
    }

    part def TerminologyAndUnitNormalizer {
        doc /* Converts vendor-specific device observations to canonical clinical observation names, universal codes, and canonical units suitable for EHR ingestion. */
        attribute supportedCodeSystem : String;
        attribute mappingVersion : String;
        attribute maximumNormalizationLatency : Millisecond;
        attribute minimumMappingCoverage : Percent;

        port input : NormalizationInputPort;
        port output : NormalizationOutputPort;
        port auditOutput : AuditPort;

        action mapVendorCode : MapVendorCode;
        action convertMeasurementUnits : ConvertMeasurementUnits;
        action validateObservation : ValidateObservation;
        action publishNormalizedObservation : PublishNormalizedObservation;

        state normalizationState : NormalizationState;
    }

    part def PatientAssociationService {
        doc /* Associates each incoming device message to a verified patient encounter and care location before clinical publication. */
        attribute associationTtl : Second;
        attribute positivePatientMatchRequired : Boolean;
        attribute unmatchedDataRetention : Second;

        port ehrContext : EhrPort;
        port contextPort : PatientContextPort;
        port auditOutput : AuditPort;

        action requestPatientContext : RequestPatientContext;
        action verifyPatientAssociation : VerifyPatientAssociation;
        action expireStaleAssociation : ExpireStaleAssociation;

        state associationState : PatientAssociationState;
    }

    part def ClinicalIntegrationEngine {
        doc /* Builds clinical update messages, routes device observations and alarms, and submits validated content to hospital clinical systems. */
        attribute supportedOutboundStandard : ConnectivityProtocol;
        attribute maximumEhrSubmissionLatency : Millisecond;
        attribute retryInterval : Second;
        attribute maximumRetryCount : Integer;

        port clinicalInput : ClinicalDataPort;
        port ehrOutput : ClinicalDataPort;
        port alarmOutput : AlarmPort;
        port auditOutput : AuditPort;

        action buildHealthRecordUpdate : BuildHealthRecordUpdate;
        action routeAlarmNotification : RouteAlarmNotification;
        action submitToEhr : SubmitToEhr;
        action retryFailedSubmission : RetryFailedSubmission;

        state integrationState : IntegrationEngineState;
    }

    part def ElectronicHealthRecordSystem {
        doc /* Authoritative hospital system receiving device-originated observations and providing patient encounter context. */
        attribute ehrVendor : String;
        attribute fhirBaseUrl : String;
        attribute inboundAvailability : Percent;

        port ehrInterface : EhrPort;
        port auditOutput : AuditPort;

        action acceptHealthRecordUpdate : AcceptHealthRecordUpdate;
        action providePatientContext : ProvidePatientContext;
    }

    part def ClinicianConsole {
        doc /* Presents near-real-time device observations, patient association state, and prioritized alarms to clinicians. */
        attribute displayRefreshPeriod : Second;
        attribute alarmAcknowledgementTimeout : Second;

        port userInterface : ClinicianUserPort;
        port alarmInput : AlarmPort;
        port dataInput : ClinicalDataPort;

        action displayObservationTrend : DisplayObservationTrend;
        action displayAlarm : DisplayAlarm;
        action acknowledgeAlarm : AcknowledgeAlarm;
    }

    part def AlarmManager {
        doc /* Deduplicates alarms, assigns clinical priority, forwards alarms to clinicians, and records alarm audit events. */
        attribute duplicateSuppressionWindow : Second;
        attribute criticalAlarmDeliveryLatency : Millisecond;
        attribute alarmRetention : Second;

        port gatewayAlarmInput : AlarmPort;
        port integrationAlarmInput : AlarmPort;
        port clinicianAlarmOutput : AlarmPort;
        port auditOutput : AuditPort;

        action deduplicateAlarm : DeduplicateAlarm;
        action prioritizeAlarm : PrioritizeAlarm;
        action distributeAlarm : DistributeAlarm;
        action auditAlarmLifecycle : AuditAlarmLifecycle;
    }

    part def SecurityAndAuditService {
        doc /* Authenticates devices and users, validates encrypted channels, records audit trails, and quarantines suspicious connections. */
        attribute tlsVersion : String;
        attribute certificateRotationInterval : Second;
        attribute auditRetentionDays : Integer;
        attribute intrusionDetectionEnabled : Boolean;

        port auditInput : AuditPort;
        port networkSecurityPort : NetworkPort;

        action authenticateDevice : AuthenticateDevice;
        action authorizeCommand : AuthorizeCommand;
        action recordAuditEvent : RecordAuditEvent;
        action quarantineEndpoint : QuarantineEndpoint;

        state securityState : SecurityState;
    }

    action def GenerateDeviceMeasurements {
        out item identity : DeviceIdentity;
        out item rawObservation : RawObservation;
        out item status : DeviceStatus;
        out item alarm : AlarmNotification;
    }

    action def RespondToDeviceCommand {
        in item command : DeviceCommand;
        out item auditEvent : AuditEvent;
    }

    action def DiscoverDevices {
        out item identity : DeviceIdentity;
        out item auditEvent : AuditEvent;
    }

    action def ReceiveDeviceTelemetry {
        in item identity : DeviceIdentity;
        in item rawObservation : RawObservation;
        in item status : DeviceStatus;
        in item alarm : AlarmNotification;
        out item auditEvent : AuditEvent;
    }

    action def BufferTelemetry {
        in item rawObservation : RawObservation;
        out item rawObservation : RawObservation;
        out item auditEvent : AuditEvent;
    }

    action def EnforceSecureSession {
        in item packet : NetworkPacket;
        out item packet : NetworkPacket;
        out item auditEvent : AuditEvent;
    }

    action def ForwardRawTelemetry {
        in item rawObservation : RawObservation;
        in item identity : DeviceIdentity;
        out item rawObservation : RawObservation;
        out item identity : DeviceIdentity;
    }

    action def MapVendorCode {
        in item rawObservation : RawObservation;
        out item normalizedObservation : NormalizedObservation;
    }

    action def ConvertMeasurementUnits {
        in item normalizedObservation : NormalizedObservation;
        out item normalizedObservation : NormalizedObservation;
    }

    action def ValidateObservation {
        in item normalizedObservation : NormalizedObservation;
        in item patientContext : PatientContext;
        out item normalizedObservation : NormalizedObservation;
        out item auditEvent : AuditEvent;
    }

    action def PublishNormalizedObservation {
        in item normalizedObservation : NormalizedObservation;
        out item normalizedObservation : NormalizedObservation;
        out item auditEvent : AuditEvent;
    }

    action def RequestPatientContext {
        in item patientContextRequest : String;
        out item patientContext : PatientContext;
        out item auditEvent : AuditEvent;
    }

    action def VerifyPatientAssociation {
        in item identity : DeviceIdentity;
        in item patientContext : PatientContext;
        out item patientContext : PatientContext;
        out item auditEvent : AuditEvent;
    }

    action def ExpireStaleAssociation {
        in item patientContext : PatientContext;
        out item patientContext : PatientContext;
        out item auditEvent : AuditEvent;
    }

    action def BuildHealthRecordUpdate {
        in item normalizedObservation : NormalizedObservation;
        out item healthRecordUpdate : HealthRecordUpdate;
        out item auditEvent : AuditEvent;
    }

    action def RouteAlarmNotification {
        in item alarm : AlarmNotification;
        out item alarm : AlarmNotification;
        out item auditEvent : AuditEvent;
    }

    action def SubmitToEhr {
        in item healthRecordUpdate : HealthRecordUpdate;
        out item healthRecordUpdate : HealthRecordUpdate;
        out item auditEvent : AuditEvent;
    }

    action def RetryFailedSubmission {
        in item healthRecordUpdate : HealthRecordUpdate;
        out item healthRecordUpdate : HealthRecordUpdate;
        out item auditEvent : AuditEvent;
    }

    action def AcceptHealthRecordUpdate {
        in item healthRecordUpdate : HealthRecordUpdate;
        out item auditEvent : AuditEvent;
    }

    action def ProvidePatientContext {
        in item patientContextRequest : String;
        out item patientContext : PatientContext;
        out item auditEvent : AuditEvent;
    }

    action def DisplayObservationTrend {
        in item normalizedObservation : NormalizedObservation;
    }

    action def DisplayAlarm {
        in item alarm : AlarmNotification;
    }

    action def AcknowledgeAlarm {
        in item alarm : AlarmNotification;
        out item alarm : AlarmNotification;
        out item auditEvent : AuditEvent;
    }

    action def DeduplicateAlarm {
        in item alarm : AlarmNotification;
        out item alarm : AlarmNotification;
    }

    action def PrioritizeAlarm {
        in item alarm : AlarmNotification;
        out item alarm : AlarmNotification;
    }

    action def DistributeAlarm {
        in item alarm : AlarmNotification;
        out item alarm : AlarmNotification;
        out item auditEvent : AuditEvent;
    }

    action def AuditAlarmLifecycle {
        in item alarm : AlarmNotification;
        out item auditEvent : AuditEvent;
    }

    action def AuthenticateDevice {
        in item identity : DeviceIdentity;
        out item auditEvent : AuditEvent;
    }

    action def AuthorizeCommand {
        in item command : DeviceCommand;
        out item command : DeviceCommand;
        out item auditEvent : AuditEvent;
    }

    action def RecordAuditEvent {
        in item auditEvent : AuditEvent;
        out item auditEvent : AuditEvent;
    }

    action def QuarantineEndpoint {
        in item packet : NetworkPacket;
        out item auditEvent : AuditEvent;
    }

    action def ProvideMedicalDeviceConnectivity {
        doc /* Primary high-level function: securely connect bedside medical devices to hospital information systems by acquiring device data, associating it with the correct patient encounter, normalizing terminology and units, distributing alarms, and publishing validated observations to the electronic health record. */
        in item bedsideIdentity : DeviceIdentity;
        in item rawObservation : RawObservation;
        in item deviceStatus : DeviceStatus;
        in item alarm : AlarmNotification;
        in item patientContext : PatientContext;
        out item normalizedObservation : NormalizedObservation;
        out item healthRecordUpdate : HealthRecordUpdate;
        out item clinicianAlarm : AlarmNotification;
        out item auditEvent : AuditEvent;

        first action acquire : ReceiveDeviceTelemetry;
        then action secure : EnforceSecureSession;
        then action associate : VerifyPatientAssociation;
        then action map : MapVendorCode;
        then action convert : ConvertMeasurementUnits;
        then action validate : ValidateObservation;
        then action publish : PublishNormalizedObservation;
        then action buildUpdate : BuildHealthRecordUpdate;
        then action submit : SubmitToEhr;
    }

    state def DeviceConnectionState {
        entry;
        state poweredOff;
        state advertisingIdentity;
        state connected;
        state streamingTelemetry;
        state commandProcessing;
        state disconnected;
        state faulted;

        transition initial then poweredOff;
        transition poweredOff then advertisingIdentity;
        transition advertisingIdentity then connected;
        transition connected then streamingTelemetry;
        transition streamingTelemetry then commandProcessing;
        transition commandProcessing then streamingTelemetry;
        transition streamingTelemetry then disconnected;
        transition disconnected then advertisingIdentity;
        transition connected then faulted;
        transition faulted then disconnected;
    }

    state def GatewayOperationalState {
        entry;
        state powerUp;
        state selfTest;
        state discoveringDevices;
        state authenticatingDevices;
        state receivingTelemetry;
        state storeAndForwardMode;
        state degradedOperation;
        state maintenanceMode;
        state cybersecureLockdown;

        transition initial then powerUp;
        transition powerUp then selfTest;
        transition selfTest then discoveringDevices;
        transition discoveringDevices then authenticatingDevices;
        transition authenticatingDevices then receivingTelemetry;
        transition receivingTelemetry then storeAndForwardMode;
        transition storeAndForwardMode then receivingTelemetry;
        transition receivingTelemetry then degradedOperation;
        transition degradedOperation then receivingTelemetry;
        transition receivingTelemetry then maintenanceMode;
        transition maintenanceMode then discoveringDevices;
        transition receivingTelemetry then cybersecureLockdown;
        transition cybersecureLockdown then maintenanceMode;
    }

    state def NormalizationState {
        entry;
        state idle;
        state mappingVendorCode;
        state convertingUnits;
        state validatingClinicalRange;
        state publishingCanonicalObservation;
        state rejectingInvalidObservation;

        transition initial then idle;
        transition idle then mappingVendorCode;
        transition mappingVendorCode then convertingUnits;
        transition convertingUnits then validatingClinicalRange;
        transition validatingClinicalRange then publishingCanonicalObservation;
        transition validatingClinicalRange then rejectingInvalidObservation;
        transition publishingCanonicalObservation then idle;
        transition rejectingInvalidObservation then idle;
    }

    state def PatientAssociationState {
        entry;
        state noPatientContext;
        state requestingContext;
        state awaitingClinicianConfirmation;
        state associated;
        state expired;
        state conflictDetected;

        transition initial then noPatientContext;
        transition noPatientContext then requestingContext;
        transition requestingContext then awaitingClinicianConfirmation;
        transition awaitingClinicianConfirmation then associated;
        transition associated then expired;
        transition expired then requestingContext;
        transition requestingContext then conflictDetected;
        transition conflictDetected then awaitingClinicianConfirmation;
    }

    state def IntegrationEngineState {
        entry;
        state ready;
        state composingFhirObservation;
        state submittingToEhr;
        state waitingForAcknowledgement;
        state retrying;
        state failedSubmission;
        state delivered;

        transition initial then ready;
        transition ready then composingFhirObservation;
        transition composingFhirObservation then submittingToEhr;
        transition submittingToEhr then waitingForAcknowledgement;
        transition waitingForAcknowledgement then delivered;
        transition waitingForAcknowledgement then retrying;
        transition retrying then submittingToEhr;
        transition retrying then failedSubmission;
        transition delivered then ready;
        transition failedSubmission then ready;
    }

    state def SecurityState {
        entry;
        state monitoring;
        state authenticatingEndpoint;
        state trustedSession;
        state suspiciousActivity;
        state quarantinedEndpoint;
        state lockedDown;

        transition initial then monitoring;
        transition monitoring then authenticatingEndpoint;
        transition authenticatingEndpoint then trustedSession;
        transition trustedSession then monitoring;
        transition monitoring then suspiciousActivity;
        transition suspiciousActivity then quarantinedEndpoint;
        transition quarantinedEndpoint then monitoring;
        transition suspiciousActivity then lockedDown;
        transition lockedDown then monitoring;
    }

    constraint def ObservationLatencyConstraint {
        in gatewayLatency : Millisecond;
        in normalizationLatency : Millisecond;
        in ehrSubmissionLatency : Millisecond;
        in maximumEndToEndLatency : Millisecond;
        gatewayLatency + normalizationLatency + ehrSubmissionLatency <= maximumEndToEndLatency
    }

    constraint def AlarmDeliveryConstraint {
        in alarmDeliveryLatency : Millisecond;
        in maximumCriticalAlarmLatency : Millisecond;
        alarmDeliveryLatency <= maximumCriticalAlarmLatency
    }

    constraint def DeviceCapacityConstraint {
        in connectedDeviceCount : Integer;
        in maximumConnectedDevices : Integer;
        connectedDeviceCount <= maximumConnectedDevices
    }

    constraint def DataLossConstraint {
        in messageLossRate : Percent;
        in maximumMessageLossRate : Percent;
        messageLossRate <= maximumMessageLossRate
    }

    constraint def MappingCoverageConstraint {
        in mappingCoverage : Percent;
        in minimumMappingCoverage : Percent;
        mappingCoverage >= minimumMappingCoverage
    }

    part def MedicalDeviceConnectivitySystem {
        doc /* System primary function: provide secure, reliable, near-real-time connectivity between bedside medical devices and clinical information systems so that device observations and alarms are associated with the correct patient, normalized to standard clinical semantics, displayed to clinicians, and recorded in the electronic health record. */

        attribute systemName : String = "Hospital Medical Device Connectivity System";
        attribute maximumEndToEndObservationLatency : Millisecond = 5000.0;
        attribute maximumCriticalAlarmLatency : Millisecond = 2000.0;
        attribute maximumMessageLossRate : Percent = 0.01;
        attribute minimumTerminologyMappingCoverage : Percent = 99.5;
        attribute minimumAvailability : Percent = 99.9;
        attribute connectedDeviceCount : Integer = 3;

        part vitalSignsMonitor : VitalSignsMonitor;
        part infusionPump : InfusionPump;
        part ventilator : Ventilator;
        part gateway : ConnectivityGateway {
            attribute :>> gatewayId = "MDC-GW-ICU-01";
            attribute :>> maximumConnectedDevices = 64;
            attribute :>> connectedDeviceCount = 3;
            attribute :>> inboundLatencyBudget = 500.0;
            attribute :>> outboundLatencyBudget = 500.0;
            attribute :>> storeAndForwardCapacity = 100000;
            attribute :>> messageLossRate = 0.001;
            attribute :>> securityPosture = CyberSecurityPosture::trusted;
        }
        part patientAssociation : PatientAssociationService {
            attribute :>> associationTtl = 28800.0;
            attribute :>> positivePatientMatchRequired = true;
            attribute :>> unmatchedDataRetention = 3600.0;
        }
        part normalizer : TerminologyAndUnitNormalizer {
            attribute :>> supportedCodeSystem = "IEEE 11073 MDC mapped to LOINC/FHIR Observation";
            attribute :>> mappingVersion = "2026.1";
            attribute :>> maximumNormalizationLatency = 1000.0;
            attribute :>> minimumMappingCoverage = 99.5;
        }
        part integrationEngine : ClinicalIntegrationEngine {
            attribute :>> supportedOutboundStandard = ConnectivityProtocol::fhirRest;
            attribute :>> maximumEhrSubmissionLatency = 3500.0;
            attribute :>> retryInterval = 30.0;
            attribute :>> maximumRetryCount = 5;
        }
        part ehr : ElectronicHealthRecordSystem {
            attribute :>> ehrVendor = "Enterprise EHR";
            attribute :>> fhirBaseUrl = "https://ehr.example.org/fhir";
            attribute :>> inboundAvailability = 99.95;
        }
        part alarmManager : AlarmManager {
            attribute :>> duplicateSuppressionWindow = 10.0;
            attribute :>> criticalAlarmDeliveryLatency = 2000.0;
            attribute :>> alarmRetention = 2592000.0;
        }
        part clinicianConsole : ClinicianConsole {
            attribute :>> displayRefreshPeriod = 1.0;
            attribute :>> alarmAcknowledgementTimeout = 120.0;
        }
        part securityAndAudit : SecurityAndAuditService {
            attribute :>> tlsVersion = "TLS 1.3";
            attribute :>> certificateRotationInterval = 7776000.0;
            attribute :>> auditRetentionDays = 2555;
            attribute :>> intrusionDetectionEnabled = true;
        }

        port hospitalNetwork : NetworkPort;
        port clinicianInteraction : ClinicianUserPort;

        connection vitalSignsLink : DeviceTelemetryInterface connect vitalSignsMonitor.connectivity to gateway.vitalSignsSide;
        connection infusionPumpLink : DeviceTelemetryInterface connect infusionPump.connectivity to gateway.infusionPumpSide;
        connection ventilatorLink : DeviceTelemetryInterface connect ventilator.connectivity to gateway.ventilatorSide;

        connection contextToNormalizer connect patientAssociation.contextPort to normalizer.input;
        connection gatewayToNormalizer connect gateway.normalizerInput to normalizer.input;
        connection normalizerToIntegration : NormalizedDataInterface connect normalizer.output to integrationEngine.clinicalInput;
        connection integrationToEhr connect integrationEngine.ehrOutput to ehr.ehrInterface;

        connection gatewayAlarmsToManager : AlarmDistributionInterface connect gateway.alarmOutput to alarmManager.gatewayAlarmInput;
        connection integrationAlarmsToManager : AlarmDistributionInterface connect integrationEngine.alarmOutput to alarmManager.integrationAlarmInput;
        connection alarmManagerToConsole : AlarmDistributionInterface connect alarmManager.clinicianAlarmOutput to clinicianConsole.alarmInput;

        connection consoleDataFeed connect integrationEngine.clinicalInput to clinicianConsole.dataInput;
        connection systemNetworkSecurity connect hospitalNetwork to securityAndAudit.networkSecurityPort;

        connection gatewayAudit connect gateway.auditOutput to securityAndAudit.auditInput;
        connection normalizerAudit connect normalizer.auditOutput to securityAndAudit.auditInput;
        connection patientAssociationAudit connect patientAssociation.auditOutput to securityAndAudit.auditInput;
        connection integrationAudit connect integrationEngine.auditOutput to securityAndAudit.auditInput;
        connection alarmAudit connect alarmManager.auditOutput to securityAndAudit.auditInput;
        connection ehrAudit connect ehr.auditOutput to securityAndAudit.auditInput;

        action primaryFunction : ProvideMedicalDeviceConnectivity;

        constraint observationLatency : ObservationLatencyConstraint {
            in gatewayLatency = gateway.outboundLatencyBudget;
            in normalizationLatency = normalizer.maximumNormalizationLatency;
            in ehrSubmissionLatency = integrationEngine.maximumEhrSubmissionLatency;
            in maximumEndToEndLatency = maximumEndToEndObservationLatency;
        }

        constraint criticalAlarmDelivery : AlarmDeliveryConstraint {
            in alarmDeliveryLatency = alarmManager.criticalAlarmDeliveryLatency;
            in maximumCriticalAlarmLatency = maximumCriticalAlarmLatency;
        }

        constraint deviceCapacity : DeviceCapacityConstraint {
            in connectedDeviceCount = gateway.connectedDeviceCount;
            in maximumConnectedDevices = gateway.maximumConnectedDevices;
        }

        constraint dataLoss : DataLossConstraint {
            in messageLossRate = gateway.messageLossRate;
            in maximumMessageLossRate = maximumMessageLossRate;
        }

        constraint terminologyCoverage : MappingCoverageConstraint {
            in mappingCoverage = normalizer.minimumMappingCoverage;
            in minimumMappingCoverage = minimumTerminologyMappingCoverage;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall securely acquire data from connected bedside medical devices, associate each observation and alarm with the correct patient encounter, normalize device-specific data into standard clinical terminology and units, and deliver validated information to clinicians and the electronic health record. */
        subject mdc : MedicalDeviceConnectivitySystem;
        require constraint {
            mdc.connectedDeviceCount >= 1
        }
    }

    requirement def EndToEndObservationLatencyRequirement {
        doc /* The system shall deliver validated non-waveform device observations to the EHR within 5 seconds of receipt at the connectivity gateway during normal operation. */
        subject mdc : MedicalDeviceConnectivitySystem;
        require constraint {
            mdc.maximumEndToEndObservationLatency <= 5000.0
        }
    }

    requirement def CriticalAlarmLatencyRequirement {
        doc /* The system shall deliver critical device alarm notifications to the clinician console within 2 seconds of receipt at the connectivity gateway. */
        subject mdc : MedicalDeviceConnectivitySystem;
        require constraint {
            mdc.maximumCriticalAlarmLatency <= 2000.0
        }
    }

    requirement def DeviceCapacityRequirement {
        doc /* The gateway shall support at least 64 concurrently connected medical devices per care unit gateway. */
        subject gateway : ConnectivityGateway;
        require constraint {
            gateway.maximumConnectedDevices >= 64
        }
    }

    requirement def PatientAssociationRequirement {
        doc /* The system shall not publish a device observation to the EHR unless the observation is associated with a verified patient encounter. */
        subject service : PatientAssociationService;
        require constraint {
            service.positivePatientMatchRequired == true
        }
    }

    requirement def DataIntegrityRequirement {
        doc /* The system shall preserve observation identity, device identity, patient identity, sample time, canonical unit, and audit trail for each accepted observation. */
        subject mdc : MedicalDeviceConnectivitySystem;
        require constraint {
            mdc.maximumMessageLossRate <= 0.01
        }
    }

    requirement def TerminologyNormalizationRequirement {
        doc /* The terminology service shall map at least 99.5 percent of supported device metrics to standard clinical observation codes and canonical units. */
        subject normalizer : TerminologyAndUnitNormalizer;
        require constraint {
            normalizer.minimumMappingCoverage >= 99.5
        }
    }

    requirement def SecurityRequirement {
        doc /* The system shall authenticate connected devices, protect network communication using TLS 1.3 or stronger, authorize device commands, and audit security-relevant events. */
        subject security : SecurityAndAuditService;
        require constraint {
            security.intrusionDetectionEnabled == true
        }
    }

    requirement def StoreAndForwardRequirement {
        doc /* The gateway shall buffer at least 100000 messages during downstream network interruption and forward buffered messages in original sequence order when connectivity is restored. */
        subject gateway : ConnectivityGateway;
        require constraint {
            gateway.storeAndForwardCapacity >= 100000
        }
    }

    requirement def AvailabilityRequirement {
        doc /* The system shall provide at least 99.9 percent operational availability for acquisition, normalization, alarm delivery, and EHR publication functions. */
        subject mdc : MedicalDeviceConnectivitySystem;
        require constraint {
            mdc.minimumAvailability >= 99.9
        }
    }

    part hospitalMedicalDeviceConnectivitySystem : MedicalDeviceConnectivitySystem;

    requirement primaryFunction : PrimaryFunctionRequirement {
        subject mdc = hospitalMedicalDeviceConnectivitySystem;
    }

    requirement observationLatency : EndToEndObservationLatencyRequirement {
        subject mdc = hospitalMedicalDeviceConnectivitySystem;
    }

    requirement alarmLatency : CriticalAlarmLatencyRequirement {
        subject mdc = hospitalMedicalDeviceConnectivitySystem;
    }

    requirement capacity : DeviceCapacityRequirement {
        subject gateway = hospitalMedicalDeviceConnectivitySystem.gateway;
    }

    requirement patientAssociationRequired : PatientAssociationRequirement {
        subject service = hospitalMedicalDeviceConnectivitySystem.patientAssociation;
    }

    requirement dataIntegrity : DataIntegrityRequirement {
        subject mdc = hospitalMedicalDeviceConnectivitySystem;
    }

    requirement terminologyNormalization : TerminologyNormalizationRequirement {
        subject normalizer = hospitalMedicalDeviceConnectivitySystem.normalizer;
    }

    requirement securityRequired : SecurityRequirement {
        subject security = hospitalMedicalDeviceConnectivitySystem.securityAndAudit;
    }

    requirement storeAndForward : StoreAndForwardRequirement {
        subject gateway = hospitalMedicalDeviceConnectivitySystem.gateway;
    }

    requirement availability : AvailabilityRequirement {
        subject mdc = hospitalMedicalDeviceConnectivitySystem;
    }

    satisfy primaryFunction by hospitalMedicalDeviceConnectivitySystem;
    satisfy observationLatency by hospitalMedicalDeviceConnectivitySystem;
    satisfy alarmLatency by hospitalMedicalDeviceConnectivitySystem;
    satisfy capacity by hospitalMedicalDeviceConnectivitySystem.gateway;
    satisfy patientAssociationRequired by hospitalMedicalDeviceConnectivitySystem.patientAssociation;
    satisfy dataIntegrity by hospitalMedicalDeviceConnectivitySystem;
    satisfy terminologyNormalization by hospitalMedicalDeviceConnectivitySystem.normalizer;
    satisfy securityRequired by hospitalMedicalDeviceConnectivitySystem.securityAndAudit;
    satisfy storeAndForward by hospitalMedicalDeviceConnectivitySystem.gateway;
    satisfy availability by hospitalMedicalDeviceConnectivitySystem;
}
