package NodeRedBasedAutomationSystem {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    enum def RuntimeMode {
        enum idle;
        enum deploying;
        enum running;
        enum degraded;
        enum stopped;
    }

    enum def MessagePriority {
        enum low;
        enum normal;
        enum high;
        enum critical;
    }

    enum def DeliveryStatus {
        enum accepted;
        enum transformed;
        enum routed;
        enum delivered;
        enum failed;
        enum retried;
    }

    item def FlowMessage {
        attribute messageId : String;
        attribute topic : String;
        attribute payload : String;
        attribute priority : MessagePriority;
        attribute timestamp : Time;
        attribute size : ISQ::information;
        attribute status : DeliveryStatus;
    }

    item def DeviceTelemetry :> FlowMessage {
        attribute deviceId : String;
        attribute measuredValue : Real;
        attribute measuredUnit : String;
        attribute quality : Real;
    }

    item def ApiCommand :> FlowMessage {
        attribute commandName : String;
        attribute targetResource : String;
        attribute authorizationToken : String;
    }

    item def AlertNotification :> FlowMessage {
        attribute severity : MessagePriority;
        attribute recipient : String;
        attribute alertText : String;
    }

    item def DeploymentPackage {
        attribute packageId : String;
        attribute flowRevision : String;
        attribute nodeCount : Integer;
        attribute checksum : String;
    }

    item def AuditRecord {
        attribute recordId : String;
        attribute eventName : String;
        attribute actor : String;
        attribute eventTime : Time;
        attribute outcome : String;
    }

    port def MessageInputPort {
        in item incomingMessage : FlowMessage;
    }

    port def MessageOutputPort {
        out item outgoingMessage : FlowMessage;
    }

    port def TelemetryPort {
        in item telemetry : DeviceTelemetry;
    }

    port def CommandPort {
        out item command : ApiCommand;
    }

    port def DeploymentPort {
        in item package : DeploymentPackage;
    }

    port def AuditPort {
        out item record : AuditRecord;
    }

    port def NotificationPort {
        out item alert : AlertNotification;
    }

    interface def MessageTransfer {
        end source : MessageOutputPort;
        end destination : MessageInputPort;
        flow message : FlowMessage from source to destination;
    }

    interface def TelemetryTransfer {
        end source : TelemetryPort;
        end destination : MessageInputPort;
        flow message : DeviceTelemetry from source to destination;
    }

    interface def CommandTransfer {
        end source : MessageOutputPort;
        end destination : CommandPort;
        flow command : ApiCommand from source to destination;
    }

    interface def NotificationTransfer {
        end source : MessageOutputPort;
        end destination : NotificationPort;
        flow alert : AlertNotification from source to destination;
    }

    interface def AuditTransfer {
        end source : AuditPort;
        end destination : AuditPort;
        flow record : AuditRecord from source to destination;
    }

    action def ReceiveMessage {
        in item rawMessage : FlowMessage;
        out item acceptedMessage : FlowMessage;
    }

    action def ValidateMessage {
        in item candidateMessage : FlowMessage;
        out item validMessage : FlowMessage;
        out item rejectedMessage : FlowMessage;
    }

    action def TransformMessage {
        in item validMessage : FlowMessage;
        out item transformedMessage : FlowMessage;
    }

    action def RouteMessage {
        in item transformedMessage : FlowMessage;
        out item routedMessage : FlowMessage;
    }

    action def ExecuteIntegration {
        in item routedMessage : FlowMessage;
        out item resultMessage : FlowMessage;
    }

    action def PublishAuditRecord {
        in item processedMessage : FlowMessage;
        out item auditRecord : AuditRecord;
    }

    action def RaiseAlert {
        in item failedMessage : FlowMessage;
        out item alert : AlertNotification;
    }

    state def RuntimeStateMachine {
        state idle;
        state deploying;
        state running;
        state degraded;
        state stopped;

        transition first idle;

        transition idle_to_deploying
            first idle
            then deploying;

        transition deploying_to_running
            first deploying
            then running;

        transition running_to_degraded
            first running
            then degraded;

        transition degraded_to_running
            first degraded
            then running;

        transition running_to_stopped
            first running
            then stopped;

        transition degraded_to_stopped
            first degraded
            then stopped;

        transition stopped_to_idle
            first stopped
            then idle;
    }

    part def SensorGateway {
        port telemetryOut : TelemetryPort;
        attribute maximumDevices : Integer = 500;
        attribute telemetryRate : Frequency = 1000 [Hz];
    }

    part def ApiGateway {
        port messageIn : MessageInputPort;
        port commandOut : CommandPort;
        attribute maximumRequestsPerSecond : Frequency = 200 [Hz];
        attribute authenticationRequired : Boolean = true;
    }

    part def FlowEditor {
        port deploymentOut : DeploymentPort;
        port auditOut : AuditPort;
        attribute concurrentEditors : Integer = 20;
        attribute autosaveInterval : Time = 30 [s];
    }

    part def FlowRepository {
        port deploymentIn : DeploymentPort;
        port deploymentOut : DeploymentPort;
        port auditOut : AuditPort;
        attribute retainedFlowRevisions : Integer = 50;
        attribute maximumFlowSize : ISQ::information = 25 [MB];
    }

    part def NodeRedRuntime {
        port messageIn : MessageInputPort;
        port messageOut : MessageOutputPort;
        port deploymentIn : DeploymentPort;
        port auditOut : AuditPort;
        attribute runtimeMode : RuntimeMode = RuntimeMode::idle;
        attribute maximumConcurrentMessages : Integer = 10000;
        attribute maximumEndToEndLatency : Time = 2 [s];
        attribute minimumAvailability : Real = 0.999;
        state runtimeState : RuntimeStateMachine;

        action processMessage {
            first start;
            then receive : ReceiveMessage;
            then validate : ValidateMessage;
            then transform : TransformMessage;
            then route : RouteMessage;
            then execute : ExecuteIntegration;
            then audit : PublishAuditRecord;
            then done;

            flow from receive.acceptedMessage to validate.candidateMessage;
            flow from validate.validMessage to transform.validMessage;
            flow from transform.transformedMessage to route.transformedMessage;
            flow from route.routedMessage to execute.routedMessage;
            flow from execute.resultMessage to audit.processedMessage;
        }
    }

    part def FunctionNode {
        port messageIn : MessageInputPort;
        port messageOut : MessageOutputPort;
        attribute scriptLanguage : String = "JavaScript";
        attribute maximumExecutionTime : Time = 250 [ms];
        attribute memoryLimit : ISQ::information = 128 [MB];
    }

    part def SwitchNode {
        port messageIn : MessageInputPort;
        port messageOut : MessageOutputPort;
        attribute routingRuleCount : Integer = 32;
        attribute defaultRouteEnabled : Boolean = true;
    }

    part def MqttBrokerAdapter {
        port messageIn : MessageInputPort;
        port messageOut : MessageOutputPort;
        attribute brokerUri : String;
        attribute keepAliveInterval : Time = 60 [s];
        attribute maximumPacketSize : ISQ::information = 256 [kB];
    }

    part def HttpServiceAdapter {
        port messageIn : MessageInputPort;
        port messageOut : MessageOutputPort;
        attribute timeout : Time = 5 [s];
        attribute maximumPayloadSize : ISQ::information = 10 [MB];
        attribute tlsRequired : Boolean = true;
    }

    part def DatabaseAdapter {
        port messageIn : MessageInputPort;
        port auditOut : AuditPort;
        attribute writeTimeout : Time = 1 [s];
        attribute retentionPeriod : Time = 90 [d];
        attribute encryptedAtRest : Boolean = true;
    }

    part def NotificationService {
        port messageIn : MessageInputPort;
        port notificationOut : NotificationPort;
        attribute maximumNotificationsPerMinute : Frequency = 10 [Hz];
        attribute deliveryRetryCount : Integer = 3;
    }

    part def MonitoringService {
        port auditIn : AuditPort;
        port alertOut : NotificationPort;
        attribute healthCheckInterval : Time = 15 [s];
        attribute alertLatencyThreshold : Time = 5 [s];
        attribute retainedMetricsPeriod : Time = 30 [d];
    }

    part def NodeRedAutomationPlatform {
        attribute primaryFunction : String =
            "Provide a Node-RED-based low-code, event-driven automation platform that receives messages from devices and services, transforms and routes them through configurable flows, executes integrations, records audit events, and publishes commands or notifications.";

        part sensorGateway : SensorGateway;
        part apiGateway : ApiGateway;
        part editor : FlowEditor;
        part repository : FlowRepository;
        part runtime : NodeRedRuntime;
        part transformNode : FunctionNode;
        part routingNode : SwitchNode;
        part mqttAdapter : MqttBrokerAdapter;
        part httpAdapter : HttpServiceAdapter;
        part databaseAdapter : DatabaseAdapter;
        part notificationService : NotificationService;
        part monitoringService : MonitoringService;

        port telemetryIn : TelemetryPort;
        port commandOut : CommandPort;
        port externalNotificationOut : NotificationPort;
        port deploymentIn : DeploymentPort;

        connect telemetryIn to sensorGateway.telemetryOut;
        connect sensorGateway.telemetryOut to runtime.messageIn;
        connect apiGateway.messageIn to runtime.messageIn;
        connect deploymentIn to editor.deploymentOut;
        connect editor.deploymentOut to repository.deploymentIn;
        connect repository.deploymentOut to runtime.deploymentIn;

        connect runtime.messageOut to transformNode.messageIn;
        connect transformNode.messageOut to routingNode.messageIn;
        connect routingNode.messageOut to mqttAdapter.messageIn;
        connect routingNode.messageOut to httpAdapter.messageIn;
        connect routingNode.messageOut to databaseAdapter.messageIn;
        connect routingNode.messageOut to notificationService.messageIn;

        connect mqttAdapter.messageOut to runtime.messageIn;
        connect httpAdapter.messageOut to runtime.messageIn;
        connect notificationService.notificationOut to externalNotificationOut;
        connect apiGateway.commandOut to commandOut;

        connect runtime.auditOut to monitoringService.auditIn;
        connect editor.auditOut to monitoringService.auditIn;
        connect repository.auditOut to monitoringService.auditIn;
        connect databaseAdapter.auditOut to monitoringService.auditIn;
        connect monitoringService.alertOut to externalNotificationOut;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall provide a Node-RED-based low-code automation environment for event-driven integration of devices, APIs, databases, and notification services. */
        subject platform : NodeRedAutomationPlatform;
        require constraint {
            platform.primaryFunction != "";
        }
    }

    requirement def MessageProcessingLatencyRequirement {
        doc /* The system shall process accepted messages from ingress to routed egress within two seconds under nominal load. */
        subject runtime : NodeRedRuntime;
        require constraint {
            runtime.maximumEndToEndLatency <= 2 [s];
        }
    }

    requirement def DeploymentManagementRequirement {
        doc /* The system shall allow flow revisions to be deployed through a managed editor and repository before execution by the runtime. */
        subject platform : NodeRedAutomationPlatform;
        require constraint {
            platform.repository.retainedFlowRevisions >= 10;
        }
    }

    requirement def AuditabilityRequirement {
        doc /* The system shall emit audit records for deployment, message processing, persistence, and operational health events. */
        subject platform : NodeRedAutomationPlatform;
        require constraint {
            platform.monitoringService.retainedMetricsPeriod >= 30 [d];
        }
    }

    requirement def AvailabilityRequirement {
        doc /* The runtime shall maintain at least 99.9 percent availability for message orchestration services. */
        subject runtime : NodeRedRuntime;
        require constraint {
            runtime.minimumAvailability >= 0.999;
        }
    }

    requirement def SecurityRequirement {
        doc /* The system shall require encrypted external service communication and encrypted persistent storage for retained operational data. */
        subject platform : NodeRedAutomationPlatform;
        require constraint {
            platform.httpAdapter.tlsRequired == true and
            platform.databaseAdapter.encryptedAtRest == true;
        }
    }

    requirement def ScalabilityRequirement {
        doc /* The platform shall support at least five hundred connected telemetry sources and ten thousand concurrent in-flight messages. */
        subject platform : NodeRedAutomationPlatform;
        require constraint {
            platform.sensorGateway.maximumDevices >= 500 and
            platform.runtime.maximumConcurrentMessages >= 10000;
        }
    }

    part nodeRedBasedSystem : NodeRedAutomationPlatform;

    satisfy PrimaryFunctionRequirement by nodeRedBasedSystem;
    satisfy DeploymentManagementRequirement by nodeRedBasedSystem;
    satisfy AuditabilityRequirement by nodeRedBasedSystem;
    satisfy SecurityRequirement by nodeRedBasedSystem;
    satisfy ScalabilityRequirement by nodeRedBasedSystem;

}