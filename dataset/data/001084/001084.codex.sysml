package HotFilamentIonizationGaugeModel {

    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def ElectricPotential specializes ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def ElectricCurrent specializes ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Temperature specializes ISQ::thermodynamicTemperature {
        unit = SI::kelvin;
    }

    attribute def Pressure specializes ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def Conductance {
        attribute value : Real;
        attribute unitSymbol : String = "S";
    }

    attribute def TimeDuration specializes ISQ::time {
        unit = SI::second;
    }

    attribute def IonizationSensitivity {
        attribute value : Real;
        attribute unitSymbol : String = "1/Pa";
    }

    attribute def EmissionStability {
        attribute value : Real;
        attribute unitSymbol : String = "%";
    }

    item def Electron {
        attribute charge : ElectricCurrent;
        attribute kineticEnergy_eV : Real;
    }

    item def Ion {
        attribute chargeState : Integer;
        attribute kineticEnergy_eV : Real;
    }

    item def NeutralGasMolecule {
        attribute species : String;
        attribute partialPressure : Pressure;
    }

    item def HeatFlow {
        attribute thermalPower : Power;
    }

    item def AnalogSignal {
        attribute voltage : ElectricPotential;
        attribute current : ElectricCurrent;
        attribute bandwidth : Real;
    }

    item def DigitalPressureReading {
        attribute measuredPressure : Pressure;
        attribute timestamp : TimeDuration;
        attribute status : GaugeStatusKind;
    }

    item def ControlCommand {
        attribute requestedMode : GaugeModeKind;
        attribute emissionCurrentSetpoint : ElectricCurrent;
        attribute degasRequested : Boolean;
    }

    enum def GaugeModeKind {
        enum off;
        enum standby;
        enum measure;
        enum degas;
        enum fault;
    }

    enum def GaugeStatusKind {
        enum invalid;
        enum warming;
        enum valid;
        enum overPressure;
        enum filamentOpen;
        enum emissionUnstable;
        enum electronicsFault;
    }

    port def ElectricalPowerPort {
        in item supplyVoltage : AnalogSignal;
        out item returnCurrent : AnalogSignal;
    }

    port def ControlPort {
        in item command : ControlCommand;
        out item reading : DigitalPressureReading;
    }

    port def VacuumGasPort {
        inout item gas : NeutralGasMolecule;
    }

    port def ElectronFlowPort {
        out item electronBeam : Electron;
    }

    port def IonFlowPort {
        in item ionCurrent : Ion;
    }

    port def HeatTransferPort {
        out item heat : HeatFlow;
    }

    port def AnalogMeasurementPort {
        out item signal : AnalogSignal;
    }

    part def Filament {
        attribute material : String = "tungsten";
        attribute operatingTemperature : Temperature = 2200 [K];
        attribute heaterVoltage : ElectricPotential = 3.5 [V];
        attribute heaterCurrent : ElectricCurrent = 2.5 [A];
        attribute emissionCurrent : ElectricCurrent = 1.0e-3 [A];
        attribute maximumTemperature : Temperature = 2600 [K];

        port power : ElectricalPowerPort;
        port electrons : ElectronFlowPort;
        port heatLoss : HeatTransferPort;

        action heatFilament {
            in attribute commandedHeaterCurrent : ElectricCurrent;
            out attribute filamentTemperature : Temperature;

            objective {
                doc /* Raise the filament temperature until thermionic electron emission is sufficient for pressure measurement. */
            }
        }

        action emitElectrons {
            in attribute filamentTemperature : Temperature;
            in attribute gridPotential : ElectricPotential;
            out item emittedElectrons : Electron;

            objective {
                doc /* Produce a controlled electron current by thermionic emission from the hot filament. */
            }
        }
    }

    part def GridAnode {
        attribute gridVoltage : ElectricPotential = 180 [V];
        attribute electronCollectionFraction : Real = 0.92;
        attribute geometryFactor : Real = 1.0;

        port incomingElectrons : ElectronFlowPort;
        port gasSpace : VacuumGasPort;
        port analogBias : ElectricalPowerPort;

        action accelerateElectrons {
            in item electrons : Electron;
            in attribute anodeVoltage : ElectricPotential;
            out item energeticElectrons : Electron;
        }

        action ionizeGas {
            in item energeticElectrons : Electron;
            in item gasMolecules : NeutralGasMolecule;
            out item generatedIons : Ion;

            objective {
                doc /* Convert neutral residual gas molecules into positive ions through electron impact ionization. */
            }
        }
    }

    part def IonCollector {
        attribute collectorVoltage : ElectricPotential = -30 [V];
        attribute leakageCurrent : ElectricCurrent = 1.0e-13 [A];
        attribute maximumIonCurrent : ElectricCurrent = 1.0e-5 [A];

        port ions : IonFlowPort;
        port ionSignal : AnalogMeasurementPort;
        port bias : ElectricalPowerPort;

        action collectPositiveIons {
            in item generatedIons : Ion;
            out item measuredIonCurrent : AnalogSignal;

            objective {
                doc /* Attract and collect positive ions so that ion current can be measured as a proxy for gas density. */
            }
        }
    }

    part def VacuumEnvelope {
        attribute internalVolume : Volume = 4.0e-5 [m^3];
        attribute maximumOperatingPressure : Pressure = 1.0e-1 [Pa];
        attribute minimumMeasurablePressure : Pressure = 1.0e-8 [Pa];
        attribute bakeoutTemperatureLimit : Temperature = 450 [K];

        port processGas : VacuumGasPort;
        port gaugeGas : VacuumGasPort;
        port heatToChamber : HeatTransferPort;
    }

    part def Electrometer {
        attribute inputBiasCurrent : ElectricCurrent = 5.0e-14 [A];
        attribute transimpedanceGain : Resistance = 1.0e9 [ohm];
        attribute noiseCurrentRms : ElectricCurrent = 2.0e-13 [A];
        attribute samplePeriod : TimeDuration = 0.1 [s];

        port inputIonCurrent : AnalogMeasurementPort;
        port pressureSignal : AnalogMeasurementPort;

        action convertIonCurrentToVoltage {
            in item ionCurrentSignal : AnalogSignal;
            out item pressureVoltageSignal : AnalogSignal;
        }
    }

    part def PressureComputationUnit {
        attribute sensitivity : IonizationSensitivity {
            :>> value = 0.1;
            :>> unitSymbol = "1/Pa";
        }
        attribute pressureLowerRange : Pressure = 1.0e-8 [Pa];
        attribute pressureUpperRange : Pressure = 1.0e-1 [Pa];
        attribute validEmissionTolerance : EmissionStability {
            :>> value = 2.0;
            :>> unitSymbol = "%";
        }

        port analogPressureInput : AnalogMeasurementPort;
        port controlInterface : ControlPort;

        action computePressure {
            in item pressureVoltageSignal : AnalogSignal;
            in attribute emissionCurrent : ElectricCurrent;
            out item reading : DigitalPressureReading;

            objective {
                doc /* Calculate pressure from ion current using the hot-filament gauge sensitivity and regulated electron emission current. */
            }
        }

        action evaluateStatus {
            in attribute measuredPressure : Pressure;
            in attribute emissionCurrentError : ElectricCurrent;
            in attribute filamentContinuity : Boolean;
            out attribute status : GaugeStatusKind;
        }
    }

    part def EmissionController {
        attribute emissionSetpoint : ElectricCurrent = 1.0e-3 [A];
        attribute emissionErrorLimit : ElectricCurrent = 2.0e-5 [A];
        attribute heaterCurrentLimit : ElectricCurrent = 3.0 [A];
        attribute warmupTime : TimeDuration = 20 [s];

        port filamentPower : ElectricalPowerPort;
        port anodePower : ElectricalPowerPort;
        port collectorPower : ElectricalPowerPort;
        port controlInterface : ControlPort;

        action regulateEmission {
            in attribute measuredEmissionCurrent : ElectricCurrent;
            in attribute setpoint : ElectricCurrent;
            out attribute heaterCurrentCommand : ElectricCurrent;
        }

        action removeHighVoltage {
            out attribute anodeVoltageCommand : ElectricPotential;
            out attribute collectorVoltageCommand : ElectricPotential;
        }
    }

    part def ProtectionInterlock {
        attribute overPressureTrip : Pressure = 2.0e-1 [Pa];
        attribute restartPressureThreshold : Pressure = 5.0e-2 [Pa];
        attribute filamentContinuityMinimum : Conductance {
            :>> value = 0.05;
            :>> unitSymbol = "S";
        }

        port controlInterface : ControlPort;

        action checkOperatingLimits {
            in attribute pressure : Pressure;
            in attribute filamentConductance : Conductance;
            in attribute electronicsHealthy : Boolean;
            out attribute permittedMode : GaugeModeKind;
        }
    }

    part def HotFilamentIonizationGauge {
        attribute modelName : String = "Bayard-Alpert hot filament ionization gauge";
        attribute primaryFunction : String = "Measure high-vacuum pressure by ionizing residual gas with electrons emitted from a heated filament and converting collected positive ion current into pressure.";
        attribute operatingPressureLowerLimit : Pressure = 1.0e-8 [Pa];
        attribute operatingPressureUpperLimit : Pressure = 1.0e-1 [Pa];
        attribute nominalEmissionCurrent : ElectricCurrent = 1.0e-3 [A];
        attribute nominalGridVoltage : ElectricPotential = 180 [V];
        attribute nominalCollectorVoltage : ElectricPotential = -30 [V];

        port vacuumPort : VacuumGasPort;
        port dcPower : ElectricalPowerPort;
        port hostControl : ControlPort;
        port thermalInterface : HeatTransferPort;

        part envelope : VacuumEnvelope;
        part filament : Filament;
        part grid : GridAnode;
        part collector : IonCollector;
        part electrometer : Electrometer;
        part computation : PressureComputationUnit;
        part controller : EmissionController;
        part interlock : ProtectionInterlock;

        connect vacuumPort to envelope.processGas;
        connect envelope.gaugeGas to grid.gasSpace;
        connect filament.electrons to grid.incomingElectrons;
        connect collector.ionSignal to electrometer.inputIonCurrent;
        connect electrometer.pressureSignal to computation.analogPressureInput;
        connect computation.controlInterface to hostControl;
        connect controller.controlInterface to hostControl;
        connect interlock.controlInterface to hostControl;
        connect dcPower to controller.filamentPower;
        connect dcPower to controller.anodePower;
        connect dcPower to controller.collectorPower;
        connect envelope.heatToChamber to thermalInterface;
        connect filament.heatLoss to thermalInterface;

        action performPressureMeasurement {
            in item gasSample : NeutralGasMolecule;
            out item pressureReading : DigitalPressureReading;

            first startHeating;
            then establishEmission;
            then ionizeResidualGas;
            then collectIonCurrent;
            then calculatePressure;

            action startHeating {
                in item gasSample : NeutralGasMolecule;
                out attribute filamentTemperature : Temperature;
            }

            action establishEmission {
                in attribute filamentTemperature : Temperature;
                out item electronBeam : Electron;
            }

            action ionizeResidualGas {
                in item electronBeam : Electron;
                in item gasSample : NeutralGasMolecule;
                out item positiveIons : Ion;
            }

            action collectIonCurrent {
                in item positiveIons : Ion;
                out item ionCurrentSignal : AnalogSignal;
            }

            action calculatePressure {
                in item ionCurrentSignal : AnalogSignal;
                out item pressureReading : DigitalPressureReading;
            }
        }

        state def GaugeOperatingState {
            entry action initialize {
                out attribute mode : GaugeModeKind = GaugeModeKind::off;
            }

            state Off;
            state Standby;
            state Warmup;
            state Measuring;
            state Degas;
            state Fault;

            transition Off_to_Standby
                first Off
                accept ControlCommand
                if command.requestedMode == GaugeModeKind::standby
                then Standby;

            transition Standby_to_Warmup
                first Standby
                accept ControlCommand
                if command.requestedMode == GaugeModeKind::measure
                then Warmup;

            transition Warmup_to_Measuring
                first Warmup
                accept TimeDuration
                if elapsed >= controller.warmupTime
                then Measuring;

            transition Measuring_to_Degas
                first Measuring
                accept ControlCommand
                if command.degasRequested == true
                then Degas;

            transition Degas_to_Measuring
                first Degas
                accept TimeDuration
                if elapsed >= 60 [s]
                then Measuring;

            transition Measuring_to_Standby
                first Measuring
                accept ControlCommand
                if command.requestedMode == GaugeModeKind::standby
                then Standby;

            transition Any_to_Fault
                first Off, Standby, Warmup, Measuring, Degas
                if computation.controlInterface.reading.status == GaugeStatusKind::overPressure or
                   computation.controlInterface.reading.status == GaugeStatusKind::filamentOpen or
                   computation.controlInterface.reading.status == GaugeStatusKind::electronicsFault
                then Fault;

            transition Fault_to_Standby
                first Fault
                accept ControlCommand
                if command.requestedMode == GaugeModeKind::standby
                then Standby;
        }

        exhibit state gaugeState : GaugeOperatingState;
    }

    requirement def PrimaryFunctionRequirement {
        doc /* The gauge shall measure high-vacuum pressure by heating a filament, emitting electrons, ionizing residual gas, collecting positive ions, and converting ion current to a pressure reading. */

        subject gauge : HotFilamentIonizationGauge;

        require constraint {
            gauge.primaryFunction == "Measure high-vacuum pressure by ionizing residual gas with electrons emitted from a heated filament and converting collected positive ion current into pressure."
        }
    }

    requirement def PressureRangeRequirement {
        doc /* The gauge shall provide valid pressure readings over the specified high-vacuum range. */

        subject gauge : HotFilamentIonizationGauge;

        require constraint {
            gauge.operatingPressureLowerLimit <= 1.0e-8 [Pa] and
            gauge.operatingPressureUpperLimit >= 1.0e-1 [Pa]
        }
    }

    requirement def EmissionControlRequirement {
        doc /* The controller shall regulate thermionic emission current to the nominal setpoint while measurement is active. */

        subject gauge : HotFilamentIonizationGauge;

        require constraint {
            gauge.controller.emissionSetpoint == gauge.nominalEmissionCurrent and
            gauge.controller.emissionErrorLimit <= 2.0e-5 [A]
        }
    }

    requirement def OverPressureProtectionRequirement {
        doc /* The gauge shall remove filament and high-voltage excitation when pressure exceeds the over-pressure trip threshold. */

        subject gauge : HotFilamentIonizationGauge;

        require constraint {
            gauge.interlock.overPressureTrip <= 2.0e-1 [Pa]
        }
    }

    requirement def IonCurrentMeasurementRequirement {
        doc /* The electrometer shall resolve ion current sufficiently below the minimum expected measurement current at the lower pressure limit. */

        subject gauge : HotFilamentIonizationGauge;

        require constraint {
            gauge.electrometer.noiseCurrentRms <= 2.0e-13 [A] and
            gauge.collector.leakageCurrent <= 1.0e-13 [A]
        }
    }

    requirement def ThermalLimitRequirement {
        doc /* The filament temperature shall remain below the material safety limit during normal measurement and degas operation. */

        subject gauge : HotFilamentIonizationGauge;

        require constraint {
            gauge.filament.operatingTemperature < gauge.filament.maximumTemperature
        }
    }

    satisfy PrimaryFunctionRequirement by HotFilamentIonizationGauge;
    satisfy PressureRangeRequirement by HotFilamentIonizationGauge;
    satisfy EmissionControlRequirement by EmissionController;
    satisfy OverPressureProtectionRequirement by ProtectionInterlock;
    satisfy IonCurrentMeasurementRequirement by Electrometer;
    satisfy ThermalLimitRequirement by Filament;

}