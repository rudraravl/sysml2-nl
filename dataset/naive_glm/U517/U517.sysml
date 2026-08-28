package HydraulicPowerUnitSystem {
    import ScalarValues::*;

    // ===== Value Types with Units =====
    def PressureValue :> Real { unit 'Pa'; }
    def FlowRateValue :> Real { unit 'm3/s'; }
    def TemperatureValue :> Real { unit 'K'; }
    def VoltageValue :> Real { unit 'V'; }
    def CurrentValue :> Real { unit 'A'; }
    def AngularSpeedValue :> Real { unit 'rad/s'; }
    def VolumeValue :> Real { unit 'm3'; }
    def TorqueValue :> Real { unit 'N.m'; }
    def PowerValue :> Real { unit 'W'; }
    def DimensionlessValue :> Real;

    // ===== Item Definitions =====
    item def HydraulicFluid {
        attribute density : Real { unit 'kg/m3'; } = 850;
        attribute viscosity : Real { unit 'Pa.s'; } = 0.04;
    }

    item def ElectricalEnergy {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    item def PressureReading {
        attribute value : PressureValue;
    }

    item def TemperatureReading {
        attribute value : TemperatureValue;
    }

    item def LevelReading {
        attribute value : VolumeValue;
    }

    // ===== Port Definitions =====
    port def HydraulicPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
    }

    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }

    port def MechanicalPort {
        attribute speed : AngularSpeedValue;
        attribute torque : TorqueValue;
    }

    port def PressureSensorPort {
        out reading : PressureReading;
    }

    port def TemperatureSensorPort {
        out reading : TemperatureReading;
    }

    port def LevelSensorPort {
        out reading : LevelReading;
    }

    port def MotorControlPort {
        in speedCommand : AngularSpeedValue;
    }

    port def ValveControlPort {
        in positionCommand : DimensionlessValue;
    }

    port def SystemControlPort {
        in startCommand : Boolean;
        in stopCommand : Boolean;
        in resetCommand : Boolean;
        in targetPressureSetpoint : PressureValue;
    }

    // ===== Part Definitions =====

    part def ElectricMotor {
        port electricIn : ElectricalPort;
        port mechanicalOut : MechanicalPort;
        port controlIn : MotorControlPort;

        attribute ratedPower : PowerValue = 15000;
        attribute ratedVoltage : VoltageValue = 400;
        attribute ratedSpeed : AngularSpeedValue = 157.08;
        attribute currentSpeed : AngularSpeedValue = 0;
        attribute currentTorque : TorqueValue = 0;
        attribute efficiency : DimensionlessValue = 0.93;

        action def ConvertEnergy {
            in voltage : VoltageValue;
            in current : CurrentValue;
            in speedCommand : AngularSpeedValue;
            out speed : AngularSpeedValue;
            out torque : TorqueValue;
        }

        perform ConvertEnergy;
    }

    part def HydraulicPump {
        port mechanicalIn : MechanicalPort;
        port suction : HydraulicPort;
        port discharge : HydraulicPort;

        attribute displacement : VolumeValue = 0.000023;
        attribute efficiency : DimensionlessValue = 0.92;
        attribute maxPressure : PressureValue = 35000000;
        attribute outputPressure : PressureValue = 0;
        attribute outputFlowRate : FlowRateValue = 0;

        action def Pressurize {
            in speed : AngularSpeedValue;
            in suctionPressure : PressureValue;
            out dischargePressure : PressureValue;
            out flowRate : FlowRateValue;
        }

        perform Pressurize;
    }

    part def Reservoir {
        port suctionOut : HydraulicPort;
        port returnIn : HydraulicPort;
        port levelOut : LevelSensorPort;

        attribute capacity : VolumeValue = 0.1;
        attribute currentLevel : VolumeValue = 0.08;
        attribute fluidTemperature : TemperatureValue = 293.15;
        attribute minLevel : VolumeValue = 0.01;

        item storedFluid : HydraulicFluid;

        action def SupplyFluid {
            out fluid : HydraulicFluid;
            out level : VolumeValue;
        }

        action def ReceiveFluid {
            in fluid : HydraulicFluid;
            out level : VolumeValue;
        }

        perform SupplyFluid;
        perform ReceiveFluid;
    }

    part def PressureSensor {
        port hydraulicIn : HydraulicPort;
        port signalOut : PressureSensorPort;

        attribute range : PressureValue = 40000000;
        attribute accuracy : DimensionlessValue = 0.005;
        attribute reading : PressureValue = 0;

        action def Measure {
            in pressure : PressureValue;
            out reading : PressureReading;
        }

        perform Measure;
    }

    part def TemperatureSensor {
        port hydraulicIn : HydraulicPort;
        port signalOut : TemperatureSensorPort;

        attribute range : TemperatureValue = 423.15;
        attribute reading : TemperatureValue = 293.15;

        action def Measure {
            in temperature : TemperatureValue;
            out reading : TemperatureReading;
        }

        perform Measure;
    }

    part def ReliefValve {
        port highPressureIn : HydraulicPort;
        port returnOut : HydraulicPort;

        attribute crackPressure : PressureValue = 35000000;
        attribute fullFlowPressure : PressureValue = 38000000;
        attribute isOpen : Boolean = false;
        attribute divertedFlowRate : FlowRateValue = 0;

        action def Regulate {
            in pressure : PressureValue;
            out divertedFlowRate : FlowRateValue;
            out isOpen : Boolean;
        }

        perform Regulate;
    }

    part def Accumulator {
        port hydraulicIn : HydraulicPort;
        port hydraulicOut : HydraulicPort;

        attribute volume : VolumeValue = 0.005;
        attribute prechargePressure : PressureValue = 20000000;
        attribute gasType : String = "Nitrogen";
        attribute currentPressure : PressureValue = 20000000;
        attribute storedVolume : VolumeValue = 0;
        attribute maxPressure : PressureValue = 35000000;

        action def StoreAndRelease {
            in pressure : PressureValue;
            out storedFluidPressure : PressureValue;
            out storedVolume : VolumeValue;
        }

        perform StoreAndRelease;
    }

    part def ControlValve {
        port hydraulicIn : HydraulicPort;
        port hydraulicOut : HydraulicPort;
        port controlIn : ValveControlPort;

        attribute position : DimensionlessValue = 0;
        attribute maxFlowRate : FlowRateValue = 0.001;
        attribute currentFlowRate : FlowRateValue = 0;

        action def RegulateFlow {
            in position : DimensionlessValue;
            in pressure : PressureValue;
            out flowRate : FlowRateValue;
        }

        perform RegulateFlow;
    }

    part def SystemController {
        port pressureSensorIn : PressureSensorPort;
        port tempSensorIn : TemperatureSensorPort;
        port levelSensorIn : LevelSensorPort;
        port motorControlOut : MotorControlPort;
        port valveControlOut : ValveControlPort;
        port systemControlIn : SystemControlPort;

        attribute targetPressure : PressureValue = 25000000;
        attribute maxSafePressure : PressureValue = 35000000;
        attribute maxSafeTemp : TemperatureValue = 353.15;
        attribute minFluidLevel : VolumeValue = 0.01;
        attribute kp : DimensionlessValue = 0.001;
        attribute ki : DimensionlessValue = 0.0001;
        attribute integralError : DimensionlessValue = 0;
        attribute motorSpeedCommand : AngularSpeedValue = 0;
        attribute valvePositionCommand : DimensionlessValue = 0;
        attribute emergencyShutdown : Boolean = false;
        attribute startCommand : Boolean = false;
        attribute stopCommand : Boolean = false;
        attribute resetCommand : Boolean = false;
        attribute fault : String = "";
        attribute ratedSpeed : AngularSpeedValue = 157.08;
        attribute currentPressure : PressureValue = 0;
        attribute currentTemp : TemperatureValue = 293.15;
        attribute currentLevel : VolumeValue = 0;
        attribute pressureError : PressureValue = 0;

        action def CheckFluidLevel {
            in level : VolumeValue;
            in minLevel : VolumeValue;
            out pass : Boolean;
        }

        action def CheckSensors {
            out pass : Boolean;
        }

        action def MonitorPressure {
            in reading : PressureReading;
            out pressure : PressureValue;
        }

        action def AdjustMotorSpeed {
            in currentPressure : PressureValue;
            in targetPressure : PressureValue;
            out speedCommand : AngularSpeedValue;
        }

        action def CheckSafety {
            in pressure : PressureValue;
            in temperature : TemperatureValue;
            in maxPressure : PressureValue;
            in maxTemp : TemperatureValue;
            out faultDetected : Boolean;
        }

        state def ControllerStates {
            entry; then Off;

            state Off {
                entry {
                    motorSpeedCommand = 0;
                    valvePositionCommand = 0;
                    emergencyShutdown = false;
                }
            }

            transition InitTransition
                from Off to Initializing
                when startCommand;

            state Initializing {
                entry {
                    fault = "";
                }
                do {
                    currentLevel = levelSensorIn.reading.value;
                }
            }

            transition InitToReady
                from Initializing to Ready
                when currentLevel >= minFluidLevel;

            transition InitToFault
                from Initializing to Faulted
                when currentLevel < minFluidLevel;

            state Ready {
                entry {
                    motorSpeedCommand = 0;
                    valvePositionCommand = 0;
                }
            }

            transition ReadyToOperating
                from Ready to Operating
                when startCommand;

            state Operating {
                entry {
                    motorSpeedCommand = ratedSpeed;
                    valvePositionCommand = 0.5;
                }
                do {
                    currentPressure = pressureSensorIn.reading.value;
                    currentTemp = tempSensorIn.reading.value;
                    pressureError = targetPressure - currentPressure;
                    integralError = integralError + pressureError;
                    motorSpeedCommand = ratedSpeed + kp * pressureError + ki * integralError;
                }
            }

            transition OperatingToShutdown
                from Operating to ShuttingDown
                when stopCommand;

            transition OperatingToFault
                from Operating to Faulted
                when currentPressure > maxSafePressure or currentTemp > maxSafeTemp;

            state ShuttingDown {
                entry {
                    motorSpeedCommand = 0;
                    valvePositionCommand = 0;
                }
                do {
                    currentPressure = pressureSensorIn.reading.value;
                }
            }

            transition ShutdownComplete
                from ShuttingDown to Off
                when currentPressure < 1000000;

            state Faulted {
                entry {
                    motorSpeedCommand = 0;
                    valvePositionCommand = 0;
                    emergencyShutdown = true;
                }
            }

            transition FaultReset
                from Faulted to Off
                when resetCommand;
        }

        exhibit state ControllerStates;
    }

    // ===== Top-Level HPU System =====
    part def HydraulicPowerUnit {
        port electricalInput : ElectricalPort;
        port hydraulicOutput : HydraulicPort;
        port systemControl : SystemControlPort;

        part motor : ElectricMotor;
        part pump : HydraulicPump;
        part reservoir : Reservoir;
        part pressureSensor : PressureSensor;
        part temperatureSensor : TemperatureSensor;
        part reliefValve : ReliefValve;
        part accumulator : Accumulator;
        part controlValve : ControlValve;
        part controller : SystemController;

        // Electrical power input to motor
        connect electricalInput to motor.electricIn;

        // Mechanical coupling: motor drives pump
        connect motor.mechanicalOut to pump.mechanicalIn;

        // Hydraulic suction: reservoir to pump
        connect reservoir.suctionOut to pump.suction;

        // Hydraulic high-pressure circuit: pump to relief valve
        connect pump.discharge to reliefValve.highPressureIn;

        // Relief valve return to reservoir
        connect reliefValve.returnOut to reservoir.returnIn;

        // High-pressure line to accumulator
        connect reliefValve.highPressureIn to accumulator.hydraulicIn;

        // Accumulator to control valve
        connect accumulator.hydraulicOut to controlValve.hydraulicIn;

        // Control valve to system output
        connect controlValve.hydraulicOut to hydraulicOutput;

        // Pressure sensor taps high-pressure line
        connect pump.discharge to pressureSensor.hydraulicIn;

        // Temperature sensor monitors reservoir fluid
        connect reservoir.suctionOut to temperatureSensor.hydraulicIn;

        // Sensor signal connections to controller
        connect pressureSensor.signalOut to controller.pressureSensorIn;
        connect temperatureSensor.signalOut to controller.tempSensorIn;
        connect reservoir.levelOut to controller.levelSensorIn;

        // Controller command outputs
        connect controller.motorControlOut to motor.controlIn;
        connect controller.valveControlOut to controlValve.controlIn;

        // External system control to controller
        connect systemControl to controller.systemControlIn;
    }

    // ===== Requirements =====
    requirement def PressureGenerationRequirement {
        doc /* The HPU shall generate hydraulic fluid at the target pressure of 25 MPa (250 bar). */;
    }

    requirement def PressureRegulationRequirement {
        doc /* The controller shall maintain output pressure within plus or minus 2 percent of the target pressure under steady-state conditions. */;
    }

    requirement def SafetyReliefRequirement {
        doc /* The relief valve shall crack open at 35 MPa (350 bar) and divert excess fluid back to the reservoir to prevent over-pressure damage. */;
    }

    requirement def EmergencyShutdownRequirement {
        doc /* The controller shall trigger an immediate emergency shutdown upon detecting over-pressure above 35 MPa or fluid temperature above 353.15 K (80 degrees C). */;
    }

    requirement def AccumulatorSmoothingRequirement {
        doc /* The accumulator shall absorb pressure fluctuations from the pump discharge and provide temporary flow boost when downstream demand increases. */;
    }

    requirement def FlowRegulationRequirement {
        doc /* The control valve shall regulate output flow rate from 0 to 0.001 cubic meters per second (60 liters per minute) based on controller position commands. */;
    }

    requirement def StartupSequenceRequirement {
        doc /* Upon receiving a start command, the system shall perform initialization checks including fluid level verification and sensor health checks before entering operating mode. */;
    }

    requirement def ControlledShutdownRequirement {
        doc /* The system shall support a normal controlled shutdown sequence that ramps motor speed to zero and closes the control valve, and an immediate emergency stop that halts all operation upon critical fault detection. */;
    }

    requirement def FluidLevelMonitoringRequirement {
        doc /* The reservoir shall provide a continuous fluid level reading to the controller, and the controller shall prevent startup if the fluid level is below the minimum threshold of 0.01 cubic meters. */;
    }

    // ===== Requirement Satisfaction =====
    part hpuInstance : HydraulicPowerUnit {
        satisfy PressureGenerationRequirement;
        satisfy PressureRegulationRequirement;
        satisfy SafetyReliefRequirement;
        satisfy EmergencyShutdownRequirement;
        satisfy AccumulatorSmoothingRequirement;
        satisfy FlowRegulationRequirement;
        satisfy StartupSequenceRequirement;
        satisfy ControlledShutdownRequirement;
        satisfy FluidLevelMonitoringRequirement;
    }
}
