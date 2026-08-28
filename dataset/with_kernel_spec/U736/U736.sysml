package 'Hot-Cathode Ionization Gauge System' {
    package Definitions {
        private import ScalarValues::Real;

        item def Electron;
        item def GasMolecule;
        item def Ion;

        attribute def PowerOn;
        attribute def WarmupComplete;
        attribute def PowerOff;
        attribute def ErrorDetected;
        attribute def Reset;

        enum def ControlCommand {
            start;
            stop;
            reset;
        }

        attribute def Voltage :> Real;
        attribute def Current :> Real;
        attribute def Pressure :> Real;
        attribute def Temperature :> Real;

        port def VoltagePort {
            attribute voltage : Voltage;
        }
        port def ElectricalPowerPort {
            attribute voltage : Voltage;
            attribute current : Current;
        }
        port def ElectronPort {
            item electrons : Electron;
        }
        port def GasPort {
            item gas : GasMolecule;
        }
        port def IonPort {
            item ions : Ion;
        }
        port def CurrentPort {
            attribute current : Current;
        }
        port def PressurePort {
            attribute pressure : Pressure;
        }
        port def ControlPort {
            attribute command : ControlCommand;
        }

        state def GaugeControllerStates {
            state off;
            state warmup;
            state measuring;
            state fault;
            transition first off then warmup accept PowerOn;
            transition first warmup then measuring accept WarmupComplete;
            transition first measuring then off accept PowerOff;
            transition first warmup then fault accept ErrorDetected;
            transition first measuring then fault accept ErrorDetected;
            transition first fault then off accept Reset;
        }

        action def EmitElectrons {
            in filamentVoltage : Voltage;
            out electrons : Electron;
        }
        action def AccelerateElectrons {
            in electrons : Electron;
            in gridVoltage : Voltage;
            out acceleratedElectrons : Electron;
        }
        action def IonizeGas {
            in electrons : Electron;
            in gas : GasMolecule;
            out ions : Ion;
        }
        action def CollectIons {
            in ions : Ion;
            in collectorVoltage : Voltage;
            out ionCurrent : Current;
        }
        action def AmplifyCurrent {
            in ionCurrent : Current;
            out amplifiedCurrent : Current;
        }
        action def CalculatePressure {
            in amplifiedCurrent : Current;
            in calibrationConstant : Real;
            out pressure : Pressure;
        }
        action def MeasurePressure {
            in filamentVoltage : Voltage;
            in gridVoltage : Voltage;
            in collectorVoltage : Voltage;
            in gas : GasMolecule;
            in calibrationConstant : Real;
            out pressure : Pressure;

            action emit : EmitElectrons {
                in filamentVoltage = MeasurePressure::filamentVoltage;
            }
            flow emit.electrons to accelerate.electrons;
            action accelerate : AccelerateElectrons {
                in gridVoltage = MeasurePressure::gridVoltage;
            }
            flow accelerate.acceleratedElectrons to ionize.electrons;
            action ionize : IonizeGas {
                in gas = MeasurePressure::gas;
            }
            flow ionize.ions to collect.ions;
            action collect : CollectIons {
                in collectorVoltage = MeasurePressure::collectorVoltage;
            }
            flow collect.ionCurrent to amplify.ionCurrent;
            action amplify : AmplifyCurrent;
            flow amplify.amplifiedCurrent to calculate.amplifiedCurrent;
            action calculate : CalculatePressure {
                in calibrationConstant = MeasurePressure::calibrationConstant;
            }
            bind calculate.pressure = MeasurePressure::pressure;
        }

        part def Filament {
            port powerIn : VoltagePort;
            port electronOut : ElectronPort;
            attribute temperature : Temperature;
        }
        part def AcceleratingGrid {
            port powerIn : VoltagePort;
            port electronIn : ElectronPort;
            port electronOut : ElectronPort;
        }
        part def IonizationRegion {
            port vacuumInlet : GasPort;
            port electronIn : ElectronPort;
            port ionOut : IonPort;
        }
        part def IonCollector {
            port biasIn : VoltagePort;
            port ionIn : IonPort;
            port currentOut : CurrentPort;
        }
        part def Electrometer {
            port currentIn : CurrentPort;
            port signalOut : CurrentPort;
        }
        part def ControllerUnit {
            port powerIn : ElectricalPowerPort;
            port signalIn : CurrentPort;
            port pressureOut : PressurePort;
            port controlIn : ControlPort;
            port controlOut : ControlPort;
            attribute calibrationConstant : Real;
            exhibit state controllerState : GaugeControllerStates;
        }
        part def PowerSupply {
            port inputPower : ElectricalPowerPort;
            port filamentPower : VoltagePort;
            port gridPower : VoltagePort;
            port collectorBias : VoltagePort;
            port controllerPower : ElectricalPowerPort;
            port controlIn : ControlPort;
        }
        part def VacuumChamber {
            port gasOut : GasPort;
            attribute pressure : Pressure;
        }
        part def ElectricalPowerSource {
            port output : ElectricalPowerPort;
        }

        part def HotCathodeGaugeSystem {
            port powerInlet : ElectricalPowerPort;
            port vacuumFlange : GasPort;
            port pressureReadout : PressurePort;
            port externalControl : ControlPort;

            part filament : Filament;
            part acceleratingGrid : AcceleratingGrid;
            part ionizationRegion : IonizationRegion;
            part ionCollector : IonCollector;
            part electrometer : Electrometer;
            part controller : ControllerUnit;
            part powerSupply : PowerSupply;

            connect powerInlet to powerSupply.inputPower;
            connect vacuumFlange to ionizationRegion.vacuumInlet;
            connect powerSupply.filamentPower to filament.powerIn;
            connect powerSupply.gridPower to acceleratingGrid.powerIn;
            connect powerSupply.collectorBias to ionCollector.biasIn;
            connect powerSupply.controllerPower to controller.powerIn;
            connect controller.controlOut to powerSupply.controlIn;
            connect externalControl to controller.controlIn;
            connect filament.electronOut to acceleratingGrid.electronIn;
            connect acceleratingGrid.electronOut to ionizationRegion.electronIn;
            connect ionizationRegion.ionOut to ionCollector.ionIn;
            connect ionCollector.currentOut to electrometer.currentIn;
            connect electrometer.signalOut to controller.signalIn;
            connect controller.pressureOut to pressureReadout;

            perform action measurePressure : MeasurePressure {
                in filamentVoltage = powerSupply.filamentPower.voltage;
                in gridVoltage = powerSupply.gridPower.voltage;
                in collectorVoltage = powerSupply.collectorBias.voltage;
                in gas = ionizationRegion.vacuumInlet.gas;
                in calibrationConstant = controller.calibrationConstant;
                out pressure;
            }
            bind measurePressure.pressure = controller.pressureOut.pressure;
        }
    }

    package Usages {
        private import Definitions::*;
        part powerSource : ElectricalPowerSource;
        part vacuumChamber : VacuumChamber;
        part gauge : HotCathodeGaugeSystem;
        connect powerSource.output to gauge.powerInlet;
        connect vacuumChamber.gasOut to gauge.vacuumFlange;
    }

    package Requirements {
        private import Definitions::*;
        requirement def MeasureUHVPressure {
            subject gaugeSystem : HotCathodeGaugeSystem;
            doc "The hot-cathode ionization gauge system shall measure ultra-high vacuum pressure by ionizing residual gas molecules and measuring the resulting ion current.";
        }
        requirement def IonizeResidualGas {
            subject ionizationRegion : IonizationRegion;
            doc "High-energy electrons emitted by the filament shall ionize residual gas molecules in the ionization region.";
        }
        requirement def AmplifyIonCurrent {
            subject electrometer : Electrometer;
            doc "The electrometer shall amplify the weak ion current into a measurable signal before the controller calculates pressure.";
        }
        requirement def ManageGaugeStates {
            subject controller : ControllerUnit;
            doc "The controller shall manage off, warmup, measuring, and fault operational states.";
        }
    }
}
