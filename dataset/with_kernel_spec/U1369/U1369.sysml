package 'Roots Supercharger System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;
    private import Quantities::*;

    item def Air {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute density : MassDensityValue;
        attribute massFlowRate : MassFlowRateValue;
    }

    item def MechanicalPower {
        attribute torque : TorqueValue;
        attribute speed : AngularVelocityValue;
    }

    port def MechanicalOutputPort {
        out item power : MechanicalPower;
    }

    port def MechanicalInputPort {
        in item power : MechanicalPower;
    }

    port def AirInletPort {
        in item air : Air;
    }

    port def AirOutletPort {
        out item air : Air;
    }

    part def Engine {
        attribute crankshaftSpeed : AngularVelocityValue;
        port mechanicalOutput : MechanicalOutputPort;
        port intakeManifold : AirInletPort;
    }

    part def Rotor {
        attribute lobeCount : Integer;
        attribute rotationalSpeed : AngularVelocityValue;
    }

    part def MaleRotor :> Rotor {
        attribute redefines lobeCount = 3;
    }

    part def FemaleRotor :> Rotor {
        attribute redefines lobeCount = 2;
    }

    part def Casing {
        attribute material : String = "Aluminum";
    }

    part def Pulley {
        attribute diameter : LengthValue;
        attribute rotationalSpeed : AngularVelocityValue;
    }

    part def Belt {
        attribute ratio : Real;
    }

    part def Supercharger {
        part maleRotor : MaleRotor;
        part femaleRotor : FemaleRotor;
        part casing : Casing;
        part pulley : Pulley;
        part belt : Belt;
        
        port mechanicalInput : MechanicalInputPort;
        port airInlet : AirInletPort;
        port airOutlet : AirOutletPort;
        
        attribute boostPressure : PressureValue;
        attribute pressureRatio : Real;
        attribute rotorSpeed : AngularVelocityValue;
        attribute maxSafePressure : PressureValue = 1.5e5 [Pa];
        
        exhibit state SuperchargerStates {
            entry; then idle;
            state idle;
            transition idle_to_spooling
                first idle
                accept when rotorSpeed > 0 [rad/s]
                then spooling;
            state spooling;
            transition spooling_to_boosting
                first spooling
                accept when rotorSpeed > 100 [rad/s]
                then boosting;
            state boosting;
            transition boosting_to_bypass
                first boosting
                accept when boostPressure > maxSafePressure
                then bypass;
            state bypass;
            transition bypass_to_boosting
                first bypass
                accept when boostPressure <= maxSafePressure
                then boosting;
        }
    }

    part def Intercooler {
        attribute effectiveness : Real;
        port hotAirInlet : AirInletPort;
        port cooledAirOutlet : AirOutletPort;
        action coolAir {
            in hotAir : Air;
            out cooledAir : Air;
        }
    }

    part def BypassValve {
        attribute threshold : PressureValue = 1.5e5 [Pa];
        attribute isOpen : Boolean;
        port inlet : AirInletPort;
        port outlet : AirOutletPort;
        exhibit state valveState {
            entry; then closed;
            state closed;
            accept when inlet.air.pressure > threshold then open;
            state open;
            accept when inlet.air.pressure <= threshold then closed;
        }
    }

    part def Atmosphere {
        attribute ambientPressure : PressureValue = 101325 [Pa];
        attribute ambientTemperature : TemperatureValue = 293.15 [K];
        port airOutlet : AirOutletPort;
        port ventInlet : AirInletPort;
    }

    calc def BoostPressureCalc {
        in pressureRatio : Real;
        in ambientPressure : PressureValue;
        return boostPressure : PressureValue = pressureRatio * ambientPressure;
    }

    requirement def IncreasePower {
        doc /* The supercharger shall increase engine power output by at least 30% over naturally aspirated. */
    }

    requirement def BoostLimitSafety {
        doc /* The bypass valve shall open when boost pressure exceeds 1.5 bar absolute to prevent engine damage. */
    }

    requirement def CoolingRequirement {
        doc /* The intercooler shall reduce intake air temperature by at least 30 degrees Celsius under maximum boost. */
    }

    part 'Supercharger System Context' {
        part engine : Engine;
        part supercharger : Supercharger;
        part intercooler : Intercooler;
        part bypassValve : BypassValve;
        part atm : Atmosphere;

        connect engine.mechanicalOutput to supercharger.mechanicalInput;
        connect atm.airOutlet to supercharger.airInlet;
        connect supercharger.airOutlet to intercooler.hotAirInlet;
        connect supercharger.airOutlet to bypassValve.inlet;
        connect intercooler.cooledAirOutlet to engine.intakeManifold;
        connect bypassValve.outlet to atm.ventInlet;

        calc boostCalc : BoostPressureCalc {
            in pressureRatio = supercharger.pressureRatio;
            in ambientPressure = atm.ambientPressure;
        }

        bind supercharger.boostPressure = boostCalc.boostPressure;

        requirement increasePowerReq : IncreasePower;
        requirement boostLimitSafetyReq : BoostLimitSafety;
        requirement coolingRequirementReq : CoolingRequirement;

        satisfy increasePowerReq by supercharger;
        satisfy boostLimitSafetyReq by bypassValve;
        satisfy coolingRequirementReq by intercooler;
    }
}
