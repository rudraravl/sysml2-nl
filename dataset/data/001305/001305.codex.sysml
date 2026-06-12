package VariometerSystemModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure {
        :>> unit = Pa;
        :>> quantityKind = pressure;
    }

    attribute def Altitude {
        :>> unit = m;
        :>> quantityKind = length;
    }

    attribute def VerticalSpeed {
        :>> unit = m / s;
        :>> quantityKind = speed;
    }

    attribute def Temperature {
        :>> unit = K;
        :>> quantityKind = thermodynamicTemperature;
    }

    attribute def TimeDuration {
        :>> unit = s;
        :>> quantityKind = time;
    }

    attribute def Voltage {
        :>> unit = V;
        :>> quantityKind = electricPotential;
    }

    attribute def SoundPressureLevel {
        :>> unit = dB;
    }

    item def StaticPressureSignal {
        attribute pressure : Pressure;
        attribute sampleTime : TimeDuration;
    }

    item def AltitudeEstimate {
        attribute altitude : Altitude;
        attribute confidence : Real;
        attribute sampleTime : TimeDuration;
    }

    item def VerticalSpeedEstimate {
        attribute verticalSpeed : VerticalSpeed;
        attribute filteredVerticalSpeed : VerticalSpeed;
        attribute sampleTime : TimeDuration;
    }

    item def PilotCue {
        attribute climbToneFrequency : Real;
        attribute sinkAlarmActive : Boolean;
        attribute displayedVerticalSpeed : VerticalSpeed;
        attribute displayedAltitude : Altitude;
    }

    item def PowerInput {
        attribute supplyVoltage : Voltage;
        attribute currentLimit : Real;
    }

    port def StaticPressurePort {
        in item staticPressure : StaticPressureSignal;
    }

    port def PowerPort {
        in item power : PowerInput;
    }

    port def DisplayPort {
        out item cue : PilotCue;
    }

    port def AudioPort {
        out item cue : PilotCue;
    }

    port def DataPort {
        out item verticalSpeed : VerticalSpeedEstimate;
        out item altitude : AltitudeEstimate;
    }

    part def Variometer {
        attribute samplePeriod : TimeDuration = 0.1 [s];
        attribute climbThreshold : VerticalSpeed = 0.2 [m / s];
        attribute sinkThreshold : VerticalSpeed = -1.5 [m / s];
        attribute maximumIndicatedClimb : VerticalSpeed = 10.0 [m / s];
        attribute maximumIndicatedSink : VerticalSpeed = -10.0 [m / s];

        port staticPressurePort : StaticPressurePort;
        port powerPort : PowerPort;
        port displayPort : DisplayPort;
        port audioPort : AudioPort;
        port dataPort : DataPort;

        part pressureSensor : BarometricPressureSensor;
        part altitudeComputer : AltitudeComputer;
        part verticalSpeedComputer : VerticalSpeedComputer;
        part cueGenerator : PilotCueGenerator;
        part display : FlightDisplay;
        part audioAnnunciator : AudioAnnunciator;
        part powerConditioner : PowerConditioner;

        connect staticPressurePort.staticPressure to pressureSensor.rawStaticPressure;
        connect powerPort.power to powerConditioner.unconditionedPower;
        connect powerConditioner.conditionedPower to pressureSensor.sensorPower;
        connect powerConditioner.conditionedPower to altitudeComputer.computerPower;
        connect powerConditioner.conditionedPower to verticalSpeedComputer.computerPower;
        connect powerConditioner.conditionedPower to cueGenerator.computerPower;
        connect pressureSensor.measuredStaticPressure to altitudeComputer.pressureInput;
        connect altitudeComputer.altitudeOutput to verticalSpeedComputer.altitudeInput;
        connect altitudeComputer.altitudeOutput to cueGenerator.altitudeInput;
        connect verticalSpeedComputer.verticalSpeedOutput to cueGenerator.verticalSpeedInput;
        connect cueGenerator.pilotCueOutput to display.cueInput;
        connect cueGenerator.pilotCueOutput to audioAnnunciator.cueInput;
        connect display.cueOutput to displayPort.cue;
        connect audioAnnunciator.cueOutput to audioPort.cue;
        connect verticalSpeedComputer.verticalSpeedOutput to dataPort.verticalSpeed;
        connect altitudeComputer.altitudeOutput to dataPort.altitude;

        perform action computeAndAnnunciateVerticalSpeed;
    }

    part def BarometricPressureSensor {
        port rawStaticPressure {
            in item pressureSignal : StaticPressureSignal;
        }

        port sensorPower {
            in item power : PowerInput;
        }

        port measuredStaticPressure {
            out item pressureSignal : StaticPressureSignal;
        }

        attribute measurementRangeLow : Pressure = 30000 [Pa];
        attribute measurementRangeHigh : Pressure = 110000 [Pa];
        attribute pressureAccuracy : Pressure = 1.5 [Pa];

        action filterPressure {
            in item raw : StaticPressureSignal;
            out item filtered : StaticPressureSignal;
        }
    }

    part def AltitudeComputer {
        port pressureInput {
            in item pressureSignal : StaticPressureSignal;
        }

        port computerPower {
            in item power : PowerInput;
        }

        port altitudeOutput {
            out item altitude : AltitudeEstimate;
        }

        attribute referenceSeaLevelPressure : Pressure = 101325 [Pa];
        attribute temperatureLapseRate : Real = 0.0065;
        attribute updatePeriod : TimeDuration = 0.1 [s];

        action estimateAltitudeFromPressure {
            in item pressureSignal : StaticPressureSignal;
            out item altitude : AltitudeEstimate;
        }
    }

    part def VerticalSpeedComputer {
        port altitudeInput {
            in item altitude : AltitudeEstimate;
        }

        port computerPower {
            in item power : PowerInput;
        }

        port verticalSpeedOutput {
            out item verticalSpeed : VerticalSpeedEstimate;
        }

        attribute derivativeWindow : TimeDuration = 1.0 [s];
        attribute filterTimeConstant : TimeDuration = 0.7 [s];
        attribute resolution : VerticalSpeed = 0.05 [m / s];

        action differentiateAltitude {
            in item previousAltitude : AltitudeEstimate;
            in item currentAltitude : AltitudeEstimate;
            out item rawVerticalSpeed : VerticalSpeedEstimate;
        }

        action lowPassFilterVerticalSpeed {
            in item rawVerticalSpeed : VerticalSpeedEstimate;
            out item filteredVerticalSpeed : VerticalSpeedEstimate;
        }
    }

    part def PilotCueGenerator {
        port altitudeInput {
            in item altitude : AltitudeEstimate;
        }

        port verticalSpeedInput {
            in item verticalSpeed : VerticalSpeedEstimate;
        }

        port computerPower {
            in item power : PowerInput;
        }

        port pilotCueOutput {
            out item cue : PilotCue;
        }

        attribute noClimbBand : VerticalSpeed = 0.1 [m / s];
        attribute positiveCueStart : VerticalSpeed = 0.2 [m / s];
        attribute strongClimbCue : VerticalSpeed = 3.0 [m / s];
        attribute sinkWarningThreshold : VerticalSpeed = -1.5 [m / s];
        attribute minimumToneFrequency : Real = 300.0;
        attribute maximumToneFrequency : Real = 1800.0;

        state def CueGenerationStateMachine {
            state off;
            state initializing;
            state silentCruise;
            state climbing;
            state sinking;
            state fault;

            transition first off then initializing;
            transition initializing then silentCruise
                accept after 2.0 [s];

            transition silentCruise then climbing
                if verticalSpeedInput.verticalSpeed.filteredVerticalSpeed > positiveCueStart;

            transition climbing then silentCruise
                if verticalSpeedInput.verticalSpeed.filteredVerticalSpeed <= noClimbBand;

            transition silentCruise then sinking
                if verticalSpeedInput.verticalSpeed.filteredVerticalSpeed < sinkWarningThreshold;

            transition sinking then silentCruise
                if verticalSpeedInput.verticalSpeed.filteredVerticalSpeed >= noClimbBand;

            transition climbing then fault
                if altitudeInput.altitude.confidence < 0.5;

            transition sinking then fault
                if altitudeInput.altitude.confidence < 0.5;

            transition silentCruise then fault
                if altitudeInput.altitude.confidence < 0.5;
        }

        action generateCue {
            in item altitude : AltitudeEstimate;
            in item verticalSpeed : VerticalSpeedEstimate;
            out item cue : PilotCue;
        }
    }

    part def FlightDisplay {
        port cueInput {
            in item cue : PilotCue;
        }

        port cueOutput {
            out item cue : PilotCue;
        }

        attribute refreshPeriod : TimeDuration = 0.2 [s];
        attribute verticalSpeedScaleMinimum : VerticalSpeed = -10.0 [m / s];
        attribute verticalSpeedScaleMaximum : VerticalSpeed = 10.0 [m / s];

        action renderVerticalSpeedAndAltitude {
            in item cue : PilotCue;
            out item displayedCue : PilotCue;
        }
    }

    part def AudioAnnunciator {
        port cueInput {
            in item cue : PilotCue;
        }

        port cueOutput {
            out item cue : PilotCue;
        }

        attribute maximumSoundLevel : SoundPressureLevel = 85 [dB];
        attribute mutedBelowClimb : VerticalSpeed = 0.1 [m / s];

        action produceClimbOrSinkAudio {
            in item cue : PilotCue;
            out item audibleCue : PilotCue;
        }
    }

    part def PowerConditioner {
        port unconditionedPower {
            in item power : PowerInput;
        }

        port conditionedPower {
            out item power : PowerInput;
        }

        attribute nominalInputVoltage : Voltage = 12 [V];
        attribute minimumInputVoltage : Voltage = 9 [V];
        attribute regulatedOutputVoltage : Voltage = 5 [V];

        action regulatePower {
            in item inputPower : PowerInput;
            out item outputPower : PowerInput;
        }
    }

    action def ComputeAndAnnunciateVerticalSpeed {
        in item pressure : StaticPressureSignal;
        out item cue : PilotCue;

        action sensePressure : BarometricPressureSensor::filterPressure;
        action computeAltitude : AltitudeComputer::estimateAltitudeFromPressure;
        action computeVerticalSpeed : VerticalSpeedComputer::differentiateAltitude;
        action filterVerticalSpeed : VerticalSpeedComputer::lowPassFilterVerticalSpeed;
        action generatePilotCue : PilotCueGenerator::generateCue;

        flow sensePressure.filtered to computeAltitude.pressureSignal;
        flow computeAltitude.altitude to computeVerticalSpeed.currentAltitude;
        flow computeVerticalSpeed.rawVerticalSpeed to filterVerticalSpeed.rawVerticalSpeed;
        flow filterVerticalSpeed.filteredVerticalSpeed to generatePilotCue.verticalSpeed;
        flow computeAltitude.altitude to generatePilotCue.altitude;
        flow generatePilotCue.cue to cue;
    }

    requirement def PrimaryVariometerFunction {
        doc
        /* The variometer shall determine aircraft vertical speed from changes in atmospheric static pressure and present a high-level climb, sink, or steady-flight cue to the pilot. */

        subject variometer : Variometer;

        require constraint {
            variometer.verticalSpeedComputer.resolution <= 0.05 [m / s]
        }

        require constraint {
            variometer.samplePeriod <= 0.2 [s]
        }
    }

    requirement def PressureBasedAltitudeRequirement {
        doc
        /* The variometer shall estimate altitude using barometric static pressure referenced to standard sea-level pressure. */

        subject altitudeComputer : AltitudeComputer;

        require constraint {
            altitudeComputer.referenceSeaLevelPressure == 101325 [Pa]
        }
    }

    requirement def VerticalSpeedFilteringRequirement {
        doc
        /* The variometer shall filter short-duration pressure disturbances before generating pilot cues. */

        subject verticalSpeedComputer : VerticalSpeedComputer;

        require constraint {
            verticalSpeedComputer.filterTimeConstant >= 0.5 [s] and
            verticalSpeedComputer.filterTimeConstant <= 1.5 [s]
        }
    }

    requirement def PilotCueRequirement {
        doc
        /* The variometer shall provide visual and audio cues indicating climb, sink, and approximately steady flight. */

        subject cueGenerator : PilotCueGenerator;

        require constraint {
            cueGenerator.positiveCueStart > cueGenerator.noClimbBand
        }

        require constraint {
            cueGenerator.sinkWarningThreshold < 0 [m / s]
        }
    }

    requirement def PowerRequirement {
        doc
        /* The variometer shall operate from aircraft low-voltage electrical power and regulate internal electronics power. */

        subject powerConditioner : PowerConditioner;

        require constraint {
            powerConditioner.minimumInputVoltage <= powerConditioner.nominalInputVoltage
        }

        require constraint {
            powerConditioner.regulatedOutputVoltage == 5 [V]
        }
    }

    satisfy PrimaryVariometerFunction by Variometer;
    satisfy PressureBasedAltitudeRequirement by AltitudeComputer;
    satisfy VerticalSpeedFilteringRequirement by VerticalSpeedComputer;
    satisfy PilotCueRequirement by PilotCueGenerator;
    satisfy PowerRequirement by PowerConditioner;

    part variometerSystem : Variometer {
        :>> samplePeriod = 0.1 [s];
        :>> climbThreshold = 0.2 [m / s];
        :>> sinkThreshold = -1.5 [m / s];
    }

}