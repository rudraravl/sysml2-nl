package PumpingSubsystem {
    import ISQ::*;
    import ScalarValues::*;

    item def Fluid;

    value type PressureValue :> Real { unit "Pa"; }
    value type FlowRateValue :> Real { unit "m^3/s"; }
    value type VolumeValue :> Real { unit "m^3"; }
    value type RotationalSpeedValue :> Real { unit "rad/s"; }
    value type TorqueValue :> Real { unit "N*m"; }
    value type PowerValue :> Real { unit "W"; }
    value type VoltageValue :> Real { unit "V"; }
    value type CurrentValue :> Real { unit "A"; }
    value type EfficiencyValue :> Real { unit "1"; }
    value type ProbabilityValue :> Real { unit "1"; }
    value type DurationValue :> Real { unit "s"; }

    attribute def PressureReading {
        in pressure : PressureValue;
    }
    attribute def FlowReading {
        in flowRate : FlowRateValue;
    }
    attribute def MotorCommand {
        out speed : RotationalSpeedValue;
        out power : PowerValue;
    }
    attribute def FlowSetpoint {
        in desiredFlowRate : FlowRateValue;
    }
    attribute def FaultSignal {
        in code : Integer;
        in description : String;
    }

    port def FluidPort {
        out item fluidOut : Fluid;
        in item fluidIn : Fluid;
    }
    port def PressureSignalPort {
        out reading : PressureReading;
    }
    port def FlowSignalPort {
        out reading : FlowReading;
    }
    port def MotorCommandPort {
        out command : MotorCommand;
    }
    port def FlowSetpointPort {
        in setpoint : FlowSetpoint;
    }
    port def RotationalDrivePort {
        out speed : RotationalSpeedValue;
        out torque : TorqueValue;
    }
    port def FaultPort {
        out fault : FaultSignal;
    }

    part def Reservoir {
        port fluidPort : FluidPort;
        attribute storedVolume : VolumeValue := 0.0 [m^3];
        attribute capacity : VolumeValue := 1.0 [m^3];
    }

    part def Pipe {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute length : Real := 1.0;
        attribute diameter : Real := 0.05;
        flow through fluidFlow : Fluid from inlet.fluidIn to outlet.fluidOut;
    }

    part def DischargePoint {
        port fluidPort : FluidPort;
        attribute label : String;
    }

    part def PumpHousing {
        port inlet : FluidPort;
        port outlet : FluidPort;
        attribute material : String := "stainless steel";
        flow through internalFlow : Fluid from inlet.fluidIn to outlet.fluidOut;
    }

    part def Impeller {
        port drivePort : RotationalDrivePort;
        attribute bladeCount : Integer := 7;
        attribute nominalDiameter : Real := 0.1;
    }

    part def ElectricMotor {
        port commandPort : MotorCommandPort;
        port shaftPort : RotationalDrivePort;
        attribute supplyVoltage : VoltageValue := 24.0 [V];
        attribute maxPower : PowerValue := 500.0 [W];
        attribute currentSpeed : RotationalSpeedValue := 0.0 [rad/s];
        attribute currentTorque : TorqueValue := 0.0 [N*m];

        action def ApplyCommand {
            in cmd : MotorCommand;
            then set currentSpeed := cmd.speed;
            then set currentTorque := cmd.power / (if currentSpeed > 0.0 [rad/s] then currentSpeed else 1.0 [rad/s]);
            then send {speed = currentSpeed, torque = currentTorque} over shaftPort;
        }

        action applyCommand : ApplyCommand {
            in cmd = commandPort.command;
        }
    }

    part def PressureSensor {
        port fluidPort : FluidPort;
        port signalPort : PressureSignalPort;
        attribute measuredPressure : PressureValue := 0.0 [Pa];
        attribute accuracy : Real := 0.01;

        action def SamplePressure {
            then set measuredPressure := /* sensed pressure */ 0.0 [Pa];
            then send {pressure = measuredPressure} over signalPort;
        }

        action sample : SamplePressure;
    }

    part def FlowSensor {
        port fluidPort : FluidPort;
        port signalPort : FlowSignalPort;
        attribute measuredFlowRate : FlowRateValue := 0.0 [m^3/s];
        attribute accuracy : Real := 0.005;

        action def SampleFlow {
            then set measuredFlowRate := /* sensed flow */ 0.0 [m^3/s];
            then send {flowRate = measuredFlowRate} over signalPort;
        }

        action sample : SampleFlow;
    }

    part def PumpController {
        port setpointPort : FlowSetpointPort;
        port inletPressurePort : PressureSignalPort;
        port outletPressurePort : PressureSignalPort;
        port flowPort : FlowSignalPort;
        port motorCommandPort : MotorCommandPort;
        port faultPort : FaultPort;

        attribute setpoint : FlowRateValue := 0.0 [m^3/s];
        attribute measuredFlow : FlowRateValue := 0.0 [m^3/s];
        attribute measuredInletPressure : PressureValue := 0.0 [Pa];
        attribute measuredOutletPressure : PressureValue := 0.0 [Pa];
        attribute primingThreshold : PressureValue := 10000.0 [Pa];
        attribute minOutletPressure : PressureValue := 150000.0 [Pa];
        attribute maxSpeed : RotationalSpeedValue := 1000.0 [rad/s];
        attribute faultDetected : Boolean := false;
        attribute resetCommand : Boolean := false;

        action def ReadSensors {
            then set measuredInletPressure := inletPressurePort.reading.pressure;
            then set measuredOutletPressure := outletPressurePort.reading.pressure;
            then set measuredFlow := flowPort.reading.flowRate;
        }

        action def ComputeControl {
            attribute error : FlowRateValue;
            attribute cmdSpeed : RotationalSpeedValue;
            attribute cmdPower : PowerValue;
            then set error := setpoint - measuredFlow;
            then set cmdSpeed := max(0.0 [rad/s], min(maxSpeed, maxSpeed * (setpoint / 0.001 [m^3/s]) + error * 1000.0));
            then set cmdPower := 200.0 [W] + error * 500000.0;
            then send {speed = cmdSpeed, power = cmdPower} over motorCommandPort;
        }

        action def CheckFaults {
            then if measuredOutletPressure < minOutletPressure and setpoint > 0.0 [m^3/s] then set faultDetected := true;
            then if measuredFlow < 0.0 [m^3/s] then set faultDetected := true;
            then if faultDetected then send {code = 1, description = "Pressure/flow fault"} over faultPort;
        }

        action readSensors : ReadSensors;
        action computeControl : ComputeControl;
        action checkFaults : CheckFaults;

        state machine PumpStates {
            state off {
                entry action { send {speed = 0.0 [rad/s], power = 0.0 [W]} over motorCommandPort; }
            }
            state starting {
                state priming {
                    entry action { send {speed = 50.0 [rad/s], power = 50.0 [W]} over motorCommandPort; }
                }
                state accelerating {
                    entry action { send {speed = 500.0 [rad/s], power = 300.0 [W]} over motorCommandPort; }
                }
                transition priming_to_accelerating: priming -> accelerating
                    when (measuredInletPressure >= primingThreshold);
            }
            state running {
                entry action { computeControl; }
                do action { readSensors; then computeControl; then checkFaults; }
            }
            state stopping {
                entry action { send {speed = 0.0 [rad/s], power = 0.0 [W]} over motorCommandPort; }
            }
            state fault {
                entry action { send {speed = 0.0 [rad/s], power = 0.0 [W]} over motorCommandPort; }
            }

            transition off_to_starting: off -> starting
                when (setpoint > 0.0 [m^3/s]);
            transition starting_to_running: starting -> running
                when (measuredFlow >= setpoint * 0.95);
            transition running_to_stopping: running -> stopping
                when (setpoint == 0.0 [m^3/s]);
            transition stopping_to_off: stopping -> off
                when (measuredFlow == 0.0 [m^3/s]);
            transition running_to_fault: running -> fault
                when (faultDetected);
            transition starting_to_fault: starting -> fault
                when (faultDetected);
            transition fault_to_off: fault -> off
                when (resetCommand);
        }
    }

    part def PumpDispenser {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port setpointPort : FlowSetpointPort;
        port faultPort : FaultPort;

        part housing : PumpHousing {
            port inlet = PumpDispenser::inlet;
            port outlet = PumpDispenser::outlet;
        }
        part impeller : Impeller;
        part motor : ElectricMotor;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : PumpController {
            port setpointPort = PumpDispenser::setpointPort;
            port faultPort = PumpDispenser::faultPort;
        }

        connection motorShaftToImpeller : RotationalDrivePort
            connect motor.shaftPort to impeller.drivePort;
        connection inletPressureSense : FluidPort
            connect housing.inlet to inletPressureSensor.fluidPort;
        connection outletPressureSense : FluidPort
            connect housing.outlet to outletPressureSensor.fluidPort;
        connection flowSense : FluidPort
            connect housing.outlet to flowSensor.fluidPort;
        connection inletPressureSignal : PressureSignalPort
            connect inletPressureSensor.signalPort to controller.inletPressurePort;
        connection outletPressureSignal : PressureSignalPort
            connect outletPressureSensor.signalPort to controller.outletPressurePort;
        connection flowSignal : FlowSignalPort
            connect flowSensor.signalPort to controller.flowPort;
        connection motorCommandLink : MotorCommandPort
            connect controller.motorCommandPort to motor.commandPort;

        flow through pumpedFluid : Fluid from inlet.fluidIn to outlet.fluidOut;
    }

    part def PumpingSystem {
        part sourceReservoir : Reservoir {
            attribute storedVolume := 0.8 [m^3];
        }
        part supplyPipe : Pipe {
            attribute length := 2.0;
            attribute diameter := 0.05;
        }
        part pumpDispenser : PumpDispenser;
        part dischargePipe : Pipe {
            attribute length := 3.0;
            attribute diameter := 0.04;
        }
        part destinationPoint : DischargePoint {
            attribute label := "Process Inlet";
        }

        connection sourceToSupply : FluidPort
            connect sourceReservoir.fluidPort to supplyPipe.inlet;
        connection supplyToPump : FluidPort
            connect supplyPipe.outlet to pumpDispenser.inlet;
        connection pumpToDischarge : FluidPort
            connect pumpDispenser.outlet to dischargePipe.inlet;
        connection dischargeToDestination : FluidPort
            connect dischargePipe.outlet to destinationPoint.fluidPort;
    }

    requirement def FlowRatePrecisionRequirement {
        doc "The pump shall deliver fluid at the commanded flow rate within a specified tolerance.";
        attribute commandedFlowRate : FlowRateValue;
        attribute tolerance : Real := 0.02;
        require { |pumpDispenser.controller.measuredFlow - commandedFlowRate| <= commandedFlowRate * tolerance }
    }

    requirement def MinimumOutletPressureRequirement {
        doc "The pump shall maintain at least the minimum outlet pressure during running operation.";
        attribute minPressure : PressureValue := 150000.0 [Pa];
        require { pumpDispenser.controller.measuredOutletPressure >= minPressure }
    }

    requirement def ReliabilityRequirement {
        doc "The pump subsystem shall achieve a minimum mean time between failures.";
        attribute mtbf : DurationValue := 20000.0 [s];
        attribute reliability : ProbabilityValue := 0.99;
        require { reliability >= 0.99 }
    }

    requirement def EfficiencyRequirement {
        doc "The pump shall operate above a minimum hydraulic efficiency under nominal load.";
        attribute minEfficiency : EfficiencyValue := 0.65;
        attribute hydraulicPower : PowerValue;
        attribute electricalPower : PowerValue;
        require { hydraulicPower / electricalPower >= minEfficiency }
    }

    requirement def PumpingSubsystemRequirements {
        requirement flowPrecision : FlowRatePrecisionRequirement {
            attribute commandedFlowRate := 0.001 [m^3/s];
        }
        requirement minOutletPressure : MinimumOutletPressureRequirement;
        requirement reliability : ReliabilityRequirement;
        requirement efficiency : EfficiencyRequirement;
    }

    part def PumpingSystemWithRequirements :> PumpingSystem {
        satisfy PumpingSubsystemRequirements;
    }
}
