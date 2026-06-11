package AirspeedIndicatorSystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    unit def knot;
    unit def pascal;
    unit def volt;
    unit def second;

    attribute def Pressure :> pressure {
        unit = pascal;
    }

    attribute def Airspeed :> speed {
        unit = knot;
    }

    attribute def Voltage :> electricPotential {
        unit = volt;
    }

    attribute def Time :> duration {
        unit = second;
    }

    attribute def Angle {
        unit = "degree";
    }

    attribute def Ratio;

    enum def IndicatorMode {
        enum Off;
        enum SelfTest;
        enum Normal;
        enum Degraded;
        enum Failed;
    }

    enum def FailureCode {
        enum None;
        enum PitotBlocked;
        enum StaticBlocked;
        enum PressureSensorFault;
        enum PowerFault;
        enum DisplayFault;
        enum OutOfRangeInput;
    }

    item def TotalPressure {
        attribute value: Pressure;
        attribute sampleAge: Time;
    }

    item def StaticPressure {
        attribute value: Pressure;
        attribute sampleAge: Time;
    }

    item def ElectricalPower {
        attribute voltage: Voltage;
        attribute available: Boolean;
    }

    item def AirspeedIndication {
        attribute indicatedAirspeed: Airspeed;
        attribute valid: Boolean;
        attribute mode: IndicatorMode;
        attribute failure: FailureCode;
    }

    port def TotalPressurePort {
        in item totalPressure: TotalPressure;
    }

    port def StaticPressurePort {
        in item staticPressure: StaticPressure;
    }

    port def PowerPort {
        in item power: ElectricalPower;
    }

    port def IndicationPort {
        out item indication: AirspeedIndication;
    }

    port def MechanicalPointerPort {
        out attribute pointerAngle: Angle;
    }

    port def MaintenancePort {
        out item indication: AirspeedIndication;
    }

    constraint def DynamicPressureCalculation {
        in total: Pressure;
        in static: Pressure;
        out dynamic: Pressure;

        dynamic = total - static;
    }

    constraint def AirspeedFromDynamicPressure {
        in dynamic: Pressure;
        in densityRatio: Ratio;
        out speed: Airspeed;

        speed = sqrt(max(0.0, 2.0 * dynamic / densityRatio));
    }

    constraint def PointerScaleMapping {
        in speed: Airspeed;
        out angle: Angle;

        angle = min(315.0, max(0.0, speed * 1.05));
    }

    part def PitotStaticSource {
        port totalPressureOut: TotalPressurePort;
        port staticPressureOut: StaticPressurePort;

        attribute sensedTotalPressure: Pressure;
        attribute sensedStaticPressure: Pressure;
        attribute pitotLineBlocked: Boolean = false;
        attribute staticLineBlocked: Boolean = false;
    }

    part def PressureTransducer {
        port totalPressureIn: TotalPressurePort;
        port staticPressureIn: StaticPressurePort;

        attribute measuredTotalPressure: Pressure;
        attribute measuredStaticPressure: Pressure;
        attribute dynamicPressure: Pressure;
        attribute sensorHealthy: Boolean = true;
        attribute maximumSampleAge: Time = 0.250 [second];

        constraint dynamicPressureLaw: DynamicPressureCalculation {
            total = measuredTotalPressure;
            static = measuredStaticPressure;
            dynamic = dynamicPressure;
        }
    }

    part def AirspeedComputer {
        attribute dynamicPressure: Pressure;
        attribute densityRatio: Ratio = 1.225;
        attribute computedAirspeed: Airspeed;
        attribute validComputation: Boolean;
        attribute lowSpeedLimit: Airspeed = 20.0 [knot];
        attribute highSpeedLimit: Airspeed = 350.0 [knot];

        constraint speedLaw: AirspeedFromDynamicPressure {
            dynamic = dynamicPressure;
            densityRatio = densityRatio;
            speed = computedAirspeed;
        }

        action def ValidateAirspeed {
            in speed: Airspeed;
            in sensorHealthy: Boolean;
            out valid: Boolean;

            valid = sensorHealthy and speed >= lowSpeedLimit and speed <= highSpeedLimit;
        }
    }

    part def AnalogDialDisplay {
        port pointerOut: MechanicalPointerPort;

        attribute commandedAirspeed: Airspeed;
        attribute pointerAngle: Angle;
        attribute displayHealthy: Boolean = true;

        constraint dialLaw: PointerScaleMapping {
            speed = commandedAirspeed;
            angle = pointerAngle;
        }
    }

    part def DigitalOutput {
        port indicationOut: IndicationPort;
        port maintenanceOut: MaintenancePort;

        attribute reportedAirspeed: Airspeed;
        attribute reportedValid: Boolean;
        attribute reportedMode: IndicatorMode;
        attribute reportedFailure: FailureCode;
    }

    part def PowerConditioner {
        port powerIn: PowerPort;

        attribute inputVoltage: Voltage;
        attribute regulatedVoltage: Voltage = 5.0 [volt];
        attribute powerHealthy: Boolean;

        action def CheckPower {
            in voltage: Voltage;
            in available: Boolean;
            out healthy: Boolean;

            healthy = available and voltage >= 18.0 [volt] and voltage <= 32.0 [volt];
        }
    }

    part def AirspeedIndicator {
        port totalPressureIn: TotalPressurePort;
        port staticPressureIn: StaticPressurePort;
        port powerIn: PowerPort;
        port indicationOut: IndicationPort;
        port pointerOut: MechanicalPointerPort;
        port maintenanceOut: MaintenancePort;

        part transducer: PressureTransducer;
        part computer: AirspeedComputer;
        part dial: AnalogDialDisplay;
        part output: DigitalOutput;
        part powerConditioner: PowerConditioner;

        attribute mode: IndicatorMode = IndicatorMode::Off;
        attribute activeFailure: FailureCode = FailureCode::None;
        attribute indicatedAirspeed: Airspeed;
        attribute primaryFunctionSatisfied: Boolean;

        connect totalPressureIn to transducer.totalPressureIn;
        connect staticPressureIn to transducer.staticPressureIn;
        connect powerIn to powerConditioner.powerIn;
        connect dial.pointerOut to pointerOut;
        connect output.indicationOut to indicationOut;
        connect output.maintenanceOut to maintenanceOut;

        action def ComputeAndDisplayAirspeed {
            in totalPressure: Pressure;
            in staticPressure: Pressure;
            in powerHealthy: Boolean;
            in sensorHealthy: Boolean;
            in displayHealthy: Boolean;
            out airspeed: Airspeed;
            out valid: Boolean;
            out modeOut: IndicatorMode;
            out failureOut: FailureCode;

            first start;
            then calculateDynamicPressure;
            then calculateAirspeed;
            then validate;
            then publish;

            action calculateDynamicPressure {
                out dynamicPressure: Pressure;
            }

            action calculateAirspeed {
                in dynamicPressure: Pressure;
                out computed: Airspeed;
            }

            action validate {
                in computed: Airspeed;
                out validResult: Boolean;
            }

            action publish {
                in computed: Airspeed;
                in validResult: Boolean;
            }
        }

        state def OperatingStateMachine {
            state off;
            state selfTest;
            state normal;
            state degraded;
            state failed;

            transition initial then off;

            transition powerApplied
                first off
                accept ElectricalPower
                if powerConditioner.powerHealthy
                then selfTest;

            transition selfTestPassed
                first selfTest
                if powerConditioner.powerHealthy and transducer.sensorHealthy and dial.displayHealthy
                then normal;

            transition sensorDegraded
                first normal
                if not transducer.sensorHealthy
                then degraded;

            transition displayDegraded
                first normal
                if not dial.displayHealthy
                then degraded;

            transition recover
                first degraded
                if powerConditioner.powerHealthy and transducer.sensorHealthy and dial.displayHealthy
                then normal;

            transition unrecoverableFault
                first normal
                if not powerConditioner.powerHealthy
                then failed;

            transition degradedUnrecoverableFault
                first degraded
                if not powerConditioner.powerHealthy
                then failed;

            transition powerRemoved
                first failed
                accept ElectricalPower
                if not powerConditioner.powerHealthy
                then off;
        }
    }

    part def AircraftAirspeedIndicationInstallation {
        part pitotStaticSource: PitotStaticSource;
        part airspeedIndicator: AirspeedIndicator;

        connect pitotStaticSource.totalPressureOut to airspeedIndicator.totalPressureIn;
        connect pitotStaticSource.staticPressureOut to airspeedIndicator.staticPressureIn;

        port aircraftPower: PowerPort;
        port cockpitAirspeedOutput: IndicationPort;
        port cockpitPointerOutput: MechanicalPointerPort;
        port maintenanceOutput: MaintenancePort;

        connect aircraftPower to airspeedIndicator.powerIn;
        connect airspeedIndicator.indicationOut to cockpitAirspeedOutput;
        connect airspeedIndicator.pointerOut to cockpitPointerOutput;
        connect airspeedIndicator.maintenanceOut to maintenanceOutput;
    }

    requirement def PrimaryFunctionRequirement {
        subject system: AirspeedIndicator;

        doc /* The airspeed indicator shall determine and present aircraft indicated airspeed at a high level by comparing pitot total pressure with static pressure, computing dynamic pressure, converting it to indicated airspeed, and providing the result to the cockpit display interface. */

        require constraint {
            system.primaryFunctionSatisfied == true
        }
    }

    requirement def ValidIndicationRequirement {
        subject system: AirspeedIndicator;

        require constraint {
            system.indicatedAirspeed >= 20.0 [knot] and
            system.indicatedAirspeed <= 350.0 [knot]
        }
    }

    requirement def PowerRequirement {
        subject system: AirspeedIndicator;

        require constraint {
            system.powerConditioner.inputVoltage >= 18.0 [volt] and
            system.powerConditioner.inputVoltage <= 32.0 [volt]
        }
    }

    requirement def FaultReportingRequirement {
        subject system: AirspeedIndicator;

        require constraint {
            system.mode == IndicatorMode::Normal implies
            system.activeFailure == FailureCode::None
        }
    }

    requirement def DegradedModeRequirement {
        subject system: AirspeedIndicator;

        require constraint {
            system.mode == IndicatorMode::Degraded implies
            system.output.reportedValid == false
        }
    }

    satisfy PrimaryFunctionSatisfaction by AirspeedIndicator;
    satisfy ValidIndicationSatisfaction by AirspeedIndicator;
    satisfy PowerSatisfaction by PowerConditioner;
    satisfy FaultReportingSatisfaction by DigitalOutput;
    satisfy DegradedModeSatisfaction by DigitalOutput;
}