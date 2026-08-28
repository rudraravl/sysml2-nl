package BackendSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    
    value type Latency :> Real {
        :>> unit = "ms";
    }
    
    value type Throughput :> Real {
        :>> unit = "req/s";
    }
    
    value type CpuLoad :> Real {
        :>> unit = "percent";
        :>> min = 0;
        :>> max = 100;
    }
    
    value type MemoryUsage :> Real {
        :>> unit = "percent";
        :>> min = 0;
        :>> max = 100;
    }
    
    value type ResponseTime :> Real {
        :>> unit = "ms";
    }
    
    value type CooldownDuration :> Real {
        :>> unit = "s";
    }
    
    value type NodeCount :> Integer {
        :>> min = 0;
        :>> max = 100;
    }
    
    value type Priority :> Integer {
        :>> min = 0;
        :>> max = 10;
    }
    
    value type RequestId :> String;
    value type NodeId :> String;
    
    // ===== Enumerations =====
    
    enum def RequestPriority {
        LOW = 1;
        NORMAL = 5;
        HIGH = 10;
    }
    
    enum def NodeStatus {
        IDLE;
        ACTIVE;
        DEGRADED;
        FAILED;
        TERMINATING;
    }
    
    enum def ScalingAction {
        SCALE_UP;
        SCALE_DOWN;
        HOLD;
    }
    
    enum def AlertLevel {
        INFO;
        WARNING;
        CRITICAL;
    }
    
    enum def CacheResult {
        HIT;
        MISS;
    }
    
    // ===== Item Definitions =====
    
    item def ServiceRequest {
        attribute requestId : RequestId;
        attribute priority : RequestPriority = RequestPriority::NORMAL;
        attribute payload : String;
        attribute timestamp : Time;
    }
    
    item def ServiceResponse {
        attribute requestId : RequestId;
        attribute data : String;
        attribute responseTime : ResponseTime;
        attribute success : Boolean;
    }
    
    item def NodeMetrics {
        attribute nodeId : NodeId;
        attribute cpuLoad : CpuLoad;
        attribute memoryUsage : MemoryUsage;
        attribute throughput : Throughput;
        attribute avgResponseTime : ResponseTime;
        attribute status : NodeStatus;
    }
    
    item def SystemMetrics {
        attribute totalRequests : Integer;
        attribute avgResponseTime : ResponseTime;
        attribute activeNodeCount : NodeCount;
        attribute totalThroughput : Throughput;
        attribute cacheHitRate : Real;
    }
    
    item def Alert {
        attribute alertId : String;
        attribute level : AlertLevel;
        attribute nodeId : NodeId;
        attribute message : String;
        attribute timestamp : Time;
    }
    
    item def ScalingCommand {
        attribute action : ScalingAction;
        attribute targetNodeCount : NodeCount;
        attribute reason : String;
    }
    
    // ===== Port Definitions =====
    
    port def RequestPort {
        in item requests : ServiceRequest;
        out item responses : ServiceResponse;
    }
    
    port def ForwardedRequestPort {
        out item forwardedRequests : ServiceRequest;
        in item responses : ServiceResponse;
    }
    
    port def NodeRequestPort {
        in item requests : ServiceRequest;
        out item responses : ServiceResponse;
    }
    
    port def MetricsPort {
        out item metrics : NodeMetrics;
    }
    
    port def SystemMetricsPort {
        in item nodeMetrics : NodeMetrics;
        out item systemMetrics : SystemMetrics;
    }
    
    port def ScalingCommandPort {
        out item commands : ScalingCommand;
    }
    
    port def AlertPort {
        out item alerts : Alert;
    }
    
    port def CacheQueryPort {
        in item requests : ServiceRequest;
        out item cacheResults : ServiceResponse;
        out item misses : ServiceRequest;
    }
    
    // ===== Cache Layer =====
    
    part def CacheLayer {
        attribute maxCacheSize : Integer = 10000;
        attribute currentCacheEntries : Integer = 0;
        attribute hitCount : Integer = 0;
        attribute missCount : Integer = 0;
        
        port cacheIn : RequestPort;
        port cacheQuery : CacheQueryPort;
        
        state machine CacheBehavior {
            entry; then Ready;
            
            state Ready;
            
            transition t1 first Ready then Ready
                when cacheIn.requests is pushed
                do {
                    if (self.isCached(cacheIn.requests)) {
                        self.hitCount = self.hitCount + 1;
                        cacheQuery.cacheResults = self.retrieveFromCache(cacheIn.requests);
                    } else {
                        self.missCount = self.missCount + 1;
                        cacheQuery.misses = cacheIn.requests;
                    }
                }
            ;
        }
        
        private action isCached(req : ServiceRequest) : Boolean {
            // Returns true if request data is in cache
        }
        
        private action retrieveFromCache(req : ServiceRequest) : ServiceResponse {
            // Retrieves cached response
        }
        
        private action evictIfNeeded() {
            // LRU eviction when cache is full
        }
    }
    
    // ===== Load Balancer =====
    
    part def LoadBalancer {
        attribute routingAlgorithm : String = "adaptive-weighted";
        attribute nodeWeights : NodeId[0..20];
        attribute highPriorityThreshold : Priority = 8;
        
        port lbIn : ForwardedRequestPort;
        port nodeOut : NodeRequestPort[2..20];
        
        state machine LoadBalancerBehavior {
            entry; then Idle;
            
            state Idle;
            state Distributing;
            
            transition t1 first Idle then Distributing
                when lbIn.forwardedRequests is pushed
                do {
                    self.routeRequest(lbIn.forwardedRequests);
                }
            ;
            
            transition t2 first Distributing then Idle
                when nodeOut.responses is pushed
                do {
                    lbIn.responses = nodeOut.responses;
                }
            ;
        }
        
        private action routeRequest(req : ServiceRequest) {
            if (req.priority >= highPriorityThreshold) {
                self.routeToOptimalNode(req);
            } else {
                self.routeRoundRobin(req);
            }
        }
        
        private action routeToOptimalNode(req : ServiceRequest) {
            // Routes high-priority requests to the least loaded, highest-performance node
        }
        
        private action routeRoundRobin(req : ServiceRequest) {
            // Distributes normal traffic evenly across available nodes
        }
        
        private action updateNodeWeights(metrics : NodeMetrics) {
            // Adjusts routing weights based on node performance
        }
    }
    
    // ===== Processing Node =====
    
    part def ProcessingNode {
        attribute nodeId : NodeId;
        attribute status : NodeStatus = NodeStatus::IDLE;
        attribute cpuLoad : CpuLoad = 0;
        attribute memoryUsage : MemoryUsage = 0;
        attribute throughput : Throughput = 0;
        attribute avgResponseTime : ResponseTime = 0;
        attribute maxConcurrentRequests : Integer = 1000;
        attribute currentRequests : Integer = 0;
        
        port nodeIn : NodeRequestPort;
        port metricsOut : MetricsPort;
        
        state machine ProcessingNodeBehavior {
            entry; then Idle;
            
            state Idle;
            state Processing;
            state Degraded;
            state Terminating;
            
            transition t1 first Idle then Processing
                when nodeIn.requests is pushed
                do {
                    self.status = NodeStatus::ACTIVE;
                    self.processRequest(nodeIn.requests);
                }
            ;
            
            transition t2 first Processing then Processing
                when nodeIn.requests is pushed
                guard currentRequests < maxConcurrentRequests
                do {
                    self.processRequest(nodeIn.requests);
                }
            ;
            
            transition t3 first Processing then Degraded
                when cpuLoad > 90 or avgResponseTime > 500
                do {
                    self.status = NodeStatus::DEGRADED;
                    self.emitMetrics();
                }
            ;
            
            transition t4 first Degraded then Processing
                when cpuLoad < 70 and avgResponseTime < 300
                do {
                    self.status = NodeStatus::ACTIVE;
                }
            ;
            
            transition t5 first Processing then Idle
                when currentRequests == 0
                do {
                    self.status = NodeStatus::IDLE;
                    self.emitMetrics();
                }
            ;
            
            transition t6 first Idle then Terminating
                when status == NodeStatus::TERMINATING
                do {
                    self.cleanup();
                }
            ;
        }
        
        private action processRequest(req : ServiceRequest) {
            self.currentRequests = self.currentRequests + 1;
            // Execute business logic
            self.updateMetrics();
            self.currentRequests = self.currentRequests - 1;
        }
        
        private action updateMetrics() {
            self.cpuLoad = self.measureCpuLoad();
            self.memoryUsage = self.measureMemoryUsage();
            self.throughput = self.measureThroughput();
            self.avgResponseTime = self.measureResponseTime();
            self.emitMetrics();
        }
        
        private action emitMetrics() {
            metricsOut.metrics = NodeMetrics {
                nodeId = self.nodeId,
                cpuLoad = self.cpuLoad,
                memoryUsage = self.memoryUsage,
                throughput = self.throughput,
                avgResponseTime = self.avgResponseTime,
                status = self.status
            };
        }
        
        private action measureCpuLoad() : CpuLoad { }
        private action measureMemoryUsage() : MemoryUsage { }
        private action measureThroughput() : Throughput { }
        private action measureResponseTime() : ResponseTime { }
        
        private action cleanup() {
            self.status = NodeStatus::TERMINATING;
            // Graceful shutdown: finish pending requests, release resources
        }
    }
    
    // ===== Auto-Scaling Controller =====
    
    part def AutoScalingController {
        attribute minNodes : NodeCount = 2;
        attribute maxNodes : NodeCount = 20;
        attribute currentNodeCount : NodeCount = 2;
        attribute scaleUpThreshold : ResponseTime = 200;
        attribute scaleDownThreshold : ResponseTime = 50;
        attribute scaleUpStep : NodeCount = 2;
        attribute scaleDownStep : NodeCount = 1;
        attribute cooldownPeriod : CooldownDuration = 60;
        attribute lastScalingTime : Time;
        attribute isInCooldown : Boolean = false;
        
        port metricsIn : SystemMetricsPort;
        port scalingOut : ScalingCommandPort;
        
        state machine AutoScalingBehavior {
            entry; then Monitoring;
            
            state Monitoring;
            state Evaluating;
            state Cooldown;
            state ScalingUp;
            state ScalingDown;
            
            transition t1 first Monitoring then Evaluating
                when metricsIn.systemMetrics is pushed
                do {
                    self.evaluateScaling(metricsIn.systemMetrics);
                }
            ;
            
            transition t2 first Evaluating then ScalingUp
                when self.shouldScaleUp(metricsIn.systemMetrics) and not self.isInCooldown
                do {
                    self.executeScaleUp();
                }
            ;
            
            transition t3 first Evaluating then ScalingDown
                when self.shouldScaleDown(metricsIn.systemMetrics) and not self.isInCooldown
                do {
                    self.executeScaleDown();
                }
            ;
            
            transition t4 first Evaluating then Monitoring
                when not self.shouldScaleUp(metricsIn.systemMetrics) and not self.shouldScaleDown(metricsIn.systemMetrics)
                do { /* Hold */ }
            ;
            
            transition t5 first Evaluating then Cooldown
                when self.isInCooldown
                do { /* Wait for cooldown to expire */ }
            ;
            
            transition t6 first ScalingUp then Cooldown
                do {
                    self.lastScalingTime = now;
                    self.isInCooldown = true;
                }
            ;
            
            transition t7 first ScalingDown then Cooldown
                do {
                    self.lastScalingTime = now;
                    self.isInCooldown = true;
                }
            ;
            
            transition t8 first Cooldown then Monitoring
                when (now - self.lastScalingTime) >= self.cooldownPeriod
                do {
                    self.isInCooldown = false;
                }
            ;
        }
        
        private action evaluateScaling(metrics : SystemMetrics) {
            // Analyzes system metrics to determine if scaling is needed
        }
        
        private action shouldScaleUp(metrics : SystemMetrics) : Boolean {
            return metrics.avgResponseTime > self.scaleUpThreshold and self.currentNodeCount < self.maxNodes;
        }
        
        private action shouldScaleDown(metrics : SystemMetrics) : Boolean {
            return metrics.avgResponseTime < self.scaleDownThreshold and self.currentNodeCount > self.minNodes;
        }
        
        private action executeScaleUp() {
            self.currentNodeCount = min(self.currentNodeCount + self.scaleUpStep, self.maxNodes);
            scalingOut.commands = ScalingCommand {
                action = ScalingAction::SCALE_UP,
                targetNodeCount = self.currentNodeCount,
                reason = "Response time exceeded scale-up threshold"
            };
        }
        
        private action executeScaleDown() {
            self.currentNodeCount = max(self.currentNodeCount - self.scaleDownStep, self.minNodes);
            scalingOut.commands = ScalingCommand {
                action = ScalingAction::SCALE_DOWN,
                targetNodeCount = self.currentNodeCount,
                reason = "Response time below scale-down threshold, idle nodes detected"
            };
        }
    }
    
    // ===== Health Monitor =====
    
    part def HealthMonitor {
        attribute monitoringInterval : Time = 5;
        attribute cpuLoadThreshold : CpuLoad = 95;
        attribute responseTimeThreshold : ResponseTime = 1000;
        attribute failedNodes : NodeId[0..20];
        attribute degradedNodes : NodeId[0..20];
        attribute systemHealthScore : Real = 100;
        
        port healthMetricsIn : SystemMetricsPort;
        port alertOut : AlertPort;
        
        state machine HealthMonitorBehavior {
            entry; then Collecting;
            
            state Collecting;
            state Analyzing;
            state Alerting;
            
            transition t1 first Collecting then Analyzing
                when healthMetricsIn.nodeMetrics is pushed
                do {
                    self.analyzeNodeHealth(healthMetricsIn.nodeMetrics);
                }
            ;
            
            transition t2 first Analyzing then Collecting
                when not self.hasIssues()
                do { /* Continue monitoring */ }
            ;
            
            transition t3 first Analyzing then Alerting
                when self.hasIssues()
                do {
                    self.raiseAlert();
                }
            ;
            
            transition t4 first Alerting then Collecting
                do { /* Return to monitoring after alert dispatched */ }
            ;
        }
        
        private action analyzeNodeHealth(metrics : NodeMetrics) {
            if (metrics.status == NodeStatus::FAILED) {
                self.failedNodes = self.failedNodes.append(metrics.nodeId);
            }
            if (metrics.status == NodeStatus::DEGRADED or metrics.cpuLoad > self.cpuLoadThreshold or metrics.avgResponseTime > self.responseTimeThreshold) {
                self.degradedNodes = self.degradedNodes.append(metrics.nodeId);
            }
            self.updateSystemHealthScore();
        }
        
        private action hasIssues() : Boolean {
            return self.failedNodes.size > 0 or self.degradedNodes.size > 0;
        }
        
        private action raiseAlert() {
            if (self.failedNodes.size > 0) {
                alertOut.alerts = Alert {
                    alertId = "ALT-" + self.generateAlertId(),
                    level = AlertLevel::CRITICAL,
                    nodeId = self.failedNodes.first(),
                    message = "Node failure detected",
                    timestamp = now
                };
            }
            if (self.degradedNodes.size > 0) {
                alertOut.alerts = Alert {
                    alertId = "ALT-" + self.generateAlertId(),
                    level = AlertLevel::WARNING,
                    nodeId = self.degradedNodes.first(),
                    message = "Node performance degraded",
                    timestamp = now
                };
            }
        }
        
        private action updateSystemHealthScore() {
            // Computes overall system health based on node statuses
        }
        
        private action generateAlertId() : String { }
    }
    
    // ===== Node Pool Manager =====
    
    part def NodePoolManager {
        attribute activeNodes : ProcessingNode[0..20];
        attribute targetNodeCount : NodeCount = 2;
        
        port scalingCommandIn : ScalingCommandPort;
        port nodeMetricsOut : SystemMetricsPort;
        
        state machine NodePoolBehavior {
            entry; then Stable;
            
            state Stable;
            state AddingNodes;
            state RemovingNodes;
            
            transition t1 first Stable then AddingNodes
                when scalingCommandIn.commands is pushed
                guard scalingCommandIn.commands.action == ScalingAction::SCALE_UP
                do {
                    self.addNode(scalingCommandIn.commands.targetNodeCount);
                }
            ;
            
            transition t2 first Stable then RemovingNodes
                when scalingCommandIn.commands is pushed
                guard scalingCommandIn.commands.action == ScalingAction::SCALE_DOWN
                do {
                    self.removeNode(scalingCommandIn.commands.targetNodeCount);
                }
            ;
            
            transition t3 first AddingNodes then Stable
                when self.activeNodes.size == self.targetNodeCount
                do { /* Node pool updated */ }
            ;
            
            transition t4 first RemovingNodes then Stable
                when self.activeNodes.size == self.targetNodeCount
                do { /* Node pool updated */ }
            ;
        }
        
        private action addNode(target : NodeCount) {
            self.targetNodeCount = target;
            while (self.activeNodes.size < target) {
                self.activeNodes = self.activeNodes.append(new ProcessingNode);
            }
        }
        
        private action removeNode(target : NodeCount) {
            self.targetNodeCount = target;
            while (self.activeNodes.size > target) {
                self.activeNodes.last().status = NodeStatus::TERMINATING;
                self.activeNodes = self.activeNodes.removeLast();
            }
        }
        
        private action aggregateMetrics() : SystemMetrics {
            // Collects metrics from all active nodes and produces system-level metrics
        }
    }
    
    // ===== Backend System (Top-Level) =====
    
    part def BackendServiceSystem {
        attribute systemName : String = "ScalableBackend";
        attribute availabilityTarget : Real = 99.99;
        attribute maxSupportedRequests : Throughput = 100000;
        
        part cacheLayer : CacheLayer {
            :>> maxCacheSize = 50000;
        }
        
        part loadBalancer : LoadBalancer;
        
        part processingNodes : ProcessingNode[2..20];
        
        part autoScaler : AutoScalingController {
            :>> minNodes = 2;
            :>> maxNodes = 20;
            :>> scaleUpThreshold = 200;
            :>> scaleDownThreshold = 50;
            :>> cooldownPeriod = 60;
        }
        
        part healthMonitor : HealthMonitor {
            :>> monitoringInterval = 5;
            :>> cpuLoadThreshold = 95;
            :>> responseTimeThreshold = 1000;
        }
        
        part nodePoolManager : NodePoolManager;
        
        // External-facing port
        port externalRequests : RequestPort;
        port systemAlerts : AlertPort;
        
        // Internal connections
        connection cacheToLB connect cacheLayer.cacheQuery.misses to loadBalancer.lbIn.forwardedRequests;
        connection lbToNodes connect loadBalancer.nodeOut to processingNodes.nodeIn;
        connection nodesToLB connect processingNodes.nodeIn.responses to loadBalancer.nodeOut.responses;
        connection lbToCache connect loadBalancer.lbIn.responses to cacheLayer.cacheQuery.cacheResults;
        connection cacheToExternal connect cacheLayer.cacheIn.responses to externalRequests.responses;
        connection externalToCache connect externalRequests.requests to cacheLayer.cacheIn.requests;
        
        connection nodesToHealthMonitor connect processingNodes.metricsOut to healthMonitor.healthMetricsIn.nodeMetrics;
        connection nodesToAutoScaler connect processingNodes.metricsOut to autoScaler.metricsIn.nodeMetrics;
        connection autoScalerToNodePool connect autoScaler.scalingOut to nodePoolManager.scalingCommandIn;
        connection healthMonitorAlerts connect healthMonitor.alertOut to systemAlerts;
        
        // System-level state machine
        state machine SystemLifecycle {
            entry; then Initializing;
            
            state Initializing {
                entry do {
                    // Bootstrap minimum processing nodes
                    self.processingNodes.size = 2;
                }
                then Running;
            }
            
            state Running;
            
            state DegradedMode {
                entry do {
                    // System enters degraded mode when health score drops
                }
            }
            
            state MaintenanceMode {
                entry do {
                    // Controlled shutdown for maintenance
                }
            }
            
            transition t1 first Running then DegradedMode
                when healthMonitor.systemHealthScore < 50
                do { /* Switch to degraded mode */ }
            ;
            
            transition t2 first DegradedMode then Running
                when healthMonitor.systemHealthScore >= 80
                do { /* Recovery detected */ }
            ;
            
            transition t3 first Running then MaintenanceMode
                when false // Triggered by admin command
                do { /* Begin maintenance */ }
            ;
            
            transition t4 first MaintenanceMode then Running
                when false // Maintenance complete
                do { /* Resume normal operation */ }
            ;
        }
    }
    
    // ===== Requirements =====
    
    requirement def HighAvailabilityRequirement {
        doc /* The system shall maintain 99.99% availability */
        attribute targetAvailability : Real = 99.99;
        subject : BackendServiceSystem;
        require constraint { self.availabilityTarget >= targetAvailability }
    }
    
    requirement def ScalabilityRequirement {
        doc /* The system shall scale between 2 and 20 processing nodes */
        attribute minNodes : NodeCount = 2;
        attribute maxNodes : NodeCount = 20;
        subject : BackendServiceSystem;
        require constraint {
            self.autoScaler.minNodes == minNodes and
            self.autoScaler.maxNodes == maxNodes
        }
    }
    
    requirement def CacheHitLatencyRequirement {
        doc /* Cache hits shall be returned within 5 ms */
        attribute maxCacheHitLatency : Latency = 5;
        subject : BackendServiceSystem;
        require constraint { /* cacheLayer response time for hits <= maxCacheHitLatency */ }
    }
    
    requirement def LoadBalancingRequirement {
        doc /* The load balancer shall distribute requests to prevent any single node bottleneck */
        subject : BackendServiceSystem;
        require constraint {
            // No single node shall exceed 80% CPU load while others are below 50%
        }
    }
    
    requirement def AutoScalingRequirement {
        doc /* The system shall automatically scale up when response time exceeds threshold and scale down during low traffic */
        attribute scaleUpThreshold : ResponseTime = 200;
        attribute scaleDownThreshold : ResponseTime = 50;
        attribute cooldownPeriod : CooldownDuration = 60;
        subject : BackendServiceSystem;
        require constraint {
            self.autoScaler.scaleUpThreshold == scaleUpThreshold and
            self.autoScaler.scaleDownThreshold == scaleDownThreshold and
            self.autoScaler.cooldownPeriod == cooldownPeriod
        }
    }
    
    requirement def HealthMonitoringRequirement {
        doc /* The health monitor shall detect node failures and degraded performance and raise alerts */
        subject : BackendServiceSystem;
        require constraint {
            self.healthMonitor.failedNodes.size >= 0 and
            self.healthMonitor.degradedNodes.size >= 0
        }
    }
    
    requirement def ProcessingNodeRedundancyRequirement {
        doc /* The system shall maintain a minimum of two processing nodes at all times */
        attribute minimumActiveNodes : NodeCount = 2;
        subject : BackendServiceSystem;
        require constraint {
            self.processingNodes.size >= minimumActiveNodes
        }
    }
    
    requirement package BackendRequirements {
        requirement haReq : HighAvailabilityRequirement;
        requirement scaleReq : ScalabilityRequirement;
        requirement cacheReq : CacheHitLatencyRequirement;
        requirement lbReq : LoadBalancingRequirement;
        requirement autoScaleReq : AutoScalingRequirement;
        requirement healthReq : HealthMonitoringRequirement;
        requirement redundancyReq : ProcessingNodeRedundancyRequirement;
    }
    
    // ===== Verification =====
    
    verification def VerifyScalability {
        subject : BackendServiceSystem;
        objective {
            doc /* Verify that the system scales correctly between 2 and 20 nodes */
        }
        return verdict : Boolean;
    }
    
    verification def VerifyCachePerformance {
        subject : CacheLayer;
        objective {
            doc /* Verify cache hit responses meet latency target */
        }
        return verdict : Boolean;
    }
    
    verification def VerifyAutoScalingCooldown {
        subject : AutoScalingController;
        objective {
            doc /* Verify that scaling actions respect the cooldown period */
        }
        return verdict : Boolean;
    }
    
    verification def VerifyHealthAlerts {
        subject : HealthMonitor;
        objective {
            doc /* Verify that health monitor raises alerts on node failure */
        }
        return verdict : Boolean;
    }
}
