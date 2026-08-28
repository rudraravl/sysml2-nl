package 'Scalable Backend System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;

	item def ServiceRequest {
		attribute id : String;
		attribute priority : Integer;
		attribute dataId : String;
	}
	item def ServiceResponse {
		attribute requestId : String;
		attribute payload : String;
		attribute status : String;
	}
	item def PerformanceMetric {
		attribute nodeId : Integer;
		attribute load : Real;
		attribute responseTime : Real;
		attribute active : Boolean;
	}
	item def ScaleCommand {
		attribute scaleAction : String;
		attribute nodeId : Integer;
	}
	item def HealthAlert {
		attribute nodeId : Integer;
		attribute severity : String;
		attribute alertMessage : String;
	}

	port def RequestPort {
		in req : ServiceRequest;
		out resp : ServiceResponse;
	}
	port def MetricPort {
		out metric : PerformanceMetric;
	}
	port def ControlPort {
		in cmd : ScaleCommand;
	}
	port def AlertPort {
		out alert : HealthAlert;
	}

	part def CacheLayer {
		port reqPort : RequestPort;
		port fwdPort : RequestPort;
		attribute cachedDataId : String = "cached_item";

		exhibit state CacheBehavior {
			entry; then idle;
			state idle;
			accept r : ServiceRequest via reqPort
				if r.dataId == cachedDataId
				do send new ServiceResponse(r.id, "cached_payload", "HIT") via reqPort
				then idle;
			accept r : ServiceRequest via reqPort
				if r.dataId != cachedDataId
				do send new ServiceRequest(r.id, r.priority, r.dataId) via fwdPort
				then waiting;
			state waiting;
			accept resp : ServiceResponse via fwdPort
				do send new ServiceResponse(resp.requestId, resp.payload, resp.status) via reqPort
				then idle;
		}
	}

	part def LoadBalancer {
		port inPort : RequestPort;
		port nodePorts : RequestPort [2..20];
		attribute nextNode : Integer = 0;

		exhibit state LBBehavior {
			entry; then idle;
			state idle;
			accept r : ServiceRequest via inPort
				if r.priority > 5
				do send new ServiceRequest(r.id, r.priority, r.dataId) via nodePorts
				then idle;
			accept r : ServiceRequest via inPort
				if r.priority <= 5
				do send new ServiceRequest(r.id, r.priority, r.dataId) via nodePorts
				then idle;
			accept resp : ServiceResponse via nodePorts
				do send new ServiceResponse(resp.requestId, resp.payload, resp.status) via inPort
				then idle;
		}
	}

	part def ProcessingNode {
		port reqPort : RequestPort;
		port metricPort : MetricPort;
		port ctrlPort : ControlPort;
		attribute nodeId : Integer;
		attribute currentLoad : Real = 0.0;
		attribute responseTime : Real = 10.0;
		attribute isActive : Boolean = false;

		exhibit state NodeBehavior {
			entry; then inactive;
			state inactive;
			accept cmd : ScaleCommand via ctrlPort
				if cmd.scaleAction == "activate"
				then active;
			state active {
				entry do send new PerformanceMetric(nodeId, currentLoad, responseTime, true) via metricPort;
			}
			accept r : ServiceRequest via reqPort
				do send new ServiceResponse(r.id, "processed_payload", "OK") via reqPort
				then active;
			accept cmd : ScaleCommand via ctrlPort
				if cmd.scaleAction == "deactivate"
				then inactive;
		}
	}

	part def AutoScalingController {
		port metricPort : MetricPort;
		port ctrlPorts : ControlPort [2..20];
		attribute minNodes : Integer = 2;
		attribute maxNodes : Integer = 20;
		attribute activeNodes : Integer = 2;
		attribute cooldownRemaining : Real = 0.0;

		exhibit state ScalingBehavior {
			entry; then monitoring;
			state monitoring;
			accept m : PerformanceMetric via metricPort
				if m.load > 80.0 and cooldownRemaining == 0.0 and activeNodes < maxNodes
				do send new ScaleCommand("activate", activeNodes) via ctrlPorts
				then cooldown;
			accept m : PerformanceMetric via metricPort
				if m.load < 20.0 and cooldownRemaining == 0.0 and activeNodes > minNodes
				do send new ScaleCommand("deactivate", activeNodes - 1) via ctrlPorts
				then cooldown;
			state cooldown;
			accept after 300.0 [s]
				then monitoring;
		}
	}

	part def HealthMonitor {
		port metricPort : MetricPort;
		port alertPort : AlertPort;
		attribute responseTimeThreshold : Real = 500.0;

		exhibit state HealthBehavior {
			entry; then healthy;
			state healthy;
			accept m : PerformanceMetric via metricPort
				if m.responseTime > responseTimeThreshold
				do send new HealthAlert(m.nodeId, "CRITICAL", "Response time exceeded threshold") via alertPort
				then degraded;
			state degraded;
			accept m : PerformanceMetric via metricPort
				if m.responseTime < 200.0
				do send new HealthAlert(m.nodeId, "RESOLVED", "System recovered") via alertPort
				then healthy;
		}
	}

	requirement def ScalabilityRequirement {
		doc /* The system must maintain between 2 and 20 processing nodes. */
	}
	requirement def PerformanceRequirement {
		doc /* Cache hits must return immediately without forwarding to processing nodes. */
	}
	requirement def AvailabilityRequirement {
		doc /* The health monitor must trigger alerts for degraded performance. */
	}
	requirement def CooldownRequirement {
		doc /* Auto-scaling must enforce a minimum 5-minute cooldown between adjustments. */
	}

	part def BackendSystem {
		satisfy ScalabilityRequirement;
		satisfy PerformanceRequirement;
		satisfy AvailabilityRequirement;
		satisfy CooldownRequirement;

		port externalReq : RequestPort;
		port externalAlert : AlertPort;

		part cache : CacheLayer;
		part loadBalancer : LoadBalancer;
		part nodes : ProcessingNode [2..20];
		part scaler : AutoScalingController;
		part monitor : HealthMonitor;

		connect externalReq to cache.reqPort;
		connect cache.fwdPort to loadBalancer.inPort;
		connect loadBalancer.nodePorts to nodes.reqPort;
		connect nodes.metricPort to scaler.metricPort;
		connect nodes.metricPort to monitor.metricPort;
		connect scaler.ctrlPorts to nodes.ctrlPort;
		connect monitor.alertPort to externalAlert;
	}
}
