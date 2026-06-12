package JetEngineSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def MassFlowRate :> ISQ::massFlowRate {
        unit = SI::kilogram / SI::second;
    }

    attribute def RotationalSpeed :> ISQ::frequency {
        unit = SI::revolution / SI::minute;
    }

    attribute def Thrust :> ISQ::force {
        unit = SI::newton;
    }

    attribute def FuelFlowRate :> ISQ::massFlowRate {
        unit = SI::kilogram / SI::second;
    }

    attribute def Ratio :> ScalarValues::Real;

    attribute def Percent :> ScalarValues::Real {
        unit = SI::percent;
    }

    item def Air {
        attribute staticPressure : Pressure;
        attribute staticTemperature : Temperature;
        attribute massFlow : MassFlowRate;
        attribute oxygenFraction : Ratio;
    }

    item def CompressedAir :> Air {
        attribute pressureRatio : Ratio;
    }

    item def Fuel {
        attribute flowRate : FuelFlowRate;
        attribute lowerHeatingValue : ISQ::specificEnergy = 43.0e6 [SI::joule / SI::kilogram];
        attribute temperature : Temperature;
    }

    item def CombustionGas {
        attribute totalPressure : Pressure;
        attribute totalTemperature : Temperature;
        attribute massFlow : MassFlowRate;
        attribute fuelAirRatio : Ratio;
    }

    item def ExhaustGas :> CombustionGas {
        attribute exhaustVelocity : ISQ::speed;
    }

    item def ShaftPower {
        attribute power : ISQ::power;
        attribute speed : RotationalSpeed;
        attribute torque : ISQ::torque;
    }

    item def ControlCommand {
        attribute throttleDemand : Percent;
        attribute startCommand : Boolean;
        attribute shutdownCommand : Boolean;
    }

    item def HealthData {
        attribute vibrationLevel : ISQ::acceleration;
        attribute oilPressure : Pressure;
        attribute exhaustGasTemperature : Temperature;
        attribute overspeedDetected : Boolean;
        attribute flameoutDetected : Boolean;
    }

    port def AirInletPort {
        in item incomingAir : Air;
    }

    port def AirOutletPort {
        out item outgoingAir : Air;
    }

    port def CompressedAirPort {
        out item compressedAir : CompressedAir;
    }

    port def FuelInletPort {
        in item fuel : Fuel;
    }

    port def GasInletPort {
        in item hotGas : CombustionGas;
    }

    port def GasOutletPort {
        out item hotGas : CombustionGas;
    }

    port def ExhaustPort {
        out item exhaust : ExhaustGas;
    }

    port def ShaftPowerPort {
        inout item shaftPower : ShaftPower;
    }

    port def CommandPort {
        in item command : ControlCommand;
    }

    port def TelemetryPort {
        out item health : HealthData;
    }

    part def Fan {
        port airIn : AirInletPort;
        port bypassAirOut : AirOutletPort;
        port coreAirOut : AirOutletPort;
        port shaftDrive : ShaftPowerPort;

        attribute fanPressureRatio : Ratio = 1.6;
        attribute bypassRatio : Ratio = 8.5;
        attribute correctedFanSpeed : RotationalSpeed;

        action accelerateAir {
            in item ambientAir : Air;
            out item bypassAir : Air;
            out item coreAir : Air;
        }
    }

    part def Compressor {
        port airIn : AirInletPort;
        port airOut : CompressedAirPort;
        port shaftDrive : ShaftPowerPort;

        attribute overallPressureRatio : Ratio = 36.0;
        attribute highPressureRotorSpeed : RotationalSpeed;
        attribute compressorExitTemperature : Temperature;

        action compressCoreAir {
            in item coreAir : Air;
            out item pressurizedAir : CompressedAir;
        }
    }

    part def FuelMeteringUnit {
        port fuelSupply : FuelInletPort;
        port commandIn : CommandPort;
        out item meteredFuel : Fuel;

        attribute minimumIdleFuelFlow : FuelFlowRate = 0.18 [SI::kilogram / SI::second];
        attribute maximumTakeoffFuelFlow : FuelFlowRate = 2.45 [SI::kilogram / SI::second];

        action meterFuel {
            in item throttle : ControlCommand;
            in item supplyFuel : Fuel;
            out item scheduledFuel : Fuel;
        }
    }

    part def Combustor {
        in item compressorDischargeAir : CompressedAir;
        in item injectedFuel : Fuel;
        port gasOut : GasOutletPort;

        attribute combustionEfficiency : Percent = 99.2 [%];
        attribute targetTurbineInletTemperature : Temperature = 1720 [SI::kelvin];
        attribute pressureLossRatio : Ratio = 0.045;

        action burnFuelAirMixture {
            in item air : CompressedAir;
            in item fuel : Fuel;
            out item hotGas : CombustionGas;
        }
    }

    part def Turbine {
        port gasIn : GasInletPort;
        port gasOut : GasOutletPort;
        port compressorShaft : ShaftPowerPort;
        port fanShaft : ShaftPowerPort;

        attribute highPressureTurbineEfficiency : Percent = 91.0 [%];
        attribute lowPressureTurbineEfficiency : Percent = 93.0 [%];
        attribute turbineExitTemperature : Temperature;

        action extractPower {
            in item combustionGas : CombustionGas;
            out item expandedGas : CombustionGas;
            out item shaftWork : ShaftPower;
        }
    }

    part def ExhaustNozzle {
        port gasIn : GasInletPort;
        port exhaustOut : ExhaustPort;

        attribute nozzlePressureRatio : Ratio;
        attribute grossThrust : Thrust;
        attribute exitArea : ISQ::area = 1.35 [SI::squareMetre];

        action expandGasToThrust {
            in item turbineExitGas : CombustionGas;
            out item exhaustJet : ExhaustGas;
        }
    }

    part def LubricationSystem {
        port telemetryOut : TelemetryPort;

        attribute oilPressure : Pressure;
        attribute oilTemperature : Temperature;
        attribute oilQuantity : ISQ::volume = 38 [SI::litre];

        action circulateOil {
            out item health : HealthData;
        }
    }

    part def EngineControlUnit {
        port commandIn : CommandPort;
        port telemetryOut : TelemetryPort;
        out item fuelCommand : ControlCommand;

        attribute commandedThrottle : Percent;
        attribute overspeedLimit : RotationalSpeed = 11200 [SI::revolution / SI::minute];
        attribute maximumEGT : Temperature = 1220 [SI::kelvin];

        action computeFuelSchedule {
            in item pilotCommand : ControlCommand;
            in item engineHealth : HealthData;
            out item fuelScheduleCommand : ControlCommand;
        }

        state def EngineControlStateMachine {
            state Off;
            state Starting;
            state Idle;
            state Accelerating;
            state SteadyThrust;
            state Decelerating;
            state Shutdown;
            state Fault;

            entry; then Off;

            transition Off_to_Starting
                first Off
                accept ControlCommand
                if command.startCommand
                then Starting;

            transition Starting_to_Idle
                first Starting
                if commandedThrottle <= 25.0
                then Idle;

            transition Idle_to_Accelerating
                first Idle
                accept ControlCommand
                if command.throttleDemand > commandedThrottle
                then Accelerating;

            transition Accelerating_to_SteadyThrust
                first Accelerating
                if commandedThrottle == command.throttleDemand
                then SteadyThrust;

            transition SteadyThrust_to_Decelerating
                first SteadyThrust
                accept ControlCommand
                if command.throttleDemand < commandedThrottle
                then Decelerating;

            transition Decelerating_to_Idle
                first Decelerating
                if commandedThrottle <= 25.0
                then Idle;

            transition Any_to_Fault
                first Off, Starting, Idle, Accelerating, SteadyThrust, Decelerating
                accept HealthData
                if health.overspeedDetected or health.flameoutDetected
                then Fault;

            transition Fault_to_Shutdown
                first Fault
                then Shutdown;

            transition Shutdown_to_Off
                first Shutdown
                then Off;
        }
    }

    part def JetEngine {
        port inlet : AirInletPort;
        port fuelInlet : FuelInletPort;
        port commandInput : CommandPort;
        port exhaust : ExhaustPort;
        port telemetry : TelemetryPort;

        part fan : Fan;
        part compressor : Compressor;
        part fuelMeteringUnit : FuelMeteringUnit;
        part combustor : Combustor;
        part turbine : Turbine;
        part nozzle : ExhaustNozzle;
        part lubricationSystem : LubricationSystem;
        part engineControlUnit : EngineControlUnit;

        attribute netThrust : Thrust;
        attribute specificFuelConsumption : ISQ::massPerEnergy;
        attribute enginePressureRatio : Ratio;
        attribute dryMass : ISQ::mass = 2850 [SI::kilogram];
        attribute maximumTakeoffThrust : Thrust = 121000 [SI::newton];

        connect inlet.incomingAir to fan.airIn.incomingAir;
        connect fan.coreAirOut.outgoingAir to compressor.airIn.incomingAir;
        connect compressor.airOut.compressedAir to combustor.compressorDischargeAir;
        connect fuelInlet.fuel to fuelMeteringUnit.fuelSupply.fuel;
        connect commandInput.command to engineControlUnit.commandIn.command;
        connect engineControlUnit.fuelCommand to fuelMeteringUnit.commandIn.command;
        connect fuelMeteringUnit.meteredFuel to combustor.injectedFuel;
        connect combustor.gasOut.hotGas to turbine.gasIn.hotGas;
        connect turbine.gasOut.hotGas to nozzle.gasIn.hotGas;
        connect nozzle.exhaustOut.exhaust to exhaust.exhaust;
        connect turbine.compressorShaft.shaftPower to compressor.shaftDrive.shaftPower;
        connect turbine.fanShaft.shaftPower to fan.shaftDrive.shaftPower;
        connect lubricationSystem.telemetryOut.health to telemetry.health;
        connect engineControlUnit.telemetryOut.health to telemetry.health;

        action generatePropulsiveThrust {
            in item ambientAir : Air;
            in item fuel : Fuel;
            in item command : ControlCommand;
            out item exhaustJet : ExhaustGas;
            out attribute producedThrust : Thrust;

            first fan.accelerateAir;
            then compressor.compressCoreAir;
            then fuelMeteringUnit.meterFuel;
            then combustor.burnFuelAirMixture;
            then turbine.extractPower;
            then nozzle.expandGasToThrust;
        }
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The jet engine shall convert chemical energy from fuel and kinetic energy from ingested air into a high velocity exhaust stream to produce controlled propulsive thrust for an aircraft. */

        subject engine : JetEngine;

        require constraint {
            engine.netThrust >= 0 [SI::newton]
        }
    }

    requirement def TakeoffThrustRequirement {
        doc /* At takeoff power, the engine shall provide at least 121 kN of net thrust under rated sea-level static conditions. */

        subject engine : JetEngine;

        require constraint {
            engine.netThrust >= 121000 [SI::newton]
        }
    }

    requirement def FuelControlRequirement {
        doc /* The engine control unit shall regulate fuel flow as a function of throttle demand while preventing turbine over-temperature and rotor overspeed. */

        subject ecu : EngineControlUnit;

        require constraint {
            ecu.commandedThrottle >= 0 [%] and ecu.commandedThrottle <= 100 [%]
        }
    }

    requirement def CombustionStabilityRequirement {
        doc /* The combustor shall sustain stable combustion over idle through takeoff operation with combustion efficiency greater than 98 percent. */

        subject combustor : Combustor;

        require constraint {
            combustor.combustionEfficiency > 98 [%]
        }
    }

    requirement def CompressorPressureRequirement {
        doc /* The compressor shall raise core airflow pressure by an overall pressure ratio of at least 30 during rated operation. */

        subject compressor : Compressor;

        require constraint {
            compressor.overallPressureRatio >= 30.0
        }
    }

    requirement def ExhaustSafetyRequirement {
        doc /* The exhaust nozzle shall direct hot gas aft and maintain turbine exhaust gas temperature within material and control limits. */

        subject nozzle : ExhaustNozzle;

        require constraint {
            nozzle.grossThrust > 0 [SI::newton]
        }
    }

    requirement def EngineHealthMonitoringRequirement {
        doc /* The engine shall provide health telemetry including exhaust gas temperature, oil pressure, vibration level, overspeed status, and flameout status. */

        subject engine : JetEngine;

        require constraint {
            engine.engineControlUnit.maximumEGT <= 1220 [SI::kelvin]
        }
    }

    satisfy PrimaryFunctionRequirement by JetEngine;
    satisfy TakeoffThrustRequirement by JetEngine;
    satisfy FuelControlRequirement by EngineControlUnit;
    satisfy CombustionStabilityRequirement by Combustor;
    satisfy CompressorPressureRequirement by Compressor;
    satisfy ExhaustSafetyRequirement by ExhaustNozzle;
    satisfy EngineHealthMonitoringRequirement by JetEngine;

}