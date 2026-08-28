package AspiratorSystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQPressure::*;
    import ISQTime::*;

    // ---- Value types with units ----
    value def PressureValue :> Real { unit = 'Pa'; }
    value def FlowRateValue :> Real { unit = 'm3/s'; }
    value def VacuumLevel :> Real { unit = 'Pa'; }
    value def ValvePosition :> Real { unit = '%'; min = 0; max = 100; }
    value def TemperatureValue :> Real { unit = 'K'; }

    // ---- Item types ----
    item def MotiveFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }
    item def SuctionFluid {
        attribute pressure : PressureValue;
        attribute temperature : TemperatureValue;
    }
    item def CombinedFluid {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    // ---- Port definitions ----
    port def MotiveFluidPort {
        out item motive : MotiveFluid;
    }
    port def SuctionFluidPort {
        in item suction : SuctionFluid;
    }
    port def DischargePort {
        out item discharge : CombinedFluid;
    }
    port def PressureSignalPort {
        out attribute measuredPressure : PressureValue;
    }
    port def ValveControlPort {
        in attribute commandPosition : ValvePosition;
    }
    port def ControllerCommandPort {
        out attribute valveCommand : ValvePosition;
    }
    port def SensorDataPort {
        in attribute vacuumReading : VacuumLevel;
    }

    // ---- Requirements ----
    requirement def VacuumControlRequirement {
        doc /* The system shall maintain vacuum within +/- 500 Pa of setpoint. */
        attribute targetVacuum : VacuumLevel = 50000;
        attribute tolerance : VacuumLevel = 500;
        constraint { abs(measuredVacuum - targetVacuum) <= tolerance }
    }

    requirement def EmergencyStopRequirement {
        doc /* The system shall support emergency stop from any state. */
    }

    requirement def StartupRequirement {
        doc /* Startup shall complete within 30 seconds. */
        attribute maxStartupTime : TimeValue = 30 [s];
    }

    // ---- Parts ----
    part def MotiveFluidSource {
        port motiveOut : MotiveFluidPort;
        attribute supplyPressure : PressureValue = 600000;
        attribute supplyTemperature : TemperatureValue = 293.15;
        action generateMotiveFluid {
            out item motive : MotiveFluid;
        }
    }

    part def FlowRegulationValve {
        port motiveIn : MotiveFluidPort;
        port motiveOut : MotiveFluidPort;
        port controlIn : ValveControlPort;
        attribute currentPosition : ValvePosition = 0;
        attribute maxFlowRate : FlowRateValue = 0.01;

        action regulateFlow {
            in item motiveIn : MotiveFluid;
            in attribute command : ValvePosition;
            out item motiveOut : MotiveFluid;
        }

        state valveBehavior {
            entry; then Closed;
            state Closed;
            transition from Closed to Open
                when { controlIn.commandPosition > 0 }
                assign currentPosition { controlIn.commandPosition; }
            state Open;
            transition from Open to Closed
                when { controlIn.commandPosition == 0 };
        }
    }

    part def VenturiTube {
        port motiveIn : MotiveFluidPort;
        port suctionIn : SuctionFluidPort;
        port dischargeOut : DischargePort;
        attribute throatDiameter : Real = 0.005;
        attribute inletDiameter : Real = 0.02;
        attribute dischargeDiameter : Real = 0.015;
        attribute efficiency : Real = 0.85;

        action accelerateMotive {
            in item motive : MotiveFluid;
            out item accelerated : MotiveFluid;
        }
        action generateSuction {
            in item accelerated : MotiveFluid;
            out item suction : SuctionFluid;
        }
        action mergeFluids {
            in item motive : MotiveFluid;
            in item suction : SuctionFluid;
            out item combined : CombinedFluid;
        }
    }

    part def SuctionChamber {
        port suctionIn : SuctionFluidPort;
        port suctionOut : SuctionFluidPort;
        port pressurePort : PressureSignalPort;
        attribute chamberVolume : VolumeValue = 0.001;
        attribute currentVacuum : VacuumLevel = 101325;

        action measurePressure {
            out attribute pressure : PressureValue;
        }
    }

    part def DischargeChamber {
        port dischargeIn : DischargePort;
        port dischargeOut : DischargePort;
        attribute dischargePressure : PressureValue = 101325;

        action dischargeFluid {
            in item combined : CombinedFluid;
            out item discharged : CombinedFluid;
        }
    }

    part def VacuumSensor {
        port pressureIn : PressureSignalPort;
        port dataOut : SensorDataPort;
        attribute samplingRate : Real = 100;
        attribute accuracy : PressureValue = 100;

        action samplePressure {
            in attribute rawPressure : PressureValue;
            out attribute filteredPressure : VacuumLevel;
        }
    }

    part def AspiratorController {
        port sensorIn : SensorDataPort;
        port valveOut : ControllerCommandPort;
        attribute setpoint : VacuumLevel = 50000;
        attribute kp : Real = 0.5;
        attribute ki : Real = 0.1;
        attribute kd : Real = 0.05;
        attribute integralError : Real = 0;
        attribute previousError : Real = 0;
        attribute currentCommand : ValvePosition = 0;

        action computeControl {
            in attribute measured : VacuumLevel;
            out attribute command : ValvePosition;
        }

        state machine ControllerStateMachine {
            entry; then Idle;
            state Idle;
            transition from Idle to Startup
                when { sensorIn.vacuumReading < setpoint };
            state Startup;
            transition from Startup to NormalOperation
                when { abs(sensorIn.vacuumReading - setpoint) <= 500 };
            state NormalOperation;
            transition from NormalOperation to ControlledShutdown
                when { shutdownRequested == true };
            state ControlledShutdown;
            transition from ControlledShutdown to Idle
                when { currentCommand == 0 };
            state EmergencyStop;
            transition from any to EmergencyStop
                when { emergencyStopRequested == true };
            transition from EmergencyStop to Idle
                when { resetRequested == true };
        }

        attribute shutdownRequested : Boolean = false;
        attribute emergencyStopRequested : Boolean = false;
        attribute resetRequested : Boolean = false;
    }

    // ---- Top-level system ----
    part def AutomatedAspiratorSystem {
        attribute systemTargetVacuum : VacuumLevel = 50000;
        attribute systemTolerance : VacuumLevel = 500;

        part motiveSource : MotiveFluidSource;
        part valve : FlowRegulationValve;
        part venturi : VenturiTube;
        part suctionChamber : SuctionChamber;
        part dischargeChamber : DischargePort;
        part vacuumSensor : VacuumSensor;
        part controller : AspiratorController;

        // Connections
        connection motiveSourceToValve connect motiveSource.motiveOut to valve.motiveIn;
        connection valveToVenturi connect valve.motiveOut to venturi.motiveIn;
        connection venturiSuction connect suctionChamber.suctionOut to venturi.suctionIn;
        connection venturiToDischarge connect venturi.dischargeOut to dischargeChamber.dischargeIn;
        connection chamberPressureSense connect suctionChamber.pressurePort to vacuumSensor.pressureIn;
        connection sensorToController connect vacuumSensor.dataOut to controller.sensorIn;
        connection controllerToValve connect controller.valveOut to valve.controlIn;

        // Requirements
        satisfy VacuumControlRequirement {
            attribute measuredVacuum = suctionChamber.currentVacuum;
        }
        satisfy EmergencyStopRequirement;
        satisfy StartupRequirement;

        // System-level state machine
        state machine SystemOperationStates {
            entry; then SystemIdle;
            state SystemIdle {
                entry { controller.currentCommand = 0; }
            }
            state SystemStartup {
                entry { controller.currentCommand = 50; }
            }
            state SystemNormalOperation;
            state SystemControlledShutdown {
                entry { controller.currentCommand = 0; }
            }
            state SystemEmergencyStop {
                entry { valve.currentPosition = 0; }
            }
            transition from SystemIdle to SystemStartup
                when { controller.sensorIn.vacuumReading < controller.setpoint };
            transition from SystemStartup to SystemNormalOperation
                when { abs(controller.sensorIn.vacuumReading - controller.setpoint) <= 500 };
            transition from SystemNormalOperation to SystemControlledShutdown
                when { controller.shutdownRequested == true };
            transition from SystemControlledShutdown to SystemIdle
                when { controller.currentCommand == 0 };
            transition from any to SystemEmergencyStop
                when { controller.emergencyStopRequested == true };
            transition from SystemEmergencyStop to SystemIdle
                when { controller.resetRequested == true };
        }
    }
}
