package AcidEggSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    item def CorrosiveFluid;
    item def PressurizedGas;

    attribute def StartSignal;
    attribute def TargetLevelReached;
    attribute def OperatingPressureReached;
    attribute def DischargeComplete;
    attribute def VentComplete;

    port def FluidPort {
        in item fluid : CorrosiveFluid;
        out item fluid : CorrosiveFluid;
    }

    port def GasPort {
        in item gas : PressurizedGas;
        out item gas : PressurizedGas;
    }

    part def FluidValve {
        attribute isClosed : Boolean = true;
        port inPort : FluidPort;
        port outPort : FluidPort;
    }

    part def GasValve {
        attribute isClosed : Boolean = true;
        port inPort : GasPort;
        port outPort : GasPort;
    }

    part def PressureVessel {
        port fluidInPort : FluidPort;
        port fluidOutPort : FluidPort;
        port gasInPort : GasPort;
        port gasOutPort : GasPort;

        attribute maxOperatingPressure :> ISQ::pressure;
        attribute burstPressure :> ISQ::pressure;
        attribute capacity :> ISQ::volume;
        attribute currentVolume :> ISQ::volume;
        attribute currentPressure :> ISQ::pressure;

        item storedFluid : CorrosiveFluid;
        item storedGas : PressurizedGas;
    }

    part def LevelSensor {
        attribute level :> ISQ::volume;
        attribute targetLevel :> ISQ::volume;
    }

    part def PressureSensor {
        attribute pressure :> ISQ::pressure;
        attribute targetPressure :> ISQ::pressure;
    }

    requirement def CorrosionResistanceRequirement {
        doc /* All components in contact with the fluid must be made from corrosion-resistant materials. */
    }

    requirement def PressureSafetyMarginRequirement {
        doc /* The pressure vessel is built to withstand pressures significantly higher than its normal operating pressure. */
        attribute maxOperatingPressure :> ISQ::pressure;
        attribute burstPressure :> ISQ::pressure;
        constraint { burstPressure > maxOperatingPressure * 2.0 }
    }

    requirement def TransferAccuracyRequirement {
        doc /* The system is required to be highly accurate, transferring a volume of fluid that is within +-2% of the specified target. */
        attribute targetVolume :> ISQ::volume;
        attribute transferredVolume :> ISQ::volume;
        constraint { 
            transferredVolume >= targetVolume * 0.98 and 
            transferredVolume <= targetVolume * 1.02 
        }
    }

    requirement corrosionResReq : CorrosionResistanceRequirement;
    requirement pressureSafetyMarginReq : PressureSafetyMarginRequirement;
    requirement transferAccuracyReq : TransferAccuracyRequirement;

    state def AcidEggStates;

    part def AcidEgg {
        port fluidInPort : FluidPort;
        port fluidOutPort : FluidPort;
        port gasInPort : GasPort;
        port gasOutPort : GasPort;

        satisfy transferAccuracyReq;

        part vessel : PressureVessel {
            satisfy corrosionResReq;
            satisfy pressureSafetyMarginReq;
        }
        part inletValve : FluidValve {
            satisfy corrosionResReq;
        }
        part outletValve : FluidValve {
            satisfy corrosionResReq;
        }
        part gasValve : GasValve;
        part ventValve : GasValve;
        part levelSensor : LevelSensor;
        part pressureSensor : PressureSensor;

        flow of fluid : CorrosiveFluid
            from fluidInPort.fluid to inletValve.inPort.fluid;
        flow of fluid : CorrosiveFluid
            from inletValve.outPort.fluid to vessel.fluidInPort.fluid;
        flow of fluid : CorrosiveFluid
            from vessel.fluidOutPort.fluid to outletValve.inPort.fluid;
        flow of fluid : CorrosiveFluid
            from outletValve.outPort.fluid to fluidOutPort.fluid;

        flow of gas : PressurizedGas
            from gasInPort.gas to gasValve.inPort.gas;
        flow of gas : PressurizedGas
            from gasValve.outPort.gas to vessel.gasInPort.gas;
        flow of gas : PressurizedGas
            from vessel.gasOutPort.gas to ventValve.inPort.gas;
        flow of gas : PressurizedGas
            from ventValve.outPort.gas to gasOutPort.gas;

        bind vessel.currentVolume = levelSensor.level;
        bind vessel.currentPressure = pressureSensor.pressure;

        state eggStates : AcidEggStates {
            entry; then idle;
            state idle;
            accept StartSignal then filling;
            state filling;
            accept TargetLevelReached then pressurizing;
            state pressurizing;
            accept OperatingPressureReached then discharging;
            state discharging;
            accept DischargeComplete then venting;
            state venting;
            accept VentComplete then idle;
        }
    }
}
