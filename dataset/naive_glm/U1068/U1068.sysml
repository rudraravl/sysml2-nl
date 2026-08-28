package GrapheneEOSystem {
    import ScalarValues::*;

    // ============================================
    // VALUE TYPE DEFINITIONS
    // ============================================

    value def Voltage :> Real;
    value def Current :> Real;
    value def Temperature :> Real;
    value def Power :> Real;
    value def DataRate :> Real;
    value def Frequency :> Real;
    value def Wavelength :> Real;
    value def OpticalIntensity :> Real;
    value def ThermalConductance :> Real;
    value def AmplificationFactor :> Real;
    value def ModulationDepth :> Real;
    value def InsertionLoss :> Real;
    value def ExtinctionRatio :> Real;

    // ============================================
    // ENUMERATION DEFINITIONS
    // ============================================

    enum def SystemMode {
        INITIALIZATION;
        STANDBY;
        CALIBRATION;
        ACTIVE;
        FAULT;
    }

    enum def FaultType {
        NONE;
        OVER_TEMPERATURE;
        OVER_CURRENT;
        SIGNAL_DEGRADATION;
    }

    // ============================================
    // ITEM DEFINITIONS
    // ============================================

    item def ElectricalSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute dataRate : DataRate;
        attribute carrierFrequency : Frequency;
    }

    item def AmplifiedSignal {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute dataRate : DataRate;
        attribute carrierFrequency : Frequency;
    }

    item def OpticalBeam {
        attribute intensity : OpticalIntensity;
        attribute wavelength : Wavelength;
        attribute modulated : Boolean;
    }

    item def ModulatedOpticalSignal {
        attribute intensity : OpticalIntensity;
        attribute wavelength : Wavelength;
        attribute modulationDepth : ModulationDepth;
    }

    item def ThermalData {
        attribute temperature : Temperature;
        attribute powerDissipation : Power;
    }

    // ============================================
    // PORT DEFINITIONS
    // ============================================

    port def ElectricalInputPort {
        in signal : ElectricalSignal;
    }

    port def ElectricalOutputPort {
        out signal : AmplifiedSignal;
    }

    port def ElectricalControlPort {
        in signal : AmplifiedSignal;
    }

    port def OpticalInputPort {
        in beam : OpticalBeam;
    }

    port def OpticalOutputPort {
        out signal : ModulatedOpticalSignal;
    }

    port def ThermalMonitorPort {
        in thermalData : ThermalData;
    }

    port def ThermalDissipationPort {
        out heatPower : Power;
        out temperature : Temperature;
    }

    port def CurrentMonitorPort {
        in signal : AmplifiedSignal;
    }

    port def SystemStatusPort {
        out mode : SystemMode;
        out fault : FaultType;
        out junctionTemperature : Temperature;
        out supplyCurrent : Current;
    }

    // ============================================
    // PART DEFINITIONS
    // ============================================

    // ---- Graphene Transistor ----
    part def GrapheneTransistor {
        doc /* High-speed electrical amplification stage using a single-atom-thick graphene conducting channel. */

        attribute nominalGain : AmplificationFactor = 15.0;
        attribute maxOperatingFrequency : Frequency = 100.0;
        attribute carrierMobility : Real = 2000000;
        attribute channelThickness : Real = 0.335;
        attribute saturationCurrent : Current = 0.5;
        attribute maxJunctionTemperature : Temperature = 358.15;
        attribute biasVoltage : Voltage = 1.2;
        attribute thresholdVoltage : Voltage = 0.4;

        port in electricalInput : ElectricalInputPort;
        port out electricalOutput : ElectricalOutputPort;
        port thermal : ThermalDissipationPort;

        action def amplifySignal {
            in inputSignal : ElectricalSignal;
            out outputSignal : AmplifiedSignal;
            doc /* Amplifies the incoming electrical signal using graphene channel conductivity. The high carrier mobility of graphene enables amplification at frequencies exceeding conventional semiconductor limits. */
        }

        action def updateThermal {
            doc /* Computes instantaneous junction temperature and dissipated power. */
        }

        state def TransistorState {
            state OFF {
                entry / {
                    electricalOutput.signal.voltage = 0.0;
                    electricalOutput.signal.current = 0.0;
                }
            }
            state ACTIVE {
                entry / {
                    amplifySignal(inputSignal => electricalInput.signal, outputSignal => electricalOutput.signal);
                    updateThermal();
                }
                do / {
                    updateThermal();
                }
            }
            state THERMAL_FAULT {
                entry / {
                    electricalOutput.signal.voltage = 0.0;
                    electricalOutput.signal.current = 0.0;
                }
            }

            transition OFF -> ACTIVE when electricalInput.signal.voltage > thresholdVoltage;
            transition ACTIVE -> OFF when electricalInput.signal.voltage <= thresholdVoltage;
            transition ACTIVE -> THERMAL_FAULT when thermal.temperature > maxJunctionTemperature;
            transition THERMAL_FAULT -> OFF when resetCommand;
        }

        attribute resetCommand : Boolean = false;
    }

    // ---- Graphene Optical Modulator ----
    part def GrapheneOpticalModulator {
        doc /* Electro-optic modulator integrating a thin graphene layer. Modulates the intensity of an incoming light beam based on the voltage of the amplified control signal from the transistor. */

        attribute modulationBandwidth : Frequency = 50.0;
        attribute insertionLoss : InsertionLoss = 2.0;
        attribute modulatorThickness : Real = 0.335;
        attribute operatingWavelength : Wavelength = 1550.0;
        attribute extinctionRatio : ExtinctionRatio = 20.0;
        attribute maxJunctionTemperature : Temperature = 358.15;
        attribute halfWaveVoltage : Voltage = 2.0;
        attribute biasVoltage : Voltage = 1.0;

        port in controlInput : ElectricalControlPort;
        port in opticalInput : OpticalInputPort;
        port out opticalOutput : OpticalOutputPort;
        port thermal : ThermalDissipationPort;

        action def modulateLight {
            in control : AmplifiedSignal;
            in inputLight : OpticalBeam;
            out outputLight : ModulatedOpticalSignal;
            doc /* Modulates the intensity of the incoming light beam according to the amplified control voltage. The graphene layer changes its optical absorption in response to the applied electric field. */
        }

        action def updateThermal {
            doc /* Computes instantaneous modulator temperature and dissipated power. */
        }

        state def ModulatorState {
            state IDLE {
                entry / {
                    opticalOutput.signal.intensity = opticalInput.beam.intensity;
                    opticalOutput.signal.modulationDepth = 0.0;
                }
            }
            state MODULATING {
                entry / {
                    modulateLight(control => controlInput.signal, inputLight => opticalInput.beam, outputLight => opticalOutput.signal);
                    updateThermal();
                }
                do / {
                    updateThermal();
                }
            }
            state THERMAL_FAULT {
                entry / {
                    opticalOutput.signal.intensity = 0.0;
                    opticalOutput.signal.modulationDepth = 0.0;
                }
            }

            transition IDLE -> MODULATING when controlInput.signal.voltage > 0;
            transition MODULATING -> IDLE when controlInput.signal.voltage == 0;
            transition MODULATING -> THERMAL_FAULT when thermal.temperature > maxJunctionTemperature;
            transition THERMAL_FAULT -> IDLE when resetCommand;
        }

        attribute resetCommand : Boolean = false;
    }

    // ---- Heat Sink ----
    part def HeatSink {
        doc /* Integrated thermal management unit thermally connected to the active graphene elements to dissipate heat generated during high-speed processing. */

        attribute thermalConductivity : Real = 400.0;
        attribute heatCapacity : Real = 0.385;
        attribute maxDissipation : Power = 15.0;
        attribute ambientTemperature : Temperature = 298.15;
        attribute finSurfaceArea : Real = 1000.0;
        attribute thermalResistance : Real = 0.5;

        port in transistorHeat : ThermalMonitorPort;
        port in modulatorHeat : ThermalMonitorPort;

        action def dissipateHeat {
            in thermalData1 : ThermalData;
            in thermalData2 : ThermalData;
            doc /* Dissipates heat from both the graphene transistor and graphene optical modulator to the ambient environment. */
        }

        state def HeatSinkState {
            state IDLE {
                entry / {
                    /* No active cooling needed; components at or near ambient. */
                }
            }
            state COOLING {
                entry / {
                    dissipateHeat(thermalData1 => transistorHeat.thermalData, thermalData2 => modulatorHeat.thermalData);
                }
                do / {
                    dissipateHeat(thermalData1 => transistorHeat.thermalData, thermalData2 => modulatorHeat.thermalData);
                }
            }

            transition IDLE -> COOLING when transistorHeat.thermalData.temperature > ambientTemperature;
            transition COOLING -> IDLE when transistorHeat.thermalData.temperature <= ambientTemperature;
        }
    }

    // ---- Temperature Sensor ----
    part def TemperatureSensor {
        doc /* Precision temperature sensor for monitoring junction temperature of graphene components. */

        attribute measurementRange : Real = 200.0;
        attribute accuracy : Real = 0.1;
        attribute responseTime : Real = 1.0;
        attribute samplingRate : Frequency = 1000.0;

        port out sensorOutput : ThermalMonitorPort;

        action def measure {
            out temperatureReading : Temperature;
            doc /* Samples the current temperature of the monitored component and reports it through the sensor output port. */
        }
    }

    // ---- Current Sensor ----
    part def CurrentSensor {
        doc /* Current monitoring sensor for detecting over-current conditions in the amplification path. */

        attribute measurementRange : Current = 2.0;
        attribute accuracy : Real = 0.01;
        attribute samplingRate : Frequency = 1000.0;

        port in monitoredCurrent : CurrentMonitorPort;
        port out sensorReading : ElectricalOutputPort;

        action def measureCurrent {
            in signal : AmplifiedSignal;
            out currentReading : Current;
            doc /* Measures the current flowing through the amplification path and reports it for fault monitoring. */
        }
    }

    // ---- Control Unit ----
    part def ControlUnit {
        doc /* Central control unit that manages system state transitions, monitors sensors, and handles fault detection. */

        attribute clockFrequency : Frequency = 1000.0;
        attribute supplyVoltage : Voltage = 3.3;
        attribute adcResolution : Integer = 16;
        attribute temperatureThreshold : Temperature = 358.15;
        attribute currentThreshold : Current = 1.0;

        port in temperatureInput : ThermalMonitorPort;
        port in currentInput : ElectricalOutputPort;
        port out statusOutput : SystemStatusPort;

        attribute currentMode : SystemMode = SystemMode::INITIALIZATION;
        attribute currentFault : FaultType = FaultType::NONE;

        action def monitorSensors {
            doc /* Continuously reads temperature and current sensor data. */
        }

        action def evaluateFaults {
            doc /* Compares sensor readings against thresholds to detect over-temperature or over-current conditions. */
        }

        action def handleFault {
            doc /* Triggers system-wide fault response: disables amplification and modulation, activates cooling, reports fault code. */
        }

        action def performCalibration {
            doc /* Runs a calibration cycle for the transistor gain and modulator bias point. */
        }

        action def initializeComponents {
            doc /* Powers on and verifies integrity of all subsystems. */
        }
    }

    // ============================================
    // CONNECTION DEFINITIONS
    // ============================================

    connection def ElectricalToControlLink {
        end1 : ElectricalOutputPort;
        end2 : ElectricalControlPort;
    }

    connection def ThermalMonitoringLink {
        end1 : ThermalDissipationPort;
        end2 : ThermalMonitorPort;
    }

    connection def CurrentMonitoringLink {
        end1 : ElectricalOutputPort;
        end2 : CurrentMonitorPort;
    }

    // ============================================
    // SYSTEM DEFINITION
    // ============================================

    part def GrapheneEOProcessingSystem {
        doc /* High-performance, graphene-based electronic system for advanced high-bandwidth communication and signal processing. Receives a high-speed electrical signal, amplifies it using a graphene transistor, and uses the amplified signal to modulate an optical beam via a graphene optical modulator. Includes integrated thermal management. */

        attribute systemName : String = "Graphene Electro-Optic Processing System";
        attribute maxDataRate : DataRate = 100.0;
        attribute maxOperatingFrequency : Frequency = 100.0;
        attribute maxJunctionTemperature : Temperature = 358.15;
        attribute maxOperatingCurrent : Current = 1.0;
        attribute supplyVoltage : Voltage = 3.3;
        attribute currentMode : SystemMode = SystemMode::INITIALIZATION;
        attribute currentFault : FaultType = FaultType::NONE;

        // Sub-components
        part transistor : GrapheneTransistor {
            :>> nominalGain = 15.0;
            :>> maxOperatingFrequency = 100.0;
            :>> maxJunctionTemperature = 358.15;
            :>> biasVoltage = 1.2;
            :>> thresholdVoltage = 0.4;
        }

        part modulator : GrapheneOpticalModulator {
            :>> modulationBandwidth = 50.0;
            :>> operatingWavelength = 1550.0;
            :>> maxJunctionTemperature = 358.15;
            :>> halfWaveVoltage = 2.0;
            :>> biasVoltage = 1.0;
        }

        part heatSink : HeatSink {
            :>> maxDissipation = 15.0;
            :>> ambientTemperature = 298.15;
            :>> thermalResistance = 0.5;
        }

        part tempSensorTransistor : TemperatureSensor {
            :>> accuracy = 0.1;
            :>> samplingRate = 1000.0;
        }

        part tempSensorModulator : TemperatureSensor {
            :>> accuracy = 0.1;
            :>> samplingRate = 1000.0;
        }

        part currentSensor : CurrentSensor {
            :>> accuracy = 0.01;
            :>> samplingRate = 1000.0;
            :>> measurementRange = 2.0;
        }

        part controlUnit : ControlUnit {
            :>> clockFrequency = 1000.0;
            :>> supplyVoltage = 3.3;
            :>> temperatureThreshold = 358.15;
            :>> currentThreshold = 1.0;
        }

        // System external ports
        port in systemElectricalInput : ElectricalInputPort;
        port in systemOpticalInput : OpticalInputPort;
        port out systemOpticalOutput : OpticalOutputPort;
        port out systemStatus : SystemStatusPort;

        // Internal connections
        connect systemElectricalInput to transistor.electricalInput;
        connect transistor.electricalOutput to modulator.controlInput;
        connect transistor.electricalOutput to currentSensor.monitoredCurrent;
        connect systemOpticalInput to modulator.opticalInput;
        connect modulator.opticalOutput to systemOpticalOutput;

        // Thermal monitoring connections
        connect transistor.thermal to tempSensorTransistor.sensorOutput;
        connect modulator.thermal to tempSensorModulator.sensorOutput;
        connect tempSensorTransistor.sensorOutput to heatSink.transistorHeat;
        connect tempSensorModulator.sensorOutput to heatSink.modulatorHeat;
        connect tempSensorTransistor.sensorOutput to controlUnit.temperatureInput;
        connect currentSensor.sensorReading to controlUnit.currentInput;
        connect controlUnit.statusOutput to systemStatus;

        // System state machine
        state def SystemStateMachine {
            state INITIALIZATION {
                entry / {
                    controlUnit.initializeComponents();
                }
                do / {
                    controlUnit.monitorSensors();
                }
            }
            state STANDBY {
                entry / {
                    controlUnit.currentMode = SystemMode::STANDBY;
                }
                do / {
                    controlUnit.monitorSensors();
                    controlUnit.evaluateFaults();
                }
            }
            state CALIBRATION {
                entry / {
                    controlUnit.currentMode = SystemMode::CALIBRATION;
                    controlUnit.performCalibration();
                }
                do / {
                    controlUnit.monitorSensors();
                }
            }
            state ACTIVE {
                entry / {
                    controlUnit.currentMode = SystemMode::ACTIVE;
                }
                do / {
                    transistor.amplifySignal(inputSignal => transistor.electricalInput.signal, outputSignal => transistor.electricalOutput.signal);
                    modulator.modulateLight(control => modulator.controlInput.signal, inputLight => modulator.opticalInput.beam, outputLight => modulator.opticalOutput.signal);
                    controlUnit.monitorSensors();
                    controlUnit.evaluateFaults();
                    heatSink.dissipateHeat(thermalData1 => tempSensorTransistor.sensorOutput.thermalData, thermalData2 => tempSensorModulator.sensorOutput.thermalData);
                }
            }
            state FAULT {
                entry / {
                    controlUnit.currentMode = SystemMode::FAULT;
                    controlUnit.handleFault();
                }
                do / {
                    heatSink.dissipateHeat(thermalData1 => tempSensorTransistor.sensorOutput.thermalData, thermalData2 => tempSensorModulator.sensorOutput.thermalData);
                }
            }

            transition INITIALIZATION -> STANDBY when initializationComplete;
            transition STANDBY -> CALIBRATION when calibrationRequested;
            transition STANDBY -> ACTIVE when operationStart;
            transition CALIBRATION -> ACTIVE when calibrationComplete;
            transition CALIBRATION -> STANDBY when calibrationFailed;
            transition ACTIVE -> STANDBY when operationStop;
            transition ACTIVE -> FAULT when temperatureExceeded;
            transition ACTIVE -> FAULT when currentExceeded;
            transition STANDBY -> FAULT when temperatureExceeded;
            transition CALIBRATION -> FAULT when temperatureExceeded;
            transition FAULT -> INITIALIZATION when resetCommand;
        }

        // State machine transition condition attributes
        attribute initializationComplete : Boolean = false;
        attribute calibrationRequested : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute calibrationFailed : Boolean = false;
        attribute operationStart : Boolean = false;
        attribute operationStop : Boolean = false;
        attribute temperatureExceeded : Boolean = false;
        attribute currentExceeded : Boolean = false;
        attribute resetCommand : Boolean = false;
    }

    // ============================================
    // REQUIREMENT DEFINITIONS
    // ============================================

    requirement def GrapheneEOSystemRequirements {
        doc /* Top-level requirements for the Graphene-Based Electro-Optic Processing System. */

        subject system : GrapheneEOProcessingSystem;

        requirement AmplificationRequirement {
            doc /* The system shall amplify high-speed electrical signals using a graphene transistor with a single-atom-thick conducting channel. */
            subject transistor : GrapheneTransistor;

            require minGain {
                doc /* The transistor shall provide a minimum amplification gain of 10x. */
                assume transistor.nominalGain >= 10.0;
            }

            require minBandwidth {
                doc /* The transistor shall support signal amplification at carrier frequencies up to 100 GHz, leveraging high carrier mobility of graphene. */
                assume transistor.maxOperatingFrequency >= 100.0;
            }

            require grapheneChannel {
                doc /* The transistor shall use a single-atom-thick graphene sheet (<= 0.335 nm) as its conducting channel. */
                assume transistor.channelThickness <= 0.335;
            }

            require highMobility {
                doc /* The graphene channel shall exhibit carrier mobility of at least 1,000,000 cm²/(V·s). */
                assume transistor.carrierMobility >= 1000000;
            }
        }

        requirement ModulationRequirement {
            doc /* The system shall modulate an incoming optical beam based on the amplified electrical signal using a graphene optical modulator. */
            subject modulator : GrapheneOpticalModulator;

            require modBandwidth {
                doc /* The modulator shall support modulation bandwidth of at least 50 GHz. */
                assume modulator.modulationBandwidth >= 50.0;
            }

            require telecomWavelength {
                doc /* The modulator shall operate at the standard telecom wavelength of 1550 nm. */
                assume modulator.operatingWavelength == 1550.0;
            }

            require grapheneModulator {
                doc /* The modulator shall integrate a thin graphene layer for electro-absorption modulation. */
                assume modulator.modulatorThickness <= 0.335;
            }

            require extinctionRatio {
                doc /* The modulator shall provide an extinction ratio of at least 20 dB. */
                assume modulator.extinctionRatio >= 20.0;
            }
        }

        requirement ThermalManagementRequirement {
            doc /* The system shall include an integrated heat sink thermally connected to the active graphene elements to ensure stable and reliable operation. */
            subject heatSink : HeatSink;

            require maxJunctionTemp {
                doc /* The system shall not exceed a maximum junction temperature of 85°C (358.15 K) during operation. */
                assume system.maxJunctionTemperature <= 358.15;
            }

            require heatSinkCapacity {
                doc /* The heat sink shall be capable of dissipating at least 10 W of thermal power. */
                assume heatSink.maxDissipation >= 10.0;
            }

            require thermalConnection {
                doc /* The heat sink shall be thermally connected to both the graphene transistor and the graphene optical modulator. */
            }
        }

        requirement StateMachineRequirement {
            doc /* The system shall operate through distinct operational states: initialization, standby, calibration, and active mode. */
            subject sys : GrapheneEOProcessingSystem;

            require supportedStates {
                doc /* The system state machine shall support INITIALIZATION, STANDBY, CALIBRATION, ACTIVE, and FAULT states. */
            }

            require initialization {
                doc /* Upon power-on, the system shall enter an INITIALIZATION state and perform component checks. */
            }

            require activeMode {
                doc /* During ACTIVE mode, the system shall continuously amplify the input electrical signal and modulate the optical signal. */
            }

            require activeMonitoring {
                doc /* During ACTIVE mode, the system shall continuously monitor its junction temperature to prevent overheating. */
            }
        }

        requirement FaultProtectionRequirement {
            doc /* The system shall automatically enter a FAULT state if critical temperature or current limits are exceeded. */
            subject sys2 : GrapheneEOProcessingSystem;

            require tempFault {
                doc /* The system shall enter FAULT state when the junction temperature exceeds 85°C (358.15 K). */
            }

            require currentFault {
                doc /* The system shall enter FAULT state when the operating current exceeds 1 A. */
            }

            require faultRecovery {
                doc /* The system shall support returning from FAULT to INITIALIZATION upon a manual reset command. */
            }
        }

        requirement SystemDataRateRequirement {
            doc /* The system shall support data rates of at least 100 Gbit/s for high-bandwidth communication applications. */
            assume system.maxDataRate >= 100.0;
        }
    }

    // ============================================
    // VERIFICATION DEFINITIONS
    // ============================================

    verification def AmplificationVerification {
        subject transistor : GrapheneTransistor;
        doc /* Verify that the graphene transistor amplifies electrical signals with a gain of at least 10x at carrier frequencies up to 100 GHz. */
    }

    verification def ModulationVerification {
        subject modulator : GrapheneOpticalModulator;
        doc /* Verify that the graphene optical modulator correctly encodes the amplified electrical signal onto a 1550 nm light beam with at least 50 GHz modulation bandwidth and 20 dB extinction ratio. */
    }

    verification def ThermalProtectionVerification {
        subject system : GrapheneEOProcessingSystem;
        doc /* Verify that the system enters FAULT state when junction temperature exceeds 85°C or operating current exceeds 1 A, and that the heat sink adequately dissipates thermal power. */
    }

    verification def StateMachineVerification {
        subject system : GrapheneEOProcessingSystem;
        doc /* Verify that the system correctly transitions through INITIALIZATION, STANDBY, CALIBRATION, ACTIVE, and FAULT states under the defined conditions. */
    }
}
