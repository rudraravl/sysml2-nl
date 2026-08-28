package MassFlowSensingUnit {
    import ScalarValues::*;
    import ISQ::*;
    import ISQMass::*;
    import ISQTime::*;
    import ISQThermodynamicTemperature::*;
    import ISQPressure::*;

    // ---- Value Types ----
    value type MassFlowRateValue :> Real {
        unit kg_per_s {
            MassDimension = 1;
            TimeDimension = -1;
        }
    }

    value type TemperatureValue :> Real {
        unit degC;
    }

    value type PressureValue :> Real {
        unit bar;
    }

    value type AccuracyValue :> Real {
        unit percent;
    }

    value type ResponseTimeValue :> Real {
        unit ms;
    }

    item ProcessFluid;

    item RawMeasurementData {
        attribute massFlowRate : MassFlowRateValue;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
    }

    item ProcessedMeasurementData {
        attribute massFlowRate : MassFlowRateValue;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute operationalStatus : String;
    }

    // ---- Port Definitions ----
    port def FluidPort {
        attribute flowDirection : String;
        in out item ProcessFluid;
    }

    port def RawDataPort {
        out item RawMeasurementData;
    }

    port def DataInterfacePort {
        out item ProcessedMeasurementData;
    }

    // ---- Requirements ----
    requirement def MassFlowSensingRequirements {
        attribute flowRangeMin : MassFlowRateValue = 0 [kg_per_s];
        attribute flowRangeMax : MassFlowRateValue = 100 [kg_per_s];
        attribute accuracy : AccuracyValue = 2.0 [percent];
        attribute responseTime : ResponseTimeValue = 100 [ms];

        requirement FlowRangeRequirement {
            doc /* The unit shall measure mass flow rate from 0 to 100 kg/s. */
            constraint { 0 [kg_per_s] <= MassFlowRateValue and MassFlowRateValue <= 100 [kg_per_s] }
        }

        requirement AccuracyRequirement {
            doc /* The unit shall achieve an accuracy of at least 2%. */
            constraint { AccuracyValue <= 2.0 [percent] }
        }

        requirement ResponseTimeRequirement {
            doc /* The unit shall respond to changes in flow within 100 milliseconds. */
            constraint { ResponseTimeValue <= 100 [ms] }
        }

        requirement MultiParameterMeasurementRequirement {
            doc /* The unit shall measure mass flow rate, temperature, and pressure. */
        }

        requirement DataOutputRequirement {
            doc /* The unit shall transmit processed data including mass flow rate, temperature, pressure, and operational status. */
        }
    }

    // ---- Internal Components ----
    part def MassFlowSensor {
        port inlet : FluidPort;
        port outlet : FluidPort;
        port rawDataOut : RawDataPort;

        attribute sensorActive : Boolean = false;

        action def takeMeasurement {
            in fluid : ProcessFluid;
            out raw : RawMeasurementData;
        }

        perform takeMeasurement;

        state sensorStateMachine {
            entry; then Idle;
            state Idle;
            state Active;
            transition from Idle to Active when sensorActive;
            transition from Active to Idle when !sensorActive;
        }
    }

    part def SignalProcessor {
        port rawDataIn : RawDataPort {
            in item RawMeasurementData;
        }
        port dataOut : DataInterfacePort;

        attribute filterCoefficient : Real = 0.2;
        attribute operationalStatus : String = "Ready";

        action def filterData {
            in raw : RawMeasurementData;
            out processed : ProcessedMeasurementData;
        }

        perform filterData;

        state processorStateMachine {
            entry; then Standby;
            state Standby;
            state Filtering;
            transition from Standby to Filtering when rawDataIn::RawMeasurementData@;
            transition from Filtering to Standby when !rawDataIn::RawMeasurementData@;
        }
    }

    // ---- Top-level Mass Flow Sensing Unit ----
    part def MassFlowSensingUnit {
        attribute unitId : String;
        attribute lastCalibrationDate : String;

        port inlet : FluidPort;
        port outlet : FluidPort;
        port dataInterface : DataInterfacePort;

        part massFlowSensor : MassFlowSensor {
            redefines inlet = MassFlowSensingUnit::inlet;
        }

        part signalProcessor : SignalProcessor;

        // Internal connections
        connection rawSensorToProcessor connect massFlowSensor.rawDataOut to signalProcessor.rawDataIn;
        connection processedToInterface connect signalProcessor.dataOut to dataInterface;

        // Fluid path: inlet -> sensor -> outlet
        // (sensor inlet redefines the unit inlet; sensor outlet connects to unit outlet)
        connection fluidSensorToOutlet connect massFlowSensor.outlet to outlet;

        // Operational state machine
        state unitStateMachine {
            entry; then Initializing;
            state Initializing {
                entry { operationalStatus = "Initializing"; }
            }
            state Ready {
                entry { operationalStatus = "Ready"; }
            }
            state Measuring {
                entry { operationalStatus = "Measuring"; }
            }
            state Fault {
                entry { operationalStatus = "Fault"; }
            }

            transition from Initializing to Ready when initializationComplete;
            transition from Ready to Measuring when fluidFlowDetected;
            transition from Measuring to Ready when !fluidFlowDetected;
            transition from Ready to Fault when faultDetected;
            transition from Measuring to Fault when faultDetected;
            transition from Fault to Initializing when resetCommand;
        }

        attribute operationalStatus : String;
        attribute initializationComplete : Boolean = false;
        attribute fluidFlowDetected : Boolean = false;
        attribute faultDetected : Boolean = false;
        attribute resetCommand : Boolean = false;

        satisfy MassFlowSensingRequirements;
    }

    // ---- Specific Instance ----
    part mfs_2024_001 : MassFlowSensingUnit {
        attribute unitId = "MFS-2024-001";
        attribute lastCalibrationDate = "2024-01-15";
        attribute operationalStatus = "Ready";

        part massFlowSensor {
            attribute sensorActive = true;
        }

        part signalProcessor {
            attribute filterCoefficient = 0.15;
            attribute operationalStatus = "Ready";
        }
    }

}
