package IndustrialFluidTransferSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    attribute def PressureValue :> Real { unit 'Pa'; }
    attribute def FlowRateValue :> Real { unit 'm3/s'; }
    attribute def RotationalSpeedValue :> Real { unit 'rad/s'; }
    attribute def TorqueValue :> Real { unit 'N*m'; }
    attribute def PowerValue :> Real { unit 'W'; }
    attribute def TemperatureValue :> Real { unit 'K'; }
    attribute def VolumeValue :> Real { unit 'm3'; }
    attribute def ViscosityValue :> Real { unit 'Pa*s'; }
    attribute def DurationValue :> Real { unit 's'; }

    // ===== Item Definitions =====
    item def ViscousFluid {
        attribute viscosity : ViscosityValue;
        attribute density : Real { unit 'kg/m3'; }
        attribute temperature : TemperatureValue;
    }

    // ===== Port Definitions =====
    port def FluidPort {
        in item fluid : ViscousFluid;
        out attribute pressure : PressureValue;
        out attribute flowRate : FlowRateValue;
    }

    port def MechanicalDrivePort {
        out attribute speed : RotationalSpeedValue;
        out attribute torque : TorqueValue;
    }

    port def ElectricalPowerPort {
        in attribute voltage : Real { unit 'V'; }
        in attribute current : Real { unit 'A'; }
    }

    port def ControlSignalPort {
        in attribute command : String;
        in attribute setpoint : PressureValue;
    }

    port def SensorOutputPort {
        out attribute measuredPressure : PressureValue;
        out attribute measuredFlowRate : FlowRateValue;
        out attribute status : String;
    }

    // ===== Requirements =====
    requirement def PressureMonitoringRequirement {
        attribute maxOutletPressure : PressureValue = 700000;
        subject sensorPressure : PressureValue;
        require sensorPressure <= maxOutletPressure;
    }

    requirement def FlowMonitoringRequirement {
        attribute minFlowRate : FlowRateValue = 0.001;
        subject measuredFlow : FlowRateValue;
        require measuredFlow >= minFlowRate;
    }

    requirement def SafetyReliefRequirement {
        attribute reliefSetPoint : PressureValue = 600000;
        subject systemPressure : PressureValue;
        require if systemPressure > reliefSetPoint then true;
    }

    requirement def ContinuousOperationRequirement {
        attribute designLife : DurationValue = 31536000;
        subject operatingTime : DurationValue;
        require operatingTime <= designLife;
    }

    // ===== Part Definitions =====

    part def SupplyTank {
        port outletPort : FluidPort;
        attribute capacity : VolumeValue = 5.0;
        attribute currentVolume : VolumeValue;
        attribute fillLevel : Real;

        exhibit state tankBehavior {
            entry;
            state Providing;
            state LowLevel {
                entry;
            }
            transition provideToLow
                first Providing
                if currentVolume < 0.1 * capacity
                then LowLevel;
        }
    }

    part def ReceivingTank {
        port inletPort : FluidPort;
        attribute capacity : VolumeValue = 3.0;
        attribute currentVolume : VolumeValue;
        attribute internalPressure : PressureValue;
        attribute maxWorkingPressure : PressureValue = 500000;

        exhibit state tankBehavior {
            entry;
            state Receiving;
            state Pressurized {
                entry;
            }
            state OverPressurized {
                entry;
            }
            transition receiveToPressurized
                first Receiving
                if internalPressure > 200000
                then Pressurized;
            transition pressurizedToOver
                first Pressurized
                if internalPressure > maxWorkingPressure
                then OverPressurized;
        }
    }

    part def IsolationValve {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        port controlPort : ControlSignalPort;
        attribute isOpen : Boolean = false;
        attribute position : Real = 0.0;

        exhibit state valveBehavior {
            entry;
            state Closed;
            state Opening {
                entry;
                do assign position : Real = 0.0;
            }
            state Open;
            state Closing {
                entry;
            }
            transition closedToOpening
                first Closed
                if controlPort.command == "open"
                then Opening;
            transition openingToOpen
                first Opening
                if position >= 1.0
                then Open;
            transition openToClosing
                first Open
                if controlPort.command == "close"
                then Closing;
            transition closingToClosed
                first Closing
                if position <= 0.0
                then Closed;
        }
    }

    part def PressureReliefValve {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        attribute setPoint : PressureValue = 600000;
        attribute isOpen : Boolean = false;
        attribute crackingPressure : PressureValue = 580000;

        exhibit state reliefBehavior {
            entry;
            state Sealed;
            state Cracking {
                entry;
            }
            state Open {
                entry;
            }
            state Reseating {
                entry;
            }
            transition sealedToCracking
                first Sealed
                if inletPort.pressure >= crackingPressure
                then Cracking;
            transition crackingToOpen
                first Cracking
                if inletPort.pressure >= setPoint
                then Open;
            transition openToReseating
                first Open
                if inletPort.pressure < setPoint
                then Reseating;
            transition reseatingToSealed
                first Reseating
                if inletPort.pressure < crackingPressure
                then Sealed;
        }
    }

    part def ElectricMotor {
        port drivePort : MechanicalDrivePort;
        port powerPort : ElectricalPowerPort;
        port controlPort : ControlSignalPort;
        attribute ratedPower : PowerValue = 15000;
        attribute ratedSpeed : RotationalSpeedValue = 157.08;
        attribute currentSpeed : RotationalSpeedValue = 0.0;
        attribute outputTorque : TorqueValue = 0.0;
        attribute isEnergized : Boolean = false;

        exhibit state motorBehavior {
            entry;
            state Deenergized;
            state Starting {
                entry;
                do assign currentSpeed : RotationalSpeedValue = 0.0;
            }
            state Running;
            state Stopping {
                entry;
            }
            state Faulted {
                entry;
            }
            transition deenergToStarting
                first Deenergized
                if controlPort.command == "start"
                then Starting;
            transition startingToRunning
                first Starting
                if currentSpeed >= ratedSpeed * 0.95
                then Running;
            transition runningToStopping
                first Running
                if controlPort.command == "stop"
                then Stopping;
            transition stoppingToDeenerg
                first Stopping
                if currentSpeed <= 0.0
                then Deenergized;
            transition runningToFaulted
                first Running
                if outputTorque > 2.0 * ratedPower / ratedSpeed
                then Faulted;
        }
    }

    part def PressureSensor {
        port measurementPort : FluidPort;
        port outputPort : SensorOutputPort;
        attribute calibrated : Boolean = true;
        attribute measurementRange : PressureValue = 1000000;
        attribute accuracy : Real = 0.01;

        exhibit state sensorBehavior {
            entry;
            state Measuring;
            state Faulted {
                entry;
            }
            transition measuringToFaulted
                first Measuring
                if measurementPort.pressure > measurementRange
                then Faulted;
        }
    }

    part def FlowMeter {
        port measurementPort : FluidPort;
        port outputPort : SensorOutputPort;
        attribute calibrated : Boolean = true;
        attribute maxFlowRange : FlowRateValue = 0.05;
        attribute accuracy : Real = 0.005;

        exhibit state meterBehavior {
            entry;
            state Measuring;
            state Faulted {
                entry;
            }
            transition measuringToFaulted
                first Measuring
                if measurementPort.flowRate > maxFlowRange
                then Faulted;
        }
    }

    part def WendelkolbenPump {
        port inletPort : FluidPort;
        port outletPort : FluidPort;
        port drivePort : MechanicalDrivePort;
        port controlPort : ControlSignalPort;

        attribute displacement : VolumeValue = 0.0008;
        attribute rotorDiameter : Real { unit 'm'; } = 0.08;
        attribute statorMaterial : String = "Elastomer";
        attribute rotorMaterial : String = "HardenedSteel";
        attribute eccentricity : Real { unit 'm'; } = 0.004;
        attribute helixLead : Real { unit 'm'; } = 0.12;
        attribute efficiency : Real = 0.85;
        attribute inletPressure : PressureValue;
        attribute outletPressure : PressureValue;
        attribute pumpSpeed : RotationalSpeedValue = 0.0;
        attribute flowRate : FlowRateValue = 0.0;
        attribute maxDifferentialPressure : PressureValue = 800000;

        exhibit state pumpOperation {
            entry;
            state Stopped {
                entry;
                do assign pumpSpeed : RotationalSpeedValue = 0.0;
                do assign flowRate : FlowRateValue = 0.0;
            }
            state Starting {
                entry;
            }
            state NormalOperation {
                entry;
                do assign flowRate : FlowRateValue = displacement * pumpSpeed / (2 * 3.14159);
            }
            state HighPressureCondition {
                entry;
            }
            state LowFlowCondition {
                entry;
            }
            state Fault {
                entry;
                do assign pumpSpeed : RotationalSpeedValue = 0.0;
                do assign flowRate : FlowRateValue = 0.0;
            }

            transition stoppedToStarting
                first Stopped
                if controlPort.command == "start"
                then Starting;
            transition startingToNormal
                first Starting
                if pumpSpeed > 0.0 and (outletPressure - inletPressure) < maxDifferentialPressure
                then NormalOperation;
            transition normalToHighPressure
                first NormalOperation
                if (outletPressure - inletPressure) > maxDifferentialPressure * 0.95
                then HighPressureCondition;
            transition normalToLowFlow
                first NormalOperation
                if flowRate < 0.0005
                then LowFlowCondition;
            transition highPressureToNormal
                first HighPressureCondition
                if (outletPressure - inletPressure) < maxDifferentialPressure * 0.85
                then NormalOperation;
            transition lowFlowToNormal
                first LowFlowCondition
                if flowRate >= 0.001
                then NormalOperation;
            transition anyToFault
                first NormalOperation
                if drivePort.torque > 500.0
                then Fault;
            transition faultToStopped
                first Fault
                if controlPort.command == "reset"
                then Stopped;
        }
    }

    part def SystemController {
        port inletSensorPort : SensorOutputPort;
        port outletSensorPort : SensorOutputPort;
        port flowMeterPort : SensorOutputPort;
        port pumpControlPort : ControlSignalPort;
        port motorControlPort : ControlSignalPort;
        port inletValveControlPort : ControlSignalPort;
        port outletValveControlPort : ControlSignalPort;

        attribute highPressureThreshold : PressureValue = 650000;
        attribute lowFlowThreshold : FlowRateValue = 0.0008;
        attribute nominalFlowSetpoint : FlowRateValue = 0.005;
        attribute systemActive : Boolean = false;

        exhibit state controllerBehavior {
            entry;
            state Idle;
            state Initializing {
                entry;
            }
            state Monitoring;
            state HighPressureResponse {
                entry;
            }
            state LowFlowResponse {
                entry;
            }
            state EmergencyShutdown {
                entry;
            }

            transition idleToInitializing
                first Idle
                if true
                then Initializing;
            transition initializingToMonitoring
                first Initializing
                if true
                then Monitoring;
            transition monitoringToHighPressure
                first Monitoring
                if outletSensorPort.measuredPressure > highPressureThreshold
                then HighPressureResponse;
            transition monitoringToLowFlow
                first Monitoring
                if flowMeterPort.measuredFlowRate < lowFlowThreshold
                then LowFlowResponse;
            transition highPressureToEmergency
                first HighPressureResponse
                if outletSensorPort.measuredPressure > highPressureThreshold * 1.1
                then EmergencyShutdown;
            transition lowFlowToEmergency
                first LowFlowResponse
                if flowMeterPort.measuredFlowRate < lowFlowThreshold * 0.5
                then EmergencyShutdown;
            transition emergencyToIdle
                first EmergencyShutdown
                if true
                then Idle;
        }
    }

    // ===== System Assembly =====
    part def FluidTransferSystem {
        // Components
        part supplyTank : SupplyTank {
            attribute currentVolume = 4.5;
        }
        part receivingTank : ReceivingTank {
            attribute currentVolume = 0.0;
            attribute internalPressure = 100000;
        }
        part inletIsolationValve : IsolationValve;
        part wendelkolbenPump : WendelkolbenPump;
        part electricMotor : ElectricMotor;
        part inletPressureSensor : PressureSensor;
        part outletPressureSensor : PressureSensor;
        part flowMeter : FlowMeter;
        part pressureReliefValve : PressureReliefValve;
        part outletIsolationValve : IsolationValve;
        part systemController : SystemController;

        // Internal piping connections
        connection supplyToInletValve : FluidPort
            connect supplyTank.outletPort to inletIsolationValve.inletPort;
        connection inletValveToPump : FluidPort
            connect inletIsolationValve.outletPort to wendelkolbenPump.inletPort;
        connection pumpToOutlet : FluidPort
            connect wendelkolbenPump.outletPort to pressureReliefValve.inletPort;
        connection reliefBypass : FluidPort
            connect pressureReliefValve.outletPort to supplyTank.outletPort;
        connection outletToFlowMeter : FluidPort
            connect wendelkolbenPump.outletPort to flowMeter.measurementPort;
        connection flowMeterToOutletValve : FluidPort
            connect flowMeter.measurementPort to outletIsolationValve.inletPort;
        connection outletValveToReceiving : FluidPort
            connect outletIsolationValve.outletPort to receivingTank.inletPort;

        // Mechanical drive connection
        connection motorDrive : MechanicalDrivePort
            connect electricMotor.drivePort to wendelkolbenPump.drivePort;

        // Sensor measurement connections
        connection inletPressureMeasurement : FluidPort
            connect wendelkolbenPump.inletPort to inletPressureSensor.measurementPort;
        connection outletPressureMeasurement : FluidPort
            connect wendelkolbenPump.outletPort to outletPressureSensor.measurementPort;

        // Control signal connections
        connection controllerToPump : ControlSignalPort
            connect systemController.pumpControlPort to wendelkolbenPump.controlPort;
        connection controllerToMotor : ControlSignalPort
            connect systemController.motorControlPort to electricMotor.controlPort;
        connection controllerToInletValve : ControlSignalPort
            connect systemController.inletValveControlPort to inletIsolationValve.controlPort;
        connection controllerToOutletValve : ControlSignalPort
            connect systemController.outletValveControlPort to outletIsolationValve.controlPort;

        // Sensor feedback to controller
        connection inletSensorFeedback : SensorOutputPort
            connect inletPressureSensor.outputPort to systemController.inletSensorPort;
        connection outletSensorFeedback : SensorOutputPort
            connect outletPressureSensor.outputPort to systemController.outletSensorPort;
        connection flowMeterFeedback : SensorOutputPort
            connect flowMeter.outputPort to systemController.flowMeterPort;

        // Requirements satisfaction
        satisfy pressureMonitoring : PressureMonitoringRequirement by outletPressureSensor.outputPort.measuredPressure;
        satisfy flowMonitoring : FlowMonitoringRequirement by flowMeter.outputPort.measuredFlowRate;
        satisfy safetyRelief : SafetyReliefRequirement by wendelkolbenPump.outletPort.pressure;
        satisfy continuousOperation : ContinuousOperationRequirement by 0.0;
    }
}
