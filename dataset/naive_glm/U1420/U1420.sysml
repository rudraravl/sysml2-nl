package GasTurbineEngine {
    import ScalarValues::*;

    // ===== Units =====
    unit def pascal;
    unit def kelvin;
    unit def second;
    unit def kilogram;
    unit def metre;
    unit def radian;
    unit def newton;
    unit def newton_metre;
    unit def watt;
    unit def joule;
    unit def kg_per_s;
    unit def rad_per_s;
    unit def m3_per_s;

    // ===== Value Types =====
    value def Pressure :> Real { unit = pascal; }
    value def Temperature :> Real { unit = kelvin; }
    value def MassFlowRate :> Real { unit = kg_per_s; }
    value def RotationalSpeed :> Real { unit = rad_per_s; }
    value def Torque :> Real { unit = newton_metre; }
    value def Power :> Real { unit = watt; }
    value def Energy :> Real { unit = joule; }
    value def VolumeFlowRate :> Real { unit = m3_per_s; }
    value def PressureRatio :> Real;
    value def Efficiency :> Real;
    value def Duration :> Real { unit = second; }
    value def FuelAirRatio :> Real;

    // ===== Item Definitions =====
    item def Air {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
    }

    item def CompressedAir :> Air {
        attribute pressureRatio : PressureRatio;
    }

    item def Fuel {
        attribute massFlowRate : MassFlowRate;
        attribute lowerHeatingValue : Energy;
        attribute supplyPressure : Pressure;
    }

    item def CombustionGas {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
    }

    item def ExhaustGas {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute massFlowRate : MassFlowRate;
    }

    // ===== Port Definitions =====
    port def AirInPort {
        in item : Air;
    }

    port def CompressedAirOutPort {
        out item : CompressedAir;
    }

    port def CompressedAirInPort {
        in item : CompressedAir;
    }

    port def FuelInPort {
        in item : Fuel;
    }

    port def FuelOutPort {
        out item : Fuel;
    }

    port def CombustionGasOutPort {
        out item : CombustionGas;
    }

    port def CombustionGasInPort {
        in item : CombustionGas;
    }

    port def ExhaustOutPort {
        out item : ExhaustGas;
    }

    port def RotationalMechanicalPort {
        attribute rotationalSpeed : RotationalSpeed;
        attribute torque : Torque;
    }

    port def PowerOutputPort :> RotationalMechanicalPort {
        attribute power : Power;
    }

    port def ControlCommandPort {
        attribute fuelFlowCommand : MassFlowRate;
        attribute startCommand : Boolean;
        attribute stopCommand : Boolean;
    }

    port def SensorFeedbackPort {
        attribute rotationalSpeed : RotationalSpeed;
        attribute turbineInletTemperature : Temperature;
        attribute exhaustTemperature : Temperature;
        attribute powerOutput : Power;
    }

    // ===== Part Definitions =====

    part def Compressor {
        port airIn : AirInPort;
        port airOut : CompressedAirOutPort;
        port shaftDrive : RotationalMechanicalPort;

        attribute pressureRatio : PressureRatio = 12.0;
        attribute isentropicEfficiency : Efficiency = 0.88;
        attribute nominalMassFlowRate : MassFlowRate = 100.0;
        attribute inletTemperature : Temperature;
        attribute outletTemperature : Temperature;
        attribute outletPressure : Pressure;
        attribute requiredPower : Power;

        action def CompressAir {
            in intakeAir : Air;
            in shaftPower : Power;
            out compressedAir : CompressedAir;
        }

        perform compress : CompressAir;
    }

    part def CombustionChamber {
        port airIn : CompressedAirInPort;
        port fuelIn : FuelInPort;
        port gasOut : CombustionGasOutPort;

        attribute fuelAirRatio : FuelAirRatio = 0.02;
        attribute combustionEfficiency : Efficiency = 0.99;
        attribute maxOutletTemperature : Temperature = 1800.0;
        attribute pressureLoss : Pressure = 50000.0;
        attribute outletTemperature : Temperature;
        attribute outletPressure : Pressure;

        action def CombustFuel {
            in compressedAir : CompressedAir;
            in fuel : Fuel;
            out combustionGas : CombustionGas;
        }

        perform combust : CombustFuel;
    }

    part def Turbine {
        port gasIn : CombustionGasInPort;
        port gasOut : ExhaustOutPort;
        port shaftDrive : RotationalMechanicalPort;

        attribute isentropicEfficiency : Efficiency = 0.90;
        attribute expansionRatio : PressureRatio;
        attribute inletTemperature : Temperature;
        attribute outletTemperature : Temperature;
        attribute producedPower : Power;

        action def ExpandGas {
            in combustionGas : CombustionGas;
            out exhaustGas : ExhaustGas;
            out mechanicalPower : Power;
        }

        perform expand : ExpandGas;
    }

    part def Shaft {
        port turbineEnd : RotationalMechanicalPort;
        port compressorEnd : RotationalMechanicalPort;
        port outputEnd : PowerOutputPort;

        attribute rotationalSpeed : RotationalSpeed;
        attribute maxTorque : Torque = 5000.0;
        attribute turbinePower : Power;
        attribute compressorPower : Power;
        attribute netPower : Power;

        action def TransmitPower {
            in turbinePower : Power;
            out compressorPower : Power;
            out netPower : Power;
        }

        perform transmit : TransmitPower;
    }

    part def FuelPump {
        port fuelSupply : FuelInPort;
        port fuelDelivery : FuelOutPort;
        port controlInput : ControlCommandPort;

        attribute fuelPressure : Pressure = 5000000.0;
        attribute maxFuelFlowRate : MassFlowRate = 5.0;
        attribute currentFuelFlowRate : MassFlowRate;

        action def PumpAndMeter {
            in command : MassFlowRate;
            in supplyFuel : Fuel;
            out deliveredFuel : Fuel;
        }

        perform pump : PumpAndMeter;
    }

    part def FuelTank {
        port fuelOutlet : FuelOutPort;

        attribute capacity : MassFlowRate = 500.0;
        attribute currentLevel : MassFlowRate;
        attribute fuelLowerHeatingValue : Energy = 43000000.0;

        action def SupplyFuel {
            out fuel : Fuel;
        }

        perform supply : SupplyFuel;
    }

    part def FuelSystem {
        port fuelDelivery : FuelOutPort;
        port controlInput : ControlCommandPort;

        part tank : FuelTank;
        part pump : FuelPump;

        connect tank.fuelOutlet to pump.fuelSupply;
        connect pump.fuelDelivery to fuelDelivery;
        connect controlInput to pump.controlInput;

        flow from tank.fuelOutlet to pump.fuelSupply : Fuel;
        flow from pump.fuelDelivery to fuelDelivery : Fuel;
    }

    part def StarterMotor {
        port shaftConnection : RotationalMechanicalPort;
        port controlInput : ControlCommandPort;

        attribute crankingSpeed : RotationalSpeed = 100.0;
        attribute crankingTorque : Torque = 500.0;
        attribute active : Boolean = false;

        action def Crank {
            out mechanicalPower : Power;
        }

        perform crank : Crank;
    }

    part def ControlSystem {
        port sensorFeedback : SensorFeedbackPort;
        port fuelCommand : ControlCommandPort;
        port starterCommand : ControlCommandPort;
        attribute powerDemand : Power;

        attribute targetSpeed : RotationalSpeed = 1000.0;
        attribute maxTurbineInletTemp : Temperature = 1600.0;
        attribute maxExhaustTemp : Temperature = 900.0;
        attribute startupFuelFlow : MassFlowRate = 0.5;
        attribute minStableFuelFlow : MassFlowRate = 0.2;
        attribute currentFuelCommand : MassFlowRate;

        state machine controlStateMachine {
            state Off;
            state Starting;
            state Running;
            state Shutdown;

            transition offToStarting first Off to Starting
                when powerDemand > 0.0;
            transition startingToRunning Starting to Running
                when sensorFeedback.rotationalSpeed >= targetSpeed * 0.95;
            transition runningToShutdown Running to Shutdown
                when powerDemand == 0.0;
            transition shutdownToOff Shutdown to Off
                when sensorFeedback.rotationalSpeed == 0.0;
        }

        perform controlLogic : controlStateMachine;

        action def RegulateFuel {
            in speed : RotationalSpeed;
            in turbineInletTemp : Temperature;
            in exhaustTemp : Temperature;
            in demand : Power;
            out fuelCommand : MassFlowRate;
        }

        perform regulate : RegulateFuel;
    }

    // ===== Engine Assembly =====
    part def Engine {
        port airIntake : AirInPort;
        port exhaust : ExhaustOutPort;
        port powerOutput : PowerOutputPort;
        attribute powerDemand : Power;

        part compressor : Compressor;
        part combustionChamber : CombustionChamber;
        part turbine : Turbine;
        part shaft : Shaft;
        part fuelSystem : FuelSystem;
        part controlSystem : ControlSystem;
        part starter : StarterMotor;

        // Fluid connections
        connect airIntake to compressor.airIn;
        connect compressor.airOut to combustionChamber.airIn;
        connect combustionChamber.gasOut to turbine.gasIn;
        connect turbine.gasOut to exhaust;

        // Fuel connections
        connect fuelSystem.fuelDelivery to combustionChamber.fuelIn;

        // Mechanical connections
        connect turbine.shaftDrive to shaft.turbineEnd;
        connect shaft.compressorEnd to compressor.shaftDrive;
        connect shaft.outputEnd to powerOutput;
        connect starter.shaftConnection to shaft.turbineEnd;

        // Control connections
        connect controlSystem.fuelCommand to fuelSystem.controlInput;
        connect controlSystem.starterCommand to starter.controlInput;

        // Item flows
        flow from airIntake to compressor.airIn : Air;
        flow from compressor.airOut to combustionChamber.airIn : CompressedAir;
        flow from fuelSystem.fuelDelivery to combustionChamber.fuelIn : Fuel;
        flow from combustionChamber.gasOut to turbine.gasIn : CombustionGas;
        flow from turbine.gasOut to exhaust : ExhaustGas;

        // Engine-level state machine
        state machine engineOperation {
            state Off;
            state Starting;
            state SteadyState;
            state Shutdown;

            transition offToStarting first Off to Starting
                when powerDemand > 0.0;
            transition startingToSteady Starting to SteadyState
                when powerOutput.power >= powerDemand * 0.95;
            transition steadyToShutdown SteadyState to Shutdown
                when powerDemand == 0.0;
            transition shutdownToOff Shutdown to Off
                when shaft.rotationalSpeed == 0.0;
        }

        perform operation : engineOperation;
    }

    // ===== Requirements =====
    requirement def PowerOutputRequirement {
        subject engine : Engine;
        attribute minPower : Power = 100000.0;
        attribute actualPower : Power;
        require actualPower >= minPower;
    }

    requirement def ExhaustTemperatureRequirement {
        subject engine : Engine;
        attribute maxExhaustTemp : Temperature = 800.0;
        attribute actualExhaustTemp : Temperature;
        require actualExhaustTemp <= maxExhaustTemp;
    }

    requirement def StartupTimeRequirement {
        subject engine : Engine;
        attribute maxStartupTime : Duration = 60.0;
        attribute actualStartupTime : Duration;
        require actualStartupTime <= maxStartupTime;
    }

    requirement def StableOperationRequirement {
        subject engine : Engine;
        attribute maxSpeedDeviation : Real = 0.05;
        attribute actualSpeedDeviation : Real;
        require actualSpeedDeviation <= maxSpeedDeviation;
    }

    requirement def ThermalEfficiencyRequirement {
        subject engine : Engine;
        attribute minThermalEfficiency : Efficiency = 0.35;
        attribute actualThermalEfficiency : Efficiency;
        require actualThermalEfficiency >= minThermalEfficiency;
    }

    requirement def TurbineInletTemperatureLimit {
        subject engine : Engine;
        attribute maxTurbineInletTemp : Temperature = 1600.0;
        attribute actualTurbineInletTemp : Temperature;
        require actualTurbineInletTemp <= maxTurbineInletTemp;
    }

    requirement def ContinuousOperationRequirement {
        subject engine : Engine;
        attribute minDuration : Duration = 7200.0;
        attribute actualDuration : Duration;
        require actualDuration >= minDuration;
    }

    // ===== Verification =====
    verification def VerifyPowerOutput {
        subject engine : Engine;
        objective { verify PowerOutputRequirement; }
    }

    verification def VerifyExhaustTemperature {
        subject engine : Engine;
        objective { verify ExhaustTemperatureRequirement; }
    }

    verification def VerifyStartupTime {
        subject engine : Engine;
        objective { verify StartupTimeRequirement; }
    }

    verification def VerifyThermalEfficiency {
        subject engine : Engine;
        objective { verify ThermalEfficiencyRequirement; }
    }
}
