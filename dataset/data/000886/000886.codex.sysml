package GerotorPumpSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :> scalar;
        unit = Pa;
    }

    attribute def FlowRate {
        :> scalar;
        unit = m^3 / s;
    }

    attribute def RotationalSpeed {
        :> scalar;
        unit = rad / s;
    }

    attribute def Torque {
        :> scalar;
        unit = N * m;
    }

    attribute def Temperature {
        :> scalar;
        unit = K;
    }

    attribute def Volume {
        :> scalar;
        unit = m^3;
    }

    attribute def Efficiency {
        :> scalar;
    }

    item def HydraulicFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute volumetricFlowRate : FlowRate;
        attribute viscosity : scalar;
    }

    item def MechanicalPower {
        attribute shaftSpeed : RotationalSpeed;
        attribute shaftTorque : Torque;
    }

    port def FluidPort {
        inout fluid : HydraulicFluid;
    }

    port def ShaftPort {
        inout power : MechanicalPower;
    }

    port def ControlPort {
        in enable : Boolean;
        in commandedSpeed : RotationalSpeed;
        out faultActive : Boolean;
    }

    part def GerotorPump {
        attribute displacementPerRevolution : Volume = 8.5e-6 [m^3];
        attribute nominalSpeed : RotationalSpeed = 314.16 [rad / s];
        attribute maximumSpeed : RotationalSpeed = 523.6 [rad / s];
        attribute maximumOutletPressure : Pressure = 1.2e7 [Pa];
        attribute volumetricEfficiency : Efficiency = 0.88;
        attribute mechanicalEfficiency : Efficiency = 0.82;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port driveShaft : ShaftPort;
        port control : ControlPort;

        part innerRotor {
            attribute toothCount : Integer = 6;
            attribute eccentricity : LengthValue = 0.0018 [m];
            attribute angularSpeed : RotationalSpeed;
        }

        part outerRotor {
            attribute lobeCount : Integer = 7;
            attribute angularSpeed : RotationalSpeed;
        }

        part pumpHousing {
            attribute inletCavityVolume : Volume = 2.2e-5 [m^3];
            attribute outletCavityVolume : Volume = 2.0e-5 [m^3];
            attribute allowableTemperature : Temperature = 423.15 [K];
        }

        part crescentSeal {
            attribute minimumTipClearance : LengthValue = 4.0e-5 [m];
            attribute maximumTipClearance : LengthValue = 9.0e-5 [m];
        }

        action def ConvertRotationToFlow {
            in shaftPower : MechanicalPower;
            in inletFluid : HydraulicFluid;
            out outletFluid : HydraulicFluid;

            attribute theoreticalFlow : FlowRate;
            attribute actualFlow : FlowRate;
            attribute pressureRise : Pressure;

            theoreticalFlow = displacementPerRevolution * shaftPower.shaftSpeed / (2.0 * pi);
            actualFlow = theoreticalFlow * volumetricEfficiency;
            outletFluid.volumetricFlowRate = actualFlow;
            outletFluid.temperature = inletFluid.temperature;
            outletFluid.pressure = inletFluid.pressure + pressureRise;
        }

        state def PumpOperatingState {
            state off;
            state priming;
            state pumping;
            state pressureLimited;
            state fault;

            entry; then off;

            transition off_to_priming
                first off
                accept control.enable == true
                then priming;

            transition priming_to_pumping
                first priming
                accept inlet.fluid.pressure > 5.0e4 [Pa]
                then pumping;

            transition pumping_to_pressureLimited
                first pumping
                accept outlet.fluid.pressure >= maximumOutletPressure
                then pressureLimited;

            transition pressureLimited_to_pumping
                first pressureLimited
                accept outlet.fluid.pressure < 0.95 * maximumOutletPressure
                then pumping;

            transition any_to_fault
                first off, priming, pumping, pressureLimited
                accept pumpHousing.allowableTemperature < inlet.fluid.temperature
                then fault;

            transition fault_to_off
                first fault
                accept control.enable == false
                then off;
        }

        behavior pumpBehavior : PumpOperatingState;

        perform action ConvertRotationToFlow {
            in shaftPower = driveShaft.power;
            in inletFluid = inlet.fluid;
            out outletFluid = outlet.fluid;
        }
    }

    part def ElectricDrive {
        attribute ratedTorque : Torque = 22.0 [N * m];
        attribute ratedSpeed : RotationalSpeed = 314.16 [rad / s];
        attribute maximumTorque : Torque = 35.0 [N * m];

        port shaftOutput : ShaftPort;
        port command : ControlPort;

        action def RegulateSpeed {
            in requestedSpeed : RotationalSpeed;
            out deliveredPower : MechanicalPower;

            deliveredPower.shaftSpeed =
                if requestedSpeed <= ratedSpeed then requestedSpeed else ratedSpeed;
            deliveredPower.shaftTorque = ratedTorque;
        }
    }

    part def FluidReservoir {
        attribute capacity : Volume = 0.012 [m^3];
        attribute nominalFluidTemperature : Temperature = 333.15 [K];
        attribute staticHeadPressure : Pressure = 1.1e5 [Pa];

        port supplyOutlet : FluidPort;
        port returnInlet : FluidPort;
    }

    part def PressureReliefValve {
        attribute crackingPressure : Pressure = 1.05e7 [Pa];
        attribute fullOpenPressure : Pressure = 1.2e7 [Pa];
        attribute bypassFlowCapacity : FlowRate = 7.5e-4 [m^3 / s];

        port highPressureInlet : FluidPort;
        port bypassOutlet : FluidPort;

        state def ReliefValveState {
            state closed;
            state opening;
            state open;

            entry; then closed;

            transition closed_to_opening
                first closed
                accept highPressureInlet.fluid.pressure >= crackingPressure
                then opening;

            transition opening_to_open
                first opening
                accept highPressureInlet.fluid.pressure >= fullOpenPressure
                then open;

            transition open_to_closed
                first open
                accept highPressureInlet.fluid.pressure < crackingPressure
                then closed;
        }

        behavior reliefBehavior : ReliefValveState;
    }

    part def OutletLoad {
        attribute requiredMinimumPressure : Pressure = 4.0e6 [Pa];
        attribute maximumAllowedPressure : Pressure = 1.1e7 [Pa];
        attribute nominalDemandFlow : FlowRate = 4.8e-4 [m^3 / s];

        port pressureSupply : FluidPort;
        port returnFlow : FluidPort;
    }

    part def GerotorHydraulicSupplySystem {
        attribute systemNominalFlow : FlowRate = 4.0e-4 [m^3 / s];
        attribute systemNominalPressure : Pressure = 7.0e6 [Pa];
        attribute startupTimeLimit : TimeValue = 2.0 [s];

        part reservoir : FluidReservoir;
        part drive : ElectricDrive;
        part pump : GerotorPump;
        part reliefValve : PressureReliefValve;
        part load : OutletLoad;

        port externalControl : ControlPort;
        port hydraulicOutput : FluidPort;
        port hydraulicReturn : FluidPort;

        connect externalControl to drive.command;
        connect drive.shaftOutput to pump.driveShaft;
        connect reservoir.supplyOutlet to pump.inlet;
        connect pump.outlet to reliefValve.highPressureInlet;
        connect reliefValve.highPressureInlet to load.pressureSupply;
        connect reliefValve.bypassOutlet to reservoir.returnInlet;
        connect load.returnFlow to reservoir.returnInlet;
        connect load.pressureSupply to hydraulicOutput;
        connect reservoir.returnInlet to hydraulicReturn;
        connect drive.command to pump.control;

        action def SupplyPressurizedFluid {
            in enableCommand : Boolean;
            in requestedSpeed : RotationalSpeed;
            out deliveredFluid : HydraulicFluid;

            drive.command.enable = enableCommand;
            drive.command.commandedSpeed = requestedSpeed;
            deliveredFluid = pump.outlet.fluid;
        }

        state def SystemState {
            state disabled;
            state starting;
            state supplying;
            state bypassing;
            state shutdown;
            state failed;

            entry; then disabled;

            transition disabled_to_starting
                first disabled
                accept externalControl.enable == true
                then starting;

            transition starting_to_supplying
                first starting
                accept pump.outlet.fluid.pressure >= load.requiredMinimumPressure
                then supplying;

            transition supplying_to_bypassing
                first supplying
                accept pump.outlet.fluid.pressure >= reliefValve.crackingPressure
                then bypassing;

            transition bypassing_to_supplying
                first bypassing
                accept pump.outlet.fluid.pressure < reliefValve.crackingPressure
                then supplying;

            transition supplying_to_shutdown
                first supplying
                accept externalControl.enable == false
                then shutdown;

            transition shutdown_to_disabled
                first shutdown
                accept drive.shaftOutput.power.shaftSpeed == 0.0 [rad / s]
                then disabled;

            transition any_to_failed
                first starting, supplying, bypassing
                accept pump.outlet.fluid.pressure > load.maximumAllowedPressure
                then failed;
        }

        behavior operatingMode : SystemState;
    }

    requirement def PrimaryFunctionRequirement {
        subject system : GerotorHydraulicSupplySystem;

        doc
        /*
         The gerotor-based system shall convert rotary mechanical input into continuous hydraulic fluid flow by using an internally meshing inner rotor and outer rotor to expand inlet chambers, draw fluid from a reservoir, contract outlet chambers, and deliver pressurized fluid to a hydraulic load.
        */

        require constraint {
            system.pump.outlet.fluid.volumetricFlowRate >= system.systemNominalFlow
        }

        require constraint {
            system.pump.outlet.fluid.pressure >= system.systemNominalPressure
        }
    }

    requirement def PressureProtectionRequirement {
        subject system : GerotorHydraulicSupplySystem;

        doc
        /*
         The system shall limit discharge pressure by bypassing excess pump flow to the reservoir when outlet pressure reaches the relief valve cracking pressure.
        */

        require constraint {
            system.reliefValve.crackingPressure < system.load.maximumAllowedPressure
        }

        require constraint {
            system.pump.maximumOutletPressure <= system.reliefValve.fullOpenPressure
        }
    }

    requirement def StartupRequirement {
        subject system : GerotorHydraulicSupplySystem;

        doc
        /*
         The system shall reach the load minimum supply pressure within the allowed startup interval after receiving an enable command.
        */

        require constraint {
            system.startupTimeLimit <= 2.0 [s]
        }

        require constraint {
            system.load.requiredMinimumPressure <= system.systemNominalPressure
        }
    }

    requirement def DriveCompatibilityRequirement {
        subject system : GerotorHydraulicSupplySystem;

        doc
        /*
         The electric drive shall provide sufficient torque and speed to rotate the gerotor pump at nominal operating conditions.
        */

        require constraint {
            system.drive.ratedSpeed >= system.pump.nominalSpeed
        }

        require constraint {
            system.drive.maximumTorque >=
                (system.systemNominalPressure * system.pump.displacementPerRevolution)
                / (2.0 * pi * system.pump.mechanicalEfficiency)
        }
    }

    satisfy PrimaryFunctionRequirement by GerotorHydraulicSupplySystem;
    satisfy PressureProtectionRequirement by GerotorHydraulicSupplySystem;
    satisfy StartupRequirement by GerotorHydraulicSupplySystem;
    satisfy DriveCompatibilityRequirement by GerotorHydraulicSupplySystem;
}