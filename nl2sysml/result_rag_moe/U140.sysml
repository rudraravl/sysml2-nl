// Design a system based on a Air ioniser and describe its primary function at a high level.
package AirIoniserSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def IonConcentration :> Real;
    attribute def VoltageLevel :> Real;
    attribute def AirFlowRate :> Real;
    attribute def ParticleConcentration :> Real;

    enum def OperatingMode {
        off;
        standby;
        low;
        medium;
        high;
        auto;
    }

    enum def AirQualityLevel {
        excellent;
        good;
        moderate;
        poor;
        hazardous;
    }

    item def Air {
        attribute particleCount : ParticleConcentration;
        attribute ionLevel : IonConcentration;
        attribute quality : AirQualityLevel;
    }

    item def NegativeIon {
        attribute charge : Real;
    }

    part def HighVoltageGenerator {
        attribute outputVoltage : VoltageLevel;
        attribute powerConsumption : PowerValue;
        port voltageOut;
    }

    part def IonEmitter {
        attribute emissionRate : IonConcentration;
        attribute needleCount : Integer;
        port voltageIn;
        port ionOut;
    }

    part def AirQualitySensor {
        attribute sensitivity : Real;
        attribute measurementRange : IonConcentration;
        port airIn;
        port dataOut;
    }

    part def Fan {
        attribute speed : Real;
        attribute flowRate : AirFlowRate;
        attribute maxFlowRate : AirFlowRate;
        port airIn;
        port airOut;
        port controlIn;
    }

    part def ControlUnit {
        attribute currentMode : OperatingMode;
        attribute targetIonLevel : IonConcentration;
        port sensorIn;
        port fanControlOut;
        port generatorControlOut;
        port userInterface;
    }

    part def PowerSupply {
        attribute inputVoltage : VoltageLevel;
        attribute outputVoltage : VoltageLevel;
        attribute maxCurrent : Real;
        port powerIn;
        port powerOut;
    }

    part def FilterAssembly {
        attribute filterEfficiency : Real;
        attribute filterLifespan : DurationValue;
        port airIn;
        port airOut;
    }

    part def AirIoniser {
        attribute operationalStatus : OperatingMode;
        attribute coverageArea : AreaValue;
        attribute totalMass : MassValue;

        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 120.0;
            attribute :>> outputVoltage = 12.0;
            attribute :>> maxCurrent = 2.0;
        }

        part controller : ControlUnit {
            attribute :>> currentMode = OperatingMode::standby;
            attribute :>> targetIonLevel = 5000.0;
        }

        part hvGenerator : HighVoltageGenerator {
            attribute :>> outputVoltage = 5000.0;
            attribute :>> powerConsumption = 15.0 [W];
        }

        part emitter : IonEmitter {
            attribute :>> emissionRate = 8000000.0;
            attribute :>> needleCount = 6;
        }

        part airSensor : AirQualitySensor {
            attribute :>> sensitivity = 0.95;
            attribute :>> measurementRange = 10000000.0;
        }

        part circulationFan : Fan {
            attribute :>> speed = 0.0;
            attribute :>> flowRate = 0.0 [m^3/s];
            attribute :>> maxFlowRate = 0.15 [m^3/s];
        }

        part preFilter : FilterAssembly {
            attribute :>> filterEfficiency = 0.85;
            attribute :>> filterLifespan = 2160.0 [h];
        }

        connection powerSupplyToGenerator connect powerSupply.powerOut to hvGenerator;
        connection generatorToEmitter connect hvGenerator.voltageOut to emitter.voltageIn;
        connection sensorToController connect airSensor.dataOut to controller.sensorIn;
        connection controllerToFan connect controller.fanControlOut to circulationFan.controlIn;
        connection controllerToGenerator connect controller.generatorControlOut to hvGenerator;
        connection filterToFan connect preFilter.airOut to circulationFan.airIn;
        connection fanToEmitter connect circulationFan.airOut to emitter;
        connection emitterToSensor connect emitter.ionOut to airSensor.airIn;
    }

    action def IonGenerationProcess {
        in inputAir : Air;
        in voltage : VoltageLevel;
        out ionizedAir : Air;

        first start;
        then action applyHighVoltage {
            in v = voltage;
        }
        then action generateIons {
            out ions : NegativeIon[*];
        }
        then action attachIonsToAir {
            in air = inputAir;
            in ions = generateIons.ions;
            out result = ionizedAir;
        }
        then done;
    }

    action def AirPurificationCycle {
        first start;
        then merge continuePurification;
        then action intakeAir {
            out rawAir : Air;
        }
        then action filterParticles {
            in air = intakeAir.rawAir;
            out cleanedAir : Air;
        }
        then action ionizeAir {
            in air = filterParticles.cleanedAir;
            out ionizedAir : Air;
        }
        then action measureQuality {
            in air = ionizeAir.ionizedAir;
            out quality : AirQualityLevel;
        }
        then decide;
            if measureQuality.quality == AirQualityLevel::excellent then completeLoop;
            if measureQuality.quality != AirQualityLevel::excellent then adjustSettings;
        action adjustSettings {
            in currentQuality = measureQuality.quality;
        }
        then continuePurification;
        action completeLoop;
        then done;
    }

    state def IoniserOperatingStates {
        entry; then off;

        state off;
        transition off_to_standby
            first off
            accept OperatingMode::standby
            then standby;

        state standby {
            entry action initializeSystem;
        }
        transition standby_to_operating
            first standby
            accept OperatingMode::low
            then operating;

        state operating {
            entry action startIonGeneration;
            do action continuousIonization : AirPurificationCycle;

            state low {
                entry action setLowPower;
            }
            state medium {
                entry action setMediumPower;
            }
            state high {
                entry action setHighPower;
            }
            state auto {
                entry action enableAutoMode;
                do action autoAdjust;
            }

            transition low_to_medium
                first low
                accept OperatingMode::medium
                then medium;

            transition medium_to_high
                first medium
                accept OperatingMode::high
                then high;

            transition low_to_auto
                first low
                accept OperatingMode::auto
                then auto;

            transition medium_to_auto
                first medium
                accept OperatingMode::auto
                then auto;

            transition high_to_auto
                first high
                accept OperatingMode::auto
                then auto;
        }

        transition operating_to_standby
            first operating
            accept OperatingMode::standby
            then standby;

        transition standby_to_off
            first standby
            accept OperatingMode::off
            then off;

        transition operating_to_off
            first operating
            accept OperatingMode::off
            then off;
    }

    requirement <'REQ-001'> primaryFunction {
        doc /* The air ioniser shall generate negative ions to purify indoor air 
             * by attaching to airborne particles and causing them to precipitate.
             */
        subject ioniser : AirIoniser;
    }

    requirement <'REQ-002'> ionGenerationRate {
        doc /* The system shall generate at least 5 million negative ions per 
             * cubic centimeter to effectively purify air.
             */
        subject emitter : AirIoniser::emitter;
        assert constraint {
            emitter.emissionRate >= 5000000.0
        }
    }

    requirement <'REQ-003'> coverageAreaRequirement {
        doc /* The air ioniser shall effectively purify air in a room up to 
             * 40 square meters.
             */
        subject ioniser : AirIoniser;
        assert constraint {
            ioniser.coverageArea >= 40.0 [m^2]
        }
    }

    requirement <'REQ-004'> powerConsumption {
        doc /* The system shall consume no more than 20 watts during normal 
             * operation to ensure energy efficiency.
             */
        subject generator : AirIoniser::hvGenerator;
        assert constraint {
            generator.powerConsumption <= 20.0 [W]
        }
    }

    requirement <'REQ-005'> operatingModes {
        doc /* The air ioniser shall provide multiple operating modes including 
             * off, standby, low, medium, high, and automatic adjustment.
             */
        subject controller : AirIoniser::controller;
    }

    requirement <'REQ-006'> airQualityMonitoring {
        doc /* The system shall continuously monitor air quality and adjust 
             * ionization levels automatically in auto mode.
             */
        subject sensor : AirIoniser::airSensor;
    }

    requirement <'REQ-007'> safetyVoltage {
        doc /* The high voltage generator output shall not exceed 6000 volts 
             * to ensure safe operation.
             */
        subject generator : AirIoniser::hvGenerator;
        assert constraint {
            generator.outputVoltage <= 6000.0
        }
    }

    part airIoniserUnit : AirIoniser {
        attribute :>> operationalStatus = OperatingMode::auto;
        attribute :>> coverageArea = 45.0 [m^2];
        attribute :>> totalMass = 1.8 [kg];

        perform action operateContinuously : AirPurificationCycle;
    }

    satisfy primaryFunction by airIoniserUnit;
    satisfy ionGenerationRate by airIoniserUnit.emitter;
    satisfy coverageAreaRequirement by airIoniserUnit;
    satisfy powerConsumption by airIoniserUnit.hvGenerator;
    satisfy operatingModes by airIoniserUnit.controller;
    satisfy airQualityMonitoring by airIoniserUnit.airSensor;
    satisfy safetyVoltage by airIoniserUnit.hvGenerator;
}
