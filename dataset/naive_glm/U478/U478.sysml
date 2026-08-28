package AutomatedCentrifugalPumpingSubsystem {

    import ScalarValues::*;

    // ---- Value Types with Units ----
    value type Pressure :> Real { unit 'bar'; }
    value type FlowRate :> Real { unit 'L/min'; }
    value type RotationalSpeed :> Real { unit 'rpm'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Power :> Real { unit 'kW'; }
    value type Efficiency :> Real { unit '%'; }
    value type Temperature :> Real { unit 'degC'; }
    value type Length :> Real { unit 'm'; }
    value type Diameter :> Real { unit 'm'; }
    value type TimeValue :> Real { unit 'h'; }
    value type Torque :> Real { unit 'N.m'; }

    // ---- Item Types ----
    item def Fluid {
        attribute density : Real = 1000;   // kg/m3
        attribute viscosity : Real = 0.001; // Pa.s
        attribute temperature : Temperature;
    }

    item def PressureReading {
        attribute value : Pressure;
    }

    item def FlowRateReading {
        attribute value : FlowRate;
    }

    item def MotorCommandSignal {
        attribute targetSpeed : RotationalSpeed;
    }

    item def ElectricalEnergy {
        attribute voltage : Voltage;
        attribute current : Current;
    }

    item def MechanicalDrive {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
    }

    // ---- Port Definitions ----
    port def FluidFlowPort {
        out item fluid : Fluid;
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def MeasurementTapPort {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    port def PressureSignalPort {
        out item reading : PressureReading;
    }

    port def FlowRateSignalPort {
        out item reading : FlowRateReading;
    }

    port def MotorCommandPort {
        in item command : MotorCommandSignal;
    }

    port def ElectricalInputPort {
        in item power : ElectricalEnergy;
    }

    port def MechanicalOutputPort {
        out item drive : MechanicalDrive;
    }

    port def MechanicalInputPort {
        in item drive : MechanicalDrive;
    }

    // ---- Requirements ----
    requirement def MinFlowRateRequirement {
        subject subsystem : AutomatedPumpingSubsystem;
        doc /* The subsystem shall deliver a minimum flow rate of 50 L/min at the discharge point. */
        requirement minFlow {
            assert { subsystem.measuredDischargeFlowRate >= 50 }
        }
    }

    requirement def DischargePressureRangeRequirement {
        subject subsystem : AutomatedPumpingSubsystem;
        doc /* The subsystem shall maintain discharge pressure between 2 and 5 bar. */
        requirement pressureRange {
            assert { subsystem.measuredDischargePressure >= 2 and subsystem.measuredDischargePressure <= 5 }
        }
    }

    requirement def EnergyEfficiencyRequirement {
        subject subsystem : AutomatedPumpingSubsystem;
        doc /* The subsystem shall operate with at least 75% overall energy efficiency. */
        requirement efficiency {
            assert { subsystem.overallEfficiency >= 75 }
        }
    }

    requirement def ReliabilityRequirement {
        subject subsystem : AutomatedPumpingSubsystem;
        doc /* The subsystem shall have a mean time between failures of at least 10000 hours. */
        requirement mtbf {
            assert { subsystem.mtbf >= 10000 }
        }
    }

    requirement def ResponseTimeRequirement {
        subject subsystem : AutomatedPumpingSubsystem;
        doc /* The controller shall adjust motor speed within 2 seconds of a pressure deviation. */
        requirement responseTime {
            assert { subsystem.controller.responseTime <= 2.0 }
        }
    }

    // ---- Component Part Definitions ----

    part def SourceReservoir {
        port fluidOut : FluidFlowPort;
        attribute fluidLevel : Real = 80;   // %
        attribute maxCapacity : Real = 500; // L
        attribute ambientPressure : Pressure = 1.013;
    }

    part def SuctionPiping {
        port fluidIn : FluidFlowPort;
        port fluidOut : FluidFlowPort;
        attribute length : Length = 2.0;
        attribute diameter : Diameter = 0.05;
        attribute frictionLoss : Pressure = 0.1;
    }

    part def CentrifugalPump {
        port fluidIn : FluidFlowPort;
        port fluidOut : FluidFlowPort;
        port mechanicalIn : MechanicalInputPort;

        attribute impellerDiameter : Diameter = 0.1;
        attribute ratedSpeed : RotationalSpeed = 2900;
        attribute currentSpeed : RotationalSpeed;
        attribute currentDischargePressure : Pressure;
        attribute currentFlowRate : FlowRate;
        attribute pumpEfficiency : Efficiency = 80;

        action def PumpOperation {
            in rotationalSpeed : RotationalSpeed;
            in suctionPressure : Pressure;
            out dischargePressure : Pressure;
            out dischargeFlowRate : FlowRate;

            private attribute speedRatio : Real = rotationalSpeed / 2900;
            private attribute generatedHead : Pressure = speedRatio * speedRatio * 4.0;
            private attribute generatedFlow : FlowRate = speedRatio * 100.0;

            // Output computation
            assign dischargePressure : Pressure = suctionPressure + generatedHead;
            assign dischargeFlowRate : FlowRate = generatedFlow;
        }

        action operate : PumpOperation {
            in rotationalSpeed = currentSpeed;
            in suctionPressure = fluidIn.pressure;
            out dischargePressure = currentDischargePressure;
            out dischargeFlowRate = currentFlowRate;
        }
    }

    part def ElectricMotor {
        port electricalIn : ElectricalInputPort;
        port mechanicalOut : MechanicalOutputPort;
        port commandIn : MotorCommandPort;

        attribute ratedPower : Power = 5.5;
        attribute ratedSpeed : RotationalSpeed = 2900;
        attribute currentSpeed : RotationalSpeed;
        attribute motorEfficiency : Efficiency = 90;
        attribute currentTorque : Torque;

        action def MotorOperation {
            in targetSpeed : RotationalSpeed;
            in inputVoltage : Voltage;
            in inputCurrent : Current;
            out outputSpeed : RotationalSpeed;
            out outputTorque : Torque;

            private attribute speedRampRate : Real = 500.0; // rpm/s
            private attribute powerInput : Power = inputVoltage * inputCurrent / 1000.0;
            private attribute powerOutput : Power = powerInput * 0.9;

            assign outputSpeed : RotationalSpeed = targetSpeed;
            assign outputTorque : Torque = powerOutput * 1000 / (targetSpeed * 2 * 3.14159 / 60);
        }

        action operate : MotorOperation {
            in targetSpeed = commandIn.command.targetSpeed;
            in inputVoltage = electricalIn.power.voltage;
            in inputCurrent = electricalIn.power.current;
            out outputSpeed = currentSpeed;
            out outputTorque = currentTorque;
        }
    }

    part def DischargePiping {
        port fluidIn : FluidFlowPort;
        port fluidOut : FluidFlowPort;
        port measurementTap : MeasurementTapPort;

        attribute length : Length = 5.0;
        attribute diameter : Diameter = 0.04;
        attribute frictionLoss : Pressure = 0.2;

        // The measurement tap reflects the fluid state at the discharge piping
        assign measurementTap.pressure : Pressure = fluidIn.pressure - frictionLoss;
        assign measurementTap.flowRate : FlowRate = fluidIn.flowRate;
    }

    part def PressureSensor {
        port measurementTap : MeasurementTapPort;
        port signalOut : PressureSignalPort;

        attribute measurementRange : Pressure = 10.0;
        attribute accuracy : Real = 0.5; // % FS
        attribute currentReading : Pressure;

        action def MeasurePressure {
            in tapPressure : Pressure;
            out reading : PressureReading;

            assign reading.value : Pressure = tapPressure;
        }

        action measure : MeasurePressure {
            in tapPressure = measurementTap.pressure;
            out reading = signalOut.reading;
        }
    }

    part def FlowMeter {
        port measurementTap : MeasurementTapPort;
        port signalOut : FlowRateSignalPort;

        attribute measurementRange : FlowRate = 200.0;
        attribute accuracy : Real = 1.0; // % FS
        attribute currentReading : FlowRate;

        action def MeasureFlowRate {
            in tapFlowRate : FlowRate;
            out reading : FlowRateReading;

            assign reading.value : FlowRate = tapFlowRate;
        }

        action measure : MeasureFlowRate {
            in tapFlowRate = measurementTap.flowRate;
            out reading = signalOut.reading;
        }
    }

    part def Controller {
        port pressureIn : PressureSignalPort;
        port flowRateIn : FlowRateSignalPort;
        port commandOut : MotorCommandPort;

        attribute targetPressure : Pressure = 3.5;
        attribute targetFlowRate : FlowRate = 75.0;
        attribute pressureLowThreshold : Pressure = 2.0;
        attribute pressureHighThreshold : Pressure = 5.0;
        attribute deadBand : Pressure = 0.2;
        attribute proportionalGain : Real = 100.0;
        attribute integralGain : Real = 10.0;
        attribute integralError : Real = 0.0;
        attribute currentCommand : RotationalSpeed = 2900;
        attribute responseTime : Real = 1.5; // s
        attribute measuredPressure : Pressure;
        attribute measuredFlowRate : FlowRate;

        action def ControlComputation {
            in measuredPressure : Pressure;
            in measuredFlowRate : FlowRate;
            in targetPressure : Pressure;
            in targetFlowRate : FlowRate;
            out motorCommand : MotorCommandSignal;

            private attribute pressureError : Real = targetPressure - measuredPressure;
            private attribute flowError : Real = targetFlowRate - measuredFlowRate;
            private attribute speedAdjustment : Real = proportionalGain * pressureError + integralGain * flowError;
            private attribute computedSpeed : Real = 2900.0 + speedAdjustment;

            assign motorCommand.targetSpeed : RotationalSpeed = computedSpeed;
        }

        action compute : ControlComputation {
            in measuredPressure = pressureIn.reading.value;
            in measuredFlowRate = flowRateIn.reading.value;
            in targetPressure = targetPressure;
            in targetFlowRate = targetFlowRate;
            out motorCommand = commandOut.command;
        }

        state machine def ControlStateMachine {
            attribute speed : RotationalSpeed;
            attribute pressure : Pressure;
            attribute target : Pressure;

            state Idle {
                entry action { speed = 0; }
                transition to Starting
                    first if (pressure > 0) then Starting;
            }

            state Starting {
                entry action { speed = 500; }
                transition to Running
                    first if (speed >= 500) then Running;
            }

            state Running {
                entry action { speed = 2900; }

                transition to IncreasingPressure
                    first if (pressure < target - 0.2) then IncreasingPressure;

                transition to DecreasingPressure
                    first if (pressure > target + 0.2) then DecreasingPressure;
            }

            state IncreasingPressure {
                entry action { speed = speed + 50; }
                transition to Running
                    first if (pressure >= target - 0.1) then Running;
            }

            state DecreasingPressure {
                entry action { speed = speed - 50; }
                transition to Running
                    first if (pressure <= target + 0.1) then Running;
            }

            state Fault {
                entry action { speed = 0; }
                transition to Idle
                    first if (resetSignal) then Idle;
            }

            transition Running to Fault
                first if (pressure > 6.0 or pressure < 0.5) then Fault;
        }

        state machine controlBehavior : ControlStateMachine {
            attribute speed = currentCommand;
            attribute pressure = measuredPressure;
            attribute target = targetPressure;
        }
    }

    part def DischargePoint {
        port fluidIn : FluidFlowPort;
        attribute elevation : Length = 10.0;
        attribute backPressure : Pressure = 1.0;
    }

    // ---- Top-Level Subsystem ----
    part def AutomatedPumpingSubsystem {
        attribute measuredDischargePressure : Pressure;
        attribute measuredDischargeFlowRate : FlowRate;
        attribute overallEfficiency : Efficiency = 78;
        attribute mtbf : TimeValue = 12000;

        part sourceReservoir : SourceReservoir {
            port fluidOut : FluidFlowPort;
        }

        part suctionPiping : SuctionPiping {
            port fluidIn : FluidFlowPort;
            port fluidOut : FluidFlowPort;
        }

        part centrifugalPump : CentrifugalPump {
            port fluidIn : FluidFlowPort;
            port fluidOut : FluidFlowPort;
            port mechanicalIn : MechanicalInputPort;
        }

        part electricMotor : ElectricMotor {
            port electricalIn : ElectricalInputPort;
            port mechanicalOut : MechanicalOutputPort;
            port commandIn : MotorCommandPort;
        }

        part dischargePiping : DischargePiping {
            port fluidIn : FluidFlowPort;
            port fluidOut : FluidFlowPort;
            port measurementTap : MeasurementTapPort;
        }

        part pressureSensor : PressureSensor {
            port measurementTap : MeasurementTapPort;
            port signalOut : PressureSignalPort;
        }

        part flowMeter : FlowMeter {
            port measurementTap : MeasurementTapPort;
            port signalOut : FlowRateSignalPort;
        }

        part controller : Controller {
            port pressureIn : PressureSignalPort;
            port flowRateIn : FlowRateSignalPort;
            port commandOut : MotorCommandPort;
        }

        part dischargePoint : DischargePoint {
            port fluidIn : FluidFlowPort;
        }

        // ---- Fluid Connections ----
        connection fluidSourceToSuction connect sourceReservoir.fluidOut to suctionPiping.fluidIn;
        connection fluidSuctionToPump connect suctionPiping.fluidOut to centrifugalPump.fluidIn;
        connection fluidPumpToDischarge connect centrifugalPump.fluidOut to dischargePiping.fluidIn;
        connection fluidDischargeToOutlet connect dischargePiping.fluidOut to dischargePoint.fluidIn;

        // ---- Measurement Tap Connections ----
        connection pressureTap connect dischargePiping.measurementTap to pressureSensor.measurementTap;
        connection flowTap connect dischargePiping.measurementTap to flowMeter.measurementTap;

        // ---- Signal Connections ----
        connection pressureFeedback connect pressureSensor.signalOut to controller.pressureIn;
        connection flowRateFeedback connect flowMeter.signalOut to controller.flowRateIn;
        connection motorControlCommand connect controller.commandOut to electricMotor.commandIn;

        // ---- Mechanical Connection ----
        connection mechanicalDrive connect electricMotor.mechanicalOut to centrifugalPump.mechanicalIn;

        // ---- Bindings for subsystem-level attributes ----
        bind measuredDischargePressure : Pressure = dischargePiping.measurementTap.pressure;
        bind measuredDischargeFlowRate : FlowRate = dischargePiping.measurementTap.flowRate;

        // ---- Requirements Satisfaction ----
        satisfy MinFlowRateRequirement by AutomatedPumpingSubsystem;
        satisfy DischargePressureRangeRequirement by AutomatedPumpingSubsystem;
        satisfy EnergyEfficiencyRequirement by AutomatedPumpingSubsystem;
        satisfy ReliabilityRequirement by AutomatedPumpingSubsystem;
        satisfy ResponseTimeRequirement by AutomatedPumpingSubsystem;
    }

    // ---- Package-level instantiation for verification ----
    part pumpingSubsystemInstance : AutomatedPumpingSubsystem;
}
