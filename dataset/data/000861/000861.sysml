package ConcentricReducerSystem {
	private import ScalarValues::*;
	private import ISQ::*;
	private import SI::*;
	
	attribute def PipeDiameter :> ISQ::LengthValue;
	attribute def FlowVelocity :> ISQ::SpeedValue;
	attribute def FlowPressure :> ISQ::PressureValue;
	attribute def VolumetricFlowRate :> ISQ::VolumeFlowRateValue;
	attribute def FluidDensity :> ISQ::DensityValue;
	attribute def FluidViscosity :> ISQ::DynamicViscosityValue;
	attribute def PressureDrop :> ISQ::PressureValue;
	attribute def ConeAngle :> ISQ::AngleValue;
	
	item def ProcessFluid {
		attribute density : FluidDensity;
		attribute viscosity : FluidViscosity;
		attribute temperature : ISQ::ThermodynamicTemperatureValue;
	}
	
	port def FluidPort {
		attribute diameter : PipeDiameter;
		attribute pressure : FlowPressure;
		attribute velocity : FlowVelocity;
		attribute flowRate : VolumetricFlowRate;
		in item fluid : ProcessFluid;
	}
	
	part def ConcentricReducer {
		attribute inletDiameter : PipeDiameter;
		attribute outletDiameter : PipeDiameter;
		attribute reducerLength : ISQ::LengthValue;
		attribute taperAngle : ConeAngle;
		
		port inletPort : FluidPort {
			attribute :>> diameter = inletDiameter;
		}
		
		port outletPort : FluidPort {
			attribute :>> diameter = outletDiameter;
		}
		
		assert constraint diameterReduction {
			doc /* Inlet diameter must be larger than outlet diameter */
			inletDiameter > outletDiameter
		}
		
		assert constraint taperAngleLimit {
			doc /* Taper angle should not exceed 30 degrees for smooth flow */
			taperAngle <= 30.0
		}
		
		action def TransitionFlow {
			in inletFlowRate : VolumetricFlowRate;
			in inletPressure : FlowPressure;
			in inletVelocity : FlowVelocity;
			in fluid : ProcessFluid;
			in inDiam : PipeDiameter;
			in outDiam : PipeDiameter;
			
			out outletFlowRate : VolumetricFlowRate;
			out outletPressure : FlowPressure;
			out outletVelocity : FlowVelocity;
			out pressureLoss : PressureDrop;
			
			first start;
			
			then action applyContinuityEquation {
				doc /* Mass flow rate remains constant: Q_in = Q_out */
			}
			then assign outletFlowRate := inletFlowRate;
			
			then action calculateVelocityChange {
				doc /* Velocity increases as cross-sectional area decreases */
			}
			then assign outletVelocity := inletVelocity * (inDiam * inDiam) / (outDiam * outDiam);
			
			then action calculatePressureLoss {
				doc /* Pressure drop due to sudden contraction and friction */
			}
			then assign pressureLoss := 0.5 * fluid.density * (outletVelocity * outletVelocity - inletVelocity * inletVelocity);
			
			then action computeOutletPressure;
			then assign outletPressure := inletPressure - pressureLoss;
			
			then done;
		}
		
		perform action transitionFlow : TransitionFlow {
			in inletFlowRate = inletPort.flowRate;
			in inletPressure = inletPort.pressure;
			in inletVelocity = inletPort.velocity;
			in fluid = inletPort.fluid;
			in inDiam = inletDiameter;
			in outDiam = outletDiameter;
			out outletFlowRate;
			out outletPressure;
			out outletVelocity;
			out pressureLoss;
		}
	}
	
	part def PipeSegment {
		attribute pipeDiameter : PipeDiameter;
		attribute pipeLength : ISQ::LengthValue;
		attribute roughness : ISQ::LengthValue;
		
		port end1 : FluidPort {
			attribute :>> diameter = pipeDiameter;
		}
		
		port end2 : FluidPort {
			attribute :>> diameter = pipeDiameter;
		}
	}
	
	part def FlowMeter {
		attribute measuredFlowRate : VolumetricFlowRate;
		
		port measurementPort : FluidPort;
		
		action def MeasureFlow {
			in flowRate : VolumetricFlowRate;
			out reading : VolumetricFlowRate;
			
			first start;
			then assign reading := flowRate;
			then done;
		}
		
		perform action measureFlow : MeasureFlow {
			in flowRate = measurementPort.flowRate;
			out reading;
		}
	}
	
	part def PressureSensor {
		attribute measuredPressure : FlowPressure;
		
		port sensePort : FluidPort;
		
		action def MeasurePressure {
			in pressure : FlowPressure;
			out reading : FlowPressure;
			
			first start;
			then assign reading := pressure;
			then done;
		}
		
		perform action measurePressure : MeasurePressure {
			in pressure = sensePort.pressure;
			out reading;
		}
	}
	
	requirement def FlowTransitionRequirement {
		doc /* The reducer shall smoothly transition fluid flow from a larger to smaller pipe diameter while maintaining flow continuity. */
		
		subject reducer : ConcentricReducer;
		
		require constraint smoothTransition {
			reducer.taperAngle <= 30.0
		}
	}
	
	requirement def MassConservationRequirement {
		doc /* The reducer shall maintain mass flow rate continuity between inlet and outlet. */
		
		subject reducer : ConcentricReducer;
		
		require constraint flowContinuity {
			reducer.inletPort.flowRate == reducer.outletPort.flowRate
		}
	}
	
	requirement def VelocityIncreaseRequirement {
		doc /* The reducer shall increase fluid velocity proportional to the reduction in cross-sectional area. */
		
		subject reducer : ConcentricReducer;
		
		require constraint velocityIncrease {
			reducer.outletPort.velocity == reducer.inletPort.velocity * 
				(reducer.inletDiameter * reducer.inletDiameter) / 
				(reducer.outletDiameter * reducer.outletDiameter)
		}
	}
	
	requirement def PressureDropRequirement {
		doc /* The reducer shall minimize pressure loss during flow transition to acceptable levels. */
		
		subject reducer : ConcentricReducer;
		
		require constraint acceptablePressureLoss {
			reducer.transitionFlow.pressureLoss <= 0.15 * reducer.inletPort.pressure
		}
	}
	
	part reducerPipelineSystem {
		doc /* 
		Primary Function: The concentric reducer system transitions fluid flow from a larger diameter pipe 
		to a smaller diameter pipe while maintaining concentric alignment of the pipe centerlines. 
		This transition increases fluid velocity and reduces cross-sectional area, enabling efficient 
		flow management in piping systems where diameter changes are required.
		*/
		
		attribute systemFlowRate : VolumetricFlowRate;
		attribute operatingPressure : FlowPressure;
		
		part upstreamPipe : PipeSegment {
			attribute :>> pipeDiameter = 200.0;
			attribute :>> pipeLength = 5000.0;
			attribute :>> roughness = 0.045;
		}
		
		part reducer : ConcentricReducer {
			attribute :>> inletDiameter = 200.0;
			attribute :>> outletDiameter = 100.0;
			attribute :>> reducerLength = 400.0;
			attribute :>> taperAngle = 20.0;
		}
		
		part downstreamPipe : PipeSegment {
			attribute :>> pipeDiameter = 100.0;
			attribute :>> pipeLength = 3000.0;
			attribute :>> roughness = 0.045;
		}
		
		part inletFlowMeter : FlowMeter;
		part outletFlowMeter : FlowMeter;
		part inletPressureSensor : PressureSensor;
		part outletPressureSensor : PressureSensor;
		
		connection upstreamConnection connect upstreamPipe.end2 to reducer.inletPort;
		connection downstreamConnection connect reducer.outletPort to downstreamPipe.end1;
		connection inletFlowMonitoring connect reducer.inletPort to inletFlowMeter.measurementPort;
		connection outletFlowMonitoring connect reducer.outletPort to outletFlowMeter.measurementPort;
		connection inletPressureMonitoring connect reducer.inletPort to inletPressureSensor.sensePort;
		connection outletPressureMonitoring connect reducer.outletPort to outletPressureSensor.sensePort;
		
		action def OperateReducerSystem {
			doc /* 
			Primary system operation: continuously transition fluid from large to small diameter 
			while monitoring flow and pressure to ensure proper performance 
			*/
			
			first start;
			then merge continuousOperation;
			
			then action monitorInletConditions {
				perform inletFlowMeter.measureFlow;
				perform inletPressureSensor.measurePressure;
			}
			
			then action performFlowTransition {
				perform reducer.transitionFlow;
			}
			
			then action monitorOutletConditions {
				perform outletFlowMeter.measureFlow;
				perform outletPressureSensor.measurePressure;
			}
			
			then continuousOperation;
		}
		
		perform action operateReducerSystem : OperateReducerSystem;
	}
	
	requirement systemRequirements {
		doc /* Overall requirements for concentric reducer system operation */
		
		require flowTransition : FlowTransitionRequirement;
		require massConservation : MassConservationRequirement;
		require velocityIncrease : VelocityIncreaseRequirement;
		require pressureDrop : PressureDropRequirement;
	}
}
