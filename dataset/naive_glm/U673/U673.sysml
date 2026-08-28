package FBG_Sensing_System {

    import ScalarValues::*;
    import ISQ::*;
    import ISQSpaceTime::*;
    import ISQThermodynamics::*;

    // ---------- Value Types with Units ----------
    value type Wavelength :> Real {
        unit "nm";
    }
    value type WavelengthShift :> Real {
        unit "pm";
    }
    value type OpticalPower :> Real {
        unit "mW";
    }
    value type Strain :> Real {
        unit "microstrain";
    }
    value type Temperature :> Real {
        unit "degC";
    }
    value type RefractiveIndex :> Real {
        unit "1";
    }
    value type GratingPeriod :> Real {
        unit "nm";
    }
    value type Duration :> Real {
        unit "ms";
    }
    value type Isolation :> Real {
        unit "dB";
    }
    value type InsertionLoss :> Real {
        unit "dB";
    }

    // ---------- Item Definitions ----------
    item def OpticalSignal {
        attribute wavelength : Wavelength;
        attribute power : OpticalPower;
    }

    item def BroadbandSignal :> OpticalSignal {
        attribute minWavelength : Wavelength;
        attribute maxWavelength : Wavelength;
    }

    item def ReflectedSignal :> OpticalSignal {
        attribute braggWavelength : Wavelength;
    }

    item def TransmittedSignal :> OpticalSignal;

    item def WavelengthMeasurement {
        attribute measuredWavelength : Wavelength;
        attribute timestamp : Duration;
    }

    item def PhysicalMeasurement {
        attribute strain : Strain;
        attribute temperature : Temperature;
        attribute confidence : Real;
    }

    // ---------- Port Definitions ----------
    port def OpticalPort {
        out item outgoing : OpticalSignal;
        in item incoming : OpticalSignal;
    }

    port def MeasurementPort {
        out item measurement : WavelengthMeasurement;
    }

    port def DataPort {
        in item wavelengthData : WavelengthMeasurement;
        out item physicalData : PhysicalMeasurement;
    }

    // ---------- Broadband Light Source ----------
    part def BroadbandLightSource {
        attribute outputPower : OpticalPower = 10.0;
        attribute centerWavelength : Wavelength = 1550.0;
        attribute spectralBandwidth : Wavelength = 100.0;
        attribute minWavelength : Wavelength = 1500.0;
        attribute maxWavelength : Wavelength = 1600.0;

        port out lightOutput : OpticalPort;

        action def EmitBroadbandLight {
            out signal : BroadbandSignal;
        }

        state def EmissionBehavior {
            entry; then powered;
            state powered {
                entry do EmitBroadbandLight {
                    out signal = BroadbandSignal {
                        wavelength = centerWavelength;
                        power = outputPower;
                        minWavelength = minWavelength;
                        maxWavelength = maxWavelength;
                    };
                }
            }
            transition from powered to powered
                when outputPower > 0.0;
        }

        exhibit EmissionBehavior;
    }

    // ---------- Optical Circulator ----------
    part def OpticalCirculator {
        attribute isolation : Isolation = 40.0;
        attribute insertionLoss : InsertionLoss = 0.5;
        attribute operatingBandwidth : Wavelength = 100.0;

        port in sourceInput : OpticalPort;
        port out sensorOutput : OpticalPort;
        port in sensorReturn : OpticalPort;
        port out analyzerOutput : OpticalPort;

        action def RouteForward {
            in broadbandIn : BroadbandSignal;
            out toSensor : BroadbandSignal;
        }

        action def RouteReturn {
            in reflectedIn : ReflectedSignal;
            out toAnalyzer : ReflectedSignal;
        }

        action def Circulate {
            in fromSource : BroadbandSignal;
            out toSensor : BroadbandSignal;
            in fromSensor : ReflectedSignal;
            out toAnalyzer : ReflectedSignal;

            do RouteForward {
                in broadbandIn = fromSource;
                out toSensor = toSensor;
            }
            do RouteReturn {
                in reflectedIn = fromSensor;
                out toAnalyzer = toAnalyzer;
            }
        }

        state def RoutingBehavior {
            entry; then idle;
            state idle;
            accept from sourceInput;
            then routingForward;
            state routingForward {
                do RouteForward;
            }
            transition from routingForward to idle;
            accept from sensorReturn;
            then routingReturn;
            state routingReturn {
                do RouteReturn;
            }
            transition from routingReturn to idle;
        }

        exhibit RoutingBehavior;
    }

    // ---------- Fiber Bragg Grating Sensor ----------
    part def FiberBraggGrating {
        attribute effectiveRefractiveIndex : RefractiveIndex = 0.5;
        attribute gratingPeriod : GratingPeriod = 535.0;
        attribute baseBraggWavelength : Wavelength = 1550.0;
        attribute strainSensitivity : Real = 1.2; // pm/microstrain
        attribute temperatureSensitivity : Real = 10.0; // pm/degC
        attribute currentStrain : Strain = 0.0;
        attribute currentTemperature : Temperature = 25.0;
        attribute minOperatingTemp : Temperature = -40.0;
        attribute maxOperatingTemp : Temperature = 120.0;

        port in lightInput : OpticalPort;
        port out reflectedOutput : OpticalPort;
        port out transmittedOutput : OpticalPort;

        action def ComputeBraggWavelength {
            in strain : Strain;
            in temperature : Temperature;
            out braggWavelength : Wavelength;

            // λ_B = 2 * n_eff * Λ + Δλ_strain + Δλ_temp
        }

        action def ReflectLight {
            in incoming : BroadbandSignal;
            out reflected : ReflectedSignal;
            out transmitted : TransmittedSignal;

            do ComputeBraggWavelength {
                in strain = currentStrain;
                in temperature = currentTemperature;
                out braggWavelength = reflected.braggWavelength;
            }
        }

        action def UpdatePhysicalConditions {
            in newStrain : Strain;
            in newTemperature : Temperature;
        }

        state def SensingBehavior {
            entry; then idle;
            state idle;
            accept from lightInput;
            then reflecting;
            state reflecting {
                do ReflectLight;
            }
            transition from reflecting to idle;
        }

        exhibit SensingBehavior;
    }

    // ---------- Optical Spectrum Analyzer ----------
    part def OpticalSpectrumAnalyzer {
        attribute resolution : Wavelength = 0.001;
        attribute measurementRange : Wavelength = 80.0;
        attribute accuracy : Wavelength = 0.0005;
        attribute samplingInterval : Duration = 10.0;

        port in lightInput : OpticalPort;
        port out dataOutput : MeasurementPort;

        action def MeasureWavelength {
            in reflectedSignal : ReflectedSignal;
            out measurement : WavelengthMeasurement;
        }

        action def Calibrate {
            in reference : Wavelength;
        }

        state def AnalysisBehavior {
            entry; then ready;
            state ready;
            accept from lightInput;
            then measuring;
            state measuring {
                do MeasureWavelength;
            }
            transition from measuring to ready;
        }

        exhibit AnalysisBehavior;
    }

    // ---------- Signal Processing Unit ----------
    part def SignalProcessingUnit {
        attribute referenceWavelength : Wavelength = 1550.0;
        attribute strainCoefficient : Real = 0.833; // microstrain/pm
        attribute temperatureCoefficient : Real = 0.1; // degC/pm
        attribute processingLatency : Duration = 5.0;
        attribute calibrationOffset : WavelengthShift = 0.0;

        port in dataInput : DataPort;
        port out resultOutput : DataPort;

        action def ComputeWavelengthShift {
            in measured : Wavelength;
            in reference : Wavelength;
            out shift : WavelengthShift;
        }

        action def ComputeStrain {
            in wavelengthShift : WavelengthShift;
            out strain : Strain;
        }

        action def ComputeTemperature {
            in wavelengthShift : WavelengthShift;
            out temperature : Temperature;
        }

        action def ProcessMeasurement {
            in measurement : WavelengthMeasurement;
            out physicalResult : PhysicalMeasurement;

            do ComputeWavelengthShift {
                in measured = measurement.measuredWavelength;
                in reference = referenceWavelength;
            }
            do ComputeStrain;
            do ComputeTemperature;
        }

        state def ProcessingBehavior {
            entry; then waiting;
            state waiting;
            accept from dataInput;
            then processing;
            state processing {
                do ProcessMeasurement;
            }
            transition from processing to waiting;
        }

        exhibit ProcessingBehavior;
    }

    // ---------- Top-Level FBG Sensing System ----------
    part def FBGSensingSystem {
        attribute systemStatus : String;
        attribute measurementCycleTime : Duration = 50.0;
        attribute strainAccuracy : Strain = 1.0;
        attribute temperatureAccuracy : Temperature = 0.5;

        part lightSource : BroadbandLightSource;
        part circulator : OpticalCirculator;
        part fbgSensor : FiberBraggGrating;
        part spectrumAnalyzer : OpticalSpectrumAnalyzer;
        part processingUnit : SignalProcessingUnit;

        connection lightSourceToCirculator
            connect lightSource.lightOutput to circulator.sourceInput;
        connection circulatorToSensor
            connect circulator.sensorOutput to fbgSensor.lightInput;
        connection sensorToCirculator
            connect fbgSensor.reflectedOutput to circulator.sensorReturn;
        connection circulatorToAnalyzer
            connect circulator.analyzerOutput to spectrumAnalyzer.lightInput;
        connection analyzerToProcessor
            connect spectrumAnalyzer.dataOutput to processingUnit.dataInput;

        action def SystemOperation {
            in broadband : BroadbandSignal;
            out measurement : PhysicalMeasurement;

            // Sequential sensing pipeline
        }

        state def SystemStateBehavior {
            entry; then initializing;
            state initializing {
                entry assign systemStatus = "Initializing";
            }
            transition from initializing to operational
                when lightSource.outputPower > 0.0;
            state operational {
                entry assign systemStatus = "Operational";
            }
            transition from operational to faulted
                when spectrumAnalyzer.accuracy > 0.01;
            state faulted {
                entry assign systemStatus = "Faulted";
            }
        }

        exhibit SystemStateBehavior;
    }

    // ---------- Requirements ----------
    requirement def MeasurementAccuracyRequirement {
        subject sensingSystem : FBGSensingSystem;
        objective {
            doc /* The system shall measure strain with accuracy better than 1 microstrain. */
            assert sensingSystem.strainAccuracy <= 1.0;
        }
    }

    requirement def WavelengthResolutionRequirement {
        subject analyzer : OpticalSpectrumAnalyzer;
        objective {
            doc /* The OSA shall resolve wavelength shifts of 1 pm or smaller. */
            assert analyzer.resolution <= 0.001;
        }
    }

    requirement def SignalIsolationRequirement {
        subject circulator : OpticalCirculator;
        objective {
            doc /* The circulator shall provide at least 30 dB isolation between ports. */
            assert circulator.isolation >= 30.0;
        }
    }

    requirement def SystemResponseTimeRequirement {
        subject sensingSystem : FBGSensingSystem;
        objective {
            doc /* The system shall complete a measurement cycle within 100 ms. */
            assert sensingSystem.measurementCycleTime <= 100.0;
        }
    }

    requirement def TemperatureRangeRequirement {
        subject fbg : FiberBraggGrating;
        objective {
            doc /* The FBG shall operate over -40 to +120 degC. */
            assert fbg.minOperatingTemp <= -40.0;
            assert fbg.maxOperatingTemp >= 120.0;
        }
    }

    requirement def BroadbandSourceRequirement {
        subject source : BroadbandLightSource;
        objective {
            doc /* The light source shall cover the 1500-1600 nm band with at least 5 mW output. */
            assert source.minWavelength <= 1500.0;
            assert source.maxWavelength >= 1600.0;
            assert source.outputPower >= 5.0;
        }
    }

    requirement def BraggWavelengthRequirement {
        subject fbg : FiberBraggGrating;
        objective {
            doc /* The FBG shall reflect a base Bragg wavelength near 1550 nm. */
            assert fbg.baseBraggWavelength >= 1540.0;
            assert fbg.baseBraggWavelength <= 1560.0;
        }
    }

    // ---------- Requirement Satisfaction ----------
    part sensingSystemInstance : FBGSensingSystem {
        satisfy MeasurementAccuracyRequirement;
        satisfy SystemResponseTimeRequirement;
    }

    part analyzerInstance : OpticalSpectrumAnalyzer {
        satisfy WavelengthResolutionRequirement;
    }

    part circulatorInstance : OpticalCirculator {
        satisfy SignalIsolationRequirement;
    }

    part fbgInstance : FiberBraggGrating {
        satisfy TemperatureRangeRequirement;
        satisfy BraggWavelengthRequirement;
    }

    part sourceInstance : BroadbandLightSource {
        satisfy BroadbandSourceRequirement;
    }

}
