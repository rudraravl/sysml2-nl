package 'Support Surface System' {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def LoadDistributionProfile;
	attribute def SurfaceIntegrityStatus;
	attribute def ContactCondition;
	
	value def PressureDistribution {
		attribute peakPressure : ISQ::PressureValue;
		attribute averagePressure : ISQ::PressureValue;
		attribute contactArea : ISQ::AreaValue;
	}
	
	value def LoadCapacity {
		attribute maximumLoad : ISQ::MassValue;
		attribute safeWorkingLoad : ISQ::MassValue;
		attribute distributedLoadLimit : ISQ::MassValue;
	}
	
	value def SurfaceDimensions {
		attribute length : ISQ::LengthValue;
		attribute width : ISQ::LengthValue;
		attribute thickness : ISQ::LengthValue;
	}
	
	value def MaterialProperties {
		attribute density : ISQ::DensityValue;
		attribute elasticModulus : ISQ::PressureValue;
		attribute yieldStrength : ISQ::PressureValue;
		attribute compressionResistance : ISQ::PressureValue;
	}
	
	item def AppliedLoad {
		attribute totalMass : ISQ::MassValue;
		attribute contactArea : ISQ::AreaValue;
		attribute centerOfMass : ISQ::LengthValue[3];
		attribute distributionPattern : LoadDistributionProfile;
	}
	
	port def LoadBearingInterface {
		in item incomingLoad : AppliedLoad;
		out attribute reactionForce : ISQ::ForceValue;
		out attribute contactPressure : ISQ::PressureValue;
		out attribute supportActive : Boolean;
	}
	
	port def StructuralMonitoringInterface {
		out attribute currentDeflection : ISQ::LengthValue;
		out attribute stressLevel : ISQ::PressureValue;
		out attribute integrityStatus : SurfaceIntegrityStatus;
		out attribute temperatureRise : ISQ::TemperatureValue;
	}
	
	port def EnvironmentalInterface {
		in attribute ambientTemperature : ISQ::TemperatureValue;
		in attribute humidity : Real;
		out attribute surfaceCondition : ContactCondition;
	}
	
	part def SupportSurface {
		attribute dimensions : SurfaceDimensions;
		attribute capacity : LoadCapacity;
		attribute material : MaterialProperties;
		attribute currentLoadMass : ISQ::MassValue;
		attribute operationalStatus : Boolean;
		attribute deflection : ISQ::LengthValue;
		
		port loadInterface : LoadBearingInterface[1..*];
		port structuralMonitor : StructuralMonitoringInterface;
		port environmentalPort : EnvironmentalInterface;
		
		part structuralCore {
			attribute coreMaterial : MaterialProperties;
			attribute coreThickness : ISQ::LengthValue;
			attribute reinforcementDensity : ISQ::DensityValue;
			
			perform action transferLoad {
				in appliedForce : ISQ::ForceValue;
				out distributedStress : ISQ::PressureValue;
			}
		}
		
		part loadBearingLayer {
			attribute layerThickness : ISQ::LengthValue;
			attribute surfaceFinish : ContactCondition;
			attribute frictionCoefficient : Real;
			attribute wearResistance : Real;
			
			perform action distributeContact {
				in contactLoad : ISQ::ForceValue;
				in contactArea : ISQ::AreaValue;
				out pressureDistribution : PressureDistribution;
			}
		}
		
		part edgeSupport {
			attribute edgeStrength : ISQ::ForceValue;
			attribute edgeReinforcement : Boolean;
			
			perform action preventEdgeFailure {
				in edgeLoad : ISQ::ForceValue;
				out edgeIntegrity : Boolean;
			}
		}
		
		part anchorageSystem {
			attribute anchorPoints : Integer;
			attribute anchorStrength : ISQ::ForceValue;
			attribute fixedPosition : Boolean;
			
			perform action maintainPosition {
				in lateralForce : ISQ::ForceValue;
				out positionStable : Boolean;
			}
		}
		
		connection loadToStructure connect loadInterface to structuralCore;
		connection structureToMonitor connect structuralCore to structuralMonitor;
	}
	
	action def AssessLoadCapacity {
		in appliedMass : ISQ::MassValue;
		in maximumCapacity : ISQ::MassValue;
		in safeWorkingLoad : ISQ::MassValue;
		out loadRatio : Real;
		out withinCapacity : Boolean;
		out safetyMargin : Real;
	}
	
	action def DistributeLoadAcrossSurface {
		in load : AppliedLoad;
		in surfaceDimensions : SurfaceDimensions;
		in materialProps : MaterialProperties;
		out pressureDistribution : PressureDistribution;
		out deflectionAmount : ISQ::LengthValue;
		out stressConcentration : ISQ::PressureValue;
		
		action calculateContactPressure {
			in loadMass : ISQ::MassValue;
			in contactArea : ISQ::AreaValue;
			out averagePressure : ISQ::PressureValue;
		}
		
		then action calculateDeflection {
			in appliedPressure : ISQ::PressureValue;
			in modulus : ISQ::PressureValue;
			in surfaceThickness : ISQ::LengthValue;
			out deflection : ISQ::LengthValue;
		}
		
		then action evaluateStress {
			in pressure : ISQ::PressureValue;
			in yieldStrength : ISQ::PressureValue;
			out stressLevel : ISQ::PressureValue;
			out withinLimit : Boolean;
		}
	}
	
	action def MonitorStructuralIntegrity {
		in currentStress : ISQ::PressureValue;
		in yieldStrength : ISQ::PressureValue;
		in deflection : ISQ::LengthValue;
		in maxDeflection : ISQ::LengthValue;
		out integrityMaintained : Boolean;
		out warningLevel : Integer;
	}
	
	action def ProvideSupportFunction {
		in item receivedLoad : AppliedLoad;
		in surfaceCapacity : LoadCapacity;
		in surfaceDimensions : SurfaceDimensions;
		in materialProperties : MaterialProperties;
		out supportProvided : Boolean;
		out reactionForce : ISQ::ForceValue;
		out surfaceIntegrity : Boolean;
		
		first start;
		then merge continuousOperation;
		
		then action assessCapacity : AssessLoadCapacity {
			in appliedMass = receivedLoad.totalMass;
			in maximumCapacity = surfaceCapacity.maximumLoad;
			in safeWorkingLoad = surfaceCapacity.safeWorkingLoad;
			out loadRatio;
			out withinCapacity;
			out safetyMargin;
		}
		
		then decide;
			if assessCapacity.withinCapacity then acceptAndDistribute;
			else rejectLoad;
		
		action rejectLoad {
			then done;
		}
		
		action acceptAndDistribute {
			action distributeLoad : DistributeLoadAcrossSurface {
				in load = receivedLoad;
				in surfaceDimensions = ProvideSupportFunction::surfaceDimensions;
				in materialProps = materialProperties;
				out pressureDistribution;
				out deflectionAmount;
				out stressConcentration;
			}
			
			then action monitorIntegrity : MonitorStructuralIntegrity {
				in currentStress = distributeLoad.stressConcentration;
				in yieldStrength = materialProperties.yieldStrength;
				in deflection = distributeLoad.deflectionAmount;
				in maxDeflection;
				out integrityMaintained;
				out warningLevel;
			}
			
			then decide;
				if monitorIntegrity.integrityMaintained then confirmSupport;
				else failureResponse;
			
			action failureResponse {
				then done;
			}
			
			action confirmSupport;
		}
		then continuousOperation;
	}
	
	state def SupportSurfaceOperationalStates {
		entry; then unloaded;
		
		state unloaded;
		accept LoadApplicationEvent then evaluating;
		
		state evaluating;
		accept at when done then loaded;
		
		state loaded;
		accept LoadRemovalEvent then unloading;
		
		state unloading;
		then unloaded;
	}
	
	part supportSurfaceSystem : SupportSurface {
		attribute :>> dimensions {
			attribute :>> length = 3.0[SI::m];
			attribute :>> width = 2.0[SI::m];
			attribute :>> thickness = 0.15[SI::m];
		}
		
		attribute :>> capacity {
			attribute :>> maximumLoad = 1000[SI::kg];
			attribute :>> safeWorkingLoad = 750[SI::kg];
			attribute :>> distributedLoadLimit = 800[SI::kg];
		}
		
		attribute :>> material {
			attribute :>> density = 2500[SI::kg/(SI::m^3)];
			attribute :>> elasticModulus = 200000[SI::MPa];
			attribute :>> yieldStrength = 350[SI::MPa];
			attribute :>> compressionResistance = 400[SI::MPa];
		}
		
		attribute :>> currentLoadMass = 0[SI::kg];
		attribute :>> operationalStatus = true;
		attribute :>> deflection = 0[SI::m];
		
		perform action provideSupportAction : ProvideSupportFunction {
			in item receivedLoad;
			in surfaceCapacity = capacity;
			in surfaceDimensions = dimensions;
			in materialProperties = material;
			out supportProvided;
			out reactionForce;
			out surfaceIntegrity;
		}
		
		exhibit state operationalStateMachine : SupportSurfaceOperationalStates;
		
		part :>> structuralCore {
			attribute :>> coreMaterial = material;
			attribute :>> coreThickness = 0.12[SI::m];
			attribute :>> reinforcementDensity = 2700[SI::kg/(SI::m^3)];
		}
		
		part :>> loadBearingLayer {
			attribute :>> layerThickness = 0.03[SI::m];
			attribute :>> frictionCoefficient = 0.5;
			attribute :>> wearResistance = 0.95;
		}
		
		part :>> edgeSupport {
			attribute :>> edgeStrength = 50000[SI::N];
			attribute :>> edgeReinforcement = true;
		}
		
		part :>> anchorageSystem {
			attribute :>> anchorPoints = 8;
			attribute :>> anchorStrength = 25000[SI::N];
			attribute :>> fixedPosition = true;
		}
	}
	
	requirement def LoadBearingRequirement {
		doc /* The support surface shall safely bear applied loads up to its rated capacity 
		       while maintaining structural integrity and distributing pressure uniformly. */
		
		subject surface : SupportSurface;
	}
	
	requirement def PressureDistributionRequirement {
		doc /* The support surface shall distribute applied loads uniformly to prevent 
		       localized stress concentrations exceeding material yield strength. */
		
		subject surface : SupportSurface;
	}
	
	requirement def OperationalSafetyRequirement {
		doc /* The support surface shall continuously monitor structural integrity and 
		       reject loads that exceed safe working limits. */
		
		subject surface : SupportSurface;
	}
	
	requirement <'SS-REQ-001'> primaryLoadBearingRequirement : LoadBearingRequirement {
		subject system = supportSurfaceSystem;
	}
	
	requirement <'SS-REQ-002'> pressureDistributionRequirement : PressureDistributionRequirement {
		subject system = supportSurfaceSystem;
	}
	
	requirement <'SS-REQ-003'> operationalSafetyRequirement : OperationalSafetyRequirement {
		subject system = supportSurfaceSystem;
	}
}
