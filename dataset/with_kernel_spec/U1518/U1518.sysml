package IndustrialTurbineSystem {
    private import ScalarValues::*;

    attribute def Pressure :> Real;
    attribute def Temperature :> Real;
    attribute def Power :> Real;
    attribute def Voltage :> Real;
    attribute def RotationalSpeed :> Real;
    attribute def Efficiency :> Real;

    item def Steam {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
    }

    item def Water {
        attribute temperature : Temperature;
    }

    port def SteamPort {
        item steam : Steam;
    }

    port def WaterPort {
        item water : Water;
    }

    port def MechanicalPort {
        attribute speed : RotationalSpeed;
    }

    port def ElectricalPort {
        attribute power : Power;
        attribute voltage : Voltage;
    }

    part def Stator {
        attribute nozzleCount : Integer;
    }

    part def Rotor {
        attribute bladeCount : Integer = 36;
    }

    part def Turbine {
        part stator : Stator;
        part rotor : Rotor;
        attribute speed : RotationalSpeed;
        attribute inletPressure : Pressure;
        port inlet : SteamPort;
        port outlet : SteamPort;
        port mechanicalOut : MechanicalPort;
    }

    part def Generator {
        attribute ratedPower : Power = 500;
        attribute ratedVoltage : Voltage = 22000;
        attribute outputPower : Power;
        port mechanicalIn : MechanicalPort;
        port electricalOut : ElectricalPort;
    }

    part def Condenser {
        port inlet : SteamPort;
        port outlet : WaterPort;
    }

    part def Boiler {
        port inlet : WaterPort;
        port outlet : SteamPort;
    }

    action def PowerGenerationProcess {
        action feedSteam;
        action spinTurbine;
        action generateElectricity;
        action condenseSteam;
        action returnWater;

        first feedSteam;
        then spinTurbine;
        then generateElectricity;
        then condenseSteam;
        then returnWater;
    }

    state machine def OperationStateMachine {
        state idle;
        state startup;
        state generating;
        state shutdown;

        transition t1 {
            source idle;
            target startup;
        }
        transition t2 {
            source startup;
            target generating;
        }
        transition t3 {
            source generating;
            target shutdown;
        }
        transition t4 {
            source shutdown;
            target idle;
        }
    }

    part def PowerGenerationSystem {
        attribute efficiency : Efficiency;
        part boiler : Boiler;
        part turbine : Turbine;
        part generator : Generator;
        part condenser : Condenser;

        bind boiler.outlet = turbine.inlet;
        bind turbine.mechanicalOut = generator.mechanicalIn;
        bind turbine.outlet = condenser.inlet;
        bind condenser.outlet = boiler.inlet;

        state machine operation : OperationStateMachine;
    }

    action powerGeneration : PowerGenerationProcess;

    part powerGenerationSystem : PowerGenerationSystem {
        perform powerGeneration;
    }

    requirement def InletSteamPressureReqDef {
        doc /* The system requires an inlet steam pressure between 10 and 25 MPa to function optimally. */
        subject system : PowerGenerationSystem;
        require constraint { system.turbine.inletPressure >= 10 && system.turbine.inletPressure <= 25 }
    }

    requirement def TurbineSpeedSafetyReqDef {
        doc /* The turbine's rotational speed shall not exceed 3600 RPM to prevent catastrophic mechanical failure. */
        subject system : PowerGenerationSystem;
        require constraint { system.turbine.speed <= 3600 }
    }

    requirement def PowerOutputReqDef {
        doc /* The system shall achieve a continuous power output of at least 500 megawatts. */
        subject system : PowerGenerationSystem;
        require constraint { system.generator.outputPower >= 500 }
    }

    requirement def SystemEfficiencyReqDef {
        doc /* The overall system efficiency shall be 85% or higher. */
        subject system : PowerGenerationSystem;
        require constraint { system.efficiency >= 85 }
    }

    requirement inletSteamPressureReq : InletSteamPressureReqDef {
        subject :>> system = powerGenerationSystem;
    }

    requirement turbineSpeedSafetyReq : TurbineSpeedSafetyReqDef {
        subject :>> system = powerGenerationSystem;
    }

    requirement powerOutputReq : PowerOutputReqDef {
        subject :>> system = powerGenerationSystem;
    }

    requirement systemEfficiencyReq : SystemEfficiencyReqDef {
        subject :>> system = powerGenerationSystem;
    }
}
