package AerogelThermalInsulationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def ThermalConductivityValue :> Real;
    attribute def HeatFluxValue :> Real;
    attribute def PorosityValue :> Real;
    attribute def SurfaceAreaValue :> Real;

    enum def OperationalMode {
        standby;
        activeInsulation;
        monitoring;
        degraded;
    }

    item def ThermalEnergy {
        attribute flowRate : HeatFluxValue;
        attribute direction : String;
    }

    port def ThermalPort {
        attribute temperature : ThermodynamicTemperatureValue;
        inout thermalFlow : ThermalEnergy;
    }

    part def AerogelMaterial {
        doc /* Nanoporous silica aerogel with ultra-low thermal conductivity */
        attribute thermalConductivity : ThermalConductivityValue;
        attribute density : MassDensityValue;
        attribute porosity : PorosityValue;
        attribute thickness : LengthValue;
        attribute surfaceArea : SurfaceAreaValue;
    }

    part def TemperatureSensor {
        attribute reading : ThermodynamicTemperatureValue;
        out port sensorOutput;
    }

    part def HeatFluxMonitor {
        attribute measuredFlux : HeatFluxValue;
        out port fluxOutput;
    }

    part def StructuralFrame {
        attribute compressionResistance : PressureValue;
        attribute frameMass : MassValue;
    }

    part def VaporBarrier {
        attribute moisturePermeability : Real;
        attribute sealEffectiveness : Real;
    }

    action def MeasureTemperatureGradient {
        in hotSideTemp : ThermodynamicTemperatureValue;
        in coldSideTemp : ThermodynamicTemperatureValue;
        out temperatureDelta : ThermodynamicTemperatureValue;
    }

    action def ComputeHeatFlux {
        in conductivity : ThermalConductivityValue;
        in thickness : LengthValue;
        in tempDelta : ThermodynamicTemperatureValue;
        in area : SurfaceAreaValue;
        out heatFlux : HeatFluxValue;
    }

    action def EvaluatePerformance {
        in actualFlux : HeatFluxValue;
        in targetFlux : HeatFluxValue;
        out efficiency : Real;
        out status : OperationalMode;
    }

    action def ThermalManagementCycle {
        first start;
        then merge continuousOperation;
        
        then action measureGradient : MeasureTemperatureGradient {
            in hotSideTemp : ThermodynamicTemperatureValue;
            in coldSideTemp : ThermodynamicTemperatureValue;
            out temperatureDelta : ThermodynamicTemperatureValue;
        }
        
        then action computeFlux : ComputeHeatFlux {
            in conductivity = 0.013;
            in thickness = 0.05;
            in tempDelta = measureGradient.temperatureDelta;
            in area = 1.0;
            out heatFlux : HeatFluxValue;
        }
        
        then action evaluate : EvaluatePerformance {
            in actualFlux = computeFlux.heatFlux;
            in targetFlux = 0.25;
            out efficiency : Real;
            out status : OperationalMode;
        }
        
        then decide;
            if evaluate.efficiency >= 0.95 then normalOperation;
            if evaluate.efficiency >= 0.80 then reducedPerformance;
            else criticalState;
        
        action normalOperation {
            doc /* System operating within optimal parameters */
        }
        then continuousOperation;
        
        action reducedPerformance {
            doc /* Performance degraded but acceptable */
        }
        then continuousOperation;
        
        action criticalState {
            doc /* Performance below acceptable threshold */
        }
        then done;
    }

    state def AerogelInsulationStateMachine {
        entry; then initialization;
        
        state initialization;
        accept at when Time::Clock::now == 0.5 [s]
        then operational;
        
        state operational {
            entry; then steadyState;
            
            state steadyState {
                do action measure : MeasureTemperatureGradient;
            }
            accept at when Time::Clock::now == 1.0 [s]
            then analyzing;
            
            state analyzing {
                do action compute : ComputeHeatFlux;
            }
            accept at when Time::Clock::now == 2.0 [s]
            if compute.heatFlux <= 0.3 then steadyState;
            if compute.heatFlux > 0.3 then degrading;
        }
        
        state degrading {
            do action logWarning;
            accept at when Time::Clock::now == 3.0 [s]
            then operational.steadyState;
        }
    }

    part def AerogelInsulationSystem {
        doc /* 
         * Primary Function: Provide ultra-efficient thermal insulation using aerogel
         * material to minimize heat transfer between environments with extreme
         * temperature differentials.
         * 
         * The system leverages aerogel's nanoporous structure (typically 95-99% air)
         * to achieve thermal conductivity as low as 0.013 W/(m·K), making it one of
         * the most effective insulation materials available. The aerogel creates a
         * thermal barrier by trapping air in nanoscale pores, drastically reducing
         * conductive, convective, and radiative heat transfer.
         * 
         * Applications include:
         * - Cryogenic storage and transport (LNG, liquid hydrogen)
         * - Aerospace thermal protection systems
         * - High-temperature industrial equipment insulation
         * - Energy-efficient building envelopes
         * - Electronics thermal management
         * 
         * The system continuously monitors thermal performance, measuring temperature
         * gradients and heat flux to ensure optimal insulation effectiveness while
         * maintaining structural integrity under operational loads.
         */
        
        attribute systemEfficiency : Real;
        attribute currentMode : OperationalMode;
        attribute maxOperatingTemp : ThermodynamicTemperatureValue;
        
        part aerogelCore : AerogelMaterial {
            attribute :>> thermalConductivity = 0.013;
            attribute :>> density = 120.0;
            attribute :>> porosity = 0.97;
            attribute :>> thickness = 0.05;
            attribute :>> surfaceArea = 1.5;
        }
        
        port hotSide : ThermalPort {
            attribute :>> temperature : ThermodynamicTemperatureValue;
        }
        
        port coldSide : ThermalPort {
            attribute :>> temperature : ThermodynamicTemperatureValue;
        }
        
        part hotSideSensor : TemperatureSensor {
            attribute :>> reading : ThermodynamicTemperatureValue;
        }
        
        part coldSideSensor : TemperatureSensor {
            attribute :>> reading : ThermodynamicTemperatureValue;
        }
        
        part fluxMonitor : HeatFluxMonitor {
            attribute :>> measuredFlux : HeatFluxValue;
        }
        
        part supportStructure : StructuralFrame {
            attribute :>> compressionResistance = 100000.0;
            attribute :>> frameMass = 2.5;
        }
        
        part moistureBarrier : VaporBarrier {
            attribute :>> moisturePermeability = 0.001;
            attribute :>> sealEffectiveness = 0.99;
        }
        
        connection thermalPath {
            end hotSide;
            end coldSide;
        }
        
        perform action thermalManagement : ThermalManagementCycle;
        
        exhibit state insulationBehavior : AerogelInsulationStateMachine;
    }

    requirement def ThermalInsulationPerformance {
        doc /* The aerogel insulation system shall provide superior thermal
             * resistance to minimize heat transfer across temperature boundaries.
             */
        subject system : AerogelInsulationSystem;
    }

    requirement <'REQ-2001'> minimizeHeatFlux : ThermalInsulationPerformance {
        doc /* The system shall maintain heat flux below 0.3 W/m² under
             * standard operating conditions with temperature differential
             * up to 300 K.
             */
        subject sys :> AerogelInsulationSystem;
        
        require constraint {
            sys.fluxMonitor.measuredFlux <= 0.3
        }
    }

    requirement <'REQ-2002'> ultraLowConductivity {
        doc /* The aerogel material shall exhibit thermal conductivity
             * not exceeding 0.015 W/(m·K) to ensure maximum insulation
             * effectiveness.
             */
        subject material :>> insulationSystem.aerogelCore;
        
        assert constraint {
            material.thermalConductivity <= 0.015
        }
    }

    requirement <'REQ-2003'> lightweightDesign {
        doc /* The aerogel insulation shall maintain density below
             * 150 kg/m³ to minimize system weight while providing
             * superior thermal performance.
             */
        subject material :>> insulationSystem.aerogelCore;
        
        assert constraint {
            material.density <= 150.0
        }
    }

    requirement <'REQ-2004'> highPorosityMaintenance {
        doc /* The aerogel shall maintain porosity of at least 95%
             * to ensure optimal thermal insulation through air
             * entrapment in nanopores.
             */
        subject material :>> insulationSystem.aerogelCore;
        
        assert constraint {
            material.porosity >= 0.95
        }
    }

    requirement <'REQ-2005'> structuralStability {
        doc /* The structural frame shall withstand compression loads
             * of at least 100 kPa without compromising aerogel
             * integrity or insulation performance.
             */
        subject frame :>> insulationSystem.supportStructure;
        
        assert constraint {
            frame.compressionResistance >= 100000.0
        }
    }

    requirement <'REQ-2006'> moistureProtection {
        doc /* The vapor barrier shall prevent moisture ingress with
             * seal effectiveness of at least 98% to protect aerogel
             * from hydrophilic degradation.
             */
        subject barrier :>> insulationSystem.moistureBarrier;
        
        assert constraint {
            barrier.sealEffectiveness >= 0.98
        }
    }

    part insulationSystem : AerogelInsulationSystem {
        attribute :>> systemEfficiency = 0.96;
        attribute :>> currentMode = OperationalMode::activeInsulation;
        attribute :>> maxOperatingTemp = 650.0;
        
        attribute :>> hotSide.temperature = 573.15;
        attribute :>> coldSide.temperature = 293.15;
    }

    satisfy minimizeHeatFlux by insulationSystem;
    satisfy ultraLowConductivity by insulationSystem.aerogelCore;
    satisfy lightweightDesign by insulationSystem.aerogelCore;
    satisfy highPorosityMaintenance by insulationSystem.aerogelCore;
    satisfy structuralStability by insulationSystem.supportStructure;
    satisfy moistureProtection by insulationSystem.moistureBarrier;
}
