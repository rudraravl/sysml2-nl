package HotFilamentIonizationGaugeModel {
    import ScalarValues::*;
    import ISQ::*;
    import ISQElectromagnetism::*;
    import ISQThermodynamics::*;

    // Value Types
    def PressureValue :> Real { unit = "Pa"; }
    def TemperatureValue :> Real { unit = "K"; }
    def VoltageValue :> Real { unit = "V"; }
    def CurrentValue :> Real { unit = "A"; }
    def SensitivityFactor :> Real { unit = "1/Pa"; }

    // Items
    item def Electron;
    item def GasMolecule;
    item def PositiveIon;

    // Ports
    port def ElectronFlowPort {
        out item electrons : Electron;
    }
    port def IonFlowPort {
        out item ions : PositiveIon;
    }
    port def GasExposurePort {
        inout item gas : GasMolecule;
    }
    port def ElectricalSignalPort {
        out current : CurrentValue;
    }
    port def PowerPort {
        inout voltage : VoltageValue;
    }
    port def PressureMonitorPort {
        out pressure : PressureValue;
    }
    port def ControlPort {
        out command : String;
    }

    // Parts
    part def HeatedFilament {
        attribute temperature : TemperatureValue;
        port electronOut : ElectronFlowPort;
        port powerIn : PowerPort;
    }

    part def AcceleratingGrid {
        attribute voltage : VoltageValue;
        port electronIn : ElectronFlowPort;
        port electronOut : ElectronFlowPort;
        port powerIn : PowerPort;
    }

    part def IonizationRegion {
        port electronIn : ElectronFlowPort;
        port gasExposure : GasExposurePort;
        port ionOut : IonFlowPort;
    }

    part def IonCollector {
        attribute voltage : VoltageValue;
        port ionIn : IonFlowPort;
        port currentOut : ElectricalSignalPort;
        port powerIn : PowerPort;
    }

    part def SignalProcessor {
        attribute sensitivity : SensitivityFactor;
        port currentIn : ElectricalSignalPort;
        port pressureOut : PressureMonitorPort;
    }

    part def PowerSupplyUnit {
        port filamentPower : PowerPort;
        port gridPower : PowerPort;
        port collectorPower : PowerPort;
        port controlIn : ControlPort;
    }

    part def ProtectionCircuit {
        attribute safeThreshold : PressureValue = 1e-3 [Pa];
        port pressureIn : PressureMonitorPort;
        port controlOut : ControlPort;
    }

    // The main system
    part def HotFilamentIonizationGauge {
        port vacuumPort : GasExposurePort;
        port measurementPort : PressureMonitorPort;

        part filament : HeatedFilament;
        part grid : AcceleratingGrid;
        part ionizationRegion : IonizationRegion;
        part collector : IonCollector;
        part signalProcessor : SignalProcessor;
        part powerSupply : PowerSupplyUnit;
        part protectionCircuit : ProtectionCircuit;

        // Connections
        connect filament.electronOut to grid.electronIn;
        connect grid.electronOut to ionizationRegion.electronIn;
        connect vacuumPort to ionizationRegion.gasExposure;
        connect ionizationRegion.ionOut to collector.ionIn;
        connect collector.currentOut to signalProcessor.currentIn;
        connect signalProcessor.pressureOut to measurementPort;
        connect signalProcessor.pressureOut to protectionCircuit.pressureIn;
        connect protectionCircuit.controlOut to powerSupply.controlIn;
        connect powerSupply.filamentPower to filament.powerIn;
        connect powerSupply.gridPower to grid.powerIn;
        connect powerSupply.collectorPower to collector.powerIn;

        // State Machine
        state def GaugeStates {
            state warmUp;
            state normalOperation;
            state emergencyShutdown;

            transition warmUp to normalOperation when filament.temperature >= 2500 [K];
            transition normalOperation to emergencyShutdown when signalProcessor.pressureOut.pressure > protectionCircuit.safeThreshold;
            transition emergencyShutdown to warmUp when signalProcessor.pressureOut.pressure < protectionCircuit.safeThreshold / 2;
        }

        exhibit state behavior : GaugeStates;

        // Requirements
        requirement def MeasureVacuumRequirement {
            doc "The gauge shall measure ultra-high vacuum pressures."
            subject gauge : HotFilamentIonizationGauge;
            objective {
                assert gauge.signalProcessor.pressureOut.pressure <= 1e-9 [Pa];
            }
        }

        requirement def SafetyShutdownRequirement {
            doc "The protection circuit shall shut down the filament if pressure exceeds safe threshold."
            subject circuit : ProtectionCircuit;
            objective {
                assert circuit.pressureIn.pressure > circuit.safeThreshold implies circuit.controlOut.command == "Shutdown";
            }
        }
    }
}
