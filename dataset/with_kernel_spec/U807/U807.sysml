package PhosphorThermometrySystem {
    private import ScalarValues::Real;
    private import ScalarValues::Boolean;
    private import ScalarValues::Integer;
    private import SI::*;
    private import ISQ::*;

    item def LaserPulse {
        attribute wavelengthNm: Real = 355;
        attribute energy: Real;
        attribute duration: Real;
    }

    item def LuminescenceEmission {
        attribute intensity: Real;
        attribute time: Real;
    }

    item def IntensityData {
        attribute values: Real[*];
        attribute timestamps: Real[*];
    }

    item def DecayProfile {
        attribute decayTime: Real;
        attribute fitQuality: Real;
    }

    item def TemperatureReading {
        attribute temperature: Real;
    }

    item def CalibrateCommand;
    item def MeasureCommand;
    item def TriggerSignal;

    action def GenerateLaserPulse {
        out laserPulse: LaserPulse;
    }
    action def EmitLuminescence {
        in laserPulse: LaserPulse;
        out emission: LuminescenceEmission;
    }
    action def CaptureEmission {
        in emission: LuminescenceEmission;
        out rawData: IntensityData;
    }
    action def AnalyzeSignal {
        in rawData: IntensityData;
        out decayProfile: DecayProfile;
    }
    action def CalculateTemperature {
        in decayProfile: DecayProfile;
        out temperatureReading: TemperatureReading;
    }
    action def MeasurementSequence {
        in trigger: TriggerSignal;
        out reading: TemperatureReading;

        action fireLaser: GenerateLaserPulse;
        action emitGlow: EmitLuminescence;
        action captureGlow: CaptureEmission;
        action processSignal: AnalyzeSignal;
        action calculateTemp: CalculateTemperature;

        flow fireLaser.laserPulse to emitGlow.laserPulse;
        flow emitGlow.emission to captureGlow.emission;
        flow captureGlow.rawData to processSignal.rawData;
        flow processSignal.decayProfile to calculateTemp.decayProfile;

        first start then fireLaser;
        first fireLaser then emitGlow;
        first emitGlow then captureGlow;
        first captureGlow then processSignal;
        first processSignal then calculateTemp;
        first calculateTemp then done;
    }

    part def ExcitationLaser {
        out item laserPulse: LaserPulse;
        action generatePulse: GenerateLaserPulse {
            out laserPulse = laserPulse;
        }
    }

    part def PhosphorCoating {
        in item laserPulse: LaserPulse;
        out item emission: LuminescenceEmission;
        attribute temperature: Real;
        action emitGlow: EmitLuminescence {
            in laserPulse = laserPulse;
            out emission = emission;
        }
    }

    part def PhotoDetector {
        in item emission: LuminescenceEmission;
        out item rawData: IntensityData;
        action captureGlow: CaptureEmission {
            in emission = emission;
            out rawData = rawData;
        }
    }

    part def SignalProcessor {
        in item rawData: IntensityData;
        out item decayProfile: DecayProfile;
        action analyzeSignal: AnalyzeSignal {
            in rawData = rawData;
            out decayProfile = decayProfile;
        }
    }

    part def TemperatureCalculator {
        in item decayProfile: DecayProfile;
        out item temperatureReading: TemperatureReading;
        attribute calibrationTable: Real[*];
        action calculateTemp: CalculateTemperature {
            in decayProfile = decayProfile;
            out temperatureReading = temperatureReading;
        }
    }

    state machine def SystemControl {
        state idle {
            transition to calibrating;
            transition to measuring;
        }
        state calibrating {
            transition to idle;
        }
        state measuring {
            transition to idle;
        }
    }

    part def ThermometrySystem {
        in item calibrateCmd: CalibrateCommand;
        in item measureCmd: MeasureCommand;
        in item trigger: TriggerSignal;
        out item temperatureReading: TemperatureReading;

        part excitationLaser: ExcitationLaser;
        part phosphorCoating: PhosphorCoating;
        part photoDetector: PhotoDetector;
        part signalProcessor: SignalProcessor;
        part temperatureCalculator: TemperatureCalculator;

        flow excitationLaser.laserPulse to phosphorCoating.laserPulse;
        flow phosphorCoating.emission to photoDetector.emission;
        flow photoDetector.rawData to signalProcessor.rawData;
        flow signalProcessor.decayProfile to temperatureCalculator.decayProfile;
        bind temperatureCalculator.temperatureReading = temperatureReading;

        action measurement: MeasurementSequence {
            in trigger = trigger;
            out reading = temperatureReading;
        }

        state machine SystemController : SystemControl;
    }

    requirement def WavelengthRequirement {
        doc /* The excitation laser shall emit a pulse at 355 nm. */
    }

    requirement def TemperatureRangeRequirement {
        doc /* The system shall measure temperatures from 20 C to 1500 C. */
    }

    requirement def CycleTimeRequirement {
        doc /* The measurement cycle shall complete within 1 ms. */
    }
}
