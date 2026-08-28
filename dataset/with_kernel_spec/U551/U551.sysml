package FluidTransferSystem {
    attribute def PressureValue :> Real;
    attribute def VolumeFlowRateValue :> Real;
    attribute def TorqueValue :> Real;
    attribute def AngularVelocityValue :> Real;
    attribute def ForceValue :> Real;
    attribute def LengthValue :> Real;
    attribute def TemperatureValue :> Real;
    attribute def ViscosityValue :> Real;
    attribute def DensityValue :> Real;
    attribute def VolumeValue :> Real;

    attribute def StartCommand;
    attribute def StopCommand;
    attribute def RampComplete;
    attribute def SuctionComplete;
    attribute def DischargeComplete;
    attribute def StopComplete;

    item def Fluid {
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
        attribute density : DensityValue;
    }

    port def FluidOutPort {
        out item fluid : Fluid;
        attribute pressure : PressureValue;
    }

    port def FluidInPort {
        in item fluid : Fluid;
        attribute pressure : PressureValue;
    }

    port def MechanicalPowerPort {
        out attribute torque : TorqueValue;
        out attribute angularVelocity : AngularVelocityValue;
    }

    port def LinearMotionPort {
        out attribute force : ForceValue;
        out attribute displacement : LengthValue;
    }

    port def PressureSensePort {
        attribute pressure : PressureValue;
    }

    port def FlowSensePort {
        attribute flowRate : VolumeFlowRateValue;
    }

    action def SuctionStroke {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
    }

    action def DischargeStroke {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
    }

    state def PumpOperation {
        entry; then idle;

        state idle;
        accept StartCommand then starting;

        state starting;
        accept RampComplete then running;

        state running {
            entry; then suction;

            state suction {
                do action performSuction : SuctionStroke;
            }
            accept SuctionComplete then discharge;

            state discharge {
                do action performDischarge : DischargeStroke;
            }
            accept DischargeComplete then suction;

            accept StopCommand then stopping;
        }

        state stopping;
        accept StopComplete then idle;
    }

    part def SupplyTank {
        port fluidOutPort : FluidOutPort;
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        item storedFluid : Fluid;
    }

    part def ReceivingTank {
        port fluidInPort : FluidInPort;
        attribute capacity : VolumeValue;
        attribute currentLevel : VolumeValue;
        item storedFluid : Fluid;
    }

    part def Crankshaft {
        port powerOutPort : MechanicalPowerPort;
        attribute rotationalSpeed : AngularVelocityValue;
        attribute torque : TorqueValue;
    }

    part def ConnectingRod {
        port powerInPort : ~MechanicalPowerPort;
        port linearOutPort : LinearMotionPort;
        attribute length : LengthValue;
    }

    part def Piston {
        port motionInPort : ~LinearMotionPort;
        attribute diameter : LengthValue;
        attribute strokeLength : LengthValue;
        attribute position : LengthValue;
    }

    part def Cylinder {
        port inletPort : FluidInPort;
        port outletPort : FluidOutPort;
        attribute bore : LengthValue;
        attribute volume : VolumeValue;
        attribute pressure : PressureValue;
    }

    part def CheckValve {
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        attribute isOpen : Boolean;
        attribute crackingPressure : PressureValue;
    }

    part def ReciprocatingPump {
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        port suctionPressurePort : PressureSensePort;
        port dischargePressurePort : PressureSensePort;
        port flowRatePort : FlowSensePort;

        attribute flowRate : VolumeFlowRateValue;
        attribute suctionPressure : PressureValue;
        attribute dischargePressure : PressureValue;
        attribute efficiency : Real;

        part crankshaft : Crankshaft;
        part connectingRod : ConnectingRod;
        part piston : Piston;
        part cylinder : Cylinder;
        part inletCheckValve : CheckValve;
        part outletCheckValve : CheckValve;

        flow crankshaft.powerOutPort to connectingRod.powerInPort;
        flow connectingRod.linearOutPort to piston.motionInPort;

        flow of fluid : Fluid from fluidInPort.fluid to inletCheckValve.fluidInPort.fluid;
        flow of fluid : Fluid from inletCheckValve.fluidOutPort.fluid to cylinder.inletPort.fluid;
        flow of fluid : Fluid from cylinder.outletPort.fluid to outletCheckValve.fluidInPort.fluid;
        flow of fluid : Fluid from outletCheckValve.fluidOutPort.fluid to fluidOutPort.fluid;

        exhibit state pumpOperation : PumpOperation;
    }

    part def PressureGauge {
        port pressureSensePort : PressureSensePort;
        attribute reading : PressureValue;
    }

    part def FlowMeter {
        port flowSensePort : FlowSensePort;
        port fluidInPort : FluidInPort;
        port fluidOutPort : FluidOutPort;
        attribute reading : VolumeFlowRateValue;
    }

    requirement def MinFlowRateRequirement {
        doc /* The pump shall deliver at least the specified minimum flow rate. */
        subject thePump : ReciprocatingPump;
        attribute minFlowRate : VolumeFlowRateValue;
    }

    requirement def MaxPressureRequirement {
        doc /* The discharge pressure shall not exceed the specified maximum. */
        subject thePump : ReciprocatingPump;
        attribute maxPressure : PressureValue;
    }

    requirement def EfficiencyRequirement {
        doc /* The pump shall achieve at least the specified operational efficiency. */
        subject thePump : ReciprocatingPump;
        attribute minEfficiency : Real;
    }

    requirement def FluidCompatibilityRequirement {
        doc /* The system shall be compatible with fluids within the specified viscosity and temperature range. */
        subject theFluid : Fluid;
        attribute minViscosity : ViscosityValue;
        attribute maxViscosity : ViscosityValue;
        attribute minTemperature : TemperatureValue;
        attribute maxTemperature : TemperatureValue;
    }

    part fluidTransferSystem {
        part supplyTank : SupplyTank {
            attribute capacity = 500.0;
            attribute currentLevel = 400.0;
        }

        part pump : ReciprocatingPump {
            attribute efficiency = 0.87;
        }

        part receivingTank : ReceivingTank {
            attribute capacity = 500.0;
            attribute currentLevel = 0.0;
        }

        part suctionGauge : PressureGauge;
        part dischargeGauge : PressureGauge;
        part flowMeter : FlowMeter;

        flow of fluid : Fluid from supplyTank.fluidOutPort.fluid to pump.fluidInPort.fluid;
        flow of fluid : Fluid from pump.fluidOutPort.fluid to flowMeter.fluidInPort.fluid;
        flow of fluid : Fluid from flowMeter.fluidOutPort.fluid to receivingTank.fluidInPort.fluid;

        connect pump.suctionPressurePort to suctionGauge.pressureSensePort;
        connect pump.dischargePressurePort to dischargeGauge.pressureSensePort;
        connect pump.flowRatePort to flowMeter.flowSensePort;

        bind suctionGauge.reading = pump.suctionPressure;
        bind dischargeGauge.reading = pump.dischargePressure;
        bind flowMeter.reading = pump.flowRate;

        requirement minFlowReq : MinFlowRateRequirement {
            attribute minFlowRate = 0.000167;
            assert constraint { pump.flowRate >= minFlowRate }
        }
        requirement maxPressureReq : MaxPressureRequirement {
            attribute maxPressure = 500000.0;
            assert constraint { pump.dischargePressure <= maxPressure }
        }
        requirement efficiencyReq : EfficiencyRequirement {
            attribute minEfficiency = 0.85;
            assert constraint { pump.efficiency >= minEfficiency }
        }
        requirement fluidCompatReq : FluidCompatibilityRequirement {
            attribute minViscosity = 0.001;
            attribute maxViscosity = 0.1;
            attribute minTemperature = 283.15;
            attribute maxTemperature = 353.15;
            assert constraint {
                supplyTank.storedFluid.viscosity >= minViscosity
                and supplyTank.storedFluid.viscosity <= maxViscosity
                and supplyTank.storedFluid.temperature >= minTemperature
                and supplyTank.storedFluid.temperature <= maxTemperature
            }
        }

        satisfy minFlowReq by pump;
        satisfy maxPressureReq by pump;
        satisfy efficiencyReq by pump;
        satisfy fluidCompatReq by supplyTank.storedFluid;
    }
}
