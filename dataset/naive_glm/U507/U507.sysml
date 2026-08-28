package HydraulicPumpingSubsystem {

    import ISQ::*;
    import ISQ::Mass::*;
    import ISQ::Space::*;
    import ISQ::Time::*;
    import ISQ::Thermodynamics::*;
    import ISQ::Mechanics::*;
    import ISQ::Electromagnetism::*;

    // ============ Custom Unit Definitions ============

    unit bar :> Pressure;
    unit LiterPerMinute :> VolumeFlowRate;
    unit rpm :> AngularVelocity;
    unit degC :> ThermodynamicTemperature;
    unit mm :> Length;
    unit ms :> Time;
    unit cm3 :> Volume;
    unit Nm :> Torque;

    // ============ Item Definitions ============

    item def HydraulicFluid {
        attribute density : Real = 850;       // kg/m3
        attribute viscosity : Real = 32;       // centistokes at 40 degC
        attribute maxTemp : ThermodynamicTemperature = 80 [degC];
    }

    item def ContaminantParticle {
        attribute size : Length;
    }

    item def ElectricalPower;

    // ============ Port Definitions ============

    port def HydraulicInlet {
        in fluid : HydraulicFluid;
        attribute pressure : Pressure;
    }

    port def HydraulicOutlet {
        out fluid : HydraulicFluid;
        attribute pressure : Pressure;
    }

    port def HydraulicTap {
        flow fluid : HydraulicFluid;
        attribute pressure : Pressure;
    }

    port def ElectricalIn {
        in power : ElectricalPower;
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    port def ElectricalOut {
        out power : ElectricalPower;
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
    }

    port def MechanicalShaft {
        attribute speed : AngularVelocity;
        attribute torque : Torque;
    }

    port def SignalOut {
        out value : Real;
    }

    port def SignalIn {
        in value : Real;
    }

    // ============ Component Definitions ============

    part def FluidReservoir {
        doc /* Storage tank that supplies hydraulic fluid to the pump
             and receives return flow from the relief valve. */;

        attribute capacity : Volume = 20 [L];
        attribute currentLevel : Volume;
        attribute fluid : HydraulicFluid;
        attribute ambientPressure : Pressure = 1 [bar];
        attribute breatherEnabled : Boolean = true;

        port supplyPort : HydraulicOutlet;
        port returnPort : HydraulicInlet;

        state reservoirStates {
            state LowLevel {
                entry { /* generate low-level warning */ }
            }
            state NormalLevel;
            state HighLevel;

            transition from LowLevel to NormalLevel
                when currentLevel > 5 [L];
            transition from NormalLevel to HighLevel
                when currentLevel >= 18 [L];
            transition from HighLevel to NormalLevel
                when currentLevel < 18 [L];
            transition from NormalLevel to LowLevel
                when currentLevel <= 5 [L];
        }
    }

    part def SuctionFilter {
        doc /* Removes particulate contaminants from the fluid before
             it enters the gear pump inlet. */;

        attribute meshSize : Length = 0.01 [mm];
        attribute maxDifferentialPressure : Pressure = 0.5 [bar];
        attribute currentDifferentialPressure : Pressure;
        attribute isClogged : Boolean = false;
        attribute surfaceArea : Area = 0.02 [m2];

        port inlet : HydraulicInlet;
        port outlet : HydraulicOutlet;

        state filterStates {
            state Operational;
            state NeedsService;
            state Clogged;

            transition from Operational to NeedsService
                when currentDifferentialPressure > 0.2 [bar];
            transition from NeedsService to Clogged
                when currentDifferentialPressure > maxDifferentialPressure;
            transition from Clogged to Operational
                when isClogged == false;
        }

        action def FilterAction {
            in dirtyFluid : HydraulicFluid;
            out cleanFluid : HydraulicFluid;
            out trappedParticles : ContaminantParticle;
        }

        action filter : FilterAction;
    }

    part def GearPump {
        doc /* Positive-displacement gear pump with a pair of meshing
             gears inside a close-tolerance housing. */;

        attribute displacement : Volume = 10 [cm3];
        attribute maxSpeed : AngularVelocity = 3000 [rpm];
        attribute ratedSpeed : AngularVelocity = 1500 [rpm];
        attribute currentSpeed : AngularVelocity;
        attribute outputPressure : Pressure;
        attribute outputFlowRate : VolumeFlowRate;
        attribute volumetricEfficiency : Real = 0.90;
        attribute maxPressure : Pressure = 250 [bar];

        port inlet : HydraulicInlet;
        port outlet : HydraulicOutlet;
        port drivePort : MechanicalShaft;

        part driveGear {
            attribute toothCount : Integer = 12;
            attribute pitchDiameter : Length = 30 [mm];
            attribute material : String = "HardenedSteel";
        }

        part drivenGear {
            attribute toothCount : Integer = 12;
            attribute pitchDiameter : Length = 30 [mm];
            attribute material : String = "HardenedSteel";
        }

        part housing {
            attribute internalClearance : Length = 0.015 [mm];
            attribute material : String = "CastIron";
        }

        action def PumpingCycle {
            in suctionFluid : HydraulicFluid;
            in shaftSpeed : AngularVelocity;
            in shaftTorque : Torque;
            out dischargeFluid : HydraulicFluid;
            out dischargePressure : Pressure;
            out dischargeFlowRate : VolumeFlowRate;
        }

        action pump : PumpingCycle;

        state pumpStates {
            state Idle {
                entry { currentSpeed = 0 [rpm]; }
            }
            state Active;
            state Faulted {
                entry { currentSpeed = 0 [rpm]; }
            }

            transition from Idle to Active
                when drivePort.speed > 0 [rpm];
            transition from Active to Idle
                when drivePort.speed == 0 [rpm];
            transition from Active to Faulted
                when outputPressure > maxPressure;
            transition from Faulted to Idle
                when drivePort.speed == 0 [rpm];
        }
    }

    part def ElectricMotor {
        doc /* Brushed DC electric motor that converts electrical power
             into rotational mechanical power to drive the gear pump. */;

        attribute ratedPower : Power = 1500 [W];
        attribute ratedSpeed : AngularVelocity = 1500 [rpm];
        attribute ratedVoltage : ElectricPotential = 24 [V];
        attribute ratedCurrent : ElectricCurrent = 60 [A];
        attribute maxCurrent : ElectricCurrent = 80 [A];
        attribute currentSpeed : AngularVelocity;
        attribute outputTorque : Torque;
        attribute inputVoltage : ElectricPotential;
        attribute inputCurrent : ElectricCurrent;
        attribute speedCommandPercent : Real;  // 0–100
        attribute motorEfficiency : Real = 0.88;

        port powerPort : ElectricalIn;
        port shaftPort : MechanicalShaft;
        port commandPort : SignalIn;

        state motorStates {
            state Off {
                entry {
                    currentSpeed = 0 [rpm];
                    outputTorque = 0 [Nm];
                }
            }
            state Starting {
                entry { currentSpeed = 0 [rpm]; }
            }
            state Running;
            state Overloaded;
            state Locked;

            transition from Off to Starting
                when commandPort.value > 0;
            transition from Starting to Running
                when currentSpeed > 100 [rpm];
            transition from Running to Off
                when commandPort.value == 0;
            transition from Running to Overloaded
                when inputCurrent > ratedCurrent;
            transition from Overloaded to Running
                when inputCurrent <= ratedCurrent;
            transition from Overloaded to Locked
                when inputCurrent > maxCurrent;
            transition from Locked to Off
                when commandPort.value == 0;
        }

        action def ConvertEnergy {
            in electricPower : ElectricalPower;
            in commandPercent : Real;
            out mechanicalSpeed : AngularVelocity;
            out mechanicalTorque : Torque;
        }

        action convert : ConvertEnergy;
    }

    part def CheckValve {
        doc /* One-way valve that prevents backflow of high-pressure fluid
             into the pump when the system is shut down. */;

        attribute crackingPressure : Pressure = 0.5 [bar];
        attribute maxPressure : Pressure = 300 [bar];
        attribute isOpen : Boolean = false;
        attribute seatDiameter : Length = 10 [mm];

        port inlet : HydraulicInlet;
        port outlet : HydraulicOutlet;

        state valveStates {
            state Closed {
                entry { isOpen = false; }
            }
            state Open {
                entry { isOpen = true; }
            }

            transition from Closed to Open
                when inlet.pressure > crackingPressure;
            transition from Open to Closed
                when inlet.pressure < crackingPressure;
        }
    }

    part def PressureReliefValve {
        doc /* Safety valve that opens when system pressure exceeds the
             preset limit and diverts excess fluid back to the reservoir. */;

        attribute setPressure : Pressure = 210 [bar];
        attribute reseatPressure : Pressure = 190 [bar];
        attribute isOpen : Boolean = false;
        attribute responseTime : Time = 10 [ms];
        attribute maxFlowCapacity : VolumeFlowRate = 80 [LiterPerMinute];

        port inlet : HydraulicInlet;
        port outlet : HydraulicOutlet;

        state reliefStates {
            state Seated {
                entry { isOpen = false; }
            }
            state Cracking;
            state FullyOpen {
                entry { isOpen = true; }
            }
            state Reseating;

            transition from Seated to Cracking
                when inlet.pressure >= setPressure;
            transition from Cracking to FullyOpen
                when inlet.pressure > setPressure;
            transition from FullyOpen to Reseating
                when inlet.pressure < reseatPressure;
            transition from Reseating to Seated
                when inlet.pressure < reseatPressure;
        }
    }

    part def PressureSensor {
        doc /* Measures hydraulic pressure on the high-pressure outlet line
             and transmits an analog signal to the control unit. */;

        attribute measuredPressure : Pressure;
        attribute measurementRange : Pressure = 300 [bar];
        attribute accuracyPercent : Real = 0.5;
        attribute updateRate : Real = 100;     // Hz

        port measurePort : HydraulicTap;
        port signalPort : SignalOut;

        action def MeasurePressure {
            in fluid : HydraulicFluid;
            in fluidPressure : Pressure;
            out signalValue : Real;
        }

        action measure : MeasurePressure;
    }

    part def FlowMeter {
        doc /* Measures volumetric flow rate on the high-pressure outlet line
             and transmits an analog signal to the control unit. */;

        attribute measuredFlowRate : VolumeFlowRate;
        attribute measurementRange : VolumeFlowRate = 100 [LiterPerMinute];
        attribute accuracyPercent : Real = 1.0;
        attribute updateRate : Real = 50;    // Hz

        port measurePort : HydraulicTap;
        port signalPort : SignalOut;

        action def MeasureFlow {
            in fluid : HydraulicFluid;
            in flowRate : VolumeFlowRate;
            out signalValue : Real;
        }

        action measure : MeasureFlow;
    }

    part def TemperatureSensor {
        doc /* Measures fluid temperature on the high-pressure outlet line
             and transmits an analog signal to the control unit. */;

        attribute measuredTemperature : ThermodynamicTemperature;
        attribute measurementRange : ThermodynamicTemperature = 150 [degC];
        attribute accuracyPercent : Real = 0.5;
        attribute updateRate : Real = 10;    // Hz

        port measurePort : HydraulicTap;
        port signalPort : SignalOut;

        action def MeasureTemperature {
            in fluid : HydraulicFluid;
            in fluidTemp : ThermodynamicTemperature;
            out signalValue : Real;
        }

        action measure : MeasureTemperature;
    }

    part def ControlUnit {
        doc /* Embedded electronic controller that reads sensor signals,
             computes motor speed commands, manages power distribution,
             and supervises safe operation of the pumping subsystem. */;

        attribute targetPressure : Pressure = 150 [bar];
        attribute targetFlowRate : VolumeFlowRate = 50 [LiterPerMinute];
        attribute maxTemperature : ThermodynamicTemperature = 80 [degC];
        attribute criticalTemperature : ThermodynamicTemperature = 95 [degC];
        attribute maxPressure : Pressure = 200 [bar];

        attribute currentPressure : Pressure;
        attribute currentFlowRate : VolumeFlowRate;
        attribute currentTemperature : ThermodynamicTemperature;
        attribute motorSpeedCommand : Real;   // percent 0–100
        attribute systemStatus : String;
        attribute outputVoltage : ElectricPotential;
        attribute outputCurrent : ElectricCurrent;
        attribute faultCode : Integer;

        port pressureInput : SignalIn;
        port flowInput : SignalIn;
        port tempInput : SignalIn;
        port motorCommandOutput : SignalOut;
        port powerInPort : ElectricalIn;
        port powerOutPort : ElectricalOut;

        action def ReadSensors {
            in pressureSignal : Real;
            in flowSignal : Real;
            in tempSignal : Real;
            out pressure : Pressure;
            out flowRate : VolumeFlowRate;
            out temperature : ThermodynamicTemperature;
        }

        action readSensors : ReadSensors;

        action def ComputeCommand {
            in pressure : Pressure;
            in flowRate : VolumeFlowRate;
            in temperature : ThermodynamicTemperature;
            out commandPercent : Real;
            out status : String;
        }

        action compute : ComputeCommand;

        state controlStates {
            state Booting {
                entry {
                    systemStatus = "Booting";
                    motorSpeedCommand = 0;
                    faultCode = 0;
                }
            }
            state NormalOperation {
                entry { systemStatus = "Normal"; }
            }
            state HighPressureMode {
                entry { systemStatus = "HighPressure"; }
            }
            state LowFlowMode {
                entry { systemStatus = "LowFlow"; }
            }
            state OverheatProtection {
                entry {
                    systemStatus = "Overheat";
                    motorSpeedCommand = 0;
                }
            }
            state EmergencyShutdown {
                entry {
                    systemStatus = "Shutdown";
                    motorSpeedCommand = 0;
                }
            }

            transition from Booting to NormalOperation
                when pressureInput.value >= 0;

            transition from NormalOperation to HighPressureMode
                when currentPressure > targetPressure;
            transition from HighPressureMode to NormalOperation
                when currentPressure <= targetPressure;

            transition from NormalOperation to LowFlowMode
                when currentFlowRate < targetFlowRate;
            transition from LowFlowMode to NormalOperation
                when currentFlowRate >= targetFlowRate;

            transition from NormalOperation to OverheatProtection
                when currentTemperature > maxTemperature;
            transition from HighPressureMode to OverheatProtection
                when currentTemperature > maxTemperature;
            transition from LowFlowMode to OverheatProtection
                when currentTemperature > maxTemperature;

            transition from OverheatProtection to EmergencyShutdown
                when currentTemperature > criticalTemperature;

            transition from EmergencyShutdown to Booting
                when currentTemperature <= maxTemperature
                    && pressureInput.value == 0;
        }
    }

    // ============ System Assembly ============

    part def HydraulicPumpingSystem {
        doc /* Self-contained, electronically controlled hydraulic pumping
             subsystem. Draws fluid from a reservoir, filters it, pressurizes
             it with a gear pump driven by an electric motor, and delivers
             controlled high-pressure flow while protecting against
             over-pressure and over-temperature conditions. */;

        attribute systemName : String = "HydraulicPumpingSubsystem";
        attribute designPressure : Pressure = 200 [bar];
        attribute designFlowRate : VolumeFlowRate = 50 [LiterPerMinute];

        port systemPowerInput : ElectricalIn;
        port systemFluidOutput : HydraulicOutlet;

        part reservoir : FluidReservoir;
        part suctionFilter : SuctionFilter;
        part pump : GearPump;
        part motor : ElectricMotor;
        part checkValve : CheckValve;
        part reliefValve : PressureReliefValve;
        part pressureSensor : PressureSensor;
        part flowMeter : FlowMeter;
        part tempSensor : TemperatureSensor;
        part controller : ControlUnit;

        // -- Hydraulic connections: main flow path --
        connect reservoir.supplyPort to suctionFilter.inlet;
        connect suctionFilter.outlet to pump.inlet;
        connect pump.outlet to checkValve.inlet;
        connect checkValve.outlet to systemFluidOutput;

        // -- Hydraulic connections: relief-valve bypass back to reservoir --
        connect pump.outlet to reliefValve.inlet;
        connect reliefValve.outlet to reservoir.returnPort;

        // -- Sensor taps on the high-pressure outlet line --
        connect checkValve.outlet to pressureSensor.measurePort;
        connect checkValve.outlet to flowMeter.measurePort;
        connect checkValve.outlet to tempSensor.measurePort;

        // -- Signal connections: sensors → controller --
        connect pressureSensor.signalPort to controller.pressureInput;
        connect flowMeter.signalPort to controller.flowInput;
        connect tempSensor.signalPort to controller.tempInput;

        // -- Signal connection: controller → motor speed command --
        connect controller.motorCommandOutput to motor.commandPort;

        // -- Electrical connections: power distribution --
        connect systemPowerInput to controller.powerInPort;
        connect controller.powerOutPort to motor.powerPort;

        // -- Mechanical connection: motor shaft → pump drive shaft --
        connect motor.shaftPort to pump.drivePort;
    }

    // ============ Requirements ============

    requirement def PressurizationRequirement {
        doc /* The system shall pressurize hydraulic fluid to at least
             150 bar at the outlet under nominal operating conditions. */;
        subject system : HydraulicPumpingSystem;
        require {
            system.pump.outputPressure >= 150 [bar]
        }
    }

    requirement def FlowRateRequirement {
        doc /* The system shall deliver a controlled flow rate of
             50 L/min plus or minus 5 percent at the outlet. */;
        subject system : HydraulicPumpingSystem;
        require {
            system.designFlowRate == 50 [LiterPerMinute]
        }
    }

    requirement def BackflowPreventionRequirement {
        doc /* The check valve shall prevent reverse flow of high-pressure
             fluid into the pump when the system is shut down. */;
        subject valve : CheckValve;
        require {
            valve.isOpen == false
                when valve.inlet.pressure < valve.outlet.pressure
        }
    }

    requirement def OverPressureProtectionRequirement {
        doc /* The pressure relief valve shall open and divert excess fluid
             to the reservoir when outlet pressure exceeds 210 bar. */;
        subject valve : PressureReliefValve;
        require {
            valve.isOpen == true
                when valve.inlet.pressure > 210 [bar]
        }
    }

    requirement def ThermalProtectionRequirement {
        doc /* The control unit shall initiate protective shutdown when
             fluid temperature exceeds 80 degC. */;
        subject controller : ControlUnit;
        require {
            controller.systemStatus == "Overheat"
                when controller.currentTemperature > 80 [degC]
        }
    }

    requirement def EmergencyShutdownRequirement {
        doc /* The control unit shall command motor speed to zero and enter
             emergency shutdown when fluid temperature exceeds 95 degC. */;
        subject controller : ControlUnit;
        require {
            controller.motorSpeedCommand == 0
                when controller.currentTemperature > 95 [degC]
        }
    }

    requirement def FiltrationRequirement {
        doc /* The suction filter shall remove particles larger than
             10 micrometres before fluid enters the pump. */;
        subject filter : SuctionFilter;
        require {
            filter.meshSize <= 0.01 [mm]
        }
    }

    requirement def MotorSizingRequirement {
        doc /* The electric motor shall be rated for at least 1500 W
             and 24 V DC operation. */;
        subject motor : ElectricMotor;
        require {
            motor.ratedPower >= 1500 [W]
                and motor.ratedVoltage == 24 [V]
        }
    }

    requirement def ControlResponsivenessRequirement {
        doc /* The control unit shall adjust motor speed within 100 ms
             of receiving updated sensor data. */;
        subject controller : ControlUnit;
        attribute maxResponseTime : Time = 0.1 [s];
        require {
            /* response latency bounded by maxResponseTime */
        }
    }

    requirement def ReservoirCapacityRequirement {
        doc /* The fluid reservoir shall have a usable capacity of at
             least 20 litres. */;
        subject reservoir : FluidReservoir;
        require {
            reservoir.capacity >= 20 [L]
        }
    }

    requirement def PumpDisplacementRequirement {
        doc /* The gear pump shall have a displacement of at least
             10 cubic centimetres per revolution. */;
        subject pump : GearPump;
        require {
            pump.displacement >= 10 [cm3]
        }
    }

    requirement def SensorAccuracyRequirement {
        doc /* All sensors shall have measurement accuracy of
             1 percent full scale or better. */;
        subject system : HydraulicPumpingSystem;
        require {
            system.pressureSensor.accuracyPercent <= 1.0
                and system.flowMeter.accuracyPercent <= 1.0
                and system.tempSensor.accuracyPercent <= 1.0
        }
    }

    // -- Requirement satisfactions --
    satisfaction pressurizationSatisfaction : PressurizationRequirement {
        subject system : HydraulicPumpingSystem;
    }

    satisfaction flowRateSatisfaction : FlowRateRequirement {
        subject system : HydraulicPumpingSystem;
    }

    satisfaction backflowSatisfaction : BackflowPreventionRequirement {
        subject valve : CheckValve;
    }

    satisfaction overPressureSatisfaction : OverPressureProtectionRequirement {
        subject valve : PressureReliefValve;
    }

    satisfaction thermalSatisfaction : ThermalProtectionRequirement {
        subject controller : ControlUnit;
    }

    satisfaction emergencySatisfaction : EmergencyShutdownRequirement {
        subject controller : ControlUnit;
    }

    satisfaction filtrationSatisfaction : FiltrationRequirement {
        subject filter : SuctionFilter;
    }

    satisfaction motorSizingSatisfaction : MotorSizingRequirement {
        subject motor : ElectricMotor;
    }

    satisfaction reservoirSatisfaction : ReservoirCapacityRequirement {
        subject reservoir : FluidReservoir;
    }

    satisfaction pumpDisplacementSatisfaction : PumpDisplacementRequirement {
        subject pump : GearPump;
    }

    satisfaction sensorAccuracySatisfaction : SensorAccuracyRequirement {
        subject system : HydraulicPumpingSystem;
    }

}
