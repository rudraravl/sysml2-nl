package HydraulicPumpingSubsystem {

    import ScalarValues::*;

    // ===== Value Types with Units =====

    attribute def Pressure :> Real { /** Unit: Pa (Pascal) */ }
    attribute def FlowRate :> Real { /** Unit: L/min */ }
    attribute def RotationalSpeed :> Real { /** Unit: rpm */ }
    attribute def Voltage :> Real { /** Unit: V */ }
    attribute def Current :> Real { /** Unit: A */ }
    attribute def Temperature :> Real { /** Unit: degC */ }
    attribute def Volume :> Real { /** Unit: L */ }
    attribute def Power :> Real { /** Unit: W */ }
    attribute def Torque :> Real { /** Unit: N*m */ }
    attribute def Ratio :> Real { /** Dimensionless */ }
    attribute def TimeValue :> Real { /** Unit: s */ }

    // ===== Item Definitions =====

    item def HydraulicFluid {
        attribute density : Real = 850;
        attribute viscosity : Real = 32;
        attribute maxOperatingTemp : Temperature = 80;
    }

    item def HighPressureFluid :> HydraulicFluid {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    item def LowPressureFluid :> HydraulicFluid {
        attribute pressure : Pressure;
        attribute flowRate : FlowRate;
    }

    // ===== Port Definitions =====

    port def HPOutputPort {
        out item fluid : HighPressureFluid;
    }

    port def HPInputPort {
        in item fluid : HighPressureFluid;
    }

    port def LPOutputPort {
        out item fluid : LowPressureFluid;
    }

    port def LPInputPort {
        in item fluid : LowPressureFluid;
    }

    port def MechanicalOutputPort {
        out attribute speed : RotationalSpeed;
        out attribute torque : Torque;
    }

    port def MechanicalInputPort {
        in attribute speed : RotationalSpeed;
        in attribute torque : Torque;
    }

    port def ElectricalPort {
        inout attribute voltage : Voltage;
        inout attribute current : Current;
    }

    port def PressureSignalOutPort {
        out attribute measuredPressure : Pressure;
    }

    port def FlowSignalOutPort {
        out attribute measuredFlow : FlowRate;
    }

    port def PressureSignalInPort {
        in attribute pressureReading : Pressure;
    }

    port def FlowSignalInPort {
        in attribute flowReading : FlowRate;
    }

    port def SpeedCommandOutPort {
        out attribute speedCommand : RotationalSpeed;
    }

    port def SpeedCommandInPort {
        in attribute speedCommand : RotationalSpeed;
    }

    // ===== Connection Definitions =====

    connection def HPLine {
        end source : HPOutputPort;
        end target : HPInputPort;
    }

    connection def LPLine {
        end source : LPOutputPort;
        end target : LPInputPort;
    }

    connection def MechanicalLink {
        end driver : MechanicalOutputPort;
        end driven : MechanicalInputPort;
    }

    connection def PressureSignalLink {
        end source : PressureSignalOutPort;
        end target : PressureSignalInPort;
    }

    connection def FlowSignalLink {
        end source : FlowSignalOutPort;
        end target : FlowSignalInPort;
    }

    connection def SpeedCommandLink {
        end source : SpeedCommandOutPort;
        end target : SpeedCommandInPort;
    }

    // ===== Component Part Definitions =====

    part def Reservoir {
        port returnPort : LPInputPort;
        port reliefReturnPort : LPInputPort;
        port suctionPort : LPOutputPort;

        attribute capacity : Volume = 100;
        attribute currentLevel : Volume = 80;
        attribute fluidTemp : Temperature = 40;
        attribute minLevel : Volume = 10;
        attribute maxTemp : Temperature = 80;
        attribute nominalPressure : Pressure = 100000;

        item storedFluid : HydraulicFluid;

        exhibit state ReservoirOperation {
            entry;
            then Normal;

            state Normal {
                doc /* Reservoir operating within normal parameters. */
            }

            state LowLevel {
                doc /* Fluid level below minimum threshold. */
            }

            state OverTemperature {
                doc /* Fluid temperature exceeds safe maximum. */
            }

            transition normal_to_lowLevel
                from Normal to LowLevel
                when currentLevel < minLevel;

            transition lowLevel_to_normal
                from LowLevel to Normal
                when currentLevel >= minLevel;

            transition normal_to_overTemp
                from Normal to OverTemperature
                when fluidTemp > maxTemp;

            transition overTemp_to_normal
                from OverTemperature to Normal
                when fluidTemp <= maxTemp;
        }
    }

    part def ElectricMotor {
        port powerInput : ElectricalPort;
        port mechanicalOutput : MechanicalOutputPort;
        port commandInput : SpeedCommandInPort;

        attribute nominalSpeed : RotationalSpeed = 1800;
        attribute currentSpeed : RotationalSpeed = 0;
        attribute nominalVoltage : Voltage = 480;
        attribute nominalPower : Power = 15000;
        attribute maxSpeed : RotationalSpeed = 3600;
        attribute minSpeed : RotationalSpeed = 0;
        attribute maxCurrent : Current = 50;
        attribute startingTime : TimeValue = 3;
        attribute outputTorque : Torque = 45;

        exhibit state MotorOperation {
            entry;
            then Off;

            state Off {
                doc /* Motor is de-energized and not rotating. */
            }

            state Starting {
                doc /* Motor is ramping up to commanded speed. */
            }

            state Running {
                doc /* Motor is operating at or near commanded speed. */
            }

            state Faulted {
                doc /* Motor has detected a fault condition. */
            }

            transition off_to_starting
                from Off to Starting
                when commandInput.speedCommand > 0;

            transition starting_to_running
                from Starting to Running
                when currentSpeed >= commandInput.speedCommand * 0.95;

            transition running_to_off
                from Running to Off
                when commandInput.speedCommand == 0;

            transition off_to_faulted
                from Off to Faulted
                when powerInput.voltage > nominalVoltage * 1.2;

            transition starting_to_faulted
                from Starting to Faulted
                when powerInput.current > maxCurrent;

            transition running_to_faulted
                from Running to Faulted
                when powerInput.current > maxCurrent;
        }
    }

    part def HydraulicPump {
        port mechanicalInput : MechanicalInputPort;
        port suctionPort : LPInputPort;
        port deliveryPort : HPOutputPort;
        port reliefTapPort : HPOutputPort;

        attribute displacement : Volume = 0.025;
        attribute nominalSpeed : RotationalSpeed = 1800;
        attribute maxPressure : Pressure = 30000000;
        attribute volumetricEfficiency : Ratio = 0.92;
        attribute mechanicalEfficiency : Ratio = 0.90;
        attribute outputPressure : Pressure = 0;
        attribute outputFlowRate : FlowRate = 0;
        attribute minOperatingPressure : Pressure = 1000000;
        attribute cavitationThreshold : Pressure = 50000;
        attribute nominalFlowRate : FlowRate = 41.4;

        exhibit state PumpLifecycle {
            entry;
            then Idle;

            state Idle {
                doc /* Pump is not rotating. No fluid is being delivered. */
            }

            state Starting {
                doc /* Pump is beginning to rotate and build pressure. */
            }

            state Running {
                doc /* Pump is fully operational, delivering pressurized fluid to the consumer. */
            }

            state Faulted {
                doc /* Pump has detected a fault condition such as cavitation, overpressure, or mechanical failure. */
            }

            transition idle_to_starting
                from Idle to Starting
                when mechanicalInput.speed > 0;

            transition starting_to_running
                from Starting to Running
                when outputPressure >= minOperatingPressure;

            transition running_to_idle
                from Running to Idle
                when mechanicalInput.speed == 0;

            transition starting_to_faulted
                from Starting to Faulted
                when suctionPort.fluid.pressure < cavitationThreshold;

            transition running_to_faulted
                from Running to Faulted
                when outputPressure > maxPressure;

            transition faulted_to_idle
                from Faulted to Idle
                when mechanicalInput.speed == 0;
        }
    }

    part def PressureReliefValve {
        port inletPort : HPInputPort;
        port outletPort : LPOutputPort;

        attribute reliefPressure : Pressure = 25000000;
        attribute currentPressure : Pressure = 0;
        attribute crackPressure : Pressure = 23000000;
        attribute fullOpenPressure : Pressure = 27000000;
        attribute maxFlowCapacity : FlowRate = 50;
        attribute valveOpening : Ratio = 0;

        exhibit state ReliefValveOperation {
            entry;
            then Closed;

            state Closed {
                doc /* Valve is closed. Normal operation with pressure below relief threshold. */
            }

            state Cracking {
                doc /* Valve is beginning to open. Pressure approaching relief threshold. */
            }

            state Open {
                doc /* Valve is open. Excess fluid is being diverted to reservoir. */
            }

            transition closed_to_cracking
                from Closed to Cracking
                when currentPressure >= crackPressure;

            transition cracking_to_open
                from Cracking to Open
                when currentPressure >= fullOpenPressure;

            transition open_to_cracking
                from Open to Cracking
                when currentPressure < fullOpenPressure;

            transition cracking_to_closed
                from Cracking to Closed
                when currentPressure < crackPressure;
        }
    }

    part def PressureSensor {
        port signalOutput : PressureSignalOutPort;

        attribute measurementRange : Pressure = 35000000;
        attribute accuracy : Ratio = 0.01;
        attribute measuredPressure : Pressure = 0;
        attribute samplingRate : Real = 100;
        attribute responseTime : TimeValue = 0.01;

        exhibit state PressureSensorOperation {
            entry;
            then Active;

            state Active {
                doc /* Sensor is actively measuring pressure and providing readings. */
            }

            state Inactive {
                doc /* Sensor is not powered or not measuring. */
            }

            state Faulted {
                doc /* Sensor has detected a malfunction or reading out of range. */
            }

            transition active_to_faulted
                from Active to Faulted
                when measuredPressure > measurementRange;

            transition active_to_inactive
                from Active to Inactive
                when measuredPressure < 0;
        }
    }

    part def FlowSensor {
        port signalOutput : FlowSignalOutPort;

        attribute measurementRange : FlowRate = 100;
        attribute accuracy : Ratio = 0.02;
        attribute measuredFlow : FlowRate = 0;
        attribute samplingRate : Real = 50;
        attribute responseTime : TimeValue = 0.05;

        exhibit state FlowSensorOperation {
            entry;
            then Active;

            state Active {
                doc /* Sensor is actively measuring flow rate and providing readings. */
            }

            state Inactive {
                doc /* Sensor is not powered or not measuring. */
            }

            state Faulted {
                doc /* Sensor has detected a malfunction or reading out of range. */
            }

            transition active_to_faulted
                from Active to Faulted
                when measuredFlow > measurementRange;

            transition active_to_inactive
                from Active to Inactive
                when measuredFlow < 0;
        }
    }

    part def ControlSystem {
        port pressureInput : PressureSignalInPort;
        port flowInput : FlowSignalInPort;
        port speedCommandOutput : SpeedCommandOutPort;

        attribute targetPressure : Pressure = 20000000;
        attribute minPressure : Pressure = 18000000;
        attribute maxPressure : Pressure = 22000000;
        attribute emergencyPressure : Pressure = 28000000;
        attribute minSpeed : RotationalSpeed = 500;
        attribute maxSpeed : RotationalSpeed = 3000;
        attribute currentSpeedCommand : RotationalSpeed = 0;
        attribute speedIncrement : RotationalSpeed = 100;
        attribute speedDecrement : RotationalSpeed = 100;
        attribute deadband : Pressure = 500000;
        attribute targetFlow : FlowRate = 30;
        attribute integralTerm : Real = 0;
        attribute proportionalGain : Real = 0.5;
        attribute integralGain : Real = 0.1;

        exhibit state ControlLoop {
            entry;
            then Monitoring;

            state Monitoring {
                doc /* Control system is monitoring pressure and flow within normal operating range. Motor speed is maintained at current command. */
            }

            state IncreasingSpeed {
                doc /* Pressure below target threshold. Motor speed command is being increased to compensate. */
            }

            state DecreasingSpeed {
                doc /* Pressure above target threshold. Motor speed command is being decreased to reduce output. */
            }

            state EmergencyStop {
                doc /* Critical pressure level detected. Motor speed command set to zero to protect system. */
            }

            transition monitoring_to_increasing
                from Monitoring to IncreasingSpeed
                when pressureInput.pressureReading < (targetPressure - deadband);

            transition monitoring_to_decreasing
                from Monitoring to DecreasingSpeed
                when pressureInput.pressureReading > (targetPressure + deadband);

            transition increasing_to_monitoring
                from IncreasingSpeed to Monitoring
                when pressureInput.pressureReading >= (targetPressure - deadband);

            transition decreasing_to_monitoring
                from DecreasingSpeed to Monitoring
                when pressureInput.pressureReading <= (targetPressure + deadband);

            transition monitoring_to_emergency
                from Monitoring to EmergencyStop
                when pressureInput.pressureReading > emergencyPressure;

            transition increasing_to_emergency
                from IncreasingSpeed to EmergencyStop
                when pressureInput.pressureReading > emergencyPressure;

            transition decreasing_to_emergency
                from DecreasingSpeed to EmergencyStop
                when pressureInput.pressureReading > emergencyPressure;
        }
    }

    part def FluidConsumer {
        port supplyPort : HPInputPort;
        port returnPort : LPOutputPort;

        attribute requiredPressure : Pressure = 18000000;
        attribute requiredFlow : FlowRate = 25;
        attribute loadResistance : Real = 0.8;
        attribute consumerPressure : Pressure = 0;
        attribute consumerFlow : FlowRate = 0;
        attribute maxFlow : FlowRate = 40;

        exhibit state ConsumerOperation {
            entry;
            then Idle;

            state Idle {
                doc /* Consumer is not demanding hydraulic power. */
            }

            state Active {
                doc /* Consumer is actively using hydraulic power from the supplied fluid. */
            }

            state Overloaded {
                doc /* Consumer is overloaded beyond rated capacity. */
            }

            transition idle_to_active
                from Idle to Active
                when consumerPressure >= requiredPressure;

            transition active_to_idle
                from Active to Idle
                when consumerPressure < requiredPressure;

            transition active_to_overloaded
                from Active to Overloaded
                when consumerFlow > maxFlow;

            transition overloaded_to_active
                from Overloaded to Active
                when consumerFlow <= maxFlow;
        }
    }

    // ===== System Assembly =====

    part def HydraulicPowerUnit {
        port electricalInput : ElectricalPort;

        part reservoir : Reservoir;
        part motor : ElectricMotor;
        part pump : HydraulicPump;
        part reliefValve : PressureReliefValve;
        part pressureSensor : PressureSensor;
        part flowSensor : FlowSensor;
        part controller : ControlSystem;
        part consumer : FluidConsumer;

        // Mechanical coupling: motor drives pump
        connection : MechanicalLink connect motor.mechanicalOutput to pump.mechanicalInput;

        // Low pressure supply: reservoir to pump suction
        connection : LPLine connect reservoir.suctionPort to pump.suctionPort;

        // High pressure delivery: pump to consumer
        connection : HPLine connect pump.deliveryPort to consumer.supplyPort;

        // Low pressure return: consumer to reservoir
        connection : LPLine connect consumer.returnPort to reservoir.returnPort;

        // Relief valve: pump relief tap to relief valve inlet
        connection : HPLine connect pump.reliefTapPort to reliefValve.inletPort;

        // Relief valve return: relief valve outlet to reservoir
        connection : LPLine connect reliefValve.outletPort to reservoir.reliefReturnPort;

        // Pressure sensor signal to controller
        connection : PressureSignalLink connect pressureSensor.signalOutput to controller.pressureInput;

        // Flow sensor signal to controller
        connection : FlowSignalLink connect flowSensor.signalOutput to controller.flowInput;

        // Controller speed command to motor
        connection : SpeedCommandLink connect controller.speedCommandOutput to motor.commandInput;

        // Electrical power input to motor
        connect electricalInput to motor.powerInput;

        // Bindings for sensor measurements to pump output
        bind pressureSensor.measuredPressure = pump.outputPressure;
        bind flowSensor.measuredFlow = pump.outputFlowRate;
        bind reliefValve.currentPressure = pump.outputPressure;
        bind consumer.consumerPressure = pump.outputPressure;
        bind consumer.consumerFlow = pump.outputFlowRate;
    }

    // ===== Requirements =====

    requirement def PressurizedFluidSupply {
        doc /* The hydraulic pumping subsystem shall generate and supply pressurized hydraulic fluid to the fluid consumer at the required pressure and flow rate. */
        subject : HydraulicPowerUnit;
        attribute requiredSupplyPressure : Pressure = 20000000;
        attribute requiredSupplyFlow : FlowRate = 25;
    }

    requirement def SafetyPressureRelief {
        doc /* The system shall incorporate a pressure relief valve that automatically opens when system pressure exceeds a predefined safety limit, diverting excess fluid back to the reservoir to prevent component damage. */
        subject : HydraulicPowerUnit;
        attribute maxSafePressure : Pressure = 25000000;
        attribute reliefValveResponseTime : TimeValue = 0.05;
    }

    requirement def PressureRegulation {
        doc /* The control system shall continuously monitor output pressure and adjust the electric motor speed to maintain the operating pressure within the specified range. If pressure drops below the consumer requirement, motor speed shall be increased to compensate. */
        subject : ControlSystem;
        attribute targetOperatingPressure : Pressure = 20000000;
        attribute pressureTolerance : Pressure = 500000;
    }

    requirement def FlowMonitoring {
        doc /* The system shall be equipped with a flow sensor to monitor the volume of fluid being delivered to the consumer. */
        subject : HydraulicPowerUnit;
        attribute flowMeasurementRange : FlowRate = 100;
        attribute flowMeasurementAccuracy : Ratio = 0.02;
    }

    requirement def PumpLifecycleManagement {
        doc /* The hydraulic pump shall have a defined operational lifecycle with states including idle, starting, running, and faulted. The pump shall transition between these states based on operational conditions. */
        subject : HydraulicPump;
    }

    requirement def ClosedCircuitOperation {
        doc /* The system shall operate as a closed hydraulic circuit where fluid flows from the reservoir through the pump to the consumer and back to the reservoir. */
        subject : HydraulicPowerUnit;
    }

    requirement def MotorSpeedControl {
        doc /* The electric motor speed shall be adjustable by the control system based on pressure and flow feedback to maintain steady operating pressure. */
        subject : ElectricMotor;
        attribute minControllableSpeed : RotationalSpeed = 500;
        attribute maxControllableSpeed : RotationalSpeed = 3000;
    }

    requirement def ReservoirStorage {
        doc /* The reservoir shall serve as a storage tank for hydraulic fluid, providing fluid to the pump suction and receiving return fluid from the consumer and relief valve. */
        subject : Reservoir;
        attribute minCapacity : Volume = 50;
    }

    requirement def EmergencyProtection {
        doc /* The control system shall initiate an emergency stop, setting motor speed to zero, when system pressure exceeds the emergency pressure threshold. */
        subject : ControlSystem;
        attribute emergencyPressureThreshold : Pressure = 28000000;
    }

    // ===== Requirement Satisfaction =====

    part def HydraulicPowerUnit {
        satisfy PressurizedFluidSupply by pump.deliveryPort;
        satisfy SafetyPressureRelief by reliefValve;
        satisfy PressureRegulation by controller;
        satisfy FlowMonitoring by flowSensor;
        satisfy PumpLifecycleManagement by pump;
        satisfy ClosedCircuitOperation by self;
        satisfy MotorSpeedControl by motor;
        satisfy ReservoirStorage by reservoir;
        satisfy EmergencyProtection by controller;
    }
}
