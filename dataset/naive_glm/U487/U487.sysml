package DiversPumpSystem {

    import SI::*;

    // ──────────────── Type Definitions ────────────────

    package Types {
        item def Fluid {
            attribute density : Real [kg/m3] = 1000;
            attribute viscosity : Real [Pa*s] = 0.001;
            attribute temperature : Real [K] = 293.15;
        }

        enumeration def PumpCommandKind {
            literal start;
            literal stop;
            literal reset;
            literal emergencyStop;
        }

        enumeration def PumpStatusKind {
            literal idle;
            literal priming;
            literal pumping;
            literal stopping;
            literal fault;
        }

        enumeration def FaultType {
            literal highInletPressure;
            literal highOutletPressure;
            literal lowInletPressure;
            literal lowFlowRate;
            literal primingFailure;
            literal driveFault;
            literal none;
        }

        enumeration def StrokeDirection {
            literal intake;
            literal discharge;
        }

        record def SensorReading {
            attribute value : Real;
            attribute unit : String;
            attribute timestamp : Real [s];
            attribute valid : Boolean = true;
        }
    }

    // ──────────────── Port Definitions ────────────────

    package Ports {
        port def FluidPort {
            in item fluid : Types::Fluid;
            attribute pressure : Real [Pa];
        }

        port def ElectricalPort {
            attribute voltage : Real [V];
            attribute current : Real [A];
        }

        port def CommandPort {
            in attribute command : Types::PumpCommandKind;
            out attribute status : Types::PumpStatusKind;
        }

        port def SensorDataPort {
            out attribute reading : Types::SensorReading;
        }
    }

    // ──────────────── Pump Components ────────────────

    package Components {
        part def CylinderChamber {
            attribute maxVolume : Real [m3] = 0.002;
            attribute currentVolume : Real [m3];
            attribute currentPressure : Real [Pa];
            attribute temperature : Real [K];
            port fluidIn : Ports::FluidPort;
            port fluidOut : Ports::FluidPort;

            action def Fill {
                doc /* Fill the cylinder with fluid from the inlet side */;
            }
            action def Empty {
                doc /* Push fluid out through the outlet side */;
            }
        }

        part def PistonAssembly {
            attribute strokeLength : Real [m] = 0.05;
            attribute boreDiameter : Real [m] = 0.08;
            attribute currentDisplacement : Real [m];
            attribute strokeCount : Integer = 0;
            attribute direction : Types::StrokeDirection = Types::StrokeDirection::intake;
            attribute strokeArea : Real [m2] = 3.1416 * (boreDiameter / 2) ^ 2;
            attribute sweptVolume : Real [m3] = strokeArea * strokeLength;
        }

        part def DriveMechanism {
            attribute ratedPower : Real [W] = 500;
            attribute maxTorque : Real [N*m] = 50;
            attribute currentSpeed : Real [1/s];
            attribute isRunning : Boolean = false;
            port electrical : Ports::ElectricalPort;
            port control : Ports::CommandPort;

            action def StartMotor {
                doc /* Energize the motor to begin driving the piston */;
            }
            action def StopMotor {
                doc /* De-energize the motor to halt piston motion */;
            }
            action def SetSpeed {
                in targetSpeed : Real [1/s];
            }
        }

        part def InletValve {
            attribute openingPressureThreshold : Real [Pa] = 5000;
            attribute closingPressureThreshold : Real [Pa] = 3000;
            attribute isOpen : Boolean = false;
            attribute crackPressure : Real [Pa];
            port fluidIn : Ports::FluidPort;
            port fluidOut : Ports::FluidPort;

            action def Open {
                doc /* Open the inlet valve when inlet pressure exceeds threshold */;
            }
            action def Close {
                doc /* Close the inlet valve to prevent backflow */;
            }
        }

        part def OutletValve {
            attribute openingPressureThreshold : Real [Pa] = 15000;
            attribute closingPressureThreshold : Real [Pa] = 10000;
            attribute isOpen : Boolean = false;
            attribute crackPressure : Real [Pa];
            port fluidIn : Ports::FluidPort;
            port fluidOut : Ports::FluidPort;

            action def Open {
                doc /* Open the outlet valve when cylinder pressure exceeds threshold */;
            }
            action def Close {
                doc /* Close the outlet valve to prevent backflow from destination */;
            }
        }
    }

    // ──────────────── Sensors ────────────────

    package Sensors {
        part def PressureSensor {
            attribute maxRange : Real [Pa] = 200000;
            attribute minRange : Real [Pa] = 0;
            attribute accuracy : Real [Pa] = 100;
            attribute samplingRate : Real [1/s] = 10;
            attribute currentReading : Real [Pa];
            port fluidPort : Ports::FluidPort;
            port dataOut : Ports::SensorDataPort;

            action def Read {
                out reading : Real [Pa];
                doc /* Sample the fluid pressure at the current port */;
            }
            action def Calibrate;
        }

        part def FlowSensor {
            attribute maxRange : Real [m3/s] = 0.01;
            attribute minRange : Real [m3/s] = 0;
            attribute accuracy : Real [m3/s] = 0.0001;
            attribute samplingRate : Real [1/s] = 10;
            attribute currentReading : Real [m3/s];
            port fluidPort : Ports::FluidPort;
            port dataOut : Ports::SensorDataPort;

            action def Read {
                out reading : Real [m3/s];
                doc /* Sample the volumetric flow rate at the current port */;
            }
            action def Calibrate;
        }
    }

    // ──────────────── Diver's Pump ────────────────

    part def DiversPump {
        part cylinder : Components::CylinderChamber;
        part piston : Components::PistonAssembly;
        part drive : Components::DriveMechanism;
        part inletValve : Components::InletValve;
        part outletValve : Components::OutletValve;

        port source : Ports::FluidPort;
        port destination : Ports::FluidPort;
        port control : Ports::CommandPort;

        attribute nominalFlowRate : Real [m3/s] = 0.005;
        attribute currentFlowRate : Real [m3/s];
        attribute strokeFrequency : Real [1/s] = 2.0;
        attribute unsafeCondition : Boolean = false;

        connection : Ports::FluidPort connect source to inletValve.fluidIn;
        connection : Ports::FluidPort connect inletValve.fluidOut to cylinder.fluidIn;
        connection : Ports::FluidPort connect cylinder.fluidOut to outletValve.fluidIn;
        connection : Ports::FluidPort connect outletValve.fluidOut to destination;

        action def IntakeStroke {
            doc /* Draw fluid into the cylinder from the source through the inlet valve */;
        }

        action def DischargeStroke {
            doc /* Push fluid out of the cylinder to the destination through the outlet valve */;
        }

        action def PumpCycle {
            action intake : IntakeStroke;
            action discharge : DischargeStroke;
        }

        state def PumpStateBehavior {
            state idle {
                entry action EnterIdle {
                    doc /* Stop the drive and close both valves */;
                }
                do action IdleWait;
                exit action ExitIdle;
            }
            state priming {
                entry action EnterPriming {
                    doc /* Begin filling the cylinder to eliminate trapped air */;
                }
                do action PrimingCycle;
                exit action ExitPriming;
            }
            state pumping {
                entry action EnterPumping {
                    doc /* Start the drive mechanism for continuous operation */;
                }
                do action cycle : PumpCycle;
                exit action ExitPumping;
            }
            state stopping {
                entry action EnterStopping {
                    doc /* Stop the drive mechanism and close valves */;
                }
                do action StoppingWait;
                exit action ExitStopping;
            }
            state fault {
                entry action EnterFault {
                    doc /* Immediately shut down the drive to prevent damage */;
                }
                do action FaultWait;
                exit action ExitFault;
            }

            transition : idle -> priming when control.command == Types::PumpCommandKind::start;
            transition : priming -> pumping when cylinder.currentVolume >= cylinder.maxVolume * 0.95;
            transition : pumping -> stopping when control.command == Types::PumpCommandKind::stop;
            transition : stopping -> idle when control.status == Types::PumpStatusKind::idle;
            transition : idle -> fault when unsafeCondition == true;
            transition : priming -> fault when unsafeCondition == true;
            transition : pumping -> fault when unsafeCondition == true;
            transition : fault -> idle when control.command == Types::PumpCommandKind::reset;
        }
    }

    // ──────────────── Pump Controller ────────────────

    part def PumpController {
        port operatorInput : Ports::CommandPort;
        port inletSensorData : Ports::SensorDataPort;
        port outletSensorData : Ports::SensorDataPort;
        port flowSensorData : Ports::SensorDataPort;
        port pumpCommandOut : Ports::CommandPort;

        attribute inletPressure : Real [Pa];
        attribute outletPressure : Real [Pa];
        attribute flowRate : Real [m3/s];

        attribute maxSafeInletPressure : Real [Pa] = 100000;
        attribute minSafeInletPressure : Real [Pa] = -10000;
        attribute maxSafeOutletPressure : Real [Pa] = 180000;
        attribute minSafeOutletPressure : Real [Pa] = 0;
        attribute expectedFlowRate : Real [m3/s] = 0.005;
        attribute flowRateTolerance : Real [m3/s] = 0.001;
        attribute primingTimeoutDuration : Real [s] = 30;
        attribute primingElapsedTime : Real [s];
        attribute currentFault : Types::FaultType = Types::FaultType::none;

        action def MonitorSensors {
            doc /* Continuously read all sensor ports and update internal values */;
        }
        action def EvaluateSafety {
            doc /* Check all monitored values against safe thresholds */;
        }
        action def SendStartCommand {
            doc /* Send a start command to the pump drive mechanism */;
        }
        action def SendStopCommand {
            doc /* Send a stop command to the pump drive mechanism */;
        }
        action def SendResetCommand {
            doc /* Send a reset command to clear the fault state */;
        }

        state def ControllerStateBehavior {
            state idle {
                entry action EnterControllerIdle;
                do action IdleMonitor;
                exit action ExitControllerIdle;
            }
            state priming {
                entry action EnterControllerPriming {
                    doc /* Issue start command and begin timing the priming phase */;
                }
                do action PrimingMonitor;
                exit action ExitControllerPriming;
            }
            state pumping {
                entry action EnterControllerPumping {
                    doc /* Confirm successful priming and maintain pumping */;
                }
                do action PumpingMonitor;
                exit action ExitControllerPumping;
            }
            state stopping {
                entry action EnterControllerStopping {
                    doc /* Issue stop command and wait for pump to return to idle */;
                }
                do action StoppingMonitor;
                exit action ExitControllerStopping;
            }
            state fault {
                entry action EnterControllerFault {
                    doc /* Issue emergency stop and record the fault type */;
                }
                do action FaultMonitor;
                exit action ExitControllerFault;
            }

            transition : idle -> priming when operatorInput.command == Types::PumpCommandKind::start;
            transition : priming -> pumping when flowRate >= expectedFlowRate - flowRateTolerance;
            transition : pumping -> stopping when operatorInput.command == Types::PumpCommandKind::stop;
            transition : stopping -> idle when pumpCommandOut.status == Types::PumpStatusKind::idle;
            transition : idle -> fault when inletPressure > maxSafeInletPressure || outletPressure > maxSafeOutletPressure || inletPressure < minSafeInletPressure;
            transition : priming -> fault when primingElapsedTime > primingTimeoutDuration;
            transition : priming -> fault when inletPressure > maxSafeInletPressure || outletPressure > maxSafeOutletPressure;
            transition : pumping -> fault when flowRate < expectedFlowRate - flowRateTolerance;
            transition : pumping -> fault when inletPressure > maxSafeInletPressure || outletPressure > maxSafeOutletPressure;
            transition : pumping -> fault when operatorInput.command == Types::PumpCommandKind::emergencyStop;
            transition : fault -> idle when operatorInput.command == Types::PumpCommandKind::reset;
        }
    }

    // ──────────────── Diver's Pump System ────────────────

    part def DiversPumpSystem {
        part pump : DiversPump;
        part controller : PumpController;
        part inletPressureSensor : Sensors::PressureSensor;
        part outletPressureSensor : Sensors::PressureSensor;
        part flowSensor : Sensors::FlowSensor;

        port sourceReservoir : Ports::FluidPort;
        port destinationVessel : Ports::FluidPort;
        port operatorInterface : Ports::CommandPort;

        attribute systemStatus : Types::PumpStatusKind = Types::PumpStatusKind::idle;
        attribute totalFluidTransferred : Real [m3];
        attribute operationStartTime : Real [s];
        attribute operationEndTime : Real [s];

        connection : Ports::FluidPort connect sourceReservoir to pump.source;
        connection : Ports::FluidPort connect pump.destination to destinationVessel;
        connection : Ports::FluidPort connect sourceReservoir to inletPressureSensor.fluidPort;
        connection : Ports::FluidPort connect pump.destination to outletPressureSensor.fluidPort;
        connection : Ports::FluidPort connect pump.destination to flowSensor.fluidPort;
        connection : Ports::SensorDataPort connect inletPressureSensor.dataOut to controller.inletSensorData;
        connection : Ports::SensorDataPort connect outletPressureSensor.dataOut to controller.outletSensorData;
        connection : Ports::SensorDataPort connect flowSensor.dataOut to controller.flowSensorData;
        connection : Ports::CommandPort connect controller.pumpCommandOut to pump.control;
        connection : Ports::CommandPort connect operatorInterface to controller.operatorInput;

        action def SystemStartup {
            doc /* Initialize all sensors, controller, and pump to idle state */;
        }
        action def SystemShutdown {
            doc /* Safely shut down the pump and return to idle state */;
        }
        action def EmergencyShutdown {
            doc /* Immediately halt all pump activity and enter fault state */;
        }
        action def LogData {
            doc /* Record sensor readings and operational status */;
        }

        state def SystemStateBehavior {
            state idle {
                entry action EnterSystemIdle;
                do action SystemIdleWait;
                exit action ExitSystemIdle;
            }
            state priming {
                entry action EnterSystemPriming;
                do action SystemPrimingWait;
                exit action ExitSystemPriming;
            }
            state pumping {
                entry action EnterSystemPumping;
                do action SystemPumpingRun;
                exit action ExitSystemPumping;
            }
            state stopping {
                entry action EnterSystemStopping;
                do action SystemStoppingWait;
                exit action ExitSystemStopping;
            }
            state fault {
                entry action EnterSystemFault;
                do action SystemFaultWait;
                exit action ExitSystemFault;
            }

            transition : idle -> priming when operatorInterface.command == Types::PumpCommandKind::start;
            transition : priming -> pumping when controller.flowRate >= controller.expectedFlowRate - controller.flowRateTolerance;
            transition : pumping -> stopping when operatorInterface.command == Types::PumpCommandKind::stop;
            transition : stopping -> idle when systemStatus == Types::PumpStatusKind::idle;
            transition : idle -> fault when controller.inletPressure > controller.maxSafeInletPressure || controller.outletPressure > controller.maxSafeOutletPressure;
            transition : priming -> fault when controller.primingElapsedTime > controller.primingTimeoutDuration;
            transition : pumping -> fault when controller.flowRate < controller.expectedFlowRate - controller.flowRateTolerance;
            transition : fault -> idle when operatorInterface.command == Types::PumpCommandKind::reset;
        }
    }

    // ──────────────── Requirements ────────────────

    package Requirements {
        requirement def PumpSystemOverallRequirement {
            doc /* The automated fluid pumping system shall transfer fluid from a source reservoir to a destination vessel in a controlled and monitored manner */;
        }

        requirement def PumpConstructionRequirement {
            doc /* The Diver's Pump shall consist of a cylinder chamber, a piston assembly, a drive mechanism, an inlet valve, and an outlet valve */;
            subject pump : DiversPump;
        }

        requirement def ValveOperationRequirement {
            doc /* The inlet and outlet valves shall open only when their respective pressure thresholds are met, ensuring one-way fluid flow */;
            subject inletValve : Components::InletValve;
            subject outletValve : Components::OutletValve;
        }

        requirement def PrimingRequirement {
            doc /* The system shall enter a priming state before pumping, during which the cylinder is filled with fluid to eliminate trapped air */;
        }

        requirement def PumpingOperationRequirement {
            doc /* During the pumping state, the pump shall execute continuous cycles of intake and discharge strokes */;
        }

        requirement def SafetyRequirement {
            doc /* If unsafe pressure levels or incorrect flow rates are detected, the system shall enter a fault state and shut down the pump to prevent damage */;
        }

        requirement def StopControlRequirement {
            doc /* Upon receiving a stop command, the system shall transition to a stopping state before returning to idle */;
        }

        requirement def MonitoringRequirement {
            doc /* The controller shall continuously monitor inlet pressure, outlet pressure, and flow rate using dedicated sensors */;
        }

        requirement def ResetRequirement {
            doc /* The system shall return to the idle state from the fault state only when a reset command is received */;
        }

        requirement def EmergencyStopRequirement {
            doc /* The system shall support an emergency stop command that immediately halts all pump activity */;
        }
    }
}
