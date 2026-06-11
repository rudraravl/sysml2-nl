package PumpingSubsystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    attribute def Pressure :> Real {
        unit = "Pa";
    }

    attribute def FlowRate :> Real {
        unit = "m^3/s";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rpm";
    }

    attribute def Torque :> Real {
        unit = "N*m";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def Temperature :> Real {
        unit = "K";
    }

    attribute def Volume :> Real {
        unit = "m^3";
    }

    attribute def Displacement :> Real {
        unit = "m^3/rev";
    }

    attribute def Efficiency :> Real {
        unit = "1";
    }

    attribute def ContaminationLevel :> Real {
        unit = "ISO4406";
    }

    item def HydraulicFluid {
        attribute pressure : Pressure;
        attribute temperature : Temperature;
        attribute volumetricFlow : FlowRate;
        attribute bulkModulus : Pressure;
        attribute viscosity : Real {
            unit = "Pa*s";
        }
        attribute contamination : ContaminationLevel;
    }

    item def MechanicalRotation {
        attribute shaftSpeed : RotationalSpeed;
        attribute shaftTorque : Torque;
        attribute shaftPower : Power;
        attribute direction : RotationDirection;
    }

    enum def RotationDirection {
        enum clockwise;
        enum counterClockwise;
    }

    item def ElectricalCommand {
        attribute enable : Boolean;
        attribute targetFlow : FlowRate;
        attribute targetPressure : Pressure;
        attribute swashplateCommand : Real {
            unit = "deg";
        }
    }

    item def StatusSignal {
        attribute pumpRunning : Boolean;
        attribute faultActive : Boolean;
        attribute actualFlow : FlowRate;
        attribute actualOutletPressure : Pressure;
        attribute caseDrainTemperature : Temperature;
        attribute diagnosticCode : DiagnosticCode;
    }

    enum def DiagnosticCode {
        enum normal;
        enum lowInletPressure;
        enum overPressure;
        enum overTemperature;
        enum excessiveCaseDrainFlow;
        enum shaftOverspeed;
        enum filterClogged;
        enum commandedShutdown;
    }

    port def HydraulicInletPort {
        in item fluidIn : HydraulicFluid;
    }

    port def HydraulicOutletPort {
        out item fluidOut : HydraulicFluid;
    }

    port def HydraulicDrainPort {
        out item drainFluid : HydraulicFluid;
    }

    port def MechanicalDrivePort {
        in item rotationIn : MechanicalRotation;
    }

    port def CommandPort {
        in item command : ElectricalCommand;
    }

    port def StatusPort {
        out item status : StatusSignal;
    }

    part def Reservoir {
        attribute fluidVolume : Volume = 0.120;
        attribute nominalFluidTemperature : Temperature = 313.15;
        attribute breatherRating : ContaminationLevel = 18.0;

        port supplyPort : HydraulicOutletPort;
        port returnPort : HydraulicInletPort;
        port drainReturnPort : HydraulicInletPort;
    }

    part def SuctionStrainer {
        attribute meshRating : Real {
            unit = "um";
        } = 125.0;

        attribute cleanPressureDrop : Pressure = 8000.0;
        attribute cloggedPressureDrop : Pressure = 60000.0;
        attribute bypassOpenPressureDrop : Pressure = 70000.0;
        attribute bypassOpen : Boolean = false;

        port inlet : HydraulicInletPort;
        port outlet : HydraulicOutletPort;
    }

    part def ElectricMotor {
        attribute ratedPower : Power = 15000.0;
        attribute ratedSpeed : RotationalSpeed = 1800.0;
        attribute ratedTorque : Torque = 79.6;
        attribute energized : Boolean = false;
        attribute actualSpeed : RotationalSpeed = 0.0;
        attribute availableTorque : Torque = 0.0;

        port shaftOutput : MechanicalDrivePort;
        port commandInput : CommandPort;

        action startMotor {
            in item command : ElectricalCommand;
            out item rotation : MechanicalRotation;

            first start;
            then setEnergized;
            then accelerate;
            then provideRotation;

            action setEnergized {
                energized := command.enable;
            }

            action accelerate {
                if command.enable then {
                    actualSpeed := ratedSpeed;
                    availableTorque := ratedTorque;
                } else {
                    actualSpeed := 0.0;
                    availableTorque := 0.0;
                }
            }

            action provideRotation {
                rotation.shaftSpeed := actualSpeed;
                rotation.shaftTorque := availableTorque;
                rotation.shaftPower := ratedPower;
                rotation.direction := RotationDirection::clockwise;
            }
        }
    }

    part def FlexibleCoupling {
        attribute torsionalStiffness : Real {
            unit = "N*m/rad";
        } = 4500.0;

        attribute dampingCoefficient : Real {
            unit = "N*m*s/rad";
        } = 38.0;

        attribute maxAllowableTorque : Torque = 120.0;

        port motorSide : MechanicalDrivePort;
        port pumpSide : MechanicalDrivePort;
    }

    part def AxialPistonPump {
        attribute numberOfPistons : Integer = 9;
        attribute pistonDiameter : Real {
            unit = "m";
        } = 0.014;

        attribute strokeLengthMax : Real {
            unit = "m";
        } = 0.018;

        attribute swashplateAngle : Real {
            unit = "deg";
        } = 0.0;

        attribute maxSwashplateAngle : Real {
            unit = "deg";
        } = 18.0;

        attribute displacementPerRev : Displacement = 4.50e-5;
        attribute volumetricEfficiency : Efficiency = 0.92;
        attribute mechanicalEfficiency : Efficiency = 0.88;
        attribute ratedSpeed : RotationalSpeed = 1800.0;
        attribute maxContinuousPressure : Pressure = 28000000.0;
        attribute peakPressure : Pressure = 32000000.0;
        attribute minimumInletPressure : Pressure = 80000.0;
        attribute nominalOutletPressure : Pressure = 21000000.0;
        attribute commandedFlow : FlowRate = 0.0;
        attribute actualOutletFlow : FlowRate = 0.0;
        attribute caseDrainFlow : FlowRate = 3.0e-5;
        attribute caseTemperature : Temperature = 318.15;
        attribute rotating : Boolean = false;
        attribute faulted : Boolean = false;

        port shaftInput : MechanicalDrivePort;
        port inlet : HydraulicInletPort;
        port outlet : HydraulicOutletPort;
        port caseDrain : HydraulicDrainPort;
        port commandInput : CommandPort;
        port statusOutput : StatusPort;

        part cylinderBlock {
            attribute boreCount : Integer = 9;
            attribute blockMaterialYieldStrength : Pressure = 620000000.0;
        }

        part pistons[9] {
            attribute diameter : Real {
                unit = "m";
            } = 0.014;

            attribute effectiveArea : Real {
                unit = "m^2";
            } = 1.539e-4;
        }

        part valvePlate {
            attribute inletKidneyArea : Real {
                unit = "m^2";
            } = 4.8e-4;

            attribute outletKidneyArea : Real {
                unit = "m^2";
            } = 4.2e-4;
        }

        part swashplate {
            attribute angle : Real {
                unit = "deg";
            } = 0.0;

            attribute actuatorResponseTime : Real {
                unit = "s";
            } = 0.080;
        }

        part caseHousing {
            attribute maximumCasePressure : Pressure = 350000.0;
            attribute oilFillVolume : Volume = 0.0045;
        }

        action computePumpFlow {
            in item rotation : MechanicalRotation;
            in item command : ElectricalCommand;
            in item inletFluid : HydraulicFluid;
            out item outletFluid : HydraulicFluid;
            out item drainFluid : HydraulicFluid;
            out item status : StatusSignal;

            first validateCommand;
            then setSwashplate;
            then calculateFlow;
            then calculateOutletState;
            then calculateDrain;
            then publishStatus;

            action validateCommand {
                if command.enable and inletFluid.pressure >= minimumInletPressure then {
                    rotating := true;
                    faulted := false;
                } else {
                    rotating := false;
                    faulted := true;
                }
            }

            action setSwashplate {
                if command.swashplateCommand > maxSwashplateAngle then {
                    swashplateAngle := maxSwashplateAngle;
                } else if command.swashplateCommand < 0.0 then {
                    swashplateAngle := 0.0;
                } else {
                    swashplateAngle := command.swashplateCommand;
                }
                swashplate.angle := swashplateAngle;
            }

            action calculateFlow {
                if rotating then {
                    commandedFlow := command.targetFlow;
                    actualOutletFlow := displacementPerRev * rotation.shaftSpeed / 60.0 * volumetricEfficiency * swashplateAngle / maxSwashplateAngle;
                } else {
                    commandedFlow := 0.0;
                    actualOutletFlow := 0.0;
                }
            }

            action calculateOutletState {
                outletFluid.volumetricFlow := actualOutletFlow;
                outletFluid.pressure := command.targetPressure;
                outletFluid.temperature := inletFluid.temperature + 6.0;
                outletFluid.bulkModulus := inletFluid.bulkModulus;
                outletFluid.viscosity := inletFluid.viscosity;
                outletFluid.contamination := inletFluid.contamination;
            }

            action calculateDrain {
                drainFluid.volumetricFlow := caseDrainFlow;
                drainFluid.pressure := 200000.0;
                drainFluid.temperature := caseTemperature;
                drainFluid.bulkModulus := inletFluid.bulkModulus;
                drainFluid.viscosity := inletFluid.viscosity;
                drainFluid.contamination := inletFluid.contamination;
            }

            action publishStatus {
                status.pumpRunning := rotating;
                status.faultActive := faulted;
                status.actualFlow := actualOutletFlow;
                status.actualOutletPressure := outletFluid.pressure;
                status.caseDrainTemperature := caseTemperature;

                if not command.enable then {
                    status.diagnosticCode := DiagnosticCode::commandedShutdown;
                } else if inletFluid.pressure < minimumInletPressure then {
                    status.diagnosticCode := DiagnosticCode::lowInletPressure;
                } else if outletFluid.pressure > peakPressure then {
                    status.diagnosticCode := DiagnosticCode::overPressure;
                } else if caseTemperature > 363.15 then {
                    status.diagnosticCode := DiagnosticCode::overTemperature;
                } else if rotation.shaftSpeed > 2100.0 then {
                    status.diagnosticCode := DiagnosticCode::shaftOverspeed;
                } else {
                    status.diagnosticCode := DiagnosticCode::normal;
                }
            }
        }

        state def PumpOperatingState {
            state off;
            state priming;
            state running;
            state pressureCompensating;
            state fault;
            state shutdown;

            initial then off;

            transition off_to_priming
                first off
                accept commandInput.command
                if commandInput.command.enable
                then priming;

            transition priming_to_running
                first priming
                if inlet.fluidIn.pressure >= minimumInletPressure
                then running;

            transition running_to_compensating
                first running
                if outlet.fluidOut.pressure >= commandInput.command.targetPressure
                then pressureCompensating;

            transition compensating_to_running
                first pressureCompensating
                if outlet.fluidOut.pressure < commandInput.command.targetPressure * 0.95
                then running;

            transition any_to_fault
                first running
                if outlet.fluidOut.pressure > peakPressure or caseTemperature > 363.15 or shaftInput.rotationIn.shaftSpeed > 2100.0
                then fault;

            transition fault_to_shutdown
                first fault
                then shutdown;

            transition shutdown_to_off
                first shutdown
                if not commandInput.command.enable
                then off;
        }
    }

    part def PressureReliefValve {
        attribute crackingPressure : Pressure = 30000000.0;
        attribute fullOpenPressure : Pressure = 32000000.0;
        attribute ratedReliefFlow : FlowRate = 0.0012;
        attribute open : Boolean = false;

        port pumpLine : HydraulicInletPort;
        port tankLine : HydraulicOutletPort;

        action relievePressure {
            in item lineFluid : HydraulicFluid;
            out item bypassFluid : HydraulicFluid;

            if lineFluid.pressure >= crackingPressure then {
                open := true;
                bypassFluid.volumetricFlow := ratedReliefFlow;
                bypassFluid.pressure := 250000.0;
                bypassFluid.temperature := lineFluid.temperature + 3.0;
                bypassFluid.bulkModulus := lineFluid.bulkModulus;
                bypassFluid.viscosity := lineFluid.viscosity;
                bypassFluid.contamination := lineFluid.contamination;
            } else {
                open := false;
                bypassFluid.volumetricFlow := 0.0;
                bypassFluid.pressure := lineFluid.pressure;
                bypassFluid.temperature := lineFluid.temperature;
                bypassFluid.bulkModulus := lineFluid.bulkModulus;
                bypassFluid.viscosity := lineFluid.viscosity;
                bypassFluid.contamination := lineFluid.contamination;
            }
        }
    }

    part def CheckValve {
        attribute forwardCrackingPressure : Pressure = 50000.0;
        attribute reverseLeakageFlow : FlowRate = 1.0e-7;
        attribute open : Boolean = false;

        port upstream : HydraulicInletPort;
        port downstream : HydraulicOutletPort;
    }

    part def PressureFilter {
        attribute elementRating : Real {
            unit = "um";
        } = 10.0;

        attribute cleanPressureDrop : Pressure = 120000.0;
        attribute cloggedPressureDrop : Pressure = 900000.0;
        attribute differentialPressure : Pressure = 120000.0;
        attribute bypassSetPressure : Pressure = 1100000.0;
        attribute clogged : Boolean = false;

        port inlet : HydraulicInletPort;
        port outlet : HydraulicOutletPort;
        port statusOutput : StatusPort;
    }

    part def Accumulator {
        attribute gasPrechargePressure : Pressure = 12000000.0;
        attribute shellRatedPressure : Pressure = 33000000.0;
        attribute totalGasVolume : Volume = 0.0020;
        attribute usableFluidVolume : Volume = 0.0012;
        attribute currentFluidVolume : Volume = 0.0006;

        port hydraulicPort : HydraulicInletPort;
    }

    part def PressureTransducer {
        attribute measurementRange : Pressure = 40000000.0;
        attribute accuracyPercentFullScale : Real {
            unit = "%";
        } = 0.5;

        attribute measuredPressure : Pressure = 0.0;

        port sensedLine : HydraulicInletPort;
        port statusOutput : StatusPort;
    }

    part def FlowMeter {
        attribute measurementRange : FlowRate = 0.0018;
        attribute accuracyPercentReading : Real {
            unit = "%";
        } = 1.0;

        attribute measuredFlow : FlowRate = 0.0;

        port sensedLine : HydraulicInletPort;
        port statusOutput : StatusPort;
    }

    part def Controller {
        attribute requestedPressure : Pressure = 21000000.0;
        attribute requestedFlow : FlowRate = 0.0010;
        attribute minimumCommandedAngle : Real {
            unit = "deg";
        } = 2.0;

        attribute maximumCommandedAngle : Real {
            unit = "deg";
        } = 18.0;

        attribute enableRequest : Boolean = false;
        attribute pressureError : Pressure = 0.0;

        port operatorCommand : CommandPort;
        port pumpStatusInput : StatusPort;
        port pressureFeedback : StatusPort;
        port flowFeedback : StatusPort;
        port motorCommand : CommandPort;
        port pumpCommand : CommandPort;
        port subsystemStatus : StatusPort;

        action regulatePump {
            in item operatorCmd : ElectricalCommand;
            in item pumpStatus : StatusSignal;
            in item pressureStatus : StatusSignal;
            in item flowStatus : StatusSignal;
            out item motorCmd : ElectricalCommand;
            out item pumpCmd : ElectricalCommand;
            out item reportedStatus : StatusSignal;

            first readCommand;
            then computeSwashplateCommand;
            then issueCommands;
            then reportSubsystemStatus;

            action readCommand {
                enableRequest := operatorCmd.enable;
                requestedPressure := operatorCmd.targetPressure;
                requestedFlow := operatorCmd.targetFlow;
            }

            action computeSwashplateCommand {
                pressureError := requestedPressure - pressureStatus.actualOutletPressure;

                if not enableRequest or pumpStatus.faultActive then {
                    pumpCmd.swashplateCommand := 0.0;
                } else if pressureError > 1000000.0 then {
                    pumpCmd.swashplateCommand := maximumCommandedAngle;
                } else if pressureError < -500000.0 then {
                    pumpCmd.swashplateCommand := minimumCommandedAngle;
                } else {
                    pumpCmd.swashplateCommand := 12.0;
                }
            }

            action issueCommands {
                motorCmd.enable := enableRequest and not pumpStatus.faultActive;
                motorCmd.targetPressure := requestedPressure;
                motorCmd.targetFlow := requestedFlow;
                motorCmd.swashplateCommand := pumpCmd.swashplateCommand;

                pumpCmd.enable := motorCmd.enable;
                pumpCmd.targetPressure := requestedPressure;
                pumpCmd.targetFlow := requestedFlow;
            }

            action reportSubsystemStatus {
                reportedStatus.pumpRunning := pumpStatus.pumpRunning;
                reportedStatus.faultActive := pumpStatus.faultActive;
                reportedStatus.actualFlow := flowStatus.actualFlow;
                reportedStatus.actualOutletPressure := pressureStatus.actualOutletPressure;
                reportedStatus.caseDrainTemperature := pumpStatus.caseDrainTemperature;
                reportedStatus.diagnosticCode := pumpStatus.diagnosticCode;
            }
        }
    }

    part def PumpingSubsystem {
        attribute nominalSystemPressure : Pressure = 21000000.0;
        attribute maximumSystemPressure : Pressure = 30000000.0;
        attribute nominalDeliveredFlow : FlowRate = 0.0010;
        attribute minimumDeliveredFlow : FlowRate = 0.00085;
        attribute reservoirCapacity : Volume = 0.120;
        attribute normalFluidTemperature : Temperature = 318.15;
        attribute maximumFluidTemperature : Temperature = 353.15;
        attribute nominalInputPower : Power = 15000.0;

        port externalCommand : CommandPort;
        port hydraulicSupplyToLoad : HydraulicOutletPort;
        port hydraulicReturnFromLoad : HydraulicInletPort;
        port subsystemStatus : StatusPort;

        part reservoir : Reservoir;
        part suctionStrainer : SuctionStrainer;
        part driveMotor : ElectricMotor;
        part coupling : FlexibleCoupling;
        part axialPistonPump : AxialPistonPump;
        part outletCheckValve : CheckValve;
        part pressureFilter : PressureFilter;
        part accumulator : Accumulator;
        part reliefValve : PressureReliefValve;
        part pressureSensor : PressureTransducer;
        part flowSensor : FlowMeter;
        part controller : Controller;

        connect externalCommand to controller.operatorCommand;
        connect controller.motorCommand to driveMotor.commandInput;
        connect controller.pumpCommand to axialPistonPump.commandInput;

        connect reservoir.supplyPort to suctionStrainer.inlet;
        connect suctionStrainer.outlet to axialPistonPump.inlet;

        connect driveMotor.shaftOutput to coupling.motorSide;
        connect coupling.pumpSide to axialPistonPump.shaftInput;

        connect axialPistonPump.outlet to outletCheckValve.upstream;
        connect outletCheckValve.downstream to pressureFilter.inlet;
        connect pressureFilter.outlet to hydraulicSupplyToLoad;

        connect pressureFilter.outlet to accumulator.hydraulicPort;
        connect pressureFilter.outlet to pressureSensor.sensedLine;
        connect pressureFilter.outlet to flowSensor.sensedLine;
        connect pressureFilter.inlet to reliefValve.pumpLine;
        connect reliefValve.tankLine to reservoir.returnPort;

        connect axialPistonPump.caseDrain to reservoir.drainReturnPort;
        connect hydraulicReturnFromLoad to reservoir.returnPort;

        connect axialPistonPump.statusOutput to controller.pumpStatusInput;
        connect pressureSensor.statusOutput to controller.pressureFeedback;
        connect flowSensor.statusOutput to controller.flowFeedback;
        connect controller.subsystemStatus to subsystemStatus;

        state def SubsystemState {
            state disabled;
            state standby;
            state starting;
            state deliveringFlow;
            state pressureHold;
            state faulted;
            state stopping;

            initial then disabled;

            transition disabled_to_standby
                first disabled
                accept externalCommand.command
                if externalCommand.command.enable
                then standby;

            transition standby_to_starting
                first standby
                if controller.motorCommand.command.enable
                then starting;

            transition starting_to_delivering
                first starting
                if axialPistonPump.statusOutput.status.pumpRunning and axialPistonPump.outlet.fluidOut.pressure > 1000000.0
                then deliveringFlow;

            transition delivering_to_hold
                first deliveringFlow
                if pressureSensor.measuredPressure >= nominalSystemPressure
                then pressureHold;

            transition hold_to_delivering
                first pressureHold
                if flowSensor.measuredFlow < minimumDeliveredFlow
                then deliveringFlow;

            transition operating_to_faulted
                first deliveringFlow
                if subsystemStatus.status.faultActive
                then faulted;

            transition hold_to_faulted
                first pressureHold
                if subsystemStatus.status.faultActive
                then faulted;

            transition faulted_to_stopping
                first faulted
                then stopping;

            transition stopping_to_disabled
                first stopping
                if not externalCommand.command.enable
                then disabled;
        }
    }

    requirement def PumpTypeRequirement {
        doc /* The pumping subsystem shall move hydraulic fluid using an axial piston pump as the primary pumping element. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.axialPistonPump.numberOfPistons >= 7
        }
    }

    requirement def FlowRequirement {
        doc /* The pumping subsystem shall deliver at least 0.00085 m^3/s of hydraulic fluid at nominal operating conditions. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.flowSensor.measuredFlow >= subsystem.minimumDeliveredFlow
        }
    }

    requirement def PressureRequirement {
        doc /* The pumping subsystem shall regulate outlet pressure to 21 MPa during normal pressure-hold operation. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.pressureSensor.measuredPressure >= 20000000.0 and
            subsystem.pressureSensor.measuredPressure <= 22000000.0
        }
    }

    requirement def OverPressureProtectionRequirement {
        doc /* The pumping subsystem shall protect the outlet line from pressure greater than 30 MPa by opening a relief path to reservoir. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.reliefValve.crackingPressure <= subsystem.maximumSystemPressure
        }
    }

    requirement def CaseDrainRequirement {
        doc /* The axial piston pump shall route internal leakage through a case drain port to reservoir. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.axialPistonPump.caseDrainFlow <= 5.0e-5
        }
    }

    requirement def TemperatureRequirement {
        doc /* The pumping subsystem shall report a fault when case drain temperature exceeds 363.15 K. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.axialPistonPump.caseTemperature <= 363.15 or
            subsystem.subsystemStatus.status.diagnosticCode == DiagnosticCode::overTemperature
        }
    }

    requirement def FiltrationRequirement {
        doc /* The pumping subsystem shall filter delivered hydraulic fluid through a pressure-line filter rated no greater than 10 micrometers. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.pressureFilter.elementRating <= 10.0
        }
    }

    requirement def DrivePowerRequirement {
        doc /* The electric drive shall provide at least 15 kW mechanical power to the axial piston pump at rated operating speed. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.driveMotor.ratedPower >= 15000.0 and
            subsystem.driveMotor.ratedSpeed >= subsystem.axialPistonPump.ratedSpeed
        }
    }

    requirement def InletPressureRequirement {
        doc /* The pump controller shall prevent running operation when inlet pressure is below 80 kPa absolute. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.axialPistonPump.minimumInletPressure >= 80000.0
        }
    }

    requirement def StatusReportingRequirement {
        doc /* The subsystem shall report running state, active fault state, outlet pressure, flow, case drain temperature, and diagnostic code. */
        subject subsystem : PumpingSubsystem;
        require constraint {
            subsystem.subsystemStatus.status.actualFlow >= 0.0 and
            subsystem.subsystemStatus.status.actualOutletPressure >= 0.0 and
            subsystem.subsystemStatus.status.caseDrainTemperature >= 273.15
        }
    }

    satisfy PumpTypeRequirement by PumpingSubsystem::axialPistonPump;
    satisfy FlowRequirement by PumpingSubsystem::flowSensor;
    satisfy PressureRequirement by PumpingSubsystem::controller;
    satisfy OverPressureProtectionRequirement by PumpingSubsystem::reliefValve;
    satisfy CaseDrainRequirement by PumpingSubsystem::axialPistonPump;
    satisfy TemperatureRequirement by PumpingSubsystem::axialPistonPump;
    satisfy FiltrationRequirement by PumpingSubsystem::pressureFilter;
    satisfy DrivePowerRequirement by PumpingSubsystem::driveMotor;
    satisfy InletPressureRequirement by PumpingSubsystem::controller;
    satisfy StatusReportingRequirement by PumpingSubsystem::controller;

    part pumpingSubsystem : PumpingSubsystem {
        attribute nominalSystemPressure = 21000000.0;
        attribute maximumSystemPressure = 30000000.0;
        attribute nominalDeliveredFlow = 0.0010;
        attribute minimumDeliveredFlow = 0.00085;
        attribute reservoirCapacity = 0.120;
        attribute normalFluidTemperature = 318.15;
        attribute maximumFluidTemperature = 353.15;
        attribute nominalInputPower = 15000.0;
    }
}