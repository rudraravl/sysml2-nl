package LiquidLevelControlSystem {

    import ISQ::*;
    import ScalarValues::*;

    // ---------- Value Types ----------
    value def Length :> Real { unit 'm'; }
    value def Volume :> Real { unit 'm3'; }
    value def VolumeFlowRate :> Real { unit 'm3/s'; }
    value def LiquidLevel :> Length;
    value def Pressure :> Real { unit 'Pa'; }
    value def Voltage :> Real { unit 'V'; }
    value def Current :> Real { unit 'A'; }
    value def Power :> Real { unit 'W'; }
    value def TimeValue :> Real { unit 's'; }

    // ---------- Enumerations ----------
    enum def SwitchState { closed; open; }
    enum def PumpOperationalState { on; off; faulted; }
    enum def FloatPosition { low; mid; high; }

    // ---------- Item Types ----------
    item def Liquid {
        attribute density : Real = 1000 [kg/m3];
    }

    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def ControlSignal :> ElectricalSignal {
        attribute switchState : SwitchState;
    }

    // ---------- Interfaces ----------
    interface def LiquidFlow {
        end inflow : Liquid;
        end outflow : Liquid;
    }

    interface def ElectricalConnection {
        end positive : ElectricalSignal;
        end negative : ElectricalSignal;
    }

    interface def ControlCircuit :> ElectricalConnection {
        end positive : ControlSignal;
        end negative : ControlSignal;
    }

    // ---------- Port Definitions ----------
    port def LiquidInPort {
        in item liquidIn : Liquid;
        attribute flowRate : VolumeFlowRate;
    }

    port def LiquidOutPort {
        out item liquidOut : Liquid;
        attribute flowRate : VolumeFlowRate;
    }

    port def PowerPort {
        in item powerIn : ElectricalSignal;
    }

    port def ControlPort {
        out item controlOut : ControlSignal;
    }

    // ---------- Tank ----------
    part def Tank {
        attribute capacity : Volume = 1.0 [m3];
        attribute activationLevel : LiquidLevel = 0.80 [m];
        attribute deactivationLevel : LiquidLevel = 0.20 [m];
        attribute currentLevel : LiquidLevel = 0.0 [m];
        attribute crossSectionalArea : Real = 1.0 [m2];

        port liquidInlet : LiquidInPort;
        port liquidOutlet : LiquidOutPort;

        item storedLiquid : Liquid;

        action def updateLevel {
            in inflowRate : VolumeFlowRate;
            in outflowRate : VolumeFlowRate;
            in dt : TimeValue;
            out newLevel : LiquidLevel;
        }

        compute levelUpdate {
            in inflowRate : VolumeFlowRate;
            in outflowRate : VolumeFlowRate;
            out level : LiquidLevel;
            // level = currentLevel + (inflowRate - outflowRate) * dt / crossSectionalArea
        }
    }

    // ---------- Float Switch ----------
    part def FloatSwitch {
        attribute activationLevel : LiquidLevel = 0.80 [m];
        attribute deactivationLevel : LiquidLevel = 0.20 [m];
        attribute hysteresis : LiquidLevel = 0.60 [m];
        attribute currentSwitchState : SwitchState = SwitchState::open;
        attribute floatPosition : FloatPosition = FloatPosition::low;

        port liquidLevelInput {
            in level : LiquidLevel;
        }

        port controlOutput : ControlPort;

        state def FloatSwitchBehavior {
            entry; then Monitoring;

            state Monitoring {
                // continuously reads liquid level
            }

            transition monitoring_to_closed
                first Monitoring
                accept when (liquidLevelInput.level >= activationLevel)
                then SwitchClosed;

            state SwitchClosed {
                entry action setClosed {
                    currentSwitchState = SwitchState::closed;
                    controlOutput.controlOut.switchState = SwitchState::closed;
                    controlOutput.controlOut.voltage = 12.0 [V];
                    controlOutput.controlOut.current = 0.5 [A];
                }
            }

            transition closed_to_monitoring
                first SwitchClosed
                accept when (liquidLevelInput.level <= deactivationLevel)
                then SwitchOpen;

            state SwitchOpen {
                entry action setOpen {
                    currentSwitchState = SwitchState::open;
                    controlOutput.controlOut.switchState = SwitchState::open;
                    controlOutput.controlOut.voltage = 0.0 [V];
                    controlOutput.controlOut.current = 0.0 [A];
                }
                then Monitoring;
            }
        }

        exhibit FloatSwitchBehavior;
    }

    // ---------- Pump ----------
    part def Pump {
        attribute nominalFlowRate : VolumeFlowRate = 0.01 [m3/s];
        attribute powerRating : Power = 500.0 [W];
        attribute operatingState : PumpOperationalState = PumpOperationalState::off;
        attribute totalRunTime : TimeValue = 0.0 [s];
        attribute cycleCount : Integer = 0;

        port powerInput : PowerPort;
        port liquidIntake : LiquidInPort;
        port liquidDischarge : LiquidOutPort;

        state def PumpOperation {
            entry; then Idle;

            state Idle {
                entry action setOff {
                    operatingState = PumpOperationalState::off;
                    liquidIntake.flowRate = 0.0 [m3/s];
                    liquidDischarge.flowRate = 0.0 [m3/s];
                }
            }

            transition idle_to_running
                first Idle
                accept when (powerInput.powerIn.voltage > 0.0 [V])
                then Running;

            state Running {
                entry action setOn {
                    operatingState = PumpOperationalState::on;
                    liquidIntake.flowRate = nominalFlowRate;
                    liquidDischarge.flowRate = nominalFlowRate;
                    cycleCount = cycleCount + 1;
                }
            }

            transition running_to_idle
                first Running
                accept when (powerInput.powerIn.voltage == 0.0 [V])
                then Idle;

            transition running_to_faulted
                first Running
                accept FaultCondition
                then Faulted;

            state Faulted {
                entry action setFault {
                    operatingState = PumpOperationalState::faulted;
                    liquidIntake.flowRate = 0.0 [m3/s];
                    liquidDischarge.flowRate = 0.0 [m3/s];
                }
            }
        }

        exhibit PumpOperation;
    }

    occurrence def FaultCondition;

    // ---------- Liquid Source ----------
    part def LiquidSource {
        attribute inflowRate : VolumeFlowRate = 0.002 [m3/s];
        attribute sourcePressure : Pressure = 101325.0 [Pa];
        attribute isSupplying : Boolean = true;

        port liquidSupply : LiquidOutPort;

        action def supplyLiquid {
            out suppliedLiquid : Liquid;
            out rate : VolumeFlowRate;
        }

        perform supplyLiquid {
            suppliedLiquid = Liquid{};
            rate = inflowRate;
        }
    }

    // ---------- System Assembly ----------
    part def LiquidLevelControlSystem {
        attribute systemActivationLevel : LiquidLevel = 0.80 [m];
        attribute systemDeactivationLevel : LiquidLevel = 0.20 [m];
        attribute systemHysteresis : LiquidLevel = 0.60 [m];

        part tank : Tank {
            attribute activationLevel = systemActivationLevel;
            attribute deactivationLevel = systemDeactivationLevel;
        }

        part floatSwitch : FloatSwitch {
            attribute activationLevel = systemActivationLevel;
            attribute deactivationLevel = systemDeactivationLevel;
            attribute hysteresis = systemHysteresis;
        }

        part pump : Pump;

        part liquidSource : LiquidSource;

        // Connections
        connection liquidSource_to_tank : LiquidFlow
            connect liquidSource.liquidSupply to tank.liquidInlet;

        connection tank_to_pump : LiquidFlow
            connect tank.liquidOutlet to pump.liquidIntake;

        connection pump_discharge : LiquidFlow
            connect pump.liquidDischarge to nothing;

        // Level monitoring connection (tank level to float switch)
        flow levelFlow : LiquidLevel
            from tank.currentLevel to floatSwitch.liquidLevelInput.level;

        // Control circuit connection (float switch to pump)
        connection controlCircuit : ControlCircuit
            connect floatSwitch.controlOutput to pump.powerInput;

        // System-level state machine
        state def SystemOperation {
            entry; then IdleState;

            state IdleState {
                // System idle, liquid level below activation
            }

            transition idle_to_active
                first IdleState
                accept when (tank.currentLevel >= systemActivationLevel)
                then PumpingState;

            state PumpingState {
                // Pump actively removing liquid
            }

            transition pumping_to_idle
                first PumpingState
                accept when (tank.currentLevel <= systemDeactivationLevel)
                then IdleState;
        }

        exhibit SystemOperation;
    }

    // ---------- Requirements ----------
    requirement def OverflowPrevention {
        doc /* The system shall prevent the tank from overflowing by activating the pump when the liquid level reaches the activation level. */
        subject : LiquidLevelControlSystem;
        objective {
            tank.currentLevel < tank.capacity
        }
    }

    requirement def AutomaticPumpActivation {
        doc /* The float switch shall close when the liquid level reaches or exceeds the activation level, causing the pump to turn on. */
        subject : FloatSwitch;
        attribute activationThreshold : LiquidLevel = 0.80 [m];
        objective {
            floatSwitch.currentSwitchState == SwitchState::closed
            when tank.currentLevel >= activationThreshold
        }
    }

    requirement def AutomaticPumpDeactivation {
        doc /* The float switch shall open when the liquid level drops to or below the deactivation level, causing the pump to turn off. */
        subject : FloatSwitch;
        attribute deactivationThreshold : LiquidLevel = 0.20 [m];
        objective {
            floatSwitch.currentSwitchState == SwitchState::open
            when tank.currentLevel <= deactivationThreshold
        }
    }

    requirement def HysteresisRequirement {
        doc /* The system shall maintain a hysteresis gap between activation and deactivation levels to prevent rapid pump cycling. */
        subject : LiquidLevelControlSystem;
        attribute minimumHysteresis : LiquidLevel = 0.50 [m];
        objective {
            (systemActivationLevel - systemDeactivationLevel) >= minimumHysteresis
        }
    }

    requirement def PumpFlowRateRequirement {
        doc /* The pump shall have a nominal flow rate greater than the maximum source inflow rate to ensure the tank level decreases during pumping. */
        subject : Pump;
        objective {
            pump.nominalFlowRate > liquidSource.inflowRate
        }
    }

    requirement def SystemResponseTime {
        doc /* The system shall respond to a high-level condition by activating the pump within 2 seconds of the activation level being reached. */
        subject : LiquidLevelControlSystem;
        attribute maxResponseTime : TimeValue = 2.0 [s];
        objective {
            // Response time from level reaching activation to pump on
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction satisfyOverflowPrevention : OverflowPrevention {
        subject = LiquidLevelControlSystem;
    }

    satisfaction satisfyAutoActivation : AutomaticPumpActivation {
        subject = floatSwitch;
    }

    satisfaction satisfyAutoDeactivation : AutomaticPumpDeactivation {
        subject = floatSwitch;
    }

    satisfaction satisfyHysteresis : HysteresisRequirement {
        subject = LiquidLevelControlSystem;
    }

    satisfaction satisfyPumpFlow : PumpFlowRateRequirement {
        subject = pump;
    }

}
