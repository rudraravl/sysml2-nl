package 'NodeRED Event Processing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def NodeIdentifier :> String;
    attribute def TopicPath :> String;
    attribute def PayloadData :> String;
    attribute def FlowName :> String;
    
    item def EventMessage {
        attribute topic : TopicPath;
        attribute payload : PayloadData;
        attribute timestamp : TimeValue;
        attribute qos : Integer;
    }
    
    item def ProcessedData {
        attribute value : Real;
        attribute unit : String;
        attribute source : NodeIdentifier;
    }
    
    port def EventInputPort {
        in event : EventMessage;
    }
    
    port def EventOutputPort {
        out event : EventMessage;
    }
    
    port def DataInputPort {
        in data : ProcessedData;
    }
    
    port def DataOutputPort {
        out data : ProcessedData;
    }
    
    part def MQTTBroker {
        attribute brokerAddress : String;
        attribute port : Integer;
        port publishPort : EventOutputPort;
        port subscribePort : EventInputPort;
    }
    
    part def InputNode {
        attribute nodeId : NodeIdentifier;
        port eventOut : EventOutputPort;
    }
    
    part def FunctionNode {
        attribute nodeId : NodeIdentifier;
        attribute code : String;
        port eventIn : EventInputPort;
        port dataOut : DataOutputPort;
    }
    
    part def SwitchNode {
        attribute nodeId : NodeIdentifier;
        attribute rules : String[*];
        port dataIn : DataInputPort;
        port route1 : DataOutputPort;
        port route2 : DataOutputPort;
    }
    
    part def DebugNode {
        attribute nodeId : NodeIdentifier;
        attribute outputTarget : String;
        port dataIn : DataInputPort;
    }
    
    part def DashboardNode {
        attribute nodeId : NodeIdentifier;
        attribute widgetType : String;
        port dataIn : DataInputPort;
    }
    
    action def ReceiveEvent {
        in msg : EventMessage;
        out receivedEvent : EventMessage;
    }
    
    action def ParsePayload {
        in rawPayload : PayloadData;
        out parsedData : ProcessedData;
    }
    
    action def EvaluateCondition {
        in inputData : ProcessedData;
        in threshold : Real;
        out conditionMet : Boolean;
    }
    
    action def TransformData {
        in originalData : ProcessedData;
        out transformedData : ProcessedData;
    }
    
    action def RouteData {
        in data : ProcessedData;
        in condition : Boolean;
        out primaryRoute : ProcessedData[0..1];
        out secondaryRoute : ProcessedData[0..1];
    }
    
    action def DisplayData {
        in data : ProcessedData;
    }
    
    action def LogDebug {
        in data : ProcessedData;
    }
    
    action def ExecuteEventFlow {
        in threshold : Real;
        out debugOutput : ProcessedData[*];
        out dashboardOutput : ProcessedData[*];
        
        first start;
        then merge continueProcessing;
        
        then action receiveMsg : ReceiveEvent {
            in msg : EventMessage;
            out receivedEvent : EventMessage;
        }
        
        then action parseData : ParsePayload {
            in rawPayload = receiveMsg.receivedEvent.payload;
            out parsedData : ProcessedData;
        }
        
        then action transformInput : TransformData {
            in originalData = parseData.parsedData;
            out transformedData : ProcessedData;
        }
        
        then action evaluateRule : EvaluateCondition {
            in inputData = transformInput.transformedData;
            in threshold = threshold;
            out conditionMet : Boolean;
        }
        
        then decide;
            if evaluateRule.conditionMet then routeToAlerts;
            if !evaluateRule.conditionMet then routeToMonitoring;
        
        action routeToAlerts : RouteData {
            in data = transformInput.transformedData;
            in condition = evaluateRule.conditionMet;
            out primaryRoute : ProcessedData[0..1];
            out secondaryRoute : ProcessedData[0..1];
        }
        then action logAlert : LogDebug {
            in data = routeToAlerts.primaryRoute;
        }
        then action displayAlert : DisplayData {
            in data = routeToAlerts.primaryRoute;
        }
        then continueProcessing;
        
        action routeToMonitoring : RouteData {
            in data = transformInput.transformedData;
            in condition = evaluateRule.conditionMet;
            out primaryRoute : ProcessedData[0..1];
            out secondaryRoute : ProcessedData[0..1];
        }
        then action displayNormal : DisplayData {
            in data = routeToMonitoring.secondaryRoute;
        }
        then continueProcessing;
    }
    
    state def FlowExecutionState {
        entry; then idle;
        
        state idle;
        transition idleToProcessing
            first idle
            accept eventReceived
            then processing;
        
        state processing {
            entry; then parsing;
            
            state parsing;
            transition parsingToTransforming
                first parsing
                accept parseComplete
                then transforming;
            
            state transforming;
            transition transformingToEvaluating
                first transforming
                accept transformComplete
                then evaluating;
            
            state evaluating;
            transition evaluatingToRouting
                first evaluating
                accept evaluationComplete
                if highPriority
                then routing;
            transition evaluatingToMonitoring
                first evaluating
                accept evaluationComplete
                if normalPriority
                then monitoring;
            
            state routing;
            transition routingToOutputting
                first routing
                accept routeComplete
                then outputting;
            
            state monitoring;
            transition monitoringToOutputting
                first monitoring
                accept monitorComplete
                then outputting;
            
            state outputting;
            transition outputtingToIdle
                first outputting
                accept outputComplete
                then idle;
        }
    }
    
    requirement def <'REQ-NR-001'> EventProcessingRequirement {
        doc /* The Node-RED system shall receive events from MQTT broker, 
                process them through configurable flows, and route outputs 
                based on evaluation rules. */
        
        subject system : NodeREDEventSystem;
        
        require constraint {
            system.flows->size() >= 1 and
            system.broker != null
        }
    }
    
    requirement def <'REQ-NR-002'> DataTransformationRequirement {
        doc /* The system shall transform incoming event payloads into 
                structured data for downstream processing. */
        
        subject functionNode : FunctionNode;
        
        require constraint {
            functionNode.code != null
        }
    }
    
    requirement def <'REQ-NR-003'> ConditionalRoutingRequirement {
        doc /* The system shall route data to different outputs based on 
                configurable threshold conditions. */
        
        subject switchNode : SwitchNode;
        
        require constraint {
            switchNode.rules->size() >= 1
        }
    }
    
    requirement def <'REQ-NR-004'> VisualizationRequirement {
        doc /* The system shall provide real-time visualization of 
                processed data through dashboard widgets. */
        
        subject dashboard : DashboardNode;
        
        require constraint {
            dashboard.widgetType != null
        }
    }
    
    part def NodeREDEventSystem {
        part broker : MQTTBroker;
        part flows : EventProcessingFlow[1..*];
    }
    
    part def EventProcessingFlow {
        attribute flowName : FlowName;
        part mqttInput : InputNode;
        part parser : FunctionNode;
        part transformer : FunctionNode;
        part conditionSwitch : SwitchNode;
        part alertDebug : DebugNode;
        part alertDashboard : DashboardNode;
        part normalDashboard : DashboardNode;
    }
    
    part nodeREDEventSystem : NodeREDEventSystem {
        doc /* 
            Node-RED is a flow-based development tool for visual programming 
            and event-driven applications. Its primary function is to wire 
            together hardware devices, APIs, and online services in new and 
            interesting ways. The system receives events from message brokers, 
            processes them through user-defined flows consisting of interconnected 
            nodes, applies transformation and routing logic, and delivers outputs 
            to various endpoints including dashboards, databases, and external 
            services. This enables rapid prototyping and deployment of IoT 
            applications, data pipelines, and automation workflows through an 
            intuitive browser-based interface.
        */
        
        part broker : MQTTBroker {
            attribute brokerAddress = "mqtt.example.com";
            attribute port = 1883;
        }
        
        part flows : EventProcessingFlow[1..*] {
            attribute flowName : FlowName;
            
            part mqttInput : InputNode {
                attribute nodeId = "mqtt-in-1";
                
                perform action receiveEvents : ReceiveEvent;
            }
            
            part parser : FunctionNode {
                attribute nodeId = "function-1";
                attribute code = "msg.payload = JSON.parse(msg.payload); return msg;";
                
                perform action parseEvents : ParsePayload;
            }
            
            part transformer : FunctionNode {
                attribute nodeId = "function-2";
                attribute code = "msg.payload.value = msg.payload.value * 1.8 + 32; return msg;";
                
                perform action transformEvents : TransformData;
            }
            
            part conditionSwitch : SwitchNode {
                attribute nodeId = "switch-1";
                attribute rules = (">=", "75.0");
                
                perform action evaluateEvents : EvaluateCondition {
                    in threshold = 75.0;
                }
            }
            
            part alertDebug : DebugNode {
                attribute nodeId = "debug-1";
                attribute outputTarget = "console";
                
                perform action logAlerts : LogDebug;
            }
            
            part alertDashboard : DashboardNode {
                attribute nodeId = "dashboard-1";
                attribute widgetType = "gauge";
                
                perform action displayAlerts : DisplayData;
            }
            
            part normalDashboard : DashboardNode {
                attribute nodeId = "dashboard-2";
                attribute widgetType = "chart";
                
                perform action displayNormal : DisplayData;
            }
            
            connection eventFlow1 connect 
                mqttInput.eventOut to parser.eventIn;
            
            connection dataFlow1 connect 
                parser.dataOut to transformer.dataIn;
            
            connection dataFlow2 connect 
                transformer.dataOut to conditionSwitch.dataIn;
            
            connection alertRoute connect 
                conditionSwitch.route1 to alertDebug.dataIn;
            
            connection dashboardRoute1 connect 
                conditionSwitch.route1 to alertDashboard.dataIn;
            
            connection dashboardRoute2 connect 
                conditionSwitch.route2 to normalDashboard.dataIn;
        }
        
        connection brokerConnection connect 
            broker.publishPort to flows.mqttInput.eventOut;
        
        perform action executeFlows : ExecuteEventFlow {
            in threshold = 75.0;
            out debugOutput : ProcessedData[*];
            out dashboardOutput : ProcessedData[*];
        }
        
        exhibit state flowState : FlowExecutionState;
        
        satisfy <'REQ-NR-001'> by nodeREDEventSystem;
        satisfy <'REQ-NR-002'> by flows.parser, flows.transformer;
        satisfy <'REQ-NR-003'> by flows.conditionSwitch;
        satisfy <'REQ-NR-004'> by flows.alertDashboard, flows.normalDashboard;
    }
}
