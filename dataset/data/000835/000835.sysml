package 'YSet Distribution System' {
	private import ScalarValues::*;
	private import ISQ::*;
	
	item def FluidMedium {
		attribute density : DensityValue;
		attribute viscosity : DynamicViscosityValue;
		attribute temperature : ThermodynamicTemperatureValue;
	}
	
	item def FlowStream {
		attribute flowRate : VolumeFlowRateValue;
		attribute pressure : PressureValue;
		attribute medium : FluidMedium;
	}
	
	port def FluidPort {
		in item flowIn : FlowStream;
		out item flowOut : FlowStream;
	}
	
	part def YSetJunction {
		doc /* A Y-Set junction splits a single inlet fluid stream into two independent outlet streams. */
		
		port inlet : FluidPort;
		port outlet1 : FluidPort;
		port outlet2 : FluidPort;
		
		attribute splitRatio : Real;
		
		attribute outlet1FlowRate : VolumeFlowRateValue;
		attribute outlet2FlowRate : VolumeFlowRateValue;
		
		assert constraint flowConservation {
			doc /* Total outlet flow equals inlet flow. */
			outlet1FlowRate + outlet2FlowRate == inlet.flowIn.flowRate
		}
		
		assert constraint pressureEquilibrium {
			doc /* Outlet pressures are equal and less than or equal to inlet pressure. */
			outlet1.flowOut.pressure == outlet2.flowOut.pressure and
			outlet1.flowOut.pressure <= inlet.flowIn.pressure
		}
	}
	
	part def FlowSensor {
		doc /* Monitors fluid flow rate and pressure at a measurement point. */
		
		port measurementPoint : FluidPort;
		
		attribute measuredFlowRate : VolumeFlowRateValue;
		attribute measuredPressure : PressureValue;
		attribute measuredTemperature : ThermodynamicTemperatureValue;
		
		action measureFlowConditions {
			out flowReading : VolumeFlowRateValue;
			out pressureReading : PressureValue;
			out temperatureReading : ThermodynamicTemperatureValue;
		}
	}
	
	part def FlowControlValve {
		doc /* Controls flow rate through valve position adjustment. */
		
		port controlledPort : FluidPort;
		
		attribute targetFlowRate : VolumeFlowRateValue;
		attribute currentValvePosition : Real;
		attribute maxFlowRate : VolumeFlowRateValue;
		
		action adjustValvePosition {
			in desiredFlow : VolumeFlowRateValue;
			in actualFlow : VolumeFlowRateValue;
			out newPosition : Real;
		}
	}
	
	part def FlowDistributionController {
		doc /* Manages flow distribution between two outlet branches. */
		
		attribute desiredSplitRatio : Real;
		attribute currentSplitRatio : Real;
		attribute toleranceBand : Real;
		
		action calculateSplitAdjustment {
			in outlet1Flow : VolumeFlowRateValue;
			in outlet2Flow : VolumeFlowRateValue;
			in targetRatio : Real;
			out valve1Command : Real;
			out valve2Command : Real;
		}
	}
	
	action def StartupCommand;
	action def ShutdownCommand;
	
	state def YSetOperationalStates {
		entry; then idle;
		
		state idle {
			doc /* System is ready but not actively distributing flow. */
		}
		
		transition idle_to_startup
			first idle
			accept at StartupCommand
			then startup;
		
		state startup {
			doc /* System is initializing flow distribution. */
		}
		
		transition startup_to_distributing
			first startup
			then distributing;
		
		state distributing {
			doc /* Active flow distribution through both outlet branches. */
			
			state balancedDistribution {
				doc /* Flow split is within acceptable tolerance. */
			}
			
			state adjustingDistribution {
				doc /* Actively correcting flow imbalance. */
			}
			
			transition balanced_to_adjusting
				first balancedDistribution
				then adjustingDistribution;
			
			transition adjusting_to_balanced
				first adjustingDistribution
				then balancedDistribution;
		}
		
		transition distributing_to_shutdown
			first distributing
			accept at ShutdownCommand
			then shutdown;
		
		state shutdown {
			doc /* System is safely stopping flow distribution. */
		}
		
		transition shutdown_to_idle
			first shutdown
			then idle;
	}
	
	action def DistributeFlow {
		doc /* Splits inlet flow into two controlled outlet streams. */
		
		in inletFlow : FlowStream;
		in targetRatio : Real;
		out outlet1Flow : FlowStream;
		out outlet2Flow : FlowStream;
		
		action calculateFlowSplit {
			in totalFlow : VolumeFlowRateValue;
			in ratio : Real;
			out flow1 : VolumeFlowRateValue;
			out flow2 : VolumeFlowRateValue;
		}
		
		then action assignOutlet1Properties {
			in flowRate : VolumeFlowRateValue;
			in basePressure : PressureValue;
			out stream1 : FlowStream;
		}
		
		then action assignOutlet2Properties {
			in flowRate : VolumeFlowRateValue;
			in basePressure : PressureValue;
			out stream2 : FlowStream;
		}
	}
	
	action def MonitorYSetPerformance {
		doc /* Continuously monitors Y-Set distribution performance and adjusts as needed. */
		
		in inletFlowRate : VolumeFlowRateValue;
		in outlet1FlowRate : VolumeFlowRateValue;
		in outlet2FlowRate : VolumeFlowRateValue;
		in targetRatio : Real;
		in toleranceBand : Real;
		out performanceStatus : Real;
		
		first start;
		then merge continuousMonitoring;
		
		then action readAllSensors {
			out inletRate : VolumeFlowRateValue;
			out outlet1Rate : VolumeFlowRateValue;
			out outlet2Rate : VolumeFlowRateValue;
		}
		
		then action evaluateDistribution {
			in flow1 : VolumeFlowRateValue;
			in flow2 : VolumeFlowRateValue;
			in targetRatio : Real;
			out actualRatio : Real;
			out distributionError : Real;
		}
		
		then decide;
			if evaluateDistribution.distributionError > toleranceBand then correctImbalance;
			if evaluateDistribution.distributionError <= toleranceBand then continuousMonitoring;
		
		action correctImbalance {
			in error : Real;
			out correctionCommand : Real;
		}
		
		then continuousMonitoring;
	}
	
	requirement def YSetFunctionalRequirements {
		doc /* Defines functional requirements for Y-Set distribution system. */
		
		requirement <'YS-REQ-1'> flowSplittingRequirement {
			doc /* The system shall split a single inlet flow into two independent outlet flows. */
		}
		
		requirement <'YS-REQ-2'> splitRatioControlRequirement {
			doc /* The system shall maintain the flow split ratio within 5% of the commanded value. */
		}
		
		requirement <'YS-REQ-3'> pressureBalanceRequirement {
			doc /* The system shall maintain equal pressure at both outlet branches. */
		}
		
		requirement <'YS-REQ-4'> flowContinuityRequirement {
			doc /* The system shall maintain continuous flow distribution during normal operation. */
		}
	}
	
	part def YSetFluidDistributionSystem {
		doc /* 
			A Y-Set fluid distribution system that divides a single inlet fluid stream into two 
			independently controlled outlet streams. The primary function is to proportionally 
			distribute flow between two downstream processes while maintaining pressure balance 
			and precise flow ratio control. The system continuously monitors inlet and outlet 
			conditions and actively adjusts valve positions to maintain the desired flow split 
			ratio, ensuring optimal distribution efficiency and preventing flow imbalances that 
			could disrupt downstream operations.
		*/
		
		part junction : YSetJunction {
			doc /* Core Y-junction that physically splits the inlet stream. */
		}
		
		part inletSensor : FlowSensor {
			doc /* Monitors inlet stream conditions. */
		}
		
		part outlet1Sensor : FlowSensor {
			doc /* Monitors first outlet stream conditions. */
		}
		
		part outlet2Sensor : FlowSensor {
			doc /* Monitors second outlet stream conditions. */
		}
		
		part outlet1Valve : FlowControlValve {
			doc /* Controls flow rate to first outlet branch. */
		}
		
		part outlet2Valve : FlowControlValve {
			doc /* Controls flow rate to second outlet branch. */
		}
		
		part controller : FlowDistributionController {
			doc /* Manages overall flow distribution strategy. */
		}
		
		connection inletConnection connect 
			inletSensor.measurementPoint to junction.inlet;
		
		connection outlet1Connection connect 
			junction.outlet1 to outlet1Valve.controlledPort;
		
		connection outlet2Connection connect 
			junction.outlet2 to outlet2Valve.controlledPort;
		
		connection outlet1SensingConnection connect 
			outlet1Sensor.measurementPoint to outlet1Valve.controlledPort;
		
		connection outlet2SensingConnection connect 
			outlet2Sensor.measurementPoint to outlet2Valve.controlledPort;
		
		perform action operateDistribution : MonitorYSetPerformance {
			in inletFlowRate = inletSensor.measuredFlowRate;
			in outlet1FlowRate = outlet1Sensor.measuredFlowRate;
			in outlet2FlowRate = outlet2Sensor.measuredFlowRate;
			in targetRatio = controller.desiredSplitRatio;
			in toleranceBand = controller.toleranceBand;
		}
		
		exhibit state operationalBehavior : YSetOperationalStates;
		
		satisfy YSetFunctionalRequirements::flowSplittingRequirement;
		satisfy YSetFunctionalRequirements::splitRatioControlRequirement;
		satisfy YSetFunctionalRequirements::pressureBalanceRequirement;
		satisfy YSetFunctionalRequirements::flowContinuityRequirement;
	}
}
