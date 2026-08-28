package RotodynamicPumpingSubsystem {
    import ScalarValues::*;
    import ISQ::*;
    import ISQVolume::*;
    import ISQPressure::*;
    import ISQEnergy::*;
    import ISQTime::*;
    import ISQPower::*;
    import ISQFrequency::*;
    import ISQLength::*;
    import ISQMass::*;
    import ISQVelocity::*;

    // ---------- Value types ----------
    def FlowRateValue :> Real { unit 'm3/s'; }
    def PressureValue :> Real { unit 'Pa'; }
    def RotationalSpeedValue :> Real { unit 'rad/s'; }
    def TorqueValue :> Real { unit 'N*m'; }
    def EfficiencyValue :> Real { unit '1'; }
    def TemperatureValue :> Real { unit 'K'; }
    def DurationValue :> Real { unit 'h'; }
    def PowerValue :> Real { unit 'W'; }
    def VoltageValue :> Real { unit 'V'; }
    def CurrentValue :> Real { unit 'A'; }
    def ValvePositionValue :> Real { unit '1'; min 0; max 1; }

    // ---------- Item types ----------
    item def Fluid {
        attribute density : MassDensityValue;
        attribute viscosity : Real;
        attribute temperature : TemperatureValue;
    }

    attribute def MassDensityValue :> Real { unit 'kg/m3'; }

    item def ElectricalPower {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        attribute frequency : Real;
    }

    item def ControlSignal {
        attribute setpoint : FlowRateValue;
        attribute valveCommand : ValvePositionValue;
        attribute motorEnable : Boolean;
    }

    item def SensorReading {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute timestamp : Real;
    }

    // ---------- Port definitions ----------
    port def FluidPort {
        out fluid : Fluid;
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def ElectricalPort {
        in power : ElectricalPower;
    }

    port def ControlPort {
        out signal : ControlSignal;
        in reading : SensorReading;
    }

    port def MechanicalDrivePort {
        out torque : TorqueValue;
        out speed : RotationalSpeedValue;
    }

    port def SensorDataPort {
        out reading : SensorReading;
    }

    // ---------- Requirements ----------
    requirement def MinFlowRateRequirement {
        doc "The system shall maintain a minimum flow rate during operation."
        attribute minFlowRate : FlowRateValue = 0.01 [m3/s];
        requirement { #flowRate >= minFlowRate }
    }

    requirement def HeadPressureRequirement {
        doc "The system shall generate a significant head pressure."
        attribute minHeadPressure : PressureValue = 200000 [Pa];
        requirement { #outletPressure - #inletPressure >= minHeadPressure }
    }

    requirement def EfficiencyRequirement {
        doc "The system shall operate with high overall efficiency."
        attribute minEfficiency : EfficiencyValue = 0.65;
        requirement { #overallEfficiency >= minEfficiency }
    }

    requirement def ReliabilityRequirement {
        doc "The system shall operate continuously for thousands of hours between maintenance cycles."
        attribute minMTBF : DurationValue = 5000 [h];
        requirement { #operatingHoursBetweenMaintenance >= minMTBF }
    }

    requirement def SafetyShutdownRequirement {
        doc "The system shall automatically shut down if a critical pressure condition is detected."
        attribute criticalHighPressure : PressureValue = 1000000 [Pa];
        attribute criticalLowPressure : PressureValue = 50000 [Pa];
        requirement {
            if #outletPressure >= criticalHighPressure or #inletPressure <= criticalLowPressure
            then #systemState == 'Shutdown'
        }
    }

    requirement def PumpingSubsystemRequirements {
        requirement minFlow : MinFlowRateRequirement;
        requirement headPressure : HeadPressureRequirement;
        requirement efficiency : EfficiencyRequirement;
        requirement reliability : ReliabilityRequirement;
        requirement safety : SafetyShutdownRequirement;
    }

    // ---------- Part definitions ----------
    part def SupplyReservoir {
        port outlet : FluidPort;
        attribute fluidLevel : Real;
        attribute storedFluid : Fluid;
    }

    part def DischargeReservoir {
        port inlet : FluidPort;
        attribute fluidLevel : Real;
        attribute storedFluid : Fluid;
    }

    part def VoluteCasing {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        attribute internalVolume : Real;
        attribute material : String = "CastIron";
    }

    part def Impeller {
        port drivePort : MechanicalDrivePort;
        attribute bladeCount : Integer = 7;
        attribute diameter : Real;
        attribute rotationalSpeed : RotationalSpeedValue;
        attribute material : String = "StainlessSteel";
    }

    part def BallBearings {
        attribute loadCapacity : Real;
        attribute lubricantType : String = "Grease";
        attribute ratedLife : DurationValue;
    }

    part def MechanicalSeal {
        attribute sealType : String = "Mechanical";
        attribute maxPressure : PressureValue;
        attribute leakageRate : FlowRateValue;
    }

    part def Shaft {
        port driveInput : MechanicalDrivePort;
        port driveOutput : MechanicalDrivePort;
        attribute material : String = "StainlessSteel";
        attribute diameter : Real;
        attribute length : Real;
        attribute torsionalStiffness : Real;
    }

    part def ElectricMotor {
        port electricalInput : ElectricalPort;
        port mechanicalOutput : MechanicalDrivePort;
        attribute ratedPower : PowerValue;
        attribute ratedSpeed : RotationalSpeedValue;
        attribute efficiency : EfficiencyValue;
        attribute supplyVoltage : VoltageValue;
        attribute supplyCurrent : CurrentValue;
    }

    part def RotodynamicPump {
        port suctionPort : FluidPort;
        port dischargePort : FluidPort;
        port driveInput : MechanicalDrivePort;

        part volute : VoluteCasing {
            port suctionPort : FluidPort;
            port dischargePort : FluidPort;
        }
        part impeller : Impeller {
            port drivePort : MechanicalDrivePort;
        }
        part shaft : Shaft {
            port driveInput : MechanicalDrivePort;
            port driveOutput : MechanicalDrivePort;
        }
        part bearings : BallBearings;
        part seal : MechanicalSeal;

        connection impellerDrive : impeller.drivePort to shaft.driveOutput;
        connection shaftDrive : shaft.driveInput to driveInput;
        connection suctionFlow : suctionPort to volute.suctionPort;
        connection dischargeFlow : volute.dischargePort to dischargePort;

        attribute designHead : PressureValue;
        attribute designFlow : FlowRateValue;
        attribute bestEfficiencyPoint : EfficiencyValue;
    }

    part def PressureSensor {
        port fluidPort : FluidPort;
        port dataPort : SensorDataPort;
        attribute measuredPressure : PressureValue;
        attribute accuracy : Real;
        attribute range : PressureValue;
    }

    part def FlowMeter {
        port fluidPort : FluidPort;
        port dataPort : SensorDataPort;
        attribute measuredFlowRate : FlowRateValue;
        attribute accuracy : Real;
    }

    part def ControlValve {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port controlPort : ControlPort;
        attribute position : ValvePositionValue = 1.0;
        attribute maxFlowRate : FlowRateValue;
    }

    part def PumpController {
        port inletSensorPort : SensorDataPort;
        port outletSensorPort : SensorDataPort;
        port flowMeterPort : SensorDataPort;
        port valveControlPort : ControlPort;
        port motorControlPort : ControlPort;

        attribute targetFlowRate : FlowRateValue = 0.05 [m3/s];
        attribute currentInletPressure : PressureValue;
        attribute currentOutletPressure : PressureValue;
        attribute currentFlowRate : FlowRateValue;
        attribute valvePosition : ValvePositionValue = 1.0;
        attribute motorEnabled : Boolean = false;
        attribute systemState : String = "Idle";

        // Controller state machine
        state def ControllerBehavior {
            entry action { systemState = "Idle"; }

            state Idle;
            state Startup;
            state Operating;
            state Shutdown;
            state EmergencyShutdown;

            transition init_to_startup
                first Idle to Startup
                when motorEnabled == true;

            transition startup_to_operating
                Startup to Operating
                when currentOutletPressure > 100000 [Pa];

            transition operating_to_shutdown
                Operating to Shutdown
                when motorEnabled == false;

            transition to_emergency
                Operating to EmergencyShutdown
                when currentOutletPressure >= 1000000 [Pa] or currentInletPressure <= 50000 [Pa];

            transition emergency_to_idle
                EmergencyShutdown to Idle
                when motorEnabled == false;

            // Startup behavior
            action StartupAction {
                // Ramp motor to operating speed
                // Monitor pressure buildup
                // Verify flow establishment
            }

            // Operating behavior
            action RegulateFlow {
                // Compute flow error
                // Adjust valve position
                // Monitor pressures
            }

            // Shutdown behavior
            action ShutdownAction {
                // Ramp motor down
                // Close control valve
                // Confirm safe state
            }
        }

        behavior controllerStateMachine : ControllerBehavior;

        action def ComputeControlAction {
            in targetFlow : FlowRateValue;
            in measuredFlow : FlowRateValue;
            in inletP : PressureValue;
            in outletP : PressureValue;
            out valveCmd : ValvePositionValue;
            out motorCmd : Boolean;
            private attribute flowError : FlowRateValue;
            private attribute pressureDelta : PressureValue;
        }
    }

    // ---------- Top-level system ----------
    part pumpingSubsystem : PumpingSubsystemRequirements {
        attribute overallEfficiency : EfficiencyValue;
        attribute operatingHoursBetweenMaintenance : DurationValue;
        attribute systemState : String;

        part supplyReservoir : SupplyReservoir {
            attribute fluidLevel : Real = 2.0;
            attribute storedFluid : Fluid {
                attribute density = 1000 [kg/m3];
                attribute viscosity = 0.001;
                attribute temperature = 293.15 [K];
            }
        }

        part dischargeReservoir : DischargeReservoir {
            attribute fluidLevel : Real = 0.0;
            attribute storedFluid : Fluid {
                attribute density = 1000 [kg/m3];
                attribute viscosity = 0.001;
                attribute temperature = 293.15 [K];
            }
        }

        part pump : RotodynamicPump {
            part volute : VoluteCasing {
                attribute internalVolume = 0.005;
            }
            part impeller : Impeller {
                attribute bladeCount = 7;
                attribute diameter = 0.15;
                attribute rotationalSpeed = 314.16 [rad/s];
            }
            part shaft : Shaft {
                attribute diameter = 0.025;
                attribute length = 0.4;
            }
            part bearings : BallBearings {
                attribute loadCapacity = 5000;
                attribute ratedLife = 10000 [h];
            }
            part seal : MechanicalSeal {
                attribute maxPressure = 1500000 [Pa];
                attribute leakageRate = 0.000001 [m3/s];
            }
            attribute designHead = 250000 [Pa];
            attribute designFlow = 0.05 [m3/s];
            attribute bestEfficiencyPoint = 0.72;
        }

        part motor : ElectricMotor {
            attribute ratedPower = 15000 [W];
            attribute ratedSpeed = 314.16 [rad/s];
            attribute efficiency = 0.90;
            attribute supplyVoltage = 400 [V];
            attribute supplyCurrent = 25 [A];
        }

        part inletPressureSensor : PressureSensor {
            attribute accuracy = 0.01;
            attribute range = 200000 [Pa];
        }

        part outletPressureSensor : PressureSensor {
            attribute accuracy = 0.01;
            attribute range = 1500000 [Pa];
        }

        part flowMeter : FlowMeter {
            attribute accuracy = 0.005;
        }

        part controlValve : ControlValve {
            attribute position = 1.0;
            attribute maxFlowRate = 0.1 [m3/s];
        }

        part controller : PumpController {
            attribute targetFlowRate = 0.05 [m3/s];
        }

        // Fluid connections
        connection supplyToInletSensor : supplyReservoir.outlet to inletPressureSensor.fluidPort;
        connection inletSensorToPump : inletPressureSensor.fluidPort to pump.suctionPort;
        connection pumpToOutletSensor : pump.dischargePort to outletPressureSensor.fluidPort;
        connection outletSensorToFlowMeter : outletPressureSensor.fluidPort to flowMeter.fluidPort;
        connection flowMeterToValve : flowMeter.fluidPort to controlValve.inlet;
        connection valveToDischarge : controlValve.outlet to dischargeReservoir.inlet;

        // Mechanical drive connections
        connection motorToPump : motor.mechanicalOutput to pump.driveInput;

        // Sensor data connections
        connection inletSensorData : inletPressureSensor.dataPort to controller.inletSensorPort;
        connection outletSensorData : outletPressureSensor.dataPort to controller.outletSensorPort;
        connection flowMeterData : flowMeter.dataPort to controller.flowMeterPort;

        // Control connections
        connection valveControl : controller.valveControlPort to controlValve.controlPort;
        connection motorControl : controller.motorControlPort to motor.electicalInput;

        // System state machine
        state def SystemLifecycle {
            entry action { systemState = "Idle"; }

            state Idle {
                entry action { systemState = "Idle"; }
            }
            state Startup {
                entry action { systemState = "Startup"; }
                // Bring pump to speed
                // Verify pressure buildup
                // Confirm flow establishment
            }
            state Operating {
                entry action { systemState = "Operating"; }
                // Monitor inlet/outlet pressure
                // Regulate flow via control valve
                // Check for critical conditions
            }
            state Shutdown {
                entry action { systemState = "Shutdown"; }
                // Ramp motor down
                // Close control valve
            }
            state EmergencyShutdown {
                entry action { systemState = "EmergencyShutdown"; }
                // Immediate motor stop
                // Close control valve
                // Log fault condition
            }

            transition idleToStartup
                first Idle to Startup
                when controller.motorEnabled == true;

            transition startupToOperating
                Startup to Operating
                when outletPressureSensor.measuredPressure > 100000 [Pa]
                and flowMeter.measuredFlowRate > 0.005 [m3/s];

            transition operatingToShutdown
                Operating to Shutdown
                when controller.motorEnabled == false;

            transition operatingToEmergency
                Operating to EmergencyShutdown
                when outletPressureSensor.measuredPressure >= 1000000 [Pa]
                or inletPressureSensor.measuredPressure <= 50000 [Pa];

            transition shutdownToIdle
                Shutdown to Idle
                when controller.motorEnabled == false
                and controlValve.position == 0.0;

            transition emergencyToIdle
                EmergencyShutdown to Idle
                when controller.motorEnabled == false
                and controlValve.position == 0.0;
        }

        behavior systemStateMachine : SystemLifecycle;

        // Startup action
        action def StartupSequence {
            in motor : ElectricMotor;
            in pump : RotodynamicPump;
            in controlValve : ControlValve;
            // 1. Enable motor
            // 2. Ramp to rated speed
            // 3. Open control valve partially
            // 4. Monitor pressure buildup
            // 5. Confirm flow establishment
            // 6. Transition to operating
        }

        // Operating action
        action def ContinuousOperation {
            in controller : PumpController;
            in inletSensor : PressureSensor;
            in outletSensor : PressureSensor;
            in flowMeter : FlowMeter;
            in controlValve : ControlValve;
            // 1. Read sensor values
            // 2. Compute flow error vs target
            // 3. Adjust valve position
            // 4. Check critical pressure conditions
            // 5. Log performance metrics
        }

        // Shutdown action
        action def ShutdownProcedure {
            in motor : ElectricMotor;
            in controlValve : ControlValve;
            // 1. Reduce motor speed gradually
            // 2. Close control valve
            // 3. Disable motor
            // 4. Confirm safe state
        }

        // Emergency shutdown action
        action def EmergencyShutdownProcedure {
            in motor : ElectricMotor;
            in controlValve : ControlValve;
            // 1. Immediately disable motor
            // 2. Close control valve
            // 3. Activate alarm
            // 4. Log fault
        }

        // Satisfy requirements
        satisfy MinFlowRateRequirement by pump {
            attribute flowRate = pump.designFlow;
        }
        satisfy HeadPressureRequirement by pump {
            attribute outletPressure = pump.designHead;
            attribute inletPressure = 101325 [Pa];
        }
        satisfy EfficiencyRequirement by pumpingSubsystem {
            attribute overallEfficiency = 0.68;
        }
        satisfy ReliabilityRequirement by pumpingSubsystem {
            attribute operatingHoursBetweenMaintenance = 6000 [h];
        }
        satisfy SafetyShutdownRequirement by systemStateMachine;
    }
}
