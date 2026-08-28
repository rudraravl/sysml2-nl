package PeristalticPumpingSystem {
    import ISQ::*;
    import ScalarValues::*;

    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type FlowRate :> Real { unit 'mL/min'; }
    value type Pressure :> Real { unit 'bar'; }
    value type Volume :> Real { unit 'mL'; }
    value type CompressionCount :> Integer;

    item def Fluid;
    item def ElectricalPower;
    
    item def StartCommand;
    item def StopCommand;
    item def PrimingComplete;
    item def PressureExceeded;

    port def FluidOutPort {
        out fluid : Fluid;
    }
    port def FluidInPort {
        in fluid : Fluid;
    }
    port def PowerOutPort {
        out power : ElectricalPower;
    }
    port def PowerInPort {
        in power : ElectricalPower;
    }
    port def PumpControlPort {
        in targetSpeed : RotationalSpeed;
        out actualFlowRate : FlowRate;
        out outletPressure : Pressure;
    }
    port def ControllerPort {
        in targetFlowRate : FlowRate;
        out status : String;
    }

    requirement def FlowAccuracyRequirement {
        doc /* The pump must maintain the desired flow rate within +/- 2%. */
        attribute targetFlowRate : FlowRate;
        attribute actualFlowRate : FlowRate;
        constraint { abs(actualFlowRate - targetFlowRate) <= 0.02 * targetFlowRate }
    }

    requirement def PressureLimitRequirement {
        doc /* The outlet pressure must not exceed 2.0 bar. */
        attribute maxPressure : Pressure = 2.0 [bar];
        attribute outletPressure : Pressure;
        constraint { outletPressure <= maxPressure }
    }

    requirement def TubingLifespanRequirement {
        doc /* The tubing must be replaced after 1,000,000 compressions. */
        attribute maxCompressions : CompressionCount = 1000000;
        attribute currentCompressions : CompressionCount;
        constraint { currentCompressions <= maxCompressions }
    }

    part def FluidReservoir {
        port fluidOut : FluidOutPort;
        attribute volume : Volume;
    }

    part def ReceivingTank {
        port fluidIn : FluidInPort;
        attribute volume : Volume;
    }

    part def PowerSupply {
        port powerOut : PowerOutPort;
        attribute outputVoltage : Voltage = 24 [V];
        attribute outputCurrent : Current = 5 [A];
    }

    part def Motor {
        port powerIn : PowerInPort;
        attribute speed : RotationalSpeed;
    }

    part def Roller {
        attribute id : Integer;
    }

    part def Rotor {
        attribute rollerCount : Integer = 3;
        attribute speed : RotationalSpeed;
        part rollers : Roller[3];
    }

    part def Tubing {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        attribute compressionCount : CompressionCount = 0;
    }

    part def PumpHousing {
        part occlusionBed;
        part rotor : Rotor;
        part tubing : Tubing;
    }

    part def PeristalticPump {
        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port powerIn : PowerInPort;
        port controlIn : PumpControlPort;
        
        part motor : Motor;
        part housing : PumpHousing;
        
        attribute flowRate : FlowRate;
        attribute outletPressure : Pressure;
        
        action def PumpAction {
            in targetSpeed : RotationalSpeed;
            out generatedFlow : FlowRate;
            out generatedPressure : Pressure;
        }
        
        perform action pumpFluid : PumpAction;
    }

    part def PumpController {
        port powerIn : PowerInPort;
        port controlOut : PumpControlPort;
        port userInterface : ControllerPort;
        
        attribute targetFlowRate : FlowRate;
        attribute actualFlowRate : FlowRate;
        attribute outletPressure : Pressure;
        attribute status : String;
    }

    part def PeristalticPumpingSystem {
        port userInterface : ControllerPort;
        
        part reservoir : FluidReservoir;
        part tank : ReceivingTank;
        part powerSupply : PowerSupply;
        part controller : PumpController;
        part pump : PeristalticPump;
        
        connection fluidConnection1 connect reservoir.fluidOut to pump.fluidIn;
        connection fluidConnection2 connect pump.fluidOut to tank.fluidIn;
        connection powerConnection1 connect powerSupply.powerOut to controller.powerIn;
        connection powerConnection2 connect powerSupply.powerOut to pump.powerIn;
        connection controlConnection connect controller.controlOut to pump.controlIn;
        
        attribute targetFlowRate : FlowRate;
        attribute actualFlowRate : FlowRate;
        attribute outletPressure : Pressure;
        attribute status : String;
        attribute maxSafePressure : Pressure = 2.0 [bar];
        
        exhibit state systemOperation {
            entry; then idle;
            
            state idle {
                entry { status = "Idle"; }
            }
            
            state priming {
                entry { status = "Priming"; }
            }
            
            state running {
                entry { status = "Running"; }
            }
            
            state faulted {
                entry { status = "Faulted"; }
            }
            
            transition idle_to_priming
                first idle
                accept StartCommand
                then priming;
                
            transition priming_to_running
                first priming
                accept PrimingComplete
                then running;
                
            transition running_to_idle
                first running
                accept StopCommand
                then idle;
                
            transition running_to_faulted
                first running
                accept PressureExceeded
                then faulted;
                
            transition priming_to_faulted
                first priming
                accept PressureExceeded
                then faulted;
        }
        
        requirement flowAccuracy : FlowAccuracyRequirement {
            attribute targetFlowRate = targetFlowRate;
            attribute actualFlowRate = actualFlowRate;
        }
        
        requirement pressureLimit : PressureLimitRequirement {
            attribute outletPressure = outletPressure;
        }
        
        requirement tubingLifespan : TubingLifespanRequirement {
            attribute currentCompressions = pump.housing.tubing.compressionCount;
        }
    }
}
