package EchocardiographySimulationSystem {

    private import ScalarValues::Real;
    private import ScalarValues::Integer;
    private import ScalarValues::Positive;
    private import ScalarValues::String;
    private import ISQ::*;
    private import SI::*;
    private import Quantities::ScalarQuantityValue;
    private import SequenceFunctions::size;

    attribute def AcousticImpedanceValue :> ScalarQuantityValue;
    attribute def AttenuationCoefficientValue :> ScalarQuantityValue;
    attribute def IntensityValue :> ScalarQuantityValue;
    attribute def AmplitudeValue :> ScalarQuantityValue;
    attribute def StrainValue :> ScalarQuantityValue;
    attribute def DepthValue :> LengthValue;
    attribute def VelocityValue :> SpeedValue;
    attribute def FrequencyValue :> ScalarQuantityValue;

    item def UltrasoundPulse {
        attribute centerFrequency : FrequencyValue;
        attribute initialIntensity : IntensityValue;
        attribute currentIntensity : IntensityValue;
        attribute depth : DepthValue;
        attribute duration : TimeValue;
    }
    item def EchoSignal {
        attribute amplitude : AmplitudeValue;
        attribute depth : DepthValue;
        attribute timeOfFlight : TimeValue;
        attribute frequency : FrequencyValue;
    }
    item def ProcessedSignal {
        attribute amplitude : AmplitudeValue;
        attribute depth : DepthValue;
        attribute timeOfFlight : TimeValue;
        attribute dopplerShift : FrequencyValue;
    }
    item def CardiacImage {
        attribute pixelData : Real[*];
        attribute resolutionX : Positive;
        attribute resolutionY : Positive;
    }
    item def VelocityField {
        attribute velocities : VelocityValue[*];
        attribute depths : DepthValue[*];
    }
    item def StrainMeasurement {
        attribute strainValues : StrainValue[*];
        attribute depths : DepthValue[*];
    }

    port def PulsePort {
        inout pulse : UltrasoundPulse;
    }
    port def EchoPort {
        inout echoes : EchoSignal[*];
    }
    port def ProcessedSignalPort {
        inout signals : ProcessedSignal[*];
    }
    port def ImagePort {
        inout image : CardiacImage;
    }
    port def VelocityPort {
        inout velocityField : VelocityField;
    }
    port def StrainPort {
        inout strainMeasurement : StrainMeasurement;
    }

    calc def ReflectionCoefficient {
        in z1 : AcousticImpedanceValue;
        in z2 : AcousticImpedanceValue;
        return : Real = ((z2 - z1) / (z2 + z1))**2;
    }
    calc def AttenuatedIntensity {
        in initialIntensity : IntensityValue;
        in attenuationCoeff : AttenuationCoefficientValue;
        in distance : DepthValue;
        return : IntensityValue = initialIntensity * (2.71828 ** (-attenuationCoeff * distance));
    }
    calc def EchoAmplitude {
        in incidentIntensity : IntensityValue;
        in reflectionCoeff : Real;
        return : AmplitudeValue = incidentIntensity * reflectionCoeff;
    }
    calc def DopplerFrequencyShift {
        in emittedFrequency : FrequencyValue;
        in bloodVelocity : VelocityValue;
        in soundSpeed : SpeedValue;
        return : FrequencyValue = 2.0 * emittedFrequency * bloodVelocity / soundSpeed;
    }
    calc def VelocityFromDoppler {
        in dopplerShift : FrequencyValue;
        in emittedFrequency : FrequencyValue;
        in soundSpeed : SpeedValue;
        return : VelocityValue = dopplerShift * soundSpeed / (2.0 * emittedFrequency);
    }
    calc def StrainFromVelocity {
        in velocity : VelocityValue;
        in initialLength : LengthValue;
        in deltaTime : TimeValue;
        return : StrainValue = (velocity * deltaTime) / initialLength;
    }

    part def TissueLayer {
        attribute name : String;
        attribute depth : DepthValue;
        attribute thickness : LengthValue;
        attribute acousticImpedance : AcousticImpedanceValue;
        attribute attenuationCoefficient : AttenuationCoefficientValue;
    }
    part def Endocardium :> TissueLayer {
        :>> name = "Endocardium";
    }
    part def Myocardium :> TissueLayer {
        :>> name = "Myocardium";
    }
    part def Pericardium :> TissueLayer {
        :>> name = "Pericardium";
    }

    part def HeartModel {
        part endocardium : Endocardium {
            :>> depth = 0.005 [m];
            :>> thickness = 0.002 [m];
            :>> acousticImpedance = 1.65e6 [kg/(m^2*s)];
            :>> attenuationCoefficient = 0.5 [1/m];
        }
        part myocardium : Myocardium {
            :>> depth = 0.012 [m];
            :>> thickness = 0.010 [m];
            :>> acousticImpedance = 1.70e6 [kg/(m^2*s)];
            :>> attenuationCoefficient = 0.8 [1/m];
        }
        part pericardium : Pericardium {
            :>> depth = 0.018 [m];
            :>> thickness = 0.003 [m];
            :>> acousticImpedance = 1.55e6 [kg/(m^2*s)];
            :>> attenuationCoefficient = 0.3 [1/m];
        }
        attribute bloodFlowVelocity : VelocityValue = 0.8 [m/s];
        attribute heartRate : FrequencyValue = 1.2 [Hz];
    }

    part def UltrasoundTransducer {
        attribute centerFrequency : FrequencyValue = 2.5e6 [Hz];
        attribute soundSpeed : SpeedValue = 1540 [m/s];
        attribute pulseDuration : TimeValue = 2.0e-6 [s];
        attribute initialIntensity : IntensityValue = 1.0 [W/m^2];
        port pulseOut : PulsePort;
        port echoOut : EchoPort;
        attribute capturedEchoes : EchoSignal[*] := ();

        exhibit state transducerLifecycle {
            entry; then idle;
            state idle;
            then transmitting;
            state transmitting;
            then receiving;
            state receiving;
            then idle;
        }
    }

    part def SignalProcessor {
        attribute gain : Real = 100.0;
        attribute noiseFloor : AmplitudeValue = 0.001;
        port rawSignalIn : EchoPort;
        port processedSignalOut : ProcessedSignalPort;

        action def ProcessSignals {
            in raw : EchoSignal[*];
            out processed : ProcessedSignal[*];
            then assign processed := raw->collect { in e : EchoSignal;
                ProcessedSignal {
                    :>> amplitude = e.amplitude * gain;
                    :>> depth = e.depth;
                    :>> timeOfFlight = e.timeOfFlight;
                    :>> dopplerShift = 0.0 [Hz];
                }
            };
        }
    }

    part def ImageReconstructor {
        attribute resolutionX : Positive = 256;
        attribute resolutionY : Positive = 256;
        port signalIn : ProcessedSignalPort;
        port imageOut : ImagePort;

        action def ReconstructImage {
            in signals : ProcessedSignal[*];
            out image : CardiacImage;
            then assign image := CardiacImage {
                :>> resolutionX = resolutionX;
                :>> resolutionY = resolutionY;
                :>> pixelData = signals->collect { in s : ProcessedSignal;
                    s.amplitude
                };
            };
        }
    }

    part def DopplerAnalyzer {
        attribute emittedFrequency : FrequencyValue = 2.5e6 [Hz];
        attribute soundSpeed : SpeedValue = 1540 [m/s];
        port signalIn : ProcessedSignalPort;
        port velocityFieldOut : VelocityPort;

        action def AnalyzeDoppler {
            in signals : ProcessedSignal[*];
            out velocityField : VelocityField;
            then assign velocityField := VelocityField {
                :>> depths = signals->collect { in s : ProcessedSignal;
                    s.depth
                };
                :>> velocities = signals->collect { in s : ProcessedSignal;
                    VelocityFromDoppler(s.dopplerShift, emittedFrequency, soundSpeed)
                };
            };
        }
    }

    part def StrainAnalyzer {
        attribute initialLength : LengthValue = 0.012 [m];
        attribute deltaTime : TimeValue = 0.01 [s];
        port velocityFieldIn : VelocityPort;
        port strainOut : StrainPort;

        action def AnalyzeStrain {
            in velocityField : VelocityField;
            out strainMeasurement : StrainMeasurement;
            then assign strainMeasurement := StrainMeasurement {
                :>> depths = velocityField.depths;
                :>> strainValues = velocityField.velocities->collect { in v : VelocityValue;
                    StrainFromVelocity(v, initialLength, deltaTime)
                };
            };
        }
    }

    action def EchocardiographySimulation {
        in heart : HeartModel;
        in transducer : UltrasoundTransducer;
        out cardiacImage : CardiacImage;
        out velocityField : VelocityField;
        out strainMeasurement : StrainMeasurement;

        attribute layers : TissueLayer[*] = (
            heart.endocardium,
            heart.myocardium,
            heart.pericardium
        );

        action emitPulse {
            out pulse : UltrasoundPulse;
            then assign pulse := UltrasoundPulse {
                :>> centerFrequency = transducer.centerFrequency;
                :>> initialIntensity = transducer.initialIntensity;
                :>> currentIntensity = transducer.initialIntensity;
                :>> depth = 0.0 [m];
                :>> duration = transducer.pulseDuration;
            };
        }

        then action propagateAndReflect {
            in pulse : UltrasoundPulse = emitPulse.pulse;
            out echoes : EchoSignal[*] := ();
            attribute cumulativeDepth : DepthValue := 0.0 [m];
            attribute prevImpedance : AcousticImpedanceValue := 1.5e6 [kg/(m^2*s)];

            for i in 1..layers->size() {
                attribute layer : TissueLayer := layers#(i);
                attribute attenuated : IntensityValue := AttenuatedIntensity(
                    pulse.currentIntensity,
                    layer.attenuationCoefficient,
                    layer.depth
                );
                attribute reflCoeff : Real := ReflectionCoefficient(
                    prevImpedance,
                    layer.acousticImpedance
                );
                attribute echo : EchoSignal := EchoSignal {
                    :>> amplitude = EchoAmplitude(attenuated, reflCoeff);
                    :>> depth = cumulativeDepth + layer.depth;
                    :>> timeOfFlight = 2.0 * (cumulativeDepth + layer.depth) / transducer.soundSpeed;
                    :>> frequency = pulse.centerFrequency;
                };
                assign cumulativeDepth := cumulativeDepth + layer.depth;
                assign prevImpedance := layer.acousticImpedance;
                assign echoes := echoes->including(echo);
            }
        }

        then action processSignals {
            in rawEchoes : EchoSignal[*] = propagateAndReflect.echoes;
            out processed : ProcessedSignal[*];
            then assign processed := rawEchoes->collect { in e : EchoSignal;
                ProcessedSignal {
                    :>> amplitude = e.amplitude * 100.0;
                    :>> depth = e.depth;
                    :>> timeOfFlight = e.timeOfFlight;
                    :>> dopplerShift = DopplerFrequencyShift(
                        transducer.centerFrequency,
                        heart.bloodFlowVelocity,
                        transducer.soundSpeed
                    );
                }
            };
        }

        then action reconstructImage {
            in signals : ProcessedSignal[*] = processSignals.processed;
            out image : CardiacImage;
            then assign image := CardiacImage {
                :>> resolutionX = 256;
                :>> resolutionY = 256;
                :>> pixelData = signals->collect { in s : ProcessedSignal;
                    s.amplitude
                };
            };
        }

        then action analyzeDoppler {
            in signals : ProcessedSignal[*] = processSignals.processed;
            out velocityFieldOut : VelocityField;
            then assign velocityFieldOut := VelocityField {
                :>> depths = signals->collect { in s : ProcessedSignal;
                    s.depth
                };
                :>> velocities = signals->collect { in s : ProcessedSignal;
                    VelocityFromDoppler(s.dopplerShift, transducer.centerFrequency, transducer.soundSpeed)
                };
            };
        }

        then action analyzeStrain {
            in velocityFieldIn : VelocityField = analyzeDoppler.velocityFieldOut;
            out strainMeasurementOut : StrainMeasurement;
            then assign strainMeasurementOut := StrainMeasurement {
                :>> depths = velocityFieldIn.depths;
                :>> strainValues = velocityFieldIn.velocities->collect { in v : VelocityValue;
                    StrainFromVelocity(v, 0.012 [m], 0.01 [s])
                };
            };
        }

        then assign cardiacImage := reconstructImage.image;
        then assign velocityField := analyzeDoppler.velocityFieldOut;
        then assign strainMeasurement := analyzeStrain.strainMeasurementOut;
    }

    part def EchocardiographySystem {
        part heart : HeartModel;
        part transducer : UltrasoundTransducer;
        part signalProcessor : SignalProcessor;
        part imageReconstructor : ImageReconstructor;
        part dopplerAnalyzer : DopplerAnalyzer;
        part strainAnalyzer : StrainAnalyzer;

        connection rawEchoPath connect transducer.echoOut to signalProcessor.rawSignalIn;
        connection processedToImage connect signalProcessor.processedSignalOut to imageReconstructor.signalIn;
        connection processedToDoppler connect signalProcessor.processedSignalOut to dopplerAnalyzer.signalIn;
        connection velocityToStrain connect dopplerAnalyzer.velocityFieldOut to strainAnalyzer.velocityFieldIn;

        action simulate : EchocardiographySimulation {
            in heart = heart;
            in transducer = transducer;
            out cardiacImage = imageReconstructor.imageOut.image;
            out velocityField = dopplerAnalyzer.velocityFieldOut.velocityField;
            out strainMeasurement = strainAnalyzer.strainOut.strainMeasurement;
        }
    }

    package Requirements {
        requirement def SimulateUltrasoundPulse {
            subject transducer : UltrasoundTransducer;
            doc /* The simulated transducer shall emit ultrasound pulses in the diagnostic frequency range. */
            require constraint {
                transducer.centerFrequency >= 1.0e6 [Hz] &
                transducer.centerFrequency <= 15.0e6 [Hz]
            }
        }
        requirement def ModelTissueLayers {
            subject heart : HeartModel;
            doc /* The heart model shall contain distinct tissue layers with positive depths and acoustic impedances. */
            require constraint {
                heart.endocardium.depth > 0.0 [m] &
                heart.myocardium.depth > 0.0 [m] &
                heart.pericardium.depth > 0.0 [m] &
                heart.endocardium.acousticImpedance > 1.0e6 [kg/(m^2*s)] &
                heart.myocardium.acousticImpedance > 1.0e6 [kg/(m^2*s)] &
                heart.pericardium.acousticImpedance > 1.0e6 [kg/(m^2*s)]
            }
        }
        requirement def GenerateEchoSignals {
            subject simulation : EchocardiographySimulation;
            doc /* The simulation shall generate echo signals from each tissue boundary. */
            require constraint {
                simulation.propagateAndReflect.echoes->size() >= 3
            }
        }
        requirement def ProduceCardiacImage {
            subject imageReconstructor : ImageReconstructor;
            doc /* The image reconstructor shall produce a 2D cardiac image with minimum resolution. */
            require constraint {
                imageReconstructor.resolutionX >= 128 &
                imageReconstructor.resolutionY >= 128
            }
        }
        requirement def CalculateBloodFlowVelocity {
            subject dopplerAnalyzer : DopplerAnalyzer;
            doc /* The Doppler analyzer shall calculate blood flow velocity from frequency shifts. */
            require constraint {
                dopplerAnalyzer.emittedFrequency > 0.0 [Hz] &
                dopplerAnalyzer.soundSpeed > 0.0 [m/s]
            }
        }
        requirement def MeasureStrain {
            subject strainAnalyzer : StrainAnalyzer;
            doc /* The strain analyzer shall measure myocardial strain from velocity data. */
            require constraint {
                strainAnalyzer.initialLength > 0.0 [m] &
                strainAnalyzer.deltaTime > 0.0 [s]
            }
        }
    }

    package Verification {
        verification def VerifyEchocardiographySystem {
            subject system : EchocardiographySystem;
            objective {
                verify Requirements::SimulateUltrasoundPulse;
                verify Requirements::ModelTissueLayers;
                verify Requirements::GenerateEchoSignals;
                verify Requirements::ProduceCardiacImage;
                verify Requirements::CalculateBloodFlowVelocity;
                verify Requirements::MeasureStrain;
            }
        }
    }

    analysis def EchocardiographyAnalysis {
        subject system : EchocardiographySystem;
        in attribute transmitFrequency : FrequencyValue = 2.5e6 [Hz];
        out attribute simulatedImage : CardiacImage;
        out attribute bloodVelocity : VelocityField;
        out attribute myocardialStrain : StrainMeasurement;

        action runSimulation {
            perform action simulate : EchocardiographySimulation {
                in heart = system.heart;
                in transducer = system.transducer;
            }
            then assign simulatedImage := simulate.cardiacImage;
            then assign bloodVelocity := simulate.velocityField;
            then assign myocardialStrain := simulate.strainMeasurement;
        }
    }
}
