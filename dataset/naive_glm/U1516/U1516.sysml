package TotalPressureMeasurementSystem {

    import ScalarValues::*;
    import ISQ::*;

    // ---- Value Types ----
    value type PressureValue :> Real {
        unit 'Pa';
    }

    value type VoltageValue :> Real {
        unit 'V';
    }

    value type VelocityValue :> Real {
        unit 'm/s';
    }

    value type DensityValue :> Real {
        unit 'kg/m3';
    }

    value type FrequencyValue :> Real {
        unit 'Hz';
    }

    value type TimeValue :> Real {
        unit 's';
    }

    // ---- Item Definitions ----
    item def PressureReading {
        attribute value : PressureValue;
        attribute timestamp : TimeValue;
    }

    item def VoltageSignal {
        attribute voltage : VoltageValue;
        attribute timestamp : TimeValue;
    }

    item def ProcessedData {
        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;
        attribute dynamicPressure : PressureValue;
        attribute airspeed : VelocityValue;
        attribute timestamp : TimeValue;
    }

    item def CommandSignal {
        attribute activate : Boolean;
        attribute reset : Boolean;
    }

    item def FaultReport {
        attribute faultCode : Integer;
        attribute description : String;
        attribute timestamp : TimeValue;
    }

    // ---- Port Definitions ----
    port def PressurePort {
        out item : PressureReading;
    }

    port def VoltagePort {
        out item : VoltageSignal;
    }

    port def DataPort {
        out item : ProcessedData;
    }

    port def CommandPort {
        in item : CommandSignal;
    }

    port def FaultPort {
        out item : FaultReport;
    }

    // ---- Requirements ----
    requirement def TotalPressureMeasurementRequirement {
        doc "The system shall measure total and static pressures and compute airspeed.";
        attribute maxOperatingPressure : PressureValue = 150000 [Pa];
        attribute minOperatingPressure : PressureValue = 20000 [Pa];
        attribute measurementAccuracy : Real = 0.01;
        attribute maxAirspeed : VelocityValue = 400 [m/s];
    }

    requirement def PitotProbeRequirement {
        doc "The Pitot probe shall measure total pressure facing into the airflow.";
        attribute pressureRange : PressureValue[2] = (20000, 150000) [Pa];
    }

    requirement def StaticProbeRequirement {
        doc "The Static probe shall measure ambient atmospheric pressure perpendicular to flow.";
        attribute pressureRange : PressureValue[2] = (20000, 110000) [Pa];
    }

    requirement def TransducerRequirement {
        doc "Each transducer shall convert pressure readings to voltage signals.";
        attribute outputRange : VoltageValue[2] = (0, 5) [V];
        attribute linearityError : Real = 0.005;
    }

    requirement def ProcessorRequirement {
        doc "The processor shall compute dynamic pressure and airspeed using Bernoulli's equation.";
        attribute processingLatency : TimeValue = 0.01 [s];
        attribute assumedAirDensity : DensityValue = 1.225 [kg/m3];
    }

    requirement def DisplayRequirement {
        doc "The display unit shall show total, static, dynamic pressures and airspeed.";
        attribute refreshRate : FrequencyValue = 10 [Hz];
    }

    requirement def LoggerRequirement {
        doc "The data logger shall record all processed data at high frequency.";
        attribute loggingRate : FrequencyValue = 100 [Hz];
        attribute storageCapacity : Integer = 1000000;
    }

    requirement def OperationalStateRequirement {
        doc "The system shall operate through initialization, standby, active, and fault states.";
    }

    // ---- Part Definitions ----

    part def PitotProbe {
        doc "Measures total (stagnation) pressure facing into oncoming airflow.";
        port pressureOut : PressurePort;
        attribute measuredPressure : PressureValue;
        perform action measureTotalPressure {
            // Action: sense stagnation pressure
            out result : PressureValue;
        }
    }

    part def StaticProbe {
        doc "Measures ambient atmospheric pressure perpendicular to airflow.";
        port pressureOut : PressurePort;
        attribute measuredPressure : PressureValue;
        perform action measureStaticPressure {
            out result : PressureValue;
        }
    }

    part def PressureTransducer {
        doc "Converts raw pressure reading into an electrical voltage signal.";
        port pressureIn : PressurePort;
        port voltageOut : VoltagePort;
        attribute sensitivity : Real = 3.3e-5; // V/Pa
        attribute offset : VoltageValue = 0 [V];
        perform action convertPressureToVoltage {
            in pressureInput : PressureValue;
            out voltageOutput : VoltageValue;
        }
    }

    part def DataProcessor {
        doc "Central processing unit that computes dynamic pressure and airspeed.";
        port totalVoltageIn : VoltagePort;
        port staticVoltageIn : VoltagePort;
        port dataOut : DataPort;
        port faultOut : FaultPort;
        port commandIn : CommandPort;

        attribute airDensity : DensityValue = 1.225 [kg/m3];
        attribute transducerSensitivity : Real = 3.3e-5;
        attribute transducerOffset : VoltageValue = 0 [V];
        attribute processingLatency : TimeValue = 0.01 [s];

        perform action computeDynamicPressure {
            in totalPressure : PressureValue;
            in staticPressure : PressureValue;
            out dynamicPressure : PressureValue;
        }

        perform action computeAirspeed {
            in dynamicPressure : PressureValue;
            in density : DensityValue;
            out airspeed : VelocityValue;
        }

        perform action processCycle {
            in totalVoltage : VoltageValue;
            in staticVoltage : VoltageValue;
            out processedData : ProcessedData;
        }
    }

    part def DisplayUnit {
        doc "Displays real-time pressures and airspeed to the operator.";
        port dataIn : DataPort;
        attribute refreshRate : FrequencyValue = 10 [Hz];
        attribute displayTotalPressure : PressureValue;
        attribute displayStaticPressure : PressureValue;
        attribute displayDynamicPressure : PressureValue;
        attribute displayAirspeed : VelocityValue;
        perform action updateDisplay {
            in data : ProcessedData;
        }
    }

    part def DataLogger {
        doc "Records processed data at high frequency for post-flight analysis.";
        port dataIn : DataPort;
        attribute loggingRate : FrequencyValue = 100 [Hz];
        attribute storageCapacity : Integer = 1000000;
        attribute recordCount : Integer = 0;
        perform action logData {
            in data : ProcessedData;
        }
    }

    // ---- System Part with State Machine ----

    part def TotalPressureMeasurementSystem {
        doc "Complete pitot-static total pressure measurement system for aerospace airspeed determination.";

        satisfy TotalPressureMeasurementRequirement;
        satisfy OperationalStateRequirement;

        part pitotProbe : PitotProbe {
            satisfy PitotProbeRequirement;
        }
        part staticProbe : StaticProbe {
            satisfy StaticProbeRequirement;
        }
        part totalTransducer : PressureTransducer {
            satisfy TransducerRequirement;
        }
        part staticTransducer : PressureTransducer {
            satisfy TransducerRequirement;
        }
        part processor : DataProcessor {
            satisfy ProcessorRequirement;
        }
        part display : DisplayUnit {
            satisfy DisplayRequirement;
        }
        part logger : DataLogger {
            satisfy LoggerRequirement;
        }

        // Connections
        connection pitotPressureConnection connect pitotProbe.pressureOut to totalTransducer.pressureIn;
        connection staticPressureConnection connect staticProbe.pressureOut to staticTransducer.pressureIn;
        connection totalVoltageConnection connect totalTransducer.voltageOut to processor.totalVoltageIn;
        connection staticVoltageConnection connect staticTransducer.voltageOut to processor.staticVoltageIn;
        connection displayDataConnection connect processor.dataOut to display.dataIn;
        connection loggerDataConnection connect processor.dataOut to logger.dataIn;

        // System-level state machine
        state measurementStateMachine {
            entry;
            do action initializeSystem {
                // Power-on self-test
                out selfTestPassed : Boolean;
            }

            state initializing {
                entry;
                do action runSelfTest {
                    out status : Boolean;
                }
                transition to standby if selfTestPassed;
                transition to fault if !selfTestPassed;
            }

            state standby {
                entry;
                do action waitForActivation {
                    in command : CommandSignal;
                }
                transition to active if command.activate;
            }

            state active {
                entry;
                do action acquirePressures {
                    out totalPressure : PressureValue;
                    out staticPressure : PressureValue;
                }
                do action processData {
                    in totalPressure : PressureValue;
                    in staticPressure : PressureValue;
                    out processedData : ProcessedData;
                }
                do action transmitResults {
                    in data : ProcessedData;
                }
                transition to standby if !command.activate;
                transition to fault if faultDetected;
            }

            state fault {
                entry;
                do action handleFault {
                    in faultReport : FaultReport;
                }
                transition to initializing if command.reset;
            }
        }
    }

    // ---- Top-level instantiation ----
    part totalPressureMeasurementSystem : TotalPressureMeasurementSystem {
        // System is ready for integration and testing
    }

}
