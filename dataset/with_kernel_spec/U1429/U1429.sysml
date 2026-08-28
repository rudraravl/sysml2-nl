package 'Hydraulic Accumulator Power System' {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::String;

    attribute def Pressure :> Real;
    attribute def Volume :> Real;
    attribute def FlowRate :> Real;

    unit bar : Pressure;
    unit liter : Volume;
    unit literPerSecond : FlowRate;

    item def HydraulicFluid;
    item def NitrogenGas;

    port def HydraulicPort {
        attribute pressure : Pressure;
        inout item fluid : HydraulicFluid;
        attribute flowRate : FlowRate;
    }

    port def PressurePort {
        attribute pressure : Pressure;
    }

    part def Reservoir {
        port fluidPort : HydraulicPort;
        attribute capacity : Volume;
    }

    part def Pump {
        port suctionPort : ~HydraulicPort;
        port dischargePort : HydraulicPort;
        attribute maxFlowRate : FlowRate;
    }

    part def BladderAccumulator {
        port fluidPort : HydraulicPort;
        attribute maxPressure : Pressure;
        attribute preChargePressure : Pressure;
        attribute gasVolume : Volume;
        attribute fluidVolume : Volume;

        part pressureVessel {
            attribute material : String = "High-Strength Steel";
        }

        part bladder {
            item gas : NitrogenGas;
        }
    }

    part def HydraulicActuator {
        port fluidPort : HydraulicPort;
        attribute cylinderVolume : Volume;
    }

    part def PressureSensor {
        port sensingPort : PressurePort;
        attribute measuredPressure : Pressure;
    }

    part def ControlValve {
        port inletPort : ~HydraulicPort;
        port outletPort : HydraulicPort;
        attribute command : Boolean;
    }

    part def PressureReliefValve {
        port inletPort : HydraulicPort;
        port outletPort : ~HydraulicPort;
        attribute crackPressure : Pressure;
    }

    state def AccumulatorStates;

    requirement def OverpressureSafetyRequirement {
        subject reliefValvePart : PressureReliefValve;
        constraint { reliefValvePart.inletPort.pressure < reliefValvePart.crackPressure
            implies reliefValvePart.outletPort.flowRate == 0 }
        constraint { reliefValvePart.inletPort.pressure >= reliefValvePart.crackPressure
            implies reliefValvePart.outletPort.flowRate > 0 }
    }

    requirement def StoreEnergyRequirement {
        doc /* The system shall store hydraulic energy in the form of pressurized fluid. */
    }

    requirement def SupplementPumpRequirement {
        doc /* The accumulator shall supplement the main pump during periods of high demand. */
    }

    requirement def AbsorbShocksRequirement {
        doc /* The system shall absorb pressure shocks to maintain stable operation. */
    }

    requirement def MaintainPressureRequirement {
        doc /* The system shall maintain system pressure within safe operating limits. */
    }

    part context {
        part reservoir : Reservoir {
            attribute :>> capacity = 100 [liter];
        }
        part pump : Pump {
            attribute :>> maxFlowRate = 50 [literPerSecond];
        }
        part accumulator : BladderAccumulator {
            attribute :>> maxPressure = 200 [bar];
            attribute :>> preChargePressure = 90 [bar];
            attribute :>> gasVolume = 40 [liter];
        }
        part actuator : HydraulicActuator {
            attribute :>> cylinderVolume = 20 [liter];
        }
        part pressureSensor : PressureSensor;
        part controlValve : ControlValve;
        part reliefValve : PressureReliefValve {
            attribute :>> crackPressure = 210 [bar];
        }

        flow of fluid : HydraulicFluid
            from reservoir.fluidPort.fluid to pump.suctionPort.fluid;
        flow of fluid : HydraulicFluid
            from pump.dischargePort.fluid to controlValve.inletPort.fluid;
        flow of fluid : HydraulicFluid
            from controlValve.outletPort.fluid to accumulator.fluidPort.fluid;
        flow of fluid : HydraulicFluid
            from accumulator.fluidPort.fluid to actuator.fluidPort.fluid;
        flow of fluid : HydraulicFluid
            from pump.dischargePort.fluid to actuator.fluidPort.fluid;
        flow of fluid : HydraulicFluid
            from pump.dischargePort.fluid to reliefValve.inletPort.fluid;
        flow of fluid : HydraulicFluid
            from reliefValve.outletPort.fluid to reservoir.fluidPort.fluid;

        bind pressureSensor.sensingPort.pressure = pump.dischargePort.pressure;

        state accumulatorStates : AccumulatorStates {
            in pumpFlow : FlowRate;
            in actuatorFlow : FlowRate;
            in accumulatorFluidVolume : Volume;

            entry; then idle;
            state idle;
            accept when pumpFlow > actuatorFlow then charging;
            state charging;
            accept when actuatorFlow > pumpFlow then discharging;
            state discharging;
            accept when accumulatorFluidVolume <= 0 [liter] then idle;
        }

        requirement overpressureSafety : OverpressureSafetyRequirement {
            subject :>> reliefValvePart = reliefValve;
        }
        requirement storeEnergyReq : StoreEnergyRequirement;
        requirement supplementPumpReq : SupplementPumpRequirement;
        requirement absorbShocksReq : AbsorbShocksRequirement;
        requirement maintainPressureReq : MaintainPressureRequirement;

        satisfy storeEnergyReq by accumulator;
        satisfy supplementPumpReq by accumulator;
        satisfy absorbShocksReq by accumulator;
        satisfy maintainPressureReq by reliefValve;
    }
}
