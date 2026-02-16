package 'Ionization Chamber System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    attribute def RadiationIntensity {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def IonizationCurrent {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def BiasVoltage {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def GasPressure {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def ChamberCapacitance {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def ElectricCharge {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def ElectrodeArea {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def ElectrodeSeparation {
        attribute magnitude : Real;
        attribute unit : String;
    }

    attribute def GasType {
        attribute name : String;
        attribute atomicNumber : Integer;
        attribute ionizationEnergy : Real;
    }

    attribute def StartCommand;
    attribute def StopCommand;

    port def RadiationInputPort {
        in attribute radiationIntensity : RadiationIntensity;
    }

    port def BiasVoltagePort {
        in attribute voltage : BiasVoltage;
    }

    port def CurrentOutputPort {
        out attribute current : IonizationCurrent;
    }

    port def SignalOutputPort {
        out attribute signal : IonizationCurrent;
    }

    part def IonizationChamber {
        doc /* Gas-filled detector that converts ionizing radiation into measurable electrical current. */

        attribute fillGas : GasType;
        attribute gasPressure : GasPressure;
        attribute chamberCapacitance : ChamberCapacitance;
        attribute electrodeArea : ElectrodeArea;
        attribute electrodeSeparation : ElectrodeSeparation;

        port radiationInput : RadiationInputPort;
        port biasInput : BiasVoltagePort;
        port currentOutput : CurrentOutputPort;

        part anode {
            attribute material : String;
            attribute surfaceArea : ElectrodeArea;
        }

        part cathode {
            attribute material : String;
            attribute surfaceArea : ElectrodeArea;
        }

        part insulators[2] {
            attribute material : String;
            attribute dielectricStrength : Real;
        }

        part gasVolume {
            attribute fillGas : GasType;
            attribute pressure : GasPressure;
            attribute temperature : Real;
        }

        perform action ionize;
    }

    part def HighVoltageSupply {
        doc /* Provides stable bias voltage to establish electric field in chamber. */

        attribute nominalVoltage : BiasVoltage;
        attribute voltageStability : Real;
        attribute ripple : BiasVoltage;

        port voltageOutput : BiasVoltagePort;

        perform action supplyBias;
    }

    part def ChargeAmplifier {
        doc /* Converts ionization current to measurable voltage signal. */

        attribute feedbackCapacitance : ChamberCapacitance;
        attribute inputImpedance : Real;
        attribute gain : Real;

        port currentInput : CurrentOutputPort;
        port signalOutput : SignalOutputPort;

        perform action amplifySignal;
    }

    part def SignalProcessor {
        doc /* Processes and digitizes amplified signal for measurement. */

        attribute integrationTime : Real;
        attribute noiseThreshold : IonizationCurrent;

        port signalInput : SignalOutputPort;

        perform action processSignal;
    }

    action def IonizeGas {
        doc /* Radiation ionizes gas molecules creating electron-ion pairs. */

        in radiationIntensity : RadiationIntensity;
        in gasType : GasType;
        in gasPressure : GasPressure;
        out ionPairsGenerated : Real;
        out chargeCreated : ElectricCharge;
    }

    action def CollectCharge {
        doc /* Electric field separates and collects charge carriers. */

        in biasVoltage : BiasVoltage;
        in chargeCreated : ElectricCharge;
        in electrodeSeparation : ElectrodeSeparation;
        out collectedCharge : ElectricCharge;
        out ionizationCurrent : IonizationCurrent;
    }

    action def AmplifyCharge {
        doc /* Charge amplifier converts current to voltage signal. */

        in ionizationCurrent : IonizationCurrent;
        in feedbackCapacitance : ChamberCapacitance;
        in gain : Real;
        out outputSignal : IonizationCurrent;
    }

    action def ProcessSignal {
        doc /* Signal processing extracts radiation measurement. */

        in inputSignal : IonizationCurrent;
        in integrationTime : Real;
        out measuredIntensity : RadiationIntensity;
    }

    action def DetectRadiation {
        doc /* Complete radiation detection process from ionization to measurement. */

        in radiationIntensity : RadiationIntensity;
        in biasVoltage : BiasVoltage;
        in gasType : GasType;
        in gasPressure : GasPressure;
        in electrodeSeparation : ElectrodeSeparation;
        in feedbackCapacitance : ChamberCapacitance;
        in gain : Real;
        in integrationTime : Real;
        out measuredIntensity : RadiationIntensity;

        first start;
        then action ionize : IonizeGas {
            in radiationIntensity = DetectRadiation::radiationIntensity;
            in gasType = DetectRadiation::gasType;
            in gasPressure = DetectRadiation::gasPressure;
            out ionPairsGenerated;
            out chargeCreated;
        }
        flow ionize.chargeCreated to collect.chargeCreated;
        then action collect : CollectCharge {
            in biasVoltage = DetectRadiation::biasVoltage;
            in chargeCreated;
            in electrodeSeparation = DetectRadiation::electrodeSeparation;
            out collectedCharge;
            out ionizationCurrent;
        }
        flow collect.ionizationCurrent to amplify.ionizationCurrent;
        then action amplify : AmplifyCharge {
            in ionizationCurrent;
            in feedbackCapacitance = DetectRadiation::feedbackCapacitance;
            in gain = DetectRadiation::gain;
            out outputSignal;
        }
        flow amplify.outputSignal to process.inputSignal;
        then action process : ProcessSignal {
            in inputSignal;
            in integrationTime = DetectRadiation::integrationTime;
            out measuredIntensity;
        }
        then assign DetectRadiation::measuredIntensity := process.measuredIntensity;
        then done;
    }

    action def OperateDetector {
        doc /* Continuous operation cycle for radiation detection. */

        in attribute startCmd : StartCommand;
        in attribute stopCmd : StopCommand;
        in attribute radiationIntensity : RadiationIntensity;
        in attribute biasVoltage : BiasVoltage;
        out attribute measuredIntensity : RadiationIntensity;

        loop {
            accept start : StartCommand;
            then action detect : DetectRadiation {
                in radiationIntensity = OperateDetector::radiationIntensity;
                in biasVoltage = OperateDetector::biasVoltage;
                in gasType;
                in gasPressure;
                in electrodeSeparation;
                in feedbackCapacitance;
                in gain;
                in integrationTime;
                out measuredIntensity;
            }
            then assign OperateDetector::measuredIntensity := detect.measuredIntensity;
            then accept stop : StopCommand;
        }
    }

    part ionizationDetectorSystem {
        doc /* 
            Complete ionization chamber radiation detection system.
            Primary function: Detect and measure ionizing radiation by converting
            radiation-induced ionization into proportional electrical signals.
        */

        port radiationInput : RadiationInputPort;

        part chamber : IonizationChamber {
            attribute :>> fillGas = GasType {
                name = "Argon";
                atomicNumber = 18;
                ionizationEnergy = 15.76;
            }
            attribute :>> gasPressure = GasPressure {
                magnitude = 101325.0;
                unit = "Pa";
            }
            attribute :>> chamberCapacitance = ChamberCapacitance {
                magnitude = 100.0;
                unit = "pF";
            }
            attribute :>> electrodeArea = ElectrodeArea {
                magnitude = 100.0;
                unit = "cm2";
            }
            attribute :>> electrodeSeparation = ElectrodeSeparation {
                magnitude = 10.0;
                unit = "mm";
            }
        }

        part hvSupply : HighVoltageSupply {
            attribute :>> nominalVoltage = BiasVoltage {
                magnitude = 500.0;
                unit = "V";
            }
            attribute :>> voltageStability = 0.001;
            attribute :>> ripple = BiasVoltage {
                magnitude = 0.1;
                unit = "V";
            }
        }

        part amplifier : ChargeAmplifier {
            attribute :>> feedbackCapacitance = ChamberCapacitance {
                magnitude = 1.0;
                unit = "pF";
            }
            attribute :>> inputImpedance = 1.0e14;
            attribute :>> gain = 1000.0;
        }

        part processor : SignalProcessor {
            attribute :>> integrationTime = 1.0;
            attribute :>> noiseThreshold = IonizationCurrent {
                magnitude = 1.0e-15;
                unit = "A";
            }
        }

        connect radiationInput to chamber.radiationInput;
        connect hvSupply.voltageOutput to chamber.biasInput;
        connect chamber.currentOutput to amplifier.currentInput;
        connect amplifier.signalOutput to processor.signalInput;

        perform action operate : OperateDetector {
            in startCmd;
            in stopCmd;
            in radiationIntensity = radiationInput.radiationIntensity;
            in biasVoltage = hvSupply.nominalVoltage;
            out measuredIntensity;
        }
    }

    requirement def RadiationDetectionRequirement {
        doc /* System shall detect and measure ionizing radiation. */

        subject detectorSystem : ionizationDetectorSystem;

        require constraint sensitivityRequirement {
            doc /* Minimum detectable dose rate shall be less than 1 microGray per hour. */
        }

        require constraint linearityRequirement {
            doc /* Response shall be linear within 5% over operational dose rate range. */
        }

        require constraint stabilityRequirement {
            doc /* Output signal drift shall be less than 2% over 8 hours continuous operation. */
        }
    }

    requirement def BiasVoltageRequirement {
        doc /* Bias voltage shall maintain saturation region operation. */

        subject hvSupply : HighVoltageSupply;

        require constraint voltageRangeRequirement {
            doc /* Bias voltage shall be between 300V and 600V. */
        }

        require constraint voltageStabilityRequirement {
            doc /* Voltage stability shall be better than 0.1% over operational temperature range. */
        }

        require constraint rippleRequirement {
            doc /* Voltage ripple shall be less than 0.5V peak-to-peak. */
        }
    }

    requirement def GasFillRequirement {
        doc /* Chamber fill gas shall provide optimal ionization characteristics. */

        subject chamber : IonizationChamber;

        require constraint gasPurityRequirement {
            doc /* Gas purity shall exceed 99.99%. */
        }

        require constraint pressureRequirement {
            doc /* Gas pressure shall be maintained at atmospheric pressure ± 2%. */
        }

        require constraint temperatureRequirement {
            doc /* Operating temperature range shall be 15°C to 35°C. */
        }
    }

    requirement def SignalProcessingRequirement {
        doc /* Signal processing shall accurately extract radiation measurement. */

        subject processor : SignalProcessor;

        require constraint noiseRejectionRequirement {
            doc /* Signal-to-noise ratio shall exceed 100:1 at minimum detectable dose rate. */
        }

        require constraint responseTimeRequirement {
            doc /* System response time shall be less than 2 seconds. */
        }
    }

    requirement systemRequirements {
        doc /* Top-level requirements for ionization chamber radiation detection system. */

        require radiationDetectionReq : RadiationDetectionRequirement;
        require biasVoltageReq : BiasVoltageRequirement;
        require gasFillReq : GasFillRequirement;
        require signalProcessingReq : SignalProcessingRequirement;
    }
}
