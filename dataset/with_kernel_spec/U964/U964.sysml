package AdvancedThermalInsulationSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def ThermalConductivityValue :> Real;
    attribute def HeatFluxValue :> Real;
    attribute def MoisturePermeabilityValue :> Real;

    enum def OperationalState {
        active;
        standby;
        degraded;
    }

    port def TemperatureOutPort {
        out temperature : TemperatureValue;
    }

    port def TemperatureInPort {
        in temperature : TemperatureValue;
    }

    port def HeatFluxOutPort {
        out heatFlux : HeatFluxValue;
    }

    port def HeatFluxInPort {
        in heatFlux : HeatFluxValue;
    }

    port def ControlOutPort {
        out operationalState : OperationalState;
        out warning : Boolean;
    }

    part def AerogelCore {
        attribute thermalConductivity : ThermalConductivityValue;
        attribute density : MassDensityValue;
        attribute porosity : Real;
        attribute thickness : LengthValue;
    }

    part def StructuralFrame {
        attribute compressionStrength : PressureValue;
    }

    part def VaporBarrier {
        attribute moisturePermeability : MoisturePermeabilityValue;
    }

    part def TemperatureSensor {
        port tempOut : TemperatureOutPort;
    }

    part def HeatFluxMonitor {
        port fluxOut : HeatFluxOutPort;
    }

    action def EvaluatePerformanceAction {
        in measuredFlux : HeatFluxValue;
        in expectedFlux : HeatFluxValue;
        in degradationThreshold : Real;
        out isDegraded : Boolean;
    }

    part def InsulationController {
        attribute degradationThreshold : Real := 1.1;
        attribute currentState : OperationalState := OperationalState::standby;
        attribute isDegraded : Boolean := false;

        port hotTempIn : TemperatureInPort;
        port coldTempIn : TemperatureInPort;
        port fluxIn : HeatFluxInPort;
        port controlOut : ControlOutPort;

        action def ManagementCycle {
            in hotTemp : TemperatureValue;
            in coldTemp : TemperatureValue;
            in measuredFlux : HeatFluxValue;
            in conductivity : ThermalConductivityValue;
            in thickness : LengthValue;
            in threshold : Real;
            out degraded : Boolean;
            out newState : OperationalState;

            perform action evaluate : EvaluatePerformanceAction {
                in measuredFlux = measuredFlux;
                in expectedFlux = conductivity * (hotTemp - coldTemp) / thickness;
                in degradationThreshold = threshold;
                out isDegraded;
            }
            then assign degraded := evaluate.isDegraded;
            then assign newState := OperationalState::active;
        }

        state def OperationalStateMachine {
            state Standby;
            state ActiveInsulation;
            state DegradedMode;
            transition from Standby to ActiveInsulation when isDegraded == false;
            transition from ActiveInsulation to DegradedMode when isDegraded == true;
            transition from DegradedMode to ActiveInsulation when isDegraded == false;
        }

        exhibit state : OperationalStateMachine;
    }

    part def ThermalInsulationSystem {
        part aerogelCore : AerogelCore {
            attribute thermalConductivity = 0.015;
            attribute density = 0.1;
            attribute porosity = 0.95;
            attribute thickness = 0.05;
        }
        part structuralFrame : StructuralFrame {
            attribute compressionStrength = 1000000;
        }
        part vaporBarrier : VaporBarrier {
            attribute moisturePermeability = 1e-6;
        }
        part hotSideSensor : TemperatureSensor;
        part coldSideSensor : TemperatureSensor;
        part heatFluxMonitor : HeatFluxMonitor;
        part controller : InsulationController;

        flow hotTempFlow of TemperatureValue
            from hotSideSensor.tempOut.temperature to controller.hotTempIn.temperature;
        flow coldTempFlow of TemperatureValue
            from coldSideSensor.tempOut.temperature to controller.coldTempIn.temperature;
        flow heatFluxFlow of HeatFluxValue
            from heatFluxMonitor.fluxOut.heatFlux to controller.fluxIn.heatFlux;
    }

    requirement def ThermalResistanceRequirement {
        doc /* The aerogel core shall maintain ultra-low thermal conductivity below a specified maximum. */
        subject aerogelCore : AerogelCore;
        attribute maxThermalConductivity : ThermalConductivityValue;
        require constraint { aerogelCore.thermalConductivity <= maxThermalConductivity }
    }

    requirement def StructuralIntegrityRequirement {
        doc /* The structural frame shall provide sufficient compression resistance to protect the brittle aerogel core. */
        subject structuralFrame : StructuralFrame;
        attribute minCompressionStrength : PressureValue;
        require constraint { structuralFrame.compressionStrength >= minCompressionStrength }
    }

    requirement def MoistureProtectionRequirement {
        doc /* The vapor barrier shall prevent moisture ingress to preserve aerogel insulation properties. */
        subject vaporBarrier : VaporBarrier;
        attribute maxPermeability : MoisturePermeabilityValue;
        require constraint { vaporBarrier.moisturePermeability <= maxPermeability }
    }

    requirement def PerformanceMonitoringRequirement {
        doc /* The system shall continuously monitor temperature gradient and heat flux across the insulation barrier. */
        subject system : ThermalInsulationSystem;
    }

    requirement def OperationalStateRequirement {
        doc /* The controller shall evaluate performance and transition between active, standby, and degraded states. */
        subject controller : InsulationController;
    }

    package SystemRequirements {
        private import AdvancedThermalInsulationSystem::*;

        requirement <'REQ-01'> thermalResistanceReq : ThermalResistanceRequirement {
            subject aerogelCore : AerogelCore;
            attribute :>> maxThermalConductivity = 0.02;
        }

        requirement <'REQ-02'> structuralIntegrityReq : StructuralIntegrityRequirement {
            subject structuralFrame : StructuralFrame;
            attribute :>> minCompressionStrength = 500000;
        }

        requirement <'REQ-03'> moistureProtectionReq : MoistureProtectionRequirement {
            subject vaporBarrier : VaporBarrier;
            attribute :>> maxPermeability = 1e-5;
        }

        requirement <'REQ-04'> performanceMonitoringReq : PerformanceMonitoringRequirement {
            subject system : ThermalInsulationSystem;
        }

        requirement <'REQ-05'> operationalStateReq : OperationalStateRequirement {
            subject controller : InsulationController;
        }
    }
}
