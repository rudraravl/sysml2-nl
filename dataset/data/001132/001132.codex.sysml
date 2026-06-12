package MachmeterSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def MachNumber :> Real {
        doc /* Dimensionless ratio of aircraft true airspeed to local speed of sound. */
    }

    attribute def PressurePa :> Real {
        unit = "Pa";
    }

    attribute def TemperatureK :> Real {
        unit = "K";
    }

    attribute def SpeedMetersPerSecond :> Real {
        unit = "m/s";
    }

    attribute def VoltageV :> Real {
        unit = "V";
    }

    attribute def TimeSecond :> Real {
        unit = "s";
    }

    attribute def Percent :> Real {
        unit = "%";
    }

    item def PitotPressureSignal {
        attribute totalPressure : PressurePa;
        attribute measurementTime : TimeSecond;
    }

    item def StaticPressureSignal {
        attribute staticPressure : PressurePa;
        attribute measurementTime : TimeSecond;
    }

    item def AirTemperatureSignal {
        attribute staticAirTemperature : TemperatureK;
        attribute measurementTime : TimeSecond;
    }

    item def ElectricalPower {
        attribute voltage : VoltageV;
        attribute availablePower : Real {
            unit = "W";
        }
    }

    item def MachIndication {
        attribute mach : MachNumber;
        attribute validity : Percent;
        attribute measurementTime : TimeSecond;
    }

    item def WarningSignal {
        attribute overspeed : Boolean;
        attribute sensorFault : Boolean;
        attribute messageCode : String;
    }

    port def PressureInputPort {
        in item pressureSignal;
    }

    port def TemperatureInputPort {
        in item temperatureSignal : AirTemperatureSignal;
    }

    port def PowerInputPort {
        in item power : ElectricalPower;
    }

    port def MachOutputPort {
        out item indication : MachIndication;
    }

    port def WarningOutputPort {
        out item warning : WarningSignal;
    }

    part def PitotProbe {
        port totalPressureOut : PressureInputPort {
            out item pressureSignal : PitotPressureSignal;
        }

        attribute pressureRangeMinimum : PressurePa = 0.0;
        attribute pressureRangeMaximum : PressurePa = 120000.0;
        attribute responseTime : TimeSecond = 0.05;
    }

    part def StaticPort {
        port staticPressureOut : PressureInputPort {
            out item pressureSignal : StaticPressureSignal;
        }

        attribute pressureRangeMinimum : PressurePa = 10000.0;
        attribute pressureRangeMaximum : PressurePa = 105000.0;
        attribute responseTime : TimeSecond = 0.05;
    }

    part def AirTemperatureSensor {
        port temperatureOut : TemperatureInputPort {
            out item temperatureSignal : AirTemperatureSignal;
        }

        attribute temperatureMinimum : TemperatureK = 180.0;
        attribute temperatureMaximum : TemperatureK = 330.0;
        attribute responseTime : TimeSecond = 0.25;
    }

    part def AircraftPowerBus {
        port powerOut : PowerInputPort {
            out item power : ElectricalPower;
        }

        attribute nominalVoltage : VoltageV = 28.0;
        attribute voltageTolerance : Percent = 10.0;
    }

    part def MachComputationUnit {
        port totalPressureIn : PressureInputPort {
            in item pressureSignal : PitotPressureSignal;
        }

        port staticPressureIn : PressureInputPort {
            in item pressureSignal : StaticPressureSignal;
        }

        port temperatureIn : TemperatureInputPort;
        port powerIn : PowerInputPort;
        port machOut : MachOutputPort;
        port warningOut : WarningOutputPort;

        attribute gamma : Real = 1.4;
        attribute gasConstantAir : Real {
            unit = "J/(kg*K)";
        } = 287.05;

        attribute computedMach : MachNumber;
        attribute localSpeedOfSound : SpeedMetersPerSecond;
        attribute trueAirspeed : SpeedMetersPerSecond;
        attribute overspeedLimit : MachNumber = 0.82;
        attribute updatePeriod : TimeSecond = 0.02;

        action computeLocalSpeedOfSound {
            in attribute staticAirTemperature : TemperatureK;
            out attribute speedOfSound : SpeedMetersPerSecond;

            speedOfSound = sqrt(gamma * gasConstantAir * staticAirTemperature);
        }

        action computeMachFromPressureRatio {
            in attribute totalPressure : PressurePa;
            in attribute staticPressure : PressurePa;
            out attribute mach : MachNumber;

            mach = sqrt((2.0 / (gamma - 1.0)) * (((totalPressure / staticPressure) ^ ((gamma - 1.0) / gamma)) - 1.0));
        }

        action publishMachIndication {
            in attribute mach : MachNumber;
            out item indication : MachIndication;

            indication.mach = mach;
            indication.validity = 100.0;
        }

        state machComputerState {
            entry; then initializing;

            state initializing;
            state operational;
            state degraded;
            state failed;

            transition initializing_to_operational
                first initializing
                accept when powerIn.power.voltage >= 25.2 and powerIn.power.voltage <= 30.8
                then operational;

            transition operational_to_degraded
                first operational
                accept when temperatureIn.temperatureSignal.staticAirTemperature < 180.0
                    or temperatureIn.temperatureSignal.staticAirTemperature > 330.0
                    or staticPressureIn.pressureSignal.staticPressure <= 0.0
                then degraded;

            transition degraded_to_operational
                first degraded
                accept when temperatureIn.temperatureSignal.staticAirTemperature >= 180.0
                    and temperatureIn.temperatureSignal.staticAirTemperature <= 330.0
                    and staticPressureIn.pressureSignal.staticPressure > 0.0
                then operational;

            transition any_to_failed
                first initializing, operational, degraded
                accept when powerIn.power.voltage < 18.0
                then failed;
        }
    }

    part def MachDisplay {
        port machIn : MachOutputPort {
            in item indication : MachIndication;
        }

        port warningIn : WarningOutputPort {
            in item warning : WarningSignal;
        }

        attribute displayedMach : MachNumber;
        attribute displayRefreshPeriod : TimeSecond = 0.05;
        attribute minimumDisplayedMach : MachNumber = 0.0;
        attribute maximumDisplayedMach : MachNumber = 1.2;

        action updateDisplay {
            in item indication : MachIndication;
            out attribute displayedMach : MachNumber;

            displayedMach = indication.mach;
        }

        state displayState {
            entry; then blank;

            state blank;
            state normalIndication;
            state overspeedAlert;
            state faultIndication;

            transition blank_to_normal
                first blank
                accept when machIn.indication.validity >= 90.0
                then normalIndication;

            transition normal_to_overspeed
                first normalIndication
                accept when warningIn.warning.overspeed == true
                then overspeedAlert;

            transition overspeed_to_normal
                first overspeedAlert
                accept when warningIn.warning.overspeed == false
                then normalIndication;

            transition normal_to_fault
                first normalIndication, overspeedAlert
                accept when warningIn.warning.sensorFault == true
                then faultIndication;
        }
    }

    part def Machmeter {
        doc /* The Machmeter determines and presents aircraft Mach number by comparing pitot total pressure with static pressure, compensating with air temperature, and displaying the ratio of true airspeed to local speed of sound to the flight crew. */

        port totalPressureInput : PressureInputPort {
            in item pressureSignal : PitotPressureSignal;
        }

        port staticPressureInput : PressureInputPort {
            in item pressureSignal : StaticPressureSignal;
        }

        port temperatureInput : TemperatureInputPort;
        port powerInput : PowerInputPort;
        port machIndicationOutput : MachOutputPort;
        port warningOutput : WarningOutputPort;

        part computationUnit : MachComputationUnit;
        part display : MachDisplay;

        connect totalPressureInput to computationUnit.totalPressureIn;
        connect staticPressureInput to computationUnit.staticPressureIn;
        connect temperatureInput to computationUnit.temperatureIn;
        connect powerInput to computationUnit.powerIn;
        connect computationUnit.machOut to display.machIn;
        connect computationUnit.warningOut to display.warningIn;
        connect computationUnit.machOut to machIndicationOutput;
        connect computationUnit.warningOut to warningOutput;

        attribute indicatedMach : MachNumber;
        attribute indicationAccuracy : MachNumber = 0.01;
        attribute operatingTemperatureMinimum : TemperatureK = 233.0;
        attribute operatingTemperatureMaximum : TemperatureK = 328.0;
        attribute maximumLatency : TimeSecond = 0.10;

        action determineMachNumber {
            in item totalPressure : PitotPressureSignal;
            in item staticPressure : StaticPressureSignal;
            in item airTemperature : AirTemperatureSignal;
            out item indication : MachIndication;

            first computationUnit.computeLocalSpeedOfSound(
                staticAirTemperature = airTemperature.staticAirTemperature,
                speedOfSound = computationUnit.localSpeedOfSound
            );

            then computationUnit.computeMachFromPressureRatio(
                totalPressure = totalPressure.totalPressure,
                staticPressure = staticPressure.staticPressure,
                mach = computationUnit.computedMach
            );

            then computationUnit.publishMachIndication(
                mach = computationUnit.computedMach,
                indication = indication
            );
        }
    }

    part def AircraftMachMeasurementInstallation {
        part pitotProbe : PitotProbe;
        part staticPort : StaticPort;
        part airTemperatureSensor : AirTemperatureSensor;
        part powerBus : AircraftPowerBus;
        part machmeter : Machmeter;

        connect pitotProbe.totalPressureOut to machmeter.totalPressureInput;
        connect staticPort.staticPressureOut to machmeter.staticPressureInput;
        connect airTemperatureSensor.temperatureOut to machmeter.temperatureInput;
        connect powerBus.powerOut to machmeter.powerInput;
    }

    requirement def MachmeterPrimaryFunctionRequirement {
        subject machmeter : Machmeter;

        require constraint {
            machmeter.indicatedMach >= 0.0 and machmeter.indicatedMach <= 1.2
        }

        doc /* The Machmeter shall provide a continuous high-level indication of aircraft Mach number, defined as true airspeed divided by local speed of sound, using aircraft pressure and temperature inputs. */
    }

    requirement def MachmeterAccuracyRequirement {
        subject machmeter : Machmeter;

        require constraint {
            machmeter.indicationAccuracy <= 0.01
        }

        doc /* The Machmeter shall indicate Mach number with an accuracy of plus or minus 0.01 Mach under nominal operating conditions. */
    }

    requirement def MachmeterLatencyRequirement {
        subject machmeter : Machmeter;

        require constraint {
            machmeter.maximumLatency <= 0.10
        }

        doc /* The Machmeter shall update the displayed Mach indication within 0.10 seconds of valid pressure and temperature input changes. */
    }

    requirement def MachmeterOverspeedWarningRequirement {
        subject machmeter : Machmeter;

        require constraint {
            machmeter.computationUnit.overspeedLimit == 0.82
        }

        doc /* The Machmeter shall generate an overspeed warning output when the computed Mach number exceeds Mach 0.82. */
    }

    requirement def MachmeterPowerRequirement {
        subject machmeter : Machmeter;

        require constraint {
            machmeter.powerInput.power.voltage >= 25.2 and machmeter.powerInput.power.voltage <= 30.8
        }

        doc /* The Machmeter shall operate from a nominal 28 VDC aircraft power bus with plus or minus 10 percent voltage tolerance. */
    }

    requirement def MachmeterSensorFaultRequirement {
        subject machmeter : Machmeter;

        require constraint {
            machmeter.staticPressureInput.pressureSignal.staticPressure > 0.0
        }

        doc /* The Machmeter shall detect invalid static pressure input and transition to a degraded or fault indication when Mach computation cannot be trusted. */
    }

    satisfy MachmeterPrimaryFunctionRequirement by Machmeter;
    satisfy MachmeterAccuracyRequirement by Machmeter;
    satisfy MachmeterLatencyRequirement by Machmeter;
    satisfy MachmeterOverspeedWarningRequirement by Machmeter;
    satisfy MachmeterPowerRequirement by Machmeter;
    satisfy MachmeterSensorFaultRequirement by Machmeter;

    part aircraftInstallation : AircraftMachMeasurementInstallation;
}