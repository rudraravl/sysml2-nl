package SoilMoistureSensingUnit {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value types with units ----
    attribute def CapacitanceValue :> Real {
        doc /* Raw capacitance measured by the probe. */
        attribute unit : CapacitanceUnit[1] default CapacitanceUnit::pF;
    }
    item def CapacitanceUnit :> Unit {
        attribute symbol : String = "F";
    }
    enum def CapacitanceUnitKind { pF; nF; }

    attribute def TemperatureValue :> Real {
        doc /* Soil temperature in degrees Celsius. */
        attribute unit : TemperatureUnit[1] default TemperatureUnit::degC;
    }
    item def TemperatureUnit :> Unit {
        attribute symbol : String = "degC";
    }

    attribute def MoisturePercentage :> Real {
        doc /* Volumetric water content expressed as a percentage. */
        attribute unit : PercentUnit[1] default PercentUnit::percent;
        attribute min : Real = 0.0;
        attribute max : Real = 100.0;
    }
    item def PercentUnit :> Unit {
        attribute symbol : String = "%";
    }

    attribute def TimeStamp :> Real {
        doc /* Elapsed time since activation, in seconds. */
        attribute unit : TimeUnit[1] default TimeUnit::s;
    }
    item def TimeUnit :> Unit {
        attribute symbol : String = "s";
    }

    item def SoilReading {
        attribute moisture : MoisturePercentage[1];
        attribute temperature : TemperatureValue[1];
        attribute timestamp : TimeStamp[1];
    }

    // ---- Port definitions ----
    port def SoilInteractionPort {
        out capacitance : CapacitanceValue;
        out temperature : TemperatureValue;
    }

    port def RawSensorPort {
        out capacitance : CapacitanceValue;
        out temperature : TemperatureValue;
    }

    port def ProcessedDataPort {
        out moisture : MoisturePercentage;
        out temperature : TemperatureValue;
    }

    port def DataOutPort {
        out reading : SoilReading;
    }

    // ---- Parts ----
    part def CapacitiveSensorProbe {
        doc /* Directly interacts with the soil to measure capacitance. */
        port soilIf : SoilInteractionPort;
        attribute rawCapacitance : CapacitanceValue[0..1];
        attribute dryCapacitance : CapacitanceValue = 10.0;
        attribute saturatedCapacitance : CapacitanceValue = 50.0;

        action measureCapacitance {
            out c : CapacitanceValue;
        }
    }

    part def TemperatureSensor {
        doc /* Integrated temperature sensor for simultaneous reading. */
        port tempOut : RawSensorPort;
        attribute rawTemperature : TemperatureValue[0..1];

        action measureTemperature {
            out t : TemperatureValue;
        }
    }

    part def SignalProcessor {
        doc /* Converts raw capacitance to moisture percentage using temperature compensation. */
        port rawIn : RawSensorPort;
        port processedOut : ProcessedDataPort;
        attribute calibrationCoeff : Real = 0.01;
        attribute tempCompCoeff : Real = 0.02;

        action convert {
            in capacitance : CapacitanceValue;
            in temperature : TemperatureValue;
            out moisture : MoisturePercentage;
            out correctedTemp : TemperatureValue;
        }
    }

    part def Microcontroller {
        doc /* Orchestrates measurement, packages data, manages power. */
        port processedIn : ProcessedDataPort;
        port dataOut : DataOutPort;
        attribute currentTime : TimeStamp = 0.0;
        attribute powerMode : String = "active";

        action orchestrate {
            in moisture : MoisturePercentage;
            in temperature : TemperatureValue;
            out reading : SoilReading;
        }

        state def ControlStates {
            entry; then Calibrating;
            state Calibrating; then Measuring;
            state Measuring; then Processing;
            state Processing; then Reporting;
            state Reporting; then Measuring;
        }
    }

    // ---- System ----
    part def SoilMoistureSensingUnit {
        doc /* Electronic device placed in the ground to measure soil water content and temperature. */

        port soilPort : SoilInteractionPort;
        port outputPort : DataOutPort;

        part probe : CapacitiveSensorProbe {
            port soilIf : SoilInteractionPort;
        }
        part tempSensor : TemperatureSensor {
            port tempOut : RawSensorPort;
        }
        part processor : SignalProcessor {
            port rawIn : RawSensorPort;
            port processedOut : ProcessedDataPort;
        }
        part controller : Microcontroller {
            port processedIn : ProcessedDataPort;
            port dataOut : DataOutPort;
        }

        connection soilToProbe connect soilPort to probe.soilIf;
        connection probeToProcessor connect probe.soilIf.capacitance to processor.rawIn.capacitance;
        connection tempToProcessor connect tempSensor.tempOut.temperature to processor.rawIn.temperature;
        connection processorToController connect processor.processedOut to controller.processedIn;
        connection controllerToOutput connect controller.dataOut to outputPort;

        state def UnitStateMachine {
            entry; then Calibrate;
            state Calibrate {
                entry action doCalibrate();
            }
            transition Calibrate_to_Measure first Calibrate then Measure;
            state Measure {
                entry action doMeasure();
            }
            transition Measure_to_Process first Measure then Process;
            state Process {
                entry action doProcess();
            }
            transition Process_to_Report first Process then Report;
            state Report {
                entry action doReport();
            }
            transition Report_to_Measure first Report then Measure;
        }

        attribute stateMachine : UnitStateMachine[1];

        action doCalibrate {
            doc /* Self-calibration sequence upon activation. */
        }
        action doMeasure {
            doc /* Trigger probe and temperature sensor. */
        }
        action doProcess {
            doc /* Convert raw data to moisture percentage. */
        }
        action doReport {
            doc /* Package and send soil reading. */
        }
    }

    // ---- Requirements ----
    requirement def ResponsivenessRequirement {
        doc /* The unit shall provide a complete reading within two seconds of activation. */
        attribute maxResponseTime : TimeStamp = 2.0;
        subject unit : SoilMoistureSensingUnit;
        satisfy by unit;
    }

    requirement def AccuracyRequirement {
        doc /* The unit shall be accurate within +/- 3 percent. */
        attribute tolerance : Real = 3.0;
        subject unit : SoilMoistureSensingUnit;
        satisfy by unit;
    }

    requirement def SoilSpectrumRequirement {
        doc /* The unit shall function across the full spectrum of soil conditions, from completely dry to fully saturated. */
        attribute dryMoisture : MoisturePercentage = 0.0;
        attribute saturatedMoisture : MoisturePercentage = 100.0;
        subject unit : SoilMoistureSensingUnit;
        satisfy by unit;
    }

    requirement def MeasurementRequirement {
        doc /* The unit shall measure soil water content and temperature simultaneously. */
        subject unit : SoilMoistureSensingUnit;
        satisfy by unit;
    }

    requirement def PowerManagementRequirement {
        doc /* The microcontroller shall manage the unit's power consumption. */
        subject controller : Microcontroller;
        satisfy by controller;
    }

    requirement SoilMoistureSensingUnitRequirements {
        doc /* Top-level requirements for the soil moisture sensing unit. */
        satisfy ResponsivenessRequirement;
        satisfy AccuracyRequirement;
        satisfy SoilSpectrumRequirement;
        satisfy MeasurementRequirement;
        satisfy PowerManagementRequirement;
    }
}
