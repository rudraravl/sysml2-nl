package 'Water Hammer System' {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def PressureWaveSpeed :> ISQ::SpeedValue;
    attribute def FlowVelocity :> ISQ::SpeedValue;
    attribute def FlowRate :> ISQ::VolumeFlowRateValue;
    attribute def PipeCrossSectionArea :> ISQ::AreaValue;
    attribute def ValveOpeningFraction :> Real;
    attribute def SurgePressure :> ISQ::PressureValue;
    attribute def FluidDensity :> ISQ::DensityValue;
    attribute def BulkModulus :> ISQ::PressureValue;
    attribute def WallThickness :> ISQ::LengthValue;
    attribute def ElasticModulus :> ISQ::PressureValue;

    attribute def ValveCommand;
    attribute def SurgeDetected;
    attribute def SystemNormal;

    item def Water {
        attribute density : FluidDensity;
        attribute bulkModulus : BulkModulus;
    }

    port def HydraulicPort {
        in attribute inletPressure : ISQ::PressureValue;
        in attribute inletFlow : FlowRate;
        out attribute outletPressure : ISQ::PressureValue;
        out attribute outletFlow : FlowRate;
        item water : Water;
    }

    part def Reservoir {
        attribute staticHead : ISQ::LengthValue;
        attribute staticPressure : ISQ::PressureValue;
        port outlet : HydraulicPort;
    }

    part def Pipeline {
        attribute length : ISQ::LengthValue;
        attribute diameter : ISQ::LengthValue;
        attribute wallThickness : WallThickness;
        attribute material : String;
        attribute elasticModulus : ElasticModulus;
        attribute waveSpeed : PressureWaveSpeed;
        attribute crossSectionArea : PipeCrossSectionArea;
        port inlet : HydraulicPort;
        port outlet : HydraulicPort;
    }

    part def ControlValve {
        attribute openingFraction : ValveOpeningFraction;
        attribute closureRate : Real;
        attribute nominalDiameter : ISQ::LengthValue;
        port upstream : HydraulicPort;
        port downstream : HydraulicPort;
        port control {
            in command : ValveCommand;
        }
    }

    part def PressureSensor {
        attribute measuredPressure : ISQ::PressureValue;
        attribute samplingRate : ISQ::FrequencyValue;
        port sensing : HydraulicPort;
        port output {
            out pressureReading : ISQ::PressureValue;
        }
    }

    part def FlowMeter {
        attribute measuredFlow : FlowRate;
        attribute measuredVelocity : FlowVelocity;
        port sensing : HydraulicPort;
        port output {
            out flowReading : FlowRate;
            out velocityReading : FlowVelocity;
        }
    }

    part def SurgeTank {
        attribute volume : ISQ::VolumeValue;
        attribute airCushionVolume : ISQ::VolumeValue;
        attribute waterLevel : ISQ::LengthValue;
        port interface : HydraulicPort;
    }

    part def ReliefValve {
        attribute setPoint : ISQ::PressureValue;
        attribute dischargeCapacity : FlowRate;
        attribute isOpen : Boolean;
        port inlet : HydraulicPort;
        port discharge : HydraulicPort;
    }

    part def AirVessel {
        attribute totalVolume : ISQ::VolumeValue;
        attribute airVolume : ISQ::VolumeValue;
        attribute waterVolume : ISQ::VolumeValue;
        attribute preChargePressure : ISQ::PressureValue;
        port interface : HydraulicPort;
    }

    part def SurgeController {
        attribute maxAllowablePressure : ISQ::PressureValue;
        attribute minAllowablePressure : ISQ::PressureValue;
        attribute normalOperatingPressure : ISQ::PressureValue;
        attribute maxClosureRate : Real;
        port pressureInput {
            in pressure : ISQ::PressureValue;
        }
        port flowInput {
            in flow : FlowRate;
            in velocity : FlowVelocity;
        }
        port valveControl {
            out command : ValveCommand;
        }
        port reliefControl {
            out activate : Boolean;
        }
    }

    action def MeasurePressure {
        in currentPressure : ISQ::PressureValue;
        out reading : ISQ::PressureValue;
    }

    action def MeasureFlow {
        in currentFlow : FlowRate;
        in pipeArea : PipeCrossSectionArea;
        out flowReading : FlowRate;
        out velocityReading : FlowVelocity;
    }

    action def CalculateWaveSpeed {
        in bulkModulus : BulkModulus;
        in density : FluidDensity;
        in diameter : ISQ::LengthValue;
        in wallThickness : WallThickness;
        in elasticModulus : ElasticModulus;
        out waveSpeed : PressureWaveSpeed;
    }

    action def ComputeSurgePressure {
        in density : FluidDensity;
        in waveSpeed : PressureWaveSpeed;
        in velocityChange : FlowVelocity;
        out surgePressure : SurgePressure;
    }

    action def DetectSurge {
        in measuredPressure : ISQ::PressureValue;
        in baselinePressure : ISQ::PressureValue;
        in threshold : ISQ::PressureValue;
        out surgeDetected : Boolean;
        out surgeMagnitude : SurgePressure;
    }

    action def ControlValveClosure {
        in currentOpening : ValveOpeningFraction;
        in targetOpening : ValveOpeningFraction;
        in maxRate : Real;
        out closureCommand : ValveCommand;
        out newOpening : ValveOpeningFraction;
    }

    action def ActivateReliefValve {
        in pressure : ISQ::PressureValue;
        in setPoint : ISQ::PressureValue;
        out shouldOpen : Boolean;
    }

    action def DampenSurge {
        in surgePressure : SurgePressure;
        in airVesselVolume : ISQ::VolumeValue;
        in surgeTankVolume : ISQ::VolumeValue;
        out dampenedPressure : ISQ::PressureValue;
    }

    action def ManageWaterHammer {
        in attribute systemPressure : ISQ::PressureValue;
        in attribute systemFlow : FlowRate;
        in attribute systemVelocity : FlowVelocity;
        in attribute valveOpening : ValveOpeningFraction;
        in attribute maxPressure : ISQ::PressureValue;
        in attribute minPressure : ISQ::PressureValue;
        in attribute normalPressure : ISQ::PressureValue;
        in attribute waveSpeed : PressureWaveSpeed;
        in attribute fluidDensity : FluidDensity;
        in attribute maxClosureRate : Real;

        out attribute valveCommand : ValveCommand;
        out attribute reliefActivation : Boolean;

        private attribute baselinePressure := normalPressure;
        private attribute previousVelocity := systemVelocity;
        private attribute surgeActive : Boolean := false;

        first start;
        then merge monitoringCycle;

        then action measurePressure : MeasurePressure {
            in currentPressure = systemPressure;
            out reading;
        }

        then action measureFlow : MeasureFlow {
            in currentFlow = systemFlow;
            in pipeArea : PipeCrossSectionArea;
            out flowReading;
            out velocityReading;
        }

        then action detectSurge : DetectSurge {
            in measuredPressure = measurePressure.reading;
            in baselinePressure = baselinePressure;
            in threshold = 0.1 * normalPressure;
            out surgeDetected;
            out surgeMagnitude;
        }

        then decide;
            if detectSurge.surgeDetected then handleSurge;
            if !detectSurge.surgeDetected then normalOp;

        action handleSurge {
            first action computeSurge : ComputeSurgePressure {
                in density = fluidDensity;
                in waveSpeed = waveSpeed;
                in velocityChange = measureFlow.velocityReading - previousVelocity;
                out surgePressure;
            }

            then action dampen : DampenSurge {
                in surgePressure = computeSurge.surgePressure;
                in airVesselVolume : ISQ::VolumeValue;
                in surgeTankVolume : ISQ::VolumeValue;
                out dampenedPressure;
            }

            then action controlClosure : ControlValveClosure {
                in currentOpening = valveOpening;
                in targetOpening : ValveOpeningFraction;
                in maxRate = maxClosureRate;
                out closureCommand;
                out newOpening;
            }

            then action activateRelief : ActivateReliefValve {
                in pressure = measurePressure.reading;
                in setPoint = maxPressure * 0.95;
                out shouldOpen;
            }

            then assign valveCommand := controlClosure.closureCommand;
            then assign reliefActivation := activateRelief.shouldOpen;
            then assign surgeActive := true;
        }
        then monitoringCycle;

        action normalOp {
            first action normalControl : ControlValveClosure {
                in currentOpening = valveOpening;
                in targetOpening : ValveOpeningFraction;
                in maxRate = maxClosureRate;
                out closureCommand;
                out newOpening;
            }

            then assign valveCommand := normalControl.closureCommand;
            then assign reliefActivation := false;
            then assign previousVelocity := measureFlow.velocityReading;
            then assign surgeActive := false;
        }
        then monitoringCycle;
    }

    state machine def WaterHammerStateMachine {
        initial state Idle;

        state Idle {
            entry action initializeSystem;
            accept SystemNormal;
            transition to NormalFlow;
        }

        state NormalFlow {
            doc /* Steady state flow with stable pressure and velocity. */
            entry action establishBaseline;
            accept ValveCommand;
            transition to ValveClosing;
        }

        state ValveClosing {
            doc /* Valve closure initiates pressure wave propagation. */
            entry action beginClosure;
            accept SurgeDetected;
            transition to SurgePropagation;
        }

        state SurgePropagation {
            doc /* Pressure surge wave travels through pipeline at wave speed. */
            entry action calculateSurge;
            do action monitorWaveFront;
            accept SurgeDetected;
            transition to SurgeMitigation;
        }

        state SurgeMitigation {
            doc /* Active mitigation through surge tanks, air vessels, and relief valves. */
            entry action activateMitigation;
            do action dampenPressure;
            accept SystemNormal;
            transition to Recovery;
        }

        state Recovery {
            doc /* System returns to normal operating conditions. */
            entry action resetProtection;
            accept SystemNormal;
            transition to NormalFlow;
        }
    }

    part def WaterHammerSystem {
        doc /*
            A water hammer system manages the transient pressure surge phenomenon 
            that occurs when fluid flow velocity changes rapidly in a pipeline.
            
            The system's primary function is to detect, analyze, and mitigate 
            dangerous pressure surges caused by sudden valve closures, pump trips, 
            or other rapid flow changes. Water hammer creates pressure waves that 
            propagate through the pipeline at the speed of sound in the fluid, 
            potentially causing catastrophic pipe rupture, valve damage, or 
            equipment failure.
            
            The system operates by continuously monitoring pressure and flow 
            conditions throughout the pipeline network. When rapid velocity changes 
            are detected, it calculates the resulting pressure surge magnitude using 
            the Joukowsky equation and implements protective measures including 
            controlled valve closure rates, surge tank absorption, air vessel 
            cushioning, and pressure relief activation to maintain system integrity 
            and prevent damage to pipeline infrastructure.
        */

        attribute fluidDensity : FluidDensity = 1000.0 [kg/(m^3)];
        attribute fluidBulkModulus : BulkModulus = 2.2e9 [Pa];
        attribute normalPressure : ISQ::PressureValue = 600000.0 [Pa];
        attribute maxAllowablePressure : ISQ::PressureValue = 1800000.0 [Pa];
        attribute minAllowablePressure : ISQ::PressureValue = 100000.0 [Pa];

        part sourceReservoir : Reservoir {
            attribute :>> staticHead = 50.0 [m];
            attribute :>> staticPressure = 490500.0 [Pa];
        }

        part mainPipeline : Pipeline {
            attribute :>> length = 500.0 [m];
            attribute :>> diameter = 0.4 [m];
            attribute :>> wallThickness = 0.01 [m];
            attribute :>> material = "Steel";
            attribute :>> elasticModulus = 2.0e11 [Pa];
            attribute :>> waveSpeed = 1200.0 [m/s];
            attribute :>> crossSectionArea = 0.1257 [m^2];
        }

        part controlValve : ControlValve {
            attribute :>> openingFraction = 1.0;
            attribute :>> closureRate = 0.1;
            attribute :>> nominalDiameter = 0.4 [m];
        }

        part upstreamSensor : PressureSensor {
            attribute :>> samplingRate = 100.0 [Hz];
        }

        part downstreamSensor : PressureSensor {
            attribute :>> samplingRate = 100.0 [Hz];
        }

        part flowMeter : FlowMeter;

        part surgeTank : SurgeTank {
            attribute :>> volume = 10.0 [m^3];
            attribute :>> airCushionVolume = 3.0 [m^3];
            attribute :>> waterLevel = 5.0 [m];
        }

        part airVessel : AirVessel {
            attribute :>> totalVolume = 5.0 [m^3];
            attribute :>> airVolume = 3.0 [m^3];
            attribute :>> waterVolume = 2.0 [m^3];
            attribute :>> preChargePressure = 400000.0 [Pa];
        }

        part reliefValve : ReliefValve {
            attribute :>> setPoint = 1700000.0 [Pa];
            attribute :>> dischargeCapacity = 0.05 [m^3/s];
            attribute :>> isOpen = false;
        }

        part controller : SurgeController {
            attribute :>> maxAllowablePressure = WaterHammerSystem::maxAllowablePressure;
            attribute :>> minAllowablePressure = WaterHammerSystem::minAllowablePressure;
            attribute :>> normalOperatingPressure = WaterHammerSystem::normalPressure;
            attribute :>> maxClosureRate = 0.05;
        }

        connect sourceReservoir.outlet to mainPipeline.inlet;
        connect mainPipeline.inlet to upstreamSensor.sensing;
        connect mainPipeline.outlet to controlValve.upstream;
        connect controlValve.upstream to flowMeter.sensing;
        connect controlValve.downstream to downstreamSensor.sensing;
        connect mainPipeline.outlet to surgeTank.interface;
        connect mainPipeline.outlet to airVessel.interface;
        connect controlValve.downstream to reliefValve.inlet;
        connect upstreamSensor.output to controller.pressureInput;
        connect flowMeter.output to controller.flowInput;
        connect controller.valveControl to controlValve.control;

        exhibit state hammerBehavior : WaterHammerStateMachine;

        perform action manageSystem : ManageWaterHammer {
            in systemPressure = upstreamSensor.measuredPressure;
            in systemFlow = flowMeter.measuredFlow;
            in systemVelocity = flowMeter.measuredVelocity;
            in valveOpening = controlValve.openingFraction;
            in maxPressure = WaterHammerSystem::maxAllowablePressure;
            in minPressure = WaterHammerSystem::minAllowablePressure;
            in normalPressure = WaterHammerSystem::normalPressure;
            in waveSpeed = mainPipeline.waveSpeed;
            in fluidDensity = WaterHammerSystem::fluidDensity;
            in maxClosureRate = controller.maxClosureRate;
            out valveCommand;
            out reliefActivation;
        }
    }

    requirement <'WH-REQ-001'> surgePressureLimit {
        doc /*
            The water hammer system shall limit transient pressure surges 
            to prevent exceeding maximum allowable pipeline pressure.
        */
        subject waterHammerSystem : WaterHammerSystem;

        require constraint maxPressureConstraint {
            waterHammerSystem.upstreamSensor.measuredPressure <= waterHammerSystem.maxAllowablePressure
        }

        require constraint minPressureConstraint {
            waterHammerSystem.downstreamSensor.measuredPressure >= waterHammerSystem.minAllowablePressure
        }
    }

    requirement <'WH-REQ-002'> surgeDetectionResponse {
        doc /*
            The system shall detect pressure surges within 10 milliseconds 
            and initiate mitigation actions within 50 milliseconds.
        */
        subject waterHammerSystem : WaterHammerSystem;

        require constraint detectionTime {
            waterHammerSystem.upstreamSensor.samplingRate >= 100.0 [Hz]
        }
    }

    requirement <'WH-REQ-003'> controlledValveOperation {
        doc /*
            Valve closure rate shall be controlled to limit surge magnitude 
            according to Joukowsky equation constraints.
        */
        subject waterHammerSystem : WaterHammerSystem;

        require constraint closureRateLimit {
            waterHammerSystem.controlValve.closureRate <= waterHammerSystem.controller.maxClosureRate
        }
    }

    requirement <'WH-REQ-004'> reliefValveActivation {
        doc /*
            Relief valve shall activate automatically when pressure exceeds 
            95% of maximum allowable pressure.
        */
        subject waterHammerSystem : WaterHammerSystem;

        require constraint reliefSetPoint {
            waterHammerSystem.reliefValve.setPoint == 0.95 * waterHammerSystem.maxAllowablePressure
        }
    }

    part system : WaterHammerSystem {
        satisfy surgePressureLimit;
        satisfy surgeDetectionResponse;
        satisfy controlledValveOperation;
        satisfy reliefValveActivation;
    }
}
