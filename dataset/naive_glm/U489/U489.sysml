package DrumPumpingSystem {

    import ScalarValues::*;
    import MeasurementReferences::*;

    // ============================================================
    // Value Types with Units
    // ============================================================

    attribute def Volume :> Real {
        unit 'm3';
    }

    attribute def FlowRate :> Real {
        unit 'm3/s';
    }

    attribute def Pressure :> Real {
        unit 'Pa';
    }

    attribute def Level :> Real {
        unit 'm';
    }

    attribute def RotationalSpeed :> Real {
        unit 'rpm';
    }

    attribute def Power :> Real {
        unit 'W';
    }

    attribute def Torque :> Real {
        unit 'N*m';
    }

    attribute def Temperature :> Real {
        unit 'K';
    }

    attribute def Duration :> Real {
        unit 's';
    }

    attribute def Percent :> Real {
        unit '%';
    }

    // ============================================================
    // Item Definitions
    // ============================================================

    item def Fluid;
    item def Vapor;

    // ============================================================
    // Port Definitions
    // ============================================================

    port def FluidPort {
        flow fluid : Fluid;
        attribute flowRate : FlowRate;
        attribute pressure : Pressure;
    }

    port def MechanicalDrivePort {
        attribute torque : Torque;
        attribute speed : RotationalSpeed;
    }

    port def SensorSignalPort {
        attribute measuredValue : Real;
        attribute valid : Boolean;
    }

    port def ControlCommandPort {
        attribute command : String;
        attribute parameter : Real;
    }

    port def StatusReportPort {
        attribute status : String;
        attribute errorCode : Integer;
    }

    // ============================================================
    // Part Definitions — Source Drum
    // ============================================================

    part def SourceDrum {
        port fluidOut : FluidPort;
        port levelSignal : SensorSignalPort;

        attribute currentVolume : Volume := 200.0;
        attribute maxVolume : Volume := 200.0;
        attribute minSafeVolume : Volume := 5.0;
        attribute fluidType : String := "industrial_fluid";

        action def dispenseFluid {
            in attribute requestedVolume : Volume;
            out item dispensedFluid : Fluid;
        }

        action def updateLevel {
            // Update currentVolume and report via levelSignal
        }
    }

    // ============================================================
    // Part Definitions — Destination Tank
    // ============================================================

    part def DestinationTank {
        port fluidIn : FluidPort;
        port levelSignal : SensorSignalPort;

        attribute currentVolume : Volume := 0.0;
        attribute maxVolume : Volume := 500.0;
        attribute maxSafeVolume : Volume := 475.0;
        attribute fillPercent : Percent := 0.0;

        action def receiveFluid {
            in item incomingFluid : Fluid;
        }

        action def updateLevel {
            // Update currentVolume and report via levelSignal
        }
    }

    // ============================================================
    // Part Definitions — Pump Sub-Components
    // ============================================================

    part def DriveMotor {
        port driveOutput : MechanicalDrivePort;
        port commandInput : ControlCommandPort;
        port statusOutput : StatusReportPort;

        attribute ratedPower : Power := 1500.0;
        attribute currentSpeed : RotationalSpeed := 0.0;
        attribute targetSpeed : RotationalSpeed := 1750.0;
        attribute energized : Boolean := false;
        attribute temperature : Temperature := 293.15;
        attribute maxTemperature : Temperature := 353.15;

        action def spinUp {
            // Ramp motor speed from 0 to targetSpeed
        }

        action def spinDown {
            // Ramp motor speed from current to 0
        }

        action def emergencyStop {
            // Immediately cut power
        }
    }

    part def DrumRotor {
        port driveInput : MechanicalDrivePort;
        port fluidIntake : FluidPort;
        port fluidDischarge : FluidPort;

        attribute bladeCount : Integer := 8;
        attribute bladeAngle : Real := 30.0;
        attribute currentSpeed : RotationalSpeed := 0.0;
        attribute maxSpeed : RotationalSpeed := 3500.0;

        action def moveFluid {
            in item intakeFluid : Fluid;
            out item dischargeFluid : Fluid;
        }
    }

    part def SuctionPipe {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute length : Level := 2.0;
        attribute diameter : Level := 0.05;
        attribute pressureDrop : Pressure := 0.0;
    }

    part def DischargePipe {
        port inlet : FluidPort;
        port outlet : FluidPort;

        attribute length : Level := 3.0;
        attribute diameter : Level := 0.05;
        attribute pressureDrop : Pressure := 0.0;
    }

    part def MechanicalSeal {
        port mountingInterface : MechanicalDrivePort;

        attribute integrity : Boolean := true;
        attribute leakRate : FlowRate := 0.0;
        attribute maxAllowableLeakRate : FlowRate := 0.0001;
        attribute wearPercent : Percent := 0.0;
        attribute maxWearPercent : Percent := 80.0;

        action def sealIntegrityCheck {
            // Verify seal is intact and leak rate is within tolerance
        }
    }

    part def FlowSensor {
        port fluidConnection : FluidPort;
        port signalOutput : SensorSignalPort;

        attribute measuredFlowRate : FlowRate := 0.0;
        attribute minDetectableFlow : FlowRate := 0.001;
        attribute accuracy : Percent := 1.0;

        action def measureFlow {
            // Continuously measure flow rate through the pipe
        }
    }

    part def PressureSensor {
        port fluidConnection : FluidPort;
        port signalOutput : SensorSignalPort;

        attribute measuredPressure : Pressure := 101325.0;
        attribute cavitationPressureThreshold : Pressure := 2000.0;
        attribute accuracy : Percent := 0.5;

        action def measurePressure {
            // Continuously measure fluid pressure at the sensor location
        }

        action def detectCavitation {
            // Compare measured pressure against cavitation threshold
        }
    }

    part def LevelSensor {
        port signalOutput : SensorSignalPort;

        attribute measuredVolume : Volume := 0.0;
        attribute accuracy : Percent := 2.0;

        action def measureLevel {
            // Measure fluid volume in the container
        }
    }

    // ============================================================
    // Part Definition — Pump Controller
    // ============================================================

    part def PumpController {
        port flowSensorInput : SensorSignalPort;
        port pressureSensorInput : SensorSignalPort;
        port sourceLevelInput : SensorSignalPort;
        port destLevelInput : SensorSignalPort;
        port motorCommandOutput : ControlCommandPort;
        port systemStatusOutput : StatusReportPort;

        attribute currentFlowRate : FlowRate := 0.0;
        attribute currentPressure : Pressure := 101325.0;
        attribute sourceLevel : Volume := 200.0;
        attribute destLevel : Volume := 0.0;
        attribute cavitationThreshold : Pressure := 2000.0;
        attribute minSourceLevel : Volume := 5.0;
        attribute maxDestLevel : Volume := 475.0;
        attribute primingTimeout : Duration := 30.0;
        attribute primingTimer : Duration := 0.0;
        attribute faultCode : Integer := 0;
        attribute pumpState : String := "idle";

        action def performSafetyChecks {
            // Verify source drum has sufficient fluid
            // Verify destination tank has sufficient empty space
            // Verify mechanical seal integrity
            // Verify motor temperature is within limits
        }

        action def startPriming {
            // Command motor to low speed
            // Open suction path
            // Monitor for prime achievement
        }

        action def startRunning {
            // Command motor to full target speed
            // Begin normal fluid transfer
        }

        action def stopPump {
            // Ramp motor down to zero
            // Close flow paths
        }

        action def handleFault {
            // Record fault code
            // Initiate emergency stop
            // Report fault status
        }

        action def monitorOperation {
            // Continuously read sensor values
            // Check for cavitation
            // Check destination tank level
            // Check source drum level
        }

        state def PumpStateMachine {

            state idle {
                entry { pumpState := "idle"; }
                do { performSafetyChecks(); }
            }

            state priming {
                entry { pumpState := "priming"; startPriming(); }
                do { monitorOperation(); }
                exit { primingTimer := 0.0; }
            }

            state running {
                entry { pumpState := "running"; startRunning(); }
                do { monitorOperation(); }
                exit { stopPump(); }
            }

            state stopping {
                entry { pumpState := "stopping"; stopPump(); }
            }

            state faulted {
                entry { pumpState := "faulted"; handleFault(); }
            }

            transition initial then idle;

            transition idle_to_priming
                from idle to priming
                when (sourceLevel >= minSourceLevel and destLevel < maxDestLevel);

            transition priming_to_running
                from priming to running
                when (currentPressure > cavitationThreshold and currentFlowRate > 0.001);

            transition priming_timeout
                from priming to faulted
                when (primingTimer >= primingTimeout);

            transition running_to_stopping_full
                from running to stopping
                when (destLevel >= maxDestLevel);

            transition running_to_faulted_cavitation
                from running to faulted
                when (currentPressure <= cavitationThreshold);

            transition running_to_faulted_empty
                from running to faulted
                when (sourceLevel < minSourceLevel);

            transition stopping_to_idle
                from stopping to idle
                when (currentFlowRate <= 0.0 and currentSpeed == 0.0);

            transition faulted_to_idle
                from faulted to idle
                when (faultCode == 0);

            // Internal attribute for transition guard
            attribute currentSpeed : RotationalSpeed := 0.0;
        }

        state machine controllerBehavior : PumpStateMachine;
    }

    // ============================================================
    // Part Definition — Drum Pump (Assembly)
    // ============================================================

    part def DrumPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port controlInterface : ControlCommandPort;
        port statusInterface : StatusReportPort;

        part motor : DriveMotor;
        part rotor : DrumRotor;
        part suctionPipe : SuctionPipe;
        part dischargePipe : DischargePipe;
        part seal : MechanicalSeal;
        part flowSensor : FlowSensor;
        part pressureSensor : PressureSensor;
        part sourceLevelSensor : LevelSensor;
        part destLevelSensor : LevelSensor;
        part controller : PumpController;

        connection motorDriveToRotor
            connect motor.driveOutput to rotor.driveInput;

        connection sealMountingToRotor
            connect seal.mountingInterface to rotor.driveInput;

        connection suctionPortToPipe
            connect suctionPort to suctionPipe.inlet;

        connection suctionPipeToRotor
            connect suctionPipe.outlet to rotor.fluidIntake;

        connection rotorToDischargePipe
            connect rotor.fluidDischarge to dischargePipe.inlet;

        connection dischargePipeToPort
            connect dischargePipe.outlet to dischargePort;

        connection flowSensorTap
            connect rotor.fluidDischarge to flowSensor.fluidConnection;

        connection pressureSensorTap
            connect rotor.fluidIntake to pressureSensor.fluidConnection;

        connection flowSensorToController
            connect flowSensor.signalOutput to controller.flowSensorInput;

        connection pressureSensorToController
            connect pressureSensor.signalOutput to controller.pressureSensorInput;

        connection sourceLevelToController
            connect sourceLevelSensor.signalOutput to controller.sourceLevelInput;

        connection destLevelToController
            connect destLevelSensor.signalOutput to controller.destLevelInput;

        connection controllerToMotor
            connect controller.motorCommandOutput to motor.commandInput;

        connection motorStatusToController
            connect motor.statusOutput to controller.systemStatusOutput;

        attribute systemFlowRate : FlowRate := 0.0;
        attribute systemPressure : Pressure := 101325.0;
        attribute cavitationDetected : Boolean := false;
        attribute totalPumpedVolume : Volume := 0.0;
    }

    // ============================================================
    // Part Definition — Top-Level System Assembly
    // ============================================================

    part def DrumPumpingSystemAssembly {
        part sourceDrum : SourceDrum;
        part destinationTank : DestinationTank;
        part pump : DrumPump;

        connection sourceToPumpSuction
            connect sourceDrum.fluidOut to pump.suctionPort;

        connection pumpDischargeToTank
            connect pump.dischargePort to destinationTank.fluidIn;

        connection sourceLevelToPump
            connect sourceDrum.levelSignal to pump.sourceLevelSensor.signalOutput;

        connection destLevelToPump
            connect destinationTank.levelSignal to pump.destLevelSensor.signalOutput;

        attribute systemActive : Boolean := false;
        attribute totalFluidTransferred : Volume := 0.0;
        attribute operatingTime : Duration := 0.0;

        action def initializeSystem {
            // Power on all components
            // Run self-diagnostics
            // Verify all sensor communications
        }

        action def shutdownSystem {
            // Stop pump if running
            // Close all valves
            // Power down components
        }
    }

    // ============================================================
    // Requirement Definitions
    // ============================================================

    requirement def FluidTransferRequirement {
        doc "The system shall transfer fluid from the source drum to the destination tank reliably and efficiently.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def SafetyCheckRequirement {
        doc "The system shall perform safety checks before starting pump operation, verifying sufficient fluid in the source drum and sufficient empty space in the destination tank.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def PrimingRequirement {
        doc "The pump shall enter a priming state to prepare for fluid transfer before entering the running state.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def MonitoringRequirement {
        doc "The system shall continuously monitor flow rate and pressure during pump operation.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def CavitationProtectionRequirement {
        doc "The system shall detect cavitation conditions and automatically shut down to prevent damage.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def OverflowPreventionRequirement {
        doc "The system shall automatically stop pumping when the destination tank is nearly full to prevent spillage.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def StateManagementRequirement {
        doc "The pump shall be in one of the following states: idle, priming, running, stopping, or faulted.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def LeakPreventionRequirement {
        doc "The system shall use a high-integrity mechanical seal to prevent fluid leaks during operation.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def MotorDriveRequirement {
        doc "The pump rotor shall be driven by an electric drive motor capable of achieving the required rotational speed for fluid transfer.";
        subject system : DrumPumpingSystemAssembly;
    }

    requirement def PipingRequirement {
        doc "Suction and discharge pipes shall connect the pump to the source drum and destination tank respectively.";
        subject system : DrumPumpingSystemAssembly;
    }

    // ============================================================
    // Requirement Usages
    // ============================================================

    requirement fluidTransferReq : FluidTransferRequirement;
    requirement safetyCheckReq : SafetyCheckRequirement;
    requirement primingReq : PrimingRequirement;
    requirement monitoringReq : MonitoringRequirement;
    requirement cavitationProtectionReq : CavitationProtectionRequirement;
    requirement overflowPreventionReq : OverflowPreventionRequirement;
    requirement stateManagementReq : StateManagementRequirement;
    requirement leakPreventionReq : LeakPreventionRequirement;
    requirement motorDriveReq : MotorDriveRequirement;
    requirement pipingReq : PipingRequirement;

    // ============================================================
    // Requirement Satisfaction
    // ============================================================

    satisfy fluidTransferReq by DrumPumpingSystemAssembly;
    satisfy safetyCheckReq by DrumPump.controller;
    satisfy primingReq by DrumPump.controller;
    satisfy monitoringReq by DrumPump.flowSensor;
    satisfy monitoringReq by DrumPump.pressureSensor;
    satisfy cavitationProtectionReq by DrumPump.pressureSensor;
    satisfy cavitationProtectionReq by DrumPump.controller;
    satisfy overflowPreventionReq by DrumPump.controller;
    satisfy stateManagementReq by DrumPump.controller;
    satisfy leakPreventionReq by DrumPump.seal;
    satisfy motorDriveReq by DrumPump.motor;
    satisfy motorDriveReq by DrumPump.rotor;
    satisfy pipingReq by DrumPump.suctionPipe;
    satisfy pipingReq by DrumPump.dischargePipe;

}
