package GerotorPumpSystem {
    import ScalarValues::*;

    // ---- Value types with units ----
    value def TorqueValue :> Real { unit 'N*m'; }
    value def SpeedValue :> Real { unit 'rpm'; }
    value def PressureValue :> Real { unit 'bar'; }
    value def FlowRateValue :> Real { unit 'L/min'; }
    value def VolumeValue :> Real { unit 'cm^3'; }
    value def EfficiencyValue :> Real { unit '%'; }
    value def AngleValue :> Real { unit 'deg'; }
    value def PowerValue :> Real { unit 'kW'; }
    value def TemperatureValue :> Real { unit 'degC'; }

    // ---- Items ----
    item def HydraulicFluid {
        attribute density : Real = 850; // kg/L
        attribute viscosity : Real = 32; // cSt
        attribute temperature : TemperatureValue;
    }

    // ---- Port definitions ----
    port def MechanicalInputPort {
        in torque : TorqueValue;
        in speed : SpeedValue;
    }

    port def MechanicalOutputPort {
        out torque : TorqueValue;
        out speed : SpeedValue;
    }

    port def FluidInletPort {
        in fluid : HydraulicFluid;
        attribute inletPressure : PressureValue;
        attribute inletFlow : FlowRateValue;
    }

    port def FluidOutletPort {
        out fluid : HydraulicFluid;
        attribute outletPressure : PressureValue;
        attribute outletFlow : FlowRateValue;
    }

    port def ControlPort {
        in command : String;
        out status : String;
    }

    // ---- Requirements ----
    requirement def RatedFlowRateRequirement {
        subject pump : GerotorPump;
        attribute ratedFlow : FlowRateValue = 50.0;
        require { pump.deliveredFlow >= ratedFlow; }
    }

    requirement def MaxOperatingPressureRequirement {
        subject pump : GerotorPump;
        attribute maxPressure : PressureValue = 250.0;
        require { pump.outletPressure <= maxPressure; }
    }

    requirement def VolumetricEfficiencyRequirement {
        subject pump : GerotorPump;
        attribute minEfficiency : EfficiencyValue = 90.0;
        require { pump.volumetricEfficiency >= minEfficiency; }
    }

    requirement def LifecycleSafetyRequirement {
        subject pump : GerotorPump;
        require { pump.controller.lifecycle.currentState != null; }
    }

    // ---- State machine ----
    state def PumpLifecycle {
        attribute targetSpeed : SpeedValue = 1800;
        attribute currentSpeed : SpeedValue = 0;
        attribute currentState : String = "stopped";

        state stopped {
            entry { currentSpeed = 0; currentState = "stopped"; }
        }

        state starting {
            entry { currentState = "starting"; }
            do { currentSpeed = targetSpeed; }
        }

        state operational {
            entry { currentState = "operational"; }
            do { /* actively pumping fluid */ }
        }

        state stopping {
            entry { currentState = "stopping"; }
            do { currentSpeed = currentSpeed - 100; }
        }

        state emergency {
            entry { currentState = "emergency"; currentSpeed = 0; }
        }

        transition start_command
            from stopped to starting
            when controlPort.command == "start";

        transition reached_speed
            from starting to operational
            when currentSpeed >= targetSpeed;

        transition stop_command
            from operational to stopping
            when controlPort.command == "stop";

        transition stopped_complete
            from stopping to stopped
            when currentSpeed <= 0;

        transition emergency_from_operational
            from operational to emergency
            when controlPort.command == "emergency";

        transition emergency_from_starting
            from starting to emergency
            when controlPort.command == "emergency";

        transition emergency_from_stopping
            from stopping to emergency
            when controlPort.command == "emergency";

        transition emergency_reset
            from emergency to stopped
            when controlPort.command == "reset";
    }

    // ---- Component parts ----
    part def DriveShaft {
        port mechanicalIn : MechanicalInputPort;
        port mechanicalOut : MechanicalOutputPort;
        attribute transmittedTorque : TorqueValue;
        attribute rotationalSpeed : SpeedValue;
        attribute shaftDiameter : Real = 25; // mm

        action transmitPower {
            in torqueIn : TorqueValue = mechanicalIn.torque;
            in speedIn : SpeedValue = mechanicalIn.speed;
            out torqueOut : TorqueValue = torqueIn;
            out speedOut : SpeedValue = speedIn;
        }
    }

    part def InnerRotor {
        attribute lobeCount : Integer = 6;
        attribute eccentricity : Real = 3.5; // mm
        attribute pitchDiameter : Real = 60; // mm
        port mechanicalIn : MechanicalInputPort;
        port mechanicalOut : MechanicalOutputPort;

        action driveOuterRotor {
            in torqueIn : TorqueValue = mechanicalIn.torque;
            in speedIn : SpeedValue = mechanicalIn.speed;
            out torqueOut : TorqueValue = torqueIn * 0.95;
            out speedOut : SpeedValue = speedIn * (lobeCount / (lobeCount + 1));
        }
    }

    part def OuterRotor {
        attribute cavityCount : Integer = 7;
        attribute outerDiameter : Real = 80; // mm
        port mechanicalIn : MechanicalInputPort;

        action rotate {
            in torqueIn : TorqueValue = mechanicalIn.torque;
            in speedIn : SpeedValue = mechanicalIn.speed;
        }
    }

    part def PumpHousing {
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute material : String = "CastIron";
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
    }

    part def PumpingChamber {
        attribute chamberVolume : VolumeValue;
        attribute chamberPressure : PressureValue;
        attribute phase : String; // "expanding", "sealed", "compressing"
        item fluid : HydraulicFluid;

        action expand {
            out volumeOut : VolumeValue = chamberVolume * 1.5;
        }

        action seal {
            in fluidIn : HydraulicFluid;
        }

        action compress {
            out pressureOut : PressureValue = chamberPressure * 2.0;
        }
    }

    part def PumpController {
        port controlPort : ControlPort;
        attribute command : String = "none";
        attribute status : String = "idle";
        exhibit state lifecycle : PumpLifecycle;
    }

    // ---- Gerotor pump assembly ----
    part def GerotorPump {
        port mechanicalInput : MechanicalInputPort;
        port fluidInlet : FluidInletPort;
        port fluidOutlet : FluidOutletPort;
        port controlPort : ControlPort;

        attribute deliveredFlow : FlowRateValue;
        attribute outletPressure : PressureValue;
        attribute inletPressure : PressureValue;
        attribute volumetricEfficiency : EfficiencyValue;
        attribute displacement : VolumeValue = 12.0;
        attribute ratedSpeed : SpeedValue = 1800;

        part driveShaft : DriveShaft;
        part innerRotor : InnerRotor;
        part outerRotor : OuterRotor;
        part housing : PumpHousing;
        part chambers[7] : PumpingChamber;
        part controller : PumpController;

        satisfy RatedFlowRateRequirement by pump :>> self;
        satisfy MaxOperatingPressureRequirement by pump :>> self;
        satisfy VolumetricEfficiencyRequirement by pump :>> self;
        satisfy LifecycleSafetyRequirement by pump :>> self;

        connection driveToInnerRotor
            connect driveShaft.mechanicalOut to innerRotor.mechanicalIn;
        connection innerToOuterRotor
            connect innerRotor.mechanicalOut to outerRotor.mechanicalIn;
        connection inletToHousing
            connect fluidInlet to housing.inlet;
        connection housingToOutlet
            connect housing.outlet to fluidOutlet;
        connection controlToController
            connect controlPort to controller.controlPort;

        action pumpFluid {
            in fluidIn : HydraulicFluid;
            out fluidOut : HydraulicFluid;
            // Expanding chambers draw fluid in, sealed chambers carry fluid,
            // compressing chambers force fluid out at high pressure.
        }
    }

    // ---- External system context ----
    part def PowerSource {
        port mechanicalOut : MechanicalOutputPort;
        attribute outputTorque : TorqueValue = 50.0;
        attribute outputSpeed : SpeedValue = 1800;
        attribute powerType : String = "electric";
    }

    part def FluidReservoir {
        port fluidOut : FluidInletPort;
        item storedFluid : HydraulicFluid;
        attribute capacity : VolumeValue = 50.0;
        attribute level : VolumeValue = 40.0;
    }

    part def HydraulicLoad {
        port fluidIn : FluidOutletPort;
        attribute loadPressure : PressureValue = 200.0;
        attribute requiredFlow : FlowRateValue = 45.0;
    }

    part def Operator {
        port controlOut : ControlPort;
        attribute issuedCommand : String = "start";
    }

    // ---- Top-level system ----
    part def GerotorPumpSystem {
        part pump : GerotorPump;
        part powerSource : PowerSource;
        part reservoir : FluidReservoir;
        part load : HydraulicLoad;
        part operator : Operator;

        connection powerConnection
            connect powerSource.mechanicalOut to pump.mechanicalInput;
        connection supplyConnection
            connect reservoir.fluidOut to pump.fluidInlet;
        connection deliveryConnection
            connect pump.fluidOutlet to load.fluidIn;
        connection commandConnection
            connect operator.controlOut to pump.controlPort;
    }
}
