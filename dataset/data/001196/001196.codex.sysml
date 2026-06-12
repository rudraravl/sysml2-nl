package PitotTubeAirDataSystem {

    import ScalarValues::*;
    import ISQ::*;

    attribute def Pressure {
        :> scalar;
        unit = "Pa";
    }

    attribute def Temperature {
        :> scalar;
        unit = "K";
    }

    attribute def Velocity {
        :> scalar;
        unit = "m/s";
    }

    attribute def Density {
        :> scalar;
        unit = "kg/m^3";
    }

    attribute def Length {
        :> scalar;
        unit = "m";
    }

    attribute def Angle {
        :> scalar;
        unit = "deg";
    }

    attribute def Time {
        :> scalar;
        unit = "s";
    }

    attribute def Voltage {
        :> scalar;
        unit = "V";
    }

    item def AirStream {
        attribute staticPressure : Pressure;
        attribute totalPressure : Pressure;
        attribute temperature : Temperature;
        attribute density : Density;
        attribute flowVelocity : Velocity;
        attribute flowAngle : Angle;
    }

    item def PressureSignal {
        attribute pressure : Pressure;
        attribute sampleTime : Time;
        attribute valid : Boolean;
    }

    item def AirspeedSignal {
        attribute indicatedAirspeed : Velocity;
        attribute dynamicPressure : Pressure;
        attribute sampleTime : Time;
        attribute valid : Boolean;
    }

    item def ElectricalPower {
        attribute supplyVoltage : Voltage;
        attribute available : Boolean;
    }

    item def DrainageFlow {
        attribute waterPresent : Boolean;
        attribute purgeComplete : Boolean;
    }

    port def PneumaticInletPort {
        in item air : AirStream;
    }

    port def PressureOutputPort {
        out item pressureSignal : PressureSignal;
    }

    port def StaticPressurePort {
        in item staticPressureSignal : PressureSignal;
    }

    port def AirspeedOutputPort {
        out item airspeedSignal : AirspeedSignal;
    }

    port def PowerPort {
        in item power : ElectricalPower;
    }

    port def DrainPort {
        out item drainage : DrainageFlow;
    }

    part def PitotTube {
        attribute inletDiameter : Length = 0.006 [m];
        attribute tubeLength : Length = 0.180 [m];
        attribute alignmentTolerance : Angle = 3 [deg];
        attribute maxOperatingPressure : Pressure = 250000 [Pa];

        port inlet : PneumaticInletPort;
        port totalPressureOut : PressureOutputPort;
        port drain : DrainPort;

        part inletLip {
            attribute radius : Length = 0.0015 [m];
        }

        part stagnationChamber {
            attribute internalVolume : Real;
        }

        part pressureLine {
            attribute internalDiameter : Length = 0.003 [m];
            attribute length : Length = 1.200 [m];
        }

        action collectTotalPressure {
            in item freeStream : AirStream;
            out item measuredTotalPressure : PressureSignal;

            first start;
            then alignFlow;
            then stagnateFlow;
            then transmitPressure;
            then done;

            action alignFlow {
                in item freeStream : AirStream;
            }

            action stagnateFlow {
                in item freeStream : AirStream;
                out item total : PressureSignal;
            }

            action transmitPressure {
                in item total : PressureSignal;
                out item measuredTotalPressure : PressureSignal;
            }
        }

        state def PitotTubeOperatingState {
            state unpowered;
            state ready;
            state measuring;
            state blocked;
            state draining;

            transition unpowered_to_ready
                first unpowered
                accept ElectricalPower
                then ready;

            transition ready_to_measuring
                first ready
                accept AirStream
                then measuring;

            transition measuring_to_blocked
                first measuring
                if totalPressureOut.pressureSignal.valid == false
                then blocked;

            transition blocked_to_draining
                first blocked
                then draining;

            transition draining_to_ready
                first draining
                if drain.drainage.purgeComplete == true
                then ready;
        }

        exhibit stateBehavior : PitotTubeOperatingState;
    }

    part def StaticPressureSource {
        attribute portDiameter : Length = 0.004 [m];

        port staticAirIn : PneumaticInletPort;
        port staticPressureOut : PressureOutputPort;

        action senseStaticPressure {
            in item ambientAir : AirStream;
            out item staticSignal : PressureSignal;
        }
    }

    part def DifferentialPressureSensor {
        attribute measurementRange : Pressure = 10000 [Pa];
        attribute pressureAccuracy : Pressure = 15 [Pa];
        attribute responseTime : Time = 0.020 [s];

        port totalPressureIn : StaticPressurePort;
        port staticPressureIn : StaticPressurePort;
        port powerIn : PowerPort;
        port differentialPressureOut : PressureOutputPort;

        action computeDynamicPressure {
            in item totalPressure : PressureSignal;
            in item staticPressure : PressureSignal;
            out item dynamicPressure : PressureSignal;

            first receivePressures;
            then subtractStaticFromTotal;
            then validateRange;
            then publishDynamicPressure;
            then done;

            action receivePressures;
            action subtractStaticFromTotal;
            action validateRange;
            action publishDynamicPressure;
        }
    }

    part def AirDataComputer {
        attribute assumedSeaLevelDensity : Density = 1.225 [kg/m^3];
        attribute minimumValidDynamicPressure : Pressure = 5 [Pa];

        port dynamicPressureIn : StaticPressurePort;
        port staticPressureIn : StaticPressurePort;
        port airspeedOut : AirspeedOutputPort;
        port powerIn : PowerPort;

        action calculateIndicatedAirspeed {
            in item dynamicPressure : PressureSignal;
            out item airspeed : AirspeedSignal;

            first verifySignalValidity;
            then calculateFromBernoulliEquation;
            then limitLowSpeedNoise;
            then publishAirspeed;
            then done;

            action verifySignalValidity;
            action calculateFromBernoulliEquation {
                constraint {
                    airspeed.indicatedAirspeed == sqrt(2 * dynamicPressure.pressure / assumedSeaLevelDensity);
                }
            }
            action limitLowSpeedNoise;
            action publishAirspeed;
        }

        state def AirDataComputerState {
            state off;
            state initializing;
            state normalOperation;
            state degradedOperation;
            state failed;

            transition off_to_initializing
                first off
                accept ElectricalPower
                if powerIn.power.available == true
                then initializing;

            transition initializing_to_normal
                first initializing
                if dynamicPressureIn.staticPressureSignal.valid == true
                then normalOperation;

            transition normal_to_degraded
                first normalOperation
                if staticPressureIn.staticPressureSignal.valid == false
                then degradedOperation;

            transition degraded_to_normal
                first degradedOperation
                if staticPressureIn.staticPressureSignal.valid == true
                then normalOperation;

            transition any_to_failed
                first normalOperation
                if powerIn.power.available == false
                then failed;
        }

        exhibit stateBehavior : AirDataComputerState;
    }

    part def PitotTubeBasedAirspeedSystem {
        attribute primaryFunction : String =
            "Convert aircraft relative airflow pressure into a valid airspeed indication by sensing total pressure with a forward-facing Pitot tube, comparing it with static pressure, and computing dynamic-pressure-based indicated airspeed.";

        port airInlet : PneumaticInletPort;
        port staticAirInlet : PneumaticInletPort;
        port electricalPowerIn : PowerPort;
        port airspeedIndicationOut : AirspeedOutputPort;
        port waterDrainOut : DrainPort;

        part pitotTube : PitotTube;
        part staticSource : StaticPressureSource;
        part differentialSensor : DifferentialPressureSensor;
        part airDataComputer : AirDataComputer;

        connect airInlet to pitotTube.inlet;
        connect staticAirInlet to staticSource.staticAirIn;
        connect pitotTube.totalPressureOut to differentialSensor.totalPressureIn;
        connect staticSource.staticPressureOut to differentialSensor.staticPressureIn;
        connect staticSource.staticPressureOut to airDataComputer.staticPressureIn;
        connect differentialSensor.differentialPressureOut to airDataComputer.dynamicPressureIn;
        connect airDataComputer.airspeedOut to airspeedIndicationOut;
        connect pitotTube.drain to waterDrainOut;
        connect electricalPowerIn to differentialSensor.powerIn;
        connect electricalPowerIn to airDataComputer.powerIn;

        action performPrimaryFunction {
            in item incomingAir : AirStream;
            out item indicatedAirspeed : AirspeedSignal;

            first captureTotalPressure;
            then captureStaticPressure;
            then deriveDynamicPressure;
            then computeAirspeed;
            then outputAirspeed;
            then done;

            action captureTotalPressure {
                in item incomingAir : AirStream;
                out item totalPressure : PressureSignal;
            }

            action captureStaticPressure {
                in item incomingAir : AirStream;
                out item staticPressure : PressureSignal;
            }

            action deriveDynamicPressure {
                in item totalPressure : PressureSignal;
                in item staticPressure : PressureSignal;
                out item dynamicPressure : PressureSignal;
            }

            action computeAirspeed {
                in item dynamicPressure : PressureSignal;
                out item indicatedAirspeed : AirspeedSignal;
            }

            action outputAirspeed {
                in item indicatedAirspeed : AirspeedSignal;
            }
        }
    }

    requirement def SenseTotalPressureRequirement {
        subject system : PitotTubeBasedAirspeedSystem;

        require constraint {
            system.pitotTube.totalPressureOut.pressureSignal.valid == true
        }

        doc /* The system shall sense total pressure from forward relative airflow using the Pitot tube inlet during normal operation. */
    }

    requirement def CompareWithStaticPressureRequirement {
        subject system : PitotTubeBasedAirspeedSystem;

        require constraint {
            system.differentialSensor.differentialPressureOut.pressureSignal.pressure ==
            system.pitotTube.totalPressureOut.pressureSignal.pressure -
            system.staticSource.staticPressureOut.pressureSignal.pressure
        }

        doc /* The system shall derive dynamic pressure by subtracting static pressure from Pitot total pressure. */
    }

    requirement def AirspeedComputationRequirement {
        subject system : PitotTubeBasedAirspeedSystem;

        require constraint {
            system.airDataComputer.airspeedOut.airspeedSignal.valid == true
        }

        doc /* The system shall output a valid indicated airspeed when total pressure, static pressure, and electrical power inputs are valid. */
    }

    requirement def DrainageRequirement {
        subject system : PitotTubeBasedAirspeedSystem;

        require constraint {
            system.waterDrainOut.drainage.purgeComplete == true implies
            system.waterDrainOut.drainage.waterPresent == false
        }

        doc /* The Pitot tube assembly shall provide drainage capability to remove accumulated water from the pressure path. */
    }

    requirement def PressureRangeProtectionRequirement {
        subject system : PitotTubeBasedAirspeedSystem;

        require constraint {
            system.pitotTube.totalPressureOut.pressureSignal.pressure <=
            system.pitotTube.maxOperatingPressure
        }

        doc /* The Pitot tube shall remain within its maximum operating pressure limit during specified operating conditions. */
    }

    requirement def HighLevelPrimaryFunctionRequirement {
        subject system : PitotTubeBasedAirspeedSystem;

        doc /* The system shall provide aircraft airspeed information by transforming relative airflow pressure into an electrical or digital airspeed signal suitable for display or downstream flight-control use. */
    }

    satisfy SenseTotalPressureRequirement by PitotTubeBasedAirspeedSystem::pitotTube;
    satisfy CompareWithStaticPressureRequirement by PitotTubeBasedAirspeedSystem::differentialSensor;
    satisfy AirspeedComputationRequirement by PitotTubeBasedAirspeedSystem::airDataComputer;
    satisfy DrainageRequirement by PitotTubeBasedAirspeedSystem::pitotTube;
    satisfy PressureRangeProtectionRequirement by PitotTubeBasedAirspeedSystem::pitotTube;
    satisfy HighLevelPrimaryFunctionRequirement by PitotTubeBasedAirspeedSystem;

}