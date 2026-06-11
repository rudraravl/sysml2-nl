package PumpingSubsystem_JabscoModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = "kPa";
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = "L/min";
    }

    attribute def Volume :> ISQ::volume {
        unit = "L";
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = "degC";
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = "V";
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = "A";
    }

    attribute def Power :> ISQ::power {
        unit = "W";
    }

    attribute def RotationalSpeed {
        :>> scalarType = Real;
        unit = "rpm";
    }

    attribute def Efficiency {
        :>> scalarType = Real;
        unit = "1";
    }

    item def WaterBasedFluid {
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute contaminationLevel : Real;
    }

    item def DC_ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    port def FluidPort {
        inout item fluid : WaterBasedFluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def ElectricalPowerPort {
        in item supply : DC_ElectricalPower;
        attribute voltage : Voltage;
        attribute current : Current;
    }

    port def ControlPort {
        in attribute enableCommand : Boolean;
        in attribute speedCommand : RotationalSpeed;
        out attribute runningStatus : Boolean;
        out attribute faultStatus : Boolean;
    }

    port def DiagnosticPort {
        out attribute inletPressure : Pressure;
        out attribute outletPressure : Pressure;
        out attribute deliveredFlow : FlowRate;
        out attribute motorCurrent : Current;
        out attribute faultCode : Integer;
    }

    part def FluidReservoir {
        attribute usableVolume : Volume = 60 [L];
        attribute minimumOperatingVolume : Volume = 5 [L];

        port outlet : FluidPort;
        port returnInlet : FluidPort;
    }

    part def InletStrainer {
        attribute meshSizeMicron : Real = 50;
        attribute maximumDifferentialPressure : Pressure = 35 [kPa];

        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def IsolationValve {
        attribute open : Boolean = true;
        attribute nominalDiameter : Real = 12.7;

        port upstream : FluidPort;
        port downstream : FluidPort;
    }

    part def CheckValve {
        attribute crackingPressure : Pressure = 7 [kPa];
        attribute reverseLeakageFlow : FlowRate = 0.05 [L/min];

        port inlet : FluidPort;
        port outlet : FluidPort;
    }

    part def PressureReliefValve {
        attribute setPressure : Pressure = 280 [kPa];
        attribute reseatPressure : Pressure = 240 [kPa];

        port inlet : FluidPort;
        port bypassOutlet : FluidPort;
    }

    part def OutletManifold {
        attribute internalVolume : Volume = 0.25 [L];

        port pumpInlet : FluidPort;
        port userOutlet : FluidPort;
        port bypassReturn : FluidPort;
        port pressureSense : FluidPort;
    }

    part def PressureSensor {
        attribute rangeMin : Pressure = 0 [kPa];
        attribute rangeMax : Pressure = 500 [kPa];
        attribute measuredPressure : Pressure;

        port sensingPort : FluidPort;
        port diagnostics : DiagnosticPort;
    }

    part def FlowSensor {
        attribute rangeMin : FlowRate = 0 [L/min];
        attribute rangeMax : FlowRate = 25 [L/min];
        attribute measuredFlow : FlowRate;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port diagnostics : DiagnosticPort;
    }

    part def DCBrushMotor {
        attribute nominalVoltage : Voltage = 12 [V];
        attribute noLoadCurrent : Current = 1.2 [A];
        attribute maximumCurrent : Current = 18 [A];
        attribute shaftSpeed : RotationalSpeed;
        attribute electricalEfficiency : Efficiency = 0.78;

        port powerInput : ElectricalPowerPort;
    }

    part def JabscoDiaphragmPump {
        attribute manufacturer : String = "Jabsco";
        attribute pumpTechnology : String = "Flexible diaphragm positive displacement";
        attribute nominalVoltage : Voltage = 12 [V];
        attribute ratedFlow : FlowRate = 17 [L/min];
        attribute maximumPressure : Pressure = 280 [kPa];
        attribute dryRunAllowed : Boolean = true;
        attribute selfPrimingHeight : Real = 2.4;
        attribute hydraulicEfficiency : Efficiency = 0.62;
        attribute commandedSpeed : RotationalSpeed;
        attribute actualSpeed : RotationalSpeed;
        attribute deliveredFlow : FlowRate;
        attribute differentialPressure : Pressure;
        attribute faulted : Boolean;

        part motor : DCBrushMotor;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port power : ElectricalPowerPort;
        port control : ControlPort;
        port diagnostics : DiagnosticPort;

        connect power to motor.powerInput;

        state pumpController {
            entry; then off;

            state off {
                entry action {
                    actualSpeed = 0 [rpm];
                    deliveredFlow = 0 [L/min];
                    control.runningStatus = false;
                    control.faultStatus = false;
                }

                transition first off_to_starting
                    accept control.enableCommand
                    if control.enableCommand == true
                    then starting;
            }

            state starting {
                entry action {
                    commandedSpeed = control.speedCommand;
                    control.runningStatus = true;
                }

                transition starting_to_running
                    if power.voltage >= 10.5 [V] and inlet.pressure > -35 [kPa]
                    then running;

                transition starting_to_fault
                    if power.voltage < 10.5 [V] or inlet.pressure <= -35 [kPa]
                    then fault;
            }

            state running {
                do action regulatePump {
                    commandedSpeed = control.speedCommand;
                    actualSpeed = commandedSpeed;
                    deliveredFlow = ratedFlow * actualSpeed / 3000 [rpm];
                    differentialPressure = outlet.pressure - inlet.pressure;
                    diagnostics.deliveredFlow = deliveredFlow;
                    diagnostics.inletPressure = inlet.pressure;
                    diagnostics.outletPressure = outlet.pressure;
                    diagnostics.motorCurrent = power.current;
                }

                transition running_to_off
                    accept control.enableCommand
                    if control.enableCommand == false
                    then off;

                transition running_to_fault_overpressure
                    if outlet.pressure > maximumPressure
                    then fault;

                transition running_to_fault_overcurrent
                    if power.current > motor.maximumCurrent
                    then fault;
            }

            state fault {
                entry action {
                    actualSpeed = 0 [rpm];
                    deliveredFlow = 0 [L/min];
                    faulted = true;
                    control.runningStatus = false;
                    control.faultStatus = true;
                    diagnostics.faultCode = 1;
                }

                transition fault_to_off
                    accept control.enableCommand
                    if control.enableCommand == false
                    then off;
            }
        }
    }

    action def PrimePump {
        in pump : JabscoDiaphragmPump;
        out primed : Boolean;

        first startPrime;
        action startPrime {
            pump.control.enableCommand = true;
            pump.control.speedCommand = 1800 [rpm];
        }
        then verifySuction;
        action verifySuction {
            primed = pump.inlet.pressure > -35 [kPa] and pump.deliveredFlow > 1 [L/min];
        }
    }

    action def DeliverFluid {
        in pump : JabscoDiaphragmPump;
        in requestedFlow : FlowRate;
        out achievedFlow : FlowRate;

        first commandFlow;
        action commandFlow {
            pump.control.enableCommand = true;
            pump.control.speedCommand = requestedFlow / pump.ratedFlow * 3000 [rpm];
        }
        then monitorFlow;
        action monitorFlow {
            achievedFlow = pump.deliveredFlow;
        }
    }

    action def ShutdownPump {
        in pump : JabscoDiaphragmPump;

        first stopMotor;
        action stopMotor {
            pump.control.enableCommand = false;
            pump.control.speedCommand = 0 [rpm];
        }
    }

    requirement def PumpingSubsystemRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.jabscoPump.ratedFlow >= 15 [L/min]
        }

        require constraint {
            subsystem.jabscoPump.maximumPressure >= 250 [kPa]
        }

        require constraint {
            subsystem.jabscoPump.nominalVoltage == 12 [V]
        }

        require constraint {
            subsystem.outletPressureSensor.measuredPressure <= 500 [kPa]
        }
    }

    requirement def DryRunToleranceRequirement {
        subject pump : JabscoDiaphragmPump;

        require constraint {
            pump.dryRunAllowed == true
        }
    }

    requirement def OverPressureProtectionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.reliefValve.setPressure <= subsystem.jabscoPump.maximumPressure
        }
    }

    requirement def ReverseFlowPreventionRequirement {
        subject subsystem : PumpingSubsystem;

        require constraint {
            subsystem.dischargeCheckValve.reverseLeakageFlow <= 0.1 [L/min]
        }
    }

    part def PumpingSubsystem {
        attribute designFlow : FlowRate = 17 [L/min];
        attribute designOutletPressure : Pressure = 240 [kPa];
        attribute supplyVoltage : Voltage = 12 [V];
        attribute maximumAllowedFluidTemperature : Temperature = 60 [degC];

        part reservoir : FluidReservoir;
        part suctionValve : IsolationValve;
        part inletStrainer : InletStrainer;
        part jabscoPump : JabscoDiaphragmPump;
        part dischargeCheckValve : CheckValve;
        part outletFlowSensor : FlowSensor;
        part outletManifold : OutletManifold;
        part reliefValve : PressureReliefValve;
        part outletPressureSensor : PressureSensor;

        port fluidSource : FluidPort;
        port fluidDelivery : FluidPort;
        port electricalSupply : ElectricalPowerPort;
        port controllerInterface : ControlPort;
        port maintenanceDiagnostics : DiagnosticPort;

        connect fluidSource to reservoir.returnInlet;
        connect reservoir.outlet to suctionValve.upstream;
        connect suctionValve.downstream to inletStrainer.inlet;
        connect inletStrainer.outlet to jabscoPump.inlet;
        connect jabscoPump.outlet to dischargeCheckValve.inlet;
        connect dischargeCheckValve.outlet to outletFlowSensor.inlet;
        connect outletFlowSensor.outlet to outletManifold.pumpInlet;
        connect outletManifold.userOutlet to fluidDelivery;
        connect outletManifold.bypassReturn to reliefValve.inlet;
        connect reliefValve.bypassOutlet to reservoir.returnInlet;
        connect outletManifold.pressureSense to outletPressureSensor.sensingPort;

        connect electricalSupply to jabscoPump.power;
        connect controllerInterface to jabscoPump.control;
        connect jabscoPump.diagnostics to maintenanceDiagnostics;
        connect outletFlowSensor.diagnostics to maintenanceDiagnostics;
        connect outletPressureSensor.diagnostics to maintenanceDiagnostics;

        perform action normalDelivery : DeliverFluid {
            in pump = jabscoPump;
            in requestedFlow = designFlow;
            out achievedFlow;
        }

        perform action shutdown : ShutdownPump {
            in pump = jabscoPump;
        }

        satisfy PumpingSubsystemRequirement by PumpingSubsystem;
        satisfy OverPressureProtectionRequirement by PumpingSubsystem;
        satisfy ReverseFlowPreventionRequirement by PumpingSubsystem;
        satisfy DryRunToleranceRequirement by jabscoPump;
    }

    part pumpingSubsystem : PumpingSubsystem {
        :>> reservoir.usableVolume = 60 [L];
        :>> suctionValve.open = true;
        :>> inletStrainer.maximumDifferentialPressure = 35 [kPa];
        :>> jabscoPump.ratedFlow = 17 [L/min];
        :>> jabscoPump.maximumPressure = 280 [kPa];
        :>> dischargeCheckValve.crackingPressure = 7 [kPa];
        :>> reliefValve.setPressure = 270 [kPa];
        :>> outletPressureSensor.rangeMax = 500 [kPa];
        :>> outletFlowSensor.rangeMax = 25 [L/min];
    }
}