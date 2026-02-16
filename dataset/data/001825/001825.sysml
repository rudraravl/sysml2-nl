package 'Orifice Plate Flow Measurement System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def FluidType;
    attribute def TapConfiguration;
    
    attribute def PressureDifferential :> Real;
    attribute def FlowCoefficient :> Real;
    attribute def ReynoldsNumber :> Real;
    attribute def BetaRatio :> Real;
    attribute def ExpansionFactor :> Real;
    
    item def ProcessFluid {
        attribute density :> Real;
        attribute viscosity :> Real;
        attribute temperature :> Real;
        attribute pressure :> Real;
        attribute velocity :> Real;
    }
    
    port def FluidPort {
        inout fluid : ProcessFluid;
    }
    
    port def PressurePort {
        out pressureValue :> Real;
    }
    
    port def SignalPort {
        inout signalValue :> Real;
    }
    
    port def DataPort {
        out flowRate :> Real;
        out massFlowRate :> Real;
    }
    
    part def Pipe {
        attribute internalDiameter :> Real;
        attribute schedule : String;
        attribute material : String;
        
        port inlet : FluidPort;
        port outlet : FluidPort;
    }
    
    part def OrificePlate {
        attribute orificeDiameter :> Real;
        attribute pipeDiameter :> Real;
        attribute betaRatio :> Real;
        attribute plateThickness :> Real;
        attribute dischargeCoefficient :> Real;
        attribute material : String;
        
        port upstream : FluidPort;
        port downstream : FluidPort;
        
        constraint betaCalculation {
            betaRatio == orificeDiameter / pipeDiameter
        }
        
        constraint betaLimits {
            betaRatio >= 0.20 and betaRatio <= 0.75
        }
        
        constraint thicknessLimit {
            plateThickness <= 0.05 * pipeDiameter
        }
    }
    
    part def PressureTap {
        attribute tapType : TapConfiguration;
        attribute distanceFromPlate :> Real;
        attribute tapDiameter :> Real;
        
        port processConnection : FluidPort;
        port instrumentConnection : PressurePort;
    }
    
    part def DifferentialPressureTransmitter {
        attribute rangeMin :> Real;
        attribute rangeMax :> Real;
        attribute accuracy :> Real;
        attribute outputMin :> Real;
        attribute outputMax :> Real;
        
        port highPressureInput : PressurePort;
        port lowPressureInput : PressurePort;
        port signalOutput : SignalPort;
        
        attribute measuredDifferential :> Real;
        
        action measureAndTransmit {
            first start;
            then action sensePressure {
                in pHigh :> Real;
                in pLow :> Real;
                out deltaP :> Real;
            }
            then action linearize {
                in differential :> Real;
                in rangeSpan :> Real;
                out normalizedValue :> Real;
            }
            then action convertToSignal {
                in normalized :> Real;
                out voltage :> Real;
            }
            then action transmit {
                in outputVoltage :> Real;
            }
            then done;
        }
    }
    
    part def FlowComputer {
        attribute calibrationFactor :> Real;
        attribute fluidDensity :> Real;
        attribute dischargeCoefficient :> Real;
        attribute expansionFactor :> Real;
        attribute orificeArea :> Real;
        attribute pipeArea :> Real;
        
        port signalInput : SignalPort;
        port dataOutput : DataPort;
        
        action computeFlow {
            first start;
            then action convertSignal {
                in voltage :> Real;
                out pressureDiff :> Real;
            }
            then action calculateVolumetricFlow {
                in deltaP :> Real;
                in density :> Real;
                in Cd :> Real;
                in epsilon :> Real;
                in Ao :> Real;
                in beta :> Real;
                out Qv :> Real;
            }
            then action calculateMassFlow {
                in volumetricFlow :> Real;
                in density :> Real;
                out Qm :> Real;
            }
            then action outputResults {
                in volFlow :> Real;
                in massFlow :> Real;
            }
            then done;
        }
    }
    
    part def FlowConditioner {
        attribute straightLengthUpstream :> Real;
        attribute straightLengthDownstream :> Real;
        attribute conditionerType : String;
        
        port inlet : FluidPort;
        port outlet : FluidPort;
    }
    
    part def FlowIndicator {
        attribute displayUnits : String;
        attribute updateRate :> Real;
        
        port dataInput : DataPort;
        
        attribute displayedFlowRate :> Real;
        attribute displayedMassFlowRate :> Real;
    }
    
    action def MeasureFlowRate {
        in processFluid : ProcessFluid;
        in inletPressure :> Real;
        out volumetricFlowRate :> Real;
        out massFlowRate :> Real;
        out differentialPressure :> Real;
    }
    
    part orificePlateMeterAssembly {
        doc /* 
            An orifice plate flow measurement system measures the volumetric and mass flow rate 
            of process fluids by creating a controlled pressure differential across a precisely 
            machined restriction plate installed in a pipe. The system operates on the principle 
            that fluid velocity increases and pressure decreases as it passes through the orifice 
            opening. By measuring the pressure difference between upstream and downstream taps and 
            applying the Bernoulli equation with empirical discharge coefficients, the system 
            accurately calculates flow rate for process monitoring and control applications.
        */
        
        part upstreamPipe : Pipe {
            attribute internalDiameter = 100.0;
            attribute schedule = "40";
            attribute material = "Stainless Steel 316";
        }
        
        part flowConditioner : FlowConditioner {
            attribute straightLengthUpstream = 1000.0;
            attribute straightLengthDownstream = 500.0;
            attribute conditionerType = "Tube Bundle";
        }
        
        part orificePlate : OrificePlate {
            attribute orificeDiameter = 50.0;
            attribute pipeDiameter = 100.0;
            attribute betaRatio = 0.5;
            attribute plateThickness = 3.0;
            attribute dischargeCoefficient = 0.61;
            attribute material = "Stainless Steel 316";
        }
        
        part upstreamTap : PressureTap {
            attribute distanceFromPlate = 25.4;
            attribute tapDiameter = 6.0;
        }
        
        part downstreamTap : PressureTap {
            attribute distanceFromPlate = 25.4;
            attribute tapDiameter = 6.0;
        }
        
        part dpTransmitter : DifferentialPressureTransmitter {
            attribute rangeMin = 0.0;
            attribute rangeMax = 100000.0;
            attribute accuracy = 0.075;
            attribute outputMin = 4.0;
            attribute outputMax = 20.0;
        }
        
        part flowComputer : FlowComputer {
            attribute calibrationFactor = 1.0;
            attribute fluidDensity = 1000.0;
            attribute dischargeCoefficient = 0.61;
            attribute expansionFactor = 1.0;
            attribute orificeArea = 1963.5;
            attribute pipeArea = 7853.98;
        }
        
        part downstreamPipe : Pipe {
            attribute internalDiameter = 100.0;
            attribute schedule = "40";
            attribute material = "Stainless Steel 316";
        }
        
        part flowIndicator : FlowIndicator {
            attribute displayUnits = "m^3/h";
            attribute updateRate = 1.0;
        }
        
        connect flowConditioner.outlet to upstreamPipe.inlet;
        connect upstreamPipe.outlet to orificePlate.upstream;
        connect orificePlate.downstream to downstreamPipe.inlet;
        
        connect upstreamPipe.outlet to upstreamTap.processConnection;
        connect downstreamPipe.inlet to downstreamTap.processConnection;
        
        connect upstreamTap.instrumentConnection to dpTransmitter.highPressureInput;
        connect downstreamTap.instrumentConnection to dpTransmitter.lowPressureInput;
        
        connect dpTransmitter.signalOutput to flowComputer.signalInput;
        connect flowComputer.dataOutput to flowIndicator.dataInput;
        
        action continuousFlowMeasurement : MeasureFlowRate {
            first start;
            then merge measurementCycle;
            then action conditionFlow;
            then action createDifferential {
                out upstreamPressure :> Real;
                out downstreamPressure :> Real;
            }
            then action senseDifferential;
            then action computeFlowRate;
            then action displayFlow;
            then measurementCycle;
        }
    }
    
    requirement def FlowMeasurementAccuracy {
        doc /* The flow measurement system shall achieve specified accuracy across the operating range. */
        
        require constraint totalUncertainty {
            doc /* Total measurement uncertainty shall not exceed ±2.0% of reading. */
        }
        
        require constraint repeatability {
            doc /* Measurement repeatability shall be within ±0.5% of reading. */
        }
    }
    
    requirement def PressureLossRequirement {
        doc /* Permanent pressure loss shall be minimized to reduce energy consumption. */
        
        require constraint maxPermanentLoss {
            doc /* Permanent pressure loss shall not exceed 5% of differential pressure. */
        }
    }
    
    requirement def InstallationRequirement {
        doc /* Proper installation conditions shall be maintained for accurate measurement. */
        
        require constraint straightPipeLength {
            doc /* Minimum 10 pipe diameters upstream and 5 pipe diameters downstream straight pipe. */
        }
        
        require constraint concentricity {
            doc /* Orifice plate shall be concentric with pipe within ±0.01 pipe diameters. */
        }
        
        require constraint perpendicularity {
            doc /* Orifice plate shall be perpendicular to pipe axis within ±1 degree. */
        }
    }
    
    requirement def OperatingRangeRequirement {
        doc /* System shall operate within specified fluid and flow conditions. */
        
        require constraint reynoldsNumber {
            doc /* Reynolds number shall be greater than 4000 for turbulent flow. */
        }
        
        require constraint fluidCondition {
            doc /* Fluid shall be single-phase, clean, and non-erosive. */
        }
    }
    
    requirement <'SYS-ORIFICE-001'> orificePlateSystemRequirement {
        doc /* 
            The orifice plate flow measurement system shall accurately measure volumetric and 
            mass flow rates of process fluids by creating a controlled pressure differential 
            across a restriction plate and computing flow rate using the differential pressure, 
            fluid properties, and empirically determined discharge coefficients according to 
            ISO 5167 standards.
        */
        
        subject orificePlateMeterAssembly;
        
        require flowMeasurementAccuracy : FlowMeasurementAccuracy;
        require pressureLossRequirement : PressureLossRequirement;
        require installationRequirement : InstallationRequirement;
        require operatingRangeRequirement : OperatingRangeRequirement;
        
        assume constraint fluidProperties {
            doc /* Process fluid properties (density, viscosity) are known and stable. */
        }
        
        assume constraint steadyFlow {
            doc /* Flow is steady-state without significant pulsations or surges. */
        }
    }
    
    state def MeasurementStates {
        entry; then initialization;
        
        state initialization {
            do action calibrateTransmitter;
            do action verifyConfiguration;
        }
        
        accept at initialization then standby;
        
        state standby;
        
        accept StartMeasurement at standby then measuring;
        
        state measuring {
            state stabilizing {
                do action monitorFlowStability;
            }
            
            accept at stabilizing then acquiring;
            
            state acquiring {
                do action sampleDifferentialPressure;
                do action recordFluidProperties;
            }
            
            accept at acquiring then computing;
            
            state computing {
                do action calculateDischargeCoefficient;
                do action calculateExpansionFactor;
                do action computeVolumetricFlow;
                do action computeMassFlow;
            }
            
            accept at computing then validating;
            
            state validating {
                do action checkReynoldsNumber;
                do action verifyBetaRatio;
                do action validatePressureDifferential;
            }
            
            accept at validating then outputting;
            
            state outputting {
                do action transmitFlowData;
                do action updateDisplay;
            }
            
            accept at outputting then stabilizing;
        }
        
        accept StopMeasurement at measuring then standby;
        
        state errorState {
            do action logError;
            do action activateAlarm;
        }
        
        accept ResetSystem at errorState then standby;
        
        state maintenance {
            do action isolateSystem;
        }
        
        accept EnterMaintenance at standby then maintenance;
        accept ExitMaintenance at maintenance then initialization;
    }
    
    part systemController {
        attribute systemStatus : String;
        attribute measurementPhase : String;
        attribute initializationComplete : Boolean;
        attribute flowStabilized : Boolean;
        attribute dataAcquired : Boolean;
        attribute computationComplete : Boolean;
        attribute validationPassed : Boolean;
        attribute validationFailed : Boolean;
        attribute continuousMeasurement : Boolean;
        attribute criticalError : Boolean;
        
        exhibit state operatingBehavior : MeasurementStates;
    }
}
