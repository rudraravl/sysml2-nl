package ICE_System {
    public import ScalarValues::*;

    // ===== Value Types =====
    value type Torque :> Real { unit "N·m"; }
    value type RotationalSpeed :> Real { unit "rpm"; }
    value type Temperature :> Real { unit "degC"; }
    value type Pressure :> Real { unit "kPa"; }
    value type Volume :> Real { unit "L"; }
    value type Ratio :> Real { unit "1"; }
    value type Power :> Real { unit "kW"; }
    value type MassFlowRate :> Real { unit "kg/s"; }
    value type VolumetricFlowRate :> Real { unit "L/min"; }
    value type Length :> Real { unit "mm"; }
    value type Force :> Real { unit "N"; }
    value type Angle :> Real { unit "deg"; }
    value type Efficiency :> Real { unit "1"; }
    value type Mass :> Real { unit "kg"; }

    // ===== Item Definitions =====
    item def Fuel;
    item def Air;
    item def FuelAirMixture;
    item def CombustionGas;
    item def ExhaustGas;
    item def Coolant;
    item def LubricatingOil;

    // ===== Port Definitions =====
    port def FuelInPort {
        in item fuel : Fuel;
        attribute pressure : Pressure;
    }
    port def AirInPort {
        in item air : Air;
        attribute pressure : Pressure;
    }
    port def ExhaustOutPort {
        out item exhaust : ExhaustGas;
        attribute temperature : Temperature;
    }
    port def CoolantFlowPort {
        in item coolantIn : Coolant;
        out item coolantOut : Coolant;
        attribute flowRate : VolumetricFlowRate;
    }
    port def OilFlowPort {
        out item oilOut : LubricatingOil;
        in item oilIn : LubricatingOil;
        attribute pressure : Pressure;
    }
    port def MechanicalPowerPort {
        out attribute torque : Torque;
        out attribute speed : RotationalSpeed;
    }
    port def MechanicalReceivePort {
        in attribute torque : Torque;
        in attribute speed : RotationalSpeed;
    }
    port def IgnitionControlPort {
        out attribute trigger : Boolean;
    }
    port def ValveControlPort {
        out attribute openCommand : Boolean;
        out attribute timing : Angle;
    }

    // ===== Part Definitions =====

    part def SparkPlug {
        doc /* Ignition device that ignites the compressed fuel-air mixture. */
        attribute gap : Length = 0.8;
        attribute voltageThreshold : Real = 12000.0;
        port ignition : IgnitionControlPort;

        action def Ignite {
            in item mixture : FuelAirMixture;
            out item gas : CombustionGas;
        }
    }

    part def Valve {
        attribute lift : Length;
        attribute diameter : Length;
        attribute isOpen : Boolean = false;
        port control : ValveControlPort;

        action def Open;
        action def Close;
    }

    part def IntakeValve :> Valve {
        doc /* Controls flow of fuel-air mixture into the cylinder. */
    }

    part def ExhaustValve :> Valve {
        doc /* Controls flow of exhaust gases out of the cylinder. */
    }

    part def Piston {
        doc /* Translates linear motion to the crankshaft via connecting rod. */
        attribute diameter : Length;
        attribute stroke : Length;
        attribute mass : Mass;
        attribute position : Length;
        attribute velocity : Real;
        port rodConnection : MechanicalReceivePort;

        action def MoveDown;
        action def MoveUp;
    }

    part def Cylinder {
        doc /* Core combustion chamber containing piston, valves, and spark plug. */
        attribute bore : Length;
        attribute stroke : Length;
        attribute displacement : Volume;
        attribute compressionRatio : Ratio;

        part piston : Piston;
        part intakeValve : IntakeValve;
        part exhaustValve : ExhaustValve;
        part sparkPlug : SparkPlug;

        port intake : AirInPort;
        port fuelIntake : FuelInPort;
        port exhaust : ExhaustOutPort;
        port mechanicalOutput : MechanicalPowerPort;

        state machine FourStrokeCycle {
            state Intake {
                doc /* Piston moves down; intake valve opens; fuel-air mixture drawn in. */
            }
            state Compression {
                doc /* Piston moves up; both valves closed; mixture compressed. */
            }
            state Power {
                doc /* Spark plug ignites mixture; expanding gases drive piston down. */
            }
            state Exhaust {
                doc /* Piston moves up; exhaust valve opens; spent gases expelled. */
            }
            transition t1 from Intake to Compression;
            transition t2 from Compression to Power;
            transition t3 from Power to Exhaust;
            transition t4 from Exhaust to Intake;
        }
    }

    part def Crankshaft {
        doc /* Converts linear piston motion into continuous rotational motion. */
        attribute length : Length;
        attribute journalDiameter : Length;
        attribute counterweightMass : Mass;
        attribute rotationalSpeed : RotationalSpeed;
        attribute outputTorque : Torque;

        port input : MechanicalReceivePort;
        port output : MechanicalPowerPort;

        action def ConvertLinearToRotational {
            in linearForce : Force;
            out rotationalTorque : Torque;
        }
    }

    part def Camshaft {
        doc /* Precisely controls timing of intake and exhaust valves. */
        attribute lobeCount : Integer;
        attribute baseCircle : Length;
        attribute lift : Length;
        attribute rotationalSpeed : RotationalSpeed;

        port intakeControl : ValveControlPort;
        port exhaustControl : ValveControlPort;

        action def ControlValveTiming {
            in cyclePosition : Angle;
            out intakeTiming : Angle;
            out exhaustTiming : Angle;
        }
    }

    part def FuelSystem {
        doc /* Delivers pressurized fuel to the cylinders. */
        attribute fuelPressure : Pressure;
        attribute fuelFlowRate : MassFlowRate;

        part fuelPump {
            attribute pressure : Pressure;
            attribute flowRate : MassFlowRate;
        }
        part fuelRail {
            attribute volume : Volume;
            attribute pressure : Pressure;
        }
        part fuelInjectors[*] {
            attribute flowRate : MassFlowRate;
        }

        port fuelOutput : FuelInPort;

        action def DeliverFuel {
            in item fuel : Fuel;
            out item pressurizedFuel : Fuel;
        }
    }

    part def CoolingSystem {
        doc /* Circulates coolant to manage heat generated during combustion. */
        attribute coolantFlowRate : VolumetricFlowRate;
        attribute operatingTemperature : Temperature;

        part waterPump {
            attribute flowRate : VolumetricFlowRate;
        }
        part radiator {
            attribute coolingCapacity : Power;
            attribute inletTemp : Temperature;
            attribute outletTemp : Temperature;
        }
        part thermostat {
            attribute openTemp : Temperature = 88.0;
            attribute isOpen : Boolean = false;
        }

        port coolantCircuit : CoolantFlowPort;

        action def CirculateCoolant {
            in item coolantIn : Coolant;
            out item coolantOut : Coolant;
        }
    }

    part def LubricationSystem {
        doc /* Pumps oil to reduce friction between moving parts. */
        attribute oilPressure : Pressure;
        attribute oilFlowRate : VolumetricFlowRate;
        attribute oilTemperature : Temperature;

        part oilPump {
            attribute pressure : Pressure;
            attribute flowRate : VolumetricFlowRate;
        }
        part oilFilter {
            attribute flowRate : VolumetricFlowRate;
        }
        part oilPan {
            attribute capacity : Volume;
            attribute oilLevel : Real;
        }

        port oilCircuit : OilFlowPort;

        action def PumpOil {
            in item oilIn : LubricatingOil;
            out item oilOut : LubricatingOil;
        }
    }

    part def Engine {
        doc /* Reciprocating internal combustion engine converting chemical energy to mechanical power. */
        attribute configuration : String;
        attribute cylinderCount : Integer;
        attribute displacement : Volume;
        attribute compressionRatio : Ratio;
        attribute deliveredPower : Power;
        attribute deliveredTorque : Torque;
        attribute operatingTemperature : Temperature;
        attribute thermalEfficiency : Efficiency;
        attribute maxRPM : RotationalSpeed;

        part cylinders : Cylinder[*];
        part crankshaft : Crankshaft;
        part camshaft : Camshaft;
        part fuelSystem : FuelSystem;
        part coolingSystem : CoolingSystem;
        part lubricationSystem : LubricationSystem;

        port fuelInput : FuelInPort;
        port airInput : AirInPort;
        port exhaustOutput : ExhaustOutPort;
        port coolantInterface : CoolantFlowPort;
        port oilInterface : OilFlowPort;
        port powerOutput : MechanicalPowerPort;

        connection fuelSupply connect fuelInput to fuelSystem.fuelOutput;
        connection fuelDistribution connect fuelSystem.fuelOutput to cylinders.fuelIntake;
        connection airIntake connect airInput to cylinders.intake;
        connection exhaustFlow connect cylinders.exhaust to exhaustOutput;
        connection pistonToCrank connect cylinders.mechanicalOutput to crankshaft.input;
        connection crankToOutput connect crankshaft.output to powerOutput;
        connection camshaftDrive connect crankshaft.output to camshaft;
        connection intakeValveTiming connect camshaft.intakeControl to cylinders.intakeValve.control;
        connection exhaustValveTiming connect camshaft.exhaustControl to cylinders.exhaustValve.control;
        connection coolantCircuit connect coolantInterface to coolingSystem.coolantCircuit;
        connection oilCircuit connect oilInterface to lubricationSystem.oilCircuit;

        action def CombustionCycle {
            action intakeStroke {
                in item air : Air;
                in item fuel : Fuel;
                out item mixture : FuelAirMixture;
            }
            action compressionStroke {
                in item mixture : FuelAirMixture;
                out item compressedMixture : FuelAirMixture;
            }
            action powerStroke {
                in item compressedMixture : FuelAirMixture;
                out item combustionGas : CombustionGas;
                out attribute mechanicalWork : Power;
            }
            action exhaustStroke {
                in item combustionGas : CombustionGas;
                out item exhaustGas : ExhaustGas;
            }

            succession s1 from intakeStroke to compressionStroke;
            succession s2 from compressionStroke to powerStroke;
            succession s3 from powerStroke to exhaustStroke;
            succession s4 from exhaustStroke to intakeStroke;

            flow f1 from intakeStroke.mixture to compressionStroke.mixture;
            flow f2 from compressionStroke.compressedMixture to powerStroke.compressedMixture;
            flow f3 from powerStroke.combustionGas to exhaustStroke.combustionGas;
        }
    }

    // ===== Requirements =====
    requirement def PowerRequirement {
        doc /* The engine shall deliver at least the minimum specified power output. */
        attribute minPower : Power = 80.0;
        subject engine : Engine;
        require engine.deliveredPower >= minPower;
    }

    requirement def TorqueRequirement {
        doc /* The engine shall deliver at least the minimum specified torque. */
        attribute minTorque : Torque = 150.0;
        subject engine : Engine;
        require engine.deliveredTorque >= minTorque;
    }

    requirement def ThermalEfficiencyRequirement {
        doc /* The engine shall achieve at least the minimum thermal efficiency. */
        attribute minEfficiency : Efficiency = 0.30;
        subject engine : Engine;
        require engine.thermalEfficiency >= minEfficiency;
    }

    requirement def SafeTemperatureRequirement {
        doc /* The engine shall operate within safe temperature limits. */
        attribute maxOperatingTemp : Temperature = 105.0;
        subject engine : Engine;
        require engine.operatingTemperature <= maxOperatingTemp;
    }

    // ===== Engine Configurations =====
    part def Inline4Engine :> Engine {
        doc /* 4-cylinder inline configuration engine. */
        attribute configuration : String = "Inline-4";
        attribute cylinderCount : Integer = 4;
        attribute displacement : Volume = 2.0;
        attribute compressionRatio : Ratio = 10.5;
        attribute deliveredPower : Power = 120.0;
        attribute deliveredTorque : Torque = 200.0;
        attribute maxRPM : RotationalSpeed = 7000.0;
        attribute thermalEfficiency : Efficiency = 0.35;
        attribute operatingTemperature : Temperature = 95.0;

        part cylinders : Cylinder[4];

        satisfy powerReq : PowerRequirement;
        satisfy torqueReq : TorqueRequirement;
        satisfy efficiencyReq : ThermalEfficiencyRequirement;
        satisfy tempReq : SafeTemperatureRequirement;
    }

    part def V6Engine :> Engine {
        doc /* 6-cylinder V configuration engine. */
        attribute configuration : String = "V6";
        attribute cylinderCount : Integer = 6;
        attribute displacement : Volume = 3.5;
        attribute compressionRatio : Ratio = 11.0;
        attribute deliveredPower : Power = 220.0;
        attribute deliveredTorque : Torque = 350.0;
        attribute maxRPM : RotationalSpeed = 6500.0;
        attribute thermalEfficiency : Efficiency = 0.38;
        attribute operatingTemperature : Temperature = 98.0;

        part cylinders : Cylinder[6];

        satisfy powerReq : PowerRequirement;
        satisfy torqueReq : TorqueRequirement;
        satisfy efficiencyReq : ThermalEfficiencyRequirement;
        satisfy tempReq : SafeTemperatureRequirement;
    }
}
