package FluidTransferSystem {
    private import ScalarValues::*;

    attribute def VolumeValue :> Real;
    attribute def FlowRateValue :> Real;
    attribute def PressureValue :> Real;
    attribute def VoltageValue :> Real;
    attribute def LengthValue :> Real;

    item def Fluid;
    item def ElectricPower;
    item def StartCommand;
    item def PrimingComplete;
    item def StopCommand;
    item def FaultSignal;
    item def ResetCommand;

    port def FluidOutPort {
        out item fluid : Fluid;
    }
    port def FluidInPort {
        in item fluid : Fluid;
    }
    port def PowerOutPort {
        out item power : ElectricPower;
    }
    port def PowerInPort {
        in item power : ElectricPower;
    }

    action def PumpFluid {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
    }
    action def FilterDebris {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
    }
    action def PreventBackflow {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
    }
    action def MeasureFlow {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
        out flowRate : FlowRateValue;
    }
    action def SensePressure {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
        out pressure : PressureValue;
    }
    action def SelfPrime;
    action def StopPump;
    action def Drive;

    part def SourceReservoir {
        attribute capacity : VolumeValue = 100.0;
        attribute currentVolume : VolumeValue = 80.0;
        port fluidOutPort : FluidOutPort;
    }

    part def StrainerFilter {
        attribute meshSize : LengthValue;
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        perform action filterDebris : FilterDebris {
            in item fluidIn = fluidInPort.fluid;
            out item fluidOut = fluidOutPort.fluid;
        }
    }

    part def SuctionPipe {
        attribute diameter : LengthValue = 25.4;
        attribute material : String = "Reinforced Rubber";
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
    }

    part def PMDCMotor {
        port powerInPort : PowerInPort;
        perform action drive : Drive;
    }

    part def NitrileImpeller;

    part def JabscoPump {
        attribute modelNumber : String = "50880-1000";
        attribute housingMaterial : String = "Bronze";
        attribute impellerMaterial : String = "Nitrile Rubber";
        attribute motorType : String = "Permanent Magnet DC";
        attribute ratedVoltage : VoltageValue = 12.0;
        attribute maxFlowRate : FlowRateValue = 15.0;
        attribute maxPressure : PressureValue = 3.0;
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        port powerInPort : PowerInPort;
        part motor : PMDCMotor;
        part impeller : NitrileImpeller;
        perform action pumpFluid : PumpFluid {
            in item fluidIn = fluidInPort.fluid;
            out item fluidOut = fluidOutPort.fluid;
        }
        perform action selfPrime : SelfPrime;
        perform action stopPump : StopPump;
    }

    part def DischargePipe {
        attribute diameter : LengthValue = 19.05;
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
    }

    part def CheckValve {
        attribute crackingPressure : PressureValue;
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        perform action preventBackflow : PreventBackflow {
            in item fluidIn = fluidInPort.fluid;
            out item fluidOut = fluidOutPort.fluid;
        }
    }

    part def FlowMeter {
        attribute measuredFlowRate : FlowRateValue;
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        perform action measureFlow : MeasureFlow {
            in item fluidIn = fluidInPort.fluid;
            out item fluidOut = fluidOutPort.fluid;
            out flowRate = measuredFlowRate;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        perform action sensePressure : SensePressure {
            in item fluidIn = fluidInPort.fluid;
            out item fluidOut = fluidOutPort.fluid;
            out pressure = measuredPressure;
        }
    }

    part def DestinationTank {
        attribute capacity : VolumeValue = 50.0;
        attribute currentVolume : VolumeValue = 10.0;
        port fluidInPort : FluidInPort;
    }

    part def PowerSupply {
        attribute outputVoltage : VoltageValue = 12.0;
        port powerOutPort : PowerOutPort;
    }

    part def FluidTransferSystem {
        part pump : JabscoPump;
        part strainer : StrainerFilter;
        part checkValve : CheckValve;
        part flowMeter : FlowMeter;
        part pressureSensor : PressureSensor;
        part sourceReservoir : SourceReservoir;
        part suctionPipe : SuctionPipe;
        part dischargePipe : DischargePipe;
        part destinationTank : DestinationTank;
        part powerSupply : PowerSupply;

        perform action selfPrime : SelfPrime;
        perform action pumpFluid : PumpFluid;
        perform action stopPump : StopPump;

        exhibit state systemStates {
            entry; then idle;
            state idle;
            accept StartCommand then selfPriming;
            state selfPriming {
                do selfPrime;
            }
            accept PrimingComplete then running;
            state running {
                do pumpFluid;
            }
            accept StopCommand then stopped;
            accept FaultSignal then fault;
            state stopped {
                do stopPump;
            }
            accept FaultSignal then fault;
            state fault {
                do stopPump;
            }
            accept ResetCommand then idle;
        }

        flow of fluid : Fluid
            from sourceReservoir.fluidOutPort.fluid to strainer.fluidInPort.fluid;
        flow of fluid : Fluid
            from strainer.fluidOutPort.fluid to suctionPipe.fluidInPort.fluid;
        flow of fluid : Fluid
            from suctionPipe.fluidOutPort.fluid to pump.fluidInPort.fluid;
        flow of fluid : Fluid
            from pump.fluidOutPort.fluid to dischargePipe.fluidInPort.fluid;
        flow of fluid : Fluid
            from dischargePipe.fluidOutPort.fluid to checkValve.fluidInPort.fluid;
        flow of fluid : Fluid
            from checkValve.fluidOutPort.fluid to flowMeter.fluidInPort.fluid;
        flow of fluid : Fluid
            from flowMeter.fluidOutPort.fluid to pressureSensor.fluidInPort.fluid;
        flow of fluid : Fluid
            from pressureSensor.fluidOutPort.fluid to destinationTank.fluidInPort.fluid;

        connect powerSupply.powerOutPort to pump.powerInPort;
    }

    requirement def NominalFlowRateRequirement {
        attribute requiredFlowRate : FlowRateValue = 15.0;
        subject sensor : FlowMeter;
        constraint { sensor.measuredFlowRate >= requiredFlowRate }
    }

    requirement def MaxPressureRequirement {
        attribute maxPressure : PressureValue = 3.0;
        subject sensor : PressureSensor;
        constraint { sensor.measuredPressure <= maxPressure }
    }

    requirement def SafetyReliabilityRequirement {
        subject theSystem : FluidTransferSystem;
    }

    part system : FluidTransferSystem {
        requirement req1 : NominalFlowRateRequirement {
            subject sensor = flowMeter;
        }
        requirement req2 : MaxPressureRequirement {
            subject sensor = pressureSensor;
        }
        requirement req3 : SafetyReliabilityRequirement {
            subject theSystem = system;
        }
    }
}
