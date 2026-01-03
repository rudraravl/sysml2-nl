package ResponsiveArchitectureSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def LoadPercentage :> Real;
    attribute def ResponseTimeValue :> TimeValue;
    attribute def ThroughputValue :> Real;
    attribute def LatencyValue :> TimeValue;

    enum def RequestPriority {
        low;
        medium;
        high;
        critical;
    }

    enum def SystemState {
        initializing;
        operational;
        degraded;
        recovering;
        failed;
    }

    item def ServiceRequest {
        attribute priority : RequestPriority;
        attribute timestamp : ResponseTimeValue;
        attribute requestId : String;
        attribute payloadSize : Real;
    }

    item def ServiceResponse {
        attribute requestId : String;
        attribute processingTime : ResponseTimeValue;
        attribute success : Boolean;
        attribute resultData : Real;
    }

    item def MetricsData {
        attribute currentLoad : LoadPercentage;
        attribute averageResponseTime : ResponseTimeValue;
        attribute throughput : ThroughputValue;
        attribute activeConnections : Integer;
    }

    item def ScalingCommand {
        attribute targetNodeCount : Integer;
        attribute scaleDirection : Integer;
        attribute reason : String;
    }

    port def ServicePort {
        in item request : ServiceRequest;
        out item response : ServiceResponse;
    }

    port def MetricsPort {
        out item metrics : MetricsData;
    }

    port def ControlPort {
        in item command : ScalingCommand;
    }

    part def LoadBalancer {
        doc /* Distributes incoming requests across available processing nodes
             * using adaptive routing algorithms to optimize resource utilization. */

        port externalPort : ServicePort;
        port nodePort : ServicePort[1..*];
        port metricsPort : MetricsPort;

        attribute currentLoad : LoadPercentage;
        attribute routingAlgorithm : String;
        attribute requestCount : Integer;

        action routeRequest {
            in req : ServiceRequest;
            out targetNode : Integer;

            first start;
            then action checkPriority {
                in incomingRequest = req;
                out priorityLevel : RequestPriority;
            }
            then decide;
                if checkPriority.priorityLevel == RequestPriority::critical then routeToPrimaryNode;
                if checkPriority.priorityLevel == RequestPriority::high then routeToOptimalNode;
                else routeByRoundRobin;
            action routeToPrimaryNode {
                out selectedNode = 0;
            }
            then done;
            action routeToOptimalNode {
                out selectedNode : Integer;
            }
            then done;
            action routeByRoundRobin {
                out selectedNode : Integer;
            }
            then done;
        }

        state balancerStateMachine {
            entry; then idle;

            state idle;
            
            transition idle_to_active
                first idle
                accept externalPort.request
                then active;

            state active {
                do action routeRequest;
            }
            
            transition active_to_idle
                first active
                if requestCount == 0
                then idle;

            state overloaded;
            
            transition active_to_overloaded
                first active
                if currentLoad > 90.0
                then overloaded;

            transition overloaded_to_active
                first overloaded
                if currentLoad < 70.0
                then active;
        }
    }

    part def ProcessingNode {
        doc /* Executes service requests with configurable capacity and
             * monitors its own performance metrics for adaptive scaling. */

        port servicePort : ServicePort;
        port metricsPort : MetricsPort;

        attribute nodeId : Integer;
        attribute capacity : LoadPercentage;
        attribute currentLoad : LoadPercentage;
        attribute processingRate : ThroughputValue;
        attribute averageLatency : LatencyValue;

        action processRequest {
            in req : ServiceRequest;
            out resp : ServiceResponse;

            first start;
            then action validateRequest {
                in request = req;
                out isValid : Boolean;
            }
            then decide;
                if validateRequest.isValid then executeService;
                else rejectRequest;
            action executeService {
                in validRequest = req;
                out result : ServiceResponse {
                    requestId = validRequest.requestId;
                    success = true;
                }
            }
            then done;
            action rejectRequest {
                out errorResponse : ServiceResponse {
                    success = false;
                }
            }
            then done;
        }

        state nodeStateMachine {
            entry; then ready;

            state ready;
            
            transition ready_to_processing
                first ready
                accept servicePort.request
                then processing;

            state processing {
                do action processRequest;
            }
            
            transition processing_to_ready
                first processing
                if currentLoad < capacity
                then ready;

            transition processing_to_saturated
                first processing
                if currentLoad >= capacity
                then saturated;

            state saturated;
            
            transition saturated_to_processing
                first saturated
                if currentLoad < capacity * 0.8
                then processing;
        }
    }

    part def AutoScalingController {
        doc /* Monitors system metrics and dynamically adjusts the number of
             * processing nodes to maintain optimal performance and efficiency. */

        port metricsInput : MetricsPort[1..*];
        port controlOutput : ControlPort;

        attribute scaleUpThreshold : LoadPercentage;
        attribute scaleDownThreshold : LoadPercentage;
        attribute currentNodeCount : Integer;
        attribute minNodes : Integer;
        attribute maxNodes : Integer;
        attribute cooldownPeriod : ResponseTimeValue;

        action evaluateScaling {
            in avgLoad : LoadPercentage;
            in avgResponseTime : ResponseTimeValue;
            out scaleDecision : ScalingCommand;

            first start;
            then action analyzeMetrics {
                in systemLoad = avgLoad;
                in responseTime = avgResponseTime;
                out needsScaling : Boolean;
                out direction : Integer;
            }
            then decide;
                if analyzeMetrics.direction > 0 then scaleUp;
                if analyzeMetrics.direction < 0 then scaleDown;
                else maintain;
            action scaleUp {
                out command : ScalingCommand {
                    scaleDirection = 1;
                    targetNodeCount = currentNodeCount + 1;
                    reason = "High load detected";
                }
            }
            then done;
            action scaleDown {
                out command : ScalingCommand {
                    scaleDirection = -1;
                    targetNodeCount = currentNodeCount - 1;
                    reason = "Low load detected";
                }
            }
            then done;
            action maintain {
                out command : ScalingCommand {
                    scaleDirection = 0;
                    targetNodeCount = currentNodeCount;
                    reason = "Optimal load";
                }
            }
            then done;
        }

        state scalingStateMachine {
            entry; then monitoring;

            state monitoring {
                do action evaluateScaling;
            }
            
            transition monitoring_to_scalingUp
                first monitoring
                if currentNodeCount < maxNodes
                then scalingUp;

            state scalingUp;
            
            transition scalingUp_to_cooldown
                first scalingUp
                then cooldown;

            state scalingDown;
            
            transition monitoring_to_scalingDown
                first monitoring
                if currentNodeCount > minNodes
                then scalingDown;

            transition scalingDown_to_cooldown
                first scalingDown
                then cooldown;

            state cooldown;
            
            transition cooldown_to_monitoring
                first cooldown
                after cooldownPeriod
                then monitoring;
        }
    }

    part def HealthMonitor {
        doc /* Continuously monitors system health and triggers recovery
             * actions when failures or degraded performance are detected. */

        port metricsInput : MetricsPort[1..*];

        attribute healthCheckInterval : ResponseTimeValue;
        attribute failureThreshold : Integer;
        attribute consecutiveFailures : Integer;

        action monitorHealth {
            first start;
            then merge continuousMonitoring;
            then action collectMetrics {
                out allMetrics : MetricsData[*];
            }
            then action analyzeHealth {
                in systemMetrics = collectMetrics.allMetrics;
                out isHealthy : Boolean;
                out degradationLevel : Real;
            }
            then decide;
                if analyzeHealth.isHealthy then continuousMonitoring;
                else triggerAlert;
            action triggerAlert {
                out alertMessage : String;
            }
            then continuousMonitoring;
        }
    }

    part def CacheLayer {
        doc /* Provides fast data access through intelligent caching
             * to reduce latency and improve overall system responsiveness. */

        port cachePort : ServicePort;

        attribute cacheSize : Real;
        attribute hitRate : Real;
        attribute evictionPolicy : String;

        action cacheOperation {
            in req : ServiceRequest;
            out resp : ServiceResponse;

            first start;
            then action checkCache {
                in request = req;
                out cacheHit : Boolean;
            }
            then decide;
                if checkCache.cacheHit then returnCached;
                else fetchAndCache;
            action returnCached {
                out cachedResponse : ServiceResponse;
            }
            then done;
            action fetchAndCache {
                out freshResponse : ServiceResponse;
            }
            then done;
        }
    }

    part def ResponsiveArchitecture {
        doc /* A responsive architecture system that dynamically adapts to varying
             * workloads through intelligent load balancing, auto-scaling, health
             * monitoring, and caching to maintain optimal performance and availability. */

        attribute maxResponseTime : ResponseTimeValue;
        attribute targetThroughput : ThroughputValue;
        attribute availabilityTarget : Real;
        attribute systemState : SystemState;

        part loadBalancer : LoadBalancer {
            attribute :>> routingAlgorithm = "weighted-round-robin";
            attribute :>> currentLoad = 0.0;
        }

        part processingNodes : ProcessingNode[2..20] {
            attribute :>> capacity = 100.0;
            attribute :>> processingRate = 100.0;
            attribute :>> averageLatency = 50.0[ms];
        }

        part autoScaler : AutoScalingController {
            attribute :>> scaleUpThreshold = 75.0;
            attribute :>> scaleDownThreshold = 25.0;
            attribute :>> minNodes = 2;
            attribute :>> maxNodes = 20;
            attribute :>> currentNodeCount = 2;
            attribute :>> cooldownPeriod = 60.0[s];
        }

        part healthMonitor : HealthMonitor {
            attribute :>> healthCheckInterval = 10.0[s];
            attribute :>> failureThreshold = 3;
            attribute :>> consecutiveFailures = 0;
        }

        part cache : CacheLayer {
            attribute :>> cacheSize = 1000.0;
            attribute :>> hitRate = 0.85;
            attribute :>> evictionPolicy = "LRU";
        }

        connection requestDistribution connect
            loadBalancer.nodePort to processingNodes.servicePort;

        connection metricsCollection connect
            processingNodes.metricsPort to autoScaler.metricsInput;

        connection healthMonitoring connect
            processingNodes.metricsPort to healthMonitor.metricsInput;

        connection cacheIntegration connect
            cache.cachePort to loadBalancer.externalPort;
    }

    requirement <'REQ-1000'> responsiveArchitectureRequirement {
        doc /* The system shall implement a responsive architecture that
             * dynamically adapts to varying workloads while maintaining
             * performance, availability, and efficiency targets through
             * intelligent load distribution, automatic scaling, health
             * monitoring, and caching mechanisms. */

        subject system : ResponsiveArchitecture;

        require <'REQ-1001'> performanceRequirement {
            doc /* The system shall maintain response times below the
                 * specified maximum under normal and peak load conditions. */
            subject system : ResponsiveArchitecture;
            assert constraint {
                system.maxResponseTime <= 200.0[ms]
            }
        }

        require <'REQ-1002'> scalabilityRequirement {
            doc /* The system shall automatically scale processing capacity
                 * between minimum and maximum node counts based on current
                 * load to maintain optimal performance. */
            subject scaler : ResponsiveArchitecture::autoScaler;
            assert constraint {
                scaler.currentNodeCount >= scaler.minNodes and
                scaler.currentNodeCount <= scaler.maxNodes
            }
        }

        require <'REQ-1003'> availabilityRequirement {
            doc /* The system shall maintain high availability through
                 * continuous health monitoring and automatic recovery. */
            subject system : ResponsiveArchitecture;
            assert constraint {
                system.availabilityTarget >= 0.99
            }
        }

        require <'REQ-1004'> loadBalancingRequirement {
            doc /* The system shall distribute incoming requests across
                 * available processing nodes using adaptive algorithms
                 * to optimize resource utilization. */
            subject balancer : ResponsiveArchitecture::loadBalancer;
        }

        require <'REQ-1005'> cachingRequirement {
            doc /* The system shall utilize intelligent caching to reduce
                 * latency and improve responsiveness for frequently
                 * accessed data. */
            subject cache : ResponsiveArchitecture::cache;
            assert constraint {
                cache.hitRate >= 0.80
            }
        }
    }

    part responsiveSystemInstance : ResponsiveArchitecture {
        attribute :>> maxResponseTime = 200.0[ms];
        attribute :>> targetThroughput = 5000.0;
        attribute :>> availabilityTarget = 0.995;
        attribute :>> systemState = SystemState::operational;
    }

    satisfy responsiveArchitectureRequirement by responsiveSystemInstance;
}
