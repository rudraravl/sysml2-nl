package SuperfluiditySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def ViscosityValue :> ISQ::DynamicViscosityValue;
    attribute def VelocityValue :> ISQ::SpeedValue;
    attribute def DensityValue :> ISQ::MassDensityValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def FlowRateValue :> ISQ::VolumeFlowRateValue;
    attribute def PowerValue :> ISQ::PowerValue;
    attribute def LengthValue :> ISQ::LengthValue;
    attribute def VolumeValue :> ISQ::VolumeValue;
    
    attribute def SuperfluidState {
        attribute temperature : TemperatureValue;
        attribute viscosity : ViscosityValue;
        attribute density : DensityValue;
        attribute isSuperfluid : Boolean;
        attribute normalFraction : Real;
        attribute superfluidFraction : Real;
    }
    
    attribute def FlowCommand {
        attribute targetFlowRate : FlowRateValue;
        attribute targetPressure : PressureValue;
    }
    
    attribute def CoolingCommand {
        attribute targetTemperature : TemperatureValue;
        attribute coolingPower : PowerValue;
    }
    
    item def SuperfluidHelium {
        attribute fluidState : SuperfluidState;
        attribute criticalTemperature : TemperatureValue;
    }
    
    port def SuperfluidPort {
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        item fluid : SuperfluidHelium;
    }
    
    port def CryogenicPort {
        attribute coolingPower : PowerValue;
        attribute temperature : TemperatureValue;
    }
    
    port def SensorPort {
        out attribute temperature : TemperatureValue;
        out attribute pressure : PressureValue;
        out attribute flowRate : FlowRateValue;
    }
    
    part def CryogenicCooler {
        doc /* Cools helium below lambda transition temperature to induce superfluidity. */
        
        port cryoPort : CryogenicPort;
        port fluidIn : SuperfluidPort;
        port fluidOut : SuperfluidPort;
        
        attribute operatingTemperature : TemperatureValue;
        attribute coolingCapacity : PowerValue;
        attribute minTemperature : TemperatureValue;
        
        action coolFluid {
            in coolingCmd : CoolingCommand;
            in inletFluid : SuperfluidHelium;
            out outletFluid : SuperfluidHelium;
            out achievedTemperature : TemperatureValue;
        }
    }
    
    part def HeliumReservoir {
        doc /* Stores liquid helium and maintains superfluid phase. */
        
        port fluidPort : SuperfluidPort;
        port thermalPort : CryogenicPort;
        
        attribute volume : VolumeValue;
        attribute currentTemperature : TemperatureValue;
        attribute heliumDensity : DensityValue;
        attribute currentState : SuperfluidState;
        
        action maintainState {
            in temperature : TemperatureValue;
            in pressure : PressureValue;
            out fluidState : SuperfluidState;
        }
    }
    
    part def TemperatureSensor {
        doc /* Monitors temperature to ensure superfluid phase is maintained. */
        
        port sensorPort : SensorPort;
        
        attribute accuracy : TemperatureValue;
        attribute responseTime : ISQ::TimeValue;
        
        action measureTemperature {
            in fluidState : SuperfluidState;
            out temperature : TemperatureValue;
        }
    }
    
    part def FlowController {
        doc /* Regulates superfluid flow with zero viscous resistance. */
        
        port inlet : SuperfluidPort;
        port outlet : SuperfluidPort;
        port controlPort;
        
        attribute flowResistance : Real;
        attribute maxFlowRate : FlowRateValue;
        
        action regulateFlow {
            in flowCmd : FlowCommand;
            in currentState : SuperfluidState;
            out actualFlowRate : FlowRateValue;
        }
    }
    
    part def PersistentCurrentLoop {
        doc /* Demonstrates persistent flow without energy dissipation. */
        
        port loopPort : SuperfluidPort;
        
        attribute loopDiameter : LengthValue;
        attribute currentVelocity : VelocityValue;
        attribute angularMomentum : ISQ::AngularMomentumValue;
        attribute circulationQuantum : Real;
        
        action maintainPersistentFlow {
            in initialVelocity : VelocityValue;
            out sustainedVelocity : VelocityValue;
        }
    }
    
    part def QuantumVortexDetector {
        doc /* Detects quantized vortices in superfluid. */
        
        attribute vortexDensity : Real;
        attribute detectionThreshold : Real;
        
        action detectVortices {
            in fluidState : SuperfluidState;
            out vortexCount : Integer;
            out vortexDensity : Real;
        }
    }
    
    part def SystemController {
        doc /* Controls cooling and flow to maintain superfluid operation. */
        
        port temperatureInput : SensorPort;
        port pressureInput : SensorPort;
        
        attribute targetTemperature : TemperatureValue;
        attribute targetFlowRate : FlowRateValue;
        attribute criticalTemperature : TemperatureValue;
        
        action controlSystem {
            in currentTemp : TemperatureValue;
            in currentPressure : PressureValue;
            out coolingCmd : CoolingCommand;
            out flowCmd : FlowCommand;
        }
    }
    
    action def MonitorTemperature {
        in currentTemp : TemperatureValue;
        in criticalTemp : TemperatureValue;
        out isBelowCritical : Boolean;
        out temperatureMargin : TemperatureValue;
    }
    
    action def InitiateCooling {
        in targetTemp : TemperatureValue;
        in currentTemp : TemperatureValue;
        out coolingPower : PowerValue;
    }
    
    action def EstablishSuperfluidPhase {
        in temperature : TemperatureValue;
        in pressure : PressureValue;
        out superfluidState : SuperfluidState;
    }
    
    action def EnableZeroViscosityFlow {
        in superfluidState : SuperfluidState;
        in flowCommand : FlowCommand;
        out flowRate : FlowRateValue;
    }
    
    action def MaintainQuantumCoherence {
        in currentState : SuperfluidState;
        out coherenceQuality : Real;
    }
    
    action def OperateSuperfluidSystem {
        doc /* Main operational cycle for superfluidity system. */
        
        in targetTemperature : TemperatureValue;
        in targetFlowRate : FlowRateValue;
        in criticalTemperature : TemperatureValue;
        out systemState : SuperfluidState;
        out achievedFlowRate : FlowRateValue;
        
        private attribute currentTemp : TemperatureValue;
        private attribute currentState : SuperfluidState;
        
        first start;
        then merge monitoringLoop;
        
        then action monitor : MonitorTemperature {
            in currentTemp = currentTemp;
            in criticalTemp = criticalTemperature;
            out isBelowCritical : Boolean;
            out temperatureMargin : TemperatureValue;
        }
        
        then decide;
            if !monitor.isBelowCritical then initiateCooling;
            if monitor.isBelowCritical then establishPhase;
        
        action initiateCooling : InitiateCooling {
            in targetTemp = targetTemperature;
            in currentTemp = currentTemp;
            out coolingPower : PowerValue;
        }
        then assign currentTemp := targetTemperature;
        then monitoringLoop;
        
        action establishPhase : EstablishSuperfluidPhase {
            in temperature = currentTemp;
            in pressure : PressureValue;
            out superfluidState : SuperfluidState;
        }
        
        then action enableFlow : EnableZeroViscosityFlow {
            in superfluidState = establishPhase.superfluidState;
            in flowCommand : FlowCommand;
            out flowRate : FlowRateValue;
        }
        
        then action maintainCoherence : MaintainQuantumCoherence {
            in currentState = establishPhase.superfluidState;
            out coherenceQuality : Real;
        }
        
        then assign systemState := establishPhase.superfluidState;
        then assign achievedFlowRate := enableFlow.flowRate;
        then assign currentState := establishPhase.superfluidState;
        
        then monitoringLoop;
    }
    
    state def SuperfluidLifecycle {
        doc /* Lifecycle states of superfluid system operation. */
        
        entry; then initialization;
        
        state initialization;
        
        state cooling {
            doc /* System is actively cooling helium toward lambda point. */
        }
        
        state lambdaTransition {
            doc /* Helium is transitioning through lambda point to superfluid phase. */
        }
        
        state superfluidOperation {
            doc /* System is operating in superfluid regime with zero viscosity. */
        }
        
        state warmup {
            doc /* System is warming up, losing superfluid properties. */
        }
        
        state shutdown;
        
        transition t1 first initialization then cooling;
        transition t2 first cooling then lambdaTransition;
        transition t3 first lambdaTransition then superfluidOperation;
        transition t4 first superfluidOperation then warmup;
        transition t5 first warmup then cooling;
        transition t6 first superfluidOperation then shutdown;
        transition t7 first cooling then shutdown;
    }
    
    requirement def SuperfluidPerformanceRequirement {
        doc /* The system shall achieve and maintain superfluid state below critical temperature. */
        
        subject system : SuperfluidSystem;
        
        require constraint criticalTemperatureConstraint {
            doc /* Operating temperature must be below lambda point for helium-4. */
        }
        
        require constraint zeroViscosityConstraint {
            doc /* Fluid viscosity shall approach zero in superfluid phase. */
        }
        
        require constraint persistentFlowConstraint {
            doc /* Flow shall persist without energy input once established. */
        }
    }
    
    requirement def QuantumCoherenceRequirement {
        doc /* The system shall maintain macroscopic quantum coherence. */
        
        subject system : SuperfluidSystem;
        
        require constraint vortexQuantizationConstraint {
            doc /* Vortices shall exhibit quantized circulation. */
        }
        
        require constraint phaseCoherenceConstraint {
            doc /* Quantum phase coherence shall be maintained across fluid volume. */
        }
    }
    
    requirement def OperationalSafetyRequirement {
        doc /* The system shall operate safely within cryogenic temperature ranges. */
        
        subject system : SuperfluidSystem;
        
        require constraint temperatureMonitoring {
            doc /* Temperature shall be continuously monitored. */
        }
        
        require constraint coolingCapacity {
            doc /* Cooling system shall maintain sufficient capacity. */
        }
    }
    
    part def SuperfluidSystem {
        doc /* 
            A superfluidity-based system that exploits quantum mechanical effects 
            to achieve zero-viscosity fluid flow and persistent currents in helium-4.
            
            The system's primary function is to establish and maintain a superfluid 
            phase of helium-4 below its lambda transition temperature of 2.17 Kelvin, 
            enabling frictionless flow and macroscopic quantum phenomena.
            
            Operation begins by cooling liquid helium using a cryogenic cooler. 
            As temperature decreases below the lambda point, helium undergoes a 
            second-order phase transition to a superfluid state characterized by 
            zero viscosity and infinite thermal conductivity. The system continuously 
            monitors temperature through precision sensors to ensure maintenance 
            below the critical threshold.
            
            Once the superfluid phase is established, the flow controller can 
            initiate and regulate fluid circulation without viscous resistance. 
            The persistent current loop demonstrates the remarkable property that 
            superfluid flow, once initiated, continues indefinitely without energy 
            input, limited only by maintenance of the low temperature environment.
            
            The quantum vortex detector monitors formation of quantized vortices, 
            which are topological defects characteristic of superfluid dynamics. 
            These vortices have circulation quantized in units of h/m, where h is 
            Planck's constant and m is the helium atom mass.
            
            This system enables applications in precision gyroscopes, quantum 
            computing, ultra-sensitive accelerometers, and fundamental physics 
            research by providing a macroscopic manifestation of quantum mechanical 
            behavior observable at the human scale.
        */
        
        part cooler : CryogenicCooler;
        
        part reservoir : HeliumReservoir;
        
        part flowController : FlowController;
        
        part currentLoop : PersistentCurrentLoop;
        
        part vortexDetector : QuantumVortexDetector;
        
        part tempSensor : TemperatureSensor;
        
        part controller : SystemController;
        
        part lifecycle : SuperfluidLifecycle;
        
        connection coolerToReservoir connect cooler.fluidOut to reservoir.fluidPort;
        connection reservoirToFlowControl connect reservoir.fluidPort to flowController.inlet;
        connection flowControlToLoop connect flowController.outlet to currentLoop.loopPort;
        connection loopToCooler connect currentLoop.loopPort to cooler.fluidIn;
        connection sensorToReservoir connect tempSensor.sensorPort to reservoir.fluidPort;
        connection sensorToController connect tempSensor.sensorPort to controller.temperatureInput;
        
        perform action operateSystem : OperateSuperfluidSystem;
        
        satisfy performanceReq : SuperfluidPerformanceRequirement;
        satisfy coherenceReq : QuantumCoherenceRequirement;
        satisfy safetyReq : OperationalSafetyRequirement;
    }
}
