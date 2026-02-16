package FluidDynamicsSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidProperties {
        attribute density : DensityValue;
        attribute viscosity : DynamicViscosityValue;
        attribute temperature : ThermodynamicTemperatureValue;
    }
    
    attribute def FlowState {
        attribute velocity : SpeedValue;
        attribute pressure : PressureValue;
        attribute volumetricFlowRate : VolumeFlowRateValue;
    }
    
    attribute def PipeGeometry {
        attribute diameter : LengthValue;
        attribute length : LengthValue;
        attribute roughness : LengthValue;
    }
    
    port def FluidPort {
        attribute flowState : FlowState;
        attribute fluidProps : FluidProperties;
    }
    
    item def Fluid {
        attribute properties : FluidProperties;
    }
    
    part def Pump {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute powerInput : PowerValue;
        attribute efficiency : Real;
        attribute headPressure : PressureValue;
    }
    
    part def Pipe {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute geometry : PipeGeometry;
        attribute frictionFactor : Real;
    }
    
    part def Valve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute openingPercentage : Real;
        attribute flowCoefficient : Real;
    }
    
    part def FlowSensor {
        port measurementPort : FluidPort;
        out attribute measuredFlowRate : VolumeFlowRateValue;
        out attribute measuredPressure : PressureValue;
    }
    
    part def PressureRegulator {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute targetPressure : PressureValue;
        attribute currentPressure : PressureValue;
    }
    
    action def CalculateReynoldsNumber {
        in velocity : SpeedValue;
        in diameter : LengthValue;
        in density : DensityValue;
        in viscosity : DynamicViscosityValue;
        out reynoldsNumber : Real;
    }
    
    action def CalculatePressureDrop {
        in flowRate : VolumeFlowRateValue;
        in pipeGeometry : PipeGeometry;
        in fluidProps : FluidProperties;
        in frictionFactor : Real;
        out pressureDrop : PressureValue;
    }
    
    action def DetermineFrictionFactor {
        in reynoldsNumber : Real;
        in relativeRoughness : Real;
        out frictionFactor : Real;
    }
    
    action def ComputeFlowDynamics {
        in inputFlowState : FlowState;
        in pipeGeometry : PipeGeometry;
        in fluidProps : FluidProperties;
        out outputFlowState : FlowState;
        
        first start;
        then action calcReynolds : CalculateReynoldsNumber {
            in velocity = inputFlowState.velocity;
            in diameter = pipeGeometry.diameter;
            in density = fluidProps.density;
            in viscosity = fluidProps.viscosity;
            out reynoldsNumber;
        }
        then action calcFriction : DetermineFrictionFactor {
            in reynoldsNumber = calcReynolds.reynoldsNumber;
            in relativeRoughness = pipeGeometry.roughness / pipeGeometry.diameter;
            out frictionFactor;
        }
        then action calcPressureDrop : CalculatePressureDrop {
            in flowRate = inputFlowState.volumetricFlowRate;
            in pipeGeometry = pipeGeometry;
            in fluidProps = fluidProps;
            in frictionFactor = calcFriction.frictionFactor;
            out pressureDrop;
        }
        then assign outputFlowState := FlowState {
            velocity = inputFlowState.velocity;
            pressure = inputFlowState.pressure - calcPressureDrop.pressureDrop;
            volumetricFlowRate = inputFlowState.volumetricFlowRate;
        }
        then done;
    }
    
    state def FlowRegulationStates {
        entry; then idle;
        
        state idle;
        transition idle_to_monitoring
            first idle
            then monitoring;
        
        state monitoring;
        transition monitoring_to_adjusting
            first monitoring
            then adjusting;
        
        state adjusting;
        transition adjusting_to_monitoring
            first adjusting
            then monitoring;
        
        transition monitoring_to_idle
            first monitoring
            then idle;
    }
    
    requirement def FluidSystemRequirements {
        doc /* The fluid dynamics system shall maintain stable flow conditions 
               and regulate pressure within specified operational limits. */
        
        requirement <'1'> maintainFlowRate {
            doc /* The system shall maintain volumetric flow rate within 
                   plus or minus 5 percent of the target flow rate. */
        }
        
        requirement <'2'> regulatePressure {
            doc /* The system shall regulate outlet pressure to within 
                   plus or minus 2 percent of the target pressure. */
        }
        
        requirement <'3'> minimizePressureLoss {
            doc /* The system shall minimize pressure losses through 
                   efficient pipe routing and component selection. */
        }
        
        requirement <'4'> respondToDisturbances {
            doc /* The system shall respond to flow disturbances within 
                   2 seconds to restore stable operation. */
        }
    }
    
    part def FluidDynamicsSystem {
        doc /* This system manages the transport and regulation of fluid flow 
               through a network of interconnected components. Its primary function 
               is to maintain stable fluid flow conditions while regulating pressure 
               and flow rate according to specified operational requirements. 
               
               The system continuously monitors fluid properties and flow states, 
               calculates dynamic flow parameters including Reynolds number and 
               friction factors, and actively adjusts control elements to compensate 
               for pressure drops and flow variations throughout the distribution network. */
        
        attribute operatingFluid : Fluid {
            attribute properties : FluidProperties {
                attribute density = 1000.0 [SI::kg/(SI::m^3)];
                attribute viscosity = 0.001 [SI::Pa*SI::s];
                attribute temperature = 293.15 [SI::K];
            }
        }
        
        part mainPump : Pump {
            attribute powerInput = 5000.0 [SI::W];
            attribute efficiency = 0.85;
            attribute headPressure = 300000.0 [SI::Pa];
        }
        
        part supplyPipe : Pipe {
            attribute geometry : PipeGeometry {
                attribute diameter = 0.1 [SI::m];
                attribute length = 50.0 [SI::m];
                attribute roughness = 0.000045 [SI::m];
            }
            attribute frictionFactor = 0.02;
        }
        
        part controlValve : Valve {
            attribute openingPercentage = 75.0;
            attribute flowCoefficient = 120.0;
        }
        
        part flowMeter : FlowSensor;
        
        part pressureControl : PressureRegulator {
            attribute targetPressure = 250000.0 [SI::Pa];
            attribute currentPressure = 250000.0 [SI::Pa];
        }
        
        part returnPipe : Pipe {
            attribute geometry : PipeGeometry {
                attribute diameter = 0.08 [SI::m];
                attribute length = 45.0 [SI::m];
                attribute roughness = 0.000045 [SI::m];
            }
            attribute frictionFactor = 0.021;
        }
        
        connect mainPump.outlet to supplyPipe.inlet;
        connect supplyPipe.outlet to controlValve.inlet;
        connect controlValve.outlet to pressureControl.inlet;
        connect pressureControl.outlet to flowMeter.measurementPort;
        connect flowMeter.measurementPort to returnPipe.inlet;
        
        perform action regulateFlow[*] ordered {
            first start;
            then merge continuousRegulation;
            then action measureFlow {
                out currentFlowRate : VolumeFlowRateValue;
                out currentPressure : PressureValue;
            }
            then action computeDynamics : ComputeFlowDynamics {
                in inputFlowState;
                in pipeGeometry = supplyPipe.geometry;
                in fluidProps = operatingFluid.properties;
                out outputFlowState;
            }
            then decide;
                if computeDynamics.outputFlowState.pressure < pressureControl.targetPressure * 0.98 
                    then increaseFlow;
                if computeDynamics.outputFlowState.pressure > pressureControl.targetPressure * 1.02 
                    then decreaseFlow;
                if computeDynamics.outputFlowState.pressure >= pressureControl.targetPressure * 0.98 
                    and computeDynamics.outputFlowState.pressure <= pressureControl.targetPressure * 1.02 
                    then maintainFlow;
            
            action increaseFlow {
                then assign controlValve.openingPercentage := controlValve.openingPercentage + 5.0;
            }
            then continuousRegulation;
            
            action decreaseFlow {
                then assign controlValve.openingPercentage := controlValve.openingPercentage - 5.0;
            }
            then continuousRegulation;
            
            action maintainFlow;
            then continuousRegulation;
        }
        
        satisfy FluidSystemRequirements::maintainFlowRate;
        satisfy FluidSystemRequirements::regulatePressure;
        satisfy FluidSystemRequirements::minimizePressureLoss;
        satisfy FluidSystemRequirements::respondToDisturbances;
    }
    
    part fluidDynamicsSystem : FluidDynamicsSystem;
}
