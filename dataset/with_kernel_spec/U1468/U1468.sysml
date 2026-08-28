package HydraulicPistonActuationSystem {
    private import SI::*;
    private import ScalarValues::*;
    private import ScalarValues::String;

    item def HydraulicFluid;

    enum def Command {
        enum idle;
        enum extend;
        enum retract;
        enum hold;
    }

    port def FluidPort {
        out item fluid : HydraulicFluid;
        attribute pressure : ISQ::pressure;
        attribute flowRate : ISQ::volumeFlowRate;
    }

    port def MechanicalPort {
        attribute force : ISQ::force;
        attribute position : ISQ::length;
        attribute velocity : ISQ::speed;
    }

    action def PressurizeFluid {
        in flowRate : ISQ::volumeFlowRate;
        in maxPressure : ISQ::pressure;
        out pressure : ISQ::pressure;
    }

    action def CalculatePistonForce {
        in pressure : ISQ::pressure;
        in area : ISQ::area;
        out force : ISQ::force;
    }

    part def Pump {
        attribute ratedPressure : ISQ::pressure;
        attribute ratedFlowRate : ISQ::volumeFlowRate;
        attribute generatedPressure : ISQ::pressure;
        
        perform action pressurize : PressurizeFluid {
            in flowRate = ratedFlowRate;
            in maxPressure = ratedPressure;
            out pressure = generatedPressure;
        }
    }

    part def HydraulicPowerUnit {
        port fluidOut : FluidPort;
        port fluidIn : ~FluidPort;
        attribute maxPressure : ISQ::pressure;
        part pump : Pump;
        bind fluidOut.pressure = pump.generatedPressure;
    }

    state machine def ValveStates {
        state idle;
        state extending;
        state retracting;
        state holding;
        
        transition t_idle_ext 
            from idle to extending 
            when (currentCommand == Command::extend);
        transition t_idle_ret 
            from idle to retracting 
            when (currentCommand == Command::retract);
        transition t_ext_hold 
            from extending to holding 
            when (currentCommand == Command::hold);
        transition t_ret_hold 
            from retracting to holding 
            when (currentCommand == Command::hold);
        transition t_hold_idle 
            from holding to idle 
            when (currentCommand == Command::idle);
        transition t_ext_idle 
            from extending to idle 
            when (currentCommand == Command::idle);
        transition t_ret_idle 
            from retracting to idle 
            when (currentCommand == Command::idle);
    }

    part def ControlValve {
        port fluidIn : ~FluidPort;
        port fluidOutExtend : FluidPort;
        port fluidOutRetract : FluidPort;
        port fluidReturn : ~FluidPort;
        attribute currentCommand : Command;
        
        exhibit state valveStates : ValveStates;
    }

    part def CylinderBody {
        attribute length : ISQ::length;
        attribute innerDiameter : ISQ::length;
    }

    part def PistonHead {
        attribute diameter : ISQ::length;
        attribute area : ISQ::area;
    }

    part def PistonRod {
        attribute length : ISQ::length;
        attribute diameter : ISQ::length;
    }

    part def Seals {
        attribute material : String;
        attribute maxLeakageRate : ISQ::volumeFlowRate;
    }

    part def ExternalLoad {
        attribute mass : ISQ::mass;
        attribute position : ISQ::length;
    }

    state machine def ActuatorStates {
        state idle {
            doc /* Waiting for commands */
        }
        state extending {
            doc /* Piston is moving outwards */
        }
        state retracting {
            doc /* Piston is moving inwards */
        }
        state holding {
            doc /* Piston is holding fixed position */
        }
        
        transition idle_to_extending 
            from idle to extending 
            when (currentCommand == Command::extend);
        transition extending_to_holding 
            from extending to holding 
            when (currentCommand == Command::hold);
        transition holding_to_retracting 
            from holding to retracting 
            when (currentCommand == Command::retract);
        transition retracting_to_idle 
            from retracting to idle 
            when (currentCommand == Command::idle);
        transition extending_to_idle 
            from extending to idle 
            when (currentCommand == Command::idle);
        transition holding_to_idle 
            from holding to idle 
            when (currentCommand == Command::idle);
    }

    part def PistonActuator {
        port fluidInExtend : ~FluidPort;
        port fluidInRetract : ~FluidPort;
        port mechanicalOut : MechanicalPort;
        attribute currentCommand : Command;
        
        attribute pistonPosition : ISQ::length;
        attribute pistonVelocity : ISQ::speed;
        attribute outputForce : ISQ::force;
        
        part cylinderBody : CylinderBody;
        part pistonHead : PistonHead;
        part pistonRod : PistonRod;
        part seals : Seals;
        ref part load : ExternalLoad;
        
        perform action calculateForce : CalculatePistonForce {
            in pressure = fluidInExtend.pressure;
            in area = pistonHead.area;
            out force = outputForce;
        }
        
        exhibit state actuatorStates : ActuatorStates;
    }

    part def ActuationSystem {
        attribute command : Command;
        
        part powerUnit : HydraulicPowerUnit;
        part controlValve : ControlValve;
        part actuator : PistonActuator;
        part load : ExternalLoad;
        
        bind controlValve.currentCommand = command;
        bind actuator.currentCommand = command;
        bind actuator.load = load;
        
        flow of fluid : HydraulicFluid
            from powerUnit.fluidOut.fluid to controlValve.fluidIn.fluid;
        flow of fluid : HydraulicFluid
            from controlValve.fluidOutExtend.fluid to actuator.fluidInExtend.fluid;
        flow of fluid : HydraulicFluid
            from controlValve.fluidOutRetract.fluid to actuator.fluidInRetract.fluid;
        flow of fluid : HydraulicFluid
            from controlValve.fluidReturn.fluid to powerUnit.fluidIn.fluid;
    }

    requirement def ActuationPerformanceRequirement {
        subject system : ActuationSystem;
        attribute maxRequiredForce : ISQ::force;
        attribute maxRequiredSpeed : ISQ::speed;
        attribute maxStrokeLength : ISQ::length;
        require constraint { system.actuator.outputForce <= maxRequiredForce }
        require constraint { system.actuator.pistonVelocity <= maxRequiredSpeed }
        require constraint { system.actuator.pistonPosition <= maxStrokeLength }
    }
    
    requirement def SealingRequirement {
        subject actuator : PistonActuator;
        attribute maxLeakageRate : ISQ::volumeFlowRate;
        require constraint { actuator.seals.maxLeakageRate <= maxLeakageRate }
    }
}
