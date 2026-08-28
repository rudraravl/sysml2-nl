package FlameDetectorSystem {
    import ScalarValues::Real;
    import ScalarValues::Boolean;
    import ScalarValues::Integer;
    import SI::Watt;
    import SI::Celsius;
    import SI::Hertz;

    attribute def IRIntensityValue :> Real {
        unit W_per_m2;
    }
    attribute def TemperatureValue :> Real {
        unit Celsius;
    }
    attribute def FlickerRateValue :> Real {
        unit Hz;
    }

    item def IRReading {
        attribute intensity : IRIntensityValue;
    }
    item def TemperatureReading {
        attribute temperature : TemperatureValue;
    }
    item def FlickerReading {
        attribute flickerRate : FlickerRateValue;
    }
    item def SensorData {
        attribute ir : IRReading;
        attribute temp : TemperatureReading;
        attribute flicker : FlickerReading;
    }
    item def ActivationCommand;
    item def PowerSupply {
        attribute voltage : Real;
        attribute active : Boolean;
    }

    port def IRDataPort {
        out irReading : IRReading;
    }
    port def TemperatureDataPort {
        out tempReading : TemperatureReading;
    }
    port def FlickerDataPort {
        out flickerReading : FlickerReading;
    }
    port def SensorDataPort {
        out sensorData : SensorData;
    }
    port def CommandPort {
        out command : ActivationCommand;
    }
    port def PowerPort {
        in power : PowerSupply;
    }

    part def IRSensor {
        attribute irThreshold : IRIntensityValue = 5.0;
        port powerIn : PowerPort;
        port dataOut : IRDataPort;
        attribute currentIntensity : IRIntensityValue;
        action def senseIR {
            in environmentRadiation : IRIntensityValue;
            out reading : IRReading;
        }
        action sense : senseIR {
            out reading = dataOut.irReading;
        }
    }

    part def TemperatureSensor {
        attribute tempThreshold : TemperatureValue = 57.0;
        port powerIn : PowerPort;
        port dataOut : TemperatureDataPort;
        attribute currentTemperature : TemperatureValue;
        action def senseTemperature {
            in ambientTemp : TemperatureValue;
            out reading : TemperatureReading;
        }
        action sense : senseTemperature {
            out reading = dataOut.tempReading;
        }
    }

    part def FlickerDetector {
        attribute flickerThreshold : FlickerRateValue = 10.0;
        port powerIn : PowerPort;
        port dataOut : FlickerDataPort;
        attribute currentFlickerRate : FlickerRateValue;
        action def detectFlicker {
            in lightPattern : Real[0..*];
            out reading : FlickerReading;
        }
        action detect : detectFlicker {
            out reading = dataOut.flickerReading;
        }
    }

    part def AnalysisModule {
        attribute irThreshold : IRIntensityValue = 5.0;
        attribute tempThreshold : TemperatureValue = 57.0;
        attribute flickerThreshold : FlickerRateValue = 10.0;
        attribute flameConfirmed : Boolean = false;
        port powerIn : PowerPort;
        port irDataIn : IRDataPort;
        port tempDataIn : TemperatureDataPort;
        port flickerDataIn : FlickerDataPort;
        port commandOut : CommandPort;

        action def analyzeData {
            in ir : IRReading;
            in temp : TemperatureReading;
            in flicker : FlickerReading;
            out command : ActivationCommand;
        }
        action analyze : analyzeData {
            in ir = irDataIn.irReading;
            in temp = tempDataIn.tempReading;
            in flicker = flickerDataIn.flickerReading;
            out command = commandOut.command;
        }
    }

    part def AlarmUnit {
        attribute sirenOutput : Real = 100.0;
        attribute strobeOutput : Real = 100.0;
        attribute sirenActive : Boolean = false;
        attribute strobeActive : Boolean = false;
        port powerIn : PowerPort;
        port commandIn : CommandPort;
        action def activateAlarm {
            in cmd : ActivationCommand;
            out sirenOn : Boolean;
            out strobeOn : Boolean;
        }
        action activate : activateAlarm {
            in cmd = commandIn.command;
            out sirenOn = sirenActive;
            out strobeOn = strobeActive;
        }
    }

    part def PowerModule {
        attribute nominalVoltage : Real = 12.0;
        attribute backupVoltage : Real = 12.0;
        attribute supplyActive : Boolean = true;
        port powerOutIR : PowerPort;
        port powerOutTemp : PowerPort;
        port powerOutFlicker : PowerPort;
        port powerOutAnalysis : PowerPort;
        port powerOutAlarm : PowerPort;
        action def supplyPower {
            out irPower : PowerSupply;
            out tempPower : PowerSupply;
            out flickerPower : PowerSupply;
            out analysisPower : PowerSupply;
            out alarmPower : PowerSupply;
        }
        action supply : supplyPower {
            out irPower = powerOutIR.power;
            out tempPower = powerOutTemp.power;
            out flickerPower = powerOutFlicker.power;
            out analysisPower = powerOutAnalysis.power;
            out alarmPower = powerOutAlarm.power;
        }
    }

    part def FlameDetectorSystem {
        part powerModule : PowerModule;
        part irSensor : IRSensor;
        part tempSensor : TemperatureSensor;
        part flickerDetector : FlickerDetector;
        part analysisModule : AnalysisModule;
        part alarmUnit : AlarmUnit;

        connection powerToIR : PowerSupply = powerModule.powerOutIR to irSensor.powerIn;
        connection powerToTemp : PowerSupply = powerModule.powerOutTemp to tempSensor.powerIn;
        connection powerToFlicker : PowerSupply = powerModule.powerOutFlicker to flickerDetector.powerIn;
        connection powerToAnalysis : PowerSupply = powerModule.powerOutAnalysis to analysisModule.powerIn;
        connection powerToAlarm : PowerSupply = powerModule.powerOutAlarm to alarmUnit.powerIn;

        connection irToAnalysis : IRReading = irSensor.dataOut to analysisModule.irDataIn;
        connection tempToAnalysis : TemperatureReading = tempSensor.dataOut to analysisModule.tempDataIn;
        connection flickerToAnalysis : FlickerReading = flickerDetector.dataOut to analysisModule.flickerDataIn;
        connection analysisToAlarm : ActivationCommand = analysisModule.commandOut to alarmUnit.commandIn;

        state def FlameDetectorStateMachine {
            entry; then Standby;
            state Standby;
            state ActiveMonitoring;
            state Analysis;
            state Alarm;
            transition standbyToActive first Standby then ActiveMonitoring {
                when powerModule.supplyActive == true accept Engage;
            }
            transition activeToAnalysis first ActiveMonitoring then Analysis {
                when (irSensor.currentIntensity >= analysisModule.irThreshold or
                      tempSensor.currentTemperature >= analysisModule.tempThreshold or
                      flickerDetector.currentFlickerRate >= analysisModule.flickerThreshold)
                accept PotentialFlameDetected;
            }
            transition analysisToActive first Analysis then ActiveMonitoring {
                when (analysisModule.irDataIn.irReading.intensity < analysisModule.irThreshold or
                      analysisModule.tempDataIn.tempReading.temperature < analysisModule.tempThreshold or
                      analysisModule.flickerDataIn.flickerReading.flickerRate < analysisModule.flickerThreshold)
                accept NoFlameConfirmed;
            }
            transition analysisToAlarm first Analysis then Alarm {
                when (analysisModule.irDataIn.irReading.intensity >= analysisModule.irThreshold and
                      analysisModule.tempDataIn.tempReading.temperature >= analysisModule.tempThreshold and
                      analysisModule.flickerDataIn.flickerReading.flickerRate >= analysisModule.flickerThreshold)
                accept FlameConfirmed;
            }
            transition alarmToActive first Alarm then ActiveMonitoring {
                accept Reset;
            }
        }
        state machine : FlameDetectorStateMachine;
    }

    requirement def FlameDetectionRequirement {
        subject detector : FlameDetectorSystem;
        objective {
            doc "The system shall continuously monitor the environment for fire using three sensing technologies."
        }
    }
    requirement def MultiFactorConfirmationRequirement {
        subject analysis : AnalysisModule;
        objective {
            doc "A flame shall only be confirmed when IR intensity, temperature, and flicker rate all exceed their thresholds simultaneously."
        }
    }
    requirement def AlarmActivationRequirement {
        subject alarm : AlarmUnit;
        objective {
            doc "Upon flame confirmation, the alarm unit shall activate both an audible siren and a visual strobe light."
        }
    }
    requirement def PowerStabilityRequirement {
        subject power : PowerModule;
        objective {
            doc "The power module shall provide a stable and reliable electrical supply to all components."
        }
    }
    requirement def StateTransitionRequirement {
        subject sm : FlameDetectorStateMachine;
        objective {
            doc "The system shall transition through Standby, ActiveMonitoring, Analysis, and Alarm states, returning to ActiveMonitoring upon reset."
        }
    }

    requirement spec FlameDetectorRequirements {
        requirement flameDetection : FlameDetectionRequirement;
        requirement multiFactor : MultiFactorConfirmationRequirement;
        requirement alarmActivation : AlarmActivationRequirement;
        requirement powerStability : PowerStabilityRequirement;
        requirement stateTransition : StateTransitionRequirement;
    }
}
