package IndustrialImpellerPump {
    private import SI::*;
    private import ScalarValues::*;

    item def Fluid;

    attribute def ControlCommand {
        attribute start : Boolean;
        attribute speedSetpoint : Real;
    }

    port def ElectricalPort {
        in voltage :> ISQ::electricPotential;
        in current :> ISQ::electricCurrent;
    }

    port def ControlPort {
        in command : ControlCommand;
    }

    port def MechanicalPort {
        out torque :> ISQ::torque;
        out rotationalSpeed :> ISQ::angularVelocity;
    }

    port def FluidInPort {
        in item fluid : Fluid;
        in pressure :> ISQ::pressure;
        in flowRate :> ISQ::volumeFlowRate;
    }

    port def FluidOutPort {
        out item fluid : Fluid;
        out pressure :> ISQ::pressure;
        out flowRate :> ISQ::volumeFlowRate;
    }

    action def GenerateMotion {
        in voltage :> ISQ::electricPotential;
        in current :> ISQ::electricCurrent;
        in command : ControlCommand;
        out torque :> ISQ::torque;
        out rotationalSpeed :> ISQ::angularVelocity;
    }

    action def TransmitMotion {
        in torque :> ISQ::torque;
        in rotationalSpeed :> ISQ::angularVelocity;
        out torque :> ISQ::torque;
        out rotationalSpeed :> ISQ::angularVelocity;
    }

    action def AccelerateFluid {
        in torque :> ISQ::torque;
        in rotationalSpeed :> ISQ::angularVelocity;
        in fluid : Fluid;
        in pressure :> ISQ::pressure;
        in flowRate :> ISQ::volumeFlowRate;
        out fluid : Fluid;
        out pressure :> ISQ::pressure;
        out flowRate :> ISQ::volumeFlowRate;
    }

    action def DirectFluid {
        in fluid : Fluid;
        in pressure :> ISQ::pressure;
        in flowRate :> ISQ::volumeFlowRate;
        out fluid : Fluid;
        out pressure :> ISQ::pressure;
        out flowRate :> ISQ::volumeFlowRate;
    }

    action def PumpOperation {
        in voltage :> ISQ::electricPotential;
        in current :> ISQ::electricCurrent;
        in command : ControlCommand;
        in fluid : Fluid;
        in pressure :> ISQ::pressure;
        in flowRate :> ISQ::volumeFlowRate;
        out fluid : Fluid;
        out pressure :> ISQ::pressure;
        out flowRate :> ISQ::volumeFlowRate;
        composite step generate : GenerateMotion {
            in voltage = PumpOperation::voltage;
            in current = PumpOperation::current;
            in command = PumpOperation::command;
            out torque;
            out rotationalSpeed;
        }
        composite step transmit : TransmitMotion {
            in torque = generate.torque;
            in rotationalSpeed = generate.rotationalSpeed;
            out torque;
            out rotationalSpeed;
        }
        composite step accelerate : AccelerateFluid {
            in torque = transmit.torque;
            in rotationalSpeed = transmit.rotationalSpeed;
            in fluid = PumpOperation::fluid;
            in pressure = PumpOperation::pressure;
            in flowRate = PumpOperation::flowRate;
            out fluid;
            out pressure;
            out flowRate;
        }
        composite step direct : DirectFluid {
            in fluid = accelerate.fluid;
            in pressure = accelerate.pressure;
            in flowRate = accelerate.flowRate;
            out fluid = PumpOperation::fluid;
            out pressure = PumpOperation::pressure;
            out flowRate = PumpOperation::flowRate;
        }
    }

    part def Motor {
        attribute ratedPower :> ISQ::power = 5.0 [kW];
        attribute efficiency : Real = 0.92;
        port electricalIn : ElectricalPort;
        port controlIn : ControlPort;
        port mechanicalOut : MechanicalPort;
        
        perform action generateMotion : GenerateMotion {
            in voltage = electricalIn.voltage;
            in current = electricalIn.current;
            in command = controlIn.command;
            out torque = mechanicalOut.torque;
            out rotationalSpeed = mechanicalOut.rotationalSpeed;
        }
    }

    part def Shaft {
        attribute length :> ISQ::length = 0.3 [m];
        attribute material : String = "Stainless Steel";
        port mechanicalIn : ~MechanicalPort;
        port mechanicalOut : MechanicalPort;
        
        perform action transmitMotion : TransmitMotion {
            in torque = mechanicalIn.torque;
            in rotationalSpeed = mechanicalIn.rotationalSpeed;
            out torque = mechanicalOut.torque;
            out rotationalSpeed = mechanicalOut.rotationalSpeed;
        }
    }

    part def Impeller {
        attribute bladeCount : Integer = 6;
        port mechanicalIn : ~MechanicalPort;
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        
        perform action accelerateFluid : AccelerateFluid {
            in torque = mechanicalIn.torque;
            in rotationalSpeed = mechanicalIn.rotationalSpeed;
            in fluid = fluidIn.fluid;
            in pressure = fluidIn.pressure;
            in flowRate = fluidIn.flowRate;
            out fluid = fluidOut.fluid;
            out pressure = fluidOut.pressure;
            out flowRate = fluidOut.flowRate;
        }
    }

    part def Casing {
        port inletPort : FluidInPort;
        port outletPort : FluidOutPort;
        port impellerInPort : FluidOutPort;
        port impellerOutPort : FluidInPort;
        
        perform action directFluid : DirectFluid {
            in fluid = impellerOutPort.fluid;
            in pressure = impellerOutPort.pressure;
            in flowRate = impellerOutPort.flowRate;
            out fluid = outletPort.fluid;
            out pressure = outletPort.pressure;
            out flowRate = outletPort.flowRate;
        }
    }

    part def ImpellerPumpSystem {
        attribute operatingTime :> ISQ::time;
        port electricalIn : ~ElectricalPort;
        port controlIn : ~ControlPort;
        port fluidIn : ~FluidInPort;
        port fluidOut : FluidOutPort;
        
        part motor : Motor;
        part shaft : Shaft;
        part impeller : Impeller;
        part casing : Casing;
        
        connect electricalIn to motor.electricalIn;
        connect controlIn to motor.controlIn;
        connect motor.mechanicalOut to shaft.mechanicalIn;
        connect shaft.mechanicalOut to impeller.mechanicalIn;
        connect fluidIn to casing.inletPort;
        connect casing.impellerInPort to impeller.fluidIn;
        connect impeller.fluidOut to casing.impellerOutPort;
        connect casing.outletPort to fluidOut;
        
        perform action pumpOperation : PumpOperation {
            in voltage = electricalIn.voltage;
            in current = electricalIn.current;
            in command = controlIn.command;
            in fluid = fluidIn.fluid;
            in pressure = fluidIn.pressure;
            in flowRate = fluidIn.flowRate;
            out fluid = fluidOut.fluid;
            out pressure = fluidOut.pressure;
            out flowRate = fluidOut.flowRate;
        }
    }

    requirement def PumpPerformanceRequirement {
        subject pump : ImpellerPumpSystem;
        attribute targetFlowRate :> ISQ::volumeFlowRate;
        attribute targetPressureRise :> ISQ::pressure;
        attribute maxPowerConsumption :> ISQ::power;
        require constraint { pump.fluidOut.flowRate >= targetFlowRate }
        require constraint { pump.fluidOut.pressure - pump.fluidIn.pressure >= targetPressureRise }
        require constraint { pump.electricalIn.voltage * pump.electricalIn.current <= maxPowerConsumption }
    }

    requirement def PumpReliabilityRequirement {
        subject pump : ImpellerPumpSystem;
        attribute minOperatingHours :> ISQ::time = 10000.0 [h];
        require constraint { pump.operatingTime >= minOperatingHours }
    }

    requirement pumpPerformance : PumpPerformanceRequirement {
        subject :>> pump;
        attribute :>> targetFlowRate = 0.000833 [m^3/s];
        attribute :>> targetPressureRise = 200000.0 [Pa];
        attribute :>> maxPowerConsumption = 5500.0 [W];
    }

    requirement pumpReliability : PumpReliabilityRequirement {
        subject :>> pump;
    }
}
