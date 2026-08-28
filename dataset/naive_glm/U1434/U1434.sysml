package ICE_System {
    import ISQ::*;
    import ScalarValues::*;

    value def TorqueValue :> Torque;
    value def SpeedValue :> RotationalFrequency;
    value def TempValue :> ThermodynamicTemperature;
    value def VolValue :> Volume;
    value def PressValue :> Pressure;
    value def FlowRateValue :> MassFlowRate;

    item def Air;
    item def Fuel;
    item def CombustibleMixture {
        ref part air : Air;
        ref part fuel : Fuel;
    }
    item def ExhaustGas;
    item def Coolant;

    signal def SparkSignal;
    signal def StartCommand;
    signal def EngineStart;
    signal def StopCommand;
    signal def EngineStop;
    signal def ThrottleIncrease;
    signal def ThrottleHold;
    signal def ThrottleDecrease;
    signal def ThrottleRelease;

    port def AirInPort {
        in item : Air;
    }
    port def FuelInPort {
        in item : Fuel;
    }
    port def MixtureInPort {
        in item : CombustibleMixture;
    }
    port def MixtureOutPort {
        out item : CombustibleMixture;
    }
    port def SparkInPort {
        in : SparkSignal;
    }
    port def SparkOutPort {
        out : SparkSignal;
    }
    port def ExhaustInPort {
        in item : ExhaustGas;
    }
    port def ExhaustOutPort {
        out item : ExhaustGas;
    }
    port def CoolantInPort {
        in item : Coolant;
    }
    port def CoolantOutPort {
        out item : Coolant;
    }
    port def MechPowerInPort {
        in torque : TorqueValue;
        in speed : SpeedValue;
    }
    port def MechPowerOutPort {
        out torque : TorqueValue;
        out speed : SpeedValue;
    }

    part def AirIntakeSystem {
        port airIn : AirInPort;
        port mixtureOut : MixtureOutPort;
        attribute flowRate : FlowRateValue;
    }

    part def FuelInjectionSystem {
        port fuelIn : FuelInPort;
        port mixtureOut : MixtureOutPort;
        attribute fuelPressure : PressValue;
    }

    part def PistonAssembly {
        port mechOut : MechPowerOutPort;
        attribute displacement : VolValue;
    }

    part def CombustionChamber {
        port mixtureIn : MixtureInPort;
        port sparkIn : SparkInPort;
        port exhaustOut : ExhaustOutPort;
        port mechOut : MechPowerOutPort;
        
        part piston : PistonAssembly;
        
        action def fourStrokeCycle {
            action intake;
            action compression;
            action power;
            action exhaust;
            
            succession first intake then compression;
            succession compression then power;
            succession power then exhaust;
        }
    }

    part def IgnitionSystem {
        port sparkOut : SparkOutPort;
    }

    part def CrankshaftAssembly {
        port mechIn : MechPowerInPort;
        port mechOut : MechPowerOutPort;
        attribute torqueOutput : TorqueValue;
        attribute speedOutput : SpeedValue;
    }

    part def ExhaustSystem {
        port exhaustIn : ExhaustInPort;
        port exhaustOut : ExhaustOutPort;
    }

    part def CoolingSystem {
        port coolantIn : CoolantInPort;
        port coolantOut : CoolantOutPort;
        attribute operatingTemp : TempValue;
    }

    part def Engine {
        attribute cylinderCount : Integer = 4;
        attribute totalDisplacement : VolValue = 0.002 [m^3];
        
        port airIntake : AirInPort;
        port fuelIntake : FuelInPort;
        port exhaustOutput : ExhaustOutPort;
        port coolantInput : CoolantInPort;
        port coolantOutput : CoolantOutPort;
        port powerOutput : MechPowerOutPort;
        
        part airIntakeSystem : AirIntakeSystem;
        part fuelInjectionSystem : FuelInjectionSystem;
        part chambers[4] : CombustionChamber;
        part ignitionSystem : IgnitionSystem;
        part crankshaft : CrankshaftAssembly;
        part exhaustSystem : ExhaustSystem;
        part coolingSystem : CoolingSystem;
        
        connect airIntake to airIntakeSystem.airIn;
        connect airIntakeSystem.mixtureOut to chambers.mixtureIn;
        connect fuelIntake to fuelInjectionSystem.fuelIn;
        connect fuelInjectionSystem.mixtureOut to chambers.mixtureIn;
        connect ignitionSystem.sparkOut to chambers.sparkIn;
        connect chambers.mechOut to crankshaft.mechIn;
        connect crankshaft.mechOut to powerOutput;
        connect chambers.exhaustOut to exhaustSystem.exhaustIn;
        connect exhaustSystem.exhaustOut to exhaustOutput;
        connect coolantInput to coolingSystem.coolantIn;
        connect coolingSystem.coolantOut to coolantOutput;
        
        state engineBehavior {
            state off;
            state cranking;
            state running {
                state idle;
                state accelerating;
                state cruising;
                state decelerating;
            }
            state stopping;
            
            transition off_to_cranking
                first off 
                accept StartCommand 
                then cranking;
                
            transition cranking_to_running
                from cranking 
                accept EngineStart 
                then running;
                
            transition running_to_stopping
                from running 
                accept StopCommand 
                then stopping;
                
            transition stopping_to_off
                from stopping 
                accept EngineStop 
                then off;
                
            transition idle_to_accel
                from idle 
                accept ThrottleIncrease 
                then accelerating;
                
            transition accel_to_cruise
                from accelerating 
                accept ThrottleHold 
                then cruising;
                
            transition cruise_to_decel
                from cruising 
                accept ThrottleDecrease 
                then decelerating;
                
            transition decel_to_idle
                from decelerating 
                accept ThrottleRelease 
                then idle;
        }
    }

    package req {
        requirement def PowerConversionRequirement {
            doc /* The engine shall convert chemical energy from fuel into mechanical power delivered as torque and speed. */
            subject engine : Engine;
            objective {
                engine.powerOutput.torque > 0 [N*m] and
                engine.powerOutput.speed > 0 [rad/s]
            }
        }
        
        requirement def FourStrokeCycleRequirement {
            doc /* The engine shall operate using a four-stroke cycle: intake, compression, power, exhaust. */
            subject chamber : CombustionChamber;
        }
        
        requirement def EngineConfigurationRequirement {
            doc /* The engine shall be a four-cylinder, 2.0-liter configuration. */
            subject engine : Engine;
            objective {
                engine.cylinderCount == 4 and
                engine.totalDisplacement == 0.002 [m^3]
            }
        }
    }
}
