package VacuumPumpingSubsystem {

    package ValueTypes {
        value def PressureValue {
            unit 'Pa';
        }
        value def FlowRateValue {
            unit 'm^3/s';
        }
        value def TemperatureValue {
            unit 'K';
        }
        value def PowerValue {
            unit 'W';
        }
        value def VolumeValue {
            unit 'm^3';
        }
        value def TimeValue {
            unit 's';
        }
        value def DimensionlessValue {
        }
    }

    package Enums {
        enum def PumpMode {
            off;
            evacuating;
            maintaining;
        }
        enum def ValveState {
            closed;
            open;
        }
        enum def SystemState {
            idle;
            startup;
            evacuating;
            maintaining;
            shutdown;
            fault;
        }
    }

    package ItemTypes {
        item def Fluid;
        item def Gas :> Fluid;
        item def PressureReading {
            attribute measuredPressure : PressureValue;
        }
        item def FlowReading {
            attribute measuredFlow : FlowRateValue;
        }
        item def PumpCommand {
            attribute mode : PumpMode;
        }
        item def ValveCommand {
            attribute state : ValveState;
        }
    }

    package Ports {
        import ItemTypes::*;

        port def FluidPort {
            in item : Fluid;
            out item : Fluid;
        }
        port def PressureSignalPort {
            in item : PressureReading;
            out item : PressureReading;
        }
        port def FlowSignalPort {
            in item : FlowReading;
            out item : FlowReading;
        }
        port def PumpCommandPort {
            in item : PumpCommand;
            out item : PumpCommand;
        }
        port def ValveCommandPort {
            in item : ValveCommand;
            out item : ValveCommand;
        }
        port def VentPort {
            out item : Fluid;
        }
    }

    package Parts {
        import ValueTypes::*;
        import Enums::*;
        import ItemTypes::*;
        import Ports::*;

        part def SourceVessel {
            port fluidPort : FluidPort;
            attribute volume : VolumeValue = 0.5 [m^3];
            attribute initialPressure : PressureValue = 101325 [Pa];
            attribute currentPressure : PressureValue = 101325 [Pa];
            attribute temperature : TemperatureValue = 293.15 [K];
        }

        part def ReceivingVessel {
            port fluidPort : FluidPort;
            port ventPort : VentPort;
            attribute volume : VolumeValue = 1.0 [m^3];
            attribute maxSafePressure : PressureValue = 200000 [Pa];
            attribute currentPressure : PressureValue = 101325 [Pa];
            attribute temperature : TemperatureValue = 293.15 [K];
        }

        part def VacuumPump {
            port suctionPort : FluidPort;
            port dischargePort : FluidPort;
            port commandPort : PumpCommandPort;
            attribute maxPower : PowerValue = 1500 [W];
            attribute evacuatingPower : PowerValue = 1200 [W];
            attribute maintainingPower : PowerValue = 300 [W];
            attribute currentMode : PumpMode = PumpMode::off;
            attribute currentPower : PowerValue = 0 [W];
            attribute nominalFlowRate : FlowRateValue = 0.05 [m^3/s];

            state pumpStates {
                entry; then off;

                state off {
                    doc "Pump is deactivated with no power applied.";
                }
                state evacuating {
                    doc "Pump operates at high power to rapidly reduce suction-side pressure.";
                }
                state maintaining {
                    doc "Pump operates at reduced power to sustain target vacuum level.";
                }

                transition off_to_evacuating
                    first off
                    then evacuating
                    when { currentMode == PumpMode::evacuating };

                transition evacuating_to_maintaining
                    first evacuating
                    then maintaining
                    when { currentMode == PumpMode::maintaining };

                transition maintaining_to_evacuating
                    first maintaining
                    then evacuating
                    when { currentMode == PumpMode::evacuating };

                transition any_to_off
                    first {evacuating, maintaining}
                    then off
                    when { currentMode == PumpMode::off };
            }

            action evacuate {
                doc "Active high-power pumping action to rapidly lower source vessel pressure.";
            }

            action maintain {
                doc "Reduced-power pumping action to hold vacuum at the target setpoint.";
            }
        }

        part def IsolationValve {
            port inletPort : FluidPort;
            port outletPort : FluidPort;
            port commandPort : ValveCommandPort;
            attribute currentState : ValveState = ValveState::closed;
            attribute nominalDiameter : DimensionlessValue = 0.05;

            state valveStates {
                entry; then closed;

                state closed {
                    doc "Valve is sealed, preventing fluid flow and isolating sections.";
                }
                state open {
                    doc "Valve is open, permitting fluid flow through the line.";
                }

                transition closed_to_open
                    first closed
                    then open
                    when { currentState == ValveState::open };

                transition open_to_closed
                    first open
                    then closed
                    when { currentState == ValveState::closed };
            }
        }

        part def PressureTransducer {
            port fluidPort : FluidPort;
            port signalPort : PressureSignalPort;
            attribute measurementRange : PressureValue = 100000 [Pa];
            attribute accuracy : DimensionlessValue = 0.01;
            attribute measuredPressure : PressureValue = 101325 [Pa];
            attribute responseTime : TimeValue = 0.1 [s];
        }

        part def FlowTransducer {
            port fluidPort : FluidPort;
            port signalPort : FlowSignalPort;
            attribute measurementRange : FlowRateValue = 0.1 [m^3/s];
            attribute measuredFlow : FlowRateValue = 0 [m^3/s];
            attribute accuracy : DimensionlessValue = 0.02;
            attribute responseTime : TimeValue = 0.2 [s];
        }

        part def DischargePressureSensor {
            port fluidPort : FluidPort;
            port signalPort : PressureSignalPort;
            attribute measurementRange : PressureValue = 300000 [Pa];
            attribute measuredPressure : PressureValue = 101325 [Pa];
            attribute accuracy : DimensionlessValue = 0.01;
            attribute responseTime : TimeValue = 0.1 [s];
        }

        part def SafetyReliefValve {
            port inletPort : FluidPort;
            port ventPort : VentPort;
            attribute setPressure : PressureValue = 200000 [Pa];
            attribute inletPressure : PressureValue = 101325 [Pa];
            attribute currentState : ValveState = ValveState::closed;
            attribute resealPressure : PressureValue = 180000 [Pa];

            state reliefValveStates {
                entry; then closed;

                state closed {
                    doc "Relief valve is sealed under normal pressure conditions.";
                }
                state open {
                    doc "Relief valve is venting excess pressure to atmosphere.";
                }

                transition closed_to_open
                    first closed
                    then open
                    when { inletPressure > setPressure };

                transition open_to_closed
                    first open
                    then closed
                    when { inletPressure <= resealPressure };
            }

            constraint reliefPressureConstraint {
                inletPressure > setPressure implies currentState == ValveState::open
            }
        }

        part def VacuumController {
            port pressureInput : PressureSignalPort;
            port flowInput : FlowSignalPort;
            port dischargePressureInput : PressureSignalPort;
            port pumpOutput : PumpCommandPort;
            port suctionValveOutput : ValveCommandPort;
            port dischargeValveOutput : ValveCommandPort;

            attribute targetVacuum : PressureValue = 100 [Pa];
            attribute measuredPressure : PressureValue = 101325 [Pa];
            attribute measuredFlow : FlowRateValue = 0 [m^3/s];
            attribute dischargePressure : PressureValue = 101325 [Pa];
            attribute systemState : SystemState = SystemState::idle;

            attribute startSignal : Boolean = false;
            attribute stopSignal : Boolean = false;
            attribute faultDetected : Boolean = false;
            attribute faultReset : Boolean = false;
            attribute suctionValveOpen : Boolean = false;
            attribute dischargeValveOpen : Boolean = false;
            attribute pumpOff : Boolean = true;
            attribute suctionValveClosed : Boolean = true;
            attribute dischargeValveClosed : Boolean = true;

            attribute hysteresisUpper : DimensionlessValue = 1.1;
            attribute hysteresisLower : DimensionlessValue = 0.9;
            attribute maxEvacuationTime : TimeValue = 300 [s];

            state controllerStates {
                entry; then idle;

                state idle {
                    doc "System is powered but not actively pumping. All valves closed, pump off.";
                }
                state startup {
                    doc "Startup sequence in progress. Opening isolation valves and initializing pump.";
                }
                state evacuating {
                    doc "Pump running in high-power evacuating mode to rapidly reduce source pressure.";
                }
                state maintaining {
                    doc "Pump running in low-power maintaining mode to hold target vacuum.";
                }
                state shutdown {
                    doc "Shutdown sequence in progress. Closing valves and powering down pump.";
                }
                state fault {
                    doc "Fault condition detected. System halted pending manual reset.";
                }

                transition idle_to_startup
                    first idle
                    then startup
                    when { startSignal == true };

                transition startup_to_evacuating
                    first startup
                    then evacuating
                    when { suctionValveOpen == true && dischargeValveOpen == true };

                transition evacuating_to_maintaining
                    first evacuating
                    then maintaining
                    when { measuredPressure <= targetVacuum };

                transition maintaining_to_evacuating
                    first maintaining
                    then evacuating
                    when { measuredPressure > targetVacuum * hysteresisUpper };

                transition evacuating_or_maintaining_to_shutdown
                    first {evacuating, maintaining}
                    then shutdown
                    when { stopSignal == true };

                transition shutdown_to_idle
                    first shutdown
                    then idle
                    when { pumpOff == true && suctionValveClosed == true && dischargeValveClosed == true };

                transition any_to_fault
                    first {idle, startup, evacuating, maintaining, shutdown}
                    then fault
                    when { faultDetected == true };

                transition fault_to_idle
                    first fault
                    then idle
                    when { faultReset == true };
            }

            action controlLoop {
                in pressure : PressureReading;
                in flow : FlowReading;
                in dischargeP : PressureReading;
                out pumpCmd : PumpCommand;
                out suctionValveCmd : ValveCommand;
                out dischargeValveCmd : ValveCommand;

                doc "Continuously compares measured suction pressure to target vacuum setpoint and dispatches operating mode commands to the pump and valve state commands to isolation valves.";
            }

            action evaluateFaults {
                in pressure : PressureReading;
                in flow : FlowReading;
                in dischargeP : PressureReading;
                out faultFlag : Boolean;

                doc "Assesses sensor readings for out-of-range conditions, pump performance degradation, and discharge overpressure to set the fault flag.";
            }
        }
    }

    package Requirements {
        import ValueTypes::*;
        import Enums::*;

        requirement EvacuationRequirement {
            doc "The system shall evacuate the source vessel from atmospheric pressure to the target vacuum level of 100 Pa within 300 seconds.";
            subject : VacuumPumpingSystem;
            objective {
                targetVacuum <= 100 [Pa] and evacuationTime <= 300 [s]
            }
        }

        requirement PressureControlRequirement {
            doc "The controller shall maintain the source vessel pressure within 10 percent of the target vacuum level during the maintaining state.";
            subject : VacuumController;
            objective {
                measuredPressure <= targetVacuum * 1.1 and measuredPressure >= targetVacuum * 0.9
            }
        }

        requirement SafetyReliefRequirement {
            doc "The safety relief valve shall automatically open when the receiving vessel pressure exceeds 200000 Pa to vent excess pressure and prevent system damage.";
            subject : SafetyReliefValve;
            objective {
                inletPressure > 200000 [Pa] implies currentState == ValveState::open
            }
        }

        requirement IsolationRequirement {
            doc "Both isolation valves shall be closed during idle, startup, and shutdown states to prevent uncontrolled fluid migration.";
            subject : IsolationValve;
            objective {
                systemState == SystemState::idle or systemState == SystemState::startup or systemState == SystemState::shutdown
                implies currentState == ValveState::closed
            }
        }

        requirement MonitoringRequirement {
            doc "The system shall continuously monitor suction pressure, discharge pressure, and flow rate to assess pump performance and overall system health.";
            subject : VacuumPumpingSystem;
            objective {
                pressureTransducer.measuredPressure >= 0 [Pa]
                and dischargePressureSensor.measuredPressure >= 0 [Pa]
                and flowTransducer.measuredFlow >= 0 [m^3/s]
            }
        }

        requirement FaultHandlingRequirement {
            doc "The controller shall transition to the fault state upon detection of any abnormal condition and remain in fault until a manual reset is issued.";
            subject : VacuumController;
            objective {
                faultDetected == true implies systemState == SystemState::fault
                and faultReset == false implies systemState == SystemState::fault
            }
        }

        requirement PumpModeRequirement {
            doc "The vacuum pump shall operate in evacuating mode at high power when measured pressure exceeds the target and switch to maintaining mode when the target is reached.";
            subject : VacuumPump;
            objective {
                measuredPressure > targetVacuum implies currentMode == PumpMode::evacuating
                and measuredPressure <= targetVacuum implies currentMode == PumpMode::maintaining
            }
        }
    }

    package System {
        import Parts::*;
        import Requirements::*;

        part VacuumPumpingSystem {
            part sourceVessel : SourceVessel;
            part receivingVessel : ReceivingVessel;
            part vacuumPump : VacuumPump;
            part suctionValve : IsolationValve;
            part dischargeValve : IsolationValve;
            part pressureTransducer : PressureTransducer;
            part flowTransducer : FlowTransducer;
            part dischargePressureSensor : DischargePressureSensor;
            part safetyReliefValve : SafetyReliefValve;
            part controller : VacuumController;

            attribute targetVacuum : PressureValue = 100 [Pa];
            attribute evacuationTime : TimeValue = 0 [s];

            connection sourceToSuctionValve
                connect sourceVessel.fluidPort to suctionValve.inletPort;
            connection suctionValveToPump
                connect suctionValve.outletPort to vacuumPump.suctionPort;
            connection pumpToDischargeValve
                connect vacuumPump.dischargePort to dischargeValve.inletPort;
            connection dischargeValveToReceiving
                connect dischargeValve.outletPort to receivingVessel.fluidPort;
            connection suctionPressureTap
                connect vacuumPump.suctionPort to pressureTransducer.fluidPort;
            connection flowTap
                connect vacuumPump.dischargePort to flowTransducer.fluidPort;
            connection dischargePressureTap
                connect dischargeValve.outletPort to dischargePressureSensor.fluidPort;
            connection reliefValveConnection
                connect receivingVessel.fluidPort to safetyReliefValve.inletPort;

            connection pressureToController
                connect pressureTransducer.signalPort to controller.pressureInput;
            connection flowToController
                connect flowTransducer.signalPort to controller.flowInput;
            connection dischargePressureToController
                connect dischargePressureSensor.signalPort to controller.dischargePressureInput;
            connection controllerToPump
                connect controller.pumpOutput to vacuumPump.commandPort;
            connection controllerToSuctionValve
                connect controller.suctionValveOutput to suctionValve.commandPort;
            connection controllerToDischargeValve
                connect controller.dischargeValveOutput to dischargeValve.commandPort;

            satisfy EvacuationRequirement;
            satisfy MonitoringRequirement;
        }

        satisfy PressureControlRequirement by controller;
        satisfy FaultHandlingRequirement by controller;
        satisfy SafetyReliefRequirement by safetyReliefValve;
        satisfy IsolationRequirement by suctionValve;
        satisfy IsolationRequirement by dischargeValve;
        satisfy PumpModeRequirement by vacuumPump;
    }
}
