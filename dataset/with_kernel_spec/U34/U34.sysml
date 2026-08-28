package AlternatingElectricFieldTherapySystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    item def PowerStatus {
        attribute onBattery : Boolean;
        attribute dcVoltage : ElectricPotentialValue;
    }
    item def ElectricFieldCommand {
        attribute direction : DirectionEnum;
        attribute frequency : FrequencyValue;
        attribute intensity : ElectricPotentialValue;
    }
    enum def DirectionEnum {
        anteriorPosterior;
        leftRight;
    }
    item def SensedTemperature {
        attribute value : TemperatureValue;
    }
    attribute def TherapyParameters {
        attribute frequency : FrequencyValue;
        attribute intensity : ElectricPotentialValue;
        attribute rotationInterval : DurationValue;
        attribute maxSkinTemperature : TemperatureValue;
        attribute totalDuration : DurationValue;
    }
    item def StartTherapy;
    item def HaltTherapy;
    item def TherapyComplete;
    item def TestPassed;
    item def TestFailed;
    item def SystemReset;

    action def RunSelfTest;
    action def LoadTherapyParameters { out params : TherapyParameters; }
    action def SynthesizeWaveform { in cmd : ElectricFieldCommand; }
    action def SenseTemperature { out temp : TemperatureValue; }

    part def PowerModule {
        port acInputPort { in acPower; }
        port dcOutputPort { out powerStatus : PowerStatus; }
        attribute batteryCapacity : DurationValue;
    }

    part def ControlProcessor {
        port powerPort { in powerStatus : PowerStatus; }
        port commandPort { out fieldCommand : ElectricFieldCommand; }
        port temperaturePort { in sensedTemp : SensedTemperature; }
        port safetyPort { out haltTherapy : HaltTherapy; }
        port therapyControlPort { in startTherapy : StartTherapy; out therapyComplete : TherapyComplete; }
        attribute therapyParams : TherapyParameters;
        exhibit state processorStates : ProcessorStates;
    }
    state def ProcessorStates {
        in processor : ControlProcessor;
        entry; then idle;
        state idle;
        accept StartTherapy
            do action loadParams : LoadTherapyParameters
            then selfTest;
        state selfTest {
            entry action runSelfTest : RunSelfTest;
        }
        accept TestPassed
            then active;
        accept TestFailed
            then idle;
        state active parallel {
            state therapyControl {
                entry; then fieldAP;
                state fieldAP;
                accept after processor.therapyParams.rotationInterval
                    do send new ElectricFieldCommand{ direction = DirectionEnum::leftRight; frequency = processor.therapyParams.frequency; intensity = processor.therapyParams.intensity; } to processor.commandPort
                    then fieldLR;
                state fieldLR;
                accept after processor.therapyParams.rotationInterval
                    do send new ElectricFieldCommand{ direction = DirectionEnum::anteriorPosterior; frequency = processor.therapyParams.frequency; intensity = processor.therapyParams.intensity; } to processor.commandPort
                    then fieldAP;
            }
            state safetyMonitor {
                entry; then monitoring;
                state monitoring;
                accept when processor.temperaturePort.sensedTemp.value > processor.therapyParams.maxSkinTemperature
                    do send new HaltTherapy() to processor.safetyPort
                    then halted;
                state halted;
            }
            state sessionTimer {
                entry; then running;
                state running;
                accept after processor.therapyParams.totalDuration
                    do send new TherapyComplete() to processor.therapyControlPort
                    then complete;
                state complete;
            }
        }
        accept TherapyComplete
            then idle;
        accept SystemReset
            then idle;
    }

    part def FieldGenerator {
        port commandPort { in fieldCommand : ElectricFieldCommand; }
        port anteriorArrayPort { out anteriorSignal; }
        port posteriorArrayPort { out posteriorSignal; }
        port leftArrayPort { out leftSignal; }
        port rightArrayPort { out rightSignal; }
        exhibit state generatorStates : GeneratorStates;
    }
    state def GeneratorStates {
        in generator : FieldGenerator;
        entry; then idle;
        state idle;
        accept ElectricFieldCommand
            then generating;
        state generating {
            do action synthesize : SynthesizeWaveform { in cmd = generator.commandPort.fieldCommand; }
        }
        accept HaltTherapy
            then idle;
    }

    part def TemperatureSensor {
        port tempOutPort { out sensedTemp : SensedTemperature; }
        attribute currentTemp : TemperatureValue;
    }

    part def TransducerArray {
        attribute position : ArrayPosition;
        port signalPort { in driveSignal; }
        port tempPort { out sensedTemp : SensedTemperature; }
        part ceramicDisks [*];
        part tempSensor : TemperatureSensor;
    }
    enum def ArrayPosition {
        anterior;
        posterior;
        left;
        right;
    }

    requirement def TherapyEfficacyRequirement {
        doc /* The system shall disrupt cancer cell mitosis by applying low-intensity, intermediate-frequency electric fields at approximately 200 kHz to the tumor. */
    }
    requirement def FieldRotationRequirement {
        doc /* The system shall continuously rotate the electric field orientation between at least two orthogonal directions during treatment. */
    }
    requirement def SafetyRequirement {
        attribute maxSafeTemp : TemperatureValue;
        doc /* The system shall automatically halt therapy if any transducer array skin temperature exceeds the safe threshold to prevent burns. */
    }
    requirement def PowerContinuityRequirement {
        doc /* The system shall include battery backup to ensure uninterrupted therapy during AC power loss. */
    }

    part therapySystem {
        requirement efficacyReq : TherapyEfficacyRequirement;
        requirement rotationReq : FieldRotationRequirement;
        requirement safetyReq : SafetyRequirement {
            attribute :>> maxSafeTemp = 314.15 [K];
        }
        requirement powerReq : PowerContinuityRequirement;

        part powerModule : PowerModule {
            attribute :>> batteryCapacity = 4 [h];
            port :>> acInputPort;
            port :>> dcOutputPort;
        }
        part controlProcessor : ControlProcessor {
            attribute :>> therapyParams : TherapyParameters {
                :>> frequency = 200000 [Hz];
                :>> intensity = 1.0 [V];
                :>> rotationInterval = 1 [s];
                :>> maxSkinTemperature = 314.15 [K];
                :>> totalDuration = 18 [h];
            }
            port :>> powerPort;
            port :>> commandPort;
            port :>> temperaturePort;
            port :>> safetyPort;
            port :>> therapyControlPort;
        }
        part fieldGenerator : FieldGenerator {
            port :>> commandPort;
            port :>> anteriorArrayPort;
            port :>> posteriorArrayPort;
            port :>> leftArrayPort;
            port :>> rightArrayPort;
        }
        part anteriorArray : TransducerArray {
            attribute :>> position = ArrayPosition::anterior;
            port :>> signalPort;
            port :>> tempPort;
        }
        part posteriorArray : TransducerArray {
            attribute :>> position = ArrayPosition::posterior;
            port :>> signalPort;
            port :>> tempPort;
        }
        part leftArray : TransducerArray {
            attribute :>> position = ArrayPosition::left;
            port :>> signalPort;
            port :>> tempPort;
        }
        part rightArray : TransducerArray {
            attribute :>> position = ArrayPosition::right;
            port :>> signalPort;
            port :>> tempPort;
        }

        flow powerFlow of PowerStatus
            from powerModule.dcOutputPort.powerStatus to controlProcessor.powerPort.powerStatus;

        flow commandFlow of ElectricFieldCommand
            from controlProcessor.commandPort.fieldCommand to fieldGenerator.commandPort.fieldCommand;

        flow anteriorSignalFlow
            from fieldGenerator.anteriorArrayPort.anteriorSignal to anteriorArray.signalPort.driveSignal;
        flow posteriorSignalFlow
            from fieldGenerator.posteriorArrayPort.posteriorSignal to posteriorArray.signalPort.driveSignal;
        flow leftSignalFlow
            from fieldGenerator.leftArrayPort.leftSignal to leftArray.signalPort.driveSignal;
        flow rightSignalFlow
            from fieldGenerator.rightArrayPort.rightSignal to rightArray.signalPort.driveSignal;

        flow anteriorTempFlow of SensedTemperature
            from anteriorArray.tempPort.sensedTemp to controlProcessor.temperaturePort.sensedTemp;
        flow posteriorTempFlow of SensedTemperature
            from posteriorArray.tempPort.sensedTemp to controlProcessor.temperaturePort.sensedTemp;
        flow leftTempFlow of SensedTemperature
            from leftArray.tempPort.sensedTemp to controlProcessor.temperaturePort.sensedTemp;
        flow rightTempFlow of SensedTemperature
            from rightArray.tempPort.sensedTemp to controlProcessor.temperaturePort.sensedTemp;
    }
}
