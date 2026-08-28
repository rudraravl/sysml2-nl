package ThermalInsulationSystem {
    import SI::*;
    import ScalarValues::*;

    // ===== Value Types =====
    value type ThermalConductivity :> Real {
        unit 'W/(m*K)';
    }
    value type Temperature :> Real {
        unit 'K';
    }
    value type HeatFlux :> Real {
        unit 'W/m^2';
    }
    value type Thickness :> Real {
        unit 'm';
    }
    value type Density :> Real {
        unit 'kg/m^3';
    }
    value type Porosity :> Real {
        unit '%';
    }
    value type CompressionStrength :> Real {
        unit 'MPa';
    }
    value type ThermalResistance :> Real {
        unit 'm^2*K/W';
    }
    value type EfficiencyFactor :> Real {
        unit '%';
    }
    value type MoistureContent :> Real {
        unit '%';
    }
    value type Power :> Real {
        unit 'W';
    }
    value type Voltage :> Real {
        unit 'V';
    }
    value type DataRate :> Real {
        unit 'kb/s';
    }

    // ===== Item Types =====
    item def ThermalEnergy;
    item def Moisture;
    item def SensorSignal;
    item def StatusReport;
    item def WarningAlert;

    // ===== Enumerations =====
    enum def OperationalState {
        active;
        standby;
        degraded;
    }

    enum def HealthStatus {
        nominal;
        warning;
        critical;
    }

    // ===== Interfaces =====
    interface def ThermalInterface {
        end thermalIn : ThermalEnergy;
        end thermalOut : ThermalEnergy;
    }

    interface def SensorDataInterface {
        end signalOut : SensorSignal;
        end signalIn : SensorSignal;
    }

    interface def ControlDataInterface {
        end dataOut : StatusReport;
        end dataIn : StatusReport;
    }

    interface def AlertInterface {
        end alertOut : WarningAlert;
        end alertIn : WarningAlert;
    }

    // ===== Port Definitions =====
    port def ThermalPort :> ThermalInterface;
    port def SensorPort :> SensorDataInterface;
    port def ControlPort :> ControlDataInterface;
    port def AlertPort :> AlertInterface;

    // ===== Aerogel Core =====
    part def AerogelCore {
        attribute thermalConductivity : ThermalConductivity = 0.015 [W/(m*K)];
        attribute density : Density = 130.0 [kg/m^3];
        attribute porosity : Porosity = 95.0 [%];
        attribute thickness : Thickness = 0.025 [m];
        attribute maxOperatingTemp : Temperature = 650.0 [K];
        attribute minOperatingTemp : Temperature = 4.0 [K];

        port hotSideThermal : ThermalPort;
        port coldSideThermal : ThermalPort;

        attribute thermalResistance : ThermalResistance = (thickness / thermalConductivity);

        item flow : ThermalEnergy {
            attribute incomingFlux : HeatFlux;
            attribute outgoingFlux : HeatFlux;
        }

        action def ConductHeat {
            in hotTemp : Temperature;
            in coldTemp : Temperature;
            in resistance : ThermalResistance;
            out calculatedFlux : HeatFlux;
        }

        action conduct : ConductHeat {
            in hotTemp = hotSideThermal.thermalIn;
            in coldTemp = coldSideThermal.thermalIn;
            in resistance = thermalResistance;
            out calculatedFlux = flow.incomingFlux;
        }
    }

    // ===== Structural Frame =====
    part def StructuralFrame {
        attribute compressionStrength : CompressionStrength = 2.5 [MPa];
        attribute frameThickness : Thickness = 0.003 [m];
        attribute material : String = "Aluminum 6061-T6";

        port frameMountHot : ThermalPort;
        port frameMountCold : ThermalPort;

        action def ProvideSupport {
            in loadApplied : CompressionStrength;
            out structuralIntegrity : Boolean;
        }

        action support : ProvideSupport {
            in loadApplied = compressionStrength;
            out structuralIntegrity = true;
        }
    }

    // ===== Vapor Barrier =====
    part def VaporBarrier {
        attribute permeance : Real = 0.0001;
        attribute barrierThickness : Thickness = 0.0005 [m];
        attribute maxMoistureContent : MoistureContent = 0.5 [%];

        port barrierHotSide : ThermalPort;
        port barrierColdSide : ThermalPort;

        item moistureFlow : Moisture {
            attribute ingressRate : Real;
            attribute blockedRate : Real;
        }

        action def BlockMoisture {
            in moistureIn : Moisture;
            out moistureBlocked : Moisture;
        }

        action block : BlockMoisture {
            in moistureIn = moistureFlow;
            out moistureBlocked = moistureFlow;
        }
    }

    // ===== Temperature Sensor =====
    part def TemperatureSensor {
        attribute measurementRange : Temperature[2] = (4.0 [K], 800.0 [K]);
        attribute accuracy : Real = 0.1 [%];
        attribute samplingRate : DataRate = 10.0 [kb/s];
        attribute supplyVoltage : Voltage = 3.3 [V];

        port thermalProbe : ThermalPort;
        port dataOutput : SensorPort;

        attribute currentReading : Temperature;

        action def MeasureTemperature {
            in thermalInput : ThermalEnergy;
            out temperatureValue : Temperature;
        }

        action measure : MeasureTemperature {
            in thermalInput = thermalProbe.thermalIn;
            out temperatureValue = currentReading;
        }
    }

    // ===== Heat Flux Monitor =====
    part def HeatFluxMonitor {
        attribute measurementRange : HeatFlux[2] = (0.0 [W/m^2], 5000.0 [W/m^2]);
        attribute accuracy : Real = 0.5 [%];
        attribute samplingRate : DataRate = 5.0 [kb/s];
        attribute supplyVoltage : Voltage = 3.3 [V];

        port fluxProbeHot : ThermalPort;
        port fluxProbeCold : ThermalPort;
        port dataOutput : SensorPort;

        attribute measuredFlux : HeatFlux;

        action def MeasureHeatFlux {
            in hotSideTemp : Temperature;
            in coldSideTemp : Temperature;
            out fluxValue : HeatFlux;
        }

        action measure : MeasureHeatFlux {
            in hotSideTemp = fluxProbeHot.thermalIn;
            in coldSideTemp = fluxProbeCold.thermalIn;
            out fluxValue = measuredFlux;
        }
    }

    // ===== Control Unit =====
    part def ControlUnit {
        attribute efficiencyTarget : EfficiencyFactor = 95.0 [%];
        attribute degradedThreshold : EfficiencyFactor = 80.0 [%];
        attribute criticalThreshold : EfficiencyFactor = 60.0 [%];
        attribute processingRate : DataRate = 100.0 [kb/s];
        attribute supplyVoltage : Voltage = 5.0 [V];

        port hotSensorInput : SensorPort;
        port coldSensorInput : SensorPort;
        port fluxSensorInput : SensorPort;
        port controlOutput : ControlPort;
        port alertOutput : AlertPort;

        attribute currentState : OperationalState = OperationalState::standby;
        attribute health : HealthStatus = HealthStatus::nominal;
        attribute hotSideTemp : Temperature;
        attribute coldSideTemp : Temperature;
        attribute measuredHeatFlux : HeatFlux;
        attribute calculatedHeatFlux : HeatFlux;
        attribute actualEfficiency : EfficiencyFactor;

        // State Machine
        state def ControlStateMachine {
            entry; then standby;

            state standby {
                entry {
                    currentState = OperationalState::standby;
                    health = HealthStatus::nominal;
                }
                on sensorDataReceived if (hotSideTemp > minOperatingTemp) do activateSystem then active;
            }

            state active {
                entry {
                    currentState = OperationalState::active;
                    health = HealthStatus::nominal;
                }
                do evaluatePerformance;
                on efficiencyBelowTarget if (actualEfficiency < degradedThreshold) do issueWarning then degraded;
                on systemIdle do deactivateSystem then standby;
            }

            state degraded {
                entry {
                    currentState = OperationalState::degraded;
                    health = HealthStatus::warning;
                }
                do evaluatePerformance;
                on efficiencyCritical if (actualEfficiency < criticalThreshold) do issueCriticalAlert {
                    health = HealthStatus::critical;
                }
                on efficiencyRecovered if (actualEfficiency >= efficiencyTarget) do clearWarning then active;
            }
        }

        action def EvaluatePerformance {
            in hotTemp : Temperature;
            in coldTemp : Temperature;
            in measuredFlux : HeatFlux;
            in targetEfficiency : EfficiencyFactor;
            out efficiency : EfficiencyFactor;
            out status : HealthStatus;
        }

        action def CalculateHeatFlux {
            in hotTemp : Temperature;
            in coldTemp : Temperature;
            in resistance : ThermalResistance;
            out flux : HeatFlux;
        }

        action def IssueWarning {
            in severity : HealthStatus;
            out alert : WarningAlert;
        }

        action evaluatePerformance : EvaluatePerformance {
            in hotTemp = hotSideTemp;
            in coldTemp = coldSideTemp;
            in measuredFlux = measuredHeatFlux;
            in targetEfficiency = efficiencyTarget;
            out efficiency = actualEfficiency;
            out status = health;
        }

        action calculateFlux : CalculateHeatFlux {
            in hotTemp = hotSideTemp;
            in coldTemp = coldSideTemp;
            in resistance = 1.67 [m^2*K/W];
            out flux = calculatedHeatFlux;
        }

        action issueWarning : IssueWarning {
            in severity = HealthStatus::warning;
            out alert = alertOutput.alertOut;
        }

        action issueCriticalAlert : IssueWarning {
            in severity = HealthStatus::critical;
            out alert = alertOutput.alertOut;
        }

        state machine : ControlStateMachine;
    }

    // ===== External Interface =====
    part def ExternalMonitor {
        port dataInput : ControlPort;
        port alertInput : AlertPort;

        action def ReceiveStatus {
            in report : StatusReport;
            in alert : WarningAlert;
        }

        action receive : ReceiveStatus {
            in report = dataInput.dataIn;
            in alert = alertInput.alertIn;
        }
    }

    // ===== Top-level Thermal Insulation System =====
    part def ThermalInsulationSystem {
        attribute systemName : String = "Ultra-Efficient Nanoporous Aerogel Insulation System";
        attribute systemID : String = "TIS-AEROGEL-001";
        attribute maxTempDifferential : Temperature = 800.0 [K];
        attribute overallEfficiency : EfficiencyFactor;

        port externalHotSide : ThermalPort;
        port externalColdSide : ThermalPort;
        port systemControlPort : ControlPort;
        port systemAlertPort : AlertPort;

        part aerogelCore : AerogelCore {
            port hotSideThermal : ThermalPort;
            port coldSideThermal : ThermalPort;
        }

        part structuralFrame : StructuralFrame {
            port frameMountHot : ThermalPort;
            port frameMountCold : ThermalPort;
        }

        part vaporBarrier : VaporBarrier {
            port barrierHotSide : ThermalPort;
            port barrierColdSide : ThermalPort;
        }

        part hotSideSensor : TemperatureSensor {
            port thermalProbe : ThermalPort;
            port dataOutput : SensorPort;
        }

        part coldSideSensor : TemperatureSensor {
            port thermalProbe : ThermalPort;
            port dataOutput : SensorPort;
        }

        part heatFluxMonitor : HeatFluxMonitor {
            port fluxProbeHot : ThermalPort;
            port fluxProbeCold : ThermalPort;
            port dataOutput : SensorPort;
        }

        part controlUnit : ControlUnit {
            port hotSensorInput : SensorPort;
            port coldSensorInput : SensorPort;
            port fluxSensorInput : SensorPort;
            port controlOutput : ControlPort;
            port alertOutput : AlertPort;
        }

        part externalMonitor : ExternalMonitor {
            port dataInput : ControlPort;
            port alertInput : AlertPort;
        }

        // Connections - Thermal path
        connection hotThermalPath : ThermalInterface connect externalHotSide to structuralFrame.frameMountHot;
        connection frameToBarrierHot : ThermalInterface connect structuralFrame.frameMountHot to vaporBarrier.barrierHotSide;
        connection barrierToAerogelHot : ThermalInterface connect vaporBarrier.barrierHotSide to aerogelCore.hotSideThermal;
        connection aerogelToBarrierCold : ThermalInterface connect aerogelCore.coldSideThermal to vaporBarrier.barrierColdSide;
        connection barrierToFrameCold : ThermalInterface connect vaporBarrier.barrierColdSide to structuralFrame.frameMountCold;
        connection coldThermalPath : ThermalInterface connect structuralFrame.frameMountCold to externalColdSide;

        // Sensor thermal connections
        connection hotSensorThermal : ThermalInterface connect aerogelCore.hotSideThermal to hotSideSensor.thermalProbe;
        connection coldSensorThermal : ThermalInterface connect aerogelCore.coldSideThermal to coldSideSensor.thermalProbe;
        connection fluxSensorHotThermal : ThermalInterface connect aerogelCore.hotSideThermal to heatFluxMonitor.fluxProbeHot;
        connection fluxSensorColdThermal : ThermalInterface connect aerogelCore.coldSideThermal to heatFluxMonitor.fluxProbeCold;

        // Sensor data connections
        connection hotSensorData : SensorDataInterface connect hotSideSensor.dataOutput to controlUnit.hotSensorInput;
        connection coldSensorData : SensorDataInterface connect coldSideSensor.dataOutput to controlUnit.coldSensorInput;
        connection fluxSensorData : SensorDataInterface connect heatFluxMonitor.dataOutput to controlUnit.fluxSensorInput;

        // Control output connections
        connection controlDataLink : ControlDataInterface connect controlUnit.controlOutput to externalMonitor.dataInput;
        connection alertDataLink : AlertInterface connect controlUnit.alertOutput to externalMonitor.alertInput;

        // System-level ports
        connection externalHotLink : ThermalInterface connect externalHotSide to externalHotSide;
        connection externalColdLink : ThermalInterface connect externalColdSide to externalColdSide;
        connection systemControlLink : ControlDataInterface connect controlUnit.controlOutput to systemControlPort;
        connection systemAlertLink : AlertInterface connect controlUnit.alertOutput to systemAlertPort;
    }

    // ===== Requirements =====
    requirement def ThermalPerformanceRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The system shall provide ultra-efficient thermal resistance with thermal conductivity not exceeding 0.020 W/(m*K)."
        }
        assume {
            aerogelCore.thermalConductivity <= 0.020 [W/(m*K)];
        }
    }

    requirement def StructuralIntegrityRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The structural frame shall provide compression resistance of at least 2.0 MPa to protect the aerogel core."
        }
        assume {
            structuralFrame.compressionStrength >= 2.0 [MPa];
        }
    }

    requirement def MoistureProtectionRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The vapor barrier shall limit moisture content in the aerogel core to below 0.5% under all operating conditions."
        }
        assume {
            vaporBarrier.maxMoistureContent <= 0.5 [%];
        }
    }

    requirement def TemperatureMonitoringRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The system shall continuously monitor temperature on both hot and cold sides with accuracy of at least 0.1%."
        }
        assume {
            hotSideSensor.accuracy <= 0.1 [%];
            coldSideSensor.accuracy <= 0.1 [%];
        }
    }

    requirement def HeatFluxMonitoringRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The system shall directly measure heat flux through the insulation with accuracy of at least 0.5%."
        }
        assume {
            heatFluxMonitor.accuracy <= 0.5 [%];
        }
    }

    requirement def OperationalStateManagementRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The system shall determine its operational state (active, standby, degraded) based on measured performance against efficiency targets."
        }
        assume {
            controlUnit.currentState in OperationalState;
        }
    }

    requirement def DegradedModeDetectionRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The system shall enter degraded mode and issue warnings when efficiency falls below 80% of the target value."
        }
        assume {
            controlUnit.degradedThreshold >= 80.0 [%];
        }
    }

    requirement def FailureWarningRequirement {
        subject : ThermalInsulationSystem;
        objective {
            doc "The system shall issue critical alerts when efficiency falls below 60% of the target value, indicating potential failure."
        }
        assume {
            controlUnit.criticalThreshold >= 60.0 [%];
        }
    }

    requirement def SystemRequirements {
        subject : ThermalInsulationSystem;

        satisfy thermalPerf : ThermalPerformanceRequirement;
        satisfy structuralIntegrity : StructuralIntegrityRequirement;
        satisfy moistureProtection : MoistureProtectionRequirement;
        satisfy tempMonitoring : TemperatureMonitoringRequirement;
        satisfy fluxMonitoring : HeatFluxMonitoringRequirement;
        satisfy stateManagement : OperationalStateManagementRequirement;
        satisfy degradedDetection : DegradedModeDetectionRequirement;
        satisfy failureWarning : FailureWarningRequirement;
    }
}
