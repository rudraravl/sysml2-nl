package MechanicalHydraulicPowertrain {

    import ScalarValues::*;
    import ScalarFunctions::*;

    // ---- Value Types with Units ----
    value def Torque :> Real { unit 'N*m'; }
    value def RotationalSpeed :> Real { unit 'rad/s'; }
    value def AngularMomentum :> Real { unit 'kg*m^2/s'; }
    value def MomentOfInertia :> Real { unit 'kg*m^2'; }
    value def Pressure :> Real { unit 'Pa'; }
    value def VolumetricFlowRate :> Real { unit 'm^3/s'; }
    value def Force :> Real { unit 'N'; }
    value def LinearVelocity :> Real { unit 'm/s'; }
    value def Energy :> Real { unit 'J'; }
    value def Power :> Real { unit 'W'; }
    value def MassFlowRate :> Real { unit 'kg/s'; }
    value def Displacement :> Real { unit 'm'; }
    value def Temperature :> Real { unit 'K'; }
    value def Ratio :> Real { unit '1'; }

    // ---- Items ----
    item def Fuel {
        attribute energyDensity : Energy = 4.6e7 [J/kg];
    }
    item def HydraulicFluid {
        attribute density : Real = 850 [kg/m^3];
        attribute viscosity : Real = 0.04 [Pa*s];
        attribute bulkModulus : Pressure = 1.6e9 [Pa];
    }

    // ---- Port Definitions ----
    port def RotationalMechanicalPort {
        out speed : RotationalSpeed;
        out torque : Torque;
    }
    port def HydraulicFluidPort {
        out pressure : Pressure;
        out flowRate : VolumetricFlowRate;
    }
    port def FuelSupplyPort {
        in fuelFlow : MassFlowRate;
    }
    port def LinearMechanicalPort {
        out force : Force;
        out velocity : LinearVelocity;
    }
    port def CommandPort {
        in startCmd : Boolean;
        in stopCmd : Boolean;
        in emergencyStopCmd : Boolean;
    }
    port def StatusPort {
        out operationalState : String;
        out flywheelSpeed : RotationalSpeed;
        out hydraulicPressure : Pressure;
    }

    // ---- Engine (Prime Mover) ----
    part def Engine {
        port fuelIn : FuelSupplyPort;
        port shaftOut : RotationalMechanicalPort;
        port controlIn : CommandPort;

        attribute maxPower : Power = 250000 [W];
        attribute maxTorque : Torque = 850 [N*m];
        attribute idleSpeed : RotationalSpeed = 80 [rad/s];
        attribute ratedSpeed : RotationalSpeed = 220 [rad/s];
        attribute thermalEfficiency : Ratio = 0.38;

        attribute currentSpeed : RotationalSpeed = 0 [rad/s];
        attribute currentTorque : Torque = 0 [N*m];
        attribute fuelConsumption : MassFlowRate = 0 [kg/s];

        action def combustFuel {
            in fuel : MassFlowRate;
            out mechanicalPower : Power;
        }

        perform combustFuel {
            in fuel = fuelIn.fuelFlow;
            out mechanicalPower;
        }

        compute currentTorque : Torque = if currentSpeed > 0 [rad/s]
            then maxTorque * (1.0 - (currentSpeed / ratedSpeed))
            else 0 [N*m];

        compute shaftOut.speed : RotationalSpeed = currentSpeed;
        compute shaftOut.torque : Torque = currentTorque;
    }

    // ---- Mechanical Transmission ----
    part def Transmission {
        port inputShaft : RotationalMechanicalPort;
        port outputShaft : RotationalMechanicalPort;

        attribute gearRatio : Ratio = 3.5;
        attribute efficiency : Ratio = 0.96;

        compute outputShaft.speed : RotationalSpeed = inputShaft.speed / gearRatio;
        compute outputShaft.torque : Torque = inputShaft.torque * gearRatio * efficiency;
    }

    // ---- Flywheel (Rotational Inertia Storage) ----
    part def Flywheel {
        port inputShaft : RotationalMechanicalPort;
        port outputShaft : RotationalMechanicalPort;

        attribute momentOfInertia : MomentOfInertia = 25.0 [kg*m^2];
        attribute maxSafeSpeed : RotationalSpeed = 180 [rad/s];
        attribute minOperatingSpeed : RotationalSpeed = 20 [rad/s];
        attribute storedEnergy : Energy = 0.0 [J];
        attribute angularMomentum : AngularMomentum = 0.0 [kg*m^2/s];
        attribute currentSpeed : RotationalSpeed = 0 [rad/s];

        compute storedEnergy : Energy = 0.5 * momentOfInertia * currentSpeed * currentSpeed;
        compute angularMomentum : AngularMomentum = momentOfInertia * currentSpeed;
        compute outputShaft.speed : RotationalSpeed = currentSpeed;
        compute outputShaft.torque : Torque = inputShaft.torque;

        assert constraint SafeSpeed {
            currentSpeed <= maxSafeSpeed
        }
    }

    // ---- Hydraulic Pump ----
    part def HydraulicPump {
        port driveShaft : RotationalMechanicalPort;
        port fluidOut : HydraulicFluidPort;
        port suctionPort : HydraulicFluidPort;

        attribute displacementPerRev : Real = 0.00012 [m^3/rad];
        attribute volumetricEfficiency : Ratio = 0.94;
        attribute mechanicalEfficiency : Ratio = 0.92;
        attribute ratedPressure : Pressure = 3.0e7 [Pa];
        attribute outputPressure : Pressure = 0 [Pa];
        attribute outputFlow : VolumetricFlowRate = 0 [m^3/s];

        compute outputFlow : VolumetricFlowRate =
            driveShaft.speed * displacementPerRev * volumetricEfficiency;
        compute outputPressure : Pressure =
            (driveShaft.torque * driveShaft.speed * mechanicalEfficiency) /
            (if outputFlow > 0 [m^3/s] then outputFlow else 1e-6 [m^3/s]);

        compute fluidOut.pressure : Pressure = outputPressure;
        compute fluidOut.flowRate : VolumetricFlowRate = outputFlow;
    }

    // ---- Hydraulic Actuator (Linear Cylinder) ----
    part def HydraulicActuator {
        port fluidIn : HydraulicFluidPort;
        port returnPort : HydraulicFluidPort;
        port rodOut : LinearMechanicalPort;

        attribute pistonArea : Real = 0.015 [m^2];
        attribute strokeLength : Displacement = 1.2 [m];
        attribute currentDisplacement : Displacement = 0 [m];
        attribute maxForce : Force = 450000 [N];
        attribute outputForce : Force = 0 [N];
        attribute outputVelocity : LinearVelocity = 0 [m/s];

        compute outputForce : Force = fluidIn.pressure * pistonArea;
        compute outputVelocity : LinearVelocity = fluidIn.flowRate / pistonArea;

        compute rodOut.force : Force = outputForce;
        compute rodOut.velocity : LinearVelocity = outputVelocity;

        assert constraint MaxForceLimit {
            outputForce <= maxForce
        }
    }

    // ---- Hydraulic Reservoir ----
    part def HydraulicReservoir {
        port supplyPort : HydraulicFluidPort;
        port returnPort : HydraulicFluidPort;

        attribute capacity : Real = 0.05 [m^3];
        attribute fluidLevel : Real = 0.04 [m^3];
        attribute fluidTemperature : Temperature = 313 [K];

        item storedFluid : HydraulicFluid;

        compute supplyPort.pressure : Pressure = 1.0e5 [Pa];
        compute supplyPort.flowRate : VolumetricFlowRate = 0 [m^3/s];
    }

    // ---- Controller ----
    part def Controller {
        port commandIn : CommandPort;
        port statusOut : StatusPort;
        port engineControl : CommandPort;
        ref flywheelRef : Flywheel;
        ref pumpRef : HydraulicPump;

        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute emergencyStop : Boolean = false;
        attribute currentState : String = "standby";

        compute statusOut.flywheelSpeed : RotationalSpeed = flywheelRef.currentSpeed;
        compute statusOut.hydraulicPressure : Pressure = pumpRef.outputPressure;
        compute statusOut.operationalState : String = currentState;
    }

    // ---- System Lifecycle State Machine ----
    state def PowertrainLifecycle {
        entry action { /* initialize system */ }

        state standby {
            entry action { /* low power, awaiting command */ }
        }

        state starting {
            entry action { /* engage starter, ramp engine */ }
        }

        state running {
            entry action { /* normal operation */ }
        }

        state shuttingDown {
            entry action { /* graceful stop, dissipate flywheel */ }
        }

        state faulted {
            entry action { /* emergency stop, isolate power */ }
        }

        transition standby_to_starting
            first standby
            then starting
            accept Controller.startCommand;

        transition starting_to_running
            first starting
            then running
            when Flywheel.currentSpeed >= Flywheel.minOperatingSpeed;

        transition running_to_shuttingDown
            first running
            then shuttingDown
            accept Controller.stopCommand;

        transition shuttingDown_to_standby
            first shuttingDown
            then standby
            when Flywheel.currentSpeed <= 1 [rad/s];

        transition any_to_faulted
            first standby | starting | running | shuttingDown
            then faulted
            accept Controller.emergencyStop;

        transition faulted_to_standby
            first faulted
            then standby
            when Flywheel.currentSpeed <= 0.5 [rad/s];
    }

    // ---- Top-Level Powertrain System ----
    part def PowertrainSystem {
        port commandPort : CommandPort;
        port statusPort : StatusPort;
        port fuelSupply : FuelSupplyPort;
        port workOutput : LinearMechanicalPort;

        part engine : Engine {
            port fuelIn : FuelSupplyPort;
            port shaftOut : RotationalMechanicalPort;
        }

        part transmission : Transmission {
            port inputShaft : RotationalMechanicalPort;
            port outputShaft : RotationalMechanicalPort;
        }

        part flywheel : Flywheel {
            port inputShaft : RotationalMechanicalPort;
            port outputShaft : RotationalMechanicalPort;
        }

        part pump : HydraulicPump {
            port driveShaft : RotationalMechanicalPort;
            port fluidOut : HydraulicFluidPort;
            port suctionPort : HydraulicFluidPort;
        }

        part actuator : HydraulicActuator {
            port fluidIn : HydraulicFluidPort;
            port returnPort : HydraulicFluidPort;
            port rodOut : LinearMechanicalPort;
        }

        part reservoir : HydraulicReservoir {
            port supplyPort : HydraulicFluidPort;
            port returnPort : HydraulicFluidPort;
        }

        part controller : Controller {
            port commandIn : CommandPort;
            port statusOut : StatusPort;
            port engineControl : CommandPort;
        }

        // Connections
        connect fuelSupply to engine.fuelIn;
        connect engine.shaftOut to transmission.inputShaft;
        connect transmission.outputShaft to flywheel.inputShaft;
        connect flywheel.outputShaft to pump.driveShaft;
        connect reservoir.supplyPort to pump.suctionPort;
        connect pump.fluidOut to actuator.fluidIn;
        connect actuator.returnPort to reservoir.returnPort;
        connect actuator.rodOut to workOutput;
        connect commandPort to controller.commandIn;
        connect controller.statusOut to statusPort;
        connect controller.engineControl to engine.controlIn;

        // Controller references
        bind controller.flywheelRef = flywheel;
        bind controller.pumpRef = pump;

        // Lifecycle behavior
        exhibit PowertrainLifecycle;

        // System-level attributes
        attribute totalEfficiency : Ratio;
        attribute systemOutputForce : Force = actuator.outputForce;
        attribute systemOutputVelocity : LinearVelocity = actuator.outputVelocity;
    }

    // ---- Requirements ----
    requirement def PowerGenerationRequirement {
        subject : PowertrainSystem;
        objective {
            doc "The system shall convert fuel energy into controlled linear force and motion."
        }
    }

    requirement PowerOutputRequirement :> PowerGenerationRequirement {
        doc "The system shall deliver a minimum linear force of 400000 N at the actuator rod."
        requirement {
            subject.systemOutputForce >= 400000 [N]
        }
    }

    requirement FlywheelSafetyRequirement {
        doc "The flywheel shall not exceed its maximum safe operating speed to prevent mechanical failure."
        subject : Flywheel;
        requirement {
            subject.currentSpeed <= subject.maxSafeSpeed
        }
    }

    requirement SmoothPowerDeliveryRequirement {
        doc "The flywheel shall buffer rotational energy to smooth output fluctuations of at least 20% of rated engine torque."
        subject : Flywheel;
        requirement {
            subject.storedEnergy >= 0.5 * subject.momentOfInertia * subject.minOperatingSpeed * subject.minOperatingSpeed
        }
    }

    requirement HydraulicPressureRequirement {
        doc "The hydraulic pump shall deliver fluid at a pressure of at least 25 MPa during running state."
        subject : HydraulicPump;
        requirement {
            subject.outputPressure >= 2.5e7 [Pa]
        }
    }

    requirement LifecycleRequirement {
        doc "The system shall operate through standby, starting, running, and shutting down states managed by start and stop commands."
        subject : PowertrainSystem;
        requirement {
            subject.exhibit PowertrainLifecycle
        }
    }

    // ---- Verification ----
    verification VerifyPowerOutput {
        subject : PowertrainSystem;
        objective {
            doc "Confirm actuator output force meets or exceeds 400000 N under rated conditions."
        }
        return success : Boolean = (subject.systemOutputForce >= 400000 [N]);
    }

    verification VerifyFlywheelSafety {
        subject : Flywheel;
        objective {
            doc "Confirm flywheel speed remains below maxSafeSpeed during all operating states."
        }
        return success : Boolean = (subject.currentSpeed <= subject.maxSafeSpeed);
    }

    verification VerifyHydraulicPressure {
        subject : HydraulicPump;
        objective {
            doc "Confirm pump output pressure meets minimum during running state."
        }
        return success : Boolean = (subject.outputPressure >= 2.5e7 [Pa]);
    }

}
