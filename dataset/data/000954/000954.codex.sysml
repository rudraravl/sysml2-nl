package VoluteSystemModel {
    import ScalarValues::*;
    import SI::*;

    attribute def Pressure {
        :> ScalarValues::Real;
        unit = "Pa";
    }

    attribute def FlowRate {
        :> ScalarValues::Real;
        unit = "m^3/s";
    }

    attribute def Velocity {
        :> ScalarValues::Real;
        unit = "m/s";
    }

    attribute def RotationalSpeed {
        :> ScalarValues::Real;
        unit = "rpm";
    }

    attribute def Efficiency {
        :> ScalarValues::Real;
        unit = "1";
    }

    item def WorkingFluid {
        attribute density : Real = 998.0;
        attribute dynamicViscosity : Real = 0.001;
        attribute vaporPressure : Pressure = 2339.0;
    }

    item def HydraulicEnergy {
        attribute staticPressure : Pressure;
        attribute dynamicPressure : Pressure;
        attribute velocity : Velocity;
        attribute volumetricFlow : FlowRate;
    }

    port def FluidPort {
        inout fluid : WorkingFluid;
        inout energy : HydraulicEnergy;
    }

    port def ShaftPort {
        in torque : Real;
        in speed : RotationalSpeed;
    }

    action def CollectAndDiffuseFlow {
        in inletEnergy : HydraulicEnergy;
        out outletEnergy : HydraulicEnergy;

        attribute recoveryEfficiency : Efficiency = 0.78;
        attribute designFlow : FlowRate = 0.065;
        attribute targetPressureRise : Pressure = 145000.0;

        objective {
            doc /* Collect high-velocity fluid leaving the impeller, reduce circumferential velocity through the expanding volute passage, and deliver a steadier higher-pressure flow to the discharge nozzle. */
        }
    }

    state def VoluteOperatingState {
        state idle;
        state priming;
        state pumping;
        state offDesignRecirculation;
        state shutdown;

        initial then idle;

        transition idle_to_priming
            first idle
            then priming;

        transition priming_to_pumping
            first priming
            then pumping
            if fillFraction >= 0.95;

        transition pumping_to_offDesign
            first pumping
            then offDesignRecirculation
            if flowDeviation > 0.20;

        transition offDesign_to_pumping
            first offDesignRecirculation
            then pumping
            if flowDeviation <= 0.10;

        transition pumping_to_shutdown
            first pumping
            then shutdown;

        transition shutdown_to_idle
            first shutdown
            then idle;

        attribute fillFraction : Real;
        attribute flowDeviation : Real;
    }

    part def Impeller {
        port suction : FluidPort;
        port discharge : FluidPort;
        port shaft : ShaftPort;

        attribute nominalSpeed : RotationalSpeed = 1750.0;
        attribute outletVelocity : Velocity = 18.5;
        attribute bladeOutletAngle : Real = 23.0;
    }

    part def Volute {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute throatArea : Real = 0.0032;
        attribute baseCircleDiameter : Real = 0.185;
        attribute cutwaterClearance : Real = 0.004;
        attribute wrapAngle : Real = 360.0;
        attribute diffusionRatio : Real = 1.85;
        attribute hydraulicRecoveryEfficiency : Efficiency = 0.78;

        perform action collectAndDiffuse : CollectAndDiffuseFlow {
            inletEnergy = inlet.energy;
            outletEnergy = outlet.energy;
        }

        exhibit state operatingState : VoluteOperatingState;
    }

    part def DischargeNozzle {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute outletDiameter : Real = 0.075;
        attribute allowablePressureLoss : Pressure = 8500.0;
    }

    part def PumpHousing {
        part impeller : Impeller;
        part volute : Volute;
        part nozzle : DischargeNozzle;

        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port drivePort : ShaftPort;

        connect suctionPort to impeller.suction;
        connect drivePort to impeller.shaft;
        connect impeller.discharge to volute.inlet;
        connect volute.outlet to nozzle.inlet;
        connect nozzle.outlet to dischargePort;
    }

    part def VoluteBasedPumpSystem {
        part hydraulicAssembly : PumpHousing;

        port fluidInlet : FluidPort;
        port fluidOutlet : FluidPort;
        port mechanicalDrive : ShaftPort;

        attribute ratedFlow : FlowRate = 0.065;
        attribute ratedPressureRise : Pressure = 145000.0;
        attribute minimumHydraulicEfficiency : Efficiency = 0.70;
        attribute maximumContinuousSpeed : RotationalSpeed = 1800.0;

        connect fluidInlet to hydraulicAssembly.suctionPort;
        connect fluidOutlet to hydraulicAssembly.dischargePort;
        connect mechanicalDrive to hydraulicAssembly.drivePort;

        perform action primaryFunction : CollectAndDiffuseFlow {
            inletEnergy = hydraulicAssembly.volute.inlet.energy;
            outletEnergy = hydraulicAssembly.volute.outlet.energy;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The system shall use a volute passage to collect fluid discharged from the impeller, convert a portion of the fluid velocity head into static pressure, and route the pressurized flow to a single discharge outlet. */
    }

    requirement def PressureRecoveryRequirement {
        doc /* At rated flow, the volute shall contribute to a total static pressure rise of at least 145000 Pa across the pump system. */
        require constraint {
            VoluteBasedPumpSystem::ratedPressureRise >= 145000.0
        }
    }

    requirement def FlowContinuityRequirement {
        doc /* The volute shall maintain continuous fluid flow from impeller discharge to discharge nozzle without dead-ended flow paths during normal pumping operation. */
    }

    requirement def EfficiencyRequirement {
        doc /* At rated flow and speed, the hydraulic assembly shall achieve hydraulic efficiency of at least 0.70. */
        require constraint {
            VoluteBasedPumpSystem::minimumHydraulicEfficiency >= 0.70
        }
    }

    requirement def MechanicalSpeedRequirement {
        doc /* The system shall operate continuously without exceeding a shaft speed of 1800 rpm. */
        require constraint {
            VoluteBasedPumpSystem::maximumContinuousSpeed <= 1800.0
        }
    }

    requirement def CutwaterClearanceRequirement {
        doc /* The volute cutwater clearance shall be large enough to reduce blade passing pressure pulsation while preserving pressure recovery. */
        require constraint {
            Volute::cutwaterClearance >= 0.003 and Volute::cutwaterClearance <= 0.006
        }
    }

    satisfy PrimaryFunctionRequirement by VoluteBasedPumpSystem::primaryFunction;
    satisfy PressureRecoveryRequirement by VoluteBasedPumpSystem::hydraulicAssembly;
    satisfy FlowContinuityRequirement by VoluteBasedPumpSystem::hydraulicAssembly::volute;
    satisfy EfficiencyRequirement by VoluteBasedPumpSystem;
    satisfy MechanicalSpeedRequirement by VoluteBasedPumpSystem::mechanicalDrive;
    satisfy CutwaterClearanceRequirement by VoluteBasedPumpSystem::hydraulicAssembly::volute;
}