package PhosphorThermometrySystem {

    import ScalarValues::*;

    // ===== Value Types with Units =====

    value type TemperatureC :> Real {
        :>> unit = 'degC';
        doc "Temperature in degrees Celsius";
    }

    value type TemperatureK :> Real {
        :>> unit = 'K';
        doc "Temperature in Kelvin";
    }

    value type Time_s :> Real {
        :>> unit = 's';
        doc "Time in seconds";
    }

    value type Wavelength_nm :> Real {
        :>> unit = 'nm';
        doc "Wavelength in nanometers";
    }

    value type Intensity_Wm2 :> Real {
        :>> unit = 'W/m^2';
        doc "Radiant intensity in watts per square meter";
    }

    value type Energy_J :> Real {
        :>> unit = 'J';
        doc "Energy in joules";
    }

    value type Voltage_V :> Real {
        :>> unit = 'V';
        doc "Electrical voltage in volts";
    }

    value type Frequency_Hz :> Real {
        :>> unit = 'Hz';
        doc "Frequency in hertz";
    }

    value type Length_m :> Real {
        :>> unit = 'm';
        doc "Length in meters";
    }

    // ===== Enumerations =====

    enumeration def CommandType {
        CALIBRATE;
        MEASURE;
        STANDBY;
    }

    enumeration def SystemStatus {
        OFFLINE;
        IDLE;
        CALIBRATING;
        READY;
        MEASURING;
        ERROR;
    }

    // ===== Item Definitions =====

    item def OpticalPulse {
        attribute wavelength : Wavelength_nm = 355.0;
        attribute pulseEnergy : Energy_J;
        attribute pulseDuration : Time_s;
        doc "A short high-energy pulse of ultraviolet light at 355 nm";
    }

    item def LuminescenceEmission {
        attribute peakWavelength : Wavelength_nm;
        attribute initialIntensity : Intensity_Wm2;
        attribute decayTime : Time_s;
        attribute coatingTemperature : TemperatureC;
        doc "Visible glow re-emitted by the phosphor coating after UV excitation";
    }

    item def IntensitySample {
        attribute timestamp : Time_s;
        attribute intensity : Intensity_Wm2;
        doc "A single sample of glow intensity at a specific time offset";
    }

    item def IntensityData {
        attribute samples : IntensitySample[0..*] ordered;
        attribute samplingRate : Frequency_Hz;
        attribute startTime : Time_s;
        attribute sampleCount : Integer;
        doc "Time series of intensity measurements from the photodetector";
    }

    item def DecayProfile {
        attribute decayTime : Time_s;
        attribute fitQuality : Real;
        attribute baseline : Intensity_Wm2;
        attribute amplitude : Intensity_Wm2;
        doc "Analyzed exponential decay characteristics of the phosphorescence signal";
    }

    item def TemperatureReading {
        attribute temperature : TemperatureC;
        attribute uncertainty : TemperatureC;
        attribute timestamp : Time_s;
        attribute decayTimeUsed : Time_s;
        attribute valid : Boolean;
        doc "Final calculated temperature measurement result with uncertainty";
    }

    item def CalibrationEntry {
        attribute referenceTemperature : TemperatureC;
        attribute measuredDecayTime : Time_s;
        attribute referenceUncertainty : TemperatureC;
        doc "A single calibration point mapping decay time to known temperature";
    }

    item def CalibrationTable {
        attribute entries : CalibrationEntry[2..*] ordered;
        attribute calibrationDate : Time_s;
        attribute validRange : TemperatureC;
        doc "Lookup table converting phosphorescence decay times to temperatures";
    }

    item def CommandMessage {
        attribute commandType : CommandType;
        attribute timestamp : Time_s;
        attribute priority : Integer = 1;
        doc "Command message to control system operation";
    }

    // ===== Port Definitions =====

    port def ExcitationOpticalPort {
        out item pulse : OpticalPulse;
        doc "Output port for UV excitation laser pulses";
    }

    port def PulseReceivePort {
        in item pulse : OpticalPulse;
        doc "Input port for receiving excitation pulses at the phosphor coating";
    }

    port def EmissionOutputPort {
        out item emission : LuminescenceEmission;
        doc "Output port for luminescence emission from the phosphor coating";
    }

    port def EmissionReceivePort {
        in item emission : LuminescenceEmission;
        doc "Input port for receiving luminescence emission at the photodetector";
    }

    port def IntensityDataOutputPort {
        out item data : IntensityData;
        doc "Output port for raw intensity time-series data from the photodetector";
    }

    port def IntensityDataInputPort {
        in item data : IntensityData;
        doc "Input port for intensity data to be processed by the signal processor";
    }

    port def DecayProfileOutputPort {
        out item profile : DecayProfile;
        doc "Output port for analyzed decay profile from the signal processor";
    }

    port def DecayProfileInputPort {
        in item profile : DecayProfile;
        doc "Input port for decay profile to be converted to temperature";
    }

    port def TemperatureResultPort {
        out item reading : TemperatureReading;
        doc "Output port for final temperature reading";
    }

    port def CommandPort {
        in item command : CommandMessage;
        doc "Input port for system commands";
    }

    // ===== Part Definitions =====

    part def ExcitationLaser {
        attribute wavelength : Wavelength_nm = 355.0;
        attribute pulseEnergy : Energy_J = 0.005;
        attribute pulseDuration : Time_s = 0.000005;
        attribute repetitionRate : Frequency_Hz = 1000.0;
        attribute beamDivergence : Real = 0.5;
        attribute ready : Boolean = false;

        port excitationOut : ExcitationOpticalPort;

        action def GeneratePulse {
            in laser : ExcitationLaser;
            out pulse : OpticalPulse;
            doc "Generates a short UV pulse at 355 nm with specified energy and duration";
        }

        exhibit action GeneratePulse {
            // Energize laser cavity and emit UV pulse through excitationOut
        }
    }

    part def PhosphorCoating {
        attribute material : String = "Dysprosium-doped YAG";
        attribute thickness : Length_m = 0.00005;
        attribute absorptionWavelength : Wavelength_nm = 355.0;
        attribute emissionPeakWavelength : Wavelength_nm = 585.0;
        attribute surfaceTemperature : TemperatureC;

        port pulseIn : PulseReceivePort;
        port emissionOut : EmissionOutputPort;

        action def AbsorbAndReemit {
            in pulse : OpticalPulse;
            in surfaceTemp : TemperatureC;
            out emission : LuminescenceEmission;
            doc "Absorbs UV energy from the laser pulse and re-emits visible luminescence whose decay rate depends on temperature";
        }

        exhibit action AbsorbAndReemit {
            // Absorb 355 nm photon energy, excite Dy3+ ions
            // Re-emit at ~585 nm with temperature-dependent exponential decay
        }
    }

    part def PhotoDetector {
        attribute sensitivity : Real = 0.85;
        attribute responseTime : Time_s = 0.000001;
        attribute samplingRate : Frequency_Hz = 1000000.0;
        attribute spectralRangeMin : Wavelength_nm = 400.0;
        attribute spectralRangeMax : Wavelength_nm = 700.0;
        attribute gain : Real = 1.0;
        attribute darkCurrent : Voltage_V = 0.001;

        port opticalIn : EmissionReceivePort;
        port dataOut : IntensityDataOutputPort;

        action def CaptureEmission {
            in emission : LuminescenceEmission;
            in detector : PhotoDetector;
            out data : IntensityData;
            doc "Records intensity of phosphorescence over time at the detector sampling rate, starting immediately after the laser pulse ends";
        }

        exhibit action CaptureEmission {
            // Convert incoming photons to electrical signal
            // Sample at 1 MHz to build intensity time series
            // Output IntensityData through dataOut
        }
    }

    part def SignalProcessor {
        attribute filterCutoff : Frequency_Hz = 500000.0;
        attribute noiseFloor : Intensity_Wm2 = 0.001;
        attribute minFitSamples : Integer = 100;
        attribute fitMethod : String = "Levenberg-Marquardt exponential";

        port dataIn : IntensityDataInputPort;
        port profileOut : DecayProfileOutputPort;

        action def FilterNoise {
            in rawData : IntensityData;
            in cutoff : Frequency_Hz;
            out filteredData : IntensityData;
            doc "Applies low-pass digital filtering to remove high-frequency noise from raw intensity data";
        }

        action def FitDecayCurve {
            in filteredData : IntensityData;
            out profile : DecayProfile;
            doc "Fits an exponential decay model I(t) = A * exp(-t/tau) + B to the filtered intensity data to extract the characteristic decay time tau";
        }

        action def ProcessSignal {
            in rawData : IntensityData;
            out profile : DecayProfile;

            perform FilterNoise {
                in rawData = rawData;
                in cutoff = filterCutoff;
            }
            then perform FitDecayCurve {
                out profile = profile;
            }
        }

        exhibit action ProcessSignal {
            // Receive raw intensity data from photodetector
            // Apply low-pass filter to suppress noise
            // Fit exponential decay curve to extract decay time
            // Output DecayProfile through profileOut
        }
    }

    part def TemperatureCalculator {
        attribute calibrationTable : CalibrationTable;
        attribute minTemperature : TemperatureC = 20.0;
        attribute maxTemperature : TemperatureC = 1500.0;
        attribute interpolationMethod : String = "cubic-spline";
        attribute lastReading : TemperatureReading;

        port profileIn : DecayProfileInputPort;
        port resultOut : TemperatureResultPort;

        action def LookupTemperature {
            in decayTime : Time_s;
            in table : CalibrationTable;
            out temperature : TemperatureC;
            out uncertainty : TemperatureC;
            doc "Interpolates the calibration table to convert a decay time into a temperature reading with associated uncertainty";
        }

        action def ConvertDecayToTemperature {
            in profile : DecayProfile;
            in table : CalibrationTable;
            out reading : TemperatureReading;
            doc "Uses the calibration table to convert the decay profile into a final temperature reading";
        }

        exhibit action ConvertDecayToTemperature {
            // Receive DecayProfile from signal processor
            // Interpolate calibration table using decay time
            // Compute uncertainty from fit quality and calibration spread
            // Output TemperatureReading through resultOut
        }
    }

    // ===== Main System Definition =====

    part def PhosphorThermometrySystem {
        attribute measurementCycleTime : Time_s = 0.001;
        attribute minOperatingTemp : TemperatureC = 20.0;
        attribute maxOperatingTemp : TemperatureC = 1500.0;
        attribute isCalibrated : Boolean = false;
        attribute measurementComplete : Boolean = false;
        attribute calibrationComplete : Boolean = false;
        attribute currentCommand : CommandType;
        attribute systemStatus : SystemStatus = SystemStatus::OFFLINE;
        attribute lastReading : TemperatureReading;
        attribute totalMeasurements : Integer = 0;

        port commandIn : CommandPort;
        port resultOut : TemperatureResultPort;

        part laser : ExcitationLaser;
        part coating : PhosphorCoating;
        part detector : PhotoDetector;
        part processor : SignalProcessor;
        part calculator : TemperatureCalculator;

        // Inter-component connections
        connect laser.excitationOut to coating.pulseIn;
        connect coating.emissionOut to detector.opticalIn;
        connect detector.dataOut to processor.dataIn;
        connect processor.profileOut to calculator.profileIn;
        connect calculator.resultOut to resultOut;

        // State machine defining the operational cycle
        state def SystemStateMachine {
            entry action {
                // Power on all subsystems and initialize
            }

            state idle {
                entry action {
                    // System is powered and waiting for a command
                }
                do action {
                    // Monitor command port for incoming commands
                }
            }

            state calibrating {
                entry action {
                    // Begin calibration sequence at known reference temperatures
                }
                do action {
                    // Fire laser at each reference temperature point
                    // Capture emission and measure decay time
                    // Populate calibration table entries
                }
                exit action {
                    // Finalize calibration table and mark system as calibrated
                }
            }

            state ready {
                entry action {
                    // System is calibrated and awaiting measurement trigger
                }
                do action {
                    // Monitor for MEASURE command
                }
            }

            state measuring {
                entry action {
                    // Fire excitation laser pulse at 355 nm
                }
                do action {
                    // Photodetector captures luminescence emission
                    // Signal processor filters and fits decay curve
                    // Temperature calculator converts decay time to temperature
                }
                exit action {
                    // Output temperature reading through result port
                }
            }

            state error {
                entry action {
                    // Log error condition and halt active measurement
                }
                do action {
                    // Await diagnostic reset command
                }
            }

            transition from idle to calibrating
                when currentCommand == CommandType::CALIBRATE;

            transition from calibrating to ready
                when calibrationComplete == true;

            transition from calibrating to error
                when calibrationComplete == false;

            transition from ready to measuring
                when currentCommand == CommandType::MEASURE;

            transition from measuring to ready
                when measurementComplete == true;

            transition from measuring to error
                when measurementComplete == false;

            transition from ready to idle
                when currentCommand == CommandType::STANDBY;

            transition from error to idle
                when currentCommand == CommandType::STANDBY;
        }

        exhibit state SystemStateMachine;
    }

    // ===== Requirements =====

    requirement def MeasurementRangeRequirement {
        doc "The system shall measure surface temperatures from 20 degC to 1500 degC";
        subject system : PhosphorThermometrySystem;
        attribute minTemp : TemperatureC = 20.0;
        attribute maxTemp : TemperatureC = 1500.0;

        require {
            system.minOperatingTemp <= minTemp and
            system.maxOperatingTemp >= maxTemp
        }
    }

    requirement def MeasurementCycleTimeRequirement {
        doc "The system shall complete a full measurement cycle within 1 millisecond";
        subject system : PhosphorThermometrySystem;
        attribute maxCycleTime : Time_s = 0.001;

        require {
            system.measurementCycleTime <= maxCycleTime
        }
    }

    requirement def ExcitationWavelengthRequirement {
        doc "The excitation laser shall emit ultraviolet light at 355 nm wavelength";
        subject laser : ExcitationLaser;
        attribute requiredWavelength : Wavelength_nm = 355.0;

        require {
            laser.wavelength == requiredWavelength
        }
    }

    requirement def TemperatureAccuracyRequirement {
        doc "The system shall provide temperature readings with measurement uncertainty no greater than 1 degC across the full operating range";
        subject system : PhosphorThermometrySystem;
        attribute maxUncertainty : TemperatureC = 1.0;

        require {
            // All temperature readings must have uncertainty <= 1 degC
            true
        }
    }

    requirement def NonContactMeasurementRequirement {
        doc "The system shall measure temperature without physical contact with the target surface using optical excitation and detection";
        subject system : PhosphorThermometrySystem;

        require {
            // Measurement performed via optical path only
            true
        }
    }

    requirement def CalibrationRequirement {
        doc "The system shall support calibration at known reference temperatures to ensure measurement accuracy before operational use";
        subject system : PhosphorThermometrySystem;

        require {
            // System must enter calibrating state and populate calibration table
            true
        }
    }

    requirement def DetectorSamplingRateRequirement {
        doc "The photodetector shall capture luminescence emission with a sampling rate of at least 1 MHz to resolve decay profiles";
        subject detector : PhotoDetector;
        attribute minSamplingRate : Frequency_Hz = 1000000.0;

        require {
            detector.samplingRate >= minSamplingRate
        }
    }

    requirement def DetectorSpectralRangeRequirement {
        doc "The photodetector shall be sensitive to visible light in the range of 400 nm to 700 nm to capture phosphor emission";
        subject detector : PhotoDetector;
        attribute minWavelength : Wavelength_nm = 400.0;
        attribute maxWavelength : Wavelength_nm = 700.0;

        require {
            detector.spectralRangeMin <= minWavelength and
            detector.spectralRangeMax >= maxWavelength
        }
    }

    requirement def PhosphorMaterialRequirement {
        doc "The phosphor coating shall use Dysprosium-doped YAG material with temperature-dependent luminescence decay";
        subject coating : PhosphorCoating;
        attribute requiredMaterial : String = "Dysprosium-doped YAG";

        require {
            coating.material == requiredMaterial
        }
    }

    requirement def RapidRepeatableMeasurementRequirement {
        doc "The system shall support rapid and repeated temperature monitoring with a laser repetition rate of at least 1000 Hz";
        subject laser : ExcitationLaser;
        attribute minRepetitionRate : Frequency_Hz = 1000.0;

        require {
            laser.repetitionRate >= minRepetitionRate
        }
    }

    // ===== Requirement Satisfaction =====

    satisfaction def RangeSatisfaction {
        satisfy MeasurementRangeRequirement by system : PhosphorThermometrySystem;
    }

    satisfaction def CycleTimeSatisfaction {
        satisfy MeasurementCycleTimeRequirement by system : PhosphorThermometrySystem;
    }

    satisfaction def WavelengthSatisfaction {
        satisfy ExcitationWavelengthRequirement by laser : ExcitationLaser;
    }

    satisfaction def AccuracySatisfaction {
        satisfy TemperatureAccuracyRequirement by system : PhosphorThermometrySystem;
    }

    satisfaction def NonContactSatisfaction {
        satisfy NonContactMeasurementRequirement by system : PhosphorThermometrySystem;
    }

    satisfaction def CalibrationSatisfaction {
        satisfy CalibrationRequirement by system : PhosphorThermometrySystem;
    }

    satisfaction def DetectorRateSatisfaction {
        satisfy DetectorSamplingRateRequirement by detector : PhotoDetector;
    }

    satisfaction def DetectorRangeSatisfaction {
        satisfy DetectorSpectralRangeRequirement by detector : PhotoDetector;
    }

    satisfaction def PhosphorMaterialSatisfaction {
        satisfy PhosphorMaterialRequirement by coating : PhosphorCoating;
    }

    satisfaction def RepetitionRateSatisfaction {
        satisfy RapidRepeatableMeasurementRequirement by laser : ExcitationLaser;
    }
}
