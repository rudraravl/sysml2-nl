package RoadSurfaceSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def SurfaceCondition {
		attribute roughness : LengthValue;
		attribute frictionCoefficient : Real;
		attribute temperature : TemperatureValue;
		attribute wetnessLevel : Real;
	}
	
	attribute def TrafficLoad {
		attribute vehicleCount : Integer;
		attribute averageAxleLoad : ForceValue;
		attribute trafficSpeed : SpeedValue;
	}
	
	item def MaintenanceCommand {
		attribute priority : Integer;
		attribute actionType : String;
		attribute scheduledTime : TimeValue;
	}
	
	item def WeatherCondition {
		attribute precipitation : LengthValue;
		attribute ambientTemperature : TemperatureValue;
		attribute windSpeed : SpeedValue;
	}
	
	port def SensorPort {
		out surfaceData : SurfaceCondition;
	}
	
	port def ControlPort {
		in maintenanceCmd : MaintenanceCommand;
		out statusReport : SurfaceCondition;
	}
	
	port def EnvironmentPort {
		in weather : WeatherCondition;
		in traffic : TrafficLoad;
	}
	
	part def SurfaceSensor {
		port sensorOutput : SensorPort;
		
		action measureCondition {
			out condition : SurfaceCondition;
		}
	}
	
	part def DrainageSubsystem {
		attribute capacity : VolumeValue;
		attribute drainageEfficiency : Real;
		
		action removeWater {
			in precipitationRate : LengthValue;
			out waterRemoved : VolumeValue;
		}
	}
	
	part def HeatingSubsystem {
		attribute heatingPower : PowerValue;
		
		action maintainTemperature {
			in currentTemp : TemperatureValue;
			in targetTemp : TemperatureValue;
			out powerOutput : PowerValue;
		}
	}
	
	part def MaintenanceController {
		port controlInterface : ControlPort;
		
		action assessCondition {
			in surfaceCondition : SurfaceCondition;
			out maintenanceNeeded : Boolean;
		}
		
		action issueMaintenanceCommand {
			in condition : SurfaceCondition;
			out command : MaintenanceCommand;
		}
	}
	
	part def RoadSurface {
		attribute surfaceLength : LengthValue;
		attribute surfaceWidth : LengthValue;
		attribute layerThickness : LengthValue;
		attribute pavementMaterial : String;
		attribute designLifespan : TimeValue;
		
		port environmentInterface : EnvironmentPort;
		port maintenanceInterface : ControlPort;
		
		part sensors : SurfaceSensor[4] {
			port :>> sensorOutput;
		}
		
		part drainage : DrainageSubsystem {
			attribute :>> capacity = 800.0 [L];
			attribute :>> drainageEfficiency = 0.90;
		}
		
		part heating : HeatingSubsystem {
			attribute :>> heatingPower = 75000.0 [W];
		}
		
		part controller : MaintenanceController {
			port :>> controlInterface;
		}
		
		connection sensorToController connect 
			sensors.sensorOutput to controller.controlInterface;
		
		perform action manageSurface;
	}
	
	action def MonitorSurfaceCondition {
		in weatherInput : WeatherCondition;
		in trafficInput : TrafficLoad;
		out currentCondition : SurfaceCondition;
	}
	
	action def ManageDrainage {
		in precipitation : LengthValue;
		in wetness : Real;
		out drainageActivated : Boolean;
	}
	
	action def ControlSurfaceHeating {
		in surfaceTemp : TemperatureValue;
		in ambientTemp : TemperatureValue;
		out heatingActivated : Boolean;
	}
	
	action def EvaluateSurfaceDegradation {
		in roughness : LengthValue;
		in friction : Real;
		out degradationLevel : Real;
	}
	
	action def ProvideSafeDrivingSurface {
		first start;
		then merge operationLoop;
		
		action monitor : MonitorSurfaceCondition {
			in weatherInput;
			in trafficInput;
			out measuredCondition : SurfaceCondition;
		}
		
		then decide;
			if monitor.measuredCondition.wetnessLevel > 0.4 then activateDrainage;
			if monitor.measuredCondition.temperature < 273.15 [K] then activateHeating;
			if monitor.measuredCondition.roughness > 0.006 [m] then evaluateDegradation;
		
		action activateDrainage : ManageDrainage {
			in precipitation = monitor.weatherInput.precipitation;
			in wetness = monitor.measuredCondition.wetnessLevel;
			out drainageActivated;
		}
		then operationLoop;
		
		action activateHeating : ControlSurfaceHeating {
			in surfaceTemp = monitor.measuredCondition.temperature;
			in ambientTemp = monitor.weatherInput.ambientTemperature;
			out heatingActivated;
		}
		then operationLoop;
		
		action evaluateDegradation : EvaluateSurfaceDegradation {
			in roughness = monitor.measuredCondition.roughness;
			in friction = monitor.measuredCondition.frictionCoefficient;
			out degradationLevel;
		}
		
		then decide maintenanceDecision;
			if evaluateDegradation.degradationLevel > 0.75 then scheduleMaintenance;
			if evaluateDegradation.degradationLevel <= 0.75 then operationLoop;
		
		action scheduleMaintenance {
			in degradationLevel = evaluateDegradation.degradationLevel;
		}
		then operationLoop;
	}
	
	state def SurfaceOperationalState {
		entry; then initial;
		
		state initial;
		
		accept at when 0.0 [s]
		do transition initial_to_active
			first initial
			then active;
		
		state active {
			entry; then optimal;
			
			state optimal;
			
			accept surfaceDegradationDetected
			do transition optimal_to_acceptable
				first optimal
				then acceptable;
			
			state acceptable;
			
			accept furtherDegradation
			do transition acceptable_to_degraded
				first acceptable
				then degraded;
			
			state degraded;
		}
		
		accept maintenanceScheduled
		do transition active_to_maintenance
			first active
			then underMaintenance;
		
		state underMaintenance;
		
		accept maintenanceComplete
		do transition maintenance_to_active
			first underMaintenance
			then active;
		
		accept endOfLifeReached
		do transition active_to_retired
			first active
			then retired;
		
		state retired;
	}
	
	part roadSurfaceSystem : RoadSurface {
		attribute :>> surfaceLength = 1500.0 [m];
		attribute :>> surfaceWidth = 14.0 [m];
		attribute :>> layerThickness = 0.35 [m];
		attribute :>> pavementMaterial = "asphalt_concrete";
		attribute :>> designLifespan = 25.0 [yr];
		
		perform action surfaceOperation : ProvideSafeDrivingSurface;
		
		exhibit state operationalState : SurfaceOperationalState;
	}
	
	requirement def SafeOperationRequirement {
		doc /* The road surface system shall maintain safe operating conditions for vehicular traffic under all environmental conditions. */
		
		require frictionRequirement;
		require drainageRequirement;
		require temperatureRequirement;
	}
	
	requirement <'RS-001'> frictionRequirement {
		doc /* The road surface friction coefficient shall exceed 0.45 under all weather conditions to ensure safe vehicle operation. */
		
		subject roadSurface : RoadSurface;
		
		require constraint {
			roadSurface.sensors.measureCondition.condition.frictionCoefficient > 0.45
		}
	}
	
	requirement <'RS-002'> drainageRequirement {
		doc /* The drainage subsystem shall remove at least 90% of surface water within 5 minutes of precipitation. */
		
		subject drainage : DrainageSubsystem;
		
		require constraint {
			drainage.drainageEfficiency >= 0.90
		}
	}
	
	requirement <'RS-003'> temperatureRequirement {
		doc /* The surface temperature shall be maintained above freezing point when ambient temperature drops below 0°C. */
		
		subject heating : HeatingSubsystem;
		
		require constraint {
			heating.maintainTemperature.currentTemp >= 273.15 [K]
		}
	}
	
	requirement <'RS-004'> surfaceQualityRequirement {
		doc /* Surface roughness shall not exceed 7mm before triggering maintenance intervention. */
		
		subject surface : RoadSurface;
		
		require constraint {
			surface.sensors.measureCondition.condition.roughness <= 0.007 [m]
		}
	}
	
	requirement <'RS-MAIN'> primaryFunctionRequirement : SafeOperationRequirement {
		doc /* The road surface system shall provide a safe, durable, and continuously maintained driving surface that responds to environmental conditions and traffic demands while ensuring optimal friction, effective drainage, and appropriate temperature control throughout its operational lifespan. */
		
		subject system : RoadSurface;
		
		assume constraint operatingEnvironment {
			system.environmentInterface.weather.ambientTemperature >= 243.15 [K] and
			system.environmentInterface.weather.ambientTemperature <= 328.15 [K]
		}
		
		assume constraint trafficLimits {
			system.environmentInterface.traffic.vehicleCount <= 8000 and
			system.environmentInterface.traffic.averageAxleLoad <= 100000.0 [N]
		}
		
		require frictionRequirement;
		require drainageRequirement;
		require temperatureRequirement;
		require surfaceQualityRequirement;
	}
}
