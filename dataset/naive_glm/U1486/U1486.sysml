package WankelRotaryEngine {
    import ScalarValues::*;
    import ISQ::*;
    import Quantities::*;

    // ---- Value types with units ----
    value def Power :> Real { unit = "kW"; }
    value def RotationalSpeed :> Real { unit = "rpm"; }
    value def Torque :> Real { unit = "N*m"; }
    value def Temperature :> Real { unit = "K"; }
    value def Pressure :> Real { unit = "Pa"; }
    value def Volume :> Real { unit = "m^3"; }
    value def MassFlowRate :> Real { unit = "kg/s"; }
    value def VolumetricFlowRate :> Real { unit = "m^3/s"; }
    value def Efficiency :> Real { unit = "%"; }
    value def Duration :> Real { unit = "h"; }
    value def Angle :> Real { unit = "rad"; }
    value def Length :> Real { unit = "m"; }
    value def Mass :> Real { unit = "kg"; }
    value def Energy :> Real { unit = "J"; }

    // ---- Item types ----
    item def AirFuelMixture {
        attribute ratio : Real;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }
    item def CombustionGas {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }
    item def ExhaustGas {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
    }
    item def Coolant {
        attribute temperature : Temperature;
        attribute flowRate : VolumetricFlowRate;
    }
    item def Spark {
        attribute energy : Energy;
        attribute timing : Angle;
    }
    item def MechanicalPower {
        attribute torque : Torque;
        attribute speed : RotationalSpeed;
    }
    item def StartCommand;
    item def StopCommand;

    // ---- Port definitions ----
    port def AirFuelIntakePort { in item mixture : AirFuelMixture; }
    port def ExhaustPort { out item gas : ExhaustGas; }
    port def CoolantInPort { in item coolant : Coolant; }
    port def CoolantOutPort { out item coolant : Coolant; }
    port def PowerOutputPort { out item power : MechanicalPower; }
    port def CommandPort {
        in item startCmd : StartCommand;
        in item stopCmd : StopCommand;
    }
    port def SparkPlugPort { out item spark : Spark; }

    // ---- Requirements ----
    requirement def PowerRequirement {
        doc "The engine shall deliver at least 180 kW at 8000 rpm."
        attribute minPower : Power = 180;
        attribute ratedSpeed : RotationalSpeed = 8000;
        subject engine : WankelEngine;
        require engine.deliveredPower >= minPower and engine.outputSpeed == ratedSpeed;
    }
    requirement def EfficiencyRequirement {
        doc "The engine shall maintain a thermal efficiency of at least 28%."
        attribute minEfficiency : Efficiency = 28;
        subject engine : WankelEngine;
        require engine.thermalEfficiency >= minEfficiency;
    }
    requirement def ReliabilityRequirement {
        doc "The engine shall operate reliably for at least 5000 hours before major overhaul."
        attribute minTimeToOverhaul : Duration = 5000;
        subject engine : WankelEngine;
        require engine.timeToOverhaul >= minTimeToOverhaul;
    }

    // ---- Parts ----
    part def Housing {
        attribute chamberType : String = "epitrochoidal";
        attribute maxVolume : Volume = 0.000654;
        attribute minVolume : Volume = 0.000082;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        port intakePort : AirFuelIntakePort;
        port exhaustPort : ExhaustPort;
    }
    part def Rotor {
        attribute shape : String = "triangular";
        attribute count : Integer = 3;
        attribute mass : Mass = 3.5;
        attribute apexSealCount : Integer = 3;
        attribute eccentricity : Length = 0.015;
    }
    part def EccentricShaft {
        attribute length : Length = 0.42;
        attribute mainJournalDiameter : Length = 0.045;
        attribute eccentricJournalOffset : Length = 0.015;
        port powerOutput : PowerOutputPort;
    }
    part def IntakeManifold {
        port intakePort : AirFuelIntakePort;
        attribute throttleDiameter : Length = 0.06;
    }
    part def ExhaustManifold {
        port exhaustPort : ExhaustPort;
        attribute outletDiameter : Length = 0.055;
    }
    part def IgnitionSystem {
        attribute sparkEnergy : Energy = 0.05;
        attribute sparkTiming : Angle = 0.524;
        port sparkPlugPort : SparkPlugPort;
    }
    part def CoolingSystem {
        attribute coolantCapacity : Volume = 0.012;
        attribute pumpFlowRate : VolumetricFlowRate = 0.0008;
        attribute operatingTemp : Temperature = 363.15;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
    }
    part def CombustionChamber {
        attribute currentVolume : Volume;
        attribute currentPressure : Pressure;
        attribute currentTemperature : Temperature;
        attribute strokePhase : StrokePhase;
    }
    enum def StrokePhase { intake; compression; combustion; exhaust; }

    // ---- Engine behavior: state machine ----
    state def EngineStateMachine {
        entry; then off;
        state off;
        transition off_to_starting
            first off
            accept StartCommand
            then starting;
        state starting {
            entry { engine.crank(); }
            do { engine.ignite(); }
            exit { engine.confirmRunning(); }
        }
        transition starting_to_running
            first starting
            accept StartCommand
            then running;
        state running {
            entry { engine.beginPowerCycle(); }
            do { engine.sustainCombustion(); }
        }
        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;
        state stopping {
            entry { engine.reduceFuel(); }
            do { engine.cooldown(); }
            exit { engine.shutdown(); }
        }
        transition stopping_to_off
            first stopping
            accept StopCommand
            then off;
    }

    // ---- Main engine part ----
    part def WankelEngine {
        attribute deliveredPower : Power;
        attribute outputSpeed : RotationalSpeed;
        attribute outputTorque : Torque;
        attribute thermalEfficiency : Efficiency;
        attribute timeToOverhaul : Duration;
        attribute operatingTemperature : Temperature;

        port commandPort : CommandPort;
        port powerOutput : PowerOutputPort;
        port intakePort : AirFuelIntakePort;
        port exhaustPort : ExhaustPort;
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;

        part housing : Housing {
            port coolantIn : CoolantInPort;
            port coolantOut : CoolantOutPort;
            port intakePort : AirFuelIntakePort;
            port exhaustPort : ExhaustPort;
        }
        part rotors : Rotor[3];
        part eccentricShaft : EccentricShaft {
            port powerOutput : PowerOutputPort;
        }
        part intakeManifold : IntakeManifold {
            port intakePort : AirFuelIntakePort;
        }
        part exhaustManifold : ExhaustManifold {
            port exhaustPort : ExhaustPort;
        }
        part ignitionSystem : IgnitionSystem {
            port sparkPlugPort : SparkPlugPort;
        }
        part coolingSystem : CoolingSystem {
            port coolantIn : CoolantInPort;
            port coolantOut : CoolantOutPort;
        }
        part chambers : CombustionChamber[3];

        // Internal connections
        connection intakeFlow connect intakePort to intakeManifold.intakePort;
        connection intakeToHousing connect intakeManifold.intakePort to housing.intakePort;
        connection exhaustFlow connect housing.exhaustPort to exhaustManifold.exhaustPort;
        connection sparkDelivery connect ignitionSystem.sparkPlugPort to housing;
        connection coolantInFlow connect coolantIn to coolingSystem.coolantIn;
        connection coolantCirculation connect coolingSystem.coolantOut to housing.coolantIn;
        connection coolantReturn connect housing.coolantOut to coolantOut;
        connection powerDelivery connect eccentricShaft.powerOutput to powerOutput;

        // Behavior actions
        action crank;
        action ignite;
        action confirmRunning;
        action beginPowerCycle;
        action sustainCombustion;
        action reduceFuel;
        action cooldown;
        action shutdown;

        // Four-stroke cycle behavior
        action def IntakeStroke {
            in chamber : CombustionChamber;
            in mixture : AirFuelMixture;
        }
        action def CompressionStroke {
            in chamber : CombustionChamber;
            out compressedMixture : AirFuelMixture;
        }
        action def CombustionStroke {
            in chamber : CombustionChamber;
            in spark : Spark;
            out gas : CombustionGas;
        }
        action def ExhaustStroke {
            in chamber : CombustionChamber;
            out exhaust : ExhaustGas;
        }

        action fourStrokeCycle {
            action intake : IntakeStroke;
            action compress : CompressionStroke;
            action combust : CombustionStroke;
            action exhaust : ExhaustStroke;
            flow from intake.chamber to compress.chamber;
            flow from compress.compressedMixture to combust;
            flow from combust.gas to exhaust;
        }

        // State machine
        exhibit state engineState : EngineStateMachine;

        // Requirements satisfaction
        satisfy req powerReq : PowerRequirement by engineState.running;
        satisfy req effReq : EfficiencyRequirement by engineState.running;
        satisfy req relReq : ReliabilityRequirement by engineState;
    }

    // ---- System-level package ----
    part engineSystem : WankelEngine {
        attribute deliveredPower : Power = 185;
        attribute outputSpeed : RotationalSpeed = 8000;
        attribute outputTorque : Torque = 220;
        attribute thermalEfficiency : Efficiency = 29;
        attribute timeToOverhaul : Duration = 5200;
        attribute operatingTemperature : Temperature = 363.15;
    }
}
