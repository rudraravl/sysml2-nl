package OscillatingUTubeDensitometer {
    import ScalarValues::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    value type Frequency :> Real;            // Hertz (Hz)
    value type OscillationPeriod :> Real;    // Microseconds (µs)
    value type Temperature :> Real;         // Degrees Celsius (°C)
    value type Pressure :> Real;            // Bar (bar)
    value type Density :> Real;             // kg/m³
    value type MassFlowRate :> Real;        // kg/h
    value type Displacement :> Real;        // Millimeters (mm)
    value type Voltage :> Real;             // Volts (V)
    value type Current :> Real;             // Amperes (A)
    value type Dimensionless :> Real;       // Dimensionless
    value type TubeStiffness :> Real;       // Newtons per meter (N/m)
    value type TubeMassValue :> Real;       // Grams (g)
    value type CrossSectionalArea :> Real;  // Square meters (m²)

    // ============================================================
    // Item Definitions
    // ============================================================
    item def ProcessFluid {
        doc /* Process fluid (liquid or gas) flowing through the densitometer. */
        attribute nominalDensity : Density;
        attribute nominalTemperature : Temperature;
        attribute nominalPressure : Pressure;
    }

    item def CalibrationData {
        doc /* Pre-loaded calibration constants for density calculation. */
        attribute emptyTubePeriod : OscillationPeriod;
        attribute tubeStiffness : TubeStiffness;
        attribute tubeVolume : Dimensionless;
        attribute tubeMass : TubeMassValue;
        attribute referenceTemperature : Temperature;
        attribute referencePressure : Pressure;
        attribute tempCompensationCoeff : Dimensionless;
        attribute pressCompensationCoeff : Dimensionless;
        attribute flowCalibrationFactor : Dimensionless;
    }

    item def DensityMeasurement {
        doc /* Complete density and mass flow rate measurement result. */
        attribute rawDensity : Density;
        attribute compensatedDensity : Density;
        attribute massFlowRate : MassFlowRate;
        attribute temperature : Temperature;
        attribute pressure : Pressure;
        attribute oscillationPeriod : OscillationPeriod;
        attribute timestamp : Real;
        attribute qualityFlag : String;
    }

    item def DriveCommand {
        doc /* Drive command for the electromagnetic driver. */
        attribute targetFrequency : Frequency;
        attribute amplitude : Voltage;
        attribute enabled : Boolean;
    }

    item def SensorReading {
        doc /* Optical sensor displacement reading. */
        attribute displacement : Displacement;
        attribute phase : Dimensionless;
        attribute timestamp : Real;
    }

    item def TemperatureReading {
        doc /* Temperature transducer reading. */
        attribute value : Temperature;
        attribute timestamp : Real;
    }

    item def PressureReading {
        doc /* Pressure transducer reading. */
        attribute value : Pressure;
        attribute timestamp : Real;
    }

    item def ControlCommand {
        doc /* External control command. */
        attribute commandType : String;
        attribute parameter : Real;
    }

    item def AlarmSignal {
        doc /* Fault alarm signal. */
        attribute faultType : String;
        attribute description : String;
        attribute severity : String;
        attribute timestamp : Real;
    }

    // ============================================================
    // Port Definitions
    // ============================================================
    port def FluidPort {
        doc /* Port for process fluid flow. */
        inout item fluid : ProcessFluid;
    }

    port def DrivePort {
        doc /* Port for drive excitation signal from DSP to driver. */
        out attribute command : DriveCommand;
    }

    port def SensorDataPort {
        doc /* Port for optical sensor displacement data. */
        out attribute reading : SensorReading;
    }

    port def TemperatureDataPort {
        doc /* Port for temperature transducer data. */
        out attribute reading : TemperatureReading;
    }

    port def PressureDataPort {
        doc /* Port for pressure transducer data. */
        out attribute reading : PressureReading;
    }

    port def MeasurementPort {
        doc /* Port for corrected density and mass flow rate output. */
        out attribute measurement : DensityMeasurement;
    }

    port def ControlPort {
        doc /* Port for external control commands. */
        in attribute command : ControlCommand;
    }

    port def AlarmPort {
        doc /* Port for alarm output. */
        out attribute alarm : AlarmSignal;
    }

    port def PowerPort {
        doc /* Port for electrical power supply. */
        in attribute voltage : Voltage;
        in attribute current : Current;
    }

    // ============================================================
    // Part Definitions — Sub-Components
    // ============================================================
    part def UTube {
        doc /*
         * U-shaped vibrating tube constructed from Hastelloy C-276.
         * Process fluid flows continuously through this precisely
         * engineered tube, which oscillates at its natural resonant
         * frequency. The frequency is directly related to the total
         * mass of the vibrating system (tube + fluid). A denser fluid
         * adds more mass, causing slower vibration; a less dense
         * fluid results in faster vibration.
         */
        attribute material : String = "Hastelloy C-276";
        attribute tubeMass : TubeMassValue = 45.0;
        attribute tubeStiffness : TubeStiffness = 8500.0;
        attribute tubeVolume : Dimensionless = 5.0e-5;
        attribute crossSectionalArea : CrossSectionalArea = 1.26e-5;
        attribute naturalFrequency : Frequency;
        attribute currentDisplacement : Displacement;
        attribute currentFrequency : Frequency;

        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port excitation : ~DrivePort;

        action vibrate {
            doc /* Oscillates the tube at its current resonant frequency. */
            attribute frequency : Frequency;
            attribute amplitude : Displacement;
        }
    }

    part def ElectromagneticDriver {
        doc /*
         * Electromagnetic exciter that causes the U-tube to oscillate.
         * Receives drive commands from the DSP and applies electromagnetic
         * force to maintain vibration at the resonant frequency, forming
         * the excitation half of the feedback loop.
         */
        attribute coilResistance : Real = 50.0;
        attribute maxDriveVoltage : Voltage = 12.0;
        attribute driveGain : Dimensionless = 1.0;
        attribute currentDriveVoltage : Voltage;
        attribute currentDriveFrequency : Frequency;

        port driveCommand : ~DrivePort;
        port excitationOutput : DrivePort;

        action excite {
            doc /* Applies electromagnetic force to drive tube oscillation. */
            in command : DriveCommand;
            attribute appliedVoltage : Voltage;
            attribute driveFrequency : Frequency;
        }
    }

    part def OpticalSensor {
        doc /*
         * High-speed optical sensor tracking tube displacement with
         * extreme precision. One of a pair of sensors that feed their
         * high-speed data to the central DSP for oscillation period
         * determination.
         */
        attribute sensingRange : Displacement = 5.0;
        attribute resolution : Displacement = 1.0e-4;
        attribute samplingRate : Frequency = 10000.0;
        attribute sensorId : String;
        attribute lastReading : SensorReading;

        port sensorOutput : SensorDataPort;

        action senseDisplacement {
            doc /* Captures tube displacement data at high sampling rate. */
            attribute rawDisplacement : Displacement;
            attribute reading : SensorReading;
        }
    }

    part def TemperatureTransducer {
        doc /*
         * Integrated temperature transducer measuring fluid temperature.
         * Temperature affects density and must be compensated by the DSP.
         */
        attribute minRange : Temperature = -50.0;
        attribute maxRange : Temperature = 200.0;
        attribute accuracy : Temperature = 0.1;
        attribute responseTime : Real = 0.5;
        attribute lastReading : TemperatureReading;

        port fluidPort : FluidPort;
        port dataOutput : TemperatureDataPort;

        action measureTemperature {
            doc /* Measures current fluid temperature. */
            attribute measuredValue : Temperature;
            attribute reading : TemperatureReading;
        }
    }

    part def PressureTransducer {
        doc /*
         * Integrated pressure transducer measuring fluid pressure.
         * Pressure affects density and must be compensated by the DSP.
         */
        attribute minRange : Pressure = 0.0;
        attribute maxRange : Pressure = 1000.0;
        attribute accuracy : Pressure = 0.01;
        attribute responseTime : Real = 0.5;
        attribute lastReading : PressureReading;

        port fluidPort : FluidPort;
        port dataOutput : PressureDataPort;

        action measurePressure {
            doc /* Measures current fluid pressure. */
            attribute measuredValue : Pressure;
            attribute reading : PressureReading;
        }
    }

    part def DigitalSignalProcessor {
        doc /*
         * Central Digital Signal Processor (DSP) — the brain of the
         * instrument. Analyzes optical sensor signals to determine
         * the exact oscillation period, calculates raw density using
         * pre-loaded calibration constants, applies live temperature
         * and pressure compensation, and computes mass flow rate.
         * Also generates drive commands for the electromagnetic
         * driver in the feedback loop, and monitors for faults.
         */
        attribute clockSpeed : Frequency = 200.0e6;
        attribute calibration : CalibrationData;
        attribute currentOscillationPeriod : OscillationPeriod;
        attribute currentFrequency : Frequency;
        attribute rawDensity : Density;
        attribute compensatedDensity : Density;
        attribute computedMassFlowRate : MassFlowRate;
        attribute currentTemperature : Temperature;
        attribute currentPressure : Pressure;
        attribute faultFlag : Boolean = false;
        attribute currentMeasurement : DensityMeasurement;

        port sensorInputA : ~SensorDataPort;
        port sensorInputB : ~SensorDataPort;
        port tempInput : ~TemperatureDataPort;
        port pressInput : ~PressureDataPort;
        port driveOutput : DrivePort;
        port measurementOutput : MeasurementPort;
        port controlInput : ControlPort;
        port alarmOutput : AlarmPort;

        action determineOscillationPeriod {
            doc /*
             * Analyzes signals from both optical sensors to determine
             * the exact oscillation period of the U-tube.
             */
            in readingA : SensorReading;
            in readingB : SensorReading;
            attribute period : OscillationPeriod;
            attribute frequency : Frequency;
        }

        action calculateRawDensity {
            doc /*
             * Calculates raw fluid density from the oscillation period
             * using pre-loaded calibration constants.
             *
             * Relationship: density = K * (T² - T₀²) / V
             * where K = tube stiffness, T = current period,
             * T₀ = empty tube period, V = tube volume.
             */
            in period : OscillationPeriod;
            in calibration : CalibrationData;
            attribute density : Density;
        }

        action compensateDensity {
            doc /*
             * Applies temperature and pressure compensation to the
             * raw density value to produce a highly accurate,
             * corrected density value.
             */
            in rawDensityValue : Density;
            in temperature : Temperature;
            in pressure : Pressure;
            in calibration : CalibrationData;
            attribute compensatedDensityValue : Density;
        }

        action calculateMassFlowRate {
            doc /*
             * Calculates mass flow rate from the compensated density
             * and oscillation characteristics using the flow
             * calibration factor.
             */
            in density : Density;
            in period : OscillationPeriod;
            in calibration : CalibrationData;
            attribute massFlowRate : MassFlowRate;
        }

        action generateDriveCommand {
            doc /*
             * Generates drive commands for the electromagnetic driver
             * to maintain stable oscillation at the resonant frequency.
             */
            in currentFrequency : Frequency;
            attribute command : DriveCommand;
        }

        action detectFault {
            doc /*
             * Monitors system health and detects faults for safe
             * operation in demanding industrial environments.
             */
            in sensorReading : SensorReading;
            in temperature : Temperature;
            in pressure : Pressure;
            attribute faultDetected : Boolean;
            attribute alarm : AlarmSignal;
        }

        action processMeasurementCycle {
            doc /*
             * Complete measurement cycle:
             * 1. Acquire displacement data from both optical sensors.
             * 2. Determine the exact oscillation period.
             * 3. Calculate raw density from the period.
             * 4. Acquire live temperature and pressure readings.
             * 5. Compensate density for temperature and pressure effects.
             * 6. Compute mass flow rate from compensated density.
             * 7. Output the corrected density and mass flow rate.
             * 8. Generate drive command for the feedback loop.
             * 9. Detect and handle any faults.
             */
            attribute measurement : DensityMeasurement;
        }
    }

    part def PowerSupply {
        doc /*
         * Power supply unit providing regulated electrical power
         * to all electronic components of the densitometer.
         */
        attribute outputVoltage : Voltage = 24.0;
        attribute maxCurrent : Current = 5.0;
        attribute efficiency : Dimensionless = 0.92;
        attribute inputVoltage : Voltage;
        attribute inputCurrent : Current;

        port powerInput : PowerPort;
        port powerOutput : ~PowerPort;
    }

    // ============================================================
    // State Machine Definition
    // ============================================================
    state def DensitometerStateMachine {
        doc /*
         * System operational state machine.
         *
         * The system transitions through several distinct states:
         * idle → warmup → (calibration?) → measuring → ...
         * with maintenance and fault states for reliability and
         * safe operation in demanding industrial environments.
         */

        // Trigger condition attributes
        attribute startCommand : Boolean;
        attribute oscillationStable : Boolean;
        attribute calibrationRequired : Boolean;
        attribute calibrationCompleteEvt : Boolean;
        attribute maintenanceRequested : Boolean;
        attribute maintenanceCompleteEvt : Boolean;
        attribute faultDetected : Boolean;
        attribute faultCleared : Boolean;

        // ---- States ----
        state idle {
            doc /* System powered but not actively measuring. */
            entry action initializeSystem {
                doc /* Initialize all subsystems, load calibration data. */
            }
            do action idleMonitoring {
                doc /* Monitor for commands, perform basic health checks. */
            }
            exit action prepareForWarmup {
                doc /* Prepare driver and sensors for oscillation. */
            }
        }

        state warmup {
            doc /* Warmup phase to establish a stable oscillation. */
            entry action startDriverExcitation {
                doc /* Begin driver excitation, allow tube to reach stable vibration. */
            }
            do action stabilizeOscillation {
                doc /*
                 * Monitor and adjust drive parameters to achieve
                 * a stable resonant frequency oscillation.
                 */
            }
            exit action recordStableParameters {
                doc /* Record stable oscillation parameters. */
            }
        }

        state calibration {
            doc /* Calibration routine to verify and adjust system accuracy. */
            entry action initCalibration {
                doc /* Load reference calibration data, prepare for calibration. */
            }
            do action performCalibrationRoutine {
                doc /*
                 * Compare measurements against known reference standards,
                 * adjust calibration constants as needed.
                 */
            }
            exit action saveCalibrationResults {
                doc /* Store updated calibration constants. */
            }
        }

        state measuring {
            doc /*
             * Primary measurement state — continuously analyzes the
             * fluid's density and mass flow rate in real-time.
             */
            entry action beginContinuousMeasurement {
                doc /* Start continuous measurement cycle. */
            }
            do action performContinuousMeasurement {
                doc /*
                 * Continuously:
                 * - Acquire optical sensor displacement data
                 * - Determine oscillation period
                 * - Calculate raw density
                 * - Acquire temperature and pressure readings
                 * - Apply temperature and pressure compensation
                 * - Compute mass flow rate
                 * - Output corrected density and mass flow rate
                 * - Generate drive command for the feedback loop
                 * - Monitor for faults
                 */
            }
            exit action stopMeasurement {
                doc /* Safely stop measurement, reduce drive amplitude. */
            }
        }

        state maintenance {
            doc /* Maintenance mode for servicing and inspection. */
            entry action enterMaintenanceMode {
                doc /* Stop oscillation, safely shut down active measurement. */
            }
            do action maintenanceOperations {
                doc /* Allow servicing, cleaning, and adjustments. */
            }
            exit action prepareForRestart {
                doc /* Prepare system for restart after maintenance. */
            }
        }

        state fault {
            doc /* Fault state — safe shutdown with alarm for reliability. */
            entry action handleFaultCondition {
                doc /*
                 * Stop driver excitation, raise alarm with fault
                 * details, log fault information for diagnostics.
                 */
            }
            do action faultMonitoring {
                doc /* Monitor for fault clearance conditions. */
            }
            exit action clearFaultState {
                doc /* Reset fault flags, prepare for restart. */
            }
        }

        // ---- Transitions ----
        transition from idle to warmup
            when startCommand;
        transition from warmup to measuring
            when oscillationStable [not calibrationRequired];
        transition from warmup to calibration
            when oscillationStable [calibrationRequired];
        transition from calibration to measuring
            when calibrationCompleteEvt;
        transition from measuring to maintenance
            when maintenanceRequested;
        transition from maintenance to idle
            when maintenanceCompleteEvt;
        transition from idle to fault
            when faultDetected;
        transition from warmup to fault
            when faultDetected;
        transition from calibration to fault
            when faultDetected;
        transition from measuring to fault
            when faultDetected;
        transition from maintenance to fault
            when faultDetected;
        transition from fault to idle
            when faultCleared;
    }

    // ============================================================
    // Main System Part Definition
    // ============================================================
    part def OscillatingUTubeDensitometer {
        doc /*
         * Industrial Oscillating U-Tube Densitometer System.
         *
         * A sophisticated instrument for continuous, highly accurate
         * measurement of fluid density and mass flow rate in real-time.
         * Commonly used in process control industries where precise
         * fluid property monitoring is critical.
         *
         * Core principle: a vibrating U-shaped tube oscillates at its
         * natural resonant frequency, which is directly related to the
         * total mass of the vibrating system (tube + fluid). A denser
         * fluid adds more mass, causing the tube to vibrate more slowly;
         * a less dense fluid results in a faster vibration. The DSP
         * determines the exact oscillation period from optical sensor
         * data, calculates density using calibration constants, applies
         * temperature and pressure compensation, and computes mass
         * flow rate — all in a closed feedback loop with the
         * electromagnetic driver.
         */

        // ---- Sub-components ----
        part utube : UTube {
            doc /* The vibrating U-shaped tube (Hastelloy C-276). */
        }

        part driver : ElectromagneticDriver {
            doc /* Electromagnetic exciter for tube oscillation. */
        }

        part opticalSensorA : OpticalSensor {
            attribute sensorId = "OS-A";
            doc /* First optical sensor of the pair. */
        }

        part opticalSensorB : OpticalSensor {
            attribute sensorId = "OS-B";
            doc /* Second optical sensor of the pair. */
        }

        part dsp : DigitalSignalProcessor {
            doc /* Central DSP — the brain of the instrument. */
        }

        part temperatureTransducer : TemperatureTransducer {
            doc /* Integrated fluid temperature transducer. */
        }

        part pressureTransducer : PressureTransducer {
            doc /* Integrated fluid pressure transducer. */
        }

        part powerSupply : PowerSupply {
            doc /* System power supply. */
        }

        // ---- External interface ports ----
        port processFluidIn : FluidPort;
        port processFluidOut : FluidPort;
        port measurementOutput : MeasurementPort;
        port controlInput : ControlPort;
        port alarmOutput : AlarmPort;
        port powerInput : PowerPort;

        // ---- Internal connections ----
        // Fluid flow path: inlet → tube → temp transducer → press transducer → outlet
        connect processFluidIn to utube.fluidIn;
        connect utube.fluidOut to temperatureTransducer.fluidPort;
        connect temperatureTransducer.fluidPort to pressureTransducer.fluidPort;
        connect pressureTransducer.fluidPort to processFluidOut;

        // Drive excitation feedback loop: DSP → driver → tube
        connect dsp.driveOutput to driver.driveCommand;
        connect driver.excitationOutput to utube.excitation;

        // Optical sensor data to DSP
        connect opticalSensorA.sensorOutput to dsp.sensorInputA;
        connect opticalSensorB.sensorOutput to dsp.sensorInputB;

        // Temperature and pressure data to DSP
        connect temperatureTransducer.dataOutput to dsp.tempInput;
        connect pressureTransducer.dataOutput to dsp.pressInput;

        // External outputs from DSP
        connect dsp.measurementOutput to measurementOutput;
        connect dsp.alarmOutput to alarmOutput;

        // External control input to DSP
        connect controlInput to dsp.controlInput;

        // Power input to power supply
        connect powerInput to powerSupply.powerInput;

        // ---- State machine ----
        state operatingStates : DensitometerStateMachine;
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def DensityAccuracyRequirement {
        doc /*
         * The densitometer shall measure fluid density with an
         * accuracy of at least ±0.1 kg/m³ across the full
         * operating range of 0–2000 kg/m³.
         */
        attribute requiredAccuracy : Density = 0.1;
        attribute operatingRangeMin : Density = 0.0;
        attribute operatingRangeMax : Density = 2000.0;
    }

    requirement def ContinuousMeasurementRequirement {
        doc /*
         * The system shall provide continuous, uninterrupted
         * real-time density and mass flow rate measurements
         * during normal operation in the measuring state.
         */
    }

    requirement def RealTimeResponseRequirement {
        doc /*
         * The system shall provide corrected measurement updates
         * at a rate of at least 1 Hz under normal operating
         * conditions.
         */
        attribute minimumUpdateRate : Frequency = 1.0;
    }

    requirement def CorrosionResistanceRequirement {
        doc /*
         * The U-tube shall be constructed from Hastelloy C-276
         * or equivalent corrosion-resistant material suitable
         * for industrial process fluid environments.
         */
        attribute requiredMaterial : String = "Hastelloy C-276";
    }

    requirement def StateManagementRequirement {
        doc /*
         * The system shall operate through the following distinct
         * states: idle, warmup, calibration, measuring, maintenance,
         * and fault. All state transitions shall be deterministic,
         * monitored, and logged.
         */
        attribute requiredStates : String = "idle, warmup, calibration, measuring, maintenance, fault";
    }

    requirement def TemperatureCompensationRequirement {
        doc /*
         * The system shall compensate density measurements for
         * the effect of fluid temperature using integrated
         * temperature transducer readings and pre-loaded
         * compensation coefficients.
         */
        attribute compensationAccuracy : Temperature = 0.1;
    }

    requirement def PressureCompensationRequirement {
        doc /*
         * The system shall compensate density measurements for
         * the effect of fluid pressure using integrated pressure
         * transducer readings and pre-loaded compensation
         * coefficients.
         */
        attribute compensationAccuracy : Pressure = 0.01;
    }

    requirement def FaultHandlingRequirement {
        doc /*
         * The system shall detect faults during all operational
         * states and transition to a safe fault state, raising an
         * alarm with detailed fault information for diagnostics.
         */
    }

    requirement def OpticalPrecisionRequirement {
        doc /*
         * The pair of optical sensors shall measure tube
         * displacement with sufficient precision and sampling
         * rate to determine the oscillation period with the
         * accuracy required for density calculation.
         */
        attribute requiredResolution : Displacement = 1.0e-4;
        attribute requiredSamplingRate : Frequency = 10000.0;
    }

    requirement def WarmupRequirement {
        doc /*
         * The system shall complete the warmup phase and achieve
         * stable oscillation within 60 seconds of transitioning
         * from the idle state.
         */
        attribute maxWarmupTime : Real = 60.0;
    }

    requirement def MassFlowRateRequirement {
        doc /*
         * The system shall calculate mass flow rate from the
         * compensated density and oscillation characteristics
         * using the pre-loaded flow calibration factor.
         */
    }

    // ============================================================
    // Requirement Satisfactions
    // ============================================================
    satisfaction satisfyDensityAccuracy {
        requirement DensityAccuracyRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyContinuousMeasurement {
        requirement ContinuousMeasurementRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyRealTimeResponse {
        requirement RealTimeResponseRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyCorrosionResistance {
        requirement CorrosionResistanceRequirement;
        subject utube : UTube;
    }

    satisfaction satisfyStateManagement {
        requirement StateManagementRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyTemperatureCompensation {
        requirement TemperatureCompensationRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyPressureCompensation {
        requirement PressureCompensationRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyFaultHandling {
        requirement FaultHandlingRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyOpticalPrecision {
        requirement OpticalPrecisionRequirement;
        subject sensor : OpticalSensor;
    }

    satisfaction satisfyWarmup {
        requirement WarmupRequirement;
        subject system : OscillatingUTubeDensitometer;
    }

    satisfaction satisfyMassFlowRate {
        requirement MassFlowRateRequirement;
        subject system : OscillatingUTubeDensitometer;
    }
}
