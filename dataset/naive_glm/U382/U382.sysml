package HFOV {
    import ScalarValues::*;
    import ScalarFunctions::*;

    // ===== Value Types with Units =====
    value type PressureMeasure :> Real { unit 'Pa'; }
    value type MeanPressureMeasure :> Real { unit 'cmH2O'; }
    value type AmplitudeMeasure :> Real { unit 'cmH2O'; }
    value type FrequencyMeasure :> Real { unit 'Hz'; }
    value type VolumeMeasure :> Real { unit 'mL'; }
    value type FlowMeasure :> Real { unit 'L/min'; }
    value type FractionMeasure :> Real { unit '%'; }
    value type TemperatureMeasure :> Real { unit 'degC'; }
    value type HumidityMeasure :> Real { unit 'percentRH'; }
    value type PowerMeasure :> Real { unit 'W'; }
    value type VoltageMeasure :> Real { unit 'V'; }
    value type ElectricCurrentMeasure :> Real { unit 'A'; }

    // ===== Enumerations =====
    enum OperationalState {
        off;
        selfTest;
        standby;
        ventilating;
        criticalAlarm;
    }

    enum AlarmLevel {
        info;
        low;
        medium;
        high;
        critical;
    }

    enum SelfTestResult {
        pass;
        fail;
    }

    // ===== Item Definitions =====
    item def CompressedAir {
        attribute supplyPressure: PressureMeasure := 350000[Pa];
    }

    item def CompressedOxygen {
        attribute supplyPressure: PressureMeasure := 350000[Pa];
        attribute purity: FractionMeasure := 99.5[%];
    }

    item def GasMixture {
        attribute oxygenConcentration: FractionMeasure;
        attribute totalPressure: PressureMeasure;
    }

    item def HumidifiedGas :> GasMixture {
        attribute temperature: TemperatureMeasure := 37[degC];
        attribute relativeHumidity: HumidityMeasure := 95[percentRH];
        attribute flowRate: FlowMeasure;
    }

    item def OscillatedGas :> HumidifiedGas {
        attribute meanPressure: MeanPressureMeasure;
        attribute amplitude: AmplitudeMeasure;
        attribute oscillationFrequency: FrequencyMeasure;
    }

    item def AlarmSignal {
        attribute level: AlarmLevel;
        attribute message: String;
        attribute timestamp: Real;
    }

    item def TherapySettings {
        attribute oscillationFrequency: FrequencyMeasure;
        attribute pressureAmplitude: AmplitudeMeasure;
        attribute meanAirwayPressure: MeanPressureMeasure;
        attribute fiO2: FractionMeasure;
        attribute biasFlow: FlowMeasure;
    }

    // ===== Port Definitions =====
    port def AirSupplyPort {
        attribute pressure: PressureMeasure;
        out air: CompressedAir;
    }

    port def OxygenSupplyPort {
        attribute pressure: PressureMeasure;
        out oxygen: CompressedOxygen;
    }

    port def GasOutputPort {
        out mixture: HumidifiedGas;
    }

    port def GasInputPort {
        in gas: HumidifiedGas;
    }

    port def OscillatedGasPort {
        out gas: OscillatedGas;
    }

    port def OscillationInputPort {
        in gas: OscillatedGas;
    }

    port def ControlCmdPort {
        in command: Real;
        in settings: TherapySettings;
    }

    port def CommandOutPort {
        out command: Real;
        out settings: TherapySettings;
    }

    port def FeedbackPort {
        out measurement: Real;
    }

    port def AlarmPort {
        out alarm: AlarmSignal;
    }

    port def AlarmAckPort {
        in acknowledge: Boolean;
    }

    port def PowerPort {
        out power: PowerMeasure;
        out voltage: VoltageMeasure;
    }

    // ===== Part Definitions =====
    part def GasBlender {
        port airSupply: AirSupplyPort;
        port oxygenSupply: OxygenSupplyPort;
        port mixtureOut: GasOutputPort;
        port controlIn: ControlCmdPort;

        attribute targetFiO2: FractionMeasure := 40[%];
        attribute outputFlow: FlowMeasure := 20[L/min];
        attribute mixturePressure: PressureMeasure;

        private attribute actualFiO2: FractionMeasure;

        action def blendGases {
            in airInput: CompressedAir;
            in oxygenInput: CompressedOxygen;
            in targetFiO2Value: FractionMeasure;
            out mixedGas: GasMixture;
            perform {
                if targetFiO2Value > 100[%] then {
                    actualFiO2 := 100[%];
                } else if targetFiO2Value < 21[%] then {
                    actualFiO2 := 21[%];
                } else {
                    actualFiO2 := targetFiO2Value;
                }
                mixedGas.oxygenConcentration := actualFiO2;
            }
        }
    }

    part def Humidifier {
        port gasIn: GasInputPort;
        port gasOut: GasOutputPort;
        port controlIn: ControlCmdPort;

        attribute targetTemperature: TemperatureMeasure := 37[degC];
        attribute targetHumidity: HumidityMeasure := 95[percentRH];
        attribute heaterPower: PowerMeasure;

        action def humidify {
            in inputGas: GasMixture;
            in targetTemp: TemperatureMeasure;
            in targetHum: HumidityMeasure;
            out humidified: HumidifiedGas;
            perform {
                heaterPower := (targetTemp - 20[degC]) * 10[W/degC];
                humidified.temperature := targetTemp;
                humidified.relativeHumidity := targetHum;
                humidified.oxygenConcentration := inputGas.oxygenConcentration;
            }
        }
    }

    part def ContinuousFlowGenerator {
        port gasIn: GasInputPort;
        port gasOut: GasOutputPort;
        port controlIn: ControlCmdPort;

        attribute biasFlow: FlowMeasure := 20[L/min];
        attribute meanAirwayPressure: MeanPressureMeasure := 15[cmH2O];
        attribute pressureRegulator: PressureMeasure;

        action def generateFlow {
            in inputGas: HumidifiedGas;
            in targetMeanPressure: MeanPressureMeasure;
            in targetFlow: FlowMeasure;
            out flowGas: HumidifiedGas;
            perform {
                biasFlow := targetFlow;
                meanAirwayPressure := targetMeanPressure;
                pressureRegulator := targetMeanPressure * 98[Pa/cmH2O];
                flowGas.flowRate := targetFlow;
            }
        }
    }

    part def PistonOscillator {
        port gasPort: GasInputPort;
        port oscillationOut: OscillatedGasPort;
        port controlIn: ControlCmdPort;

        attribute frequency: FrequencyMeasure := 10[Hz];
        attribute pressureAmplitude: AmplitudeMeasure := 30[cmH2O];
        attribute pistonStroke: VolumeMeasure := 50[mL];
        attribute pistonSpeed: Real;

        action def oscillate {
            in inputGas: HumidifiedGas;
            in targetFrequency: FrequencyMeasure;
            in targetAmplitude: AmplitudeMeasure;
            in targetMeanPressure: MeanPressureMeasure;
            out oscillated: OscillatedGas;
            perform {
                if targetFrequency < 3[Hz] then {
                    frequency := 3[Hz];
                } else if targetFrequency > 15[Hz] then {
                    frequency := 15[Hz];
                } else {
                    frequency := targetFrequency;
                }
                pressureAmplitude := targetAmplitude;
                meanAirwayPressure := targetMeanPressure;
                pistonSpeed := frequency * 2 * 3.14159;
                oscillated.oscillationFrequency := frequency;
                oscillated.amplitude := pressureAmplitude;
                oscillated.meanPressure := meanAirwayPressure;
                oscillated.flowRate := inputGas.flowRate;
            }
        }
    }

    part def ControlSystem {
        port operatorCommand: ControlCmdPort;
        port alarmOut: AlarmPort;
        port pressureFeedbackIn: FeedbackPort;
        port volumeFeedbackIn: FeedbackPort;
        port blenderCmd: CommandOutPort;
        port flowCmd: CommandOutPort;
        port oscillatorCmd: CommandOutPort;
        port powerIn: PowerPort;

        attribute targetFrequency: FrequencyMeasure := 10[Hz];
        attribute targetAmplitude: AmplitudeMeasure := 30[cmH2O];
        attribute targetMeanPressure: MeanPressureMeasure := 15[cmH2O];
        attribute targetFiO2: FractionMeasure := 40[%];
        attribute targetBiasFlow: FlowMeasure := 20[L/min];
        attribute currentState: OperationalState := OperationalState::off;
        attribute lastAlarm: AlarmLevel := AlarmLevel::info;

        state machine operationalStateMachine {
            state off {
                entry action { currentState := OperationalState::off; }
            }
            state selfTest {
                entry action { currentState := OperationalState::selfTest; }
                do action { performSelfTest(); }
            }
            state standby {
                entry action { currentState := OperationalState::standby; }
            }
            state ventilating {
                entry action { currentState := OperationalState::ventilating; }
                do action { deliverTherapy(); }
            }
            state criticalAlarm {
                entry action {
                    currentState := OperationalState::criticalAlarm;
                    lastAlarm := AlarmLevel::critical;
                    alarmOut.alarm := AlarmSignal{level = AlarmLevel::critical, message = "Critical alarm: patient safety compromised", timestamp = 0.0};
                }
            }

            transition off2selfTest first off -> selfTest when powerApplied;
            transition selfTest2standby first selfTest -> standby when selfTestResult == SelfTestResult::pass;
            transition selfTest2off first selfTest -> off when selfTestResult == SelfTestResult::fail;
            transition standby2ventilating first standby -> ventilating when startVentilation;
            transition ventilating2standby first ventilating -> standby when stopVentilation;
            transition ventilating2criticalAlarm first ventilating -> criticalAlarm when alarmConditionDetected;
            transition standby2criticalAlarm first standby -> criticalAlarm when alarmConditionDetected;
            transition criticalAlarm2off first criticalAlarm -> off when powerOff;
            transition criticalAlarm2standby first criticalAlarm -> standby when alarmAcknowledged;

            action performSelfTest {
                out selfTestResult: SelfTestResult;
                perform {
                    // verify all subsystems
                    selfTestResult := SelfTestResult::pass;
                }
            }

            action deliverTherapy {
                perform {
                    blenderCmd.command := targetFiO2;
                    blenderCmd.settings := TherapySettings{
                        oscillationFrequency = targetFrequency,
                        pressureAmplitude = targetAmplitude,
                        meanAirwayPressure = targetMeanPressure,
                        fiO2 = targetFiO2,
                        biasFlow = targetBiasFlow
                    };
                    flowCmd.command := targetMeanPressure;
                    oscillatorCmd.command := targetFrequency;
                }
            }
        }

        action def evaluateSafety {
            in pressureValue: Real;
            in volumeValue: Real;
            out alarmLevel: AlarmLevel;
            perform {
                if pressureValue > 40[cmH2O] then {
                    alarmLevel := AlarmLevel::critical;
                } else if pressureValue < 5[cmH2O] then {
                    alarmLevel := AlarmLevel::critical;
                } else if pressureValue > 35[cmH2O] then {
                    alarmLevel := AlarmLevel::high;
                } else {
                    alarmLevel := AlarmLevel::info;
                }
            }
        }
    }

    part def OperatorInterface {
        port commandOut: CommandOutPort;
        port alarmAck: AlarmAckPort;
        port alarmIn: AlarmPort;

        attribute displayState: OperationalState;
        attribute displayFrequency: FrequencyMeasure;
        attribute displayAmplitude: AmplitudeMeasure;
        attribute displayMeanPressure: MeanPressureMeasure;
        attribute displayFiO2: FractionMeasure;

        action def updateDisplay {
            in state: OperationalState;
            in freq: FrequencyMeasure;
            in amp: AmplitudeMeasure;
            in meanP: MeanPressureMeasure;
            in fiO2: FractionMeasure;
            perform {
                displayState := state;
                displayFrequency := freq;
                displayAmplitude := amp;
                displayMeanPressure := meanP;
                displayFiO2 := fiO2;
            }
        }

        action def acceptOperatorInput {
            in freqInput: FrequencyMeasure;
            in ampInput: AmplitudeMeasure;
            in meanPInput: MeanPressureMeasure;
            in fiO2Input: FractionMeasure;
            out settings: TherapySettings;
            perform {
                settings.oscillationFrequency := freqInput;
                settings.pressureAmplitude := ampInput;
                settings.meanAirwayPressure := meanPInput;
                settings.fiO2 := fiO2Input;
            }
        }
    }

    part def AlarmSystem {
        port alarmOut: AlarmPort;
        port controlAlarmIn: AlarmPort;
        port monitorAlarmIn: AlarmPort;
        port ackIn: AlarmAckPort;

        attribute currentLevel: AlarmLevel := AlarmLevel::info;
        attribute audibleActive: Boolean := false;
        attribute visualActive: Boolean := false;

        action def triggerAlarm {
            in level: AlarmLevel;
            in message: String;
            perform {
                currentLevel := level;
                if level >= AlarmLevel::high then {
                    audibleActive := true;
                    visualActive := true;
                } else if level == AlarmLevel::medium then {
                    visualActive := true;
                    audibleActive := false;
                } else {
                    audibleActive := false;
                    visualActive := false;
                }
                alarmOut.alarm := AlarmSignal{level = level, message = message, timestamp = 0.0};
            }
        }

        action def silenceAlarm {
            perform {
                audibleActive := false;
                if currentLevel <= AlarmLevel::medium then {
                    visualActive := false;
                }
            }
        }
    }

    part def PressureMonitor {
        port measurementOut: FeedbackPort;
        port alarmOut: AlarmPort;
        port sensorPort: OscillationInputPort;

        attribute measuredPressure: MeanPressureMeasure;
        attribute highLimit: MeanPressureMeasure := 40[cmH2O];
        attribute lowLimit: MeanPressureMeasure := 5[cmH2O];
        attribute sampleRate: FrequencyMeasure := 100[Hz];

        action def measurePressure {
            in gasSample: OscillatedGas;
            out pressureValue: MeanPressureMeasure;
            perform {
                measuredPressure := gasSample.meanPressure;
                measurementOut.measurement := measuredPressure;
            }
        }

        action def checkPressureLimits {
            in pressure: MeanPressureMeasure;
            out alarmLevel: AlarmLevel;
            perform {
                if pressure > highLimit then {
                    alarmLevel := AlarmLevel::critical;
                    alarmOut.alarm := AlarmSignal{level = AlarmLevel::critical, message = "High airway pressure", timestamp = 0.0};
                } else if pressure < lowLimit then {
                    alarmLevel := AlarmLevel::critical;
                    alarmOut.alarm := AlarmSignal{level = AlarmLevel::critical, message = "Low airway pressure", timestamp = 0.0};
                } else {
                    alarmLevel := AlarmLevel::info;
                }
            }
        }
    }

    part def VolumeMonitor {
        port measurementOut: FeedbackPort;
        port alarmOut: AlarmPort;
        port sensorPort: OscillationInputPort;

        attribute measuredTidalVolume: VolumeMeasure;
        attribute highLimit: VolumeMeasure := 30[mL];
        attribute lowLimit: VolumeMeasure := 2[mL];
        attribute sampleRate: FrequencyMeasure := 100[Hz];

        action def measureVolume {
            in gasSample: OscillatedGas;
            out volumeValue: VolumeMeasure;
            perform {
                measuredTidalVolume := gasSample.amplitude * 0.5[mL/cmH2O];
                measurementOut.measurement := measuredTidalVolume;
            }
        }

        action def checkVolumeLimits {
            in volume: VolumeMeasure;
            out alarmLevel: AlarmLevel;
            perform {
                if volume > highLimit then {
                    alarmLevel := AlarmLevel::high;
                    alarmOut.alarm := AlarmSignal{level = AlarmLevel::high, message = "High tidal volume", timestamp = 0.0};
                } else if volume < lowLimit then {
                    alarmLevel := AlarmLevel::high;
                    alarmOut.alarm := AlarmSignal{level = AlarmLevel::high, message = "Low tidal volume", timestamp = 0.0};
                } else {
                    alarmLevel := AlarmLevel::info;
                }
            }
        }
    }

    part def PatientCircuit {
        port ventilatorIn: OscillationInputPort;
        port patientEnd: OscillationInputPort;
        port pressureSensorTap: OscillationInputPort;
        port volumeSensorTap: OscillationInputPort;

        attribute circuitResistance: PressureMeasure;
        attribute circuitCompliance: VolumeMeasure;
        attribute tubeLength: Real := 1.5;
        attribute tubeDiameter: Real := 0.01;

        action def deliverToPatient {
            in gasIn: OscillatedGas;
            out gasOut: OscillatedGas;
            perform {
                gasOut := gasIn;
            }
        }
    }

    part def PowerSupply {
        port powerOut: PowerPort;

        attribute outputPower: PowerMeasure := 500[W];
        attribute inputVoltage: VoltageMeasure := 120[V];
        attribute batteryBackup: PowerMeasure := 200[W];
        attribute onBattery: Boolean := false;

        action def convertPower {
            in inputVoltage: VoltageMeasure;
            out outputPower: PowerMeasure;
            perform {
                outputPower := 500[W];
                powerOut.power := outputPower;
                powerOut.voltage := 24[V];
            }
        }
    }

    // ===== Requirements =====
    requirement def HFOVOverallRequirement {
        subject ventilator: HFOV;
        doc '''
        The HFOV shall provide gentle respiratory support for critically ill
        neonates and pediatric patients by maintaining lung inflation and
        facilitating gas exchange while minimizing the risk of lung injury.
        '''
        require ventilator.gasBlender.targetFiO2 >= 21[%];
        require ventilator.gasBlender.targetFiO2 <= 100[%];
        require ventilator.oscillator.frequency >= 3[Hz];
        require ventilator.oscillator.frequency <= 15[Hz];
    }

    requirement def GasBlendingRequirement {
        subject blender: GasBlender;
        doc '''
        The gas blender shall mix compressed air and oxygen to achieve the
        prescribed oxygen concentration within 2% of the target value.
        '''
        require blender.targetFiO2 >= 21[%];
        require blender.targetFiO2 <= 100[%];
    }

    requirement def ContinuousFlowRequirement {
        subject flowGen: ContinuousFlowGenerator;
        doc '''
        The continuous flow generator shall maintain a steady bias flow to
        sustain the prescribed mean airway pressure.
        '''
        require flowGen.meanAirwayPressure >= 5[cmH2O];
        require flowGen.meanAirwayPressure <= 45[cmH2O];
        require flowGen.biasFlow >= 5[L/min];
        require flowGen.biasFlow <= 40[L/min];
    }

    requirement def OscillationRequirement {
        subject oscillator: PistonOscillator;
        doc '''
        The piston oscillator shall generate high-frequency pressure waves
        at 3 to 15 Hz superimposed on the continuous flow for gas exchange.
        '''
        require oscillator.frequency >= 3[Hz];
        require oscillator.frequency <= 15[Hz];
        require oscillator.pressureAmplitude >= 10[cmH2O];
        require oscillator.pressureAmplitude <= 80[cmH2O];
    }

    requirement def ControlSystemRequirement {
        subject controller: ControlSystem;
        doc '''
        The control system shall orchestrate all subsystems to deliver the
        therapy prescribed via the operator interface.
        '''
        require controller.currentState in {OperationalState::ventilating, OperationalState::standby};
    }

    requirement def SafetyMonitoringRequirement {
        subject monitor: PressureMonitor;
        doc '''
        The pressure and volume monitors shall provide real-time feedback
        and trigger alarms when values exceed safe limits.
        '''
        require monitor.highLimit >= 35[cmH2O];
        require monitor.lowLimit <= 10[cmH2O];
    }

    requirement def AlarmRequirement {
        subject alarm: AlarmSystem;
        doc '''
        The alarm system shall issue audible and visual alerts immediately
        when a critical condition is detected, prioritizing patient safety.
        '''
        require alarm.currentLevel == AlarmLevel::critical implies alarm.audibleActive;
        require alarm.currentLevel == AlarmLevel::critical implies alarm.visualActive;
    }

    requirement def HumidificationRequirement {
        subject humidifier: Humidifier;
        doc '''
        The humidifier shall warm and humidify the gas mixture to body
        conditions to prevent cooling and drying of the patient airway.
        '''
        require humidifier.targetTemperature >= 32[degC];
        require humidifier.targetTemperature <= 40[degC];
        require humidifier.targetHumidity >= 90[percentRH];
    }

    requirement def StateMachineRequirement {
        subject controller: ControlSystem;
        doc '''
        The ventilator shall operate through the states of off, selfTest,
        standby, ventilating, and criticalAlarm, ensuring safe transitions.
        '''
        require controller.currentState in OperationalState;
    }

    // ===== Top-Level HFOV System =====
    part def HFOV {
        part gasBlender: GasBlender;
        part humidifier: Humidifier;
        part flowGenerator: ContinuousFlowGenerator;
        part oscillator: PistonOscillator;
        part controlSystem: ControlSystem;
        part operatorInterface: OperatorInterface;
        part alarmSystem: AlarmSystem;
        part pressureMonitor: PressureMonitor;
        part volumeMonitor: VolumeMonitor;
        part patientCircuit: PatientCircuit;
        part powerSupply: PowerSupply;

        // External supply ports
        port airSupply: AirSupplyPort;
        port oxygenSupply: OxygenSupplyPort;

        // Gas flow connections
        connect airSupply to gasBlender.airSupply;
        connect oxygenSupply to gasBlender.oxygenSupply;
        connect gasBlender.mixtureOut to humidifier.gasIn;
        connect humidifier.gasOut to flowGenerator.gasIn;
        connect flowGenerator.gasOut to oscillator.gasPort;
        connect oscillator.oscillationOut to patientCircuit.ventilatorIn;

        // Patient circuit sensor taps
        connect patientCircuit.pressureSensorTap to pressureMonitor.sensorPort;
        connect patientCircuit.volumeSensorTap to volumeMonitor.sensorPort;

        // Control and command connections
        connect operatorInterface.commandOut to controlSystem.operatorCommand;
        connect controlSystem.blenderCmd to gasBlender.controlIn;
        connect controlSystem.flowCmd to flowGenerator.controlIn;
        connect controlSystem.oscillatorCmd to oscillator.controlIn;

        // Feedback connections
        connect pressureMonitor.measurementOut to controlSystem.pressureFeedbackIn;
        connect volumeMonitor.measurementOut to controlSystem.volumeFeedbackIn;

        // Alarm connections
        connect controlSystem.alarmOut to alarmSystem.controlAlarmIn;
        connect pressureMonitor.alarmOut to alarmSystem.monitorAlarmIn;
        connect volumeMonitor.alarmOut to alarmSystem.monitorAlarmIn;
        connect alarmSystem.alarmOut to operatorInterface.alarmIn;
        connect operatorInterface.alarmAck to alarmSystem.ackIn;

        // Power distribution
        connect powerSupply.powerOut to controlSystem.powerIn;

        attribute systemSerialNumber: String;
        attribute deviceModel: String := "SensorMedics HFOV";
        attribute maximumPatientWeight: Real := 35;

        satisfy HFOVOverallRequirement by ventilator => self;
        satisfy GasBlendingRequirement by blender => gasBlender;
        satisfy ContinuousFlowRequirement by flowGen => flowGenerator;
        satisfy OscillationRequirement by oscillator => oscillator;
        satisfy ControlSystemRequirement by controller => controlSystem;
        satisfy SafetyMonitoringRequirement by monitor => pressureMonitor;
        satisfy AlarmRequirement by alarm => alarmSystem;
        satisfy HumidificationRequirement by humidifier => humidifier;
        satisfy StateMachineRequirement by controller => controlSystem;
    }
}
