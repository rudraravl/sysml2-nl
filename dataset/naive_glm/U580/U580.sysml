package WellPumpingSystem {

    import ScalarValues::*;

    // ============================================================
    //  Item Definitions
    // ============================================================

    item def Water;

    item def ElectricalPower;

    item def ControlSignal;

    item def StartCommand :> ControlSignal {
        doc "Signal commanding the pump to start.";
    }

    item def StopCommand :> ControlSignal {
        doc "Signal commanding the pump to stop.";
    }

    item def ResetCommand :> ControlSignal {
        doc "Signal commanding the pump to reset from fault.";
    }

    item def ManualStartCommand :> StartCommand {
        doc "Manual override start command.";
    }

    item def ManualStopCommand :> StopCommand {
        doc "Manual override stop command.";
    }

    item def StatusReport :> ControlSignal {
        attribute pumpState : PumpState;
        attribute flowRate : FlowRate;
        attribute totalVolume : Volume;
    }

    item def FlowReading :> ControlSignal {
        attribute instantaneousFlow : FlowRate;
        attribute cumulativeVolume : Volume;
    }

    // ============================================================
    //  Value Types
    // ============================================================

    attribute def Pressure :> Real {
        attribute unit : String = "Pa";
    }

    attribute def FlowRate :> Real {
        attribute unit : String = "m3/s";
    }

    attribute def Volume :> Real {
        attribute unit : String = "m3";
    }

    attribute def ElectricCurrent :> Real {
        attribute unit : String = "A";
    }

    attribute def Voltage :> Real {
        attribute unit : String = "V";
    }

    attribute def Length :> Real {
        attribute unit : String = "m";
    }

    attribute def Duration :> Real {
        attribute unit : String = "s";
    }

    // ============================================================
    //  Enumerations
    // ============================================================

    enum def PumpState {
        idle;
        priming;
        running;
        fault;
    }

    enum def FlowDirection {
        none;
        forward;
        reverse;
    }

    enum def ValveState {
        open;
        closed;
    }

    enum def SwitchState {
        open;
        closed;
    }

    // ============================================================
    //  Port Definitions
    // ============================================================

    port def FluidPort {
        out item waterOut : Water;
        in item waterIn : Water;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def PowerPort {
        in item power : ElectricalPower;
        attribute voltage : Voltage;
        attribute current : ElectricCurrent;
    }

    port def ControlPort {
        in item command : ControlSignal;
        out item status : ControlSignal;
    }

    // ============================================================
    //  Requirements
    // ============================================================

    requirement def PumpingRequirement {
        doc "Base requirement for the automated well pumping system.";
        subject pumpSystem : WellPumpingSystem;
    }

    requirement def PumpActivationRequirement :> PumpingRequirement {
        doc "The pump shall activate when tank pressure drops below the cut-in pressure.";
        attribute cutInPressure : Pressure = 137895;
        require {
            pumpSystem.pressureTank.pressure < cutInPressure
            implies pumpSystem.wellPump.pumpState == PumpState::running
        }
    }

    requirement def PumpDeactivationRequirement :> PumpingRequirement {
        doc "The pump shall deactivate when tank pressure reaches the cut-out pressure.";
        attribute cutOutPressure : Pressure = 275790;
        require {
            pumpSystem.pressureTank.pressure >= cutOutPressure
            implies pumpSystem.wellPump.pumpState == PumpState::idle
        }
    }

    requirement def BackflowPreventionRequirement :> PumpingRequirement {
        doc "Check valves shall prevent water from flowing back into the well when the pump is off.";
        require {
            pumpSystem.wellPump.pumpState != PumpState::running
            implies pumpSystem.checkValveSuction.flowDirection == FlowDirection::none
        }
    }

    requirement def FaultProtectionRequirement :> PumpingRequirement {
        doc "The pump shall enter a fault state when motor current exceeds the maximum rated current.";
        attribute maxRatedCurrent : ElectricCurrent = 15.0;
        require {
            pumpSystem.wellPump.motorCurrent > maxRatedCurrent
            implies pumpSystem.wellPump.pumpState == PumpState::fault
        }
    }

    requirement def PressureReserveRequirement :> PumpingRequirement {
        doc "The pressure tank shall maintain a reserve of pressurized water to reduce pump cycling.";
        attribute minimumReserveVolume : Volume = 0.05;
        require {
            pumpSystem.pressureTank.waterVolume >= minimumReserveVolume
        }
    }

    requirement def FlowMeasurementRequirement :> PumpingRequirement {
        doc "The system shall measure and report the instantaneous flow rate and cumulative volume of water pumped.";
        require {
            pumpSystem.flowMeter.totalVolume >= 0.0
        }
    }

    requirement def ManualOverrideRequirement :> PumpingRequirement {
        doc "The control panel shall provide a manual override for direct pump control.";
        require {
            pumpSystem.controlPanel.manualOverrideEnabled == true
            implies pumpSystem.wellPump.pumpState != PumpState::fault
        }
    }

    // ============================================================
    //  Part Definitions
    // ============================================================

    part def WellCasing {
        doc "Underground cylindrical casing that contains the water source and houses the submersible pump.";
        attribute depth : Length = 60.0;
        attribute diameter : Length = 0.15;
        attribute staticWaterLevel : Length = 30.0;
        attribute availableReserve : Volume = 2.5;
        port wellWaterPort : FluidPort {
            attribute pressure : Pressure = 101325;
            attribute flowRate : FlowRate = 0.0;
        }
    }

    part def CheckValve {
        doc "One-way valve permitting flow only in the forward direction.";
        attribute valveState : ValveState = ValveState::closed;
        attribute flowDirection : FlowDirection = FlowDirection::none;
        attribute crackingPressure : Pressure = 6894.76;
        port inlet : FluidPort;
        port outlet : FluidPort;

        action def RegulateFlow {
            in pressureIn : Pressure;
            in pressureOut : Pressure;
            out resultingValveState : ValveState;
            out resultingFlowDirection : FlowDirection;
            if pressureIn > pressureOut + crackingPressure {
                resultingValveState = ValveState::open;
                resultingFlowDirection = FlowDirection::forward;
            } else {
                resultingValveState = ValveState::closed;
                resultingFlowDirection = FlowDirection::none;
            }
        }
    }

    part def WellPump {
        doc "Submersible pump that draws water from the well casing and pushes it to the surface through the discharge line.";

        attribute ratedVoltage : Voltage = 230.0;
        attribute ratedCurrent : ElectricCurrent = 10.0;
        attribute motorCurrent : ElectricCurrent = 0.0;
        attribute flowCapacity : FlowRate = 0.000631;
        attribute maxSafeCurrent : ElectricCurrent = 15.0;
        attribute primingDuration : Duration = 5.0;
        attribute pumpState : PumpState = PumpState::idle;

        port powerInput : PowerPort;
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port controlPort : ControlPort;

        state behavior PumpController {
            entry; then Idle;

            state Idle {
                doc "Pump is off and waiting for a start command.";
                entry {
                    motorCurrent = 0.0;
                }
            }

            state Priming {
                doc "Pump is priming before full operation.";
                entry {
                    motorCurrent = ratedCurrent * 0.5;
                }
            }

            state Running {
                doc "Pump is actively pumping water to the surface.";
                entry {
                    motorCurrent = ratedCurrent;
                }
            }

            state Fault {
                doc "Pump has entered a protective fault state and awaits manual reset.";
                entry {
                    motorCurrent = 0.0;
                }
            }

            transition Idle_to_Priming
                first Idle
                accept StartCommand
                then Priming;

            transition Priming_to_Running
                first Priming
                after 5.0
                then Running;

            transition Running_to_Idle
                first Running
                accept StopCommand
                then Idle;

            transition Running_to_Fault_Overcurrent
                first Running
                when motorCurrent > maxSafeCurrent
                then Fault;

            transition Priming_to_Fault_Overcurrent
                first Priming
                when motorCurrent > maxSafeCurrent
                then Fault;

            transition Fault_to_Idle_Reset
                first Fault
                accept ResetCommand
                then Idle;
        }

        action def PumpWater {
            doc "Pumps water from the suction port to the discharge port when the pump is running.";
            in incomingWater : Water;
            out outgoingWater : Water;
            out outputFlow : FlowRate;
            if pumpState == PumpState::running {
                outputFlow = flowCapacity;
            } else {
                outputFlow = 0.0;
            }
        }
    }

    part def PressureTank {
        doc "Bladder-style pressure tank storing a reserve of water under compressed air pressure.";
        attribute totalCapacity : Volume = 0.208;
        attribute prechargePressure : Pressure = 137895;
        attribute pressure : Pressure = 137895;
        attribute waterVolume : Volume = 0.0;
        attribute airVolume : Volume = 0.208;
        attribute maxPressure : Pressure = 413685;

        port inlet : FluidPort;
        port outlet : FluidPort;

        action def RegulatePressure {
            doc "Updates tank pressure and stored water volume based on inflow and outflow over a time step.";
            in inflow : FlowRate;
            in outflow : FlowRate;
            in timeStep : Duration;
            out updatedPressure : Pressure;
            out updatedWaterVolume : Volume;
            attribute deltaVolume : Volume;
            deltaVolume = (inflow - outflow) * timeStep;
            updatedWaterVolume = waterVolume + deltaVolume;
            if updatedWaterVolume > 0.0 and updatedWaterVolume < totalCapacity {
                updatedPressure = prechargePressure * totalCapacity / (totalCapacity - updatedWaterVolume);
            } else if updatedWaterVolume >= totalCapacity {
                updatedPressure = maxPressure;
                updatedWaterVolume = totalCapacity;
            } else {
                updatedPressure = prechargePressure;
                updatedWaterVolume = 0.0;
            }
        }
    }

    part def PressureSwitch {
        doc "Electromechanical switch that monitors tank pressure and signals the control panel at cut-in and cut-out thresholds.";
        attribute cutInPressure : Pressure = 137895;
        attribute cutOutPressure : Pressure = 275790;
        attribute switchState : SwitchState = SwitchState::open;
        attribute monitoredPressure : Pressure = 137895;

        port fluidSensePort : FluidPort;
        port controlPort : ControlPort;

        action def MonitorPressure {
            doc "Evaluates tank pressure and emits start or stop commands accordingly.";
            in sensedPressure : Pressure;
            out emittedCommand : ControlSignal;
            if sensedPressure < cutInPressure {
                switchState = SwitchState::closed;
            } else if sensedPressure >= cutOutPressure {
                switchState = SwitchState::open;
            }
        }
    }

    part def ControlPanel {
        doc "Automated controller that processes pressure switch signals and manual override commands to control the pump.";
        attribute manualOverrideEnabled : Boolean = false;
        attribute manualCommand : ControlSignal;
        attribute supplyVoltage : Voltage = 230.0;

        port switchInput : ControlPort;
        port pumpOutput : ControlPort;
        port flowMeterInput : ControlPort;
        port powerInput : PowerPort;

        action def ProcessControl {
            doc "Determines the command to send to the pump based on automatic or manual mode.";
            in switchSignal : ControlSignal;
            in manualCmd : ControlSignal;
            out pumpCommand : ControlSignal;
            if manualOverrideEnabled {
                pumpCommand = manualCmd;
            } else {
                pumpCommand = switchSignal;
            }
        }

        action def DistributePower {
            doc "Routes incoming electrical power to the pump through the control circuit.";
            in incomingPower : ElectricalPower;
            out pumpPower : ElectricalPower;
            attribute outputVoltage : Voltage = supplyVoltage;
        }
    }

    part def FlowMeter {
        doc "Measures the instantaneous flow rate and cumulative volume of water delivered to the user.";
        attribute flowRate : FlowRate = 0.0;
        attribute totalVolume : Volume = 0.0;

        port fluidPort : FluidPort;
        port dataPort : ControlPort;

        action def MeasureFlow {
            doc "Computes flow rate and accumulates total volume over a time step.";
            in sensedFlow : FlowRate;
            in timeStep : Duration;
            out reportedFlow : FlowRate;
            out reportedTotal : Volume;
            reportedFlow = sensedFlow;
            reportedTotal = totalVolume + sensedFlow * timeStep;
        }
    }

    part def UserEndpoint {
        doc "Represents the user demand point such as a household tap or irrigation valve.";
        attribute demandFlow : FlowRate = 0.0;
        attribute isDemandActive : Boolean = false;

        port waterPort : FluidPort;

        action def UseWater {
            doc "Draws water from the system based on user demand and available pressure.";
            in availablePressure : Pressure;
            out requestedFlow : FlowRate;
            if isDemandActive and availablePressure > 0.0 {
                requestedFlow = demandFlow;
            } else {
                requestedFlow = 0.0;
            }
        }
    }

    // ============================================================
    //  System Assembly
    // ============================================================

    part def WellPumpingSystem {
        doc "Automated water well pumping system that extracts groundwater and delivers pressurized water on demand to a user.";

        attribute systemPressure : Pressure = 137895;
        attribute systemFlow : FlowRate = 0.0;
        attribute operational : Boolean = true;

        port userPort : FluidPort;
        port powerPort : PowerPort;

        part wellCasing : WellCasing;
        part checkValveSuction : CheckValve;
        part wellPump : WellPump;
        part checkValveDischarge : CheckValve;
        part pressureTank : PressureTank;
        part pressureSwitch : PressureSwitch;
        part controlPanel : ControlPanel;
        part flowMeter : FlowMeter;
        part userEndpoint : UserEndpoint;

        // Requirement usages
        requirement pumpActivation : PumpActivationRequirement;
        requirement pumpDeactivation : PumpDeactivationRequirement;
        requirement backflowPrevention : BackflowPreventionRequirement;
        requirement faultProtection : FaultProtectionRequirement;
        requirement pressureReserve : PressureReserveRequirement;
        requirement flowMeasurement : FlowMeasurementRequirement;
        requirement manualOverride : ManualOverrideRequirement;

        // Fluid path: well casing -> suction check valve -> pump -> discharge check valve -> pressure tank -> flow meter -> user
        connect wellCasing.wellWaterPort to checkValveSuction.inlet;
        connect checkValveSuction.outlet to wellPump.suctionPort;
        connect wellPump.dischargePort to checkValveDischarge.inlet;
        connect checkValveDischarge.outlet to pressureTank.inlet;
        connect pressureTank.outlet to flowMeter.fluidPort;
        connect flowMeter.fluidPort to userEndpoint.waterPort;
        connect userEndpoint.waterPort to userPort;

        // Pressure sensing: pressure switch monitors tank pressure
        connect pressureTank.outlet to pressureSwitch.fluidSensePort;

        // Control signal path: pressure switch -> control panel -> pump
        connect pressureSwitch.controlPort to controlPanel.switchInput;
        connect controlPanel.pumpOutput to wellPump.controlPort;

        // Flow meter data reporting to control panel
        connect flowMeter.dataPort to controlPanel.flowMeterInput;

        // Power distribution: external power -> control panel -> pump
        connect powerPort to controlPanel.powerInput;
        connect controlPanel.powerInput to wellPump.powerInput;

        // Requirement satisfaction
        satisfy pumpActivation by wellPump;
        satisfy pumpDeactivation by wellPump;
        satisfy backflowPrevention by checkValveSuction;
        satisfy faultProtection by wellPump;
        satisfy pressureReserve by pressureTank;
        satisfy flowMeasurement by flowMeter;
        satisfy manualOverride by controlPanel;
    }
}
