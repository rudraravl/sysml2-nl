package PumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;

    value type FlowRate :> Real { unit "L/min"; }
    value type Pressure :> Real { unit "bar"; }
    value type RotationalSpeed :> Real { unit "rpm"; }
    value type Voltage :> Real { unit "V"; }
    value type Current :> Real { unit "A"; }
    value type Power :> Real { unit "kW"; }

    item def Fluid {
        attribute solidsContent : Real;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def FluidPort {
        in item fluid : Fluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def ElectricalPort {
        in item power : ElectricalPower;
    }

    port def MechanicalPort {
        out attribute speed : RotationalSpeed;
    }

    port def ControlPort {
        in attribute startCmd : Boolean;
        in attribute stopCmd : Boolean;
        in attribute desiredSpeed : RotationalSpeed;
        out attribute operationalStatus : String;
        out attribute actualSpeed : RotationalSpeed;
    }

    part def SourceReservoir {
        port fluidOut : FluidPort;
        attribute initialFluid : Fluid;
    }

    part def SuctionPipe {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def DestinationVessel {
        port fluidIn : FluidPort;
    }

    part def DischargePipe {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
    }

    part def ElectricMotor {
        port electricalIn : ElectricalPort;
        port mechanicalOut : MechanicalPort;
        
        attribute ratedPower : Power;
        attribute currentSpeed : RotationalSpeed;
    }

    part def ChopperImpeller {
        port mechanicalIn : MechanicalPort;
        attribute numBlades : Integer = 4;
        attribute operatingSpeed : RotationalSpeed = 1450;
    }

    part def PumpCasing {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute material : String = "Stainless Steel";
        attribute maxPressure : Pressure = 10;
    }

    part def ChopperPump {
        part motor : ElectricMotor;
        part impeller : ChopperImpeller;
        part casing : PumpCasing;
        
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port electricalIn : ElectricalPort;
        port controlIn : ControlPort;
        
        connection motor.mechanicalOut to impeller.mechanicalIn;
        connection fluidIn to casing.fluidIn;
        connection casing.fluidOut to fluidOut;
        
        state pumpBehavior {
            state idle;
            state starting;
            state running;
            state stopping;
            
            transition idle to starting when controlIn.startCmd;
            transition starting to running when motor.currentSpeed >= controlIn.desiredSpeed;
            transition running to stopping when controlIn.stopCmd;
            transition stopping to idle when motor.currentSpeed == 0;
        }
    }

    part def ControlInterface {
        port controlOut : ControlPort;
        attribute operatorInput : Boolean;
    }

    part def PumpingSystem {
        part source : SourceReservoir;
        part suction : SuctionPipe;
        part pump : ChopperPump;
        part discharge : DischargePipe;
        part destination : DestinationVessel;
        part controller : ControlInterface;
        
        connection source.fluidOut to suction.fluidIn;
        connection suction.fluidOut to pump.fluidIn;
        connection pump.fluidOut to discharge.fluidIn;
        connection discharge.fluidOut to destination.fluidIn;
        
        connection controller.controlOut to pump.controlIn;
    }

    requirement def PerformanceRequirements {
        subject pumpingSystem : PumpingSystem;
        
        requirement minFlowRate {
            subject pump : ChopperPump;
            constraint { pump.fluidOut.flowRate >= 100 }
        }
        
        requirement maxDischargePressure {
            subject pump : ChopperPump;
            constraint { pump.fluidOut.pressure <= 10 }
        }
        
        requirement operatingSpeed {
            subject pump : ChopperPump;
            constraint { pump.impeller.operatingSpeed == 1450 }
        }
        
        requirement energyEfficiency {
            subject pump : ChopperPump;
            constraint { pump.motor.ratedPower <= 5.5 }
        }
    }
}
