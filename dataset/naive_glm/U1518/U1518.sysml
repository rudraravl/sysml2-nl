package TurbinePowerGenerationSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type Pressure :> Real { unit 'MPa'; }
    value type Temperature :> Real { unit 'K'; }
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type Power :> Real { unit 'MW'; }
    value type Voltage :> Real { unit 'kV'; }
    value type Efficiency :> Real { unit '%'; }
    value type Length :> Real { unit 'm'; }
    value type MassFlowRate :> Real { unit 'kg/s'; }
    value type Current :> Real { unit 'A'; }
    value type Frequency :> Real { unit 'Hz'; }

    // ===== Item Definitions =====
    item def Steam {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute flowRate : MassFlowRate;
    }

    item def Water {
        attribute temperature : Temperature;
        attribute flowRate : MassFlowRate;
    }

    item def MechanicalDrive {
        attribute speed : RotationalSpeed;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute power : Power;
        attribute frequency : Frequency;
    }

    // ===== Port Definitions =====
    port def SteamPort { flow steam : Steam; }
    port def WaterPort { flow water : Water; }
    port def DrivePort { flow drive : MechanicalDrive; }
    port def ElectricalPort { flow power : ElectricalPower; }

    // ===== Component Part Definitions =====
    part def Stator {
        attribute nozzleCount : Integer = 24;
        attribute material : String = "Cast Steel";
        port steamIn : SteamPort;
        port steamOut : SteamPort;

        action def DirectSteamFlow {
            in item inletSteam : Steam;
            out item outletSteam : Steam;
        }
    }

    part def Blade {
        attribute material : String = "Titanium Alloy";
        attribute length : Length = 0.35;
        attribute rootWidth : Length = 0.08;
    }

    part def Rotor {
        attribute bladeCount : Integer = 36;
        attribute currentSpeed : RotationalSpeed;
        attribute maxSpeed : RotationalSpeed = 3600;
        part blades : Blade[36];
        port driveOut : DrivePort;

        action def Rotate {
            in item steamImpulse : Steam;
            out item drive : MechanicalDrive;
        }
    }

    part def Shaft {
        attribute length : Length = 8.0;
        attribute diameter : Length = 0.5;
        attribute material : String = "Forged Steel";
        port driveIn : DrivePort;
        port driveOut : DrivePort;
    }

    part def Turbine {
        attribute inletPressure : Pressure;
        attribute ratedSpeed : RotationalSpeed = 3600;
        attribute maxSafeSpeed : RotationalSpeed = 3600;
        attribute isOperational : Boolean = false;

        port steamIn : SteamPort;
        port steamOut : SteamPort;
        port driveOut : DrivePort;

        part stator : Stator;
        part rotor : Rotor;
        part shaft : Shaft;

        flow from steamIn to stator.steamIn;
        flow from stator.steamOut to steamOut;
        flow from rotor.driveOut to shaft.driveIn;
        flow from shaft.driveOut to driveOut;

        state machine TurbineStates {
            entry; then Idle;
            state Idle {
                entry action { rotor.currentSpeed = 0; isOperational = false; }
            }
            transition from Idle to Accelerating when inletPressure >= 10;
            state Accelerating {
                entry action { isOperational = true; }
            }
            transition from Accelerating to Synchronized when rotor.currentSpeed >= 3600;
            state Synchronized;
            transition from Synchronized to OverspeedTrip when rotor.currentSpeed > 3600;
            state OverspeedTrip {
                entry action { isOperational = false; }
            }
            transition from OverspeedTrip to Idle when rotor.currentSpeed == 0;
        }
    }

    part def Generator {
        attribute ratedPower : Power = 500;
        attribute ratedVoltage : Voltage = 22;
        attribute ratedFrequency : Frequency = 60;
        attribute efficiency : Efficiency = 95;
        attribute currentOutput : Power;
        attribute currentVoltage : Voltage;

        port driveIn : DrivePort;
        port electricalOut : ElectricalPort;

        action def GenerateElectricity {
            in item drive : MechanicalDrive;
            out item power : ElectricalPower;
        }

        state machine GeneratorStates {
            entry; then Offline;
            state Offline;
            transition from Offline to Exciting when driveIn.drive.speed >= 3000;
            state Exciting;
            transition from Exciting to Online when currentOutput >= 500;
            state Online;
            transition from Online to Offline when driveIn.drive.speed < 3000;
        }
    }

    part def Condenser {
        attribute coolingCapacity : Power = 200;
        attribute vacuumPressure : Pressure = 0.005;
        attribute coolingWaterTemp : Temperature;

        port steamIn : SteamPort;
        port waterOut : WaterPort;

        action def CondenseSteam {
            in item exhaustSteam : Steam;
            out item condensate : Water;
        }

        state machine CondenserStates {
            entry; then Idle;
            state Idle;
            transition from Idle to Active when steamIn.steam.pressure > 0;
            state Active;
            transition from Active to Idle when steamIn.steam.pressure == 0;
        }
    }

    part def Boiler {
        attribute ratedPressure : Pressure = 25;
        attribute ratedTemperature : Temperature = 813;
        attribute fuelInput : Power;

        port waterIn : WaterPort;
        port steamOut : SteamPort;

        action def ReheatWater {
            in item water : Water;
            out item steam : Steam;
        }

        state machine BoilerStates {
            entry; then Cold;
            state Cold;
            transition from Cold to Firing when fuelInput > 0;
            state Firing;
            transition from Firing to Steaming when steamOut.steam.pressure >= 10;
            state Steaming;
            transition from Steaming to Cold when fuelInput == 0;
        }
    }

    part def Grid {
        attribute demand : Power;
        attribute frequency : Frequency = 60;
        port gridConnection : ElectricalPort;
    }

    // ===== System Assembly =====
    part def PowerPlant {
        attribute systemEfficiency : Efficiency;
        attribute totalOutput : Power;
        attribute inletSteamPressure : Pressure;
        attribute ambientTemperature : Temperature = 298;

        port steamInlet : SteamPort;
        port gridConnection : ElectricalPort;
        port waterReturn : WaterPort;

        part boiler : Boiler;
        part turbine : Turbine;
        part generator : Generator;
        part condenser : Condenser;
        part grid : Grid;

        flow from waterReturn to boiler.waterIn;
        flow from boiler.steamOut to steamInlet;
        flow from steamInlet to turbine.steamIn;
        flow from turbine.steamOut to condenser.steamIn;
        flow from condenser.waterOut to waterReturn;
        flow from turbine.driveOut to generator.driveIn;
        flow from generator.electricalOut to gridConnection;
        flow from gridConnection to grid.gridConnection;

        state machine PlantStates {
            entry; then Standby;
            state Standby {
                entry action { totalOutput = 0; }
            }
            transition from Standby to Starting when inletSteamPressure >= 10;
            state Starting;
            transition from Starting to FullLoad when generator.currentOutput >= 500;
            state FullLoad;
            transition from FullLoad to Cooldown when inletSteamPressure < 10;
            state Cooldown;
            transition from Cooldown to Standby when turbine.rotor.currentSpeed == 0;
        }

        satisfy InletPressureRequirement by self;
        satisfy SpeedSafetyRequirement by turbine;
        satisfy PowerOutputRequirement by self;
        satisfy EfficiencyRequirement by self;
    }

    // ===== Requirements =====
    requirement def InletPressureRequirement {
        attribute minPressure : Pressure = 10;
        attribute maxPressure : Pressure = 25;
        subject plant : PowerPlant;
        require constraint { plant.inletSteamPressure >= 10 and plant.inletSteamPressure <= 25 }
    }

    requirement def SpeedSafetyRequirement {
        attribute maxSpeed : RotationalSpeed = 3600;
        subject turbine : Turbine;
        require constraint { turbine.rotor.currentSpeed <= 3600 }
    }

    requirement def PowerOutputRequirement {
        attribute minPower : Power = 500;
        subject plant : PowerPlant;
        require constraint { plant.totalOutput >= 500 }
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : Efficiency = 85;
        subject plant : PowerPlant;
        require constraint { plant.systemEfficiency >= 85 }
    }

    requirement def GeneratorRatingRequirement {
        attribute ratedPower : Power = 500;
        attribute ratedVoltage : Voltage = 22;
        subject generator : Generator;
        require constraint { generator.ratedPower == 500 and generator.ratedVoltage == 22 }
    }

    requirement def RotorBladeCountRequirement {
        attribute bladeCount : Integer = 36;
        subject rotor : Rotor;
        require constraint { rotor.bladeCount == 36 }
    }

    requirement PowerPlantSpecification {
        subject plant : PowerPlant;

        requirement inletPressureReq : InletPressureRequirement {
            subject plant = PowerPlantSpecification::plant;
        }
        requirement speedSafetyReq : SpeedSafetyRequirement {
            subject turbine = plant.turbine;
        }
        requirement powerOutputReq : PowerOutputRequirement {
            subject plant = PowerPlantSpecification::plant;
        }
        requirement efficiencyReq : EfficiencyRequirement {
            subject plant = PowerPlantSpecification::plant;
        }
        requirement generatorRatingReq : GeneratorRatingRequirement {
            subject generator = plant.generator;
        }
        requirement bladeCountReq : RotorBladeCountRequirement {
            subject rotor = plant.turbine.rotor;
        }
    }
}
