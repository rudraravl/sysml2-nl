package PulsometerPumpSystem {

    import ScalarValues::*;

    // =====================================================================
    // Value Types with Units
    // =====================================================================
    value type PressureValue :> Real {
        attribute unit : String = "Pa";
    }
    value type TemperatureValue :> Real {
        attribute unit : String = "K";
    }
    value type FlowRateValue :> Real {
        attribute unit : String = "m3/s";
    }
    value type VolumeValue :> Real {
        attribute unit : String = "m3";
    }
    value type MassFlowRateValue :> Real {
        attribute unit : String = "kg/s";
    }
    value type LevelValue :> Real {
        attribute unit : String = "m";
    }
    value type LengthValue :> Real {
        attribute unit : String = "m";
    }
    value type DurationValue :> Real {
        attribute unit : String = "s";
    }
    value type EnergyValue :> Real {
        attribute unit : String = "J";
    }
    value type EfficiencyValue :> Real {
        attribute unit : String = "1";
    }

    // =====================================================================
    // Item Definitions
    // =====================================================================
    item def Water {
        attribute density : Real = 1000;            // kg/m3
        attribute temperature : TemperatureValue = 293.15;
        attribute specificHeat : Real = 4186;       // J/(kg.K)
    }
    item def Steam {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute massFlow : MassFlowRateValue;
        attribute latentHeat : Real = 2257e3;       // J/kg
    }
    item def Condensate :> Water {
        attribute origin : String = "condensedSteam";
    }

    // =====================================================================
    // Port Definitions
    // =====================================================================
    port def SteamPort {
        out item : Steam;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute massFlow : MassFlowRateValue;
    }
    port def WaterFlowPort {
        in item : Water;
        out item : Water;
        attribute flowRate : FlowRateValue;
        attribute pressure : PressureValue;
    }
    port def CondensatePort {
        out item : Condensate;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }
    port def ControlSignalPort {
        attribute command : String;
        attribute active : Boolean;
    }

    // =====================================================================
    // Requirements
    // =====================================================================
    requirement def PumpPerformanceReq {
        doc /* The pulsometer pump system shall deliver a minimum discharge flow
               while operating within a defined steam pressure band. */
        attribute minDischargeFlowRate : FlowRateValue = 0.010;   // ~600 L/min
        attribute minSteamPressure : PressureValue = 0.5e6;       // 0.5 MPa
        attribute maxSteamPressure : PressureValue = 1.5e6;       // 1.5 MPa
        requirement deliverFlow {
            doc /* The pump shall deliver at least minDischargeFlowRate at the
                   discharge port under nominal conditions. */
        }
        requirement operateRange {
            doc /* The pump shall operate with inlet steam pressure between
                   minSteamPressure and maxSteamPressure. */
        }
    }
    requirement def AlternatingChambersReq {
        doc /* The two pumping chambers shall operate in alternating sequence:
               while one chamber fills via vacuum, the other discharges via
               direct steam pressure. */
    }
    requirement def OneWayValveReq {
        doc /* Each chamber shall be equipped with one-way suction and discharge
               check valves that prevent reverse flow of water. */
    }
    requirement def CondensateRecoveryReq {
        doc /* Condensed steam exhausted after the pumping cycle shall be routed
               to a condensate receiver for reuse or controlled disposal. */
    }
    requirement def SuctionLiftReq {
        doc /* The pump shall lift water from a source at a lower elevation to a
               discharge tank at a higher elevation. */
        attribute maxSuctionLift : LengthValue = 7.0;
        attribute dischargeHead : LengthValue = 5.0;
    }
    requirement def BoilerSafetyReq {
        doc /* The steam boiler shall be protected against over-pressure by a
               fault state that interrupts steam generation. */
        attribute maxAllowablePressure : PressureValue = 1.5e6;
    }

    // =====================================================================
    // Check Valve
    // =====================================================================
    part def CheckValve {
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        attribute crackingPressure : PressureValue = 2000;       // Pa
        attribute isOpen : Boolean = false;
        attribute nominalDiameter : LengthValue = 0.10;

        state machine ValveState {
            state Closed {
                entry { assign isOpen = false; }
            }
            state Open {
                entry { assign isOpen = true; }
                do { assign outlet.flowRate = inlet.flowRate; }
            }
            transition from Closed to Open when inlet.pressure - outlet.pressure > crackingPressure;
            transition from Open to Closed when inlet.pressure <= outlet.pressure;
        }
    }

    // =====================================================================
    // Pumping Chamber
    // =====================================================================
    part def PumpingChamber {
        port steamIn : SteamPort;
        port suctionSide : WaterFlowPort;
        port dischargeSide : WaterFlowPort;
        port condensateDrain : CondensatePort;
        port controlIn : ControlSignalPort;

        attribute chamberVolume : VolumeValue = 0.5;
        attribute chamberHeight : LengthValue = 1.0;
        attribute waterLevel : LevelValue = 0;
        attribute chamberPressure : PressureValue = 101325;
        attribute chamberTemperature : TemperatureValue = 293.15;
        attribute steamAdmitted : Boolean = false;
        attribute full : Boolean = false;
        attribute empty : Boolean = true;
        attribute steamSupplyReady : Boolean = false;
        attribute cycleCount : Integer = 0;

        state machine ChamberCycle {
            state Empty {
                entry {
                    assign empty = true;
                    assign full = false;
                    assign waterLevel = 0;
                    assign chamberPressure = 101325;
                    assign steamAdmitted = false;
                }
            }
            state SteamAdmission {
                entry {
                    assign steamAdmitted = true;
                    assign chamberPressure = 1.2e5;
                }
                do {
                    assign chamberPressure = chamberPressure - 4000;
                    assign chamberTemperature = chamberTemperature + 0.5;
                }
            }
            state VacuumFill {
                entry { assign steamAdmitted = false; }
                do {
                    assign chamberPressure = chamberPressure - 1500;
                    assign waterLevel = waterLevel + 0.05;
                }
            }
            state Full {
                entry {
                    assign full = true;
                    assign empty = false;
                    assign waterLevel = chamberHeight;
                    assign chamberPressure = 50000;
                }
            }
            state Pressurize {
                entry { assign steamAdmitted = true; }
                do {
                    assign chamberPressure = chamberPressure + 6.0e4;
                    assign chamberTemperature = chamberTemperature + 1.0;
                }
            }
            state Discharge {
                entry { assign steamAdmitted = true; }
                do {
                    assign waterLevel = waterLevel - 0.05;
                    assign chamberPressure = chamberPressure - 5.0e3;
                    assign condensateDrain.flowRate = 0.001;
                }
            }
            transition from Empty to SteamAdmission when steamSupplyReady;
            transition from SteamAdmission to VacuumFill when chamberPressure < 40000;
            transition from VacuumFill to Full when waterLevel >= chamberHeight;
            transition from Full to Pressurize when steamSupplyReady;
            transition from Pressurize to Discharge when chamberPressure >= 5.0e5;
            transition from Discharge to Empty when waterLevel <= 0.05;
            transition from Discharge to Empty {
                effect { assign cycleCount = cycleCount + 1; }
            }
        }
    }

    // =====================================================================
    // Pulsometer Pump (Dual-Chamber)
    // =====================================================================
    part def PulsometerPump {
        port steamSupply : SteamPort;
        port suctionPort : WaterFlowPort;
        port dischargePort : WaterFlowPort;
        port condensatePort : CondensatePort;

        part chamberA : PumpingChamber;
        part chamberB : PumpingChamber;

        part suctionValveA : CheckValve;
        part suctionValveB : CheckValve;
        part dischargeValveA : CheckValve;
        part dischargeValveB : CheckValve;

        attribute alternationPhase : String = "A_fill_B_discharge";
        attribute totalDischargeFlow : FlowRateValue = 0;

        connect steamSupply to chamberA.steamIn;
        connect steamSupply to chamberB.steamIn;

        connect suctionPort to suctionValveA.inlet;
        connect suctionValveA.outlet to chamberA.suctionSide;
        connect suctionPort to suctionValveB.inlet;
        connect suctionValveB.outlet to chamberB.suctionSide;

        connect chamberA.dischargeSide to dischargeValveA.inlet;
        connect dischargeValveA.outlet to dischargePort;
        connect chamberB.dischargeSide to dischargeValveB.inlet;
        connect dischargeValveB.outlet to dischargePort;

        connect chamberA.condensateDrain to condensatePort;
        connect chamberB.condensateDrain to condensatePort;

        state machine Coordinator {
            state A_Filling_B_Discharging {
                entry {
                    assign chamberA.steamSupplyReady = true;
                    assign chamberB.steamSupplyReady = true;
                    assign alternationPhase = "A_fill_B_discharge";
                }
                do {
                    assign chamberA.steamSupplyReady = true;
                    assign chamberB.steamSupplyReady = true;
                }
            }
            state A_Discharging_B_Filling {
                entry {
                    assign chamberA.steamSupplyReady = true;
                    assign chamberB.steamSupplyReady = true;
                    assign alternationPhase = "A_discharge_B_fill";
                }
                do {
                    assign chamberA.steamSupplyReady = true;
                    assign chamberB.steamSupplyReady = true;
                }
            }
            transition from A_Filling_B_Discharging to A_Discharging_B_Filling
                when chamberA.full and chamberB.empty;
            transition from A_Discharging_B_Filling to A_Filling_B_Discharging
                when chamberB.full and chamberA.empty;
        }
    }

    // =====================================================================
    // Steam Boiler
    // =====================================================================
    part def SteamBoiler {
        port steamOutlet : SteamPort;
        port waterInlet : WaterFlowPort;
        port controlIn : ControlSignalPort;

        attribute nominalPressure : PressureValue = 1.0e6;
        attribute maxPressure : PressureValue = 1.5e6;
        attribute minPressure : PressureValue = 0.5e6;
        attribute steamGenRate : MassFlowRateValue = 0.5;
        attribute operatingTemperature : TemperatureValue = 453.15;
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute resetCommand : Boolean = false;
        attribute fuelInput : MassFlowRateValue = 0.05;
        attribute boilerEfficiency : EfficiencyValue = 0.85;

        state machine BoilerState {
            state Off {
                entry {
                    assign steamOutlet.pressure = 0;
                    assign steamOutlet.massFlow = 0;
                    assign startCommand = false;
                }
            }
            state Warmup {
                entry { assign steamOutlet.pressure = 1.0e5; }
                do {
                    assign steamOutlet.pressure = steamOutlet.pressure + 5.0e3;
                    assign steamOutlet.temperature = operatingTemperature;
                }
            }
            state Operating {
                entry {
                    assign steamOutlet.pressure = nominalPressure;
                    assign steamOutlet.massFlow = steamGenRate;
                    assign steamOutlet.temperature = operatingTemperature;
                }
            }
            state Fault {
                entry {
                    assign steamOutlet.pressure = 0;
                    assign steamOutlet.massFlow = 0;
                }
            }
            transition from Off to Warmup when startCommand;
            transition from Warmup to Operating when steamOutlet.pressure >= nominalPressure;
            transition from Operating to Fault when steamOutlet.pressure > maxPressure;
            transition from Operating to Off when stopCommand;
            transition from Fault to Off when resetCommand;
        }
    }

    // =====================================================================
    // Water Source
    // =====================================================================
    part def WaterSource {
        port waterOutlet : WaterFlowPort;
        attribute sourceType : String = "well";
        attribute sourceLevel : LevelValue = 0;
        attribute availableVolume : VolumeValue = 100;
        attribute waterTemperature : TemperatureValue = 288.15;
        attribute staticPressure : PressureValue = 101325;
    }

    // =====================================================================
    // Discharge Tank
    // =====================================================================
    part def DischargeTank {
        port waterInlet : WaterFlowPort;
        port overflow : WaterFlowPort;
        attribute capacity : VolumeValue = 50;
        attribute currentLevel : LevelValue = 0;
        attribute elevation : LengthValue = 5.0;
        attribute tankCrossSection : Real = 3.14;     // m2

        state machine TankLevel {
            state Normal;
            state Filling {
                do { assign currentLevel = currentLevel + 0.001; }
            }
            state Overflow {
                entry { assign overflow.flowRate = waterInlet.flowRate; }
            }
            transition from Normal to Filling when waterInlet.flowRate > 0;
            transition from Filling to Overflow when currentLevel >= capacity / tankCrossSection;
            transition from Overflow to Normal when waterInlet.flowRate = 0;
        }
    }

    // =====================================================================
    // Condensate Receiver
    // =====================================================================
    part def CondensateReceiver {
        port condensateIn : CondensatePort;
        port drain : CondensatePort;
        attribute capacity : VolumeValue = 20;
        attribute currentVolume : VolumeValue = 0;
        attribute receiverTemperature : TemperatureValue = 320.0;

        state machine ReceiverLevel {
            state Accepting {
                do { assign currentVolume = currentVolume + 0.0005; }
            }
            state Draining {
                entry { assign drain.flowRate = 0.002; }
                do { assign currentVolume = currentVolume - 0.002; }
            }
            state Idle;
            transition from Idle to Accepting when condensateIn.flowRate > 0;
            transition from Accepting to Draining when currentVolume >= 0.9 * capacity;
            transition from Draining to Idle when currentVolume <= 0.1 * capacity;
        }
    }

    // =====================================================================
    // Drain (for discharge tank overflow)
    // =====================================================================
    part def Drain {
        port waterIn : WaterFlowPort;
        attribute drainCapacity : FlowRateValue = 0.1;
    }

    // =====================================================================
    // Pipes
    // =====================================================================
    part def SteamPipe {
        port inlet : SteamPort;
        port outlet : SteamPort;
        attribute length : LengthValue = 2.0;
        attribute diameter : LengthValue = 0.05;
        attribute insulationThickness : LengthValue = 0.025;
        attribute pressureLoss : PressureValue = 5.0e3;
    }
    part def WaterPipe {
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        attribute length : LengthValue = 3.0;
        attribute diameter : LengthValue = 0.10;
        attribute frictionLoss : PressureValue = 2.0e3;
    }
    part def CondensatePipe {
        port inlet : CondensatePort;
        port outlet : CondensatePort;
        attribute length : LengthValue = 1.0;
        attribute diameter : LengthValue = 0.025;
    }

    // =====================================================================
    // Top-Level Pulsometer Pumping System
    // =====================================================================
    part def PulsometerPumpingSystem {
        satisfy PumpPerformanceReq;
        satisfy AlternatingChambersReq;
        satisfy OneWayValveReq;
        satisfy CondensateRecoveryReq;
        satisfy SuctionLiftReq;
        satisfy BoilerSafetyReq;

        part boiler : SteamBoiler;
        part pump : PulsometerPump;
        part source : WaterSource;
        part tank : DischargeTank;
        part receiver : CondensateReceiver;
        part drain : Drain;

        part steamPipe : SteamPipe;
        part suctionPipe : WaterPipe;
        part dischargePipe : WaterPipe;
        part condensatePipe : CondensatePipe;
        part overflowPipe : WaterPipe;

        // ---- Steam supply chain ----
        connect boiler.steamOutlet to steamPipe.inlet;
        connect steamPipe.outlet to pump.steamSupply;

        // ---- Suction chain ----
        connect source.waterOutlet to suctionPipe.inlet;
        connect suctionPipe.outlet to pump.suctionPort;

        // ---- Discharge chain ----
        connect pump.dischargePort to dischargePipe.inlet;
        connect dischargePipe.outlet to tank.waterInlet;

        // ---- Condensate return chain ----
        connect pump.condensatePort to condensatePipe.inlet;
        connect condensatePipe.outlet to receiver.condensateIn;

        // ---- Tank overflow / drain ----
        connect tank.overflow to overflowPipe.inlet;
        connect overflowPipe.outlet to drain.waterIn;

        // ---- Boiler makeup water (optional return from receiver) ----
        connect receiver.drain to boiler.waterInlet;

        // ---- Controller wiring (start/stop) ----
        connect boiler.controlIn to pump.steamSupply;
    }

    // =====================================================================
    // System Instantiation
    // =====================================================================
    part pulsometerPumpingSystem : PulsometerPumpingSystem;
}
