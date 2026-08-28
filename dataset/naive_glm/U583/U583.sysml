package WaterPumpingSystem {
    import SI::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    attribute def Length :> Real { unit 'm'; }
    attribute def Angle :> Real { unit 'deg'; }
    attribute def Volume :> Real { unit 'm^3'; }
    attribute def VolumetricFlowRate :> Real { unit 'm^3/s'; }
    attribute def RotationalSpeed :> Real { unit 'rev/min'; }
    attribute def Torque :> Real { unit 'N*m'; }
    attribute def Power :> Real { unit 'W'; }
    attribute def Duration :> Real { unit 'h'; }
    attribute def Efficiency :> Real { unit '%'; }
    attribute def Elevation :> Real { unit 'm'; }

    // ---- Items ----
    item def Water;

    // ---- Port definitions ----
    port def FluidPort {
        out item water : Water;
        in attribute flowRate : VolumetricFlowRate;
    }
    port def FluidInPort {
        in item water : Water;
        out attribute demandFlow : VolumetricFlowRate;
    }
    port def FluidOutPort {
        out item water : Water;
        out attribute flowRate : VolumetricFlowRate;
    }
    port def MechanicalShaftPort {
        out attribute speed : RotationalSpeed;
        out attribute torque : Torque;
    }
    port def ElectricalPowerPort {
        in attribute voltage : Real;
        in attribute current : Real;
    }
    port def SignalPort {
        out attribute measuredFlow : VolumetricFlowRate;
    }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ---- Sump Reservoir ----
    part def SumpReservoir {
        attribute minLevel : Length = 0.5 [m];
        attribute maxLevel : Length = 3.0 [m];
        attribute currentLevel : Length;
        attribute capacity : Volume = 10.0 [m^3];
        attribute elevation : Elevation = 0.0 [m];

        port fluidOut : FluidOutPort;

        exhibit state ReservoirBehavior {
            entry; then Normal;
            state Normal;
            state LowLevel;
            state HighLevel;
            transition Normal to LowLevel when currentLevel < minLevel;
            transition LowLevel to Normal when currentLevel >= minLevel;
            transition Normal to HighLevel when currentLevel >= maxLevel;
            transition HighLevel to Normal when currentLevel < maxLevel;
        }

        action def UpdateLevel(in deltaVolume : Volume) {
            // Updates currentLevel based on volume change
        }
    }

    // ---- Wood Screw Pump ----
    part def WoodScrewPump {
        attribute diameter : Length = 0.8 [m];
        attribute length : Length = 6.0 [m];
        attribute bladePitch : Length = 0.9 [m];
        attribute inclinationAngle : Angle = 30.0 [deg];
        attribute nominalSpeed : RotationalSpeed = 60.0 [rev/min];
        attribute theoreticalFlowRate : VolumetricFlowRate = 0.05 [m^3/s];
        attribute efficiency : Efficiency = 75.0 [%];

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port driveShaft : MechanicalShaftPort;
        port control : ControlPort;

        exhibit state PumpOperation {
            entry; then Idle;
            state Idle;
            state Starting;
            state Running;
            state Stopping;

            transition Idle to Starting when control.command == "start";
            transition Starting to Running when driveShaft.speed >= nominalSpeed;
            transition Running to Stopping when control.command == "stop";
            transition Stopping to Idle when driveShaft.speed == 0.0 [rev/min];
        }

        action def LiftFluid(in inFlow : VolumetricFlowRate, out outFlow : VolumetricFlowRate) {
            // Lifts fluid along the inclined screw
        }
    }

    // ---- Electric Motor ----
    part def ElectricMotor {
        attribute ratedPower : Power = 5000.0 [W];
        attribute ratedSpeed : RotationalSpeed = 1450.0 [rev/min];
        attribute ratedTorque : Torque = 33.0 [N*m];
        attribute supplyVoltage : Real = 400.0;
        attribute supplyCurrent : Real = 12.0;

        port powerIn : ElectricalPowerPort;
        port shaftOut : MechanicalShaftPort;
        port control : ControlPort;

        exhibit state MotorOperation {
            entry; then Off;
            state Off;
            state Starting;
            state Accelerating;
            state Running;
            state Decelerating;

            transition Off to Starting when control.command == "start";
            transition Starting to Accelerating;
            transition Accelerating to Running when shaftOut.speed >= ratedSpeed;
            transition Running to Decelerating when control.command == "stop";
            transition Decelerating to Off when shaftOut.speed == 0.0 [rev/min];
        }

        action def GenerateTorque(out torque : Torque, out speed : RotationalSpeed) {
            // Converts electrical energy into mechanical torque
        }
    }

    // ---- Flow Meter ----
    part def FlowMeter {
        attribute maxFlowRate : VolumetricFlowRate = 0.2 [m^3/s];
        attribute accuracy : Efficiency = 99.0 [%];
        attribute totalVolume : Volume = 0.0 [m^3];

        port fluidIn : FluidInPort;
        port fluidOut : FluidOutPort;
        port signalOut : SignalPort;

        action def MeasureFlow(in inFlow : VolumetricFlowRate, out measured : VolumetricFlowRate) {
            // Measures instantaneous flow rate
        }

        action def AccumulateVolume(in flowRate : VolumetricFlowRate, in dt : Duration) {
            // Integrates flow rate over time
        }
    }

    // ---- Discharge Tank ----
    part def DischargeTank {
        attribute maxLevel : Length = 4.0 [m];
        attribute currentLevel : Length;
        attribute capacity : Volume = 15.0 [m^3];
        attribute elevation : Elevation = 8.0 [m];

        port fluidIn : FluidInPort;

        exhibit state TankBehavior {
            entry; then Filling;
            state Filling;
            state Full;
            transition Filling to Full when currentLevel >= maxLevel;
            transition Full to Filling when currentLevel < maxLevel;
        }

        action def ReceiveFluid(in flowRate : VolumetricFlowRate, in dt : Duration) {
            // Accumulates incoming fluid
        }
    }

    // ---- System composition ----
    part def WaterPumpingSystem {
        part sump : SumpReservoir {
            attribute currentLevel redefines currentLevel = 2.0 [m];
        }
        part pump : WoodScrewPump;
        part motor : ElectricMotor;
        part flowMeter : FlowMeter;
        part dischargeTank : DischargeTank {
            attribute currentLevel redefines currentLevel = 0.0 [m];
        }

        connection sumpFluidPath : FluidPort connect sump.fluidOut to pump.fluidIn;
        connection pumpFluidPath : FluidPort connect pump.fluidOut to flowMeter.fluidIn;
        connection meterFluidPath : FluidPort connect flowMeter.fluidOut to dischargeTank.fluidIn;
        connection mechanicalCoupling : MechanicalShaftPort connect motor.shaftOut to pump.driveShaft;
        connection motorControl : ControlPort connect pump.control to motor.control;
        connection flowSignal : SignalPort connect flowMeter.signalOut to pump.control;

        attribute systemFlowRate : VolumetricFlowRate;
        attribute systemEfficiency : Efficiency;
        attribute operatingTime : Duration;
    }

    // ---- Requirements ----
    requirement def MinFlowRateRequirement {
        attribute minFlowRate : VolumetricFlowRate = 0.03 [m^3/s];
        requirement {
            subject :> WaterPumpingSystem.systemFlowRate;
            objective {
                WaterPumpingSystem.systemFlowRate >= minFlowRate;
            }
        }
    }

    requirement def EfficiencyRequirement {
        attribute minEfficiency : Efficiency = 70.0 [%];
        requirement {
            subject :> WaterPumpingSystem.systemEfficiency;
            objective {
                WaterPumpingSystem.systemEfficiency >= minEfficiency;
            }
        }
    }

    requirement def ReliabilityRequirement {
        attribute minOperatingTime : Duration = 8.0 [h];
        requirement {
            subject :> WaterPumpingSystem.operatingTime;
            objective {
                WaterPumpingSystem.operatingTime >= minOperatingTime;
            }
        }
    }

    requirement def PumpingSystemRequirements {
        requirement minFlowReq : MinFlowRateRequirement;
        requirement efficiencyReq : EfficiencyRequirement;
        requirement reliabilityReq : ReliabilityRequirement;
    }

    requirement def SumpLevelRequirement {
        attribute minLevel : Length = 0.5 [m];
        attribute maxLevel : Length = 3.0 [m];
        requirement {
            subject :> SumpReservoir.currentLevel;
            objective {
                SumpReservoir.currentLevel >= minLevel and
                SumpReservoir.currentLevel <= maxLevel;
            }
        }
    }

    requirement def DischargeTankLevelRequirement {
        attribute maxLevel : Length = 4.0 [m];
        requirement {
            subject :> DischargeTank.currentLevel;
            objective {
                DischargeTank.currentLevel <= maxLevel;
            }
        }
    }
}
