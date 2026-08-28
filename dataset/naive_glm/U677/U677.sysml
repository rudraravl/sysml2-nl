package FlameDetectionSuppressionSystem {
    import ScalarValues::*;
    import SI::*;

    value type IrradianceValue :> Real { unit 'W/m2'; }
    value type UVIntensityValue :> Real { unit 'W/m2'; }
    value type DecibelValue :> Real { unit 'dB'; }
    value type FrequencyValue :> Real { unit 'Hz'; }
    value type ProbabilityValue :> Real { unit '1'; }
    value type VolumeValue :> Real { unit 'L'; }
    value type TemperatureValue :> Real { unit 'K'; }
    value type DurationValue :> Real { unit 's'; }

    item def IRReading {
        attribute value : IrradianceValue;
    }

    item def UVReading {
        attribute value : UVIntensityValue;
    }

    item def ThermalReading {
        attribute value : TemperatureValue;
    }

    item def FireDetectionResult {
        attribute fireProbability : ProbabilityValue;
        attribute fireDetected : Boolean;
    }

    item def AlarmCommand {
        attribute activate : Boolean;
        attribute sirenLevel : DecibelValue;
        attribute strobeFrequency : FrequencyValue;
    }

    item def SuppressionCommand {
        attribute activate : Boolean;
        attribute agentType : String;
        attribute deploymentDuration : DurationValue;
    }

    port def IRDataPort {
        out irReading : IRReading;
    }

    port def UVDataPort {
        out uvReading : UVReading;
    }

    port def ThermalDataPort {
        out thermalReading : ThermalReading;
    }

    port def SensorInputPort {
        in irReading : IRReading;
        in uvReading : UVReading;
        in thermalReading : ThermalReading;
    }

    port def AlarmOutputPort {
        out alarmCommand : AlarmCommand;
    }

    port def AlarmInputPort {
        in alarmCommand : AlarmCommand;
    }

    port def SuppressionOutputPort {
        out suppressionCommand : SuppressionCommand;
    }

    port def SuppressionInputPort {
        in suppressionCommand : SuppressionCommand;
    }

    part def IRSensor {
        port irOut : IRDataPort;
        attribute detectionRange : IrradianceValue = 100.0 [W/m2];
        attribute samplingRate : FrequencyValue = 10.0 [Hz];
        attribute detectedRadiation : IrradianceValue = 0.0 [W/m2];

        action detectFlameRadiation {
            out reading : IRReading;
        }

        state def IRSensorStates {
            initial Idle;
            state Idle {
                do detectFlameRadiation;
                transition to Active
                    when (detectedRadiation > 0.0 [W/m2]);
            }
            state Active {
                do detectFlameRadiation;
                transition to Idle
                    when (detectedRadiation == 0.0 [W/m2]);
            }
        }

        state machine sensorStateMachine : IRSensorStates;
    }

    part def UVSensor {
        port uvOut : UVDataPort;
        attribute detectionRange : UVIntensityValue = 50.0 [W/m2];
        attribute samplingRate : FrequencyValue = 10.0 [Hz];
        attribute detectedUV : UVIntensityValue = 0.0 [W/m2];

        action detectCombustionUV {
            out reading : UVReading;
        }

        state def UVSensorStates {
            initial Standby;
            state Standby {
                do detectCombustionUV;
                transition to Sensing
                    when (detectedUV > 0.0 [W/m2]);
            }
            state Sensing {
                do detectCombustionUV;
                transition to Standby
                    when (detectedUV == 0.0 [W/m2]);
            }
        }

        state machine sensorStateMachine : UVSensorStates;
    }

    part def ThermalSensor {
        port thermalOut : ThermalDataPort;
        attribute operatingRange : TemperatureValue = 500.0 [K];
        attribute samplingRate : FrequencyValue = 5.0 [Hz];
        attribute currentTemperature : TemperatureValue = 293.15 [K];
        attribute previousTemperature : TemperatureValue = 293.15 [K];

        action measureTemperature {
            out reading : ThermalReading;
        }

        state def ThermalSensorStates {
            initial Monitoring;
            state Monitoring {
                do measureTemperature;
                transition to OverTemp
                    when (currentTemperature > 373.15 [K]);
            }
            state OverTemp {
                do measureTemperature;
                transition to Monitoring
                    when (currentTemperature <= 323.15 [K]);
            }
        }

        state machine sensorStateMachine : ThermalSensorStates;
    }

    part def SignalProcessor {
        port sensorIn : SensorInputPort;
        port alarmOut : AlarmOutputPort;
        port suppressionOut : SuppressionOutputPort;

        attribute irThreshold : IrradianceValue = 50.0 [W/m2];
        attribute uvThreshold : UVIntensityValue = 20.0 [W/m2];
        attribute temperatureThreshold : TemperatureValue = 328.15 [K];
        attribute temperatureRiseRateThreshold : TemperatureValue = 10.0 [K/s];

        attribute fireProbability : ProbabilityValue = 0.0;
        attribute fireDetected : Boolean = false;
        attribute irExceeded : Boolean = false;
        attribute uvExceeded : Boolean = false;
        attribute tempExceeded : Boolean = false;

        action analyzeSensorData {
            in irReading : IRReading;
            in uvReading : UVReading;
            in thermalReading : ThermalReading;
            out result : FireDetectionResult;

            if (irReading.value >= irThreshold) {
                irExceeded = true;
            } else {
                irExceeded = false;
            }

            if (uvReading.value >= uvThreshold) {
                uvExceeded = true;
            } else {
                uvExceeded = false;
            }

            if (thermalReading.value >= temperatureThreshold) {
                tempExceeded = true;
            } else {
                tempExceeded = false;
            }

            if (irExceeded && uvExceeded && tempExceeded) {
                fireProbability = 0.99;
            } else if (irExceeded && uvExceeded) {
                fireProbability = 0.85;
            } else if (irExceeded && tempExceeded) {
                fireProbability = 0.80;
            } else if (uvExceeded && tempExceeded) {
                fireProbability = 0.75;
            } else if (irExceeded || uvExceeded || tempExceeded) {
                fireProbability = 0.40;
            } else {
                fireProbability = 0.0;
            }

            result.fireProbability = fireProbability;
            result.fireDetected = (fireProbability >= 0.75);
        }

        action issueAlarmCommand {
            out cmd : AlarmCommand;
        }

        action issueSuppressionCommand {
            out cmd : SuppressionCommand;
        }

        state def ProcessorStates {
            initial NormalMode;
            state NormalMode {
                do analyzeSensorData;
                transition to AlertMode
                    when (fireProbability >= 0.75);
            }
            state AlertMode {
                entry {
                    fireDetected = true;
                }
                do issueAlarmCommand;
                do issueSuppressionCommand;
                do analyzeSensorData;
                transition to NormalMode
                    when (fireProbability < 0.10);
            }
        }

        state machine processorStateMachine : ProcessorStates;
    }

    part def AlarmDevice {
        port alarmIn : AlarmInputPort;
        attribute maxSirenLevel : DecibelValue = 120.0 [dB];
        attribute strobeFrequency : FrequencyValue = 2.0 [Hz];
        attribute active : Boolean = false;

        action soundSiren {
            in level : DecibelValue;
        }

        action flashStrobes {
            in frequency : FrequencyValue;
        }

        state def AlarmStates {
            initial Silent;
            state Silent {
                transition to Active
                    when (active == true);
            }
            state Active {
                entry { active = true; }
                do soundSiren;
                do flashStrobes;
                transition to Silent
                    when (active == false);
            }
        }

        state machine alarmStateMachine : AlarmStates;
    }

    part def SuppressionActuator {
        port suppressionIn : SuppressionInputPort;
        attribute agentType : String = "CleanAgent";
        attribute tankCapacity : VolumeValue = 50.0 [L];
        attribute remainingAgent : VolumeValue = 50.0 [L];
        attribute deployed : Boolean = false;

        action deploySuppressant {
            in duration : DurationValue;
        }

        state def SuppressionStates {
            initial Ready;
            state Ready {
                transition to Deploying
                    when (deployed == true);
            }
            state Deploying {
                entry { deployed = true; }
                do deploySuppressant;
                transition to Depleted
                    when (remainingAgent == 0.0 [L]);
                transition to Ready
                    when (deployed == false);
            }
            state Depleted {
                entry { deployed = false; }
            }
        }

        state machine actuatorStateMachine : SuppressionStates;
    }

    part def FlameDetectionSuppressionSystem {
        part irSensor : IRSensor;
        part uvSensor : UVSensor;
        part thermalSensor : ThermalSensor;
        part signalProcessor : SignalProcessor;
        part alarmDevice : AlarmDevice;
        part suppressionActuator : SuppressionActuator;

        connection irSensor.irOut to signalProcessor.sensorIn;
        connection uvSensor.uvOut to signalProcessor.sensorIn;
        connection thermalSensor.thermalOut to signalProcessor.sensorIn;
        connection signalProcessor.alarmOut to alarmDevice.alarmIn;
        connection signalProcessor.suppressionOut to suppressionActuator.suppressionIn;
    }

    requirement def FireDetectionRequirement {
        doc /* The system shall detect fires using IR, UV, and thermal sensors and automatically activate alarm and suppression. */
        subject system : FlameDetectionSuppressionSystem;

        requirement DetectFlameIR {
            doc /* The IR sensor shall detect heat radiation characteristic of flames. */
            require system.irSensor.detectionRange >= 100.0 [W/m2];
        }

        requirement DetectFlameUV {
            doc /* The UV sensor shall detect UV light emitted during combustion. */
            require system.uvSensor.detectionRange >= 50.0 [W/m2];
        }

        requirement MonitorTemperature {
            doc /* The thermal sensor shall monitor ambient temperature for sudden increases. */
            require system.thermalSensor.operatingRange >= 500.0 [K];
        }

        requirement ProcessSensorData {
            doc /* The signal processor shall analyze IR, UV, and temperature data in real time against thresholds. */
            require system.signalProcessor.fireProbability >= 0.75 implies system.signalProcessor.fireDetected == true;
        }

        requirement ActivateAlarm {
            doc /* The alarm device shall provide warning via siren and flashing lights upon fire detection. */
            require system.alarmDevice.maxSirenLevel >= 110.0 [dB];
        }

        requirement ActivateSuppression {
            doc /* The suppression actuator shall deploy fire-fighting agent upon fire detection. */
            require system.suppressionActuator.tankCapacity >= 50.0 [L];
        }

        requirement AutomaticResponse {
            doc /* The system shall transition from passive monitoring to active response without human intervention. */
            require system.signalProcessor.fireDetected == true implies
                (system.alarmDevice.active == true and system.suppressionActuator.deployed == true);
        }
    }

    requirement systemRequirements : FireDetectionRequirement {
        subject system : FlameDetectionSuppressionSystem;
    }
}
