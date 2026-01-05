package IonizationGaugeSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;
    
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def CurrentValue :> ISQ::ElectricCurrentValue;
    attribute def VoltageValue :> ISQ::VoltageValue;
    attribute def TemperatureValue :> ISQ::ThermodynamicTemperatureValue;
    attribute def SensitivityValue :> Real;
    
    enum def GaugeState {
        off;
        warmup;
        measuring;
        fault;
    }
    
    item def GasMolecule;
    item def Electron;
    item def Ion;
    
    port def VacuumPort {
        attribute pressure : PressureValue;
        in item gasFlow : GasMolecule[*];
    }
    
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
    }
    
    port def DataPort {
        out attribute pressureReading : PressureValue;
        out attribute gaugeStatus : GaugeState;
    }
    
    part def Filament {
        doc /* Thermionic electron emitter heated to produce electron beam */
        
        attribute emissionCurrent : CurrentValue;
        attribute heatingVoltage : VoltageValue;
        attribute operatingTemperature : TemperatureValue;
        
        port power : ElectricalPort;
        port electronOutput {
            out item electrons : Electron[*];
        }
        
        action emitElectrons {
            doc /* Heat filament to thermionic emission temperature and release electrons */
        }
    }
    
    part def AcceleratingGrid {
        doc /* Positively biased grid that accelerates electrons toward ionization region */
        
        attribute gridVoltage : VoltageValue;
        attribute transparency : Real;
        
        port power : ElectricalPort;
        
        action accelerateElectrons {
            doc /* Apply positive potential to accelerate electrons */
        }
    }
    
    part def IonizationRegion {
        doc /* Volume where energetic electrons collide with gas molecules to create ions */
        
        attribute ionizationEfficiency : Real;
        attribute regionVolume : ISQ::VolumeValue;
        
        port vacuumInterface : VacuumPort;
        
        action ionizeGas {
            doc /* Electron-molecule collisions produce positive ions */
            in item gasIn : GasMolecule[*];
            in item electronsIn : Electron[*];
            out item ionsOut : Ion[*];
        }
    }
    
    part def IonCollector {
        doc /* Negatively biased electrode that collects positive ions */
        
        attribute collectorVoltage : VoltageValue;
        attribute ionCurrent : CurrentValue;
        attribute collectionEfficiency : Real;
        
        port power : ElectricalPort;
        port ionInput {
            in item ions : Ion[*];
        }
        port currentOutput : ElectricalPort;
        
        action collectIons {
            doc /* Attract and collect positive ions to generate measurable current */
        }
    }
    
    part def Electrometer {
        doc /* Ultra-sensitive current amplifier for measuring ion current */
        
        attribute gain : Real;
        attribute inputImpedance : Real;
        attribute measuredCurrent : CurrentValue;
        
        port signalIn : ElectricalPort;
        port signalOut : ElectricalPort;
        
        action amplifySignal {
            doc /* Amplify weak ion current to measurable voltage */
        }
    }
    
    part def ControllerUnit {
        doc /* Manages gauge operation and converts ion current to pressure */
        
        attribute calibrationConstant : SensitivityValue;
        attribute currentState : GaugeState;
        attribute warmupDuration : ISQ::DurationValue;
        
        port sensorInput : ElectricalPort;
        port filamentControl : ElectricalPort;
        port gridControl : ElectricalPort;
        port collectorControl : ElectricalPort;
        port dataOutput : DataPort;
        
        action calculatePressure {
            doc /* Convert ion current to pressure using gauge sensitivity */
            in ionCurrent : CurrentValue;
            in sensitivity : SensitivityValue;
            out pressure : PressureValue;
        }
        
        state gaugeOperationControl {
            entry; then off;
            
            state off {
                doc /* Gauge is powered down, no measurement active */
            }
            
            state warmup {
                doc /* Filament heating to stable emission temperature */
            }
            
            state measuring {
                doc /* Active pressure measurement in progress */
            }
            
            state fault {
                doc /* Error condition detected, safe shutdown initiated */
            }
            
            transition powerOn first off accept at off then warmup;
            transition warmupComplete accept at warmup then measuring;
            transition errorDetected accept at measuring then fault;
            transition faultFromWarmup accept at warmup then fault;
            transition reset accept at fault then off;
            transition shutdown accept at measuring then off;
        }
    }
    
    part def PowerSupply {
        doc /* Provides regulated voltages for gauge operation */
        
        attribute inputVoltage : VoltageValue;
        
        port mainPower : ElectricalPort;
        port filamentPower : ElectricalPort;
        port gridPower : ElectricalPort;
        port collectorPower : ElectricalPort;
        
        action regulatePower {
            doc /* Generate stable regulated voltages for all gauge components */
        }
    }
    
    part def IonizationGauge {
        doc /* Hot cathode ionization gauge for ultra-high vacuum pressure measurement */
        
        attribute measurementRange : PressureValue[2];
        attribute sensitivity : SensitivityValue;
        attribute accuracy : Real;
        
        part filament : Filament {
            attribute :>> emissionCurrent = 4.0 [mA];
            attribute :>> heatingVoltage = 3.5 [V];
            attribute :>> operatingTemperature = 2500.0 [K];
        }
        
        part grid : AcceleratingGrid {
            attribute :>> gridVoltage = 180.0 [V];
            attribute :>> transparency = 0.85;
        }
        
        part ionRegion : IonizationRegion {
            attribute :>> ionizationEfficiency = 0.75;
        }
        
        part collector : IonCollector {
            attribute :>> collectorVoltage = -30.0 [V];
            attribute :>> collectionEfficiency = 0.90;
        }
        
        part electrometer : Electrometer {
            attribute :>> gain = 1.0e11;
            attribute :>> inputImpedance = 1.0e14;
        }
        
        part controller : ControllerUnit {
            attribute :>> calibrationConstant = 10.0;
            attribute :>> currentState = GaugeState::off;
            attribute :>> warmupDuration = 30.0 [s];
        }
        
        part powerSupply : PowerSupply {
            attribute :>> inputVoltage = 24.0 [V];
        }
        
        port vacuumConnection : VacuumPort;
        port powerInput : ElectricalPort;
        port dataOutput : DataPort;
        
        connection powerDistribution1 connect powerSupply.filamentPower to filament.power;
        connection powerDistribution2 connect powerSupply.gridPower to grid.power;
        connection powerDistribution3 connect powerSupply.collectorPower to collector.power;
        connection controlFilament connect controller.filamentControl to filament.power;
        connection controlGrid connect controller.gridControl to grid.power;
        connection controlCollector connect controller.collectorControl to collector.power;
        connection collectorToElectrometer connect collector.currentOutput to electrometer.signalIn;
        connection electrometerToController connect electrometer.signalOut to controller.sensorInput;
        connection vacuumInterface connect vacuumConnection to ionRegion.vacuumInterface;
        connection dataInterface connect controller.dataOutput to dataOutput;
        connection mainPowerConnection connect powerInput to powerSupply.mainPower;
        
        action measurePressure {
            doc /* Primary function: Measure ultra-high vacuum pressure by ionizing residual gas and measuring ion current */
            
            first start;
            
            then action heatFilament : Filament::emitElectrons {
                doc /* Thermionic emission produces electron beam */
            }
            
            then action accelerate : AcceleratingGrid::accelerateElectrons {
                doc /* Electrons gain kinetic energy from grid potential */
            }
            
            then action ionize : IonizationRegion::ionizeGas {
                doc /* Energetic electrons collide with gas molecules creating positive ions */
            }
            
            then action collect : IonCollector::collectIons {
                doc /* Positive ions attracted to negative collector generate ion current */
            }
            
            then action amplify : Electrometer::amplifySignal {
                doc /* Ion current amplified to measurable voltage signal */
            }
            
            then action compute : ControllerUnit::calculatePressure {
                doc /* Ion current converted to pressure using calibration constant */
            }
            
            then done;
        }
    }
    
    requirement <'REQ-IG-001'> measureUHVPressure {
        doc /* The ionization gauge shall measure pressure in the ultra-high vacuum range from 1e-10 Pa to 1e-3 Pa */
        
        subject gauge : IonizationGauge;
        
        require constraint pressureRange {
            gauge.measurementRange[1] == 1.0e-10 [Pa] and
            gauge.measurementRange[2] == 1.0e-3 [Pa]
        }
    }
    
    requirement <'REQ-IG-002'> ionCurrentProportionality {
        doc /* The ion current shall be directly proportional to gas pressure for accurate measurement */
        
        subject gauge : IonizationGauge;
    }
    
    requirement <'REQ-IG-003'> measurementAccuracy {
        doc /* The gauge shall maintain measurement accuracy within 10% across operating range */
        
        subject gauge : IonizationGauge;
        
        require constraint accuracyRequirement {
            gauge.accuracy >= 0.90
        }
    }
    
    requirement <'REQ-IG-004'> stableEmission {
        doc /* The filament shall provide stable electron emission current during measurement */
        
        subject filament : IonizationGauge::filament;
        
        require constraint emissionStability {
            filament.emissionCurrent >= 1.0 [mA] and
            filament.emissionCurrent <= 10.0 [mA]
        }
    }
    
    requirement <'REQ-IG-005'> gridVoltageStability {
        doc /* The accelerating grid voltage shall remain stable to ensure consistent ionization */
        
        subject grid : IonizationGauge::grid;
        
        require constraint voltageStability {
            grid.gridVoltage >= 150.0 [V] and
            grid.gridVoltage <= 200.0 [V]
        }
    }
    
    part ionizationGaugeSystem : IonizationGauge {
        attribute :>> measurementRange = (1.0e-10 [Pa], 1.0e-3 [Pa]);
        attribute :>> sensitivity = 10.0;
        attribute :>> accuracy = 0.95;
    }
    
    satisfy measureUHVPressure by ionizationGaugeSystem;
    satisfy ionCurrentProportionality by ionizationGaugeSystem;
    satisfy measurementAccuracy by ionizationGaugeSystem;
    satisfy stableEmission by ionizationGaugeSystem.filament;
    satisfy gridVoltageStability by ionizationGaugeSystem.grid;
}
