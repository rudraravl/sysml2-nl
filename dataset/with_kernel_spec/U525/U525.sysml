package HighPressureInjectionPumpSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    
    public import Definitions::*;
    public import Usages::*;
    
    package Definitions {
        item def Fluid;
        
        attribute def PressureValue :> ScalarValues::Real;
        attribute def FlowRateValue :> ScalarValues::Real;
        attribute def MotorSpeedValue :> ScalarValues::Real;
        
        attribute def StartCommand;
        attribute def PrimingComplete;
        attribute def FlushCommand;
        attribute def FlushComplete;
        attribute def FaultCondition;
        attribute def ResetCommand;
        
        port def FluidPort {
            out item fluid: Fluid;
        }
        
        port def PressureSignalPort {
            out attribute pressure: PressureValue;
        }
        
        port def FlowSignalPort {
            out attribute flowRate: FlowRateValue;
        }
        
        port def ControlSignalPort {
            out attribute motorSpeed: MotorSpeedValue;
        }
        
        part def Reservoir {
            port fluidOutPort: FluidPort;
            port fluidReturnPort: ~FluidPort;
        }
        
        part def Motor {
            attribute speed: MotorSpeedValue;
        }
        part def Plunger;
        part def Cam;
        part def Valve;
        
        part def InjectionPump {
            part motor: Motor;
            part plunger: Plunger;
            part cam: Cam;
            part valve: Valve;
            port fluidInPort: ~FluidPort;
            port fluidOutPort: FluidPort;
            port controlPort: ~ControlSignalPort;
            
            attribute currentPressure: PressureValue;
            attribute currentFlowRate: FlowRateValue;
            
            perform action pumpFluid: PumpFluid;
        }
        
        part def DischargeManifold {
            port fluidInPort: ~FluidPort;
            port fluidOutPort: FluidPort;
            port reliefPort: FluidPort;
        }
        
        part def ReliefValve {
            port fluidInPort: ~FluidPort;
            port fluidOutPort: FluidPort;
            attribute pressureThreshold: PressureValue;
        }
        
        part def PressureTransducer {
            port fluidInPort: ~FluidPort;
            port fluidOutPort: FluidPort;
            port signalOutPort: PressureSignalPort;
            attribute measuredPressure: PressureValue;
        }
        
        part def FlowMeter {
            port fluidInPort: ~FluidPort;
            port fluidOutPort: FluidPort;
            port signalOutPort: FlowSignalPort;
            attribute measuredFlowRate: FlowRateValue;
        }
        
        part def PumpController {
            port targetPressurePort: ~PressureSignalPort;
            port targetFlowRatePort: ~FlowSignalPort;
            port suctionSensorPort: ~PressureSignalPort;
            port dischargeSensorPort: ~PressureSignalPort;
            port flowSensorPort: ~FlowSignalPort;
            port controlOutPort: ControlSignalPort;
            perform action pidControl: PIDControl;
        }
        
        action def PumpFluid {
            in fluidIn: Fluid;
            out fluidOut: Fluid;
        }
        
        action def PIDControl {
            in targetPressure: PressureValue;
            in targetFlowRate: FlowRateValue;
            in actualPressure: PressureValue;
            in actualFlowRate: FlowRateValue;
            out motorSpeed: MotorSpeedValue;
        }
        
        state def PumpStates;
        
        requirement def PerformanceRequirements {
            subject pump: InjectionPump;
            attribute requiredFlowRate: FlowRateValue;
            attribute requiredPressure: PressureValue;
            require constraint { pump.currentFlowRate >= requiredFlowRate }
            require constraint { pump.currentPressure >= requiredPressure }
        }
        
        requirement def SafetyRequirements {
            subject valve: ReliefValve;
            attribute maxPressure: PressureValue;
            require constraint { valve.pressureThreshold <= maxPressure }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part subsystem {
            part reservoir: Reservoir;
            part suctionTransducer: PressureTransducer;
            part pump: InjectionPump;
            part dischargeTransducer: PressureTransducer;
            part manifold: DischargeManifold;
            part flowMeter: FlowMeter;
            part reliefValve: ReliefValve;
            part controller: PumpController;
            
            flow of fluid : Fluid from reservoir.fluidOutPort.fluid to suctionTransducer.fluidInPort.fluid;
            flow of fluid : Fluid from suctionTransducer.fluidOutPort.fluid to pump.fluidInPort.fluid;
            flow of fluid : Fluid from pump.fluidOutPort.fluid to dischargeTransducer.fluidInPort.fluid;
            flow of fluid : Fluid from dischargeTransducer.fluidOutPort.fluid to manifold.fluidInPort.fluid;
            flow of fluid : Fluid from manifold.fluidOutPort.fluid to flowMeter.fluidInPort.fluid;
            flow of fluid : Fluid from manifold.reliefPort.fluid to reliefValve.fluidInPort.fluid;
            flow of fluid : Fluid from reliefValve.fluidOutPort.fluid to reservoir.fluidReturnPort.fluid;
            
            connect suctionTransducer.signalOutPort to controller.suctionSensorPort;
            connect dischargeTransducer.signalOutPort to controller.dischargeSensorPort;
            connect flowMeter.signalOutPort to controller.flowSensorPort;
            connect controller.controlOutPort to pump.controlPort;
            
            exhibit state pumpStates: PumpStates {
                entry; then idle;
                state idle;
                accept StartCommand then priming;
                state priming;
                accept PrimingComplete then pumping;
                state pumping {
                    do pump.pumpFluid;
                }
                accept FlushCommand then flushing;
                accept FaultCondition then fault;
                state flushing;
                accept FlushComplete then idle;
                state fault;
                accept ResetCommand then idle;
            }
            
            requirement performanceReqs : PerformanceRequirements {
                subject = pump;
                attribute requiredFlowRate = 0.0001;
                attribute requiredPressure = 100000000;
            }
            
            requirement safetyReqs : SafetyRequirements {
                subject = reliefValve;
                attribute maxPressure = 120000000;
            }
        }
    }
}
