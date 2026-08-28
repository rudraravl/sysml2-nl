package 'FluidFlowControlSystem' {
    private import ScalarValues::*;
    
    public import Definitions::*;
    
    package Definitions {
        item def Fluid;
        
        attribute def PressureValue :> ScalarValues::Real;
        attribute def VelocityValue :> ScalarValues::Real;
        attribute def VolumeFlowRateValue :> ScalarValues::Real;
        attribute def ValvePositionValue :> ScalarValues::Real;
        attribute def AreaValue :> ScalarValues::Real;
        
        attribute def StartCommand;
        attribute def SystemReady;
        attribute def ShutdownCommand;
        attribute def ShutdownComplete;
        attribute def ResetCommand;
        
        item def PressureReading {
            attribute value : PressureValue;
        }
        item def VelocityReading {
            attribute value : VelocityValue;
        }
        item def ValveCommand {
            attribute position : ValvePositionValue;
        }
        
        port def FluidPort {
            out item fluid : Fluid;
        }
        port def PressureSensorPort {
            out reading : PressureReading;
        }
        port def VelocitySensorPort {
            out reading : VelocityReading;
        }
        port def ValveCommandPort {
            in command : ValveCommand;
        }
        
        part def FluidReservoir {
            port fluidOutPort : FluidPort;
        }
        
        part def Pump {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            perform action pumpFluid : PumpFluid {
                in fluidIn = fluidInPort.fluid;
                out fluidOut = fluidOutPort.fluid;
            }
        }
        
        action def PumpFluid {
            in fluidIn : Fluid;
            out fluidOut : Fluid;
        }
        
        part def PressureSensor {
            port outPort : PressureSensorPort;
            perform action sensePressure : SensePressure {
                out reading = outPort.reading;
            }
        }
        
        action def SensePressure {
            out reading : PressureReading;
        }
        
        part def VelocitySensor {
            port outPort : VelocitySensorPort;
            perform action senseVelocity : SenseVelocity {
                out reading = outPort.reading;
            }
        }
        
        action def SenseVelocity {
            out reading : VelocityReading;
        }
        
        part def VenturiTube {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            attribute inletArea : AreaValue;
            attribute throatArea : AreaValue;
            
            part inletPressureSensor : PressureSensor;
            part throatPressureSensor : PressureSensor;
            part inletVelocitySensor : VelocitySensor;
            part throatVelocitySensor : VelocitySensor;
        }
        
        part def ControlValve {
            port fluidInPort : ~FluidPort;
            port fluidOutPort : FluidPort;
            port commandPort : ValveCommandPort;
            attribute currentOpening : ValvePositionValue;
            perform action adjustValve : AdjustValve {
                in command = commandPort.command;
                out opening = currentOpening;
            }
        }
        
        action def AdjustValve {
            in command : ValveCommand;
            out opening : ValvePositionValue;
        }
        
        part def FluidSink {
            port fluidInPort : ~FluidPort;
        }
        
        action def CalculateFlowRate {
            in pressureInlet : PressureReading;
            in pressureThroat : PressureReading;
            in inletArea : AreaValue;
            in throatArea : AreaValue;
            out flowRate : VolumeFlowRateValue;
        }
        
        action def ControlValvePosition {
            in targetFlowRate : VolumeFlowRateValue;
            in actualFlowRate : VolumeFlowRateValue;
            out valvePosition : ValvePositionValue;
        }
        
        action def MeasureAndControl {
            in pressureInlet : PressureReading;
            in pressureThroat : PressureReading;
            in targetFlowRate : VolumeFlowRateValue;
            out valvePosition : ValvePositionValue;
        }
        
        state def FlowControlStates;
        
        part def FlowController {
            port pressureInletInPort : ~PressureSensorPort;
            port pressureThroatInPort : ~PressureSensorPort;
            port velocityInletInPort : ~VelocitySensorPort;
            port velocityThroatInPort : ~VelocitySensorPort;
            port valveCommandOutPort : ~ValveCommandPort;
            
            attribute targetFlowRate : VolumeFlowRateValue = 0.05;
            attribute actualFlowRate : VolumeFlowRateValue;
            attribute maxPressureDrop : PressureValue = 50000.0;
            
            perform action calculateFlow : CalculateFlowRate {
                in pressureInlet = pressureInletInPort.reading;
                in pressureThroat = pressureThroatInPort.reading;
                in inletArea = 0.01;
                in throatArea = 0.005;
                out flowRate = actualFlowRate;
            }
            
            perform action controlValvePosition : ControlValvePosition {
                in targetFlowRate = targetFlowRate;
                in actualFlowRate = actualFlowRate;
                out valvePosition = valveCommandOutPort.command.position;
            }
            
            perform action measureAndControl : MeasureAndControl {
                in pressureInlet = pressureInletInPort.reading;
                in pressureThroat = pressureThroatInPort.reading;
                in targetFlowRate = targetFlowRate;
                out valvePosition = valveCommandOutPort.command.position;
            }
            
            exhibit state flowControlStates : FlowControlStates {
                entry; then standby;
                state standby;
                accept StartCommand then startup;
                state startup;
                accept SystemReady then normalOperation;
                state normalOperation {
                    entry calculateFlow;
                    do controlValvePosition;
                }
                accept ShutdownCommand then shutdown;
                accept when pressureInletInPort.reading.value - pressureThroatInPort.reading.value > maxPressureDrop then alarm;
                state shutdown;
                accept ShutdownComplete then standby;
                state alarm;
                accept ResetCommand then standby;
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part systemContext {
            part reservoir : FluidReservoir;
            part pump : Pump;
            part venturiTube : VenturiTube;
            part controlValve : ControlValve;
            part sink : FluidSink;
            part controller : FlowController;
            
            flow of Fluid from reservoir.fluidOutPort.fluid to pump.fluidInPort.fluid;
            flow of Fluid from pump.fluidOutPort.fluid to venturiTube.fluidInPort.fluid;
            flow of Fluid from venturiTube.fluidOutPort.fluid to controlValve.fluidInPort.fluid;
            flow of Fluid from controlValve.fluidOutPort.fluid to sink.fluidInPort.fluid;
            
            flow of PressureReading from venturiTube.inletPressureSensor.outPort.reading to controller.pressureInletInPort.reading;
            flow of PressureReading from venturiTube.throatPressureSensor.outPort.reading to controller.pressureThroatInPort.reading;
            flow of VelocityReading from venturiTube.inletVelocitySensor.outPort.reading to controller.velocityInletInPort.reading;
            flow of VelocityReading from venturiTube.throatVelocitySensor.outPort.reading to controller.velocityThroatInPort.reading;
            
            flow of ValveCommand from controller.valveCommandOutPort.command to controlValve.commandPort.command;
        }
        
        requirement def 'Flow Rate Accuracy' {
            attribute requiredAccuracy : Real;
        }
        requirement def 'Abnormal Pressure Drop Safety' {
            attribute minimumPressureDrop : PressureValue;
        }
        
        requirement flowAccuracy : 'Flow Rate Accuracy' {
            requiredAccuracy = 0.01;
        }
        requirement pressureSafety : 'Abnormal Pressure Drop Safety' {
            minimumPressureDrop = 50000.0;
        }
    }
}
