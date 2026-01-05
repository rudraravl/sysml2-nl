package 'SensorMedics HFOV System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def VentilationMode;
    attribute def AlarmCondition;
    attribute def SystemStatus;
    attribute def OscillationFrequency :> ISQ::FrequencyValue;
    attribute def MeanAirwayPressure :> ISQ::PressureValue;
    attribute def TidalVolume :> ISQ::VolumeValue;
    attribute def OxygenConcentration :> Real;
    attribute def FlowRate :> ISQ::VolumetricFlowRateValue;
    attribute def Amplitude :> ISQ::PressureValue;
    attribute def PowerAmplitude :> ISQ::PowerValue;

    item def CompressedGas;
    item def MedicalAir :> CompressedGas;
    item def MedicalOxygen :> CompressedGas;
    item def MixedGas :> CompressedGas;
    item def ExhaledGas :> CompressedGas;

    port def GasSupplyPort {
        in item gasIn : CompressedGas;
        out attribute pressure : PressureValue;
        out attribute flowRate : VolumetricFlowRateValue;
    }

    port def PatientCircuitPort {
        out item deliveredGas : MixedGas;
        in item exhaledGas : ExhaledGas;
        out attribute meanPressure : PressureValue;
        out attribute oscillatoryPressure : PressureValue;
    }

    port def ControlInterfacePort {
        in attribute setFrequency : OscillationFrequency;
        in attribute setMeanPressure : MeanAirwayPressure;
        in attribute setAmplitude : Amplitude;
        in attribute setFiO2 : OxygenConcentration;
        out attribute measuredVolume : TidalVolume;
        out attribute alarmStatus : AlarmCondition;
        out attribute systemStatus : SystemStatus;
    }

    part def GasBlender {
        port airInlet : GasSupplyPort;
        port oxygenInlet : GasSupplyPort;
        port mixedOutlet : GasSupplyPort;

        attribute targetFiO2 : OxygenConcentration;
        attribute actualFiO2 : OxygenConcentration;
        attribute blendedFlowRate : VolumetricFlowRateValue;

        action def BlendGases {
            in airFlowRate : VolumetricFlowRateValue;
            in oxygenFlowRate : VolumetricFlowRateValue;
            in targetFiO2 : OxygenConcentration;
            out mixedGas : MixedGas;
            out actualFiO2 : OxygenConcentration;
        }
    }

    part def PistonOscillator {
        port gasInput : GasSupplyPort;
        port gasOutput : PatientCircuitPort;

        attribute frequency : OscillationFrequency;
        attribute amplitude : Amplitude;
        attribute strokeVolume : TidalVolume;
        attribute pistonPosition : ISQ::LengthValue;

        action def GenerateOscillation {
            in freq : OscillationFrequency;
            in amp : Amplitude;
            in baseFlowRate : VolumetricFlowRateValue;
            out pressureWave : PressureValue;
            out volumeDelivered : TidalVolume;
        }

        state oscillatorBehavior {
            entry; then idle;
            state idle;
            accept StartOscillation
                then oscillating;
            state oscillating {
                do action oscillate : GenerateOscillation;
            }
            accept StopOscillation
                if oscillating
                then idle;
            accept FaultDetected
                if oscillating
                then fault;
            state fault;
            accept FaultCleared
                if fault
                then idle;
        }
    }

    part def ContinuousFlowGenerator {
        port gasInput : GasSupplyPort;
        port gasOutput : GasSupplyPort;

        attribute baseFlowRate : VolumetricFlowRateValue;
        attribute targetMeanPressure : MeanAirwayPressure;
        attribute actualMeanPressure : PressureValue;

        action def MaintainBaseFlow {
            in targetPressure : MeanAirwayPressure;
            in measuredPressure : PressureValue;
            out adjustedFlowRate : VolumetricFlowRateValue;
        }
    }

    part def PatientCircuit {
        port ventilatorConnection : PatientCircuitPort;
        port patientConnection : PatientCircuitPort;

        attribute circuitCompliance : Real;
        attribute circuitResistance : Real;
        attribute circuitVolume : VolumeValue;
    }

    part def PressureMonitor {
        port measurementPoint : PatientCircuitPort;

        attribute currentPressure : PressureValue;
        attribute meanPressure : MeanAirwayPressure;
        attribute peakPressure : PressureValue;
        attribute lowPressure : PressureValue;

        action def MeasurePressure {
            in circuitPressure : PressureValue;
            out instantaneousPressure : PressureValue;
            out calculatedMeanPressure : MeanAirwayPressure;
        }
    }

    part def VolumeMonitor {
        port measurementPoint : PatientCircuitPort;

        attribute deliveredVolume : TidalVolume;
        attribute minuteVolume : VolumeValue;
        attribute expiratoryVolume : VolumeValue;

        action def MeasureVolume {
            in flowRate : VolumetricFlowRateValue;
            in deltaTime : ISQ::TimeValue;
            out accumulatedVolume : TidalVolume;
        }
    }

    part def AlarmSystem {
        attribute highPressureLimit : PressureValue;
        attribute lowPressureLimit : PressureValue;
        attribute highVolumeLimit : VolumeValue;
        attribute lowVolumeLimit : VolumeValue;
        attribute activeAlarms : AlarmCondition[*];

        action def MonitorAlarms {
            in currentPressure : PressureValue;
            in currentVolume : VolumeValue;
            in highPLimit : PressureValue;
            in lowPLimit : PressureValue;
            in highVLimit : VolumeValue;
            in lowVLimit : VolumeValue;
            out alarmTriggered : Boolean;
            out alarmType : AlarmCondition;
        }

        state alarmBehavior {
            entry; then normal;
            state normal;
            accept AlarmTriggered
                then alarmActive;
            state alarmActive {
                do action activateAlarm;
            }
            accept SilencePressed
                if alarmActive
                then alarmSilenced;
            state alarmSilenced;
            accept ConditionCleared
                then normal;
        }
    }

    part def ControlSystem {
        port userInterface : ControlInterfacePort;

        attribute operatingMode : VentilationMode;
        attribute targetFrequency : OscillationFrequency;
        attribute targetMeanPressure : MeanAirwayPressure;
        attribute targetAmplitude : Amplitude;
        attribute targetFiO2 : OxygenConcentration;

        action def ControlVentilation {
            in userSetFrequency : OscillationFrequency;
            in userSetPressure : MeanAirwayPressure;
            in userSetAmplitude : Amplitude;
            in userSetFiO2 : OxygenConcentration;
            in measuredPressure : PressureValue;
            in measuredVolume : VolumeValue;
            out oscillatorCommand : Amplitude;
            out flowCommand : VolumetricFlowRateValue;
            out blenderCommand : OxygenConcentration;
        }

        state controlBehavior {
            entry; then powerOff;
            state powerOff;
            accept PowerOn
                then selfTest;
            state selfTest;
            accept TestPassed
                then standby;
            state standby;
            accept StartVentilation
                then ventilating;
            state ventilating {
                do action controlLoop : ControlVentilation;
            }
            accept StopVentilation
                if ventilating
                then standby;
            accept CriticalAlarm
                if ventilating
                then alarm;
            state alarm;
            accept AlarmResolved
                if alarm
                then standby;
            accept PowerOff
                if standby
                then powerOff;
        }
    }

    part def HighFrequencyOscillatoryVentilator {
        doc /* SensorMedics high-frequency oscillatory ventilator system providing 
               respiratory support through rapid, small-volume oscillations superimposed 
               on continuous positive airway pressure for neonatal and pediatric patients. */

        port airSupply : GasSupplyPort;
        port oxygenSupply : GasSupplyPort;
        port patientInterface : PatientCircuitPort;
        port operatorInterface : ControlInterfacePort;

        part gasMixer : GasBlender {
            port :>> airInlet;
            port :>> oxygenInlet;
            port :>> mixedOutlet;
        }

        part flowGenerator : ContinuousFlowGenerator {
            port :>> gasInput;
            port :>> gasOutput;
        }

        part oscillator : PistonOscillator {
            port :>> gasInput;
            port :>> gasOutput;
        }

        part circuit : PatientCircuit {
            port :>> ventilatorConnection;
            port :>> patientConnection;
        }

        part pressureMonitor : PressureMonitor {
            port :>> measurementPoint;
        }

        part volumeMonitor : VolumeMonitor {
            port :>> measurementPoint;
        }

        part alarmSystem : AlarmSystem;

        part controlSystem : ControlSystem {
            port :>> userInterface;
        }

        connect airSupply to gasMixer.airInlet;
        connect oxygenSupply to gasMixer.oxygenInlet;
        connect gasMixer.mixedOutlet to flowGenerator.gasInput;
        connect flowGenerator.gasOutput to oscillator.gasInput;
        connect oscillator.gasOutput to circuit.ventilatorConnection;
        connect circuit.patientConnection to patientInterface;
        connect circuit.patientConnection to pressureMonitor.measurementPoint;
        connect circuit.patientConnection to volumeMonitor.measurementPoint;
        connect controlSystem.userInterface to operatorInterface;

        perform action provideHighFrequencyVentilation {
            doc /* Primary function: Deliver high-frequency oscillatory ventilation by 
                   generating rapid pressure oscillations at frequencies of 3-15 Hz with 
                   small tidal volumes at or near anatomical dead space, superimposed on 
                   continuous distending pressure to maintain lung recruitment and optimize 
                   gas exchange while minimizing ventilator-induced lung injury. */

            first start;
            then action initializeSystem {
                action performSelfTest;
                then action calibrateSensors;
                then action establishBaseFlow;
            }
            then merge ventilationCycle;

            action receiveOperatorSettings {
                out frequency : OscillationFrequency;
                out meanPressure : MeanAirwayPressure;
                out amplitude : Amplitude;
                out fiO2 : OxygenConcentration;
            }

            flow from receiveOperatorSettings.fiO2 to blendGases.targetFiO2;

            action blendGases : GasBlender::BlendGases {
                in targetFiO2;
                out mixedGas;
                out actualFiO2;
            }

            flow from blendGases.mixedGas to maintainBaseFlow.gasSupply;

            action maintainBaseFlow : ContinuousFlowGenerator::MaintainBaseFlow {
                in gasSupply : MixedGas;
                in targetPressure = receiveOperatorSettings.meanPressure;
                out adjustedFlowRate;
            }

            flow from maintainBaseFlow.adjustedFlowRate to generateOscillations.baseFlowRate;
            flow from receiveOperatorSettings.frequency to generateOscillations.freq;
            flow from receiveOperatorSettings.amplitude to generateOscillations.amp;

            action generateOscillations : PistonOscillator::GenerateOscillation {
                in baseFlowRate;
                in freq;
                in amp;
                out pressureWave;
                out volumeDelivered;
            }

            flow from generateOscillations.pressureWave to deliverToPatient.pressure;
            flow from generateOscillations.volumeDelivered to deliverToPatient.volume;

            action deliverToPatient {
                in pressure : PressureValue;
                in volume : TidalVolume;
                out patientResponse : PressureValue;
            }

            flow from deliverToPatient.patientResponse to monitorParameters.measuredPressure;

            action monitorParameters {
                in measuredPressure : PressureValue;
                out meanPressure : MeanAirwayPressure;
                out measuredVolume : TidalVolume;
            }

            flow from monitorParameters.meanPressure to evaluateAlarms.currentPressure;
            flow from monitorParameters.measuredVolume to evaluateAlarms.currentVolume;

            action evaluateAlarms : AlarmSystem::MonitorAlarms {
                in currentPressure;
                in currentVolume;
                in highPLimit = alarmSystem.highPressureLimit;
                in lowPLimit = alarmSystem.lowPressureLimit;
                in highVLimit = alarmSystem.highVolumeLimit;
                in lowVLimit = alarmSystem.lowVolumeLimit;
                out alarmTriggered;
                out alarmType;
            }

            flow from monitorParameters.meanPressure to adjustControl.feedbackPressure;
            flow from monitorParameters.measuredVolume to adjustControl.feedbackVolume;

            action adjustControl {
                in feedbackPressure : PressureValue;
                in feedbackVolume : VolumeValue;
                out controlAdjustment : Boolean;
            }

            then decide;
                if adjustControl.controlAdjustment then ventilationCycle;
                else accept stopCommand then terminateVentilation;

            action terminateVentilation;
            then done;
        }
    }

    part hfovSystem : HighFrequencyOscillatoryVentilator;

    requirement <'HFOV-REQ-001'> primaryVentilationRequirement {
        doc /* The HFOV system shall deliver high-frequency oscillatory ventilation 
               with frequencies between 3 and 15 Hz and tidal volumes at or near 
               anatomical dead space while maintaining continuous positive airway pressure. */

        subject system : HighFrequencyOscillatoryVentilator;

        require constraint frequencyRange {
            3.0 <= system.oscillator.frequency.num and 
            system.oscillator.frequency.num <= 15.0
        }

        require constraint maintainPositivePressure {
            system.pressureMonitor.meanPressure.num > 0.0
        }

        require constraint smallTidalVolumes {
            system.volumeMonitor.deliveredVolume.num <= 
            system.oscillator.strokeVolume.num
        }
    }

    requirement <'HFOV-REQ-002'> gasDeliveryRequirement {
        doc /* The system shall accurately mix oxygen and air to deliver 
               the prescribed FiO2 between 21% and 100% with accuracy within ±3%. */

        subject mixer : GasBlender;

        require constraint fio2Range {
            21.0 <= mixer.actualFiO2 and mixer.actualFiO2 <= 100.0
        }

        require constraint fio2Accuracy {
            (mixer.actualFiO2 - mixer.targetFiO2).abs() <= 3.0
        }
    }

    requirement <'HFOV-REQ-003'> safetyMonitoringRequirement {
        doc /* The system shall continuously monitor airway pressures and volumes 
               and activate alarms when parameters exceed safe limits. */

        subject alarms : AlarmSystem;

        require constraint continuousMonitoring {
            alarms.activeAlarms != null
        }

        require constraint pressureLimitEnforcement {
            alarms.highPressureLimit.num > alarms.lowPressureLimit.num
        }
    }

    requirement <'HFOV-REQ-004'> oscillationPerformanceRequirement {
        doc /* The piston oscillator shall generate consistent pressure oscillations 
               with amplitude control and maintain stroke volume stability. */

        subject osc : PistonOscillator;

        require constraint amplitudeControl {
            osc.amplitude.num > 0.0
        }

        require constraint strokeVolumeStability {
            osc.strokeVolume.num > 0.0
        }
    }
}
