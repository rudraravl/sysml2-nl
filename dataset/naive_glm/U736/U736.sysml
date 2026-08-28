package HotCathodeIonizationGauge {

import ScalarValues::*;

// ===== Units =====
unit pascal;
unit volt;
unit ampere;
unit second;
unit degreeCelsius;
unit watt;
unit ohm;

// ===== Value Types =====
value type Pressure :> Real {
    unit pascal;
    constraint { self >= 0; }
}

value type Voltage :> Real {
    unit volt;
}

value type Current :> Real {
    unit ampere;
}

value type Temperature :> Real {
    unit degreeCelsius;
}

value type Duration :> Real {
    unit second;
}

value type Power :> Real {
    unit watt;
}

value type Resistance :> Real {
    unit ohm;
}

value type CalibrationFactor :> Real;

// ===== Item Definitions =====
item def Electron;

item def GasMolecule;

item def PositiveIon;

item def VacuumGasMixture {
    attribute pressure : Pressure;
    attribute temperature : Temperature;
    ref item molecules : GasMolecule[0..*];
}

// ===== Port Definitions =====
port def ElectronEmissionPort {
    out item electrons : Electron;
}

port def ElectronAcceptPort {
    in item electrons : Electron;
}

port def IonEmissionPort {
    out item ions : PositiveIon;
}

port def IonAcceptPort {
    in item ions : PositiveIon;
}

port def IonCurrentPort {
    out attribute ionCurrent : Current;
}

port def IonCurrentInputPort {
    in attribute ionCurrent : Current;
}

port def AmplifiedSignalPort {
    out attribute signal : Current;
}

port def AmplifiedSignalInputPort {
    in attribute signal : Current;
}

port def PowerOutputPort {
    out attribute suppliedVoltage : Voltage;
}

port def PowerInputPort {
    in attribute suppliedVoltage : Voltage;
}

port def VacuumInterfacePort {
    ref item gasMixture : VacuumGasMixture;
    attribute chamberPressure : Pressure;
}

port def PressureOutputPort {
    out attribute measuredPressure : Pressure;
}

port def CommandInputPort {
    in attribute command : String;
    in attribute parameter : Real;
}

port def StatusOutputPort {
    out attribute status : String;
    out attribute errorCode : Integer;
}

// ===== Action Definitions =====
action def EmitElectrons {
    in attribute filamentTemperature : Temperature;
    in attribute emissionCurrentSetting : Current;
    out item emittedElectrons : Electron;
}

action def AccelerateElectrons {
    in item inputElectrons : Electron;
    in attribute gridVoltage : Voltage;
    out item acceleratedElectrons : Electron;
}

action def IonizeGasMolecules {
    in item electrons : Electron;
    ref item gasMixture : VacuumGasMixture;
    out item ions : PositiveIon;
}

action def CollectIons {
    in item ions : PositiveIon;
    in attribute collectorVoltage : Voltage;
    out attribute ionCurrent : Current;
}

action def AmplifyCurrent {
    in attribute inputCurrent : Current;
    in attribute gain : Real;
    out attribute outputSignal : Current;
}

action def ComputePressure {
    in attribute amplifiedSignal : Current;
    in attribute calibrationConstant : CalibrationFactor;
    out attribute pressure : Pressure;
}

action def RegulatePower {
    in attribute mainsVoltage : Voltage;
    out attribute filamentSupply : Voltage;
    out attribute gridSupply : Voltage;
    out attribute collectorSupply : Voltage;
}

// ===== Part Definitions =====

part def Filament {
    attribute nominalTemperature : Temperature = 1800 [degreeCelsius];
    attribute emissionCurrent : Current = 5e-3 [ampere];
    attribute maxPower : Power = 5 [watt];
    port powerInput : PowerInputPort;
    port electronOutput : ElectronEmissionPort;
    action emitElectrons : EmitElectrons;
}

part def AcceleratingGrid {
    attribute gridVoltage : Voltage = 150 [volt];
    port powerInput : PowerInputPort;
    port electronInput : ElectronAcceptPort;
    port electronOutput : ElectronEmissionPort;
    action accelerateElectrons : AccelerateElectrons;
}

part def IonizationRegion {
    port electronInput : ElectronAcceptPort;
    port vacuumInterface : VacuumInterfacePort;
    port ionOutput : IonEmissionPort;
    action ionizeGas : IonizeGasMolecules;
}

part def IonCollector {
    attribute collectorVoltage : Voltage = -150 [volt];
    port powerInput : PowerInputPort;
    port ionInput : IonAcceptPort;
    port currentOutput : IonCurrentPort;
    action collectIons : CollectIons;
}

part def Electrometer {
    attribute gain : Real = 1e8;
    attribute inputImpedance : Resistance = 1e12 [ohm];
    attribute bandwidth : Real = 100;
    port currentInput : IonCurrentInputPort;
    port signalOutput : AmplifiedSignalPort;
    action amplify : AmplifyCurrent;
}

part def ControllerUnit {
    attribute calibrationConstant : CalibrationFactor = 1.33e-2;
    attribute warmupDuration : Duration = 60 [second];
    attribute reportedPressure : Pressure;
    attribute warmupTimer : Duration = 0 [second];
    attribute faultDetected : Boolean = false;
    attribute errorCode : Integer = 0;
    port signalInput : AmplifiedSignalInputPort;
    port pressureOutput : PressureOutputPort;
    port commandInput : CommandInputPort;
    port statusOutput : StatusOutputPort;
    action computePressure : ComputePressure;

    state controllerState {
        state off {
            entry { statusOutput.status = "off"; }
        }
        state warmup {
            entry { statusOutput.status = "warmup"; }
            do { warmupTimer = warmupTimer + 1 [second]; }
            exit { warmupTimer = 0 [second]; }
        }
        state measuring {
            entry { statusOutput.status = "measuring"; }
            do { computePressure; }
        }
        state fault {
            entry {
                statusOutput.status = "fault";
                statusOutput.errorCode = errorCode;
            }
        }
        transition from off to warmup
            when commandInput.command == "start";
        transition from warmup to measuring
            when warmupTimer >= warmupDuration;
        transition from warmup to fault
            when faultDetected == true;
        transition from measuring to fault
            when faultDetected == true;
        transition from measuring to off
            when commandInput.command == "stop";
        transition from fault to off
            when commandInput.command == "reset";
        transition from fault to warmup
            when commandInput.command == "retry";
    }
}

part def PowerSupply {
    attribute filamentOutputVoltage : Voltage = 5 [volt];
    attribute gridOutputVoltage : Voltage = 150 [volt];
    attribute collectorOutputVoltage : Voltage = -150 [volt];
    attribute maxOutputPower : Power = 50 [watt];
    attribute voltageStability : Real = 0.001;
    port filamentOutput : PowerOutputPort;
    port gridOutput : PowerOutputPort;
    port collectorOutput : PowerOutputPort;
    action regulate : RegulatePower;
}

part def VacuumChamber {
    attribute chamberPressure : Pressure;
    attribute chamberTemperature : Temperature = 25 [degreeCelsius];
    ref item gasMixture : VacuumGasMixture;
    port vacuumPort : VacuumInterfacePort;
}

// ===== System Assembly =====
part def IonizationGaugeSystem {
    attribute systemId : String;
    attribute manufacturer : String;

    part filament : Filament;
    part acceleratingGrid : AcceleratingGrid;
    part ionizationRegion : IonizationRegion;
    part ionCollector : IonCollector;
    part electrometer : Electrometer;
    part controllerUnit : ControllerUnit;
    part powerSupply : PowerSupply;
    part vacuumChamber : VacuumChamber;

    connect powerSupply.filamentOutput to filament.powerInput;
    connect powerSupply.gridOutput to acceleratingGrid.powerInput;
    connect powerSupply.collectorOutput to ionCollector.powerInput;

    connect filament.electronOutput to acceleratingGrid.electronInput;
    connect acceleratingGrid.electronOutput to ionizationRegion.electronInput;

    connect ionizationRegion.ionOutput to ionCollector.ionInput;

    connect ionCollector.currentOutput to electrometer.currentInput;
    connect electrometer.signalOutput to controllerUnit.signalInput;

    connect vacuumChamber.vacuumPort to ionizationRegion.vacuumInterface;

    flow of Electron from filament.electronOutput to acceleratingGrid.electronInput;
    flow of Electron from acceleratingGrid.electronOutput to ionizationRegion.electronInput;
    flow of PositiveIon from ionizationRegion.ionOutput to ionCollector.ionInput;
}

// ===== Requirements =====
requirement def PressureMeasurementRequirement {
    subject gauge : IonizationGaugeSystem;
    attribute minPressure : Pressure = 1e-9 [pascal];
    attribute maxPressure : Pressure = 1e-1 [pascal];
    attribute measurementAccuracy : Real = 0.1;
    require constraint {
        gauge.controllerUnit.reportedPressure >= minPressure and
        gauge.controllerUnit.reportedPressure <= maxPressure;
    }
}

requirement def FilamentEmissionRequirement {
    subject filament : Filament;
    attribute minEmissionCurrent : Current = 1e-3 [ampere];
    attribute maxEmissionCurrent : Current = 10e-3 [ampere];
    require constraint {
        filament.emissionCurrent >= minEmissionCurrent and
        filament.emissionCurrent <= maxEmissionCurrent;
    }
}

requirement def GridAccelerationRequirement {
    subject grid : AcceleratingGrid;
    attribute minGridVoltage : Voltage = 100 [volt];
    attribute maxGridVoltage : Voltage = 200 [volt];
    require constraint {
        grid.gridVoltage >= minGridVoltage and
        grid.gridVoltage <= maxGridVoltage;
    }
}

requirement def CollectorBiasRequirement {
    subject collector : IonCollector;
    attribute minCollectorVoltage : Voltage = -200 [volt];
    attribute maxCollectorVoltage : Voltage = -50 [volt];
    require constraint {
        collector.collectorVoltage >= minCollectorVoltage and
        collector.collectorVoltage <= maxCollectorVoltage;
    }
}

requirement def ElectrometerSensitivityRequirement {
    subject electrometer : Electrometer;
    attribute minGain : Real = 1e6;
    attribute minInputImpedance : Resistance = 1e11 [ohm];
    require constraint {
        electrometer.gain >= minGain and
        electrometer.inputImpedance >= minInputImpedance;
    }
}

requirement def WarmupDurationRequirement {
    subject controller : ControllerUnit;
    attribute minWarmupTime : Duration = 30 [second];
    attribute maxWarmupTime : Duration = 120 [second];
    require constraint {
        controller.warmupDuration >= minWarmupTime and
        controller.warmupDuration <= maxWarmupTime;
    }
}

requirement def PowerStabilityRequirement {
    subject supply : PowerSupply;
    attribute maxVoltageDrift : Real = 0.01;
    require constraint {
        supply.voltageStability <= maxVoltageDrift;
    }
}

requirement def OperationalStateRequirement {
    subject controller : ControllerUnit;
    attribute requiredStates : String = "off,warmup,measuring,fault";
    require constraint {
        controller.warmupDuration >= 30 [second] and
        controller.warmupDuration <= 120 [second];
    }
}

// ===== Requirement Usages and Satisfaction =====
part gaugeSystem : IonizationGaugeSystem;

requirement pressureMeasurement : PressureMeasurementRequirement {
    subject = gaugeSystem;
}

requirement filamentEmission : FilamentEmissionRequirement {
    subject = gaugeSystem.filament;
}

requirement gridAcceleration : GridAccelerationRequirement {
    subject = gaugeSystem.acceleratingGrid;
}

requirement collectorBias : CollectorBiasRequirement {
    subject = gaugeSystem.ionCollector;
}

requirement electrometerSensitivity : ElectrometerSensitivityRequirement {
    subject = gaugeSystem.electrometer;
}

requirement warmupDuration : WarmupDurationRequirement {
    subject = gaugeSystem.controllerUnit;
}

requirement powerStability : PowerStabilityRequirement {
    subject = gaugeSystem.powerSupply;
}

requirement operationalStates : OperationalStateRequirement {
    subject = gaugeSystem.controllerUnit;
}

satisfy pressureMeasurement by gaugeSystem;
satisfy filamentEmission by gaugeSystem.filament;
satisfy gridAcceleration by gaugeSystem.acceleratingGrid;
satisfy collectorBias by gaugeSystem.ionCollector;
satisfy electrometerSensitivity by gaugeSystem.electrometer;
satisfy warmupDuration by gaugeSystem.controllerUnit;
satisfy powerStability by gaugeSystem.powerSupply;
satisfy operationalStates by gaugeSystem.controllerUnit;

}
