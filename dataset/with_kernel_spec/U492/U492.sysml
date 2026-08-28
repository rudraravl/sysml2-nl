package ElectromagneticPumpingSubsystem {
    private import ISQ::*;
    private import ScalarValues::*;
    private import SI::*;

    item def ConductiveFluid {
        attribute conductivity : Real;
        attribute density :> ISQ::massDensity;
        attribute temperature :> ISQ::temperature;
    }

    item def PressureReading {
        attribute value :> ISQ::pressure;
    }

    item def FlowReading {
        attribute value :> ISQ::volumeFlowRate;
    }

    item def PowerCommand {
        attribute voltage :> ISQ::electricPotential;
        attribute current :> ISQ::electricCurrent;
    }

    item def ValveCommand {
        attribute open : Boolean;
    }

    item def StartSignal;
    item def StopSignal;
    item def ResetSignal;

    port def FluidOutPort {
        out item fluid : ConductiveFluid;
    }

    port def FluidInPort {
        in item fluid : ConductiveFluid;
    }

    port def ElectricalPowerInPort {
        in item power : PowerCommand;
    }

    port def ElectricalPowerOutPort {
        out item power : PowerCommand;
    }

    port def PressureSensorOutPort {
        out item reading : PressureReading;
    }

    port def PressureSensorInPort {
        in item reading : PressureReading;
    }

    port def FlowMeterOutPort {
        out item reading : FlowReading;
    }

    port def FlowMeterInPort {
        in item reading : FlowReading;
    }

    port def ValveControlInPort {
        in item command : ValveCommand;
    }

    port def ValveControlOutPort {
        out item command : ValveCommand;
    }

    port def ControlSignalInPort {
        in item start : StartSignal;
        in item stop : StopSignal;
        in item reset : ResetSignal;
    }

    part def SourceTank {
        attribute capacity :> ISQ::volume;
        port outlet : FluidOutPort;
    }

    part def DestinationTank {
        attribute capacity :> ISQ::volume;
        port inlet : FluidInPort;
    }

    part def InletValve {
        attribute isOpen : Boolean;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port control : ValveControlInPort;
        perform action openValve;
        perform action closeValve;
    }

    part def ElectromagneticPump {
        attribute magneticFluxDensity :> ISQ::magneticFluxDensity;
        attribute maxPressure :> ISQ::pressure;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port powerIn : ElectricalPowerInPort;
        perform action generateLorentzForce;
    }

    part def PowerSupply {
        attribute maxCurrent :> ISQ::electricCurrent;
        attribute maxVoltage :> ISQ::electricPotential;
        port powerOut : ElectricalPowerOutPort;
        port controlIn : ElectricalPowerInPort;
        perform action regulatePower;
    }

    part def PressureSensor {
        attribute measuredPressure :> ISQ::pressure;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port signalOut : PressureSensorOutPort;
        perform action measurePressure;
    }

    part def FlowMeter {
        attribute measuredFlowRate :> ISQ::volumeFlowRate;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port signalOut : FlowMeterOutPort;
        perform action measureFlow;
    }

    part def PumpController {
        attribute desiredFlowRate :> ISQ::volumeFlowRate;
        attribute maxSafePressure :> ISQ::pressure;
        attribute inletPressure :> ISQ::pressure;
        attribute outletPressure :> ISQ::pressure;
        attribute measuredFlowRate :> ISQ::volumeFlowRate;
        
        port inletPressureIn : PressureSensorInPort;
        port outletPressureIn : PressureSensorInPort;
        port flowIn : FlowMeterInPort;
        port powerCmdOut : ElectricalPowerOutPort;
        port valveCmdOut : ValveControlOutPort;
        port controlIn : ControlSignalInPort;
        
        perform action monitorSensors;
        perform action adjustPower;
        perform action emergencyShutdown;
        
        exhibit state controllerStates : ControllerStates;
    }

    state def ControllerStates {
        entry; then off;
        
        state off;
        
        transition off_to_priming 
            first off 
            accept StartSignal 
            then priming;
            
        state priming;
        
        transition priming_to_running 
            first priming 
            accept f : FlowReading 
            if f.value > 0 
            then running;
            
        state running;
        
        transition running_to_fault 
            first running 
            accept p : PressureReading 
            if p.value > 800000 [pascal] 
            then fault;
            
        transition running_to_off 
            first running 
            accept StopSignal 
            then off;
            
        state fault;
        
        transition fault_to_off 
            first fault 
            accept ResetSignal 
            then off;
    }

    requirement def FlowRateMaintenance {
        subject controller : PumpController;
        attribute targetFlowRate :> ISQ::volumeFlowRate;
        attribute tolerance :> ISQ::volumeFlowRate;
        assert constraint {
            controller.measuredFlowRate >= targetFlowRate - tolerance and
            controller.measuredFlowRate <= targetFlowRate + tolerance
        }
    }

    requirement def PressureSafetyLimit {
        subject controller : PumpController;
        attribute pressureThreshold :> ISQ::pressure;
        assert constraint {
            controller.outletPressure <= pressureThreshold
        }
    }

    requirement def NoMovingParts {
        subject pump : ElectromagneticPump;
        assert constraint {
            pump.magneticFluxDensity > 0
        }
    }

    part pumpingSubsystem {
        part sourceTank : SourceTank {
            attribute redefines capacity = 1 [metre*metre*metre];
        }
        
        part inletValve : InletValve;
        
        part inletPressureSensor : PressureSensor;
        
        part pump : ElectromagneticPump {
            attribute redefines maxPressure = 1000000 [pascal];
        }
        
        part outletPressureSensor : PressureSensor;
        
        part flowMeter : FlowMeter;
        
        part destinationTank : DestinationTank {
            attribute redefines capacity = 1 [metre*metre*metre];
        }
        
        part powerSupply : PowerSupply;
        
        part controller : PumpController {
            attribute redefines desiredFlowRate = 0.000833 [metre*metre*metre/second];
            attribute redefines maxSafePressure = 800000 [pascal];
        }

        flow fluidFlow1 of ConductiveFluid 
            from sourceTank.outlet.fluid to inletValve.fluidIn.fluid;
            
        flow fluidFlow2 of ConductiveFluid 
            from inletValve.fluidOut.fluid to inletPressureSensor.fluidIn.fluid;
            
        flow fluidFlow3 of ConductiveFluid 
            from inletPressureSensor.fluidOut.fluid to pump.fluidIn.fluid;
            
        flow fluidFlow4 of ConductiveFluid 
            from pump.fluidOut.fluid to outletPressureSensor.fluidIn.fluid;
            
        flow fluidFlow5 of ConductiveFluid 
            from outletPressureSensor.fluidOut.fluid to flowMeter.fluidIn.fluid;
            
        flow fluidFlow6 of ConductiveFluid 
            from flowMeter.fluidOut.fluid to destinationTank.inlet.fluid;

        flow inletPressureSignal of PressureReading 
            from inletPressureSensor.signalOut.reading to controller.inletPressureIn.reading;
            
        flow outletPressureSignal of PressureReading 
            from outletPressureSensor.signalOut.reading to controller.outletPressureIn.reading;
            
        flow flowSignal of FlowReading 
            from flowMeter.signalOut.reading to controller.flowIn.reading;

        flow valveCmdFlow of ValveCommand 
            from controller.valveCmdOut.command to inletValve.control.command;
            
        flow powerCmdFlow of PowerCommand 
            from controller.powerCmdOut.power to powerSupply.controlIn.power;
            
        flow powerToPump of PowerCommand 
            from powerSupply.powerOut.power to pump.powerIn.power;

        requirement flowRateReq : FlowRateMaintenance {
            attribute redefines targetFlowRate = 0.000833 [metre*metre*metre/second];
            attribute redefines tolerance = 0.0000833 [metre*metre*metre/second];
        }
        
        requirement pressureSafetyReq : PressureSafetyLimit {
            attribute redefines pressureThreshold = 800000 [pascal];
        }
        
        requirement noMovingPartsReq : NoMovingParts;
        
        satisfy flowRateReq by controller;
        satisfy pressureSafetyReq by controller;
        satisfy noMovingPartsReq by pump;
    }
}
