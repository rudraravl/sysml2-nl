package FaradayCupSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def ElectricCurrentValue :> ISQ::CurrentValue {
        attribute :>> num : Real;
        attribute :>> mRef : CurrentUnit[1];
    }
    
    attribute def ElectricChargeValue :> ISQ::ChargeValue {
        attribute :>> num : Real;
        attribute :>> mRef : ChargeUnit[1];
    }
    
    attribute def VoltageValue :> ISQ::VoltageValue {
        attribute :>> num : Real;
        attribute :>> mRef : VoltageUnit[1];
    }
    
    attribute def ParticleFluxValue {
        attribute particlesPerSecond : Real;
    }
    
    item def ChargedParticleBeam {
        attribute flux : ParticleFluxValue;
        attribute beamCurrent : ElectricCurrentValue;
        attribute particleCharge : ElectricChargeValue;
    }
    
    item def CurrentSignal {
        attribute magnitude : ElectricCurrentValue;
        attribute timestamp : Real;
    }
    
    port def BeamInputPort {
        in item beam : ChargedParticleBeam;
    }
    
    port def CurrentOutputPort {
        out item signal : CurrentSignal;
    }
    
    port def BiasPort {
        in attribute voltage : VoltageValue;
    }
    
    part def CollectorCup {
        attribute material : String;
        attribute collectionArea : Real;
        attribute accumulatedCharge : ElectricChargeValue;
        
        port beamInput : BeamInputPort;
        
        action collectCharge {
            in incidentBeam : ChargedParticleBeam;
            out chargeCollected : ElectricChargeValue;
        }
    }
    
    part def BiasSupply {
        attribute suppressionVoltage : VoltageValue;
        
        port biasOutput : BiasPort;
        
        action applyBias {
            out voltage : VoltageValue;
        }
    }
    
    part def CurrentAmplifier {
        attribute gain : Real;
        attribute inputImpedance : Real;
        
        port currentInput : CurrentOutputPort;
        port signalOutput : CurrentOutputPort;
        
        action amplifySignal {
            in inputCurrent : ElectricCurrentValue;
            out amplifiedCurrent : ElectricCurrentValue;
        }
    }
    
    part def VacuumEnclosure {
        attribute pressure : Real;
        attribute volume : Real;
        
        action maintainVacuum {
            in targetPressure : Real;
            out actualPressure : Real;
        }
    }
    
    part def ElectromagneticShield {
        attribute shieldingFactor : Real;
        
        action attenuateNoise {
            in externalNoise : Real;
            out residualNoise : Real;
        }
    }
    
    part def FaradayCupInstrument {
        attribute totalMass : MassValue;
        attribute operatingTemperature : Real;
        
        port particleInput : BeamInputPort;
        port measurementOutput : CurrentOutputPort;
        
        part collector : CollectorCup {
            attribute :>> material = "copper";
            attribute :>> collectionArea = 500.0;
        }
        
        part biasSupply : BiasSupply;
        
        part amplifier : CurrentAmplifier {
            attribute :>> gain = 1.0e6;
            attribute :>> inputImpedance = 1.0e12;
        }
        
        part vacuum : VacuumEnclosure {
            attribute :>> pressure = 1.0e-7;
            attribute :>> volume = 0.1;
        }
        
        part shield : ElectromagneticShield {
            attribute :>> shieldingFactor = 100.0;
        }
        
        connection beamToCollector connect particleInput to collector.beamInput;
        connection biasToCollector connect biasSupply.biasOutput to collector;
        connection collectorToAmplifier connect collector to amplifier.currentInput;
        connection amplifierToOutput connect amplifier.signalOutput to measurementOutput;
    }
    
    action def MeasureBeamCurrent {
        first start;
        then action captureParticles {
            in beam : ChargedParticleBeam;
            out charge : ElectricChargeValue;
        }
        then action suppressSecondaryEmission {
            in biasVoltage : VoltageValue;
            out suppressionEfficiency : Real;
        }
        then action convertToSignal {
            in charge : ElectricChargeValue;
            out current : ElectricCurrentValue;
        }
        then action amplify {
            in rawCurrent : ElectricCurrentValue;
            out amplifiedCurrent : ElectricCurrentValue;
        }
        then action output {
            in finalCurrent : ElectricCurrentValue;
        }
        then done;
    }
    
    state def OperatingStates {
        entry; then idle;
        
        state idle {
            entry action initialize;
        }
        
        accept BeamDetected
        then measuring;
        
        state measuring {
            entry action startCollection;
            do action continuousMeasurement : MeasureBeamCurrent;
        }
        
        accept at signalStable
        then integrating;
        
        state integrating {
            do action integrateCharge {
                in currentFlow : ElectricCurrentValue;
                out totalCharge : ElectricChargeValue;
            }
        }
        
        accept at integrationPeriodComplete
        then reporting;
        
        state reporting {
            do action transmitResults {
                in measuredCurrent : ElectricCurrentValue;
            }
        }
        
        accept MeasurementComplete
        then idle;
        
        accept BeamLost
        then idle;
    }
    
    requirement def AccuracyRequirement {
        doc /* The Faraday cup shall measure beam current with high accuracy. */
        subject instrument : FaradayCupInstrument;
        require constraint {
            instrument.amplifier.gain >= 1.0e5
        }
    }
    
    requirement def VacuumRequirement {
        doc /* The Faraday cup shall operate in high vacuum to minimize scattering. */
        subject enclosure : VacuumEnclosure;
        require constraint {
            enclosure.pressure <= 1.0e-6
        }
    }
    
    requirement def SecondaryEmissionSuppressionRequirement {
        doc /* The Faraday cup shall suppress secondary electron emission. */
        subject instrument : FaradayCupInstrument;
        require constraint {
            instrument.biasSupply.suppressionVoltage.num <= -50.0
        }
    }
    
    requirement def NoiseShieldingRequirement {
        doc /* The Faraday cup shall be shielded from electromagnetic interference. */
        subject shield : ElectromagneticShield;
        require constraint {
            shield.shieldingFactor >= 60.0
        }
    }
    
    requirement <'REQ-FC-PRIMARY'> primaryFunction {
        doc /* The Faraday cup system shall measure the electric current of 
             * charged particle beams by collecting particles in a conductive 
             * cup and measuring the resulting charge accumulation. The system 
             * suppresses secondary electron emission through negative bias 
             * voltage and operates in high vacuum to ensure accurate 
             * measurement of beam characteristics.
             */
        subject faradayCup : FaradayCupInstrument;
        
        assume constraint validBeam {
            faradayCup.particleInput.beam.flux.particlesPerSecond > 0.0
        }
        
        require accuracy : AccuracyRequirement {
            :>> instrument = faradayCup;
        }
        
        require vacuumCondition : VacuumRequirement {
            :>> enclosure = faradayCup.vacuum;
        }
        
        require suppressSecondaries : SecondaryEmissionSuppressionRequirement {
            :>> instrument = faradayCup;
        }
        
        require shielding : NoiseShieldingRequirement {
            :>> shield = faradayCup.shield;
        }
    }
    
    part faradayCupSystem : FaradayCupInstrument {
        attribute :>> totalMass = 3.5 [kg];
        attribute :>> operatingTemperature = 298.0;
        
        part :>> collector {
            attribute :>> material = "copper";
            attribute :>> collectionArea = 490.0;
        }
        
        part :>> biasSupply {
            attribute :>> suppressionVoltage = -90.0 [V];
        }
        
        part :>> amplifier {
            attribute :>> gain = 1.0e6;
            attribute :>> inputImpedance = 1.0e12;
        }
        
        part :>> vacuum {
            attribute :>> pressure = 1.0e-7;
            attribute :>> volume = 0.125;
        }
        
        part :>> shield {
            attribute :>> shieldingFactor = 80.0;
        }
        
        perform action measurementBehavior : MeasureBeamCurrent;
        
        exhibit state systemStates : OperatingStates;
    }
    
    satisfy primaryFunction by faradayCupSystem;
}
