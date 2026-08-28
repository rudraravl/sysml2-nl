package PitometerLog {
    import SI::*;
    import ScalarValues::*;

    // ===== Value Types with Units =====
    value type PressureValue :> Real [Pa] {
        doc "Absolute hydraulic pressure in Pascals.";
    }
    value type PressureDifferenceValue :> Real [Pa] {
        doc "Differential pressure between dynamic and static water pressure.";
    }
    value type VoltageValue :> Real [V] {
        doc "Calibrated electrical signal voltage.";
    }
    value type SpeedValue :> Real [m/s] {
        doc "Vessel speed through the water.";
    }
    value type DistanceValue :> Real [m] {
        doc "Accumulated distance traveled in meters.";
    }
    value type TimeValue :> Real [s] {
        doc "Time interval in seconds.";
    }
    value type WaterDensityValue :> Real [kg/m3] {
        doc "Density of seawater in kilograms per cubic meter.";
    }
    value type DimensionlessFactor :> Real {
        doc "Dimensionless calibration factor.";
    }

    // ===== Port Definitions =====
    port def PressureOutPort {
        out pressureDifference : PressureDifferenceValue;
    }
    port def PressureInPort {
        in pressureDifference : PressureDifferenceValue;
    }
    port def SignalOutPort {
        out signal : VoltageValue;
    }
    port def SignalInPort {
        in signal : VoltageValue;
    }
    port def SpeedOutPort {
        out speed : SpeedValue;
    }
    port def SpeedInPort {
        in speed : SpeedValue;
    }
    port def DistanceOutPort {
        out distance : DistanceValue;
    }
    port def DistanceInPort {
        in distance : DistanceValue;
    }

    // ===== Requirements =====
    requirement def SpeedMeasurementRequirement {
        doc "The system shall measure the vessel's speed through the water in real time.";
        attribute minSpeed : SpeedValue = 0 [m/s];
        attribute maxSpeed : SpeedValue = 30 [m/s];
        attribute accuracyPercent : DimensionlessFactor = 0.01;
    }

    requirement def DistanceAccumulationRequirement {
        doc "The system shall continuously accumulate total distance traveled through the water.";
        attribute initialDistance : DistanceValue = 0 [m];
        attribute maxAccumulated : DistanceValue = 10000000 [m];
    }

    requirement def RealTimeUpdateRequirement {
        doc "The system shall provide real-time speed and distance updates at regular intervals.";
        attribute updateInterval : TimeValue = 1 [s];
    }

    requirement def CalibrationRequirement {
        doc "The velocity computer shall be calibratable by adjusting water density to maintain accuracy.";
        attribute defaultDensity : WaterDensityValue = 1025 [kg/m3];
        attribute minDensity : WaterDensityValue = 990 [kg/m3];
        attribute maxDensity : WaterDensityValue = 1030 [kg/m3];
    }

    requirement def HydrodynamicSensingRequirement {
        doc "The Pitot tube shall measure the difference between dynamic and static water pressure at the hull.";
    }

    requirement def SignalConversionRequirement {
        doc "The pressure transducer shall convert the raw pressure difference into a calibrated electrical signal.";
        attribute outputRange : VoltageValue = 10 [V];
    }

    requirement def CrewDisplayRequirement {
        doc "The display unit shall show current speed and total accumulated distance to the crew.";
    }

    // ===== Part: Pitot Tube =====
    part def PitotTube {
        doc "Hydrodynamic sensor extending through the ship's hull that measures the difference between dynamic water pressure and surrounding static water pressure.";
        port pressureDifferenceOut : PressureOutPort;

        attribute dynamicPressure : PressureValue;
        attribute staticPressure : PressureValue;
        attribute measuredDifference : PressureDifferenceValue;
        attribute hullPenetrationDepth : DistanceValue = 0.5 [m];

        action measureDynamicPressure {
            doc "Senses the dynamic (stagnation) pressure of water flowing past the hull.";
            out dynamicPressure;
        }
        action measureStaticPressure {
            doc "Senses the surrounding static water pressure.";
            out staticPressure;
        }
        action computePressureDifference {
            doc "Subtracts static pressure from dynamic pressure to obtain the differential.";
            in dynamicP : PressureValue;
            in staticP : PressureValue;
            out measuredDifference;
        }
    }

    // ===== Part: Pressure Transducer =====
    part def PressureTransducer {
        doc "Converts the raw pressure difference from the Pitot tube into a calibrated electrical signal.";
        port pressureIn : PressureInPort;
        port signalOut : SignalOutPort;

        attribute calibrationFactor : DimensionlessFactor = 1.0;
        attribute zeroOffset : VoltageValue = 0 [V];
        attribute fullScaleVoltage : VoltageValue = 10 [V];
        attribute fullScalePressure : PressureDifferenceValue = 50000 [Pa];
        attribute outputVoltage : VoltageValue;

        action convertPressureToVoltage {
            doc "Maps the input pressure difference to a proportional voltage using the calibration factor.";
            in pressureDifference : PressureDifferenceValue;
            in calibrationFactor;
            in zeroOffset;
            in fullScaleVoltage;
            in fullScalePressure;
            out outputVoltage;
        }

        action performZeroCalibration {
            doc "Adjusts the zero offset to compensate for sensor drift.";
            out zeroOffset;
        }
    }

    // ===== Part: Velocity Computer =====
    part def VelocityComputer {
        doc "Uses Bernoulli's principle to calculate the vessel's instantaneous speed through the water from the calibrated electrical signal.";
        port signalIn : SignalInPort;
        port speedOut : SpeedOutPort;

        attribute waterDensity : WaterDensityValue = 1025 [kg/m3];
        attribute densityAdjustmentFactor : DimensionlessFactor = 1.0;
        attribute signalToPressureScale : DimensionlessFactor = 5000 [Pa/V];
        attribute computedSpeed : SpeedValue;
        attribute minSpeed : SpeedValue = 0 [m/s];
        attribute maxSpeed : SpeedValue = 30 [m/s];

        action convertSignalToPressure {
            doc "Reconstructs the pressure difference from the electrical signal.";
            in signal : VoltageValue;
            in signalToPressureScale;
            out pressureDifference : PressureDifferenceValue;
        }

        action applyBernoulliPrinciple {
            doc "Computes v = sqrt(2 * dp / rho) using Bernoulli's equation.";
            in pressureDifference : PressureDifferenceValue;
            in waterDensity;
            out computedSpeed;
        }

        action calibrateWaterDensity {
            doc "Adjusts the water density parameter to maintain accuracy in different seawater conditions.";
            in newDensity : WaterDensityValue;
            out waterDensity;
        }

        action computeInstantaneousSpeed {
            doc "Orchestrates signal-to-pressure conversion and Bernoulli calculation.";
            in signal : VoltageValue;
            in waterDensity;
            out computedSpeed;
        }
    }

    // ===== Part: Distance Integrator =====
    part def DistanceIntegrator {
        doc "Continuously calculates the distance traveled over small time intervals and adds it to a running total, acting as the ship's odometer.";
        port speedIn : SpeedInPort;
        port distanceOut : DistanceOutPort;

        attribute runningTotal : DistanceValue = 0 [m];
        attribute timeStep : TimeValue = 1 [s];
        attribute maxAccumulated : DistanceValue = 10000000 [m];
        attribute lastSpeed : SpeedValue = 0 [m/s];
        attribute distanceIncrement : DistanceValue = 0 [m];

        action integrateDistance {
            doc "Multiplies current speed by the time step and adds the increment to the running total.";
            in speed : SpeedValue;
            in timeStep;
            in currentTotal : DistanceValue;
            out newTotal : DistanceValue;
        }

        action resetOdometer {
            doc "Resets the running total to zero.";
            out runningTotal;
        }

        action startIntegration;
        action commitTotal;
        action raiseAlarm;

        state machine integrationState {
            initial Standby;
            state Active {
                doc "Continuously integrating distance from incoming speed samples.";
                entry / startIntegration;
                do integrateDistance;
                exit / commitTotal;
            }
            state Resetting {
                doc "Resetting the odometer to zero.";
                entry / resetOdometer;
            }
            state Fault {
                doc "Fault state when an error is detected during integration.";
                entry / raiseAlarm;
            }
            Standby -> Active on startCommand;
            Active -> Active on speedSampleReceived;
            Active -> Resetting on resetCommand;
            Resetting -> Standby on resetComplete;
            Active -> Fault on errorDetected;
            Fault -> Standby on errorCleared;
        }
    }

    // ===== Part: Display Unit =====
    part def DisplayUnit {
        doc "Displays the current speed and total accumulated distance to the crew.";
        port speedIn : SpeedInPort;
        port distanceIn : DistanceInPort;

        attribute displayedSpeed : SpeedValue;
        attribute displayedDistance : DistanceValue;
        attribute backlightEnabled : Boolean = true;
        attribute refreshInterval : TimeValue = 1 [s];

        action updateSpeedDisplay {
            doc "Updates the displayed speed value.";
            in speed : SpeedValue;
            out displayedSpeed;
        }
        action updateDistanceDisplay {
            doc "Updates the displayed total distance value.";
            in distance : DistanceValue;
            out displayedDistance;
        }
        action refreshDisplay {
            doc "Refreshes the physical display screen with current speed and distance.";
            in displayedSpeed;
            in displayedDistance;
        }
    }

    // ===== Top-Level System Assembly =====
    part def PitometerLogSystem {
        doc "Pitometer Log: a marine navigation instrument that measures a vessel's speed through the water and the total distance it has traveled, providing real-time speed and distance information for navigation and voyage planning.";

        satisfy SpeedMeasurementRequirement;
        satisfy DistanceAccumulationRequirement;
        satisfy RealTimeUpdateRequirement;
        satisfy CalibrationRequirement;
        satisfy HydrodynamicSensingRequirement;
        satisfy SignalConversionRequirement;
        satisfy CrewDisplayRequirement;

        // Sub-parts
        part pitotTube : PitotTube;
        part pressureTransducer : PressureTransducer;
        part velocityComputer : VelocityComputer;
        part distanceIntegrator : DistanceIntegrator;
        part displayUnit : DisplayUnit;

        // System-level actions referenced by the state machine
        action performSelfTest;
        action warmUpSensors;
        action verifyCalibration;
        action startMeasurementLoop;
        action continuousMeasurementLoop;
        action prepareForShutdown;
        action enterCalibrationMode;
        action adjustDensityParameters;
        action saveCalibrationSettings;
        action raiseFaultAlarm;
        action diagnoseFault;
        action clearFault;

        // System operation state machine
        state machine operationState {
            doc "Governs the Pitometer Log's operational modes: power-off, initialization, continuous operation, calibration, and fault handling.";
            initial PoweredOff;
            state Initializing {
                doc "Power-on self-test and sensor warm-up.";
                entry / performSelfTest;
                do warmUpSensors;
                exit / verifyCalibration;
            }
            state Operational {
                doc "Continuous measurement loop providing real-time speed and distance updates.";
                entry / startMeasurementLoop;
                do continuousMeasurementLoop;
                exit / prepareForShutdown;
            }
            state Calibrating {
                doc "Calibration mode for adjusting water density and other factors.";
                entry / enterCalibrationMode;
                do adjustDensityParameters;
                exit / saveCalibrationSettings;
            }
            state Faulted {
                doc "Fault state for diagnosing and clearing errors.";
                entry / raiseFaultAlarm;
                do diagnoseFault;
                exit / clearFault;
            }
            PoweredOff -> Initializing on powerOn;
            Initializing -> Operational on initializationComplete;
            Operational -> Calibrating on calibrationRequested;
            Calibrating -> Operational on calibrationComplete;
            Operational -> Faulted on faultDetected;
            Faulted -> PoweredOff on powerOff;
            Faulted -> Initializing on resetCommand;
        }

        // ===== Inter-part Connections =====
        // Pitot tube sends raw pressure difference to the pressure transducer
        connect pitotTube.pressureDifferenceOut to pressureTransducer.pressureIn;
        // Pressure transducer sends calibrated electrical signal to the velocity computer
        connect pressureTransducer.signalOut to velocityComputer.signalIn;
        // Velocity computer sends instantaneous speed to the distance integrator
        connect velocityComputer.speedOut to distanceIntegrator.speedIn;
        // Velocity computer sends instantaneous speed to the display unit
        connect velocityComputer.speedOut to displayUnit.speedIn;
        // Distance integrator sends accumulated distance to the display unit
        connect distanceIntegrator.distanceOut to displayUnit.distanceIn;
    }
}
