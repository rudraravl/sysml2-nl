package YSetFluidDistributionSystem {
    import ISQ::*;
    import ScalarValues::*;

    value def FlowRate :> Real { unit "m^3/s" }
    value def Pressure :> Real { unit "Pa" }
    value def Temperature :> Real { unit "K" }
    value def ValvePosition :> Real { unit "1" }
    value def SplitRatio :> Real { unit "1" }

    item def Fluid;

    port def FluidPort {
        out item fluid : Fluid;
        out attr flowRate : FlowRate;
        out attr pressure : Pressure;
        out attr temperature : Temperature;
    }

    port def SensorSignalPort {
        out attr flowRate : FlowRate;
        out attr pressure : Pressure;
        out attr temperature : Temperature;
    }

    port def ValveControlPort {
        in attr position : ValvePosition;
    }

    occurrence def StartCommand;
    occurrence def StartupComplete;
    occurrence def DeviationDetected;
    occurrence def BalancedAchieved;
    occurrence def StopCommand;
    occurrence def ShutdownComplete;

    part def InletFlowSensor {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port out signal : SensorSignalPort;
        
        action measure {
            in fluid;
            out flowRate;
            out pressure;
            out temperature;
        }
    }

    part def YSetJunction {
        port in fluidIn : FluidPort;
        port out fluidOut1 : FluidPort;
        port out fluidOut2 : FluidPort;
    }

    part def FlowControlValve {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port in control : ValveControlPort;
        
        attr position : ValvePosition;
        
        action adjust {
            in targetPosition : ValvePosition;
        }
    }

    part def OutletFlowSensor {
        port in fluidIn : FluidPort;
        port out fluidOut : FluidPort;
        port out signal : SensorSignalPort;
        
        action measure {
            in fluid;
            out flowRate;
            out pressure;
            out temperature;
        }
    }

    part def FlowDistributionController {
        port in inletSensorSignal : SensorSignalPort;
        port in outletSensor1Signal : SensorSignalPort;
        port in outletSensor2Signal : SensorSignalPort;
        port out valve1Control : ValveControlPort;
        port out valve2Control : ValveControlPort;
        
        attr desiredRatio : SplitRatio = 0.6;
        attr tolerance : SplitRatio = 0.05;
        attr actualRatio : SplitRatio;
        
        action calculateAdjustments {
            in measuredRatio : SplitRatio;
            in targetRatio : SplitRatio;
            out valve1Position : ValvePosition;
            out valve2Position : ValvePosition;
        }
        
        state def ControllerBehavior {
            entry; then idle;
            state idle;
            transition idle to startup when StartCommand;
            state startup;
            transition startup to distributing when StartupComplete;
            state distributing {
                entry; then balanced;
                state balanced;
                transition balanced to adjusting when DeviationDetected;
                state adjusting;
                transition adjusting to balanced when BalancedAchieved;
            }
            transition distributing to shutdown when StopCommand;
            state shutdown;
            transition shutdown to idle when ShutdownComplete;
        }
    }

    part def YSetSystem {
        part inletSensor : InletFlowSensor;
        part junction : YSetJunction;
        part valve1 : FlowControlValve;
        part valve2 : FlowControlValve;
        part outletSensor1 : OutletFlowSensor;
        part outletSensor2 : OutletFlowSensor;
        part controller : FlowDistributionController;
        
        connect inletSensor.fluidOut to junction.fluidIn;
        connect junction.fluidOut1 to valve1.fluidIn;
        connect junction.fluidOut2 to valve2.fluidIn;
        connect valve1.fluidOut to outletSensor1.fluidIn;
        connect valve2.fluidOut to outletSensor2.fluidIn;
        
        connect inletSensor.signal to controller.inletSensorSignal;
        connect outletSensor1.signal to controller.outletSensor1Signal;
        connect outletSensor2.signal to controller.outletSensor2Signal;
        
        connect controller.valve1Control to valve1.control;
        connect controller.valve2Control to valve2.control;
    }

    requirement def SplitRatioControl {
        subject system : YSetSystem;
        requirement {
            subject controller : FlowDistributionController;
            doc /* The controller shall maintain the actual split ratio within the tolerance of the desired split ratio. */
            require controller.actualRatio >= controller.desiredRatio - controller.tolerance
            require controller.actualRatio <= controller.desiredRatio + controller.tolerance
        }
    }
}
