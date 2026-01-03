package PhotoionizationDetectorSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ConcentrationPPM :> Real {
        doc /* Concentration measured in parts per million */
    }
    
    attribute def PhotonEnergyEV :> Real {
        doc /* Photon energy measured in electron volts */
    }
    
    item def VolatileOrganicCompound {
        attribute molecularFormula : String;
        attribute ionizationPotential : PhotonEnergyEV;
        attribute concentration : ConcentrationPPM;
    }
    
    item def AirSample {
        attribute voc : VolatileOrganicCompound;
        attribute temperature : TemperatureValue;
        attribute pressure : PressureValue;
        attribute flowRate : VolumeFlowRateValue;
    }
    
    item def IonizedMolecule {
        attribute charge : ElectricChargeValue;
        attribute mobility : Real;
    }
    
    port def SampleInletPort {
        in item airSample : AirSample;
    }
    
    port def SampleOutletPort {
        out item exhaustSample : AirSample;
    }
    
    port def ElectricalSignalPort {
        out attribute voltage : ElectricPotentialValue;
        out attribute current : ElectricCurrentValue;
    }
    
    port def PowerSupplyPort {
        in attribute voltage : ElectricPotentialValue;
        in attribute current : ElectricCurrentValue;
    }
    
    port def DataOutputPort {
        out attribute vocConcentration : ConcentrationPPM;
        out attribute alarmStatus : Boolean;
    }
    
    part def UltravioletLamp {
        doc /* UV lamp emitting photons at 10.6 eV to ionize VOC molecules */
        attribute photonEnergy : PhotonEnergyEV;
        attribute operatingVoltage : ElectricPotentialValue;
        attribute lampLifetime : DurationValue;
        
        port powerIn : PowerSupplyPort;
        
        action emitPhotons {
            in voltage : ElectricPotentialValue;
            out energy : PhotonEnergyEV;
        }
    }
    
    part def IonizationChamber {
        doc /* Chamber where VOC molecules are ionized by UV photons */
        attribute chamberVolume : VolumeValue;
        attribute chamberPressure : PressureValue;
        
        port sampleIn : SampleInletPort;
        port sampleOut : SampleOutletPort;
        
        action ionizeVOCs {
            in sample : AirSample;
            in photonEnergy : PhotonEnergyEV;
            out ionizedMolecules : IonizedMolecule[*];
        }
    }
    
    part def CollectorElectrodes {
        doc /* Biased electrodes that collect ionized particles and generate current */
        attribute biasVoltage : ElectricPotentialValue;
        attribute electrodeSpacing : LengthValue;
        attribute collectionEfficiency : Real;
        
        part anodeElectrode {
            attribute voltage : ElectricPotentialValue;
        }
        
        part cathodeElectrode {
            attribute voltage : ElectricPotentialValue;
        }
        
        port signalOut : ElectricalSignalPort;
        
        action collectIons {
            in ions : IonizedMolecule[*];
            in biasVoltage : ElectricPotentialValue;
            out ionCurrent : ElectricCurrentValue;
        }
    }
    
    part def CurrentAmplifier {
        doc /* Amplifies weak ionization current to measurable voltage signal */
        attribute gainFactor : Real;
        attribute bandwidth : FrequencyValue;
        
        port signalIn : ElectricalSignalPort;
        port signalOut : ElectricalSignalPort;
        port powerIn : PowerSupplyPort;
        
        action amplifySignal {
            in inputCurrent : ElectricCurrentValue;
            in gain : Real;
            out outputVoltage : ElectricPotentialValue;
        }
    }
    
    part def SignalProcessor {
        doc /* Processes amplified signal and converts to concentration reading */
        attribute calibrationCurve : Real[*];
        attribute samplingRate : FrequencyValue;
        
        port signalIn : ElectricalSignalPort;
        port dataOut : DataOutputPort;
        port powerIn : PowerSupplyPort;
        
        action convertToConcentration {
            in signalVoltage : ElectricPotentialValue;
            in calibration : Real[*];
            out concentration : ConcentrationPPM;
        }
    }
    
    part def AlarmSystem {
        doc /* Monitors concentration and triggers alarm when threshold exceeded */
        attribute alarmThreshold : ConcentrationPPM;
        attribute alarmDelay : DurationValue;
        
        action evaluateAlarm {
            in concentration : ConcentrationPPM;
            in threshold : ConcentrationPPM;
            out alarmActive : Boolean;
        }
    }
    
    part def SamplePump {
        doc /* Draws air sample through ionization chamber at controlled flow rate */
        attribute targetFlowRate : VolumeFlowRateValue;
        attribute pumpSpeed : FrequencyValue;
        
        port sampleIn : SampleInletPort;
        port sampleOut : SampleOutletPort;
        port powerIn : PowerSupplyPort;
        
        action drawSample {
            in flowRate : VolumeFlowRateValue;
            in sample : AirSample;
            out pumpedSample : AirSample;
        }
    }
    
    part def PowerSupply {
        doc /* Provides regulated power to all detector components */
        attribute outputVoltage : ElectricPotentialValue;
        attribute maxCurrent : ElectricCurrentValue;
        
        port powerOut : PowerSupplyPort[*];
    }
    
    part def PIDDetector {
        doc /* Complete Photoionization Detector system for VOC detection */
        
        port ambientAirIn : SampleInletPort;
        port exhaustOut : SampleOutletPort;
        port measurementOut : DataOutputPort;
        port mainPowerIn : PowerSupplyPort;
        
        part uvLamp : UltravioletLamp {
            attribute redefines photonEnergy = 10.6;
        }
        
        part chamber : IonizationChamber;
        
        part electrodes : CollectorElectrodes;
        
        part amplifier : CurrentAmplifier {
            attribute redefines gainFactor = 1000000.0;
        }
        
        part processor : SignalProcessor;
        
        part alarm : AlarmSystem {
            attribute redefines alarmThreshold = 100.0;
        }
        
        part pump : SamplePump;
        
        part power : PowerSupply;
        
        connection powerDistribution connect mainPowerIn to power.powerOut;
        connection lampPower connect power.powerOut to uvLamp.powerIn;
        connection ampPower connect power.powerOut to amplifier.powerIn;
        connection procPower connect power.powerOut to processor.powerIn;
        connection pumpPower connect power.powerOut to pump.powerIn;
        
        connection sampleFlow connect ambientAirIn to pump.sampleIn;
        connection pumpToChamber connect pump.sampleOut to chamber.sampleIn;
        connection chamberExhaust connect chamber.sampleOut to exhaustOut;
        
        connection electrodeSignal connect electrodes.signalOut to amplifier.signalIn;
        connection amplifiedSignal connect amplifier.signalOut to processor.signalIn;
        connection dataOutput connect processor.dataOut to measurementOut;
    }
    
    action def DetectVolatileOrganicCompounds {
        doc /* Primary detection function: ionize VOCs and measure concentration */
        
        in airSample : AirSample;
        in uvEnergy : PhotonEnergyEV;
        in biasVoltage : ElectricPotentialValue;
        in amplifierGain : Real;
        in calibration : Real[*];
        in alarmThreshold : ConcentrationPPM;
        out vocConcentration : ConcentrationPPM;
        out alarmTriggered : Boolean;
        
        first start;
        
        then action drawAirSample {
            in sample = airSample;
            out pumpedSample : AirSample;
        }
        
        flow drawAirSample.pumpedSample to ionizeSample.sample;
        
        then action ionizeSample {
            in sample : AirSample;
            in photonEnergy = uvEnergy;
            out ions : IonizedMolecule[*];
        }
        
        flow ionizeSample.ions to collectIonCurrent.ions;
        
        then action collectIonCurrent {
            in ions : IonizedMolecule[*];
            in bias = biasVoltage;
            out current : ElectricCurrentValue;
        }
        
        flow collectIonCurrent.current to amplifySignal.inputCurrent;
        
        then action amplifySignal {
            in inputCurrent : ElectricCurrentValue;
            in gain = amplifierGain;
            out voltage : ElectricPotentialValue;
        }
        
        flow amplifySignal.voltage to processSignal.signalVoltage;
        
        then action processSignal {
            in signalVoltage : ElectricPotentialValue;
            in calibration;
            out concentration : ConcentrationPPM;
        }
        
        flow processSignal.concentration to checkAlarm.concentration;
        
        then action checkAlarm {
            in concentration : ConcentrationPPM;
            in threshold = alarmThreshold;
            out alarm : Boolean;
        }
        
        then assign vocConcentration := processSignal.concentration;
        then assign alarmTriggered := checkAlarm.alarm;
        
        then done;
    }
    
    state def PIDOperatingStates {
        doc /* Operating states of the PID detector */
        
        entry; then PowerOff;
        
        state PowerOff;
        
        state Initializing {
            doc /* System startup and self-test */
        }
        
        state Warmup {
            doc /* UV lamp warming up to stable operation */
        }
        
        state Ready {
            doc /* System ready for measurement */
        }
        
        state Measuring {
            doc /* Actively measuring VOC concentration */
        }
        
        state AlarmActive {
            doc /* Concentration exceeds alarm threshold */
        }
        
        state Fault {
            doc /* System fault detected */
        }
        
        transition powerOn first PowerOff then Initializing;
        transition initComplete first Initializing then Warmup;
        transition warmupComplete first Warmup then Ready;
        transition startMeasure first Ready then Measuring;
        transition measureComplete first Measuring then Ready;
        transition thresholdExceeded first Measuring then AlarmActive;
        transition thresholdNormal first AlarmActive then Measuring;
        transition faultDetected first Measuring then Fault;
        transition reset first Fault then Initializing;
        transition shutdown first Ready then PowerOff;
    }
    
    part pidSystem : PIDDetector {
        doc /* Operational PID detector system instance */
        
        exhibit state operatingState : PIDOperatingStates;
        
        perform action detectVOCs[*] ordered references DetectVolatileOrganicCompounds {
            in airSample;
            in uvEnergy = uvLamp.photonEnergy;
            in biasVoltage = electrodes.biasVoltage;
            in amplifierGain = amplifier.gainFactor;
            in calibration = processor.calibrationCurve;
            in alarmThreshold = alarm.alarmThreshold;
            out vocConcentration;
            out alarmTriggered;
        }
        
        part redefines pump {
            perform detectVOCs.drawAirSample;
        }
        
        part redefines uvLamp {
            perform action emitUV references emitPhotons;
        }
        
        part redefines chamber {
            perform detectVOCs.ionizeSample;
        }
        
        part redefines electrodes {
            perform detectVOCs.collectIonCurrent;
        }
        
        part redefines amplifier {
            perform detectVOCs.amplifySignal;
        }
        
        part redefines processor {
            perform detectVOCs.processSignal;
        }
        
        part redefines alarm {
            perform detectVOCs.checkAlarm;
        }
    }
    
    requirement def DetectionCapabilityRequirement {
        doc /* Requirements for VOC detection capability */
        
        subject detector : PIDDetector;
        
        require constraint detectionRange {
            doc /* Detector shall measure VOC concentrations from 0.1 to 10000 ppm */
        }
        
        require constraint responseTime {
            doc /* Detector shall respond to concentration changes within 3 seconds */
        }
        
        require constraint selectivity {
            doc /* Detector shall ionize compounds with ionization potential below lamp energy */
        }
        
        require constraint accuracy {
            doc /* Measurement accuracy shall be within ±5% of reading or ±0.1 ppm */
        }
    }
    
    requirement def SafetyRequirement {
        doc /* Safety requirements for PID operation */
        
        subject detector : PIDDetector;
        
        require constraint uvShielding {
            doc /* UV lamp shall be fully shielded to prevent operator exposure */
        }
        
        require constraint alarmReliability {
            doc /* Alarm system shall activate within 1 second of threshold exceedance */
        }
        
        require constraint powerSafety {
            doc /* System shall include overcurrent and overvoltage protection */
        }
    }
    
    requirement def OperationalRequirement {
        doc /* Operational requirements for PID system */
        
        subject detector : PIDDetector;
        
        require constraint warmupTime {
            doc /* System shall be ready for measurement within 60 seconds of power-on */
        }
        
        require constraint continuousOperation {
            doc /* System shall support continuous operation for 8 hours minimum */
        }
        
        require constraint lampLifetime {
            doc /* UV lamp shall maintain performance for minimum 2000 operating hours */
        }
    }
    
    requirement pidSystemRequirements {
        doc /* Complete requirements for PID detector system */
        
        subject detector = pidSystem;
        
        satisfy detectionCapability : DetectionCapabilityRequirement;
        satisfy safety : SafetyRequirement;
        satisfy operational : OperationalRequirement;
    }
}
