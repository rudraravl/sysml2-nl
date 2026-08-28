package ChlorideSensorSystem {
    import ISQ::*;
    import ScalarValues::*;
    import MeasurementReferences::*;

    // ---- Value Types ----
    value type Concentration :> Real { unit 'mg/L'; }
    value type Wavelength :> Real { unit 'nm'; }
    value type LightIntensity :> Real { unit 'lx'; }
    value type Voltage :> Real { unit 'V'; }
    value type Current :> Real { unit 'A'; }
    value type Temperature :> Real { unit 'degC'; }
    value type FlowRate :> Real { unit 'mL/min'; }
    value type DigitalCount :> Integer;
    value type TimeValue :> Real { unit 's'; }

    // ---- Items ----
    item def LiquidSample {
        attribute chlorideConcentration : Concentration;
        attribute temperature : Temperature;
        attribute pH : Real;
    }

    item def OpticalSignal {
        attribute wavelength : Wavelength;
        attribute intensity : LightIntensity;
    }

    item def CalibrationStandard {
        attribute knownConcentration : Concentration;
        attribute expectedDigitalCount : DigitalCount;
    }

    // ---- Ports ----
    port def FluidPort {
        out item sample : LiquidSample;
    }

    port def OpticalPort {
        out item beam : OpticalSignal;
    }

    port def AnalogSignalPort {
        out attribute voltage : Voltage;
    }

    port def DigitalDataPort {
        out attribute count : DigitalCount;
    }

    port def ConcentrationOutputPort {
        out attribute concentration : Concentration;
    }

    port def CommandPort {
        in attribute command : String;
    }

    port def StatusPort {
        out attribute status : String;
        out attribute errorCode : Integer;
    }

    // ---- Component Part Definitions ----
    part def SamplePump {
        port fluidOut : FluidPort;
        attribute nominalFlowRate : FlowRate := 5.0 ['mL/min'];
        attribute maxPressure : Real := 2.0; // bar
    }

    part def QuartzFlowCell {
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        attribute internalVolume : Real := 0.5; // mL
        attribute material : String := "Quartz";
        attribute opticalPathLength : Real := 10.0; // mm
    }

    part def UVLED {
        port lightOut : OpticalPort;
        attribute excitationWavelength : Wavelength := 365 ['nm'];
        attribute driveCurrent : Current := 0.02 ['A'];
        attribute opticalPower : Real := 5.0; // mW
    }

    part def ExcitationFilter {
        port lightIn : OpticalPort;
        port lightOut : OpticalPort;
        attribute centerWavelength : Wavelength := 365 ['nm'];
        attribute bandwidth : Wavelength := 10 ['nm'];
        attribute transmissionEfficiency : Real := 0.85;
    }

    part def SensingChamber {
        port fluidIn : FluidPort;
        port excitationIn : OpticalPort;
        port emissionOut : OpticalPort;
        attribute dyeName : String := "ChlorideQuenchFluorophore";
        attribute referenceIntensity : LightIntensity := 1000.0 ['lx'];
        attribute quenchingConstant : Real := 0.005; // per mg/L
    }

    part def EmissionFilter {
        port lightIn : OpticalPort;
        port lightOut : OpticalPort;
        attribute centerWavelength : Wavelength := 460 ['nm'];
        attribute bandwidth : Wavelength := 20 ['nm'];
        attribute blockingAttenuation : Real := 1e-6; // UV blocking factor
    }

    part def Photodetector {
        port lightIn : OpticalPort;
        port signalOut : AnalogSignalPort;
        attribute responsivity : Real := 0.3; // A/W
        attribute darkCurrent : Current := 1.0e-9 ['A'];
        attribute activeArea : Real := 1.0; // mm^2
    }

    part def SignalConditioner {
        port signalIn : AnalogSignalPort;
        port digitalOut : DigitalDataPort;
        attribute gain : Real := 10000.0;
        attribute resolutionBits : Integer := 16;
        attribute samplingRate : Real := 1000.0; // Hz
        attribute inputRange : Voltage := 3.3 ['V'];
    }

    part def Microprocessor {
        port digitalIn : DigitalDataPort;
        port concentrationOut : ConcentrationOutputPort;
        port commandIn : CommandPort;
        port statusOut : StatusPort;

        attribute calibrationStandards : CalibrationStandard[0..*];
        attribute calibrationSlope : Real;
        attribute calibrationIntercept : Real;
        attribute measurementBuffer : DigitalCount[0..*];
        attribute averagingWindow : Integer := 16;

        action def performCalibration {
            in standards : CalibrationStandard[0..*];
            out slope : Real;
            out intercept : Real;
        }

        action def calculateConcentration {
            in digitalValue : DigitalCount;
            in slope : Real;
            in intercept : Real;
            out concentration : Concentration;
        }

        action def validateMeasurement {
            in rawValue : DigitalCount;
            out isValid : Boolean;
        }
    }

    // ---- System Definition ----
    part def ChlorideSensorSystem {
        // External interfaces
        port sampleInlet : FluidPort;
        port wasteOutlet : FluidPort;
        port concentrationOutput : ConcentrationOutputPort;
        port commandInput : CommandPort;
        port statusOutput : StatusPort;

        // Internal parts
        part pump : SamplePump;
        part flowCell : QuartzFlowCell;
        part led : UVLED;
        part excitationFilter : ExcitationFilter;
        part sensingChamber : SensingChamber;
        part emissionFilter : EmissionFilter;
        part photodetector : Photodetector;
        part signalConditioner : SignalConditioner;
        part microprocessor : Microprocessor;

        // Internal connections
        connection fluidPath1 connect sampleInlet to pump.fluidOut;
        connection fluidPath2 connect pump.fluidOut to flowCell.fluidIn;
        connection fluidPath3 connect flowCell.fluidOut to sensingChamber.fluidIn;
        connection fluidPath4 connect sensingChamber.fluidIn to wasteOutlet;

        connection excitationPath1 connect led.lightOut to excitationFilter.lightIn;
        connection excitationPath2 connect excitationFilter.lightOut to sensingChamber.excitationIn;

        connection emissionPath1 connect sensingChamber.emissionOut to emissionFilter.lightIn;
        connection emissionPath2 connect emissionFilter.lightOut to photodetector.lightIn;

        connection analogLink connect photodetector.signalOut to signalConditioner.signalIn;
        connection digitalLink connect signalConditioner.digitalOut to microprocessor.digitalIn;

        connection outputLink connect microprocessor.concentrationOut to concentrationOutput;
        connection commandLink connect commandInput to microprocessor.commandIn;
        connection statusLink connect microprocessor.statusOut to statusOutput;

        // System attributes
        attribute warmUpDuration : TimeValue := 300.0 ['s'];
        attribute flushDuration : TimeValue := 60.0 ['s'];
        attribute measurementInterval : TimeValue := 10.0 ['s'];
        attribute systemState : String;
        attribute lastConcentration : Concentration;
        attribute faultDetected : Boolean := false;

        // ---- Lifecycle State Machine ----
        state machine lifecycle {
            state off {
                entry action offEntry {
                    /* System powered down, all subsystems inactive */
                }
            }

            state warmUp {
                entry action warmUpEntry {
                    /* Activate LED, stabilize electronics, allow photodetector to reach thermal equilibrium */
                }
                attribute elapsedTime : TimeValue;
            }

            state calibration {
                entry action calibEntry {
                    /* Pump known calibration standards, record digital counts, compute slope and intercept */
                }
            }

            state measuring {
                entry action measureEntry {
                    /* Pump sample through flow cell, excite dye, capture fluorescence intensity */
                }
            }

            state dataProcessing {
                entry action processEntry {
                    /* Apply calibration curve, average buffer, compute chloride concentration */
                }
            }

            state flushing {
                entry action flushEntry {
                    /* Pump clean rinse fluid through flow cell and sensing chamber */
                }
            }

            state error {
                entry action errorEntry {
                    /* Log fault code, disable LED drive, output error status */
                }
            }

            transition powerOn
                from off to warmUp
                when commandInput.command == "POWER_ON";

            transition warmUpDone
                from warmUp to calibration
                when warmUp.elapsedTime >= warmUpDuration;

            transition warmUpFault
                from warmUp to error
                when faultDetected == true;

            transition calibrationDone
                from calibration to measuring
                when commandInput.command == "START_MEASUREMENT";

            transition calibrationFault
                from calibration to error
                when faultDetected == true;

            transition measurementDone
                from measuring to dataProcessing
                when signalConditioner.digitalOut.count is stable;

            transition measurementFault
                from measuring to error
                when faultDetected == true;

            transition processingDone
                from dataProcessing to flushing
                when concentrationOutput.concentration is set;

            transition processingFault
                from dataProcessing to error
                when faultDetected == true;

            transition flushDone
                from flushing to measuring
                when commandInput.command == "CONTINUE";

            transition flushFault
                from flushing to error
                when faultDetected == true;

            transition errorReset
                from error to off
                when commandInput.command == "RESET";

            transition errorShutdown
                from error to off
                when commandInput.command == "SHUTDOWN";
        }

        // ---- Measurement Action Chain ----
        action def MeasurementSequence {
            in sample : LiquidSample;
            out concentration : Concentration;

            action exciteDye {
                in uvLight : OpticalSignal;
                in fluid : LiquidSample;
                out fluorescence : OpticalSignal;
            }

            action filterEmission {
                in rawLight : OpticalSignal;
                out filteredLight : OpticalSignal;
            }

            action detectLight {
                in light : OpticalSignal;
                out analogSignal : Voltage;
            }

            action conditionSignal {
                in analog : Voltage;
                out digital : DigitalCount;
            }

            action computeConcentration {
                in digital : DigitalCount;
                out result : Concentration;
            }

            flow from exciteDye.fluorescence to filterEmission.rawLight;
            flow from filterEmission.filteredLight to detectLight.light;
            flow from detectLight.analogSignal to conditionSignal.analog;
            flow from conditionSignal.digital to computeConcentration.digital;
        }
    }

    // ---- Requirements ----
    package Requirements {
        requirement def MeasurementAccuracyRequirement {
            attribute requiredAccuracy : Real := 0.5; // mg/L
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* The system shall measure chloride concentration with accuracy better than or equal to requiredAccuracy. */
            }
        }

        requirement def ResponseTimeRequirement {
            attribute maxResponseTime : TimeValue := 30.0 ['s'];
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* The system shall produce a concentration reading within maxResponseTime of sample introduction. */
            }
        }

        requirement def WavelengthSpecificationRequirement {
            attribute excitationWavelength : Wavelength := 365 ['nm'];
            attribute emissionWavelength : Wavelength := 460 ['nm'];
            subject led : UVLED;
            subject emFilter : EmissionFilter;
            objective {
                doc /* The UV LED shall emit at excitationWavelength and the emission filter shall pass emissionWavelength. */
            }
        }

        requirement def LifecycleRequirement {
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* The system shall implement warm-up, calibration, measuring, data processing, flushing, and error states. */
            }
        }

        requirement def FaultDetectionRequirement {
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* The system shall detect faults during any operational state and transition to an error state. */
            }
        }

        requirement def ContinuousMonitoringRequirement {
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* The system shall continuously measure and output chloride concentration during the measuring state. */
            }
        }

        requirement def FlushingRequirement {
            attribute flushDuration : TimeValue := 60.0 ['s'];
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* The system shall flush the flow cell and sensing chamber for flushDuration between measurements. */
            }
        }

        requirement measurementAccuracy : MeasurementAccuracyRequirement;
        requirement responseTime : ResponseTimeRequirement;
        requirement wavelengthSpec : WavelengthSpecificationRequirement;
        requirement lifecycleStates : LifecycleRequirement;
        requirement faultDetection : FaultDetectionRequirement;
        requirement continuousMonitoring : ContinuousMonitoringRequirement;
        requirement flushingCycle : FlushingRequirement;
    }

    // ---- Verification ----
    package Verification {
        verification verifyAccuracy {
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* Verify measurement accuracy against known chloride standards. */
            }
            return sensorSystem.lastConcentration;
        }

        verification verifyLifecycle {
            subject sensorSystem : ChlorideSensorSystem;
            objective {
                doc /* Verify all lifecycle states and transitions are reachable. */
            }
        }
    }
}
