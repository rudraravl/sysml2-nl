package IndustrialFluidPumpingSystem {
    import ScalarValues::*;

    // ---- Units ----
    unit mm;
    unit mL;
    unit L;
    unit L_per_min;
    unit kPa;
    unit rpm;
    unit Nm;
    unit V;
    unit A;
    unit degC;
    unit kg_per_L;
    unit mPa_s;

    // ---- Value types ----
    value type LengthValue :> Real { unit mm; }
    value type VolumeValue :> Real { unit L; }
    value type DisplacementValue :> Real { unit mL; }
    value type FlowRateValue :> Real { unit L_per_min; }
    value type PressureValue :> Real { unit kPa; }
    value type RotationalSpeedValue :> Real { unit rpm; }
    value type TorqueValue :> Real { unit Nm; }
    value type VoltageValue :> Real { unit V; }
    value type CurrentValue :> Real { unit A; }
    value type TemperatureValue :> Real { unit degC; }
    value type DensityValue :> Real { unit kg_per_L; }
    value type ViscosityValue :> Real { unit mPa_s; }

    // ---- Enumerations ----
    enumeration def MotorStatusType {
        value STOPPED = 0;
        value RUNNING = 1;
        value FAULT = 2;
    }

    enumeration def PumpStateType {
        value IDLE = 0;
        value PRIMING = 1;
        value NORMAL_OPERATING = 2;
        value PRESSURE_RELIEF = 3;
        value SHUTDOWN = 4;
        value FAULT = 5;
    }

    // ---- Items ----
    item def Fluid {
        attribute density : DensityValue;
        attribute viscosity : ViscosityValue;
        attribute temperature : TemperatureValue;
    }

    item def PumpingFluid :> Fluid {
        attribute density = 0.9 [kg_per_L];
        attribute viscosity = 50 [mPa_s];
        attribute temperature = 25 [degC];
    }

    item def Air;

    item def SpeedCommand {
        attribute commandedSpeed : RotationalSpeedValue;
    }

    item def SpeedFeedback {
        attribute actualSpeed : RotationalSpeedValue;
        attribute status : MotorStatusType;
    }

    item def PressureReading {
        attribute pressure : PressureValue;
    }

    item def FlowReading {
        attribute flowRate : FlowRateValue;
    }

    item def ControlCommand {
        attribute start : Boolean;
        attribute stop : Boolean;
        attribute reset : Boolean;
    }

    item def FaultSignal {
        attribute code : Integer;
        attribute description : String;
    }

    // ---- Port definitions ----
    port def FluidPort {
        in out item fluid : Fluid;
        attribute pressure : PressureValue;
    }

    port def MechanicalPowerPort {
        attribute speed : RotationalSpeedValue;
        attribute torque : TorqueValue;
    }

    port def CommandPort {
        in item cmd : SpeedCommand;
    }

    port def FeedbackPort {
        out item feedback : SpeedFeedback;
    }

    port def PressureSignalPort {
        out item reading : PressureReading;
    }

    port def FlowSignalPort {
        out item reading : FlowReading;
    }

    port def ControlSignalPort {
        in item command : ControlCommand;
        out item fault : FaultSignal;
    }

    // ---- Action definitions ----
    action def IdleStandby {
        doc /* Maintain motor stopped while monitoring for operator commands. */;
    }

    action def PrimePump {
        doc /* Operate pump at low speed to fill the chamber and purge trapped air. */;
    }

    action def OperatePump {
        doc /* Operate pump at nominal speed to transfer fluid from source to destination. */;
    }

    action def RelievePressure {
        doc /* Reduce motor speed and divert excess fluid through the relief valve in response to high outlet pressure. */;
    }

    action def ShutdownPump {
        doc /* Ramp motor speed to zero and secure the pumping process in an orderly manner. */;
    }

    action def HandleFault {
        doc /* Stop the motor, set fault status, and emit a fault signal for operator attention. */;
    }

    action def DrawFluid {
        doc /* Rotors unmesh at the inlet, creating expanding pockets that draw fluid into the pump. */;
    }

    action def CarryFluid {
        doc /* Captured fluid is carried around the periphery of the chamber in spaces between lobes and chamber wall. */;
    }

    action def DischargeFluid {
        doc /* Rotors mesh at the outlet, squeezing fluid out and discharging it at higher pressure. */;
    }

    action def RotateRotor {
        doc /* Rotate the two-lobed rotor in synchronized counter-rotation with the paired rotor. */;
    }

    action def RegulateSpeed {
        doc /* Adjust motor actual speed toward the commanded speed value. */;
    }

    action def SupplyFluid {
        doc /* Supply fluid from the reservoir to the pump inlet under suction. */;
    }

    action def ReceiveFluid {
        doc /* Accept discharged fluid into the destination receiver. */;
    }

    action def SensePressure {
        doc /* Measure fluid pressure at the sensing point and transmit a pressure reading. */;
    }

    action def MeasureFlow {
        doc /* Measure volumetric flow rate passing through the meter and transmit a flow reading. */;
    }

    action def RelieveValveOpen {
        doc /* Open the relief valve to divert excess fluid back to the source reservoir. */;
    }

    action def RelieveValveClose {
        doc /* Close the relief valve once pressure returns below the set point. */;
    }

    // ---- Part definitions ----

    part def LobeRotor {
        attribute lobeCount : Integer = 2;
        attribute clearance : LengthValue;
        attribute rotationalSpeed : RotationalSpeedValue;
        port mechanicalIn : MechanicalPowerPort;
        port mechanicalOut : MechanicalPowerPort;
        exhibit action rotate : RotateRotor;
    }

    part def PumpChamber {
        attribute internalClearance : LengthValue;
        attribute synchronized : Boolean;
        port inlet : FluidPort;
        port outlet : FluidPort;
        part drivingRotor : LobeRotor {
            attribute lobeCount = 2;
        }
        part drivenRotor : LobeRotor {
            attribute lobeCount = 2;
        }
        connection rotorSynchronization connect drivingRotor.mechanicalOut to drivenRotor.mechanicalIn;
    }

    part def Driveshaft {
        attribute length : LengthValue;
        attribute diameter : LengthValue;
        port input : MechanicalPowerPort;
        port output : MechanicalPowerPort;
    }

    part def LobePump {
        attribute displacement : DisplacementValue;
        attribute nominalSpeed : RotationalSpeedValue;
        attribute maxPressure : PressureValue;
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port driveInput : MechanicalPowerPort;

        part chamber : PumpChamber {
            attribute internalClearance = 0.1 [mm];
            attribute synchronized = true;
        }

        part driveShaft : Driveshaft {
            attribute length = 200 [mm];
            attribute diameter = 25 [mm];
        }

        connection driveShaftIn connect driveInput to driveShaft.input;
        connection shaftToRotor connect driveShaft.output to chamber.drivingRotor.mechanicalIn;
        connection inletToChamber connect inlet to chamber.inlet;
        connection outletFromChamber connect chamber.outlet to outlet;

        exhibit action drawFluid : DrawFluid;
        exhibit action carryFluid : CarryFluid;
        exhibit action dischargeFluid : DischargeFluid;
    }

    part def ElectricMotor {
        attribute nominalSpeed : RotationalSpeedValue;
        attribute nominalVoltage : VoltageValue;
        attribute nominalCurrent : CurrentValue;
        attribute commandedSpeed : RotationalSpeedValue;
        attribute actualSpeed : RotationalSpeedValue;
        attribute status : MotorStatusType;
        attribute reset : Boolean;

        port command : CommandPort;
        port feedback : FeedbackPort;
        port mechanicalOut : MechanicalPowerPort;

        exhibit action regulateSpeed : RegulateSpeed;

        exhibit state machine MotorStateMachine {
            state Off {
                doc /* Motor de-energized and stationary. */;
            }
            state On {
                doc /* Motor energized and regulating toward commanded speed. */;
            }
            state Faulted {
                doc /* Motor stopped due to detected fault, awaiting reset. */;
            }
            transition Off -> On when command.cmd.commandedSpeed > 0;
            transition On -> Off when command.cmd.commandedSpeed == 0;
            transition On -> Faulted when status == MotorStatusType::FAULT;
            transition Faulted -> Off when reset;
        }
    }

    part def GearSet {
        attribute gearRatio : Real = 1.0;
        port input : MechanicalPowerPort;
        port output : MechanicalPowerPort;
    }

    part def Reservoir {
        attribute capacity : VolumeValue;
        attribute fillLevel : VolumeValue;
        port fluidOut : FluidPort;
        port fluidReturn : FluidPort;
        exhibit action supplyFluid : SupplyFluid;
    }

    part def Receiver {
        attribute capacity : VolumeValue;
        attribute fillLevel : VolumeValue;
        port fluidIn : FluidPort;
        exhibit action receiveFluid : ReceiveFluid;
    }

    part def PressureSensor {
        attribute measuredPressure : PressureValue;
        attribute rangeMax : PressureValue;
        port fluidIn : FluidPort;
        port signal : PressureSignalPort;
        exhibit action sensePressure : SensePressure;
    }

    part def FlowMeter {
        attribute measuredFlow : FlowRateValue;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port signal : FlowSignalPort;
        exhibit action measureFlow : MeasureFlow;
    }

    part def PressureReliefValve {
        attribute setPressure : PressureValue;
        attribute isOpen : Boolean;
        port inlet : FluidPort;
        port outlet : FluidPort;
        exhibit action relieveValveOpen : RelieveValveOpen;
        exhibit action relieveValveClose : RelieveValveClose;
    }

    part def PumpController {
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute currentPumpState : PumpStateType;
        attribute reliefThreshold : PressureValue;
        attribute reliefReset : PressureValue;
        attribute primingTimeout : Integer;

        port motorCommand : CommandPort;
        port motorFeedback : FeedbackPort;
        port inletSensor : PressureSignalPort;
        port outletSensor : PressureSignalPort;
        port flowSensor : FlowSignalPort;
        port operatorControl : ControlSignalPort;

        exhibit state machine PumpingStateMachine {
            state Idle {
                doc /* System idle: motor stopped, awaiting start command from the operator. */;
                do action idleStandby : IdleStandby;
            }
            state Priming {
                doc /* Priming: low-speed operation to fill the pump and remove air before normal operation. */;
                do action primePump : PrimePump;
            }
            state NormalOperating {
                doc /* Normal operation: pump transfers fluid from source to destination at nominal speed. */;
                do action operatePump : OperatePump;
            }
            state PressureRelief {
                doc /* Pressure relief: motor speed reduced in response to a high outlet-pressure event. */;
                do action relievePressure : RelievePressure;
            }
            state Shutdown {
                doc /* Shutdown: motor ramping to a controlled stop. */;
                do action shutdownPump : ShutdownPump;
            }
            state Fault {
                doc /* Fault: motor stopped, fault reported, awaiting operator reset. */;
                do action handleFault : HandleFault;
            }

            transition Idle -> Priming when operatorControl.command.start;
            transition Priming -> NormalOperating when inletSensor.reading.pressure >= reliefReset;
            transition NormalOperating -> PressureRelief when outletSensor.reading.pressure >= reliefThreshold;
            transition PressureRelief -> NormalOperating when outletSensor.reading.pressure <= reliefReset;
            transition NormalOperating -> Shutdown when operatorControl.command.stop;
            transition PressureRelief -> Shutdown when operatorControl.command.stop;
            transition Priming -> Shutdown when operatorControl.command.stop;
            transition Idle -> Fault when motorFeedback.feedback.status == MotorStatusType::FAULT;
            transition Priming -> Fault when motorFeedback.feedback.status == MotorStatusType::FAULT;
            transition NormalOperating -> Fault when motorFeedback.feedback.status == MotorStatusType::FAULT;
            transition PressureRelief -> Fault when motorFeedback.feedback.status == MotorStatusType::FAULT;
            transition Shutdown -> Idle when motorFeedback.feedback.actualSpeed == 0;
            transition Fault -> Idle when operatorControl.command.reset;
        }
    }

    // ---- Top-level subsystem ----
    part def PumpingSubsystem {
        attribute systemName : String = "IndustrialFluidPumpingSystem";

        port operatorInterface : ControlSignalPort;

        part sourceReservoir : Reservoir {
            attribute capacity = 500 [L];
            attribute fillLevel = 400 [L];
        }

        part destinationReceiver : Receiver {
            attribute capacity = 1000 [L];
            attribute fillLevel = 0 [L];
        }

        part lobePump : LobePump {
            attribute displacement = 80 [mL];
            attribute nominalSpeed = 1450 [rpm];
            attribute maxPressure = 1000 [kPa];
        }

        part electricMotor : ElectricMotor {
            attribute nominalSpeed = 1450 [rpm];
            attribute nominalVoltage = 400 [V];
            attribute nominalCurrent = 15 [A];
            attribute status = MotorStatusType::STOPPED;
            attribute reset = false;
        }

        part gearSet : GearSet {
            attribute gearRatio = 1.0;
        }

        part inletPressureSensor : PressureSensor {
            attribute rangeMax = 200 [kPa];
        }

        part outletPressureSensor : PressureSensor {
            attribute rangeMax = 1200 [kPa];
        }

        part flowMeter : FlowMeter;

        part pressureReliefValve : PressureReliefValve {
            attribute setPressure = 1000 [kPa];
            attribute isOpen = false;
        }

        part controller : PumpController {
            attribute reliefThreshold = 900 [kPa];
            attribute reliefReset = 750 [kPa];
            attribute currentPumpState = PumpStateType::IDLE;
        }

        // Fluid path connections
        connection sourceToPump connect sourceReservoir.fluidOut to lobePump.inlet;
        connection pumpToFlowMeter connect lobePump.outlet to flowMeter.fluidIn;
        connection flowMeterToReceiver connect flowMeter.fluidOut to destinationReceiver.fluidIn;
        connection reliefReturn connect pressureReliefValve.outlet to sourceReservoir.fluidReturn;

        // Sensing tap connections
        connection inletSensing connect lobePump.inlet to inletPressureSensor.fluidIn;
        connection outletSensing connect lobePump.outlet to outletPressureSensor.fluidIn;
        connection reliefTap connect lobePump.outlet to pressureReliefValve.inlet;

        // Mechanical power connections
        connection motorToGear connect electricMotor.mechanicalOut to gearSet.input;
        connection gearToPump connect gearSet.output to lobePump.driveInput;

        // Signal connections
        connection inletSensorSignal connect inletPressureSensor.signal to controller.inletSensor;
        connection outletSensorSignal connect outletPressureSensor.signal to controller.outletSensor;
        connection flowSensorSignal connect flowMeter.signal to controller.flowSensor;
        connection motorCommandLink connect controller.motorCommand to electricMotor.command;
        connection motorFeedbackLink connect electricMotor.feedback to controller.motorFeedback;
        connection operatorLink connect operatorInterface to controller.operatorControl;
    }

    // ---- Requirements ----
    requirement def PumpingSystemRequirements {
        subject ps : PumpingSubsystem;

        requirement MoveFluidRequirement {
            doc /* The system shall move pumping fluid from the source reservoir to the destination receiver. */;
        }

        requirement PositiveDisplacementRequirement {
            doc /* The core pump shall be an electrically-driven, positive-displacement lobe pump. */;
        }

        requirement TwoLobeRotorsRequirement {
            doc /* The lobe pump chamber shall contain two synchronized, two-lobed rotors. */;
        }

        requirement RotorSynchronizationRequirement {
            doc /* Precise synchronization and minimal clearance between the rotors shall be maintained to prevent rotor contact and ensure efficient operation. */;
            attribute maxClearance : LengthValue = 0.1 [mm];
        }

        requirement DriveTrainRequirement {
            doc /* An electric motor connected through a gear set and driveshaft shall turn the driving rotor, which in turn drives the driven rotor. */;
        }

        requirement PumpingActionRequirement {
            doc /* As rotors unmesh at the inlet, expanding pockets shall draw fluid in; captured fluid shall be carried around the chamber periphery; and as rotors mesh at the outlet, fluid shall be discharged at higher pressure. */;
        }

        requirement InletPressureSensorRequirement {
            doc /* A pressure sensor shall be installed at the pump inlet to monitor inlet pressure. */;
        }

        requirement OutletPressureSensorRequirement {
            doc /* A pressure sensor shall be installed at the pump outlet to monitor outlet pressure. */;
        }

        requirement FlowMeterRequirement {
            doc /* A flow meter shall measure the pump output flow rate. */;
        }

        requirement PressureReliefValveRequirement {
            doc /* A pressure relief valve shall prevent over-pressurization by opening above the set pressure and diverting fluid back to the source reservoir. */;
            attribute setPressure : PressureValue = 1000 [kPa];
        }

        requirement StateControlRequirement {
            doc /* System operation shall be managed through Idle, Priming, Normal Operating, Pressure Relief, Shutdown, and Fault states. */;
        }

        requirement PressureReliefModeRequirement {
            doc /* During operation, the system shall enter a pressure-relief mode that reduces motor speed in response to high outlet-pressure events. */;
            attribute threshold : PressureValue = 900 [kPa];
        }

        requirement PrimingRequirement {
            doc /* The system shall enter a priming state to fill the pump and remove air before normal operation. */;
        }

        requirement ShutdownRequirement {
            doc /* The system shall provide a defined shutdown state for proper stopping. */;
        }

        requirement FaultHandlingRequirement {
            doc /* The system shall provide a fault state that stops the motor and reports the fault condition, with a reset transition back to idle. */;
        }

        requirement MotorControlInterfaceRequirement {
            doc /* The electric motor shall be controlled by commanded speed signals and shall report back its actual speed and operational status. */;
        }
    }
}
