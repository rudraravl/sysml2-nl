package EFI_System {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Units =====
    unit def Pa;
    unit def L;
    unit def kg_per_s;
    unit def m3_per_s;
    unit def deg;
    unit def rpm;
    unit def V;
    unit def ms;
    unit def kg;
    unit def ratio;
    unit def K;

    // ===== Item Definitions =====
    item def Fuel;
    item def Air;
    item def AirFuelMixture;
    item def ExhaustGas;

    // ===== Value Types =====
    value def PressureValue :> Real { unit Pa; }
    value def VolumeValue :> Real { unit L; }
    value def MassFlowValue :> Real { unit kg_per_s; }
    value def VolumeFlowValue :> Real { unit m3_per_s; }
    value def AngleValue :> Real { unit deg; }
    value def RotationalSpeedValue :> Real { unit rpm; }
    value def VoltageValue :> Real { unit V; }
    value def DurationValue :> Real { unit ms; }
    value def MassValue :> Real { unit kg; }
    value def RatioValue :> Real { unit ratio; }
    value def TemperatureValue :> Real { unit K; }

    // ===== Port Definitions =====
    port def FuelPort { item fuel: Fuel; }
    port def AirPort { item air: Air; }
    port def MixturePort { item mixture: AirFuelMixture; }
    port def ExhaustPort { item exhaust: ExhaustGas; }
    port def AnalogSignalPort { attribute voltage: VoltageValue; }
    port def DigitalSignalPort {
        attribute voltage: VoltageValue;
        attribute frequency: RotationalSpeedValue;
    }
    port def InjectorPulsePort {
        attribute voltage: VoltageValue;
        attribute pulseDuration: DurationValue;
    }
    port def MechanicalAnglePort { attribute angle: AngleValue; }
    port def MechanicalSpeedPort { attribute speed: RotationalSpeedValue; }

    // ===== Requirements =====
    requirement def FuelDeliveryRequirement {
        doc "The system shall deliver pressurized, filtered fuel to all four injectors.";
    }
    requirement def AirFuelRatioRequirement {
        attribute targetAFR: RatioValue = 14.7;
        doc "The system shall maintain a stoichiometric air-fuel ratio of 14.7:1 under steady-state conditions.";
    }
    requirement def InjectorTimingRequirement {
        doc "The ECU shall send timed pulses to each injector synchronized with crankshaft position.";
    }
    requirement def PressureRegulationRequirement {
        attribute targetPressure: PressureValue = 350000;
        doc "The system shall maintain fuel rail pressure at targetPressure within +/- 5%.";
    }
    requirement def ClosedLoopControlRequirement {
        doc "The ECU shall use oxygen sensor feedback to adjust fuel delivery in closed-loop operation.";
    }

    // ===== Component Definitions =====

    part def FuelTank {
        port out fuelOut: FuelPort;
        port in returnIn: FuelPort;
        attribute capacity: VolumeValue = 50;
        attribute currentLevel: VolumeValue = 50;
    }

    part def FuelPump {
        port in fuelIn: FuelPort;
        port out fuelOut: FuelPort;
        port in powerIn: AnalogSignalPort;
        attribute nominalPressure: PressureValue = 400000;
        attribute flowRate: VolumeFlowValue = 0.0005;
        attribute isRunning: Boolean = false;
    }

    part def FuelFilter {
        port in fuelIn: FuelPort;
        port out fuelOut: FuelPort;
        attribute efficiency: RatioValue = 0.99;
    }

    part def PressureRegulator {
        port in fuelIn: FuelPort;
        port out fuelOut: FuelPort;
        port out returnOut: FuelPort;
        attribute regulatedPressure: PressureValue = 350000;
    }

    part def FuelRail {
        port in fuelIn: FuelPort;
        port out injectorFeed[4]: FuelPort;
        attribute railPressure: PressureValue;
    }

    part def FuelInjector {
        port in fuelIn: FuelPort;
        port in pulseIn: InjectorPulsePort;
        port out mixtureOut: MixturePort;
        attribute flowRate: VolumeFlowValue = 0.00003;
        attribute isOpen: Boolean = false;
    }

    part def ThrottleBody {
        port in airIn: AirPort;
        port out airOut: AirPort;
        port out mechanicalAngle: MechanicalAnglePort;
        attribute throttleAngle: AngleValue;
        attribute maxAngle: AngleValue = 90;
    }

    part def IntakeManifold {
        port in airIn: AirPort;
        port in mixtureIn[4]: MixturePort;
        port out mixtureOut[4]: MixturePort;
        attribute manifoldPressure: PressureValue;
    }

    part def Engine {
        port in mixtureIn[4]: MixturePort;
        port out exhaustOut: ExhaustPort;
        port out mechanicalSpeed: MechanicalSpeedPort;
        attribute cylinderCount: Integer = 4;
        attribute displacement: VolumeValue = 2.0;
        attribute rpm: RotationalSpeedValue;
    }

    part def MAFSensor {
        port in airIn: AirPort;
        port out airOut: AirPort;
        port out signalOut: AnalogSignalPort;
        attribute measuredMassFlow: MassFlowValue;
    }

    part def ThrottlePositionSensor {
        port in mechanicalInput: MechanicalAnglePort;
        port out signalOut: AnalogSignalPort;
        attribute measuredAngle: AngleValue;
    }

    part def CrankshaftPositionSensor {
        port in mechanicalInput: MechanicalSpeedPort;
        port out signalOut: DigitalSignalPort;
        attribute measuredRPM: RotationalSpeedValue;
    }

    part def OxygenSensor {
        port in exhaustIn: ExhaustPort;
        port out signalOut: AnalogSignalPort;
        attribute measuredAFR: RatioValue;
    }

    part def ECU {
        port in mafSignal: AnalogSignalPort;
        port in tpsSignal: AnalogSignalPort;
        port in cpsSignal: DigitalSignalPort;
        port in o2Signal: AnalogSignalPort;
        port out injectorPulse[4]: InjectorPulsePort;
        port out pumpPower: AnalogSignalPort;

        attribute targetAFR: RatioValue = 14.7;
        attribute calculatedFuelMass: MassValue;
        attribute injectionDuration: DurationValue;
        attribute engineRPM: RotationalSpeedValue;
        attribute operatingMode: String;

        action def performInitialization {
            out done: Boolean;
        }

        action def calculateFuelMass {
            in maf: MassFlowValue;
            in rpm: RotationalSpeedValue;
            in afr: RatioValue;
            out fuelMass: MassValue;
        }

        action def determineInjectionTiming {
            in rpm: RotationalSpeedValue;
            in cylinderIndex: Integer;
            out pulseDuration: DurationValue;
        }

        action def closedLoopCorrection {
            in o2Voltage: VoltageValue;
            in baseFuelMass: MassValue;
            out correctedFuelMass: MassValue;
        }

        state machine ECUControlStates {
            state Off;
            transition off_to_init
                first Off
                then Initializing
                when pumpPower.voltage > 0;
            state Initializing {
                entry { operatingMode = "initializing"; }
                do performInitialization();
            }
            transition init_to_run
                first Initializing
                then Running
                when cpsSignal.frequency > 0;
            state Running {
                entry { operatingMode = "running"; }
                state OpenLoop {
                    do calculateFuelMass(mafSignal.voltage, cpsSignal.frequency, targetAFR);
                }
                state ClosedLoop {
                    do closedLoopCorrection(o2Signal.voltage, calculatedFuelMass);
                }
                transition open_to_closed
                    first OpenLoop
                    then ClosedLoop
                    when o2Signal.voltage > 0.1 & o2Signal.voltage < 0.9;
                transition closed_to_open
                    first ClosedLoop
                    then OpenLoop
                    when engineRPM > 4000;
            }
            transition run_to_off
                first Running
                then Off
                when pumpPower.voltage == 0;
        }
    }

    // ===== System Assembly =====
    part def EFI_System {
        satisfy FuelDeliveryRequirement;
        satisfy AirFuelRatioRequirement;
        satisfy InjectorTimingRequirement;
        satisfy PressureRegulationRequirement;
        satisfy ClosedLoopControlRequirement;

        part fuelTank: FuelTank;
        part fuelPump: FuelPump;
        part fuelFilter: FuelFilter;
        part pressureRegulator: PressureRegulator;
        part fuelRail: FuelRail;
        part injectors[4]: FuelInjector;
        part throttleBody: ThrottleBody;
        part intakeManifold: IntakeManifold;
        part engine: Engine;
        part mafSensor: MAFSensor;
        part tpsSensor: ThrottlePositionSensor;
        part cpsSensor: CrankshaftPositionSensor;
        part o2Sensor: OxygenSensor;
        part ecu: ECU;

        // Fuel delivery path
        connect fuelTank.fuelOut to fuelPump.fuelIn;
        connect fuelPump.fuelOut to fuelFilter.fuelIn;
        connect fuelFilter.fuelOut to pressureRegulator.fuelIn;
        connect pressureRegulator.fuelOut to fuelRail.fuelIn;
        connect pressureRegulator.returnOut to fuelTank.returnIn;

        // Fuel rail to injectors
        connect fuelRail.injectorFeed to injectors.fuelIn;

        // Air intake path
        connect mafSensor.airOut to throttleBody.airIn;
        connect throttleBody.airOut to intakeManifold.airIn;

        // Injectors spray into intake manifold
        connect injectors.mixtureOut to intakeManifold.mixtureIn;

        // Intake manifold to engine cylinders
        connect intakeManifold.mixtureOut to engine.mixtureIn;

        // Exhaust path
        connect engine.exhaustOut to o2Sensor.exhaustIn;

        // Mechanical linkages
        connect throttleBody.mechanicalAngle to tpsSensor.mechanicalInput;
        connect engine.mechanicalSpeed to cpsSensor.mechanicalInput;

        // Sensor signals to ECU
        connect mafSensor.signalOut to ecu.mafSignal;
        connect tpsSensor.signalOut to ecu.tpsSignal;
        connect cpsSensor.signalOut to ecu.cpsSignal;
        connect o2Sensor.signalOut to ecu.o2Signal;

        // ECU control outputs
        connect ecu.injectorPulse to injectors.pulseIn;
        connect ecu.pumpPower to fuelPump.powerIn;
    }
}
