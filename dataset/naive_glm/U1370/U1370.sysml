package EductorJetPumpSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQ::Mass::*;
    import ISQ::Length::*;
    import ISQ::Time::*;
    import ISQ::Thermodynamics::*;

    // ---- Value types with units ----
    value def PressureValue :> Real { unit 'Pa'; }
    value def FlowRateValue :> Real { unit 'm3/s'; }
    value def VelocityValue :> Real { unit 'm/s'; }
    value def AreaValue :> Real { unit 'm2'; }
    value def DensityValue :> Real { unit 'kg/m3'; }
    value def EfficiencyValue :> Real { unit '1'; }
    value def LengthValue :> Real { unit 'm'; }
    value def DiameterValue :> Real { unit 'm'; }

    // ---- Item definitions ----
    item def Fluid {
        attribute density : DensityValue;
        attribute temperature : TemperatureValue;
        attribute dynamicViscosity : Real;
    }
    item def MotiveFluid :> Fluid;
    item def SuctionFluid :> Fluid;
    item def MixedFluid :> Fluid;

    // ---- Port definitions ----
    port def FluidInPort {
        in item stream : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    port def FluidOutPort {
        out item stream : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }
    port def MotivePort :> FluidInPort {
        redefinition stream : MotiveFluid;
    }
    port def SuctionPort :> FluidInPort {
        redefinition stream : SuctionFluid;
    }
    port def DischargePort :> FluidOutPort {
        redefinition stream : MixedFluid;
    }

    // ---- Internal components of the eductor-jet pump ----
    part def ConvergingNozzle {
        attribute inletDiameter : DiameterValue = 0.05;
        attribute outletDiameter : DiameterValue = 0.012;
        attribute length : LengthValue = 0.15;
        attribute efficiency : EfficiencyValue = 0.95;
        in port motiveIn : MotivePort;
        out port jetOut : FluidOutPort {
            redefinition stream : MotiveFluid;
        }
        action def Accelerate :> Action {
            in item inflow : MotiveFluid;
            out item outflow : MotiveFluid;
        }
        perform Accelerate {
            in inflow = motiveIn.stream;
            out outflow = jetOut.stream;
        }
    }

    part def SuctionChamber {
        attribute chamberVolume : AreaValue = 0.008;
        attribute vacuumPressure : PressureValue;
        in port jetIn : FluidInPort {
            redefinition stream : MotiveFluid;
        }
        in port suctionIn : SuctionPort;
        out port mixtureOut : FluidOutPort {
            redefinition stream : MixedFluid;
        }
        action def Entrain :> Action {
            in item jet : MotiveFluid;
            in item suction : SuctionFluid;
            out item mixture : MixedFluid;
        }
        perform Entrain {
            in jet = jetIn.stream;
            in suction = suctionIn.stream;
            out mixture = mixtureOut.stream;
        }
    }

    part def MixingThroat {
        attribute throatDiameter : DiameterValue = 0.020;
        attribute throatLength : LengthValue = 0.30;
        attribute mixingEfficiency : EfficiencyValue = 0.88;
        in port mixtureIn : FluidInPort {
            redefinition stream : MixedFluid;
        }
        out port mixedOut : FluidOutPort {
            redefinition stream : MixedFluid;
        }
        action def Mix :> Action {
            in item inflow : MixedFluid;
            out item outflow : MixedFluid;
        }
        perform Mix {
            in inflow = mixtureIn.stream;
            out outflow = mixedOut.stream;
        }
    }

    part def DivergingDiffuser {
        attribute inletDiameter : DiameterValue = 0.020;
        attribute outletDiameter : DiameterValue = 0.08;
        attribute length : LengthValue = 0.40;
        attribute recoveryFactor : EfficiencyValue = 0.82;
        in port diffuserIn : FluidInPort {
            redefinition stream : MixedFluid;
        }
        out port dischargeOut : DischargePort;
        action def Decelerate :> Action {
            in item inflow : MixedFluid;
            out item outflow : MixedFluid;
        }
        perform Decelerate {
            in inflow = diffuserIn.stream;
            out outflow = dischargeOut.stream;
        }
    }

    // ---- Eductor-jet pump assembly ----
    part def EductorJetPump {
        attribute designPressureRatio : Real = 2.5;
        attribute ratedMotiveFlow : FlowRateValue = 0.005;
        attribute ratedSuctionFlow : FlowRateValue = 0.003;
        attribute dischargePressure : PressureValue;

        port motiveSupply : MotivePort;
        port suctionSupply : SuctionPort;
        port discharge : DischargePort;

        part nozzle : ConvergingNozzle {
            connect motiveIn to motiveSupply;
        }
        part suctionChamber : SuctionChamber {
            connect suctionIn to suctionSupply;
        }
        part throat : MixingThroat;
        part diffuser : DivergingDiffuser {
            connect dischargeOut to discharge;
        }

        connect nozzle.jetOut to suctionChamber.jetIn;
        connect suctionChamber.mixtureOut to throat.mixtureIn;
        connect throat.mixedOut to diffuser.diffuserIn;
    }

    // ---- External system components ----
    part def HighPressureSource {
        attribute supplyPressure : PressureValue = 800000;
        attribute supplyFlowRate : FlowRateValue = 0.005;
        attribute motiveDensity : DensityValue = 1000;
        out port motiveOut : MotivePort;
        action def SupplyMotive :> Action {
            out item motive : MotiveFluid;
        }
        perform SupplyMotive {
            out motive = motiveOut.stream;
        }
    }

    part def SuctionReservoir {
        attribute initialLevel : LengthValue = 1.5;
        attribute surfacePressure : PressureValue = 101325;
        attribute fluidDensity : DensityValue = 1000;
        out port suctionOut : SuctionPort;
        action def ProvideSuction :> Action {
            out item suction : SuctionFluid;
        }
        perform ProvideSuction {
            out suction = suctionOut.stream;
        }
    }

    part def DischargeDestination {
        attribute backPressure : PressureValue = 250000;
        attribute capacity : AreaValue = 2.0;
        in port dischargeIn : DischargePort;
        action def ReceiveDischarge :> Action {
            in item discharge : MixedFluid;
        }
        perform ReceiveDischarge {
            in discharge = dischargeIn.stream;
        }
    }

    // ---- System-level assembly ----
    part EductorPumpingSystem {
        attribute systemEfficiency : EfficiencyValue;
        attribute totalDischargeFlow : FlowRateValue;

        part motiveSource : HighPressureSource;
        part suctionTank : SuctionReservoir;
        part eductor : EductorJetPump;
        part destination : DischargeDestination;

        connect motiveSource.motiveOut to eductor.motiveSupply;
        connect suctionTank.suctionOut to eductor.suctionSupply;
        connect eductor.discharge to destination.dischargeIn;
    }

    // ---- State machine for system operation lifecycle ----
    state def EductorOperation {
        attribute motiveFlowEstablished : Boolean;
        attribute steadyFlow : Boolean;
        attribute shutdownRequested : Boolean;

        entry; then idle;

        state idle {
            entry { motiveFlowEstablished = false; }
        }

        transition idle_to_starting
            first idle then starting
            when motiveFlowEstablished;

        state starting {
            entry { /* ramp motive flow */ }
            do { /* establish suction vacuum */ }
        }

        transition starting_to_operating
            first starting then operating
            when steadyFlow;

        state operating {
            entry { /* monitor pressures */ }
            do { /* regulate motive/suction balance */ }
        }

        transition operating_to_stopping
            first operating then stopping
            when shutdownRequested;

        state stopping {
            entry { /* reduce motive flow */ }
            do { /* vent and isolate */ }
        }

        transition stopping_to_idle
            first stopping then idle
            when not motiveFlowEstablished;
    }

    // ---- Requirements ----
    requirement def EductorPerformanceRequirement {
        subject eductor : EductorJetPump;
        attribute minDischargePressure : PressureValue = 250000;
        attribute minSuctionFlow : FlowRateValue = 0.002;
        require { eductor.discharge.pressure >= minDischargePressure; }
        require { eductor.ratedSuctionFlow >= minSuctionFlow; }
    }

    requirement def NoMovingPartsRequirement {
        subject pump : EductorJetPump;
        require { pump.nozzle.efficiency > 0.0; }
        require { pump.diffuser.recoveryFactor > 0.0; }
        doc { "The eductor-jet pump shall contain no moving mechanical components." }
    }

    requirement def LifecycleRequirement {
        subject system : EductorPumpingSystem;
        require { system satisfies EductorOperation; }
        doc { "System shall transition through idle, starting, operating, and stopping states." }
    }

    requirement EductorPerformance : EductorPerformanceRequirement {
        subject eductor :> EductorPumpingSystem.eductor;
    }
    requirement NoMovingParts : NoMovingPartsRequirement {
        subject pump :> EductorPumpingSystem.eductor;
    }
    requirement Lifecycle : LifecycleRequirement {
        subject system :> EductorPumpingSystem;
    }
}
