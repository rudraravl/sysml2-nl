package StationarySteamEngineSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    item def CommandSignal;
    item def StartSignal :> CommandSignal;
    item def StopSignal :> CommandSignal;
    item def BoilerReadySignal :> CommandSignal;

    item def ControlSignal {
        attribute valvePosition : Real;
    }

    item def WorkingFluid {
        attribute pressure :> ISQ::pressure;
        attribute temperature :> ISQ::temperature;
    }
    item def Water :> WorkingFluid;
    item def HighPressureSteam :> WorkingFluid;
    item def LowPressureSteam :> WorkingFluid;
    item def CondensedWater :> WorkingFluid;

    item def MechanicalPower {
        attribute torque :> ISQ::torque;
        attribute speed :> ISQ::angularVelocity;
    }

    item def LinearPower {
        attribute force :> ISQ::force;
    }

    port def CommandInPort { in item command : CommandSignal; }
    port def CommandOutPort { out item command : CommandSignal; }
    port def FluidInPort { in item fluid : WorkingFluid; }
    port def FluidOutPort { out item fluid : WorkingFluid; }
    port def ShaftInPort { in item power : MechanicalPower; }
    port def ShaftOutPort { out item power : MechanicalPower; }
    port def LinearInPort { in item power : LinearPower; }
    port def LinearOutPort { out item power : LinearPower; }
    port def ControlInPort { in item command : ControlSignal; }
    port def ControlOutPort { out item command : ControlSignal; }

    action def GenerateSteam { in feedWater : Water; out steam : HighPressureSteam; }
    action def RegulateSteam { in steamIn : HighPressureSteam; in command : ControlSignal; out steamOut : HighPressureSteam; }
    action def ExpandSteam { in steam : HighPressureSteam; out exhaust : LowPressureSteam; out linearPower : LinearPower; }
    action def ConvertLinearToRotary { in linearPower : LinearPower; out shaftPower : MechanicalPower; }
    action def CondenseSteam { in exhaust : LowPressureSteam; out water : CondensedWater; }
    action def PumpWater { in water : CondensedWater; out waterOut : Water; }
    action def MeasureSpeed { in shaftPower : MechanicalPower; out command : ControlSignal; }

    state def EngineStates {
        entry; then stopped;
        state stopped;
        transition stopped_to_starting
            first stopped
            accept StartSignal
            then starting;
        state starting;
        transition starting_to_warming
            first starting
            accept BoilerReadySignal
            then warming;
        state warming;
        transition warming_to_running
            first warming
            accept BoilerReadySignal
            then running;
        state running;
        transition running_to_stopping
            first running
            accept StopSignal
            then stopping;
        state stopping;
        transition stopping_to_stopped
            first stopping
            accept StopSignal
            then stopped;
    }

    part def Boiler {
        attribute maxPressure :> ISQ::pressure;
        port feedWaterIn : FluidInPort;
        port steamOut : FluidOutPort;
        perform action generateSteam : GenerateSteam;
    }

    part def ThrottleValve {
        port steamIn : FluidInPort;
        port steamOut : FluidOutPort;
        port controlIn : ControlInPort;
        perform action regulateSteam : RegulateSteam;
    }

    part def Governor {
        attribute setPointSpeed :> ISQ::angularVelocity;
        attribute speedError :> ISQ::angularVelocity;
        port shaftIn : ShaftInPort;
        port controlOut : ControlOutPort;
        perform action measureSpeed : MeasureSpeed;
    }

    part def Cylinder {
        port steamIn : FluidInPort;
        port exhaustOut : FluidOutPort;
        port linearOut : LinearOutPort;
        perform action expandSteam : ExpandSteam;
    }

    part def Piston {
        port linearIn : LinearInPort;
        port linearOut : LinearOutPort;
    }

    part def ConnectingRod {
        port linearIn : LinearInPort;
        port shaftOut : ShaftOutPort;
        perform action convertLinearToRotary : ConvertLinearToRotary;
    }

    part def Crankshaft {
        port shaftIn : ShaftInPort;
        port mainShaftOut : ShaftOutPort;
        port governorDriveOut : ShaftOutPort;
        port pumpDriveOut : ShaftOutPort;
    }

    part def Flywheel {
        port shaftIn : ShaftInPort;
        port loadOut : ShaftOutPort;
    }

    part def Condenser {
        port steamIn : FluidInPort;
        port waterOut : FluidOutPort;
        perform action condenseSteam : CondenseSteam;
    }

    part def FeedPump {
        port waterIn : FluidInPort;
        port waterOut : FluidOutPort;
        port driveShaftIn : ShaftInPort;
        perform action pumpWater : PumpWater;
    }

    part def StationarySteamEngine {
        attribute powerOutput :> ISQ::power;
        attribute thermalEfficiency : Real;
        port commandIn : CommandInPort;
        exhibit state engineStates : EngineStates;

        part boiler : Boiler;
        part throttleValve : ThrottleValve;
        part governor : Governor;
        part cylinder : Cylinder;
        part piston : Piston;
        part connectingRod : ConnectingRod;
        part crankshaft : Crankshaft;
        part flywheel : Flywheel;
        part condenser : Condenser;
        part feedPump : FeedPump;

        connect feedPump.waterOut to boiler.feedWaterIn;
        connect boiler.steamOut to throttleValve.steamIn;
        connect throttleValve.steamOut to cylinder.steamIn;
        connect cylinder.exhaustOut to condenser.steamIn;
        connect condenser.waterOut to feedPump.waterIn;

        connect cylinder.linearOut to piston.linearIn;
        connect piston.linearOut to connectingRod.linearIn;
        connect connectingRod.shaftOut to crankshaft.shaftIn;
        connect crankshaft.mainShaftOut to flywheel.shaftIn;
        connect crankshaft.governorDriveOut to governor.shaftIn;
        connect crankshaft.pumpDriveOut to feedPump.driveShaftIn;
        connect governor.controlOut to throttleValve.controlIn;
    }

    requirement powerOutputReq {
        subject engine : StationarySteamEngine;
        require constraint { engine.powerOutput >= 75.0 [kW] }
    }

    requirement thermalEfficiencyReq {
        subject engine : StationarySteamEngine;
        require constraint { engine.thermalEfficiency >= 0.15 }
    }

    requirement boilerPressureSafetyReq {
        subject boiler : Boiler;
        require constraint { boiler.maxPressure <= 1500.0 [kPa] }
    }

    requirement speedRegulationReq {
        subject governor : Governor;
        require constraint { governor.speedError <= 0.05 [rad/s] }
    }

    part steamEngine : StationarySteamEngine;

    satisfy powerOutputReq by steamEngine;
    satisfy thermalEfficiencyReq by steamEngine;
    satisfy boilerPressureSafetyReq by steamEngine.boiler;
    satisfy speedRegulationReq by steamEngine.governor;
}
