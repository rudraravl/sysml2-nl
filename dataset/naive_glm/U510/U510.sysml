package HandyBilly {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types =====
    value type MassKg :> Real { unit "kg"; }
    value type PowerKw :> Real { unit "kW"; }
    value type VolumeL :> Real { unit "L"; }
    value type DurationMin :> Real { unit "min"; }
    value type DurationHr :> Real { unit "hr"; }
    value type PressureBar :> Real { unit "bar"; }
    value type FlowRateLpm :> Real { unit "L/min"; }
    value type TemperatureC :> Real { unit "degC"; }
    value type LengthM :> Real { unit "m"; }
    value type SpeedRpm :> Real { unit "rpm"; }
    value type Percent :> Real { unit "%"; }

    // ===== Item Types =====
    item def Gasoline;
    item def Water;
    item def Debris;

    // ===== Port Definitions =====
    port def FluidInPort {
        out item water : Water;
        attribute flowRate : FlowRateLpm;
    }
    port def FluidOutPort {
        in item water : Water;
        attribute flowRate : FlowRateLpm;
        attribute pressure : PressureBar;
    }
    port def FuelPort {
        out item fuel : Gasoline;
        attribute supplyRate : FlowRateLpm;
    }
    port def MechanicalShaftPort {
        out attribute torque : Real;
        out attribute speed : SpeedRpm;
    }
    port def ControlPort {
        in attribute command : String;
        out attribute status : String;
    }

    // ===== Requirements =====
    requirement def WeightRequirement {
        doc /* The system shall weigh less than 50 kg for two-person carry. */
        attribute maxWeight : MassKg = 50.0;
        subject :>> systemWeight : MassKg;
        require constraint { systemWeight < maxWeight }
    }

    requirement def SetupTimeRequirement {
        doc /* The system shall be set up and running in under 3 minutes. */
        attribute maxSetupTime : DurationMin = 3.0;
        subject :>> setupTime : DurationMin;
        require constraint { setupTime < maxSetupTime }
    }

    requirement def EnduranceRequirement {
        doc /* The system shall operate continuously for at least 2 hours. */
        attribute minEndurance : DurationHr = 2.0;
        subject :>> endurance : DurationHr;
        require constraint { endurance >= minEndurance }
    }

    requirement def EnginePowerRequirement {
        doc /* The engine shall provide at least 4 kW of power. */
        attribute minPower : PowerKw = 4.0;
        subject :>> enginePower : PowerKw;
        require constraint { enginePower >= minPower }
    }

    requirement def PortabilityRequirement {
        doc /* The system shall be portable and carried by two people. */
        attribute carriers : Integer = 2;
        subject :>> weight : MassKg;
        require constraint { weight < 50.0 }
    }

    // ===== Part Definitions =====

    part def GalvanizedSteelFrame {
        attribute mass : MassKg = 8.0;
        attribute material : String = "Galvanized Steel";
        attribute length : LengthM = 0.6;
        attribute width : LengthM = 0.4;
        port controlPort : ControlPort;
    }

    part def FuelTank {
        attribute capacity : VolumeL = 3.0;
        attribute currentFuelLevel : VolumeL;
        attribute fuelLevelPercent : Percent;
        attribute minFuelThreshold : Percent = 10.0;
        port fuelOut : FuelPort;
        exhibit state tankBehavior {
            entry; then Normal;
            state Normal;
            transition Normal to LowFuel
                when fuelLevelPercent < minFuelThreshold;
            state LowFuel;
            transition LowFuel to Normal
                when fuelLevelPercent >= minFuelThreshold;
        }
    }

    part def GasolineEngine {
        attribute ratedPower : PowerKw = 4.0;
        attribute maxTemperature : TemperatureC = 120.0;
        attribute operatingTemperature : TemperatureC;
        attribute fuelConsumptionRate : FlowRateLpm = 0.025;
        port fuelIn : FuelPort;
        port shaftOut : MechanicalShaftPort;
        port controlPort : ControlPort;
        exhibit state engineOperation {
            entry; then Stopped;
            state Stopped;
            transition Stopped to Starting
                when controlPort.command == "start";
            state Starting;
            transition Starting to Running
                when shaftOut.speed > 0;
            transition Starting to Stopped
                when controlPort.command == "abort";
            state Running;
            transition Running to Overheated
                when operatingTemperature > maxTemperature;
            transition Running to Stopped
                when controlPort.command == "stop";
            state Overheated;
            transition Overheated to Stopped
                when controlPort.command == "stop";
        }
    }

    part def CentrifugalPump {
        attribute ratedFlowRate : FlowRateLpm = 500.0;
        attribute ratedPressure : PressureBar = 2.5;
        attribute isPrimed : Boolean = false;
        attribute isCavitating : Boolean = false;
        port shaftIn : MechanicalShaftPort;
        port suctionPort : FluidInPort;
        port dischargePort : FluidOutPort;
        port controlPort : ControlPort;
        exhibit state pumpOperation {
            entry; then Dry;
            state Dry;
            transition Dry to Primed
                when isPrimed == true;
            state Primed;
            transition Primed to Pumping
                when shaftIn.speed > 0;
            state Pumping;
            transition Pumping to Cavitation
                when isCavitating == true;
            transition Pumping to Primed
                when shaftIn.speed == 0;
            state Cavitation;
            transition Cavitation to Pumping
                when isCavitating == false;
        }
    }

    part def SuctionHose {
        attribute length : LengthM = 3.0;
        attribute diameter : LengthM = 0.05;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
    }

    part def Strainer {
        attribute meshSize : LengthM = 0.005;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        action def filter {
            in item incoming : Water;
            in item debris : Debris;
            out item filtered : Water;
        }
    }

    part def DischargeHose {
        attribute length : LengthM = 10.0;
        attribute diameter : LengthM = 0.04;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
    }

    part def Nozzle {
        attribute orificeDiameter : LengthM = 0.02;
        attribute jetAngle : Real = 15.0;
        port inlet : FluidInPort;
        port outlet : FluidOutPort;
        action def formJet {
            in item water : Water;
            in attribute pressure : PressureBar;
            out item jet : Water;
        }
    }

    // ===== Top-level System =====
    part def HandyBillySystem {
        attribute totalMass : MassKg;
        attribute setupTime : DurationMin;
        attribute endurance : DurationHr;

        satisfy WeightRequirement { subject :>> systemWeight = totalMass; }
        satisfy SetupTimeRequirement { subject :>> setupTime = setupTime; }
        satisfy EnduranceRequirement { subject :>> endurance = endurance; }
        satisfy EnginePowerRequirement { subject :>> enginePower = engine.ratedPower; }

        part frame : GalvanizedSteelFrame;
        part fuelTank : FuelTank;
        part engine : GasolineEngine;
        part pump : CentrifugalPump;
        part suctionHose : SuctionHose;
        part strainer : Strainer;
        part dischargeHose : DischargeHose;
        part nozzle : Nozzle;

        connection fuelSupply connect fuelTank.fuelOut to engine.fuelIn;
        connection mechanicalCoupling connect engine.shaftOut to pump.shaftIn;
        connection suctionLine connect strainer.outlet to suctionHose.inlet;
        connection pumpSuction connect suctionHose.outlet to pump.suctionPort;
        connection pumpDischarge connect pump.dischargePort to dischargeHose.inlet;
        connection dischargeLine connect dischargeHose.outlet to nozzle.inlet;

        // External interfaces
        port waterIntake : FluidInPort;
        port waterJet : FluidOutPort;
        port systemControl : ControlPort;

        connection externalSuction connect waterIntake to strainer.inlet;
        connection externalDischarge connect nozzle.outlet to waterJet;
        connection controlLink connect systemControl to frame.controlPort;
        connection engineControl connect frame.controlPort to engine.controlPort;
        connection pumpControl connect frame.controlPort to pump.controlPort;

        exhibit state systemLifecycle {
            entry; then Idle;
            state Idle;
            transition Idle to Priming
                when systemControl.command == "prime";
            state Priming {
                entry action { pump.isPrimed := true; }
            }
            transition Priming to Running
                when pump.isPrimed == true and systemControl.command == "run";
            state Running;
            transition Running to Fault
                when engine.operatingTemperature > engine.maxTemperature
                    or fuelTank.fuelLevelPercent < fuelTank.minFuelThreshold
                    or pump.isCavitating == true;
            transition Running to ShuttingDown
                when systemControl.command == "stop";
            state Fault {
                entry action { engine.controlPort.command := "stop"; }
            }
            transition Fault to ShuttingDown
                when systemControl.command == "acknowledge";
            state ShuttingDown {
                entry action { engine.controlPort.command := "stop"; }
            }
            transition ShuttingDown to Idle
                when engine.shaftOut.speed == 0;
        }

        action def deploySystem {
            in attribute location : String;
            out attribute ready : Boolean;
            then action connectSuctionHose;
            then action connectDischargeHose;
            then action primePump;
            then action startEngine;
        }

        action def connectSuctionHose;
        action def connectDischargeHose;
        action def primePump {
            out attribute primed : Boolean;
        }
        action def startEngine {
            out attribute running : Boolean;
        }
    }

    // ===== Instances =====
    part handyBillyInstance : HandyBillySystem {
        attribute totalMass = 45.0;
        attribute setupTime = 2.5;
        attribute endurance = 2.5;
        reframe part fuelTank : FuelTank {
            attribute currentFuelLevel = 3.0;
            attribute fuelLevelPercent = 100.0;
        }
    }
}
