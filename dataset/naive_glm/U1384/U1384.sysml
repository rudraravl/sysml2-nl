package PitotStaticAirspeedSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value def PressureValue :> Real {
        unit 'Pa' = pascal;
    }
    value def SpeedValue :> Real {
        unit 'knot' = knot;
    }
    value def DensityValue :> Real {
        unit 'kg/m3' = kilogram / (meter ^ 2);
    }
    value def DimensionlessValue :> Real {
        unit '1' = 1;
    }
    value def FrequencyValue :> Real {
        unit 'Hz' = hertz;
    }
    value def TimeValue :> Real {
        unit 's' = second;
    }

    // ---- Item Types ----
    item def TotalPressure {
        attribute value : PressureValue;
    }
    item def StaticPressure {
        attribute value : PressureValue;
    }
    item def DynamicPressure {
        attribute value : PressureValue;
    }
    item def AirDensity {
        attribute value : DensityValue;
    }
    item def Airspeed {
        attribute value : SpeedValue;
    }
    item def AirspeedReport {
        attribute airspeed : SpeedValue;
        attribute timestamp : TimeValue;
        attribute valid : Boolean;
    }

    // ---- Requirements ----
    requirement def MeasureAirspeedRequirement {
        doc "The system shall continuously measure and display the aircraft's speed relative to the surrounding air."
        attribute updateRate : FrequencyValue = 10 [Hz];
        subject system : PitotStaticAirspeedSystem;
        require { system.measuredAirspeed.value >= 0 [knot] and system.measuredAirspeed.value <= 600 [knot]; }
    }
    requirement def CapturePressureRequirement {
        doc "The Pitot Tube shall capture total and static pressure simultaneously."
        subject pitotTube : PitotTube;
        require { pitotTube.totalPressureOut.item.value >= 0 [Pa]; }
        require { pitotTube.staticPressureOut.item.value >= 0 [Pa]; }
    }
    requirement def ComputeAirspeedRequirement {
        doc "The Air Data Computer shall calculate indicated airspeed using Bernoulli's principle."
        subject adc : AirDataComputer;
        require { adc.airspeedOut.item.value >= 0 [knot]; }
    }
    requirement def ValidateDataRequirement {
        doc "The system shall validate calculated airspeed for plausibility."
        subject adc : AirDataComputer;
        require { adc.validationStatus == true; }
    }
    requirement def DisplayAirspeedRequirement {
        doc "The Display Unit shall present airspeed to the pilot in knots and update at a regular rate."
        subject display : DisplayUnit;
        attribute refreshRate : FrequencyValue = 10 [Hz];
        require { display.displayedAirspeed.value >= 0 [knot]; }
    }
    requirement def StateBehaviorRequirement {
        doc "The system shall initialize on power-up, remain in standby on the ground, switch to active when airflow is detected, and return to standby when the aircraft stops."
        subject system : PitotStaticAirspeedSystem;
        require { system.stateMachine.isInState(Active) implies system.airflowDetected == true; }
    }

    // ---- Port Definitions ----
    port def PressureOutPort {
        out item pressure;
    }
    port def PressureInPort {
        in item pressure;
    }
    port def AirspeedOutPort {
        out item airspeed : AirspeedReport;
    }
    port def AirspeedInPort {
        in item airspeed : AirspeedReport;
    }
    port def DensityInPort {
        in item density : AirDensity;
    }
    port def AirflowSignalPort {
        out attribute airflowDetected : Boolean;
    }

    // ---- Pitot Tube ----
    part def PitotTube {
        port totalPressureOut : PressureOutPort {
            out item pressure : TotalPressure;
        }
        port staticPressureOut : PressureOutPort {
            out item pressure : StaticPressure;
        }
        port airflowSignal : AirflowSignalPort;

        attribute totalPressure : PressureValue;
        attribute staticPressure : PressureValue;

        action def CapturePressures {
            in currentAirspeed : SpeedValue;
            out totalP : TotalPressure;
            out staticP : StaticPressure;
            out airflow : Boolean;
            perform {
                totalP.value = currentAirspeed * currentAirspeed * 1.225 [kg/m3] / 2 + staticP.value;
                airflow = currentAirspeed > 0 [knot];
            }
        }

        perform CapturePressures;
    }

    // ---- Air Data Computer ----
    part def AirDataComputer {
        port totalPressureIn : PressureInPort {
            in item pressure : TotalPressure;
        }
        port staticPressureIn : PressureInPort {
            in item pressure : StaticPressure;
        }
        port densityIn : DensityInPort;
        port airspeedOut : AirspeedOutPort;

        attribute dynamicPressure : PressureValue;
        attribute airDensity : DensityValue = 1.225 [kg/m3];
        attribute calculatedAirspeed : SpeedValue;
        attribute validationStatus : Boolean;
        attribute maxPlausibleAirspeed : SpeedValue = 600 [knot];
        attribute minPlausibleAirspeed : SpeedValue = 0 [knot];

        action def CalculateDynamicPressure {
            in totalP : TotalPressure;
            in staticP : StaticPressure;
            out dynP : DynamicPressure;
            perform {
                dynP.value = totalP.value - staticP.value;
            }
        }

        action def CalculateAirspeed {
            in dynP : DynamicPressure;
            in density : AirDensity;
            out airspeed : Airspeed;
            perform {
                if density.value > 0 [kg/m3] {
                    airspeed.value = sqrt(2 * dynP.value / density.value) * 1.94384; // m/s to knots
                } else {
                    airspeed.value = 0 [knot];
                }
            }
        }

        action def ValidateAirspeed {
            in airspeed : Airspeed;
            out valid : Boolean;
            perform {
                valid = airspeed.value >= minPlausibleAirspeed and airspeed.value <= maxPlausibleAirspeed;
            }
        }

        action def ProcessAirspeed {
            in totalP : TotalPressure;
            in staticP : StaticPressure;
            in density : AirDensity;
            out report : AirspeedReport;
            perform {
                CalculateDynamicPressure(totalP, staticP, dynamicPressure);
                CalculateAirspeed(dynamicPressure, density, calculatedAirspeed);
                ValidateAirspeed(calculatedAirspeed, validationStatus);
                report.airspeed = calculatedAirspeed;
                report.valid = validationStatus;
                report.timestamp = 0 [s];
            }
        }

        perform ProcessAirspeed;
    }

    // ---- Display Unit ----
    part def DisplayUnit {
        port airspeedIn : AirspeedInPort;

        attribute displayedAirspeed : SpeedValue;
        attribute displayValid : Boolean;
        attribute refreshRate : FrequencyValue = 10 [Hz];

        action def UpdateDisplay {
            in report : AirspeedReport;
            perform {
                displayedAirspeed = report.airspeed;
                displayValid = report.valid;
            }
        }

        perform UpdateDisplay;
    }

    // ---- System ----
    part def PitotStaticAirspeedSystem {
        port airflowInput : AirflowSignalPort;
        port densityInput : DensityInPort;
        port airspeedDisplayOut : AirspeedOutPort;

        attribute measuredAirspeed : Airspeed;
        attribute airflowDetected : Boolean = false;
        attribute systemPower : Boolean = true;

        part pitotTube : PitotTube {
            port totalPressureOut : PressureOutPort {
                out item pressure : TotalPressure;
            }
            port staticPressureOut : PressureOutPort {
                out item pressure : StaticPressure;
            }
            port airflowSignal : AirflowSignalPort;
        }

        part airDataComputer : AirDataComputer {
            port totalPressureIn : PressureInPort {
                in item pressure : TotalPressure;
            }
            port staticPressureIn : PressureInPort {
                in item pressure : StaticPressure;
            }
            port densityIn : DensityInPort;
            port airspeedOut : AirspeedOutPort;
        }

        part displayUnit : DisplayUnit {
            port airspeedIn : AirspeedInPort;
        }

        // Connections
        connection pitotTotalToADC connect pitotTube.totalPressureOut to airDataComputer.totalPressureIn;
        connection pitotStaticToADC connect pitotTube.staticPressureOut to airDataComputer.staticPressureIn;
        connection pitotAirflowToSystem connect pitotTube.airflowSignal to airflowInput;
        connection densityToADC connect densityInput to airDataComputer.densityIn;
        connection adcToDisplay connect airDataComputer.airspeedOut to displayUnit.airspeedIn;
        connection displayToSystemOut connect displayUnit.airspeedIn to airspeedDisplayOut;

        // State Machine
        state machine def AirspeedSystemStates {
            entry action initializeSystem {
                systemPower = true;
                airflowDetected = false;
                measuredAirspeed.value = 0 [knot];
            }

            state Initializing {
                entry action powerUp {
                    perform pitotTube.CapturePressures;
                    perform airDataComputer.ProcessAirspeed;
                }
                transition to Standby when systemPower == true;
            }

            state Standby {
                entry action enterStandby {
                    measuredAirspeed.value = 0 [knot];
                }
                do action monitorAirflow {
                    airflowDetected = airflowInput.airflowDetected;
                }
                transition to Active when airflowDetected == true;
            }

            state Active {
                do action continuousMeasurement {
                    perform pitotTube.CapturePressures;
                    perform airDataComputer.ProcessAirspeed;
                    perform displayUnit.UpdateDisplay;
                    measuredAirspeed = displayUnit.displayedAirspeed;
                }
                transition to Standby when airflowDetected == false;
            }

            transition from Initializing to Standby;
            transition from Standby to Active when airflowDetected == true;
            transition from Active to Standby when airflowDetected == false;
        }

        satisfy MeasureAirspeedRequirement by self;
        satisfy CapturePressureRequirement by pitotTube;
        satisfy ComputeAirspeedRequirement by airDataComputer;
        satisfy ValidateDataRequirement by airDataComputer;
        satisfy DisplayAirspeedRequirement by displayUnit;
        satisfy StateBehaviorRequirement by self;

        exhibit AirspeedSystemStates;
    }
}
