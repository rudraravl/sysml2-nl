package ThermoluminescentDosimeterSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def DoseValue :> ISQ::AbsorbedDoseValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def LightIntensityValue :> ISQ::LuminousIntensityValue;
    attribute def TimeValue :> ISQ::TimeValue;
    attribute def EnergyValue :> ISQ::EnergyValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def VoltageValue :> ISQ::ElectricPotentialValue;

    attribute def DoseRecord {
        attribute measuredDose : DoseValue;
        attribute readoutTime : TimeValue;
        attribute badgeID : String;
    }

    attribute def CalibrationData {
        attribute calibrationFactor : Real;
        attribute calibrationDate : String;
        attribute referenceTemperature : TemperatureValue;
        attribute linearityRange : DoseValue[2];
    }

    item def TLDMaterial {
        attribute materialType : String;
        attribute sensitivity : Real;
        attribute fadingRate : Real;
        attribute maxDoseCapacity : DoseValue;
        attribute trappedCharge : EnergyValue;
    }

    port def RadiationPort {
        in attribute incidentRadiation : DoseValue;
    }

    port def ThermalPort {
        in attribute heatingPower : ISQ::PowerValue;
        out attribute currentTemperature : TemperatureValue;
    }

    port def OpticalPort {
        out attribute emittedLight : LightIntensityValue;
    }

    port def ElectricalPort {
        in attribute supplyVoltage : VoltageValue;
        out attribute signalCurrent : CurrentValue;
    }

    port def DataPort {
        out attribute doseData : DoseRecord;
        in attribute calibrationInput : CalibrationData;
    }

    part def TLDCrystal {
        attribute material : TLDMaterial;
        attribute storedEnergy : EnergyValue = 0.0 [J];
        
        port radiationInput : RadiationPort;
        port thermalInput : ThermalPort;
        port lightOutput : OpticalPort;
    }

    part def HeatingElement {
        attribute maxTemperature : TemperatureValue;
        attribute heatingRate : Real;
        
        port powerInput : ElectricalPort;
        port thermalOutput : ThermalPort;
    }

    part def PhotomultiplierTube {
        attribute gain : Real;
        attribute spectralSensitivity : String;
        attribute darkCurrent : CurrentValue;
        
        port opticalInput : OpticalPort;
        port signalOutput : ElectricalPort;
    }

    part def ControlProcessor {
        attribute processingSpeed : Real;
        attribute calibration : CalibrationData;
        
        port sensorInput : ElectricalPort;
        port dataOutput : DataPort;
    }

    part def DosimeterBadge {
        doc /* Passive wearable component containing TLD crystal that accumulates radiation dose. */
        
        part crystal : TLDCrystal;
        port radiationExposure : RadiationPort;
        
        connection exposureLink connect radiationExposure to crystal.radiationInput;
    }

    part def TLDReader {
        doc /* Active readout device that heats the TLD crystal and measures emitted light. */
        
        part heater : HeatingElement;
        part pmt : PhotomultiplierTube;
        part processor : ControlProcessor;
        port badgeSlot;
        port dataInterface : DataPort;
        
        connection heaterPower connect heater.powerInput;
        connection pmtPower connect pmt.signalOutput to processor.sensorInput;
        connection dataOut connect processor.dataOutput to dataInterface;
    }

    action def AccumulateRadiation {
        in exposedDose : DoseValue;
        in exposureDuration : TimeValue;
        inout crystalEnergy : EnergyValue;
        
        doc /* Crystal absorbs ionizing radiation and traps charge in lattice defects. */
    }

    action def HeatCrystal {
        in targetTemperature : TemperatureValue;
        in heatingDuration : TimeValue;
        out achievedTemperature : TemperatureValue;
        
        doc /* Apply controlled heat to release trapped charge. */
    }

    action def EmitThermoluminescence {
        in temperature : TemperatureValue;
        in storedEnergy : EnergyValue;
        out lightIntensity : LightIntensityValue;
        out remainingEnergy : EnergyValue;
        
        doc /* Heated crystal emits light proportional to trapped charge. */
    }

    action def DetectLight {
        in lightIntensity : LightIntensityValue;
        out electricalSignal : CurrentValue;
        
        doc /* PMT converts light photons to electrical signal. */
    }

    action def CalculateDose {
        in signalIntegral : Real;
        in calibrationData : CalibrationData;
        out computedDose : DoseValue;
        
        doc /* Process signal using calibration curve to determine dose. */
    }

    action def AnnealCrystal {
        in annealingTemperature : TemperatureValue;
        in annealingDuration : TimeValue;
        inout crystalEnergy : EnergyValue;
        
        doc /* High-temperature annealing resets crystal for reuse. */
    }

    action def PerformDoseReadout {
        in badge : DosimeterBadge;
        in calibration : CalibrationData;
        out doseRecord : DoseRecord;
        
        private attribute crystalEnergy : EnergyValue;
        private attribute temperature : TemperatureValue;
        private attribute lightSignal : LightIntensityValue;
        private attribute electricalSignal : CurrentValue;
        private attribute signalIntegral : Real := 0.0;
        private attribute measuredDose : DoseValue;
        
        first start;
        
        then action insertBadge {
            doc /* Place dosimeter badge in reader slot. */
        }
        
        then action heating : HeatCrystal {
            in targetTemperature = 300.0 [K];
            in heatingDuration = 30.0 [s];
            out achievedTemperature;
        }
        
        then assign temperature := heating.achievedTemperature;
        
        then action emission : EmitThermoluminescence {
            in temperature = temperature;
            in storedEnergy = crystalEnergy;
            out lightIntensity;
            out remainingEnergy;
        }
        
        then assign lightSignal := emission.lightIntensity;
        then assign crystalEnergy := emission.remainingEnergy;
        
        then action detection : DetectLight {
            in lightIntensity = lightSignal;
            out electricalSignal;
        }
        
        then assign electricalSignal := detection.electricalSignal;
        then assign signalIntegral := signalIntegral + electricalSignal * 1.0;
        
        then action computation : CalculateDose {
            in signalIntegral = signalIntegral;
            in calibrationData = calibration;
            out computedDose;
        }
        
        then assign measuredDose := computation.computedDose;
        
        then action annealing : AnnealCrystal {
            in annealingTemperature = 400.0 [K];
            in annealingDuration = 60.0 [s];
            inout crystalEnergy;
        }
        
        then action recordResult {
            doc /* Store dose measurement with timestamp and badge ID. */
        }
        
        then assign doseRecord.measuredDose := measuredDose;
        
        then done;
    }

    state def DosimeterLifecycle {
        entry; then Initialized;
        
        state Initialized;
        
        state InField {
            entry action {
                doc /* Badge issued to personnel for radiation monitoring. */
            }
        }
        
        state AccumulatingDose {
            do action {
                doc /* Continuously accumulating radiation exposure. */
            }
        }
        
        state AwaitingReadout {
            entry action {
                doc /* Badge collected from field, ready for analysis. */
            }
        }
        
        state BeingRead {
            do action {
                doc /* Readout process in progress. */
            }
        }
        
        state Annealed {
            entry action {
                doc /* Crystal reset and ready for reuse. */
            }
        }
        
        transition issue first Initialized then InField;
        transition deploy first InField then AccumulatingDose;
        transition collect first AccumulatingDose then AwaitingReadout;
        transition readout first AwaitingReadout then BeingRead;
        transition complete first BeingRead then Annealed;
        transition reissue first Annealed then InField;
    }

    part def ThermoluminescentDosimeter {
        doc /* 
            A thermoluminescent dosimeter (TLD) system measures accumulated ionizing 
            radiation dose by detecting light emitted from a crystalline material when 
            heated after radiation exposure. The system consists of a passive dosimeter 
            badge worn by personnel and an active reader device that performs dose analysis.
        */
        
        part badge : DosimeterBadge {
            exhibit state lifecycle : DosimeterLifecycle;
        }
        
        part reader : TLDReader;
        
        connection badgeInterface connect reader.badgeSlot to badge;
        
        perform action measureDose : PerformDoseReadout {
            in badge = self.badge;
            in calibration : CalibrationData;
            out doseRecord : DoseRecord;
        }
    }

    requirement def DosimetryRequirement {
        doc /* Requirements for radiation dosimetry system performance. */
        subject dosimeter : ThermoluminescentDosimeter;
    }

    requirement <'TLD-REQ-001'> measureAccumulatedDose : DosimetryRequirement {
        doc /* 
            The TLD system shall measure the accumulated absorbed dose of ionizing 
            radiation to which the dosimeter badge has been exposed and provide a 
            quantitative dose reading.
        */
        
        require constraint accuracyConstraint {
            doc /* Dose measurement accuracy shall be within ±10% of true value. */
        }
    }

    requirement <'TLD-REQ-002'> doseRangeRequirement : DosimetryRequirement {
        doc /* 
            The TLD system shall measure radiation doses from 0.1 mGy to 10 Gy 
            across the energy range of common ionizing radiation sources.
        */
    }

    requirement <'TLD-REQ-003'> reproducibilityRequirement : DosimetryRequirement {
        doc /* 
            The TLD system shall provide reproducible measurements with coefficient 
            of variation less than 5% for repeated readouts of identical exposures.
        */
    }

    requirement <'TLD-REQ-004'> fadingRequirement : DosimetryRequirement {
        doc /* 
            The TLD badge shall retain at least 90% of trapped charge for 90 days 
            post-exposure when stored at room temperature.
        */
    }

    requirement <'TLD-REQ-005'> reusabilityRequirement : DosimetryRequirement {
        doc /* 
            The TLD badge shall be reusable for at least 500 readout-annealing 
            cycles without degradation in sensitivity exceeding 10%.
        */
    }

    requirement <'TLD-REQ-006'> nonDestructiveRequirement : DosimetryRequirement {
        doc /* 
            The readout process shall not damage the TLD crystal, allowing the 
            badge to be annealed and reused for subsequent monitoring periods.
        */
    }

    action def MonitorPersonnelExposure {
        doc /* 
            Primary system function: Monitor and quantify cumulative radiation exposure 
            of personnel working in radiation environments to ensure compliance with 
            safety limits and maintain exposure records.
        */
        
        in monitoringPeriod : TimeValue;
        in personnelID : String;
        out totalDose : DoseValue;
        out exposureRecord : DoseRecord;
        
        first start;
        
        then action issueBadge {
            doc /* Assign calibrated TLD badge to personnel. */
        }
        
        then action wearingPeriod {
            doc /* Personnel wears badge during radiation work. */
            in duration = monitoringPeriod;
        }
        
        then action collectBadge {
            doc /* Retrieve badge at end of monitoring period. */
        }
        
        then action performReadout : PerformDoseReadout {
            in badge : DosimeterBadge;
            in calibration : CalibrationData;
            out doseRecord;
        }
        
        then action evaluateDose {
            doc /* Compare measured dose against regulatory limits. */
            in measured = performReadout.doseRecord.measuredDose;
        }
        
        then action archiveRecord {
            doc /* Store dose record in personnel exposure database. */
        }
        
        then assign totalDose := performReadout.doseRecord.measuredDose;
        then assign exposureRecord := performReadout.doseRecord;
        
        then done;
    }
}
