package PulsometerPumpingSystem {
    import SI::*;
    import ScalarValues::*;

    // ---- Value Types ----
    value type PressureValue :> Real { unit 'Pa'; }
    value type TemperatureValue :> Real { unit 'K'; }
    value type VolumeValue :> Real { unit 'm3'; }
    value type VolumeFlowRateValue :> Real { unit 'm3/s'; }
    value type MassFlowRateValue :> Real { unit 'kg/s'; }
    value type LengthValue :> Real { unit 'm'; }
    value type DurationValue :> Real { unit 's'; }
    value type AreaValue :> Real { unit 'm2'; }

    // ---- Item Types ----
    item def Water;
    item def Steam;
    item def Condensate :> Water;

    // ---- Port Definitions ----
    port def SteamPort {
        out item steam : Steam;
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
        attribute massFlowRate : MassFlowRateValue;
    }

    port def WaterPort {
        out item water : Water;
        attribute pressure : PressureValue;
        attribute volumeFlowRate : VolumeFlowRateValue;
    }

    port def CondensatePort {
        out item condensate : Condensate;
        attribute volumeFlowRate : VolumeFlowRateValue;
    }

    // ---- Check Valve ----
    part def CheckValve {
        port inlet : WaterPort;
        port outlet : WaterPort;
        attribute crackingPressure : PressureValue = 5000.0 [Pa];
        attribute isOpen : Boolean;
        attribute flowRate : VolumeFlowRateValue;

        action def regulateFlow {
            in currentInletPressure : PressureValue;
            in currentOutletPressure : PressureValue;
            out valveOpen : Boolean;
            out flow : VolumeFlowRateValue;
        }
    }

    // ---- Boiler ----
    part def SteamBoiler {
        port steamOut : SteamPort;
        attribute steamPressure : PressureValue = 800000.0 [Pa];
        attribute steamTemperature : TemperatureValue = 450.0 [K];
        attribute steamFlowRate : MassFlowRateValue = 0.5 [kg/s];
        attribute waterCapacity : VolumeValue = 2.0 [m3];

        action def generateSteam {
            out steam : Steam;
        }
    }

    // ---- Source Reservoir ----
    part def SourceReservoir {
        port waterOut : WaterPort;
        attribute waterLevel : LengthValue = 2.0 [m];
        attribute waterVolume : VolumeValue = 10.0 [m3];
        attribute ambientPressure : PressureValue = 101325.0 [Pa];
    }

    // ---- Delivery Tank ----
    part def DeliveryTank {
        port waterIn : WaterPort;
        attribute waterLevel : LengthValue = 0.0 [m];
        attribute tankPressure : PressureValue = 101325.0 [Pa];
        attribute capacity : VolumeValue = 20.0 [m3];
        attribute currentVolume : VolumeValue = 0.0 [m3];
    }

    // ---- Condensate Tank ----
    part def CondensateTank {
        port condensateIn : CondensatePort;
        attribute currentVolume : VolumeValue = 0.0 [m3];
        attribute capacity : VolumeValue = 5.0 [m3];
    }

    // ---- Pump Chamber ----
    part def PumpChamber {
        port steamIn : SteamPort;
        port suctionIn : WaterPort;
        port dischargeOut : WaterPort;
        port condensateOut : CondensatePort;

        attribute chamberVolume : VolumeValue = 0.05 [m3];
        attribute currentWaterVolume : VolumeValue = 0.05 [m3];
        attribute currentSteamVolume : VolumeValue = 0.0 [m3];
        attribute internalPressure : PressureValue = 101325.0 [Pa];
        attribute internalTemperature : TemperatureValue = 293.0 [K];
        attribute chamberId : String;

        // Check valves for this chamber
        part suctionCheckValve : CheckValve {
            redefines crackingPressure = 3000.0 [Pa];
        }
        part dischargeCheckValve : CheckValve {
            redefines crackingPressure = 3000.0 [Pa];
        }

        // State machine for chamber operation
        state def ChamberCycle {
            entry; then SteamAdmission;

            state SteamAdmission {
                entry {
                    // Open steam admission, chamber is full of water
                    internalPressure := 800000.0 [Pa];
                    internalTemperature := 450.0 [K];
                }
                do {
                    // Steam admitted into chamber
                    currentSteamVolume := currentSteamVolume + 0.001 [m3];
                }
                transition SteamAdmission -> Discharging
                    when (currentWaterVolume > 0.0 [m3] and internalPressure > 200000.0 [Pa]);
            }

            state Discharging {
                entry {
                    // Steam pushes water out through discharge check valve
                    dischargeCheckValve.isOpen := true;
                    suctionCheckValve.isOpen := false;
                }
                do {
                    // Water is forced out of chamber
                    currentWaterVolume := currentWaterVolume - 0.005 [m3];
                    currentSteamVolume := currentSteamVolume + 0.005 [m3];
                }
                transition Discharging -> SteamCondensation
                    when (currentWaterVolume <= 0.0 [m3]);
            }

            state SteamCondensation {
                entry {
                    dischargeCheckValve.isOpen := false;
                    suctionCheckValve.isOpen := false;
                }
                do {
                    // Steam condenses, creating vacuum
                    currentSteamVolume := currentSteamVolume - 0.002 [m3];
                    internalPressure := internalPressure - 50000.0 [Pa];
                    internalTemperature := internalTemperature - 20.0 [K];
                }
                transition SteamCondensation -> Filling
                    when (internalPressure < 50000.0 [Pa]);
            }

            state Filling {
                entry {
                    // Vacuum pulls water through suction check valve
                    suctionCheckValve.isOpen := true;
                    dischargeCheckValve.isOpen := false;
                }
                do {
                    // Water drawn into chamber from source reservoir
                    currentWaterVolume := currentWaterVolume + 0.005 [m3];
                    currentSteamVolume := currentSteamVolume - 0.001 [m3];
                    internalPressure := internalPressure + 5000.0 [Pa];
                    internalTemperature := internalTemperature + 5.0 [K];
                }
                transition Filling -> SteamAdmission
                    when (currentWaterVolume >= chamberVolume);
            }
        }

        part behavior :>> ChamberCycle;
    }

    // ---- Pulsometer Pump ----
    part def PulsometerPump {
        port steamInlet : SteamPort;
        port suctionPort : WaterPort;
        port dischargePort : WaterPort;
        port condensatePort : CondensatePort;

        attribute pumpCycleTime : DurationValue = 4.0 [s];
        attribute nominalFlowRate : VolumeFlowRateValue = 0.025 [m3/s];

        part chamberA : PumpChamber {
            redefines chamberId = "A";
        }
        part chamberB : PumpChamber {
            redefines chamberId = "B";
        }

        // Internal connections from pump ports to chambers
        connection : SteamPort connect steamInlet to chamberA.steamIn;
        connection : SteamPort connect steamInlet to chamberB.steamIn;
        connection : WaterPort connect suctionPort to chamberA.suctionIn;
        connection : WaterPort connect suctionPort to chamberB.suctionIn;
        connection : WaterPort connect chamberA.dischargeOut to dischargePort;
        connection : WaterPort connect chamberB.dischargeOut to dischargePort;
        connection : CondensatePort connect chamberA.condensateOut to condensatePort;
        connection : CondensatePort connect chamberB.condensateOut to condensatePort;

        // Alternating operation coordination
        action def coordinateChambers {
            // Chamber A and B operate in opposite phases
            // When A is in Discharging, B is in Filling
            // When A is in SteamCondensation, B is in SteamAdmission
        }
    }

    // ---- System ----
    part def PulsometerPumpingSystem {
        attribute systemName : String = "Steam Pulsometer Pumping System";
        attribute designPressure : PressureValue = 800000.0 [Pa];
        attribute designFlowRate : VolumeFlowRateValue = 0.05 [m3/s];

        part boiler : SteamBoiler;
        part sourceReservoir : SourceReservoir;
        part deliveryTank : DeliveryTank;
        part condensateTank : CondensateTank;
        part pump : PulsometerPump;

        // System-level connections
        connection : SteamPort connect boiler.steamOut to pump.steamInlet;
        connection : WaterPort connect sourceReservoir.waterOut to pump.suctionPort;
        connection : WaterPort connect pump.dischargePort to deliveryTank.waterIn;
        connection : CondensatePort connect pump.condensatePort to condensateTank.condensateIn;
    }

    // ---- Requirements ----
    requirement def PumpingRequirement {
        subject system : PulsometerPumpingSystem;
        objective {
            doc "The system shall move water from a source reservoir to a higher-pressure delivery tank using direct steam force."
        }
    }

    requirement def AlternatingChamberRequirement {
        subject pump : PulsometerPump;
        objective {
            doc "The pump shall feature two identical operating chambers working in an alternating cycle to create continuous pulsating flow."
        }
    }

    requirement def SteamAdmissionRequirement {
        subject chamber : PumpChamber;
        objective {
            doc "High-pressure steam from the boiler shall be admitted into a chamber that is full of water."
        }
    }

    requirement def DischargeRequirement {
        subject chamber : PumpChamber;
        objective {
            doc "Steam pressure shall push directly on the water surface, forcing it out through a one-way discharge check valve into the delivery pipe."
        }
    }

    requirement def CondensationRequirement {
        subject chamber : PumpChamber;
        objective {
            doc "After the chamber is empty of water, the steam inside shall condense, creating a strong vacuum."
        }
    }

    requirement def FillingRequirement {
        subject chamber : PumpChamber;
        objective {
            doc "The vacuum shall pull water from the source reservoir through a one-way suction check valve, refilling the chamber."
        }
    }

    requirement def OppositePhaseRequirement {
        subject pump : PulsometerPump;
        objective {
            doc "The two chambers shall operate in opposite phases: while one discharges, the other draws in water, ensuring nearly continuous output."
        }
    }

    requirement def CheckValveRequirement {
        subject pump : PulsometerPump;
        objective {
            doc "A set of check valves for each chamber shall ensure water flows only from the source, into the chambers, and out to the delivery tank."
        }
    }

    requirement def NoMovingPartsRequirement {
        subject pump : PulsometerPump;
        objective {
            doc "The pump shall operate without complex moving parts such as pistons or turbines, relying on direct steam force and vacuum."
        }
    }

    requirement def ContinuousFlowRequirement {
        subject system : PulsometerPumpingSystem;
        attribute minFlowRate : VolumeFlowRateValue = 0.02 [m3/s];
        objective {
            doc "The system shall provide a more consistent output with a nominal flow rate of at least 0.02 m3/s."
        }
        satisfy {
            system.designFlowRate >= minFlowRate;
        }
    }

    // ---- Requirement Satisfaction ----
    satisfaction satisfy PumpingRequirement by system;
    satisfaction satisfy AlternatingChamberRequirement by pump;
    satisfaction satisfy SteamAdmissionRequirement by pump.chamberA;
    satisfaction satisfy SteamAdmissionRequirement by pump.chamberB;
    satisfaction satisfy DischargeRequirement by pump.chamberA;
    satisfaction satisfy DischargeRequirement by pump.chamberB;
    satisfaction satisfy CondensationRequirement by pump.chamberA;
    satisfaction satisfy CondensationRequirement by pump.chamberB;
    satisfaction satisfy FillingRequirement by pump.chamberA;
    satisfaction satisfy FillingRequirement by pump.chamberB;
    satisfaction satisfy OppositePhaseRequirement by pump;
    satisfaction satisfy CheckValveRequirement by pump;
    satisfaction satisfy NoMovingPartsRequirement by pump;
    satisfaction satisfy ContinuousFlowRequirement by system;
}
