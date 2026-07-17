package 'Slurry Transport and Processing System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def SolidsFraction :> Real;
    attribute def ParticleSize :> ISQ::LengthValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def Pressure :> ISQ::PressureValue;
    attribute def Viscosity :> ISQ::DynamicViscosityValue;
    attribute def Density :> ISQ::DensityValue;
    attribute def Temperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def Power :> ISQ::PowerValue;
    
    attribute def StartCommand;
    attribute def StopCommand;
    attribute def EmergencyStopCommand;
    attribute def ResetCommand;
    
    item def Slurry {
        attribute solidsFraction : SolidsFraction;
        attribute particleSize : ParticleSize;
        attribute viscosity : Viscosity;
        attribute density : Density;
        attribute temperature : Temperature;
    }
    
    item def SlurryFlow {
        attribute slurry : Slurry;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }
    
    port def SlurryInletPort {
        in item slurryIn : SlurryFlow;
    }
    
    port def SlurryOutletPort {
        out item slurryOut : SlurryFlow;
    }
    
    port def ControlPort {
        in attribute command;
        out attribute status : Boolean;
        out attribute currentFlowRate : FlowRate;
        out attribute currentPressure : Pressure;
    }
    
    part def MixingVessel {
        doc /* Vessel for combining solid particles with liquid to create slurry */
        
        port solidInput : SlurryInletPort;
        port liquidInput : SlurryInletPort;
        port slurryOutput : SlurryOutletPort;
        port control : ControlPort;
        
        attribute vesselVolume : ISQ::VolumeValue;
        attribute mixingSpeed : ISQ::AngularVelocityValue;
        attribute currentLevel : ISQ::LengthValue;
        
        action def Mix {
            in solidFeed : SlurryFlow;
            in liquidFeed : SlurryFlow;
            out mixedSlurry : SlurryFlow;
        }
    }
    
    part def SlurryPump {
        doc /* Centrifugal pump for transporting slurry through pipeline */
        
        port inlet : SlurryInletPort;
        port outlet : SlurryOutletPort;
        port control : ControlPort;
        
        attribute ratedPower : Power;
        attribute maxPressure : Pressure;
        attribute efficiency : Real;
        attribute impellerDiameter : ISQ::LengthValue;
        
        action def PumpSlurry {
            in inletFlow : SlurryFlow;
            out outletFlow : SlurryFlow;
            out powerConsumption : Power;
        }
    }
    
    part def Pipeline {
        doc /* Pipeline for conveying slurry from source to destination */
        
        port inlet : SlurryInletPort;
        port outlet : SlurryOutletPort;
        
        attribute pipeLength : ISQ::LengthValue;
        attribute pipeDiameter : ISQ::LengthValue;
        attribute roughness : ISQ::LengthValue;
        
        action def TransportSlurry {
            in inletFlow : SlurryFlow;
            out outletFlow : SlurryFlow;
            out pressureDrop : Pressure;
        }
    }
    
    part def ViscosityMonitor {
        doc /* Inline sensor for monitoring slurry viscosity */
        
        port slurryInput : SlurryInletPort;
        port slurryOutput : SlurryOutletPort;
        
        attribute measuredViscosity : Viscosity;
        attribute measurementAccuracy : Real;
        
        action def MeasureViscosity {
            in slurryFlow : SlurryFlow;
            out viscosity : Viscosity;
        }
    }
    
    part def FlowMeter {
        doc /* Flow measurement device for slurry flow rate */
        
        port slurryInput : SlurryInletPort;
        port slurryOutput : SlurryOutletPort;
        
        attribute measuredFlowRate : FlowRate;
        attribute measurementRange : FlowRate;
        
        action def MeasureFlow {
            in slurryFlow : SlurryFlow;
            out flowRate : FlowRate;
        }
    }
    
    part def PressureSensor {
        doc /* Pressure transducer for monitoring pipeline pressure */
        
        attribute measuredPressure : Pressure;
        attribute maxPressure : Pressure;
        
        action def MeasurePressure {
            in slurryFlow : SlurryFlow;
            out pressure : Pressure;
        }
    }
    
    part def ControlSystem {
        doc /* Automated control system for slurry transport operations */
        
        port pumpControl : ControlPort;
        port mixerControl : ControlPort;
        port operatorInterface;
        
        attribute targetFlowRate : FlowRate;
        attribute targetViscosity : Viscosity;
        attribute maxAllowablePressure : Pressure;
        
        exhibit state controlLogic : SlurryControlStateMachine;
    }
    
    state def SlurryControlStateMachine {
        entry; then idle;
        
        state idle {
            doc /* System is stopped and ready to start */
        }
        transition idleToStartup
            accept StartCommand
            then startup;
        
        state startup {
            doc /* System is starting up and initializing */
            entry action initializePump;
            entry action initializeMixer;
        }
        transition startupToNormal
            if systemReady
            then normalOperation;
        
        state normalOperation {
            doc /* System is operating under normal conditions */
            
            state monitoring {
                do action monitorViscosity;
                do action monitorFlowRate;
                do action monitorPressure;
            }
            
            state controlling {
                do action adjustPumpSpeed;
                do action adjustMixingSpeed;
            }
        }
        transition normalToAlarm
            if pressureExceeded
            then alarm;
        transition normalToShutdown
            accept StopCommand
            then shutdown;
        
        state alarm {
            doc /* System has detected abnormal condition */
            entry action reduceFlowRate;
        }
        transition alarmToNormal
            if pressureNormal
            then normalOperation;
        transition alarmToEmergency
            accept EmergencyStopCommand
            then emergencyShutdown;
        
        state shutdown {
            doc /* System is performing controlled shutdown */
            entry action stopPump;
            entry action stopMixer;
        }
        transition shutdownToIdle
            then idle;
        
        state emergencyShutdown {
            doc /* System is performing emergency shutdown */
            entry action emergencyStopPump;
            entry action emergencyStopMixer;
            entry action closeValves;
        }
        transition emergencyToIdle
            accept ResetCommand
            then idle;
        
        action def initializePump;
        action def initializeMixer;
        action def monitorViscosity;
        action def monitorFlowRate;
        action def monitorPressure;
        action def adjustPumpSpeed;
        action def adjustMixingSpeed;
        action def reduceFlowRate;
        action def stopPump;
        action def stopMixer;
        action def emergencyStopPump;
        action def emergencyStopMixer;
        action def closeValves;
    }
    
    action def TransportSlurry {
        doc /* Primary system function: transport slurry from mixing vessel to destination */
        
        in startSignal : StartCommand;
        in stopSignal : StopCommand;
        in solidFeed : SlurryFlow;
        in liquidFeed : SlurryFlow;
        out deliveredSlurry : SlurryFlow;
        
        first start;
        then merge continuousOperation;
        
        then action mixingStep : MixingVessel::Mix {
            in solidFeed = solidFeed;
            in liquidFeed = liquidFeed;
            out mixedSlurry : SlurryFlow;
        }
        
        flow mixingStep.mixedSlurry to viscosityCheck.slurryFlow;
        
        action viscosityCheck : ViscosityMonitor::MeasureViscosity {
            in slurryFlow : SlurryFlow;
            out viscosity : Viscosity;
        }
        
        then decide;
            if viscosityCheck.viscosity < targetViscosity then adjustMixing;
            if viscosityCheck.viscosity >= targetViscosity then pumpingStep;
        
        action adjustMixing {
            doc /* Adjust mixing parameters to achieve target viscosity */
        }
        then continuousOperation;
        
        flow viscosityCheck.slurryFlow to pumpingStep.inletFlow;
        
        action pumpingStep : SlurryPump::PumpSlurry {
            in inletFlow : SlurryFlow;
            out outletFlow : SlurryFlow;
            out powerConsumption : Power;
        }
        
        flow pumpingStep.outletFlow to flowMeasurement.slurryFlow;
        
        action flowMeasurement : FlowMeter::MeasureFlow {
            in slurryFlow : SlurryFlow;
            out flowRate : FlowRate;
        }
        
        flow flowMeasurement.slurryFlow to transportStep.inletFlow;
        
        action transportStep : Pipeline::TransportSlurry {
            in inletFlow : SlurryFlow;
            out outletFlow : SlurryFlow;
            out pressureDrop : Pressure;
        }
        
        then assign deliveredSlurry := transportStep.outletFlow;
        then continuousOperation;
    }
    
    requirement def PrimaryFunctionRequirement {
        doc /* The slurry transport system shall continuously mix solid particles with liquid 
               to form slurry and transport it through a pipeline to the destination point. */
        
        require constraint mixingCapability {
            doc /* The system shall mix solid particles with liquid to create homogeneous slurry. */
        }
        
        require constraint transportCapability {
            doc /* The system shall transport slurry from source to destination via pipeline. */
        }
        
        require constraint continuousOperation {
            doc /* The system shall operate continuously during normal operation mode. */
        }
    }
    
    requirement def PerformanceRequirement {
        doc /* The slurry transport system shall meet specified performance criteria. */
        
        attribute minimumFlowRate : FlowRate = 0.05 [SI::m^3/SI::s];
        attribute maximumPressure : Pressure = 2000000.0 [SI::Pa];
        attribute targetViscosity : Viscosity = 0.1 [SI::Pa*SI::s];
        
        require constraint flowRateRequirement {
            doc /* The system shall maintain flow rate at or above minimum specified value. */
        }
        
        require constraint pressureRequirement {
            doc /* The system pressure shall not exceed maximum allowable pressure. */
        }
        
        require constraint viscosityRequirement {
            doc /* The slurry viscosity shall be maintained within specified tolerance. */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* The slurry transport system shall operate safely under all conditions. */
        
        require constraint pressureProtection {
            doc /* The system shall automatically reduce flow rate if pressure exceeds safe limit. */
        }
        
        require constraint emergencyStop {
            doc /* The system shall provide emergency stop capability to halt all operations. */
        }
        
        require constraint overpressureShutdown {
            doc /* The system shall shut down if pressure exceeds maximum rated pressure. */
        }
    }
    
    part slurryTransportSystem {
        doc /* A slurry transport and processing system that mixes solid particles with liquid 
               to create slurry and transports it through a pipeline network. The system 
               continuously monitors slurry properties including viscosity, flow rate, and 
               pressure, automatically adjusting operating parameters to maintain optimal 
               transport conditions while ensuring safe operation within design limits. */
        
        part mixer : MixingVessel {
            attribute :>> vesselVolume = 10.0 [SI::m^3];
            attribute :>> mixingSpeed = 2.0 [SI::rad/SI::s];
        }
        
        part mainPump : SlurryPump {
            attribute :>> ratedPower = 75000.0 [SI::W];
            attribute :>> maxPressure = 2500000.0 [SI::Pa];
            attribute :>> efficiency = 0.75;
        }
        
        part transportPipeline : Pipeline {
            attribute :>> pipeLength = 500.0 [SI::m];
            attribute :>> pipeDiameter = 0.3 [SI::m];
        }
        
        part viscositySensor : ViscosityMonitor {
            attribute :>> measurementAccuracy = 0.02;
        }
        
        part flowSensor : FlowMeter {
            attribute :>> measurementRange = 0.1 [SI::m^3/SI::s];
        }
        
        part pressureSensor : PressureSensor {
            attribute :>> maxPressure = 3000000.0 [SI::Pa];
        }
        
        part controller : ControlSystem {
            attribute :>> targetFlowRate = 0.05 [SI::m^3/SI::s];
            attribute :>> targetViscosity = 0.1 [SI::Pa*SI::s];
            attribute :>> maxAllowablePressure = 2000000.0 [SI::Pa];
        }
        
        connection mixerToViscosity : FlowConnection connect 
            mixer.slurryOutput to viscositySensor.slurryInput;
        
        connection viscosityToPump : FlowConnection connect 
            viscositySensor.slurryOutput to mainPump.inlet;
        
        connection pumpToFlow : FlowConnection connect 
            mainPump.outlet to flowSensor.slurryInput;
        
        connection flowToPipeline : FlowConnection connect 
            flowSensor.slurryOutput to transportPipeline.inlet;
        
        connection controlToPump : ControlConnection connect 
            controller.pumpControl to mainPump.control;
        
        connection controlToMixer : ControlConnection connect 
            controller.mixerControl to mixer.control;
        
        perform action transportOperation : TransportSlurry;
        
        exhibit state systemState : SlurryControlStateMachine;
        
        satisfy primaryFunction : PrimaryFunctionRequirement;
        satisfy performance : PerformanceRequirement;
        satisfy safety : SafetyRequirement;
    }
    
    connection def FlowConnection {
        end source : SlurryOutletPort;
        end target : SlurryInletPort;
    }
    
    connection def ControlConnection {
        end controller : ControlPort;
        end controlled : ControlPort;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Slurry Transport and Processing System'::*;

    part testSubject = slurryTransportSystem {
        exhibit state sm : SlurryControlStateMachine;
    }

    action orchestrator {
        item testSlurryFlow : SlurryFlow {
            item slurry : Slurry {
                attribute solidsFraction : SolidsFraction = 0.0;
                attribute particleSize : ParticleSize;
                attribute viscosity : Viscosity;
                attribute density : Density;
                attribute temperature : Temperature;
            }
            attribute flowRate : FlowRate;
            attribute pressure : Pressure;
        }
        action viscosityCheckProbe : ViscosityMonitor {
            in slurryFlow = testSlurryFlow;
        }
        first viscosityCheckProbe;
    }
}
