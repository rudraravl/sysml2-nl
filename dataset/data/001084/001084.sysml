package HotFilamentIonizationGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def VacuumPressure :> ISQ::PressureValue;
    attribute def ElectronEmissionCurrent :> ISQ::ElectricCurrentValue;
    attribute def IonCurrent :> ISQ::ElectricCurrentValue;
    attribute def FilamentTemperature :> ISQ::ThermodynamicTemperatureValue;
    attribute def GridVoltage :> ISQ::VoltageValue;
    attribute def CollectorVoltage :> ISQ::VoltageValue;
    attribute def FilamentVoltage :> ISQ::VoltageValue;
    attribute def SensitivityFactor :> Real;
    
    item def GasMolecule;
    item def Electron;
    item def PositiveIon;
    
    port def VacuumInterfacePort {
        in attribute gasMolecules : GasMolecule[*];
        out attribute measuredPressure : VacuumPressure;
    }
    
    port def ElectricalSupplyPort {
        in attribute appliedVoltage : ISQ::VoltageValue;
        out attribute measuredCurrent : ISQ::ElectricCurrentValue;
    }
    
    port def SignalPort {
        out attribute pressureSignal : VacuumPressure;
    }
    
    part def HeatedFilament {
        doc /* Tungsten or thoriated iridium filament heated to emit electrons via thermionic emission. */
        
        attribute operatingTemperature : FilamentTemperature;
        attribute emissionCurrent : ElectronEmissionCurrent;
        port powerInput : ElectricalSupplyPort;
        
        action emitElectrons {
            in filamentVoltage : FilamentVoltage;
            in targetTemperature : FilamentTemperature;
            out electrons : Electron[*];
            out emissionRate : ElectronEmissionCurrent;
        }
    }
    
    part def AcceleratingGrid {
        doc /* Positively biased grid that accelerates emitted electrons toward the ionization region. */
        
        attribute gridBias : GridVoltage;
        port powerInput : ElectricalSupplyPort;
        
        action accelerateElectrons {
            in electrons : Electron[*];
            in gridVoltage : GridVoltage;
            out acceleratedElectrons : Electron[*];
        }
    }
    
    part def IonizationRegion {
        doc /* Volume where energetic electrons collide with gas molecules to produce positive ions. */
        
        port vacuumExposure : VacuumInterfacePort;
        
        action ionizeGasMolecules {
            in gasMolecules : GasMolecule[*];
            in energeticElectrons : Electron[*];
            out positiveIons : PositiveIon[*];
            out ionizationRate : Real;
        }
    }
    
    part def IonCollector {
        doc /* Negatively biased electrode that attracts and collects positive ions, generating measurable current. */
        
        attribute collectorBias : CollectorVoltage;
        attribute collectedIonCurrent : IonCurrent;
        port powerInput : ElectricalSupplyPort;
        
        action collectIons {
            in positiveIons : PositiveIon[*];
            in collectorVoltage : CollectorVoltage;
            out ionCurrent : IonCurrent;
        }
    }
    
    part def SignalProcessor {
        doc /* Electronics that convert ion current to pressure reading using calibrated sensitivity factor. */
        
        attribute calibrationConstant : SensitivityFactor;
        
        action convertCurrentToPressure {
            in ionCurrent : IonCurrent;
            in emissionCurrent : ElectronEmissionCurrent;
            in sensitivity : SensitivityFactor;
            out pressure : VacuumPressure;
        }
    }
    
    part def PowerSupplyUnit {
        doc /* Provides regulated voltages for filament heating, grid acceleration, and collector bias. */
        
        attribute filamentSupply : FilamentVoltage;
        attribute gridSupply : GridVoltage;
        attribute collectorSupply : CollectorVoltage;
        
        action supplyPower {
            out filamentVoltage : FilamentVoltage;
            out gridVoltage : GridVoltage;
            out collectorVoltage : CollectorVoltage;
        }
    }
    
    part def ProtectionCircuit {
        doc /* Monitors pressure and automatically shuts down filament at high pressure to prevent burnout. */
        
        attribute pressureThreshold : VacuumPressure;
        attribute filamentEnabled : Boolean;
        
        action monitorAndProtect {
            in currentPressure : VacuumPressure;
            in threshold : VacuumPressure;
            out shutdownSignal : Boolean;
        }
    }
    
    part def HotFilamentIonizationGauge {
        doc /* 
            A hot filament ionization gauge measures ultra-high vacuum pressure by ionizing 
            residual gas molecules with electrons emitted from a heated filament. The resulting 
            ion current, collected at a negatively biased electrode, is proportional to gas 
            density and thus pressure. This gauge operates in the pressure range from 10^-10 Pa 
            to 10^-3 Pa, providing accurate vacuum measurement for scientific and industrial applications.
        */
        
        port vacuumConnection : VacuumInterfacePort;
        port pressureOutput : SignalPort;
        
        part filament : HeatedFilament {
            operatingTemperature = 2500.0;
            emissionCurrent = 4.0e-3;
        }
        
        part grid : AcceleratingGrid {
            gridBias = 180.0;
        }
        
        part ionizationChamber : IonizationRegion;
        
        part collector : IonCollector {
            collectorBias = -30.0;
        }
        
        part processor : SignalProcessor {
            calibrationConstant = 15.0;
        }
        
        part powerSupply : PowerSupplyUnit {
            filamentSupply = 5.0;
            gridSupply = 180.0;
            collectorSupply = -30.0;
        }
        
        part protection : ProtectionCircuit {
            pressureThreshold = 1.0e-3;
            filamentEnabled = true;
        }
        
        connection filamentPower connect powerSupply.supplyPower.filamentVoltage to filament.powerInput.appliedVoltage;
        connection gridPower connect powerSupply.supplyPower.gridVoltage to grid.powerInput.appliedVoltage;
        connection collectorPower connect powerSupply.supplyPower.collectorVoltage to collector.powerInput.appliedVoltage;
        
        action measurePressure {
            first start;
            
            then action heatFilament : filament.emitElectrons {
                in filamentVoltage = powerSupply.filamentSupply;
                in targetTemperature = filament.operatingTemperature;
                out electrons;
                out emissionRate;
            }
            
            then action accelerate : grid.accelerateElectrons {
                in electrons = heatFilament.electrons;
                in gridVoltage = powerSupply.gridSupply;
                out acceleratedElectrons;
            }
            
            then action ionize : ionizationChamber.ionizeGasMolecules {
                in gasMolecules = vacuumConnection.gasMolecules;
                in energeticElectrons = accelerate.acceleratedElectrons;
                out positiveIons;
                out ionizationRate;
            }
            
            then action collect : collector.collectIons {
                in positiveIons = ionize.positiveIons;
                in collectorVoltage = powerSupply.collectorSupply;
                out ionCurrent;
            }
            
            then action convert : processor.convertCurrentToPressure {
                in ionCurrent = collect.ionCurrent;
                in emissionCurrent = heatFilament.emissionRate;
                in sensitivity = processor.calibrationConstant;
                out pressure;
            }
            
            then action protect : protection.monitorAndProtect {
                in currentPressure = convert.pressure;
                in threshold = protection.pressureThreshold;
                out shutdownSignal;
            }
            
            then assign vacuumConnection.measuredPressure := convert.pressure;
            then assign pressureOutput.pressureSignal := convert.pressure;
            then done;
        }
    }
    
    state def GaugeOperationalState {
        entry; then warmUp;
        
        state warmUp {
            doc /* Filament heating phase to reach stable emission temperature. */
        }
        then stabilize;
        
        state stabilize {
            doc /* Grid and collector voltages stabilizing for accurate measurement. */
        }
        then normalOperation;
        
        state normalOperation {
            doc /* Active pressure measurement with continuous ion current monitoring. */
            
            transition highPressureDetected
                first normalOperation
                accept at when measuredPressure > 1.0e-3
                then emergencyShutdown;
        }
        
        state emergencyShutdown {
            doc /* Filament power cut to prevent burnout from excessive gas load. */
            
            transition pressureRecovered
                first emergencyShutdown
                accept at when measuredPressure < 1.0e-4
                then normalOperation;
        }
        
        state degassingMode {
            doc /* High temperature operation to remove adsorbed gases from electrodes. */
            
            transition degassingComplete
                first degassingMode
                accept at when filamentTemperature > 2000.0
                then normalOperation;
        }
        
        attribute measuredPressure : VacuumPressure;
        attribute filamentTemperature : FilamentTemperature;
    }
    
    part gaugeInstance : HotFilamentIonizationGauge {
        exhibit state operationalState : GaugeOperationalState;
    }
    
    requirement def MeasurementRangeRequirement {
        doc /* The gauge shall accurately measure vacuum pressure from 10^-10 Pa to 10^-3 Pa. */
        
        subject gauge : HotFilamentIonizationGauge;
        
        require constraint {
            gauge.vacuumConnection.measuredPressure >= 1.0e-10 and
            gauge.vacuumConnection.measuredPressure <= 1.0e-3
        }
    }
    
    requirement def FilamentProtectionRequirement {
        doc /* The gauge shall automatically disable filament power when pressure exceeds 10^-3 Pa to prevent filament burnout. */
        
        subject gauge : HotFilamentIonizationGauge;
        
        require constraint {
            gauge.vacuumConnection.measuredPressure > 1.0e-3 implies
            gauge.protection.filamentEnabled == false
        }
    }
    
    requirement def LinearResponseRequirement {
        doc /* Ion current shall be linearly proportional to gas pressure over the measurement range. */
        
        subject gauge : HotFilamentIonizationGauge;
        
        require constraint {
            gauge.collector.collectedIonCurrent == 
            gauge.processor.calibrationConstant * 
            gauge.filament.emissionCurrent * 
            gauge.vacuumConnection.measuredPressure
        }
    }
    
    requirement def EmissionStabilityRequirement {
        doc /* Electron emission current shall remain stable within ±5% during measurement. */
        
        subject gauge : HotFilamentIonizationGauge;
        
        require constraint {
            gauge.filament.emissionCurrent >= 3.8e-3 and
            gauge.filament.emissionCurrent <= 4.2e-3
        }
    }
    
    requirement def OperatingTemperatureRequirement {
        doc /* Filament shall operate at temperature between 2300 K and 2700 K for optimal emission. */
        
        subject gauge : HotFilamentIonizationGauge;
        
        require constraint {
            gauge.filament.operatingTemperature >= 2300.0 and
            gauge.filament.operatingTemperature <= 2700.0
        }
    }
    
    requirement systemRequirements {
        doc /* Top-level functional and safety requirements for hot filament ionization gauge. */
        
        require measurementRange : MeasurementRangeRequirement;
        require filamentProtection : FilamentProtectionRequirement;
        require linearResponse : LinearResponseRequirement;
        require emissionStability : EmissionStabilityRequirement;
        require operatingTemperature : OperatingTemperatureRequirement;
    }
}
